@tool
extends RefCounted

class_name InlineTransformEngine

"""
INLINE TRANSFORM ENGINE
=======================

PURPOSE: Extend the editor with keyboard transform actions for the current
Node3D selection - no plugin modes, no preview, no overlays.

RESPONSIBILITIES:
- Poll configured keys every frame and gate them behind an explicit
  pick-up toggle (default Tab) for scene nodes; the picked selection
  follows the mouse cursor like a drag preview until Enter/Tab confirm
  or Escape resets it to the pickup-time transforms
- Rotate, move and scale (all stepped with hold-repeat)
  all selected Node3D nodes directly - always in world space
- Quick duplicate (default V): copies the current selection and picks the
  copies up for placement; confirming keeps them as one undoable action,
  reset/cancel removes them again
- The mouse-follow snaps to the editor's translate snap increment (the
  fine modifier gives 1/10 steps)
- Batch changes into debounced, undoable editor actions
- While a file is dragged from the asset browser into the 3D viewport,
  transform the editor's own drag preview node and transfer that transform
  onto the newly instantiated nodes once the drop lands

ARCHITECTURE POSITION:
- Driven by plugin.gd's _process loop, always on
- Pure direct node mutation - does not use TransformState or plugin modes
- Movement keys nudge the picked selection in camera-snapped world axes
  (W/S/A/D + Q/E) on top of the mouse-follow position
"""

const UNDO_DEBOUNCE_MS := 400.0
const UNDO_ACTION_NAME := "Keyboard Transform Nodes"
const MIN_SCALE := 0.01
const ROTATE_FIRST_REPEAT_MS := 250.0
const ROTATE_REPEAT_MS := 100.0
const FINE_MULTIPLIER := 0.1
const LARGE_MULTIPLIER := 5.0
const FLOOR_CAST_RANGE := 10000.0

## Injected by plugin.gd (EditorPlugin.get_undo_redo)
var undo_redo: EditorUndoRedoManager

var _pending_undo: Dictionary = {}  # instance_id -> {"node": Node3D, "original": Transform3D}
var _last_change_ms: float = -1.0
var _last_selection_ids: Array = []
var _held_actions: Dictionary = {}
var _next_repeat_ms: Dictionary = {}

var _drag_active := false
var _drag_modified := false
var _drag_base: Vector3 = Vector3.ZERO
var _drag_last_written_pos: Vector3 = Vector3.ZERO
var _drag_offset: Vector3 = Vector3.ZERO
var _drag_basis: Basis = Basis()
var _drag_scale := 1.0
var _drag_selection_ids: Array = []

var _pickup_active := false
var _pickup_offset := Vector3.ZERO
var _pickup_anchor := Vector3.ZERO
var _toggle_keys_held := {}
var _pickup_mouse_held := {}
var _lmb_release_pending := false
var _dup_copies: Array[Node3D] = []
var _pickup_cancelled := false
var _snap_toggle: Button = null
var _floor_lock_y = null


## Main Processing


func process(camera: Camera3D, delta: float) -> void:
	"""Apply keyboard actions to the picked-up selection or the drag preview."""
	if not camera or not is_instance_valid(camera):
		_flush_undo_if_due()
		return

	var viewport := _get_viewport_3d()
	if not viewport:
		_flush_undo_if_due()
		return

	# Drag handling runs before every other guard: during a drag the
	# subviewport mouse position can go stale, and a preview node existing
	# already implies the cursor is over the 3D viewport.
	var drag_preview := _find_drag_preview_node()
	if drag_preview:
		_process_drag_frame(camera, delta, drag_preview)
		return

	if _is_ui_text_focus_locked():
		_finish_drag(true)
		_flush_undo_if_due()
		return

	_process_pickup_keys()

	if Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		# Right mouse button is reserved for camera navigation
		_flush_undo_if_due()
		return

	_finish_drag(true)

	if not _pickup_active:
		_flush_undo_if_due()
		return

	var nodes := _get_selected_node3d()
	if nodes.is_empty():
		# The carried selection is gone (deselected, deleted, scene switch)
		_set_pickup_active(false)
		_flush_undo_if_due()
		return

	_flush_undo_if_selection_changed(nodes)

	var changed := false
	changed = _apply_rotation(nodes) or changed
	changed = _apply_pickup_movement(camera) or changed
	changed = _apply_scale(nodes) or changed
	changed = _snap_pickup_to_floor(nodes) or changed
	changed = _follow_mouse(nodes, camera) or changed

	if changed:
		_last_change_ms = float(Time.get_ticks_msec())
	else:
		_flush_undo_if_due()


func abort_session() -> void:
	"""Abort an active pickup session (plugin teardown): restore transformed
	nodes, remove fresh duplicates, and commit any pending undo batch."""
	if _pickup_active:
		_reset_pickup_transforms()
	flush_undo()


func flush_undo() -> void:
	"""Commit pending inline transforms as a single undoable editor action."""
	if _pending_undo.is_empty():
		_last_change_ms = -1.0
		return

	if not undo_redo:
		_pending_undo.clear()
		_last_change_ms = -1.0
		return

	undo_redo.create_action(UNDO_ACTION_NAME)
	var applied := 0
	for entry in _pending_undo.values():
		var node = entry["node"]
		if not is_instance_valid(node) or not node.is_inside_tree():
			continue
		var current: Transform3D = node.global_transform
		if current.is_equal_approx(entry["original"]):
			continue
		undo_redo.add_do_property(node, "global_transform", current)
		undo_redo.add_undo_property(node, "global_transform", entry["original"])
		applied += 1

	if applied > 0:
		undo_redo.commit_action()

	_pending_undo.clear()
	_last_change_ms = -1.0


## Pick-Up Gating (transforms on scene nodes require an explicit pickup)


func _process_pickup_keys() -> void:
	for action in ["pickup", "confirm", "reset", "duplicate"]:
		var held := TransformKeybinds.is_action_pressed(action)
		var was_held: bool = _toggle_keys_held.get(action, false)
		_toggle_keys_held[action] = held
		if not held or was_held:
			continue
		match action:
			"pickup":
				_set_pickup_active(not _pickup_active)
			"confirm":
				_set_pickup_active(false)
			"reset":
				_reset_pickup_transforms()
			"duplicate":
				_quick_duplicate()
	_process_pickup_mouse_buttons()


func _process_pickup_mouse_buttons() -> void:
	# LMB confirms the pickup, RMB cancels it (reset + drop). Edges are tracked
	# always so a button already held when the pickup starts never misfires.
	var viewport := _get_viewport_3d()
	var mouse_in_view: bool = viewport != null and _is_mouse_in_viewport(viewport)
	if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		# The button went up without a release event reaching us (e.g. focus
		# lost mid-click); stop reserving the next release.
		_lmb_release_pending = false
	for entry in [[MOUSE_BUTTON_LEFT, true], [MOUSE_BUTTON_RIGHT, false]]:
		var button: int = entry[0]
		var held := Input.is_mouse_button_pressed(button)
		var was_held: bool = _pickup_mouse_held.get(button, false)
		_pickup_mouse_held[button] = held
		if not held or was_held or not _pickup_active or not mouse_in_view:
			continue
		if entry[1]:
			_set_pickup_active(false)
		else:
			_reset_pickup_transforms()


func _set_pickup_active(active: bool) -> void:
	if active == _pickup_active:
		return
	_pickup_active = active
	if active:
		_pickup_offset = Vector3.ZERO
		_pickup_anchor = _get_group_pivot(_get_selected_node3d())
		_pickup_cancelled = false
	else:
		# Fresh duplicates are committed as one undoable action on
		# confirm/auto-drop; an explicit cancel (reset key / RMB) removes
		# them entirely.
		_end_duplicate_session(not _pickup_cancelled)
		_pickup_cancelled = false
	_floor_lock_y = null
	# Each pickup session is its own undoable unit.
	flush_undo()


func _reset_pickup_transforms() -> void:
	"""Restore every node touched in this pickup session, then drop the pickup.
	While placing fresh duplicates the cancel removes them entirely."""
	if _pickup_active:
		_pickup_cancelled = true
	for entry in _pending_undo.values():
		var node = entry["node"]
		if is_instance_valid(node) and node.is_inside_tree():
			node.global_transform = entry["original"]
	# flush_undo() skips entries whose transform equals the original again.
	_set_pickup_active(false)


func get_pickup_status() -> String:
	"""One-line dock hint describing the active pickup session ("" if none)."""
	if not _pickup_active:
		return ""
	var nodes := _get_selected_node3d()
	if nodes.is_empty():
		return ""
	var names := PackedStringArray()
	for node in nodes:
		names.append(String(node.name))
	var confirm := "%s/%s/%s" % [
		TransformKeybinds.get_action_label("pickup"),
		TransformKeybinds.get_action_label("confirm"),
		"LMB",
	]
	var floor_hint := TransformKeybinds.get_action_label("snap_to_floor")
	if not _dup_copies.is_empty():
		return "Placing duplicates: %s  (%s confirm - %s/%s removes - %s floor)" % [
			", ".join(names),
			confirm,
			TransformKeybinds.get_action_label("reset"),
			"RMB",
			floor_hint,
		]
	return "Transforming: %s  (%s confirm - %s/%s reset - %s floor)" % [
		", ".join(names),
		confirm,
		TransformKeybinds.get_action_label("reset"),
		"RMB",
		floor_hint,
	]


## Quick Duplicate (Stamp)


func _quick_duplicate() -> void:
	"""Duplicate the selected nodes and pick the copies up for placement."""
	if _pickup_active:
		return
	var viewport := _get_viewport_3d()
	if not viewport or not _is_mouse_in_viewport(viewport):
		return
	var nodes := _get_selected_node3d()
	if nodes.is_empty():
		return
	# Close any pending transform batch so the stamp starts clean.
	flush_undo()
	var editor_root := EditorInterface.get_edited_scene_root()
	var copies: Array[Node3D] = []
	for node in nodes:
		if not is_instance_valid(node) or not node.is_inside_tree():
			continue
		var parent: Node = node.get_parent()
		if parent == null:
			continue
		var copy := node.duplicate() as Node3D
		if copy == null:
			continue
		copy.name = _unique_child_name(parent, String(node.name))
		parent.add_child(copy)
		copy.global_transform = node.global_transform
		if editor_root:
			copy.owner = editor_root
		copies.append(copy)
	if copies.is_empty():
		return
	var selection := EditorInterface.get_selection()
	if selection:
		selection.clear()
		for copy in copies:
			selection.add_node(copy)
	_dup_copies = copies
	_set_pickup_active(true)


func _unique_child_name(parent: Node, base_name: String) -> String:
	var name := base_name
	var suffix := 2
	while parent.has_node(name):
		name = "%s%d" % [base_name, suffix]
		suffix += 1
	return name


func _end_duplicate_session(commit: bool) -> void:
	if _dup_copies.is_empty():
		return
	var copies := _dup_copies
	_dup_copies = []
	if commit:
		_commit_duplicate_action(copies)
		return
	var selection := EditorInterface.get_selection()
	if selection:
		selection.clear()
	for copy in copies:
		if not is_instance_valid(copy):
			continue
		var parent := copy.get_parent()
		if parent:
			parent.remove_child(copy)
		copy.queue_free()


func _commit_duplicate_action(copies: Array[Node3D]) -> void:
	"""Record the already-applied duplicate creation as one undoable action."""
	if not undo_redo:
		return
	var editor_root := EditorInterface.get_edited_scene_root()
	var valid: Array[Node3D] = []
	for copy in copies:
		if is_instance_valid(copy) and copy.get_parent() != null:
			valid.append(copy)
	if valid.is_empty():
		return
	undo_redo.create_action("Quick Duplicate Selection")
	for copy in valid:
		undo_redo.add_do_method(copy.get_parent(), "add_child", copy)
		if editor_root:
			undo_redo.add_do_method(copy, "set_owner", editor_root)
		undo_redo.add_do_reference(copy)
		undo_redo.add_undo_method(copy.get_parent(), "remove_child", copy)
	# The changes were already applied when the copies were created.
	undo_redo.commit_action(false)


## Pick-Up Mouse Follow


func _follow_mouse(nodes: Array, camera: Camera3D) -> bool:
	"""Keep the picked selection under the cursor, like a drag preview."""
	var viewport := _get_viewport_3d()
	if not viewport or not _is_mouse_in_viewport(viewport):
		return false
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) or Input.is_mouse_button_pressed(MOUSE_BUTTON_MIDDLE):
		# LMB may drag an editor gizmo and MMB navigates - let the editor win.
		return false

	var pivot := _get_group_pivot(nodes)
	var target: Variant = _get_follow_target(nodes, camera, pivot)
	if target == null:
		return false

	# The follow target is already snapped to the editor's translate grid
	# (before the surface lift); movement-key nudges accumulate as a
	# world-space offset on top of it so they survive follow updates.
	var shift: Vector3 = (target as Vector3) + _pickup_offset - pivot
	if _floor_lock_y != null:
		# Snap-to-floor lock: keep XZ following, pin the height.
		shift.y = _floor_lock_y - pivot.y
	if shift.is_zero_approx():
		return false
	for node in nodes:
		_translate_node(node, shift)
	return true


func _snap_point(point: Vector3) -> Vector3:
	"""Quantize a placement point to the configured translate snap increment."""
	var increment := _get_follow_snap()
	if increment <= 0.0:
		return point
	# Round to the nearest grid multiple per axis (the editor's snapf math).
	return Vector3(
		roundf(point.x / increment) * increment,
		roundf(point.y / increment) * increment,
		roundf(point.z / increment) * increment,
	)


func _get_follow_snap() -> float:
	"""Translate snap for the mouse-follow placement. 0 = disabled.
	The setting mirrors the editor's snap: 0 follows the editor's translate
	snap increment and its Use Snap toolbar toggle (holding Ctrl inverts the
	toggle, like gizmo dragging), a positive value fixes one, a negative
	value disables snapping. The fine modifier gives 1/10 steps, like the
	move gizmo."""
	var configured := TransformKeybinds.get_number("snap_increment")
	var increment := 0.0
	if configured > 0.0:
		increment = configured
	elif configured == 0.0:
		if not _is_editor_snap_enabled():
			return 0.0
		var settings := EditorInterface.get_editor_settings()
		# The editor's Snap menu writes its translate increment here live.
		if settings and settings.has_method("get_project_metadata"):
			increment = settings.get_project_metadata("3d_editor", "snap_translate_value", 1.0)
	if increment <= 0.0:
		return 0.0
	if TransformKeybinds.is_fine_modifier_held():
		increment *= FINE_MULTIPLIER
	return increment


## Editor Snap Toggle


func _is_editor_snap_enabled() -> bool:
	"""Mirror the 3D editor toolbar's Use Snap toggle: pressed XOR Ctrl."""
	var button := _get_snap_toggle()
	if not button:
		return true
	return button.button_pressed != Input.is_key_pressed(KEY_CTRL)


func _get_snap_toggle() -> Button:
	"""The spatial editor toolbar's Use Snap toggle (cached; null if absent)."""
	if _snap_toggle != null and is_instance_valid(_snap_toggle):
		return _snap_toggle
	_snap_toggle = null
	var base := EditorInterface.get_base_control()
	if not base:
		return null
	var editor := _find_by_class(base, "Node3DEditor")
	if not editor:
		return null
	var snap_icon: Texture2D = base.get_theme_icon("Snap", "EditorIcons")
	_snap_toggle = _find_snap_button(editor, snap_icon)
	return _snap_toggle


func _find_by_class(node: Node, cls: String) -> Node:
	if node.get_class() == cls:
		return node
	for child in node.get_children():
		var found := _find_by_class(child, cls)
		if found:
			return found
	return null


func _find_snap_button(node: Node, snap_icon: Texture2D) -> Button:
	"""Match the toggle by snap shortcut, tooltip or icon (language-proof)."""
	var button := node as BaseButton
	if button and button.toggle_mode:
		var key_match := false
		if button.shortcut:
			for event in button.shortcut.events:
				key_match = key_match or (event is InputEventKey \
						and not event.ctrl_pressed and not event.alt_pressed \
						and not event.shift_pressed \
						and (event.keycode == KEY_Y or event.physical_keycode == KEY_Y))
		var acc: Variant = button.get("accessibility_name")
		var label_match: bool = button.tooltip_text.contains("Use Snap") \
				or (acc is String and acc.contains("Use Snap"))
		var icon_match: bool = snap_icon != null and button.icon == snap_icon
		if key_match or label_match or icon_match:
			return button
	for child in node.get_children():
		var found := _find_snap_button(child, snap_icon)
		if found:
			return found
	return null


func _get_group_pivot(nodes: Array) -> Vector3:
	var pivot := Vector3.ZERO
	for node in nodes:
		pivot += node.global_position
	return pivot / nodes.size()


func _get_follow_target(nodes: Array, camera: Camera3D, pivot: Vector3) -> Variant:
	"""Snapped point under the cursor: a physics surface hit (drag/drop-like
	placement including the bounds-on-surface lift), else the camera-facing
	plane through the pickup-time pivot. The surface contact snaps BEFORE
	the bounds lift so resting height stays exact - snapping the lifted
	point rounds it onto the grid and sinks/rests nodes incorrectly.
	Ray hits on the carried nodes' own collision (e.g. a CSG shape's internal
	use_collision body) are skipped by excluding that body and re-casting."""
	var viewport := _get_viewport_3d()
	if not viewport:
		return null
	var mouse := viewport.get_mouse_position()
	var origin := camera.project_ray_origin(mouse)
	var dir := camera.project_ray_normal(mouse)
	if dir == Vector3.ZERO:
		return null

	var space := _get_physics_space(nodes, viewport)
	if space:
		var params := PhysicsRayQueryParameters3D.create(origin, origin + dir * camera.far)
		var rids := _get_pickup_rids(nodes)
		if not rids.is_empty():
			params.exclude = rids
		var hit := _cast_first_surface(space, params, nodes)
		if not hit.is_empty():
			var normal: Vector3 = hit["normal"]
			var contact: Vector3 = _snap_point(hit["position"])
			return contact + normal * _get_group_surface_lift(nodes, pivot, normal)

	var plane := Plane(camera.global_transform.basis.z, _pickup_anchor)
	var point: Variant = plane.intersects_ray(origin, dir)
	if point == null:
		return null
	return _snap_point(point as Vector3)


func _get_physics_space(nodes: Array, viewport: Viewport) -> PhysicsDirectSpaceState3D:
	"""The physics space the picked nodes live in (== the edited scene's world)."""
	for node in nodes:
		if node is Node3D and node.is_inside_tree():
			return node.get_world_3d().direct_space_state
	if viewport.get_world_3d():
		return viewport.get_world_3d().direct_space_state
	return null


func _get_pickup_rids(nodes: Array) -> Array[RID]:
	var rids: Array[RID] = []
	for node in nodes:
		_collect_collision_rids(node, rids)
	return rids


func _collect_collision_rids(node: Node, rids: Array[RID]) -> void:
	if node is CollisionObject3D:
		rids.append(node.get_rid())
	for child in node.get_children(true):
		_collect_collision_rids(child, rids)


func _is_in_pickup(node: Node, nodes: Array) -> bool:
	var current: Node = node
	while current:
		if nodes.has(current):
			return true
		current = current.get_parent()
	return false


func _cast_first_surface(space: PhysicsDirectSpaceState3D, params: PhysicsRayQueryParameters3D, nodes: Array) -> Dictionary:
	"""First ray hit that is not the carried nodes' own collision (re-casts
	past bodies that cannot be pre-collected, e.g. CSG use_collision bodies).
	Empty when only self-hits are found or the ray misses."""
	for _attempt in 8:
		var hit: Dictionary = space.intersect_ray(params)
		if hit.is_empty():
			return {}
		var collider: Variant = hit.get("collider")
		if collider is Node and _is_in_pickup(collider, nodes):
			var rid: RID = hit["rid"]
			if rid == RID() or params.exclude.has(rid):
				return {}
			params.exclude.append(rid)
			continue
		return hit
	return {}


func _get_group_surface_lift(nodes: Array, pivot: Vector3, normal: Vector3) -> float:
	"""Offset along the surface normal so the group's bounds rest on the surface."""
	var state := [INF]
	for node in nodes:
		_accumulate_bounds_min_proj(node, pivot, normal, state)
	if state[0] == INF:
		return 0.0
	return -state[0]


func _accumulate_bounds_min_proj(node: Node, pivot: Vector3, normal: Vector3, state: Array) -> void:
	if node is VisualInstance3D:
		var xf: Transform3D = node.global_transform
		var aabb: AABB = node.get_aabb()
		for i in 8:
			var proj := normal.dot(xf * aabb.get_endpoint(i) - pivot)
			if proj < state[0]:
				state[0] = proj
	for child in node.get_children():
		_accumulate_bounds_min_proj(child, pivot, normal, state)


func _snap_pickup_to_floor(nodes: Array) -> bool:
	"""Page Down while carrying: drop the selection onto the surface directly
	below it (self-collision skipped) and lock the follow height there, so the
	next follow update cannot override the floor snap. Height keys (Q/E) or a
	new pickup release the lock; re-pressing re-snaps under the position."""
	if not _stepped_pressed("snap_to_floor"):
		return false
	var viewport := _get_viewport_3d()
	if not viewport:
		return false
	var space := _get_physics_space(nodes, viewport)
	if not space:
		return false
	var pivot := _get_group_pivot(nodes)
	var params := PhysicsRayQueryParameters3D.create(
			pivot + Vector3.UP * FLOOR_CAST_RANGE,
			pivot + Vector3.DOWN * FLOOR_CAST_RANGE)
	var rids := _get_pickup_rids(nodes)
	if not rids.is_empty():
		params.exclude = rids
	var hit := _cast_first_surface(space, params, nodes)
	if hit.is_empty():
		return false
	var lift := _get_group_surface_lift(nodes, pivot, Vector3.UP)
	var shift := (hit["position"] as Vector3) + Vector3.UP * lift - pivot
	for node in nodes:
		_translate_node(node, shift)
	_floor_lock_y = pivot.y + shift.y
	# Accumulated height nudges no longer apply from the floor-snapped base.
	_pickup_offset.y = 0.0
	return true


## Input Application


func _apply_rotation(nodes: Array) -> bool:
	var x_stepped := _stepped_pressed("rotate_x")
	var y_stepped := _stepped_pressed("rotate_y")
	var z_stepped := _stepped_pressed("rotate_z")
	if not (x_stepped or y_stepped or z_stepped):
		return false

	var step: float = TransformKeybinds.get_number("rotation_step_degrees")
	if TransformKeybinds.is_fine_modifier_held():
		step *= FINE_MULTIPLIER
	elif TransformKeybinds.is_large_modifier_held():
		step *= LARGE_MULTIPLIER
	if TransformKeybinds.is_reverse_modifier_held():
		step = -step

	if x_stepped:
		for node in nodes:
			_rotate_node(node, "x", step)
	if y_stepped:
		for node in nodes:
			_rotate_node(node, "y", step)
	if z_stepped:
		for node in nodes:
			_rotate_node(node, "z", step)
	return true


func _apply_pickup_movement(camera: Camera3D) -> bool:
	"""Move keys step the follow-target offset (hold to repeat)."""
	var move := _read_move_step(camera)
	if move == Vector3.ZERO:
		return false

	var step: float = TransformKeybinds.get_number("move_step")
	if TransformKeybinds.is_fine_modifier_held():
		step *= FINE_MULTIPLIER
	elif TransformKeybinds.is_large_modifier_held():
		step *= LARGE_MULTIPLIER

	_pickup_offset += move.normalized() * step
	if move.y != 0.0:
		# Height steps release the snap-to-floor lock.
		_floor_lock_y = null
	return true


func _read_move_step(camera: Camera3D) -> Vector3:
	var move := Vector3.ZERO
	if _stepped_pressed("move_forward"):
		move += _camera_forward_snapped(camera)
	if _stepped_pressed("move_back"):
		move -= _camera_forward_snapped(camera)
	if _stepped_pressed("move_right"):
		move += _camera_right_snapped(camera)
	if _stepped_pressed("move_left"):
		move -= _camera_right_snapped(camera)
	if _stepped_pressed("height_up"):
		move += Vector3.UP
	if _stepped_pressed("height_down"):
		move -= Vector3.UP
	return move


func _apply_scale(nodes: Array) -> bool:
	var up_stepped := _stepped_pressed("scale_up")
	var down_stepped := _stepped_pressed("scale_down")
	if not (up_stepped or down_stepped):
		return false

	var step: float = TransformKeybinds.get_number("scale_step_factor")
	if TransformKeybinds.is_fine_modifier_held():
		step *= FINE_MULTIPLIER
	elif TransformKeybinds.is_large_modifier_held():
		step *= LARGE_MULTIPLIER
	if TransformKeybinds.is_reverse_modifier_held() or down_stepped:
		step = -step

	var factor := 1.0 + step
	for node in nodes:
		_scale_node(node, factor)
	return true


func _rotate_node(node: Node3D, axis: String, step: float) -> void:
	_capture_undo(node)
	# World-space rotation so steps stay predictable on pre-rotated nodes.
	match axis:
		"x":
			node.global_rotate(Vector3.RIGHT, deg_to_rad(step))
		"y":
			node.global_rotate(Vector3.UP, deg_to_rad(step))
		"z":
			node.global_rotate(Vector3.BACK, deg_to_rad(step))


func _translate_node(node: Node3D, offset: Vector3) -> void:
	_capture_undo(node)
	node.global_position += offset


func _scale_node(node: Node3D, factor: float) -> void:
	_capture_undo(node)
	var new_scale: Vector3 = node.scale * factor
	new_scale.x = maxf(new_scale.x, MIN_SCALE)
	new_scale.y = maxf(new_scale.y, MIN_SCALE)
	new_scale.z = maxf(new_scale.z, MIN_SCALE)
	node.scale = new_scale


## Drag Preview Transforming (file dragged from the browser into the viewport)


func _get_gui_viewport() -> Viewport:
	"""Editor window viewport that owns the native drag-and-drop state."""
	var base_control := EditorInterface.get_base_control()
	if not base_control:
		return null
	return base_control.get_viewport()


func _find_drag_preview_node() -> Node3D:
	"""Locate the editor's transient drag preview root, if a file drag is active.

	The 3D editor adds an unnamed Node3D preview root to the editor's scene
	host viewport (EditorNode::scene_root, a SubViewport - reachable as the
	edited scene root's viewport) while dragging "files" payload over the
	viewport; owner == null keeps it outside the saved scene. Prefer a root
	that holds an instantiated copy of one of the dragged files; fall back to
	the first unowned Node3D that is not the edited scene root itself.
	"""
	var gui := _get_gui_viewport()
	if not gui or not gui.gui_is_dragging():
		return null
	var data: Variant = gui.gui_get_drag_data()
	if typeof(data) != TYPE_DICTIONARY:
		return null
	if String(data.get("type", "")) != "files":
		return null
	var files: Array = data.get("files", [])
	if files.is_empty():
		return null

	var scene_root := EditorInterface.get_edited_scene_root()
	if not scene_root:
		return null

	# The preview root lives next to the edited scene, under the editor's
	# scene host viewport - not under the edited scene root node.
	var host := scene_root.get_viewport()
	if not host:
		return null

	var dragged := {}
	for file in files:
		dragged[String(file)] = true
	var fallback: Node3D = null
	for child in host.get_children():
		if not (child is Node3D) or child == scene_root or child.get_owner() != null:
			continue
		for sub in child.get_children():
			if dragged.has(String(sub.scene_file_path)):
				return child
		if not fallback:
			fallback = child
	return fallback


func _process_drag_frame(camera: Camera3D, delta: float, preview: Node3D) -> void:
	if not _drag_active:
		_begin_drag()

	if not preview.is_visible():
		return

	# The editor rewrites the preview position on mouse motion; any change
	# against what we last wrote is an editor-owned base position update.
	var editor_pos := preview.global_position
	if editor_pos != _drag_last_written_pos:
		_drag_base = editor_pos

	var moved := _accumulate_drag_movement(camera)
	var rotated := _accumulate_drag_rotation()
	var scaled := _accumulate_drag_scale()
	if moved or rotated or scaled:
		_drag_modified = true

	preview.global_transform = Transform3D(
		_drag_basis.scaled(Vector3.ONE * _drag_scale), _drag_base + _drag_offset
	)
	_drag_last_written_pos = _drag_base + _drag_offset


func _begin_drag() -> void:
	_drag_active = true
	_drag_modified = false
	_drag_offset = Vector3.ZERO
	_drag_basis = Basis()
	_drag_scale = 1.0
	_drag_last_written_pos = Vector3.INF
	_drag_selection_ids = []
	if _pickup_active:
		_set_pickup_active(false)
	for node in _get_selected_node3d():
		_drag_selection_ids.append(node.get_instance_id())


func _finish_drag(allow_transfer: bool) -> void:
	if not _drag_active:
		return
	_drag_active = false
	if not allow_transfer or not _drag_modified:
		return

	# Only nodes instantiated by the drop (selection delta) receive the
	# preview transform; the drop position stays editor-computed.
	var scale_basis := Basis.from_scale(Vector3.ONE * _drag_scale)
	for node in _get_selected_node3d():
		if _drag_selection_ids.has(node.get_instance_id()):
			continue
		var xf: Transform3D = node.global_transform
		xf.basis = scale_basis * _drag_basis * xf.basis
		node.global_transform = xf
		node.global_position += _drag_offset


func _accumulate_drag_movement(camera: Camera3D) -> bool:
	var move := _read_move_step(camera)
	if move == Vector3.ZERO:
		return false
	var step: float = TransformKeybinds.get_number("move_step")
	if TransformKeybinds.is_fine_modifier_held():
		step *= FINE_MULTIPLIER
	elif TransformKeybinds.is_large_modifier_held():
		step *= LARGE_MULTIPLIER
	_drag_offset += move.normalized() * step
	return true


func _accumulate_drag_rotation() -> bool:
	var x_stepped := _stepped_pressed("rotate_x")
	var y_stepped := _stepped_pressed("rotate_y")
	var z_stepped := _stepped_pressed("rotate_z")
	if not (x_stepped or y_stepped or z_stepped):
		return false

	var step: float = TransformKeybinds.get_number("rotation_step_degrees")
	if TransformKeybinds.is_fine_modifier_held():
		step *= FINE_MULTIPLIER
	elif TransformKeybinds.is_large_modifier_held():
		step *= LARGE_MULTIPLIER
	if TransformKeybinds.is_reverse_modifier_held():
		step = -step

	if x_stepped:
		_drag_basis = Basis(Vector3.RIGHT, deg_to_rad(step)) * _drag_basis
	if y_stepped:
		_drag_basis = Basis(Vector3.UP, deg_to_rad(step)) * _drag_basis
	if z_stepped:
		_drag_basis = Basis(Vector3.BACK, deg_to_rad(step)) * _drag_basis
	return true


func _accumulate_drag_scale() -> bool:
	var up_stepped := _stepped_pressed("scale_up")
	var down_stepped := _stepped_pressed("scale_down")
	if not (up_stepped or down_stepped):
		return false

	var step: float = TransformKeybinds.get_number("scale_step_factor")
	if TransformKeybinds.is_fine_modifier_held():
		step *= FINE_MULTIPLIER
	elif TransformKeybinds.is_large_modifier_held():
		step *= LARGE_MULTIPLIER
	if TransformKeybinds.is_reverse_modifier_held() or down_stepped:
		step = -step

	_drag_scale = maxf(_drag_scale * (1.0 + step), MIN_SCALE)
	return true


## Stepped Input (press edge + hold-repeat cadence)


func _stepped_pressed(action: String) -> bool:
	var held := TransformKeybinds.is_action_pressed(action)
	var was_held: bool = _held_actions.get(action, false)
	_held_actions[action] = held

	var now := float(Time.get_ticks_msec())
	if held and not was_held:
		_next_repeat_ms[action] = now + ROTATE_FIRST_REPEAT_MS
		return true
	if held and now >= float(_next_repeat_ms.get(action, 0.0)):
		_next_repeat_ms[action] = now + ROTATE_REPEAT_MS
		return true
	return false


## Camera-Relative Directions (camera-snapped to XZ axes)


func _camera_forward_snapped(camera: Camera3D) -> Vector3:
	var forward := -camera.global_transform.basis.z
	forward.y = 0.0
	if forward.length_squared() > 0.01:
		forward = forward.normalized()
		if absf(forward.z) > absf(forward.x):
			return Vector3(0.0, 0.0, signf(forward.z))
		return Vector3(signf(forward.x), 0.0, 0.0)
	return Vector3.FORWARD


func _camera_right_snapped(camera: Camera3D) -> Vector3:
	var right := camera.global_transform.basis.x
	right.y = 0.0
	if right.length_squared() > 0.01:
		right = right.normalized()
		if absf(right.x) > absf(right.z):
			return Vector3(signf(right.x), 0.0, 0.0)
		return Vector3(0.0, 0.0, signf(right.z))
	return Vector3.RIGHT


## Key Event Consumption (keeps editor shortcuts like tool switching from firing)


func should_consume_key(event: InputEvent) -> bool:
	"""True when a transform key press should be swallowed by the editor.

	Mirror of the process() guards so keys are only swallowed while transforms
	can actually run: during a file drag, during an active pickup (transform,
	confirm and reset keys), or for the pickup key itself while a Node3D
	selection exists. Includes the plugin's own modifier combos (CTRL for fine
	steps, ALT for large steps) so editor shortcuts like Ctrl+S or Ctrl+X
	cannot fire at the same time.
	"""
	if not (event is InputEventKey):
		return false
	if event.echo or not event.pressed:
		return false
	# CTRL (fine step) and ALT (large step) are the plugin's own transform
	# modifiers, so combos with them are owned by the plugin too. SHIFT and
	# META stay with the editor.
	if event.meta_pressed or event.shift_pressed:
		return false
	var viewport := _get_viewport_3d()
	if not viewport or not _is_mouse_in_viewport(viewport):
		return false
	if _is_ui_text_focus_locked():
		return false
	# Logical keycodes match keycap labels on every layout; physical codes are
	# US-QWERTY positions and swap Y/Z on QWERTZ keyboards.
	var key: Key = event.keycode
	if key == KEY_NONE:
		key = event.physical_keycode
	# The pickup key is swallowed while a Node3D selection exists so the
	# toggle stays clean (it has no other default use over the viewport).
	var pickup_key := TransformKeybinds.get_action_key("pickup")
	if pickup_key != KEY_NONE and key == pickup_key:
		return not _get_selected_node3d().is_empty()
	# The duplicate key starts a quick-duplicate stamp: it belongs to the
	# plugin while a Node3D selection exists and no pickup is running.
	var duplicate_key := TransformKeybinds.get_action_key("duplicate")
	if duplicate_key != KEY_NONE and key == duplicate_key:
		return not _pickup_active and not _get_selected_node3d().is_empty()
	# Confirm/reset keys only belong to the plugin while a pickup is active.
	var confirm_key := TransformKeybinds.get_action_key("confirm")
	var reset_key := TransformKeybinds.get_action_key("reset")
	if (confirm_key != KEY_NONE and key == confirm_key) or (reset_key != KEY_NONE and key == reset_key):
		return _pickup_active
	# Snap-to-floor belongs to the plugin while a pickup is active: it drops
	# the carried selection and locks the follow height (the editor's own
	# Snap to Floor would be overridden by the next follow update anyway).
	var floor_key := TransformKeybinds.get_action_key("snap_to_floor")
	if floor_key != KEY_NONE and key == floor_key:
		return _pickup_active
	# Plain transform keys only apply to an active pickup session or a drag.
	if not _pickup_active and not _find_drag_preview_node():
		return false
	return TransformKeybinds.matches_transform_key(key)


func should_consume_mouse(event: InputEvent) -> bool:
	"""Consume the confirm click's LMB press and its matching release while a
	pickup is active. The plugin's forward-3d stop alone is not enough: the
	editor's internal click handling in _sinput can run before the plugin's
	forward call, and its release-time click-select would override the
	plugin's post-confirm selection. The plugin consumes this at the editor's
	root input stage, where handled events never reach _sinput."""
	if not (event is InputEventMouseButton):
		return false
	var mouse := event as InputEventMouseButton
	if mouse.button_index != MOUSE_BUTTON_LEFT:
		return false
	if mouse.pressed:
		if not _pickup_active:
			return false
		# Only clicks over the 3D viewport are owned by the plugin; clicks
		# elsewhere (docks, dialogs) keep working mid-session.
		var viewport := _get_viewport_3d()
		if not viewport or not _is_mouse_in_viewport(viewport):
			return false
		# The confirm fires between press and release (frame-polled), so the
		# release arrives after the session ended and must still be swallowed.
		_lmb_release_pending = true
		return true
	if _lmb_release_pending:
		_lmb_release_pending = false
		return true
	return false


## Guards


func _get_viewport_3d() -> Viewport:
	return EditorInterface.get_editor_viewport_3d(0)


func _is_mouse_in_viewport(viewport: Viewport) -> bool:
	return viewport.get_visible_rect().has_point(viewport.get_mouse_position())


func _is_ui_text_focus_locked() -> bool:
	var base_control := EditorInterface.get_base_control()
	if not base_control:
		return false
	var focus_owner: Control = base_control.get_viewport().gui_get_focus_owner()
	if not focus_owner:
		return false
	return (
		focus_owner is LineEdit
		or focus_owner is TextEdit
		or focus_owner is CodeEdit
		or focus_owner.get_class() == "SpinBox"
	)


func _get_selected_node3d() -> Array:
	var selection := EditorInterface.get_selection()
	if not selection:
		return []
	var nodes := []
	for node in selection.get_selected_nodes():
		if node is Node3D and is_instance_valid(node):
			nodes.append(node)
	return nodes


## Selection Tracking


func _flush_undo_if_selection_changed(nodes: Array) -> void:
	var ids := []
	for node in nodes:
		ids.append(node.get_instance_id())
	if ids != _last_selection_ids:
		flush_undo()
	_last_selection_ids = ids


## Undo Batching


func _capture_undo(node: Node3D) -> void:
	var id := node.get_instance_id()
	if not _pending_undo.has(id):
		_pending_undo[id] = {"node": node, "original": node.global_transform}


func _flush_undo_if_due() -> void:
	if _pending_undo.is_empty():
		return
	var now := float(Time.get_ticks_msec())
	if _last_change_ms < 0.0 or (now - _last_change_ms) >= UNDO_DEBOUNCE_MS:
		flush_undo()
@tool
extends EditorPlugin

"""
PLUGIN ENTRY - SIMPLE ASSET PLACER 3
====================================

PURPOSE: Wire the two 3.0 features into the editor.

RESPONSIBILITIES:
- Register/resolve Editor Settings keybinds, refreshing on settings change
- Drive InlineTransformEngine every frame with the active 3D viewport camera
- Install the AssetBrowserDock in the right dock area (next to Inspector)
- Flush pending inline-transform undo actions on teardown
- Swallow owned transform keys and the confirm click at the root input and
  shortcut input stages so editor shortcuts (save, cut, undo, select all,
  tool switching) and the release-time click-select cannot fire during
  transforms
"""

var _engine: InlineTransformEngine
var _dock: AssetBrowserDock
var _editor_settings: EditorSettings
var _last_pickup_hint := ""


func _enter_tree() -> void:
	_cleanup_legacy_settings()
	TransformKeybinds.register_defaults()
	TransformKeybinds.resolve_keys()
	_editor_settings = EditorInterface.get_editor_settings()
	if _editor_settings:
		_editor_settings.settings_changed.connect(_on_editor_settings_changed)
	_engine = InlineTransformEngine.new()
	_dock = AssetBrowserDock.new()
	_engine.undo_redo = get_undo_redo()
	_dock.undo_redo = get_undo_redo()
	add_control_to_dock(DOCK_SLOT_RIGHT_UL, _dock)


func _process(delta: float) -> void:
	var viewport := EditorInterface.get_editor_viewport_3d(0)
	var camera: Camera3D = null
	if viewport:
		camera = viewport.get_camera_3d()
	_engine.process(camera, delta)
	_update_pickup_hint()


func _update_pickup_hint() -> void:
	var hint := _engine.get_pickup_status()
	if hint == _last_pickup_hint:
		return
	_last_pickup_hint = hint
	_dock.set_transform_hint(hint)


func _forward_3d_gui_input(viewport_camera: Camera3D, event: InputEvent) -> int:
	if not _engine:
		return EditorPlugin.AFTER_GUI_INPUT_PASS
	# LMB confirms the pickup: the press and its release are both consumed so
	# the click never reaches the editor's click-select (which selects the
	# node under the cursor on release). RMB stays unconsumed so camera
	# orbit still works right after a cancel.
	if _engine.should_consume_mouse(event):
		return EditorPlugin.AFTER_GUI_INPUT_STOP
	if _engine.should_consume_key(event):
		return EditorPlugin.AFTER_GUI_INPUT_STOP
	return EditorPlugin.AFTER_GUI_INPUT_PASS


func _input(event: InputEvent) -> void:
	if _engine == null:
		return
	if event is InputEventKey:
		# The forward-3d stop does not reach the editor's shortcut stage, so
		# consumed keys would still trigger editor shortcuts (Ctrl+S saves,
		# Ctrl+X cuts). Swallow owned keys at the root input stage, before
		# the gui and shortcut stages run. Guarding lives in should_consume_key.
		_swallow_owned_key(event)
	elif event is InputEventMouseButton:
		# The confirm click is swallowed at the root stage too: the editor's
		# internal click handling in _sinput can run before the plugin's
		# forward stop, and its release-time click-select would override the
		# plugin's post-confirm selection.
		_swallow_confirm_click(event)


func _shortcut_input(event: InputEvent) -> void:
	# Second net after the gui stage: still fires for keys the forward stop
	# let through, before the editor's shortcut/unhandled stages.
	if _engine == null or not (event is InputEventKey):
		return
	_swallow_owned_key(event)


func _swallow_owned_key(event: InputEvent) -> void:
	if _engine.should_consume_key(event):
		get_viewport().set_input_as_handled()


func _swallow_confirm_click(event: InputEvent) -> void:
	if _engine.should_consume_mouse(event):
		get_viewport().set_input_as_handled()


func _exit_tree() -> void:
	_engine.abort_session()
	if _editor_settings:
		_editor_settings.settings_changed.disconnect(_on_editor_settings_changed)
	remove_control_from_docks(_dock)
	_dock.queue_free()


func _on_editor_settings_changed() -> void:
	TransformKeybinds.resolve_keys()


## Removes settings left behind by the removed 2.x addon and pre-release 3.0
## builds (e.g. the old "simpleassetplacer/" prefix and 2.x categories/ui/
## browser entries). 3.0's own keybind and value settings are kept.
## Runs once per project, tracked in the project's editor metadata.
func _cleanup_legacy_settings() -> void:
	var editor_settings := EditorInterface.get_editor_settings()
	if not editor_settings:
		return
	if editor_settings.get_project_metadata(TransformKeybinds.SETTINGS_PREFIX, "stale_settings_cleaned", false):
		return
	var keep := {}
	for action in TransformKeybinds.KEY_DEFAULTS:
		keep["%s/%s_key" % [TransformKeybinds.SETTINGS_PREFIX, action]] = true
	for id in TransformKeybinds.VALUE_DEFAULTS:
		keep["%s/%s" % [TransformKeybinds.SETTINGS_PREFIX, id]] = true
	var stale_paths: PackedStringArray = []
	for prop in editor_settings.get_property_list():
		var path := String(prop.get("name", ""))
		var stale := path.begins_with("simpleassetplacer/")
		if not stale and path.begins_with(TransformKeybinds.SETTINGS_PREFIX + "/") and not keep.has(path):
			stale = true
		if stale and editor_settings.has_setting(path):
			stale_paths.append(path)
	for path in stale_paths:
		editor_settings.erase(path)
	if not stale_paths.is_empty():
		print("Simple Asset Placer 3: removed %d legacy editor setting(s)." % stale_paths.size())
	editor_settings.set_project_metadata(TransformKeybinds.SETTINGS_PREFIX, "stale_settings_cleaned", true)
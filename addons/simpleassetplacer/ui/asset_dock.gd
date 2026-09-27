@tool
extends PanelContainer

class_name AssetBrowserDock

"""
ASSET BROWSER DOCK
==================

PURPOSE: Browse project assets (scenes and meshes) in a dock with engine
generated thumbnails, and get them into the scene via native drag-and-drop
or double-click placement.

RESPONSIBILITIES:
- Scan a project folder for scene/mesh assets (DirAccess - engine pipeline)
- res:// folder editing with a native folder picker dialog plus refresh
- Request thumbnails from EditorResourcePreview (same pipeline as the
  FileSystem dock - engine cached, no custom generation); Refresh
  re-requests them
- Tree layout: assets grouped under collapsible subfolder headers (native
  tree), with engine thumbnails
- Drag items into the 3D viewport using the standard "files" drag payload
  (the editor instantiates them natively)
- Double-click / Enter asks the placement engine to spawn the asset under
  the cursor: it is picked up there, so it can be transformed before being
  confirmed; the "Keep placing" switch (or the keep-placing modifier while
  confirming) places it and carries a fresh copy (keep-placing chain)
"""

const ASSET_EXTENSIONS := ["tscn", "scn", "res", "tres", "glb", "gltf", "fbx", "obj", "dae"]
const MAX_ASSETS := 2000
const NAME_CHARS := 46
const DRAG_PREVIEW_SIZE := 64
const DEFAULT_FOLDER := "res://"
## Editor Settings id (under TransformKeybinds.SETTINGS_PREFIX) backing the
## keep-placing switch, so the mode survives editor restarts.
const KEEP_PLACING_SETTING := "keep_placing_mode"

var _path_edit: LineEdit
var _search_edit: LineEdit
var _status_label: Label
var _hint_label: Label
var _keep_placing_check: CheckBox
var _tree: AssetTree
var _folder_dialog: EditorFileDialog
var _folder_missing := false

var _all_paths: Array = []
var _paths: Array = []
var _preview_requested: Dictionary = {}
var _preview_cache: Dictionary = {}
var _tree_items: Dictionary = {}
var _root_path := DEFAULT_FOLDER
var _folder_icon: Texture2D

## Injected by plugin.gd: owns placement (undoable) and keep-placing chains
var placer: InlineTransformEngine


## UI Construction


class AssetTree:
	extends Tree

	var dock: AssetBrowserDock

	func _get_drag_data(at_position: Vector2) -> Variant:
		if dock:
			return dock._get_tree_drag_data(at_position)
		return null


func _init() -> void:
	# Explicit dock name - auto names show up as "@PanelContainer@<id>".
	name = "Asset Browser"


func _ready() -> void:
	custom_minimum_size = Vector2(240, 320)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	add_child(vbox)

	var path_row := HBoxContainer.new()
	path_row.add_theme_constant_override("separation", 4)
	vbox.add_child(path_row)

	var folder_label := Label.new()
	folder_label.text = "Folder:"
	path_row.add_child(folder_label)

	_path_edit = LineEdit.new()
	_path_edit.text = DEFAULT_FOLDER
	_path_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_path_edit.text_submitted.connect(_on_path_submitted)
	path_row.add_child(_path_edit)

	var browse_button := Button.new()
	browse_button.text = "..."
	browse_button.tooltip_text = "Browse for a folder inside res://"
	browse_button.pressed.connect(_on_browse_pressed)
	path_row.add_child(browse_button)

	var refresh_button := Button.new()
	refresh_button.text = "Refresh"
	refresh_button.tooltip_text = "Rescan the folder and refresh thumbnails"
	refresh_button.pressed.connect(_on_path_submitted)
	path_row.add_child(refresh_button)

	_search_edit = LineEdit.new()
	_search_edit.placeholder_text = "Search assets..."
	_search_edit.clear_button_enabled = true
	_search_edit.text_changed.connect(_on_search_changed)
	vbox.add_child(_search_edit)

	_tree = AssetTree.new()
	_tree.dock = self
	_tree.hide_root = true
	_tree.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_tree.custom_minimum_size = Vector2(220, 200)
	_tree.item_activated.connect(_on_tree_item_activated)
	vbox.add_child(_tree)

	_status_label = Label.new()
	_status_label.add_theme_font_size_override("font_size", 11)
	vbox.add_child(_status_label)

	_keep_placing_check = CheckBox.new()
	_keep_placing_check.text = "Keep placing"
	var modifier_label := TransformKeybinds.get_action_label("keep_placing_modifier")
	_keep_placing_check.tooltip_text = (
		"Every confirm places the carried asset and carries a fresh copy of "
		+ "the same asset - no need to hold the %s modifier. Escape / Right "
		+ "Mouse ends the chain."
	) % modifier_label
	# FOCUS_NONE: the switch must never take keyboard focus, or the confirm
	# keys (Enter/Space) would toggle it instead of placing the asset.
	_keep_placing_check.focus_mode = Control.FOCUS_NONE
	_keep_placing_check.set_pressed_no_signal(TransformKeybinds.get_bool(KEEP_PLACING_SETTING))
	_keep_placing_check.toggled.connect(_on_keep_placing_toggled)
	vbox.add_child(_keep_placing_check)

	_hint_label = Label.new()
	_hint_label.add_theme_font_size_override("font_size", 11)
	_hint_label.visible = false
	vbox.add_child(_hint_label)

	_folder_dialog = EditorFileDialog.new()
	_folder_dialog.file_mode = EditorFileDialog.FILE_MODE_OPEN_DIR
	_folder_dialog.access = EditorFileDialog.ACCESS_RESOURCES
	_folder_dialog.title = "Select Asset Folder"
	_folder_dialog.dir_selected.connect(_on_folder_selected)
	add_child(_folder_dialog)

	_rebuild()


## Scanning and Display


func _on_path_submitted(_text: String = "") -> void:
	_path_edit.text = _normalized_folder()
	_rebuild()


func _on_browse_pressed() -> void:
	_folder_dialog.current_dir = _normalized_folder()
	_folder_dialog.popup_centered(Vector2i(560, 440))


func _on_folder_selected(dir: String) -> void:
	_path_edit.text = dir
	_rebuild()


func _normalized_folder() -> String:
	var text := _path_edit.text.strip_edges()
	if text.is_empty():
		return DEFAULT_FOLDER
	if not text.begins_with("res://"):
		text = "res://" + text.trim_prefix("/")
	return text


func _on_search_changed(_text: String) -> void:
	_apply_filter()


## Transform Hint


func set_transform_hint(text: String) -> void:
	"""Show what the engine is currently transforming (empty string hides)."""
	_hint_label.text = text
	_hint_label.visible = not text.is_empty()


func _truncate_name(file_name: String) -> String:
	if file_name.length() > NAME_CHARS:
		file_name = file_name.substr(0, NAME_CHARS - 1) + "…"
	return file_name


func _rebuild() -> void:
	# Clearing the request cache lets Refresh actually re-request thumbnails.
	_preview_requested.clear()
	_folder_missing = false
	_root_path = _normalized_folder()
	_all_paths = _scan_folder(_normalized_folder())
	_apply_filter()


func _apply_filter() -> void:
	_paths.clear()
	var search := _search_edit.text.strip_edges().to_lower()
	for path in _all_paths:
		if search.is_empty() or path.to_lower().contains(search):
			_paths.append(path)
	_paths.sort_custom(func(a: String, b: String): return a.to_lower() < b.to_lower())

	_tree.clear()
	_tree_items.clear()
	_populate_tree()

	var count := _paths.size()
	if _folder_missing:
		_status_label.text = "Folder not found in res://"
	elif count >= MAX_ASSETS:
		_status_label.text = "%d+ assets (folder scan capped)" % count
	elif count == 1:
		_status_label.text = "1 asset"
	else:
		_status_label.text = "%d assets" % count

	_request_previews()


## List Grouping (subfolders as collapsible headers)


func _populate_tree() -> void:
	var tree_root := _tree.create_item()
	var root_prefix := _root_path.trim_suffix("/")
	var folder_icon := _get_folder_icon()
	var folder_items: Dictionary = {}

	# Pass 1: create every group's folder chain (sorted), so folder headers
	# precede files at each level.
	var dirs: Array = []
	for path in _paths:
		var rel := _relative_dir(path, root_prefix)
		if not rel.is_empty() and not folder_items.has(rel):
			folder_items[rel] = null
			dirs.append(rel)
	dirs.sort_custom(func(a: String, b: String): return a.to_lower() < b.to_lower())
	for rel in dirs:
		_ensure_folder_chain(rel, folder_items, tree_root, folder_icon)

	# Pass 2: append files after their group's subfolder chains.
	for path in _paths:
		var rel := _relative_dir(path, root_prefix)
		var parent: TreeItem = tree_root if rel.is_empty() else folder_items[rel]
		var item := parent.create_child()
		item.set_text(0, _truncate_name(path.get_file()))
		item.set_metadata(0, path)
		item.set_tooltip_text(0, path)
		var cached: Texture2D = _preview_cache.get(path)
		if cached:
			item.set_icon(0, cached)
		_tree_items[path] = item


func _ensure_folder_chain(
	rel: String, folder_items: Dictionary, tree_root: TreeItem, folder_icon: Texture2D
) -> void:
	var parent: TreeItem = tree_root
	var walked := ""
	for part in rel.split("/"):
		walked = part if walked.is_empty() else walked + "/" + part
		var existing: Variant = folder_items.get(walked)
		if existing is TreeItem:
			parent = existing
			continue
		var item := parent.create_child()
		item.set_text(0, part)
		item.set_icon(0, folder_icon)
		item.set_metadata(0, "")
		item.set_selectable(0, false)
		folder_items[walked] = item
		parent = item


func _relative_dir(path: String, root_prefix: String) -> String:
	var dir := path.get_base_dir()
	if dir == root_prefix:
		return ""
	if root_prefix == "res://":
		return dir.trim_prefix("res://")
	return dir.trim_prefix(root_prefix + "/")


func _get_folder_icon() -> Texture2D:
	if _folder_icon == null:
		var base := EditorInterface.get_base_control()
		if base:
			_folder_icon = base.get_theme_icon("Folder", "EditorIcons")
	return _folder_icon


func _scan_folder(root_path: String) -> Array:
	var result := []
	if not root_path.begins_with("res://"):
		return result

	var root_dir := DirAccess.open(root_path)
	if not root_dir:
		_folder_missing = true
		return result

	var stack := [root_path]
	while not stack.is_empty() and result.size() < MAX_ASSETS:
		var dir_path: String = stack.pop_back()
		var dir := DirAccess.open(dir_path)
		if not dir:
			continue
		dir.list_dir_begin()
		var item := dir.get_next()
		while item != "":
			if not item.begins_with("."):
				var full := dir_path.path_join(item)
				if dir.current_is_dir():
					stack.append(full)
				else:
					var ext := item.get_extension().to_lower()
					if ext in ASSET_EXTENSIONS:
						result.append(full)
			item = dir.get_next()
		dir.list_dir_end()
	return result


## Engine Preview Pipeline


func _request_previews() -> void:
	var previewer := EditorInterface.get_resource_previewer()
	if not previewer:
		return
	for i in _paths.size():
		var path: String = _paths[i]
		if _preview_requested.has(path):
			continue
		_preview_requested[path] = true
		previewer.queue_resource_preview(path, self, "_on_preview_loaded", i)


func _on_preview_loaded(
	path: String, preview: Texture2D, _thumbnail_info, _userdata: Variant
) -> void:
	if preview:
		# Cache by path: the callback's row index can go stale while the
		# filter changes and previews are still in flight.
		_preview_cache[path] = preview
		var tree_item: TreeItem = _tree_items.get(path)
		if tree_item and is_instance_valid(tree_item):
			tree_item.set_icon(0, preview)


## Drag and Drop (native "files" payload)


func _get_tree_drag_data(at_position: Vector2) -> Variant:
	var item := _tree.get_item_at_position(at_position)
	if not item:
		return null
	var path: Variant = item.get_metadata(0)
	if not (path is String) or (path as String).is_empty():
		return null

	_tree.set_drag_preview(_make_drag_preview(item.get_icon(0)))
	return {"type": "files", "files": [path]}


func _make_drag_preview(icon: Texture2D) -> TextureRect:
	var drag_root := TextureRect.new()
	drag_root.texture = icon
	drag_root.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	drag_root.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	drag_root.custom_minimum_size = Vector2(DRAG_PREVIEW_SIZE, DRAG_PREVIEW_SIZE)
	return drag_root


## Double-Click Placement and Keep-Placing Switch


func get_selected_asset_path() -> String:
	"""Asset path of the selected tree row ("" for headers/none). The
	placement engine reads this so keep-placing re-arms with the row that is
	selected at the time of the confirm."""
	if not _tree:
		return ""
	var item := _tree.get_selected()
	if not item:
		return ""
	var path: Variant = item.get_metadata(0)
	if (path is String) and not (path as String).is_empty():
		return path
	return ""


func is_keep_placing_enabled() -> bool:
	"""Switch state read by the placement engine: while the mode is on every
	confirm places the carried asset and carries the next one, so the
	keep-placing modifier does not have to be held. The editor setting behind
	the switch is the single source of truth."""
	return TransformKeybinds.get_bool(KEEP_PLACING_SETTING)


func sync_keep_placing() -> void:
	"""Re-read the setting behind the switch (manual Editor Settings edits)."""
	if _keep_placing_check:
		_keep_placing_check.set_pressed_no_signal(TransformKeybinds.get_bool(KEEP_PLACING_SETTING))


func _on_keep_placing_toggled(pressed: bool) -> void:
	TransformKeybinds.set_bool(KEEP_PLACING_SETTING, pressed)


func _on_tree_item_activated() -> void:
	if not placer:
		return
	var path := get_selected_asset_path()
	if not path.is_empty():
		placer.place_asset(path)


## Cleanup


func clear() -> void:
	_paths.clear()
	_all_paths.clear()
	_preview_requested.clear()
	_preview_cache.clear()
	_tree_items.clear()
	if _tree:
		_tree.clear()
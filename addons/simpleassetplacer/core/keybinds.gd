@tool
extends RefCounted

class_name TransformKeybinds

"""
TRANSFORM KEYBINDS
==================

PURPOSE: Key and value definitions for inline transforms, stored in Godot's
Editor Settings - no custom settings panel.

RESPONSIBILITIES:
- Register default settings on plugin startup
- Resolve configured keys to Key codes (cached, refreshable)
- Poll current key and modifier state

USAGE:
All settings live under "simple_asset_placer/" and are editable in the
Editor Settings dialog (search for "simple_asset_placer").
"""

const SETTINGS_PREFIX := "simple_asset_placer"

## Action id -> default key string
const KEY_DEFAULTS := {
	"rotate_x": "X",
	"rotate_y": "Y",
	"rotate_z": "Z",
	"move_forward": "W",
	"move_back": "S",
	"move_left": "A",
	"move_right": "D",
	"height_up": "Q",
	"height_down": "E",
	"scale_up": "L",
	"scale_down": "K",
	"pickup": "Tab",
	"confirm": "Enter",
	"reset": "Escape",
	"snap_to_floor": "PageDown",
	"duplicate": "V",
	"fine_modifier": "CTRL",
	"large_modifier": "ALT",
	"reverse_modifier": "SHIFT",
	"keep_placing_modifier": "SHIFT",
}

## Value id -> default value
const VALUE_DEFAULTS := {
	"rotation_step_degrees": 15.0,
	"move_step": 0.5,
	"scale_step_factor": 0.1,
	# 0 follows the editor's snap increment, > 0 is a fixed increment,
	# < 0 disables snapping for the mouse-follow placement.
	"snap_increment": 0.0,
}

## Bool id -> default value
const TOGGLE_DEFAULTS := {
	# Keep-placing mode: written by the dock switch, read by the placement
	# engine - keeps the chain running without holding the modifier key.
	"keep_placing_mode": false,
}


static var _key_cache: Dictionary = {}
static var _cache_valid := false


## Settings Registration


static func register_defaults() -> void:
	"""Register all defaults in Editor Settings (existing values are kept)."""
	var editor_settings := EditorInterface.get_editor_settings()
	if not editor_settings:
		return
	for action in KEY_DEFAULTS:
		var setting := "%s/%s_key" % [SETTINGS_PREFIX, action]
		if not editor_settings.has_setting(setting):
			editor_settings.set_setting(setting, KEY_DEFAULTS[action])
			editor_settings.set_initial_value(setting, KEY_DEFAULTS[action], false)
	for id in VALUE_DEFAULTS:
		var setting := "%s/%s" % [SETTINGS_PREFIX, id]
		if not editor_settings.has_setting(setting):
			editor_settings.set_setting(setting, VALUE_DEFAULTS[id])
			editor_settings.set_initial_value(setting, VALUE_DEFAULTS[id], false)
	for id in TOGGLE_DEFAULTS:
		var setting := "%s/%s" % [SETTINGS_PREFIX, id]
		if not editor_settings.has_setting(setting):
			editor_settings.set_setting(setting, TOGGLE_DEFAULTS[id])
			editor_settings.set_initial_value(setting, TOGGLE_DEFAULTS[id], false)


## Key Resolution (cached)


static func resolve_keys() -> void:
	"""Re-resolve all configured key strings to Key codes."""
	_key_cache.clear()
	var editor_settings := EditorInterface.get_editor_settings()
	for action in KEY_DEFAULTS:
		var default: String = KEY_DEFAULTS[action]
		var value: String = default
		if editor_settings:
			var setting := "%s/%s_key" % [SETTINGS_PREFIX, action]
			if editor_settings.has_setting(setting):
				value = str(editor_settings.get_setting(setting))
		_key_cache[action] = _parse_key(value)
	_cache_valid = true


static func _parse_key(key_string: String) -> Key:
	var normalized := key_string.strip_edges().to_upper()
	if normalized.is_empty():
		return KEY_NONE
	return OS.find_keycode_from_string(normalized)


## Input Polling


static func is_action_pressed(action: String) -> bool:
	if not _cache_valid:
		resolve_keys()
	var key: int = _key_cache.get(action, KEY_NONE)
	if key == KEY_NONE:
		return false
	# Logical keycodes match keycap labels on every layout; physical codes are
	# US-QWERTY positions and swap Y/Z on QWERTZ keyboards.
	return Input.is_key_pressed(key)


static func is_fine_modifier_held() -> bool:
	return is_action_pressed("fine_modifier")


static func is_large_modifier_held() -> bool:
	return is_action_pressed("large_modifier")


static func is_reverse_modifier_held() -> bool:
	return is_action_pressed("reverse_modifier")


static func is_keep_placing_modifier_held() -> bool:
	"""Held while confirming to keep placing (keep-placing chain)."""
	return is_action_pressed("keep_placing_modifier")


static func get_action_key(action: String) -> Key:
	"""Resolved Key code for an action (KEY_NONE when unresolvable)."""
	if not _cache_valid:
		resolve_keys()
	return _key_cache.get(action, KEY_NONE)


static func get_action_label(action: String) -> String:
	"""Configured key string for an action, for UI hints."""
	var value: String = KEY_DEFAULTS.get(action, "")
	var editor_settings := EditorInterface.get_editor_settings()
	if editor_settings:
		var setting := "%s/%s_key" % [SETTINGS_PREFIX, action]
		if editor_settings.has_setting(setting):
			value = str(editor_settings.get_setting(setting))
	return value


## Value Access


static func get_number(id: String) -> float:
	var editor_settings := EditorInterface.get_editor_settings()
	var setting := "%s/%s" % [SETTINGS_PREFIX, id]
	if editor_settings and editor_settings.has_setting(setting):
		return float(editor_settings.get_setting(setting))
	return float(VALUE_DEFAULTS.get(id, 0.0))


## Toggle Access


static func get_bool(id: String) -> bool:
	var editor_settings := EditorInterface.get_editor_settings()
	var setting := "%s/%s" % [SETTINGS_PREFIX, id]
	if editor_settings and editor_settings.has_setting(setting):
		return bool(editor_settings.get_setting(setting))
	return bool(TOGGLE_DEFAULTS.get(id, false))


static func set_bool(id: String, value: bool) -> void:
	var editor_settings := EditorInterface.get_editor_settings()
	if editor_settings:
		editor_settings.set_setting("%s/%s" % [SETTINGS_PREFIX, id], value)


## Key Event Matching (used to keep editor shortcuts from firing while transforming)


## Actions whose keys should block editor shortcut handling (modifiers excluded)
const TRANSFORM_ACTION_KEYS := [
	"rotate_x", "rotate_y", "rotate_z",
	"move_forward", "move_back", "move_left", "move_right",
	"height_up", "height_down", "scale_up", "scale_down",
]


static func matches_transform_key(key: Key) -> bool:
	"""True when key is one of the configured transform action keys."""
	if key == KEY_NONE:
		return false
	if not _cache_valid:
		resolve_keys()
	var key_int := int(key)
	for action in TRANSFORM_ACTION_KEYS:
		if int(_key_cache.get(action, KEY_NONE)) == key_int:
			return true
	return false
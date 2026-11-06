extends RefCounted

signal changed

const SETTINGS_PATH := "user://world_story_settings.json"
const WindowShortcuts = preload("res://scripts/system/WindowShortcuts.gd")
const DEFAULTS := {
	"master_volume": 1.0,
	"fullscreen": false,
	"sensitivity": 0.0025,
	"msaa": 2
}

var values: Dictionary = DEFAULTS.duplicate()
var settings_path: String = SETTINGS_PATH
var _windowed_size := Vector2i.ZERO
var _windowed_position := Vector2i.ZERO
var _windowed_mode: int = DisplayServer.WINDOW_MODE_WINDOWED

func _init(path: String = SETTINGS_PATH) -> void:
	settings_path = path
	load_settings()

func load_settings() -> Dictionary:
	values = DEFAULTS.duplicate()
	if FileAccess.file_exists(settings_path):
		var file := FileAccess.open(settings_path, FileAccess.READ)
		var parsed = JSON.parse_string(file.get_as_text()) if file != null else null
		if parsed is Dictionary:
			for key in DEFAULTS:
				if parsed.has(key):
					values[key] = parsed[key]
	return values.duplicate()

func save() -> bool:
	var file := FileAccess.open(settings_path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(values))
	file.flush()
	var success := file.get_error() == OK
	file.close()
	return success

func apply(viewport: Viewport, player = null) -> void:
	_bind_shortcuts(viewport)
	var master := AudioServer.get_bus_index("Master")
	if master >= 0:
		AudioServer.set_bus_volume_linear(master, clampf(float(get_value("master_volume")), 0.0, 1.0))
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_min_size(Vector2i(800, 500))
		var current := DisplayServer.window_get_mode()
		var is_fullscreen := current in [DisplayServer.WINDOW_MODE_FULLSCREEN, DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN]
		if bool(get_value("fullscreen")) and not is_fullscreen:
			_windowed_size = DisplayServer.window_get_size()
			_windowed_position = DisplayServer.window_get_position()
			_windowed_mode = current
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		elif not bool(get_value("fullscreen")) and is_fullscreen:
			DisplayServer.window_set_mode(_windowed_mode)
			if _windowed_mode == DisplayServer.WINDOW_MODE_WINDOWED and _windowed_size != Vector2i.ZERO:
				var usable := DisplayServer.screen_get_usable_rect(DisplayServer.window_get_current_screen())
				var extent := _windowed_size.min(usable.size).max(Vector2i(800, 500))
				DisplayServer.window_set_size(extent)
				DisplayServer.window_set_position(_windowed_position.clamp(usable.position, (usable.end - extent).max(usable.position)))
	if viewport != null:
		match int(get_value("msaa")):
			2: viewport.msaa_3d = Viewport.MSAA_2X
			4: viewport.msaa_3d = Viewport.MSAA_4X
			_: viewport.msaa_3d = Viewport.MSAA_DISABLED
	if player != null and "mouse_sensitivity" in player:
		player.mouse_sensitivity = float(get_value("sensitivity"))

func _bind_shortcuts(viewport: Viewport) -> void:
	if viewport == null:
		return
	var window := viewport.get_window()
	if window == null:
		return
	var handler: Node = window.get_meta("world_story_window_shortcuts") if window.has_meta("world_story_window_shortcuts") else null
	if not is_instance_valid(handler):
		handler = WindowShortcuts.new()
		handler.name = "WindowShortcuts"
		window.set_meta("world_story_window_shortcuts", handler)
		window.add_child.call_deferred(handler)
	handler.settings = self

func toggle_fullscreen(viewport: Viewport) -> bool:
	var was_fullscreen := bool(get_value("fullscreen"))
	if DisplayServer.get_name() != "headless":
		was_fullscreen = DisplayServer.window_get_mode() in [DisplayServer.WINDOW_MODE_FULLSCREEN, DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN]
	set_value("fullscreen", not was_fullscreen)
	apply(viewport)
	return save()

func set_value(key: String, value) -> void:
	if not DEFAULTS.has(key):
		return
	values[key] = value
	changed.emit()

func reset() -> void:
	values = DEFAULTS.duplicate()
	changed.emit()

func get_value(key: String, fallback = null):
	return values.get(key, fallback)

extends RefCounted

signal changed

const SETTINGS_PATH := "user://world_story_settings.json"
const DEFAULTS := {
	"master_volume": 1.0,
	"fullscreen": false,
	"sensitivity": 0.0025,
	"msaa": 2
}

var values: Dictionary = DEFAULTS.duplicate()
var settings_path: String = SETTINGS_PATH

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
	var master := AudioServer.get_bus_index("Master")
	if master >= 0:
		AudioServer.set_bus_volume_linear(master, clampf(float(get_value("master_volume")), 0.0, 1.0))
	if DisplayServer.get_name() != "headless":
		var desired := DisplayServer.WINDOW_MODE_FULLSCREEN if bool(get_value("fullscreen")) else DisplayServer.WINDOW_MODE_WINDOWED
		if DisplayServer.window_get_mode() != desired:
			DisplayServer.window_set_mode(desired)
	if viewport != null:
		match int(get_value("msaa")):
			2: viewport.msaa_3d = Viewport.MSAA_2X
			4: viewport.msaa_3d = Viewport.MSAA_4X
			_: viewport.msaa_3d = Viewport.MSAA_DISABLED
	if player != null and "mouse_sensitivity" in player:
		player.mouse_sensitivity = float(get_value("sensitivity"))

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

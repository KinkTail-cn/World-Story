extends Node

const MainScene = preload("res://scenes/Main.tscn")
const MainMenuScene = preload("res://scenes/MainMenu.tscn")
const SettingsScene = preload("res://scenes/SettingsPanel.tscn")
const SaveSystem = preload("res://scripts/system/SaveSystem.gd")
const SettingsSystem = preload("res://scripts/system/SettingsSystem.gd")

var menu
var settings
var game
var save_system
var settings_system

func _ready() -> void:
	if save_system == null:
		save_system = SaveSystem.new()
	if settings_system == null:
		settings_system = SettingsSystem.new()
	settings_system.load_settings()
	if not settings_system.changed.is_connected(_apply_settings):
		settings_system.changed.connect(_apply_settings)
	_apply_settings()
	menu = MainMenuScene.instantiate()
	menu.save_system = save_system
	add_child(menu)
	menu.new_game.connect(_new_game)
	menu.continue_game.connect(_continue_game)
	menu.settings_requested.connect(_open_settings)
	menu.quit_requested.connect(func(): get_tree().quit())
	settings = SettingsScene.instantiate()
	add_child(settings)
	settings.close_requested.connect(func(): settings.close(); menu.visible = true)

func _open_settings() -> void:
	menu.visible = false
	settings.open(settings_system)

func _apply_settings() -> void:
	settings_system.apply(get_viewport())

func _new_game(mode: String = "creative") -> void:
	var chosen_world_type: String = "infinite"
	if menu != null and "selected_world_type" in menu:
		chosen_world_type = menu.selected_world_type
	_start_game({}, mode, chosen_world_type)

func _continue_game() -> void:
	var result: Dictionary = save_system.load_world()
	if not result.ok:
		menu.show_error("无法继续旅程：" + str(result.error) + "。请检查存档或备份。")
		return
	var data: Dictionary = result.data
	var mode := str(data.get("mode", "creative"))
	var world_data: Dictionary = data.get("world", {})
	var world_type := str(world_data.get("world_type", "island"))
	_start_game(data, mode, world_type)
	if result.recovered:
		game.hud.show_message("已从上一版备份恢复进度 · F5 保存恢复后的世界")

func _start_game(data: Dictionary, mode: String = "creative", world_type: String = "infinite") -> void:
	menu.visible = false
	settings.close()
	game = MainScene.instantiate()
	game.game_mode = mode
	if is_instance_valid(game) and "world_type" in game:
		game.world_type = world_type
	game.setup_lifecycle(save_system, settings_system, data)
	add_child(game)
	game.return_to_menu.connect(_return_to_menu)
	game.regenerate_requested.connect(_regenerate_game)

func _regenerate_game() -> void:
	var mode: String = game.game_mode
	var kind: String = game.world_type
	remove_child(game)
	game.queue_free()
	game = null
	_start_game({}, mode, kind)

func _return_to_menu() -> void:
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if game != null:
		game.queue_free()
		game = null
	menu.refresh()
	menu.visible = true

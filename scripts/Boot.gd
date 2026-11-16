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
	get_tree().auto_accept_quit = false
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

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and not is_instance_valid(game):
		get_tree().quit()

func _open_settings() -> void:
	menu.visible = false
	settings.open(settings_system)

func _apply_settings() -> void:
	settings_system.apply(get_viewport())

func _new_game(mode: String = "creative") -> void:
	_start_game({}, mode, "infinite")

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
	var terrain = game.get_node("World")
	terrain.world_type = world_type
	if data.is_empty():
		terrain.world_seed = menu.selected_world_seed if is_instance_valid(menu) else int(randi() & 0x7fffffff)
		if world_type == "infinite":
			terrain.terrain_generation_version = 1
			terrain.spawn_resolution_pending = true
	else:
		var world_data: Dictionary = data.get("world", {})
		terrain.world_seed = int(world_data.get("world_seed", 1337))
		terrain.terrain_generation_version = int(world_data.get("terrain_generation_version", 0))
		terrain.village_generation_version = int(world_data.get("village_generation_version", 0))
		if world_data.get("spawn_position") is Vector3:
			terrain.world_spawn = world_data.spawn_position
	game.setup_lifecycle(save_system, settings_system, data)
	add_child(game)
	game.return_to_menu.connect(_return_to_menu)
	game.regenerate_requested.connect(_regenerate_game)

func _regenerate_game() -> void:
	var mode: String = game.game_mode
	remove_child(game)
	game.queue_free()
	game = null
	if is_instance_valid(menu):
		menu.selected_world_seed = int(randi() & 0x7fffffff)
	_start_game({}, mode, "infinite")

func _return_to_menu() -> void:
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if game != null:
		game.queue_free()
		game = null
	menu.refresh()
	menu.visible = true

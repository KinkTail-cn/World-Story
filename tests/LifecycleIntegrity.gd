extends SceneTree

const Saves = preload("res://scripts/system/SaveSystem.gd")
const Settings = preload("res://scripts/system/SettingsSystem.gd")
const MainScript = preload("res://scripts/Main.gd")
const BootScript = preload("res://scripts/Boot.gd")

class FailedRename extends "res://scripts/system/SaveSystem.gd":
	func _replace_file(_source: String, destination: String) -> Error:
		DirAccess.remove_absolute(destination)
		return ERR_CANT_CREATE

class SensitivityTarget extends RefCounted:
	var mouse_sensitivity: float = 0.0025

class WorldStub extends Node3D:
	const SEA_LEVEL = 0.0
	func is_water_at(_position: Vector3) -> bool:
		return false
	func save_data() -> Dictionary:
		return {}

class HudStub extends RefCounted:
	var last_message: String
	func show_message(text: String) -> void:
		last_message = text

class BlueprintsStub extends RefCounted:
	var saved: bool = false
	var succeeds: bool = true
	func save_json() -> bool:
		saved = true
		return succeeds

class GameStub extends Node3D:
	var game_mode: String = "survival"
	var world_type: String = "island"

class BootStub extends "res://scripts/Boot.gd":
	var restarted_data: Dictionary = {"old": true}
	func _init(test_save, test_settings) -> void:
		save_system = test_save
		settings_system = test_settings
	func _start_game(data: Dictionary, mode: String = "creative", kind: String = "infinite") -> void:
		restarted_data = data
		game = GameStub.new()
		game.game_mode = mode
		game.world_type = kind
		add_child(game)

var failures: int = 0
var directory: String

func _initialize() -> void:
	call_deferred("_run")

func check(condition: bool, description: String) -> void:
	if not condition:
		failures += 1
		push_error(description)

func _run() -> void:
	directory = "user://lifecycle_%s_%s" % [OS.get_process_id(), Time.get_ticks_usec()]
	check(DirAccess.make_dir_absolute(directory) == OK, "Create isolated directory")
	var path := directory + "/save.json"
	var saves = Saves.new(path)
	check(saves.save_game({"version": 1}), "Initial save")
	check(saves.save_game({"version": 2}), "Replace existing save")
	check(saves.load_game().get("version") == 2, "Replacement is readable")
	var failed = FailedRename.new(path)
	check(not failed.save_game({"version": 3}), "Rename failure returns false")
	check(saves.load_game().get("version") == 2, "Backup restored after failed rename")
	var blocked = Saves.new(directory + "/missing/save.json")
	check(not blocked.save_game({}), "Open failure returns false")
	DirAccess.remove_absolute(path + ".bak")
	check(DirAccess.make_dir_absolute(path + ".bak") == OK, "Block backup destination")
	check(not saves.save_game({"version": 4}), "Backup failure returns false")
	check(saves.load_game().get("version") == 2, "Backup failure preserves original")
	DirAccess.remove_absolute(path + ".bak")

	var player = preload("res://scenes/Player.tscn").instantiate()
	var world := WorldStub.new()
	player.world = world
	player.process_mode = Node.PROCESS_MODE_DISABLED
	root.add_child(player)
	player.position = Vector3(2, 5, 8)
	player.rotation = Vector3(0, 0.2, 0)
	player.rig.rotation.y = 1.1
	player.pitch.rotation.x = -0.4
	player.visual.rotation.y = 0.7
	player.select_slot(5)
	player.set_first_person(true)
	check(saves.save_game({"player": saves.save_player(player)}), "Save actual Player")
	player.position = Vector3.ZERO
	player.rotation = Vector3.ZERO
	player.rig.rotation = Vector3.ZERO
	player.pitch.rotation = Vector3.ZERO
	player.visual.rotation = Vector3.ZERO
	player.select_slot(0)
	player.set_first_person(false)
	saves.apply_player(player, saves.load_game().player)
	check(player.position.is_equal_approx(Vector3(2, 5, 8)), "Player position restored")
	check(is_equal_approx(player.rotation.y, 0.2), "Player rotation restored")
	check(is_equal_approx(player.rig.rotation.y, 1.1), "Rig yaw restored")
	check(is_equal_approx(player.pitch.rotation.x, -0.4), "Pitch restored")
	check(is_equal_approx(player.visual.rotation.y, 0.7), "Visual yaw restored")
	check(player.first_person and not player.visual.visible and player.arm.spring_length == 0.0, "View setter applied")
	check(player.selected_slot == 5, "Selected slot restored")
	saves.apply_player(player, {"global_position": Vector3.ONE, "rotation": Vector3.ZERO, "selected_slot": 2})
	check(player.position == Vector3.ONE and player.selected_slot == 2, "Legacy player save accepted")
	check(is_equal_approx(player.rig.rotation.y, 1.1), "Legacy data preserves unspecified camera state")
	player.free()

	var settings_path := directory + "/settings.json"
	var settings = Settings.new(settings_path)
	var target := SensitivityTarget.new()
	var viewport := SubViewport.new()
	root.add_child(viewport)
	var previous_volume := AudioServer.get_bus_volume_linear(0)
	settings.set_value("master_volume", 0.35)
	settings.set_value("sensitivity", 0.006)
	settings.set_value("msaa", 4)
	settings.apply(viewport, target)
	check(is_equal_approx(AudioServer.get_bus_volume_linear(0), 0.35), "Master volume applied")
	check(is_equal_approx(target.mouse_sensitivity, 0.006), "Player sensitivity applied")
	check(viewport.msaa_3d == Viewport.MSAA_4X, "MSAA samples mapped to enum")
	check(settings.save(), "Isolated settings saved")
	var restored = Settings.new(settings_path)
	check(is_equal_approx(float(restored.get_value("sensitivity")), 0.006), "Settings reloaded")
	settings.reset()
	settings.apply(viewport, target)
	check(viewport.msaa_3d == Viewport.MSAA_2X and is_equal_approx(target.mouse_sensitivity, 0.0025), "Defaults reapplied")
	settings.set_value("msaa", 0)
	settings.apply(viewport, target)
	check(viewport.msaa_3d == Viewport.MSAA_DISABLED, "MSAA disabled")
	var main = MainScript.new()
	main.setup_lifecycle(saves, settings, {})
	main.setup_lifecycle(saves, settings, {})
	check(settings.changed.get_connections().size() == 1, "Main settings subscription is unique")
	main.inventory = {"mode": "survival"}
	main.player = {"global_position": Vector3.ZERO, "rotation": Vector3.ZERO}
	main.world = world
	main.hud = HudStub.new()
	main.blueprint_manager = BlueprintsStub.new()
	main.save_system = blocked
	check(not main.save_progress(), "Main reports save failure")
	check(not main.blueprint_manager.saved, "Failed save does not persist blueprints")
	var failure_message: String = main.hud.last_message
	main.save_system = saves
	check(main.save_progress(), "Main reports save success")
	check(main.blueprint_manager.saved and main.hud.last_message != failure_message, "Success message follows successful save")
	main.blueprint_manager.succeeds = false
	check(not main.save_progress() and main.hud.last_message.contains("笔记保存失败"), "A library failure reports partial save instead of success")
	main.free()
	world.free()
	var boot := BootStub.new(saves, settings)
	boot.game = GameStub.new()
	boot.add_child(boot.game)
	var previous_game = boot.game
	boot._regenerate_game()
	check(boot.game != previous_game and previous_game.is_queued_for_deletion(), "Regeneration replaces game child")
	check(boot.game.game_mode == "survival" and boot.game.world_type == "island", "Regeneration retains mode and world type")
	check(boot.restarted_data.is_empty(), "Regeneration starts a fresh world")
	boot.free()
	viewport.free()
	AudioServer.set_bus_volume_linear(0, previous_volume)
	for filename in DirAccess.get_files_at(directory):
		DirAccess.remove_absolute(directory + "/" + filename)
	check(DirAccess.remove_absolute(directory) == OK, "Isolated files cleaned up")
	print("LifecycleIntegrity: %s" % ("PASS" if failures == 0 else "%d failures" % failures))
	quit(0 if failures == 0 else 1)

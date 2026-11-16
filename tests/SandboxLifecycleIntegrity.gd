extends SceneTree

const Saves = preload("res://scripts/system/SaveSystem.gd")
const Settings = preload("res://scripts/system/SettingsSystem.gd")
var checks: int = 0
var failures: int = 0

class ExitProbe extends "res://scripts/Main.gd":
	var exit_committed: bool = false
	func _commit_exit() -> void:
		exit_committed = true

func _initialize() -> void:
	create_timer(35.0).timeout.connect(func(): push_error("SANDBOX_LIFECYCLE_TIMEOUT"); quit(1))
	_run.call_deferred()

func check(condition: bool, text: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(text)

func frames(count: int = 4) -> void:
	for i in count:
		await process_frame

func _run() -> void:
	var saves = Saves.new("user://sandbox_lifecycle.json")
	var settings = Settings.new("user://sandbox_lifecycle_settings.json")
	var boot = preload("res://scenes/Boot.tscn").instantiate()
	boot.save_system = saves
	boot.settings_system = settings
	root.add_child(boot)
	current_scene = boot
	boot.menu.selected_world_type = "island"
	boot._new_game("survival")
	while boot.game.is_loading:
		await process_frame
	var game = boot.game
	game.player.set_physics_process(false)
	game.world.set_block(Vector3i(21, 5, 21), 14)
	game.inventory.add_item(7, 8)
	game.player.health = 76.0
	game.player.air = 12.0
	game.player.mined = 9
	game.player.placed = 4
	game.autosave_time = 119.9
	paused = true
	var before: float = game.autosave_time
	game._process(0.2)
	check(game.autosave_time == before and not saves.has_save(), "Autosave timer pauses with the world")
	paused = false
	game._process(0.2)
	check(saves.has_save() and saves.load_world().ok, "Interval autosave writes a validated world")
	var blocked = Saves.new("user://missing_sandbox_directory/save.json")
	game.save_system = blocked
	check(not game.save_progress() and paused and game.hud.pause_panel.visible, "A failed gameplay save opens the actionable pause status without a floating hint")
	paused = true
	game.hud.set_paused(true)
	game._save_and_menu()
	check(boot.game == game and paused and game.hud.pause_panel.visible, "Failed save-and-menu retains the game")
	check(game.hud.get_node("Root/Pause/Panel/Margin/Content/Description").text.contains("保存失败"), "Pause card visibly reports a failed save")
	game.save_system = saves
	game._save_and_menu()
	await frames()
	check(boot.game == null and boot.menu.visible and not paused, "Successful save-and-menu returns to the live title")
	var former_save: Dictionary = saves.load_world().data
	former_save.player.character = {"schema_version": 1, "name": "旧自定义人物", "parameters": {"height": 1.1}, "cubes": []}
	check(saves.save_game(former_save), "Write a world snapshot containing the retired character field")
	boot.menu._open_mode_popup()
	boot.menu._start_selected_mode()
	check(boot.menu.replace_confirmation.visible and boot.game == null, "Creating a world protects the existing save with an overwrite choice")
	boot.menu.replace_confirmation.hide()
	boot.menu._close_mode_popup()
	boot._continue_game()
	while boot.game.is_loading:
		await process_frame
	game = boot.game
	game.player.set_physics_process(false)
	check(game.inventory.count_item(7) == 8 and game.world.get_block(Vector3i(21, 5, 21)) == 14, "Continue restores possessions and authored buildings")
	check(not game.player.has_method("apply_character") and is_equal_approx(game.player.collision.shape.height, 1.8) and is_equal_approx(game.player.visual.head.position.y, 1.575), "Continue uses the fixed character while ignoring retired model data")
	# One physics tick may replenish air/health after the loading screen fades.
	check(game.player.health >= 76.0 and game.player.health < 77.0 and game.player.air >= 12.0 and game.player.air < 13.0 and game.player.mined == 9 and game.player.placed == 4, "Continue restores vitals and persistent build statistics")
	check(game.save_progress() and not saves.load_world().data.player.has("character"), "New saves write the fixed player without obsolete model data")
	var confined_save: Dictionary = saves.load_world().data
	confined_save.player.character = {"parameters": {"height": 1.1}}
	confined_save.player.global_position = Vector3(16.5, 4.02, 21.5)
	check(saves.save_game(confined_save), "Write a retired-model position that the fixed character cannot occupy")
	boot._return_to_menu()
	await frames()
	boot._continue_game()
	while boot.game.is_loading:
		await process_frame
	game = boot.game
	game.player.set_physics_process(false)
	check(game.player._can_occupy(game.player.global_position, false) and game.player.global_position.distance_to(game.world.get_spawn_position()) < 3.0, "A confined retired-model position recovers to a safe fixed-body spawn")
	check(game.world.get_block(Vector3i(21, 5, 21)) == 14 and game.inventory.count_item(7) == 8, "Safe character recovery preserves world edits and inventory")
	check(game.save_progress(), "The recovered fixed-body world can be saved")
	var legacy: Dictionary = saves.load_world().data
	for key in ["health", "air", "mined", "placed"]:
		legacy.player.erase(key)
	check(saves.save_game(legacy), "Write a legacy world fixture")
	boot._return_to_menu()
	await frames()
	boot._continue_game()
	while boot.game.is_loading:
		await process_frame
	game = boot.game
	game.player.set_physics_process(false)
	check(game.player.health == 100.0 and game.player.air == 18.0, "Legacy saves receive safe default vitals")
	check(game.world.get_block(Vector3i(21, 5, 21)) == 14 and game.inventory.count_item(7) == 8, "Legacy adoption preserves buildings and possessions")
	check(saves.world_validation_error(legacy).is_empty(), "Old world structure remains valid")
	for entry in [{"health": -1}, {"health": 101}, {"health": "broken"}, {"air": 19}, {"air": -1}, {"mined": 1.5}, {"placed": -1}]:
		var invalid: Dictionary = legacy.duplicate(true)
		invalid.player.merge(entry, true)
		check(not saves.world_validation_error(invalid).is_empty(), "Malformed survival/statistic fields are rejected: %s" % str(entry))
	var corrupt: Dictionary = legacy.duplicate(true)
	corrupt.player.health = -10
	check(saves.save_game(corrupt), "Write a damaged survival fixture")
	var recovered: Dictionary = saves.load_world()
	check(recovered.ok and recovered.recovered, "Invalid survival state recovers the previous backup")
	boot.queue_free()
	await frames()
	# Closing the native window from an edited blueprint goes through the
	# editor's existing save/discard/cancel transition before committing exit.
	var probe = preload("res://scenes/Main.tscn").instantiate()
	probe.set_script(ExitProbe)
	probe.setup_lifecycle(saves, settings, {})
	root.add_child(probe)
	while probe.is_loading:
		await process_frame
	probe.player.set_physics_process(false)
	paused = true
	probe.hud.open_blueprint(probe.player.visual)
	var editor = probe.hud.blueprint_workshop
	editor.name_edit.text = "关闭保护测试"
	probe._save_and_quit()
	check(not probe.exit_committed and editor.get_node("%UnsavedDialog").visible, "An edited blueprint blocks immediate window close")
	editor.cancel_edit()
	check(not probe.exit_committed and editor.visible, "Cancel keeps the editor and draft open")
	editor._finish_close()
	paused = false
	probe._save_and_quit()
	check(probe.exit_committed, "An unblocked close reaches the exit commit")
	probe.queue_free()
	await frames()
	check(saves.delete_save(), "Isolated lifecycle fixtures are cleaned up")
	print("SANDBOX_LIFECYCLE_INTEGRITY_PASS: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

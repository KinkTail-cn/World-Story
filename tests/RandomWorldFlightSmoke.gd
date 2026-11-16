extends SceneTree

const World = preload("res://scripts/world/VoxelWorld.gd")
const Saves = preload("res://scripts/system/SaveSystem.gd")
const Settings = preload("res://scripts/system/SettingsSystem.gd")
var checks: int = 0
var failures: int = 0

func _initialize() -> void:
	create_timer(38.0).timeout.connect(func(): push_error("RANDOM_WORLD_FLIGHT_TIMEOUT"); quit(1))
	_run.call_deferred()

func check(condition: bool, text: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(text)

func frames(count: int = 4) -> void:
	for index in count:
		await physics_frame

func key(code: int, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = pressed
	root.push_input(event, true)

func tap_jump() -> void:
	key(KEY_SPACE, true)
	await frames(1)
	key(KEY_SPACE, false)
	await frames(2)

func action(name: String) -> InputEventAction:
	var event := InputEventAction.new()
	event.action = name
	event.pressed = true
	return event

func _run() -> void:
	var shapes := {}
	var starts := {}
	for seed_value in [0, 1, 42, 1337, 2026, -1, 2147483647, -2147483648]:
		var world := World.new()
		world.world_type = "infinite"
		world.terrain_generation_version = 1
		world.world_seed = seed_value
		world._setup_noise()
		var spawn := world.find_random_spawn()
		check(spawn == world.find_random_spawn(), "Identical seeds reproduce the safe spawn")
		check(world._origin_blocks.is_empty() and spawn.y > world.SEA_LEVEL + 1.0, "Random generation does not construct starter island data")
		check(not world.villages.is_managed(Vector2i(spawn.x, spawn.z)), "Birth is chosen from natural terrain rather than a forced village")
		var signature := PackedInt32Array()
		for z in range(-24, 33, 8):
			for x in range(-24, 33, 8):
				signature.append(world._get_procedural_height(x, z))
				for y in [0, 4, 7, 10]:
					var cell := Vector3i(x, y, z)
					check(world.get_block(cell) == world._get_procedural_block_at(x, y, z), "Origin-region queries use procedural terrain, including the former starter coordinates")
		shapes[str(signature)] = true
		starts[spawn] = true
		world.free()
	check(shapes.size() > 4 and starts.size() > 4, "Different seeds vary both origin terrain and spawn locations")
	var boot = preload("res://scenes/Boot.tscn").instantiate()
	boot.save_system = Saves.new("user://random_flight.json")
	boot.settings_system = Settings.new("user://random_flight_settings.json")
	root.add_child(boot)
	current_scene = boot
	check(boot.menu.mode_box.item_count == 2 and not boot.menu.has_node("ModePopup/Card/Body/WorldType"), "Creation offers exactly creative and survival, without preset map choices")
	boot.menu._open_mode_popup()
	boot.menu.get_node("ModePopup/Card/Body/Seed").text = "1337"
	boot.menu.get_node("ModePopup/Card/Body/Start").pressed.emit()
	var game = boot.game
	while game.is_loading:
		await process_frame
	var player = game.player
	await frames(8)
	check(game.world.terrain_generation_version == 1 and game.world._origin_blocks.is_empty() and game.world.world_type == "infinite", "The actual create action starts a random infinite world")
	var home: Vector3 = game.world.get_spawn_position()
	check(player.is_on_floor() and player._can_occupy(home, false) and player.global_position.distance_to(home) < 0.1, "Random birth loads collision before play and lands safely")
	await tap_jump()
	check(not player.flying, "One space press is still a normal jump")
	await tap_jump()
	check(player.flying, "A real double-space input enables creative flight")
	var before_y: float = player.global_position.y
	Input.action_press("jump")
	await frames(24)
	Input.action_release("jump")
	check(player.global_position.y > before_y + 1.0 and player.flying, "Space rises while flying")
	# Verify free flight above the current build-height ceiling as well.
	player.global_position.y = 32.0
	player.velocity = Vector3.ZERO
	await frames(18)
	check(absf(player.global_position.y - 32.0) < 0.03, "Releasing controls hovers without gravity above terrain height")
	var start: Vector3 = player.global_position
	Input.action_press("move_forward")
	await frames(36)
	var plain_distance: float = player.global_position.distance_to(start)
	start = player.global_position
	Input.action_press("sprint")
	await frames(36)
	var fast_distance: float = player.global_position.distance_to(start)
	Input.action_release("move_forward")
	Input.action_release("sprint")
	check(plain_distance > 3.0 and fast_distance > plain_distance * 1.5, "WASD moves through the air and Shift accelerates")
	before_y = player.global_position.y
	Input.action_press("dive")
	await frames(24)
	Input.action_release("dive")
	check(player.global_position.y < before_y - 1.0, "The descend action lowers the flying player")
	game._input(action("pause"))
	var frozen: Vector3 = player.global_position
	player._unhandled_input(action("jump"))
	await frames(6)
	check(player.global_position == frozen and player.flying and paused, "Pause freezes flight and ignores flight toggles")
	game._input(action("pause"))
	check(game.save_progress(), "An airborne creative game saves successfully")
	var saved: Dictionary = boot.save_system.load_world()
	check(saved.ok and saved.data.player.flying and not saved.data.world.has("blocks") and saved.data.world.spawn_position == home, "Save preserves flight, random terrain version and the original spawn")
	boot._return_to_menu()
	await process_frame
	boot._continue_game()
	game = boot.game
	while game.is_loading:
		await process_frame
	player = game.player
	check(player.flying and game.world.get_spawn_position() == home and player.global_position.y > 24.0, "Continue restores creative flight above the same random world")
	player.global_position = home + Vector3.UP * 0.1
	player.velocity = Vector3.ZERO
	player.set_flying(true)
	var ceiling_y := floori(home.y) + 4
	var original := {}
	for z in range(floori(home.z) - 1, floori(home.z) + 2):
		for x in range(floori(home.x) - 1, floori(home.x) + 2):
			var cell := Vector3i(x, ceiling_y, z)
			original[cell] = game.world.get_block(cell)
			game.world.set_block(cell, 14)
	await frames(4)
	Input.action_press("jump")
	await frames(36)
	Input.action_release("jump")
	check(player.global_position.y + 1.8 <= ceiling_y + 0.03 and player.flying, "Flying retains capsule collision against ceilings")
	for cell in original:
		game.world.set_block(cell, original[cell])
	Input.action_press("dive")
	await frames(45)
	Input.action_release("dive")
	check(player.is_on_floor() and not player.flying, "Descending onto solid ground exits flight")
	await capture(game)
	boot._return_to_menu()
	await process_frame
	boot.menu._open_mode_popup()
	boot.menu.mode_box.select(1)
	boot.menu.get_node("ModePopup/Card/Body/Seed").text = "42"
	boot.menu._start_selected_mode()
	boot.menu.replace_confirmation.confirmed.emit()
	game = boot.game
	while game.is_loading:
		await process_frame
	player = game.player
	await tap_jump()
	await tap_jump()
	player.set_flying(true)
	check(game.inventory.mode == "survival" and not player.flying and game.world.terrain_generation_version == 1, "Survival uses random terrain and cannot enable flight")
	var invalid: Dictionary = saved.data.duplicate(true)
	invalid.player.flying = "broken"
	check(not boot.save_system.world_validation_error(invalid).is_empty(), "Invalid saved flight values are rejected")
	invalid = saved.data.duplicate(true)
	invalid.world.terrain_generation_version = 99
	check(not boot.save_system.world_validation_error(invalid).is_empty(), "Unknown terrain generation versions are rejected")
	boot.queue_free()
	await process_frame
	print("RANDOM_WORLD_FLIGHT_SMOKE_PASS: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

func capture(game: Node3D) -> void:
	if not "--capture" in OS.get_cmdline_user_args():
		return
	var player = game.player
	player.set_flying(true)
	player.global_position.y = 18.0
	player.velocity = Vector3.ZERO
	player.rig.rotation.y = 0.7
	player.pitch.rotation.x = -0.42
	await frames(8)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("C:/Users/Qi/AppData/Local/Temp/opencode/random-world-creative-flight.png")

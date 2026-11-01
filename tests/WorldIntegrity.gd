extends SceneTree

const Saves = preload("res://scripts/system/SaveSystem.gd")
const Settings = preload("res://scripts/system/SettingsSystem.gd")
var checks: int = 0
var failures: int = 0

class TrackedWorld extends "res://scripts/world/VoxelWorld.gd":
	var rebuilds: int = 0
	func _rebuild_chunk_mesh(coord: Vector2i) -> void:
		rebuilds += 1
		super._rebuild_chunk_mesh(coord)

func _initialize() -> void:
	create_timer(30.0).timeout.connect(func(): push_error("WORLD_INTEGRITY_TIMEOUT"); quit(1))
	_run.call_deferred()

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(label)

func frames(amount: int) -> void:
	for i in amount:
		await physics_frame
	await process_frame

func action(name: String) -> InputEventAction:
	var event := InputEventAction.new()
	event.action = name
	event.pressed = true
	return event

func _run() -> void:
	var boot = preload("res://scenes/Boot.tscn").instantiate()
	boot.save_system = Saves.new("user://world_integrity.json")
	boot.settings_system = Settings.new("user://world_integrity_settings.json")
	root.add_child(boot)
	current_scene = boot
	boot._start_game({}, "creative", "infinite")
	var game = boot.game
	var start: Vector3 = game.player.global_position
	Input.action_press("move_forward")
	Input.action_press("jump")
	game.player._unhandled_input(action("switch_view"))
	game._input(action("blueprint"))
	await frames(8)
	Input.action_release("move_forward")
	Input.action_release("jump")
	check(game.is_loading and game.player.global_position == start, "Loading overlay freezes movement and gravity")
	check(not game.player.first_person and not game.hud.blueprint_workshop.visible, "Loading blocks view and workshop hotkeys")
	check(not game.save_progress(), "Loading cannot save a partially initialized session")
	while game.is_loading:
		await process_frame
	check(game.player.controls_enabled and not game.hud.loading_screen.visible, "Finished loading hands control back to the player")
	await frames(4)
	check(game.player.global_position.y >= 5.0, "Spawn collision exists before physics resumes")
	game.player._spawn_debris(game.player.global_position + Vector3.UP, Color.RED)
	game.player.target_cell = Vector3i(16, 4, 21)
	game.player.target_id = 1
	game.player._spawn_hit_spark()
	var effects: Array = []
	for entry in game.player.debris:
		effects.append(entry.node)
	boot._regenerate_game()
	await frames(2)
	check(effects.all(func(effect): return not is_instance_valid(effect)), "Regeneration releases both debris and hit sparks from the Boot entry")
	game = boot.game
	while game.is_loading:
		await process_frame
	game.player.set_physics_process(false)
	var x := 400
	var z := 400
	var ground: int = game.world._get_procedural_height(x, z) + 1
	game.player.global_position = Vector3(x + 0.5, ground + 0.01, z + 0.5)
	check(game.save_progress(), "Save a far-world position")
	boot._return_to_menu()
	await process_frame
	var began := Time.get_ticks_usec()
	boot._continue_game()
	var synchronous_ms := float(Time.get_ticks_usec() - began) / 1000.0
	game = boot.game
	var focus := Vector2i(25, 25)
	check(game != null and game.world._active_chunks.is_empty(), "Continue does not synchronously build 49 spawn chunks")
	await frames(2)
	check(game.world._active_chunks.has(focus) and not game.world._active_chunks.has(Vector2i(1, 1)), "The first loaded chunk is at the saved position")
	while game.is_loading:
		await process_frame
	check(game.world._active_chunks.size() == 49, "Prewarm completes the saved position's full view distance")
	await frames(10)
	check(game.player.global_position.y >= ground - 0.01, "Restored player lands on the nearby collision")
	print("WORLD_CONTINUE_SYNCHRONOUS_MS: ", synchronous_ms)
	boot.queue_free()
	await process_frame

	var world := TrackedWorld.new()
	world.world_type = "infinite"
	world.initial_load_position = Vector3(-320, 20, -320)
	root.add_child(world)
	world.set_process(false)
	await world.world_ready
	var coord := Vector2i(-20, -20)
	var stone := Vector3i(-312, 20, -312)
	var glass := stone + Vector3i.RIGHT
	var began_edits := world.rebuilds
	world.set_block(stone, 5)
	world.set_block(glass, 16)
	world.set_block(stone + Vector3i.UP, 7)
	world.set_block(stone + Vector3i.UP, 0)
	await frames(3)
	check(world.rebuilds == began_edits + 1, "Multiple edits in one chunk rebuild its mesh and collision once")
	var chunk: Dictionary = world._active_chunks[coord]
	check(chunk.glass.mesh != null and chunk.glass.material_override != chunk.visual.material_override, "Glass uses a separate transparent surface")
	check(chunk.glass.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX].size() == 20, "Glass next to stone keeps its five exposed faces")
	var opaque_vertices: PackedVector3Array = chunk.visual.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var stone_face_vertices := 0
	for vertex in opaque_vertices:
		if is_equal_approx(vertex.x, stone.x + 1) and vertex.y >= stone.y and vertex.y <= stone.y + 1 and vertex.z >= stone.z and vertex.z <= stone.z + 1:
			stone_face_vertices += 1
	check(stone_face_vertices >= 4, "Opaque neighbor keeps the face visible through glass")
	var from := Vector3(glass) + Vector3(0.5, 0.5, 3)
	var query := PhysicsRayQueryParameters3D.create(from, from + Vector3.FORWARD * 4, 1)
	var hit := world.get_world_3d().direct_space_state.intersect_ray(query)
	check(not hit.is_empty() and Vector3i((hit.position - hit.normal * 0.01).floor()) == glass, "Glass still blocks the targeting ray and physics")
	world.set_block(glass + Vector3i.RIGHT, 16)
	await frames(2)
	check(chunk.glass.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX].size() == 36, "Adjacent glass removes the shared interior faces")

	var edited := Vector3i(-1001, 21, -1001)
	world.set_block(edited, 7)
	for i in 10000:
		world.set_block(Vector3i(10000 + i, 21, 10000), 8)
	var data: Dictionary = world.save_data()
	world.load_data(data, Vector3(edited))
	check(world.get_block(edited) == 7, "Negative-coordinate edits survive a save/load")
	await world.world_ready
	var restored_coord := Vector2i(-63, -63)
	var restored: Dictionary = world._active_chunks[restored_coord]
	check(restored.blocks[world._chunk_local_index(7, 21, 7)] == 7, "Chunk edit index restores the same negative local cell")
	var timings: Array[float] = []
	for i in 5:
		var tick := Time.get_ticks_usec()
		world._generate_chunk_blocks(Vector2i(20, 20))
		timings.append(float(Time.get_ticks_usec() - tick) / 1000.0)
	print("WORLD_GENERATE_WITH_10000_EDITS_MS: ", timings)
	world.queue_free()
	await process_frame
	print("WORLD_INTEGRITY_PASS: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

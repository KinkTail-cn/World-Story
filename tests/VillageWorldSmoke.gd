extends SceneTree

const Houses = preload("res://scripts/world/HouseTemplates.gd")
const Villages = preload("res://scripts/world/VillageGenerator.gd")
const World = preload("res://scripts/world/VoxelWorld.gd")
const Saves = preload("res://scripts/system/SaveSystem.gd")
const Settings = preload("res://scripts/system/SettingsSystem.gd")
var checks: int = 0
var failures: int = 0

func _initialize() -> void:
	create_timer(38.0).timeout.connect(func(): push_error("VILLAGE_WORLD_TIMEOUT"); quit(1))
	_run.call_deferred()

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)

func frames(amount: int = 4) -> void:
	for index in amount:
		await process_frame

func _run() -> void:
	var boot = preload("res://scenes/Boot.tscn").instantiate()
	boot.save_system = Saves.new("user://village_world.json")
	boot.settings_system = Settings.new("user://village_settings.json")
	root.add_child(boot)
	current_scene = boot
	boot.menu._describe_choices()
	check(boot.menu.get_node("ModePopup/Card/Body/Seed").visible and not boot.menu.has_node("ModePopup/Card/Body/WorldType"), "Random creation exposes a reproducible seed without preset world choices")
	boot.menu.get_node("ModePopup/Card/Body/Seed").text = "invalid"
	boot.menu._start_selected_mode()
	check(boot.game == null and boot.menu.get_node("ModePopup/Card/Body/SeedError").visible, "Invalid seeds do not start or replace a world")
	boot.menu.get_node("ModePopup/Card/Body/Seed").text = "1337"
	# Keep the previous village-start format as a legacy fixture. New menu
	# worlds are covered by RandomWorldFlightSmoke and never force a village start.
	boot.menu.selected_world_seed = 1337
	boot._start_game({}, "creative", "village")
	var game = boot.game
	check(game != null and game.world_type == "village" and game.is_loading, "Legacy village sessions still load behind the loading screen")
	while game.is_loading:
		await process_frame
	var world = game.world
	var plan: Dictionary = world.starting_village
	check(not plan.is_empty(), "The terrain search finds a suitable real village")
	if plan.is_empty():
		quit(1)
		return
	await frames(8)
	check(plan.plaza.has_point(Vector2i(game.player.global_position.x, game.player.global_position.z)), "The player starts in the connected public square")
	check(game.player._can_occupy(game.player.global_position, false), "The spawn has standing clearance")
	check(not game.hud.get_node("Root/TopLeftPanel").visible and not game.hud.target.visible, "Village exploration preserves the clean gameplay HUD")
	check(world._modified_blocks.is_empty(), "Generated architecture does not become player edit history")
	var complete := true
	for building in plan.houses:
		complete = complete and world._active_chunks.has(world._chunk_coord(building.origin))
	check(complete and world._active_chunks.size() < 300, "The whole large village remains loaded at spawn within a bounded chunk budget")
	var within_height := true
	var chunk_agrees := true
	for building in plan.houses:
		var shape := Houses.oriented(building.style, building.variation, building.turns)
		within_height = within_height and building.origin.y + shape.size.y <= World.CHUNK_HEIGHT
		var entrance: Vector3i = building.entrance
		chunk_agrees = chunk_agrees and world.get_block(entrance) == 0 and world.get_block(entrance + Vector3i.UP) == 0 and world.get_block(entrance + Vector3i.DOWN) > 0
		var edge: Vector3i = building.origin
		var coord: Vector2i = world._chunk_coord(edge)
		var generated: PackedByteArray = world._generate_chunk_blocks(coord)
		for y in range(building.origin.y, building.origin.y + shape.size.y):
			chunk_agrees = chunk_agrees and int(generated[world._chunk_local_index(posmod(edge.x, 16), y, posmod(edge.z, 16))]) == world.get_block(Vector3i(edge.x, y, edge.z))
	check(within_height and chunk_agrees, "House height, unloaded queries and chunk arrays agree at boundaries")
	# Walk the real capsule from a lane through a front door; a visual gap alone
	# would not catch a roof, collision or one-block threshold obstructing entry.
	var house: Dictionary = plan.houses[0]
	var house_bounds: Rect2i = house.bounds.grow(8)
	for z in range(floori(float(house_bounds.position.y) / 16), floori(float(house_bounds.end.y - 1) / 16) + 1):
		for x in range(floori(float(house_bounds.position.x) / 16), floori(float(house_bounds.end.x - 1) / 16) + 1):
			world._load_or_create_chunk(Vector2i(x, z))
	await physics_frame
	var door_key := "v:%d:%d:door:0:0" % [plan.region.x, plan.region.y]
	check(world.life.records.has(door_key) and world.life.set_door_open(door_key, true).ok, "The generated house has a real door that can be opened")
	for tick in range(18): await physics_frame
	var facing := Vector3(house.facing.x, 0, house.facing.y)
	var doorway := Vector3(house.door) + Vector3(0.5, 0.02, 0.5)
	game.player.global_position = doorway + facing * 2.4
	game.player.velocity = Vector3.ZERO
	game.player.rig.rotation.y = atan2(facing.x, facing.z)
	Input.action_press("move_forward")
	for tick in range(62):
		await physics_frame
	Input.action_release("move_forward")
	check((game.player.global_position - doorway).dot(facing) < -0.3 and game.player.is_on_floor(), "A real player can walk from the street into a house")
	game.player.set_physics_process(false)
	await capture_village(game, plan)
	var shape := Houses.oriented(house.style, house.variation, house.turns)
	var roof_cell := Vector3i.ZERO
	for cell in shape.cells:
		if cell.y > roof_cell.y:
			roof_cell = cell
	roof_cell += Vector3i(house.origin)
	var original_roof: int = world.get_block(roof_cell)
	check(original_roof > 0 and world.set_block(roof_cell, 0), "Village roofs are ordinary mineable world blocks")
	var marker := Vector3i(plan.centre.x - 3, plan.floor_y + 1, plan.centre.y - 3)
	check(world.set_block(marker, 14) and world._modified_blocks.size() == 2, "Only the player's removal and construction enter edit history")
	check(game.save_progress(), "A village game saves through the normal lifecycle")
	var saved: Dictionary = boot.save_system.load_world()
	check(saved.ok and saved.data.world.world_type == "village" and saved.data.world.village_generation_version == 1, "The save preserves village mode, generator version and seed")
	boot._return_to_menu()
	await frames()
	boot._continue_game()
	game = boot.game
	while game.is_loading:
		await process_frame
	world = game.world
	game.player.set_physics_process(false)
	check(world.starting_village == plan, "Continuing regenerates the same village and home square")
	check(world.get_block(roof_cell) == 0 and world.get_block(marker) == 14, "Continuing preserves removed roofs and newly placed blocks")
	var home: Vector3 = world.get_spawn_position()
	check(plan.plaza.has_point(Vector2i(home.x, home.z)), "Return-home still targets the saved village")
	# Check a generated house outside the active view in both directions, then load
	# its chunk: occlusion queries and full chunks must use the same structure data.
	var coord: Vector2i = world._chunk_coord(roof_cell)
	var chunk_node: Node3D = world._active_chunks[coord].node
	chunk_node.queue_free()
	world._active_chunks.erase(coord)
	check(world.get_block(roof_cell) == 0, "Unloading does not resurrect a removed building cube")
	world._load_or_create_chunk(coord)
	check(world.get_block(roof_cell) == 0, "Reloading the chunk applies player edits after generated architecture")
	var legacy_data: Dictionary = saved.data.world.duplicate(true)
	legacy_data.erase("village_generation_version")
	legacy_data.erase("village_home")
	legacy_data.world_type = "infinite"
	var legacy := World.new()
	root.add_child(legacy)
	legacy.set_process(false)
	legacy.load_data(legacy_data, Vector3(marker))
	check(legacy.village_generation_version == 0 and legacy.villages._regions.is_empty(), "Pre-village saves preserve their original procedural landscape")
	check(legacy.get_block(marker) == 14, "Legacy compatibility preserves player-authored blocks")
	var malformed: Dictionary = saved.data.duplicate(true)
	malformed.world.village_generation_version = 99
	check(not boot.save_system.world_validation_error(malformed).is_empty(), "Unknown generation versions are rejected before terrain changes")
	malformed = saved.data.duplicate(true)
	malformed.world.village_home = [1, "bad"]
	check(not boot.save_system.world_validation_error(malformed).is_empty(), "Malformed village home data is rejected")
	legacy.queue_free()
	boot.queue_free()
	await frames()
	if "--capture" in OS.get_cmdline_user_args():
		for path in ["HouseStylesPreview", "VillagePreview"]:
			var gallery = load("res://scenes/" + path + ".tscn").instantiate()
			root.add_child(gallery)
			await gallery.showcase_ready
			await frames(8)
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("C:/Users/Qi/AppData/Local/Temp/opencode/village-" + path + ".png")
			gallery.queue_free()
			await frames()
	print("VILLAGE_WORLD_SMOKE_PASS: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

func capture_village(game: Node3D, plan: Dictionary) -> void:
	if not "--capture" in OS.get_cmdline_user_args():
		return
	game.world.set_process(false)
	var bounds: Rect2i = plan.bounds.grow(16)
	for z in range(floori(float(bounds.position.y) / 16), floori(float(bounds.end.y - 1) / 16) + 1):
		for x in range(floori(float(bounds.position.x) / 16), floori(float(bounds.end.x - 1) / 16) + 1):
			game.world._load_or_create_chunk(Vector2i(x, z))
		await process_frame
	var camera := Camera3D.new()
	game.add_child(camera)
	var middle := Vector3(plan.centre.x, plan.floor_y + 4, plan.centre.y)
	var span := float(maxi(plan.bounds.size.x, plan.bounds.size.y))
	camera.position = middle + Vector3(0.55, 0.5, 0.75) * span
	camera.look_at(middle)
	camera.far = 1400
	camera.current = true
	game.hud.visible = false
	game.sky_atmosphere.visible = false
	var previous_fog: bool = game.environment.environment.fog_enabled
	game.environment.environment.fog_enabled = false
	await frames(8)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("C:/Users/Qi/AppData/Local/Temp/opencode/village-world-overview.png")
	camera.position = middle + Vector3(-1, -1.7, 4)
	var toward: Vector2i = plan.waypoints[0]
	camera.look_at(Vector3(toward.x, plan.floor_y + 2, toward.y))
	await frames(6)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("C:/Users/Qi/AppData/Local/Temp/opencode/village-street-view.png")
	var house: Dictionary = plan.houses[1]
	var door_key := "v:%d:%d:door:1:0" % [plan.region.x, plan.region.y]
	if game.world.life.records.has(door_key):
		var record: Dictionary = game.world.life.records[door_key]
		var root_transform := preload("res://scripts/world/DoorGeometry.gd").transform_for(record)
		var facing := Vector3(house.facing.x, 0, house.facing.y)
		camera.position = root_transform.origin + facing * 5.0 + root_transform.basis.x * 0.15 + Vector3.UP * 1.6
		camera.look_at(root_transform.origin + Vector3.UP * 1.4)
		await frames(6)
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("C:/Users/Qi/AppData/Local/Temp/opencode/wooden-door-village.png")
	camera.queue_free()
	game.player.camera.current = true
	game.hud.visible = true
	game.sky_atmosphere.visible = true
	game.environment.environment.fog_enabled = previous_fog
	game.world.set_process(true)
	await frames()

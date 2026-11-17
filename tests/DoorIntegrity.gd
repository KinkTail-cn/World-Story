extends SceneTree

const Inventory = preload("res://scripts/inventory/Inventory.gd")
const Door = preload("res://scripts/world/DoorGeometry.gd")
const Houses = preload("res://scripts/world/HouseTemplates.gd")
const Data = preload("res://scripts/world/FacilityData.gd")
var checks: int = 0
var failures: int = 0

func _initialize() -> void:
	create_timer(38.0).timeout.connect(func(): push_error("DOOR_INTEGRITY_TIMEOUT"); quit(1))
	_run.call_deferred()

func check(value: bool, text: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(text)

func frames(count: int = 4) -> void:
	for index in count: await physics_frame

func key(code: int) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = true
	root.push_input(event, true)
	event = event.duplicate()
	event.pressed = false
	root.push_input(event, true)

func _run() -> void:
	var supplies := Inventory.new("survival")
	supplies.add_item(7, 1)
	supplies.add_item(601, 1)
	supplies.add_item(602, 1)
	check(supplies.prepare_recipe("7,601,602") and supplies.take_result() and supplies.count_item(510) == 1, "Wood, stick and hinge material craft a real double door")
	var authored := preload("res://scripts/blueprint/UtilityPresets.gd").design(510)
	check(preload("res://scripts/blueprint/BlueprintEquipment.gd").validation_error(authored).is_empty(), "The door's complete cube model is editable and craftable")
	for style in Houses.STYLES:
		var source := Houses.model(style)
		check(source.doors.size() == (2 if style == "courtyard" else 1), "All entrances, including the courtyard annex, declare door anchors")
		for turns in range(4):
			var oriented := Houses.oriented(style, 0, turns)
			check(oriented.doors.size() == source.doors.size(), "Door metadata survives every house rotation")
	var game = preload("res://scenes/Main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	while game.is_loading: await process_frame
	var world = game.world
	var life = world.life
	world.world_type = "infinite"
	world.set_process(false)
	life.set_process(false)
	var player = game.player
	player.set_physics_process(false)
	player.global_position = Vector3(40.5, 6.02, 48.5)
	for z in range(36, 54):
		for x in range(36, 62):
			world.set_block(Vector3i(x, 5, z), 14)
			for y in range(6, 12): world.set_block(Vector3i(x, y, z), 0)
	for z in range(2, 4):
		for x in range(2, 4): world._load_or_create_chunk(Vector2i(x, z))
	# Recreate the actual two-wide, three-high house aperture.
	for x in range(42, 48):
		for y in range(6, 10):
			if x not in [44, 45] or y == 9: world.set_block(Vector3i(x, y, 44), 7)
	await frames()
	var away := AABB(Vector3(-100, 50, -100), Vector3.ONE)
	var placed: Dictionary = life.place({"id": 510, "count": 1}, Vector3i(44, 5, 44), away)
	check(placed.ok, "A door places into the real house-sized aperture")
	if not placed.ok: quit(1); return
	var door_key: String = placed.record.key
	var record: Dictionary = life.records[door_key]
	await frames()
	check(not record.opened and life.nodes[door_key].leaves.size() == 2, "New doors start closed with two physical hinged leaves")
	player.global_position = Vector3(45, 6.02, 47)
	player.velocity = Vector3.ZERO
	player.rig.rotation.y = 0.0
	player.set_physics_process(true)
	Input.action_press("move_forward")
	await frames(45)
	Input.action_release("move_forward")
	check(player.global_position.z > 44.7, "A closed door blocks the actual walking capsule")
	player.set_first_person(true)
	player.pitch.rotation.x = 0.0
	player._resolve_camera_collision()
	player._update_target()
	check(player.target_facility == door_key, "The real aim ray identifies the door leaf for interaction")
	Input.action_press("place")
	await frames(36)
	Input.action_release("place")
	check(record.opened, "Holding right-click toggles a door once and does not repeatedly reverse it")
	game._open_facility(door_key)
	await frames(18)
	check(not record.opened, "A new interaction closes the door after the held click ends")
	player._update_target()
	key(KEY_R)
	await frames(18)
	check(record.opened and player.controls_enabled and not game.facility_panel.visible and not paused, "Physical R opens the door directly without a menu or pause")
	check(absf(life.nodes[door_key].leaves[0].rotation.y - PI * 0.5) < 0.01, "The visible leaf reaches its hinged open pose")
	await capture(game, door_key, "open")
	Input.action_press("move_forward")
	await frames(42)
	Input.action_release("move_forward")
	check(player.global_position.z < 43.5 and player.is_on_floor(), "An opened door leaves a usable passage through the real wall")
	player.set_physics_process(false)
	player.global_position = Vector3(45, 6.02, 44.5)
	player.velocity = Vector3.ZERO
	await frames(3)
	check(not life.set_door_open(door_key, false).ok and record.opened, "Closing is rejected when the player stands in the opening arc")
	player.global_position = Vector3(40, 6.02, 48)
	await frames(3)
	check(life.set_door_open(door_key, false).ok, "A clear opening can be closed again")
	await frames(18)
	await capture(game, door_key, "closed")
	check(not world.set_block(Vector3i(44, 5, 44), 0) and not world.set_block(Vector3i(45, 5, 44), 0), "Both supporting floor blocks are protected")
	check(not world.set_block(Vector3i(44, 7, 44), 5), "Building cannot bury the doorway")
	for turns in range(1, 4):
		var support := Vector3i(52 + turns * 2, 5, 48)
		var result: Dictionary = life.place({"id": 510, "count": 1}, support, away, turns)
		check(result.ok, "Player-built doors support quarter-turn orientation " + str(turns))
		if result.ok:
			await frames(2)
			check(life.set_door_open(result.record.key, true).ok, "Rotated door sweeps remain functional")
			await frames(18)
	var previous: Dictionary = life.save_data()
	check(Data.validation_error(previous).is_empty(), "Door state passes facility save validation")
	check(game.save_progress() and game.save_system.load_world().ok, "Door states round-trip through a real JSON world save")
	var saved: Dictionary = game.save_system.load_world().data.world.village_life
	life.load_data(saved)
	await frames(3)
	life.refresh()
	await frames(3)
	check(not life.records[door_key].opened and life.nodes[door_key].leaves[0].rotation.y == 0, "Reload restores closed appearance and collision immediately")
	check(life.set_door_open(door_key, true).ok, "A restored door can be opened")
	await frames(18)
	check(life.set_door_open(door_key, false).ok, "Prepare a closed passage for a resident")
	await frames(18)
	var resident = preload("res://scripts/world/VillageResident.gd").new()
	resident.record = {"key": "test:door-resident", "kind": "resident", "role": "farmer", "support": [45, 5, 46], "position": [45, 6.02, 46], "route": [[45, 6.02, 46], [45, 6.02, 42.4]], "stock": {}, "restock_at": life.clock + 300.0}
	resident.world = world
	life.records[resident.record.key] = resident.record
	life.add_child(resident)
	resident.global_position = Vector3(45, 6.02, 46)
	resident.rest = 0.0
	life.nodes[resident.record.key] = resident
	await frames(210)
	check(life.records[door_key].opened and resident.global_position.z < 44.0 and life.door_release.has(door_key), "A walking resident opens the closed door and passes through its actual collision")
	resident.set_physics_process(false)
	resident.global_position = Vector3(45, 6.02, 42.4)
	await frames(2)
	life.clock += 2.0
	life._process(0.01)
	await frames(18)
	check(not life.records[door_key].opened, "A door used by residents closes again after the passage clears")
	var custom_item := preload("res://scripts/blueprint/BlueprintEquipment.gd").make_item(authored)
	var custom: Dictionary = life.place(custom_item, Vector3i(39, 5, 39), away)
	check(custom.ok and custom.record.item.blueprint == custom_item.blueprint, "A crafted custom door places with its original blueprint")
	if custom.ok:
		await frames(3)
		check(life.set_door_open(custom.record.key, true).ok, "Custom-model leaves retain the same opening function")
		await frames(18)
		check(life.pickup(custom.record.key, game.inventory).ok and game.inventory.bag.any(func(item: Dictionary): return item.id == 510 and item.get("blueprint", {}) == custom_item.blueprint), "Recovering a custom door preserves its authored appearance")
	var full := Inventory.new("survival")
	for index in full.bag.size(): full.bag[index] = {"id": 301, "count": 1}
	check(not life.pickup(door_key, full).ok and not life.records[door_key].get("removed", false), "A full bag leaves a mined door in place")
	check(life.pickup(door_key, game.inventory).ok and life.records[door_key].removed, "A door can be recovered as a real inventory item")
	check(world.set_block(Vector3i(44, 5, 44), 0), "Removing a door releases its supporting floor")
	var invalid := previous.duplicate(true)
	invalid.objects[0].opened = "invalid"
	check(not Data.validation_error(invalid).is_empty(), "Corrupt door switch states are rejected")
	game.queue_free()
	await frames(4)
	print("DOOR_INTEGRITY_PASS: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

func capture(game: Node3D, door_key: String, tag: String) -> void:
	if not "--capture" in OS.get_cmdline_user_args(): return
	var camera := Camera3D.new()
	game.add_child(camera)
	camera.position = Vector3(47.5, 7.8, 49.5)
	camera.look_at(Vector3(45, 7.4, 44.5))
	camera.current = true
	game.hud.visible = false
	await frames(3)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("C:/Users/Qi/AppData/Local/Temp/opencode/wooden-door-" + tag + ".png")
	camera.queue_free()
	game.player.camera.current = true
	game.hud.visible = true

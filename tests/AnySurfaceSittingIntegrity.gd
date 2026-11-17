extends SceneTree

var checks: int = 0
var failures: int = 0

func _initialize() -> void:
	create_timer(35.0).timeout.connect(func(): push_error("ANY_SURFACE_SITTING_TIMEOUT"); quit(1))
	_run.call_deferred()

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)

func frames(count: int = 4) -> void:
	for index in count: await physics_frame

func right_click() -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_RIGHT
	event.position = root.get_visible_rect().size * 0.5
	event.global_position = event.position
	event.pressed = true
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	await process_frame
	await frames(3)
	event = event.duplicate()
	event.pressed = false
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	await process_frame
	await frames(2)

func aim(player: Node3D, origin: Vector3, point: Vector3) -> void:
	player.global_position = origin
	player.velocity = Vector3.ZERO
	player.set_first_person(true)
	var offset := point - (origin + Vector3(0, 1.6, 0))
	player.rig.rotation.y = atan2(-offset.x, -offset.z)
	player.pitch.rotation.x = atan2(offset.y, Vector2(offset.x, offset.z).length())
	player._resolve_camera_collision()
	player._update_target()
	player.select_function(1)
	await frames(3)

func _run() -> void:
	var game = preload("res://scenes/Main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	while game.is_loading: await process_frame
	var player = game.player
	var world = game.world
	var life = world.life
	world.world_type = "infinite"
	world.set_process(false)
	life.set_process(false)
	player.set_physics_process(false)
	for z in range(39, 57):
		for x in range(39, 70):
			world.set_block(Vector3i(x, 5, z), 1)
			for y in range(6, 14): world.set_block(Vector3i(x, y, z), 0)
	for z in range(2, 4):
		for x in range(2, 5): world._load_or_create_chunk(Vector2i(x, z))
	await frames()
	player.global_position = Vector3(42.5, 6.02, 45)
	player.set_physics_process(true)
	await aim(player, Vector3(42.5, 6.02, 45), Vector3(42.72, 6, 42.78))
	var floor_point: Vector3 = player.target_hit.get("position", Vector3.ZERO)
	await right_click()
	check(player.sitting and player.seat_cell == Vector3i(42, 5, 42), "A real right click sits on ordinary continuous ground")
	check(player.global_position.distance_to(floor_point + Vector3.UP * 0.01) < 0.025, "The seat uses the actual aimed position instead of snapping to the block centre")
	var feet_clear := true
	for leg in [player.visual.left_lower_leg, player.visual.right_lower_leg]:
		for mesh in leg.find_children("*", "MeshInstance3D", true, false):
			if not mesh.visible: continue
			feet_clear = feet_clear and (mesh.global_transform * mesh.mesh.get_aabb()).position.y >= player.global_position.y - 0.015
	check(player.visual.seat_feet_supported and feet_clear, "Ground sitting extends both lower legs above the floor instead of burying them")
	await capture(game, "ground")
	check(player._stand_up(), "Standing from plain ground succeeds")
	# A low ceiling and a nearby wall must not gate the sitting action.
	for x in range(41, 44):
		for z in range(46, 49): world.set_block(Vector3i(x, 7, z), 7)
	world.set_block(Vector3i(43, 6, 47), 5)
	await frames()
	player.set_physics_process(false)
	player.global_position = Vector3(40.5, 6.02, 47.5)
	var return_position: Vector3 = player.global_position
	player.target_id = 1
	player.target_cell = Vector3i(42, 5, 47)
	player.target_hit = {}
	player.target_facility = ""
	player.select_function(1)
	player._place()
	check(player.sitting and not player._can_occupy(player.global_position, true), "Low headroom and a wall in front no longer reject sitting")
	player.set_physics_process(true)
	await frames()
	check(player.sitting, "A cramped seat stays seated during the real player update")
	await capture(game, "low-ceiling")
	check(player._stand_up() and player.global_position.distance_to(return_position) < 0.01, "When there is no standing room, getting up can return to the previous standing position")
	for y in range(6, 9): world.set_block(Vector3i(46, y, 42), 7)
	await frames()
	await aim(player, Vector3(44.5, 6.02, 42.5), Vector3(46.2, 6.5, 42.5))
	check(player.target_cell.y == 6, "The real aim ray hits the side of a stacked block column")
	await right_click()
	check(player.sitting and player.seat_cell == Vector3i(46, 8, 42) and absf(player.global_position.y - 9.01) < 0.02, "Side hits resolve to the top of stairs, walls and roofs instead of rejecting the seat")
	await capture(game, "roof")
	check(player._stand_up(), "The player can stand on the roof after sitting")
	var away := AABB(Vector3(-100, 50, -100), Vector3.ONE)
	var keys := {}
	for entry in [[501, 47, 47, 0.64], [502, 50, 47, 0.8], [503, 53, 47, 0.47], [504, 56, 47, 0.49], [505, 59, 47, 0.32], [506, 62, 47, 0.65], [507, 47, 52, 0.24], [508, 51, 52, 1.5], [509, 56, 52, 0.77], [510, 61, 52, 1.3]]:
		var placed: Dictionary = life.place({"id": entry[0], "count": 1}, Vector3i(entry[1], 5, entry[2]), away)
		check(placed.ok, "A surface test uses a real placed facility: " + str(entry[0]))
		if not placed.ok: continue
		var record: Dictionary = placed.record
		keys[entry[0]] = record.key
		var pos := Vector3(record.position[0], record.position[1], record.position[2])
		await aim(player, Vector3(pos.x, 6.02, pos.z - 2.4), pos + Vector3(0, entry[3], 0))
		check(player.target_facility == record.key, "The real camera ray identifies the facility surface: " + str(entry[0]))
		await right_click()
		check(player.sitting and player.seat_support != null and not game.facility_panel.visible, "Sitting mode takes precedence on every facility surface: " + str(entry[0]))
		if entry[0] == 504:
			check(absf(player.global_position.y - pos.y - 0.53) < 0.02 and life.nodes[record.key].effects.seated_actor != null, "A chair uses its cushion and receives its sitting animation")
		if entry[0] == 509: await capture(game, "workbench")
		check(player._stand_up(), "Getting up from the facility succeeds: " + str(entry[0]))
	var custom: Dictionary = life.place(preload("res://scripts/blueprint/BlueprintEquipment.gd").make_item(preload("res://scripts/blueprint/UtilityPresets.gd").design(509)), Vector3i(65, 5, 52), away)
	check(custom.ok, "A custom blueprint supplies a working seating surface")
	if custom.ok:
		var pos := Vector3(custom.record.position[0], custom.record.position[1], custom.record.position[2])
		await aim(player, Vector3(pos.x, 6.02, pos.z - 2.4), pos + Vector3(0, 0.8, 0))
		await right_click()
		check(player.sitting and player.seat_support != null, "Custom authored furniture can be sat on through the same right click")
		check(player._stand_up(), "Custom furniture releases the seated player")
	var body := AnimatableBody3D.new()
	body.sync_to_physics = false
	body.collision_layer = 1
	var shape := CollisionShape3D.new()
	var cube := BoxShape3D.new()
	cube.size = Vector3.ONE * 0.65
	shape.shape = cube
	body.add_child(shape)
	game.add_child(body)
	body.global_position = Vector3(64.5, 6.325, 43.5)
	await frames()
	await aim(player, Vector3(64.5, 6.02, 41), body.global_position)
	await right_click()
	check(player.sitting and player.seat_support != null and player.global_position.y > 6.65, "An unlabelled physical surface also supports sitting")
	var seated_position: Vector3 = player.global_position
	body.global_position += Vector3(0.2, 0.1, 0)
	await frames()
	check(player.global_position.distance_to(seated_position + Vector3(0.2, 0.1, 0)) < 0.01, "A seat follows its supporting object's movement")
	body.queue_free()
	await frames()
	check(not player.sitting, "Removing a supporting object releases the seat")
	await aim(player, Vector3(42.35, 6.02, 44.2), Vector3(42.35, 20, 43))
	check(player.target_hit.is_empty(), "The player looks at the sky rather than a preselected surface")
	await right_click()
	check(player.sitting and player.global_position.distance_to(Vector3(42.35, 6.01, 44.2)) < 0.025, "Right click without an aimed surface sits on the floor at the current location")
	check(player._stand_up(), "The player can get up from an in-place floor seat")
	player.set_physics_process(false)
	player.global_position = Vector3(42.5, 18, 44.5)
	player.target_hit = {}
	player.target_id = 0
	player.target_facility = ""
	player.set_flying(true)
	player.select_function(1)
	player._place()
	player.set_physics_process(true)
	await frames()
	check(player.sitting and player.seat_in_place and not player.flying and absf(player.global_position.y - 18) < 0.01, "Even without a surface underfoot the player can sit in place")
	paused = true
	var paused_position: Vector3 = player.global_position
	await frames()
	check(player.sitting and player.global_position == paused_position, "A paused game keeps the current sitting pose and location")
	paused = false
	check(player._stand_up(), "The player can leave a seat without a supporting surface")
	player.set_physics_process(false)
	check(game.save_progress() and game.save_system.load_world().ok, "Surface seating remains compatible with the normal world save")
	game.queue_free()
	await frames()
	print("ANY_SURFACE_SITTING_INTEGRITY_PASS: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

func capture(game: Node3D, tag: String) -> void:
	if not "--capture" in OS.get_cmdline_user_args(): return
	var first_person: bool = game.player.first_person
	game.player.set_first_person(false)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 3.8
	game.add_child(camera)
	var centre: Vector3 = game.player.global_position + Vector3(0, 0.5, 0)
	camera.global_position = centre + Vector3(2.4, 1.4, 2.2)
	camera.look_at(centre)
	camera.current = true
	game.player.visual.show()
	game.hud.hide()
	await frames(3)
	game.player.visual.show()
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("C:/Users/Qi/AppData/Local/Temp/opencode/sitting-anywhere-" + tag + ".png")
	game.hud.show()
	camera.queue_free()
	game.player.camera.current = true
	game.player.set_first_person(first_person)

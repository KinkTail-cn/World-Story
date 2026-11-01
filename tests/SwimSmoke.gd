extends SceneTree

func _initialize() -> void:
	create_timer(25.0).timeout.connect(func():
		push_error("SWIM_SMOKE_TIMEOUT")
		quit(1)
	)
	_run.call_deferred()

func _run() -> void:
	var main = load("res://scenes/Main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	var player = main.get_node("Player")
	var world = main.get_node("World")
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	for frame in range(90):
		await physics_frame
	assert(player.is_on_floor() and not player.swimming, "Land movement must remain dry")
	assert(not world.is_water_at(Vector3(16.5, 2.0, 21.5)), "Solid island cells are not water")
	player.position = Vector3(16.5, 3.1, 30.5)
	player.velocity = Vector3.ZERO
	player.rig.rotation.y = PI
	Input.action_press("move_forward")
	for frame in range(95):
		await physics_frame
	Input.action_release("move_forward")
	assert(player.position.z > 33.0 and player.swimming, "Walking off the beach must enter swimming beyond the island")
	for frame in range(70):
		await physics_frame
	assert(absf(player.position.y - (world.SEA_LEVEL - 1.25)) < 0.25, "Idle swimmer must float at the surface")
	assert(not player.submerged, "Idle swimmer must keep their head above water")
	var surface_y: float = player.position.y
	Input.action_press("dive")
	for frame in range(80):
		await physics_frame
	Input.action_release("dive")
	assert(player.position.y < surface_y - 2.5 and player.submerged, "Dive must move the player underwater")
	for frame in range(35):
		await physics_frame
	var hover_y: float = player.position.y
	for frame in range(40):
		await physics_frame
	assert(absf(player.position.y - hover_y) < 0.15, "Release controls underwater to hover without sinking")
	assert(player.position.y < 0.0 and player.position.z > 32.0, "Diving outside the island must not trigger respawn")
	player.rig.rotation.y = 0.0
	player.pitch.rotation.x = -0.6
	var before: Vector3 = player.position
	Input.action_press("move_forward")
	for frame in range(30):
		await physics_frame
	Input.action_release("move_forward")
	assert(player.position.z < before.z - 0.7 and player.position.y < before.y - 0.4, "Underwater forward movement must follow the look direction")
	player.position = Vector3(16.5, -4.0, 42.0)
	player.velocity = Vector3.ZERO
	player.pitch.rotation.x = 0.0
	Input.action_press("jump")
	var highest: float = -100.0
	for frame in range(160):
		await physics_frame
		highest = maxf(highest, player.position.y)
	Input.action_release("jump")
	assert(highest > 2.8, "Ascend must reach and jump out of the water")
	player.position = Vector3(1200, -10, 1200)
	player.velocity = Vector3.ZERO
	for frame in range(12):
		await physics_frame
	assert(player.swimming and player.position.x > 1000.0, "Ocean swimming must continue far outside the island")
	assert(absf(world.get_node("Water").global_position.x - player.camera.global_position.x) < 128.0, "Ocean rendering must follow distant exploration")
	player.position = Vector3(40, -12, 40)
	player.velocity = Vector3.ZERO
	Input.action_press("dive")
	for frame in range(140):
		await physics_frame
	Input.action_release("dive")
	assert(player.position.y >= world.SEA_FLOOR - 0.02 and player.position.y < world.SEA_FLOOR + 0.2, "Seabed collision must stop descent without respawning")
	Input.action_press("jump")
	for frame in range(40):
		await physics_frame
	Input.action_release("jump")
	assert(player.position.y > world.SEA_FLOOR + 1.0, "Swimmer must be able to ascend from the seabed")
	var view_event := InputEventAction.new()
	view_event.action = "switch_view"
	view_event.pressed = true
	player._unhandled_input(view_event)
	for frame in range(3):
		await physics_frame
	assert(player.first_person_item.is_visible_in_tree() and main.get_node("HUD/Root/Underwater").visible, "First-person diving must show the held block and underwater tint")
	player._unhandled_input(view_event)
	player.position = Vector3(16.5, 0.8, 32.2)
	player.velocity = Vector3.ZERO
	player.rig.rotation.y = 0.0
	player.pitch.rotation.x = 0.0
	Input.action_press("move_forward")
	Input.action_press("jump")
	for frame in range(80):
		await physics_frame
	Input.action_release("move_forward")
	Input.action_release("jump")
	assert(player.position.z < 30.0 and player.position.y > 2.8, "Swimming and jumping must allow returning to the beach")
	for frame in range(60):
		await physics_frame
	assert(player.is_on_floor() and not player.swimming, "Landing on shore must restore land movement")
	assert(absf(player.visual.body.rotation.x) < 0.03, "Swimming pose must reset on land")
	if "--capture" in OS.get_cmdline_user_args():
		player.position = Vector3(16.5, 0.95, 39.0)
		player.velocity = Vector3.ZERO
		player.rig.rotation.y = 0.0
		player.pitch.rotation.x = -0.12
		Input.action_press("move_forward")
		for frame in range(20):
			await physics_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("C:/Users/Qi/AppData/Local/Temp/opencode/world-story-swimming.png")
		Input.action_release("move_forward")
		player.position = Vector3(16.5, -4, 39.0)
		player.velocity = Vector3.ZERO
		player.pitch.rotation.x = -0.15
		for frame in range(15):
			await physics_frame
		assert(main.get_node("HUD/Root/Underwater").visible, "Underwater camera must enable the tint")
		assert(main.get_node("HUD/Root/TopRight/Depth").visible, "Diving must show depth")
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("C:/Users/Qi/AppData/Local/Temp/opencode/world-story-diving.png")
	print("SWIM_SMOKE_PASS: beach entry, offshore movement, buoyancy, dive, hover, look direction, ascent, ocean range, seabed, first-person diving, return to shore")
	quit(0)

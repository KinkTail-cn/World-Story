extends SceneTree

var failures: int = 0
var checks: int = 0
var game
var player
var world

func _initialize() -> void:
	create_timer(30.0).timeout.connect(func(): push_error("CAMERA_COLLISION_TIMEOUT"); quit(1))
	_run.call_deferred()

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(label)

func _run() -> void:
	game = preload("res://scenes/Main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	player = game.player
	world = game.world
	for frame in range(75):
		await physics_frame
	player.set_physics_process(false)
	player.velocity = Vector3.ZERO
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	player.position = Vector3(16.5, 5.01, 21.5)
	player.rig.rotation.y = 0.0
	player.pitch.rotation.x = -0.12
	await _settle()
	check(player.camera.global_position.distance_to(player.rig.global_position) > 3.0 and player.visual.visible, "Open space retains a full third-person view")
	check(_safe_camera(), "Open-space near plane is unobstructed")

	# Real exposed-face voxel meshes reproduce the original bug: with an
	# offset pivot the sweep used to start inside this right-side wall.
	for z in range(18, 27):
		for y in range(5, 10):
			world.set_block(Vector3i(17, y, z), 7)
	await _settle()
	check(_safe_camera(), "Right-side wall keeps the lens and near plane on the player's side")
	check(player.camera.global_position.x < 17.0 and player.camera.global_position.distance_to(player.rig.global_position) < 1.3, "Shoulder offset retracts together with the boom")
	check(not player.visual.visible, "A collapsed view hides the body before the head fills the screen")
	await _capture("side")
	player.position.x = 16.64
	for pitch_angle in [-1.20, -0.30, 0.55, 1.10]:
		player.pitch.rotation.x = pitch_angle
		for step in range(24):
			player.rig.rotation.y = TAU * float(step) / 24.0
			await _settle()
			check(_safe_camera(), "Side wall: orbit %d at pitch %.2f" % [step, pitch_angle])

	# A rear wall and opposing side form a narrow corner/corridor.
	for y in range(5, 10):
		for x in range(14, 18):
			world.set_block(Vector3i(x, y, 23), 5)
		for z in range(18, 24):
			world.set_block(Vector3i(15, y, z), 7)
	player.position = Vector3(16.5, 5.01, 22.64)
	player.pitch.rotation.x = -0.12
	player.rig.rotation.y = 0.0
	await _settle()
	check(_safe_camera(), "Rear wall and corner keep all near-plane corners outside the terrain")
	await _capture("corner")
	for step in range(32):
		player.rig.rotation.y = TAU * float(step) / 32.0
		# Resolve before another physics frame to cover mouse motion at render
		# rates above the physics tick, including sudden 180-degree turns.
		player._process(0.0)
		check(_safe_camera(), "Immediate render correction at corner angle %d" % step)
		await _settle()
		check(_safe_camera(), "Physics correction at corner angle %d" % step)

	for z in range(19, 23):
		world.set_block(Vector3i(16, 7, z), 7)
	player.position = Vector3(16.5, 5.01, 21.5)
	for pitch_angle in [-1.25, -0.35, 0.6, 1.15]:
		player.pitch.rotation.x = pitch_angle
		player.rig.rotation.y = 0.0
		await _settle()
		check(_safe_camera(), "Low ceiling/floor at pitch %.2f" % pitch_angle)
	await _capture("ceiling")

	for iteration in range(6):
		player.set_first_person(true)
		await _settle()
		check(_safe_camera() and player.camera.global_position.distance_to(player.rig.global_position) < 0.001, "First person remains at the eyes near walls")
		check(not player.visual.visible and player.first_person_item.visible, "First-person visibility remains correct")
		player.set_first_person(false)
		await _settle()
		check(_safe_camera(), "Switching back to third person preserves collision")
		check(player.camera.global_basis.is_equal_approx(player.pitch.global_basis), "Repeated view changes keep aim aligned without rotation drift")

	player.sitting = true
	player._update_camera_height()
	await _settle()
	check(is_equal_approx(player.rig.position.y, 0.95) and _safe_camera(), "Seated camera uses the same wall protection")
	player.sitting = false
	player._update_camera_height()
	# Resize and sprint FOV must preserve the near-plane clearance volume.
	var original_size := root.size
	root.size = Vector2i(1920, 540)
	player.camera.fov = 77.5
	await _settle()
	check(_safe_camera(), "Ultrawide viewport and sprint FOV remain outside walls")
	root.size = original_size
	player.position = Vector3(16.5, 5.01, 28.0)
	player.rig.rotation.y = 0.0
	player.pitch.rotation.x = -0.12
	await _settle()
	check(player.camera.global_position.distance_to(player.rig.global_position) > 3.0 and player.visual.visible, "Moving away restores full distance and the character")
	game.queue_free()
	await process_frame
	print("CAMERA_COLLISION_SMOKE_PASS: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

func _settle() -> void:
	await physics_frame
	await physics_frame
	await process_frame
	# process_frame fires before node _process callbacks; inspect the frame
	# after the render correction and visibility have both been applied.
	await process_frame

func _safe_camera() -> bool:
	var camera: Camera3D = player.camera
	var anchor: Vector3 = player.rig.global_position
	var size := camera.get_viewport().get_visible_rect().size
	var points: Array[Vector3] = [camera.global_position]
	for x in [0.0, 0.5, 1.0]:
		for y in [0.0, 0.5, 1.0]:
			points.append(camera.project_position(size * Vector2(x, y), camera.near))
	for point in points:
		if world.get_block(Vector3i(point.floor())) != 0:
			return false
		var ray := PhysicsRayQueryParameters3D.create(anchor, point, 1)
		ray.exclude = [player.get_rid()]
		if not camera.get_world_3d().direct_space_state.intersect_ray(ray).is_empty():
			return false
	return true

func _capture(tag: String) -> void:
	if "--capture" in OS.get_cmdline_user_args():
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("C:/Users/Qi/AppData/Local/Temp/opencode/world-story-camera-" + tag + ".png")

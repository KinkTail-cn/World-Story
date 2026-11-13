extends SceneTree

const Atmosphere = preload("res://scripts/world/SkyAtmosphere.gd")
var checks: int = 0
var failures: int = 0

func _initialize() -> void:
	create_timer(30.0).timeout.connect(func(): push_error("SKY_ENVIRONMENT_TIMEOUT"); quit(1))
	_run.call_deferred()

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)

func frames(count: int = 4) -> void:
	for frame in count:
		await process_frame

func _run() -> void:
	var game = preload("res://scenes/Main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	while game.is_loading:
		await process_frame
	game.player.set_physics_process(false)
	game.hud.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var atmosphere = game.sky_atmosphere
	var environment: Environment = game.environment.environment
	check(environment.sky.sky_material is ShaderMaterial, "The scene uses the coordinated coastal sky")
	check(game.player.camera.far >= Atmosphere.PERIOD * 2.0, "The actual player camera retains the cloud layers and distant ocean haze")
	check(environment.fog_sky_affect < 0.2, "Surface fog retains the sky's gradient and sun")
	check(atmosphere.clouds.size() == Atmosphere.CLOUD_COUNT, "Cloud population is bounded")
	check(atmosphere.find_children("*", "CollisionObject3D", true, false).is_empty(), "Clouds never block targeting or movement")
	check(atmosphere.sun_direction.is_equal_approx(game.get_node("Sun").global_basis.z.normalized()), "Cloud highlights and sky sun agree with the shadow-casting light")
	var mesh_ids := {}
	var low := false
	var high := false
	for entry in atmosphere.clouds:
		var mesh: ArrayMesh = entry.node.mesh
		mesh_ids[mesh.get_instance_id()] = true
		low = low or entry.origin.y < 90
		high = high or entry.origin.y > 100
		check(mesh.get_meta("cloud_cube_count", 0) > 0 and mesh.get_aabb().size.y > Atmosphere.CELL, "Each cloud is a volume built from cubes")
		check(entry.node.rotation.is_zero_approx() and is_equal_approx(entry.node.scale.x, entry.node.scale.y) and is_equal_approx(entry.node.scale.x, entry.node.scale.z), "Cloud cubes keep equal edge lengths and axis alignment")
	check(low and high and mesh_ids.size() <= 6, "Two cloud heights share a small reusable mesh set")
	var replica = Atmosphere.new()
	replica.world_seed = atmosphere.world_seed
	replica.visible = false
	root.add_child(replica)
	check(replica.clouds.map(func(p): return p.origin) == atmosphere.clouds.map(func(p): return p.origin), "The world seed restores the same cloud layout")
	replica.free()
	var snapshot: Dictionary = game.world.save_data()
	atmosphere.set_process(false)
	var before: Vector3 = atmosphere.clouds[0].node.global_position
	atmosphere._process(2.0)
	check(atmosphere.clouds[0].node.global_position != before, "Clouds drift gradually rather than staying at the spawn")
	for position in [Vector3(0, 6, 0), Vector3(10000, 6, -20000), Vector3(-30000, 8, 40000)]:
		atmosphere.place_around(position)
		var nearby := true
		var visible_clouds := 0
		for entry in atmosphere.clouds:
			var offset: Vector3 = entry.node.global_position - position
			nearby = nearby and absf(offset.x) <= Atmosphere.PERIOD * 0.5 and absf(offset.z) <= Atmosphere.PERIOD * 0.5
			visible_clouds += 1 if entry.node.visible else 0
		check(nearby and visible_clouds > 0 and atmosphere.clouds.size() == Atmosphere.CLOUD_COUNT, "Distant positive and negative exploration retains a bounded sky")
	atmosphere.set_process(true)
	paused = true
	var stopped: float = atmosphere.elapsed
	await frames()
	check(atmosphere.elapsed == stopped, "Cloud drift pauses with the game")
	paused = false
	await frames()
	check(atmosphere.elapsed > stopped, "Cloud drift resumes after unpausing")
	check(game.world.save_data() == snapshot, "Sky motion does not modify terrain or save data")
	var fog_color := environment.fog_light_color
	var fog_density := environment.fog_density
	var fog_sky := environment.fog_sky_affect
	game._update_water_environment(true, true, true, 4.0)
	check(not atmosphere.visible and environment.fog_density > fog_density and environment.fog_sky_affect == 1.0 and environment.sky.sky_material.get_shader_parameter("underwater_mix") == 1.0, "Underwater hides cloud meshes and applies the underwater haze")
	game._update_water_environment(false, false, false, 0.0)
	check(atmosphere.visible and environment.fog_light_color == fog_color and environment.fog_density == fog_density and environment.fog_sky_affect == fog_sky and environment.sky.sky_material.get_shader_parameter("underwater_mix") == 0.0, "Leaving water exactly restores the surface atmosphere")
	if DisplayServer.get_name() != "headless":
		await _render_checks(game)
	game.queue_free()
	await frames()
	check(not is_instance_valid(atmosphere), "Scene teardown releases its cloud nodes")
	print("SKY_ENVIRONMENT_INTEGRITY_PASS: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

func _render_checks(game: Node3D) -> void:
	var camera := Camera3D.new()
	game.add_child(camera)
	camera.fov = game.player.camera.fov
	camera.near = game.player.camera.near
	camera.far = game.player.camera.far
	camera.position = Vector3(16, 7, 24)
	camera.make_current()
	game.world.visible = false
	game.player.visible = false
	var atmosphere = game.sky_atmosphere
	atmosphere.visible = false
	camera.look_at(camera.position + Vector3.UP, Vector3.FORWARD)
	var zenith: Image = await image_after(4)
	camera.look_at(camera.position + Vector3(1, 0.01, 0))
	var horizon: Image = await image_after(4)
	var top: Color = zenith.get_pixel(zenith.get_width() / 2, zenith.get_height() / 2)
	var bottom: Color = horizon.get_pixel(horizon.get_width() / 2, horizon.get_height() / 2)
	check(bottom.get_luminance() > top.get_luminance() + 0.1 and top.b > top.r + 0.15, "Actual OpenGL sky has a blue zenith and a lighter horizon")
	camera.look_at(camera.position + game.get_node("Sun").global_basis.z * 100)
	var sun: Image = await image_after(4)
	var center: Color = sun.get_pixel(sun.get_width() / 2, sun.get_height() / 2)
	var nearby: Color = sun.get_pixel(sun.get_width() / 2 + 50, sun.get_height() / 2)
	check(center.get_luminance() > nearby.get_luminance() + 0.08, "The visible sun disc aligns with the directional light")
	atmosphere.visible = true
	atmosphere.motion_enabled = true
	atmosphere.place_around(camera.position)
	for entry in atmosphere.clouds:
		if entry.node.visible and entry.origin.y < 90:
			camera.look_at(entry.node.global_position)
			break
	var moving_a: Image = await image_after(4)
	var moving_b: Image = await image_after(24)
	check(moving_a.get_data() != moving_b.get_data(), "Actual cloud silhouettes drift in the rendered sky")
	atmosphere.motion_enabled = false
	var fixed_a: Image = await image_after(4)
	var fixed_b: Image = await image_after(24)
	check(fixed_a.get_data() == fixed_b.get_data(), "Disabling cloud motion leaves the sky pixel-stable")
	game.world.visible = true
	camera.position = Vector3(50, 5, 50)
	camera.look_at(Vector3(150, 5, 150))
	var ocean: Image = await image_after(4)
	var air: Color = ocean.get_pixel(ocean.get_width() / 2, ocean.get_height() / 2 - 3)
	var sea: Color = ocean.get_pixel(ocean.get_width() / 2, ocean.get_height() / 2 + 3)
	check(Vector3(air.r, air.g, air.b).distance_to(Vector3(sea.r, sea.g, sea.b)) < 0.15, "The distant ocean joins the sky without a bright or dark stripe")
	game._update_water_environment(true, true, true, 5.0)
	camera.position = Vector3(50, -5, 50)
	camera.look_at(camera.position + game.get_node("Sun").global_basis.z * 50)
	var underwater: Image = await image_after(4)
	var tint: Color = underwater.get_pixel(underwater.get_width() / 2, underwater.get_height() / 2)
	check(tint.b > tint.r + 0.15 and tint.get_luminance() < 0.8, "The underwater view stays blue and does not expose a bright surface sun")
	game._update_water_environment(false, false, false, 0.0)
	if "--capture" in OS.get_cmdline_user_args():
		zenith.save_png("C:/Users/Qi/AppData/Local/Temp/opencode/world-story-sky-test-zenith.png")
		horizon.save_png("C:/Users/Qi/AppData/Local/Temp/opencode/world-story-sky-test-horizon.png")
		sun.save_png("C:/Users/Qi/AppData/Local/Temp/opencode/world-story-sky-test-sun.png")
		moving_b.save_png("C:/Users/Qi/AppData/Local/Temp/opencode/world-story-sky-test-clouds.png")
		ocean.save_png("C:/Users/Qi/AppData/Local/Temp/opencode/world-story-sky-test-ocean.png")
		underwater.save_png("C:/Users/Qi/AppData/Local/Temp/opencode/world-story-sky-test-underwater.png")

func image_after(count: int) -> Image:
	await frames(count)
	await RenderingServer.frame_post_draw
	return root.get_texture().get_image()

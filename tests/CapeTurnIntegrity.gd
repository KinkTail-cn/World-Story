extends SceneTree

const Character = preload("res://scripts/player/CharacterVisual.gd")
const Presets = preload("res://scripts/blueprint/BlueprintPresets.gd")
const Equipment = preload("res://scripts/blueprint/BlueprintEquipment.gd")
var checks: int = 0
var failures: int = 0

func _initialize() -> void:
	create_timer(35.0).timeout.connect(func(): push_error("CAPE_TURN_TIMEOUT"); quit(1))
	_run.call_deferred()

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)

func _run() -> void:
	var stage := Node3D.new()
	root.add_child(stage)
	var character = Character.new()
	stage.add_child(character)
	character.held_item.visible = false
	var gear = character.equipment_visuals
	for fps in [30, 60, 120]:
		gear.cape_wind = 1.5
		var peak_change := 0.0
		for frame in range(fps * 4):
			# The player's acceleration passes through zero at each reversal.
			var speed := absf(sin(float(frame) / fps * PI * 2.0)) * 7.8
			var previous: float = gear.cape_wind
			gear.update_motion(1.0 / fps, speed, false, false, false)
			peak_change = maxf(peak_change, absf(gear.cape_wind - previous))
		check(peak_change < 0.19, "Repeated left/right acceleration keeps wind amplitude continuous at %d FPS" % fps)
	if DisplayServer.get_name() != "headless":
		await _gpu_continuity(stage, character)
	stage.queue_free()
	await process_frame
	await _actual_reversals()
	print("CAPE_TURN_INTEGRITY_PASS: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

func _actual_reversals() -> void:
	var game = preload("res://scenes/Main.tscn").instantiate()
	root.add_child(game)
	while game.is_loading:
		await process_frame
	var player = game.player
	var gear = player.visual.equipment_visuals
	var home: Vector3 = game.world.get_spawn_position()
	Input.action_press("sprint")
	for id in [106, 406, 416, 426, -1]:
		player.global_position = home
		player.velocity = Vector3.ZERO
		game.inventory.equipment[5] = 106 if id == -1 else id
		game.inventory.equipment_items[5] = Equipment.make_item(Presets.design_for_item(426)) if id == -1 else {"id": id, "count": 1}
		game._refresh_inventory()
		var previous: float = gear.cape_wind
		var peak := 0.0
		for frame in range(120):
			var left := (frame / 20) % 2 == 0
			Input.action_release("move_right" if left else "move_left")
			Input.action_press("move_left" if left else "move_right")
			await physics_frame
			peak = maxf(peak, absf(gear.cape_wind - previous))
			previous = gear.cape_wind
		Input.action_release("move_left")
		Input.action_release("move_right")
		check(peak < 0.13 and player.global_position.is_finite() and not player.swimming, "Actual sprinting with repeated left/right input stays continuous for cape %d" % id)
		if id == 426 and "--capture" in OS.get_cmdline_user_args():
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("C:/Users/Qi/AppData/Local/Temp/opencode/cape-turn-gameplay.png")
	Input.action_release("sprint")
	game.queue_free()
	for frame in range(4):
		await process_frame

func _gpu_continuity(stage: Node3D, character: Node3D) -> void:
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("253544")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color("cfdae1")
	environment.environment.ambient_light_energy = 0.7
	stage.add_child(environment)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-35, -25, 0)
	stage.add_child(light)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 2.2
	stage.add_child(camera)
	camera.position = Vector3(1.9, 1.4, 3)
	camera.look_at(Vector3(0, 0.95, 0.25))
	camera.make_current()
	# Render the real shader with a controllable clock, so the exact same time
	# can be compared before/after a tiny speed change, including a 30-min session.
	var original: Shader = preload("res://shaders/cube_cape.gdshader")
	var sampled := Shader.new()
	sampled.code = original.code.replace("TIME", "sample_time").replace("render_mode specular_disabled;", "render_mode specular_disabled;\nuniform float sample_time = 0.0;")
	var design := Presets.design_for_item(426)
	var item := Equipment.make_item(design)
	for id in [106, 406, 416, 426, -1]:
		var ids: Array[int] = [0, 0, 0, 0, 0, maxi(106, id), 0]
		character.equipment_visuals.apply_equipment(ids, [{}, {}, {}, {}, {}, item, {}] if id == -1 else [])
		var pieces: Array = character.equipment_visuals.pieces[5] if id == 106 else (character.equipment_visuals.custom_visuals[5].pieces if id == -1 else character.equipment_visuals.set_visuals[5].pieces)
		var materials: Array = pieces.map(func(piece): return piece.material_override)
		var originals: Array = materials.map(func(material): return material.shader)
		for material in materials:
			material.shader = sampled
		var early := 0.0
		var late := 0.0
		for sample_time in [12.0, 1800.0]:
			var before: Image = await _frame(materials, sample_time, 0.90)
			var after: Image = await _frame(materials, sample_time, 0.92)
			var error := _difference(before, after)
			if sample_time == 12.0:
				early = error
			else:
				late = error
			print("CAPE_SPEED_CHANGE_PIXEL_MEAN: id=%d time=%.0f mean=%.6f" % [id, sample_time, error])
			check(error < 0.0007, "A tiny change in reversal speed moves pixels continuously at t=%.0f for cape %d" % [sample_time, id])
		check(late < early * 2.0 + 0.00015, "Long sessions do not amplify speed-change phase jumps: " + str(id))
		if id == -1 and "--capture" in OS.get_cmdline_user_args():
			var image := await _frame(materials, 1800.0, 0.92)
			image.save_png("C:/Users/Qi/AppData/Local/Temp/opencode/cape-turn-stable.png")
		for index in materials.size():
			materials[index].shader = originals[index]

func _frame(materials: Array, time_value: float, wind: float) -> Image:
	for material in materials:
		material.set_shader_parameter("sample_time", time_value)
		material.set_shader_parameter("wind_strength", wind)
	for frame in range(3):
		await process_frame
	await RenderingServer.frame_post_draw
	return root.get_texture().get_image()

func _difference(first: Image, second: Image) -> float:
	first = first.duplicate()
	second = second.duplicate()
	first.resize(320, 200, Image.INTERPOLATE_BILINEAR)
	second.resize(320, 200, Image.INTERPOLATE_BILINEAR)
	var a := first.get_data()
	var b := second.get_data()
	var error := 0.0
	for index in range(a.size()):
		error += absf(float(a[index]) - float(b[index])) / 255.0
	return error / maxf(1, a.size())

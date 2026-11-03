extends SceneTree

const Character = preload("res://scripts/player/CharacterVisual.gd")
const Presets = preload("res://scripts/blueprint/BlueprintPresets.gd")
const Equipment = preload("res://scripts/blueprint/BlueprintEquipment.gd")
const Renderer = preload("res://scripts/player/BlueprintEquipmentVisual.gd")
var checks: int = 0
var failures: int = 0

func _initialize() -> void:
	create_timer(30.0).timeout.connect(func(): push_error("CAPE_MOTION_TIMEOUT"); quit(1))
	_run.call_deferred()

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(label)

func _run() -> void:
	var stage := Node3D.new()
	root.add_child(stage)
	var character = Character.new()
	stage.add_child(character)
	character.held_item.visible = false
	var gear = character.equipment_visuals
	for id in [106, 406, 416, 426]:
		var ids: Array[int] = [0, 0, 0, 0, 0, id, 0]
		gear.set_motion_enabled(true)
		gear.apply_equipment(ids)
		var pieces: Array = gear.pieces[5] if id == 106 else gear.set_visuals[5].pieces
		var materials: Array = pieces.map(func(p): return p.material_override)
		check(not pieces.is_empty() and pieces.all(func(p): return rigid_uvs(p.mesh)), "Every animated cube has one shared motion coordinate: " + str(id))
		for frame in range(30):
			gear.update_motion(1.0 / 60.0, 7.8, false, false, false)
		check(materials.all(func(m): return m is ShaderMaterial and float(m.get_shader_parameter("wind_strength")) > 1.0 and float(m.get_shader_parameter("motion_scale")) == 1.0), "Running drives the visible cape: " + str(id))
		gear.set_motion_enabled(false)
		gear.update_motion(1.0, 7.8, true, false, false)
		check(materials.all(func(m): return float(m.get_shader_parameter("motion_scale")) == 0.0 and float(m.get_shader_parameter("wind_strength")) == 0.0), "Static modeling disables both idle and running motion: " + str(id))
		gear.apply_equipment(ids)
		check(materials.all(func(m): return float(m.get_shader_parameter("motion_scale")) == 0.0), "Reapplying gear preserves the modeling freeze: " + str(id))
	var design := Presets.design_for_item(426)
	var snapshot := design.duplicate(true)
	var item := Equipment.make_item(design)
	var custom_ids: Array[int] = [0, 0, 0, 0, 0, 106, 0]
	gear.set_motion_enabled(true)
	gear.apply_equipment(custom_ids, [{}, {}, {}, {}, {}, item, {}])
	gear.update_motion(1.0, 7.8, false, false, false)
	var custom = gear.custom_visuals[5]
	check(custom.cape_materials.size() > 0 and custom.cape_materials.all(func(m): return float(m.get_shader_parameter("wind_strength")) > 1.0), "Custom crafted capes receive the same wind as official capes")
	check(custom.pieces.all(func(p): return rigid_uvs(p.mesh)) and custom.blueprint == snapshot and item.blueprint == snapshot, "Animation keeps every cube rigid and never changes saved blueprint data")
	var icon = Renderer.new()
	stage.add_child(icon)
	icon.build(design)
	check(icon.cape_materials.is_empty() and icon.source_part_count == design.voxels.size(), "Inventory icon stays fixed while displaying the full cape")
	icon.free()
	var has_collar := false
	var has_tail := false
	for piece in custom.pieces:
		var uvs: PackedVector2Array = piece.mesh.surface_get_arrays(0)[Mesh.ARRAY_TEX_UV]
		for uv in uvs:
			has_collar = has_collar or uv.y <= 0.10
			has_tail = has_tail or uv.y > 0.8
	check(has_collar and has_tail, "Shared cape profile includes a fixed collar and movable lower cubes")
	var single = Renderer.new()
	stage.add_child(single)
	single.build({"schema_version": 3, "category": "披风", "voxels": [{"pos": [0, 0, 0], "part": "披风", "mat": 1, "size": 1}]}, character)
	var single_uvs: PackedVector2Array = single.pieces[0].mesh.surface_get_arrays(0)[Mesh.ARRAY_TEX_UV]
	check(Array(single_uvs).all(func(uv: Vector2): return uv.y == 0.0), "A one-cube cloak remains attached instead of waving its collar away")
	single.free()
	if DisplayServer.get_name() != "headless":
		await _check_rendered_motion(stage, character)
	stage.queue_free()
	await process_frame
	print("CAPE_MOTION_INTEGRITY_PASS: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

func rigid_uvs(mesh: Mesh) -> bool:
	var arrays := mesh.surface_get_arrays(0)
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
	var count := indices.size() if not indices.is_empty() else vertices.size()
	if uvs.size() != vertices.size() or count == 0 or count % 36 != 0:
		return false
	for start in range(0, count, 36):
		var first: Vector2 = uvs[indices[start] if not indices.is_empty() else start]
		for corner in range(start, start + 36):
			if not uvs[indices[corner] if not indices.is_empty() else corner].is_equal_approx(first):
				return false
	return true

func _check_rendered_motion(stage: Node3D, character: Node3D) -> void:
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
	camera.size = 2.35
	stage.add_child(camera)
	camera.position = Vector3(2.2, 1.6, 4)
	camera.look_at(Vector3(0, 1.05, 0))
	camera.make_current()
	var moving_a: Image = await _image_after_frames(4)
	var moving_b: Image = await _image_after_frames(20)
	check(moving_a.get_data() != moving_b.get_data(), "Actual OpenGL cape pixels move while worn")
	character.equipment_visuals.set_motion_enabled(false)
	var fixed_a: Image = await _image_after_frames(4)
	var fixed_b: Image = await _image_after_frames(20)
	check(fixed_a.get_data() == fixed_b.get_data(), "Actual OpenGL pixels remain identical with modeling motion disabled")
	if "--capture" in OS.get_cmdline_user_args():
		moving_b.save_png("C:/Users/Qi/AppData/Local/Temp/opencode/world-story-cape-moving.png")
		fixed_b.save_png("C:/Users/Qi/AppData/Local/Temp/opencode/world-story-cape-fixed.png")

func _image_after_frames(count: int) -> Image:
	for frame in count:
		await process_frame
	await RenderingServer.frame_post_draw
	return root.get_texture().get_image()

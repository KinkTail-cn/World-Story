extends SceneTree

const Data = preload("res://scripts/blueprint/BlueprintData.gd")
const Geometry = preload("res://scripts/blueprint/BlueprintGeometry.gd")
const Session = preload("res://scripts/blueprint/BlueprintEditSession.gd")
const Presets = preload("res://scripts/blueprint/BlueprintPresets.gd")
const Renderer = preload("res://scripts/player/BlueprintEquipmentVisual.gd")
const Character = preload("res://scripts/player/CharacterVisual.gd")
const Document = preload("res://scripts/player/DocumentVisual.gd")
const World = preload("res://scripts/world/VoxelWorld.gd")
const Cover = preload("res://scripts/world/GroundCover.gd")
const Inventory = preload("res://scripts/inventory/Inventory.gd")
const Save = preload("res://scripts/system/SaveSystem.gd")
var checks: int = 0
var failures: int = 0
var shots: Array[Image] = []

func _initialize() -> void:
	create_timer(35.0).timeout.connect(func(): push_error("SOFT_MATERIAL_TIMEOUT"); quit(1))
	_run.call_deferred()

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)

func _run() -> void:
	var world = World.new()
	root.add_child(world)
	await world.world_ready
	await physics_frame
	var moving_leaves := 0
	var grass_cubes := 0
	for chunk in world._active_chunks.values():
		var arrays: Array = chunk.visual.mesh.surface_get_arrays(0)
		var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var motion_uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV2]
		check(vertices.size() == motion_uvs.size(), "Every terrain corner has a stable cube motion coordinate")
		var only_leaves := true
		for index in vertices.size():
			if colors[index].a < 0.3:
				moving_leaves += 1
				var cell := Vector3i(floori(motion_uvs[index].x), floori(vertices[index].y + 0.001), floori(motion_uvs[index].y))
				only_leaves = only_leaves and (world.get_block(cell) == 4 or world.get_block(cell + Vector3i.DOWN) == 4)
		check(only_leaves, "Wind never marks soil, sand, stone, snow or wood as moving terrain")
		if chunk.grass.mesh != null:
			grass_cubes += int(chunk.grass.mesh.get_meta("grass_cube_count", 0))
			check(chunk.grass.find_children("*", "CollisionObject3D", true, false).is_empty(), "Grass blades introduce no picking or movement blockers")
		var expected_faces: int = chunk.visual.mesh.get_faces().size()
		if chunk.glass.mesh != null:
			expected_faces += chunk.glass.mesh.get_faces().size()
		check(chunk.collider.shape.get_faces().size() == expected_faces, "Terrain collision excludes decorative moving grass")
	check(moving_leaves > 0 and grass_cubes > 0, "Existing island contains moving leaves and sparse grass blades")
	var grass_cells: Array[Vector3i] = []
	for x in range(32):
		for z in range(16):
			grass_cells.append(Vector3i(x, 4, z))
	var cover_a := Cover.build(grass_cells)
	var cover_b := Cover.build(grass_cells)
	check(cover_a.surface_get_arrays(0)[Mesh.ARRAY_VERTEX] == cover_b.surface_get_arrays(0)[Mesh.ARRAY_VERTEX], "Grass positions remain deterministic after a chunk rebuild")
	var world_snapshot: Dictionary = world.save_data()
	world.set_wind_enabled(false)
	check(world.save_data() == world_snapshot, "Wind does not change terrain save data")
	world.visible = false

	var character = Character.new()
	root.add_child(character)
	character.held_item.visible = false
	for id in [401, 407, 411, 423, 427]:
		var design := Presets.design_for_item(id)
		check(design.voxels.any(func(p): return str(p.get("motion", "fixed")) != "fixed") and design.voxels.all(Geometry.is_cube), "Loose soft parts of " + str(id) + " retain cubic geometry")
		check(Data.validation_error(design).is_empty() and Data.from_dictionary(JSON.parse_string(JSON.stringify(design))).to_dictionary() == design, "Motion metadata survives blueprint JSON: " + str(id))
		var renderer = Renderer.new()
		root.add_child(renderer)
		renderer.build(design, character)
		renderer.set_wind(1.5)
		check(not renderer.motion_materials.is_empty() and renderer.cape_materials.is_empty(), "Soft motion is available outside the cape slot: " + str(id))
		check(renderer.pieces.all(func(p): return not p.material_override is ShaderMaterial or same_cube_coordinates(p.mesh)), "Each soft cube shares a single translation: " + str(id))
		renderer.set_motion_enabled(false)
		check(renderer.motion_materials.all(func(m): return float(m.get_shader_parameter("motion_scale")) == 0.0), "Modeling freezes all soft parts: " + str(id))
		renderer.free()
		var icon = Renderer.new()
		root.add_child(icon)
		icon.build(design)
		check(icon.motion_materials.is_empty(), "Inventory icons are fixed: " + str(id))
		icon.free()
	check(Presets.design_for_item(421).voxels.all(func(p): return p.get("motion", "fixed") == "fixed"), "Fitted mage hat and its gems stay fixed")
	check(Presets.design_for_item(412).voxels.all(func(p): return p.get("motion", "fixed") == "fixed"), "Metal chest armor stays fixed")

	var data = Data.new("自制布条", "腰带")
	for y in range(5):
		data.add_part(Geometry.primitive("腰带", Vector3(0.15, 0.7 - float(y) * 0.0325, 0.20), Vector3.ONE * 0.0325, "body"))
	var session = Session.new()
	session.bind(data)
	session.select(data.voxels.map(func(p): return p.uid))
	check(session.set_properties({"motion": "cloth"}) and session.undo() and session.redo(), "Soft motion edits participate in undo and redo")
	var before: Dictionary = data.to_dictionary()
	check(not session.set_properties({"motion": "unknown"}) and data.to_dictionary() == before, "Invalid motion edits roll back atomically")
	var saves = Save.new("user://soft_material_%d.json" % OS.get_process_id())
	var inv = Inventory.new()
	var made: Dictionary = inv.craft_blueprint(before)
	check(made.ok and inv.equip_from_bag(int(made.index)), "A design with soft material motion can be crafted and worn")
	check(saves.save_game({"inventory": saves.save_inventory(inv)}), "Soft item snapshot saves")
	var restored = Inventory.new()
	saves.apply_inventory(restored, saves.load_game().inventory)
	check(restored.get_slot("equipment", 6) == inv.get_slot("equipment", 6), "Worn soft parts survive actual save/load unchanged")
	saves.delete_save()
	var sheet = Document.new()
	sheet.item_id = 109
	sheet.motion_enabled = true
	root.add_child(sheet)
	check(not sheet.motion_materials.is_empty(), "Loose blueprint paper has a gentle wind effect")
	sheet.set_motion_enabled(false)
	check(sheet.motion_materials.all(func(m): return float(m.get_shader_parameter("motion_scale")) == 0.0), "Paper motion can be frozen")
	sheet.free()
	var book = Document.new()
	book.item_id = 108
	book.motion_enabled = true
	root.add_child(book)
	check(book.motion_materials.is_empty(), "A bound notebook and its cover do not wave")
	book.free()
	if DisplayServer.get_name() != "headless":
		await _render_checks(world, character)
	character.queue_free()
	world.queue_free()
	await process_frame
	print("SOFT_MATERIAL_INTEGRITY_PASS: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

func same_cube_coordinates(mesh: Mesh) -> bool:
	var arrays := mesh.surface_get_arrays(0)
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	if uvs.size() % 36 != 0:
		return false
	for start in range(0, uvs.size(), 36):
		for index in range(start, start + 36):
			if not uvs[index].is_equal_approx(uvs[start]):
				return false
	return true

func _render_checks(world: Node3D, character: Node3D) -> void:
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("253544")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color("cfdae1")
	environment.environment.ambient_light_energy = 0.7
	root.add_child(environment)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-35, -25, 0)
	root.add_child(light)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	root.add_child(camera)
	camera.make_current()
	for id in [401, 407, 411, 423, 427]:
		var ids: Array[int] = [0, 0, 0, 0, 0, 0, 0]
		var category: int = (id % 10) - 1
		ids[category] = id
		character.equipment_visuals.set_motion_enabled(true)
		character.equipment_visuals.apply_equipment(ids)
		character.equipment_visuals.update_motion(1.0, 7.8, false, false, false)
		var focus := Vector3(0, 1.85 if category == 0 else (0.4 if category == 2 else 0.67), 0)
		camera.size = 0.85
		camera.position = focus + Vector3(0.8, 0.2, -2)
		camera.look_at(focus)
		await _compare_frames(character.equipment_visuals.set_motion_enabled, "Soft equipment " + str(id))
	character.visible = false
	var paper = Document.new()
	paper.item_id = 109
	paper.motion_enabled = true
	root.add_child(paper)
	camera.size = 0.85
	camera.position = Vector3(0.7, 0.65, 1.0)
	camera.look_at(Vector3(0, 0.03, 0))
	await _compare_frames(paper.set_motion_enabled, "Loose paper")
	paper.free()
	world.visible = true
	world._water.visible = false
	camera.size = 5.5
	camera.position = Vector3(10, 11, 24)
	camera.look_at(Vector3(8.5, 9.5, 19.5))
	await _compare_frames(world.set_wind_enabled, "Leaves")
	var grass_focus := Vector3.ZERO
	for chunk in world._active_chunks.values():
		if chunk.grass.mesh != null:
			var arrays: Array = chunk.grass.mesh.surface_get_arrays(0)
			var coords: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV2]
			var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			grass_focus = Vector3(coords[0].x, points[0].y + 0.04, coords[0].y)
			break
	camera.size = 0.9
	camera.position = grass_focus + Vector3(0.6, 0.5, 1.0)
	camera.look_at(grass_focus)
	await _compare_frames(world.set_wind_enabled, "Grass blades")
	if "--capture" in OS.get_cmdline_user_args():
		var image := Image.create(1600, 800, false, Image.FORMAT_RGBA8)
		for index in shots.size():
			shots[index].resize(400, 400)
			image.blit_rect(shots[index], Rect2i(0, 0, 400, 400), Vector2i(index % 4 * 400, index / 4 * 400))
		image.save_png("C:/Users/Qi/AppData/Local/Temp/opencode/world-story-soft-materials.png")
	camera.free()
	light.free()
	environment.free()

func _compare_frames(toggle: Callable, label: String) -> void:
	toggle.call(true)
	var first: Image = await _frame(4)
	var second: Image = await _frame(24)
	check(first.get_data() != second.get_data(), label + " visibly moves in OpenGL")
	shots.append(second)
	toggle.call(false)
	first = await _frame(4)
	second = await _frame(24)
	check(first.get_data() == second.get_data(), label + " is pixel-stable when fixed")

func _frame(count: int) -> Image:
	for frame in count:
		await process_frame
	await RenderingServer.frame_post_draw
	return root.get_texture().get_image()

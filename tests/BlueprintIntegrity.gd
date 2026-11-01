extends SceneTree

const Data = preload("res://scripts/blueprint/BlueprintData.gd")
const Manager = preload("res://scripts/blueprint/BlueprintManager.gd")
const Workshop = preload("res://scripts/ui/BlueprintWorkshop.gd")

var failures: int = 0
var checks: int = 0

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var data = Data.new()
	var pos := Vector3i(1, 2, 3)
	var center := Vector3(pos) * Data.VOXEL_SIZE
	data.add_voxel(pos, 1, "a")
	data.add_voxel(pos, 2, "b")
	check(data.voxels.size() == 2, "Categories sharing pos must coexist")
	check(data.recolor_voxel(center, "a", 3), "Part-aware recolor")
	check(data.get_voxel_at(center, "b").mat == 2, "Recolor must not affect another part")
	check(data.remove_voxel(center, "a"), "Part-aware erase")
	check(data.voxels.size() == 1 and not data.get_voxel_at(center, "b").is_empty(), "Erase preserves other part")
	data.add_voxel(pos, 4, "b", 4, [0.017, 0.024, 0.033])
	check(data.voxels.size() == 2, "Legacy pos aliases with different physical centers coexist")
	data.add_voxel(Vector3i(99, 99, 99), 5, "b", 1, [0.017, 0.024, 0.033])
	check(data.voxels.size() == 2, "Physical identity is independent of pos units")
	check(data.get_voxel_at(Vector3(0.017, 0.024, 0.033), "b").get("size") == 1, "Replacement resets size to standard")
	for category in Workshop.CATEGORIES:
		data.category = category
		check(data.estimate_stats().filled_cells == 2, "Voxel counts for " + category)
	var cells_only = Data.new()
	cells_only.cells[0] = 6
	check(cells_only.get_material_counts() == {6: 1}, "Legacy cell-only counts")
	data.cells[0] = 7
	check(data.estimate_stats().filled_cells == 2, "Voxel data takes precedence over legacy cells")

	var legacy := {"name": "legacy", "voxels": [
		{"pos": [1, 2, 3], "mat": 1, "part": "a"},
		{"pos": [1, 2, 3], "mat": 2, "part": "b", "size": 3},
		{"pos": [1, 2, 3], "mat": 3, "part": "b", "size": 4, "center": [0.017, 0.024, 0.033]}
	]}
	var restored = Data.from_dictionary(legacy)
	check(restored.voxels.size() == 3, "Loading must retain existing entries")
	check(Data.voxel_center(restored.voxels[1]).is_equal_approx(center), "Legacy no-center rendering remains standard units")
	var round_trip = Data.from_dictionary(JSON.parse_string(JSON.stringify(restored.to_dictionary())))
	check(round_trip.to_dictionary() == restored.to_dictionary(), "Saved voxel fields survive JSON round trip")

	# Exercise workshop geometry without opening the game or its save handlers.
	var workshop = Workshop.new()
	workshop.blueprint = Data.new()
	workshop.current_category = "a"
	workshop.voxel_container = Node3D.new()
	workshop.count_label = Label.new()
	workshop.status_label = Label.new()
	workshop.template_parts.append({"part": "a", "category": "a", "pos": Vector3.ZERO})
	var normals := [Vector3.RIGHT, Vector3.LEFT, Vector3.UP, Vector3.DOWN, Vector3.FORWARD, Vector3.BACK]
	for old_mode in [1, 2, 3, 4]:
		var old_size: float = Workshop.VOXEL_SIZE * workshop._get_size_scale(old_mode)
		for new_mode in [1, 2, 3, 4]:
			workshop.current_voxel_size = new_mode
			var new_size: float = Workshop.VOXEL_SIZE * workshop._get_size_scale(new_mode)
			for normal in normals:
				var origin := Vector3(0.017, -0.024, 0.033)
				var hit: Vector3 = origin + normal * old_size * 0.5
				var target: Vector3 = workshop._surface_center(origin, old_size, hit, normal)
				check(is_equal_approx((target - origin).dot(normal), (old_size + new_size) * 0.5), "All mixed-size faces touch without gaps")
				workshop.blueprint.voxels.clear()
				workshop._place_voxel_with_brush(Vector3i.ZERO, "a", target)
				var placed: Dictionary = workshop.blueprint.voxels[0]
				check(Data.voxel_center(placed).is_equal_approx(target) and placed.get("size") == new_mode, "Placement preserves preview center and size")
				var base := Vector3(0, 1.575, 0)
				var template_hit: Vector3 = base + normal * 0.25
				var template_target: Vector3 = workshop._template_center(base, template_hit, normal)
				check(is_equal_approx((template_target - (template_hit - base)).dot(normal), new_size * 0.5), "Template placement sits flush at every size")

	workshop.current_voxel_size = Workshop.SIZE_THIRTYSECOND
	var first: Vector3 = workshop._surface_center(Vector3.ZERO, 0.26, Vector3(-0.129, 0.13, 0), Vector3.UP)
	var second: Vector3 = workshop._surface_center(Vector3.ZERO, 0.26, Vector3(-0.095, 0.13, 0), Vector3.UP)
	check(is_equal_approx(second.x - first.x, 0.0325), "Fine brush tiles quarter face without gaps")
	workshop.blueprint.voxels.clear()
	for mode in [1, 2, 3, 4]:
		workshop.current_voxel_size = mode
		var exact := Vector3(0.017 + mode, 0.024, 0.033)
		workshop._place_voxel_with_brush(pos, "a", exact)
	workshop.blueprint.add_voxel(pos, 8, "b")
	workshop._mirror_x()
	check(workshop.blueprint.voxels.size() == 9, "Mirror retains all sizes and other parts")
	for mode in [1, 2, 3, 4]:
		var mirrored: Dictionary = workshop.blueprint.get_voxel_at(Vector3(-(0.017 + mode), 0.024, 0.033), "a")
		check(not mirrored.is_empty() and mirrored.get("size") == mode, "Mirror preserves exact center and size")
		var before: Dictionary = mirrored.duplicate(true)
		workshop.blueprint.recolor_voxel(Data.voxel_center(mirrored), "a", 7)
		check(mirrored.get("size") == before.get("size") and mirrored.center == before.center, "Recolor retains geometry")
	workshop._mirror_x()
	check(workshop.blueprint.voxels.size() == 9, "Repeated mirror is idempotent")
	workshop._sync_voxels()
	for block in workshop.voxel_blocks:
		var physical: Vector3 = block.body.get_meta("voxel_center")
		check(block.node.position.is_equal_approx(physical), "Rendered center matches saved center")
		check(block.node.mesh.size.is_equal_approx(block.body.get_meta("box_size")), "Mesh and collider sizes agree")
	workshop.current_voxel_size = Workshop.SIZE_QUARTER
	workshop._remove_voxel_with_brush(Vector3(1.017, 0.024, 0.033), "a")
	check(workshop.blueprint.voxels.size() == 8, "Erase removes only hit voxel regardless of brush")
	check(not workshop.blueprint.get_voxel_at(center, "b").is_empty(), "Workshop erase preserves other category")
	workshop.voxel_container.free()
	workshop.count_label.free()
	workshop.status_label.free()
	workshop.free()

	# Real viewport rays exercise the shared hover/click path headlessly.
	var scene = load("res://scenes/BlueprintWorkshop.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	var scene_manager = Manager.new()
	scene_manager.create_blueprint("ray test", Workshop.CATEGORIES[0], 8)
	scene.open(scene_manager)
	await process_frame
	var part: String = scene.current_category
	var part_base: Vector3 = scene._find_part(part).pos
	for old_mode in [1, 2, 3, 4]:
		for new_mode in [1, 2, 3, 4]:
			scene.blueprint.voxels.clear()
			var origin := Vector3(0, 0, 1)
			var old_size: float = Workshop.VOXEL_SIZE * scene._get_size_scale(old_mode)
			scene._place_voxel_with_brush(Vector3i.ZERO, part, origin, old_mode)
			scene.current_voxel_size = new_mode
			scene._sync_voxels()
			var hit := part_base + origin + Vector3(old_size * 0.2, old_size * 0.2, old_size * 0.5)
			scene.preview_camera.global_position = hit + Vector3(0, 0, 2)
			scene.preview_camera.look_at(hit)
			await physics_frame
			await physics_frame
			var point: Vector2 = scene.preview_camera.unproject_position(hit) * scene.preview_container.size / Vector2(scene.preview_viewport.size)
			scene._update_hover_preview(point)
			check(scene.hover_indicator.visible, "Ray hover finds voxel")
			var preview: Vector3 = scene.hover_indicator.position - part_base
			var expected: Vector3 = scene._surface_center(origin, old_size, hit - part_base, Vector3.BACK)
			check(preview.is_equal_approx(expected), "Ray hover uses physical surface center")
			scene._handle_click(point, false)
			check(scene.blueprint.voxels.size() == 2, "Ray click adds exactly one brush voxel")
			var added: Dictionary = scene.blueprint.get_voxel_at(preview, part)
			check(not added.is_empty() and added.get("size") == new_mode, "Ray click matches hover at every mixed size")
	var drafts = Manager.new()
	scene.open(drafts)
	scene._place_voxel_with_brush(Vector3i.ONE, scene.current_category)
	scene.name_edit.text = "草稿"
	scene.name_edit.text_changed.emit("草稿")
	scene._select_category("手套", true)
	scene.close()
	scene.open(drafts)
	check(scene.blueprint.voxels.size() == 1 and scene.name_edit.text == "草稿" and scene.current_category == "手套", "First workshop draft keeps geometry, name and selected category when reopened")
	scene._new_design()
	scene._place_voxel_with_brush(Vector3i(1, 0, 2), "手套")
	scene._mirror_x()
	var origin: Vector3 = scene.EquipmentDesign.template_origin("手套")
	var a: Vector3 = origin + Data.voxel_center(scene.blueprint.voxels[0])
	var b: Vector3 = origin + Data.voxel_center(scene.blueprint.voxels[1])
	check(is_equal_approx(a.x, -b.x) and is_equal_approx(a.y, b.y) and is_equal_approx(a.z, b.z), "Glove mirror reflects across the mannequin center")
	scene._mirror_x()
	check(scene.blueprint.voxels.size() == 2, "Repeating glove mirror does not add duplicates")
	scene.queue_free()
	await process_frame

	# Every disk write is confined to a newly created, unique test directory.
	var directory := "user://blueprint_integrity_%d_%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	check(DirAccess.make_dir_absolute(directory) == OK, "Create isolated test directory")
	var path := directory + "/library.json"
	var manager = Manager.new()
	manager.current = restored
	manager.save_current()
	manager.create_blueprint("latest", "tools", 8)
	manager.current.add_voxel(pos, 4, "tools", 2, [0.17, 0.24, 0.33])
	manager.save_current()
	manager.save_note("retained note")
	check(manager.save_json(path), "Save isolated library")
	var loaded = Manager.new()
	check(loaded.load_json(path), "Load isolated library")
	check(loaded.current != null and loaded.current.name == "latest", "Restore current from last library entry")
	check(loaded.blueprints == manager.blueprints and loaded.notes == manager.notes, "Retain library and notes")
	var imported: Array = [manager.blueprints.back().duplicate(true)]
	loaded.import_blueprints(imported)
	loaded.import_blueprints(imported)
	check(loaded.blueprints.size() == 2, "Repeated paper imports do not duplicate designs")
	imported[0].voxels[0].mat = 6
	check(loaded.import_blueprints(imported) and loaded.blueprints.back().voxels[0].mat == 6, "Importing an edited design updates the same name and category")
	loaded.load_json(path)
	loaded.current.voxels[0].mat = 8
	check(loaded.blueprints.back().voxels[0].mat == 4, "Restored current does not alias saved entry")
	loaded.current.voxels[0].center[0] = 9.0
	check(is_equal_approx(loaded.blueprints.back().voxels[0].center[0], 0.17), "Restored center does not alias saved entry")
	check(not loaded.load_json(directory + "/missing.json") and loaded.current.name == "latest", "Failed load preserves current")
	manager.blueprints.clear()
	check(manager.save_json(path) and loaded.load_json(path) and loaded.current == null, "Empty library clears stale current")
	check(DirAccess.remove_absolute(path) == OK, "Remove isolated library")
	check(DirAccess.remove_absolute(path + ".bak") == OK, "Remove isolated library backup")
	check(DirAccess.remove_absolute(directory) == OK, "Remove isolated test directory")
	await process_frame
	print("BLUEPRINT_INTEGRITY: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

extends SceneTree

const Data = preload("res://scripts/blueprint/BlueprintData.gd")
const Geometry = preload("res://scripts/blueprint/BlueprintGeometry.gd")
const Migration = preload("res://scripts/blueprint/BlueprintMigration.gd")
const Session = preload("res://scripts/blueprint/BlueprintEditSession.gd")
const Presets = preload("res://scripts/blueprint/BlueprintPresets.gd")
const Equipment = preload("res://scripts/blueprint/BlueprintEquipment.gd")
const Renderer = preload("res://scripts/player/BlueprintEquipmentVisual.gd")
const Character = preload("res://scripts/player/CharacterVisual.gd")
const Save = preload("res://scripts/system/SaveSystem.gd")
const Inventory = preload("res://scripts/inventory/Inventory.gd")
const Cubes = preload("res://scripts/content/CubeParts.gd")
var checks: int = 0
var failures: int = 0

func _initialize() -> void:
	create_timer(30.0).timeout.connect(func(): push_error("BLUEPRINT_MODELING_TIMEOUT"); quit(1))
	_run.call_deferred()

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(label)

func _run() -> void:
	var data = Data.new("方块护肩", "盔甲")
	var part := Geometry.primitive("盔甲", Vector3(-0.38, 1.31, 0.13), Vector3.ONE * 0.13, "right_arm")
	part.merge({"tint": "638d9e", "surface": "metal", "label": "右侧方块肩甲"})
	var uid: String = data.add_part(part)
	check(not uid.is_empty() and data.schema_version == 3 and Data.validation_error(data.to_dictionary()).is_empty(), "New designs contain valid version-three cubes")
	check(Geometry.primitive("盔甲", Vector3.ZERO, Vector3(0.13, 0.065, 0.13)).is_empty(), "Primitive creation refuses unequal edges")
	var restored = Data.from_dictionary(JSON.parse_string(JSON.stringify(data.to_dictionary())))
	check(restored.to_dictionary() == data.to_dictionary(), "Cube fields survive exact JSON round trip")
	var old := {"name": "old", "category": "头部装备", "voxels": [{"pos": [1, 2, 3], "mat": 6, "part": "头部装备", "size": 3}]}
	var legacy = Data.from_dictionary(old)
	check(legacy.voxels.size() == 1 and Geometry.dimensions(legacy.voxels[0]).is_equal_approx(Vector3.ONE * 0.065) and Geometry.center(legacy.voxels[0]).is_equal_approx(Vector3(1, 2, 3) * 0.13), "Existing cubic voxels retain their exact size and position")
	for mutation in [{"schema_version": 99}, {"name": []}]:
		var invalid: Dictionary = data.to_dictionary()
		invalid.merge(mutation, true)
		check(not Data.validation_error(invalid).is_empty(), "Invalid schema or field type is rejected")
	for bad_field in [{"dimensions": [0.13, 0.065, 0.13]}, {"dimensions": [0, 0, 0]}, {"anchor": "missing_bone"}, {"shape": "wedge"}, {"shape": "cone"}, {"shape": "cloth"}, {"rotation": [0, 90, 0]}, {"rotation": [INF, 0, 0]}, {"tint": "bad-color"}, {"cloth": {"wind": 1}}]:
		var invalid: Dictionary = data.to_dictionary()
		invalid.voxels[0].merge(bad_field, true)
		check(not Data.validation_error(invalid).is_empty(), "Version three rejects noncubic, rotated or malformed data")

	for shape in ["box", "wedge", "cone", "cloth"]:
		var source := {"uid": "original", "part": "盔甲", "mat": 6, "size": 1, "pos": [0, 0, 0], "dimensions": [0.26, 0.39, 0.065], "shape": shape, "rotation": [0, 0, 25], "anchor": "right_arm", "offset": [0.02, -0.1, -0.17], "tint": "527c91", "surface": "cloth" if shape == "cloth" else "metal", "locked": true, "hidden": true}
		if shape == "cloth":
			source.cloth = {"emblem": 2, "trim": "ffd088", "wind": 1.0, "flare": 0.06}
		var historical := {"schema_version": 2, "name": "旧设计", "category": "盔甲", "voxels": [source]}
		check(Data.validation_error(historical).is_empty(), "Valid historical " + shape + " can still load")
		var converted = Data.from_dictionary(historical)
		var design: Dictionary = converted.to_dictionary()
		check(converted.voxels.size() > 1 and cubes_valid(design) and Data.validation_error(design).is_empty(), "Legacy " + shape + " becomes only unrotated equal-edge cubes")
		check(converted.voxels[0].uid == "original" and converted.voxels.all(func(p): return p.mat == 6 and p.anchor == "right_arm" and p.locked and p.hidden), "Migration preserves identity, material, anchor and editor flags")
		check(Data.from_dictionary(JSON.parse_string(JSON.stringify(design))).to_dictionary() == design, "Migration runs once and is stable across subsequent saves")
		check(historical.voxels[0] == source and source.shape == shape and source.rotation == [0, 0, 25], "Loading does not mutate the historical source")
		if shape != "cloth":
			check(converted.voxels.all(func(p): return p.tint == "527c91"), "Rigid migration retains the original dye")
		else:
			check(converted.voxels.any(func(p): return p.tint == "ffd088"), "Old cloak decoration becomes colored cubes")
	var uncolored := {"part": "盔甲", "mat": 4, "pos": [0, 0, 0], "dimensions": [0.26, 0.065, 0.065]}
	check(Migration.convert_part(uncolored, "盔甲", 32).all(func(p): return not p.has("tint")), "Migration retains material-derived color when no dye exists")
	var crowded: Array[Dictionary] = []
	for index in range(4096):
		crowded.append(uncolored.duplicate(true))
	var bounded := Migration.convert_all(crowded, "盔甲", 4096)
	check(bounded.size() == 4096 and bounded.all(Geometry.is_cube), "A full old blueprint migrates without exceeding the part limit or dropping a source")
	var oversized := uncolored.duplicate(true)
	oversized.dimensions = [4.0, 4.0, 4.0]
	oversized.rotation = [45, 45, 45]
	var coarse := Migration.convert_part(oversized, "盔甲", 1)
	check(coarse.size() == 1 and Geometry.dimensions(coarse[0]).x <= 4.0 and Geometry.is_cube(coarse[0]), "A large rotated part with one remaining cell still respects cube edge limits")
	var migrated_cost := Equipment.material_cost({"schema_version": 2, "category": "盔甲", "voxels": [uncolored]})
	check(migrated_cost == Equipment.material_cost(Data.from_dictionary({"schema_version": 2, "category": "盔甲", "voxels": [uncolored]}).to_dictionary()), "Old-design costing uses the same cubic geometry as crafting")

	var mirrored := Geometry.mirrored(part, "盔甲")
	var twice := Geometry.mirrored(mirrored, "盔甲")
	check(mirrored.anchor == "left_arm" and Geometry.character_transform(twice, "盔甲").is_equal_approx(Geometry.character_transform(part, "盔甲")), "Mirror swaps anchors and reverses after two applications")
	check(Geometry.is_cube(mirrored) and mirrored.tint == part.tint, "Mirror preserves cubic geometry and color")
	for edge in [0.26, 0.13, 0.065, 0.0325, 0.0473]:
		var primitive := Geometry.primitive("头部装备", Vector3.ZERO, Vector3.ONE * edge, "head")
		var basis := Geometry.preview_transform(primitive, "头部装备").basis
		for normal in [Vector3.RIGHT, Vector3.LEFT, Vector3.UP, Vector3.DOWN, Vector3.FORWARD, Vector3.BACK]:
			var hit := Vector3(0.017, 1.812, -0.126)
			var center := Geometry.placement(hit, normal, primitive, basis, 0.0325)
			var minimum := INF
			for vertex in Geometry.vertices(primitive):
				minimum = minf(minimum, Vector3(normal).dot(center + basis * vertex - hit))
			check(absf(minimum) < 0.0001, "Cubes of mixed sizes sit flush on all six faces")
		check(Geometry.mesh(primitive).size.is_equal_approx(Geometry.collision_shape(primitive).size), "Cube render and picking dimensions agree")
	var fine_a := Geometry.primitive("头部装备", Vector3.ZERO, Vector3.ONE * 0.047301)
	var fine_b := Geometry.primitive("头部装备", Vector3.ZERO, Vector3.ONE * 0.047309)
	check(Geometry.mesh(fine_a) != Geometry.mesh(fine_b) and absf(Geometry.mesh(fine_b).size.x - 0.047309) < 0.0000001, "Distinct micrometre edges never alias in the geometry cache")

	var session = Session.new()
	session.bind(data)
	session.select([uid])
	var initial := Geometry.character_transform(data.voxels[0], "盔甲")
	check(session.set_properties({"anchor": "body"}) and Geometry.character_transform(data.voxels[0], "盔甲").is_equal_approx(initial), "Changing anchor preserves the rest-pose position")
	var before: Dictionary = data.to_dictionary()
	check(not session.set_properties({"rotation": [0, 45, 0]}) and not session.set_properties({"dimensions": [0.1, 0.2, 0.1]}) and data.to_dictionary() == before, "Forbidden rotation and stretching fail atomically")
	check(session.set_properties({"dimensions": [0.065, 0.065, 0.065]}), "A single edge can resize all three dimensions")
	var resized: Dictionary = data.to_dictionary()
	check(session.undo() and data.to_dictionary() == before, "Undo restores cube size")
	check(session.redo() and data.to_dictionary() == resized, "Redo restores cube size")
	check(session.duplicate_selected() and data.voxels.size() == 2 and session.selection[0] != uid, "Duplicate uses an independent stable ID")
	check(session.set_properties({"locked": true}), "A cube can be locked")
	before = data.to_dictionary()
	check(not session.translate_selected(Vector3.ONE) and not session.erase_selected() and data.to_dictionary() == before, "Locked cubes cannot move or be deleted")
	check(session.set_properties({"locked": false, "hidden": true}) and session.selected_parts()[0].hidden, "Hidden cubes remain accessible through the list")
	session.set_properties({"hidden": false})
	check(session.mirror_selected(), "Mirror creates an opposite cube")
	var mirrored_count: int = data.voxels.size()
	session.mirror_selected()
	check(data.voxels.size() == mirrored_count, "Repeated mirror does not add coincident cubes")
	session.undo()
	session.translate_selected(Vector3(0, 0.0325, 0))
	check(session.redo_stack.is_empty(), "New edits clear the redo branch")
	for i in range(70):
		session.translate_selected(Vector3(0.001, 0, 0))
	check(session.undo_stack.size() == 64, "History remains bounded at 64 steps")
	data.add_part(Geometry.primitive("头部装备", Vector3(0, 1.9, 0), Vector3.ONE * 0.1))
	check(session.clear_category() and data.voxels.size() == 1 and data.voxels[0].part == "头部装备", "Clear affects only the active category")
	check(session.undo() and data.voxels.size() > 1, "Clear is reversible")
	var snapshot := session.snapshot()
	var invalid_part := part.duplicate(true)
	invalid_part.dimensions = [0.0, 0.1, 0.1]
	check(session.add(invalid_part).is_empty() and session.snapshot().data == snapshot.data, "Invalid insertion is atomic")

	var sample = Data.new("体积", "头部装备")
	sample.add_part(Geometry.primitive("头部装备", Vector3.ZERO, Vector3.ONE * 1.04))
	check(is_equal_approx(Geometry.volume(sample.voxels[0]), pow(1.04, 3.0)), "Material volume is edge cubed")
	var costs := Equipment.material_cost(sample.to_dictionary())
	sample.voxels[0].tint = "143abc"
	check(costs == Equipment.material_cost(sample.to_dictionary()), "Dye does not change consumption")
	var presets := Presets.all()
	check(presets.size() == 21, "All three outfits expose seven templates")
	for design in presets:
		check(Data.validation_error(design).is_empty() and cubes_valid(design) and design.voxels.size() <= 4096, "Every official model is composed exclusively of valid cubes")
		design.voxels[0].tint = "123456"
		check(Presets.design_for_item(int(design.source_item_id)).voxels[0].tint != "123456", "Editing cannot mutate the official source")
	var many = Data.new("batch", "头部装备")
	for i in range(100):
		many.add_part(Geometry.primitive("头部装备", Vector3(float(i) * 0.01, 1.9, 0.4), Vector3.ONE * 0.02, "head"))
	var character = Character.new()
	root.add_child(character)
	var renderer = Renderer.new()
	root.add_child(renderer)
	renderer.build(many.to_dictionary(), character)
	check(renderer.source_part_count == 100 and renderer.pieces.size() == 1, "Same-anchor cubes merge into one draw mesh without changing their vertices")
	check(renderer.pieces[0].get_parent() == character.head and character.find_children("*", "CollisionObject3D", true, false).is_empty(), "Merged cubes follow the bone without editor colliders")
	renderer.free()
	character.queue_free()
	await process_frame
	var path := "user://blueprint_modeling_%d_%d.json" % [OS.get_process_id(), Time.get_ticks_usec()]
	var saves = Save.new(path)
	var inv = Inventory.new()
	var made: Dictionary = inv.craft_blueprint(Presets.design_for_item(426))
	check(made.ok and inv.equip_from_bag(int(made.get("index", -1))), "Cubic cloak can be made and worn")
	check(saves.save_game({"inventory": saves.save_inventory(inv)}), "Version-three inventory snapshot writes")
	var loaded = Inventory.new()
	saves.apply_inventory(loaded, saves.load_game().inventory)
	check(inv.get_slot("equipment", 5) == loaded.get_slot("equipment", 5), "Cubes, colors and anchors survive actual save/load")
	var historical_item := {"id": 102, "count": 1, "blueprint": {"schema_version": 2, "name": "旧长条", "category": "盔甲", "voxels": [uncolored]}}
	saves.apply_inventory(loaded, {"bag": [historical_item], "equipment": [0, 102, 0, 0, 0, 0, 0], "equipment_items": [{"id": 0, "count": 0}, historical_item]})
	check(cubes_valid(loaded.bag[0].blueprint) and cubes_valid(loaded.get_slot("equipment", 1).blueprint), "Historical backpack and worn items both migrate at load")
	saves.delete_save()
	print("BLUEPRINT_MODELING_INTEGRITY_PASS: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

func cubes_valid(design: Dictionary) -> bool:
	return int(design.get("schema_version", 0)) == 3 and not design.voxels.is_empty() and design.voxels.all(func(p): return Geometry.is_cube(p) and Geometry.character_transform(p, str(p.part)).basis.is_equal_approx(Basis.IDENTITY))

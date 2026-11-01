extends SceneTree

const Data = preload("res://scripts/blueprint/BlueprintData.gd")
const Geometry = preload("res://scripts/blueprint/BlueprintGeometry.gd")
const Session = preload("res://scripts/blueprint/BlueprintEditSession.gd")
const Presets = preload("res://scripts/blueprint/BlueprintPresets.gd")
const Equipment = preload("res://scripts/blueprint/BlueprintEquipment.gd")
const Renderer = preload("res://scripts/player/BlueprintEquipmentVisual.gd")
const Character = preload("res://scripts/player/CharacterVisual.gd")
const Save = preload("res://scripts/system/SaveSystem.gd")
const Inventory = preload("res://scripts/inventory/Inventory.gd")
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
	var data = Data.new("斜面护肩", "盔甲")
	var part := Geometry.primitive("盔甲", Vector3(-0.38, 1.31, 0.13), Vector3(0.3, 0.12, 0.23), Vector3(15, 45, 30), "wedge", "right_arm")
	part["tint"] = "638d9e"
	part["surface"] = "metal"
	part["label"] = "右侧斜肩甲"
	var uid: String = data.add_part(part)
	check(not uid.is_empty() and Data.validation_error(data.to_dictionary()).is_empty(), "Versioned rotated wedge is a valid blueprint")
	var restored = Data.from_dictionary(JSON.parse_string(JSON.stringify(data.to_dictionary())))
	check(restored.to_dictionary() == data.to_dictionary(), "Every geometry/anchor/color field survives direct JSON round trip")
	var old := {"name": "old", "category": "头部装备", "voxels": [{"pos": [1, 2, 3], "mat": 6, "part": "头部装备", "size": 3}]}
	var legacy = Data.from_dictionary(old)
	check(Geometry.dimensions(legacy.voxels[0]).is_equal_approx(Vector3.ONE * 0.065) and Geometry.center(legacy.voxels[0]).is_equal_approx(Vector3(1, 2, 3) * 0.13), "Legacy size and position units remain unchanged")
	for mutation in [{"schema_version": 99}, {"name": []}, {"voxels": []}]:
		var invalid: Dictionary = data.to_dictionary()
		invalid.merge(mutation, true)
		if mutation.has("voxels"):
			invalid.voxels = [part.duplicate(true)]
			invalid.voxels[0].dimensions = [0, 0.2, 0.2]
		check(not Data.validation_error(invalid).is_empty(), "Invalid schema, field type or dimension is rejected")
	for bad_field in [{"anchor": "missing_bone"}, {"shape": "unknown"}, {"rotation": [INF, 0, 0]}, {"tint": "not-a-color"}, {"cloth": {"wind": -1}}]:
		var invalid: Dictionary = data.to_dictionary()
		invalid.voxels[0].merge(bad_field, true)
		check(not Data.validation_error(invalid).is_empty(), "Malformed component fields are rejected")
	var mirrored := Geometry.mirrored(part, "盔甲")
	var twice := Geometry.mirrored(mirrored, "盔甲")
	check(mirrored.anchor == "left_arm" and Geometry.character_transform(twice, "盔甲").is_equal_approx(Geometry.character_transform(part, "盔甲")), "Mirror swaps sides and reverses exactly after two applications")
	check(mirrored.tint == part.tint and Geometry.dimensions(mirrored) == Geometry.dimensions(part), "Mirror preserves material appearance and dimensions")

	var normals := [Vector3.RIGHT, Vector3.LEFT, Vector3.UP, Vector3.DOWN, Vector3.FORWARD, Vector3.BACK, Vector3(0.2, 1, -0.7).normalized()]
	for shape in Geometry.SHAPES:
		for angles in [Vector3.ZERO, Vector3(0, 45, 0), Vector3(15, 37, -23)]:
			var primitive := Geometry.primitive("头部装备", Vector3.ZERO, Vector3(0.26, 0.13, 0.065), angles, shape, "head")
			var basis := Geometry.preview_transform(primitive, "头部装备").basis
			for normal in normals:
				var hit := Vector3(0.017, 1.812, -0.126)
				var center := Geometry.placement(hit, normal, primitive, basis, 0.0325)
				var minimum := INF
				for vertex in Geometry.vertices(primitive):
					minimum = minf(minimum, Vector3(normal).dot(center + basis * vertex - hit))
				check(absf(minimum) < 0.0001, "Rotated " + shape + " touches the hit plane without gaps or penetration")
			check(Geometry.mesh(primitive).get_surface_count() > 0 and Geometry.collision_shape(primitive) != null, "Every shape has rendering and picking geometry")

	var stage := Node3D.new()
	root.add_child(stage)
	var bodies: Array[StaticBody3D] = []
	for i in range(3):
		var shape: String = ["box", "wedge", "cone"][i]
		var primitive := {"shape": shape, "dimensions": [0.52, 0.26, 0.52]}
		var body := StaticBody3D.new()
		body.position = Vector3(i * 2.0, 1, 0)
		body.rotation = Vector3(0.2, 0.4, -0.1)
		var collision := CollisionShape3D.new()
		collision.shape = Geometry.collision_shape(primitive)
		body.add_child(collision)
		stage.add_child(body)
		bodies.append(body)
	await physics_frame
	await physics_frame
	var wedge: StaticBody3D = bodies[1]
	var slope_normal := (wedge.global_basis * Vector3(0, 0.52, -0.26).normalized()).normalized()
	var slope := wedge.global_position
	var ray := PhysicsRayQueryParameters3D.create(slope + slope_normal * 2.0, slope - slope_normal * 0.1)
	var hit := wedge.get_world_3d().direct_space_state.intersect_ray(ray)
	check(not hit.is_empty() and hit.collider == wedge and Vector3(hit.normal).dot(slope_normal) > 0.999, "Physics picks the actual rotated wedge slope normal")
	stage.queue_free()
	await process_frame

	var session = Session.new()
	session.bind(data)
	session.category = "盔甲"
	session.select([uid])
	var initial := Geometry.character_transform(data.voxels[0], "盔甲")
	check(session.set_properties({"anchor": "body"}) and Geometry.character_transform(data.voxels[0], "盔甲").is_equal_approx(initial), "Changing a body anchor preserves the rest-pose position")
	check(session.rotate_selected(Vector3(0, 45, 0)), "Selected component rotates as one transaction")
	var rotated: Dictionary = data.to_dictionary()
	check(session.undo() and Geometry.character_transform(data.voxels[0], "盔甲").is_equal_approx(initial), "Undo restores the entire transform")
	check(session.redo() and data.to_dictionary() == rotated, "Redo restores the rotated part")
	check(session.duplicate_selected() and data.voxels.size() == 2, "Duplicate creates a distinct stable component ID")
	var copied_uid: String = session.selection[0]
	check(copied_uid != uid, "Copy IDs are independent")
	check(session.set_properties({"locked": true}), "A part can be locked")
	var before: Dictionary = data.to_dictionary()
	check(not session.translate_selected(Vector3.ONE) and not session.erase_selected() and data.to_dictionary() == before, "Locked parts cannot move or be deleted")
	check(session.set_properties({"locked": false, "hidden": true}) and session.selected_parts()[0].hidden, "Hidden parts remain accessible through the parts list")
	session.set_properties({"hidden": false})
	check(session.mirror_selected(), "Mirror creates a matching opposite component")
	var mirrored_count: int = data.voxels.size()
	session.mirror_selected()
	check(data.voxels.size() == mirrored_count, "Repeating mirror never adds coincident duplicates")
	session.undo()
	session.translate_selected(Vector3(0, 0.0325, 0))
	check(session.redo_stack.is_empty(), "A new edit after undo clears the redo branch")
	for i in range(70):
		session.translate_selected(Vector3(0.001, 0, 0))
	check(session.undo_stack.size() == 64, "Undo snapshots remain bounded at 64 steps")
	var foreign := Geometry.primitive("头部装备", Vector3(0, 1.9, 0), Vector3.ONE * 0.1)
	data.add_part(foreign)
	check(session.clear_category() and data.voxels.size() == 1 and data.voxels[0].part == "头部装备", "Clear removes only the active equipment category")
	check(session.undo() and data.voxels.size() > 1, "Clear is reversible")
	var snapshot := session.snapshot()
	var invalid_part := part.duplicate(true)
	invalid_part.dimensions = [0.0, 0.1, 0.1]
	check(session.add(invalid_part).is_empty() and session.snapshot().data == snapshot.data, "Invalid primitive insertion is an atomic failed transaction")

	for shape in ["box", "wedge", "cone"]:
		var sample = Data.new(shape, "头部装备")
		sample.add_part(Geometry.primitive("头部装备", Vector3.ZERO, Vector3(1.04, 1.04, 1.04), Vector3(15, 45, 90), shape))
		var volume := Geometry.volume(sample.voxels[0])
		var expected: float = pow(1.04, 3.0) * (0.5 if shape == "wedge" else (1.0 / 3.0 if shape == "cone" else 1.0))
		check(is_equal_approx(volume, expected), "Geometric material volume is correct for " + shape)
		var costs := Equipment.material_cost(sample.to_dictionary())
		sample.voxels[0].tint = "143abc"
		sample.voxels[0].rotation = [55.0, 120.0, -35.0]
		check(costs == Equipment.material_cost(sample.to_dictionary()), "Rotation and dye do not change material consumption")
	var presets := Presets.all()
	check(presets.size() == 21, "All three official outfits expose seven editable templates")
	for design in presets:
		check(Data.validation_error(design).is_empty() and not design.voxels.is_empty(), "Every official template uses the public validated blueprint format")
		var first: Dictionary = design.voxels[0]
		first.tint = "123456"
		check(Presets.design_for_item(int(design.source_item_id)).voxels[0].tint != "123456", "Editing a preset copy cannot mutate official source data")

	var many = Data.new("batch", "头部装备")
	for i in range(100):
		var element := Geometry.primitive("头部装备", Vector3(float(i) * 0.01, 1.9, 0.4), Vector3.ONE * 0.02, Vector3.ZERO, "box", "head")
		many.add_part(element)
	var character = Character.new()
	root.add_child(character)
	var renderer = Renderer.new()
	root.add_child(renderer)
	renderer.build(many.to_dictionary(), character)
	check(renderer.source_part_count == 100 and renderer.pieces.size() == 1, "Same-anchor same-material rigid components are merged into one mesh")
	check(renderer.pieces[0].get_parent() == character.head, "Merged geometry keeps its intended animated anchor")
	check(character.find_children("*", "CollisionObject3D", true, false).is_empty(), "Worn designs create no editor picking bodies")
	renderer.free()
	await process_frame
	character.queue_free()
	await process_frame
	var path := "user://blueprint_modeling_%d_%d.json" % [OS.get_process_id(), Time.get_ticks_usec()]
	var saves = Save.new(path)
	var inv = Inventory.new()
	var cloak := Presets.design_for_item(426)
	var made: Dictionary = inv.craft_blueprint(cloak)
	check(made.ok and inv.equip_from_bag(int(made.get("index", -1))), "Editable cloth template can be made and worn")
	check(saves.save_game({"inventory": saves.save_inventory(inv)}), "Version-two inventory snapshot writes")
	var loaded = Inventory.new()
	saves.apply_inventory(loaded, saves.load_game().inventory)
	check(inv.get_slot("equipment", 5) == loaded.get_slot("equipment", 5), "Cloth, transform, tint and version metadata survive actual save/load")
	saves.delete_save()
	print("BLUEPRINT_MODELING_INTEGRITY_PASS: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

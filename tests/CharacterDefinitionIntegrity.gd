extends SceneTree

const Definition = preload("res://scripts/character/CharacterDefinition.gd")
const Session = preload("res://scripts/character/CharacterEditSession.gd")
const Library = preload("res://scripts/character/CharacterLibrary.gd")
const Character = preload("res://scripts/player/CharacterVisual.gd")
const Presets = preload("res://scripts/blueprint/BlueprintPresets.gd")
var checks: int = 0
var failures: int = 0

func _initialize() -> void:
	create_timer(35.0).timeout.connect(func(): push_error("CHARACTER_DEFINITION_TIMEOUT"); quit(1))
	_run.call_deferred()

func check(condition: bool, text: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(text)

func _run() -> void:
	var data := Definition.new_model()
	check(Definition.validation_error(data).is_empty() and Definition.playable_error(data).is_empty(), "Generated character is valid and playable")
	check(data.cubes.size() > 100 and data.cubes.size() <= Definition.MAX_CUBES, "Default body has a bounded editable cube model")
	check(Definition.BONES.size() == 17 and Definition.rest_origins(data).size() == 17, "Humanoid rig contains seventeen stable joints")
	var below_ground := data.duplicate(true)
	below_ground.cubes[0].center[1] = -3.0
	check(not Definition.playable_error(below_ground).is_empty(), "A model with body cubes below ground cannot be applied")
	var original := data.duplicate(true)
	var broad := data.duplicate(true)
	broad.parameters.merge({"height":1.65,"body_width":1.6,"body_depth":1.5},true)
	broad.cubes = Definition.reshape(data,broad)
	check(Definition.validation_error(broad).is_empty() and Definition.playable_error(broad).is_empty(),"Reshaping a detailed body keeps a valid playable cube budget")
	var fit := Definition.local_fit(data,broad,"chest")
	var continuous := true
	for x in [-0.18,-0.09,0.0,0.09,0.18]:
		for y in [-0.27,-0.135,0.0,0.135,0.27]:
			for z in [-0.07,0.0,0.07]:
				continuous = continuous and covers(broad.cubes,"chest",fit * Vector3(x,y,z))
	check(continuous,"A broad reshaped torso remains filled across its interior")
	var hollow := data.duplicate(true)
	hollow.cubes = []
	for x in range(2):
		for y in range(2):
			for z in range(2):
				if x == 1 and y == 1 and z == 1:
					continue
				hollow.cubes.append({"id":"cut_%d%d%d" % [x,y,z],"bone":"chest","center":[x*0.1,y*0.1,z*0.1],"edge":0.1,"color":"4f98aa"})
	var reshaped_hollow := hollow.duplicate(true)
	reshaped_hollow.parameters.body_width = 1.5
	reshaped_hollow.cubes = Definition.reshape(hollow,reshaped_hollow)
	var hollow_fit := Definition.local_fit(hollow,reshaped_hollow,"chest")
	check(not covers(reshaped_hollow.cubes,"chest",hollow_fit * (Vector3.ONE * 0.1)),"Reshaping preserves a deliberately removed voxel rather than filling the group's entire bounds")
	for values in [{"height": 1.15, "head_size": 1.2}, {"height": 2.6, "body_width": 0.8, "leg_length": 1.3}, {"height": 1.65, "body_width": 1.6, "body_depth": 1.5, "leg_width": 1.2}]:
		var profile := Definition.new_model("测试体型", values)
		check(Definition.validation_error(profile).is_empty() and Definition.playable_error(profile).is_empty(), "Short, tall and broad profiles remain playable")
		var valid := true
		for cube in profile.cubes:
			valid = valid and float(cube.edge) >= 0.005 and not cube.has("rotation") and not cube.has("dimensions")
		check(valid, "Body generation only produces upright equal-edge cubes")
	var character = Character.new()
	root.add_child(character)
	check(character.apply_character(data), "Actual CharacterVisual accepts an editable character")
	var optional := data.duplicate(true)
	optional.erase("sockets")
	check(character.apply_character(optional) and character.character_definition.sockets.has("right_grip"), "Missing optional sockets normalize to safe defaults")
	check(character.rig_nodes.size() == 17 and not character._model_pieces.is_empty(), "Actual visual uses the configurable rig and merged body meshes")
	var unfitted := true
	for group in character.equipment_visuals.pieces:
		for piece in group:
			unfitted = unfitted and not piece.get_meta("fitted",false)
	check(unfitted,"Unused basic equipment does not perform body fitting")
	for state in [0,1,2,3,4]:
		for frame in range(8):
			character.animate(1.0/60.0, 7.8 if state == 1 else 0.0, state == 2, state == 4, state == 3, state == 3, state == 0, state == 1)
		var rigid := true
		for piece in character._model_pieces:
			var basis: Basis = piece.global_basis
			rigid = rigid and basis.get_scale().is_equal_approx(Vector3.ONE) and absf(basis.x.dot(basis.y)) < 0.00001 and absf(basis.y.dot(basis.z)) < 0.00001
		check(rigid, "Animation never scales or shears character cubes")
	var gear := Presets.design_for_item(406)
	var gear_before := gear.duplicate(true)
	var equipment_ids: Array[int] = [0,0,0,0,0,406,0]
	character.equipment_visuals.apply_equipment(equipment_ids)
	var tall := Definition.new_model("长腿人物", {"height": 2.5, "leg_length": 1.2})
	check(character.apply_character(tall), "Body can change with equipment attached")
	check(character.equipment_visuals.equipped_ids[5] == 406, "Changing the body preserves equipped items")
	var retained_equipment: Node3D = character.equipment_visuals
	var recolored := tall.duplicate(true)
	recolored.cubes[0].color = "557799"
	character.apply_character(recolored)
	check(character.equipment_visuals == retained_equipment,"Geometry-only edits reuse fitted equipment when the rig is unchanged")
	check(gear == gear_before and Presets.design_for_item(406) == gear_before, "Fitting equipment never edits its source blueprint")
	character.set_held_block(201)
	check(character.held_item.get_parent() == character.rig_nodes.right_hand and character.held_item.global_position.is_equal_approx(character.global_transform * Definition.socket_position(tall,"right_grip")), "Tool grip follows the independent new hand joint")
	check(character.apply_character({}) and character._model_pieces.is_empty() and character.body_metrics.height == 1.8, "Reset restores the legacy character without destroying its base meshes")
	character.queue_free()
	await process_frame
	var session = Session.new()
	session.bind(data)
	check(session.add("right_hand", Vector3(0.2,0,0), 0.065, Color("aabbcc")), "Add an independent hand-bound cube")
	var added_id: String = session.selection[0]
	var edited: Dictionary = session.model.duplicate(true)
	check(session.set_parameter("body_width", 1.2), "Proportional reshape succeeds after hand editing")
	var first_shape: Array = session.model.cubes.duplicate(true)
	check(session.set_parameter("body_width", 1.4) and session.set_parameter("body_width", 1.2), "Body proportions can be edited repeatedly")
	check(session.model.cubes == first_shape, "Returning a slider to its prior value rebuilds from a stable reference")
	check(session.undo() and session.redo() and session.model.cubes == first_shape, "History restores both skeletal parameters and cube geometry")
	session.bind(edited)
	session.select([added_id])
	var from: Dictionary = session.model.cubes[session.find(added_id)]
	var center: Vector3 = Definition.rest_origins(session.model)[from.bone] + Definition.vector(from.center)
	check(session.set_properties({"bone": "left_hand"}), "Cube can be rebound to another joint")
	var rebound: Dictionary = session.model.cubes[session.find(added_id)]
	check((Vector3(Definition.rest_origins(session.model)[rebound.bone]) + Definition.vector(rebound.center)).is_equal_approx(center), "Changing attachment preserves the model-space position")
	check(session.duplicate_selected(true), "Mirrored copy is created")
	var mirrored: Dictionary = session.model.cubes[session.find(session.selection[0])]
	var mirror_position: Vector3 = Definition.rest_origins(session.model)[mirrored.bone] + Definition.vector(mirrored.center)
	check(mirror_position.is_equal_approx(Vector3(-center.x,center.y,center.z)), "Mirror swaps left/right attachment and reflects position")
	var before: PackedByteArray = session.snapshot()
	check(not session.set_properties({"edge": -1}) and session.snapshot() == before, "Invalid geometry is an atomic failed transaction")
	check(not session.move_joint("left_forearm", Vector3(0,3.5,0)) and session.snapshot() == before, "Invalid skeletal edits never enter history or inverse-transform calculations")
	check(session.move_joint("left_arm", Vector3(-0.43,1.35,0), true, false), "Joint branch can be moved symmetrically")
	var origins := Definition.rest_origins(session.model)
	check(is_equal_approx(Vector3(origins.left_arm).x, -Vector3(origins.right_arm).x), "Symmetric joint editing keeps opposite shoulders aligned")
	session.read_only = true
	before = session.snapshot()
	check(not session.add("head", Vector3.ZERO,0.1,Color.WHITE) and session.snapshot() == before and not session.undo(), "Animation preview protects the model from editing")
	var library = Library.new()
	library.storage.save_path = "user://character_integrity.json"
	check(library.save_model(original), "Character library writes a complete validated model")
	original.name = "外部更改"
	check(library.designs[0].name != original.name, "Library stores an independent model snapshot")
	var restored = Library.new()
	restored.storage.save_path = library.storage.save_path
	check(restored.load_library() and Definition.validation_error(restored.designs[0]).is_empty(), "Character library reloads its rig and body")
	restored.storage.save_path = "user://missing_character_directory/library.json"
	var old_designs: Array = restored.designs.duplicate(true)
	check(not restored.save_model(data) and restored.designs == old_designs, "Library write failure leaves the previous in-memory designs intact")
	for modification in [{"bone":"unknown"}, {"edge":0.0}, {"rotation":[0,0,0]}, {"color":"broken"}, {"center":[0,0,100]}]:
		var invalid := data.duplicate(true)
		invalid.cubes[0].merge(modification,true)
		check(not Definition.validation_error(invalid).is_empty(), "Malformed character cube is rejected")
	check(library.storage.delete_save(), "Isolated character library is cleaned up")
	await process_frame
	print("CHARACTER_DEFINITION_INTEGRITY_PASS: %d checks, %d failures" % [checks,failures])
	quit(0 if failures == 0 else 1)

func covers(cubes: Array,bone: String,point: Vector3) -> bool:
	for cube in cubes:
		if cube.bone != bone:
			continue
		var half: float = float(cube.edge)*0.5 + 0.00001
		var offset := (Definition.vector(cube.center)-point).abs()
		if maxf(offset.x,maxf(offset.y,offset.z)) <= half:
			return true
	return false

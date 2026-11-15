extends SceneTree

const Definition = preload("res://scripts/character/CharacterDefinition.gd")
const Session = preload("res://scripts/character/CharacterEditSession.gd")
const Character = preload("res://scripts/player/CharacterVisual.gd")
const Saves = preload("res://scripts/system/SaveSystem.gd")
var checks: int = 0
var failures: int = 0
var _cells: Dictionary = {}
var _character: Node3D
var _tolerance: float = 0.004
var _last_missing: String = ""
var _camera: Camera3D

func _initialize() -> void:
	create_timer(35.0).timeout.connect(func(): push_error("CHARACTER_CONNECTIVITY_TIMEOUT"); quit(1))
	_run.call_deferred()

func check(condition: bool, text: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(text)

func _run() -> void:
	var base := Definition.new_model("连接性检查")
	var cases: Array[Dictionary] = [{"name":"default","data":base}]
	for values in [
		{"shoulder_width":1.5},
		{"shoulder_width":0.7,"hip_width":0.75},
		{"body_width":0.65,"shoulder_width":1.5,"hip_width":1.5},
		{"height":1.15,"body_width":1.5,"body_depth":1.4,"leg_width":1.3},
		{"height":2.6,"leg_length":1.3,"torso_length":0.8,"arm_length":1.3},
		{"body_width":1.6,"body_depth":1.5,"shoulder_width":0.8,"hip_width":0.8}]:
		var session = Session.new()
		session.bind(base)
		check(session.set_parameters(values),"Apply body proportions "+JSON.stringify(values))
		cases.append({"name":JSON.stringify(values),"data":session.model})
	for command in [
		["neck",Vector3(0,1.55,0),true],
		["head",Vector3(0.08,1.775,0.08),false],
		["chest",Vector3(0,1.2125,0),false],
		["chest",Vector3(0.1,1.1125,0.1),false],
		["right_arm",Vector3(0.49,1.45,0.12),true],
		["right_forearm",Vector3(0.45,0.95,0.12),true],
		["right_hand",Vector3(0.45,0.735,0.15),true],
		["right_lower_leg",Vector3(0.1125,0.485,0),true],
		["right_lower_leg",Vector3(0.22,0.385,0.1),false],
		["right_foot",Vector3(0.2,0.09,-0.12),false],
		["pelvis",Vector3(0,0.795,0),false]]:
		var session = Session.new()
		session.bind(base)
		check(session.move_joint(command[0],command[1],command[2],true),"Move skeleton joint "+str(command[0]))
		if str(command[0]) == "right_lower_leg":
			var origins := Definition.rest_origins(session.model)
			check(is_equal_approx(Vector3(origins.right_lower_leg).y,Vector3(command[1]).y),"Knee moves to its requested height")
			check(is_equal_approx(Vector3(origins.right_foot).y,0.09),"Moving a knee keeps the sole planted")
		cases.append({"name":str(command[0]),"data":session.model})
	var combined = Session.new()
	combined.bind(base)
	check(combined.move_joint("right_lower_leg",Vector3(0.1125,0.485,0),true,true),"Prepare a sequential knee edit")
	check(combined.add("neck",Vector3(0,0.1,0),0.065,Color("f5d3b0")),"Add a handmade neck detail before editing its endpoint")
	check(combined.move_joint("head",Vector3(0.08,1.775,0.08),false,true),"Move the head after editing the knees")
	check(combined.set_parameters({"height":2.4,"body_width":1.4,"shoulder_width":1.2,"leg_length":1.15}),"Change proportions after editing multiple joints")
	var handmade_neck := _bounds(combined.model,"neck",false)
	check(handmade_neck.get_center().x-Vector3(Definition.rest_origins(combined.model).neck).x > 0.01,"Handmade neck geometry follows the head's lateral change as well as its height")
	cases.append({"name":"sequential_joint_and_body_edits","data":combined.model})
	_character = Character.new()
	_character.editor_mode = true
	_character.rotation.y = PI
	root.add_child(_character)
	if "--capture" in OS.get_cmdline_user_args() and DisplayServer.get_name()!="headless":
		_setup_visuals()
	for case_index in cases.size():
		var entry: Dictionary = cases[case_index]
		var data: Dictionary = entry.data
		check(Definition.validation_error(data).is_empty(),"Connected body remains valid: "+str(entry.name))
		check(_character.apply_character(data),"Render connected model: "+str(entry.name))
		_prepare_cells(data)
		_character._reset_rig(data)
		_character.held_item.visible = false
		var rest_connected := _contacts()
		check(rest_connected,"Rest-pose connections: "+str(entry.name)+" · "+_last_missing)
		if case_index in [1,2,7,8,9]:
			await _capture("rest_%d" % case_index,data)
		for pose in range(6):
			_character._reset_rig(data)
			_character.set_held_block(201)
			_character.held_item.visible = pose==5
			var connected := true
			for frame in range(16):
				_character.animate(1.0/30.0,7.8 if pose==1 else (4.8 if pose in [0,3] else 0.0),pose==4,pose==5,pose==3,pose==3,pose==2,pose==1)
				if frame in [3,7,15]:
					connected = connected and _contacts()
			check(connected,"Animated connections %d: %s · %s" % [pose,entry.name,_last_missing])
			if (case_index==10 and pose==1) or (case_index==11 and pose==3) or (case_index==12 and pose==5) or (case_index==14 and pose==2):
				await _capture("pose_%d_%d" % [case_index,pose],data)
		var rigid := true
		for node in _character.rig_nodes.values():
			rigid = rigid and node.global_basis.get_scale().is_equal_approx(Vector3.ONE)
		check(rigid,"Connection repair keeps rigid, unscaled joints: "+str(entry.name))
		await process_frame
	var narrow: Dictionary = cases[2].data
	_prepare_cells(narrow)
	_character.apply_character(narrow)
	_character._reset_rig(narrow)
	var left := _bounds(narrow,"left_leg")
	var right := _bounds(narrow,"right_leg")
	check(left.end.x <= right.position.x+0.004,"Narrow hips do not force the two thighs through each other")
	var chest := _bounds(narrow,"chest",false)
	var arm := _bounds(narrow,"right_arm",false)
	check(chest.end.x <= arm.position.x+0.01,"Narrow shoulders constrain the torso instead of burying the arm inside it")
	# Legacy definitions retain their authored blocks. The explicit repair
	# operation adds/rebuilds only the known joint links and is undoable.
	var legacy := base.duplicate(true)
	legacy.cubes = legacy.cubes.filter(func(cube): return not cube.has("connection"))
	legacy.parameters.shoulder_width = 1.5
	var legacy_session = Session.new()
	legacy_session.bind(legacy)
	var before: Dictionary = legacy_session.model.duplicate(true)
	_character.apply_character(legacy)
	_prepare_cells(legacy)
	check(not _contacts(),"The contact check detects the original disconnected legacy shoulder")
	check(legacy_session.repair_connections(),"Legacy body can explicitly repair its joints")
	check(legacy_session.model.cubes.slice(0,legacy.cubes.size()) == legacy.cubes,"Repair preserves every authored legacy cube")
	_character.apply_character(legacy_session.model)
	_prepare_cells(legacy_session.model)
	check(_contacts(),"Legacy wide shoulders are connected after repair")
	check(legacy_session.undo() and legacy_session.model == before,"Undo restores the exact legacy body")
	check(legacy_session.redo(),"Joint repair can be redone")
	var missing_arm := base.duplicate(true)
	missing_arm.cubes = missing_arm.cubes.filter(func(cube): return not str(cube.bone).begins_with("left_arm") and not str(cube.bone).begins_with("left_forearm") and not str(cube.bone).begins_with("left_hand"))
	var repaired := Definition.repaired_connections(missing_arm)
	check(not repaired.any(func(cube): return str(cube.get("connection","")).begins_with("left_shoulder")),"Repair does not resurrect a deliberately removed arm")
	var saves = Saves.new("user://character_connections.json")
	check(saves.save_game({"character":legacy_session.model}),"Connected character saves")
	var restored: Dictionary = saves.load_game().character
	check(Definition.validation_error(restored).is_empty() and restored.cubes.size()==legacy_session.model.cubes.size(),"Save round trip preserves connection metadata")
	_character.apply_character(restored)
	_prepare_cells(restored)
	check(_contacts(),"Reload retains connected joints")
	check(saves.delete_save(),"Isolated connection save is cleaned up")
	_character.queue_free()
	await process_frame
	print("CHARACTER_CONNECTIVITY_INTEGRITY_PASS: %d checks, %d failures" % [checks,failures])
	quit(0 if failures==0 else 1)

func _prepare_cells(data: Dictionary) -> void:
	_cells.clear()
	_tolerance = Definition.unit(data)*0.004
	for cube in data.cubes:
		if not _cells.has(cube.bone):
			_cells[cube.bone] = []
		_cells[cube.bone].append({"center":Definition.vector(cube.center),"half":float(cube.edge)*0.5})

func _covered(bone: String, world_point: Vector3) -> bool:
	var local: Vector3 = _character.rig_nodes[bone].global_transform.affine_inverse()*world_point
	for cell in _cells.get(bone,[]):
		var distance := (local-Vector3(cell.center)).abs()
		if maxf(distance.x,maxf(distance.y,distance.z)) <= float(cell.half)+_tolerance:
			return true
	return false

func _contacts() -> bool:
	_last_missing = ""
	for pair in [["pelvis","chest","pelvis"],["neck","chest","neck"],["head","neck","head"]]:
		var point: Vector3 = _character.rig_nodes[pair[0]].global_position
		if not _covered(pair[1],point) or not _covered(pair[2],point):
			_last_missing = "%s / %s" % [pair[1],pair[2]]
			return false
	for side in ["left","right"]:
		for pair in [["_arm","chest","_arm"],["_forearm","_arm","_forearm"],["_hand","_forearm","_hand"],["_leg","pelvis","_leg"],["_lower_leg","_leg","_lower_leg"],["_foot","_lower_leg","_foot"]]:
			var point: Vector3 = _character.rig_nodes[side+str(pair[0])].global_position
			var parent: String = str(pair[1]) if pair[1] in ["chest","pelvis"] else side+str(pair[1])
			if not _covered(parent,point) or not _covered(side+str(pair[2]),point):
				_last_missing = "%s / %s" % [parent,side+str(pair[2])]
				return false
	return true

func _bounds(data: Dictionary,bone: String,include_connections: bool=true) -> AABB:
	var result := AABB()
	var first := true
	var origin: Vector3 = Definition.rest_origins(data)[bone]
	for cube in data.cubes:
		if cube.bone == bone and (include_connections or not cube.has("connection")):
			var box := AABB(origin+Definition.vector(cube.center)-Vector3.ONE*float(cube.edge)*0.5,Vector3.ONE*float(cube.edge))
			result = box if first else result.merge(box)
			first = false
	return result

func _setup_visuals() -> void:
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("81939b")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color("d4e2e5")
	environment.environment.ambient_light_energy = 0.7
	root.add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-35,-30,0)
	sun.light_energy = 1.0
	root.add_child(sun)
	_camera = Camera3D.new()
	_camera.fov = 38.0
	root.add_child(_camera)
	_camera.make_current()

func _capture(tag: String,data: Dictionary) -> void:
	if _camera==null:
		return
	var height: float = Definition.metrics(data).height
	var center := Vector3(0,height*0.52,0)
	_camera.look_at_from_position(center+Vector3(1.5,0.4,3.3)*maxf(0.75,height/1.8),center)
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("C:/Users/Qi/AppData/Local/Temp/opencode/character-connection-"+tag+".png")

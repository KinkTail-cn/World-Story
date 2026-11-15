extends RefCounted

const VERSION: int = 1
const MAX_CUBES: int = 16384
const BONES: Array[String] = ["body", "pelvis", "chest", "neck", "head", "left_arm", "left_forearm", "left_hand", "right_arm", "right_forearm", "right_hand", "left_leg", "left_lower_leg", "left_foot", "right_leg", "right_lower_leg", "right_foot"]
const BONE_NAMES: Array[String] = ["根节点", "骨盆", "胸部", "颈部", "头部", "左大臂", "左前臂", "左掌心", "右大臂", "右前臂", "右掌心", "左大腿", "左小腿", "左脚", "右大腿", "右小腿", "右脚"]
const PARENTS := {"body": "", "pelvis": "body", "chest": "pelvis", "neck": "chest", "head": "neck", "left_arm": "chest", "right_arm": "chest", "left_forearm": "left_arm", "right_forearm": "right_arm", "left_hand": "left_forearm", "right_hand": "right_forearm", "left_leg": "pelvis", "right_leg": "pelvis", "left_lower_leg": "left_leg", "right_lower_leg": "right_leg", "left_foot": "left_lower_leg", "right_foot": "right_lower_leg"}
const DEFAULTS := {"height": 1.8, "torso_length": 1.0, "leg_length": 1.0, "arm_length": 1.0, "shoulder_width": 1.0, "hip_width": 1.0, "body_width": 1.0, "body_depth": 1.0, "arm_width": 1.0, "leg_width": 1.0, "head_size": 1.0}
const PARAMETER_NAMES := {"height": "基础身高（米）", "torso_length": "躯干比例", "leg_length": "腿长比例", "arm_length": "手臂长度", "shoulder_width": "肩宽", "hip_width": "胯宽", "body_width": "胸腰宽度", "body_depth": "身体厚度", "arm_width": "手臂粗细", "leg_width": "腿部粗细", "head_size": "头部大小"}
const RANGES := {"height": Vector2(1.1, 2.8), "torso_length": Vector2(0.7, 1.4), "leg_length": Vector2(0.7, 1.4), "arm_length": Vector2(0.65, 1.4), "shoulder_width": Vector2(0.7, 1.5), "hip_width": Vector2(0.75, 1.5), "body_width": Vector2(0.65, 1.8), "body_depth": Vector2(0.65, 1.8), "arm_width": Vector2(0.65, 1.6), "leg_width": Vector2(0.65, 1.6), "head_size": Vector2(0.7, 1.35)}
const PALETTE := {"skin": "f5d3b0", "hair": "563e3d", "shirt": "4f98aa", "trim": "fff0cf", "leather": "78513f", "pants": "384862", "eyes": "304354"}
const SOCKETS := {"eyes": {"bone": "head", "offset": [0, 0.025, 0]}, "breathing": {"bone": "head", "offset": [0, -0.125, 0]}, "right_grip": {"bone": "right_hand", "offset": [0, 0, 0]}}
const CONNECTION_IDS: Array[String] = ["waist", "neck", "left_shoulder", "right_shoulder", "left_hip", "right_hip", "left_wrist", "right_wrist", "left_ankle", "right_ankle", "left_shoulder_cap", "right_shoulder_cap", "left_elbow_cap", "right_elbow_cap", "left_elbow_upper_cap", "right_elbow_upper_cap", "left_hip_cap", "right_hip_cap", "left_knee_cap", "right_knee_cap", "left_knee_upper_cap", "right_knee_upper_cap"]

static func vector(value: Variant) -> Vector3:
	return Vector3(float(value[0]), float(value[1]), float(value[2]))

static func array(value: Vector3) -> Array:
	return [snappedf(value.x, 0.000001), snappedf(value.y, 0.000001), snappedf(value.z, 0.000001)]

static func parameters(data: Dictionary) -> Dictionary:
	var result := DEFAULTS.duplicate()
	result.merge(data.get("parameters", {}), true)
	return result

static func unit(data: Dictionary) -> float:
	var p := parameters(data)
	return float(p.height) / (0.675 * float(p.leg_length) + 0.675 * float(p.torso_length) + 0.45 * float(p.head_size))

static func rest_origins(data: Dictionary) -> Dictionary:
	var p := parameters(data)
	var u := unit(data)
	var hip := 0.675 * float(p.leg_length) * u
	var shoulder := hip + 0.675 * float(p.torso_length) * u
	var result := {"body": Vector3.ZERO, "pelvis": Vector3(0, hip, 0), "chest": Vector3(0, (hip + shoulder) * 0.5, 0), "neck": Vector3(0, shoulder, 0), "head": Vector3(0, shoulder + 0.225 * float(p.head_size) * u, 0)}
	for side in ["left", "right"]:
		var sign_value := -1.0 if side == "left" else 1.0
		var arm_x := (0.225 * float(p.body_width) + 0.1125 * float(p.arm_width)) * float(p.shoulder_width) * u * sign_value
		var leg_x := (0.1075 * float(p.leg_width) + 0.005) * float(p.hip_width) * u * sign_value
		result[side + "_arm"] = Vector3(arm_x, shoulder, 0)
		result[side + "_forearm"] = Vector3(arm_x, shoulder - 0.34 * float(p.arm_length) * u, 0)
		result[side + "_hand"] = Vector3(arm_x, shoulder - 0.565 * float(p.arm_length) * u, 0)
		result[side + "_leg"] = Vector3(leg_x, hip, 0)
		result[side + "_lower_leg"] = Vector3(leg_x, hip - 0.34 * float(p.leg_length) * u, 0)
		result[side + "_foot"] = Vector3(leg_x, 0.09 * float(p.leg_length) * u, 0)
	for bone in data.get("joints", {}):
		if bone in BONES and bone != "body":
			result[bone] = vector(data.joints[bone])
	var foot_half := 0.09 * float(p.leg_length) * u
	var floor_offset := minf(Vector3(result.left_foot).y,Vector3(result.right_foot).y) - foot_half
	if absf(floor_offset) > 0.000001:
		for bone in BONES:
			if bone != "body":
				result[bone] = Vector3(result[bone]) - Vector3.UP * floor_offset
	return result

static func normalize_joints(data: Dictionary) -> void:
	if data.get("joints",{}).is_empty():
		return
	var origins := rest_origins(data)
	for bone in BONES:
		if bone != "body":
			data.joints[bone] = array(origins[bone])

static func move_branch(data: Dictionary, bone: String, delta: Vector3, origins: Dictionary) -> void:
	for candidate in BONES:
		var ancestor: String = candidate
		while not ancestor.is_empty():
			if ancestor == bone:
				var position: Vector3 = origins[candidate] + delta
				# Editing the knee or pelvis changes limb proportions. Keep
				# descendant soles planted; an explicitly edited foot is free.
				if candidate.ends_with("_foot") and candidate != bone:
					position.y = Vector3(origins[candidate]).y
				data.joints[candidate] = array(position)
				break
			ancestor = PARENTS[ancestor]

static func _form_frame(data: Dictionary, bone: String) -> Transform3D:
	var origins := rest_origins(data)
	var p := parameters(data)
	var u := unit(data)
	var scale := Vector3.ONE * u
	var origin: Vector3 = origins[bone]
	var along := Vector3.UP * u
	if bone in ["body", "chest", "pelvis"]:
		scale = Vector3(float(p.body_width), float(p.torso_length), float(p.body_depth)) * u
		along = (Vector3(origins.neck) - Vector3(origins.pelvis)) / 0.675
		if bone in ["body", "chest"]:
			# The torso must reach both endpoints even when its chest pivot
			# was moved separately from the pelvis or neck.
			origin = (Vector3(origins.neck)+Vector3(origins.pelvis))*0.5
			var arm_half := 0.1125*float(p.arm_width)*u
			var clearance := minf(Vector3(origins.right_arm).x-origin.x-arm_half,origin.x-Vector3(origins.left_arm).x-arm_half)
			scale.x = minf(scale.x,maxf(0.05*u,clearance)/0.225)
	elif bone == "neck":
		scale = Vector3.ONE * float(p.head_size) * u
		along = Vector3(origins.head)-Vector3(origins.neck)
		along.y = maxf(0.005,along.y)
		along /= 0.225
	elif bone == "head":
		scale = Vector3.ONE * float(p.head_size) * u
		along = Vector3.UP * scale.y
	elif bone.ends_with("_arm") or bone.ends_with("_forearm") or bone.ends_with("_hand"):
		scale = Vector3(float(p.arm_width), float(p.arm_length), float(p.arm_width)) * u
		along = Vector3.UP * scale.y
		if bone.ends_with("_arm"):
			along = (Vector3(origins[bone]) - Vector3(origins[bone.replace("_arm", "_forearm")])) / 0.34
		elif bone.ends_with("_forearm"):
			along = (Vector3(origins[bone]) - Vector3(origins[bone.replace("_forearm", "_hand")])) / 0.225
	else:
		scale = Vector3(float(p.leg_width), float(p.leg_length), float(p.leg_width)) * u
		var prefix := "_foot" if bone.ends_with("_foot") else ("_lower_leg" if bone.ends_with("_lower_leg") else "_leg")
		var spacing: float = absf(Vector3(origins["right"+prefix]).x-Vector3(origins["left"+prefix]).x)
		scale.x = minf(scale.x,maxf(0.05*u,spacing)/0.225)
		along = Vector3.UP * scale.y
		if bone.ends_with("_leg") and not bone.ends_with("_lower_leg"):
			along = (Vector3(origins[bone]) - Vector3(origins[bone.replace("_leg", "_lower_leg")])) / 0.34
		elif bone.ends_with("_lower_leg"):
			along = (Vector3(origins[bone]) - Vector3(origins[bone.replace("_lower_leg", "_foot")])) / 0.245
	return Transform3D(Basis(Vector3.RIGHT * scale.x, along, Vector3.BACK * scale.z), origin)

## This affine map is only used to resample volumes. It is never assigned to
## an animated node or a rendered cube, so nonuniform scale cannot leak out.
static func local_fit(source: Dictionary, target: Dictionary, bone: String) -> Transform3D:
	var from_origin: Vector3 = rest_origins(source)[bone]
	var to_origin: Vector3 = rest_origins(target)[bone]
	return Transform3D(Basis.IDENTITY, -to_origin) * _form_frame(target, bone) * _form_frame(source, bone).affine_inverse() * Transform3D(Basis.IDENTITY, from_origin)

static func socket_position(data: Dictionary, key: String) -> Vector3:
	var socket: Dictionary = data.get("sockets", {}).get(key, SOCKETS.get(key, {}))
	var bone := str(socket.get("bone", "head"))
	return Vector3(rest_origins(data)[bone]) + vector(socket.get("offset", [0, 0, 0]))

static func metrics(data: Dictionary = {}) -> Dictionary:
	if data.is_empty():
		return {"height": 1.8, "radius": 0.36, "seated_height": 1.3, "seat_offset": -0.5625, "eyes": 1.6, "eye_position": Vector3(0,1.6,0), "breathing": 1.45, "breathing_position": Vector3(0,1.45,0), "torso": 0.85, "float_height": 1.25, "interaction": 1.2, "motion_pivot": 0.9, "stride": 1.0, "unit": 1.0}
	var o := rest_origins(data)
	var p := parameters(data)
	var u := unit(data)
	var height := float(p.height)
	var radius := maxf(0.225 * float(p.body_width), (0.215 * float(p.leg_width) * 0.5 + absf(Vector3(o.left_leg).x) / u)) * u + 0.135 * u
	for cube in data.get("cubes", []):
		if str(cube.bone) not in ["body", "chest", "pelvis", "head"]:
			continue
		var pos: Vector3 = o[cube.bone] + vector(cube.center)
		height = maxf(height, pos.y + float(cube.edge) * 0.5)
		radius = maxf(radius, maxf(absf(pos.x), absf(pos.z)) + float(cube.edge) * 0.5 + 0.05 * u)
	var hip: float = Vector3(o.pelvis).y
	return {"height": height, "radius": radius, "seated_height": maxf(radius * 2.0, height - hip + 0.175 * u), "seat_offset": -hip + 0.1125 * u, "eyes": socket_position(data, "eyes").y, "eye_position": socket_position(data,"eyes"), "breathing": socket_position(data, "breathing").y, "breathing_position": socket_position(data,"breathing"), "torso": hip + 0.175 * u, "float_height": socket_position(data, "breathing").y - 0.20 * u, "interaction": Vector3(o.chest).y + 0.1875 * u, "motion_pivot": hip + 0.225 * float(p.torso_length) * u, "stride": maxf(0.4, hip / 0.675), "unit": u}

static func new_model(name: String = "我的人物", values: Dictionary = {}) -> Dictionary:
	var data := {"schema_version": VERSION, "id": "character_" + Crypto.new().generate_random_bytes(8).hex_encode(), "name": name, "parameters": DEFAULTS.duplicate(), "joints": {}, "sockets": SOCKETS.duplicate(true), "palette": PALETTE.duplicate(), "cubes": []}
	data.parameters.merge(values, true)
	_update_default_sockets(data)
	data.cubes = generate_body(data)
	return data

static func normalized(data: Dictionary) -> Dictionary:
	if data.is_empty():
		return {}
	var result := data.duplicate(true)
	result.parameters = parameters(data)
	result.joints = data.get("joints",{}).duplicate(true)
	result.sockets = SOCKETS.duplicate(true)
	result.sockets.merge(data.get("sockets",{}),true)
	result.palette = PALETTE.duplicate()
	result.palette.merge(data.get("palette",{}),true)
	return result

static func _update_default_sockets(data: Dictionary) -> void:
	var head_scale := float(parameters(data).head_size) * unit(data)
	data.sockets = SOCKETS.duplicate(true)
	data.sockets.eyes.offset = [0, 0.025 * head_scale, 0]
	data.sockets.breathing.offset = [0, -0.125 * head_scale, 0]

static func generate_body(data: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var reference := {"parameters": DEFAULTS, "joints": {}}
	var origins := rest_origins(reference)
	var sources := _body_boxes()
	var budget := MAX_CUBES / sources.size()
	for source in sources:
		var bone: String = source.bone
		var center: Vector3 = source.center - Vector3(origins[bone])
		var cells := voxelize_box(center, source.size, local_fit(reference, data, bone), int(budget))
		for cell in cells:
			result.append({"id": "base_%d" % result.size(), "bone": bone, "center": array(cell.center), "edge": snappedf(float(cell.edge), 0.000001), "color": str(data.get("palette", PALETTE).get(source.color, PALETTE[source.color]))})
	var reference_body := data.duplicate(false)
	reference_body.cubes = result
	return _append_connections(result,connection_cubes(reference_body,data))

static func voxelize_box(center: Vector3, size: Vector3, fit: Transform3D, budget: int = 128) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if budget <= 0:
		return result
	var box: AABB = fit * AABB(center - size * 0.5, size)
	var axes := Vector3(fit.basis.x.length(), fit.basis.y.length(), fit.basis.z.length())
	if size.is_equal_approx(Vector3.ONE * size.x) and axes.is_equal_approx(Vector3.ONE * axes.x) and fit.basis.x.normalized().is_equal_approx(Vector3.RIGHT) and fit.basis.y.normalized().is_equal_approx(Vector3.UP) and fit.basis.z.normalized().is_equal_approx(Vector3.BACK):
		if size.x * axes.x <= 1.0:
			return [{"center": fit * center, "edge": maxf(0.005, size.x * axes.x)}]
	if fit.basis.x.normalized().is_equal_approx(Vector3.RIGHT) and fit.basis.y.normalized().is_equal_approx(Vector3.UP) and fit.basis.z.normalized().is_equal_approx(Vector3.BACK):
		return _tile_box(box, budget)
	var edge := maxf(0.005, minf(0.065, minf(box.size.x, minf(box.size.y, box.size.z))))
	var counts := Vector3i((box.size / edge).ceil()).max(Vector3i.ONE)
	while counts.x * counts.y * counts.z > budget:
		edge *= maxf(1.08, pow(float(counts.x * counts.y * counts.z) / budget, 1.0 / 3.0))
		counts = Vector3i((box.size / edge).ceil()).max(Vector3i.ONE)
	var start := box.get_center() - Vector3(counts) * edge * 0.5
	var inverse := fit.affine_inverse()
	var source_box := AABB(center - size * 0.5, size).grow(0.000001)
	for y in counts.y:
		for x in counts.x:
			for z in counts.z:
				var pos := start + (Vector3(x, y, z) + Vector3.ONE * 0.5) * edge
				if source_box.has_point(inverse * pos):
					result.append({"center": pos, "edge": edge})
	if result.is_empty():
		result.append({"center": fit * center, "edge": maxf(0.005, minf(box.size.x, minf(box.size.y, box.size.z)))})
	return result

## Tile rectangular volumes with mixed cube sizes. Keeping the outer planes
## within 2.5 mm avoids expanding thin trim onto the shirt's exact surface.
## Greedy integer cuboids also make the editable starter model much smaller.
static func _tile_box(box: AABB, budget: int) -> Array[Dictionary]:
	var quantum := 0.005
	for attempt in range(20):
		var counts := Vector3i((box.size / quantum).round()).max(Vector3i.ONE)
		var start := box.get_center() - Vector3(counts) * quantum * 0.5
		var pending: Array[Dictionary] = [{"start": Vector3i.ZERO, "size": counts}]
		var result: Array[Dictionary] = []
		var exceeded := false
		while not pending.is_empty():
			var region: Dictionary = pending.pop_back()
			var extent: Vector3i = region.size
			var origin: Vector3i = region.start
			var edge_cells := mini(mini(extent.x, mini(extent.y, extent.z)), maxi(1,int(floorf(1.0 / quantum))))
			var filled := Vector3i(extent.x / edge_cells, extent.y / edge_cells, extent.z / edge_cells)
			if result.size() + filled.x * filled.y * filled.z > budget:
				exceeded = true
				break
			for y in filled.y:
				for x in filled.x:
					for z in filled.z:
						result.append({"center": start + (Vector3(origin) + (Vector3(x,y,z) + Vector3.ONE * 0.5) * edge_cells) * quantum, "edge": float(edge_cells) * quantum})
			var used := filled * edge_cells
			if extent.x > used.x:
				pending.append({"start": origin + Vector3i(used.x,0,0), "size": Vector3i(extent.x-used.x,extent.y,extent.z)})
			if extent.y > used.y:
				pending.append({"start": origin + Vector3i(0,used.y,0), "size": Vector3i(used.x,extent.y-used.y,extent.z)})
			if extent.z > used.z:
				pending.append({"start": origin + Vector3i(0,0,used.z), "size": Vector3i(used.x,used.y,extent.z-used.z)})
		if not exceeded:
			return result
		quantum *= 1.5
	return [{"center": box.get_center(), "edge": clampf(minf(box.size.x,minf(box.size.y,box.size.z)),0.005,1.0)}]

static func reshape(reference: Dictionary, target: Dictionary) -> Array[Dictionary]:
	var connections := connection_cubes(reference,target)
	var authored: Array = reference.get("cubes",[]).filter(func(cube): return not cube.has("connection"))
	var source := _reference_volumes(authored)
	var budget := MAX_CUBES-connections.size()
	if source.size() > budget:
		return []
	var result: Array[Dictionary] = []
	var fits := {}
	for bone in BONES:
		fits[bone] = local_fit(reference, target, bone)
	for source_index in source.size():
		var cube: Dictionary = source[source_index]
		var fit: Transform3D = fits[cube.bone]
		var cells := voxelize_box(cube.center, cube.size, fit, maxi(1, (budget-result.size()) / maxi(1,source.size()-source_index)))
		for index in cells.size():
			var copy: Dictionary = cube.duplicate(true)
			copy.center = array(cells[index].center)
			copy.edge = snappedf(float(cells[index].edge), 0.000001)
			copy.erase("size")
			copy.id = "reshape_%d_%d" % [source_index,index]
			result.append(copy)
			if result.size() > budget:
				return []
	return _append_connections(result,connections)

static func repaired_connections(data: Dictionary) -> Array[Dictionary]:
	var authored: Array[Dictionary] = []
	for cube in data.cubes:
		if not cube.has("connection"):
			authored.append(cube.duplicate(true))
	return _append_connections(authored,connection_cubes(data,data))

static func _append_connections(authored: Array[Dictionary], connections: Array[Dictionary]) -> Array[Dictionary]:
	if authored.size()+connections.size() > MAX_CUBES:
		return []
	var ids := {}
	for cube in authored:
		ids[cube.id] = true
	for cube in connections:
		var id := str(cube.id)
		while ids.has(id):
			id += "_joint"
		cube.id = id
		ids[id] = true
		authored.append(cube)
	return authored

## Joint links are ordinary, editable upright cubes. Their overlapping
## centers cover the actual joint in both adjacent rigid frames, closing
## elbows and knees during motion without bending individual cubes.
static func connection_cubes(reference: Dictionary, target: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var origins := rest_origins(target)
	var defaults := rest_origins({})
	var grouped := {}
	var colors := {}
	for cube in reference.get("cubes",[]):
		if cube.has("connection"):
			if not colors.has(cube.connection):
				colors[cube.connection] = str(cube.color)
			continue
		if not grouped.has(cube.bone):
			grouped[cube.bone] = []
		grouped[cube.bone].append(cube)
	var fits := {}
	for bone in grouped:
		fits[bone] = local_fit({},reference,str(bone))
	var p := parameters(target)
	var u := unit(target)
	for spec in connection_specs():
		var supported := true
		for support in spec.supports:
			var bone := str(support.bone)
			if not grouped.has(bone):
				supported = false
				break
			var local: Vector3 = fits[bone] * (Vector3(support.point)-Vector3(defaults[bone]))
			var occupied := false
			for cube in grouped[bone]:
				var edge := float(cube.edge)+0.012*unit(reference)
				if AABB(vector(cube.center)-Vector3.ONE*edge*0.5,Vector3.ONE*edge).has_point(local):
					occupied = true
					break
			if not occupied:
				supported = false
				break
		if not supported:
			continue
		var factor: float = u * float(p[spec.profile])
		if str(spec.profile) == "leg_width":
			factor = minf(factor,maxf(0.05*u,absf(Vector3(origins.right_leg).x-Vector3(origins.left_leg).x))/0.225)
		var start: Vector3 = origins[spec.start]
		var finish: Vector3 = origins[spec.finish]
		var offset: Vector3 = Vector3.DOWN*float(spec.get("drop",0.0))*factor
		start += offset
		finish += offset
		var edge: float = snappedf(float(spec.edge)*factor,0.000001)
		if str(spec.id) == "waist":
			edge = minf(edge,0.4*_form_frame(target,"chest").basis.x.length())
			var direction := (finish-start).normalized()
			var largest := maxf(absf(direction.x),maxf(absf(direction.y),absf(direction.z)))
			var inset := minf(start.distance_to(finish)*0.5,edge*0.5/maxf(0.00001,largest))
			start += direction*inset
			finish -= direction*inset
		if str(spec.id).ends_with("_ankle"):
			edge = minf(edge,minf(start.y,finish.y)*1.8)
		var steps := maxi(1,ceili((finish-start).abs().length()/(edge*0.6)))
		var color := str(colors.get(spec.id,target.get("palette",PALETTE).get(spec.color,PALETTE[spec.color])))
		for index in range(steps+1 if start.distance_to(finish)>0.00001 else 1):
			var center := start.lerp(finish,float(index)/steps)-Vector3(origins[spec.bone])
			result.append({"id":"connection_%s_%d" % [spec.id,index],"bone":spec.bone,"center":array(center),"edge":edge,"color":color,"connection":spec.id})
	return result

static func connection_specs() -> Array[Dictionary]:
	var defaults := rest_origins({})
	var result: Array[Dictionary] = [
		{"id":"waist","bone":"chest","start":"pelvis","finish":"neck","edge":0.2,"profile":"body_depth","color":"shirt","supports":[{"bone":"pelvis","point":Vector3(defaults.pelvis)+Vector3.UP*0.04},{"bone":"chest","point":defaults.chest}]},
		{"id":"neck","bone":"neck","start":"neck","finish":"head","edge":0.14,"profile":"head_size","color":"skin","supports":[{"bone":"chest","point":Vector3(defaults.neck)-Vector3.UP*0.04},{"bone":"head","point":defaults.head}]}]
	for side in ["left","right"]:
		var shoulder: Vector3 = defaults[side+"_arm"]
		var elbow: Vector3 = defaults[side+"_forearm"]
		var hand: Vector3 = defaults[side+"_hand"]
		var hip: Vector3 = defaults[side+"_leg"]
		var knee: Vector3 = defaults[side+"_lower_leg"]
		var foot: Vector3 = defaults[side+"_foot"]
		var shoulder_support := [{"bone":"chest","point":Vector3(defaults.neck)-Vector3.UP*0.04},{"bone":side+"_arm","point":shoulder-Vector3.UP*0.04}]
		var hip_support := [{"bone":"pelvis","point":Vector3(defaults.pelvis)+Vector3.UP*0.04},{"bone":side+"_leg","point":hip-Vector3.UP*0.04}]
		var elbow_support := [{"bone":side+"_arm","point":elbow+Vector3.UP*0.04},{"bone":side+"_forearm","point":elbow-Vector3.UP*0.04}]
		var knee_support := [{"bone":side+"_leg","point":knee+Vector3.UP*0.04},{"bone":side+"_lower_leg","point":knee-Vector3.UP*0.04}]
		result.append({"id":side+"_shoulder","bone":"chest","start":"neck","finish":side+"_arm","drop":0.06,"edge":0.16,"profile":"arm_width","color":"shirt","supports":shoulder_support})
		result.append({"id":side+"_hip","bone":"pelvis","start":"pelvis","finish":side+"_leg","drop":0.025,"edge":0.14,"profile":"leg_width","color":"pants","supports":hip_support})
		result.append({"id":side+"_wrist","bone":side+"_forearm","start":side+"_forearm","finish":side+"_hand","edge":0.12,"profile":"arm_width","color":"skin","supports":[{"bone":side+"_forearm","point":elbow-Vector3.UP*0.07},{"bone":side+"_hand","point":hand}]})
		result.append({"id":side+"_ankle","bone":side+"_lower_leg","start":side+"_lower_leg","finish":side+"_foot","edge":0.14,"profile":"leg_width","color":"pants","supports":[{"bone":side+"_lower_leg","point":knee-Vector3.UP*0.07},{"bone":side+"_foot","point":foot}]})
		for entry in [["shoulder_cap","_arm","shirt","arm_width",shoulder_support],["elbow_cap","_forearm","shirt","arm_width",elbow_support],["hip_cap","_leg","pants","leg_width",hip_support],["knee_cap","_lower_leg","pants","leg_width",knee_support]]:
			result.append({"id":side+"_"+str(entry[0]),"bone":side+str(entry[1]),"start":side+str(entry[1]),"finish":side+str(entry[1]),"drop":0.06 if entry[0]=="shoulder_cap" else (0.025 if entry[0]=="hip_cap" else 0.0),"edge":0.16,"profile":str(entry[3]),"color":str(entry[2]),"supports":entry[4]})
		result.append({"id":side+"_elbow_upper_cap","bone":side+"_arm","start":side+"_forearm","finish":side+"_forearm","edge":0.16,"profile":"arm_width","color":"shirt","supports":elbow_support})
		result.append({"id":side+"_knee_upper_cap","bone":side+"_leg","start":side+"_lower_leg","finish":side+"_lower_leg","edge":0.16,"profile":"leg_width","color":"pants","supports":knee_support})
	return result

## Join exactly adjacent boxes only in the computational reference volume.
## This preserves hand-cut holes and colors while giving large connected
## surfaces a shared tiling budget instead of shrinking every source cube.
static func _reference_volumes(cubes: Array) -> Array[Dictionary]:
	var volumes: Array[Dictionary] = []
	for cube in cubes:
		var volume: Dictionary = cube.duplicate(true)
		volume.center = vector(cube.center)
		volume.size = Vector3.ONE * float(cube.edge)
		volume.erase("edge")
		volumes.append(volume)
	for pass_index in range(8):
		var previous_count := volumes.size()
		for axis in range(3):
			var groups := {}
			for volume in volumes:
				var center: Vector3 = volume.center
				var extent: Vector3 = volume.size
				var first_axis := (axis+1)%3
				var second_axis := (axis+2)%3
				var key := "%s:%s:%s:%s:%d:%d:%d:%d" % [volume.bone,volume.color,volume.get("hidden",false),volume.get("locked",false),roundi(center[first_axis]*100000.0),roundi(center[second_axis]*100000.0),roundi(extent[first_axis]*100000.0),roundi(extent[second_axis]*100000.0)]
				if not groups.has(key):
					groups[key] = []
				groups[key].append(volume)
			var combined: Array[Dictionary] = []
			for group in groups.values():
				group.sort_custom(func(a: Dictionary,b: Dictionary): return Vector3(a.center)[axis] - Vector3(a.size)[axis]*0.5 < Vector3(b.center)[axis] - Vector3(b.size)[axis]*0.5)
				var current: Dictionary = group[0]
				for index in range(1,group.size()):
					var next: Dictionary = group[index]
					var current_end: float = Vector3(current.center)[axis] + Vector3(current.size)[axis]*0.5
					var next_start: float = Vector3(next.center)[axis] - Vector3(next.size)[axis]*0.5
					if absf(current_end-next_start) <= 0.000003:
						var start: float = Vector3(current.center)[axis] - Vector3(current.size)[axis]*0.5
						var finish: float = Vector3(next.center)[axis] + Vector3(next.size)[axis]*0.5
						var merged_center: Vector3 = current.center
						var merged_size: Vector3 = current.size
						merged_center[axis] = (start+finish)*0.5
						merged_size[axis] = finish-start
						current.center = merged_center
						current.size = merged_size
					else:
						combined.append(current)
						current = next
				combined.append(current)
			volumes = combined
		if volumes.size() == previous_count:
			break
	return volumes

static func validation_error(data: Dictionary) -> String:
	if data.get("schema_version") != VERSION or not data.get("name") is String or data.name.strip_edges().is_empty() or data.name.length() > 128 or not data.get("id") is String or data.id.is_empty() or data.id.length() > 128:
		return "人物版本、名称或标识无效"
	if not data.get("parameters", {}) is Dictionary or not data.get("joints", {}) is Dictionary or not data.get("sockets", {}) is Dictionary or not data.get("palette", {}) is Dictionary:
		return "人物骨架参数格式无效"
	for key in data.get("parameters", {}):
		var value: Variant = data.parameters[key]
		if not DEFAULTS.has(key) or not _number(value) or value < RANGES[key].x or value > RANGES[key].y:
			return "体型参数超出范围：" + str(key)
	for bone in data.get("joints", {}):
		if bone not in BONES or bone == "body" or not _vector(data.joints[bone]) or vector(data.joints[bone]).length() > 4.0:
			return "关节坐标无效"
	var o := rest_origins(data)
	if Vector3(o.pelvis).y < 0.25 or Vector3(o.neck).y - Vector3(o.pelvis).y < 0.15 or Vector3(o.head).y < Vector3(o.neck).y:
		return "骨盆、躯干和头部的高度关系无效"
	for bone in ["left_arm", "right_arm", "left_forearm", "right_forearm", "left_leg", "right_leg", "left_lower_leg", "right_lower_leg"]:
		var end: String = bone.replace("_forearm", "_hand") if bone.ends_with("_forearm") else (bone.replace("_lower_leg", "_foot") if bone.ends_with("_lower_leg") else (bone.replace("_arm", "_forearm") if bone.ends_with("_arm") else bone.replace("_leg", "_lower_leg")))
		if Vector3(o[bone]).y - Vector3(o[end]).y < 0.04:
			return "肘、膝或手脚的位置需要低于上级关节"
	for key in data.get("sockets", {}):
		var socket: Variant = data.sockets[key]
		if key not in SOCKETS or not socket is Dictionary or socket.get("bone") not in BONES or not _vector(socket.get("offset")) or vector(socket.offset).length() > 1.0:
			return "人物功能点无效"
	for color in data.get("palette", {}).values():
		if not color is String or not Color.html_is_valid(color):
			return "人物配色无效"
	if not data.get("cubes") is Array or data.cubes.is_empty() or data.cubes.size() > MAX_CUBES:
		return "人物需要 1 至 16384 个立方体"
	var ids := {}
	for cube in data.cubes:
		var cube_error := cube_validation_error(cube)
		if not cube_error.is_empty():
			return cube_error
		if ids.has(cube.id):
			return "方块标识重复"
		ids[cube.id] = true
	return ""

static func cube_validation_error(cube: Variant) -> String:
	if not cube is Dictionary or not cube.get("id") is String or cube.id.is_empty() or cube.id.length() > 160 or cube.get("bone") not in BONES:
		return "方块标识或附着关节无效"
	if not _vector(cube.get("center")) or vector(cube.center).length() > 4.0 or not _number(cube.get("edge")) or cube.edge < 0.005 or cube.edge > 1.0:
		return "方块位置或边长无效"
	if cube.has("rotation") or cube.has("scale") or cube.has("dimensions"):
		return "人物方块只能调整统一边长，不能单独旋转或拉伸"
	if not cube.get("color") is String or not Color.html_is_valid(cube.color):
		return "方块颜色无效"
	if cube.has("connection") and (not cube.connection is String or cube.connection not in CONNECTION_IDS):
		return "关节连接类型无效"
	for flag in ["hidden", "locked"]:
		if cube.has(flag) and not cube[flag] is bool:
			return "方块编辑状态无效"
	return ""

static func playable_error(data: Dictionary) -> String:
	if data.is_empty():
		return ""
	var error := validation_error(data)
	if not error.is_empty():
		return error
	var size := metrics(data)
	if size.height > 4.0 or size.radius > 0.95 or size.height < size.radius * 2.0:
		return "身体过宽或过高，无法生成可通行的碰撞体，请调整体型或身体方块"
	if size.eyes < 0.1 or size.eyes > size.height + 0.2 or size.breathing < 0.1 or size.breathing > size.height + 0.2:
		return "眼位或呼吸点需要位于身体高度范围内"
	var eye: Vector3 = size.eye_position
	var cap_center := clampf(eye.y,float(size.radius),float(size.height)-float(size.radius))
	var clearance := sqrt(maxf(0.0,float(size.radius)*float(size.radius)-pow(eye.y-cap_center,2.0))) - 0.1
	if eye.y > float(size.height)-0.06 or Vector2(eye.x,eye.z).length() > maxf(0.0,clearance):
		return "眼位需要留在身体碰撞范围内，请向头部中心移动"
	var origins := rest_origins(data)
	for cube in data.cubes:
		if Vector3(origins[cube.bone]).y + vector(cube.center).y - float(cube.edge) * 0.5 < -0.015:
			return "有身体方块低于地面，请移动方块或调整骨架后再应用"
	return ""

static func rig_reference(data: Dictionary) -> Dictionary:
	if data.is_empty():
		return {}
	return {"parameters": parameters(data), "joints": data.get("joints", {}).duplicate(true)}

static func reference_error(data: Dictionary) -> String:
	var fixture := {"schema_version": VERSION, "id": "reference", "name": "reference", "parameters": data.get("parameters",{}), "joints": data.get("joints",{}), "sockets": {}, "palette": {}, "cubes": [{"id": "reference", "bone": "body", "center": [0,0,0], "edge": 0.065, "color": "ffffff"}]}
	return validation_error(fixture)

static func _number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))

static func _vector(value: Variant) -> bool:
	return value is Array and value.size() == 3 and value.all(_number)

static func _body_boxes() -> Array[Dictionary]:
	var boxes: Array[Dictionary] = []
	var rows := [
		["chest", Vector3(0,1.0125,0), Vector3(0.45,0.675,0.225), "shirt"],
		["pelvis", Vector3(0,0.715,0), Vector3(0.46,0.08,0.24), "leather"],
		["pelvis", Vector3(0,0.715,-0.13), Vector3(0.09,0.07,0.025), "trim"],
		["head", Vector3(0,1.575,0), Vector3.ONE*0.45, "skin"],
		["head", Vector3(0,1.765,0), Vector3(0.47,0.11,0.47), "hair"],
		["head", Vector3(0,1.575,0.22), Vector3(0.47,0.3,0.05), "hair"],
		["head", Vector3(-0.09,1.69,-0.23), Vector3(0.28,0.1,0.04), "hair"],
		["head", Vector3(0,1.45,-0.23), Vector3(0.08,0.018,0.015), "leather"],
		["chest", Vector3(0,1.325,0), Vector3(0.47,0.055,0.25), "trim"],
		["chest", Vector3(-0.13,1.18,-0.13), Vector3(0.09,0.24,0.025), "trim"]]
	for x in [-0.225,0.225]:
		rows.append(["head", Vector3(x,1.66,0), Vector3(0.04,0.19,0.46), "hair"])
	for x in [-0.105,0.105]:
		rows.append(["head", Vector3(x,1.57,-0.23), Vector3(0.1,0.065,0.015), "trim"])
		rows.append(["head", Vector3(x,1.57,-0.241), Vector3(0.045,0.065,0.01), "eyes"])
	for side in ["left", "right"]:
		var x: float = -0.3375 if side == "left" else 0.3375
		var leg_x: float = -0.1125 if side == "left" else 0.1125
		rows.append([side+"_arm", Vector3(x,1.18,0), Vector3(0.225,0.34,0.225), "shirt"])
		rows.append([side+"_forearm", Vector3(x,0.94,0), Vector3(0.225,0.14,0.225), "shirt"])
		rows.append([side+"_hand", Vector3(x,0.785,0), Vector3(0.227,0.195,0.227), "skin"])
		rows.append([side+"_leg", Vector3(leg_x,0.505,0), Vector3(0.215,0.34,0.225), "pants"])
		rows.append([side+"_lower_leg", Vector3(leg_x,0.2575,0), Vector3(0.215,0.155,0.225), "pants"])
		rows.append([side+"_foot", Vector3(leg_x,0.09,0), Vector3(0.217,0.18,0.255), "leather"])
	for row in rows:
		boxes.append({"bone": row[0], "center": row[1], "size": row[2], "color": row[3]})
	return boxes

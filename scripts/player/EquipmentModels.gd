extends RefCounted

const Sets = preload("res://scripts/content/EquipmentSets.gd")
const Cubes = preload("res://scripts/content/CubeParts.gd")
static var _parts: Dictionary = {}
const BONE_ORIGINS := {
	"body": Vector3.ZERO, "head": Vector3(0, 1.575, 0),
	"left_arm": Vector3(-0.3375, 1.35, 0), "right_arm": Vector3(0.3375, 1.35, 0),
	"left_forearm": Vector3(-0.3375, 1.01, 0), "right_forearm": Vector3(0.3375, 1.01, 0),
	"left_leg": Vector3(-0.1125, 0.675, 0), "right_leg": Vector3(0.1125, 0.675, 0),
	"left_lower_leg": Vector3(-0.1125, 0.335, 0), "right_lower_leg": Vector3(0.1125, 0.335, 0)
}

static func parts(id: int) -> Array[Dictionary]:
	if _parts.has(id):
		var cached: Array[Dictionary] = []
		cached.assign(_parts[id].duplicate(true))
		return cached
	var result: Array[Dictionary] = []
	if not Sets.is_new(id):
		return result
	var key := Sets.style(id)
	var colors: Dictionary = Sets.PALETTES[key]
	match key:
		"ranger": _ranger(result, Sets.slot(id), colors)
		"knight": _knight(result, Sets.slot(id), colors)
		"mage": _mage(result, Sets.slot(id), colors)
	var weights: Array[int] = []
	for part in result:
		weights.append(Cubes.weight(part.size, part.rotation, part.shape, {"flare": 0.06}))
	var budgets := Cubes.budgets(weights, 1024)
	var cubes: Array[Dictionary] = []
	for index in result.size():
		var source: Dictionary = result[index]
		var origin: Vector3 = source.pos
		if source.shape == "cloth":
			origin.y -= source.size.y * 0.5
		var cloth := {"trim": Color(source.get("trim", Color.WHITE)).to_html(false), "emblem": int(source.get("emblem", 0)), "flare": 0.06}
		for cell in Cubes.sample(source.size, source.rotation, source.shape, cloth, budgets[index]):
			cubes.append({"bone": source.bone, "pos": origin + Vector3(cell.pos), "size": Vector3.ONE * float(cell.edge), "tint": Color(str(cell.tint)) if cell.has("tint") else source.tint, "rotation": Vector3.ZERO, "shape": "box"})
	_parts[id] = cubes.duplicate(true)
	return cubes

static func _box(parts: Array[Dictionary], bone: String, pos: Vector3, size: Vector3, tint: Color, rotation: Vector3 = Vector3.ZERO) -> void:
	parts.append({"bone": bone, "pos": pos, "size": size, "tint": tint, "rotation": rotation, "shape": "box"})

static func _cloth(parts: Array[Dictionary], colors: Dictionary, width: float, length: float, emblem: int) -> void:
	parts.append({"bone": "body", "pos": Vector3(0, 1.30, 0.18), "size": Vector3(width, length, 0.02), "tint": colors.cloth, "trim": colors.trim, "rotation": Vector3.ZERO, "shape": "cloth", "emblem": emblem})
	_box(parts, "body", Vector3(0, 1.305, 0.19), Vector3(width, 0.05, 0.06), colors.trim)
	for x in [-0.19, 0.19]:
		_box(parts, "body", Vector3(x, 1.29, -0.165), Vector3(0.085, 0.075, 0.05), colors.trim)

static func _ranger(parts: Array[Dictionary], slot: int, c: Dictionary) -> void:
	match slot:
		0:
			_box(parts, "head", Vector3(0, 0.255, 0.025), Vector3(0.55, 0.12, 0.55), c.main)
			_box(parts, "head", Vector3(0, 0.04, 0.255), Vector3(0.52, 0.38, 0.08), c.dark)
			for x in [-0.255, 0.255]:
				_box(parts, "head", Vector3(x, 0.04, 0.02), Vector3(0.07, 0.38, 0.49), c.main)
			_box(parts, "head", Vector3(0, 0.175, -0.255), Vector3(0.50, 0.05, 0.055), c.trim)
			_box(parts, "head", Vector3(-0.25, 0.36, 0.04), Vector3(0.06, 0.24, 0.045), c.gem, Vector3(0.12, 0, -0.35))
		1:
			_box(parts, "body", Vector3(0, 1.015, 0), Vector3(0.49, 0.63, 0.29), c.main)
			_box(parts, "body", Vector3(0, 1.04, -0.165), Vector3(0.065, 0.60, 0.035), c.leather, Vector3(0, 0, -0.38))
			_box(parts, "body", Vector3(0.13, 0.93, -0.17), Vector3(0.13, 0.15, 0.045), c.leather)
			_box(parts, "body", Vector3(0.13, 0.98, -0.20), Vector3(0.07, 0.025, 0.015), c.trim)
			for bone in ["left_arm", "right_arm"]:
				_box(parts, bone, Vector3(0, -0.17, 0), Vector3(0.25, 0.348, 0.25), c.dark)
			for bone in ["left_forearm", "right_forearm"]:
				_box(parts, bone, Vector3(0, -0.065, 0), Vector3(0.245, 0.145, 0.25), c.dark)
			_box(parts, "left_arm", Vector3(0, -0.09, 0), Vector3(0.30, 0.20, 0.31), c.leather)
			_box(parts, "left_arm", Vector3(0, -0.055, -0.16), Vector3(0.26, 0.035, 0.03), c.trim)
		2:
			for side in ["left", "right"]:
				_box(parts, side + "_leg", Vector3(0, -0.17, 0), Vector3(0.235, 0.348, 0.255), c.dark)
				_box(parts, side + "_lower_leg", Vector3(0, -0.025, -0.135), Vector3(0.23, 0.14, 0.045), c.leather)
				for y in [-0.08, -0.26]:
					_box(parts, side + "_leg", Vector3(0, y, 0), Vector3(0.245, 0.04, 0.265), c.leather)
		3:
			for side in ["left", "right"]:
				_box(parts, side + "_lower_leg", Vector3(0, -0.18, 0), Vector3(0.25, 0.29, 0.28), c.leather)
				_box(parts, side + "_lower_leg", Vector3(0, -0.276, -0.045), Vector3(0.26, 0.12, 0.35), c.dark)
				_box(parts, side + "_lower_leg", Vector3(0, -0.10, -0.15), Vector3(0.19, 0.035, 0.03), c.trim)
		4:
			for side in ["left", "right"]:
				_box(parts, side + "_forearm", Vector3(0, -0.215, 0), Vector3(0.25, 0.24, 0.25), c.leather)
				_box(parts, side + "_forearm", Vector3(0, -0.13, -0.13), Vector3(0.20, 0.04, 0.03), c.trim)
		5: _cloth(parts, c, 0.43, 0.57, 1)
		6:
			_box(parts, "body", Vector3(0, 0.715, 0), Vector3(0.51, 0.105, 0.31), c.leather)
			_box(parts, "body", Vector3(0, 0.715, -0.17), Vector3(0.10, 0.08, 0.04), c.trim)
			for x in [-0.19, 0.19]:
				_box(parts, "body", Vector3(x, 0.68, -0.19), Vector3(0.12, 0.16, 0.09), c.leather)
				_box(parts, "body", Vector3(x, 0.725, -0.24), Vector3(0.09, 0.04, 0.015), c.dark)

static func _knight(parts: Array[Dictionary], slot: int, c: Dictionary) -> void:
	match slot:
		0:
			_box(parts, "head", Vector3(0, 0.245, 0), Vector3(0.53, 0.13, 0.54), c.main)
			for sign_value in [-1.0, 1.0]:
				_box(parts, "head", Vector3(sign_value * 0.25, 0.055, 0.03), Vector3(0.07, 0.34, 0.47), c.main)
				_box(parts, "head", Vector3(sign_value * 0.31, 0.24, 0.02), Vector3(0.07, 0.24, 0.25), c.trim, Vector3(0, 0, -sign_value * 0.55))
				_box(parts, "head", Vector3(sign_value * 0.185, -0.045, -0.25), Vector3(0.11, 0.19, 0.07), c.main)
			_box(parts, "head", Vector3(0, 0.115, -0.26), Vector3(0.50, 0.06, 0.06), c.trim)
			_box(parts, "head", Vector3(0, -0.015, -0.265), Vector3(0.04, 0.20, 0.05), c.dark)
			_box(parts, "head", Vector3(0, 0.35, 0.055), Vector3(0.08, 0.24, 0.32), c.cloth)
		1:
			_box(parts, "body", Vector3(0, 1.02, 0), Vector3(0.51, 0.65, 0.31), c.main)
			for x in [-0.12, 0.12]:
				_box(parts, "body", Vector3(x, 1.075, -0.175), Vector3(0.045, 0.42, 0.035), c.trim, Vector3(0, 0, -signf(x) * 0.25))
			_box(parts, "body", Vector3(0, 1.13, -0.20), Vector3(0.09, 0.12, 0.04), c.gem)
			for bone in ["left_arm", "right_arm"]:
				_box(parts, bone, Vector3(0, -0.08, 0), Vector3(0.34, 0.24, 0.35), c.main)
				_box(parts, bone, Vector3(0, -0.02, 0), Vector3(0.35, 0.055, 0.36), c.trim)
				_box(parts, bone, Vector3(0, -0.255, 0), Vector3(0.25, 0.20, 0.28), c.dark)
			for bone in ["left_forearm", "right_forearm"]:
				_box(parts, bone, Vector3(0, -0.065, 0), Vector3(0.245, 0.145, 0.27), c.dark)
		2:
			for side in ["left", "right"]:
				_box(parts, side + "_leg", Vector3(0, -0.17, 0), Vector3(0.24, 0.348, 0.26), c.main)
				_box(parts, side + "_leg", Vector3(0, -0.06, -0.16), Vector3(0.24, 0.17, 0.05), c.trim)
				_box(parts, side + "_lower_leg", Vector3(0, -0.015, -0.15), Vector3(0.27, 0.15, 0.07), c.main)
		3:
			for side in ["left", "right"]:
				_box(parts, side + "_lower_leg", Vector3(0, -0.21, 0), Vector3(0.26, 0.24, 0.30), c.main)
				_box(parts, side + "_lower_leg", Vector3(0, -0.274, -0.06), Vector3(0.27, 0.124, 0.36), c.main)
				_box(parts, side + "_lower_leg", Vector3(0, -0.12, -0.16), Vector3(0.23, 0.04, 0.03), c.trim)
		4:
			for side in ["left", "right"]:
				_box(parts, side + "_forearm", Vector3(0, -0.215, 0), Vector3(0.265, 0.25, 0.28), c.main)
				_box(parts, side + "_forearm", Vector3(0, -0.115, 0), Vector3(0.28, 0.05, 0.29), c.trim)
				_box(parts, side + "_forearm", Vector3(0, -0.21, -0.15), Vector3(0.13, 0.14, 0.035), c.dark)
		5: _cloth(parts, c, 0.50, 0.89, 2)
		6:
			_box(parts, "body", Vector3(0, 0.715, 0), Vector3(0.53, 0.10, 0.33), c.trim)
			_box(parts, "body", Vector3(0, 0.715, -0.19), Vector3(0.13, 0.09, 0.05), c.dark)
			_box(parts, "body", Vector3(0, 0.715, -0.22), Vector3(0.07, 0.065, 0.025), c.gem)

static func _mage(parts: Array[Dictionary], slot: int, c: Dictionary) -> void:
	match slot:
		0:
			_box(parts, "head", Vector3(0, 0.25, 0), Vector3(0.68, 0.055, 0.61), c.dark)
			_box(parts, "head", Vector3(0, 0.31, 0), Vector3(0.46, 0.13, 0.44), c.main)
			for layer in range(6):
				var width := 0.42 - float(layer) * 0.065
				_box(parts, "head", Vector3(-0.015, 0.36 + float(layer) * 0.065, 0.015), Vector3(width, 0.065, width), c.main)
			_box(parts, "head", Vector3(0, 0.315, -0.23), Vector3(0.46, 0.045, 0.035), c.trim)
			_box(parts, "head", Vector3(0, 0.36, -0.25), Vector3(0.065, 0.12, 0.04), c.gem)
		1:
			_box(parts, "body", Vector3(0, 1.015, 0), Vector3(0.49, 0.67, 0.30), c.main)
			_box(parts, "body", Vector3(0, 1.04, -0.17), Vector3(0.16, 0.51, 0.04), c.dark)
			for x in [-0.10, 0.10]:
				_box(parts, "body", Vector3(x, 1.04, -0.19), Vector3(0.025, 0.52, 0.025), c.trim)
			_box(parts, "body", Vector3(0, 1.27, -0.20), Vector3(0.08, 0.10, 0.045), c.gem)
			for bone in ["left_arm", "right_arm"]:
				_box(parts, bone, Vector3(0, -0.17, 0), Vector3(0.28, 0.35, 0.28), c.main)
				_box(parts, bone, Vector3(0, -0.05, 0), Vector3(0.29, 0.06, 0.29), c.trim)
			for bone in ["left_forearm", "right_forearm"]:
				_box(parts, bone, Vector3(0, -0.065, 0), Vector3(0.27, 0.145, 0.27), c.main)
		2:
			for side in ["left", "right"]:
				_box(parts, side + "_leg", Vector3(0, -0.17, 0), Vector3(0.23, 0.348, 0.26), c.dark)
				_box(parts, side + "_leg", Vector3(0, -0.21, -0.17), Vector3(0.245, 0.42, 0.055), c.main)
				_box(parts, side + "_leg", Vector3(0, -0.39, -0.205), Vector3(0.25, 0.035, 0.025), c.trim)
				_box(parts, side + "_lower_leg", Vector3(0, -0.075, 0), Vector3(0.23, 0.15, 0.26), c.dark)
		3:
			for side in ["left", "right"]:
				_box(parts, side + "_lower_leg", Vector3(0, -0.21, 0), Vector3(0.25, 0.24, 0.29), c.leather)
				_box(parts, side + "_lower_leg", Vector3(0, -0.276, -0.075), Vector3(0.25, 0.12, 0.36), c.dark)
				_box(parts, side + "_lower_leg", Vector3(0, -0.12, 0), Vector3(0.26, 0.04, 0.30), c.trim)
		4:
			for side in ["left", "right"]:
				_box(parts, side + "_forearm", Vector3(0, -0.215, 0), Vector3(0.25, 0.24, 0.26), c.main)
				_box(parts, side + "_forearm", Vector3(0, -0.12, 0), Vector3(0.28, 0.055, 0.29), c.trim)
				_box(parts, side + "_forearm", Vector3(0, -0.215, -0.15), Vector3(0.07, 0.10, 0.035), c.gem)
		5: _cloth(parts, c, 0.52, 0.95, 3)
		6:
			_box(parts, "body", Vector3(0, 0.72, 0), Vector3(0.52, 0.12, 0.32), c.dark)
			_box(parts, "body", Vector3(0, 0.72, -0.18), Vector3(0.16, 0.10, 0.04), c.trim)
			_box(parts, "body", Vector3(0, 0.72, -0.21), Vector3(0.07, 0.07, 0.025), c.gem)
			_box(parts, "body", Vector3(0.15, 0.60, -0.18), Vector3(0.06, 0.24, 0.035), c.main)

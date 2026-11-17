extends RefCounted

# Model descriptions are also editable blueprints. Every entry is a cube.
static var _parts: Dictionary = {}

static func parts(id: int) -> Array[Dictionary]:
	if id >= 501 and id <= 509:
		return preload("res://scripts/content/FacilityModels.gd").parts(id)
	if id >= 601 and id <= 610:
		return preload("res://scripts/content/SupplyModels.gd").parts(id)
	if _parts.has(id):
		return _parts[id]
	var result: Array[Dictionary] = []
	var wood := Color("a87847")
	var dark := Color("664328")
	if id in range(201, 210) or id in range(301, 306):
		var head := Color("c69b64") if id in [201, 202, 203, 301] else (Color("8998a4") if id in [204, 205, 206, 302] else Color("d4e0e5"))
		_box(result, Vector3(0, 0.15, 0), Vector3(0.05, 0.5, 0.05), dark)
		if id in [201, 204, 207]:
			_box(result, Vector3(0, 0.42, -0.04), Vector3(0.07, 0.07, 0.48), head)
		elif id in [202, 205, 208, 302]:
			_box(result, Vector3(0, 0.4, -0.1), Vector3(0.07, 0.24, 0.24), head)
		elif id in [203, 206, 209]:
			_box(result, Vector3(0, 0.48, 0), Vector3(0.2, 0.22, 0.04), head)
		else:
			_box(result, Vector3(0, 0.43, 0), Vector3(0.08, 0.7, 0.06), head)
			_box(result, Vector3(0, 0.12, 0), Vector3(0.3, 0.05, 0.08), head.darkened(0.2))
		_parts[id] = result
		return result
	match id:
		510:
			# Door frames stay fixed; the two panels rotate as complete assemblies.
			for side in [-1, 1]:
				for y in range(29):
					result.append({"pos": Vector3(side * 0.95, 0.05 + y * 0.1, 0), "edge": 0.1, "tint": dark})
				for slat in range(9):
					for y in range(28):
						result.append({"pos": Vector3(side * (0.05 + slat * 0.1), 0.1 + y * 0.1, 0), "edge": 0.1, "tint": dark if y in [1, 13, 26] else wood.lightened(0.025 * (slat % 2))})
				for z in [-0.1, 0.1]:
					_box(result, Vector3(side * 0.15, 1.38, z), Vector3(0.05, 0.15, 0.05), Color("c9ad6b"))
			for x in range(20):
				result.append({"pos": Vector3(-0.95 + x * 0.1, 2.95, 0), "edge": 0.1, "tint": dark})
	_parts[id] = result
	return result

static func _box(result: Array[Dictionary], pos: Vector3, size: Vector3, tint: Color) -> void:
	for cube in preload("res://scripts/content/CubeParts.gd").sample(size, Vector3.ZERO, "box", {}, 180):
		result.append({"pos": pos + Vector3(cube.pos), "edge": float(cube.edge), "tint": tint})

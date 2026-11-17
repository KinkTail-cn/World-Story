extends RefCounted

# Model descriptions are also editable blueprints. Every entry is a cube.
static var _parts: Dictionary = {}

static func parts(id: int) -> Array[Dictionary]:
	if _parts.has(id):
		return _parts[id]
	var result: Array[Dictionary] = []
	var wood := Color("a87847")
	var dark := Color("664328")
	var stone := Color("788995")
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
		501, 506:
			_box(result, Vector3(0, 0.36, 0), Vector3(0.84, 0.62, 0.84), wood)
			for y in [0.14, 0.62]:
				_box(result, Vector3(0, y, 0), Vector3(0.9, 0.07, 0.9), dark)
			_box(result, Vector3(0, 0.72, 0), Vector3(0.88, 0.08, 0.88), wood.lightened(0.12))
			_box(result, Vector3(0, 0.59, -0.44), Vector3(0.12, 0.16, 0.07), Color("dfbd7d"))
		502:
			_box(result, Vector3(0, 0.4, 0), Vector3(0.88, 0.8, 0.88), stone)
			_box(result, Vector3(0, 0.31, -0.45), Vector3(0.55, 0.32, 0.07), Color("263139"))
			_box(result, Vector3(0, 0.18, -0.5), Vector3(0.43, 0.07, 0.06), Color("d08348"))
			_box(result, Vector3(0.23, 0.9, 0.2), Vector3(0.24, 0.2, 0.24), stone.darkened(0.2))
		503:
			_box(result, Vector3(0, 0.23, 0), Vector3(0.9, 0.15, 1.8), dark)
			_box(result, Vector3(0, 0.4, 0.1), Vector3(0.84, 0.2, 1.5), Color("568a9a"))
			_box(result, Vector3(0, 0.49, -0.62), Vector3(0.76, 0.1, 0.36), Color("eee6cf"))
			for x in [-0.36, 0.36]:
				for z in [-0.75, 0.75]:
					_box(result, Vector3(x, 0.16, z), Vector3(0.12, 0.32, 0.12), wood)
		504:
			_box(result, Vector3(0, 0.45, 0), Vector3(0.6, 0.12, 0.6), wood)
			_box(result, Vector3(0, 0.72, 0.25), Vector3(0.6, 0.45, 0.1), dark)
			for x in [-0.23, 0.23]:
				for z in [-0.23, 0.23]:
					_box(result, Vector3(x, 0.22, z), Vector3(0.1, 0.44, 0.1), dark)
		505:
			_box(result, Vector3(0, 0.08, 0), Vector3(0.34, 0.16, 0.34), dark)
			_box(result, Vector3(0, 0.32, 0), Vector3(0.22, 0.36, 0.22), Color("f4cf79"))
			_box(result, Vector3(0, 0.55, 0), Vector3(0.34, 0.1, 0.34), dark)
		507:
			_box(result, Vector3(0, 0.12, 0), Vector3(0.94, 0.24, 0.94), wood)
			_box(result, Vector3(0, 0.25, 0), Vector3(0.82, 0.1, 0.82), Color("735138"))
		508:
			_box(result, Vector3(0, 0.15, 0), Vector3(1.4, 0.3, 1.4), stone)
			_box(result, Vector3(0, 0.32, 0), Vector3(0.8, 0.05, 0.8), Color("548baf"))
			for x in [-0.58, 0.58]:
				_box(result, Vector3(x, 0.8, 0), Vector3(0.14, 1.25, 0.14), dark)
			_box(result, Vector3(0, 1.5, 0), Vector3(1.5, 0.2, 1.4), wood)
		509:
			_box(result, Vector3(0, 0.78, 0), Vector3(0.94, 0.16, 0.94), wood)
			for x in [-0.35, 0.35]:
				for z in [-0.35, 0.35]:
					_box(result, Vector3(x, 0.36, z), Vector3(0.14, 0.72, 0.14), dark)
			_box(result, Vector3(0.05, 0.88, 0), Vector3(0.52, 0.04, 0.6), Color("538db3"))
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
		601:
			_box(result, Vector3(0, 0.2, 0), Vector3(0.06, 0.45, 0.06), wood)
		602, 608:
			_box(result, Vector3(0, 0.08, 0), Vector3(0.36, 0.14, 0.22), Color("d6e2e7") if id == 602 else Color("e0bd63"))
		603:
			for x in [-0.08, 0.06]:
				_box(result, Vector3(x, 0.07, 0), Vector3(0.09, 0.09, 0.09), Color("bba468"))
		604:
			for x in [-0.08, 0, 0.08]:
				_box(result, Vector3(x, 0.18, 0), Vector3(0.025, 0.36, 0.025), Color("8f9e48"))
				_box(result, Vector3(x, 0.36, 0), Vector3(0.07, 0.16, 0.07), Color("d5b758"))
		605:
			_box(result, Vector3(0, 0.1, 0), Vector3(0.35, 0.18, 0.22), Color("c68f4c"))
		606:
			_box(result, Vector3(0, 0.13, 0), Vector3(0.25, 0.25, 0.25), Color("b95f4e"))
			_box(result, Vector3(0, 0.29, 0), Vector3(0.035, 0.08, 0.035), dark)
		607:
			_box(result, Vector3(0, 0.12, 0), Vector3(0.25, 0.25, 0.25), Color("343b40"))
		609, 610:
			_box(result, Vector3(0, 0.17, 0), Vector3(0.3, 0.33, 0.3), wood)
			_box(result, Vector3(0, 0.34, 0), Vector3(0.24, 0.03, 0.24), Color("5395bb") if id == 610 else dark)
	_parts[id] = result
	return result

static func _box(result: Array[Dictionary], pos: Vector3, size: Vector3, tint: Color) -> void:
	for cube in preload("res://scripts/content/CubeParts.gd").sample(size, Vector3.ZERO, "box", {}, 180):
		result.append({"pos": pos + Vector3(cube.pos), "edge": float(cube.edge), "tint": tint})

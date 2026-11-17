extends RefCounted

const Parts = preload("res://scripts/content/FacilityModels.gd")
static var _cache: Dictionary = {}

static func parts(id: int) -> Array[Dictionary]:
	if _cache.has(id): return _cache[id]
	var p: Array[Dictionary] = []
	match id:
		601:
			for x in [-0.055, 0.055]:
				for z in [-0.045, 0.045]:
					Parts.box(p, Vector3(x, 0.19, z), Vector3(0.04, 0.4 + (0.04 if x > 0 else 0), 0.04), Color("9b693d"), "body", "wood", 0.02)
					Parts.cube(p, Vector3(x, 0.4, z), 0.04, Color("d2b07b"))
			for y in [0.1, 0.27]: Parts.box(p, Vector3(0, y, 0), Vector3(0.16, 0.025, 0.14), Color("aa9c72"), "body", "fabric", 0.025)
		602, 608:
			var color := Color("bbc9ce") if id == 602 else Color("cfa74e")
			Parts.box(p, Vector3(0, 0.06, 0), Vector3(0.35, 0.1, 0.2), color, "body", "metal")
			Parts.box(p, Vector3(0, 0.12, 0), Vector3(0.3, 0.05, 0.15), color.lightened(0.13), "body", "metal")
			Parts.box(p, Vector3(-0.05, 0.15, 0), Vector3(0.05, 0.025, 0.075), color.darkened(0.15), "body", "metal", 0.025)
		603:
			Parts.box(p, Vector3(0, 0.08, 0), Vector3(0.22, 0.15, 0.18), Color("a99367"), "body", "fabric")
			for x in [-0.1, 0.1]: Parts.box(p, Vector3(x, 0.18, 0), Vector3(0.025, 0.1, 0.15), Color("c0ab7a"), "body", "fabric", 0.025)
			for z in [-0.075, 0.075]: Parts.box(p, Vector3(0, 0.18, z), Vector3(0.2, 0.1, 0.025), Color("c0ab7a"), "body", "fabric", 0.025)
			Parts.box(p, Vector3(0, 0.14, -0.1), Vector3(0.075, 0.075, 0.025), Color("6b8a4d"), "body", "plant", 0.025)
			for index in range(9): Parts.cube(p, Vector3(-0.06 + index % 3 * 0.055, 0.18 + (index % 2) * 0.022, -0.04 + index / 3 * 0.04), 0.03, Color("d3b878"), "body", "grain")
		604:
			for index in range(5):
				var x := -0.08 + index * 0.04
				var height := 0.33 + index % 3 * 0.035
				Parts.box(p, Vector3(x, height * 0.5, 0), Vector3(0.02, height, 0.02), Color("a4a551"), "body", "plant", 0.02)
				for y in range(4): Parts.cube(p, Vector3(x + (0.012 if y % 2 else -0.012), height + y * 0.032, 0), 0.045, Color("d9bb65"), "body", "grain")
			Parts.box(p, Vector3(0, 0.12, 0), Vector3(0.2, 0.025, 0.075), Color("8f7044"), "body", "fabric", 0.025)
		605:
			Parts.box(p, Vector3(0, 0.055, 0), Vector3(0.3, 0.1, 0.2), Color("a66c35"), "body", "food")
			Parts.box(p, Vector3(0, 0.12, 0), Vector3(0.35, 0.1, 0.2), Color("c9924d"), "body", "food")
			Parts.box(p, Vector3(0, 0.18, 0), Vector3(0.25, 0.05, 0.15), Color("dcaf6d"), "body", "food")
			for x in [-0.1, 0, 0.1]: Parts.box(p, Vector3(x, 0.205, 0), Vector3(0.025, 0.025, 0.125), Color("edd1a0"), "body", "food", 0.025)
		606:
			Parts.box(p, Vector3(0, 0.13, 0), Vector3(0.2, 0.25, 0.2), Color("b84c3e"), "body", "food")
			Parts.box(p, Vector3(0, 0.13, 0), Vector3(0.25, 0.15, 0.25), Color("c55d46"), "body", "food")
			Parts.box(p, Vector3(0, 0.29, 0), Vector3(0.025, 0.075, 0.025), Color("63482c"), "body", "wood", 0.025)
			Parts.box(p, Vector3(0.055, 0.28, 0), Vector3(0.1, 0.025, 0.05), Color("71934b"), "body", "plant", 0.025)
			Parts.cube(p, Vector3(-0.11, 0.18, -0.08), 0.025, Color("df8768"), "body", "food")
		607:
			for index in range(5):
				var edge := 0.08 + (index % 3) * 0.025
				var centre := Vector3(-0.08 + (index % 3) * 0.08, 0.06 + (index / 3) * 0.075, (index % 2) * 0.07)
				Parts.cube(p, centre, edge, Color("30373a").lightened(0.03 * (index % 2)), "body", "stone")
				for mark in range(3): Parts.cube(p, centre + Vector3(-0.02 + mark * 0.02, edge * 0.5, -0.015 + mark * 0.01), 0.012, Color("606765").darkened(0.07 * (mark % 2)), "body", "stone")
		609, 610:
			for x in [-0.13, 0.13]: Parts.box(p, Vector3(x, 0.17, 0), Vector3(0.05, 0.3, 0.25), Color("a5794a"))
			for z in [-0.13, 0.13]: Parts.box(p, Vector3(0, 0.17, z), Vector3(0.25, 0.3, 0.05), Color("b18854"))
			Parts.box(p, Vector3(0, 0.04, 0), Vector3(0.25, 0.05, 0.25), Color("705036"))
			for y in [0.08, 0.28]:
				for x in [-0.155, 0.155]: Parts.box(p, Vector3(x, y, 0), Vector3(0.025, 0.025, 0.3), Color("586165"), "body", "metal", 0.025)
				for z in [-0.155, 0.155]: Parts.box(p, Vector3(0, y, z), Vector3(0.3, 0.025, 0.025), Color("586165"), "body", "metal", 0.025)
			for x in [-0.14, 0.14]: Parts.box(p, Vector3(x, 0.38, 0), Vector3(0.025, 0.15, 0.025), Color("586165"), "body", "metal", 0.025)
			Parts.box(p, Vector3(0, 0.45, 0), Vector3(0.3, 0.025, 0.025), Color("586165"), "body", "metal", 0.025)
			Parts.box(p, Vector3(0, 0.285 if id == 610 else 0.07, 0), Vector3(0.2, 0.025, 0.2), Color("5799ab") if id == 610 else Color("543d2c"), "water" if id == 610 else "body", "water" if id == 610 else "wood", 0.025)
	_cache[id] = p
	return p

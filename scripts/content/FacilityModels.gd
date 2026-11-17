extends RefCounted

# All structural pieces are tiled with cubes; moving groups keep those cubes
# rigid. The same descriptions supply world models, icons and editable presets.
const WOOD := Color("aa7746")
const EDGE := Color("67462f")
const IRON := Color("48545c")
const BRASS := Color("c9ad70")
const STONE := Color("7e8c91")
static var _cache: Dictionary = {}

static func parts(id: int) -> Array[Dictionary]:
	if _cache.has(id): return _cache[id]
	var p: Array[Dictionary] = []
	match id:
		501: _chest(p)
		502: _furnace(p)
		503: _bed(p)
		504: _chair(p)
		505: _lantern(p)
		506: _barrel(p)
		507: _planter(p)
		508: _well(p)
		509: _bench(p)
	_cache[id] = p
	return p

static func cube(p: Array[Dictionary], position: Vector3, edge: float, tint: Color, group: String = "body", surface: String = "wood") -> void:
	p.append({"pos": position, "edge": edge, "tint": tint, "group": group, "surface": surface})

static func box(p: Array[Dictionary], position: Vector3, extent: Vector3, tint: Color, group: String = "body", surface: String = "wood", edge: float = 0.05) -> void:
	var count := Vector3i(maxi(1, roundi(extent.x / edge)), maxi(1, roundi(extent.y / edge)), maxi(1, roundi(extent.z / edge)))
	for z in count.z:
		for y in count.y:
			for x in count.x:
				# Cull cubes completely inside a beam. Its exterior stays a closed,
				# rigid cube shell without spending the blueprint budget on its core.
				if x > 0 and x < count.x - 1 and y > 0 and y < count.y - 1 and z > 0 and z < count.z - 1: continue
				cube(p, position + (Vector3(x, y, z) - Vector3(count - Vector3i.ONE) * 0.5) * edge, edge, tint, group, surface)

static func _chest(p: Array[Dictionary]) -> void:
	box(p, Vector3(0, 0.12, 0), Vector3(0.8, 0.1, 0.7), EDGE)
	for x in [-0.35, 0.35]:
		for z in [-0.3, 0.3]: box(p, Vector3(x, 0.08, z), Vector3(0.1, 0.15, 0.1), IRON, "body", "metal")
	for slat in range(8):
		var x := -0.35 + slat * 0.1
		for z in [-0.35, 0.35]:
			box(p, Vector3(x, 0.36, z), Vector3(0.1, 0.45, 0.1), WOOD.lightened(0.04 * (slat % 3)))
	for x in [-0.4, 0.4]: box(p, Vector3(x, 0.36, 0), Vector3(0.1, 0.45, 0.7), WOOD.darkened(0.05))
	for x in [-0.27, 0.27]:
		for z in [-0.41, 0.41]: box(p, Vector3(x, 0.35, z), Vector3(0.05, 0.5, 0.05), IRON, "body", "metal")
	for slat in range(8):
		box(p, Vector3(-0.35 + slat * 0.1, 0.65, 0), Vector3(0.1, 0.1, 0.8), WOOD.lightened(0.08 + 0.025 * (slat % 2)), "lid")
	for x in [-0.27, 0.27]: box(p, Vector3(x, 0.72, 0), Vector3(0.05, 0.05, 0.85), IRON, "lid", "metal")
	box(p, Vector3(0, 0.6, -0.43), Vector3(0.1, 0.2, 0.05), BRASS, "lid", "metal")
	cube(p, Vector3(0, 0.56, -0.468), 0.025, EDGE, "lid", "metal")
	for x in [-0.27, 0.27]: box(p, Vector3(x, 0.6, 0.4), Vector3(0.1, 0.1, 0.1), IRON, "body", "metal")

static func _barrel(p: Array[Dictionary]) -> void:
	for y in range(8):
		var radius := 0.32 if y in [0, 7] else 0.4
		for z in range(-4, 5):
			for x in range(-4, 5):
				var r := Vector2(x, z).length() * 0.085
				if r > radius or (r < radius - 0.11 and y != 0): continue
				cube(p, Vector3(x * 0.085, 0.07 + y * 0.095, z * 0.085), 0.085, IRON if y in [1, 6] else WOOD.lightened(0.035 * posmod(x + z, 3)), "body", "metal" if y in [1, 6] else "wood")
	for z in range(-3, 4):
		for x in range(-3, 4):
			if Vector2(x, z).length() > 3.5: continue
			cube(p, Vector3(x * 0.09, 0.82, z * 0.09), 0.09, WOOD.lightened(0.05 * posmod(x, 2)), "lid")
	box(p, Vector3(0, 0.88, 0), Vector3(0.2, 0.05, 0.05), IRON, "lid", "metal")

static func _furnace(p: Array[Dictionary]) -> void:
	for y in range(4):
		for x in range(6):
			var tint := STONE.lightened(0.035 * posmod(x + y, 3))
			for z in [-0.375, 0.375]:
				if z < 0 and x in [1, 2, 3, 4] and y in [1, 2]: continue
				box(p, Vector3(-0.375 + x * 0.15, 0.1 + y * 0.2, z), Vector3(0.15, 0.2, 0.1), tint, "body", "stone")
	for x in [-0.4, 0.4]: box(p, Vector3(x, 0.4, 0), Vector3(0.1, 0.8, 0.7), STONE.darkened(0.08), "body", "stone")
	box(p, Vector3(0, 0.07, 0), Vector3(0.8, 0.1, 0.7), Color("353e42"), "body", "stone")
	box(p, Vector3(0, 0.5, 0.22), Vector3(0.6, 0.55, 0.1), Color("263035"), "body", "stone")
	box(p, Vector3(0, 0.8, 0), Vector3(0.9, 0.1, 0.9), STONE.lightened(0.12), "body", "stone")
	for x in range(-3, 4): box(p, Vector3(x * 0.085, 0.2, -0.18), Vector3(0.025, 0.025, 0.4), IRON, "body", "metal", 0.025)
	for x in [-0.2, 0, 0.2]: cube(p, Vector3(x, 0.16, -0.1), 0.1, Color("292d30"), "body", "stone")
	for x in [-0.28, 0.28]: box(p, Vector3(x, 0.39, -0.43), Vector3(0.05, 0.4, 0.05), IRON, "body", "metal")
	box(p, Vector3(0, 0.58, -0.43), Vector3(0.6, 0.05, 0.05), IRON, "body", "metal")
	for x in [-0.1, 0.1]: box(p, Vector3(0.22 + x, 0.94, 0.22), Vector3(0.1, 0.2, 0.3), STONE.darkened(0.16), "body", "stone")
	for z in [0.12, 0.32]: box(p, Vector3(0.22, 0.94, z), Vector3(0.15, 0.2, 0.1), STONE, "body", "stone")
	box(p, Vector3(0.22, 1.04, 0.22), Vector3(0.12, 0.025, 0.12), Color("222a2e"), "body", "stone", 0.025)

static func _bed(p: Array[Dictionary]) -> void:
	for x in [-0.4, 0.4]:
		box(p, Vector3(x, 0.24, 0), Vector3(0.1, 0.15, 1.75), EDGE)
		for z in [-0.8, 0.8]: box(p, Vector3(x, 0.16, z), Vector3(0.12, 0.3, 0.12), WOOD, "body", "wood", 0.04)
	for z in [-0.85, 0.85]: box(p, Vector3(0, 0.32, z), Vector3(0.9, 0.2, 0.1), WOOD)
	for x in [-0.4, 0.4]: box(p, Vector3(x, 0.45, -0.85), Vector3(0.1, 0.4, 0.1), EDGE)
	box(p, Vector3(0, 0.57, -0.85), Vector3(0.85, 0.15, 0.1), WOOD.lightened(0.1))
	box(p, Vector3(0, 0.37, 0), Vector3(0.8, 0.15, 1.6), Color("ded8c8"), "body", "fabric")
	for x in range(8):
		box(p, Vector3(-0.35 + x * 0.1, 0.47, 0.18), Vector3(0.1, 0.1, 1.15), Color("477b8e").lightened(0.035 * (x % 2)), "quilt", "fabric")
	for x in [-0.38, 0.38]: box(p, Vector3(x, 0.44, 0.2), Vector3(0.05, 0.15, 1.15), Color("8aafae"), "quilt", "fabric")
	box(p, Vector3(0, 0.49, -0.57), Vector3(0.7, 0.15, 0.3), Color("f2e9d6"), "quilt", "fabric")
	for x in [-0.25, 0, 0.25]: cube(p, Vector3(x, 0.535, 0.57), 0.025, Color("bfd2ca"), "quilt", "fabric")

static func _chair(p: Array[Dictionary]) -> void:
	for x in [-0.24, 0.24]:
		for z in [-0.24, 0.24]: box(p, Vector3(x, 0.23, z), Vector3(0.08, 0.44, 0.08), EDGE, "body", "wood", 0.04)
		box(p, Vector3(x, 0.67, 0.25), Vector3(0.08, 0.56, 0.08), WOOD, "body", "wood", 0.04)
		box(p, Vector3(x, 0.18, 0), Vector3(0.05, 0.05, 0.5), WOOD)
	box(p, Vector3(0, 0.2, 0.23), Vector3(0.5, 0.05, 0.05), WOOD)
	for x in range(5): box(p, Vector3(-0.2 + x * 0.1, 0.43, 0), Vector3(0.1, 0.1, 0.55), WOOD.lightened(0.035 * (x % 2)))
	box(p, Vector3(0, 0.5, -0.01), Vector3(0.5, 0.05, 0.45), Color("6e8d76"), "seat", "fabric")
	for x in [-0.15, 0, 0.15]: box(p, Vector3(x, 0.74, 0.26), Vector3(0.05, 0.3, 0.05), WOOD.lightened(0.08))
	box(p, Vector3(0, 0.92, 0.26), Vector3(0.6, 0.08, 0.08), WOOD, "body", "wood", 0.04)

static func _lantern(p: Array[Dictionary]) -> void:
	box(p, Vector3(0, 0.07, 0), Vector3(0.35, 0.1, 0.35), IRON, "body", "metal")
	box(p, Vector3(0, 0.15, 0), Vector3(0.25, 0.05, 0.25), BRASS, "body", "metal")
	for x in [-0.125, 0.125]:
		for z in [-0.125, 0.125]: box(p, Vector3(x, 0.32, z), Vector3(0.025, 0.3, 0.025), IRON, "body", "metal", 0.025)
	for z in [-0.125, 0.125]: box(p, Vector3(0, 0.31, z), Vector3(0.2, 0.25, 0.025), Color("c3d3c5"), "glass", "glass", 0.025)
	for x in [-0.125, 0.125]: box(p, Vector3(x, 0.31, 0), Vector3(0.025, 0.25, 0.2), Color("b7cabf"), "glass", "glass", 0.025)
	box(p, Vector3(0, 0.22, 0), Vector3(0.1, 0.1, 0.1), BRASS, "body", "metal")
	box(p, Vector3(0, 0.33, 0), Vector3(0.075, 0.15, 0.075), Color("ffe0a0"), "glow", "glow", 0.025)
	box(p, Vector3(0, 0.49, 0), Vector3(0.35, 0.05, 0.35), IRON, "body", "metal")
	box(p, Vector3(0, 0.54, 0), Vector3(0.25, 0.05, 0.25), BRASS, "body", "metal")
	for x in [-0.075, 0.075]: box(p, Vector3(x, 0.61, 0), Vector3(0.025, 0.125, 0.025), IRON, "body", "metal", 0.025)
	box(p, Vector3(0, 0.67, 0), Vector3(0.15, 0.025, 0.025), IRON, "body", "metal", 0.025)

static func _planter(p: Array[Dictionary]) -> void:
	box(p, Vector3(0, 0.06, 0), Vector3(0.85, 0.1, 0.85), EDGE)
	for y in [0.12, 0.22]:
		for side in [-0.42, 0.42]:
			box(p, Vector3(side, y, 0), Vector3(0.05, 0.1, 0.85), WOOD.lightened(0.04))
			box(p, Vector3(0, y, side), Vector3(0.85, 0.1, 0.05), WOOD)
	for x in [-0.4, 0.4]:
		for z in [-0.4, 0.4]: box(p, Vector3(x, 0.17, z), Vector3(0.1, 0.3, 0.1), EDGE)
	for z in range(8):
		for x in range(8): cube(p, Vector3(-0.35 + x * 0.1, 0.22 + (x + z) % 2 * 0.008, -0.35 + z * 0.1), 0.1, Color("79583d").lightened(0.035 * ((x * 7 + z) % 3)), "soil", "soil")
	for x in [-0.39, 0.39]:
		for z in [-0.44, 0.44]: cube(p, Vector3(x, 0.2, z), 0.025, IRON, "body", "metal")

static func _well(p: Array[Dictionary]) -> void:
	for y in range(3):
		for z in range(-6, 7):
			for x in range(-6, 7):
				var d := maxi(absi(x), absi(z))
				if d < 4 or (absi(x) > 5 and absi(z) > 5): continue
				cube(p, Vector3(x * 0.1, 0.075 + y * 0.1, z * 0.1), 0.1, STONE.lightened(0.04 * posmod(x + z + y, 3)), "body", "stone")
	box(p, Vector3(0, 0.14, 0), Vector3(0.75, 0.05, 0.75), Color("4b8d9f"), "water", "water")
	for x in [-0.6, 0.6]: box(p, Vector3(x, 0.87, 0), Vector3(0.1, 1.35, 0.15), EDGE)
	for z in range(-6, 7):
		var rise := 0.02 * (6 - absi(z))
		box(p, Vector3(0, 1.48 + rise, z * 0.1), Vector3(1.45, 0.1, 0.1), WOOD.lightened(0.04 * posmod(z, 2)))
	box(p, Vector3(0, 1.12, 0), Vector3(1.3, 0.1, 0.1), WOOD)
	box(p, Vector3(0.69, 1.12, 0), Vector3(0.05, 0.35, 0.05), IRON, "crank", "metal")
	box(p, Vector3(0.75, 0.96, 0), Vector3(0.15, 0.05, 0.05), WOOD, "crank")
	box(p, Vector3(0, 0.84, 0), Vector3(0.025, 0.5, 0.025), Color("b9a078"), "rope", "fabric", 0.025)
	for x in [-0.1, 0.1]: box(p, Vector3(x, 0.5, 0), Vector3(0.05, 0.2, 0.25), WOOD, "bucket")
	for z in [-0.1, 0.1]: box(p, Vector3(0, 0.5, z), Vector3(0.15, 0.2, 0.05), WOOD, "bucket")
	box(p, Vector3(0, 0.41, 0), Vector3(0.2, 0.05, 0.2), EDGE, "bucket")

static func _bench(p: Array[Dictionary]) -> void:
	for x in [-0.34, 0.34]:
		for z in [-0.34, 0.34]: box(p, Vector3(x, 0.36, z), Vector3(0.1, 0.7, 0.1), EDGE)
		box(p, Vector3(x, 0.16, 0), Vector3(0.1, 0.1, 0.75), WOOD)
	box(p, Vector3(0, 0.18, 0.3), Vector3(0.75, 0.1, 0.1), WOOD)
	for slat in range(9): box(p, Vector3(-0.4 + slat * 0.1, 0.77, 0), Vector3(0.1, 0.1, 0.9), WOOD.lightened(0.035 * (slat % 3)))
	box(p, Vector3(0, 0.64, -0.31), Vector3(0.55, 0.15, 0.15), WOOD.darkened(0.08), "drawer")
	box(p, Vector3(0, 0.65, -0.41), Vector3(0.2, 0.025, 0.025), IRON, "drawer", "metal", 0.025)
	box(p, Vector3(0.08, 0.84, 0.06), Vector3(0.45, 0.025, 0.55), Color("e6dfc8"), "paper", "paper", 0.025)
	for x in range(5): box(p, Vector3(-0.1 + x * 0.075, 0.86, 0.06), Vector3(0.025, 0.025, 0.45), Color("648b9d"), "paper", "paper", 0.025)
	for z in range(5): box(p, Vector3(0.05, 0.865, -0.1 + z * 0.075), Vector3(0.35, 0.025, 0.025), Color("648b9d"), "paper", "paper", 0.025)
	box(p, Vector3(-0.28, 0.85, -0.2), Vector3(0.05, 0.05, 0.35), EDGE, "tool")
	box(p, Vector3(-0.28, 0.88, -0.31), Vector3(0.2, 0.1, 0.1), IRON, "tool", "metal")
	box(p, Vector3(0.36, 0.82, 0.23), Vector3(0.15, 0.1, 0.2), IRON, "body", "metal")
	cube(p, Vector3(0.41, 0.9, 0.23), 0.05, BRASS, "body", "metal")

static func crop_parts(stage: int) -> Array[Dictionary]:
	var p: Array[Dictionary] = []
	if stage <= 0: return p
	for x in [-0.23, 0.0, 0.23]:
		for z in [-0.23, 0.23]:
			var height: float = [0.0, 0.15, 0.32, 0.45][clampi(stage, 0, 3)]
			box(p, Vector3(x, height * 0.5, z), Vector3(0.025, height, 0.025), Color("9caa50") if stage == 3 else Color("648d4b"), "crop", "plant", 0.025)
			for side in [-1, 1]:
				cube(p, Vector3(x + side * 0.035, height * 0.42, z), 0.05, Color("72964c"), "crop", "plant")
				if stage > 1: cube(p, Vector3(x + side * 0.055, height * 0.47, z), 0.025, Color("72964c"), "crop", "plant")
			if stage == 3:
				for y in range(4): cube(p, Vector3(x + (0.015 if y % 2 else -0.015), height + y * 0.03, z), 0.045, Color("d9b761").lightened(0.04 * (y % 2)), "crop", "plant")
	return p

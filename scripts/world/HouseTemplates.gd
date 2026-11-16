extends RefCounted

# Reusable, grid-aligned building models. Local Y=0 is the finished floor;
# the two-wide front entrance faces +Z. All solids remain ordinary world cubes.
const STYLES: Array[String] = ["cottage", "lodge", "stone", "workshop", "courtyard"]
const TITLES := {
	"cottage": "田园瓦顶屋", "lodge": "林木长屋", "stone": "石砌民居",
	"workshop": "匠人作坊", "courtyard": "庭院双屋"
}
const SIZES := {
	"cottage": Vector2i(9, 11), "lodge": Vector2i(13, 11),
	"stone": Vector2i(11, 11), "workshop": Vector2i(13, 13),
	"courtyard": Vector2i(13, 13)
}
static var _models: Dictionary = {}
static var _rotated: Dictionary = {}

static func model(style: String, variation: int = 0) -> Dictionary:
	if not SIZES.has(style):
		return {}
	var variant := posmod(variation, 3)
	var key := style + ":" + str(variant)
	if _models.has(key):
		return _models[key]
	var extent: Vector2i = SIZES[style]
	var cells: Dictionary = {}
	var room := Rect2i(1, 1, extent.x - 2, extent.y - 4)
	var doorway_x := extent.x / 2 - 1
	var wall := 7
	var floor_material := 7
	var roof := 8
	if style == "lodge":
		wall = 3
		roof = 7 if variant != 2 else 13
	elif style == "stone":
		wall = 14 if variant != 1 else 13
		floor_material = 14
		roof = 13
	elif style == "workshop":
		wall = 7 if variant != 1 else 14
		floor_material = 13
		roof = 8 if variant != 2 else 13
	elif style == "courtyard":
		room = Rect2i(1, 1, 7, 8)
		doorway_x = 3
		wall = 17 if variant == 1 else 7
		floor_material = 14
		roof = 8 if variant != 2 else 7
	_shell(cells, room, wall, floor_material, 4)
	if style == "stone":
		_hip_roof(cells, room.grow(1), 5, roof)
	else:
		_gable_roof(cells, room.grow(1), 5, roof, wall)
	var front := room.end.y - 1
	_door(cells, doorway_x, front)
	# A level porch connects directly to village paths without a one-block step.
	for z in range(front + 1, extent.y):
		for x in range(doorway_x - 1, doorway_x + 3):
			_put(cells, Vector3i(x, 0, z), floor_material)
	if style in ["cottage", "lodge"]:
		_porch(cells, doorway_x - 1, doorway_x + 2, front + 1, extent.y - 1, 4, roof)
	if style == "courtyard":
		var annex := Rect2i(8, 1, 4, 6)
		_shell(cells, annex, wall, floor_material, 3)
		_gable_roof(cells, annex.grow(1), 4, roof, wall)
		# The second room opens into the sheltered courtyard, not into a wall.
		_door(cells, 9, annex.end.y - 1)
		for z in range(7, 11):
			for x in range(8, 12):
				_put(cells, Vector3i(x, 0, z), 13 if (x + z) % 3 == 0 else 14)
		_put(cells, Vector3i(11, 1, 10), 7)
		_put(cells, Vector3i(11, 1, 11), 7)
	elif style == "workshop":
		# The wide work porch and chimney distinguish the workshop silhouette.
		_porch(cells, 2, extent.x - 3, front + 1, extent.y - 1, 4, 7)
		_put(cells, Vector3i(2, 1, front + 1), 20)
		_put(cells, Vector3i(extent.x - 3, 1, front + 1), 13)
		for y in range(1, 10):
			_put(cells, Vector3i(room.end.x - 2, y, 2), 14)
		_put(cells, Vector3i(room.end.x - 2, 10, 2), 13)
	else:
		# Fixed furniture leaves the entrance's central aisle unobstructed.
		_put(cells, Vector3i(2, 1, 2), 7)
		_put(cells, Vector3i(2, 1, 3), 7)
		_put(cells, Vector3i(room.end.x - 2, 1, 2), 20 if style == "lodge" else 7)
	# Clear the entry after roof/porch construction, including the second doorway.
	_door(cells, doorway_x, front)
	var tallest := 0
	for cell in cells:
		tallest = maxi(tallest, cell.y)
	var result := {
		"style": style, "title": TITLES[style], "variation": variant,
		"size": Vector3i(extent.x, tallest + 1, extent.y), "cells": cells,
		"door": Vector3i(doorway_x, 1, front),
		"entrance": Vector3i(doorway_x, 1, extent.y - 1),
		"room": room
	}
	_models[key] = result
	return result

static func oriented(style: String, variation: int, turns: int) -> Dictionary:
	turns = posmod(turns, 4)
	var key := style + ":" + str(posmod(variation, 3)) + ":" + str(turns)
	if _rotated.has(key):
		return _rotated[key]
	var source := model(style, variation)
	if source.is_empty():
		return {}
	var extent: Vector3i = source.size
	var cells: Dictionary = {}
	for cell in source.cells:
		cells[rotate_cell(cell, turns, extent)] = source.cells[cell]
	var result := {
		"style": style, "title": source.title, "variation": source.variation,
		"turns": turns, "cells": cells,
		"size": Vector3i(extent.z, extent.y, extent.x) if turns % 2 else extent,
		"door": rotate_cell(source.door, turns, extent),
		"entrance": rotate_cell(source.entrance, turns, extent)
	}
	_rotated[key] = result
	return result

static func rotate_cell(cell: Vector3i, turns: int, extent: Vector3i) -> Vector3i:
	match posmod(turns, 4):
		1: return Vector3i(extent.z - 1 - cell.z, cell.y, cell.x)
		2: return Vector3i(extent.x - 1 - cell.x, cell.y, extent.z - 1 - cell.z)
		3: return Vector3i(cell.z, cell.y, extent.x - 1 - cell.x)
	return cell

static func _shell(cells: Dictionary, room: Rect2i, wall: int, floor_id: int, height: int) -> void:
	for z in range(room.position.y, room.end.y):
		for x in range(room.position.x, room.end.x):
			_put(cells, Vector3i(x, 0, z), floor_id)
			var edge := x == room.position.x or x == room.end.x - 1 or z == room.position.y or z == room.end.y - 1
			if not edge:
				continue
			var corner := (x == room.position.x or x == room.end.x - 1) and (z == room.position.y or z == room.end.y - 1)
			for y in range(1, height + 1):
				var material := 3 if corner or y == height else wall
				var window := y in [2, 3] and not corner and ((x == room.position.x or x == room.end.x - 1) and posmod(z - room.position.y, 4) in [2, 3] or z == room.position.y and posmod(x - room.position.x, 4) in [2, 3])
				_put(cells, Vector3i(x, y, z), 16 if window else material)
			_put(cells, Vector3i(x, height + 1, z), 7)
	# A continuous ceiling supports the stepped roof, leaving four clear blocks below.
	for z in range(room.position.y, room.end.y):
		for x in range(room.position.x, room.end.x):
			_put(cells, Vector3i(x, height + 1, z), 7)

static func _gable_roof(cells: Dictionary, roof: Rect2i, base: int, material: int, gable: int) -> void:
	for x in range(roof.position.x, roof.end.x):
		var rise := mini(x - roof.position.x, roof.end.x - 1 - x)
		for z in range(roof.position.y, roof.end.y):
			_put(cells, Vector3i(x, base + rise, z), material)
			if z in [roof.position.y + 1, roof.end.y - 2]:
				for y in range(base, base + rise):
					_put(cells, Vector3i(x, y, z), gable)

static func _hip_roof(cells: Dictionary, roof: Rect2i, base: int, material: int) -> void:
	for z in range(roof.position.y, roof.end.y):
		for x in range(roof.position.x, roof.end.x):
			var rise := mini(mini(x - roof.position.x, roof.end.x - 1 - x), mini(z - roof.position.y, roof.end.y - 1 - z))
			for y in range(base, base + mini(rise, 3) + 1):
				_put(cells, Vector3i(x, y, z), material)

static func _door(cells: Dictionary, x: int, z: int) -> void:
	for dx in range(2):
		for y in range(1, 4):
			cells.erase(Vector3i(x + dx, y, z))

static func _porch(cells: Dictionary, left: int, right: int, back: int, front: int, height: int, roof: int) -> void:
	for x in [left, right]:
		for y in range(1, height):
			_put(cells, Vector3i(x, y, front), 3)
	for z in range(back, front + 1):
		for x in range(left, right + 1):
			_put(cells, Vector3i(x, height, z), roof)

static func _put(cells: Dictionary, cell: Vector3i, id: int) -> void:
	cells[cell] = id

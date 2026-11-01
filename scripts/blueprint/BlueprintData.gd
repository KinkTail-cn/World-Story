extends RefCounted

class_name BlueprintData

var name: String = "未命名蓝图"
var category: String = "道具摆件"
var grid_size: int = 8
var cells: Array[int] = []
var voxels: Array[Dictionary] = []
var created_at: String = ""

const VOXEL_SIZE: float = 0.13

static func voxel_center(voxel: Dictionary) -> Vector3:
	var center: Variant = voxel.get("center", [])
	if center is Array and center.size() == 3:
		return Vector3(float(center[0]), float(center[1]), float(center[2]))
	# Legacy pos is always rendered in standard voxel units, regardless of size.
	var pos: Variant = voxel.get("pos", Vector3i.ZERO)
	if pos is Array and pos.size() == 3:
		return Vector3(float(pos[0]), float(pos[1]), float(pos[2])) * VOXEL_SIZE
	return Vector3(pos) * VOXEL_SIZE

func _init(blueprint_name: String = "未命名蓝图", blueprint_category: String = "道具摆件", size: int = 8) -> void:
	name = blueprint_name
	category = blueprint_category
	grid_size = 8 if size not in [8, 12, 16] else size
	created_at = Time.get_datetime_string_from_system()
	_resize_cells()

func _resize_cells() -> void:
	cells.clear()
	for _index in range(grid_size * grid_size):
		cells.append(0)

func is_equipment() -> bool:
	return category in ["头部装备", "盔甲", "裤甲", "鞋子", "手套", "披风", "腰带"]

func add_voxel(pos: Vector3i, material_id: int, part: String, size_mode: int = 1, center_pos: Array = []) -> void:
	var entry := {"pos": pos, "mat": material_id, "part": part, "size": size_mode}
	if not center_pos.is_empty():
		entry["center"] = center_pos.duplicate()
	var existing := get_voxel_at(voxel_center(entry), part)
	if not existing.is_empty():
		existing.merge(entry, true)
		if center_pos.is_empty():
			existing.erase("center")
		return
	voxels.append(entry)

func remove_voxel(center: Vector3, part: String) -> bool:
	for i in range(voxels.size()):
		if str(voxels[i].part) == part and voxel_center(voxels[i]).distance_to(center) < 0.000001:
			voxels.remove_at(i)
			return true
	return false

func get_voxel_at(center: Vector3, part: String) -> Dictionary:
	for voxel in voxels:
		if str(voxel.part) == part and voxel_center(voxel).distance_to(center) < 0.000001:
			return voxel
	return {}

func recolor_voxel(center: Vector3, part: String, material_id: int) -> bool:
	var voxel := get_voxel_at(center, part)
	if voxel.is_empty():
		return false
	voxel.mat = material_id
	return true

func get_material_counts() -> Dictionary:
	var counts: Dictionary = {}
	if not voxels.is_empty():
		for voxel in voxels:
			var mat_id: int = voxel.mat
			if mat_id > 0:
				counts[mat_id] = int(counts.get(mat_id, 0)) + 1
	else:
		for material_id in cells:
			if material_id > 0:
				counts[material_id] = int(counts.get(material_id, 0)) + 1
	return counts

func estimate_stats() -> Dictionary:
	return {"filled_cells": get_material_counts().values().reduce(func(total: int, value: int) -> int: return total + value, 0), "materials": get_material_counts()}

func to_dictionary() -> Dictionary:
	var voxel_data: Array[Dictionary] = []
	for voxel in voxels:
		var item := {"pos": [voxel.pos.x, voxel.pos.y, voxel.pos.z], "mat": voxel.mat, "part": voxel.part}
		if voxel.has("size"):
			item["size"] = voxel.size
		if voxel.has("center"):
			item["center"] = voxel.center.duplicate()
		voxel_data.append(item)
	return {"name": name, "category": category, "grid_size": grid_size, "cells": cells.duplicate(), "voxels": voxel_data, "created_at": created_at}

static func from_dictionary(value: Dictionary):
	var script = load("res://scripts/blueprint/BlueprintData.gd")
	var result = script.new(str(value.get("name", "未命名蓝图")), str(value.get("category", "道具摆件")), int(value.get("grid_size", 8)))
	result.created_at = str(value.get("created_at", result.created_at))
	var source: Array = value.get("cells", [])
	result.cells.clear()
	for index in range(result.grid_size * result.grid_size):
		result.cells.append(int(source[index]) if index < source.size() else 0)
	result.voxels.clear()
	for voxel_dict in value.get("voxels", []):
		var pos_array: Array = voxel_dict.get("pos", [0, 0, 0])
		var entry := {
			"pos": Vector3i(int(pos_array[0]), int(pos_array[1]), int(pos_array[2])),
			"mat": int(voxel_dict.get("mat", 1)),
			"part": str(voxel_dict.get("part", "")),
			"size": int(voxel_dict.get("size", 1))
		}
		if voxel_dict.has("center"):
			entry["center"] = voxel_dict.center.duplicate()
		result.voxels.append(entry)
	return result

static func validation_error(value: Dictionary) -> String:
	if value.has("grid_size") and (not _integer(value.grid_size) or int(value.grid_size) not in [8, 12, 16]):
		return "蓝图网格尺寸无效"
	if not value.get("cells", []) is Array or not value.get("voxels", []) is Array:
		return "蓝图方块列表无效"
	for material in value.get("cells", []):
		if not _integer(material) or material < 0 or material > 8:
			return "蓝图材料无效"
	for voxel in value.get("voxels", []):
		if not voxel is Dictionary or not _vector(voxel.get("pos", [0, 0, 0])):
			return "蓝图方块坐标无效"
		if voxel.get("pos") is Array and not voxel.pos.all(_integer):
			return "蓝图网格坐标必须为整数"
		if voxel.has("center") and not _vector(voxel.center):
			return "蓝图方块中心无效"
		var material: Variant = voxel.get("mat", 1)
		var mode: Variant = voxel.get("size", 1)
		if not _integer(material) or material < 1 or material > 8 or not _integer(mode) or mode < 1 or mode > 4:
			return "蓝图材料或方块尺寸无效"
	return ""

static func _number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))

static func _integer(value: Variant) -> bool:
	return _number(value) and float(value) == floorf(float(value))

static func _vector(value: Variant) -> bool:
	return value is Vector3i or (value is Array and value.size() == 3 and value.all(_number))

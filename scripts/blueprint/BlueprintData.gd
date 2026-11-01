extends RefCounted

class_name BlueprintData

const Geometry = preload("res://scripts/blueprint/BlueprintGeometry.gd")
const Materials = preload("res://scripts/blueprint/BlueprintMaterials.gd")
const MAX_PARTS: int = 4096

var name: String = "未命名蓝图"
var category: String = "道具摆件"
var grid_size: int = 8
var cells: Array[int] = []
var voxels: Array[Dictionary] = []
var created_at: String = ""
var schema_version: int = 2
var source_item_id: int = 0
var _next_id: int = 1

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

func add_part(entry: Dictionary) -> String:
	if voxels.size() >= MAX_PARTS:
		return ""
	var part := entry.duplicate(true)
	while find_part("part_%d" % _next_id) >= 0:
		_next_id += 1
	part["uid"] = "part_%d" % _next_id
	_next_id += 1
	part["label"] = str(part.get("label", "部件 %d" % (voxels.size() + 1)))
	voxels.append(part)
	return part.uid

func ensure_ids() -> void:
	var used := {}
	for index in voxels.size():
		var uid := str(voxels[index].get("uid", "legacy_%d" % index))
		if uid.is_empty() or used.has(uid):
			uid = "legacy_%d_%d" % [index, _next_id]
			_next_id += 1
		voxels[index]["uid"] = uid
		used[uid] = true

func find_part(uid: String) -> int:
	for index in voxels.size():
		if str(voxels[index].get("uid", "")) == uid:
			return index
	return -1

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
		var item: Dictionary = _serialized(voxel)
		var position := Geometry.vector(voxel.get("pos"))
		item["pos"] = [int(position.x), int(position.y), int(position.z)]
		voxel_data.append(item)
	return {"schema_version": schema_version, "source_item_id": source_item_id, "name": name, "category": category, "grid_size": grid_size, "cells": cells.duplicate(), "voxels": voxel_data, "created_at": created_at}

static func _serialized(value: Variant) -> Variant:
	if value is Dictionary:
		var result := {}
		for key in value:
			result[key] = _serialized(value[key])
		return result
	if value is Array:
		var result: Array = []
		for element in value:
			result.append(_serialized(element))
		return result
	# Stable micrometre / microdegree precision prevents JSON's display-number
	# formatting from changing snapshots on every save-and-load cycle.
	if value is float:
		return roundf(value * 1000000.0) / 1000000.0
	return value

static func from_dictionary(value: Dictionary):
	var script = load("res://scripts/blueprint/BlueprintData.gd")
	var result = script.new(str(value.get("name", "未命名蓝图")), str(value.get("category", "道具摆件")), int(value.get("grid_size", 8)))
	result.created_at = str(value.get("created_at", result.created_at))
	result.source_item_id = int(value.get("source_item_id", 0))
	var source: Array = value.get("cells", [])
	result.cells.clear()
	for index in range(result.grid_size * result.grid_size):
		result.cells.append(int(source[index]) if index < source.size() else 0)
	result.voxels.clear()
	for voxel_dict in value.get("voxels", []):
		var pos_array := Geometry.vector(voxel_dict.get("pos", [0, 0, 0]))
		var entry := {
			"pos": Vector3i(int(pos_array[0]), int(pos_array[1]), int(pos_array[2])),
			"mat": int(voxel_dict.get("mat", 1)),
			"part": str(voxel_dict.get("part", "")),
			"size": int(voxel_dict.get("size", 1))
		}
		for key in ["center", "uid", "label", "shape", "dimensions", "anchor", "offset", "rotation", "tint", "surface", "cloth", "hidden", "locked"]:
			if voxel_dict.has(key):
				var field: Variant = voxel_dict[key]
				entry[key] = field.duplicate(true) if field is Array or field is Dictionary else field
		if entry.has("cloth"):
			entry.cloth["emblem"] = int(entry.cloth.get("emblem", 0))
			entry.cloth["wind"] = float(entry.cloth.get("wind", 1.0))
		result.voxels.append(entry)
	return result

static func validation_error(value: Dictionary) -> String:
	for key in ["name", "category", "created_at"]:
		if value.has(key) and not value[key] is String:
			return "蓝图名称或类别格式无效"
	if value.has("source_item_id") and not _integer(value.source_item_id):
		return "蓝图来源 ID 无效"
	if value.has("schema_version") and (not _integer(value.schema_version) or value.schema_version < 1 or value.schema_version > 2):
		return "蓝图版本不受支持"
	if value.has("grid_size") and (not _integer(value.grid_size) or int(value.grid_size) not in [8, 12, 16]):
		return "蓝图网格尺寸无效"
	if not value.get("cells", []) is Array or not value.get("voxels", []) is Array:
		return "蓝图方块列表无效"
	if value.get("voxels", []).size() > MAX_PARTS:
		return "蓝图最多支持 4096 个部件"
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
		for key in ["uid", "label", "part"]:
			if voxel.has(key) and not voxel[key] is String:
				return "部件名称、标识或类别无效"
		var material: Variant = voxel.get("mat", 1)
		var mode: Variant = voxel.get("size", 1)
		if not _integer(material) or material < 1 or material > 8 or not _integer(mode) or mode < 1 or mode > 4:
			return "蓝图材料或方块尺寸无效"
		if str(voxel.get("shape", "box")) not in Geometry.SHAPES or str(voxel.get("surface", "solid")) not in Materials.SURFACES:
			return "蓝图形状或表面类型无效"
		if voxel.has("anchor") and not Geometry.ORIGINS.has(str(voxel.anchor)):
			return "蓝图身体挂点无效"
		for key in ["dimensions", "offset", "rotation"]:
			if voxel.has(key) and (not voxel[key] is Array or not _vector(voxel[key])):
				return "蓝图变换参数无效"
		if voxel.has("dimensions"):
			var extent := Geometry.vector(voxel.dimensions)
			if minf(extent.x, minf(extent.y, extent.z)) < 0.005 or maxf(extent.x, maxf(extent.y, extent.z)) > 4.0:
				return "部件尺寸应在 0.005 至 4 米之间"
		if voxel.has("offset"):
			var offset := Geometry.vector(voxel.offset).abs()
			if maxf(offset.x, maxf(offset.y, offset.z)) > 64.0:
				return "部件位置超出允许范围"
		if voxel.has("tint") and (not voxel.tint is String or not Color.html_is_valid(voxel.tint)):
			return "蓝图染色无效"
		for key in ["hidden", "locked"]:
			if voxel.has(key) and not voxel[key] is bool:
				return "部件显示或锁定状态无效"
		if voxel.has("cloth"):
			if not voxel.cloth is Dictionary:
				return "布料参数无效"
			var cloth: Dictionary = voxel.cloth
			if not _integer(cloth.get("emblem", 0)) or int(cloth.get("emblem", 0)) not in range(4):
				return "布料图案无效"
			if not _number(cloth.get("wind", 1.0)) or float(cloth.get("wind", 1.0)) < 0.0 or float(cloth.get("wind", 1.0)) > 2.0:
				return "布料风力比例无效"
			if not cloth.get("trim", "c3ad79") is String or not Color.html_is_valid(str(cloth.get("trim", "c3ad79"))):
				return "布料饰边色无效"
			if not _number(cloth.get("flare", 0.06)) or absf(float(cloth.get("flare", 0.06))) > 0.4 or Geometry.dimensions(voxel).x + float(cloth.get("flare", 0.06)) < 0.005:
				return "布料下摆宽度无效"
	return ""

static func _number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))

static func _integer(value: Variant) -> bool:
	return _number(value) and float(value) == floorf(float(value))

static func _vector(value: Variant) -> bool:
	return value is Vector3i or (value is Array and value.size() == 3 and value.all(_number) and Geometry.vector(value).is_finite())

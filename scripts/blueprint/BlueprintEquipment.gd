extends RefCounted

const Data = preload("res://scripts/blueprint/BlueprintData.gd")
const Blocks = preload("res://scripts/content/BlockCatalog.gd")
const Geometry = preload("res://scripts/blueprint/BlueprintGeometry.gd")
const Materials = preload("res://scripts/blueprint/BlueprintMaterials.gd")
const CATEGORIES: Array[String] = ["头部装备", "盔甲", "裤甲", "鞋子", "手套", "披风", "腰带"]
const MATERIAL_NAMES: Array[String] = Materials.NAMES
const MATERIAL_COLORS: Array[Color] = Materials.COLORS
const RESOURCE_IDS: Array[int] = Materials.RESOURCE_IDS
# One material block supplies 512 standard (1/8) voxels. Count in smallest
# (1/32) units so every brush size has an exact integer volume.
const UNITS_PER_BLOCK: int = 32768
const VOLUME_UNITS: Array[int] = [0, 64, 512, 8, 1]

static func equipment_id(blueprint: Dictionary) -> int:
	var slot := CATEGORIES.find(str(blueprint.get("category", "")))
	return 101 + slot if slot >= 0 else 0

static func is_custom_item(item: Dictionary) -> bool:
	var blueprint: Variant = item.get("blueprint")
	return blueprint is Dictionary and equipment_id(blueprint) > 0 and int(item.get("id", 0)) == equipment_id(blueprint)

static func size_scale(mode: int) -> float:
	return [1.0, 1.0, 2.0, 0.5, 0.25][clampi(mode, 0, 4)]

static func active_voxels(blueprint: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if int(blueprint.get("schema_version", 1)) < Data.SCHEMA_VERSION:
		blueprint = Data.from_dictionary(blueprint).to_dictionary()
	for voxel in blueprint.get("voxels", []):
		if voxel is Dictionary and str(voxel.get("part", "")) == str(blueprint.get("category", "")):
			result.append(voxel)
	return result

static func validation_error(blueprint: Dictionary) -> String:
	var data_error := Data.validation_error(blueprint)
	if not data_error.is_empty():
		return data_error
	if equipment_id(blueprint) == 0:
		return "请选择头部装备、盔甲、裤甲、鞋子、手套、披风或腰带进行制作"
	var voxels := active_voxels(blueprint)
	if voxels.is_empty():
		return "请先在当前部位放置至少一个方块"
	for voxel in voxels:
		if int(voxel.get("mat", 0)) not in range(1, 9) or int(voxel.get("size", 1)) not in range(1, 5):
			return "蓝图包含无效的材料或方块尺寸"
		var pos: Variant = voxel.get("pos")
		if not (pos is Vector3i or (pos is Array and pos.size() == 3)):
			return "蓝图包含无效的方块坐标"
	return ""

static func material_cost(blueprint: Dictionary) -> Dictionary:
	var volumes := {}
	for voxel in active_voxels(blueprint):
		var material := int(voxel.get("mat", 0))
		var mode := int(voxel.get("size", 1))
		if material < 1 or material > 8 or mode < 1 or mode > 4:
			continue
		var resource: int = RESOURCE_IDS[material - 1]
		volumes[resource] = float(volumes.get(resource, 0.0)) + Geometry.volume(voxel)
	var result := {}
	for resource in volumes:
		result[resource] = maxi(1, ceili(float(volumes[resource]) / (pow(Geometry.UNIT, 3.0) * 512.0) - 0.000000001))
	return result

static func make_item(blueprint: Dictionary) -> Dictionary:
	if not validation_error(blueprint).is_empty():
		return {}
	var saved := blueprint.duplicate(true)
	saved["voxels"] = active_voxels(blueprint).duplicate(true)
	# Store a canonical serializable snapshot, independent of later editing.
	saved = Data.from_dictionary(saved).to_dictionary()
	var title := str(saved.get("name", "")).strip_edges()
	if title.is_empty() or title == "未命名蓝图":
		title = "自制" + str(saved.category)
	return {"id": equipment_id(saved), "count": 1, "custom_name": title, "blueprint": saved}

static func template_origin(category: String) -> Vector3:
	return Geometry.template_origin(category)

static func character_position(blueprint: Dictionary, voxel: Dictionary) -> Vector3:
	return Geometry.character_transform(voxel, str(blueprint.get("category", ""))).origin

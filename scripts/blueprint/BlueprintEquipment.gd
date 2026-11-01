extends RefCounted

const Data = preload("res://scripts/blueprint/BlueprintData.gd")
const Blocks = preload("res://scripts/content/BlockCatalog.gd")
const CATEGORIES: Array[String] = ["头部装备", "盔甲", "裤甲", "鞋子", "手套", "披风", "腰带"]
const MATERIAL_NAMES: Array[String] = ["岩纹石", "海纹玉", "暖阳金", "苔痕木", "暮紫晶", "寒铁", "赤陶土", "云母矿"]
const MATERIAL_COLORS: Array[Color] = [
	Color("#d28f62"), Color("#82a8b8"), Color("#d8bf73"), Color("#8ca77d"),
	Color("#b38ca8"), Color("#7e8798"), Color("#d17c6d"), Color("#e7d9b2")
]
const RESOURCE_IDS: Array[int] = [5, 16, 11, 3, 19, 9, 8, 17]
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
	for voxel in blueprint.get("voxels", []):
		if voxel is Dictionary and str(voxel.get("part", "")) == str(blueprint.get("category", "")):
			result.append(voxel)
	return result

static func validation_error(blueprint: Dictionary) -> String:
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
		volumes[resource] = int(volumes.get(resource, 0)) + VOLUME_UNITS[mode]
	var result := {}
	for resource in volumes:
		result[resource] = ceili(float(volumes[resource]) / float(UNITS_PER_BLOCK))
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
	match category:
		"头部装备": return Vector3(0, 1.575, 0)
		"盔甲": return Vector3(0, 1.0125, 0)
		"裤甲": return Vector3(0, 0.38, 0)
		"鞋子": return Vector3(0, 0.09, 0)
		"手套": return Vector3(-0.3375, 0.78, 0)
		"披风": return Vector3(0, 1.30, -0.16)
		"腰带": return Vector3(0, 0.715, 0)
	return Vector3.ZERO

static func character_position(blueprint: Dictionary, voxel: Dictionary) -> Vector3:
	var preview := template_origin(str(blueprint.get("category", ""))) + Data.voxel_center(voxel)
	# The workshop mannequin faces the viewer (180 degrees from the game rig).
	return Vector3(-preview.x, preview.y, -preview.z)

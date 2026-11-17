extends RefCounted

const Data = preload("res://scripts/blueprint/BlueprintData.gd")
const Blocks = preload("res://scripts/content/BlockCatalog.gd")
const Geometry = preload("res://scripts/blueprint/BlueprintGeometry.gd")
const Materials = preload("res://scripts/blueprint/BlueprintMaterials.gd")
const VillageItems = preload("res://scripts/content/VillageItems.gd")
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
	if slot >= 0:
		return 101 + slot
	var category := str(blueprint.get("category", ""))
	var id := int(blueprint.get("target_item_id", 0))
	if category == "工具":
		return id if id in range(201, 210) else (201 if id == 0 else 0)
	if category == "武器":
		return id if id in range(301, 306) else (301 if id == 0 else 0)
	if category == "道具摆件":
		return id if id in VillageItems.FACILITIES else (504 if id == 0 else 0)
	return 0

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
		return "请选择有效的装备、工具、武器或生活设施类别"
	var voxels := active_voxels(blueprint)
	if voxels.is_empty():
		return "请先在当前部位放置至少一个方块"
	for voxel in voxels:
		if int(voxel.get("mat", 0)) not in range(1, 9) or int(voxel.get("size", 1)) not in range(1, 5):
			return "蓝图包含无效的材料或方块尺寸"
		var pos: Variant = voxel.get("pos")
		if not (pos is Vector3i or (pos is Array and pos.size() == 3)):
			return "蓝图包含无效的方块坐标"
	if str(blueprint.get("category", "")) not in CATEGORIES:
		var bounds := item_bounds(blueprint)
		var door := equipment_id(blueprint) == 510
		var limit := 3.00001 if door else (2.6 if str(blueprint.category) == "道具摆件" else 1.8)
		if maxf(bounds.size.x, maxf(bounds.size.y, bounds.size.z)) > limit:
			return "该类别的成品整体尺寸过大"
		if door and (bounds.size.x < 1.7 or bounds.size.x > 2.00001 or bounds.size.y < 2.0 or bounds.size.z > 0.3):
			return "双扇木门应为 1.7–2 米宽、2–3 米高、厚度不超过 0.3 米"
		if str(blueprint.category) in ["工具", "武器"] and bounds.get_center().length() > 1.5:
			return "请围绕握柄基准搭建工具或武器"
	return ""

static func item_bounds(blueprint: Dictionary) -> AABB:
	var bounds := AABB()
	var first := true
	var category := str(blueprint.get("category", ""))
	for part in active_voxels(blueprint):
		var pos := Geometry.preview_transform(part, category).origin
		if category in ["工具", "武器"]: pos -= Vector3(-0.34, 0.78, 0.18)
		var size := Geometry.dimensions(part)
		var box := AABB(pos - size * 0.5, size)
		bounds = box if first else bounds.merge(box)
		first = false
	return bounds

static func product_ids(category: String) -> Array[int]:
	var result: Array[int] = []
	if category == "工具":
		for id in range(201, 210): result.append(id)
	elif category == "武器":
		for id in range(301, 306): result.append(id)
	elif category == "道具摆件":
		result.assign(VillageItems.FACILITIES)
	return result

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
	var id := equipment_id(blueprint)
	var core := {}
	if id in range(201, 210): core = {3: 1, (3 if id <= 203 else (5 if id <= 206 else 602)): 1}
	elif id in range(301, 306): core = {3: 1, {301: 3, 302: 5, 303: 602, 304: 608, 305: 19}[id]: 1}
	elif id in VillageItems.FACILITIES:
		core = {3: 1}
		if id in [502, 508]: core[5] = 1
		if id == 505: core[16] = 1; core[10] = 1
		if id == 503: core[4] = 1
		if id == 507: core[2] = 1
	for resource in core: result[resource] = maxi(int(result.get(resource, 0)), int(core[resource]))
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

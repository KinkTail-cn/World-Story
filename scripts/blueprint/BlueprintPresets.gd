extends RefCounted

const Data = preload("res://scripts/blueprint/BlueprintData.gd")
const Geometry = preload("res://scripts/blueprint/BlueprintGeometry.gd")
const Models = preload("res://scripts/player/EquipmentModels.gd")
const Sets = preload("res://scripts/content/EquipmentSets.gd")
const CATEGORIES: Array[String] = ["头部装备", "盔甲", "裤甲", "鞋子", "手套", "披风", "腰带"]
static var _designs: Dictionary = {}

static func design_for_item(id: int) -> Dictionary:
	if _designs.has(id):
		return _designs[id].duplicate(true)
	if not Sets.is_new(id):
		return {}
	var category: String = CATEGORIES[Sets.slot(id)]
	var blueprint = Data.new(Sets.title(id), category)
	blueprint.source_item_id = id
	blueprint.created_at = "2026-11-02T00:00:00"
	var index := 0
	for model in Models.parts(id):
		var extent: Vector3 = model.size
		var pos: Vector3 = model.pos
		var rotation: Vector3 = model.rotation
		var shape: String = model.shape
		if shape == "cloth":
			pos.y -= extent.y * 0.5
		elif shape == "cone":
			extent.x /= sqrt(2.0)
			extent.z /= sqrt(2.0)
			rotation.y -= PI * 0.25
		var transform := Transform3D(Basis.from_euler(rotation), Vector3(Geometry.ORIGINS[model.bone]) + pos)
		var part := {"part": category, "mat": 4 if Sets.style(id) == "ranger" else (6 if Sets.style(id) == "knight" else 5), "size": 1, "shape": shape, "dimensions": Geometry.array(extent), "tint": Color(model.tint).to_html(false), "surface": "leather" if Sets.style(id) == "ranger" else ("metal" if Sets.style(id) == "knight" else "cloth"), "label": _label(category, str(model.bone), shape, index)}
		if shape == "cloth":
			part["cloth"] = {"trim": Color(model.trim).to_html(false), "emblem": int(model.emblem), "wind": minf(1.0, extent.y / 0.82), "flare": 0.06}
		Geometry.set_character_transform(part, category, transform, str(model.bone))
		blueprint.add_part(part)
		index += 1
	_designs[id] = blueprint.to_dictionary()
	return _designs[id].duplicate(true)

static func _label(category: String, bone: String, shape: String, index: int) -> String:
	var anchor_index := Geometry.ANCHORS.find(bone)
	var name: String = Geometry.ANCHOR_NAMES[anchor_index] if anchor_index >= 0 else category
	return "%s·%s %d" % [name, "布料" if shape == "cloth" else ("尖顶" if shape == "cone" else "部件"), index + 1]

static func all() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for style in Sets.STYLES:
		for id in Sets.ids(style):
			result.append(design_for_item(id))
	return result

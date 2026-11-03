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
		var transform := Transform3D(Basis.IDENTITY, Vector3(Geometry.ORIGINS[model.bone]) + pos)
		var part := {"part": category, "mat": 4 if Sets.style(id) == "ranger" else (6 if Sets.style(id) == "knight" else 5), "size": 1, "shape": "box", "dimensions": Geometry.array(extent), "tint": Color(model.tint).to_html(false), "surface": "leather" if Sets.style(id) == "ranger" else ("metal" if Sets.style(id) == "knight" else "cloth"), "label": _label(category, str(model.bone), index)}
		Geometry.set_character_transform(part, category, transform, str(model.bone))
		blueprint.add_part(part)
		index += 1
	_designs[id] = blueprint.to_dictionary()
	return _designs[id].duplicate(true)

static func _label(category: String, bone: String, index: int) -> String:
	var anchor_index := Geometry.ANCHORS.find(bone)
	var name: String = Geometry.ANCHOR_NAMES[anchor_index] if anchor_index >= 0 else category
	return "%s·方块 %d" % [name, index + 1]

static func all() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for style in Sets.STYLES:
		for id in Sets.ids(style):
			result.append(design_for_item(id))
	return result

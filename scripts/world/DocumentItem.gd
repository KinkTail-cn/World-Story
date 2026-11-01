extends StaticBody3D

const Models = preload("res://scripts/player/DocumentVisual.gd")
const Manager = preload("res://scripts/blueprint/BlueprintManager.gd")
const Catalog = preload("res://scripts/inventory/ItemCatalog.gd")
var item_id: int = 108
var support_cell := Vector3i.ZERO
var contents = Manager.new()

func _ready() -> void:
	collision_layer = 1
	collision_mask = 2
	set_meta("document", true)
	var visual = Models.new()
	visual.item_id = item_id
	add_child(visual)
	var collision := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.62, 0.09, 0.48)
	collision.shape = box
	collision.position.y = 0.05
	add_child(collision)

func save_data() -> Dictionary:
	return {"id": item_id, "support": [support_cell.x, support_cell.y, support_cell.z], "notes": contents.notes.duplicate(), "blueprints": contents.blueprints.duplicate(true), "custom_name": inventory_name()}

func inventory_name() -> String:
	var title := str(get_meta("inventory_custom_name", ""))
	if not title.is_empty() and title != Catalog.title(item_id) and not title.begins_with("蓝图: "):
		return title
	if item_id == 109 and not contents.blueprints.is_empty():
		return "蓝图: " + str(contents.blueprints.back().get("name", "未命名蓝图"))
	return title if not title.is_empty() else Catalog.title(item_id)

func restore_data(data: Dictionary) -> void:
	if data.has("custom_name"):
		set_meta("inventory_custom_name", str(data.custom_name))
	contents.notes.clear()
	for text in data.get("notes", []):
		contents.notes.append(str(text))
	contents.blueprints.clear()
	contents.current = null
	for blueprint in data.get("blueprints", []):
		if blueprint is Dictionary:
			contents.blueprints.append(blueprint)
	if not contents.blueprints.is_empty():
		var Data = preload("res://scripts/blueprint/BlueprintData.gd")
		contents.current = Data.from_dictionary(contents.blueprints.back())

extends RefCounted

const SAVE_PATH := "user://world_story_save.json"
const Blueprint = preload("res://scripts/blueprint/BlueprintData.gd")
const Items = preload("res://scripts/inventory/ItemCatalog.gd")
var save_path: String = SAVE_PATH
var recovered_backup: bool = false
var last_error: String = ""

func _init(path: String = SAVE_PATH) -> void:
	save_path = path

func save_game(data: Dictionary) -> bool:
	var temporary := save_path + ".tmp"
	var backup := save_path + ".bak"
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(_encode(data)))
	file.flush()
	var success := file.get_error() == OK
	file.close()
	if not success:
		DirAccess.remove_absolute(temporary)
		return false
	var had_save := FileAccess.file_exists(save_path)
	# Never replace a usable backup with the broken file we just recovered from.
	var readable := _read_file(save_path)
	if had_save and not recovered_backup and readable.ok and DirAccess.copy_absolute(save_path, backup) != OK:
		DirAccess.remove_absolute(temporary)
		return false
	if _replace_file(temporary, save_path) != OK:
		# Keep the backup available if restoring the previous save also fails.
		if had_save and not FileAccess.file_exists(save_path) and FileAccess.file_exists(backup):
			DirAccess.copy_absolute(backup, save_path)
		DirAccess.remove_absolute(temporary)
		return false
	recovered_backup = false
	return true

func _replace_file(source: String, destination: String) -> Error:
	return DirAccess.rename_absolute(source, destination)

func load_game() -> Dictionary:
	return load_result().data

func load_world() -> Dictionary:
	return load_result(world_validation_error)

func load_result(validator: Callable = Callable()) -> Dictionary:
	last_error = ""
	recovered_backup = false
	for path in [save_path, save_path + ".bak"]:
		var result := _read_file(path)
		if result.ok and validator.is_valid():
			var error: String = validator.call(result.data)
			if not error.is_empty():
				result = {"ok": false, "data": {}, "error": error}
		if result.ok:
			recovered_backup = path != save_path
			return {"ok": true, "data": result.data, "error": "", "recovered": recovered_backup}
		if path == save_path or last_error.is_empty():
			last_error = result.error
	return {"ok": false, "data": {}, "error": last_error, "recovered": false}

func _read_file(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"ok": false, "data": {}, "error": "未找到存档文件"}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {"ok": false, "data": {}, "error": "无法读取存档文件"}
	var text := file.get_as_text()
	var read_error := file.get_error()
	file.close()
	var json := JSON.new()
	if read_error != OK or json.parse(text) != OK or not json.data is Dictionary:
		return {"ok": false, "data": {}, "error": "存档文件损坏或格式不完整"}
	return {"ok": true, "data": _decode(json.data), "error": ""}

func has_save() -> bool:
	return FileAccess.file_exists(save_path) or FileAccess.file_exists(save_path + ".bak")

func delete_save() -> bool:
	var success := true
	for path in [save_path, save_path + ".bak", save_path + ".tmp"]:
		if FileAccess.file_exists(path):
			success = DirAccess.remove_absolute(path) == OK and success
	return success

func world_validation_error(data: Dictionary) -> String:
	if not data.get("world") is Dictionary or not data.get("player") is Dictionary:
		return "存档缺少世界或玩家数据"
	var world: Dictionary = data.world
	var player: Dictionary = data.player
	if not world.has("blocks") and not world.has("modified_blocks"):
		return "存档缺少地形数据"
	if data.get("mode", "creative") not in ["creative", "survival"] or world.get("world_type", "island") not in ["island", "infinite"]:
		return "存档的游戏模式或世界类型无效"
	if world.has("world_seed") and not _integer(world.world_seed):
		return "存档的世界种子无效"
	if world.has("blocks"):
		if not world.blocks is String:
			return "存档的岛屿数据无效"
		var blocks := Marshalls.base64_to_raw(world.blocks)
		if blocks.size() != 32 * 24 * 32:
			return "存档的岛屿数据不完整"
		for id in blocks:
			if id > 20:
				return "存档包含未知方块"
	if not world.get("modified_blocks", []) is Array or not world.get("documents", []) is Array:
		return "存档的世界修改记录无效"
	for entry in world.get("modified_blocks", []):
		if not entry is Array or entry.size() != 4 or not entry.all(_integer):
			return "存档的方块修改记录无效"
		if entry[1] < 1 or entry[1] >= 24 or entry[3] < 0 or entry[3] > 20:
			return "存档的方块坐标或种类无效"
		if world.get("world_type", "island") == "island" and (entry[0] < 0 or entry[0] >= 32 or entry[2] < 0 or entry[2] >= 32):
			return "存档的方块超出岛屿范围"
	for document in world.get("documents", []):
		if not document is Dictionary or document.get("id") not in [108, 109] or not _number_array(document.get("support"), 3):
			return "存档的纸笔数据无效"
		if not _document_valid(document):
			return "存档的纸笔内容无效"
	for key in ["global_position", "rotation", "rig_rotation", "pitch_rotation", "visual_rotation"]:
		if player.has(key) and not (player[key] is Vector3 and player[key].is_finite()):
			return "存档的玩家位置或视角无效"
	if player.has("selected_slot") and (not _integer(player.selected_slot) or player.selected_slot < 0 or player.selected_slot > 7):
		return "存档的快捷栏位置无效"
	if player.has("first_person") and not player.first_person is bool:
		return "存档的视角模式无效"
	if player.has("inventory"):
		if not player.inventory is Dictionary or not _inventory_valid(player.inventory):
			return "存档的背包或装备数据无效"
	return ""

func _inventory_valid(data: Dictionary) -> bool:
	if data.get("mode", "creative") not in ["creative", "survival"]:
		return false
	for group in ["bag", "crafting", "equipment", "equipment_items"]:
		if not data.get(group, []) is Array:
			return false
		var slots: Array = data.get(group, [])
		if (group == "crafting" and slots.size() > 3) or (group in ["equipment", "equipment_items"] and slots.size() > 7):
			return false
		if group == "bag" and data.get("mode", "creative") == "survival" and slots.size() > 24:
			return false
		for index in slots.size():
			var item: Variant = slots[index]
			if group == "equipment":
				if not _integer(item) or index >= 7 or (item != 0 and Items.equipment_slot(int(item)) != index):
					return false
				continue
			if not item is Dictionary or not _integer(item.get("id")) or not _integer(item.get("count")):
				return false
			var id := int(item.id)
			var count := int(item.count)
			if id == 0:
				if count != 0:
					return false
				continue
			if not (Items.is_block(id) or Items.is_document(id) or Items.is_equipment(id) or Items.is_tool_item(id) or Items.is_weapon(id)):
				return false
			if count != -1 and (count < 1 or count > 64):
				return false
			if (Items.is_equipment(id) or Items.is_tool_item(id) or Items.is_weapon(id)) and count != 1:
				return false
			if data.get("mode", "creative") == "survival" and count == -1:
				return false
			if group == "crafting" and (id > 20 or count < 1):
				return false
			if group == "equipment_items" and (index >= 7 or Items.equipment_slot(id) != index):
				return false
			if not _document_valid(item):
				return false
			if item.has("blueprint") and (not item.blueprint is Dictionary or not Blueprint.validation_error(item.blueprint).is_empty()):
				return false
	return true

func _document_valid(value: Dictionary) -> bool:
	if not value.get("notes", []) is Array or not value.get("blueprints", []) is Array:
		return false
	for note in value.get("notes", []):
		if not note is String:
			return false
	for design in value.get("blueprints", []):
		if not design is Dictionary or not Blueprint.validation_error(design).is_empty():
			return false
	return true

static func _integer(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) == floorf(float(value))

static func _number_array(value: Variant, size: int) -> bool:
	return value is Array and value.size() == size and value.all(func(number): return (number is int or number is float) and is_finite(float(number)))

func save_inventory(inventory) -> Dictionary:
	var equipped: Array = []
	if inventory is Object and inventory.has_method("get_slot"):
		for index in inventory.equipment.size():
			equipped.append(inventory.get_slot("equipment", index))
	return {
		"mode": str(_read_value(inventory, "mode", "creative")),
		"bag": _encode(_read_value(inventory, "bag", [])),
		"equipment": _encode(_read_value(inventory, "equipment", [])),
		"equipment_items": _encode(equipped),
		"crafting": _encode(_read_value(inventory, "crafting", []))
	}

func apply_inventory(inventory, data: Dictionary) -> void:
	if data.has("mode") and inventory.has_method("set_mode"):
		inventory.set_mode(str(data.mode))
	for group in ["bag", "crafting"]:
		var source: Array = data.get(group, [])
		var slots: Array = inventory.get(group)
		if group == "bag" and inventory.is_creative():
			while slots.size() < source.size():
				slots.append({"id": 0, "count": 0})
		for i in range(mini(slots.size(), source.size())):
			if source[i] is Dictionary:
				var entry: Dictionary = {"id": int(source[i].get("id", 0)), "count": int(source[i].get("count", 0))}
				if source[i].has("custom_name"):
					entry["custom_name"] = str(source[i].custom_name)
				if source[i].has("blueprints"):
					entry["blueprints"] = source[i].blueprints.map(func(design: Dictionary): return Blueprint.from_dictionary(design).to_dictionary())
				if source[i].has("notes"):
					entry["notes"] = source[i].notes.duplicate(true)
				if source[i].get("blueprint") is Dictionary:
					entry["blueprint"] = Blueprint.from_dictionary(source[i].blueprint).to_dictionary()
				slots[i] = entry
	var equipment: Array = data.get("equipment", [])
	for i in range(mini(inventory.equipment.size(), equipment.size())):
		inventory.equipment[i] = int(equipment[i])
	var equipped: Array = data.get("equipment_items", [])
	for i in inventory.equipment_items.size():
		inventory.equipment_items[i] = {"id": 0, "count": 0}
		if i < equipped.size() and equipped[i] is Dictionary and int(equipped[i].get("id", 0)) == inventory.equipment[i]:
			inventory.equipment_items[i] = equipped[i].duplicate(true)
			if inventory.equipment_items[i].get("blueprint") is Dictionary:
				inventory.equipment_items[i]["blueprint"] = Blueprint.from_dictionary(inventory.equipment_items[i].blueprint).to_dictionary()
	_emit_changed(inventory)

func save_player(player) -> Dictionary:
	var result := {
		"global_position": _encode(_read_value(player, "global_position", Vector3.ZERO)),
		"rotation": _encode(_read_value(player, "rotation", Vector3.ZERO)),
		"selected_slot": int(_read_value(player, "selected_slot", 0))
	}
	var inventory = _read_value(player, "inventory", null)
	for part in ["rig", "pitch", "visual"]:
		var node = _read_value(player, part, null)
		if node != null:
			result[part + "_rotation"] = _encode(node.rotation)
	result["first_person"] = bool(_read_value(player, "first_person", false))
	if inventory != null:
		result["inventory"] = save_inventory(inventory)
	return result

func apply_player(player, data: Dictionary) -> void:
	for key in ["global_position", "rotation"]:
		var value: Variant = _decode(data.get(key))
		if value is Vector3 and value.is_finite():
			_write_value(player, key, value)
	for part in ["rig", "pitch", "visual"]:
		var node = _read_value(player, part, null)
		var rotation_value: Variant = _decode(data.get(part + "_rotation"))
		if node != null and rotation_value is Vector3 and rotation_value.is_finite():
			node.rotation = rotation_value
	var inventory = _read_value(player, "inventory", null)
	var inventory_data = data.get("inventory", {})
	if inventory != null and inventory_data is Dictionary:
		apply_inventory(inventory, inventory_data)
	var slot := int(data.get("selected_slot", 0))
	if player is Object and player.has_method("select_slot"):
		player.select_slot(slot)
	else:
		_write_value(player, "selected_slot", slot)
	if data.has("first_person"):
		if player is Object and player.has_method("set_first_person"):
			player.set_first_person(bool(data.first_person))
		else:
			_write_value(player, "first_person", bool(data.first_person))

func _read_value(target, property: String, fallback):
	if target == null:
		return fallback
	if target is Dictionary:
		return target.get(property, fallback)
	return target.get(property) if target.get(property) != null else fallback

func _write_value(target, property: String, value) -> void:
	if target == null:
		return
	if target is Dictionary:
		target[property] = value
	else:
		target.set(property, value)

func _emit_changed(target) -> void:
	if target == null or not target is Object:
		return
	for signal_info in target.get_signal_list():
		if signal_info.get("name", "") == "changed":
			target.emit_signal("changed")
			return

func _encode(value):
	if value is Vector3:
		return {"__type": "Vector3", "x": value.x, "y": value.y, "z": value.z}
	if value is Vector2:
		return {"__type": "Vector2", "x": value.x, "y": value.y}
	if value is Dictionary:
		var result := {}
		for key in value:
			result[str(key)] = _encode(value[key])
		return result
	if value is Array:
		var result: Array = []
		for item in value:
			result.append(_encode(item))
		return result
	return value

func _decode(value, field: String = ""):
	if value is Dictionary:
		if value.get("__type", "") == "Vector3" and _number_array([value.get("x"), value.get("y"), value.get("z")], 3):
			return Vector3(float(value.get("x", 0.0)), float(value.get("y", 0.0)), float(value.get("z", 0.0)))
		if value.get("__type", "") == "Vector2" and _number_array([value.get("x"), value.get("y")], 2):
			return Vector2(float(value.get("x", 0.0)), float(value.get("y", 0.0)))
		var result := {}
		for key in value:
			result[key] = _decode(value[key], str(key))
		return result
	if value is Array:
		var result: Array = []
		for item in value:
			result.append(_decode(item, field))
		return result
	# JSON numbers are floats. Restore discrete item/voxel fields while keeping
	# physical centers and other continuous values as floats.
	if value is float and _integer(value) and field in ["id", "count", "grid_size", "mat", "size", "pos", "cells", "schema_version", "source_item_id", "emblem"]:
		return int(value)
	return value

extends RefCounted

signal changed

const ItemCatalog = preload("res://scripts/inventory/ItemCatalog.gd")
const BlueprintEquipment = preload("res://scripts/blueprint/BlueprintEquipment.gd")
const EquipmentSets = preload("res://scripts/content/EquipmentSets.gd")
const BAG_SIZE := 24
const EQUIPMENT_SIZE := 7
const CRAFT_SIZE := 3
const STACK_MAX := 64

var bag: Array[Dictionary] = []
var equipment: Array[int] = []
var equipment_items: Array[Dictionary] = []
var crafting: Array[Dictionary] = []
var mode: String = "creative"
var unlimited: bool = true

func _init(game_mode: String = "creative") -> void:
	set_mode(game_mode)
	for i in BAG_SIZE:
		bag.append(_empty())
	for i in EQUIPMENT_SIZE:
		equipment.append(0)
		equipment_items.append(_empty())
	for i in CRAFT_SIZE:
		crafting.append(_empty())
	if unlimited:
		for i in 8:
			bag[i] = _item(i + 1, -1)
		bag[8] = _item(108, -1)
		bag[9] = _item(109, -1)
		for i in EQUIPMENT_SIZE:
			bag[10 + i] = _item(101 + i, 1)
		# 预置常用多材质工具至背包后段
		var tools_preset := [201, 202, 204, 205, 207, 208, 209]
		for i in range(tools_preset.size()):
			bag[17 + i] = _item(tools_preset[i], 1)

func set_mode(game_mode: String) -> void:
	mode = "survival" if game_mode == "survival" else "creative"
	unlimited = mode == "creative"

func is_creative() -> bool:
	return unlimited

func mode_title() -> String:
	return "创造模式" if unlimited else "生存模式"

func _empty() -> Dictionary:
	return {"id": 0, "count": 0}

func _item(id: int, count: int) -> Dictionary:
	return {"id": id, "count": count}

func get_slot(group: String, index: int) -> Dictionary:
	if group == "bag" and index >= 0 and index < bag.size():
		return bag[index].duplicate(true)
	if group == "equipment" and index >= 0 and index < equipment.size():
		if equipment[index] != 0 and equipment_items[index].get("id", 0) == equipment[index]:
			return equipment_items[index].duplicate(true)
		return _item(equipment[index], 1) if equipment[index] != 0 else _empty()
	if group == "crafting" and index >= 0 and index < crafting.size():
		return crafting[index].duplicate(true)
	if group == "result" and index == 0:
		return _recipe_result().duplicate()
	return _empty()

func can_move(source_group: String, source_index: int, target_group: String, target_index: int) -> bool:
	if source_group == "creative":
		var item_id: int = source_index
		if not is_creative() or item_id <= 0:
			return false
		if target_group == "bag":
			return target_index >= 0 and target_index < bag.size()
		elif target_group == "equipment":
			return ItemCatalog.is_equipment(item_id) and ItemCatalog.equipment_slot(item_id) == target_index
		elif target_group == "crafting":
			return ItemCatalog.is_block(item_id) and target_index >= 0 and target_index < CRAFT_SIZE
		return false
	if not _valid_slot(source_group, source_index) or not _valid_slot(target_group, target_index):
		return false
	if source_group == "result" or target_group == "result":
		if source_group == "result" and target_group == "bag":
			var result: Dictionary = get_slot("result", 0)
			return result.id != 0 and _can_add_to_bag(result.id, result.count, target_index)
		return false
	if source_group == target_group and source_index == target_index:
		return false
	var source := get_slot(source_group, source_index)
	if source["id"] == 0:
		return false
	if target_group == "equipment":
		return source_group == "bag" and ItemCatalog.is_equipment(source["id"]) and ItemCatalog.equipment_slot(source["id"]) == target_index
	if source_group == "equipment":
		return target_group == "bag" and _can_add_to_bag(source.id, 1, target_index)
	if target_group == "crafting":
		var target: Dictionary = crafting[target_index]
		return ItemCatalog.is_block(source.id) and (source_group == "crafting" or target.id == 0 or (target.id == source.id and target.count < STACK_MAX))
	if source_group == "crafting" and target_group == "bag":
		return _can_add_to_bag(source["id"], source["count"], target_index)
	if source_group == "bag" and target_group == "bag":
		return true
	return false

func is_unique_blueprint(slot: Dictionary) -> bool:
	return is_unique_document(slot)

func is_unique_document(slot: Dictionary) -> bool:
	return ItemCatalog.is_document(int(slot.get("id", 0))) and (slot.has("notes") or slot.has("blueprints") or slot.has("custom_name"))

func _stack_limit(id: int) -> int:
	return 1 if ItemCatalog.is_equipment(id) or ItemCatalog.is_tool_item(id) or ItemCatalog.is_weapon(id) else STACK_MAX

func _empty_bag_slot() -> int:
	for i in bag.size():
		if bag[i].id == 0:
			return i
	if is_creative():
		bag.append(_empty())
		return bag.size() - 1
	return -1

func move_item(source_group: String, source_index: int, target_group: String, target_index: int) -> bool:
	if not can_move(source_group, source_index, target_group, target_index):
		return false
	if source_group == "creative":
		var item_id: int = source_index
		if target_group == "bag":
			return give_creative_item(item_id, target_index)
		elif target_group == "equipment":
			if equipment[target_index] != 0:
				bag[_empty_bag_slot()] = get_slot("equipment", target_index)
			equipment[target_index] = item_id
			equipment_items[target_index] = _item(item_id, 1)
			changed.emit()
			return true
		elif target_group == "crafting":
			if crafting[target_index].id != 0:
				bag[_empty_bag_slot()] = crafting[target_index].duplicate(true)
			crafting[target_index] = _item(item_id, 1)
			changed.emit()
			return true
		return false
	if source_group == "result":
		return take_result(target_index)
	var source := get_slot(source_group, source_index)
	if source_group == "bag" and target_group == "equipment":
		var old := get_slot("equipment", target_index)
		equipment[target_index] = source["id"]
		equipment_items[target_index] = source.duplicate(true)
		bag[source_index] = old
		changed.emit()
		return true
	if source_group == "equipment" and target_group == "bag":
		if not _add_to_bag(source["id"], 1, target_index):
			return false
		bag[target_index] = source.duplicate(true)
		equipment[source_index] = 0
		equipment_items[source_index] = _empty()
		changed.emit()
		return true
	if source_group == "bag" and target_group == "crafting":
		if not _add_to_crafting(source["id"], 1, target_index):
			return false
		if not is_creative() and bag[source_index]["count"] != -1:
			bag[source_index]["count"] -= 1
			if bag[source_index]["count"] <= 0:
				bag[source_index] = _empty()
		changed.emit()
		return true
	if source_group == "crafting" and target_group == "bag":
		if target_index >= 0 and bag[target_index]["id"] == source["id"] and bag[target_index]["count"] == -1:
			crafting[source_index] = _empty()
		else:
			if not _add_to_bag(source["id"], source["count"], target_index):
				return false
			crafting[source_index] = _empty()
		changed.emit()
		return true
	if source_group == "crafting" and target_group == "crafting":
		var target := crafting[target_index]
		crafting[target_index] = source
		crafting[source_index] = target
		changed.emit()
		return true
	if source_group == "bag" and target_group == "bag":
		var target_bag := bag[target_index]
		if target_bag["id"] == source["id"] and source["id"] != 0 and _stack_limit(source.id) > 1 and not is_unique_document(target_bag) and not is_unique_document(source) and target_bag["count"] != -1 and source["count"] != -1 and target_bag["count"] + source["count"] <= STACK_MAX:
			bag[target_index]["count"] += source["count"]
			bag[source_index] = _empty()
		else:
			bag[target_index] = source
			bag[source_index] = target_bag
		changed.emit()
		return true
	return false

func equip_from_bag(index: int) -> bool:
	if index < 0 or index >= bag.size() or not ItemCatalog.is_equipment(bag[index]["id"]):
		return false
	return move_item("bag", index, "equipment", ItemCatalog.equipment_slot(bag[index]["id"]))

func unequip(index: int) -> bool:
	if index < 0 or index >= equipment.size() or equipment[index] == 0:
		return false
	var target := _first_bag_capacity(equipment[index], 1)
	return target >= 0 and move_item("equipment", index, "bag", target)

func equip_creative_set(ids: Array[int]) -> bool:
	if not is_creative() or ids.size() != EQUIPMENT_SIZE:
		return false
	for index in EQUIPMENT_SIZE:
		if ItemCatalog.equipment_slot(ids[index]) != index:
			return false
	for index in EQUIPMENT_SIZE:
		if equipment[index] != 0:
			bag[_empty_bag_slot()] = get_slot("equipment", index)
		equipment[index] = ids[index]
		equipment_items[index] = _item(ids[index], 1)
	changed.emit()
	return true

## 创造模式：获取指定内置物品放入背包或装备栏
func give_creative_item(item_id: int, target_slot: int = -1) -> bool:
	if not is_creative() or item_id <= 0 or target_slot < -1 or target_slot >= bag.size():
		return false
	var count: int = -1 if (unlimited and (ItemCatalog.is_block(item_id) or ItemCatalog.is_document(item_id))) else 1
	if target_slot < 0:
		target_slot = _empty_bag_slot()
	elif bag[target_slot].id != 0:
		bag[_empty_bag_slot()] = bag[target_slot].duplicate(true)
	bag[target_slot] = _item(item_id, count)
	changed.emit()
	return true

func take_result(target_index: int = -1) -> bool:
	var result := _recipe_result()
	if result["id"] == 0:
		return false
	var target := target_index
	if target < 0:
		target = _first_bag_capacity(result["id"], result["count"])
	if target < 0 or not _can_add_to_bag(result["id"], result["count"], target):
		return false
	for i in (0 if is_creative() else crafting.size()):
		var slot: Dictionary = crafting[i]
		if slot["id"] != 0:
			var left: int = slot["count"] - 1
			if left <= 0:
				crafting[i] = _empty()
			else:
				crafting[i] = _item(slot["id"], left)
	if not _add_to_bag(result["id"], result["count"], target):
		return false
	changed.emit()
	return true

func recipe_text() -> String:
	var result := _recipe_result()
	if result["id"] == 0:
		return "拖入材料查看配方，点击或拖动右侧成品领取"
	return "合成：" + ItemCatalog.title(result["id"]) + " ×" + str(result["count"])

func consume_slot(index: int) -> bool:
	if index < 0 or index >= bag.size() or bag[index].id == 0:
		return false
	if is_unique_document(bag[index]):
		bag[index] = _empty()
		changed.emit()
		return true
	if is_creative() or bag[index].count == -1:
		return true
	bag[index].count -= 1
	if bag[index].count <= 0:
		bag[index] = _empty()
	changed.emit()
	return true

func can_add_item(id: int, amount: int = 1) -> bool:
	if id <= 0 or amount <= 0:
		return false
	if is_creative():
		return true
	var capacity := 0
	var maximum := _stack_limit(id)
	for slot in bag:
		if slot.id == 0:
			capacity += maximum
		elif slot.id == id and not is_unique_document(slot) and maximum > 1:
			if slot.count == -1:
				return true
			capacity += maxi(0, maximum - int(slot.count))
	return capacity >= amount

func add_item(id: int, amount: int = 1) -> bool:
	if not can_add_item(id, amount):
		return false
	var maximum := _stack_limit(id)
	for slot in bag:
		if slot.id == id and slot.count == -1 and not is_unique_document(slot) and maximum > 1:
			return true
	var remaining := amount
	while remaining > 0:
		var target := _first_bag_capacity(id, 1)
		if target < 0:
			return false
		var room: int = maximum if bag[target].id == 0 else maximum - int(bag[target].count)
		var added := mini(remaining, room)
		_add_to_bag(id, added, target)
		remaining -= added
	changed.emit()
	return true

func _valid_slot(group: String, index: int) -> bool:
	return (group == "bag" and index >= 0 and index < bag.size()) or (group == "equipment" and index >= 0 and index < EQUIPMENT_SIZE) or (group == "crafting" and index >= 0 and index < CRAFT_SIZE) or (group == "result" and index == 0)

func _add_to_crafting(id: int, amount: int, index: int) -> bool:
	var slot := crafting[index]
	if slot["id"] == 0:
		crafting[index] = _item(id, amount)
		return true
	if slot["id"] == id and slot["count"] + amount <= STACK_MAX:
		slot["count"] += amount
		return true
	return false

func _can_add_to_bag(id: int, amount: int, index: int) -> bool:
	if index < 0 or index >= bag.size() or id <= 0 or amount <= 0 or amount > _stack_limit(id):
		return false
	var slot := bag[index]
	if slot["id"] == 0:
		return true
	if is_unique_blueprint(slot):
		return false
	var maximum := 1 if (ItemCatalog.is_equipment(id) or ItemCatalog.is_tool_item(id) or ItemCatalog.is_weapon(id)) else STACK_MAX
	if slot["id"] == id and slot["count"] != -1 and slot["count"] + amount <= maximum:
		return true
	if slot["id"] == id and slot["count"] == -1 and not ItemCatalog.is_equipment(id) and not ItemCatalog.is_tool_item(id) and not ItemCatalog.is_weapon(id):
		return true
	return false

func add_blueprint_item(blueprints: Array, custom_name: String = "") -> bool:
	return add_document_item(109, {"blueprints": blueprints, "custom_name": custom_name})

func count_item(id: int) -> int:
	var total := 0
	for slot in bag:
		if int(slot.id) == id:
			if int(slot.count) == -1:
				return -1
			total += int(slot.count)
	return total

func craft_blueprint(blueprint: Dictionary) -> Dictionary:
	var error := BlueprintEquipment.validation_error(blueprint)
	if not error.is_empty():
		return {"ok": false, "message": error}
	var item := BlueprintEquipment.make_item(blueprint)
	var costs := BlueprintEquipment.material_cost(blueprint)
	# Stage the complete transaction so failed capacity/material checks never
	# consume resources or replace a player's existing item.
	var next_bag: Array[Dictionary] = bag.duplicate(true)
	if not is_creative():
		for id in costs:
			var remaining := int(costs[id])
			for slot in next_bag:
				if int(slot.id) != int(id):
					continue
				if int(slot.count) == -1:
					remaining = 0
					break
				var used := mini(remaining, int(slot.count))
				slot.count -= used
				remaining -= used
				if slot.count == 0:
					slot.id = 0
				if remaining == 0:
					break
			if remaining > 0:
				return {"ok": false, "message": "材料不足：" + ItemCatalog.title(int(id)) + "，需要 " + str(costs[id]) + " 份"}
	var target := -1
	for i in next_bag.size():
		if int(next_bag[i].id) == 0:
			target = i
			break
	if target < 0:
		if not is_creative():
			return {"ok": false, "message": "背包已满，请空出一格后再制作"}
		target = next_bag.size()
		next_bag.append(_empty())
	next_bag[target] = item
	bag = next_bag
	changed.emit()
	return {"ok": true, "index": target, "item": item.duplicate(true), "message": "已制作：" + str(item.custom_name) + " · B 打开背包，右键或双击穿戴"}

func add_document_item(id: int, data: Dictionary) -> bool:
	if not ItemCatalog.is_document(id):
		return false
	var target := _empty_bag_slot()
	if target < 0:
		return false
	var document := _item(id, 1)
	for key in ["notes", "blueprints", "custom_name"]:
		if data.has(key):
			document[key] = data[key]
	if not document.has("notes") and not document.has("blueprints"):
		document["notes" if id == 108 else "blueprints"] = []
	bag[target] = document.duplicate(true)
	changed.emit()
	return true

func _add_to_bag(id: int, amount: int, index: int) -> bool:
	if not _can_add_to_bag(id, amount, index):
		return false
	if bag[index].id == id and bag[index].count == -1:
		return true
	if bag[index]["id"] == id and bag[index]["count"] != -1:
		bag[index]["count"] += amount
	else:
		bag[index] = _item(id, amount)
	return true

func _first_bag_capacity(id: int, amount: int) -> int:
	for i in bag.size():
		if bag[i].id == id and bag[i].count != -1 and _can_add_to_bag(id, amount, i):
			return i
	for i in bag.size():
		if bag[i].id == 0:
			return i
	for i in bag.size():
		if _can_add_to_bag(id, amount, i):
			return i
	return _empty_bag_slot() if is_creative() and amount > 0 and amount <= _stack_limit(id) else -1

func clear_crafting() -> bool:
	var staged = get_script().new(mode)
	staged.bag = bag.duplicate(true)
	staged.crafting = crafting.duplicate(true)
	for i in CRAFT_SIZE:
		var item: Dictionary = staged.crafting[i]
		if item.id == 0:
			continue
		if not staged.add_item(item.id, item.count):
			return false
		staged.crafting[i] = _empty()
	bag = staged.bag
	crafting = staged.crafting
	changed.emit()
	return true

func prepare_recipe(key: String) -> bool:
	if not recipe_definitions().has(key):
		return false
	var staged = get_script().new(mode)
	staged.bag = bag.duplicate(true)
	staged.crafting = crafting.duplicate(true)
	if not staged.clear_crafting():
		return false
	var ingredients := key.split(",")
	for i in ingredients.size():
		var id := int(ingredients[i])
		if not is_creative():
			var source := -1
			for slot in staged.bag.size():
				if staged.bag[slot].id == id and staged.bag[slot].count != 0:
					source = slot
					break
			if source < 0:
				return false
			staged.consume_slot(source)
		staged.crafting[i] = _item(id, 1)
	bag = staged.bag
	crafting = staged.crafting
	changed.emit()
	return true

func sort_storage() -> void:
	var items: Array[Dictionary] = []
	for i in range(8, bag.size()):
		var item: Dictionary = bag[i].duplicate(true)
		if item.id == 0:
			continue
		if _stack_limit(item.id) > 1 and not is_unique_document(item) and item.count > 0:
			for existing in items:
				if existing.id == item.id and existing.count > 0 and not is_unique_document(existing):
					var merged := mini(int(item.count), STACK_MAX - int(existing.count))
					existing.count += merged
					item.count -= merged
		if item.count != 0:
			items.append(item)
	items.sort_custom(func(a: Dictionary, b: Dictionary): return int(a.id) < int(b.id))
	for i in range(8, bag.size()):
		bag[i] = items[i - 8] if i - 8 < items.size() else _empty()
	changed.emit()

func quick_move(group: String, index: int) -> bool:
	if group == "equipment":
		return unequip(index)
	if group == "result":
		return take_result()
	if group == "crafting":
		var item := get_slot(group, index)
		var target := _first_bag_capacity(item.id, item.count) if item.id != 0 else -1
		return target >= 0 and move_item(group, index, "bag", target)
	if group == "bag" and index >= 0 and index < bag.size() and bag[index].id != 0:
		if ItemCatalog.is_equipment(bag[index].id):
			return equip_from_bag(index)
		var start := 8 if index < 8 else 0
		var end := bag.size() if index < 8 else 8
		for target in range(start, end):
			if bag[target].id == 0:
				return move_item("bag", index, "bag", target)
	return false

func _recipe_result() -> Dictionary:
	var ids: Array[int] = []
	for slot in crafting:
		if slot["id"] != 0:
			ids.append(slot["id"])
	ids.sort()
	var recipes := recipe_definitions()
	var keys := PackedStringArray()
	for id in ids:
		keys.append(str(id))
	var found: Dictionary = recipes.get(",".join(keys), {})
	return _item(found["id"], found["count"]) if not found.is_empty() else _empty()

static func recipe_definitions() -> Dictionary:
	var recipes := {
		"3": {"id": 7, "count": 4, "name": "原木"},
		"5,6": {"id": 8, "count": 4, "name": "石头 + 沙子"},
		"3,5,5": {"id": 101, "count": 1, "name": "石头 + 石头 + 原木"},
		"5,5,7": {"id": 102, "count": 1, "name": "石头 + 木板 + 石头"},
		"5,7,7": {"id": 103, "count": 1, "name": "石头 + 木板 + 木板"},
		"3,5,6": {"id": 104, "count": 1, "name": "石头 + 沙子 + 原木"},
		"3,4,5": {"id": 105, "count": 1, "name": "原木 + 树叶 + 石头"},
		"3,4,4": {"id": 106, "count": 1, "name": "树叶 + 树叶 + 原木"},
		"3,3,7": {"id": 107, "count": 1, "name": "原木 + 原木 + 木板"},
		"3,4,7": {"id": 108, "count": 1, "name": "原木 + 树叶 + 木板"},
		"4,6,7": {"id": 109, "count": 1, "name": "树叶 + 沙子 + 木板"},
		# 基础建材与加工方块
		"5,5": {"id": 14, "count": 4, "name": "石头 ×2 → 石砖 ×4"},
		"6,6": {"id": 17, "count": 2, "name": "沙子 ×2 → 砂岩 ×2"},
		"6,6,6": {"id": 16, "count": 3, "name": "沙子 ×3 → 纯净玻璃 ×3"},
		"9,9": {"id": 12, "count": 1, "name": "高纯生铁 ×2 → 生铁块"},
		"3,7,7": {"id": 20, "count": 1, "name": "原木 + 木板 ×2 → 工作台"},
		
		# 基础工具：木制系列 (ID 201 ~ 203)
		"7,7,7": {"id": 201, "count": 1, "name": "木板 ×3 → 木镐"},
		"3,7": {"id": 202, "count": 1, "name": "原木 + 木板 → 木斧"},
		"7,7": {"id": 203, "count": 1, "name": "木板 ×2 → 木锹"},
		# 基础工具：石制系列 (ID 204 ~ 206，支持素雅岩石与鹅卵石)
		"5,5,5": {"id": 204, "count": 1, "name": "石头 ×3 → 石镐"},
		"3,5": {"id": 205, "count": 1, "name": "原木 + 石头 → 石斧"},
		"5,7": {"id": 206, "count": 1, "name": "石头 + 木板 → 石锹"},
		"13,13,13": {"id": 204, "count": 1, "name": "鹅卵石 ×3 → 石镐"},
		"3,13": {"id": 205, "count": 1, "name": "原木 + 鹅卵石 → 石斧"},
		"7,13": {"id": 206, "count": 1, "name": "木板 + 鹅卵石 → 石锹"},
		# 基础工具：铁制系列 (ID 207 ~ 209，支持高纯生铁矿与历史陶瓦)
		"9,9,9": {"id": 207, "count": 1, "name": "高纯生铁 ×3 → 铁镐"},
		"3,9": {"id": 208, "count": 1, "name": "原木 + 高纯生铁 → 铁斧"},
		"7,9": {"id": 209, "count": 1, "name": "木板 + 高纯生铁 → 铁锹"},
		"8,8,8": {"id": 207, "count": 1, "name": "陶瓦 ×3 → 铁镐"},
		"3,8": {"id": 208, "count": 1, "name": "原木 + 陶瓦 → 铁斧"},
		"7,8": {"id": 209, "count": 1, "name": "木板 + 陶瓦 → 铁锹"},
		
		# 多元化特色近战武器 (ID 301 ~ 305，涵盖木材、原石、生铁、金矿、黑曜石)
		"3,3": {"id": 301, "count": 1, "name": "原木 ×2 → 原木轻短剑"},
		"3,13,13": {"id": 302, "count": 1, "name": "原木 + 鹅卵石 ×2 → 砥石破山斧"},
		"3,5,7": {"id": 302, "count": 1, "name": "原木 + 石头 + 木板 → 砥石破山斧"},
		"3,9,9": {"id": 303, "count": 1, "name": "原木 + 高纯生铁 ×2 → 精炼铁长剑"},
		"3,11": {"id": 304, "count": 1, "name": "原木 + 金矿石 → 灵蕴金晶细剑"},
		"7,11,11": {"id": 304, "count": 1, "name": "木板 + 金矿石 ×2 → 灵蕴金晶细剑"},
		"3,19": {"id": 305, "count": 1, "name": "原木 + 黑曜石 → 暗渊黑曜石巨剑"},
		"3,19,19": {"id": 305, "count": 1, "name": "原木 + 黑曜石 ×2 → 暗渊黑曜石巨剑"}
	}
	for key in EquipmentSets.RECIPES:
		recipes[key] = {"id": EquipmentSets.RECIPES[key], "count": 1, "name": EquipmentSets.title(EquipmentSets.RECIPES[key])}
	return recipes

extends RefCounted

const Items = preload("res://scripts/inventory/ItemCatalog.gd")
const VillageItems = preload("res://scripts/content/VillageItems.gd")
const Blueprint = preload("res://scripts/blueprint/BlueprintData.gd")
const Design = preload("res://scripts/blueprint/BlueprintEquipment.gd")

static func integer(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) == floorf(float(value))

static func number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))

static func vector(value: Variant) -> bool:
	return value is Array and value.size() == 3 and value.all(number) and Vector3(value[0], value[1], value[2]).is_finite()

static func item_error(item: Variant) -> String:
	if not item is Dictionary or not integer(item.get("id")) or not integer(item.get("count")): return "物品记录格式无效"
	var id := int(item.id)
	if not Items.is_valid_item(id) or item.count < 1 or item.count > 64: return "物品类别或数量无效"
	if (Items.is_equipment(id) or Items.is_tool_item(id) or Items.is_weapon(id) or Items.is_facility(id) or id in [609, 610]) and item.count != 1: return "独立成品不能堆叠"
	if item.has("custom_name") and not item.custom_name is String: return "物品名称无效"
	if item.has("blueprint"):
		if not item.blueprint is Dictionary or not Blueprint.validation_error(item.blueprint).is_empty() or not Design.is_custom_item(item): return "自定义成品蓝图无效"
		if not Items.is_equipment(id) and not Design.validation_error(item.blueprint).is_empty(): return "自定义成品外形无效"
	for field in ["notes", "blueprints"]:
		if not item.get(field, []) is Array: return "纸笔内容无效"
	for note in item.get("notes", []):
		if not note is String: return "笔记内容无效"
	for data in item.get("blueprints", []):
		if not data is Dictionary or not Blueprint.validation_error(data).is_empty(): return "图纸内容无效"
	return ""

static func validation_error(data: Variant) -> String:
	if not data is Dictionary: return "村庄设施存档格式无效"
	if not number(data.get("clock", 0)) or data.get("clock", 0) < 0: return "设施时间无效"
	if not integer(data.get("next_id", 1)) or data.get("next_id", 1) < 1: return "设施编号无效"
	if not data.get("objects", []) is Array: return "设施列表无效"
	var used := {}
	for record in data.get("objects", []):
		if not record is Dictionary or not record.get("key") is String or record.key.is_empty() or used.has(record.key): return "设施标识无效或重复"
		used[record.key] = true
		if not vector(record.get("position")) or not vector(record.get("support")) or not record.support.all(integer): return "设施位置无效"
		if record.support[1] < 1 or record.support[1] >= 24: return "设施超出建筑高度"
		if record.get("kind", "") == "resident":
			if record.get("role", "") not in ["farmer", "smith", "trader", "keeper"]: return "村民职业无效"
			if not record.get("route", []) is Array or record.get("route", []).size() > 128 or not record.get("route", []).all(vector): return "村民路线无效"
			if not record.get("stock", {}) is Dictionary: return "交易库存无效"
			for value in record.get("stock", {}).values():
				if not integer(value) or value < 0 or value > 8: return "交易库存数量无效"
			for key in record.get("stock", {}):
				if not str(key).is_valid_int() or int(key) < 0 or int(key) > 2: return "交易条目无效"
			if not number(record.get("restock_at", 0)) or record.get("restock_at", 0) < 0: return "补货时间无效"
			if not integer(record.get("patrol_index", 0)) or record.get("patrol_index", 0) < 0 or record.get("patrol_index", 0) >= maxi(1, record.get("route", []).size()): return "村民行动位置无效"
			if not integer(record.get("patrol_direction", 1)) or absi(int(record.get("patrol_direction", 1))) != 1: return "村民行动方向无效"
			if not number(record.get("patrol_rest", 0)) or record.get("patrol_rest", 0) < 0 or record.get("patrol_rest", 0) > 30: return "村民休息时间无效"
			continue
		if not item_error(record.get("item")).is_empty(): return "设施物品记录无效"
		if VillageItems.KINDS.get(int(record.item.id), "") != record.get("kind", ""): return "设施功能类别无效"
		var size_limit := 3.00001 if record.kind == "door" else 2.6
		if record.has("size") and (not vector(record.size) or record.size.any(func(value): return value < 0.005 or value > size_limit)): return "设施尺寸无效"
		for field in ["removed", "lit", "watered", "opened"]:
			if record.has(field) and not record[field] is bool: return "设施开关状态无效"
		if not integer(record.get("turns", 0)) or record.get("turns", 0) < 0 or record.get("turns", 0) > 3: return "设施朝向无效"
		for field in ["storage", "output"]:
			if not record.get(field, []) is Array or record.get(field, []).size() > (8 if field == "output" else (12 if record.kind == "barrel" else 24)): return "设施容器容量无效"
			for item in record.get(field, []):
				if not item_error(item).is_empty(): return "设施容器中包含无效物品"
		if not record.get("input", {}) is Dictionary: return "加工原料无效"
		var total := 0
		for id in record.get("input", {}):
			var amount: Variant = record.input[id]
			if not str(id).is_valid_int() or not VillageItems.SMELTING.has(int(id)) or not integer(amount) or amount < 1: return "加工原料无效"
			total += int(amount)
		if total > 64 or not integer(record.get("fuel", 0)) or record.get("fuel", 0) < 0 or record.get("fuel", 0) > 128: return "加工容量或燃料无效"
		if not record.get("input_order", []) is Array: return "加工顺序无效"
		var ordered := {}
		for id in record.get("input_order", []):
			if not id is String or not record.get("input", {}).has(id) or ordered.has(id): return "加工顺序无效"
			ordered[id] = true
		if not record.get("current", {}) is Dictionary: return "加工任务无效"
		var current: Dictionary = record.get("current", {})
		if not current.is_empty():
			if not item_error({"id": current.get("id"), "count": current.get("count")}).is_empty() or not number(current.get("due")) or current.due < 0: return "加工任务无效"
		if not integer(record.get("growth_stage", 0)) or record.get("growth_stage", 0) < 0 or record.get("growth_stage", 0) > 3: return "作物生长阶段无效"
		if not number(record.get("planted_at", -1)) or record.get("planted_at", -1) < -1: return "作物播种时间无效"
	return ""

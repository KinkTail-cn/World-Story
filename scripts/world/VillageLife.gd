extends Node

signal changed
const Items = preload("res://scripts/content/VillageItems.gd")
const Catalog = preload("res://scripts/inventory/ItemCatalog.gd")
const Inventory = preload("res://scripts/inventory/Inventory.gd")
const Houses = preload("res://scripts/world/HouseTemplates.gd")
const Generator = preload("res://scripts/world/VillageGenerator.gd")
const DoorGeometry = preload("res://scripts/world/DoorGeometry.gd")
var world: Node3D
var clock: float = 0.0
var next_id: int = 1
var records: Dictionary = {}
var nodes: Dictionary = {}
var edits: Dictionary = {}
var known_villages: Dictionary = {}
var support_index: Dictionary = {}
var occupied_index: Dictionary = {}
var timer: float = 0.0
var last_message: String = ""
var active_interaction: String = ""
var interacting_actor: Node3D
var door_release: Dictionary = {}

func _process(delta: float) -> void:
	if world.is_loading or get_tree().paused: return
	clock += delta
	for key in door_release.keys():
		if clock >= float(door_release[key]):
			var result := set_door_open(str(key), false)
			if result.ok: door_release.erase(key)
			else: door_release[key] = clock + 0.6
	timer -= delta
	if timer <= 0:
		timer = 0.5
		refresh()

func refresh() -> void:
	if not is_inside_tree() or world._active_chunks.is_empty(): return
	if world.world_type != "island" and world.village_generation_version > 0:
		for plan in world.villages._regions.values().duplicate():
			if not plan.is_empty() and _near_plan(plan): _ensure_village(plan)
	for key in records.keys():
		var record: Dictionary = records[key]
		if record.get("removed", false): continue
		var coord: Vector2i = world._chunk_coord(Vector3i(record.support[0], record.support[1], record.support[2]))
		var active: bool = world._active_chunks.has(coord)
		if not active:
			if nodes.has(key):
				nodes[key].queue_free()
				nodes.erase(key)
			continue
		_simulate(record)
		if not nodes.has(key):
			if record.kind == "resident":
				var resident = preload("res://scripts/world/VillageResident.gd").new()
				resident.record = record
				resident.world = world
				add_child(resident)
				resident.global_position = Vector3(record.position[0], record.position[1], record.position[2])
				nodes[key] = resident
			else:
				var object: Node3D
				if record.kind == "door": object = preload("res://scripts/world/DoorObject.gd").new()
				else: object = preload("res://scripts/world/FacilityObject.gd").new()
				object.record = record
				add_child(object)
				object.global_position = Vector3(record.position[0], record.position[1], record.position[2])
				object.rotation.y = int(record.get("turns", 0)) * PI * 0.5
				nodes[key] = object
		elif record.kind != "resident":
			nodes[key].update_state()
	# Keep generated defaults only while their settlement is visible. Edited
	# state remains indexed and saved independently for future visits.
	for prefix in known_villages.keys():
		var plan: Dictionary = known_villages[prefix]
		if _near_plan(plan): continue
		known_villages.erase(prefix)
		for key in records.keys():
			if str(key).begins_with(prefix) and not edits.has(key):
				_index_support(records[key], true)
				if nodes.has(key):
					nodes[key].queue_free()
					nodes.erase(key)
				records.erase(key)

func _near_plan(plan: Dictionary) -> bool:
	var point: Vector2i = plan.centre
	return world._active_chunks.has(world._chunk_coord(Vector3i(point.x, plan.floor_y, point.y)))

func _record(key: String, id: int, support: Vector3i, turns: int = 0) -> Dictionary:
	var pos := Vector3(support) + Vector3(0.5, 1.0, 0.5)
	if id == 503: pos += Basis(Vector3.UP, turns * PI * 0.5) * Vector3(0, 0, 0.5)
	if id == 510: pos += Basis(Vector3.UP, turns * PI * 0.5) * Vector3(0.5, 0, 0)
	return {"key": key, "kind": Items.KINDS.get(id, "workbench"), "item": {"id": id, "count": 1}, "support": [support.x, support.y, support.z], "position": [pos.x, pos.y, pos.z], "turns": turns, "storage": [], "input": {}, "input_order": [], "output": [], "fuel": 0, "lit": true, "planted_at": -1.0, "growth_stage": 0, "watered": false}

func _ensure_village(plan: Dictionary) -> void:
	var prefix := "v:%d:%d:" % [plan.region.x, plan.region.y]
	if known_villages.has(prefix): return
	known_villages[prefix] = plan
	for index in plan.houses.size():
		var building: Dictionary = plan.houses[index]
		var source := Houses.model(building.style, building.variation)
		for door_index in source.doors.size():
			var door_cell: Vector3i = source.doors[door_index] + Vector3i.DOWN
			var support: Vector3i = building.origin + Houses.rotate_cell(door_cell, building.turns, source.size)
			var door_key := prefix + "door:%d:%d" % [index, door_index]
			var door := _record(door_key, 510, support, posmod(-int(building.turns), 4))
			door["opened"] = false
			_add_generated(door)
		var fixtures := []
		if building.role == "workshop":
			fixtures = [[509, Vector3i(2, 0, 4)], [502, Vector3i(source.size.x - 3, 0, 4)], [501, Vector3i(2, 0, 5)]]
		elif building.role == "storehouse":
			fixtures = [[501, Vector3i(3, 0, 5)], [506, Vector3i(source.size.x - 3, 0, 5)]]
		else:
			fixtures = [[503, Vector3i(2, 0, 4)], [504, Vector3i(source.size.x - 3, 0, 4)]]
		if index % 3 == 0: fixtures.append([505, Vector3i(2, 0, 6)])
		for slot in fixtures.size():
			var fixture: Array = fixtures[slot]
			var cell: Vector3i = building.origin + Houses.rotate_cell(fixture[1], building.turns, source.size)
			var key := prefix + "house:%d:%d" % [index, slot]
			# Building-grid quarter turns and Node3D yaw use opposite signs.
			var turns: int = -int(building.turns)
			if fixture[0] == 504: turns += 1
			elif fixture[0] in [501, 502, 506, 509]: turns += 2
			_add_generated(_record(key, fixture[0], cell, posmod(turns, 4)))
	for index in plan.greens.size():
		if index % 2 == 1: continue
		var yard: Rect2i = plan.greens[index]
		for slot in range(4):
			var cell := Vector3i(yard.position.x + 2 + slot % 2 * 3, plan.floor_y, yard.position.y + 2 + slot / 2 * 3)
			var record := _record(prefix + "crop:%d:%d" % [index, slot], 507, cell)
			record.growth_stage = 3
			record.planted_at = 0.0
			_add_generated(record)
	var centre: Vector2i = plan.centre
	_add_generated(_record(prefix + "well", 508, Vector3i(centre.x - 3, plan.floor_y, centre.y)))
	for index in 4:
		var point: Vector2i = plan.waypoints[index]
		var key := prefix + "resident:" + str(index)
		if not records.has(key):
			var position := Vector3(point.x + 0.5, plan.floor_y + 1.02, point.y + 0.5)
			var record := {"key": key, "kind": "resident", "role": ["farmer", "smith", "trader", "keeper"][index], "support": [point.x, plan.floor_y, point.y], "position": [position.x, position.y, position.z], "stock": {}, "restock_at": clock + 300.0, "route": _resident_route(plan, index)}
			records[key] = edits.get(key, record)

func _resident_route(plan: Dictionary, index: int) -> Array:
	var start: Vector2i = plan.waypoints[index]
	var network := {}
	for point in plan.road_centres: network[point] = true
	var queue: Array[Vector2i] = [start]
	var visited := {start: true}
	var route: Array = []
	var current := start
	for step in range(18):
		route.append([current.x + 0.5, plan.floor_y + 1.02, current.y + 0.5])
		var found := false
		for direction in [Vector2i.LEFT, Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN]:
			var next: Vector2i = current + direction
			if network.has(next) and not visited.has(next):
				visited[next] = true
				current = next
				found = true
				break
		if not found: break
	return route

func _add_generated(record: Dictionary) -> void:
	var key: String = record.key
	if records.has(key): return
	if edits.has(key):
		records[key] = edits[key]
		_index_support(records[key])
		return
	var cell := Vector3i(record.support[0], record.support[1], record.support[2])
	if world.get_block(cell) == 0 or world.get_block(cell + Vector3i.UP) != 0: return
	var box := bounds_for(record)
	for z in range(floori(box.position.z), ceili(box.end.z)):
		for x in range(floori(box.position.x), ceili(box.end.x)):
			if world.get_block(Vector3i(x, cell.y, z)) == 0: return
			for y in range(floori(box.position.y), ceili(box.end.y)):
				if world.get_block(Vector3i(x, y, z)) != 0 or not occupying(Vector3i(x, y, z)).is_empty(): return
	records[key] = record
	_index_support(record)

func place(item: Dictionary, cell: Vector3i, player_box: AABB, turns: int = 0) -> Dictionary:
	var id := int(item.get("id", 0))
	if not Catalog.is_facility(id): return fail("该物品不能作为设施放置")
	while records.has("p:" + str(next_id)): next_id += 1
	var record := _record("p:" + str(next_id), id, cell, posmod(turns, 4))
	if id == 510: record["opened"] = false
	record.item = item.duplicate(true)
	record.item.count = 1
	if preload("res://scripts/blueprint/BlueprintEquipment.gd").is_custom_item(item):
		var size := preload("res://scripts/blueprint/BlueprintEquipment.gd").item_bounds(item.blueprint).size
		record["size"] = [size.x, size.y, size.z]
	var box := bounds_for(record)
	if box.end.y > 24.0: return fail("设施超出当前建筑高度")
	if box.intersects(player_box): return fail("设施离人物太近，请退后放置")
	for x in range(floori(box.position.x), ceili(box.end.x)):
		for z in range(floori(box.position.z), ceili(box.end.z)):
			if world.get_block(Vector3i(x, cell.y, z)) == 0: return fail("请放在足够大的平整地面上")
			for y in range(cell.y + 1, ceili(box.end.y)):
				if world.get_block(Vector3i(x, y, z)) != 0: return fail("这里没有足够的设施空间")
	for other in records.values():
		if other.get("removed", false) or other.kind == "resident": continue
		if bounds_for(other).intersects(box): return fail("这里已经摆放了其他设施")
	next_id += 1
	records[record.key] = record
	_index_support(record)
	mark(record)
	refresh()
	return {"ok": true, "record": record, "message": "已放置"}

func bounds_for(record: Dictionary) -> AABB:
	if record.kind == "door": return DoorGeometry.reserved_bounds(record)
	var pos := Vector3(record.position[0], record.position[1], record.position[2])
	var size: Vector3 = Items.size(int(record.item.id))
	if record.get("size") is Array: size = Vector3(record.size[0], record.size[1], record.size[2])
	if int(record.get("turns", 0)) % 2: size = Vector3(size.z, size.y, size.x)
	return AABB(pos + Vector3(-size.x * 0.5, 0, -size.z * 0.5), size)

func supporting(cell: Vector3i) -> String:
	return str(support_index.get(cell, ""))

func occupying(cell: Vector3i) -> String:
	return str(occupied_index.get(cell, ""))

func _index_support(record: Dictionary, remove: bool = false) -> void:
	if record.get("removed", false) and not remove or record.kind == "resident": return
	var box := bounds_for(record)
	var support_box := DoorGeometry.threshold_bounds(record) if record.kind == "door" else box
	for z in range(floori(support_box.position.z + 0.001), ceili(support_box.end.z - 0.001)):
		for x in range(floori(support_box.position.x + 0.001), ceili(support_box.end.x - 0.001)):
			var cell := Vector3i(x, record.support[1], z)
			if remove:
				if support_index.get(cell) == record.key: support_index.erase(cell)
			else: support_index[cell] = record.key
	for z in range(floori(box.position.z + 0.001), ceili(box.end.z - 0.001)):
		for x in range(floori(box.position.x + 0.001), ceili(box.end.x - 0.001)):
			for y in range(floori(box.position.y + 0.001), ceili(box.end.y - 0.001)):
				var occupied := Vector3i(x, y, z)
				if remove:
					if occupied_index.get(occupied) == record.key: occupied_index.erase(occupied)
				else: occupied_index[occupied] = record.key

func pickup(key: String, inventory: RefCounted) -> Dictionary:
	if not records.has(key): return fail("设施不存在")
	var record: Dictionary = records[key]
	if record.kind == "resident": return fail("请使用交互操作与村民交易")
	_simulate(record)
	if not record.storage.is_empty() or not record.input.is_empty() or not record.output.is_empty() or not record.get("current", {}).is_empty():
		return fail("请先取出设施内的物品")
	if record.kind == "crop" and record.growth_stage > 0: return fail("请先收获或清理种植箱")
	if not inventory.add_snapshot(record.item): return fail("背包已满，设施保留在原处")
	record["removed"] = true
	_index_support(record, true)
	mark(record)
	if nodes.has(key):
		nodes[key].queue_free()
		nodes.erase(key)
	door_release.erase(key)
	return {"ok": true, "message": "设施已回收"}

func set_door_open(key: String, opened: bool) -> Dictionary:
	var record: Dictionary = records.get(key, {})
	if record.is_empty() or record.kind != "door" or record.get("removed", false): return fail("门不存在")
	if bool(record.get("opened", false)) == opened: return {"ok": true, "message": ""}
	var object: Node3D = nodes.get(key)
	if object != null and object.is_moving(): return fail("门扇正在移动")
	var query := PhysicsShapeQueryParameters3D.new()
	var shape := BoxShape3D.new()
	# Ignore contact within the physics solver's tolerance. A person resting
	# against the outside is safe; a body inside the opening arc still blocks it.
	shape.size = DoorGeometry.LEAF_SIZE - Vector3(0.006, 0.004, 0.006)
	query.shape = shape
	query.collision_mask = 3
	query.margin = 0.0
	if object != null: query.exclude = object.excluded_rids()
	var root := DoorGeometry.transform_for(record)
	for step in range(1, 13):
		var amount := float(step) / 12.0
		if not opened: amount = 1.0 - amount
		for side in [-1, 1]:
			query.transform = root * DoorGeometry.leaf_transform(side, amount)
			if not world.get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty():
				return fail("门边有人或物品挡住，请留出开关空间")
	record["opened"] = opened
	mark(record)
	if object != null: object.update_state()
	return {"ok": true, "message": "门已打开" if opened else "门已关上"}

func open_for_resident(position: Vector3, movement: Vector3) -> void:
	if movement.length_squared() < 0.01: return
	var ahead := position + movement.normalized() * 0.75 + Vector3.UP
	var key := occupying(Vector3i(ahead.floor()))
	var record: Dictionary = records.get(key, {})
	if record.get("kind", "") != "door": return
	if set_door_open(key, true).ok:
		door_release[key] = clock + 1.8

func mark(record: Dictionary) -> void:
	edits[record.key] = record
	changed.emit()

func fail(text: String) -> Dictionary:
	last_message = text
	return {"ok": false, "message": text}

func deposit(key: String, inventory: RefCounted, index: int) -> Dictionary:
	var record: Dictionary = records.get(key, {})
	if record.is_empty() or record.kind not in ["chest", "barrel"]: return fail("不是储物设施")
	var item: Dictionary = inventory.get_slot("bag", index)
	if item.id == 0: return fail("请选择背包中的物品")
	var unlimited := int(item.count) == -1
	if unlimited: item.count = 64
	var staged: Array = record.storage.duplicate(true)
	var remaining := int(item.count)
	if not inventory.is_unique_document(item) and inventory._stack_limit(item.id) > 1:
		for slot in staged:
			if slot.id == item.id and not inventory.is_unique_document(slot):
				var moved := mini(remaining, 64 - int(slot.count))
				slot.count += moved
				remaining -= moved
				if remaining == 0: break
	while remaining > 0:
		if staged.size() >= (24 if record.kind == "chest" else 12): return fail("容器已满")
		var moved := mini(remaining, inventory._stack_limit(item.id))
		var added: Dictionary = item.duplicate(true)
		added.count = moved
		staged.append(added)
		remaining -= moved
	if not unlimited: inventory.bag[index] = {"id": 0, "count": 0}
	record.storage = staged
	inventory.changed.emit()
	mark(record)
	return {"ok": true, "message": "已存入容器"}

func withdraw(key: String, inventory: RefCounted, index: int, output: bool = false) -> Dictionary:
	var record: Dictionary = records.get(key, {})
	if record.is_empty(): return fail("设施不存在")
	var slots: Array = record.output if output else record.storage
	if index < 0 or index >= slots.size(): return fail("请选择容器中的物品")
	if not inventory.add_snapshot(slots[index]): return fail("背包空间不足")
	slots.remove_at(index)
	mark(record)
	return {"ok": true, "message": "已放入背包"}

func act(key: String, action: String, inventory: RefCounted, player: Node3D, value: int = 0) -> Dictionary:
	var record: Dictionary = records.get(key, {})
	if record.is_empty() or record.get("removed", false): return fail("设施不存在")
	_simulate(record)
	match action:
		"door":
			return set_door_open(key, not bool(record.get("opened", false)))
		"fuel":
			if record.kind != "furnace" or not Items.FUELS.has(value): return fail("燃料无效")
			if int(record.fuel) + int(Items.FUELS[value]) > 128: return fail("炉内已有足够燃料")
			if not inventory.exchange({value: 1}, []): return fail("背包中缺少燃料")
			record.fuel += int(Items.FUELS[value])
		"smelt":
			if record.kind != "furnace" or not Items.SMELTING.has(value): return fail("原料无效")
			var amount := 0
			for count in record.input.values(): amount += int(count)
			if amount >= 64: return fail("待加工原料已满")
			if not inventory.exchange({value: 1}, []): return fail("背包中缺少该原料")
			if not record.input.has(str(value)): record.get_or_add("input_order", []).append(str(value))
			record.input[str(value)] = int(record.input.get(str(value), 0)) + 1
		"return_input":
			var returns: Array = []
			for id in record.input: returns.append({"id": int(id), "count": int(record.input[id])})
			if not inventory.exchange({}, returns): return fail("背包空间不足")
			record.input = {}
			record.input_order = []
		"plant":
			if record.kind != "crop" or record.growth_stage > 0: return fail("种植箱中已有作物")
			if not inventory.exchange({603: 1}, []): return fail("需要一份小麦种子")
			record.planted_at = clock
			record.growth_stage = 1
			record.watered = false
		"water":
			if record.kind != "crop" or record.growth_stage not in [1, 2] or record.watered: return fail("这株作物暂时不需要浇水")
			if not inventory.exchange({610: 1}, [{"id": 609, "count": 1}]): return fail("需要水桶，并留出空桶的位置")
			record.planted_at = clock - (clock - float(record.planted_at)) * 0.5
			record.watered = true
		"harvest":
			if record.kind != "crop" or record.growth_stage < 3: return fail("小麦尚未成熟")
			if not inventory.exchange({}, [{"id": 604, "count": 3}, {"id": 603, "count": 2}]): return fail("背包空间不足，作物保留在原处")
			record.growth_stage = 0
			record.planted_at = -1.0
			record.watered = false
		"clear_crop":
			if record.kind != "crop" or record.growth_stage == 0: return fail("种植箱是空的")
			if not inventory.exchange({}, [{"id": 603, "count": 1}]): return fail("背包空间不足")
			record.growth_stage = 0
			record.planted_at = -1.0
			record.watered = false
		"draw_water":
			if record.kind != "well": return fail("请在井台取水")
			if not inventory.exchange({609: 1}, [{"id": 610, "count": 1}]): return fail("需要空木桶，并留出水桶的位置")
		"lamp":
			if record.kind != "lamp": return fail("不是照明设施")
			record.lit = not record.lit
		"rest":
			if record.kind != "bed": return fail("不是床铺")
			var centre := Vector3(record.position[0], record.position[1], record.position[2])
			var found := false
			for offset in [Vector3(1.3, 0.02, 0), Vector3(-1.3, 0.02, 0), Vector3(0, 0.02, 1.5), Vector3(0, 0.02, -1.5)]:
				var position: Vector3 = centre + offset
				if world.get_block(Vector3i((position - Vector3.UP * 0.05).floor())) > 0 and player._can_occupy(position, false):
					world.world_spawn = world.to_local(position)
					world.has_custom_spawn = true
					found = true
					break
			if not found: return fail("床铺附近没有可站立的返回位置")
			player.health = 100.0
			player.air = 18.0
			player.vitals_changed.emit(player.health, player.air, false)
		"sit":
			if record.kind != "chair" or not player.sit_at_facility(record): return fail("这里暂时无法坐下")
		"trade":
			if record.kind != "resident": return fail("请与村民交易")
			var offers := trades(str(record.role))
			if value < 0 or value >= offers.size(): return fail("交易无效")
			var bought := int(record.stock.get(str(value), 0))
			if bought >= 8: return fail("这项交易暂时售罄，村民会稍后补货")
			var offer: Dictionary = offers[value]
			if not inventory.exchange(offer.cost, [offer.item]): return fail("材料不足或背包空间不足")
			record.stock[str(value)] = bought + 1
		_:
			return fail("无效操作")
	mark(record)
	_simulate(record)
	if nodes.has(key) and record.kind != "resident": nodes[key].update_state()
	return {"ok": true, "message": {"plant": "已播种", "water": "已浇水，生长速度提升", "harvest": "小麦与种子已收进背包", "rest": "已休息恢复，并设置返回位置", "trade": "交易完成"}.get(action, "操作完成")}

static func trades(role: String) -> Array[Dictionary]:
	match role:
		"farmer": return [{"cost": {4: 1}, "item": {"id": 603, "count": 3}}, {"cost": {604: 4}, "item": {"id": 605, "count": 2}}, {"cost": {7: 2}, "item": {"id": 606, "count": 2}}]
		"smith": return [{"cost": {602: 3, 601: 2}, "item": {"id": 207, "count": 1}}, {"cost": {602: 2, 601: 1}, "item": {"id": 208, "count": 1}}, {"cost": {9: 4}, "item": {"id": 602, "count": 3}}]
		"keeper": return [{"cost": {7: 8}, "item": {"id": 501, "count": 1}}, {"cost": {3: 3}, "item": {"id": 609, "count": 1}}, {"cost": {604: 3}, "item": {"id": 7, "count": 4}}]
	return [{"cost": {7: 5, 10: 1}, "item": {"id": 505, "count": 1}}, {"cost": {5: 4}, "item": {"id": 601, "count": 4}}, {"cost": {604: 6}, "item": {"id": 608, "count": 1}}]

func _simulate(record: Dictionary) -> void:
	if record.kind == "crop" and record.growth_stage > 0 and record.growth_stage < 3:
		var duration := 90.0 if record.watered else 180.0
		record.growth_stage = mini(3, 1 + floori((clock - float(record.planted_at)) / (duration / 2.0)))
	elif record.kind == "resident" and clock >= float(record.get("restock_at", 0)):
		record.stock = {}
		record.restock_at = clock + 300.0
	elif record.kind == "furnace":
		for step in range(64):
			var job: Dictionary = record.get("current", {})
			if not job.is_empty():
				if clock < float(job.due) or not _output_room(record.output, int(job.id), int(job.count)): break
				_push_output(record.output, int(job.id), int(job.count))
				record["current"] = {}
				mark(record)
			if int(record.fuel) <= 0 or record.input.is_empty(): break
			var order: Array = record.get("input_order", [])
			var id := int(order[0] if not order.is_empty() else record.input.keys()[0])
			var recipe: Dictionary = Items.SMELTING[id]
			if not _output_room(record.output, recipe.id, recipe.count): break
			record.input[str(id)] -= 1
			if record.input[str(id)] <= 0:
				record.input.erase(str(id))
				order.erase(str(id))
			record.fuel -= 1
			record["current"] = {"id": recipe.id, "count": recipe.count, "due": (float(job.due) if not job.is_empty() else clock) + float(recipe.seconds)}
			mark(record)

func _output_room(slots: Array, id: int, amount: int) -> bool:
	return slots.size() < 8 or slots.any(func(item: Dictionary): return item.id == id and item.count + amount <= 64)

func _push_output(slots: Array, id: int, amount: int) -> void:
	for item in slots:
		if item.id == id and item.count + amount <= 64:
			item.count += amount
			return
	slots.append({"id": id, "count": amount})

func save_data() -> Dictionary:
	for key in nodes:
		if records[key].kind == "resident":
			var resident: CharacterBody3D = nodes[key]
			var position := resident.global_position
			records[key].position = [position.x, position.y, position.z]
			records[key]["patrol_index"] = resident.cursor
			records[key]["patrol_direction"] = resident.direction
			records[key]["patrol_rest"] = resident.rest
			edits[key] = records[key]
	return {"clock": clock, "next_id": next_id, "objects": edits.values().duplicate(true)}

func load_data(data: Dictionary) -> void:
	active_interaction = ""
	interacting_actor = null
	for node in nodes.values(): node.queue_free()
	nodes.clear()
	records.clear()
	edits.clear()
	known_villages.clear()
	support_index.clear()
	occupied_index.clear()
	door_release.clear()
	clock = float(data.get("clock", 0.0))
	next_id = int(data.get("next_id", 1))
	for record in data.get("objects", []):
		var copy: Dictionary = record.duplicate(true)
		records[str(copy.key)] = copy
		edits[str(copy.key)] = copy
		_index_support(copy)
	timer = 0.0

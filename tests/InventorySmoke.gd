extends SceneTree

const Inventory = preload("res://scripts/inventory/Inventory.gd")

func _initialize() -> void:
	create_timer(8.0).timeout.connect(func(): push_error("INVENTORY_SMOKE_TIMEOUT"); quit(1))
	_run.call_deferred()

func _run() -> void:
	var inv = Inventory.new()
	var changes := {"count": 0}
	inv.changed.connect(func(): changes.count += 1)
	assert(inv.bag.size() == 24 and inv.equipment.size() == 7 and inv.crafting.size() == 3)
	for i in range(7):
		assert(inv.equip_from_bag(10 + i) and inv.equipment[i] == 101 + i)
		assert(not inv.can_move("equipment", i, "equipment", (i + 1) % 7))
		assert(inv.unequip(i))
	assert(changes.count >= 12)
	assert(not inv.can_move("bag", 0, "equipment", 0))
	assert(inv.move_item("bag", 0, "bag", 1))
	assert(inv.bag[0].id == 2 and inv.bag[1].id == 1)
	inv = Inventory.new("survival")
	inv.bag[2] = {"id": 3, "count": 3}
	assert(inv.move_item("bag", 2, "crafting", 0))
	assert(inv.bag[2].count == 2 and inv.crafting[0].count == 1)
	assert(inv.get_slot("result", 0).id == 7)
	assert(inv.move_item("result", 0, "bag", 15))
	assert(inv.bag[15].id == 7 and inv.bag[15].count == 4 and inv.crafting[0].id == 0)
	inv = Inventory.new()
	assert(inv.move_item("bag", 2, "crafting", 0))
	assert(inv.move_item("bag", 4, "crafting", 1))
	assert(inv.move_item("bag", 4, "crafting", 2))
	assert(inv.get_slot("result", 0).id == 101)
	inv.set_mode("survival")
	for i in range(24):
		inv.bag[i] = {"id": 102, "count": 1}
	assert(not inv.take_result() and inv.crafting[0].count == 1, "Full bag must not consume recipe materials")
	inv.bag[15] = {"id": 0, "count": 0}
	assert(inv.take_result() and inv.bag[15].id == 101)
	assert(inv.equip_from_bag(15) and inv.equipment[0] == 101)
	assert(inv.unequip(0) and inv.bag[15].count == 1)
	var panel = load("res://scenes/InventoryPanel.tscn").instantiate()
	root.add_child(panel)
	await process_frame
	panel.bind_inventory(inv)
	assert(panel.slots.size() == 35, "24 bag slots, seven equipment slots, three inputs, one output")
	var target = panel.equipment_grid.get_child(0)
	var payload := {"model": inv, "group": "bag", "index": 15}
	assert(target._can_drop_data(Vector2.ZERO, payload))
	target._drop_data(Vector2.ZERO, payload)
	assert(inv.equipment[0] == 101)
	assert(not panel.equipment_grid.get_child(1)._can_drop_data(Vector2.ZERO, {"model": inv, "group": "equipment", "index": 0}))
	panel.queue_free()
	await process_frame
	print("INVENTORY_SMOKE_PASS: bag swaps, seven equipment slots, drag payloads, creative sources, crafting output, full bag atomicity")
	quit(0)

extends SceneTree

const Inventory = preload("res://scripts/inventory/Inventory.gd")
const FacilityData = preload("res://scripts/world/FacilityData.gd")
var checks: int = 0
var failures: int = 0

func _initialize() -> void:
	create_timer(35.0).timeout.connect(func(): push_error("VILLAGE_FACILITIES_TIMEOUT"); quit(1))
	_run.call_deferred()

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)

func _run() -> void:
	var game = preload("res://scenes/Main.tscn").instantiate()
	game.game_mode = "survival"
	root.add_child(game)
	while game.is_loading: await process_frame
	game.player.set_physics_process(false)
	var life = game.world.life
	var inventory = game.inventory
	var away := AABB(Vector3(-100, 50, -100), Vector3.ONE)
	var keys := {}
	for pair in [[501, Vector3i(18, 4, 22)], [502, Vector3i(20, 4, 22)], [507, Vector3i(22, 4, 22)], [505, Vector3i(24, 4, 22)]]:
		var result: Dictionary = life.place({"id": pair[0], "count": 1}, pair[1], away)
		check(result.ok, "A real world facility can be placed: " + str(pair[0]))
		if result.ok: keys[pair[0]] = result.record.key
	if keys.size() < 4:
		quit(1)
		return
	var chest: String = keys[501]
	var furnace: String = keys[502]
	var crop: String = keys[507]
	var lamp: String = keys[505]
	inventory.add_item(7, 20)
	var document := {"id": 109, "count": 1, "custom_name": "独立仓库图纸", "blueprints": []}
	inventory.add_snapshot(document)
	var document_index: int = inventory.bag.find(document)
	check(life.deposit(chest, inventory, document_index).ok, "Storage accepts independent document snapshots")
	check(life.records[chest].storage[0] == document, "Storage retains document identity and data")
	check(not life.pickup(chest, inventory).ok, "A filled container cannot silently discard its contents")
	check(life.withdraw(chest, inventory, 0).ok and inventory.bag.has(document), "Storage withdrawal restores the complete item")
	inventory.add_item(9, 2)
	inventory.add_item(10, 1)
	check(life.act(furnace, "smelt", inventory, game.player, 9).ok, "Furnace accepts actual ore")
	check(life.act(furnace, "fuel", inventory, game.player, 10).ok, "Furnace consumes actual fuel")
	check(not life.records[furnace].current.is_empty(), "Processing starts from real inputs")
	life.clock += 12.0
	life._simulate(life.records[furnace])
	check(life.records[furnace].output.size() == 1 and life.records[furnace].output[0].id == 602, "Ore completes as iron ingots")
	check(life.withdraw(furnace, inventory, 0, true).ok and inventory.count_item(602) == 2, "Processed ingots can be collected")
	inventory.add_item(603, 1)
	inventory.add_item(610, 1)
	check(life.act(crop, "plant", inventory, game.player).ok, "Planting consumes seed")
	check(life.act(crop, "water", inventory, game.player).ok and inventory.count_item(609) == 1, "Watering returns the empty bucket")
	life.clock += 100.0
	life._simulate(life.records[crop])
	check(life.records[crop].growth_stage == 3, "Watered wheat reaches maturity")
	check(life.act(crop, "harvest", inventory, game.player).ok and inventory.count_item(604) == 3 and inventory.count_item(603) == 2, "Harvest returns wheat and replanting seed")
	check(life.act(furnace, "smelt", inventory, game.player, 604).ok, "Harvested wheat can be baked")
	life.clock += 8.0
	life._simulate(life.records[furnace])
	check(life.withdraw(furnace, inventory, 0, true).ok and inventory.count_item(605) == 1, "Baking completes the food-production loop")
	var bread_index := -1
	for index in inventory.bag.size():
		if inventory.bag[index].id == 605: bread_index = index
	game.player.health = 50.0
	check(game.player.use_food_slot(bread_index) and game.player.health == 78.0 and inventory.count_item(605) == 0, "Food actually restores health and is consumed")
	check(life.act(lamp, "lamp", inventory, game.player).ok and not life.nodes[lamp].light.visible, "Lamp switch changes real world lighting")
	game._open_facility(furnace)
	check(game.facility_panel.visible and not game.player.controls_enabled and not paused, "Facility UI locks player input while production continues")
	var running_clock: float = life.clock
	for frame in range(12): await physics_frame
	check(life.clock > running_clock, "The facility simulation really advances while its menu is open")
	paused = true
	var paused_clock: float = life.clock
	for frame in range(6): await physics_frame
	check(life.clock == paused_clock, "A real pause freezes processing and crop time")
	paused = false
	game.facility_panel.close_panel()
	check(game.player.controls_enabled and not game.facility_panel.visible, "Closing the facility restores player control")
	# A separate level test pad exercises large furniture, seats and return points.
	game.world.world_type = "infinite"
	game.world.set_process(false)
	for z in range(40, 51):
		for x in range(40, 56):
			game.world.set_block(Vector3i(x, 5, z), 14)
			for y in range(6, 14): game.world.set_block(Vector3i(x, y, z), 0)
	for coord in [Vector2i(2, 2), Vector2i(3, 2), Vector2i(2, 3), Vector2i(3, 3)]: game.world._load_or_create_chunk(coord)
	for frame in range(4): await physics_frame
	for pair in [[503, Vector3i(42, 5, 43)], [504, Vector3i(46, 5, 43)], [508, Vector3i(51, 5, 44)]]:
		var result: Dictionary = life.place({"id": pair[0], "count": 1}, pair[1], away)
		check(result.ok, "Large and seating furniture places with real floor clearance")
		if result.ok: keys[pair[0]] = result.record.key
	for frame in range(4): await physics_frame
	if keys.has(503):
		game.player.health = 25.0
		check(life.act(keys[503], "rest", inventory, game.player).ok and game.player.health == 100.0 and game.world.has_custom_spawn, "A bed heals and establishes a genuinely safe return point")
	if keys.has(504):
		check(life.act(keys[504], "sit", inventory, game.player).ok and game.player.sitting, "A real chair seats the player")
		check(game.player._stand_up() and not game.player.sitting, "The player can stand safely from a chair")
	if keys.has(508):
		check(life.act(keys[508], "draw_water", inventory, game.player).ok and inventory.count_item(610) == 1, "The well refills the bucket for another crop cycle")
	var trader := {"key": "test:farmer", "kind": "resident", "role": "farmer", "support": [45, 5, 45], "position": [45.5, 6.02, 45.5], "route": [], "stock": {}, "restock_at": life.clock + 300.0}
	life.records[trader.key] = trader
	inventory.add_item(4, 10)
	check(life.act(trader.key, "trade", inventory, game.player, 0).ok and trader.stock["0"] == 1, "A villager exchange consumes resources and records stock")
	for attempt in range(7): life.act(trader.key, "trade", inventory, game.player, 0)
	check(not life.act(trader.key, "trade", inventory, game.player, 0).ok, "Trading cannot exceed the villager's stock")
	life.clock += 301.0
	life._simulate(trader)
	check(trader.stock.is_empty(), "Villagers replenish stock using saved game time")
	# Full-bag failures must not destroy a harvest or partially mutate storage.
	var full := Inventory.new("survival")
	for index in full.bag.size(): full.bag[index] = {"id": 301, "count": 1}
	life.records[crop].growth_stage = 3
	life.records[crop].planted_at = life.clock - 200.0
	check(not life.act(crop, "harvest", full, game.player).ok and life.records[crop].growth_stage == 3, "A failed harvest preserves the complete mature crop")
	check(life.act(crop, "harvest", inventory, game.player).ok, "Harvest still succeeds after capacity is available")
	var stacks := Inventory.new("survival")
	stacks.add_item(7, 20)
	life.records[chest].storage = [{"id": 7, "count": 54}, {"id": 7, "count": 54}]
	for index in range(22): life.records[chest].storage.append({"id": 301, "count": 1})
	check(life.deposit(chest, stacks, 0).ok and stacks.count_item(7) == 0 and life.records[chest].storage[0].count == 64 and life.records[chest].storage[1].count == 64, "Deposit distributes a stack over all existing capacity without needing a new slot")
	stacks.add_item(7, 1)
	var before_storage: Array = life.records[chest].storage.duplicate(true)
	check(not life.deposit(chest, stacks, 0).ok and stacks.count_item(7) == 1 and life.records[chest].storage == before_storage, "A full container rejects the entire transfer without partial mutation")
	var saved: Dictionary = life.save_data()
	check(FacilityData.validation_error(saved).is_empty(), "Facility state passes strict save validation")
	check(game.save_progress() and game.save_system.load_world().ok, "The normal world save accepts working village facilities")
	life.load_data(saved)
	life.refresh()
	check(not life.records[lamp].lit and life.records[crop].growth_stage == 0, "Facility switches and crop state restore")
	var malformed: Dictionary = saved.duplicate(true)
	malformed.objects[0].item.id = 9999
	check(not FacilityData.validation_error(malformed).is_empty(), "Unknown facility items are rejected")
	game.queue_free()
	for frame in range(4): await process_frame
	print("VILLAGE_FACILITIES_INTEGRITY_PASS: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

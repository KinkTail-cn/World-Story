extends SceneTree

const Generator = preload("res://scripts/world/VillageGenerator.gd")
var checks: int = 0
var failures: int = 0

func _initialize() -> void:
	create_timer(38.0).timeout.connect(func(): push_error("VILLAGE_FUNCTION_TIMEOUT"); quit(1))
	_run.call_deferred()

func check(value: bool, text: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(text)

func frames(count: int = 4) -> void:
	for index in count: await physics_frame

func _run() -> void:
	var game = preload("res://scenes/Main.tscn").instantiate()
	game.world_type = "infinite"
	game.game_mode = "survival"
	var world = game.get_node("World")
	world.world_type = "infinite"
	world.terrain_generation_version = 1
	world.world_seed = 1337
	world._setup_noise()
	var plan := {}
	for radius in range(3):
		for region in Generator.search_ring(Vector2i.ZERO, radius):
			plan = world.villages.plan_for_region(region)
			if not plan.is_empty(): break
		if not plan.is_empty(): break
	check(not plan.is_empty(), "Random terrain contains naturally generated village sites")
	if plan.is_empty(): quit(1); return
	world.world_spawn = Vector3(plan.centre.x - 1 + 0.5, plan.floor_y + 1.02, plan.centre.y + 0.5)
	root.add_child(game)
	current_scene = game
	while game.is_loading: await process_frame
	await frames(8)
	var life = world.life
	var kinds := {}
	var resident_key := ""
	var chest_key := ""
	for record in life.records.values():
		kinds[record.kind] = int(kinds.get(record.kind, 0)) + 1
		if record.kind == "resident" and record.role == "farmer": resident_key = record.key
		if record.kind == "chest": chest_key = record.key
	check(kinds.get("resident", 0) == 4 and kinds.get("workbench", 0) > 0 and kinds.get("furnace", 0) > 0, "A natural village has residents and a functioning production workshop")
	var homes: int = plan.houses.filter(func(building: Dictionary): return building.role == "home").size()
	check(kinds.get("bed", 0) == homes and kinds.get("chair", 0) == homes and kinds.get("crop", 0) == 8 and kinds.get("well", 0) == 1, "Every unmodified home, field and public well receives its full functional facilities")
	if resident_key.is_empty() or chest_key.is_empty(): quit(1); return
	var resident: CharacterBody3D = life.nodes[resident_key]
	var start := resident.global_position
	await frames(100)
	check(resident.global_position.distance_to(start) > 0.2, "A village resident actually walks on the road network")
	game.inventory.add_item(4, 10)
	game._open_facility(resident_key)
	await frames(3)
	var stopped := resident.global_position
	await frames(20)
	check(resident.global_position.distance_to(stopped) < 0.05, "The resident stops and attends to an active interaction")
	var panel = game.facility_panel
	panel.contents.select(0)
	var trade_button: Button
	for button in panel.find_children("*", "Button", true, false):
		if button.text == "交换所选物品": trade_button = button
	check(trade_button != null and panel.contents.item_count == 3, "The real village trading interface presents actionable offers")
	if trade_button != null: trade_button.pressed.emit()
	check(game.inventory.count_item(603) == 3 and game.inventory.count_item(4) == 9, "The real trade action exchanges actual inventory items")
	await capture("resident-trade")
	panel.close_panel()
	var design := preload("res://scripts/blueprint/UtilityPresets.gd").design(207)
	var item := preload("res://scripts/blueprint/BlueprintEquipment.gd").make_item(design)
	check(game.inventory.add_snapshot(item), "Prepare an authored tool for the village warehouse")
	var index: int = game.inventory.bag.find(item)
	check(life.deposit(chest_key, game.inventory, index).ok, "A generated warehouse stores a custom tool")
	check(game.save_progress(), "The working village saves through the normal save system")
	var saved: Dictionary = game.save_system.load_world()
	check(saved.ok and not saved.data.world.village_life.objects.is_empty(), "Resident stocks, movement and storage survive validation")
	world._update_chunks_around(Vector2i(200, 200), false)
	world._load_or_create_chunk(Vector2i(200, 200))
	life.refresh()
	check(life.nodes.is_empty(), "Leaving the village releases all facility and resident scene nodes")
	world.load_data(saved.data.world, world.world_spawn)
	while game.is_loading: await process_frame
	await frames(4)
	check(life.records[chest_key].storage[0].blueprint == item.blueprint, "Returning from a save restores the warehouse's complete authored tool")
	check(int(life.records[resident_key].stock.get("0", 0)) == 1 and life.nodes.has(resident_key), "Resident stock and world identity survive reload without duplication")
	check(life.withdraw(chest_key, game.inventory, 0).ok and game.inventory.bag.any(func(slot: Dictionary): return slot.has("blueprint") and slot.id == 207), "The restored custom tool remains usable after withdrawal")
	if "--capture" in OS.get_cmdline_user_args():
		world.set_process(false)
		var camera := Camera3D.new()
		game.add_child(camera)
		var middle := Vector3(plan.centre.x, plan.floor_y + 2, plan.centre.y)
		camera.position = middle + Vector3(26, 21, 32)
		camera.look_at(middle)
		camera.current = true
		game.hud.visible = false
		await frames(5)
		await capture("working-village")
	game.queue_free()
	await frames(4)
	print("VILLAGE_FUNCTION_SMOKE_PASS: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

func capture(tag: String) -> void:
	if "--capture" in OS.get_cmdline_user_args():
		await create_timer(0.2).timeout
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("C:/Users/Qi/AppData/Local/Temp/opencode/village-life-" + tag + ".png")

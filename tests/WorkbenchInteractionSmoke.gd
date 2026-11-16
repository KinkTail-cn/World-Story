extends SceneTree

var checks: int = 0
var failures: int = 0

func _initialize() -> void:
	create_timer(35.0).timeout.connect(func(): push_error("WORKBENCH_INTERACTION_TIMEOUT"); quit(1))
	_run.call_deferred()

func check(value: bool, text: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(text)

func frames(count: int = 4) -> void:
	for index in count: await physics_frame

func key(code: int) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = true
	root.push_input(event, true)
	event = event.duplicate()
	event.pressed = false
	root.push_input(event, true)

func _run() -> void:
	var game = preload("res://scenes/Main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	while game.is_loading: await process_frame
	var player = game.player
	player.set_physics_process(false)
	player.global_position = Vector3(16.5, 5.02, 21.5)
	game.world.set_block(Vector3i(18, 5, 21), 20)
	await frames(4)
	player.set_first_person(true)
	player.rig.rotation.y = -PI * 0.5
	player.pitch.rotation.x = -0.42
	player._resolve_camera_collision()
	player._update_target()
	check(player.target_id == 20, "The real camera ray targets the placed workbench")
	key(KEY_R)
	await frames(2)
	check(game.facility_panel.visible and not player.controls_enabled, "Physical R opens the workbench's usable menu")
	await capture("workbench")
	game.facility_panel.blueprint_requested.emit()
	await frames(2)
	var editor = game.hud.blueprint_workshop
	check(editor.visible and paused and not game.facility_panel.visible, "The station opens the actual blueprint editor")
	editor._select_category("道具摆件", true)
	editor.product_selector.select(editor.product_selector.get_item_index(501))
	editor.product_selector.item_selected.emit(editor.product_selector.selected)
	editor._open_product_template()
	editor._craft_pressed()
	var crafted: Dictionary = game.inventory.bag.back()
	check(crafted.id == 501 and crafted.has("blueprint"), "The station crafts an authored storage-container item")
	var editor_size := root.size
	var editor_scale := root.content_scale_size
	root.content_scale_size = Vector2i.ZERO
	root.size = Vector2i(800, 500)
	await frames(3)
	check(root.get_visible_rect().grow(-3).encloses(editor.get_node("LeftDrawer/Panel").get_global_rect()), "Product selectors and their source scroll fit a small window")
	check(root.get_visible_rect().encloses(editor.product_template.get_global_rect()), "The basic-product template action remains reachable")
	root.size = editor_size
	root.content_scale_size = editor_scale
	await frames(3)
	await capture("product-blueprint")
	editor._finish_close()
	game.inventory.move_item("bag", game.inventory.bag.size() - 1, "bag", 0)
	player.select_slot(0)
	player.target_facility = ""
	player.target_document = null
	player.target_cell = Vector3i(20, 4, 21)
	player.target_id = 1
	player.target_normal = Vector3i.UP
	player._place()
	var life = game.world.life
	var placed_key := ""
	for record in life.records.values():
		if record.kind == "chest": placed_key = record.key
	check(not placed_key.is_empty() and life.records[placed_key].item.blueprint == crafted.blueprint, "The crafted chest places in the world with its complete design")
	check(not game.world.set_block(Vector3i(20, 4, 21), 0), "A placed facility protects its supporting floor")
	check(not game.world.set_block(Vector3i(20, 5, 21), 5), "Terrain building cannot bury an existing facility")
	game._open_facility(placed_key)
	await frames(2)
	var panel = game.facility_panel
	check(panel.bag_list != null and panel.contents != null, "A crafted chest exposes real storage controls")
	await capture("custom-storage")
	panel.close_panel()
	var original_size := root.size
	var original_scale := root.content_scale_size
	root.content_scale_size = Vector2i.ZERO
	life.set_process(false)
	for id in [502, 503, 504, 505, 507, 508, 509]:
		var record: Dictionary = life._record("ui:" + str(id), id, Vector3i(25, 4, 21))
		life.records[record.key] = record
		for dimensions in [Vector2i(800, 500), Vector2i(1280, 800)]:
			root.size = dimensions
			panel.open_for(record.key, life, game.inventory, player)
			await frames(3)
			check(root.get_visible_rect().grow(-3).encloses(panel.card.get_global_rect()), "Facility actions fit the viewport: %d %s" % [id, str(dimensions)])
			if dimensions.x == 1280: await capture("facility-" + str(id))
		panel.close_panel()
		life.records.erase(record.key)
	root.size = original_size
	root.content_scale_size = original_scale
	life.set_process(true)
	check(game.save_progress() and game.save_system.load_world().ok, "The actual custom facility and station workflow can be saved")
	game.queue_free()
	await frames(4)
	print("WORKBENCH_INTERACTION_SMOKE_PASS: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

func capture(tag: String) -> void:
	if "--capture" in OS.get_cmdline_user_args():
		await create_timer(0.2).timeout
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("C:/Users/Qi/AppData/Local/Temp/opencode/village-life-" + tag + ".png")

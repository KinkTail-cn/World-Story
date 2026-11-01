extends SceneTree

const Inventory = preload("res://scripts/inventory/Inventory.gd")
var checks: int = 0
var failures: int = 0

func _initialize() -> void:
	create_timer(35.0).timeout.connect(func(): push_error("INVENTORY_LAYOUT_TIMEOUT"); quit(1))
	_run.call_deferred()

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(label)

func _run() -> void:
	var inventory = Inventory.new("survival")
	inventory.bag[0] = {"id": 7, "count": 2}
	inventory.bag[8] = {"id": 3, "count": 40}
	inventory.bag[9] = {"id": 3, "count": 30}
	inventory.bag[10] = {"id": 109, "count": 1, "custom_name": "独立设计", "blueprints": [{"name": "test"}]}
	inventory.bag[11] = {"id": 101, "count": 1, "custom_name": "自制头盔", "blueprint": {"category": "头部装备", "voxels": []}}
	var hotbar: Array = inventory.bag.slice(0, 8).duplicate(true)
	var unique: Dictionary = inventory.bag[10].duplicate(true)
	var custom: Dictionary = inventory.bag[11].duplicate(true)
	inventory.sort_storage()
	check(inventory.bag.slice(0, 8) == hotbar, "Sort leaves all eight hotbar slots unchanged")
	check(inventory.count_item(3) == 70 and inventory.bag[8].count == 64 and inventory.bag[9].count == 6, "Sort merges ordinary stacks up to 64 without losing material")
	check(inventory.bag.has(unique) and inventory.bag.has(custom), "Sort retains unique document and custom equipment metadata")
	check(inventory.quick_move("bag", 8) and inventory.bag[1].id == 3 and inventory.bag[8].id == 0, "Shift move transfers storage into a free hotbar slot")
	inventory = Inventory.new("survival")
	inventory.bag[8] = {"id": 3, "count": 2}
	inventory.crafting[0] = {"id": 5, "count": 1}
	check(inventory.prepare_recipe("3") and inventory.count_item(5) == 1 and inventory.count_item(3) == 1, "Recipe selection returns old ingredients before adding new ones")
	check(inventory.take_result() and inventory.count_item(7) == 4, "Prepared survival recipe produces the correct output")
	var before: Array = inventory.bag.duplicate(true)
	check(not inventory.prepare_recipe("9,9,9") and inventory.bag == before, "Unavailable recipe does not mutate the bag")
	for i in range(24):
		inventory.bag[i] = {"id": 301, "count": 1}
	inventory.crafting[0] = {"id": 5, "count": 1}
	before = inventory.bag.duplicate(true)
	var inputs: Array = inventory.crafting.duplicate(true)
	check(not inventory.clear_crafting() and inventory.bag == before and inventory.crafting == inputs, "Full-bag return is atomic")
	check(not inventory.prepare_recipe("3") and inventory.bag == before and inventory.crafting == inputs, "Failed recipe replacement preserves original input")

	var game = preload("res://scenes/Main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	for frame in range(70):
		await physics_frame
	game._input(_action("inventory"))
	await _layout_frames()
	var panel = game.hud.inventory_panel
	check(paused and panel.visible and panel.creative_section.visible, "Creative backpack opens directly on the item library")
	check(panel.hotbar_grid.get_child_count() == 8 and panel.bag_grid.get_child_count() == 16, "Hotbar is pinned separately from storage")
	check(panel.equipment_grid.get_child_count() == 7 and panel.preview_character != null, "Equipment slots and mannequin are present")
	await _capture("creative")
	var original_scale_size := root.content_scale_size
	var original_size := root.size
	root.content_scale_size = Vector2i.ZERO
	for dimensions in [Vector2i(1440, 900), Vector2i(1280, 800), Vector2i(1024, 640), Vector2i(960, 600)]:
		root.size = dimensions
		await _layout_frames()
		var viewport := root.get_visible_rect().grow(-8)
		check(viewport.encloses(panel.card.get_global_rect()), "Backpack fits window " + str(dimensions))
		for tab in [true, false]:
			panel._set_creative_view(tab)
			await _layout_frames()
			for control in [panel.hotbar_grid, panel.bag_scroll, panel.close_button, panel.equipment_grid, panel.creative_section if tab else panel.craft_section]:
				check(panel.card.get_global_rect().encloses(control.get_global_rect()), "All controls fit within the card at " + str(dimensions))
			check(panel.hotbar_grid.get_global_rect().position.y > panel.bag_scroll.get_global_rect().end.y, "Storage scroll does not overlap the pinned hotbar")
		if dimensions == Vector2i(960, 600):
			await _capture("small")
	root.size = original_size
	root.content_scale_size = original_scale_size
	await _layout_frames()
	panel._set_creative_view(true)
	_set_search(panel.search, "铁")
	await _layout_frames()
	check(panel.creative_grid.get_child_count() > 0 and panel.creative_grid.get_children().all(func(slot): return slot.item_id == 9 or "铁" in slot.ItemCatalog.title(slot.item_id)), "Catalog search filters item names")
	_set_search(panel.search, "不存在的物品")
	check(panel.creative_grid.get_child_count() == 0 and panel.get_node("%EmptySearch").visible, "Empty search shows a helpful message")
	panel.search.grab_focus()
	for key in [KEY_B, KEY_E, KEY_P, KEY_N, KEY_G]:
		var event := InputEventKey.new()
		event.pressed = true
		event.keycode = key
		event.physical_keycode = key
		event.unicode = key + 32
		root.push_input(event, true)
	check(panel.visible and paused and not game.hud.notebook_panel.visible and not game.hud.blueprint_workshop.visible, "Typing search letters does not trigger game hotkeys")
	_set_search(panel.search, "")
	panel.search.release_focus()
	panel._select_category("tools")
	await _layout_frames()
	var catalog: Control = panel.creative_grid.get_child(0)
	var count: int = game.inventory.bag.size()
	_click(catalog)
	await _layout_frames()
	check(game.inventory.bag.size() == count + 1 and panel.bag_slots.size() == count + 1, "Catalog click grants once and expands visible storage")
	_click(panel.get_bag_slot(3))
	await process_frame
	_click(catalog, MOUSE_BUTTON_RIGHT)
	await _layout_frames()
	check(game.player.selected_slot == 3 and game.inventory.bag[3].id == catalog.item_id, "Catalog right click targets the selected hotbar slot")
	check(panel.creative_grid.get_child(0) == catalog, "Receiving items preserves the current catalog node and scroll state")
	panel._hovered_slot = panel.get_bag_slot(17)
	panel._unhandled_key_input(_action("slot_6"))
	check(game.player.selected_slot == 5 and game.inventory.bag[5].id == 201, "Hover plus number key moves a stored item to that hotbar slot")
	var shift_click := InputEventMouseButton.new()
	shift_click.pressed = true
	shift_click.button_index = MOUSE_BUTTON_LEFT
	shift_click.shift_pressed = true
	panel.get_bag_slot(10)._gui_input(shift_click)
	check(game.inventory.equipment[0] == 101 and panel.preview_character.equipment_visuals.pieces[0][0].visible, "Shift click equips and updates the mannequin")
	panel.tab_crafting.pressed.emit()
	await _layout_frames()
	_set_search(panel.recipe_search, "铁镐")
	check(panel.recipe_list.item_count == 2, "Recipe search finds both current and legacy iron pickaxe recipes")
	_set_search(panel.recipe_search, "")
	await _layout_frames()
	var first_recipe: Rect2 = panel.recipe_list.get_item_rect(0)
	_button(panel.recipe_list.get_global_transform_with_canvas() * first_recipe.get_center(), MOUSE_BUTTON_LEFT, true)
	_button(panel.recipe_list.get_global_transform_with_canvas() * first_recipe.get_center(), MOUSE_BUTTON_LEFT, false)
	await _layout_frames()
	check(game.inventory.crafting[0].id == 3 and game.inventory.get_slot("result", 0).id == 7, "Clicking a recipe fills the real crafting slots")
	_click(panel.get_node("%TakeResult"))
	await _layout_frames()
	check(game.inventory.bag.any(func(item): return item.id == 7 and item.count == 4), "Claim button grants the crafted result")
	_click(panel.get_node("%ReturnMaterials"))
	await _layout_frames()
	check(game.inventory.crafting.all(func(item): return item.id == 0), "Return button clears all ingredients")
	await _capture("crafting")
	panel.bind_inventory(Inventory.new("survival"))
	await _layout_frames()
	check(not panel.tab_creative.visible and panel.craft_section.visible, "Survival backpack shows crafting and hides creative grants")
	panel.close_button.pressed.emit()
	check(not paused and not panel.visible, "Closing the new backpack restores game input")
	game.queue_free()
	await process_frame
	print("INVENTORY_LAYOUT_SMOKE_PASS: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

func _layout_frames() -> void:
	for frame in range(5):
		await process_frame

func _set_search(field: LineEdit, text: String) -> void:
	field.text = text
	field.text_changed.emit(text)

func _action(name: String) -> InputEventAction:
	var event := InputEventAction.new()
	event.action = name
	event.pressed = true
	return event

func _click(control: Control, button: int = MOUSE_BUTTON_LEFT) -> void:
	var point := control.get_global_transform_with_canvas() * (control.size * 0.5)
	_button(point, button, true)
	_button(point, button, false)

func _button(point: Vector2, button: int, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.position = point
	event.global_position = point
	event.button_index = button
	event.pressed = pressed
	root.push_input(event, true)

func _capture(tag: String) -> void:
	if "--capture" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("C:/Users/Qi/AppData/Local/Temp/opencode/world-story-backpack-" + tag + ".png")

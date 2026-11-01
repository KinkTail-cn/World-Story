extends SceneTree

func _initialize() -> void:
	create_timer(15.0).timeout.connect(func():
		push_error("BACKPACK_GAME_SMOKE_TIMEOUT")
		quit(1)
	)
	_run.call_deferred()

func _run() -> void:
	var main = load("res://scenes/Main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	var player = main.player
	var inv = main.inventory
	var panel = main.hud.inventory_panel
	for frame in range(90):
		await physics_frame
	main._input(_action("inventory"))
	await process_frame
	await process_frame
	assert(paused and panel.visible and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE)
	main._input(_action("function_wheel"))
	assert(panel.visible and not main.hud.function_wheel.visible, "G must not open another modal over the backpack")
	var before: Vector3 = player.position
	Input.action_press("move_forward")
	for frame in range(4):
		await physics_frame
	Input.action_release("move_forward")
	assert(player.position.is_equal_approx(before), "Backpack must pause player movement")
	await _drag(panel.get_bag_slot(10), panel.equipment_grid.get_child(0))
	assert(inv.equipment[0] == 101 and inv.bag[10].id == 0, "Mouse drag must equip the helmet")
	assert(player.visual.equipment_visuals.pieces[0][0].visible, "Equipping must update the character model")
	for i in range(1, 7):
		_click(panel.get_bag_slot(10 + i), MOUSE_BUTTON_RIGHT)
		await process_frame
		assert(inv.equipment[i] == 101 + i)
		assert(player.visual.equipment_visuals.pieces[i][0].visible)
	for frame in range(20):
		player.visual.equipment_visuals.update_motion(1.0 / 60.0, 7.8, false, false, false)
	assert(player.visual.equipment_visuals.cape_wind > 0.75, "Running must increase cape billowing")
	for frame in range(60):
		player.visual.equipment_visuals.update_motion(1.0 / 60.0, 0, false, false, true)
	assert(player.visual.equipment_visuals.cape_wind < 0.01, "Sitting must let the cape settle")
	panel.tab_crafting.pressed.emit()
	await process_frame
	await process_frame
	await _drag(panel.get_bag_slot(2), panel.crafting_box.get_child(0))
	assert(inv.crafting[0].id == 3 and inv.bag[2].count == -1, "Creative logs must copy into a crafting slot")
	_click(panel.result_slot, MOUSE_BUTTON_LEFT)
	await process_frame
	var crafted_slot: int = -1
	for i in range(8, 24):
		if inv.bag[i].id == 7 and inv.bag[i].count == 4:
			crafted_slot = i
	assert(crafted_slot >= 8 and inv.crafting[0].id == 3, "Creative crafting produces an item without consuming the input")
	await _drag(panel.crafting_box.get_child(0), panel.get_bag_slot(2))
	assert(inv.crafting[0].id == 0, "Returning the ingredient clears the crafting slot")
	await _drag(panel.get_bag_slot(crafted_slot), panel.get_bag_slot(0))
	assert(player.selected_item_id() == 7 and player.visual.held_item.block_id == 7, "Hotbar dragging must refresh the held item")
	assert(main.hud.slots.get_child(0).get_node("Icon").block_id == 7)
	await _drag(panel.get_bag_slot(4), panel.crafting_box.get_child(0))
	await _drag(panel.get_bag_slot(5), panel.crafting_box.get_child(1))
	assert(inv.get_slot("result", 0).id == 8)
	await _drag(panel.result_slot, panel.get_bag_slot(15))
	assert(inv.bag[15].id == 8 and inv.bag[15].count == 4, "Craft output must be draggable into a chosen empty slot")
	if "--capture" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("C:/Users/Qi/AppData/Local/Temp/opencode/world-story-backpack.png")
	main._input(_action("pause"))
	assert(not paused and not panel.visible and not main.hud.pause_panel.visible, "Escape must close only the backpack")
	for frame in range(4):
		await physics_frame
	inv.set_mode("survival")
	player.target_cell = Vector3i(20, 4, 21)
	player.target_id = main.world.get_block(player.target_cell)
	player._mine()
	player.target_cell = Vector3i(20, 3, 21)
	player.target_id = main.world.get_block(player.target_cell)
	player.target_normal = Vector3i.UP
	player._place()
	assert(inv.bag[0].count == 3 and main.world.get_block(Vector3i(20, 4, 21)) == 7, "Finite crafted blocks must decrement on placement")
	main._input(_action("inventory"))
	await process_frame
	_click(panel.close_button, MOUSE_BUTTON_LEFT)
	await process_frame
	assert(not paused and not panel.visible, "The close button must restore game input")
	if "--capture" in OS.get_cmdline_user_args():
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		player.rig.rotation.y = 0.0
		player.pitch.rotation.x = -0.1
		player.visual.rotation.y = PI
		for frame in range(4):
			await physics_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("C:/Users/Qi/AppData/Local/Temp/opencode/world-story-equipment.png")
	print("BACKPACK_GAME_SMOKE_PASS: modal input, actual mouse drag, seven equipment visuals, crafting click/drag, hotbar sync, finite placement, cape motion, ESC/button close")
	quit(0)

func _action(action: String) -> InputEventAction:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	return event

func _center(control: Control) -> Vector2:
	return control.get_global_transform_with_canvas() * (control.size * 0.5)

func _button(point: Vector2, button: int, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.position = point
	event.global_position = point
	event.button_index = button
	event.pressed = pressed
	root.push_input(event, true)

func _click(control: Control, button: int) -> void:
	_button(_center(control), button, true)
	_button(_center(control), button, false)

func _drag(source: Control, target: Control) -> void:
	var from := _center(source)
	var to := _center(target)
	_button(from, MOUSE_BUTTON_LEFT, true)
	var motion := InputEventMouseMotion.new()
	motion.position = from + Vector2(20, 0)
	motion.global_position = motion.position
	motion.relative = Vector2(20, 0)
	motion.button_mask = MOUSE_BUTTON_MASK_LEFT
	root.push_input(motion, true)
	await process_frame
	motion = motion.duplicate()
	motion.position = to
	motion.global_position = to
	motion.relative = to - from
	root.push_input(motion, true)
	await process_frame
	_button(to, MOUSE_BUTTON_LEFT, false)
	await process_frame

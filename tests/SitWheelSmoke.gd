extends SceneTree

func _initialize() -> void:
	create_timer(20.0).timeout.connect(func():
		push_error("SIT_WHEEL_SMOKE_TIMEOUT")
		quit(1)
	)
	_run.call_deferred()

func _run() -> void:
	var main = load("res://scenes/Main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	var player = main.get_node("Player")
	var world = main.get_node("World")
	var wheel = main.get_node("HUD/Root/FunctionWheel")
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	for frame in range(90):
		await physics_frame
	player.rig.rotation = Vector3.ZERO
	player.pitch.rotation.x = -0.65
	main._input(_action("function_wheel"))
	assert(paused and wheel.visible and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "G must open the wheel and pause player input")
	assert(wheel.function_at_position(wheel.center + Vector2(-125, 0)) == 0, "Left sector combines mining and building")
	assert(wheel.function_at_position(wheel.center + Vector2(125, 0)) == 1, "Right sector selects sitting")
	assert(wheel.function_at_position(wheel.center) == -1, "Wheel center must not trigger a function")
	var before: Vector3 = player.position
	Input.action_press("move_forward")
	Input.action_press("mine")
	for frame in range(8):
		await physics_frame
	assert(player.position.is_equal_approx(before) and player.mined == 0, "Wheel must block movement and mining")
	Input.action_release("move_forward")
	Input.action_release("mine")
	assert(player.target_id > 0, "Wheel opens with a real crosshair target")
	var selected_cell: Vector3i = player.target_cell
	_click(wheel.center + Vector2(125, 0))
	await process_frame
	assert(not paused and not wheel.visible and player.active_function == 1 and not player.sitting, "Selecting sitting closes the wheel and waits for a right click")
	for frame in range(3): await physics_frame
	selected_cell = player.target_cell
	await _right_click()
	assert(player.sitting, "A right click in sitting mode sits on the aimed block")
	assert(player.seat_cell == selected_cell and absf(player.position.y - selected_cell.y - 1.01) < 0.001)
	assert(absf(player.visual.left_leg.rotation.x - PI * 0.5) < 0.001, "Sitting pose must extend both legs forward")
	var hip_height: float = player.visual.left_leg.global_position.y - selected_cell.y - 1.0
	assert(hip_height > 0.1 and hip_height < 0.2, "Hips must rest above the support block while leaving room for worn boots")
	var count: int = player.mined
	player._mine()
	player._place()
	assert(player.mined == count and player.placed == 0, "Sitting must block both mining and placing")
	player._unhandled_input(_action("switch_view"))
	assert(player.first_person and is_equal_approx(player.rig.position.y, 0.95), "Sitting must lower the first-person camera")
	player._unhandled_input(_action("switch_view"))
	main._input(_action("function_wheel"))
	main._input(_action("pause"))
	assert(not paused and not wheel.visible and player.sitting and not main.hud.pause_panel.visible, "Escape must cancel the wheel without opening pause or leaving the seat")
	player._unhandled_input(_action("sit"))
	assert(not player.sitting and player.active_function == 0 and player.visual.position.y == 0.0, "F must stand and restore mining/building")
	var cell := Vector3i(18, 5, 21)
	player.set_first_person(true)
	player.rig.rotation.y = -PI * 0.5
	player.pitch.rotation.x = 1.1
	player._resolve_camera_collision()
	player._update_target()
	assert(player.target_id == 0)
	player.select_function(1)
	await _right_click()
	assert(player.active_function == 1 and player.sitting, "Clicking empty space in sitting mode sits at the player's current location")
	assert(player._stand_up())
	player.pitch.rotation.x = -0.45
	for id in range(1, 21):
		world.set_block(cell, id)
		player.position = Vector3(16.5, 5.01, 21.5)
		player.velocity = Vector3.ZERO
		for frame in range(3):
			await physics_frame
		assert(player.target_cell == cell and player.target_id == id, "The real camera ray must aim at every block type")
		player.select_function(1)
		assert(not player.sitting and player.active_function == 1, "Selecting sitting must not act before the right click")
		if id == 1:
			Input.action_press("mine")
			for frame in range(4): await physics_frame
			Input.action_release("mine")
			assert(not player.sitting and player.mined == count, "Left click in sitting mode must not sit or mine")
		await _right_click()
		assert(player.sitting and player.seat_cell == cell, "Right click must sit on all twenty block types, including the workbench")
		assert(not main.facility_panel.visible and not main.hud.inventory_panel.visible, "Sitting on the workbench must not open a facility menu")
		assert(player._stand_up(), "Standing from a clear block must succeed")
	var original_item: Dictionary = main.inventory.bag[0].duplicate(true)
	for held_id in [0, 207, 501, 605]:
		main.inventory.bag[0] = {"id": held_id, "count": 2 if held_id == 605 else (0 if held_id == 0 else 1)}
		player.select_slot(0)
		player.health = 50.0
		player.position = Vector3(16.5, 5.01, 21.5)
		player.velocity = Vector3.ZERO
		for frame in range(3): await physics_frame
		var held_before: Dictionary = main.inventory.bag[0].duplicate(true)
		player.select_function(1)
		await _right_click()
		assert(player.sitting and player.seat_cell == cell and main.inventory.bag[0] == held_before and player.placed == 0, "Sitting works with empty hands, tools, facilities and food without consuming or placing them")
		assert(player._stand_up())
	main.inventory.bag[0] = original_item
	player.select_slot(0)
	player.health = 100.0
	player.set_first_person(false)
	world.set_block(cell + Vector3i.UP, 5)
	for frame in range(3):
		await physics_frame
	player.position = Vector3(16.5, 5.01, 21.5)
	player.target_cell = cell
	player.target_id = world.get_block(cell)
	player.select_function(1)
	player._place()
	assert(player.sitting and player.seat_cell == cell + Vector3i.UP, "A side target with blocks above resolves to the top of the stack")
	assert(player._stand_up())
	world.set_block(cell + Vector3i.UP, 0)
	for frame in range(3):
		await physics_frame
	player.target_cell = cell
	player.target_id = world.get_block(cell)
	player.select_function(1)
	player._place()
	assert(player.sitting)
	var seat_origin: Vector3 = player.global_position
	var ceiling := StaticBody3D.new()
	var ceiling_shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.9, 0.3, 0.9)
	ceiling_shape.shape = box
	ceiling.add_child(ceiling_shape)
	main.add_child(ceiling)
	ceiling.global_position = seat_origin + Vector3(0, 1.6, 0)
	for frame in range(3):
		await physics_frame
	assert(not player._can_occupy(seat_origin, false), "Standing clearance must include non-voxel ceilings")
	assert(player._stand_up() and not player.global_position.is_equal_approx(seat_origin), "A blocked seat must choose a safe adjacent stand-up position")
	ceiling.queue_free()
	for frame in range(3):
		await physics_frame
	player.position = Vector3(16.5, 5.01, 21.5)
	player.target_cell = cell
	player.target_id = world.get_block(cell)
	player.select_function(1)
	player._place()
	assert(player.sitting)
	Input.action_press("move_forward")
	for frame in range(4):
		await physics_frame
	Input.action_release("move_forward")
	assert(not player.sitting and player.active_function == 0, "Movement must stand up and restore normal controls")
	player.position = Vector3(16.5, 5.01, 21.5)
	player.target_cell = cell
	player.target_id = world.get_block(cell)
	player.select_function(1)
	player._place()
	assert(player.sitting)
	world.set_block(cell, 0)
	for frame in range(5):
		await physics_frame
	assert(not player.sitting, "Removing the support must release the seat")
	player.select_function(0)
	main._input(_action("function_wheel"))
	_click(wheel.center + Vector2(-125, 0))
	await process_frame
	assert(not paused and player.active_function == 0, "Wheel mining/building selection must restore the combined mode")
	for frame in range(5):
		await physics_frame
	var mine_cell := Vector3i(20, 4, 21)
	player.target_cell = mine_cell
	player.target_id = world.get_block(mine_cell)
	player._mine()
	assert(world.get_block(mine_cell) == 0, "Mining remains available after leaving sitting mode")
	player.target_cell = mine_cell + Vector3i.DOWN
	player.target_id = world.get_block(player.target_cell)
	player.target_normal = Vector3i.UP
	player._place()
	assert(world.get_block(mine_cell) == player.selected_slot + 1 and player.visual.place_time > 0.0, "Placement remains available and starts the hand animation")
	# Check the contact pose explicitly; the free-running phase may otherwise
	# sample the backwards windup depending on how long scene loading took.
	player.visual.swing_phase = 0.60 * TAU - 0.15 * 12.0
	player.visual.animate(0.15, 0, false, true)
	assert(player.visual.right_arm.rotation.x > 0.0, "Mining swing must point toward the character's front")
	if "--capture" in OS.get_cmdline_user_args():
		world.set_block(cell, 7)
		player.position = Vector3(16.5, 5.01, 21.5)
		player.velocity = Vector3.ZERO
		for frame in range(4):
			await physics_frame
		player.rig.rotation.y = 0.0
		player.target_cell = cell
		player.target_id = 7
		player.select_function(1)
		player._place()
		player.rig.rotation.y = 1.2
		player.pitch.rotation.x = -0.2
		for frame in range(4):
			await physics_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("C:/Users/Qi/AppData/Local/Temp/opencode/world-story-sitting.png")
		main._input(_action("function_wheel"))
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("C:/Users/Qi/AppData/Local/Temp/opencode/world-story-functions.png")
		main._input(_action("function_wheel"))
	main.queue_free()
	for frame in range(4): await process_frame
	print("SIT_WHEEL_SMOKE_PASS: G wheel, right-click sitting on all 20 blocks, workbench priority, input blocking, pose, F/move exit, support removal, combined mining/building, action poses")
	quit(0)

func _right_click() -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_RIGHT
	event.position = root.get_visible_rect().size * 0.5
	event.global_position = event.position
	event.pressed = true
	Input.parse_input_event(event)
	for frame in range(3): await physics_frame
	event = event.duplicate()
	event.pressed = false
	Input.parse_input_event(event)
	for frame in range(2): await physics_frame

func _action(action: String) -> InputEventAction:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	return event

func _click(point: Vector2) -> void:
	var wheel = current_scene.get_node("HUD/Root/FunctionWheel")
	point = wheel.get_global_transform_with_canvas() * point
	var event := InputEventMouseButton.new()
	event.position = point
	event.global_position = point
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	root.push_input(event, true)
	event = event.duplicate()
	event.pressed = false
	root.push_input(event, true)

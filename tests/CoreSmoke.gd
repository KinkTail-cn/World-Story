extends SceneTree

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var main = load("res://scenes/Main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	var world = main.get_node("World")
	var player = main.get_node("Player")
	for frame in range(90):
		await physics_frame
	assert(player.is_on_floor(), "Player must land on the grass, not fall through the mesh")
	assert(absf(player.position.y - 5.0) < 0.1, "Clearing floor must be at y=5")
	var slot_event := InputEventAction.new()
	slot_event.pressed = true
	for slot in range(8):
		slot_event.action = "slot_%d" % (slot + 1)
		player._unhandled_input(slot_event)
		assert(player.visual.held_item.block_id == slot + 1, "Third-person held block must follow number keys")
		assert(player.first_person_item.block_id == slot + 1, "First-person held block must follow number keys")
		assert(main.get_node("HUD").selected == slot, "HUD must match the held block")
	slot_event.action = "next_slot"
	player._unhandled_input(slot_event)
	assert(player.selected_slot == 0 and player.visual.held_item.block_id == 1, "Scroll must wrap the held selection")
	var start: Vector3 = player.position
	Input.action_press("move_forward")
	for frame in range(30):
		await physics_frame
	Input.action_release("move_forward")
	assert(player.position.z < start.z - 1.0, "W must move toward -Z")
	Input.action_press("jump")
	await physics_frame
	Input.action_release("jump")
	for frame in range(12):
		await physics_frame
	assert(player.position.y > 5.7, "Jump must clear a block-height ledge")
	for frame in range(60):
		await physics_frame
	assert(player.is_on_floor(), "Player must land again after jumping")
	var cell := Vector3i(20, 4, 21)
	var original: int = world.get_block(cell)
	assert(original > 0)
	player.target_cell = cell
	player.target_id = original
	player._mine()
	assert(world.get_block(cell) == 0 and player.mined == 1, "Mining must remove the target")
	player.target_cell = cell + Vector3i.DOWN
	player.target_id = world.get_block(player.target_cell)
	player.target_normal = Vector3i.UP
	player.select_slot(6)
	player._place()
	assert(world.get_block(cell) == 7 and player.placed == 1, "Placement must snap onto the target face")
	assert(player.place_delay >= 0.20, "成功放置后必须具备防抖冷却时间")
	assert(world.get_block(cell) == player.visual.held_item.block_id, "Placed material must match the held item")
	world.set_block(cell, original)
	var overlap := Vector3i(player.position.floor())
	player.target_cell = overlap + Vector3i.DOWN
	player.target_id = world.get_block(player.target_cell)
	player.target_normal = Vector3i.UP
	player._place()
	assert(world.get_block(overlap) == 0, "Placement must not trap the character")
	assert(not world.set_block(Vector3i(0, 0, 0), 0), "Bedrock is protected")
	assert(not world.set_block(Vector3i(-1, 4, 0), 1), "World bounds must be protected")
	player.position = world.get_spawn_position()
	player.velocity = Vector3.ZERO
	player.select_slot(0)
	for frame in range(90):
		await physics_frame
	main._input(_pause_event())
	assert(paused and main.get_node("HUD/Root/Pause").visible, "Escape must pause the game")
	main._input(_pause_event())
	assert(not paused)
	var view_event := InputEventAction.new()
	view_event.action = "switch_view"
	view_event.pressed = true
	player._unhandled_input(view_event)
	assert(player.first_person and not player.visual.visible and player.arm.spring_length == 0.0)
	assert(player.first_person_item.is_visible_in_tree(), "First-person held item must remain visible when the body is hidden")
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	player.rig.rotation = Vector3.ZERO
	player.pitch.rotation.x = deg_to_rad(-60.0)
	await physics_frame
	player._update_target()
	assert(player.target_id > 0 and player.outline.visible, "First person ray must select the ground")
	if "--capture" in OS.get_cmdline_user_args():
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("C:/Users/Qi/AppData/Local/Temp/opencode/world-story-first-person.png")
	player._unhandled_input(view_event)
	assert(not player.first_person and player.visual.visible and is_equal_approx(player.arm.spring_length, 3.2))
	assert(not player.first_person_item.visible, "First-person item must hide in third person")
	if "--capture" in OS.get_cmdline_user_args():
		player.rig.rotation = Vector3.ZERO
		player.pitch.rotation.x = deg_to_rad(-20.0)
		player.visual.rotation.y = 0.0
		main.get_node("HUD/Root/Toast").visible = false
		for frame in range(5):
			await process_frame
		await process_frame
		await RenderingServer.frame_post_draw
		var image: Image = root.get_texture().get_image()
		image.save_png("C:/Users/Qi/AppData/Local/Temp/opencode/world-story-preview.png")
	print("CORE_SMOKE_PASS: landing, movement, jump, mining, placement, overlap guard, bounds, pause, viewpoints, aim ray, held selection")
	quit(0)

func _pause_event() -> InputEventAction:
	var event := InputEventAction.new()
	event.action = "pause"
	event.pressed = true
	return event

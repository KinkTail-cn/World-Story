extends SceneTree

const Character = preload("res://scripts/player/CharacterVisual.gd")
const Swing = preload("res://scripts/player/ToolSwing.gd")
var failures: int = 0
var checks: int = 0

func _initialize() -> void:
	create_timer(25.0).timeout.connect(func(): push_error("TOOL_SWING_TIMEOUT"); quit(1))
	_run.call_deferred()

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(label)

func _run() -> void:
	var character = Character.new()
	root.add_child(character)
	for id in range(201, 210):
		var start := Swing.sample(id, 0.0)
		var finish := Swing.sample(id, 1.0)
		check(start == finish, "%d: loop closes on the original carry pose" % id)
		for boundary in [Swing.WINDUP_END, Swing.IMPACT_PHASE, Swing.REBOUND_END]:
			var before := Swing.sample(id, boundary - 0.00001)
			var after := Swing.sample(id, boundary + 0.00001)
			check(Vector3(before.arm).distance_to(after.arm) < 0.003 and Vector3(before.grip_rotation).distance_to(after.grip_rotation) < 0.003, "%d: continuous third-person stage boundary" % id)
			check(Vector3(before.fp_position).distance_to(after.fp_position) < 0.003 and Vector3(before.fp_rotation).distance_to(after.fp_rotation) < 0.003, "%d: continuous first-person stage boundary" % id)
		character.set_held_block(id)
		await process_frame
		for delta in [1.0 / 120.0, 1.0 / 30.0]:
			for frame in range(90):
				character.animate(delta, 0.0, false, false)
			var duration: float = Swing.duration(id)
			var contacts := 0
			var contact_time := 0.0
			var highest := -INF
			var impact_height := 0.0
			var impact_forward := 0.0
			var grip_stays_in_hand := true
			var working_end_stays_forward := true
			var model: Node3D = character.held_item.tool_visual
			var working_point := Vector3(0, 0.43, -0.245)
			if (id - 201) % 3 == 1:
				working_point = Vector3(0, 0.44, -0.17)
			elif (id - 201) % 3 == 2:
				working_point = Vector3(0, 0.635, -0.025)
			for frame in range(ceili(duration * 1.5 / delta)):
				character.animate(delta, 0.0, false, frame == 0)
				var point: Vector3 = character.body.to_local(model.to_global(working_point))
				highest = maxf(highest, point.y)
				grip_stays_in_hand = grip_stays_in_hand and character.right_forearm.to_local(model.global_position).distance_to(Vector3(0, -0.225, 0)) < 0.001
				working_end_stays_forward = working_end_stays_forward and point.z < -0.15
				if character.swing_contact:
					contacts += 1
					contact_time = float(frame + 1) * delta
					impact_height = point.y
					impact_forward = point.z
			check(contacts == 1, "%d: one click completes exactly one impact at %d fps" % [id, roundi(1.0 / delta)])
			check(absf(contact_time - duration * Swing.IMPACT_PHASE) <= delta + 0.0001, "%d: impact event matches the shared animation phase" % id)
			check(not character.swing_cycle_running and character.swing < 0.01, "%d: released click completes recovery and stops" % id)
			check(highest - impact_height > 0.25 and impact_forward < -0.5, "%d: working end travels down and forward rather than back into the shoulder" % id)
			check(grip_stays_in_hand and working_end_stays_forward, "%d: complete arc maintains its grip and stays ahead of the body" % id)
		var held_contacts := 0
		for frame in range(ceili(Swing.duration(id) * 3.0 * 120.0) + 1):
			character.animate(1.0 / 120.0, 0.0, false, true)
			if character.swing_contact:
				held_contacts += 1
		check(held_contacts == 3, "%d: holding produces one impact per cycle" % id)
		character.set_held_block(7)
		check(not character.swing_cycle_running and not character.swing_contact, "Switching items cancels the old tool cycle")
	check(Swing.sample(207, Swing.IMPACT_PHASE).arm != Swing.sample(208, Swing.IMPACT_PHASE).arm and Swing.sample(208, Swing.IMPACT_PHASE).grip_rotation != Swing.sample(209, Swing.IMPACT_PHASE).grip_rotation, "Pickaxe, axe and shovel use distinct working strokes")
	character.queue_free()
	await process_frame

	var game = preload("res://scenes/Main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	for frame in range(70):
		await physics_frame
	var player = game.player
	game.inventory.bag[0] = {"id": 207, "count": 1}
	player.select_slot(0)
	player.set_first_person(true)
	player.pitch.rotation.x = -0.8
	Input.action_press("mine")
	for frame in range(2):
		await physics_frame
	Input.action_release("mine")
	var impacts := 0
	var highest_fp := -INF
	var lowest_fp := INF
	var feedback_at_contact := false
	var early_feedback := false
	for frame in range(65):
		await physics_frame
		var fp_model: Node3D = player.first_person_item.tool_visual
		var fp_tip: Vector3 = player.camera.to_local(fp_model.to_global(Vector3(0, 0.43, -0.245)))
		highest_fp = maxf(highest_fp, fp_tip.y)
		lowest_fp = minf(lowest_fp, fp_tip.y)
		if player.visual.swing_contact:
			impacts += 1
			feedback_at_contact = player.debris.size() > 0
		elif impacts == 0 and player.debris.size() > 0:
			early_feedback = true
	check(impacts == 1 and not player.visual.swing_cycle_running, "Real player input completes a single click after release")
	check(player.first_person_item.visible and player.first_person_item.position.is_finite(), "First-person tool finishes at a valid visible pose")
	check(highest_fp - lowest_fp > 0.08, "Actual first-person working end follows a visible arc")
	check(feedback_at_contact and not early_feedback, "Impact particles appear at contact rather than during windup")
	var held_impacts := 0
	Input.action_press("mine")
	for frame in range(ceili(Swing.duration(207) * 0.86 * 60.0)):
		await physics_frame
		if player.visual.swing_contact:
			held_impacts += 1
	Input.action_release("mine")
	for frame in range(65):
		await physics_frame
		if player.visual.swing_contact:
			held_impacts += 1
	check(held_impacts == 1 and not player.visual.swing_cycle_running, "Releasing near the end does not queue an extra swing")
	game.queue_free()
	await process_frame
	print("TOOL_SWING_SMOKE_PASS: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

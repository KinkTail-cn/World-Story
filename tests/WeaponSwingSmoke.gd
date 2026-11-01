extends SceneTree

const Character = preload("res://scripts/player/CharacterVisual.gd")
const Swing = preload("res://scripts/player/WeaponSwing.gd")
const Items = preload("res://scripts/inventory/ItemCatalog.gd")
var checks: int = 0
var failures: int = 0

func _initialize() -> void:
	create_timer(30.0).timeout.connect(func(): push_error("WEAPON_SWING_TIMEOUT"); quit(1))
	_run.call_deferred()

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(label)

func _run() -> void:
	var character = Character.new()
	root.add_child(character)
	for id in range(301, 306):
		check(Swing.sample(id, 0.0) == Swing.sample(id, 1.0), "%d closes its action loop" % id)
		check(is_equal_approx(Swing.duration(id) * Items.weapon_speed(id), 1.0), "%d follows its weapon speed" % id)
		for phase in [0.30, 0.52, 0.65]:
			var before := Swing.sample(id, phase - 0.00001)
			var after := Swing.sample(id, phase + 0.00001)
			check(Vector3(before.grip_rotation).distance_to(after.grip_rotation) < 0.003 and Vector3(before.fp_rotation).distance_to(after.fp_rotation) < 0.003, "%d has continuous action stages in both views" % id)
		for delta in [1.0 / 30.0, 1.0 / 120.0]:
			character.set_held_block(1)
			character.set_held_block(id)
			await process_frame
			for frame in range(90):
				character.animate(delta, 0.0, false, false)
			var weapon: Node3D = character.held_item.weapon_visual
			var contacts := 0
			var palm_aligned := true
			var forward_arc := true
			var max_reach := 0.0
			var previous_rotation: Quaternion = weapon.global_basis.orthonormalized().get_rotation_quaternion()
			var largest_step := 0.0
			for frame in range(ceili(Swing.duration(id) * 1.5 / delta)):
				character.animate(delta, 0.0, false, frame == 0)
				contacts += 1 if character.swing_contact else 0
				palm_aligned = palm_aligned and character.right_forearm.to_local(weapon.global_position).distance_to(Vector3(0, -0.225, 0)) < 0.001
				var tip: Vector3 = character.body.to_local(weapon.to_global(Vector3(0, 0.78 if id == 304 else (0.84 if id == 305 else 0.48), 0)))
				max_reach = maxf(max_reach, -tip.z)
				forward_arc = forward_arc and tip.z < -0.12
				var rotation: Quaternion = weapon.global_basis.orthonormalized().get_rotation_quaternion()
				largest_step = maxf(largest_step, previous_rotation.angle_to(rotation))
				previous_rotation = rotation
			check(contacts == 1 and not character.swing_cycle_running and character.swing < 0.01, "%d single click completes one stroke and recovers at %d FPS" % [id, roundi(1.0 / delta)])
			check(palm_aligned and forward_arc and max_reach > 0.65, "%d remains gripped and swings in front of the body" % id)
			check(largest_step < 0.85, "%d avoids abrupt backward wrist flips" % id)
			var held_contacts := 0
			for frame in range(ceili(Swing.duration(id) * 3.0 / delta)):
				character.animate(delta, 0.0, false, true)
				held_contacts += 1 if character.swing_contact else 0
			check(held_contacts == 3, "%d held attack completes three distinct strokes" % id)
		character.set_held_block(1)
		check(not character.swing_cycle_running, "Item change cancels the previous weapon stroke")
	character.queue_free()
	await process_frame
	var game = preload("res://scenes/Main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	for frame in range(70):
		await physics_frame
	var player = game.player
	player.set_first_person(true)
	for id in range(301, 306):
		game.inventory.bag[0] = {"id": id, "count": 1}
		player.select_slot(0)
		Input.action_press("mine")
		for frame in range(2):
			await physics_frame
		Input.action_release("mine")
		var impacts := 0
		var start: Transform3D = player.first_person_item.transform
		var maximum_motion := 0.0
		for frame in range(ceili(Swing.duration(id) * 1.4 * 60.0)):
			await physics_frame
			impacts += 1 if player.visual.swing_contact else 0
			maximum_motion = maxf(maximum_motion, start.origin.distance_to(player.first_person_item.position))
		check(impacts == 1 and not player.visual.swing_cycle_running, "%d real mouse action finishes exactly one weapon swing" % id)
		check(maximum_motion > 0.04 and player.first_person_item.visible and player.first_person_item.transform.is_finite(), "%d first-person view uses a visible weapon-specific stroke" % id)
	game.queue_free()
	await process_frame
	print("WEAPON_SWING_SMOKE_PASS: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

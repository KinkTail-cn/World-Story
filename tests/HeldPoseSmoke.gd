extends SceneTree

const Character = preload("res://scripts/player/CharacterVisual.gd")
const Inventory = preload("res://scripts/inventory/Inventory.gd")
var failures: int = 0
var checks: int = 0

class DryWorld extends Node3D:
	const SEA_LEVEL: float = 2.2
	func is_water_at(_point: Vector3) -> bool:
		return false

func _initialize() -> void:
	create_timer(20.0).timeout.connect(func(): push_error("HELD_POSE_TIMEOUT"); quit(1))
	_run.call_deferred()

func check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(description)

func _run() -> void:
	var stage := Node3D.new()
	stage.rotation = Vector3(0.08, 0.7, -0.06)
	root.add_child(stage)
	var character = Character.new()
	stage.add_child(character)
	var ids: Array = range(201, 210)
	ids.append_array(range(301, 306))
	var states := [
		["idle", 0.0, false, false, false, false],
		["walk", 4.8, false, false, false, false],
		["sprint", 7.8, false, false, false, true],
		["jump", 4.8, true, false, false, false],
		["swim", 4.2, false, true, false, false],
		["sit", 0.0, false, false, true, false]
	]
	for id in ids:
		character.set_held_block(id)
		await process_frame
		var model: Node3D = character.held_item.tool_visual if id < 300 else character.held_item.weapon_visual
		for state in states:
			for frame in range(90):
				character.animate(1.0 / 60.0, state[1], state[2], false, state[3], state[3], state[4], state[5])
			var direction: Vector3 = character.body.global_basis.orthonormalized().inverse() * model.global_basis.y.normalized()
			var prefix := "%d %s: " % [id, state[0]]
			check(direction.z < -0.2 and direction.y > 0.75, prefix + "working end points up and forward, never back toward the shoulder")
			check(character.right_forearm.to_local(model.global_position).distance_to(Vector3(0, -0.225, 0)) < 0.001, prefix + "handle stays centered in the palm")
			if state[0] in ["idle", "walk", "sprint"]:
				check(_backmost(model, character.body) < -0.15, prefix + "entire model stays ahead of torso and shoulder")
		for frame in range(60):
			character.animate(1.0 / 60.0, 0.0, false, false)
		var rest_axis: Vector3 = model.global_basis.y.normalized()
		var swing_changed := false
		for frame in range(60):
			character.animate(1.0 / 60.0, 0.0, false, true)
			swing_changed = swing_changed or model.global_basis.y.normalized().distance_to(rest_axis) > 0.3
		check(swing_changed, "%d: swing animation still moves the working end" % id)
		for frame in range(90):
			character.animate(1.0 / 60.0, 0.0, false, false)
		var recovered: Vector3 = character.body.global_basis.orthonormalized().inverse() * model.global_basis.y.normalized()
		check(recovered.z < -0.2 and recovered.y > 0.75, "%d: releasing attack returns to forward carry" % id)
	character.set_held_block(7)
	check(character.held_item.get_node("Block").visible and character.held_item.tool_visual == null and character.held_item.weapon_visual == null, "Switching back to blocks clears the long-item model")
	stage.queue_free()
	await process_frame

	var player = preload("res://scenes/Player.tscn").instantiate()
	var dry_world := DryWorld.new()
	root.add_child(dry_world)
	player.world = dry_world
	player.process_mode = Node.PROCESS_MODE_DISABLED
	root.add_child(player)
	player.inventory = Inventory.new()
	player.inventory.bag[0] = {"id": 207, "count": 1}
	player.select_slot(0)
	player.set_first_person(true)
	var first_person_model: Node3D = player.first_person_item.tool_visual
	var first_person_transform: Transform3D = first_person_model.transform
	player.first_person_item.update_third_person_grip(Basis.from_euler(Vector3(1, 2, 0.4)), 1.0)
	check(first_person_model.transform.is_equal_approx(first_person_transform), "Third-person compensation leaves camera-held models in their own coordinate system")
	check(player.first_person_item.visible and not player.visual.visible, "First-person tool remains visible")
	player.free()
	dry_world.free()
	await process_frame
	print("HELD_POSE_SMOKE_PASS: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

func _backmost(model: Node3D, torso: Node3D) -> float:
	var back := -INF
	for mesh in model.find_children("*", "MeshInstance3D", true, false):
		var bounds: AABB = mesh.get_aabb()
		for x in [0.0, 1.0]:
			for y in [0.0, 1.0]:
				for z in [0.0, 1.0]:
					var corner := bounds.position + bounds.size * Vector3(x, y, z)
					back = maxf(back, torso.to_local(mesh.to_global(corner)).z)
	return back

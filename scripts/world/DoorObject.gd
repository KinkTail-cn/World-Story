extends Node3D

const Geometry = preload("res://scripts/world/DoorGeometry.gd")
const Visual = preload("res://scripts/player/UtilityVisual.gd")
var record: Dictionary = {}
var leaves: Array[AnimatableBody3D] = []
var bodies: Array[PhysicsBody3D] = []
var tween: Tween
var applied_open: bool = false
var ready_pose: bool = false

func _ready() -> void:
	var frame := StaticBody3D.new()
	frame.collision_layer = 1
	frame.collision_mask = 2
	frame.set_meta("facility", str(record.key))
	add_child(frame)
	bodies.append(frame)
	var frame_visual = Visual.new()
	frame.add_child(frame_visual)
	frame_visual.build(510, record.item, false, 2)
	for side in [-1, 1]:
		var post := CollisionShape3D.new()
		var post_shape := BoxShape3D.new()
		post_shape.size = Vector3(0.08, 2.96, 0.16)
		post.shape = post_shape
		post.position = Vector3(float(side) * 0.96, 1.48, 0)
		frame.add_child(post)
		var leaf := AnimatableBody3D.new()
		leaf.sync_to_physics = false
		leaf.collision_layer = 1
		leaf.collision_mask = 2
		leaf.set_meta("facility", str(record.key))
		leaf.position.x = float(side) * Geometry.HINGE
		add_child(leaf)
		leaves.append(leaf)
		bodies.append(leaf)
		var visual = Visual.new()
		leaf.add_child(visual)
		visual.build(510, record.item, false, side)
		visual.position.x = -float(side) * Geometry.HINGE
		var collision := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = Geometry.LEAF_SIZE
		collision.shape = shape
		collision.position = Vector3(-float(side) * Geometry.LEAF_SIZE.x * 0.5, Geometry.LEAF_BOTTOM + Geometry.LEAF_SIZE.y * 0.5, 0)
		leaf.add_child(collision)
	update_state()

func update_state() -> void:
	var opened := bool(record.get("opened", false))
	if ready_pose and opened == applied_open: return
	if tween != null and tween.is_valid(): tween.kill()
	var target := 1.0 if opened else 0.0
	if not ready_pose:
		for index in leaves.size():
			leaves[index].rotation.y = (1.0 if index == 0 else -1.0) * target * PI * 0.5
	else:
		tween = create_tween().set_parallel(true).set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
		for index in leaves.size():
			tween.tween_property(leaves[index], "rotation:y", (1.0 if index == 0 else -1.0) * target * PI * 0.5, Geometry.DURATION).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	applied_open = opened
	ready_pose = true

func is_moving() -> bool:
	return tween != null and tween.is_running()

func excluded_rids() -> Array[RID]:
	var result: Array[RID] = []
	for body in bodies: result.append(body.get_rid())
	return result

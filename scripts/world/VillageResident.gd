extends CharacterBody3D

var record: Dictionary = {}
var world: Node3D
var actor: Node3D
var cursor: int = 0
var direction: int = 1
var rest: float = 1.0
var stuck: float = 0.0

func _ready() -> void:
	set_meta("facility", str(record.key))
	collision_layer = 1
	collision_mask = 1
	var collider := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.26
	capsule.height = 1.8
	collider.shape = capsule
	collider.position.y = 0.9
	add_child(collider)
	actor = preload("res://scripts/player/CharacterVisual.gd").new()
	add_child(actor)
	actor.held_item.hide()
	var shirt: MeshInstance3D = actor.body.get_child(0)
	var material: ShaderMaterial = shirt.material_override.duplicate()
	material.set_shader_parameter("base_color", {"farmer": Color("8c9c61"), "smith": Color("866b5c"), "trader": Color("7b6f9b"), "keeper": Color("597f8e")}.get(str(record.role), Color("778e85")))
	shirt.material_override = material
	cursor = clampi(int(record.get("patrol_index", 0)), 0, maxi(0, record.get("route", []).size() - 1))
	direction = -1 if int(record.get("patrol_direction", 1)) < 0 else 1
	rest = maxf(0, float(record.get("patrol_rest", 1.0)))

func _physics_process(delta: float) -> void:
	if world.is_loading: return
	var route: Array = record.get("route", [])
	var horizontal := Vector3.ZERO
	rest = maxf(0.0, rest - delta)
	var interacting: bool = world.life.active_interaction == str(record.key)
	if interacting and is_instance_valid(world.life.interacting_actor):
		var offset: Vector3 = world.life.interacting_actor.global_position - global_position
		actor.rotation.y = lerp_angle(actor.rotation.y, atan2(-offset.x, -offset.z), minf(1, delta * 8))
	elif rest <= 0.0 and route.size() > 1:
		var target := Vector3(route[cursor][0], route[cursor][1], route[cursor][2])
		var offset := target - global_position
		offset.y = 0
		if offset.length() < 0.16:
			cursor += direction
			if cursor >= route.size() or cursor < 0:
				direction *= -1
				cursor = clampi(cursor, 0, route.size() - 1)
				rest = 2.0
		else:
			var floor_cell := Vector3i(target.floor()) + Vector3i.DOWN
			var target_chunk: Vector2i = world._chunk_coord(floor_cell)
			if not world._active_chunks.has(target_chunk) or world.get_block(floor_cell) == 0:
				direction *= -1
				cursor = clampi(cursor + direction, 0, route.size() - 1)
				rest = 1.0
			else: horizontal = offset.normalized() * 1.1
			actor.rotation.y = lerp_angle(actor.rotation.y, atan2(-horizontal.x, -horizontal.z), minf(1, delta * 8))
	velocity.x = horizontal.x
	velocity.z = horizontal.z
	velocity.y = 0.0 if is_on_floor() else velocity.y - delta * 18.0
	var previous := global_position
	move_and_slide()
	stuck = stuck + delta if horizontal.length() > 0.5 and global_position.distance_to(previous) < 0.01 else 0.0
	if stuck > 2.0 and route.size() > 1:
		direction *= -1
		cursor = clampi(cursor + direction, 0, route.size() - 1)
		rest = 1.0
		stuck = 0.0
	if global_position.y < world.SEA_FLOOR - 5:
		for point in route:
			var position := Vector3(point[0], point[1], point[2])
			if world.get_block(Vector3i(position.floor()) + Vector3i.DOWN) != 0:
				global_position = position
				velocity = Vector3.ZERO
				break
	actor.animate(delta, horizontal.length(), not is_on_floor(), false)

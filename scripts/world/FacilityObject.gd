extends StaticBody3D

const Items = preload("res://scripts/content/VillageItems.gd")
var record: Dictionary = {}
var model: Node3D
var light: OmniLight3D
var crop_root: Node3D
var effects: Node3D
var lid_body: AnimatableBody3D
var service: Node
var preview: bool = false
var lid_query: PhysicsShapeQueryParameters3D

func _ready() -> void:
	collision_layer = 1
	collision_mask = 2
	set_meta("facility", str(record.key))
	model = preload("res://scripts/player/UtilityVisual.gd").new()
	add_child(model)
	model.build(int(record.item.id), record.item)
	var collision := CollisionShape3D.new()
	var moving_lid: bool = record.kind in ["chest", "barrel"] and model.groups.has("lid")
	collision.shape = model.collision_shape("!lid" if moving_lid else "")
	add_child(collision)
	if moving_lid:
		lid_body = AnimatableBody3D.new()
		lid_body.sync_to_physics = false
		lid_body.collision_layer = 1
		lid_body.collision_mask = 2
		lid_body.set_meta("facility", str(record.key))
		lid_body.position = model.group_pivots.lid
		add_child(lid_body)
		var lid_collision := CollisionShape3D.new()
		lid_collision.shape = model.collision_shape("lid")
		lid_collision.position = -Vector3(model.group_pivots.lid)
		lid_body.add_child(lid_collision)
		lid_query = PhysicsShapeQueryParameters3D.new()
		var lid_bounds: AABB = model.group_bounds.lid
		var lid_shape := BoxShape3D.new()
		lid_shape.size = (lid_bounds.size - Vector3.ONE * 0.006).max(Vector3.ONE * 0.005)
		lid_query.shape = lid_shape
		lid_query.margin = 0.0
		lid_query.collision_mask = 3
		lid_query.exclude = [get_rid(), lid_body.get_rid()]
	if service == null: service = get_parent()
	effects = preload("res://scripts/world/FacilityEffects.gd").new()
	effects.host = self
	effects.service = service
	effects.record = record
	effects.model = model
	effects.quiet = preview
	add_child(effects)
	update_state()

func update_state() -> void:
	if effects != null: effects.update_state()

func can_move_lid(angle: float, shift: Vector3) -> bool:
	if preview or lid_body == null: return true
	var bounds: AABB = model.group_bounds.lid
	var pivot: Vector3 = model.group_pivots.lid
	lid_query.transform = global_transform * Transform3D(Basis(Vector3.RIGHT, angle), pivot + shift) * Transform3D(Basis.IDENTITY, bounds.get_center() - pivot)
	return get_world_3d().direct_space_state.intersect_shape(lid_query, 1).is_empty()

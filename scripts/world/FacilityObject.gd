extends StaticBody3D

const Items = preload("res://scripts/content/VillageItems.gd")
var record: Dictionary = {}
var model: Node3D
var light: OmniLight3D
var crop_root: Node3D

func _ready() -> void:
	collision_layer = 1
	collision_mask = 2
	set_meta("facility", str(record.key))
	model = preload("res://scripts/player/UtilityVisual.gd").new()
	add_child(model)
	model.build(int(record.item.id), record.item)
	var collision := CollisionShape3D.new()
	collision.shape = model.collision_shape()
	add_child(collision)
	if record.kind == "lamp":
		light = OmniLight3D.new()
		light.position.y = 0.6
		light.light_color = Color("ffcf84")
		light.omni_range = 7.5
		light.light_energy = 1.4
		add_child(light)
	if record.kind == "crop":
		crop_root = Node3D.new()
		add_child(crop_root)
	update_state()

func update_state() -> void:
	if light != null:
		light.visible = bool(record.get("lit", true))
	if crop_root != null:
		var stage := int(record.get("growth_stage", 0))
		if int(crop_root.get_meta("stage", -1)) == stage: return
		crop_root.set_meta("stage", stage)
		for child in crop_root.get_children():
			crop_root.remove_child(child)
			child.queue_free()
		if stage > 0:
			for x in [-0.23, 0.23]:
				for z in [-0.23, 0.23]:
					var mesh := MeshInstance3D.new()
					mesh.mesh = preload("res://scripts/content/CubeParts.gd").mesh(Vector3(0.08, 0.12 + stage * 0.1, 0.08))
					mesh.position = Vector3(x, 0.3 + (0.12 + stage * 0.1) * 0.5, z)
					var material := StandardMaterial3D.new()
					material.albedo_color = Color("d7b65d") if stage == 3 else Color("6f9a51")
					mesh.material_override = material
					crop_root.add_child(mesh)

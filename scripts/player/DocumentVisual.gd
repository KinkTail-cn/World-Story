extends Node3D

const Cubes = preload("res://scripts/content/CubeParts.gd")
const Materials = preload("res://scripts/blueprint/BlueprintMaterials.gd")

var item_id: int = 108
var motion_enabled: bool = false
var motion_materials: Array[ShaderMaterial] = []

func _ready() -> void:
	if item_id == 108:
		_box(Vector3(0, 0.015, 0), Vector3(0.5, 0.025, 0.4), Color("82523b"))
		_box(Vector3(0, 0.04, 0), Vector3(0.46, 0.03, 0.37), Color("fff2cd"))
		_box(Vector3(0, 0.06, 0), Vector3(0.5, 0.02, 0.4), Color("bd8155"))
		_box(Vector3(-0.2, 0.072, 0), Vector3(0.035, 0.009, 0.4), Color("e3b768"))
		_box(Vector3(0.08, 0.072, 0), Vector3(0.18, 0.008, 0.08), Color("fff2cd"))
	else:
		_box(Vector3(0, 0.022, 0), Vector3(0.58, 0.016, 0.43), Color("397db3"))
		for i in range(-3, 4):
			_box(Vector3(i * 0.07, 0.032, 0), Vector3(0.004, 0.002, 0.38), Color("89bad9"))
		for i in range(-2, 3):
			_box(Vector3(0, 0.032, i * 0.075), Vector3(0.53, 0.002, 0.004), Color("89bad9"))
		_box(Vector3(0, 0.034, 0), Vector3(0.12, 0.002, 0.004), Color.WHITE)
	_box(Vector3(0.26, 0.06, 0.02), Vector3(0.026, 0.026, 0.30), Color("45392f"), false)
	_box(Vector3(0.3, 0.06, -0.13), Vector3(0.025, 0.025, 0.05), Color("e8c279"), false)

func _box(pos: Vector3, size: Vector3, tint: Color, paper: bool = true) -> MeshInstance3D:
	var mesh := Cubes.mesh(size)
	var material: Material = StandardMaterial3D.new()
	material.albedo_color = tint
	material.roughness = 0.9
	if paper and item_id == 109:
		material = Materials.create_soft({"tint": tint.to_html(false)}, "paper")
		material.set_shader_parameter("horizontal_sheet", true)
		material.set_shader_parameter("motion_uv_scale", Vector2(size.x / 0.58, size.z / 0.43))
		material.set_shader_parameter("motion_uv_offset", Vector2((pos.x - size.x * 0.5) / 0.58 + 0.5, (pos.z - size.z * 0.5) / 0.43 + 0.5))
		material.set_shader_parameter("motion_scale", 1.0 if motion_enabled else 0.0)
		motion_materials.append(material)
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.position = pos
	instance.material_override = material
	if paper and item_id == 109:
		instance.custom_aabb = mesh.get_aabb().grow(0.015)
	add_child(instance)
	return instance

func set_motion_enabled(enabled: bool) -> void:
	motion_enabled = enabled
	for material in motion_materials:
		material.set_shader_parameter("motion_scale", 1.0 if enabled else 0.0)

extends Node3D

var item_id: int = 108

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
	var pen := _box(Vector3(0.26, 0.06, 0.02), Vector3(0.026, 0.026, 0.30), Color("45392f"))
	pen.rotation.y = -0.3
	_box(Vector3(0.3, 0.06, -0.13), Vector3(0.025, 0.025, 0.05), Color("e8c279"))

func _box(pos: Vector3, size: Vector3, tint: Color) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var material := StandardMaterial3D.new()
	material.albedo_color = tint
	material.roughness = 0.9
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.position = pos
	instance.material_override = material
	add_child(instance)
	return instance

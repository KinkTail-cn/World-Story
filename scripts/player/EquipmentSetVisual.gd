extends Node3D

const Models = preload("res://scripts/player/EquipmentModels.gd")
const Sets = preload("res://scripts/content/EquipmentSets.gd")
const SHADER = preload("res://shaders/character.gdshader")
const CAPE_SHADER = preload("res://shaders/cape.gdshader")
var item_id: int = 0
var pieces: Array[MeshInstance3D] = []
var cloth_materials: Array[ShaderMaterial] = []
var cloth_wind_scale: float = 1.0

func build(id: int, character: Node3D = null) -> void:
	_clear()
	item_id = id
	var materials := {}
	var bounds := AABB()
	var first := true
	for part in Models.parts(id):
		var piece := MeshInstance3D.new()
		if part.shape == "cloth":
			cloth_wind_scale = minf(1.0, part.size.y / 0.82)
			piece.mesh = _cloth_mesh(part.size.x, part.size.y)
			var material := ShaderMaterial.new()
			material.shader = CAPE_SHADER
			material.set_shader_parameter("base_color", part.tint)
			material.set_shader_parameter("trim_color", part.trim)
			material.set_shader_parameter("emblem", part.emblem)
			piece.material_override = material
			cloth_materials.append(material)
			piece.custom_aabb = AABB(Vector3(-0.8, -1.3, -0.2), Vector3(1.6, 1.6, 1.7))
		else:
			if part.shape == "cone":
				var cone := CylinderMesh.new()
				cone.top_radius = 0.0
				cone.bottom_radius = part.size.x * 0.5
				cone.height = part.size.y
				cone.radial_segments = 4
				piece.mesh = cone
			else:
				var box := BoxMesh.new()
				box.size = part.size
				piece.mesh = box
			var color_key: Color = part.tint
			if not materials.has(color_key):
				var material := ShaderMaterial.new()
				material.shader = SHADER
				material.set_shader_parameter("base_color", color_key)
				materials[color_key] = material
			piece.material_override = materials[color_key]
		piece.name = "Set_%d_%s_%d" % [id, part.bone, pieces.size()]
		piece.position = part.pos
		piece.rotation = part.rotation
		if character != null:
			var bone: Node3D = character.get(part.bone)
			bone.add_child(piece)
		else:
			piece.position += Vector3(Models.BONE_ORIGINS[part.bone])
			add_child(piece)
			var box: AABB = piece.transform * piece.get_aabb()
			bounds = box if first else bounds.merge(box)
			first = false
		pieces.append(piece)
	if character == null and not first:
		var fit := 0.42 / maxf(bounds.size.x, maxf(bounds.size.y, bounds.size.z))
		for piece in pieces:
			piece.position = (piece.position - bounds.get_center()) * fit
			piece.scale = Vector3.ONE * fit
		rotation.y = 0.0 if Sets.slot(id) == 5 else PI

func set_wind(strength: float) -> void:
	for material in cloth_materials:
		material.set_shader_parameter("wind_strength", strength * cloth_wind_scale)

func _cloth_mesh(width: float, length: float) -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for y in range(16):
		for x in range(8):
			for corner in [Vector2(0, 0), Vector2(1, 1), Vector2(1, 0), Vector2(0, 0), Vector2(0, 1), Vector2(1, 1)]:
				var uv := Vector2((float(x) + corner.x) / 8.0, (float(y) + corner.y) / 16.0)
				surface.set_uv(uv)
				surface.set_normal(Vector3.BACK)
				surface.add_vertex(Vector3((uv.x - 0.5) * (width + uv.y * 0.06), -uv.y * length, 0))
	return surface.commit()

func _clear() -> void:
	for piece in pieces:
		if is_instance_valid(piece):
			piece.visible = false
			piece.queue_free()
	pieces.clear()
	cloth_materials.clear()

func _exit_tree() -> void:
	_clear()

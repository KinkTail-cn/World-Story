extends Node3D

const Design = preload("res://scripts/blueprint/BlueprintEquipment.gd")
const Geometry = preload("res://scripts/blueprint/BlueprintGeometry.gd")
const Materials = preload("res://scripts/blueprint/BlueprintMaterials.gd")
const Data = preload("res://scripts/blueprint/BlueprintData.gd")
var blueprint: Dictionary = {}
var pieces: Array[MeshInstance3D] = []
var source_part_count: int = 0
var icon_size: float = 0.40

func build(data: Dictionary, character: Node3D = null) -> void:
	_clear()
	if not Data.validation_error(data).is_empty():
		return
	blueprint = data.duplicate(true)
	var groups := {}
	var index := 0
	for part in Design.active_voxels(data):
		var bone := Geometry.anchor(part, str(data.get("category", "")))
		var key := "%s:%s:%s:%s" % [bone, str(part.get("mat", 1)), Materials.tint(part).to_html(), str(part.get("surface", "solid"))]
		if not groups.has(key):
			groups[key] = []
		groups[key].append(part)
		index += 1
	source_part_count = index
	var bounds := AABB()
	var first := true
	for key in groups:
		var parts: Array = groups[key]
		var part: Dictionary = parts[0]
		var category := str(data.get("category", ""))
		var bone := Geometry.anchor(part, category)
		var piece := MeshInstance3D.new()
		piece.name = "Blueprint_" + bone + "_" + str(pieces.size())
		piece.material_override = Materials.create(part)
		if parts.size() == 1:
			piece.mesh = Geometry.mesh(part)
			piece.transform = Geometry.local_transform(part, category) if character != null else Geometry.character_transform(part, category)
		else:
			piece.mesh = _merged_mesh(parts, category, character != null)
		if character != null:
			var parent: Node3D = character.get(bone)
			parent.add_child(piece)
		else:
			add_child(piece)
			var box: AABB = piece.transform * piece.mesh.get_aabb()
			bounds = box if first else bounds.merge(box)
			first = false
		pieces.append(piece)
	if character == null and not first:
		var fit := icon_size / maxf(bounds.size.x, maxf(bounds.size.y, bounds.size.z))
		for piece in pieces:
			piece.position = (piece.position - bounds.get_center()) * fit
			piece.scale = Vector3.ONE * fit

func _merged_mesh(parts: Array, category: String, worn: bool) -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for part in parts:
		var mesh: Mesh = Geometry.mesh(part)
		var arrays: Array = mesh.surface_get_arrays(0)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
		var transform := Geometry.local_transform(part, category) if worn else Geometry.character_transform(part, category)
		for corner in range(indices.size() if not indices.is_empty() else vertices.size()):
			var index: int = indices[corner] if not indices.is_empty() else corner
			surface.set_normal((transform.basis * normals[index]).normalized())
			surface.set_uv(Vector2.ZERO)
			surface.add_vertex(transform * vertices[index])
	return surface.commit()

func hide_pieces() -> void:
	for piece in pieces:
		if is_instance_valid(piece):
			piece.visible = false

func _clear() -> void:
	for piece in pieces:
		if is_instance_valid(piece):
			piece.visible = false
			piece.queue_free()
	pieces.clear()
	source_part_count = 0

func _exit_tree() -> void:
	_clear()

extends Node3D

const Design = preload("res://scripts/blueprint/BlueprintEquipment.gd")
const Geometry = preload("res://scripts/blueprint/BlueprintGeometry.gd")
const Materials = preload("res://scripts/blueprint/BlueprintMaterials.gd")
const Data = preload("res://scripts/blueprint/BlueprintData.gd")
const Definition = preload("res://scripts/character/CharacterDefinition.gd")
var blueprint: Dictionary = {}
var pieces: Array[MeshInstance3D] = []
var cape_materials: Array[ShaderMaterial] = []
var motion_materials: Array[ShaderMaterial] = []
var motion_enabled: bool = true
var wind_strength: float = 0.0
var source_part_count: int = 0
var icon_size: float = 0.40
var _origins: Dictionary = {}
var _reference: Dictionary = {}

func build(data: Dictionary, character: Node3D = null) -> void:
	_clear()
	if not Data.validation_error(data).is_empty():
		return
	blueprint = data.duplicate(true)
	_reference = data.get("rig_reference", {})
	var category := str(data.get("category", ""))
	var moving_cape := character != null and category == "披风"
	var groups := {}
	var index := 0
	var cape_bounds := AABB()
	var motion_bounds := {}
	var active: Array = Design.active_voxels(data)
	_origins = {}
	var target_reference: Dictionary = character.character_definition if character != null and "character_definition" in character else {}
	if character != null and (not target_reference.is_empty() or not _reference.is_empty()):
		_origins = Definition.rest_origins(target_reference)
		var fitted: Array[Dictionary] = []
		var budget := maxi(1, mini(64, Definition.MAX_CUBES / maxi(1, active.size())))
		var fits := {}
		for source in active:
			var bone := Geometry.anchor(source, category,_reference)
			if not fits.has(bone):
				fits[bone] = Definition.local_fit(_reference,target_reference,bone)
			var center := Geometry.vector(source.offset) if source.has("offset") else Geometry.local_transform(source,category,_reference).origin
			for cell in Definition.voxelize_box(center, Geometry.dimensions(source), fits[bone], budget):
				var copy: Dictionary = source.duplicate(true)
				copy["_local_center"] = Definition.array(cell.center)
				copy["dimensions"] = Geometry.array(Vector3.ONE * float(cell.edge))
				fitted.append(copy)
		active = fitted
	for part in active:
		var bone := Geometry.anchor(part, category,_reference)
		var profile := str(part.get("motion", "fixed")) if character != null else "fixed"
		var motion_key := _motion_key(part, bone, profile)
		if profile != "fixed" and not moving_cape:
			var box := AABB(_character_transform(part, category).origin, Vector3.ZERO)
			motion_bounds[motion_key] = box if not motion_bounds.has(motion_key) else AABB(motion_bounds[motion_key]).merge(box)
		if moving_cape:
			var box := AABB(_character_transform(part, category).origin, Vector3.ZERO)
			cape_bounds = box if index == 0 else cape_bounds.merge(box)
		var key := "%s:%s:%s:%s" % [bone, str(part.get("mat", 1)), Materials.tint(part).to_html(), str(part.get("surface", "solid"))]
		if profile != "fixed" and not moving_cape:
			key += ":" + motion_key
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
		var bone := Geometry.anchor(part, category,_reference)
		var profile := str(part.get("motion", "fixed")) if character != null else "fixed"
		var soft := profile != "fixed" and not moving_cape
		var free_bounds: AABB = motion_bounds.get(_motion_key(part, bone, profile), AABB())
		var piece := MeshInstance3D.new()
		piece.name = "Blueprint_" + bone + "_" + str(pieces.size())
		piece.material_override = Materials.create_cape(part) if moving_cape else Materials.create(part)
		if soft:
			piece.material_override = Materials.create_soft(part, profile)
			piece.material_override.set_shader_parameter("motion_length", clampf(free_bounds.size.y, 0.005, 0.8))
			piece.material_override.set_shader_parameter("outward_sign", -1.0 if free_bounds.get_center().z < 0.0 else 1.0)
		if soft or moving_cape:
			motion_materials.append(piece.material_override)
			piece.material_override.set_shader_parameter("motion_scale", 1.0 if motion_enabled else 0.0)
			piece.material_override.set_shader_parameter("wind_strength", wind_strength)
		if moving_cape:
			cape_materials.append(piece.material_override)
			piece.material_override.set_shader_parameter("cape_length", clampf(cape_bounds.size.y, 0.005, 1.6))
		if parts.size() == 1 and not moving_cape and not soft:
			piece.mesh = Geometry.mesh(part)
			piece.transform = _local_transform(part, category) if character != null else Geometry.character_transform(part, category,_reference)
		else:
			piece.mesh = _merged_mesh(parts, category, character != null, moving_cape or soft, cape_bounds if moving_cape else free_bounds, profile == "feather" and soft)
		if moving_cape:
			piece.custom_aabb = piece.mesh.get_aabb().grow(1.6)
		elif soft:
			piece.custom_aabb = piece.mesh.get_aabb().grow(0.16)
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

func _motion_key(part: Dictionary, bone: String, profile: String) -> String:
	return bone + ":" + profile + ":" + str(part.get("motion_group", "custom"))

func _local_transform(part: Dictionary, category: String) -> Transform3D:
	return Transform3D(Basis.IDENTITY, Definition.vector(part._local_center)) if part.has("_local_center") else Geometry.local_transform(part, category,_reference)

func _character_transform(part: Dictionary, category: String) -> Transform3D:
	if part.has("_local_center"):
		return Transform3D(Basis.IDENTITY, Vector3(_origins[Geometry.anchor(part, category,_reference)]) + Definition.vector(part._local_center))
	return Geometry.character_transform(part, category,_reference)

func _merged_mesh(parts: Array, category: String, worn: bool, cape: bool = false, cape_bounds: AABB = AABB(), pinned_bottom: bool = false) -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for part in parts:
		var mesh: Mesh = Geometry.mesh(part)
		var arrays: Array = mesh.surface_get_arrays(0)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
		var transform := _local_transform(part, category) if worn else Geometry.character_transform(part, category,_reference)
		var uv := Vector2.ZERO
		if cape:
			var center := _character_transform(part, category).origin
			uv = Vector2((center.x - cape_bounds.position.x) / maxf(cape_bounds.size.x, 0.000001), (cape_bounds.end.y - center.y) / maxf(cape_bounds.size.y, 0.000001))
			if pinned_bottom:
				uv.y = (center.y - cape_bounds.position.y) / maxf(cape_bounds.size.y, 0.000001)
		for corner in range(indices.size() if not indices.is_empty() else vertices.size()):
			var index: int = indices[corner] if not indices.is_empty() else corner
			surface.set_normal((transform.basis * normals[index]).normalized())
			surface.set_uv(uv)
			surface.add_vertex(transform * vertices[index])
	return surface.commit()

func set_wind(strength: float) -> void:
	wind_strength = clampf(strength, 0.0, 2.0)
	for material in motion_materials:
		material.set_shader_parameter("wind_strength", wind_strength)

func set_motion_enabled(enabled: bool) -> void:
	motion_enabled = enabled
	for material in motion_materials:
		material.set_shader_parameter("motion_scale", 1.0 if enabled else 0.0)

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
	cape_materials.clear()
	motion_materials.clear()
	source_part_count = 0

func _exit_tree() -> void:
	_clear()

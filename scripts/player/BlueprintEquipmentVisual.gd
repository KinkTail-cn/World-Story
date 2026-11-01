extends Node3D

const Design = preload("res://scripts/blueprint/BlueprintEquipment.gd")
const SHADER = preload("res://shaders/character.gdshader")
var blueprint: Dictionary = {}
var pieces: Array[MeshInstance3D] = []

func build(data: Dictionary, character: Node3D = null) -> void:
	_clear()
	blueprint = data.duplicate(true)
	var materials := {}
	var bounds := AABB()
	var first := true
	for voxel in Design.active_voxels(data):
		var material_id := int(voxel.get("mat", 0))
		if material_id < 1 or material_id > 8:
			continue
		if not materials.has(material_id):
			var material := ShaderMaterial.new()
			material.shader = SHADER
			material.set_shader_parameter("base_color", Design.MATERIAL_COLORS[material_id - 1])
			materials[material_id] = material
		var extent: float = Design.Data.VOXEL_SIZE * Design.size_scale(int(voxel.get("size", 1)))
		var pos := Design.character_position(data, voxel)
		var mesh := BoxMesh.new()
		mesh.size = Vector3.ONE * extent
		var piece := MeshInstance3D.new()
		piece.mesh = mesh
		piece.material_override = materials[material_id]
		if character != null:
			var attachment := _attachment(character, str(data.get("category", "")), pos)
			attachment.node.add_child(piece)
			piece.position = pos - Vector3(attachment.origin)
		else:
			add_child(piece)
			piece.position = pos
		pieces.append(piece)
		var box := AABB(pos - Vector3.ONE * extent * 0.5, Vector3.ONE * extent)
		bounds = box if first else bounds.merge(box)
		first = false
	if character == null and not first:
		var fit: float = 0.40 / maxf(bounds.size.x, maxf(bounds.size.y, bounds.size.z))
		for piece in pieces:
			piece.position = (piece.position - bounds.get_center()) * fit
			piece.scale = Vector3.ONE * fit

func _attachment(character: Node3D, category: String, pos: Vector3) -> Dictionary:
	var right := pos.x >= 0.0
	match category:
		"头部装备": return {"node": character.head, "origin": Vector3(0, 1.575, 0)}
		"手套":
			return {"node": character.right_forearm if right else character.left_forearm, "origin": Vector3(0.3375 if right else -0.3375, 1.01, 0)}
		"裤甲", "鞋子":
			var lower := category == "鞋子" or pos.y < 0.335
			var bone: Node3D = (character.right_lower_leg if right else character.left_lower_leg) if lower else (character.right_leg if right else character.left_leg)
			return {"node": bone, "origin": Vector3(0.1125 if right else -0.1125, 0.335 if lower else 0.675, 0)}
		"盔甲":
			if absf(pos.x) > 0.26:
				var lower := pos.y < 1.01
				var bone: Node3D = (character.right_forearm if right else character.left_forearm) if lower else (character.right_arm if right else character.left_arm)
				return {"node": bone, "origin": Vector3(0.3375 if right else -0.3375, 1.01 if lower else 1.35, 0)}
	return {"node": character.body, "origin": Vector3.ZERO}

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

func _exit_tree() -> void:
	_clear()

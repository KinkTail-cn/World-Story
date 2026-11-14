extends RefCounted

const Definition = preload("res://scripts/character/CharacterDefinition.gd")
const BodyMesh = preload("res://scripts/character/CharacterBodyMesh.gd")
var pieces: Array[GeometryInstance3D] = []
var groups: Dictionary = {}
var locations: Dictionary = {}
var _values: Dictionary = {}
var _rig: Dictionary = {}
var _cube_mesh := BoxMesh.new()
var _material = BodyMesh.material()

func build(data: Dictionary, rig: Dictionary) -> void:
	clear()
	_rig = rig
	_cube_mesh.size = Vector3.ONE
	var counts := {}
	for cube in data.cubes:
		counts[cube.bone] = int(counts.get(cube.bone,0)) + 1
	for bone in counts:
		_group(str(bone),int(counts[bone]))
	update(data.cubes,[])

func update(updated: Array, removed: Array) -> void:
	for id in removed:
		_remove(str(id))
	var touched := {}
	for cube in updated:
		var id := str(cube.id)
		var bone := str(cube.bone)
		if locations.has(id) and str(locations[id].bone) != bone:
			_remove(id)
		var group := _group(bone)
		var ids: Array = group.ids
		if not locations.has(id):
			_reserve(group,ids.size()+1)
			locations[id] = {"bone":bone,"index":ids.size()}
			ids.append(id)
		var edge := 0.0 if bool(cube.get("hidden",false)) else float(cube.edge)
		var transform := Transform3D(Basis.IDENTITY.scaled(Vector3.ONE*edge),Definition.vector(cube.center))
		var color := Color(cube.color)
		_values[id] = {"transform":transform,"color":color}
		var index: int = locations[id].index
		var mesh: MultiMesh = group.node.multimesh
		mesh.set_instance_transform(index,transform)
		mesh.set_instance_color(index,color)
		touched[bone] = true
	for bone in touched:
		groups[bone].node.multimesh.visible_instance_count = groups[bone].ids.size()

func _group(bone: String, required: int = 0) -> Dictionary:
	if groups.has(bone):
		return groups[bone]
	var piece := MultiMeshInstance3D.new()
	piece.name = "CharacterEditCubes_"+bone
	piece.multimesh = MultiMesh.new()
	piece.multimesh.transform_format = MultiMesh.TRANSFORM_3D
	piece.multimesh.use_colors = true
	piece.multimesh.mesh = _cube_mesh
	piece.material_override = _material
	_rig[bone].add_child(piece)
	pieces.append(piece)
	var group := {"node":piece,"ids":[]}
	groups[bone] = group
	_reserve(group,maxi(32,required))
	return group

func _reserve(group: Dictionary, required: int) -> void:
	var mesh: MultiMesh = group.node.multimesh
	if mesh.instance_count >= required:
		return
	var capacity := maxi(32,mesh.instance_count)
	while capacity < required:
		capacity *= 2
	mesh.instance_count = capacity
	var ids: Array = group.ids
	for index in ids.size():
		var value: Dictionary = _values[ids[index]]
		mesh.set_instance_transform(index,value.transform)
		mesh.set_instance_color(index,value.color)
	mesh.visible_instance_count = ids.size()

func _remove(id: String) -> void:
	if not locations.has(id):
		return
	var location: Dictionary = locations[id]
	var group: Dictionary = groups[location.bone]
	var ids: Array = group.ids
	var index: int = location.index
	var last := str(ids.back())
	if index != ids.size()-1:
		ids[index] = last
		locations[last].index = index
		var value: Dictionary = _values[last]
		group.node.multimesh.set_instance_transform(index,value.transform)
		group.node.multimesh.set_instance_color(index,value.color)
	ids.pop_back()
	group.node.multimesh.visible_instance_count = ids.size()
	locations.erase(id)
	_values.erase(id)

func clear() -> void:
	for piece in pieces:
		if is_instance_valid(piece):
			piece.get_parent().remove_child(piece)
			piece.queue_free()
	pieces.clear()
	groups.clear()
	locations.clear()
	_values.clear()

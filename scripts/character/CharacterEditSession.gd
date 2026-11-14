extends RefCounted

signal changed
signal selection_changed
const Definition = preload("res://scripts/character/CharacterDefinition.gd")
const LIMIT: int = 64
var model: Dictionary = {}
var reference: Dictionary = {}
var selection: Array[String] = []
var undo_stack: Array[PackedByteArray] = []
var redo_stack: Array[PackedByteArray] = []
var saved_json: String = ""
var last_error: String = ""
var _next_id: int = 0
var read_only: bool = false

func bind(data: Dictionary) -> void:
	model = data.duplicate(true)
	reference = data.duplicate(true)
	selection.clear()
	undo_stack.clear()
	redo_stack.clear()
	mark_saved()
	changed.emit()
	selection_changed.emit()

func snapshot() -> PackedByteArray:
	return var_to_bytes({"model": model, "reference": reference, "selection": selection}).compress(FileAccess.COMPRESSION_DEFLATE)

func _restore(bytes: PackedByteArray) -> void:
	var state: Dictionary = bytes_to_var(bytes.decompress_dynamic(64 * 1024 * 1024, FileAccess.COMPRESSION_DEFLATE))
	model = state.model
	reference = state.reference
	selection.assign(state.selection)

func record(before: PackedByteArray, validate: bool = true) -> bool:
	if read_only:
		last_error = "动作预览中，请先切回静止建模"
		_restore(before)
		changed.emit()
		selection_changed.emit()
		return false
	last_error = Definition.validation_error(model) if validate else ""
	if not last_error.is_empty():
		_restore(before)
		changed.emit()
		selection_changed.emit()
		return false
	var previous: Dictionary = bytes_to_var(before.decompress_dynamic(64 * 1024 * 1024, FileAccess.COMPRESSION_DEFLATE))
	if previous.model == model:
		reference = previous.reference
		selection_changed.emit()
		return false
	undo_stack.append(before)
	if undo_stack.size() > LIMIT:
		undo_stack.pop_front()
	redo_stack.clear()
	changed.emit()
	selection_changed.emit()
	return true

func select(ids: Array, additive: bool = false) -> void:
	if not additive:
		selection.clear()
	for id in ids:
		if find(str(id)) < 0:
			continue
		if additive and id in selection:
			selection.erase(str(id))
		elif str(id) not in selection:
			selection.append(str(id))
	selection_changed.emit()

func find(id: String) -> int:
	for i in model.get("cubes", []).size():
		if str(model.cubes[i].id) == id:
			return i
	return -1

func _id() -> String:
	while find("cube_%d" % _next_id) >= 0:
		_next_id += 1
	var value := "cube_%d" % _next_id
	_next_id += 1
	return value

func add(bone: String, center: Vector3, edge: float, color: Color) -> bool:
	var before := snapshot()
	var id := _id()
	model.cubes.append({"id": id, "bone": bone, "center": Definition.array(center), "edge": edge, "color": color.to_html(false)})
	selection = [id]
	reference = model.duplicate(true)
	return record(before)

func erase_selected() -> bool:
	var remaining: Array = model.cubes.filter(func(cube): return cube.id not in selection or bool(cube.get("locked", false)))
	if remaining.is_empty():
		last_error = "人物至少需要保留一个方块"
		return false
	var before := snapshot()
	model.cubes = remaining
	selection.clear()
	reference = model.duplicate(true)
	return record(before)

func set_properties(values: Dictionary) -> bool:
	var before := snapshot()
	var origins := Definition.rest_origins(model)
	for id in selection:
		var index := find(id)
		if index < 0:
			continue
		var cube: Dictionary = model.cubes[index]
		if bool(cube.get("locked", false)):
			for flag in ["hidden","locked"]:
				if values.has(flag):
					cube[flag] = values[flag]
			continue
		if values.has("bone") and str(values.bone) in Definition.BONES:
			var center: Vector3 = origins[cube.bone] + Definition.vector(cube.center)
			cube.bone = str(values.bone)
			cube.center = Definition.array(center - Vector3(origins[cube.bone]))
		for key in ["center", "edge", "color", "hidden", "locked"]:
			if values.has(key):
				cube[key] = values[key]
	reference = model.duplicate(true)
	return record(before)

func translate_selected(delta: Vector3) -> bool:
	var before := snapshot()
	for id in selection:
		var index := find(id)
		if index >= 0 and not bool(model.cubes[index].get("locked", false)):
			model.cubes[index].center = Definition.array(Definition.vector(model.cubes[index].center) + delta)
	reference = model.duplicate(true)
	return record(before)

func duplicate_selected(mirror: bool = false) -> bool:
	var before := snapshot()
	var originals: Array = model.cubes.duplicate(true)
	var origins := Definition.rest_origins(model)
	var created: Array[String] = []
	for cube in originals:
		if cube.id not in selection or bool(cube.get("locked", false)):
			continue
		var copy: Dictionary = cube.duplicate(true)
		copy.id = _id()
		if mirror:
			var pos: Vector3 = origins[cube.bone] + Definition.vector(cube.center)
			pos.x = -pos.x
			copy.bone = mirror_bone(str(cube.bone))
			copy.center = Definition.array(pos - Vector3(origins[copy.bone]))
		else:
			copy.center = Definition.array(Definition.vector(copy.center) + Vector3.RIGHT * float(copy.edge))
		model.cubes.append(copy)
		created.append(copy.id)
	selection = created
	reference = model.duplicate(true)
	return record(before)

static func mirror_bone(bone: String) -> String:
	return bone.replace("left_", "right_") if bone.begins_with("left_") else (bone.replace("right_", "left_") if bone.begins_with("right_") else bone)

func set_parameter(key: String, value: float, reshape: bool = true) -> bool:
	if not Definition.DEFAULTS.has(key):
		return false
	return set_parameters({key: value}, reshape)

func set_parameters(values: Dictionary, reshape: bool = true) -> bool:
	var before := snapshot()
	var previous := {"parameters": model.parameters.duplicate(), "joints": model.joints.duplicate(true)}
	model.parameters.merge(values, true)
	last_error = Definition.validation_error(model)
	if not last_error.is_empty():
		_restore(before)
		changed.emit()
		return false
	var old_base := Definition.rest_origins({"parameters": previous.parameters})
	var new_base := Definition.rest_origins({"parameters": model.parameters})
	var factor := Definition.unit(model) / Definition.unit(previous)
	for bone in model.joints:
		model.joints[bone] = Definition.array(Vector3(new_base[bone]) + (Definition.vector(previous.joints[bone]) - Vector3(old_base[bone])) * factor)
	Definition.normalize_joints(model)
	last_error = Definition.validation_error(model)
	if not last_error.is_empty():
		_restore(before)
		changed.emit()
		return false
	for key in model.sockets:
		var socket: Dictionary = model.sockets[key]
		socket.offset = Definition.array(Definition.local_fit(previous, model, str(socket.bone)) * Definition.vector(socket.offset))
	if reshape:
		model.cubes = Definition.reshape(reference, model)
	selection.clear()
	return record(before)

func move_joint(bone: String, position: Vector3, symmetric: bool = true, reshape: bool = true) -> bool:
	if bone == "body" or bone not in Definition.BONES:
		return false
	var before := snapshot()
	var origins := Definition.rest_origins(model)
	if Vector3(origins[bone]).is_equal_approx(position):
		last_error = "关节位置未改变"
		return false
	_move_branch(bone, position - Vector3(origins[bone]), origins)
	if symmetric:
		var other := mirror_bone(bone)
		if other != bone:
			var opposite := Vector3(-position.x, position.y, position.z)
			_move_branch(other, opposite - Vector3(origins[other]), origins)
	Definition.normalize_joints(model)
	last_error = Definition.validation_error(model)
	if not last_error.is_empty():
		_restore(before)
		changed.emit()
		return false
	if reshape:
		model.cubes = Definition.reshape(reference, model)
	selection.clear()
	return record(before)

func _move_branch(bone: String, delta: Vector3, origins: Dictionary) -> void:
	for candidate in Definition.BONES:
		var ancestor: String = candidate
		while not ancestor.is_empty():
			if ancestor == bone:
				model.joints[candidate] = Definition.array(Vector3(origins[candidate]) + delta)
				break
			ancestor = Definition.PARENTS[ancestor]

func set_socket(key: String, offset: Vector3) -> bool:
	if key not in Definition.SOCKETS:
		return false
	var before := snapshot()
	model.sockets[key].offset = Definition.array(offset)
	return record(before)

func rename(value: String) -> bool:
	var before := snapshot()
	model.name = value.strip_edges()
	return record(before)

func undo() -> bool:
	if read_only or undo_stack.is_empty():
		return false
	redo_stack.append(snapshot())
	_restore(undo_stack.pop_back())
	changed.emit()
	selection_changed.emit()
	return true

func redo() -> bool:
	if read_only or redo_stack.is_empty():
		return false
	undo_stack.append(snapshot())
	_restore(redo_stack.pop_back())
	changed.emit()
	selection_changed.emit()
	return true

func dirty() -> bool:
	return JSON.stringify(model) != saved_json

func mark_saved() -> void:
	saved_json = JSON.stringify(model)

func restore_snapshot(before: PackedByteArray) -> void:
	_restore(before)
	changed.emit()
	selection_changed.emit()

func preview_translation(before: PackedByteArray, delta: Vector3) -> void:
	_restore(before)
	for id in selection:
		var index := find(id)
		if index >= 0 and not bool(model.cubes[index].get("locked", false)):
			model.cubes[index].center = Definition.array(Definition.vector(model.cubes[index].center) + delta)
	reference = model.duplicate(true)
	changed.emit()

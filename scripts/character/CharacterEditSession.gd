extends RefCounted

signal changed
signal selection_changed
const Definition = preload("res://scripts/character/CharacterDefinition.gd")
const LIMIT: int = 64
var model: Dictionary = {}
var reference: Dictionary = {}
var selection: Array[String] = []
var undo_stack: Array[Dictionary] = []
var redo_stack: Array[Dictionary] = []
var saved_json: String = ""
var last_error: String = ""
var _next_id: int = 0
var read_only: bool = false
var last_change: Dictionary = {"full":true}
var _indices: Dictionary = {}
var _reference_dirty: bool = false
var _translation_snapshot := PackedByteArray()
var _translation_state: Dictionary = {}

func bind(data: Dictionary) -> void:
	model = data.duplicate(true)
	reference = data.duplicate(true)
	_reference_dirty = false
	_reindex()
	selection.clear()
	undo_stack.clear()
	redo_stack.clear()
	mark_saved()
	_emit_full()

func snapshot() -> PackedByteArray:
	var raw := var_to_bytes({"model":model,"reference":reference,"reference_dirty":_reference_dirty,"selection":selection})
	var result := PackedByteArray()
	result.resize(4)
	result.encode_u32(0,raw.size())
	result.append_array(raw.compress(FileAccess.COMPRESSION_FASTLZ))
	return result

func _unpack(bytes: PackedByteArray) -> Dictionary:
	return bytes_to_var(bytes.slice(4).decompress(bytes.decode_u32(0),FileAccess.COMPRESSION_FASTLZ))

func _restore(bytes: PackedByteArray) -> void:
	var state := _unpack(bytes)
	model = state.model
	reference = state.reference
	_reference_dirty = bool(state.get("reference_dirty",false))
	selection.assign(state.selection)
	_reindex()
	_translation_snapshot = PackedByteArray()

func record(before: PackedByteArray, validate: bool = true) -> bool:
	if read_only:
		last_error = "动作预览中，请先切回静止建模"
		_restore(before)
		_emit_full()
		return false
	last_error = Definition.validation_error(model) if validate else ""
	if not last_error.is_empty():
		_restore(before)
		_emit_full()
		return false
	var previous := _unpack(before)
	if previous.model == model:
		reference = previous.reference
		_reference_dirty = bool(previous.get("reference_dirty",false))
		selection_changed.emit()
		return false
	_reindex()
	_push_history({"kind":"snapshot","state":before})
	_emit_full()
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
	return int(_indices.get(id,-1))

func _reindex() -> void:
	_indices.clear()
	for index in model.get("cubes",[]).size():
		_indices[str(model.cubes[index].id)] = index

func _id() -> String:
	while find("cube_%d" % _next_id) >= 0:
		_next_id += 1
	var value := "cube_%d" % _next_id
	_next_id += 1
	return value

func add(bone: String, center: Vector3, edge: float, color: Color) -> bool:
	var id := _id()
	var cube := {"id":id,"bone":bone,"center":Definition.array(center),"edge":edge,"color":color.to_html(false)}
	return _commit_cubes([{"index":model.cubes.size(),"before":{},"after":cube}],[id])

func erase_selected() -> bool:
	var patches: Array = []
	for id in selection:
		var index := find(id)
		if index >= 0 and not bool(model.cubes[index].get("locked",false)):
			patches.append({"index":index,"before":model.cubes[index].duplicate(true),"after":{}})
	return _commit_cubes(patches,[])

func set_properties(values: Dictionary) -> bool:
	var origins := Definition.rest_origins(model)
	var patches: Array = []
	for id in selection:
		var index := find(id)
		if index < 0:
			continue
		var cube: Dictionary = model.cubes[index].duplicate(true)
		if bool(cube.get("locked", false)):
			for flag in ["hidden","locked"]:
				if values.has(flag):
					cube[flag] = values[flag]
		elif values.has("bone") and str(values.bone) in Definition.BONES:
			var center: Vector3 = origins[cube.bone] + Definition.vector(cube.center)
			cube.bone = str(values.bone)
			cube.center = Definition.array(center - Vector3(origins[cube.bone]))
		if not bool(model.cubes[index].get("locked",false)):
			for key in ["center","edge","color","hidden","locked"]:
				if values.has(key):
					cube[key] = values[key]
		patches.append({"index":index,"before":model.cubes[index].duplicate(true),"after":cube})
	return _commit_cubes(patches,selection)

func translate_selected(delta: Vector3) -> bool:
	var state := begin_translation()
	preview_patch_translation(state,delta)
	return commit_translation(state)

func duplicate_selected(mirror: bool = false) -> bool:
	var origins := Definition.rest_origins(model)
	var created: Array[String] = []
	var patches: Array = []
	for id in selection:
		var index := find(id)
		if index < 0 or bool(model.cubes[index].get("locked",false)):
			continue
		var cube: Dictionary = model.cubes[index]
		var copy: Dictionary = cube.duplicate(true)
		copy.id = _id()
		if mirror:
			var pos: Vector3 = origins[cube.bone] + Definition.vector(cube.center)
			pos.x = -pos.x
			copy.bone = mirror_bone(str(cube.bone))
			copy.center = Definition.array(pos - Vector3(origins[copy.bone]))
		else:
			copy.center = Definition.array(Definition.vector(copy.center) + Vector3.RIGHT * float(copy.edge))
		patches.append({"index":model.cubes.size()+patches.size(),"before":{},"after":copy})
		created.append(copy.id)
	return _commit_cubes(patches,created)

static func mirror_bone(bone: String) -> String:
	return bone.replace("left_", "right_") if bone.begins_with("left_") else (bone.replace("right_", "left_") if bone.begins_with("right_") else bone)

func set_parameter(key: String, value: float, reshape: bool = true) -> bool:
	if not Definition.DEFAULTS.has(key):
		return false
	return set_parameters({key: value}, reshape)

func set_parameters(values: Dictionary, reshape: bool = true) -> bool:
	var before := snapshot()
	if reshape:
		_ensure_reference()
	var previous := {"parameters": model.parameters.duplicate(), "joints": model.joints.duplicate(true)}
	model.parameters.merge(values, true)
	last_error = Definition.validation_error(model)
	if not last_error.is_empty():
		_restore(before)
		_emit_full()
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
		_emit_full()
		return false
	for key in model.sockets:
		var socket: Dictionary = model.sockets[key]
		socket.offset = Definition.array(Definition.local_fit(previous, model, str(socket.bone)) * Definition.vector(socket.offset))
	if reshape:
		model.cubes = Definition.reshape(reference, model)
	else:
		_reference_dirty = true
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
	if reshape:
		_ensure_reference()
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
		_emit_full()
		return false
	if reshape:
		model.cubes = Definition.reshape(reference, model)
	else:
		_reference_dirty = true
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
	var entry: Dictionary = undo_stack.pop_back()
	if entry.kind == "cubes":
		redo_stack.append(entry)
		_apply_cube_history(entry,false)
	else:
		redo_stack.append({"kind":"snapshot","state":snapshot()})
		_restore(entry.state)
		_emit_full()
	return true

func redo() -> bool:
	if read_only or redo_stack.is_empty():
		return false
	var entry: Dictionary = redo_stack.pop_back()
	if entry.kind == "cubes":
		undo_stack.append(entry)
		_apply_cube_history(entry,true)
	else:
		undo_stack.append({"kind":"snapshot","state":snapshot()})
		_restore(entry.state)
		_emit_full()
	return true

func dirty() -> bool:
	return JSON.stringify(model) != saved_json

func mark_saved() -> void:
	saved_json = JSON.stringify(model)

func restore_snapshot(before: PackedByteArray) -> void:
	_restore(before)
	_emit_full()

func preview_translation(before: PackedByteArray, delta: Vector3) -> void:
	if before != _translation_snapshot:
		var source := _unpack(before)
		var patches: Array = []
		var selected := {}
		for id in source.selection:
			selected[id] = true
		for index in source.model.cubes.size():
			var cube: Dictionary = source.model.cubes[index]
			if selected.has(cube.id) and not bool(cube.get("locked",false)):
				patches.append({"index":index,"before":cube})
		_translation_state = {"patches":patches,"selection":source.selection,"reference":source.reference,"reference_dirty":source.get("reference_dirty",false)}
		_translation_snapshot = before
	preview_patch_translation(_translation_state,delta)

func _ensure_reference() -> void:
	if _reference_dirty:
		reference = model.duplicate(true)
		_reference_dirty = false

func _emit_full() -> void:
	last_change = {"full":true}
	changed.emit()
	selection_changed.emit()

func _push_history(entry: Dictionary) -> void:
	undo_stack.append(entry)
	if undo_stack.size() > LIMIT:
		undo_stack.pop_front()
	redo_stack.clear()
	_translation_snapshot = PackedByteArray()

func _commit_cubes(source: Array, next_selection: Array, initial: Dictionary = {}) -> bool:
	last_error = ""
	if read_only:
		last_error = "动作预览中，请先切回静止建模"
		return false
	var patches: Array = []
	var count: int = model.cubes.size()
	for patch in source:
		if patch.before == patch.after:
			continue
		if not patch.after.is_empty():
			last_error = Definition.cube_validation_error(patch.after)
			if not last_error.is_empty():
				return false
		count += (1 if patch.before.is_empty() else 0) - (1 if patch.after.is_empty() else 0)
		patches.append(patch)
	if count < 1 or count > Definition.MAX_CUBES:
		last_error = "人物需要 1 至 16384 个立方体"
		return false
	if patches.is_empty():
		if not initial.is_empty():
			reference = initial.reference
			_reference_dirty = initial.reference_dirty
		return false
	patches.sort_custom(func(a: Dictionary,b: Dictionary): return int(a.index) < int(b.index))
	var state: Dictionary = initial if not initial.is_empty() else {"selection":selection.duplicate(),"reference":reference,"reference_dirty":_reference_dirty}
	var entry := {"kind":"cubes","patches":patches,"selection_before":state.selection.duplicate(),"selection_after":next_selection.duplicate(),"reference_before":state.reference,"reference_dirty_before":state.reference_dirty,"reference_after":state.reference,"reference_dirty_after":true}
	_apply_cube_patches(patches,true)
	selection.assign(next_selection)
	reference = state.reference
	_reference_dirty = true
	_push_history(entry)
	_emit_cube_change(patches,true)
	return true

func _apply_cube_patches(patches: Array, forward: bool) -> void:
	var reindex_needed := false
	for position in range(patches.size()-1,-1,-1):
		var patch: Dictionary = patches[position]
		var value: Dictionary = patch.after if forward else patch.before
		var old: Dictionary = patch.before if forward else patch.after
		if value.is_empty():
			reindex_needed = reindex_needed or int(patch.index) != model.cubes.size()-1
			model.cubes.remove_at(int(patch.index))
			_indices.erase(str(old.id))
		elif not old.is_empty():
			model.cubes[int(patch.index)] = value.duplicate(true)
	for patch in patches:
		var value: Dictionary = patch.after if forward else patch.before
		var old: Dictionary = patch.before if forward else patch.after
		if old.is_empty() and not value.is_empty():
			reindex_needed = reindex_needed or int(patch.index) != model.cubes.size()
			model.cubes.insert(int(patch.index),value.duplicate(true))
			_indices[str(value.id)] = int(patch.index)
	if reindex_needed:
		_reindex()

func _apply_cube_history(entry: Dictionary, forward: bool) -> void:
	_apply_cube_patches(entry.patches,forward)
	selection.assign(entry.selection_after if forward else entry.selection_before)
	reference = entry.reference_after if forward else entry.reference_before
	_reference_dirty = entry.reference_dirty_after if forward else entry.reference_dirty_before
	_translation_snapshot = PackedByteArray()
	_emit_cube_change(entry.patches,forward)

func _emit_cube_change(patches: Array, forward: bool) -> void:
	var updated: Array[Dictionary] = []
	var removed: Array[String] = []
	var bones := {}
	var bounds_bones := {}
	var list_changed := false
	for patch in patches:
		var value: Dictionary = patch.after if forward else patch.before
		var old: Dictionary = patch.before if forward else patch.after
		if not old.is_empty():
			bones[old.bone] = true
		if value.is_empty():
			removed.append(str(old.id))
		else:
			updated.append(value)
			bones[value.bone] = true
		if old.is_empty() or value.is_empty() or old.get("bone") != value.get("bone") or old.get("center") != value.get("center") or old.get("edge") != value.get("edge") or old.get("hidden",false) != value.get("hidden",false):
			if not old.is_empty():
				bounds_bones[old.bone] = true
			if not value.is_empty():
				bounds_bones[value.bone] = true
		list_changed = list_changed or old.is_empty() or value.is_empty() or old.get("bone") != value.get("bone") or old.get("hidden",false) != value.get("hidden",false) or old.get("locked",false) != value.get("locked",false)
	last_change = {"full":false,"updated":updated,"removed":removed,"bones":bones,"bounds_bones":bounds_bones,"list_changed":list_changed}
	changed.emit()
	selection_changed.emit()

func begin_translation() -> Dictionary:
	var patches: Array = []
	for id in selection:
		var index := find(id)
		if index >= 0 and not bool(model.cubes[index].get("locked",false)):
			patches.append({"index":index,"before":model.cubes[index].duplicate(true)})
	return {"patches":patches,"selection":selection.duplicate(),"reference":reference,"reference_dirty":_reference_dirty}

func preview_patch_translation(state: Dictionary, delta: Vector3) -> void:
	if read_only:
		return
	var patches: Array = []
	for original in state.patches:
		var cube: Dictionary = original.before.duplicate(true)
		cube.center = Definition.array(Definition.vector(cube.center)+delta)
		last_error = Definition.cube_validation_error(cube)
		if not last_error.is_empty():
			return
		patches.append({"index":original.index,"before":original.before,"after":cube})
	_apply_cube_patches(patches,true)
	selection.assign(state.selection)
	reference = state.reference
	_reference_dirty = true
	_emit_cube_change(patches,true)

func commit_translation(state: Dictionary) -> bool:
	var patches: Array = []
	for original in state.patches:
		patches.append({"index":original.index,"before":original.before,"after":model.cubes[int(original.index)].duplicate(true)})
	return _commit_cubes(patches,state.selection,state)

func cancel_translation(state: Dictionary) -> void:
	var patches: Array = []
	for original in state.patches:
		patches.append({"index":original.index,"before":original.before,"after":model.cubes[int(original.index)].duplicate(true)})
	_apply_cube_patches(patches,false)
	selection.assign(state.selection)
	reference = state.reference
	_reference_dirty = state.reference_dirty
	_emit_cube_change(patches,false)

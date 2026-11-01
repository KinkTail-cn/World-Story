extends RefCounted

signal changed
signal selection_changed

const Data = preload("res://scripts/blueprint/BlueprintData.gd")
const Geometry = preload("res://scripts/blueprint/BlueprintGeometry.gd")
const HISTORY_LIMIT: int = 64
var blueprint
var category: String = "头部装备"
var selection: Array[String] = []
var undo_stack: Array[Dictionary] = []
var redo_stack: Array[Dictionary] = []
var saved_state: Dictionary = {}
var last_error: String = ""

func bind(data) -> void:
	blueprint = data
	blueprint.ensure_ids()
	category = blueprint.category
	selection.clear()
	undo_stack.clear()
	redo_stack.clear()
	saved_state = blueprint.to_dictionary()

func selected_parts() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if blueprint == null:
		return result
	for uid in selection:
		var index: int = blueprint.find_part(uid)
		if index >= 0 and str(blueprint.voxels[index].part) == category:
			result.append(blueprint.voxels[index])
	return result

func select(ids: Array, additive: bool = false) -> void:
	if not additive:
		selection.clear()
	for uid in ids:
		if blueprint.find_part(str(uid)) < 0:
			continue
		if additive and selection.has(str(uid)):
			selection.erase(str(uid))
		elif not selection.has(str(uid)):
			selection.append(str(uid))
	selection_changed.emit()

func snapshot() -> Dictionary:
	return {"data": blueprint.to_dictionary(), "selection": selection.duplicate()}

func record(before: Dictionary) -> bool:
	if before.data == blueprint.to_dictionary():
		return false
	undo_stack.append(before.duplicate(true))
	if undo_stack.size() > HISTORY_LIMIT:
		undo_stack.pop_front()
	redo_stack.clear()
	changed.emit()
	selection_changed.emit()
	return true

func add(part: Dictionary) -> String:
	var before := snapshot()
	last_error = ""
	var uid: String = blueprint.add_part(part)
	if uid.is_empty():
		last_error = "部件数量已达到上限"
		return ""
	last_error = Data.validation_error(blueprint.to_dictionary())
	if not last_error.is_empty():
		_restore(before)
		return ""
	selection = [uid]
	record(before)
	return uid

func erase_selected() -> bool:
	var before := snapshot()
	for index in range(blueprint.voxels.size() - 1, -1, -1):
		var part: Dictionary = blueprint.voxels[index]
		if selection.has(str(part.get("uid", ""))) and not bool(part.get("locked", false)):
			blueprint.voxels.remove_at(index)
	selection = selection.filter(func(uid: String): return blueprint.find_part(uid) >= 0)
	return record(before)

func clear_category() -> bool:
	var before := snapshot()
	for index in range(blueprint.voxels.size() - 1, -1, -1):
		var part: Dictionary = blueprint.voxels[index]
		if str(part.part) == category and not bool(part.get("locked", false)):
			blueprint.voxels.remove_at(index)
	selection.clear()
	return record(before)

func duplicate_selected() -> bool:
	var before := snapshot()
	var copies: Array[String] = []
	for part in selected_parts():
		if bool(part.get("locked", false)):
			continue
		var copy := part.duplicate(true)
		var transform := Geometry.character_transform(copy, category)
		transform.origin.x += 0.0325
		Geometry.set_character_transform(copy, category, transform)
		copy["label"] = str(copy.get("label", "部件")) + " 副本"
		var uid: String = blueprint.add_part(copy)
		if not uid.is_empty():
			copies.append(uid)
	selection = copies
	return record(before)

func translate_selected(delta: Vector3) -> bool:
	var before := snapshot()
	for part in selected_parts():
		if not bool(part.get("locked", false)):
			var transform := Geometry.character_transform(part, category)
			transform.origin += delta
			Geometry.set_character_transform(part, category, transform)
	return record(before)

func rotate_selected(degrees: Vector3, about_anchor: bool = false) -> bool:
	var before := snapshot()
	var parts := selected_parts().filter(func(part: Dictionary): return not bool(part.get("locked", false)))
	if parts.is_empty():
		return false
	var pivot := Vector3.ZERO
	for part in parts:
		pivot += Geometry.character_transform(part, category).origin
	pivot /= float(parts.size())
	if about_anchor and parts.size() == 1:
		pivot = Geometry.ORIGINS[Geometry.anchor(parts[0], category)]
	var rotation := Basis.from_euler(degrees * (PI / 180.0))
	for part in parts:
		var transform := Geometry.character_transform(part, category)
		transform.origin = pivot + rotation * (transform.origin - pivot)
		transform.basis = rotation * transform.basis
		Geometry.set_character_transform(part, category, transform)
	return record(before)

func set_properties(properties: Dictionary) -> bool:
	var before := snapshot()
	for part in selected_parts():
		if bool(part.get("locked", false)):
			for flag in ["locked", "hidden"]:
				if properties.has(flag):
					part[flag] = properties[flag]
			continue
		var transform := Geometry.character_transform(part, category)
		var bone := Geometry.anchor(part, category)
		if properties.has("anchor") and Geometry.ORIGINS.has(str(properties.anchor)):
			bone = str(properties.anchor)
		if properties.has("offset"):
			transform.origin = Vector3(Geometry.ORIGINS[bone]) + Geometry.vector(properties.offset)
		if properties.has("rotation"):
			transform.basis = Basis.from_euler(Geometry.vector(properties.rotation) * (PI / 180.0))
		var preserved_offset: Variant = part.get("offset")
		if properties.has("anchor") or properties.has("offset") or properties.has("rotation"):
			Geometry.set_character_transform(part, category, transform, bone)
			if properties.has("rotation") and not properties.has("anchor") and not properties.has("offset") and preserved_offset != null:
				part["offset"] = preserved_offset
		for key in ["label", "shape", "dimensions", "mat", "tint", "surface", "cloth", "hidden", "locked"]:
			if properties.has(key):
				var value: Variant = properties[key]
				part[key] = value.duplicate(true) if value is Dictionary or value is Array else value
	if not Data.validation_error(blueprint.to_dictionary()).is_empty():
		_restore(before)
		return false
	return record(before)

func mirror_selected() -> bool:
	var before := snapshot()
	var sources := selected_parts()
	if sources.is_empty():
		for part in blueprint.voxels:
			if str(part.part) == category:
				sources.append(part)
	var copies: Array[String] = []
	for part in sources:
		if bool(part.get("locked", false)):
			continue
		var copy := Geometry.mirrored(part, category)
		var found := false
		for existing in blueprint.voxels:
			if str(existing.part) == category and _same_geometry(existing, copy):
				found = true
				break
		if not found:
			copy["label"] = str(copy.get("label", "部件")) + " 镜像"
			var uid: String = blueprint.add_part(copy)
			if not uid.is_empty():
				copies.append(uid)
	if not copies.is_empty():
		selection = copies
	return record(before)

func _same_geometry(a: Dictionary, b: Dictionary) -> bool:
	return str(a.get("shape", "box")) == str(b.get("shape", "box")) and Geometry.dimensions(a).is_equal_approx(Geometry.dimensions(b)) and Geometry.character_transform(a, category).is_equal_approx(Geometry.character_transform(b, category))

func undo() -> bool:
	if undo_stack.is_empty():
		return false
	redo_stack.append(snapshot())
	_restore(undo_stack.pop_back())
	changed.emit()
	selection_changed.emit()
	return true

func redo() -> bool:
	if redo_stack.is_empty():
		return false
	undo_stack.append(snapshot())
	_restore(redo_stack.pop_back())
	changed.emit()
	selection_changed.emit()
	return true

func _restore(state: Dictionary) -> void:
	var restored = Data.from_dictionary(state.data)
	for key in ["name", "category", "grid_size", "cells", "voxels", "created_at", "source_item_id", "schema_version"]:
		blueprint.set(key, restored.get(key))
	selection.assign(state.selection)
	blueprint.ensure_ids()

func dirty() -> bool:
	return blueprint != null and saved_state != blueprint.to_dictionary()

func mark_saved() -> void:
	saved_state = blueprint.to_dictionary()

func restore_snapshot(state: Dictionary) -> void:
	_restore(state)
	changed.emit()
	selection_changed.emit()

extends RefCounted

const Definition = preload("res://scripts/character/CharacterDefinition.gd")
const Storage = preload("res://scripts/system/SaveSystem.gd")
var designs: Array[Dictionary] = []
var storage = Storage.new("user://characters.json")
var last_error: String = ""

func load_library() -> bool:
	if not storage.has_save():
		return true
	var result: Dictionary = storage.load_result(_validate)
	if not result.ok:
		last_error = str(result.error)
		return false
	designs.clear()
	for entry in result.data.characters:
		designs.append(Definition.normalized(entry))
	return true

func save_model(data: Dictionary) -> bool:
	last_error = Definition.validation_error(data)
	if not last_error.is_empty():
		return false
	var staged: Array[Dictionary] = designs.duplicate(true)
	var found := -1
	for i in staged.size():
		if staged[i].id == data.id:
			found = i
	if found >= 0:
		staged[found] = data.duplicate(true)
	else:
		if staged.size() >= 64:
			last_error = "人物库最多保存 64 个模型"
			return false
		staged.append(data.duplicate(true))
	if not storage.save_game({"version": 1, "characters": staged}):
		last_error = "人物库保存失败，请检查存储空间"
		return false
	designs = staged
	return true

func _validate(data: Dictionary) -> String:
	if data.get("version") != 1 or not data.get("characters") is Array or data.characters.size() > 64:
		return "人物库格式无效"
	var ids := {}
	for entry in data.characters:
		if not entry is Dictionary:
			return "人物数据无效"
		var error := Definition.validation_error(entry)
		if not error.is_empty():
			return error
		if ids.has(entry.id):
			return "人物库标识重复"
		ids[entry.id] = true
	return ""

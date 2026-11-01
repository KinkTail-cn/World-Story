extends RefCounted

class_name BlueprintManager

signal changed

const BlueprintDataScript = preload("res://scripts/blueprint/BlueprintData.gd")
const Storage = preload("res://scripts/system/SaveSystem.gd")
var blueprints: Array[Dictionary] = []
var notes: Array[String] = []
var current = null
var _storage = Storage.new("user://blueprints.json")

func create_blueprint(blueprint_name: String, category: String, size: int) -> Dictionary:
	current = BlueprintDataScript.new(blueprint_name, category, size)
	return current.to_dictionary()

func set_cell(index: int, material_id: int) -> bool:
	if current == null or index < 0 or index >= current.cells.size():
		return false
	current.cells[index] = clampi(material_id, 0, 8)
	changed.emit()
	return true

func save_current() -> Dictionary:
	if current == null:
		return {}
	var saved: Dictionary = current.to_dictionary()
	_upsert_blueprint(saved)
	changed.emit()
	return saved

func import_blueprints(designs: Array) -> bool:
	var updated := false
	for design in designs:
		if design is Dictionary and BlueprintDataScript.validation_error(design).is_empty():
			updated = _upsert_blueprint(BlueprintDataScript.from_dictionary(design).to_dictionary()) or updated
	if updated:
		changed.emit()
	return updated

func _upsert_blueprint(design: Dictionary) -> bool:
	var found := -1
	var updated := false
	for i in range(blueprints.size() - 1, -1, -1):
		if blueprints[i].get("name") == design.get("name") and blueprints[i].get("category") == design.get("category"):
			if found < 0:
				found = i
				updated = blueprints[i] != design
				blueprints[i] = design.duplicate(true)
			else:
				blueprints.remove_at(i)
				updated = true
	if found < 0:
		blueprints.append(design.duplicate(true))
		updated = true
	return updated

func delete(index: int) -> bool:
	if index < 0 or index >= blueprints.size():
		return false
	blueprints.remove_at(index)
	changed.emit()
	return true

func save_note(text: String, index: int = -1) -> String:
	var note := text.strip_edges()
	if note.is_empty() or index < -1 or index >= notes.size():
		return ""
	if index < 0:
		notes.append(note)
	else:
		notes[index] = note
	changed.emit()
	return note

func save_json(path: String = "user://blueprints.json") -> bool:
	_storage.save_path = path
	return _storage.save_game({"blueprints": blueprints, "notes": notes})

func load_json(path: String = "user://blueprints.json") -> bool:
	_storage.save_path = path
	var result: Dictionary = _storage.load_result(_library_error)
	if not result.ok:
		return false
	var parsed: Dictionary = result.data
	blueprints.clear()
	for item in parsed.get("blueprints", []):
		if item is Dictionary:
			_upsert_blueprint(BlueprintDataScript.from_dictionary(item).to_dictionary())
	notes.clear()
	for note in parsed.get("notes", []):
		notes.append(str(note))
	current = BlueprintDataScript.from_dictionary(blueprints.back()) if not blueprints.is_empty() else null
	changed.emit()
	return true

func _library_error(value: Dictionary) -> String:
	if not value.get("blueprints") is Array or not value.get("notes") is Array:
		return "蓝图库格式不完整"
	for design in value.blueprints:
		if not design is Dictionary or not BlueprintDataScript.validation_error(design).is_empty():
			return "蓝图数据无效"
	return ""

extends Control

signal closed

var manager: RefCounted
var editing_index: int = -1
const ManagerScript = preload("res://scripts/blueprint/BlueprintManager.gd")

@onready var editor: TextEdit = $Card/Body/Editor
@onready var list: ItemList = $Card/Body/Notes

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP
	$Card/Header/CloseButton.pressed.connect(close)
	$Card/Body/Actions/Close.pressed.connect(close)
	$Card/Body/Actions/Save.pressed.connect(_save_note)
	$Card/Body/Actions/New.pressed.connect(_new_note)
	list.item_selected.connect(_select_note)
	visible = false

func open(value: RefCounted) -> void:
	manager = value
	_new_note()
	_refresh()
	visible = true

func close() -> void:
	visible = false
	closed.emit()

func _save_note() -> void:
	var typed_manager = manager if manager != null and manager.get_script() == ManagerScript else null
	if typed_manager != null:
		if typed_manager.save_note(editor.text, editing_index).is_empty():
			return
		_refresh()
		if editing_index >= 0:
			list.select(editing_index)
		else:
			editor.clear()
		$Card/Body/Notice.text = "笔记已更新 · 按 F5 保存到存档"

func _new_note() -> void:
	editing_index = -1
	editor.clear()
	list.deselect_all()
	$Card/Body/Actions/Save.text = "添加笔记"
	$Card/Body/Notice.text = "添加或修改笔记后，按 F5 保存进度"

func _select_note(index: int) -> void:
	if manager == null or index < 0 or index >= manager.notes.size():
		return
	editing_index = index
	editor.text = manager.notes[index]
	$Card/Body/Actions/Save.text = "保存修改"
	$Card/Body/Notice.text = "正在编辑第 %d 篇 · 修改后点击保存修改，再按 F5 保存进度" % (index + 1)

func _refresh() -> void:
	list.clear()
	var typed_manager = manager if manager != null and manager.get_script() == ManagerScript else null
	if typed_manager == null:
		return
	for note in typed_manager.notes:
		list.add_item(note)

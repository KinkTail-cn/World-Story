extends Control

signal closed

var manager: RefCounted
var editing_index: int = -1
const ManagerScript = preload("res://scripts/blueprint/BlueprintManager.gd")
const Layout = preload("res://scripts/ui/ResponsiveLayout.gd")
const UI = preload("res://scripts/ui/UIStyle.gd")

@onready var editor: TextEdit = $Card/Body/Editor
@onready var list: ItemList = $Card/Body/Notes

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	UI.apply(self)
	UI.panel($Card)
	UI.label($Card/Header/Title, 26, UI.INK, true)
	UI.label($Card/Body/Notice, 13, UI.MUTED)
	UI.label($Card/Body/Empty, 14, UI.MUTED)
	UI.label($Card/Body/EditorTitle, 16, UI.TEAL, true)
	UI.button($Card/Body/Actions/Save, "primary")
	mouse_filter = Control.MOUSE_FILTER_STOP
	$Card/Header/CloseButton.pressed.connect(close)
	$Card/Body/Actions/Close.pressed.connect(close)
	$Card/Body/Actions/Save.pressed.connect(_save_note)
	$Card/Body/Actions/New.pressed.connect(_new_note)
	list.item_selected.connect(_select_note)
	visible = false
	resized.connect(_layout)
	_layout.call_deferred()

func _layout() -> void:
	if is_node_ready():
		Layout.fit_centered($Card, size, Vector2(minf(960, size.x - 40), minf(640, size.y - 40)))
		var column := 180.0 if $Card.size.x < 850 else 244.0
		$Card/Body/Notes.offset_right = column
		$Card/Body/NotesTitle.size.x = column
		$Card/Body/Empty.size.x = column - 32
		for control in [$Card/Body/Editor, $Card/Body/EditorTitle, $Card/Body/Notice]:
			control.offset_left = column + 26

func open(value: RefCounted) -> void:
	manager = value
	_new_note()
	_refresh()
	visible = true
	_layout()
	UI.reveal($Card)

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
	$Card/Body/EditorTitle.text = "新的灵感"

func _select_note(index: int) -> void:
	if manager == null or index < 0 or index >= manager.notes.size():
		return
	editing_index = index
	editor.text = manager.notes[index]
	$Card/Body/Actions/Save.text = "保存修改"
	$Card/Body/EditorTitle.text = "第 %02d 篇笔记" % (index + 1)
	$Card/Body/Notice.text = "正在编辑第 %d 篇 · 修改后点击保存修改，再按 F5 保存进度" % (index + 1)

func _refresh() -> void:
	list.clear()
	var typed_manager = manager if manager != null and manager.get_script() == ManagerScript else null
	if typed_manager == null:
		return
	$Card/Body/Empty.visible = typed_manager.notes.is_empty()
	$Card/Body/NotesTitle.text = "我的笔记  ·  %d" % typed_manager.notes.size()
	for note in typed_manager.notes:
		var first_line := str(note).split("\n")[0].left(18)
		var index := list.add_item(first_line)
		list.set_item_tooltip(index, note)

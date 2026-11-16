extends Control

const Layout = preload("res://scripts/ui/ResponsiveLayout.gd")
const UI = preload("res://scripts/ui/UIStyle.gd")

signal new_game(mode: String)
signal continue_game
signal settings_requested
signal quit_requested

@onready var continue_button: Button = $Center/Card/Body/Buttons/Continue
@onready var mode_popup: Control = $ModePopup
@onready var mode_box: OptionButton = $ModePopup/Card/Body/Mode
@onready var world_type_box: OptionButton = $ModePopup/Card/Body/WorldType

var selected_world_type: String = "infinite"
var save_system
var replace_confirmation: ConfirmationDialog

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	UI.apply(self, true)
	$Center/Card.add_theme_stylebox_override("panel", UI.box(Color.TRANSPARENT, Color.TRANSPARENT, 0, Vector2.ZERO))
	UI.label($Center/Card/Body/Title, 64, UI.LIGHT, true)
	UI.label($Center/Card/Body/Eyebrow, 14, UI.GOLD)
	UI.label($Center/Card/Body/Subtitle, 18, Color("d2dfdb"))
	UI.label($Wordmark, 13, Color("d8e5df"))
	UI.label($Footer, 13, Color("afc5c4"))
	UI.label($SceneCaption, 15, Color("e2ede3"))
	UI.label($Center/Card/Body/Error, 14, UI.ERROR)
	UI.apply($ModePopup, false)
	UI.panel($ModePopup/Card, false, Vector2(32, 26))
	UI.label($ModePopup/Card/Body/Title, 30, UI.INK, true)
	for key in ["Description", "ModeDescription", "WorldDescription"]:
		UI.label(get_node("ModePopup/Card/Body/" + key), 14, UI.MUTED)
	UI.label($ModePopup/Card/Body/Eyebrow, 12, UI.TEAL)
	UI.button($ModePopup/Card/Body/Start, "primary")
	$ModePopup/Card/Body/Start.text = "创建世界"
	$ModePopup/Card/Body/Start.icon = UI.icon("forward")
	$ModePopup/Card/Body/Start.icon_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	continue_button.visible = _has_save()
	mode_box.add_item("创造模式  ·  自由建造")
	mode_box.add_item("生存模式  ·  采集与制作")
	world_type_box.add_item("无限世界  ·  大陆与群岛")
	world_type_box.add_item("晴风岛  ·  经典岛屿")
	mode_box.item_selected.connect(_describe_choices)
	world_type_box.item_selected.connect(_describe_choices)
	$Center/Card/Body/Buttons/NewGame.pressed.connect(_open_mode_popup)
	continue_button.pressed.connect(func(): continue_game.emit())
	$Center/Card/Body/Buttons/Settings.pressed.connect(func(): settings_requested.emit())
	$Center/Card/Body/Buttons/Quit.pressed.connect(func(): quit_requested.emit())
	$ModePopup/Card/Body/Cancel.pressed.connect(_close_mode_popup)
	$ModePopup/Card/Body/Start.pressed.connect(_start_selected_mode)
	mode_popup.visible = false
	resized.connect(_layout)
	$Center/Card.minimum_size_changed.connect(_layout.call_deferred)
	$ModePopup/Card.minimum_size_changed.connect(_layout.call_deferred)
	_style_actions()
	_layout.call_deferred()
	UI.reveal($Center/Card)

func _layout() -> void:
	if not is_node_ready():
		return
	Layout.fit_centered($Center/Card, size, Vector2(392, 0), 64)
	$Center/Card.position.x = clampf(size.x * 0.055, 32.0, 88.0)
	Layout.fit_centered($ModePopup/Card, size, Vector2(580, 0), 24)
	$Wordmark.position.x = $Center/Card.position.x
	$Footer.position.x = $Center/Card.position.x
	$SceneCaption.visible = size.x >= 1000

func _style_actions() -> void:
	for button in $Center/Card/Body/Buttons.get_children():
		UI.button(button, "primary" if (button == continue_button and continue_button.visible) or (button.name == "NewGame" and not continue_button.visible) else "secondary")
		button.focus_mode = Control.FOCUS_ALL
	continue_button.text = "继续游戏"
	continue_button.icon = UI.icon("forward")
	continue_button.icon_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	$Center/Card/Body/Buttons/NewGame.text = "创建新世界"
	$Center/Card/Body/Buttons/NewGame.icon = UI.icon("plus")
	$Center/Card/Body/Buttons/NewGame.icon_alignment = HORIZONTAL_ALIGNMENT_RIGHT

func _describe_choices(_index: int = 0) -> void:
	$ModePopup/Card/Body/ModeDescription.text = "采集材料、制作工具，留意生命与潜水空气。" if mode_box.selected == 1 else "无限建材，专心建造与设计，尽情实现你的灵感。"
	$ModePopup/Card/Body/WorldDescription.text = "一座适合专心建造的有限岛屿，有海岸、树林与小屋。" if world_type_box.selected == 1 else "从晴风岛出发，探索不断延伸的大陆与群岛。"

func refresh() -> void:
	continue_button.visible = _has_save()
	mode_popup.visible = false
	$Center/Card/Body/Error.visible = false
	_style_actions()

func show_error(text: String) -> void:
	var label: Label = $Center/Card/Body/Error
	label.text = text
	label.visible = true

func _open_mode_popup() -> void:
	mode_popup.visible = true
	for button in $Center/Card/Body/Buttons.get_children():
		button.focus_mode = Control.FOCUS_NONE
	_describe_choices()
	UI.reveal($ModePopup/Card)
	mode_box.grab_focus()

func _close_mode_popup() -> void:
	mode_popup.visible = false
	_style_actions()
	$Center/Card/Body/Buttons/NewGame.grab_focus()

func _start_selected_mode() -> void:
	if _has_save():
		if replace_confirmation == null:
			replace_confirmation = ConfirmationDialog.new()
			replace_confirmation.title = "创建新世界"
			replace_confirmation.dialog_text = "当前已有一份世界存档。\n新世界会自动保存，并替换这份世界；上一版保留在备份中。"
			replace_confirmation.ok_button_text = "创建新世界"
			replace_confirmation.cancel_button_text = "保留当前世界"
			replace_confirmation.confirmed.connect(_launch_selected_mode)
			add_child(replace_confirmation)
			UI.dialog(replace_confirmation)
		replace_confirmation.popup_centered()
		return
	_launch_selected_mode()

func _launch_selected_mode() -> void:
	var mode := "survival" if mode_box.selected == 1 else "creative"
	selected_world_type = "island" if (world_type_box != null and world_type_box.selected == 1) else "infinite"
	mode_popup.visible = false
	new_game.emit(mode)

func _unhandled_input(event: InputEvent) -> void:
	if mode_popup.visible and event.is_action_pressed("pause"):
		_close_mode_popup()
		get_viewport().set_input_as_handled()

func _has_save() -> bool:
	if save_system == null:
		save_system = preload("res://scripts/system/SaveSystem.gd").new()
	return save_system.has_save()

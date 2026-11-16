extends Control

const Layout = preload("res://scripts/ui/ResponsiveLayout.gd")
const UI = preload("res://scripts/ui/UIStyle.gd")

signal close_requested

var settings
var _updating := false

@onready var volume: HSlider = $Center/Card/Body/Volume
@onready var sensitivity: HSlider = $Center/Card/Body/Sensitivity
@onready var fullscreen: CheckButton = $Center/Card/Body/Fullscreen
@onready var msaa: OptionButton = $Center/Card/Body/MSAA
@onready var value_label: Label = $Center/Card/Body/VolumeValue

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	UI.apply(self)
	UI.panel($Center/Card, false, Vector2(32, 26))
	UI.label($Center/Card/Body/Header/Title, 28, UI.INK, true)
	for key in ["Subtitle", "Hint", "Status"]:
		UI.label(get_node("Center/Card/Body/" + key), 13, UI.MUTED)
	for key in ["SoundTitle", "DisplayTitle"]:
		UI.label(get_node("Center/Card/Body/" + key), 16, UI.TEAL, true)
	UI.button($Center/Card/Body/Buttons/Apply, "primary")
	msaa.add_item("关闭", 0)
	msaa.add_item("2× MSAA  ·  性能与画质均衡", 2)
	msaa.add_item("4× MSAA  ·  更平滑的边缘", 4)
	volume.value_changed.connect(_on_volume_changed)
	sensitivity.value_changed.connect(_on_sensitivity_changed)
	fullscreen.toggled.connect(_on_fullscreen_toggled)
	msaa.item_selected.connect(_on_msaa_selected)
	$Center/Card/Body/Buttons/Apply.pressed.connect(_apply)
	$Center/Card/Body/Buttons/Reset.pressed.connect(_reset)
	$Center/Card/Body/Header/Close.pressed.connect(func(): close_requested.emit())
	visible = false
	resized.connect(_layout)
	$Center/Card.minimum_size_changed.connect(_layout.call_deferred)
	_layout.call_deferred()

func _layout() -> void:
	if is_node_ready():
		Layout.fit_centered($Center/Card, size, Vector2(650, 0))

func open(value) -> void:
	if settings != null and settings.changed.is_connected(_refresh):
		settings.changed.disconnect(_refresh)
	settings = value
	if settings != null:
		settings.changed.connect(_refresh)
	visible = true
	_refresh()
	$Center/Card/Body/Status.text = "调整即时生效，点击保存后会记住你的偏好。"
	UI.reveal($Center/Card)

func close() -> void:
	if settings != null and settings.changed.is_connected(_refresh):
		settings.changed.disconnect(_refresh)
	visible = false

func _refresh() -> void:
	if settings == null:
		return
	_updating = true
	volume.value = float(settings.get_value("master_volume", 1.0))
	sensitivity.value = float(settings.get_value("sensitivity", 0.0025))
	_update_sensitivity_text(sensitivity.value)
	fullscreen.button_pressed = bool(settings.get_value("fullscreen", false))
	msaa.select(msaa.get_item_index(int(settings.get_value("msaa", 2))))
	_update_volume_text(volume.value)
	_updating = false

func _on_volume_changed(value: float) -> void:
	_update_volume_text(value)
	if settings != null and not _updating:
		settings.set_value("master_volume", value)

func _on_sensitivity_changed(value: float) -> void:
	_update_sensitivity_text(value)
	if settings != null and not _updating:
		settings.set_value("sensitivity", value)

func _on_fullscreen_toggled(value: bool) -> void:
	if settings != null and not _updating:
		settings.set_value("fullscreen", value)

func _apply() -> void:
	if settings != null:
		settings.set_value("msaa", msaa.get_selected_id())
		if not settings.save():
			$Center/Card/Body/Status.text = "设置保存失败，请检查存储空间后重试。"
			return
	close_requested.emit()

func _on_msaa_selected(index: int) -> void:
	if settings != null and not _updating:
		settings.set_value("msaa", msaa.get_item_id(index))

func _reset() -> void:
	if settings != null:
		settings.reset()
		_refresh()

func _update_volume_text(value: float) -> void:
	value_label.text = "%d%%" % roundi(value * 100.0)
	$Center/Card/Body/VolumeHeader/Value.text = value_label.text

func _update_sensitivity_text(value: float) -> void:
	$Center/Card/Body/SensitivityHeader/Value.text = "%.1f×" % (value / 0.0025)

func _unhandled_key_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("pause"):
		close_requested.emit()
		get_viewport().set_input_as_handled()

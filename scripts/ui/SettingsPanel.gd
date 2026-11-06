extends Control

const Layout = preload("res://scripts/ui/ResponsiveLayout.gd")

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
	msaa.add_item("关闭", 0)
	msaa.add_item("2x", 2)
	msaa.add_item("4x", 4)
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
		Layout.fit_centered($Center/Card, size, Vector2(540, 0))

func open(value) -> void:
	settings = value
	visible = true
	_refresh()

func close() -> void:
	visible = false

func _refresh() -> void:
	if settings == null:
		return
	_updating = true
	volume.value = float(settings.get_value("master_volume", 1.0))
	sensitivity.value = float(settings.get_value("sensitivity", 0.0025))
	fullscreen.button_pressed = bool(settings.get_value("fullscreen", false))
	msaa.select(msaa.get_item_index(int(settings.get_value("msaa", 2))))
	_update_volume_text(volume.value)
	_updating = false

func _on_volume_changed(value: float) -> void:
	_update_volume_text(value)
	if settings != null and not _updating:
		settings.set_value("master_volume", value)

func _on_sensitivity_changed(value: float) -> void:
	if settings != null and not _updating:
		settings.set_value("sensitivity", value)

func _on_fullscreen_toggled(value: bool) -> void:
	if settings != null and not _updating:
		settings.set_value("fullscreen", value)

func _apply() -> void:
	if settings != null:
		settings.set_value("msaa", msaa.get_selected_id())
		if not settings.save():
			value_label.text = "设置保存失败"
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

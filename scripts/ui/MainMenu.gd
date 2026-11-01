extends Control

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

var motes_particles: Array[Dictionary] = []
var anim_time: float = 0.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	continue_button.visible = _has_save()
	mode_box.add_item("创造模式：无限物品，无数量和堆叠限制")
	mode_box.add_item("生存模式：有限背包，需要采集和消耗")
	world_type_box.add_item("真实无限大世界（无限地图 · 广袤大陆与连绵群岛）")
	world_type_box.add_item("晴风群岛（经典有限地图 · 原版精巧岛屿）")
	$Center/Card/Body/Buttons/NewGame.pressed.connect(_open_mode_popup)
	continue_button.pressed.connect(func(): continue_game.emit())
	$Center/Card/Body/Buttons/Settings.pressed.connect(func(): settings_requested.emit())
	$Center/Card/Body/Buttons/Quit.pressed.connect(func(): quit_requested.emit())
	$ModePopup/Card/Body/Cancel.pressed.connect(_close_mode_popup)
	$ModePopup/Card/Body/Start.pressed.connect(_start_selected_mode)
	mode_popup.visible = false
	
	# 初始化漂浮神圣萤火光斑
	for i in range(24):
		motes_particles.append({
			"pos": Vector2(randf() * 1280.0, randf() * 720.0),
			"speed": randf_range(12.0, 26.0),
			"radius": randf_range(2.0, 4.0),
			"phase": randf() * TAU,
			"color": Color("#fce488") if randf() > 0.3 else Color("#9efba4")
		})
	set_process(true)


func _process(delta: float) -> void:
	anim_time += delta
	var vp_size := get_viewport_rect().size
	for p in motes_particles:
		p.pos.y -= p.speed * delta
		p.pos.x += sin(anim_time * 1.4 + p.phase) * 10.0 * delta
		if p.pos.y < -10:
			p.pos.y = vp_size.y + 10
			p.pos.x = randf() * vp_size.x
	queue_redraw()


func _draw() -> void:
	# 绘制漂浮在羊皮卷轴背景上的金色与微翠荧光光尘
	for p in motes_particles:
		var alpha: float = 0.4 + 0.4 * sin(anim_time * 2.2 + p.phase)
		var c: Color = p.color
		c.a = alpha
		draw_circle(p.pos, p.radius, c)
		draw_circle(p.pos, p.radius * 0.45, Color(1, 1, 1, alpha * 0.85))

func refresh() -> void:
	continue_button.visible = _has_save()
	mode_popup.visible = false
	$Center/Card/Body/Error.visible = false

func show_error(text: String) -> void:
	var label: Label = $Center/Card/Body/Error
	label.text = text
	label.visible = true

func _open_mode_popup() -> void:
	mode_popup.visible = true

func _close_mode_popup() -> void:
	mode_popup.visible = false

func _start_selected_mode() -> void:
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

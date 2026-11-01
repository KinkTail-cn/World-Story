extends Control

const ItemDisplay3D = preload("res://scripts/ui/ItemDisplay3D.gd")

@export var block_id: int = 1:
	set(val):
		block_id = val
		_update_3d()
		if _overlay != null:
			_overlay.queue_redraw()

var slot_number: int = 1:
	set(val):
		slot_number = val
		if _overlay != null:
			_overlay.queue_redraw()

var _container: SubViewportContainer
var _viewport: SubViewport
var _display3d: Node3D
var _overlay: Control
var item_data: Dictionary = {}

func set_item_data(data: Dictionary) -> void:
	item_data = data.duplicate(true)
	block_id = int(data.get("id", 0))

func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	_setup_3d_viewport()
	_overlay = Control.new()
	_overlay.name = "Overlay"
	_overlay.mouse_filter = MOUSE_FILTER_IGNORE
	_overlay.set_anchors_preset(PRESET_FULL_RECT)
	_overlay.draw.connect(_on_overlay_draw)
	add_child(_overlay)
	_update_3d()

func _setup_3d_viewport() -> void:
	_container = SubViewportContainer.new()
	_container.name = "ViewportContainer"
	_container.mouse_filter = MOUSE_FILTER_IGNORE
	_container.set_anchors_preset(PRESET_FULL_RECT)
	_container.stretch = true
	add_child(_container)
	
	_viewport = SubViewport.new()
	_viewport.name = "SubViewport"
	_viewport.transparent_bg = true
	_viewport.own_world_3d = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_container.add_child(_viewport)
	
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color.TRANSPARENT
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.92, 0.94, 1.0)
	e.ambient_light_energy = 0.65
	env.environment = e
	_viewport.add_child(env)
	
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-45, -30, 0)
	sun.light_color = Color("#fff8ea")
	sun.light_energy = 1.15
	_viewport.add_child(sun)
	
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 0.58
	cam.look_at_from_position(Vector3(0.9, 0.72, 0.9), Vector3.ZERO, Vector3.UP)
	_viewport.add_child(cam)
	
	_display3d = ItemDisplay3D.new()
	_viewport.add_child(_display3d)

func _update_3d() -> void:
	if _display3d != null:
		_display3d.set_item(block_id, item_data)

func _on_overlay_draw() -> void:
	# 顶层精致复古金槽位编号 (1 ~ 8)，带清晰黑金双层立体字效
	var font := get_theme_default_font()
	var num_str := str(slot_number)
	# 绘制多方位阴影描边，防止任何背景下数字模糊
	_overlay.draw_string(font, Vector2(7, 17), num_str, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0, 0, 0, 0.85))
	_overlay.draw_string(font, Vector2(5, 15), num_str, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0, 0, 0, 0.85))
	_overlay.draw_string(font, Vector2(6, 16), num_str, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("#f3d38c"))


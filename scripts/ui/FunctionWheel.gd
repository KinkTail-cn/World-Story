extends Control

signal function_selected(index: int)
signal cancel_requested

const OPTIONS := ["挖掘 / 建造", "坐下 / 起身"]
var active_index: int = 0
var hovered_index: int = -1
var seated: bool = false
var opened: bool = false
var center := Vector2.ZERO
var radius: float = 180.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	resized.connect(func(): center = size * 0.5; queue_redraw())

func open(current_function: int, is_seated: bool) -> void:
	active_index = clampi(current_function, 0, 1)
	seated = is_seated
	opened = true
	visible = true
	center = size * 0.5
	hovered_index = -1
	queue_redraw()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func close() -> void:
	opened = false
	visible = false
	queue_redraw()

func confirm_at(point: Vector2) -> void:
	if not opened:
		return
	var choice := function_at_position(point)
	close()
	if choice >= 0:
		function_selected.emit(choice)
	else:
		cancel_requested.emit()

func function_at_position(point: Vector2) -> int:
	var offset := point - center
	var distance := offset.length()
	if distance < 88.0 or distance > radius:
		return -1
	return 0 if offset.x < 0.0 else 1

func _gui_input(event: InputEvent) -> void:
	if not opened:
		return
	if event is InputEventMouseMotion:
		_update_hover(event.position)
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and not event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			confirm_at(event.position)
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			close()
			cancel_requested.emit()
			get_viewport().set_input_as_handled()

func _update_hover(point: Vector2) -> void:
	var choice := function_at_position(point)
	hovered_index = choice
	queue_redraw()

func _draw() -> void:
	if not opened:
		return
	var viewport_size := size
	center = viewport_size * 0.5
	radius = clampf((viewport_size.y - 200.0) * 0.5, 140.0, 180.0)
	# 半透明深邃暗青背景
	draw_rect(Rect2(Vector2.ZERO, viewport_size), Color(0.04, 0.09, 0.13, 0.68))
	
	# 外围罗盘轻发光外圈
	draw_arc(center, radius + 4.0, 0, TAU, 64, Color(0.96, 0.82, 0.42, 0.25), 1.5, true)
	
	var sector_angle := TAU / 2.0
	for i in range(2):
		var start := PI * 0.5 - i * sector_angle + 0.025
		var end := start + sector_angle - 0.05
		var is_hovered := (i == hovered_index)
		var fill_color := Color("fae4ab") if is_hovered else Color("eef4ec")
		
		# 绘制扇区底板
		_draw_sector(center, 88.0, radius, start, end, fill_color)
		
		# 悬停时外圈金光弧描边
		if is_hovered:
			draw_arc(center, radius + 1.0, start, end, 32, Color("e8a838"), 3.0, true)
			draw_arc(center, 87.0, start, end, 32, Color("e8a838"), 2.0, true)
		else:
			draw_arc(center, radius, start, end, 32, Color("769299", 0.5), 1.2, true)
			draw_arc(center, 88.0, start, end, 32, Color("769299", 0.5), 1.2, true)
			
		var label_angle := start + (end - start) * 0.5
		var label_position := center + Vector2(cos(label_angle), sin(label_angle)) * ((88.0 + radius) * 0.5)
		var label: String = ("起身" if seated else "坐下") if i == 1 else OPTIONS[i]
		var font := get_theme_default_font()
		var label_width := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x
		
		# 标题阴影与文字
		draw_string(font, label_position + Vector2(-label_width * 0.5, 33), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(0, 0, 0, 0.15))
		draw_string(font, label_position + Vector2(-label_width * 0.5, 32), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("1e3840") if is_hovered else Color("2c4d57"))
		
		# 绘制动作图标
		_draw_icon(label_position + Vector2(0, -10), i, is_hovered)
		
		# 当前正在激活的功能标记点
		if i == active_index:
			draw_circle(label_position + Vector2(0, 50), 4.0, Color("d99726"))
			draw_circle(label_position + Vector2(0, 50), 2.0, Color("fff8e7"))
	
	# 中心罗盘枢纽
	draw_circle(center, 82.0, Color(0, 0, 0, 0.2)) # 柔和阴影
	draw_circle(center, 80.0, Color("203b44"))
	draw_circle(center, 76.0, Color("e8a838"))
	draw_circle(center, 74.0, Color("f4f8f2"))
	
	var font := get_theme_default_font()
	var title := "角色动作"
	var title_width := font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x
	draw_string(font, center + Vector2(-title_width * 0.5, -4), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color("1a353d"))
	
	var current: String = "当前：坐下" if active_index == 1 else "当前：拆建"
	var current_width: float = font.get_string_size(current, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
	draw_string(font, center + Vector2(-current_width * 0.5, 22), current, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("627d82"))
	
	# 底部操作提示胶囊
	var sub := "鼠标移动选择 · 单击左键确认 · 按 G / ESC 取消"
	var sub_width := font.get_string_size(sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
	var pill_rect := Rect2(center + Vector2(-sub_width * 0.5 - 18, radius + 52.0), Vector2(sub_width + 36, 32))
	draw_rect(pill_rect, Color(0.08, 0.16, 0.22, 0.85), true)
	draw_rect(pill_rect, Color(0.45, 0.65, 0.70, 0.6), false, 1.2)
	draw_string(font, center + Vector2(-sub_width * 0.5, radius + 74.0), sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("f5f8f2"))

func _draw_sector(origin: Vector2, inner: float, outer: float, start: float, end: float, color: Color) -> void:
	var points := PackedVector2Array()
	for i in range(16):
		points.append(origin + Vector2(cos(lerpf(start, end, float(i) / 15.0)), sin(lerpf(start, end, float(i) / 15.0))) * outer)
	for i in range(15, -1, -1):
		points.append(origin + Vector2(cos(lerpf(start, end, float(i) / 15.0)), sin(lerpf(start, end, float(i) / 15.0))) * inner)
	draw_colored_polygon(points, color)

func _draw_icon(origin: Vector2, index: int, highlighted: bool) -> void:
	var color: Color = Color("234b54") if highlighted else Color("527c82")
	if index == 0:
		# 镐头与建造手柄
		draw_line(origin + Vector2(-15, 18), origin + Vector2(11, -15), color, 5.0, true)
		draw_polyline(PackedVector2Array([origin + Vector2(-13, -14), origin + Vector2(10, -18), origin + Vector2(23, -6)]), color, 5.5, true)
	else:
		# 舒适坐姿人体剪影
		draw_circle(origin + Vector2(-7, -18), 6.5, color)
		draw_polyline(PackedVector2Array([origin + Vector2(-7, -8), origin + Vector2(-7, 9), origin + Vector2(13, 9), origin + Vector2(13, 23)]), color, 5.0, true)
		draw_line(origin + Vector2(-18, 16), origin + Vector2(6, 16), color, 3.5, true)

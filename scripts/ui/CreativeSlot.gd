extends Control

signal selected(item_id: int)
signal quick_equipped(item_id: int)
signal item_focused(item: Dictionary)

const ItemCatalog = preload("res://scripts/inventory/ItemCatalog.gd")
const ItemDisplay3D = preload("res://scripts/ui/ItemDisplay3D.gd")
const ItemTooltip = preload("res://scripts/ui/ItemTooltip.gd")

var item_id: int = 0
var model: RefCounted
var hovered: bool = false
var _click_pending: bool = false
var background := StyleBoxFlat.new()
var target_hotbar: int = 0
var _hover_time: float = 0.0
var _tooltip_shown: bool = false

var _container: SubViewportContainer
var _viewport: SubViewport
var _display3d: Node3D

func _ready() -> void:
	custom_minimum_size = Vector2(72, 76)
	background.set_border_width_all(1.5)
	background.set_corner_radius_all(10)
	mouse_entered.connect(_on_creative_mouse_entered)
	mouse_exited.connect(_on_creative_mouse_exited)
	_setup_3d_viewport()
	refresh()

func _on_creative_mouse_entered() -> void:
	hovered = true
	_hover_time = 0.0
	_tooltip_shown = false
	queue_redraw()
	if item_id > 0:
		item_focused.emit({"id": item_id, "count": -1})

func _process(delta: float) -> void:
	if not hovered or not is_visible_in_tree() or get_viewport().gui_is_dragging():
		return
	_hover_time += delta
	if _hover_time > 0.55 and not _tooltip_shown:
		ItemTooltip.show_for_item(item_id, get_global_mouse_position())
		_tooltip_shown = true

func _on_creative_mouse_exited() -> void:
	hovered = false
	queue_redraw()
	ItemTooltip.hide_card()

func _setup_3d_viewport() -> void:
	_container = SubViewportContainer.new()
	_container.name = "ViewportContainer"
	_container.mouse_filter = MOUSE_FILTER_IGNORE
	_container.anchor_left = 0.0
	_container.anchor_right = 1.0
	_container.anchor_top = 0.0
	_container.anchor_bottom = 1.0
	_container.offset_left = 3.0
	_container.offset_right = -3.0
	_container.offset_top = 3.0
	_container.offset_bottom = -21.0
	_container.stretch = true
	add_child(_container)
	
	_viewport = SubViewport.new()
	_viewport.name = "SubViewport"
	_viewport.transparent_bg = true
	_viewport.own_world_3d = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
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
	cam.size = 0.60
	cam.look_at_from_position(Vector3(0.9, 0.72, 0.9), Vector3.ZERO, Vector3.UP)
	_viewport.add_child(cam)
	
	_display3d = ItemDisplay3D.new()
	_viewport.add_child(_display3d)

func set_item(id: int, inv_model: RefCounted = null) -> void:
	item_id = id
	model = inv_model
	refresh()

func refresh() -> void:
	queue_redraw()
	if item_id <= 0:
		tooltip_text = ""
		if _container != null:
			_container.visible = false
		return
		
	if _container != null and _display3d != null:
		_container.visible = true
		_display3d.set_item(item_id)
		
	tooltip_text = ""

func _draw() -> void:
	if hovered:
		background.bg_color = Color("#263c47")
		background.border_color = Color("#d5b37b")
		background.set_border_width_all(2.0)
		background.shadow_color = Color(1.0, 0.8, 0.3, 0.45)
		background.shadow_size = 0
	else:
		background.bg_color = Color("#18242d")
		background.border_color = Color("#425560")
		background.set_border_width_all(1.5)
		background.shadow_color = Color(0, 0, 0, 0.45)
		background.shadow_size = 0

	draw_style_box(background, Rect2(Vector2.ZERO, size))
	if item_id <= 0:
		return
		
	var title: String = ItemCatalog.title(item_id)
	var font := get_theme_default_font()
	var font_size: int = 12
	var title_width: float = font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	if title_width > size.x - 8 and font_size > 10:
		font_size = 11
		title_width = font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	if title.length() > 7:
		title = title.substr(0, 6) + "…"
		title_width = font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var title_color: Color = Color("#edd2a5") if hovered else Color("#dce5e2")
	# 底部专属留白区文字绘制：黑褐色微阴影 + 清晰本体
	draw_string(font, Vector2((size.x - title_width) * 0.5 + 1, size.y - 4), title, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(0, 0, 0, 0.75))
	draw_string(font, Vector2((size.x - title_width) * 0.5, size.y - 5), title, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, title_color)

func _get_drag_data(_position: Vector2) -> Variant:
	ItemTooltip.hide_card()
	if item_id <= 0 or model == null or not model.is_creative():
		return null
	_click_pending = false
	var preview := Control.new()
	preview.custom_minimum_size = Vector2(90, 46)
	var label := Label.new()
	label.text = ItemCatalog.title(item_id)
	label.add_theme_constant_override("outline_size", 4)
	preview.add_child(label)
	set_drag_preview(preview)
	return {"model": model, "group": "creative", "index": item_id, "item_id": item_id}

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and item_id > 0 and model != null and model.is_creative():
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_click_pending = true
			else:
				var grant := _click_pending and not get_viewport().gui_is_dragging() and Rect2(Vector2.ZERO, size).has_point(event.position)
				_click_pending = false
				if grant and model.give_creative_item(item_id):
					selected.emit(item_id)
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			if model != null:
				if ItemCatalog.is_equipment(item_id):
					var slot: int = ItemCatalog.equipment_slot(item_id)
					model.move_item("creative", item_id, "equipment", slot)
				else:
					model.give_creative_item(item_id, target_hotbar)
			quick_equipped.emit(item_id)
		accept_event()

extends Control

signal item_focused(item: Dictionary)
signal quick_move_requested(group: String, index: int)
signal slot_selected(index: int)

const ItemCatalog = preload("res://scripts/inventory/ItemCatalog.gd")
const ItemTooltip = preload("res://scripts/ui/ItemTooltip.gd")
@export var group: String = "bag"
@export var index: int = 0
var model: RefCounted
var hovered: bool = false
var dragging: bool = false
var background := StyleBoxFlat.new()
var selected_hotbar: bool = false
var _hover_time: float = 0.0
var _tooltip_shown: bool = false

const ItemDisplay3D = preload("res://scripts/ui/ItemDisplay3D.gd")

var _container: SubViewportContainer
var _viewport: SubViewport
var _display3d: Node3D

func _ready() -> void:
	background.set_border_width_all(1.5)
	background.set_corner_radius_all(10)
	mouse_entered.connect(_on_slot_mouse_entered)
	mouse_exited.connect(_on_slot_mouse_exited)
	_setup_3d_viewport()

func _on_slot_mouse_entered() -> void:
	hovered = true
	_hover_time = 0.0
	_tooltip_shown = false
	queue_redraw()
	if model != null:
		var item: Dictionary = model.get_slot(group, index)
		if item.id > 0:
			item_focused.emit(item)

func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	if get_viewport().gui_is_dragging():
		queue_redraw()
		return
	if hovered and not _tooltip_shown and model != null:
		_hover_time += delta
		if _hover_time > 0.55:
			var item: Dictionary = model.get_slot(group, index)
			if item.id > 0:
				ItemTooltip.show_for_item(item.id, get_global_mouse_position(), item)
			_tooltip_shown = true

func _on_slot_mouse_exited() -> void:
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

func bind_inventory(value: RefCounted) -> void:
	model = value
	refresh()

func refresh() -> void:
	queue_redraw()
	if model == null:
		tooltip_text = ""
		if _container != null:
			_container.visible = false
		return
	var item: Dictionary = model.get_slot(group, index)
	if _container != null and _display3d != null:
		if item.id > 0:
			_container.visible = true
			_display3d.set_item(item.id, item)
		else:
			_container.visible = false
	tooltip_text = ""
	if hovered:
		item_focused.emit(item)

func _draw() -> void:
	background.bg_color = Color("#263c47") if hovered else Color("#18242d")
	background.border_color = Color("#d5b37b") if hovered or selected_hotbar else Color("#425560")
	background.set_border_width_all(2 if hovered or selected_hotbar else 1)
	background.shadow_size = 0
	if get_viewport().gui_is_dragging():
		var data: Variant = get_viewport().gui_get_drag_data()
		if _can_drop_data(Vector2.ZERO, data):
			background.border_color = Color("#7faf9d")
			background.bg_color = Color("#203b37")
		elif hovered:
			background.border_color = Color("#c77a70")

	draw_style_box(background, Rect2(Vector2.ZERO, size))
	if model == null:
		return
	var item: Dictionary = model.get_slot(group, index)
	var font := get_theme_default_font()
	if group == "bag" and index < 8:
		draw_string(font, Vector2(7, 16), str(index + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("#dcc397"))
	if item.id == 0:
		if group == "equipment":
			var label: String = ["头盔", "盔甲", "裤甲", "鞋子", "手套", "披风", "腰带"][index]
			var width: float = font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
			draw_string(font, Vector2((size.x - width) * 0.5, size.y * 0.56), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("#9baeb5"))
		elif group in ["crafting", "result"]:
			draw_string(font, Vector2(17, size.y * 0.57), "成品" if group == "result" else "材料", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("#8499a2"))
		return
	var title: String = str(item.custom_name) if item.has("custom_name") and not str(item.custom_name).is_empty() else ItemCatalog.title(item.id)
	var font_size: int = 12
	var title_width: float = font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	if title_width > size.x - 8 and font_size > 10:
		font_size = 11
		title_width = font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	if title.length() > 7:
		title = title.substr(0, 6) + "…"
		title_width = font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var title_color: Color = Color("#e9c68d") if item.has("custom_name") else Color("#dce5e2")
	# 底部留白区域专属文字绘制：黑褐色微阴影 + 清晰本体
	draw_string(font, Vector2((size.x - title_width) * 0.5 + 1, size.y - 4), title, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(0, 0, 0, 0.75))
	draw_string(font, Vector2((size.x - title_width) * 0.5, size.y - 5), title, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, title_color)
	var count: String = "∞" if item.count == -1 else (str(item.count) if item.count > 1 else "")
	if count != "":
		draw_string(font, Vector2(size.x - 26, 17), count, HORIZONTAL_ALIGNMENT_RIGHT, 20, 14, Color("#f3dca9"))


func _get_drag_data(_position: Vector2) -> Variant:
	ItemTooltip.hide_card()
	if model == null or model.get_slot(group, index).id == 0:
		return null
	dragging = true
	var preview := PanelContainer.new()
	var label := Label.new()
	var item: Dictionary = model.get_slot(group, index)
	label.text = str(item.get("custom_name", ItemCatalog.title(item.id)))
	label.add_theme_color_override("font_color", Color("#f4e3c5"))
	label.add_theme_constant_override("outline_size", 4)
	preview.add_child(label)
	set_drag_preview(preview)
	return {"model": model, "group": group, "index": index}

func _can_drop_data(_position: Vector2, data: Variant) -> bool:
	return data is Dictionary and data.get("model") == model and model != null and model.can_move(data.get("group", ""), data.get("index", -1), group, index)

func _drop_data(_position: Vector2, data: Variant) -> void:
	if _can_drop_data(_position, data):
		model.move_item(data.group, data.index, group, index)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		hovered = true
		queue_redraw()
	elif event is InputEventMouseButton and model != null:
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT and event.shift_pressed:
			quick_move_requested.emit(group, index)
			accept_event()
			return
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				dragging = false
				if event.double_click and group == "bag":
					model.equip_from_bag(index)
			elif group == "result" and not dragging:
				model.take_result()
			elif group == "bag" and index < 8 and not dragging and not get_viewport().gui_is_dragging():
				slot_selected.emit(index)
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			if group == "bag" and ItemCatalog.is_document(model.get_slot(group, index).id):
				var panel := get_parent()
				while panel != null and not panel.has_signal("item_used"):
					panel = panel.get_parent()
				if panel != null:
					panel.item_used.emit(model.get_slot(group, index).id)
			elif group == "bag":
				model.equip_from_bag(index)
			elif group == "equipment":
				model.unequip(index)
			elif group == "result":
				model.take_result()
		accept_event()

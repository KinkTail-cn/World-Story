extends Control

## 现代沉浸式动态悬浮物品介绍卡片（ItemTooltip）
## 跟随鼠标平滑悬停与智能边界避障，呈现日系深木金边、品质着色、属性面板与背景故事

const ItemCatalog = preload("res://scripts/inventory/ItemCatalog.gd")

static var instance: Control = null

# 节点引用
var _panel: PanelContainer
var _title_label: Label
var _category_label: Label
var _attr_box: VBoxContainer
var _desc_label: Label
var _divider: HSeparator
var _tip_label: Label

# 状态变量
var _current_id: int = 0
var _custom_data: Dictionary = {}
var _is_active: bool = false
var _target_pos: Vector2 = Vector2.ZERO
var _last_mouse_pos: Vector2 = Vector2(-9999, -9999)
var follow_mouse: bool = true

func _ready() -> void:
	instance = self
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 1000 # 确保处于最高层渲染
	visible = false
	_build_ui()

## 全局便捷展示物品信息卡片
static func show_for_item(id: int, mouse_pos: Vector2, custom_info: Dictionary = {}) -> void:
	if instance == null or not is_instance_valid(instance):
		return
	instance.display_item(id, mouse_pos, custom_info)

## 全局便捷隐藏物品信息卡片
static func hide_card() -> void:
	if instance == null or not is_instance_valid(instance):
		return
	instance.dismiss()

func _build_ui() -> void:
	# 根悬浮面板
	_panel = PanelContainer.new()
	_panel.name = "TooltipCard"
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.custom_minimum_size = Vector2(260, 0)
	add_child(_panel)
	
	# 日系深胡桃木与圆角烫金边框主题
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#180f09", 0.96)
	style.border_color = Color("#d8a44c")
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	style.shadow_color = Color(0, 0, 0, 0.75)
	style.shadow_size = 10
	style.shadow_offset = Vector2(0, 4)
	style.content_margin_left = 14.0
	style.content_margin_top = 12.0
	style.content_margin_right = 14.0
	style.content_margin_bottom = 12.0
	_panel.add_theme_stylebox_override("panel", style)
	
	var vbox := VBoxContainer.new()
	vbox.name = "CardLayout"
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.custom_minimum_size = Vector2(232, 0)
	vbox.add_theme_constant_override("separation", 8)
	_panel.add_child(vbox)
	
	# 1. 标题行（名称 + 稀有度品质）
	var header_hbox := HBoxContainer.new()
	header_hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(header_hbox)
	
	_title_label = Label.new()
	_title_label.name = "TitleLabel"
	_title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title_label.add_theme_font_size_override("font_size", 16)
	_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title_label.clip_text = true
	_title_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	header_hbox.add_child(_title_label)
	
	_category_label = Label.new()
	_category_label.name = "CategoryLabel"
	_category_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_category_label.add_theme_font_size_override("font_size", 11)
	_category_label.modulate = Color("#e5caa0")
	header_hbox.add_child(_category_label)
	
	# 2. 属性面板（暗底微凸）
	_attr_box = VBoxContainer.new()
	_attr_box.name = "AttrBox"
	_attr_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_attr_box.add_theme_constant_override("separation", 4)
	
	var attr_panel := PanelContainer.new()
	attr_panel.name = "AttrPanel"
	attr_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var attr_style := StyleBoxFlat.new()
	attr_style.bg_color = Color("#0f0905", 0.75)
	attr_style.set_corner_radius_all(6)
	attr_style.content_margin_left = 8.0
	attr_style.content_margin_top = 6.0
	attr_style.content_margin_right = 8.0
	attr_style.content_margin_bottom = 6.0
	attr_panel.add_theme_stylebox_override("panel", attr_style)
	attr_panel.add_child(_attr_box)
	vbox.add_child(attr_panel)
	
	# 3. 沉浸式奇幻背景故事
	_desc_label = Label.new()
	_desc_label.name = "DescLabel"
	_desc_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_desc_label.custom_minimum_size = Vector2(232, 0)
	_desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_desc_label.add_theme_font_size_override("font_size", 12)
	_desc_label.add_theme_color_override("font_color", Color("#d8cfc4"))
	vbox.add_child(_desc_label)
	
	# 4. 操作指引分割线
	_divider = HSeparator.new()
	_divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var div_style := StyleBoxLine.new()
	div_style.color = Color("#5a3c1e", 0.6)
	div_style.thickness = 1
	_divider.add_theme_stylebox_override("separator", div_style)
	vbox.add_child(_divider)
	
	# 5. 操作快捷按键指引
	_tip_label = Label.new()
	_tip_label.name = "TipLabel"
	_tip_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tip_label.custom_minimum_size = Vector2(232, 0)
	_tip_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tip_label.add_theme_font_size_override("font_size", 11)
	_tip_label.add_theme_color_override("font_color", Color("#a69480"))
	vbox.add_child(_tip_label)

func _process(_delta: float) -> void:
	if not _is_active or not visible:
		return
	var m_pos := get_global_mouse_position()
	if follow_mouse and m_pos.length_squared() > 20.0:
		_update_position(m_pos)

## 展示指定物品的信息介绍
func display_item(id: int, mouse_pos: Vector2, custom_info: Dictionary = {}) -> void:
	if id <= 0:
		dismiss()
		return
		
	_current_id = id
	_custom_data = custom_info
	_is_active = true
	visible = true
	
	var info: Dictionary = ItemCatalog.get_item_info(id)
	var design = preload("res://scripts/blueprint/BlueprintEquipment.gd")
	if design.is_custom_item(custom_info):
		var blueprint: Dictionary = custom_info.blueprint
		info["category"] = "自制" + str(blueprint.category)
		info["description"] = "由你在蓝图工坊中设计并制作，形状、材料颜色和尺寸随物品保存。"
		info["attributes"] = [{"icon": "◆", "label": "设计方块", "val": str(blueprint.get("voxels", []).size()), "color": Color("#79c0ff")}]
	
	# 1. 标题与稀有度
	var display_title: String = str(info.get("title", ""))
	if custom_info.has("custom_name") and not str(custom_info.custom_name).is_empty():
		display_title = str(custom_info.custom_name)
		
	_title_label.text = display_title
	_title_label.add_theme_color_override("font_color", info.get("rarity_color", Color.WHITE))
	
	var r_text: String = "【" + str(info.get("category", "物品")) + "】"
	match str(info.get("rarity", "common")):
		"legendary": r_text += " · 传说"
		"epic": r_text += " · 史诗"
		"rare": r_text += " · 稀有"
		"uncommon": r_text += " · 精良"
		_: r_text += " · 普通"
	_category_label.text = r_text
	
	# 2. 动态构建属性条目
	for child in _attr_box.get_children():
		child.queue_free()
		
	var attrs: Array = info.get("attributes", [])
	var has_attrs: bool = not attrs.is_empty()
	_attr_box.get_parent().visible = has_attrs
	
	for a in attrs:
		var row := HBoxContainer.new()
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		
		var icon_lbl := Label.new()
		icon_lbl.text = str(a.get("icon", "•"))
		icon_lbl.add_theme_font_size_override("font_size", 12)
		row.add_child(icon_lbl)
		
		var name_lbl := Label.new()
		name_lbl.text = str(a.get("label", "")) + ":"
		name_lbl.add_theme_font_size_override("font_size", 12)
		name_lbl.add_theme_color_override("font_color", Color("#bcae9c"))
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name_lbl)
		
		var val_lbl := Label.new()
		val_lbl.text = str(a.get("val", ""))
		val_lbl.add_theme_font_size_override("font_size", 12)
		val_lbl.add_theme_color_override("font_color", a.get("color", Color.WHITE))
		row.add_child(val_lbl)
		
		_attr_box.add_child(row)
		
	# 3. 沉浸式背景故事
	_desc_label.text = str(info.get("description", ""))
	
	# 4. 操作与快捷键提示
	var tip_text: String = str(info.get("usage_tip", ""))
	if custom_info.has("custom_tip") and not str(custom_info.custom_tip).is_empty():
		tip_text = str(custom_info.custom_tip)
	_tip_label.text = tip_text
	
	# 5. 计算初始位置并执行智能避障
	_panel.reset_size()
	_update_position(mouse_pos)

## 隐藏介绍窗口
func dismiss() -> void:
	_is_active = false
	visible = false

## 智能边缘避障计算：根据当前视口宽高与鼠标位置，防止超出屏幕边缘
func _update_position(mouse_pos: Vector2) -> void:
	if _panel == null:
		return
		
	var vp_size: Vector2 = get_viewport_rect().size
	_panel.reset_size()
	var card_size: Vector2 = _panel.get_combined_minimum_size()
	if card_size.x <= 0 or card_size.y <= 0:
		card_size = Vector2(260, 160)
	_panel.size = card_size
		
	var offset := Vector2(18, 16) # 默认向右下偏置
	var final_x: float = mouse_pos.x + offset.x
	var final_y: float = mouse_pos.y + offset.y
	
	# 右边缘检测：若超出屏幕右侧，则自动翻转至鼠标左侧
	if final_x + card_size.x > vp_size.x - 12:
		final_x = mouse_pos.x - card_size.x - 14
		
	# 下边缘检测：若超出屏幕底部，则自动向上翻转
	if final_y + card_size.y > vp_size.y - 12:
		final_y = mouse_pos.y - card_size.y - 12
		
	# 左与顶边界防溢出兜底
	final_x = clampf(final_x, 10.0, maxf(10.0, vp_size.x - card_size.x - 10.0))
	final_y = clampf(final_y, 10.0, maxf(10.0, vp_size.y - card_size.y - 10.0))
	
	_panel.position = Vector2(final_x, final_y)

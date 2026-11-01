extends CanvasLayer

signal resume_requested
signal restart_requested
signal quit_requested
signal slot_requested(slot: int)
signal function_selected(index: int)
signal function_cancelled
signal design_closed

const Catalog = preload("res://scripts/inventory/ItemCatalog.gd")
const ItemTooltip = preload("res://scripts/ui/ItemTooltip.gd")
var selected: int = 0
var toast_time: float = 0.0
var active_style := StyleBoxFlat.new()
var inactive_style := StyleBoxFlat.new()
var swimming: bool = false
var submerged: bool = false
var active_function: int = 0
var sitting: bool = false
var inventory: RefCounted
var blueprints: RefCounted
var item_tooltip: Control

@onready var slots: HBoxContainer = $Root/Bottom/HotbarDock/Margin/Hotbar if has_node("Root/Bottom/HotbarDock/Margin/Hotbar") else $Root/Bottom/Hotbar
@onready var target: Label = $Root/Aim/Target
@onready var progress: ProgressBar = $Root/Aim/Progress
@onready var toast: Label = $Root/Toast
@onready var pause_panel: Control = $Root/Pause
@onready var function_wheel = $Root/FunctionWheel
@onready var inventory_panel = $Root/InventoryPanel
@onready var blueprint_workshop = $Root/BlueprintWorkshop
@onready var notebook_panel = $Root/NotebookPanel
@onready var loading_screen = $LoadingScreen
@onready var mode_label: Label = $Root/TopRightPanel/Margin/TopRight/Mode if has_node("Root/TopRightPanel/Margin/TopRight/Mode") else $Root/TopRight/Mode
@onready var depth_label: Label = $Root/TopRightPanel/Margin/TopRight/Depth if has_node("Root/TopRightPanel/Margin/TopRight/Depth") else $Root/TopRight/Depth
@onready var function_label: Label = $Root/TopRightPanel/Margin/TopRight/Function if has_node("Root/TopRightPanel/Margin/TopRight/Function") else $Root/TopRight/Function


func _ready() -> void:
	# 选中槽位：参考设计图第1格，深木内底 + 明亮温润圆角金边 + 金光晕
	active_style.bg_color = Color("#2e1c12")
	active_style.border_color = Color("#f8d05a")
	active_style.set_border_width_all(3)
	active_style.set_corner_radius_all(12)
	active_style.shadow_color = Color(0.96, 0.78, 0.25, 0.65)
	active_style.shadow_size = 8

	# 未选中槽位：参考设计图，深胡桃实木雕刻内凹槽位
	inactive_style.bg_color = Color("#1e140d")
	inactive_style.border_color = Color("#4a321f")
	inactive_style.set_border_width_all(2)
	inactive_style.set_corner_radius_all(12)
	inactive_style.shadow_color = Color(0, 0, 0, 0.5)
	inactive_style.shadow_size = 4

	item_tooltip = ItemTooltip.new()
	$Root.add_child(item_tooltip)

	for i in range(8):
		var button: Button = slots.get_child(i)
		button.text = ""
		button.focus_mode = Control.FOCUS_NONE
		button.get_node("Icon").slot_number = i + 1
		button.add_theme_stylebox_override("normal", inactive_style)
		button.add_theme_stylebox_override("focus", inactive_style)
		button.add_theme_stylebox_override("pressed", inactive_style)
		button.add_theme_stylebox_override("disabled", inactive_style)
		var hover_style := inactive_style.duplicate()
		hover_style.border_color = Color("#d8a44c")
		hover_style.shadow_color = Color(0.85, 0.65, 0.25, 0.35)
		hover_style.shadow_size = 5
		button.add_theme_stylebox_override("hover", hover_style)
		button.pressed.connect(func(): slot_requested.emit(i))
		
		# 快捷栏物品鼠标悬停动态展示日系卡片
		var slot_idx: int = i
		button.mouse_entered.connect(func():
			if inventory != null:
				var item: Dictionary = inventory.get_slot("bag", slot_idx)
				if item.id > 0:
					ItemTooltip.show_for_item(item.id, button.get_global_mouse_position(), item)
		)
		button.mouse_exited.connect(func():
			ItemTooltip.hide_card()
		)
	
	var resume_btn: Button = $Root/Pause/Panel/Margin/Content/Resume if has_node("Root/Pause/Panel/Margin/Content/Resume") else $Root/Pause/Panel/Content/Resume
	var restart_btn: Button = $Root/Pause/Panel/Margin/Content/Restart if has_node("Root/Pause/Panel/Margin/Content/Restart") else $Root/Pause/Panel/Content/Restart
	var quit_btn: Button = $Root/Pause/Panel/Margin/Content/Quit if has_node("Root/Pause/Panel/Margin/Content/Quit") else $Root/Pause/Panel/Content/Quit
	
	resume_btn.pressed.connect(func(): resume_requested.emit())
	restart_btn.pressed.connect(func(): restart_requested.emit())
	quit_btn.pressed.connect(func(): quit_requested.emit())

	function_wheel.function_selected.connect(func(index: int): function_selected.emit(index))
	function_wheel.cancel_requested.connect(func(): function_cancelled.emit())
	inventory_panel.item_used.connect(_use_inventory_item)
	inventory_panel.slot_requested.connect(func(index: int): slot_requested.emit(index))
	blueprint_workshop.closed.connect(func(): design_closed.emit())
	notebook_panel.closed.connect(func(): design_closed.emit())
	show_message("欢迎来到晴风岛 · 试着敲下一块草地，再建造你的家")

func _process(delta: float) -> void:
	toast_time = maxf(0.0, toast_time - delta)
	toast.modulate.a = minf(toast_time * 2.0, 1.0)

func update_status(text: String, amount: float, first_person: bool, mined: int, placed: int) -> void:
	target.text = text
	progress.value = amount * 100.0
	progress.visible = amount > 0.0
	var mode_str := "精密建造 · 第一人称" if first_person else "自由探索 · 第三人称"
	if swimming:
		mode_str = ("水下潜泳" if submerged else "海面游泳") + (" · 第一人称" if first_person else " · 第三人称")
	if sitting:
		mode_str = "坐在方块上" + (" · 第一人称" if first_person else " · 第三人称")
	mode_label.text = mode_str
	if has_node("Root/TopRight/Mode"):
		$Root/TopRight/Mode.text = mode_str
	$Root/TopLeft/Stats.text = "已采集 %d  /  已建造 %d" % [mined, placed]

func update_water_status(in_water: bool, under_surface: bool, camera_underwater: bool, depth: float) -> void:
	swimming = in_water
	submerged = under_surface
	$Root/Underwater.visible = camera_underwater
	depth_label.visible = submerged
	depth_label.text = "潜水深度 %.1f 米" % depth
	if has_node("Root/TopRight/Depth"):
		$Root/TopRight/Depth.visible = submerged
		$Root/TopRight/Depth.text = "潜水深度 %.1f 米" % depth
	_update_help()

func update_function(index: int, seated: bool) -> void:
	active_function = index
	sitting = seated
	var func_str := "当前功能：坐下" if index == 1 else "当前功能：挖掘 / 建造"
	function_label.text = func_str
	if has_node("Root/TopRight/Function"):
		$Root/TopRight/Function.text = func_str
	_update_help()


func _update_help() -> void:
	var help: String = "WASD 移动  ·  左键 挖掘  ·  右键 放置  ·  B 背包  ·  G 人物功能  ·  F 坐下"
	if swimming:
		help = "WASD 游动  ·  空格 上浮  ·  C / Ctrl 下潜  ·  Shift 加速  ·  G 人物功能"
	if active_function == 1:
		help = "对准任意方块，左键坐到顶面  ·  G 切换人物功能  ·  F 快捷坐下"
	if sitting:
		help = "F / WASD / 空格 起身  ·  鼠标 环顾  ·  G 人物功能  ·  V 切换视角"
	$Root/Bottom/Help.text = help

func select_slot(slot: int) -> void:
	selected = slot
	inventory_panel.select_hotbar(slot)
	for i in range(8):
		var button: Button = slots.get_child(i)
		var style: StyleBoxFlat = active_style if i == slot else inactive_style
		button.add_theme_stylebox_override("normal", style)
		button.add_theme_stylebox_override("focus", style)
	var item: Dictionary = inventory.get_slot("bag", slot) if inventory != null else {"id": slot + 1, "count": -1}
	var name: String = str(item.get("custom_name", Catalog.title(item.id))) if item.id != 0 else "空手"
	var count: String = "无限建材" if item.count == -1 else "数量 %d" % item.count
	$Root/Bottom/Selected.text = "手持：%s  ·  %s  ·  %s" % [name, count, inventory.mode_title() if inventory != null else "创造模式"]

func bind_inventory(model: RefCounted) -> void:
	inventory = model
	inventory_panel.bind_inventory(model)
	blueprint_workshop.bind_inventory(model)
	refresh_inventory()
	$Root/TopRight/Mode.text = inventory.mode_title()

func refresh_inventory() -> void:
	if inventory == null:
		return
	for i in range(8):
		var icon = slots.get_child(i).get_node("Icon")
		var item: Dictionary = inventory.get_slot("bag", i)
		icon.set_item_data(item)
		icon.queue_redraw()
		slots.get_child(i).tooltip_text = Catalog.title(item.id)
	select_slot(selected)

func show_message(text: String) -> void:
	toast.text = text
	toast_time = 4.0

func set_paused(value: bool) -> void:
	pause_panel.visible = value

func open_function_wheel(current_function: int, is_seated: bool) -> void:
	function_wheel.open(current_function, is_seated)

func bind_blueprints(value: RefCounted) -> void:
	blueprints = value

func _use_inventory_item(id: int) -> void:
	show_message("把" + Catalog.title(id) + "拖入快捷栏，再对准方块顶面右键放置")

func open_blueprint(player_visual: Node3D = null) -> void:
	blueprint_workshop.set_player_template(player_visual)
	blueprint_workshop.open(blueprints)

func open_notebook() -> void:
	notebook_panel.open(blueprints)

func close_design() -> void:
	blueprint_workshop.visible = false
	notebook_panel.visible = false
	design_closed.emit()

func any_modal_visible() -> bool:
	return pause_panel.visible or inventory_panel.visible or function_wheel.visible or blueprint_workshop.visible or notebook_panel.visible

func update_loading(percent: float, message: String = "") -> void:
	if loading_screen != null and is_instance_valid(loading_screen) and loading_screen.has_method("update_progress"):
		loading_screen.update_progress(percent, message)

func finish_loading() -> void:
	if loading_screen != null and is_instance_valid(loading_screen) and loading_screen.has_method("finish_loading"):
		loading_screen.finish_loading()

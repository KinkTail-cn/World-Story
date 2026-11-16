extends CanvasLayer

signal resume_requested
signal restart_requested
signal quit_requested
signal slot_requested(slot: int)
signal function_selected(index: int)
signal function_cancelled
signal design_closed
signal home_requested
signal save_requested
signal menu_requested
signal settings_requested

const Catalog = preload("res://scripts/inventory/ItemCatalog.gd")
const ItemTooltip = preload("res://scripts/ui/ItemTooltip.gd")
const Layout = preload("res://scripts/ui/ResponsiveLayout.gd")
const UI = preload("res://scripts/ui/UIStyle.gd")
var selected: int = 0
var active_style := StyleBoxFlat.new()
var inactive_style := StyleBoxFlat.new()
var swimming: bool = false
var submerged: bool = false
var active_function: int = 0
var sitting: bool = false
var inventory: RefCounted
var blueprints: RefCounted
var item_tooltip: Control
var vitals_label: Label
var hurt_overlay: ColorRect
var vitals_panel: PanelContainer
var health_bar: ProgressBar
var air_bar: ProgressBar
var air_row: HBoxContainer

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
	UI.apply($Root, true)
	active_style = UI.box(Color("294d55"), UI.GOLD, 8, Vector2.ZERO)
	active_style.set_border_width_all(2)
	inactive_style = UI.box(Color(0.06, 0.13, 0.16, 0.80), Color("486069"), 8, Vector2.ZERO)
	for badge in [$Root/Bottom/HotbarDock]:
		badge.add_theme_stylebox_override("panel", UI.box(Color(0.05, 0.12, 0.15, 0.82), Color(0.5, 0.66, 0.66, 0.24), 12, Vector2.ZERO))
	for label in [$Root/TopLeftPanel, $Root/TopRightPanel, target, toast, $Root/Bottom/Help, $Root/Bottom/Selected]:
		label.hide()
	$Root/Aim/Crosshair.text = "·"
	UI.label($Root/Aim/Crosshair, 28, UI.LIGHT)
	$Root/Aim/Crosshair.add_theme_color_override("font_outline_color", Color("152b34"))
	$Root/Aim/Crosshair.add_theme_constant_override("outline_size", 3)

	item_tooltip = ItemTooltip.new()
	$Root.add_child(item_tooltip)
	_create_sandbox_ui()

	for i in range(8):
		var button: Button = slots.get_child(i)
		button.text = ""
		button.custom_minimum_size = Vector2(76, 76)
		button.focus_mode = Control.FOCUS_NONE
		button.get_node("Icon").slot_number = i + 1
		button.add_theme_stylebox_override("normal", inactive_style)
		button.add_theme_stylebox_override("focus", inactive_style)
		button.add_theme_stylebox_override("pressed", inactive_style)
		button.add_theme_stylebox_override("disabled", inactive_style)
		var hover_style := inactive_style.duplicate()
		hover_style.border_color = UI.GOLD
		button.add_theme_stylebox_override("hover", hover_style)
		button.pressed.connect(func(): slot_requested.emit(i))
		
	
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
	_style_pause()
	$Root.resized.connect(_layout)
	_layout.call_deferred()

func _layout() -> void:
	if not is_node_ready():
		return
	var available: Vector2 = $Root.size
	var bottom: Control = $Root/Bottom
	var factor := minf(1.0, (available.x - 32.0) / 720.0)
	bottom.set_anchors_preset(Control.PRESET_TOP_LEFT)
	bottom.size = Vector2(720, 92)
	bottom.scale = Vector2.ONE * factor
	bottom.position = Vector2((available.x - 720.0 * factor) * 0.5, available.y - bottom.size.y * factor - 16.0)
	for panel in [$Root/TopLeftPanel, $Root/TopRightPanel]:
		var width: float = 280.0 if panel == $Root/TopLeftPanel else 342.0
		var badge_scale := minf(1.0, (available.x - 56.0) / (280.0 + 342.0))
		panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
		panel.size = Vector2(width, 92)
		panel.scale = Vector2.ONE * badge_scale
		panel.position = Vector2(20, 20) if panel == $Root/TopLeftPanel else Vector2(available.x - 20.0 - width * badge_scale, 20)
	toast.set_anchors_preset(Control.PRESET_TOP_LEFT)
	toast.size.x = minf(680, available.x - 32.0)
	toast.position = Vector2((available.x - toast.size.x) * 0.5, 140)
	if vitals_panel != null:
		vitals_panel.size = Vector2(224, vitals_panel.get_combined_minimum_size().y)
		vitals_panel.position = Vector2((available.x - vitals_panel.size.x) * 0.5, bottom.position.y - vitals_panel.size.y - 8)
	Layout.fit_centered($Root/Pause/Panel, available, Vector2(540, 0))

func _process(_delta: float) -> void:
	var clear_view: bool = not any_modal_visible() and not loading_screen.visible
	var settings := $Root.get_node_or_null("SettingsPanel")
	clear_view = clear_view and (settings == null or not settings.visible)
	for control in [$Root/Bottom, $Root/Aim]:
		control.visible = clear_view
	vitals_panel.visible = clear_view and inventory != null and not inventory.is_creative()

func update_status(_text: String, amount: float, _first_person: bool, _mined: int, _placed: int) -> void:
	progress.value = amount * 100.0
	progress.visible = amount > 0.0

func update_water_status(in_water: bool, under_surface: bool, camera_underwater: bool, _depth: float) -> void:
	swimming = in_water
	submerged = under_surface
	$Root/Underwater.visible = camera_underwater

func update_function(index: int, seated: bool) -> void:
	active_function = index
	sitting = seated

func select_slot(slot: int) -> void:
	selected = slot
	inventory_panel.select_hotbar(slot)
	for i in range(8):
		var button: Button = slots.get_child(i)
		var style: StyleBoxFlat = active_style if i == slot else inactive_style
		button.add_theme_stylebox_override("normal", style)
		button.add_theme_stylebox_override("focus", style)

func bind_inventory(model: RefCounted) -> void:
	inventory = model
	inventory_panel.bind_inventory(model)
	blueprint_workshop.bind_inventory(model)
	refresh_inventory()

func refresh_inventory() -> void:
	if inventory == null:
		return
	for i in range(8):
		var icon = slots.get_child(i).get_node("Icon")
		var item: Dictionary = inventory.get_slot("bag", i)
		icon.set_item_data(item)
		icon.queue_redraw()
		slots.get_child(i).tooltip_text = ""
	select_slot(selected)

func show_message(text: String) -> void:
	# Routine gameplay messages stay off the world view. Save failures remain
	# actionable in the current menu, or open pause when no menu is present.
	if text.contains("保存失败"):
		var preferences := $Root.get_node_or_null("SettingsPanel")
		if preferences != null and preferences.visible:
			preferences.get_node("Center/Card/Body/Status").text = text
			return
		if function_wheel.visible:
			function_wheel.close()
		if not any_modal_visible():
			get_tree().paused = true
			set_paused(true)
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		elif blueprint_workshop.visible:
			blueprint_workshop.status_label.text = text
		elif notebook_panel.visible:
			notebook_panel.get_node("Card/Body/Notice").text = text
		elif inventory_panel.visible:
			inventory_panel.show_feedback(text)
	if pause_panel.visible:
		$Root/Pause/Panel/Margin/Content/Description.text = text
		_layout.call_deferred()

func set_paused(value: bool) -> void:
	pause_panel.visible = value
	if value:
		ItemTooltip.hide_card()
		UI.reveal($Root/Pause/Panel)
		$Root/Pause/Panel/Margin/Content/Resume.grab_focus()

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

func _create_sandbox_ui() -> void:
	hurt_overlay = ColorRect.new()
	hurt_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hurt_overlay.color = Color(0.65, 0.1, 0.08, 0.0)
	hurt_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$Root.add_child(hurt_overlay)
	$Root.move_child(hurt_overlay, 1)
	vitals_panel = PanelContainer.new()
	vitals_panel.name = "Vitals"
	vitals_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vitals_panel.add_theme_stylebox_override("panel", UI.box(Color(0.05, 0.12, 0.15, 0.82), Color.TRANSPARENT, 10, Vector2(14, 10)))
	var vitals := VBoxContainer.new()
	vitals.add_theme_constant_override("separation", 8)
	vitals_panel.add_child(vitals)
	vitals_label = Label.new()
	vitals_label.visible = false
	vitals.add_child(vitals_label)
	var health_row := HBoxContainer.new()
	health_row.add_theme_constant_override("separation", 10)
	vitals.add_child(health_row)
	var heart := TextureRect.new()
	heart.texture = UI.icon("heart", Color("83b9a7"))
	heart.custom_minimum_size = Vector2(18, 18)
	heart.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	heart.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	health_row.add_child(heart)
	health_bar = ProgressBar.new()
	health_bar.custom_minimum_size = Vector2(168, 5)
	health_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	health_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	health_bar.show_percentage = false
	health_row.add_child(health_bar)
	air_row = HBoxContainer.new()
	air_row.add_theme_constant_override("separation", 10)
	vitals.add_child(air_row)
	var breath := TextureRect.new()
	breath.texture = UI.icon("air", Color("8fcbd4"))
	breath.custom_minimum_size = Vector2(18, 18)
	breath.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	breath.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	air_row.add_child(breath)
	air_bar = ProgressBar.new()
	air_bar.custom_minimum_size = Vector2(168, 5)
	air_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	air_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	air_bar.show_percentage = false
	air_bar.max_value = 18.0
	air_bar.add_theme_stylebox_override("fill", UI.box(Color("8fcbd4"), Color.TRANSPARENT, 3, Vector2.ZERO))
	air_row.add_child(air_bar)
	$Root.add_child(vitals_panel)
	$Root.move_child(vitals_panel, $Root/FunctionWheel.get_index())
	var pause_content := $Root/Pause/Panel/Margin/Content
	for data in [{"title": "保存进度  F5", "action": save_requested}, {"title": "游戏设置", "action": settings_requested}, {"title": "返回出生点", "action": home_requested}, {"title": "保存并返回标题", "action": menu_requested}]:
		var button: Button = $Root/Pause/Panel/Margin/Content/Resume.duplicate()
		button.text = data.title
		button.name = "Action" + str(pause_content.get_child_count())
		for connection in button.pressed.get_connections():
			button.pressed.disconnect(connection.callable)
		var action: Signal = data.action
		button.pressed.connect(func(): action.emit())
		pause_content.add_child(button)
		pause_content.move_child(button, pause_content.get_child_count() - 3)
	$Root/Pause/Panel/Margin/Content/Title.text = "游戏暂停"
	$Root/Pause/Panel/Margin/Content/Description.text = "返回出生点保留背包物品 · 出生点附近可恢复生命\n每两分钟自动保存，F5 随时保存。"
	$Root/Pause/Panel/Margin/Content/Quit.text = "保存并退出游戏"
	$Root/TopRightPanel/Margin/TopRight/Keys.text = "B 背包   P 工坊   N 笔记   Esc 暂停"

func _style_pause() -> void:
	var content := $Root/Pause/Panel/Margin/Content
	UI.apply($Root/Pause)
	UI.panel($Root/Pause/Panel, false, Vector2.ZERO)
	$Root/Pause/Panel/Margin.add_theme_constant_override("margin_top", 26)
	$Root/Pause/Panel/Margin.add_theme_constant_override("margin_bottom", 26)
	content.add_theme_constant_override("separation", 14)
	UI.label(content.get_node("Title"), 28, UI.INK, true)
	UI.label(content.get_node("Description"), 13, UI.MUTED)
	content.get_node("Description").autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.get_node("Description").text = "歇一会儿，再继续创造。\n每两分钟自动保存，也可按 F5 随时保存。"
	content.get_node("Resume").text = "继续游戏   →"
	UI.button(content.get_node("Resume"), "primary")
	var actions := GridContainer.new()
	actions.name = "Actions"
	actions.columns = 2
	actions.add_theme_constant_override("h_separation", 10)
	actions.add_theme_constant_override("v_separation", 10)
	content.add_child(actions)
	for child in content.get_children():
		if child is Button and child.name != "Resume":
			child.reparent(actions)
			child.custom_minimum_size = Vector2(210, 42)
			child.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			UI.button(child, "danger" if child.name == "Restart" else "secondary", true)

func update_vitals(health: float, air: float, hurt: bool) -> void:
	var creative: bool = inventory != null and inventory.is_creative()
	health_bar.value = health
	health_bar.add_theme_stylebox_override("fill", UI.box(UI.ERROR if health < 30 else Color("83b9a7"), Color.TRANSPARENT, 3, Vector2.ZERO))
	var show_air := not creative and air < 17.5
	if air_row.visible != show_air:
		air_row.visible = show_air
		_layout.call_deferred()
	air_bar.value = air
	hurt_overlay.color.a = 0.1 if hurt and not creative else 0.0

func update_loading(percent: float, message: String = "") -> void:
	if loading_screen != null and is_instance_valid(loading_screen) and loading_screen.has_method("update_progress"):
		loading_screen.update_progress(percent, message)

func finish_loading() -> void:
	if loading_screen != null and is_instance_valid(loading_screen) and loading_screen.has_method("finish_loading"):
		loading_screen.finish_loading()

extends Control

# ==============================================================================
# 三维蓝图工坊 / 装备设计台 控制器
# 遵循规范：UI场景化拼装、视轨平滑运镜、抽屉式侧边栏布局、三维旋转球交互
# ==============================================================================

signal blueprint_saved(blueprint: Dictionary)
signal item_crafted(item: Dictionary)
signal closed

const BlueprintDataScript = preload("res://scripts/blueprint/BlueprintData.gd")
const ManagerScript = preload("res://scripts/blueprint/BlueprintManager.gd")
const CharacterVisualScript = preload("res://scripts/player/CharacterVisual.gd")
const EquipmentDesign = preload("res://scripts/blueprint/BlueprintEquipment.gd")
const Geometry = preload("res://scripts/blueprint/BlueprintGeometry.gd")
const Materials = preload("res://scripts/blueprint/BlueprintMaterials.gd")
const EditSession = preload("res://scripts/blueprint/BlueprintEditSession.gd")
const Presets = preload("res://scripts/blueprint/BlueprintPresets.gd")
const InspectorScene = preload("res://scenes/BlueprintInspector.tscn")
const BlueprintRenderer = preload("res://scripts/player/BlueprintEquipmentVisual.gd")

const CATEGORIES: Array[String] = [
	"头部装备", "盔甲", "裤甲", "鞋子", "手套", "披风", "腰带", "武器", "工具", "道具摆件"
]
const MATERIAL_COLORS: Array[Color] = EquipmentDesign.MATERIAL_COLORS
const MATERIAL_NAMES: Array[String] = EquipmentDesign.MATERIAL_NAMES
const VOXEL_SIZE: float = 0.13

# 基础数据模型与选中状态
var manager: RefCounted
var inventory: RefCounted
var blueprint
var current_category: String = "头部装备"
var selected_material: int = 1
var erase_mode: bool = false

# 三维视口与相机视轨控制参数
var preview_viewport: SubViewport
var preview_root: Node3D
var preview_camera: Camera3D
var orbit: Node3D
var orbit_yaw: float = 0.5
var orbit_pitch: float = -0.16
var preview_distance: float = 3.6
var target_look_center: Vector3 = Vector3(0, 1.4, 0)
var current_look_center: Vector3 = Vector3(0, 1.4, 0)
var camera_tween: Tween

# 观察手势、选择与画布拖动状态
var dragging_preview: bool = false
var preview_press_position := Vector2.ZERO
var gizmo_dragging: bool = false

# 真实游戏人物与体素容器
var template_root: Node3D
var voxel_container: Node3D
var template_parts: Array[Dictionary] = []
var voxel_blocks: Array[Dictionary] = []
var player_template: Node3D
var real_character: Node3D
var current_equipment_ids: Array[int] = [0, 0, 0, 0, 0, 0, 0]
var current_equipment_items: Array[Dictionary] = []

# 装饰品与神圣展示底座（用不同颜色与大小的方块还原）
var decor_root: Node3D
var floating_motes: Array[Node3D] = []
var motes_time: float = 0.0

# 抽屉展开状态
var left_drawer_open: bool = true
var right_drawer_open: bool = true

# 节点引用（UI场景化，基于场景预置节点）
@onready var preview_container: SubViewportContainer = $PreviewContainer
@onready var status_label: Label = $TopBar/Status
@onready var close_button: Button = $TopBar/CloseButton

# 左侧制作物品选择抽屉
@onready var left_drawer: Control = $LeftDrawer
@onready var left_toggle_btn: Button = $LeftDrawer/LeftToggleBtn
@onready var name_edit: LineEdit = $LeftDrawer/Panel/Margin/VBox/NameEdit
@onready var saved_designs: OptionButton = $LeftDrawer/Panel/Margin/VBox/SavedDesigns
@onready var new_design_btn: Button = $LeftDrawer/Panel/Margin/VBox/NewDesign
@onready var category_selector: OptionButton = %CategorySelector

# 右上角三维旋转球与复位按钮
@onready var rotate_gizmo: Control = $RotateGizmo
@onready var gizmo_disc: Panel = $RotateGizmo/BallArea/Disc
@onready var ball_canvas: Control = $RotateGizmo/BallArea/Disc/BallCanvas
@onready var gizmo_up: Button = $RotateGizmo/BallArea/Disc/UpBtn
@onready var gizmo_down: Button = $RotateGizmo/BallArea/Disc/DownBtn
@onready var gizmo_left: Button = $RotateGizmo/BallArea/Disc/LeftBtn
@onready var gizmo_right: Button = $RotateGizmo/BallArea/Disc/RightBtn
@onready var reset_btn: Button = $RotateGizmo/ResetBtn

# 方块尺寸选择（1/4 大小双倍体积 0.26，1/8 标准微体素 0.13，1/16 精细雕刻 0.065，1/32 超微细节 0.0325）
const SIZE_EIGHTH: int = 1
const SIZE_QUARTER: int = 2
const SIZE_SIXTEENTH: int = 3
const SIZE_THIRTYSECOND: int = 4
var current_voxel_size: int = SIZE_EIGHTH

# 悬停预选方框（在放置前呈现半透明材质方块与发光三维线框）
var hover_indicator: Node3D
var hover_mesh: MeshInstance3D
var hover_outline_box: Node3D
var hover_material: StandardMaterial3D

# 右侧材料与工具抽屉
@onready var right_drawer: Control = $RightDrawer
@onready var right_toggle_btn: Button = $RightDrawer/RightToggleBtn
@onready var size_quarter_btn: Button = $RightDrawer/Panel/Margin/VBox/SizeBox/SizeQuarterBtn
@onready var size_eighth_btn: Button = $RightDrawer/Panel/Margin/VBox/SizeBox/SizeEighthBtn
@onready var size_sixteenth_btn: Button = $RightDrawer/Panel/Margin/VBox/SizeBox/SizeSixteenthBtn
@onready var size_thirtysecond_btn: Button = $RightDrawer/Panel/Margin/VBox/SizeBox/SizeThirtySecondBtn
@onready var palette_grid: GridContainer = $RightDrawer/Panel/Margin/VBox/PaletteGrid
@onready var count_label: Label = $RightDrawer/Panel/Margin/VBox/CountLabel
@onready var erase_btn: CheckButton = $RightDrawer/Panel/Margin/VBox/ToolsGrid/Erase
@onready var mirror_btn: Button = $RightDrawer/Panel/Margin/VBox/ToolsGrid/Mirror
@onready var clear_btn: Button = $RightDrawer/Panel/Margin/VBox/ToolsGrid/Clear
@onready var reset_cam_btn: Button = $RightDrawer/Panel/Margin/VBox/ToolsGrid/ResetCam
@onready var zoom_slider: HSlider = $RightDrawer/Panel/Margin/VBox/ZoomBox/ZoomSlider
@onready var save_btn: Button = $RightDrawer/Panel/Margin/VBox/Save
@onready var craft_btn: Button = $RightDrawer/Panel/Margin/VBox/Craft
@onready var cost_label: Label = $RightDrawer/Panel/Margin/VBox/Cost

var edit_session = EditSession.new()
var inspector: Control
var editor_mode: String = "add"
var brush: Dictionary = {"shape": "box", "mat": 1, "size": 1}
var preview_pose: int = 0
var pose_renderer: Node3D
var camera_dragging: bool = false
var pan_dragging: bool = false
var box_selecting: bool = false
var box_end := Vector2.ZERO
var selection_overlay: Control
var _refreshing_parts: bool = false
var _last_save_success: bool = true
var _pending_transition: Callable
var drag_snapshot: Dictionary = {}
var drag_started: bool = false
var _pose_view: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP
	_setup_preview()
	_setup_ui_events()
	_setup_controls_scroll()
	_setup_editor()
	_build_category_buttons()
	_bind_palette_buttons()
	set_process(true)
	visible = false


func _process(delta: float) -> void:
	if not visible:
		return
	if preview_pose > 0 and is_instance_valid(real_character):
		real_character.animate(delta, 7.8 if preview_pose == 1 else (4.2 if preview_pose == 3 else 0.0), false, preview_pose == 4, preview_pose == 3, preview_pose == 3, preview_pose == 2, preview_pose == 1)
		if is_instance_valid(pose_renderer):
			pose_renderer.set_wind(real_character.equipment_visuals.cape_wind)
	motes_time += delta
	# 驱动漂浮神圣金光体素微粒轻柔游弋
	for mote in floating_motes:
		if is_instance_valid(mote):
			var base: Vector3 = mote.get_meta("base_pos", mote.position)
			var freq: float = mote.get_meta("freq", 1.5)
			var phase: float = mote.get_meta("phase", 0.0)
			mote.position.y = base.y + sin(motes_time * freq + phase) * 0.08
			mote.rotation.y += delta * 0.9
			mote.rotation.x += delta * 0.5


# -----------------------------------------------------------------------------
# 初始化与外部入口
# -----------------------------------------------------------------------------

func open(value: RefCounted) -> void:
	if manager != null and manager.changed.is_connected(_refresh_library):
		manager.changed.disconnect(_refresh_library)
	manager = value
	var typed_manager = manager if manager != null and manager.get_script() == ManagerScript else null
	if typed_manager != null:
		typed_manager.changed.connect(_refresh_library)
	if typed_manager != null and typed_manager.current != null:
		blueprint = typed_manager.current
	else:
		blueprint = BlueprintDataScript.new("未命名蓝图", "头部装备")
		if typed_manager != null:
			typed_manager.current = blueprint
	
	name_edit.text = blueprint.name
	_bind_edit_session()
	var category_to_select: String = str(blueprint.category) if (blueprint != null and str(blueprint.category) in CATEGORIES) else "头部装备"
	_select_category(category_to_select, true)
	visible = true
	_refresh_library()
	_refresh_crafting()

func bind_inventory(value: RefCounted) -> void:
	if inventory != null and inventory.changed.is_connected(_refresh_crafting):
		inventory.changed.disconnect(_refresh_crafting)
	inventory = value
	if inventory != null:
		inventory.changed.connect(_refresh_crafting)
	_refresh_crafting()

func _setup_controls_scroll() -> void:
	var controls := $RightDrawer/Panel/Margin/VBox
	var stack := VBoxContainer.new()
	stack.name = "Stack"
	stack.add_theme_constant_override("separation", 10)
	controls.get_parent().add_child(stack)
	var scroll := ScrollContainer.new()
	scroll.name = "Scroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stack.add_child(scroll)
	controls.reparent(scroll)
	controls.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var actions := HBoxContainer.new()
	actions.name = "Actions"
	cost_label.reparent(stack)
	stack.add_child(actions)
	save_btn.reparent(actions)
	craft_btn.reparent(actions)
	save_btn.text = "保存"
	craft_btn.text = "制作入包"
	save_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	craft_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cost_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART


func set_player_template(source: Node3D) -> void:
	player_template = source
	_extract_equipment_from_source(source)
	if is_node_ready() and visible:
		_rebuild_template()


func _extract_equipment_from_source(source: Node3D) -> void:
	current_equipment_ids = [0, 0, 0, 0, 0, 0, 0]
	current_equipment_items.clear()
	if source == null:
		return
	
	# 优先从父级 Player 节点的 inventory.equipment 读取实时穿戴数据
	var parent_node := source.get_parent()
	if parent_node != null and "inventory" in parent_node and parent_node.inventory != null and "equipment" in parent_node.inventory:
		var eq = parent_node.inventory.equipment
		if eq is Array:
			for i in range(mini(7, eq.size())):
				current_equipment_ids[i] = int(eq[i])
				current_equipment_items.append(parent_node.inventory.get_slot("equipment", i))
			return
	
	# 如果直接传入的是 Player 实例
	if "inventory" in source and source.inventory != null and "equipment" in source.inventory:
		var eq = source.inventory.equipment
		if eq is Array:
			for i in range(mini(7, eq.size())):
				current_equipment_ids[i] = int(eq[i])
				current_equipment_items.append(source.inventory.get_slot("equipment", i))
			return
	
	# 尝试从 EquipmentVisuals 的子部件可见性逆向提取
	var eq_visual: Node3D = source.get_node_or_null("EquipmentVisuals")
	if eq_visual == null and "equipment_visuals" in source:
		eq_visual = source.equipment_visuals
	if eq_visual != null and "equipped_ids" in eq_visual:
		current_equipment_ids = eq_visual.equipped_ids.duplicate()
		current_equipment_items.assign(eq_visual.equipped_items)
		return
	
	if eq_visual != null and "pieces" in eq_visual and eq_visual.pieces is Array:
		for slot in range(mini(7, eq_visual.pieces.size())):
			var pieces_arr = eq_visual.pieces[slot]
			if pieces_arr is Array:
				for p in pieces_arr:
					if is_instance_valid(p) and p is Node3D and p.visible:
						current_equipment_ids[slot] = 101 + slot
						break


func close() -> void:
	request_close()

func request_close() -> void:
	_transition(_finish_close)

func _finish_close() -> void:
	_set_preview_pose(0)
	edit_session.undo_stack.clear()
	edit_session.redo_stack.clear()
	visible = false
	closed.emit()

func cancel_edit() -> bool:
	if %UnsavedDialog.visible:
		%UnsavedDialog.hide()
		return true
	if not drag_snapshot.is_empty():
		edit_session.restore_snapshot(drag_snapshot)
		drag_snapshot.clear()
		drag_started = false
		dragging_preview = false
		return true
	if camera_dragging or dragging_preview or box_selecting:
		camera_dragging = false
		dragging_preview = false
		box_selecting = false
		selection_overlay.queue_redraw()
		return true
	if not edit_session.selection.is_empty():
		edit_session.select([])
		return true
	return false

func _transition(next: Callable) -> void:
	var typed_name := name_edit.text.strip_edges()
	if typed_name.is_empty():
		typed_name = "未命名蓝图"
	if edit_session.blueprint != null and (edit_session.dirty() or typed_name != blueprint.name):
		_pending_transition = next
		%UnsavedDialog.popup_centered()
	else:
		next.call()

func set_save_result(success: bool) -> void:
	_last_save_success = success


# -----------------------------------------------------------------------------
# 三维视口与渲染相机配置
# -----------------------------------------------------------------------------

func _setup_preview() -> void:
	preview_viewport = SubViewport.new()
	preview_viewport.name = "PreviewViewport"
	# 初始分辨率匹配容器大小，避免拉伸失真
	var initial_size := Vector2i(preview_container.size)
	if initial_size.x <= 50 or initial_size.y <= 50:
		initial_size = Vector2i(1280, 800)
	preview_viewport.size = initial_size
	preview_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	# 启用透明背景，使 3D 人物与展台完美悬浮于沉稳雅致的聚光灯暗调背景之上
	preview_viewport.transparent_bg = true
	preview_viewport.world_3d = World3D.new()
	preview_container.add_child(preview_viewport)

	# 0. 专属影棚环境配置（电影级ACES色调映射 + 柔和环境光遮蔽）
	var world_env := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_CANVAS
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#b5c8db")
	env.ambient_light_energy = 0.35
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_white = 1.0
	env.ssao_enabled = true
	env.ssao_radius = 0.35
	env.ssao_intensity = 1.6
	world_env.environment = env
	preview_viewport.add_child(world_env)

	# 1. 静态世界容器（人物与微体素静止安放，绝对不随相机旋转）
	preview_root = Node3D.new()
	preview_root.name = "PreviewRoot"
	preview_viewport.add_child(preview_root)

	# 2. 独立相机旋转枢纽（位置对齐观察焦点，全向自由回旋）
	orbit = Node3D.new()
	orbit.name = "CameraPivot"
	preview_viewport.add_child(orbit)

	# 3. 观察相机（挂载在枢纽下，纯沿局部+Z后退，始终直视枢纽原点）
	preview_camera = Camera3D.new()
	preview_camera.fov = 38.0 # 38度平实透视，人物形态端庄真实，消除畸变
	preview_camera.far = 150.0
	orbit.add_child(preview_camera)
	var view_fill := DirectionalLight3D.new()
	view_fill.name = "ViewFill"
	view_fill.light_energy = 0.35
	view_fill.light_color = Color("e0e8ed")
	view_fill.rotation_degrees = Vector3(-10, -15, 0)
	preview_camera.add_child(view_fill)

	# 4. 专业影视级三点立体布光系统（告别正面暴晒死白，塑造立体雕塑感）
	# (1) 主光（Key Light）：右前方斜上方45度投射，适度能量塑造自然的微明暗面
	var key_light := DirectionalLight3D.new()
	key_light.rotation_degrees = Vector3(-35, 32, 0)
	key_light.light_energy = 0.35
	key_light.light_color = Color("#fffcf5")
	key_light.shadow_enabled = true
	key_light.directional_shadow_max_distance = 10.0
	preview_viewport.add_child(key_light)

	# (2) 前侧补光（Fill Light）：左前上方柔和漫射冷光，照亮暗面细节，绝不过曝
	var fill_light := OmniLight3D.new()
	fill_light.position = Vector3(-2.2, 1.4, 2.0)
	fill_light.light_color = Color("#d0e2f5")
	fill_light.omni_range = 9.0
	fill_light.light_energy = 0.10
	preview_viewport.add_child(fill_light)

	# (3) 核心高光轮廓背光（Rim / Back Light）：正后方斜上方精准投射，在头顶、双肩与手臂勾勒耀眼金光边
	var rim_light := OmniLight3D.new()
	rim_light.position = Vector3(0.0, 2.6, -2.4)
	rim_light.light_color = Color("#ffe7ba")
	rim_light.omni_range = 8.5
	rim_light.light_energy = 0.35
	preview_viewport.add_child(rim_light)

	# (4) 展台微光（Bounce Light）：从青苔石阶底部柔和反射，衬托人物立足点
	var bounce_light := OmniLight3D.new()
	bounce_light.position = Vector3(0.0, -0.4, 0.4)
	bounce_light.light_color = Color("#b8dca2")
	bounce_light.omni_range = 4.0
	bounce_light.light_energy = 0.05
	preview_viewport.add_child(bounce_light)

	# 绑定容器输入、鼠标移出与尺寸自适应监听
	preview_container.gui_input.connect(_preview_input)
	preview_container.mouse_filter = Control.MOUSE_FILTER_STOP
	preview_container.resized.connect(_on_preview_container_resized)
	preview_container.mouse_exited.connect(func():
		if hover_indicator != null:
			hover_indicator.visible = false
	)
	
	_create_hover_indicator()
	_update_camera_transform()


func _create_hover_indicator() -> void:
	if hover_indicator != null and is_instance_valid(hover_indicator):
		return
	hover_indicator = Node3D.new()
	hover_indicator.name = "HoverIndicator"
	hover_indicator.visible = false
	preview_viewport.add_child(hover_indicator)

	# 1. 内部半透明预览方块
	hover_mesh = MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3.ONE * VOXEL_SIZE
	hover_mesh.mesh = box
	
	hover_material = StandardMaterial3D.new()
	hover_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	hover_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	hover_material.albedo_color = Color(MATERIAL_COLORS[selected_material - 1], 0.45)
	hover_mesh.material_override = hover_material
	hover_indicator.add_child(hover_mesh)

	# 2. 外部高亮金色线框（十二条边缘线段，立体通透不穿模）
	hover_outline_box = Node3D.new()
	hover_indicator.add_child(hover_outline_box)
	
	var edge_mat := StandardMaterial3D.new()
	edge_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	edge_mat.albedo_color = Color("#ffe066") # 暖阳金辉轮廓线
	
	var h: float = VOXEL_SIZE * 0.502
	var corners: Array[Vector3] = []
	for x in [-h, h]:
		for y in [-h, h]:
			for z in [-h, h]:
				corners.append(Vector3(x, y, z))
	
	for a in range(8):
		for b in range(a + 1, 8):
			var diff: Vector3 = (corners[a] - corners[b]).abs()
			if int(diff.x > 0.0) + int(diff.y > 0.0) + int(diff.z > 0.0) != 1:
				continue
			var edge_box := BoxMesh.new()
			edge_box.size = diff + Vector3.ONE * 0.006
			var edge_inst := MeshInstance3D.new()
			edge_inst.mesh = edge_box
			edge_inst.material_override = edge_mat
			edge_inst.position = (corners[a] + corners[b]) * 0.5
			hover_outline_box.add_child(edge_inst)


func _update_hover_indicator_visual(is_erase: bool) -> void:
	if hover_material == null:
		return
	if is_erase:
		hover_material.albedo_color = Color(1.0, 0.25, 0.25, 0.55) # 橡皮擦警戒红
	else:
		var c: Color = MATERIAL_COLORS[selected_material - 1]
		hover_material.albedo_color = Color(c.r, c.g, c.b, 0.5) # 当前选定材料色半透明


func _on_preview_container_resized() -> void:
	if preview_container != null and preview_viewport != null and not preview_container.stretch:
		var new_size := Vector2i(preview_container.size)
		if new_size.x > 50 and new_size.y > 50:
			preview_viewport.size = new_size


func _update_camera_transform() -> void:
	if orbit == null or preview_camera == null:
		return
	# 视轨枢纽平移至当前骨骼观察焦点
	orbit.position = current_look_center
	# 视轨枢纽全向回旋（偏航角与俯仰角）
	orbit.rotation = Vector3(orbit_pitch, orbit_yaw, 0.0)
	# 相机在局部坐标系直视中心原点
	preview_camera.position = Vector3(0, 0, preview_distance)
	preview_camera.rotation = Vector3.ZERO
	
	zoom_slider.set_value_no_signal(preview_distance)
	if ball_canvas != null and is_instance_valid(ball_canvas):
		ball_canvas.queue_redraw()


# -----------------------------------------------------------------------------
# 关键特性：选择部位时视角平滑聚焦（Camera Focus Tween）
# -----------------------------------------------------------------------------

func _focus_camera_on_category(category: String, immediate: bool = false) -> void:
	# 各身体部位对应真实角色的骨骼空间焦点与人体工学观察视距
	var target_center := Vector3(0, 1.05, 0)
	var target_dist: float = 2.35
	var target_pitch: float = -0.06
	# 默认正面对视视角；仅当设计披风时自动转到背后
	var target_yaw: float = PI if category == "披风" else 0.0

	match category:
		"头部装备":
			target_center = Vector3(0, 1.62, 0)
			target_dist = 1.82
			target_pitch = -0.04
		"盔甲":
			target_center = Vector3(0, 1.08, 0)
			target_dist = 2.25
			target_pitch = -0.06
		"裤甲":
			target_center = Vector3(0, 0.42, 0)
			target_dist = 2.05
			target_pitch = -0.08
		"鞋子":
			target_center = Vector3(0, 0.12, 0)
			target_dist = 1.70
			target_pitch = -0.12
		"手套":
			target_center = Vector3(0, 0.85, 0)
			target_dist = 2.15
			target_pitch = -0.06
		"披风":
			target_center = Vector3(0, 1.25, 0)
			target_dist = 2.35
			target_pitch = -0.06
			target_yaw = PI
		"腰带":
			target_center = Vector3(0, 0.72, 0)
			target_dist = 1.95
			target_pitch = -0.05
		"武器", "工具":
			target_center = Vector3(-0.34, 0.82, 0.10)
			target_dist = 2.0
			target_pitch = -0.06
		_:
			target_center = Vector3(0, 0.50, 0)
			target_dist = 2.35
			target_pitch = -0.10

	if immediate:
		current_look_center = target_center
		preview_distance = target_dist
		orbit_pitch = target_pitch
		orbit_yaw = target_yaw
		_update_camera_transform()
		return

	if camera_tween != null and camera_tween.is_running():
		camera_tween.kill()

	# 丝滑平滑过渡（Cubic Out 缓动）
	camera_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	camera_tween.tween_method(func(pos: Vector3):
		current_look_center = pos
		_update_camera_transform()
	, current_look_center, target_center, 0.38)

	camera_tween.tween_method(func(dist: float):
		preview_distance = dist
		_update_camera_transform()
	, preview_distance, target_dist, 0.38)

	camera_tween.tween_method(func(pitch: float):
		orbit_pitch = pitch
		_update_camera_transform()
	, orbit_pitch, target_pitch, 0.38)

	camera_tween.tween_method(func(yaw: float):
		orbit_yaw = yaw
		_update_camera_transform()
	, orbit_yaw, target_yaw, 0.38)


# -----------------------------------------------------------------------------
# 抽屉式侧边栏折叠/展开动画
# -----------------------------------------------------------------------------

func _toggle_left_drawer() -> void:
	left_drawer_open = not left_drawer_open
	left_toggle_btn.text = "◀" if left_drawer_open else "▶"
	var target_x: float = 18.0 if left_drawer_open else -255.0
	var tween := create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(left_drawer, "offset_left", target_x, 0.28)
	tween.parallel().tween_property(left_drawer, "offset_right", target_x + 250.0, 0.28)


func _toggle_right_drawer() -> void:
	right_drawer_open = not right_drawer_open
	right_toggle_btn.text = "▶" if right_drawer_open else "◀"
	var target_offset_right: float = -18.0 if right_drawer_open else 270.0
	var tween := create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(right_drawer, "offset_right", target_offset_right, 0.28)
	tween.parallel().tween_property(right_drawer, "offset_left", target_offset_right - 282.0, 0.28)


# -----------------------------------------------------------------------------
# 界面事件绑定（遵照UI场景化规范）
# -----------------------------------------------------------------------------

func _setup_ui_events() -> void:
	close_button.pressed.connect(close)
	name_edit.text_changed.connect(func(text: String):
		if blueprint != null:
			blueprint.name = text.strip_edges() if not text.strip_edges().is_empty() else "未命名蓝图"
	)
	left_toggle_btn.pressed.connect(_toggle_left_drawer)
	right_toggle_btn.pressed.connect(_toggle_right_drawer)
	
	# 右上角三维旋转球方向按键与复位按钮
	gizmo_up.pressed.connect(func(): _rotate_gizmo(0.0, 0.22))
	gizmo_down.pressed.connect(func(): _rotate_gizmo(0.0, -0.22))
	gizmo_left.pressed.connect(func(): _rotate_gizmo(PI * 0.25, 0.0))
	gizmo_right.pressed.connect(func(): _rotate_gizmo(-PI * 0.25, 0.0))
	for button in [gizmo_up, gizmo_down, gizmo_left, gizmo_right]:
		button.add_theme_color_override("font_color", Color("#3d2e1e"))
	reset_btn.pressed.connect(_reset_camera_pose)
	gizmo_disc.gui_input.connect(_gizmo_disc_input)
	ball_canvas.draw.connect(_draw_ball_gizmo)

	# 方块尺寸选择切换（1/4、1/8、1/16、1/32）
	if size_quarter_btn != null:
		size_quarter_btn.pressed.connect(func(): _select_size(SIZE_QUARTER))
	if size_eighth_btn != null:
		size_eighth_btn.pressed.connect(func(): _select_size(SIZE_EIGHTH))
	if size_sixteenth_btn != null:
		size_sixteenth_btn.pressed.connect(func(): _select_size(SIZE_SIXTEENTH))
	if size_thirtysecond_btn != null:
		size_thirtysecond_btn.pressed.connect(func(): _select_size(SIZE_THIRTYSECOND))
	_update_size_buttons()

	# 工具栏功能按键
	erase_btn.toggled.connect(func(pressed: bool):
		erase_mode = pressed
		_update_hover_indicator_visual(erase_mode)
		_refresh_palette_highlight()
		status_label.text = "橡皮擦已开启 · 点击方块移除" if erase_mode else "橡皮擦已关闭"
	)
	mirror_btn.pressed.connect(_mirror_x)
	clear_btn.pressed.connect(_clear_all)
	reset_cam_btn.pressed.connect(_reset_camera_pose)
	save_btn.pressed.connect(_save_pressed)
	craft_btn.pressed.connect(_craft_pressed)
	saved_designs.item_selected.connect(_load_design)
	new_design_btn.pressed.connect(_new_design)
	zoom_slider.value_changed.connect(func(val: float):
		preview_distance = clampf(val, 1.6, 8.0)
		_update_camera_transform()
	)


func _get_size_scale(size_val: int) -> float:
	match size_val:
		SIZE_QUARTER:
			return 2.0
		SIZE_EIGHTH:
			return 1.0
		SIZE_SIXTEENTH:
			return 0.5
		SIZE_THIRTYSECOND:
			return 0.25
		_:
			return 1.0


func _select_size(size_val: int) -> void:
	current_voxel_size = size_val
	brush["size"] = size_val
	brush["dimensions"] = Geometry.array(Vector3.ONE * VOXEL_SIZE * _get_size_scale(size_val))
	if inspector != null:
		inspector.set_dimensions(Geometry.dimensions(brush))
	_update_size_buttons()
	if hover_indicator != null:
		var s := _get_size_scale(current_voxel_size)
		hover_indicator.scale = Vector3.ONE * s
	match size_val:
		SIZE_QUARTER:
			status_label.text = "已切换为 1/4 大小方块 (0.26m) · 快速铺装大面积与厚实结构"
		SIZE_EIGHTH:
			status_label.text = "已切换为 1/8 大小方块 (0.13m) · 标准体素构建"
		SIZE_SIXTEENTH:
			status_label.text = "已切换为 1/16 大小方块 (0.065m) · 精细纹理雕刻"
		SIZE_THIRTYSECOND:
			status_label.text = "已切换为 1/32 大小方块 (0.0325m) · 超微体素细节"


func _update_size_buttons() -> void:
	var buttons: Dictionary = {
		SIZE_QUARTER: size_quarter_btn,
		SIZE_EIGHTH: size_eighth_btn,
		SIZE_SIXTEENTH: size_sixteenth_btn,
		SIZE_THIRTYSECOND: size_thirtysecond_btn,
	}
	for s_val in buttons:
		var btn: Button = buttons[s_val]
		if btn != null:
			var is_active: bool = (current_voxel_size == int(s_val))
			btn.modulate = Color(1.0, 1.0, 1.0) if is_active else Color(0.72, 0.72, 0.72)
			btn.add_theme_color_override("font_color", Color("#d48822") if is_active else Color("#3d525c"))


func _rotate_gizmo(yaw_delta: float, pitch_delta: float) -> void:
	orbit_yaw += yaw_delta
	# 范围扩展至 ±85°，实现真正从天顶俯视至地底仰视的全方位旋转
	orbit_pitch = clampf(orbit_pitch + pitch_delta, -1.48, 1.48)
	_update_camera_transform()


func _reset_camera_pose() -> void:
	# 复位相机到当前身体部位的默认正前视角（披风切至正背面）
	orbit_yaw = PI if current_category == "披风" else 0.0
	orbit_pitch = -0.06
	_focus_camera_on_category(current_category, false)
	status_label.text = "已复位视角 · 正面观察当前部位"


func _gizmo_disc_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			gizmo_dragging = event.pressed
			if gizmo_dragging:
				# 支持在球面上直接点击对齐视角方位
				var center := ball_canvas.size * 0.5
				var radius := 36.0
				var click_offset: Vector2 = event.position - center
				if click_offset.length() > 6.0 and click_offset.length() <= radius * 1.15:
					var norm := click_offset / radius
					orbit_yaw = atan2(norm.x, sqrt(maxf(0.01, 1.0 - norm.length_squared())))
					orbit_pitch = clampf(-norm.y * 1.48, -1.48, 1.48)
					_update_camera_transform()
				status_label.text = "长按滑动旋转球 · 全方位调整观察视角"
			if ball_canvas != null and is_instance_valid(ball_canvas):
				ball_canvas.queue_redraw()
			accept_event()
	elif event is InputEventMouseMotion and gizmo_dragging:
		# 全方位三维自由旋转：根据滑动距离驱动偏航角与俯仰角（提升滑动灵敏度，操作极其轻盈顺手）
		orbit_yaw -= event.relative.x * 0.022
		orbit_pitch = clampf(orbit_pitch - event.relative.y * 0.020, -1.48, 1.48)
		_update_camera_transform()
		accept_event()


func _draw_ball_gizmo() -> void:
	var center := ball_canvas.size * 0.5
	var radius := 36.0
	
	# 1. 绘制外部球体阴影与古木托盘底色
	ball_canvas.draw_circle(center, radius + 2.5, Color(0.18, 0.12, 0.08, 0.85))
	
	# 2. 绘制球体立体复古罗盘质感（青铜微绿沉稳色 + 温暖金铜受光高光）
	ball_canvas.draw_circle(center, radius, Color(0.24, 0.28, 0.26, 0.98))
	var highlight_offset := Vector2(-radius * 0.25, -radius * 0.25)
	ball_canvas.draw_circle(center + highlight_offset, radius * 0.65, Color(0.42, 0.50, 0.44, 0.65))
	ball_canvas.draw_circle(center + highlight_offset * 1.3, radius * 0.22, Color(0.92, 0.86, 0.68, 0.75))
	
	# 3. 黄铜外金属环与激活时灿金发光环
	if gizmo_dragging:
		ball_canvas.draw_arc(center, radius + 3.0, 0.0, TAU, 32, Color(1.0, 0.85, 0.35, 0.95), 2.5, true)
	else:
		ball_canvas.draw_arc(center, radius, 0.0, TAU, 32, Color(0.85, 0.68, 0.38, 0.9), 1.8, true)
	
	# 4. 根据当前俯仰角与偏航角，动态绘制倾斜旋转的赤道圈与经线圈（复古细金线）
	var pitch_ratio := sin(orbit_pitch)
	var yaw_cos := cos(orbit_yaw)
	
	# 动态赤道纬线（随俯仰角产生立体椭圆形变）
	var eq_points := PackedVector2Array()
	for i in range(25):
		var angle := float(i) / 24.0 * TAU
		var pt := Vector2(cos(angle) * radius * 0.95, sin(angle) * (radius * pitch_ratio * 0.75))
		eq_points.append(center + pt)
	ball_canvas.draw_polyline(eq_points, Color(0.96, 0.85, 0.55, 0.65), 1.5, true)
	
	# 辅助纬线（增强三维球体网格透视）
	var sub_eq_points := PackedVector2Array()
	for i in range(25):
		var angle := float(i) / 24.0 * TAU
		var pt := Vector2(cos(angle) * radius * 0.72, sin(angle) * (radius * pitch_ratio * 0.55) - pitch_ratio * radius * 0.28)
		sub_eq_points.append(center + pt)
	ball_canvas.draw_polyline(sub_eq_points, Color(0.92, 0.80, 0.50, 0.40), 1.0, true)
	
	# 动态子午经线（随偏航角产生空间立体旋转）
	var meridian_points := PackedVector2Array()
	for i in range(25):
		var angle := float(i) / 24.0 * TAU
		var pt := Vector2(sin(angle) * (radius * yaw_cos * 0.95), cos(angle) * radius * 0.95)
		meridian_points.append(center + pt)
	ball_canvas.draw_polyline(meridian_points, Color(0.96, 0.85, 0.55, 0.65), 1.5, true)
	
	# 5. 【核心设计】：圆中心是人物点位，黄铜古纽扣几何锚点
	ball_canvas.draw_circle(center, 3.4, Color(0.96, 0.84, 0.50, 0.95))
	ball_canvas.draw_circle(center, 1.8, Color(0.25, 0.16, 0.10, 1.0))
	
	# 6. 【核心设计】：红点是玩家的视角！计算玩家摄像机在球面上的投影位置与半球深度
	# 相机相对于球心人物的 3D 单位方向矢量
	var cam_dir := Basis.from_euler(Vector3(orbit_pitch, orbit_yaw, 0.0)) * Vector3(0, 0, 1.0)
	var cam_pt := center + Vector2(cam_dir.x * radius * 0.88, -cam_dir.y * radius * 0.88)
	
	# 如果相机在前半球（面向角色身前），绘制高亮实心红标（白边红心小圆标）；如果绕到背后，绘制半透明空心红圈
	if cam_dir.z >= -0.05:
		# 视线引导段：从红点连向圆中心人物
		ball_canvas.draw_line(cam_pt, center, Color(1.0, 0.45, 0.4, 0.35), 1.2, true)
		# 玩家视角红点：白圈底衬 + 鲜亮红心 + 白色高光
		ball_canvas.draw_circle(cam_pt, 5.5, Color(0.12, 0.16, 0.20, 0.55))
		ball_canvas.draw_circle(cam_pt, 4.5, Color(1.0, 1.0, 1.0, 1.0))
		ball_canvas.draw_circle(cam_pt, 3.2, Color("#f24c3d"))
		ball_canvas.draw_circle(cam_pt, 1.2, Color(1.0, 1.0, 1.0, 0.95))
	else:
		# 背面视角：半透明虚线红圈，提示当前视角位于人物后方
		ball_canvas.draw_line(cam_pt, center, Color(1.0, 0.45, 0.4, 0.15), 1.0, true)
		ball_canvas.draw_arc(cam_pt, 4.5, 0.0, TAU, 16, Color(0.95, 0.35, 0.3, 0.55), 1.6, true)
		ball_canvas.draw_circle(cam_pt, 2.0, Color(1.0, 1.0, 1.0, 0.45))


# -----------------------------------------------------------------------------
# 制作部位列表与材料调色板绑定
# -----------------------------------------------------------------------------

func _build_category_buttons() -> void:
	for cat in CATEGORIES:
		category_selector.add_item("部位：" + cat)
	category_selector.item_selected.connect(func(index: int): _select_category(CATEGORIES[index], false))


func _select_category(cat: String, immediate: bool = false) -> void:
	_set_preview_pose(0)
	current_category = cat
	if inspector != null and blueprint != null and edit_session.blueprint != blueprint:
		_bind_edit_session()
	edit_session.category = cat
	if edit_session.blueprint != null:
		edit_session.select([])
	if blueprint != null:
		blueprint.category = cat
	if category_selector != null:
		category_selector.select(maxi(0, CATEGORIES.find(cat)))
	
	_rebuild_template()
	_focus_camera_on_category(cat, immediate)
	status_label.text = "正在制作：%s · 左键放置/换色，右键或橡皮擦移除" % cat


func _bind_palette_buttons() -> void:
	# 绑定场景中预排版的 8 个材料按钮
	for i in range(8):
		var btn: Button = palette_grid.get_node_or_null("Mat%d" % (i + 1))
		if btn != null:
			btn.text = MATERIAL_NAMES[i]
			btn.tooltip_text = "%s · 制作消耗%s，按方块体积折算" % [MATERIAL_NAMES[i], EquipmentDesign.Blocks.title(EquipmentDesign.RESOURCE_IDS[i])]
			btn.add_theme_color_override("font_color", Color("#32271b"))
			var mat_id: int = i + 1
			btn.pressed.connect(func(): _select_material(mat_id))
	_refresh_palette_highlight()


func _select_material(id: int) -> void:
	selected_material = id
	brush["mat"] = id
	erase_mode = false
	erase_btn.button_pressed = false
	_refresh_palette_highlight()
	_update_hover_indicator_visual(false)
	status_label.text = "已选择材料：%s" % MATERIAL_NAMES[id - 1]


func _refresh_palette_highlight() -> void:
	for i in range(8):
		var btn: Button = palette_grid.get_node_or_null("Mat%d" % (i + 1))
		if btn != null:
			var is_active := (i + 1 == selected_material and not erase_mode)
			btn.modulate = Color.WHITE
			var style: StyleBoxFlat = theme.get_stylebox("normal", "Button").duplicate()
			style.bg_color = MATERIAL_COLORS[i].lerp(Color("#faf1db"), 0.72)
			style.border_color = Color("#8b5b19") if is_active else MATERIAL_COLORS[i].darkened(0.28)
			style.set_border_width_all(3 if is_active else 1)
			btn.add_theme_stylebox_override("normal", style)


# -----------------------------------------------------------------------------
# 三维模板构建与微体素同步（统管生命周期，杜绝内存泄漏）
# -----------------------------------------------------------------------------

func _rebuild_template() -> void:
	for child in preview_root.get_children():
		preview_root.remove_child(child)
		child.queue_free()
	
	template_root = Node3D.new()
	preview_root.add_child(template_root)
	
	voxel_container = Node3D.new()
	voxel_container.name = "VoxelContainer"
	preview_root.add_child(voxel_container)
	
	floating_motes.clear()
	_build_voxel_pedestal_and_decorations()
	
	template_parts.clear()
	voxel_blocks.clear()
	_build_template_for(current_category)
	_sync_voxels()


# -----------------------------------------------------------------------------
# 关键艺术特性：用不同颜色与大小的方块尽量还原青苔阶梯底座与花草装饰品
# -----------------------------------------------------------------------------

func _build_voxel_pedestal_and_decorations() -> void:
	decor_root = Node3D.new()
	decor_root.name = "DecorPedestal"
	preview_root.add_child(decor_root)
	floating_motes.clear()
	
	# 材质缓存
	var stone_mat := StandardMaterial3D.new()
	stone_mat.albedo_color = Color("#5a5752") # 沉稳石块灰
	stone_mat.roughness = 0.85
	
	var stone_light_mat := StandardMaterial3D.new()
	stone_light_mat.albedo_color = Color("#76736d") # 浅灰岩石
	stone_light_mat.roughness = 0.8
	
	var moss_dark_mat := StandardMaterial3D.new()
	moss_dark_mat.albedo_color = Color("#426e2e") # 深苔藓绿
	moss_dark_mat.roughness = 0.9
	
	var moss_light_mat := StandardMaterial3D.new()
	moss_light_mat.albedo_color = Color("#62993e") # 嫩草苔藓绿
	moss_light_mat.roughness = 0.9
	
	# 1. 用不同颜色和大小的方块构建两层圆石阶梯底座（角色站在 y = 0 原点）
	var step_size := 0.12 # 阶梯体素单元大小
	var radius_top := 0.70
	var radius_bottom := 0.94
	
	var top_box_mesh := BoxMesh.new()
	top_box_mesh.size = Vector3(step_size * 0.96, 0.13, step_size * 0.96)
	
	var bottom_box_mesh := BoxMesh.new()
	bottom_box_mesh.size = Vector3(step_size * 0.96, 0.15, step_size * 0.96)
	
	var grid_span := int(ceil(radius_bottom / step_size))
	for xi in range(-grid_span, grid_span + 1):
		for zi in range(-grid_span, grid_span + 1):
			var pos_xz := Vector2(xi * step_size, zi * step_size)
			var dist := pos_xz.length()
			
			if dist <= radius_top:
				# 上层台阶方块 (y: -0.065)
				var inst := MeshInstance3D.new()
				inst.mesh = top_box_mesh
				inst.position = Vector3(pos_xz.x, -0.065, pos_xz.y)
				var hash_val := int(abs(xi * 73856093 ^ zi * 19349663)) % 100
				if hash_val < 38:
					inst.material_override = stone_mat
				elif hash_val < 62:
					inst.material_override = stone_light_mat
				elif hash_val < 82:
					inst.material_override = moss_dark_mat
				else:
					inst.material_override = moss_light_mat
				decor_root.add_child(inst)
			elif dist <= radius_bottom:
				# 下层台阶方块 (y: -0.205)
				var inst := MeshInstance3D.new()
				inst.mesh = bottom_box_mesh
				inst.position = Vector3(pos_xz.x, -0.205, pos_xz.y)
				var hash_val := int(abs(xi * 73856093 ^ zi * 19349663)) % 100
				if hash_val < 45:
					inst.material_override = stone_mat
				elif hash_val < 70:
					inst.material_override = moss_dark_mat
				else:
					inst.material_override = moss_light_mat
				decor_root.add_child(inst)
	
	# 2. 还原四周点缀的体素小花与绿叶装饰品（用不同颜色与大小的方块还原）
	_build_voxel_flower(decor_root, Vector3(-0.62, 0.0, 0.45), Color("#f7b7cb"), Color("#fac832"))
	_build_voxel_flower(decor_root, Vector3(0.68, 0.0, 0.40), Color("#fce8ed"), Color("#fae16b"))
	_build_voxel_flower(decor_root, Vector3(-0.76, -0.14, -0.25), Color("#ffffff"), Color("#fae16b"))
	_build_voxel_flower(decor_root, Vector3(0.56, -0.14, -0.66), Color("#f09bbb"), Color("#fac832"))
	
	# 绿叶与青藤体素簇
	_build_voxel_leaves(decor_root, Vector3(-0.52, 0.0, 0.52))
	_build_voxel_leaves(decor_root, Vector3(0.58, 0.0, 0.48))
	_build_voxel_leaves(decor_root, Vector3(-0.84, -0.14, 0.14))
	_build_voxel_leaves(decor_root, Vector3(0.74, -0.14, -0.32))
	
	# 3. 还原展台四周点缀的金色微光浮游光尘（发光小方块，仅在展台外围低空轻柔浮动，不遮挡人物正面与五官）
	var mote_mat := StandardMaterial3D.new()
	mote_mat.albedo_color = Color("#ffe885")
	mote_mat.emission_enabled = true
	mote_mat.emission = Color("#ffe885")
	mote_mat.emission_energy_multiplier = 1.3
	mote_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	
	var mote_mesh := BoxMesh.new()
	mote_mesh.size = Vector3.ONE * 0.015
	
	for i in range(10):
		var mote := MeshInstance3D.new()
		mote.mesh = mote_mesh
		mote.material_override = mote_mat
		var angle := float(i) / 10.0 * TAU + randf() * 0.25
		var dist := randf_range(0.85, 1.35)
		var h := randf_range(-0.15, 0.45)
		mote.position = Vector3(cos(angle) * dist, h, sin(angle) * dist)
		mote.set_meta("base_pos", mote.position)
		mote.set_meta("freq", randf_range(1.2, 2.2))
		mote.set_meta("phase", randf() * TAU)
		decor_root.add_child(mote)
		floating_motes.append(mote)


func _build_voxel_flower(parent: Node3D, root_pos: Vector3, petal_color: Color, pistil_color: Color) -> void:
	var flower_group := Node3D.new()
	flower_group.position = root_pos
	parent.add_child(flower_group)
	
	# 花茎：绿色微体素方块柱 (高度 0.09)
	var stem_mat := StandardMaterial3D.new()
	stem_mat.albedo_color = Color("#458532")
	var stem_mesh := BoxMesh.new()
	stem_mesh.size = Vector3(0.024, 0.08, 0.024)
	var stem_inst := MeshInstance3D.new()
	stem_inst.mesh = stem_mesh
	stem_inst.material_override = stem_mat
	stem_inst.position = Vector3(0, 0.04, 0)
	flower_group.add_child(stem_inst)
	
	# 花瓣：4 个粉白色微方块向四面延伸
	var petal_mat := StandardMaterial3D.new()
	petal_mat.albedo_color = petal_color
	var petal_mesh := BoxMesh.new()
	petal_mesh.size = Vector3.ONE * 0.030
	
	var offsets: Array[Vector3] = [
		Vector3(0.025, 0.08, 0), Vector3(-0.025, 0.08, 0),
		Vector3(0, 0.08, 0.025), Vector3(0, 0.08, -0.025)
	]
	for off in offsets:
		var p_inst := MeshInstance3D.new()
		p_inst.mesh = petal_mesh
		p_inst.material_override = petal_mat
		p_inst.position = off
		flower_group.add_child(p_inst)
	
	# 花蕊：中央黄色超微方块
	var pistil_mat := StandardMaterial3D.new()
	pistil_mat.albedo_color = pistil_color
	var pistil_mesh := BoxMesh.new()
	pistil_mesh.size = Vector3.ONE * 0.024
	var pistil_inst := MeshInstance3D.new()
	pistil_inst.mesh = pistil_mesh
	pistil_inst.material_override = pistil_mat
	pistil_inst.position = Vector3(0, 0.085, 0)
	flower_group.add_child(pistil_inst)


func _build_voxel_leaves(parent: Node3D, root_pos: Vector3) -> void:
	var leaf_group := Node3D.new()
	leaf_group.position = root_pos
	parent.add_child(leaf_group)
	
	var leaf_dark_mat := StandardMaterial3D.new()
	leaf_dark_mat.albedo_color = Color("#326822")
	var leaf_light_mat := StandardMaterial3D.new()
	leaf_light_mat.albedo_color = Color("#5fa63a")
	
	var leaf_mesh := BoxMesh.new()
	leaf_mesh.size = Vector3(0.045, 0.026, 0.065)
	
	var leaf1 := MeshInstance3D.new()
	leaf1.mesh = leaf_mesh
	leaf1.material_override = leaf_dark_mat
	leaf1.position = Vector3(0.02, 0.015, 0.02)
	leaf1.rotation_degrees = Vector3(10, 25, -12)
	leaf_group.add_child(leaf1)
	
	var leaf2 := MeshInstance3D.new()
	leaf2.mesh = leaf_mesh
	leaf2.material_override = leaf_light_mat
	leaf2.position = Vector3(-0.02, 0.012, -0.02)
	leaf2.rotation_degrees = Vector3(-8, -40, 15)
	leaf_group.add_child(leaf2)


func _ghost_material(color: Color, alpha: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(color, alpha)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	mat.roughness = 0.8
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	return mat


func _add_pick_collider(pos: Vector3, box_size: Vector3, part_name: String, show_guide: bool = true) -> void:
	# 专用于微体素吸附与拾取的物理空间盒（精确对齐真实人体骨骼）
	var body := StaticBody3D.new()
	body.name = "Pick_" + part_name
	body.position = pos
	body.collision_layer = 1
	body.collision_mask = 0
	body.set_meta("blueprint_part", current_category)
	body.set_meta("part_name", part_name)
	
	var shape := BoxShape3D.new()
	shape.size = box_size
	var collision := CollisionShape3D.new()
	collision.shape = shape
	body.add_child(collision)
	template_root.add_child(body)
	
	# 轻微半透明引导边框（提供清晰制作边界，完全不遮挡真实人物细节）
	if show_guide:
		var guide_mesh := BoxMesh.new()
		guide_mesh.size = box_size
		var guide_inst := MeshInstance3D.new()
		guide_inst.mesh = guide_mesh
		guide_inst.position = pos
		guide_inst.material_override = _ghost_material(Color("8fc4d8"), 0.16)
		template_root.add_child(guide_inst)
	
	template_parts.append({
		"part": part_name,
		"category": current_category,
		"pos": pos,
		"size": box_size
	})


func _build_template_for(category: String) -> void:
	# 核心重构：中间的人物模型直接以游戏当时的【实时真实游戏人物】呈现
	real_character = CharacterVisualScript.new()
	real_character.name = "RealCharacter"
	# 核心改动：角色旋转 180 度，面部五官（眼睛、面庞、发型与前襟）初始 100% 正对玩家镜头视角！
	real_character.rotation.y = PI
	template_root.add_child(real_character)
	
	# 隐藏手持施工方块，角色自然直立
	if is_instance_valid(real_character.held_item):
		real_character.held_item.visible = false
	
	# 实时同步玩家当时的防具装备（智能隐藏当前正在制作设计的部位）
	if is_instance_valid(real_character.equipment_visuals):
		var active_equipment: Array[int] = current_equipment_ids.duplicate()
		match category:
			"头部装备": active_equipment[0] = 0
			"盔甲": active_equipment[1] = 0
			"裤甲": active_equipment[2] = 0
			"鞋子": active_equipment[3] = 0
			"手套": active_equipment[4] = 0
			"披风": active_equipment[5] = 0
			"腰带": active_equipment[6] = 0
		real_character.equipment_visuals.apply_equipment(active_equipment, current_equipment_items)
	
	# 为当前制作部位配置 1:1 精确骨骼物理拾取盒与制作基准
	match category:
		"头部装备":
			_add_pick_collider(Vector3(0, 1.575, 0), Vector3(0.50, 0.50, 0.50), "head")
		"盔甲":
			_add_pick_collider(Vector3(0, 1.0125, 0), Vector3(0.52, 0.70, 0.28), "body")
		"裤甲":
			_add_pick_collider(Vector3(0, 0.38, 0), Vector3(0.48, 0.68, 0.26), "legs")
		"鞋子":
			_add_pick_collider(Vector3(0, 0.09, 0.0), Vector3(0.52, 0.22, 0.32), "feet")
		"手套":
			_add_pick_collider(Vector3(-0.3375, 0.78, 0), Vector3(0.24, 0.24, 0.24), "hands")
			_add_pick_collider(Vector3(0.3375, 0.78, 0), Vector3(0.24, 0.24, 0.24), "hands")
		"披风":
			# 角色面朝+Z正面，背部披风朝向-Z
			_add_pick_collider(Vector3(0, 1.30, -0.16), Vector3(0.46, 0.85, 0.06), "back")
		"腰带":
			_add_pick_collider(Vector3(0, 0.715, 0), Vector3(0.52, 0.14, 0.30), "waist")
		"武器":
			_add_pick_collider(Vector3(-0.34, 0.78, 0.18), Vector3(0.14, 0.88, 0.14), "handle")
		"工具":
			_add_pick_collider(Vector3(-0.34, 0.78, 0.18), Vector3(0.14, 0.88, 0.14), "handle")
		_:
			_add_pick_collider(Vector3(0, 0.08, 0), Vector3(1.2, 0.16, 1.2), "base")


func _sync_voxels() -> void:
	if voxel_container != null:
		for child in voxel_container.get_children():
			voxel_container.remove_child(child)
			child.queue_free()
	voxel_blocks.clear()

	if blueprint == null or voxel_container == null:
		return
	blueprint.ensure_ids()

	var active_part := current_category
	var part_info := _find_part(active_part)
	var part_base: Vector3 = part_info.pos if not part_info.is_empty() else Vector3.ZERO
	var active_materials := {}

	for voxel in blueprint.voxels:
		if str(voxel.part) != active_part:
			continue
		if bool(voxel.get("hidden", false)):
			continue
		var pos: Vector3i = voxel.pos
		var mat_id: int = voxel.mat
		if mat_id <= 0 or mat_id > MATERIAL_COLORS.size():
			continue
		active_materials[mat_id] = true

		var v_size: int = int(voxel.get("size", SIZE_EIGHTH))
		var v_scale: float = _get_size_scale(v_size)
		var actual_size := Geometry.dimensions(voxel)
		var transform := Geometry.preview_transform(voxel, current_category)
		var cube := MeshInstance3D.new()
		cube.mesh = Geometry.mesh(voxel)
		cube.material_override = Materials.create(voxel)
		if voxel.get("shape", "box") == "cloth":
			cube.material_override.set_shader_parameter("motion_scale", 0.0)
		cube.transform = transform
		voxel_container.add_child(cube)

		var body := StaticBody3D.new()
		body.name = "VoxelPick_%d_%d_%d" % [pos.x, pos.y, pos.z]
		body.transform = transform
		body.collision_layer = 1
		body.collision_mask = 0
		body.set_meta("voxel_pos", pos)
		body.set_meta("blueprint_part", active_part)
		body.set_meta("voxel_size", v_size)
		body.set_meta("uid", str(voxel.uid))
		body.set_meta("primitive", voxel.duplicate(true))
		body.set_meta("box_size", actual_size)
		body.set_meta("voxel_center", transform.origin - part_base)

		var collision := CollisionShape3D.new()
		collision.shape = Geometry.collision_shape(voxel)
		body.add_child(collision)
		voxel_container.add_child(body)

		voxel_blocks.append({"node": cube, "body": body, "pos": pos, "size": v_size, "uid": str(voxel.uid)})

	count_label.text = "当前部位：%d 方块 · %d 种材料" % [voxel_blocks.size(), active_materials.size()]
	_refresh_crafting()
	if inspector != null:
		_selection_changed()


# -----------------------------------------------------------------------------
# 画布工具、观察手势与选择拖动
# -----------------------------------------------------------------------------

func _preview_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.pressed and event.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE]:
			var focus := get_viewport().gui_get_focus_owner()
			if focus != null:
				focus.release_focus()
		if event.button_index == MOUSE_BUTTON_MIDDLE or (event.button_index == MOUSE_BUTTON_LEFT and (event.alt_pressed or camera_dragging)):
			if not drag_snapshot.is_empty():
				if drag_started:
					edit_session.record(drag_snapshot)
				drag_snapshot.clear()
				drag_started = false
			camera_dragging = event.pressed
			pan_dragging = event.shift_pressed
			dragging_preview = false
			box_selecting = false
			if hover_indicator != null:
				hover_indicator.visible = false
			return
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				preview_press_position = event.position
				dragging_preview = true
				drag_snapshot.clear()
				drag_started = false
				if editor_mode == "select" and not event.ctrl_pressed:
					var hit := _ray_hit(event.position)
					if not hit.is_empty():
						var uid := str(_get_meta(hit.collider, "uid", ""))
						if edit_session.selection.has(uid):
							drag_snapshot = edit_session.snapshot()
			else:
				if drag_started:
					edit_session.record(drag_snapshot)
				elif box_selecting:
					_box_select(event.position, event.ctrl_pressed)
				elif dragging_preview and preview_press_position.distance_to(event.position) < 8.0:
					_handle_click(event.position, erase_mode, event.ctrl_pressed)
				drag_snapshot.clear()
				drag_started = false
				dragging_preview = false
				box_selecting = false
				if selection_overlay != null:
					selection_overlay.queue_redraw()
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			# 右键精准删除方块
			_handle_click(event.position, true)
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			preview_distance = maxf(1.6, preview_distance - 0.25)
			_update_camera_transform()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			preview_distance = minf(8.0, preview_distance + 0.25)
			_update_camera_transform()
	elif event is InputEventMouseMotion:
		if camera_dragging:
			if pan_dragging or event.shift_pressed:
				var pan: Vector3 = (-preview_camera.global_basis.x * event.relative.x + preview_camera.global_basis.y * event.relative.y) * preview_distance * 0.0015
				current_look_center += pan
			else:
				orbit_yaw -= event.relative.x * 0.010
				orbit_pitch = clampf(orbit_pitch - event.relative.y * 0.010, -1.48, 1.48)
			_update_camera_transform()
		elif dragging_preview and not drag_snapshot.is_empty() and event.position.distance_to(preview_press_position) > 6.0:
			drag_started = true
			var screen_delta: Vector2 = event.position - preview_press_position
			var preview_delta := (preview_camera.global_basis.x * screen_delta.x - preview_camera.global_basis.y * screen_delta.y) * preview_distance * 0.0015
			var delta: Vector3 = Geometry.PREVIEW_FLIP * preview_delta
			delta = delta.snapped(Vector3.ONE * 0.0325)
			var old_parts = BlueprintDataScript.from_dictionary(drag_snapshot.data)
			for uid in edit_session.selection:
				var index: int = blueprint.find_part(uid)
				var old_index: int = old_parts.find_part(uid)
				if index >= 0 and old_index >= 0 and not bool(blueprint.voxels[index].get("locked", false)):
					var transform := Geometry.character_transform(old_parts.voxels[old_index], current_category)
					transform.origin += delta
					Geometry.set_character_transform(blueprint.voxels[index], current_category, transform)
			_update_drag_visuals()
		elif dragging_preview and editor_mode == "select" and event.position.distance_to(preview_press_position) > 6.0:
			box_selecting = true
			box_end = event.position
			selection_overlay.queue_redraw()
		elif not gizmo_dragging:
			_update_hover_preview(event.position)

func _box_select(point: Vector2, additive: bool) -> void:
	if preview_pose > 0:
		return
	var rectangle := Rect2(preview_press_position, point - preview_press_position).abs()
	var ids: Array[String] = []
	for block in voxel_blocks:
		var index: int = blueprint.find_part(str(block.uid))
		if index < 0 or bool(blueprint.voxels[index].get("locked", false)):
			continue
		var pos: Vector3 = block.node.global_position
		if not preview_camera.is_position_behind(pos):
			var projected := preview_camera.unproject_position(pos) * preview_container.size / Vector2(preview_viewport.size)
			if rectangle.has_point(projected):
				ids.append(str(block.uid))
	edit_session.select(ids, additive)

func _update_drag_visuals() -> void:
	for block in voxel_blocks:
		if not edit_session.selection.has(str(block.uid)):
			continue
		var index: int = blueprint.find_part(str(block.uid))
		if index >= 0:
			var part: Dictionary = blueprint.voxels[index]
			var transform := Geometry.preview_transform(part, current_category)
			block.node.transform = transform
			block.body.transform = transform
			block.body.set_meta("primitive", part.duplicate(true))


func _viewport_ray(point: Vector2) -> Array:
	var viewport_size := Vector2(preview_viewport.size)
	var container_size := preview_container.size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0 or container_size.x <= 0.0 or container_size.y <= 0.0:
		return []
	var scale_factor := container_size / viewport_size
	if scale_factor.x == 0.0 or scale_factor.y == 0.0:
		return []
	var local := point / scale_factor
	var from := preview_camera.project_ray_origin(local)
	var dir := preview_camera.project_ray_normal(local)
	return [from, from + dir * 60.0]

func _ray_hit(point: Vector2) -> Dictionary:
	var ray := _viewport_ray(point)
	if ray.is_empty():
		return {}
	return preview_viewport.world_3d.direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(ray[0], ray[1]))


func _update_hover_preview(point: Vector2) -> void:
	if hover_indicator == null or blueprint == null:
		return
	if gizmo_dragging or dragging_preview or camera_dragging or preview_pose > 0:
		hover_indicator.visible = false
		return

	var ray := _viewport_ray(point)
	if ray.is_empty():
		hover_indicator.visible = false
		return

	var space := preview_viewport.world_3d.direct_space_state
	var query := PhysicsRayQueryParameters3D.create(ray[0], ray[1])
	var result := space.intersect_ray(query)
	if result.is_empty():
		hover_indicator.visible = false
		return

	var collider: Node3D = result.collider
	var voxel_meta = _get_meta(collider, "voxel_pos", null)
	var part_meta: String = str(_get_meta(collider, "blueprint_part", ""))

	var target_mode := erase_mode or editor_mode in ["select", "paint"]
	if target_mode:
		if voxel_meta == null:
			hover_indicator.visible = false
			return
		var primitive: Dictionary = _get_meta(collider, "primitive", {})
		hover_mesh.mesh = Geometry.mesh(primitive)
		hover_indicator.transform = collider.transform
		hover_material.albedo_color = Color(0.95, 0.25, 0.18, 0.35) if erase_mode else Color(0.5, 0.8, 1.0, 0.25)
		hover_mesh.material_override = hover_material
		hover_outline_box.scale = Geometry.dimensions(primitive) / VOXEL_SIZE
		hover_indicator.visible = true
		return
	if part_meta.is_empty():
		hover_indicator.visible = false
		return
	var placement := _placement_from_hit(result)
	hover_mesh.mesh = Geometry.mesh(placement)
	hover_mesh.material_override = Materials.create(placement, true)
	hover_indicator.transform = Geometry.preview_transform(placement, current_category)
	hover_outline_box.scale = Geometry.dimensions(placement) / VOXEL_SIZE
	hover_indicator.visible = true

func _placement_from_hit(hit: Dictionary) -> Dictionary:
	var extent := Geometry.dimensions(brush)
	if int(brush.get("size", 1)) != current_voxel_size:
		extent = Vector3.ONE * VOXEL_SIZE * _get_size_scale(current_voxel_size)
	var rotation := Geometry.vector(brush.get("rotation"))
	var shape := str(brush.get("shape", "box"))
	var bone := str(brush.get("anchor", ""))
	var part := Geometry.primitive(current_category, Vector3.ZERO, extent, rotation, shape, bone)
	part["mat"] = selected_material
	part["size"] = current_voxel_size
	for key in ["tint", "surface", "cloth"]:
		if brush.has(key):
			part[key] = brush[key].duplicate(true) if brush[key] is Dictionary else brush[key]
	var basis := Geometry.preview_transform(part, current_category).basis
	if inspector != null and inspector.align_surface():
		basis = Basis(Quaternion(Vector3.UP, Vector3(hit.normal))) * basis
	var target: Dictionary = _get_meta(hit.collider, "primitive", {})
	var standard := Vector3.ONE * VOXEL_SIZE * _get_size_scale(current_voxel_size)
	var target_extent := Geometry.dimensions(target)
	var axis := Vector3(_get_normal_offset(hit.normal))
	var basic: bool = shape == "box" and extent.is_equal_approx(standard) and rotation.is_zero_approx() and (inspector == null or not inspector.align_surface()) and absf(axis.dot(Vector3(hit.normal))) > 0.9999
	var target_uniform := is_equal_approx(target_extent.x, target_extent.y) and is_equal_approx(target_extent.x, target_extent.z)
	var center: Vector3
	var origin := EquipmentDesign.template_origin(current_category)
	if basic and (target.is_empty() or (str(target.get("shape", "box")) == "box" and target_uniform and Geometry.vector(target.get("rotation")).is_zero_approx())):
		if target.is_empty():
			center = origin + _template_center(origin, hit.position, hit.normal)
		else:
			var target_center: Vector3 = hit.collider.position - origin
			center = origin + _surface_center(target_center, target_extent.x, Vector3(hit.position) - origin, hit.normal)
	else:
		center = Geometry.placement(hit.position, hit.normal, part, basis, 0.0325)
	var char_transform := Transform3D(Geometry.PREVIEW_FLIP * basis, Geometry.PREVIEW_FLIP * center)
	var selected_anchor := bone if not bone.is_empty() else Geometry.auto_anchor(current_category, char_transform.origin)
	Geometry.set_character_transform(part, current_category, char_transform, selected_anchor)
	return part


func _handle_click(point: Vector2, delete_mode: bool, additive: bool = false) -> void:
	if blueprint == null:
		return
	if preview_pose > 0:
		status_label.text = "动作预览中，切回静止建模后可编辑"
		return
	var ray := _viewport_ray(point)
	if ray.is_empty():
		return
	var space := preview_viewport.world_3d.direct_space_state
	var query := PhysicsRayQueryParameters3D.create(ray[0], ray[1])
	var result := space.intersect_ray(query)
	if result.is_empty():
		if editor_mode == "select" and not additive and not Input.is_key_pressed(KEY_CTRL):
			edit_session.select([])
		return

	var collider: Node3D = result.collider
	var part_meta: String = str(_get_meta(collider, "blueprint_part", ""))
	var voxel_meta = _get_meta(collider, "voxel_pos", null)
	var uid := str(_get_meta(collider, "uid", ""))
	var existing_part: Dictionary = _get_meta(collider, "primitive", {})
	if delete_mode:
		if not uid.is_empty() and not existing_part.get("locked", false):
			edit_session.select([uid])
			edit_session.erase_selected()
		return
	if editor_mode == "select":
		if not existing_part.get("locked", false):
			edit_session.select([uid] if not uid.is_empty() else [], additive or Input.is_key_pressed(KEY_CTRL))
		return
	if editor_mode == "paint" or (Input.is_key_pressed(KEY_CTRL) and voxel_meta != null):
		if not uid.is_empty() and not existing_part.get("locked", false):
			var color: Color = inspector.tint_picker.color
			edit_session.select([uid])
			edit_session.set_properties({"mat": selected_material, "tint": color.to_html(false)})
		return
	if part_meta.is_empty():
		return
	var placed := _placement_from_hit(result)
	if edit_session.add(placed).is_empty():
		status_label.text = edit_session.last_error
		return
	edit_session.select([])
	_update_hover_preview(point)
	status_label.text = "已放置部件 · V 选择编辑，Ctrl+Z 撤销"


func _get_normal_offset(normal: Vector3) -> Vector3i:
	var abs_norm := normal.abs()
	if abs_norm.x >= abs_norm.y and abs_norm.x >= abs_norm.z:
		return Vector3i(int(signf(normal.x)), 0, 0)
	elif abs_norm.y >= abs_norm.x and abs_norm.y >= abs_norm.z:
		return Vector3i(0, int(signf(normal.y)), 0)
	else:
		return Vector3i(0, 0, int(signf(normal.z)))


func _place_voxel_with_brush(pos: Vector3i, part: String, custom_center: Variant = null, custom_size: int = -1) -> void:
	var before: Dictionary = edit_session.snapshot() if edit_session.blueprint == blueprint else {}
	var use_size: int = current_voxel_size if custom_size <= 0 else custom_size
	var center := Vector3(pos) * VOXEL_SIZE
	if custom_center is Vector3:
		center = custom_center
	elif custom_center is Array and custom_center.size() == 3:
		center = Vector3(custom_center[0], custom_center[1], custom_center[2])
	blueprint.add_voxel(pos, selected_material, part, use_size, [center.x, center.y, center.z])
	blueprint.ensure_ids()
	if not before.is_empty():
		edit_session.record(before)


func _remove_voxel_with_brush(center: Vector3, part: String) -> void:
	var target: Dictionary = blueprint.get_voxel_at(center, part)
	if bool(target.get("locked", false)):
		return
	var before: Dictionary = edit_session.snapshot() if edit_session.blueprint == blueprint else {}
	blueprint.remove_voxel(center, part)
	if not before.is_empty():
		edit_session.record(before)


func _surface_center(center: Vector3, old_size: float, hit: Vector3, normal: Vector3) -> Vector3:
	var direction := _get_normal_offset(normal)
	var step := VOXEL_SIZE * _get_size_scale(current_voxel_size)
	var target := center + Vector3(direction) * (old_size + step) * 0.5
	if step < old_size:
		var count := int(roundf(old_size / step))
		for axis in range(3):
			if direction[axis] == 0:
				var index := clampi(int(floorf((hit[axis] - center[axis] + old_size * 0.5) / step)), 0, count - 1)
				target[axis] = center[axis] + (float(index) + 0.5) * step - old_size * 0.5
	return target


func _template_center(base: Vector3, hit: Vector3, normal: Vector3) -> Vector3:
	var direction := _get_normal_offset(normal)
	var step := VOXEL_SIZE * _get_size_scale(current_voxel_size)
	var target := hit - base
	for axis in range(3):
		if direction[axis] == 0:
			target[axis] = roundf(target[axis] / step) * step
		else:
			target[axis] += direction[axis] * step * 0.5
	return target


func _get_meta(node: Node, key: String, fallback: Variant) -> Variant:
	var current: Node = node
	while current != null:
		if current.has_meta(key):
			return current.get_meta(key)
		current = current.get_parent()
	return fallback


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		if drag_started and not drag_snapshot.is_empty():
			edit_session.record(drag_snapshot)
		drag_snapshot.clear()
		drag_started = false
		camera_dragging = false
		dragging_preview = false
		box_selecting = false
		if gizmo_dragging:
			gizmo_dragging = false
			if ball_canvas != null and is_instance_valid(ball_canvas):
				ball_canvas.queue_redraw()
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_MIDDLE and not event.pressed:
		camera_dragging = false
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.ctrl_pressed and event.keycode == KEY_S and not %UnsavedDialog.visible:
		_save_pressed()
		get_viewport().set_input_as_handled()
		return
	var focus := get_viewport().gui_get_focus_owner()
	if focus is LineEdit or focus is TextEdit or %UnsavedDialog.visible:
		return
	if event.ctrl_pressed:
		match event.keycode:
			KEY_Z: _editor_action("redo" if event.shift_pressed else "undo")
			KEY_Y: _editor_action("redo")
			KEY_D: _editor_action("duplicate")
			KEY_S: _save_pressed()
			_: return
	else:
		match event.keycode:
			KEY_B: _set_editor_mode("add")
			KEY_V: _set_editor_mode("select")
			KEY_C: _set_editor_mode("paint")
			KEY_X: _set_editor_mode("erase")
			KEY_DELETE: _editor_action("delete")
			KEY_F: _frame_selection()
			KEY_LEFT, KEY_RIGHT, KEY_UP, KEY_DOWN, KEY_PAGEUP, KEY_PAGEDOWN:
				if preview_pose == 0:
					var delta := Vector3.ZERO
					match event.keycode:
						KEY_LEFT: delta.x = -0.0325
						KEY_RIGHT: delta.x = 0.0325
						KEY_UP: delta.y = 0.0325
						KEY_DOWN: delta.y = -0.0325
						KEY_PAGEUP: delta.z = -0.0325
						KEY_PAGEDOWN: delta.z = 0.0325
					edit_session.translate_selected(Geometry.PREVIEW_FLIP * (preview_camera.global_basis * delta))
			_: return
	get_viewport().set_input_as_handled()


func _find_part(part: String) -> Dictionary:
	for info in template_parts:
		if str(info.get("part", "")) == part or str(info.get("category", "")) == part:
			return info
	if not template_parts.is_empty():
		return template_parts[0]
	return {}


func _snap_voxel(base: Vector3, half: Vector3, hit: Vector3, normal: Vector3) -> Vector3i:
	var local := (hit - base) / VOXEL_SIZE
	var offset := Vector3(signf(normal.x), signf(normal.y), signf(normal.z)) * 0.5
	local += offset
	var snapped := Vector3i(roundi(local.x), roundi(local.y), roundi(local.z))
	var limit := (half / VOXEL_SIZE).floor() + Vector3.ONE * 2.0 # 允许外延堆叠扩展
	snapped.x = clampi(snapped.x, -int(limit.x), int(limit.x))
	snapped.y = clampi(snapped.y, -int(limit.y), int(limit.y))
	snapped.z = clampi(snapped.z, -int(limit.z), int(limit.z))
	return snapped


# -----------------------------------------------------------------------------
# 辅助操作动作
# -----------------------------------------------------------------------------

func _clear_all() -> void:
	if preview_pose > 0:
		status_label.text = "请先切回静止建模，再编辑部件"
		return
	if blueprint != null:
		if edit_session.blueprint == blueprint:
			edit_session.clear_category()
		else:
			blueprint.voxels = blueprint.voxels.filter(func(part: Dictionary): return str(part.part) != current_category or bool(part.get("locked", false)))
		_sync_voxels()
		status_label.text = "已清空当前蓝图"


func _set_cell(index: int, material_id: int) -> void:
	# 保持对老测试用例的兼容支持
	if blueprint == null:
		return
	var width: int = max(1, blueprint.grid_size)
	var local_pos := Vector3i(index % width - width / 2, -(index / width) + width / 2, 0)
	blueprint.add_voxel(local_pos, material_id, current_category)
	_sync_voxels()


func _mirror_x() -> void:
	if preview_pose > 0:
		status_label.text = "请先切回静止建模，再编辑部件"
		return
	if blueprint == null or blueprint.voxels.is_empty():
		status_label.text = "没有可镜像的方块"
		return
	var session = edit_session
	if session.blueprint != blueprint:
		session = EditSession.new()
		session.bind(blueprint)
	session.category = current_category
	session.mirror_selected()
	_sync_voxels()
	status_label.text = "已完成左右对称镜像"


func _save_pressed() -> bool:
	if blueprint == null:
		return false
	var typed_name := name_edit.text.strip_edges()
	blueprint.name = typed_name if not typed_name.is_empty() else "未命名蓝图"
	blueprint.category = current_category
	var error := BlueprintDataScript.validation_error(blueprint.to_dictionary())
	if not error.is_empty():
		status_label.text = error
		return false
	var typed_manager = manager if manager != null and manager.get_script() == ManagerScript else null
	var old_library: Array = typed_manager.blueprints.duplicate(true) if typed_manager != null else []
	var saved: Dictionary = blueprint.to_dictionary()
	if typed_manager != null:
		typed_manager.current = blueprint
		saved = typed_manager.save_current()
	status_label.text = "蓝图已保存 · 共 %d 个方块" % blueprint.voxels.size()
	_last_save_success = true
	blueprint_saved.emit(saved)
	if _last_save_success:
		edit_session.mark_saved()
	elif typed_manager != null:
		typed_manager.blueprints.assign(old_library)
		typed_manager.changed.emit()
	return _last_save_success

func _design_snapshot() -> Dictionary:
	if blueprint == null:
		return {}
	var saved: Dictionary = blueprint.to_dictionary()
	saved["category"] = current_category
	var title := name_edit.text.strip_edges()
	saved["name"] = title if not title.is_empty() else "未命名蓝图"
	return saved

func _refresh_crafting() -> void:
	if cost_label == null or craft_btn == null:
		return
	var data := _design_snapshot()
	var error := EquipmentDesign.validation_error(data)
	craft_btn.disabled = inventory == null or not error.is_empty()
	craft_btn.tooltip_text = error if not error.is_empty() else "制作当前部位的装备，随后在 B 背包中双击或右键穿戴"
	if not error.is_empty():
		cost_label.text = error
		return
	var lines := PackedStringArray()
	var creative: bool = inventory != null and inventory.is_creative()
	var costs := EquipmentDesign.material_cost(data)
	for id in costs:
		var count: int = inventory.count_item(int(id)) if inventory != null else 0
		if creative:
			lines.append("%s×%d" % [EquipmentDesign.Blocks.title(int(id)), costs[id]])
		else:
			lines.append("%s %d/%s" % [EquipmentDesign.Blocks.title(int(id)), costs[id], "∞" if count < 0 else str(count)])
	cost_label.text = ("免费制作 · " if creative else "用料/库存 · ") + " · ".join(lines)

func _craft_pressed() -> void:
	if inventory == null:
		status_label.text = "请从游戏中打开工坊进行制作"
		return
	var result: Dictionary = inventory.craft_blueprint(_design_snapshot())
	status_label.text = str(result.message)
	if result.ok:
		item_crafted.emit(result.item)

func _refresh_library() -> void:
	if saved_designs == null:
		return
	saved_designs.clear()
	if manager == null or manager.blueprints.is_empty():
		saved_designs.add_item("已保存蓝图（暂无）")
		saved_designs.disabled = true
		return
	saved_designs.disabled = false
	for saved in manager.blueprints:
		saved_designs.add_item(str(saved.get("name", "未命名蓝图")) + " · " + str(saved.get("category", "")))
	saved_designs.select(-1)
	saved_designs.text = "选择已保存蓝图"

func _load_design(index: int) -> void:
	if manager == null or index < 0 or index >= manager.blueprints.size():
		return
	_transition(_open_saved_design.bind(index))

func _open_saved_design(index: int) -> void:
	blueprint = BlueprintDataScript.from_dictionary(manager.blueprints[index])
	manager.current = blueprint
	name_edit.text = blueprint.name
	saved_designs.select(index)
	_bind_edit_session()
	_select_category(str(blueprint.category) if str(blueprint.category) in CATEGORIES else CATEGORIES[0], true)

func _new_design() -> void:
	_transition(_create_new_design)

func _create_new_design() -> void:
	blueprint = BlueprintDataScript.new("未命名蓝图", current_category, 8)
	if manager != null:
		manager.current = blueprint
	name_edit.text = ""
	saved_designs.select(-1)
	saved_designs.text = "选择已保存蓝图"
	_bind_edit_session()
	_rebuild_template()

func _setup_editor() -> void:
	inspector = InspectorScene.instantiate()
	var controls := $RightDrawer/Panel/Margin/Stack/Scroll/VBox
	controls.add_child(inspector)
	controls.move_child(inspector, 0)
	inspector.parameters_changed.connect(_brush_changed)
	inspector.action_requested.connect(_editor_action)
	inspector.flags_changed.connect(func(key: String, value: bool):
		if preview_pose == 0 and edit_session.blueprint != null:
			edit_session.set_properties({key: value})
	)
	edit_session.changed.connect(_after_edit)
	edit_session.selection_changed.connect(_selection_changed)
	for item in [["Add", "add"], ["Select", "select"], ["Paint", "paint"], ["Erase", "erase"]]:
		get_node("EditorToolbar/" + str(item[0])).pressed.connect(_set_editor_mode.bind(str(item[1])))
	%Undo.pressed.connect(func(): _editor_action("undo"))
	%Redo.pressed.connect(func(): _editor_action("redo"))
	%Frame.pressed.connect(_frame_selection)
	%PartList.multi_selected.connect(func(_index: int, _selected: bool): _parts_selected())
	%OfficialDesigns.add_item("载入官方装备蓝图")
	for design in Presets.all():
		var index: int = %OfficialDesigns.item_count
		%OfficialDesigns.add_item(str(design.name) + " · " + str(design.category))
		%OfficialDesigns.set_item_metadata(index, int(design.source_item_id))
	%OfficialDesigns.item_selected.connect(func(index: int):
		if index > 0:
			_transition(_open_official.bind(int(%OfficialDesigns.get_item_metadata(index))))
	)
	for pose in ["动作预览：静止建模", "动作预览：奔跑", "动作预览：坐下", "动作预览：游泳", "动作预览：挥击"]:
		%PreviewPose.add_item(pose)
	%PreviewPose.item_selected.connect(_set_preview_pose)
	%UnsavedDialog.add_button("放弃修改", false, "discard")
	%UnsavedDialog.confirmed.connect(func():
		if _save_pressed():
			%UnsavedDialog.hide()
			if _pending_transition.is_valid():
				_pending_transition.call()
		else:
			%UnsavedDialog.popup_centered()
	)
	%UnsavedDialog.custom_action.connect(func(action: String):
		if action == "discard":
			%UnsavedDialog.hide()
			edit_session.restore_snapshot({"data": edit_session.saved_state.duplicate(true), "selection": []})
			name_edit.text = blueprint.name
			if _pending_transition.is_valid():
				_pending_transition.call()
	)
	selection_overlay = Control.new()
	selection_overlay.name = "SelectionOverlay"
	selection_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	selection_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	preview_container.add_child(selection_overlay)
	selection_overlay.draw.connect(func():
		if box_selecting:
			var rectangle := Rect2(preview_press_position, box_end - preview_press_position).abs()
			selection_overlay.draw_rect(rectangle, Color(0.4, 0.7, 0.9, 0.15))
			selection_overlay.draw_rect(rectangle, Color(0.6, 0.85, 1.0), false, 1.5)
	)
	_set_editor_mode("add")
	resized.connect(_layout_editor)
	_layout_editor()
	%Undo.disabled = true
	%Redo.disabled = true

func _layout_editor() -> void:
	var small := size.x < 1100.0 and size.x > 0.0
	var top := maxf(230.0, rotate_gizmo.get_rect().end.y + 12.0) if small else 68.0
	%EditorToolbar.offset_top = top
	%EditorToolbar.offset_bottom = top + 76.0

func _bind_edit_session() -> void:
	_set_preview_pose(0)
	%UnsavedDialog.hide()
	edit_session.bind(blueprint)
	edit_session.category = current_category
	brush = {"shape": "box", "mat": selected_material, "size": current_voxel_size, "dimensions": Geometry.array(Vector3.ONE * VOXEL_SIZE * _get_size_scale(current_voxel_size))}
	if inspector != null:
		inspector.set_values(brush)
	camera_dragging = false
	dragging_preview = false
	box_selecting = false
	_refresh_parts()
	%Undo.disabled = true
	%Redo.disabled = true

func _open_official(id: int) -> void:
	var design := Presets.design_for_item(id)
	if design.is_empty():
		return
	blueprint = BlueprintDataScript.from_dictionary(design)
	var copy_name: String = blueprint.name + " 副本"
	blueprint.name = copy_name
	var suffix := 2
	while manager != null and manager.blueprints.any(func(saved: Dictionary): return str(saved.get("name", "")) == blueprint.name and str(saved.get("category", "")) == blueprint.category):
		blueprint.name = copy_name + " " + str(suffix)
		suffix += 1
	if manager != null:
		manager.current = blueprint
	name_edit.text = blueprint.name
	current_category = str(blueprint.category)
	_bind_edit_session()
	_select_category(current_category, true)
	status_label.text = "已载入官方设计副本 · V 选择部件，右侧修改，Ctrl+S 保存"

func _after_edit() -> void:
	if manager != null:
		manager.current = blueprint
	_sync_voxels()
	_refresh_parts()
	%Undo.disabled = edit_session.undo_stack.is_empty()
	%Redo.disabled = edit_session.redo_stack.is_empty()
	status_label.text = "修改未保存 · Ctrl+Z 撤销，Ctrl+S 保存"

func _selection_changed() -> void:
	if inspector == null:
		return
	var selected := edit_session.selected_parts()
	if selected.is_empty():
		selected_material = int(brush.get("mat", selected_material))
		inspector.set_values(brush)
	else:
		selected_material = int(selected[0].get("mat", selected_material))
		inspector.set_values(selected[0], selected.size(), current_category)
	_refresh_palette_highlight()
	_refresh_parts()
	var highlight := StandardMaterial3D.new()
	highlight.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	highlight.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	highlight.albedo_color = Color(1, 0.78, 0.25, 0.22)
	for block in voxel_blocks:
		block.node.material_overlay = highlight if edit_session.selection.has(str(block.get("uid", ""))) else null

func _refresh_parts() -> void:
	if not is_node_ready() or not has_node("LeftDrawer/Panel/Margin/VBox/PartList"):
		return
	_refreshing_parts = true
	var scroll: int = %PartList.get_v_scroll_bar().value
	var parts: Array[Dictionary] = []
	if blueprint != null:
		for part in blueprint.voxels:
			if str(part.part) == current_category:
				parts.append(part)
	var rebuild: bool = %PartList.item_count != parts.size()
	if not rebuild:
		for index in parts.size():
			if str(%PartList.get_item_metadata(index)) != str(parts[index].get("uid", "")):
				rebuild = true
				break
	if rebuild:
		%PartList.clear()
	for index in parts.size():
		var part: Dictionary = parts[index]
		var prefix := ("[锁] " if part.get("locked", false) else "") + ("[隐] " if part.get("hidden", false) else "")
		var label := prefix + str(part.get("label", "方块 " + str(index + 1)))
		var uid := str(part.get("uid", ""))
		if rebuild:
			%PartList.add_item(label)
			%PartList.set_item_metadata(index, uid)
		else:
			%PartList.set_item_text(index, label)
		if edit_session.selection.has(uid) and not %PartList.is_selected(index):
			%PartList.select(index, false)
		elif not edit_session.selection.has(uid) and %PartList.is_selected(index):
			%PartList.deselect(index)
	%PartList.get_v_scroll_bar().value = scroll
	_refreshing_parts = false

func _parts_selected() -> void:
	if _refreshing_parts or preview_pose > 0:
		return
	var ids: Array[String] = []
	for index in %PartList.get_selected_items():
		ids.append(str(%PartList.get_item_metadata(index)))
	edit_session.select(ids)

func _brush_changed() -> void:
	if inspector != null and edit_session.selection.is_empty():
		brush = inspector.properties()
		brush["mat"] = selected_material
		brush["size"] = current_voxel_size

func _set_editor_mode(mode: String) -> void:
	editor_mode = mode
	erase_mode = mode == "erase"
	if erase_btn != null:
		erase_btn.set_pressed_no_signal(erase_mode)
	if mode == "add" and edit_session.blueprint != null:
		edit_session.select([])
	for item in [["Add", "add"], ["Select", "select"], ["Paint", "paint"], ["Erase", "erase"]]:
		get_node("EditorToolbar/" + str(item[0])).modulate = Color("f5d28c") if mode == item[1] else Color.WHITE
	if hover_indicator != null:
		hover_indicator.visible = false

func _editor_action(action: String) -> void:
	if blueprint == null:
		return
	if preview_pose > 0:
		status_label.text = "请先切回静止建模，再编辑部件"
		return
	match action:
		"apply":
			var values: Dictionary = inspector.properties()
			values["mat"] = selected_material
			edit_session.set_properties(values)
		"paint": edit_session.set_properties({"mat": selected_material, "tint": inspector.tint_picker.color.to_html(false), "surface": Materials.SURFACES[maxi(0, inspector.surface_box.selected)]})
		"duplicate": edit_session.duplicate_selected()
		"delete": edit_session.erase_selected()
		"undo": edit_session.undo()
		"redo": edit_session.redo()
		"rotate_x", "rotate_y", "rotate_z":
			var delta := Vector3.ZERO
			delta[["rotate_x", "rotate_y", "rotate_z"].find(action)] = inspector.angle_step()
			edit_session.rotate_selected(delta, inspector.pivot_at_anchor())

func _set_preview_pose(index: int) -> void:
	if index > 0 and preview_pose == 0:
		_pose_view = {"center": current_look_center, "distance": preview_distance}
	preview_pose = index
	if inspector != null:
		_set_inspector_enabled(inspector, index == 0)
	if is_node_ready():
		%PreviewPose.select(index)
	if is_instance_valid(pose_renderer):
		pose_renderer.hide_pieces()
		pose_renderer.queue_free()
		pose_renderer = null
	if not is_instance_valid(real_character):
		return
	for bone in Geometry.ANCHORS:
		var node: Node3D = real_character.get(bone)
		node.rotation = Vector3.ZERO
	real_character.body.position = Vector3.ZERO
	if is_instance_valid(voxel_container):
		voxel_container.visible = index == 0
	real_character.held_item.visible = index == 4
	if index > 0 and blueprint != null:
		current_look_center = Vector3(0, 1.05, 0)
		preview_distance = 4.0
		_update_camera_transform()
		hover_indicator.visible = false
		pose_renderer = BlueprintRenderer.new()
		preview_root.add_child(pose_renderer)
		pose_renderer.build(_design_snapshot(), real_character)
		if index == 4:
			real_character.set_held_block(303)
		status_label.text = "动作预览中 · 选择静止建模可继续编辑"
	elif index == 0 and not _pose_view.is_empty():
		current_look_center = _pose_view.center
		preview_distance = _pose_view.distance
		_pose_view.clear()
		_update_camera_transform()
	if index == 0 and inspector != null:
		_selection_changed()

func _set_inspector_enabled(node: Node, enabled: bool) -> void:
	if node is BaseButton:
		node.disabled = not enabled
	elif node is SpinBox or node is LineEdit:
		node.editable = enabled
	for child in node.get_children():
		_set_inspector_enabled(child, enabled)

func _frame_selection() -> void:
	if blueprint == null:
		return
	var parts := edit_session.selected_parts()
	if parts.is_empty():
		parts = EquipmentDesign.active_voxels(_design_snapshot())
	if parts.is_empty():
		_focus_camera_on_category(current_category, true)
		return
	var bounds := AABB()
	var first := true
	for part in parts:
		var box: AABB = Geometry.preview_transform(part, current_category) * Geometry.mesh(part).get_aabb()
		bounds = box if first else bounds.merge(box)
		first = false
	current_look_center = bounds.get_center()
	var tangent := tan(deg_to_rad(preview_camera.fov * 0.5))
	var usable_width := maxf(160.0, preview_container.size.x - 590.0)
	var aspect := usable_width / maxf(1.0, preview_container.size.y)
	preview_distance = clampf(maxf(bounds.size.y, bounds.size.x / aspect) / (2.0 * tangent) * 1.2 + bounds.size.z * 0.5, 1.6, 8.0)
	_update_camera_transform()

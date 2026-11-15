extends Control

signal closed
signal apply_requested(data: Dictionary)

const Definition = preload("res://scripts/character/CharacterDefinition.gd")
const Session = preload("res://scripts/character/CharacterEditSession.gd")
const Library = preload("res://scripts/character/CharacterLibrary.gd")
const Character = preload("res://scripts/player/CharacterVisual.gd")
const Layout = preload("res://scripts/ui/ResponsiveLayout.gd")
const DESIGN_SIZE := Vector2(1320, 820)
var edit_session = Session.new()
var library = Library.new()
var card: PanelContainer
var viewport: SubViewport
var preview: SubViewportContainer
var preview_character: Node3D
var camera: Camera3D
var skeleton_lines: MeshInstance3D
var joint_handles: MultiMeshInstance3D
var socket_marker: MeshInstance3D
var selection_mesh: MultiMeshInstance3D
var ghost: MeshInstance3D
var name_edit: LineEdit
var library_box: OptionButton
var bone_box: OptionButton
var bone_list: ItemList
var cube_list: ItemList
var status_label: Label
var count_label: Label
var pose_box: OptionButton
var tool_box: OptionButton
var color_picker: ColorPickerButton
var edge_spin: SpinBox
var joint_xyz: Array[SpinBox] = []
var cube_xyz: Array[SpinBox] = []
var parameter_inputs: Dictionary = {}
var symmetric: CheckBox
var reshape_body: CheckBox
var isolate_bone: CheckBox
var show_bones: CheckBox
var socket_box: OptionButton
var socket_xyz: Array[SpinBox] = []
var unsaved_dialog: ConfirmationDialog
var selected_bone: String = "head"
var pose: int = 0
var tool: int = 0
var orbit_yaw: float = 0.0
var orbit_pitch: float = -0.08
var orbit_distance: float = 3.8
var look_center := Vector3(0, 0.95, 0)
var _updating: bool = false
var _pending_parameters: Dictionary = {}
var _parameter_timer: Timer
var _pending_transition: Callable
var _saved_model: Dictionary = {}
var _equipment: Array[int] = []
var _equipment_items: Array = []
var _mouse_position := Vector2.ZERO
var _hover_inside: bool = false
var _hover_time: float = 0.0
var _orbiting: bool = false
var _panning: bool = false
var _drag_snapshot := PackedByteArray()
var _drag_start := Vector2.ZERO
var _drag_point := Vector3.ZERO
var _drag_plane := Plane()
var _drag_joint: String = ""
var _drag_joint_position := Vector3.ZERO
var _box_selecting: bool = false
var _box_start := Vector2.ZERO
var _selection_overlay: Control
var _bone_bounds: Dictionary = {}
var _metric_bounds: Dictionary = {}
var _draft_bound: bool = false
var _last_model_height: float = 0.0
var _origins: Dictionary = {}
var _cubes_by_bone: Dictionary = {}
var _cube_bones: Dictionary = {}
var _listed_ids: Dictionary = {}
var _listed_selection: Dictionary = {}
var _listed_bone: String = ""
var _drag_translation: Dictionary = {}
var _ghost_dirty: bool = true
var _editing_roots: Array[Control] = []
var _source_center := Vector3.ZERO
var _source_edge: float = 0.065
var _source_joint := Vector3.ZERO
var _source_socket := Vector3.ZERO
var _cube_dirty_axes: Array[int] = []
var _joint_dirty_axes: Array[int] = []
var _socket_dirty_axes: Array[int] = []
var _edge_dirty: bool = false
var _socket_tab_active: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shade := ColorRect.new()
	shade.color = Color("17252c")
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	card = PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color("e9dfc9")
	style.set_corner_radius_all(14)
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 16
	style.content_margin_bottom = 16
	card.add_theme_stylebox_override("panel", style)
	add_child(card)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 10)
	card.add_child(body)
	var header := HBoxContainer.new()
	body.add_child(header)
	var title := _label("人物创造器", 25)
	title.custom_minimum_size.x = 155
	header.add_child(title)
	library_box = OptionButton.new()
	library_box.custom_minimum_size.x = 170
	library_box.clip_text = true
	header.add_child(library_box)
	library_box.item_selected.connect(func(index: int):
		if index > 0 and index <= library.designs.size():
			request_transition(func(): _bind(library.designs[index - 1])))
	name_edit = LineEdit.new()
	name_edit.placeholder_text = "人物名称"
	name_edit.max_length = 128
	name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(name_edit)
	name_edit.text_submitted.connect(func(_text: String): _commit_name())
	name_edit.focus_exited.connect(_commit_name)
	name_edit.text_changed.connect(func(text: String):
		if not _updating and not edit_session.model.is_empty():
			edit_session.model.name = text.strip_edges() if not text.strip_edges().is_empty() else "我的人物")
	header.add_child(_button("新建", func(): request_transition(func(): _bind(Definition.new_model()))))
	header.add_child(_button("另存副本", _save_copy))
	header.add_child(_button("保存", save_model))
	header.add_child(_button("应用人物", _request_apply))
	header.add_child(_button("关闭", request_close))
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 14)
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(columns)
	var tabs := TabContainer.new()
	tabs.custom_minimum_size.x = 280
	columns.add_child(tabs)
	_editing_roots.append(tabs)
	tabs.tab_changed.connect(func(index: int): _socket_tab_active = index == 1; _refresh_socket())
	_build_skeleton_tab(tabs)
	_build_socket_tab(tabs)
	var middle := VBoxContainer.new()
	middle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.add_child(middle)
	var tools := HBoxContainer.new()
	middle.add_child(tools)
	tool_box = OptionButton.new()
	for label in ["放置 B", "选择 V", "染色 C", "删除 X", "调骨架"]:
		tool_box.add_item(label)
	tool_box.item_selected.connect(func(index: int):
		tool = index
		ghost.visible = false
		_ghost_dirty = true
		if index == 4:
			show_bones.button_pressed = true
			_draw_skeleton())
	tools.add_child(tool_box)
	_editing_roots.append(tool_box)
	pose_box = OptionButton.new()
	for label in ["静止建模", "行走", "奔跑", "跳跃", "坐下", "游泳", "挖掘"]:
		pose_box.add_item(label)
	pose_box.item_selected.connect(set_pose)
	tools.add_child(pose_box)
	var undo_button := _button("撤销", func(): edit_session.undo())
	var redo_button := _button("重做", func(): edit_session.redo())
	tools.add_child(undo_button)
	tools.add_child(redo_button)
	_editing_roots.append(undo_button)
	_editing_roots.append(redo_button)
	tools.add_child(_button("聚焦 F", focus_selection))
	preview = SubViewportContainer.new()
	preview.custom_minimum_size = Vector2(450, 440)
	preview.size_flags_vertical = Control.SIZE_EXPAND_FILL
	preview.stretch = true
	middle.add_child(preview)
	_setup_preview()
	var help := _label("中键 / Alt+左键旋转 · Shift+中键平移 · 滚轮缩放\nV 选择和拖动 · Ctrl 多选 · 空白拖动框选 · Ctrl+S 保存", 13)
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	middle.add_child(help)
	_build_parts_panel(columns)
	var footer := HBoxContainer.new()
	body.add_child(footer)
	status_label = _label("调整骨架，然后用立方体搭建自己的模型。", 15)
	status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	footer.add_child(status_label)
	count_label = _label("", 14)
	footer.add_child(count_label)
	_parameter_timer = Timer.new()
	_parameter_timer.one_shot = true
	_parameter_timer.wait_time = 0.16
	_parameter_timer.timeout.connect(_flush_parameters)
	add_child(_parameter_timer)
	unsaved_dialog = ConfirmationDialog.new()
	unsaved_dialog.title = "人物有未保存修改"
	unsaved_dialog.dialog_text = "保存修改、放弃修改，或继续编辑。"
	unsaved_dialog.ok_button_text = "保存后继续"
	unsaved_dialog.cancel_button_text = "继续编辑"
	unsaved_dialog.add_button("放弃修改", false, "discard")
	unsaved_dialog.confirmed.connect(func():
		if save_model():
			_continue_transition())
	unsaved_dialog.custom_action.connect(func(action: String):
		if action == "discard":
			unsaved_dialog.hide()
			_bind(_saved_model)
			_continue_transition())
	unsaved_dialog.canceled.connect(func(): _pending_transition = Callable())
	add_child(unsaved_dialog)
	edit_session.changed.connect(_model_changed)
	edit_session.selection_changed.connect(_selection_changed)
	resized.connect(_layout)
	card.minimum_size_changed.connect(_layout.call_deferred)
	visibility_changed.connect(func():
		viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS if visible else SubViewport.UPDATE_DISABLED)
	library.load_library()
	_refresh_library()
	visible = false
	_layout.call_deferred()

func _build_skeleton_tab(tabs: TabContainer) -> void:
	var scroll := ScrollContainer.new()
	scroll.name = "骨架"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	tabs.add_child(scroll)
	var stack := VBoxContainer.new()
	stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stack.add_theme_constant_override("separation", 8)
	scroll.add_child(stack)
	stack.add_child(_label("体型参数", 20))
	stack.add_child(_button("修复部位连接",func(): _feedback(edit_session.repair_connections())))
	for key in Definition.DEFAULTS:
		stack.add_child(_label(Definition.PARAMETER_NAMES[key], 14))
		var row := HBoxContainer.new()
		stack.add_child(row)
		var slider := HSlider.new()
		slider.min_value = Definition.RANGES[key].x
		slider.max_value = Definition.RANGES[key].y
		slider.step = 0.01
		slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(slider)
		var spin := _spin(slider.min_value, slider.max_value, 0.01)
		spin.custom_minimum_size.x = 90
		row.add_child(spin)
		parameter_inputs[key] = {"slider": slider, "spin": spin}
		slider.value_changed.connect(func(value: float):
			spin.set_value_no_signal(value)
			_queue_parameter(str(key), value))
		spin.value_changed.connect(func(value: float):
			slider.set_value_no_signal(value)
			_queue_parameter(str(key), value))
	reshape_body = CheckBox.new()
	reshape_body.text = "调整骨架时重塑身体方块"
	reshape_body.button_pressed = true
	stack.add_child(reshape_body)
	symmetric = CheckBox.new()
	symmetric.text = "左右关节对称编辑"
	symmetric.button_pressed = true
	stack.add_child(symmetric)
	show_bones = CheckBox.new()
	show_bones.text = "显示骨架"
	show_bones.button_pressed = true
	show_bones.toggled.connect(func(_value: bool): _draw_skeleton())
	stack.add_child(show_bones)
	stack.add_child(_label("关节位置（米）", 18))
	bone_list = ItemList.new()
	bone_list.custom_minimum_size.y = 160
	for i in Definition.BONES.size():
		bone_list.add_item(Definition.BONE_NAMES[i])
		bone_list.set_item_metadata(i, Definition.BONES[i])
	bone_list.item_selected.connect(func(index: int): _choose_bone(str(bone_list.get_item_metadata(index))))
	stack.add_child(bone_list)
	joint_xyz = _coordinate_inputs(stack)
	for axis in range(3):
		joint_xyz[axis].value_changed.connect(func(_value: float):
			if axis not in _joint_dirty_axes:
				_joint_dirty_axes.append(axis))
	stack.add_child(_button("应用关节位置", _apply_joint))

func _build_socket_tab(tabs: TabContainer) -> void:
	var stack := VBoxContainer.new()
	stack.name = "功能点"
	tabs.add_child(stack)
	var help := _label("眼位控制第一人称镜头，呼吸点控制潜水判定，掌心点控制工具握持。\n坐姿和脚底按骨架自动计算。", 15)
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stack.add_child(help)
	socket_box = OptionButton.new()
	for key in Definition.SOCKETS:
		socket_box.add_item({"eyes": "眼睛", "breathing": "呼吸点", "right_grip": "右手握持点"}[key])
		socket_box.set_item_metadata(socket_box.item_count - 1, key)
	socket_box.item_selected.connect(func(_index: int): _refresh_socket())
	stack.add_child(socket_box)
	socket_xyz = _coordinate_inputs(stack)
	for axis in range(3):
		socket_xyz[axis].value_changed.connect(func(_value: float):
			if axis not in _socket_dirty_axes:
				_socket_dirty_axes.append(axis))
	stack.add_child(_button("应用功能点", func():
		var value := _source_socket
		for axis in _socket_dirty_axes:
			value[axis] = socket_xyz[axis].value
		_feedback(edit_session.set_socket(str(socket_box.get_selected_metadata()), value))))
	var note := _label("方块的形状保持等边。想要长短、胖瘦的轮廓，可调整身体参数，或用更多方块搭建。", 15)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stack.add_child(note)

func _build_parts_panel(columns: HBoxContainer) -> void:
	var right := VBoxContainer.new()
	right.custom_minimum_size.x = 235
	columns.add_child(right)
	_editing_roots.append(right)
	right.add_child(_label("附着部位与方块", 20))
	bone_box = OptionButton.new()
	for i in Definition.BONES.size():
		bone_box.add_item(Definition.BONE_NAMES[i])
		bone_box.set_item_metadata(i, Definition.BONES[i])
	bone_box.item_selected.connect(func(index: int): _choose_bone(str(bone_box.get_item_metadata(index))))
	right.add_child(bone_box)
	isolate_bone = CheckBox.new()
	isolate_bone.text = "独显当前部位"
	isolate_bone.toggled.connect(func(_value: bool): _update_isolation())
	right.add_child(isolate_bone)
	color_picker = ColorPickerButton.new()
	color_picker.edit_alpha = false
	color_picker.color = Color("f5d3b0")
	color_picker.custom_minimum_size.y = 34
	right.add_child(color_picker)
	right.add_child(_label("立方体边长（米）", 14))
	edge_spin = _spin(0.005, 1.0, 0.0005)
	edge_spin.value = 0.065
	edge_spin.value_changed.connect(func(_value: float): _edge_dirty = true; _ghost_dirty = true)
	right.add_child(edge_spin)
	var sizes := GridContainer.new()
	sizes.columns = 2
	right.add_child(sizes)
	for value in [0.26, 0.13, 0.065, 0.0325]:
		sizes.add_child(_button(str(value), func(): edge_spin.value = value))
	cube_list = ItemList.new()
	cube_list.custom_minimum_size.y = 145
	cube_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cube_list.select_mode = ItemList.SELECT_MULTI
	cube_list.multi_selected.connect(func(_index: int, _selected: bool):
		if not _updating:
			var ids: Array = []
			for index in cube_list.get_selected_items():
				ids.append(cube_list.get_item_metadata(index))
			edit_session.select(ids))
	right.add_child(cube_list)
	cube_xyz = _coordinate_inputs(right)
	for axis in range(3):
		cube_xyz[axis].value_changed.connect(func(_value: float):
			if axis not in _cube_dirty_axes:
				_cube_dirty_axes.append(axis))
	right.add_child(_button("应用方块位置 / 边长", _apply_cube_properties))
	right.add_child(_button("给选中方块染色", func(): _feedback(edit_session.set_properties({"color": color_picker.color.to_html(false)}))))
	right.add_child(_button("改挂到当前部位", func(): _feedback(edit_session.set_properties({"bone": selected_bone}))))
	var row := HBoxContainer.new()
	right.add_child(row)
	row.add_child(_button("复制", func(): _feedback(edit_session.duplicate_selected())))
	row.add_child(_button("镜像", func(): _feedback(edit_session.duplicate_selected(true))))
	row.add_child(_button("删除", func(): _feedback(edit_session.erase_selected())))
	var flags := HBoxContainer.new()
	right.add_child(flags)
	flags.add_child(_button("隐藏 / 显示", func(): _toggle_flag("hidden")))
	flags.add_child(_button("锁定 / 解锁", func(): _toggle_flag("locked")))
	right.add_child(_button("恢复游戏默认人物", func(): apply_requested.emit({})))

func _setup_preview() -> void:
	viewport = SubViewport.new()
	viewport.own_world_3d = true
	viewport.size = Vector2i(600, 650)
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	preview.add_child(viewport)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("3d535b")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color("c4d6df")
	environment.environment.ambient_light_energy = 0.7
	viewport.add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-35, -30, 0)
	sun.light_energy = 1.0
	viewport.add_child(sun)
	preview_character = Character.new()
	preview_character.editor_mode = true
	preview_character.rotation.y = PI
	viewport.add_child(preview_character)
	preview_character.held_item.visible = false
	camera = Camera3D.new()
	camera.fov = 38
	viewport.add_child(camera)
	camera.make_current()
	skeleton_lines = MeshInstance3D.new()
	skeleton_lines.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	skeleton_lines.material_override = _guide_material(Color("ffd381"))
	viewport.add_child(skeleton_lines)
	joint_handles = MultiMeshInstance3D.new()
	joint_handles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var handle_material := _guide_material(Color.WHITE)
	handle_material.vertex_color_use_as_albedo = true
	joint_handles.material_override = handle_material
	viewport.add_child(joint_handles)
	socket_marker = MeshInstance3D.new()
	var socket_sphere := SphereMesh.new()
	socket_sphere.radius = 1.0
	socket_sphere.height = 2.0
	socket_marker.mesh = socket_sphere
	socket_marker.material_override = _guide_material(Color("95f4e2"))
	socket_marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	socket_marker.visible = false
	viewport.add_child(socket_marker)
	selection_mesh = MultiMeshInstance3D.new()
	selection_mesh.material_override = _guide_material(Color(1.0, 0.85, 0.35, 0.3))
	selection_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	viewport.add_child(selection_mesh)
	ghost = MeshInstance3D.new()
	ghost.mesh = BoxMesh.new()
	ghost.material_override = _guide_material(Color(0.75, 0.92, 1.0, 0.45))
	ghost.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ghost.visible = false
	viewport.add_child(ghost)
	var grid := ImmediateMesh.new()
	grid.surface_begin(Mesh.PRIMITIVE_LINES)
	for i in range(-10,11):
		grid.surface_add_vertex(Vector3(i * 0.2, -0.005, -2))
		grid.surface_add_vertex(Vector3(i * 0.2, -0.005, 2))
		grid.surface_add_vertex(Vector3(-2, -0.005, i * 0.2))
		grid.surface_add_vertex(Vector3(2, -0.005, i * 0.2))
	grid.surface_end()
	var floor_grid := MeshInstance3D.new()
	floor_grid.mesh = grid
	floor_grid.material_override = _guide_material(Color("71848a"))
	viewport.add_child(floor_grid)
	_selection_overlay = Control.new()
	_selection_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_selection_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_selection_overlay.draw.connect(func():
		if _box_selecting:
			var rect := Rect2(_box_start, _mouse_position - _box_start).abs()
			_selection_overlay.draw_rect(rect, Color(1,0.85,0.4,0.15))
			_selection_overlay.draw_rect(rect, Color("f8d16c"), false, 1.5))
	preview.add_child(_selection_overlay)
	preview.gui_input.connect(_preview_input)
	preview.mouse_entered.connect(func(): _hover_inside = true; _ghost_dirty = true)
	preview.mouse_exited.connect(func(): _hover_inside = false; ghost.visible = false)
	_update_camera()

func open(source: Dictionary, equipment: Array[int], items: Array) -> void:
	_equipment = equipment.duplicate()
	_equipment_items = items.duplicate(true)
	if not _draft_bound:
		_bind(source if not source.is_empty() else Definition.new_model())
	preview_character.equipment_visuals.apply_equipment(_equipment, _equipment_items)
	visible = true
	set_pose(0)
	_layout.call_deferred()
	if not library.last_error.is_empty():
		status_label.text = library.last_error + " · 世界中的人物仍可继续编辑"

func _bind(data: Dictionary) -> void:
	if pose != 0:
		set_pose(0)
	edit_session.bind(Definition.normalized(data))
	_choose_bone(selected_bone)
	_saved_model = data.duplicate(true)
	_draft_bound = true
	look_center = Vector3(0, float(Definition.metrics(data).height) * 0.52, 0)
	orbit_distance = maxf(2.4, float(Definition.metrics(data).height) * 2.1)
	_update_camera()

func _layout() -> void:
	if card != null and is_inside_tree():
		Layout.fit_centered(card, size, DESIGN_SIZE)

func _process(delta: float) -> void:
	if not visible or edit_session.model.is_empty():
		return
	if pose > 0:
		preview_character.animate(delta, 7.8 if pose == 2 else (4.2 if pose in [1,5] else 0.0), pose == 3, pose == 6, pose == 5, pose == 5, pose == 4, pose == 2)
	_hover_time -= delta
	if pose == 0 and tool == 0 and _hover_inside and _ghost_dirty and _hover_time <= 0.0 and _drag_snapshot.is_empty() and _drag_translation.is_empty():
		_hover_time = 0.08
		_update_ghost(_mouse_position)
		_ghost_dirty = false

func set_pose(index: int) -> void:
	_flush_parameters()
	pose = index
	edit_session.read_only = index > 0
	pose_box.select(index)
	for control in _editing_roots:
		_set_editing_enabled(control, index == 0)
	preview_character._reset_rig(edit_session.model)
	preview_character.equipment_visuals.set_motion_enabled(index > 0)
	preview_character.held_item.visible = index == 6
	if index == 6:
		preview_character.set_held_block(201)
	ghost.visible = false
	selection_mesh.visible = index == 0
	_draw_skeleton()
	_refresh_socket()
	if index == 0:
		_selection_changed()
	status_label.text = "静止建模 · 方块与软材质固定" if index == 0 else "动作预览 · 切回静止建模可继续编辑"

func _model_changed() -> void:
	if not is_instance_valid(preview_character) or edit_session.model.is_empty():
		return
	var data: Dictionary = edit_session.model
	var change: Dictionary = edit_session.last_change
	var full := bool(change.get("full",true))
	if full:
		preview_character.apply_character(data)
		preview_character.held_item.visible = pose == 6
		preview_character.equipment_visuals.set_motion_enabled(pose > 0)
		_updating = true
		name_edit.text = str(data.name)
		for key in parameter_inputs:
			parameter_inputs[key].slider.set_value_no_signal(data.parameters[key])
			parameter_inputs[key].spin.set_value_no_signal(data.parameters[key])
		_updating = false
		_origins = Definition.rest_origins(data)
		_build_bounds()
		_refresh_joint()
		_refresh_socket()
		_draw_skeleton()
	else:
		preview_character.update_editor_cubes(data,change.updated,change.removed)
		for id in change.removed:
			_remove_pick_cube(str(id))
		for cube in change.updated:
			_index_pick_cube(cube)
		for bone in change.bounds_bones:
			_build_bone_bounds(str(bone))
		if not change.bounds_bones.is_empty():
			_refresh_editor_metrics(data)
	if full or (bool(change.get("list_changed",false)) and change.bones.has(selected_bone)):
		_refresh_cube_list(change)
	var new_height: float = preview_character.body_metrics.height
	if _last_model_height > 0.0 and absf(new_height/_last_model_height-1.0) > 0.01:
		look_center.y *= new_height/_last_model_height
		orbit_distance = clampf(orbit_distance*new_height/_last_model_height,0.5,10.0)
		_update_camera()
	_last_model_height = new_height
	_update_isolation()
	count_label.text = "%d / %d 方块 · 模型高 %.2f 米" % [data.cubes.size(),Definition.MAX_CUBES,new_height]
	_ghost_dirty = true

func _refresh_editor_metrics(data: Dictionary) -> void:
	var meta := data.duplicate(false)
	meta.cubes = []
	var metrics := Definition.metrics(meta)
	var height: float = metrics.height
	var radius: float = metrics.radius
	for bone in ["body","chest","pelvis","head"]:
		if _metric_bounds.has(bone):
			var bounds: AABB = _metric_bounds[bone]
			height = maxf(height,bounds.end.y)
			radius = maxf(radius,maxf(maxf(absf(bounds.position.x),absf(bounds.end.x)),maxf(absf(bounds.position.z),absf(bounds.end.z)))+0.05*float(metrics.unit))
	metrics.seated_height = maxf(radius*2.0,float(metrics.seated_height)+height-float(metrics.height))
	metrics.height = height
	metrics.radius = radius
	preview_character.body_metrics = metrics

func _build_bounds() -> void:
	_bone_bounds.clear()
	_metric_bounds.clear()
	_cubes_by_bone.clear()
	_cube_bones.clear()
	for cube in edit_session.model.cubes:
		_index_pick_cube(cube)
	for bone in _cubes_by_bone:
		_build_bone_bounds(str(bone))

func _remove_pick_cube(id: String) -> void:
	if _cube_bones.has(id):
		_cubes_by_bone[_cube_bones[id]].erase(id)
		_cube_bones.erase(id)

func _index_pick_cube(cube: Dictionary) -> void:
	var id := str(cube.id)
	if _cube_bones.has(id) and _cube_bones[id] != cube.bone:
		_remove_pick_cube(id)
	if not _cubes_by_bone.has(cube.bone):
		_cubes_by_bone[cube.bone] = {}
	_cubes_by_bone[cube.bone][id] = cube
	_cube_bones[id] = cube.bone

func _build_bone_bounds(bone: String) -> void:
	_bone_bounds.erase(bone)
	_metric_bounds.erase(bone)
	for cube in _cubes_by_bone.get(bone,{}).values():
		var box := AABB(Vector3(_origins[cube.bone]) + Definition.vector(cube.center) - Vector3.ONE * float(cube.edge) * 0.5, Vector3.ONE * float(cube.edge))
		_metric_bounds[bone] = box if not _metric_bounds.has(bone) else AABB(_metric_bounds[bone]).merge(box)
		if bool(cube.get("hidden",false)):
			continue
		_bone_bounds[cube.bone] = box if not _bone_bounds.has(cube.bone) else AABB(_bone_bounds[cube.bone]).merge(box)

func _choose_bone(bone: String) -> void:
	var same_list := selected_bone == bone and _listed_bone == bone
	selected_bone = bone
	bone_box.select(Definition.BONES.find(bone))
	bone_list.select(Definition.BONES.find(bone))
	if not same_list:
		_refresh_cube_list()
	_refresh_joint()
	_update_isolation()
	_draw_skeleton()

func _refresh_cube_list(change: Dictionary = {}) -> void:
	if not bool(change.get("full",true)) and _listed_bone == selected_bone:
		_update_list_rows(change)
		return
	_updating = true
	var scroll: float = cube_list.get_v_scroll_bar().value
	var sources: Array[Dictionary] = []
	for cube in _cubes_by_bone.get(selected_bone,{}).values():
		sources.append(cube)
	var rebuild := cube_list.item_count != sources.size()
	if not rebuild:
		for index in sources.size():
			if str(cube_list.get_item_metadata(index)) != str(sources[index].id):
				rebuild = true
				break
	if rebuild:
		cube_list.clear()
	_listed_ids.clear()
	_listed_selection.clear()
	for index in sources.size():
		var cube: Dictionary = sources[index]
		var flags := (" 隐" if cube.get("hidden", false) else "") + (" 锁" if cube.get("locked", false) else "")
		var label := "方块 %d%s" % [index + 1,flags]
		if rebuild:
			cube_list.add_item(label)
			cube_list.set_item_metadata(index,cube.id)
		elif cube_list.get_item_text(index) != label:
			cube_list.set_item_text(index,label)
		if str(cube.id) in edit_session.selection:
			cube_list.select(index, false)
			_listed_selection[str(cube.id)] = true
		else:
			cube_list.deselect(index)
		_listed_ids[str(cube.id)] = index
	cube_list.get_v_scroll_bar().value = scroll
	_listed_bone = selected_bone
	_updating = false

func _update_list_rows(change: Dictionary) -> void:
	_updating = true
	var removed_indices: Array[int] = []
	for id in change.removed:
		if _listed_ids.has(id):
			removed_indices.append(int(_listed_ids[id]))
	for cube in change.updated:
		if str(cube.bone) != selected_bone and _listed_ids.has(cube.id):
			removed_indices.append(int(_listed_ids[cube.id]))
	removed_indices.sort()
	for position in range(removed_indices.size()-1,-1,-1):
		var index: int = removed_indices[position]
		var id := str(cube_list.get_item_metadata(index))
		_listed_ids.erase(id)
		_listed_selection.erase(id)
		cube_list.remove_item(index)
	if not removed_indices.is_empty():
		for index in range(removed_indices[0],cube_list.item_count):
			var id := str(cube_list.get_item_metadata(index))
			_listed_ids[id] = index
			var cube: Dictionary = _cubes_by_bone[selected_bone][id]
			cube_list.set_item_text(index,_cube_label(cube,index))
	for cube in change.updated:
		if str(cube.bone) != selected_bone:
			continue
		var id := str(cube.id)
		if _listed_ids.has(id):
			var index: int = _listed_ids[id]
			cube_list.set_item_text(index,_cube_label(cube,index))
		else:
			var index := cube_list.item_count
			cube_list.add_item(_cube_label(cube,index))
			cube_list.set_item_metadata(index,id)
			_listed_ids[id] = index
	_updating = false

func _cube_label(cube: Dictionary, index: int) -> String:
	return "方块 %d%s%s" % [index+1," 隐" if cube.get("hidden",false) else ""," 锁" if cube.get("locked",false) else ""]

func _selection_changed() -> void:
	if edit_session.model.is_empty():
		return
	_updating = true
	var next_selection := {}
	for id in edit_session.selection:
		if _listed_ids.has(id):
			next_selection[id] = true
			if not _listed_selection.has(id):
				cube_list.select(int(_listed_ids[id]),false)
	for id in _listed_selection:
		if not next_selection.has(id) and _listed_ids.has(id):
			cube_list.deselect(int(_listed_ids[id]))
	_listed_selection = next_selection
	_updating = false
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	var box := BoxMesh.new()
	box.size = Vector3.ONE
	multimesh.mesh = box
	var selected: Array[Dictionary] = []
	for id in edit_session.selection:
		var index: int = edit_session.find(id)
		if index >= 0:
			selected.append(edit_session.model.cubes[index])
	multimesh.instance_count = selected.size()
	for i in selected.size():
		var cube: Dictionary = selected[i]
		var center: Vector3 = _origins[cube.bone] + Definition.vector(cube.center)
		var transform := preview_character.global_transform * Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * (float(cube.edge) + 0.003)), center)
		multimesh.set_instance_transform(i, transform)
	selection_mesh.multimesh = multimesh
	selection_mesh.visible = pose == 0
	if selected.size() == 1:
		var cube: Dictionary = selected[0]
		var center := Definition.vector(cube.center)
		_source_center = center
		_source_edge = float(cube.edge)
		_cube_dirty_axes.clear()
		_edge_dirty = false
		for axis in range(3):
			cube_xyz[axis].set_value_no_signal(center[axis])
		edge_spin.set_value_no_signal(float(cube.edge))
		color_picker.color = Color(cube.color)
	for input in cube_xyz:
		input.editable = selected.size() == 1

func _update_isolation() -> void:
	for piece in preview_character._model_pieces:
		piece.visible = not isolate_bone.button_pressed or piece.get_parent() == preview_character.rig_nodes[selected_bone]

func _refresh_joint() -> void:
	if edit_session.model.is_empty():
		return
	var pos: Vector3 = Definition.rest_origins(edit_session.model)[selected_bone]
	_source_joint = pos
	_joint_dirty_axes.clear()
	for axis in range(3):
		joint_xyz[axis].set_value_no_signal(pos[axis])

func _refresh_socket() -> void:
	if edit_session.model.is_empty():
		return
	var key := str(socket_box.get_selected_metadata())
	var offset := Definition.vector(edit_session.model.sockets[key].offset)
	socket_marker.visible = _socket_tab_active and pose == 0
	socket_marker.scale = Vector3.ONE * 0.025 * Definition.unit(edit_session.model)
	socket_marker.global_position = preview_character.global_transform * Definition.socket_position(edit_session.model,key)
	_source_socket = offset
	_socket_dirty_axes.clear()
	for axis in range(3):
		socket_xyz[axis].set_value_no_signal(offset[axis])

func _queue_parameter(key: String, value: float) -> void:
	if _updating or pose > 0:
		return
	_pending_parameters[key] = value
	_parameter_timer.start()

func _flush_parameters() -> void:
	if _pending_parameters.is_empty():
		return
	_parameter_timer.stop()
	var values := _pending_parameters.duplicate()
	_pending_parameters.clear()
	_feedback(edit_session.set_parameters(values, reshape_body.button_pressed))

func _apply_joint() -> void:
	if pose > 0:
		return
	var position := _source_joint
	for axis in _joint_dirty_axes:
		position[axis] = joint_xyz[axis].value
	_feedback(edit_session.move_joint(selected_bone, position, symmetric.button_pressed, reshape_body.button_pressed))

func _apply_cube_properties() -> void:
	if pose > 0:
		return
	var values := {}
	if _edge_dirty:
		values["edge"] = edge_spin.value
	if edit_session.selection.size() == 1:
		var center := _source_center
		for axis in _cube_dirty_axes:
			center[axis] = cube_xyz[axis].value
		values["center"] = Definition.array(center)
	_feedback(edit_session.set_properties(values))

func _toggle_flag(key: String) -> void:
	if pose > 0 or edit_session.selection.is_empty():
		return
	var index: int = edit_session.find(edit_session.selection[0])
	if index >= 0:
		_feedback(edit_session.set_properties({key: not bool(edit_session.model.cubes[index].get(key, false))}))

func _commit_name() -> void:
	if _updating or edit_session.model.is_empty():
		return
	var value := name_edit.text.strip_edges()
	if value.is_empty():
		value = "我的人物"
	if str(edit_session.model.name) != value:
		edit_session.rename(value)

func save_model() -> bool:
	_flush_parameters()
	_commit_name()
	if not library.save_model(edit_session.model):
		status_label.text = library.last_error
		return false
	edit_session.mark_saved()
	_saved_model = edit_session.model.duplicate(true)
	_refresh_library()
	status_label.text = "人物模型已保存"
	return true

func _save_copy() -> void:
	_flush_parameters()
	_commit_name()
	var copy: Dictionary = edit_session.model.duplicate(true)
	copy.id = "character_" + Crypto.new().generate_random_bytes(8).hex_encode()
	copy.name = str(copy.name).left(120) + " 副本"
	if library.save_model(copy):
		_bind(copy)
		_refresh_library()
		status_label.text = "已另存为独立副本"
	else:
		status_label.text = library.last_error

func _refresh_library() -> void:
	library_box.clear()
	library_box.add_item("已保存人物…")
	for data in library.designs:
		library_box.add_item(str(data.name))

func _request_apply() -> void:
	_flush_parameters()
	_commit_name()
	var error := Definition.validation_error(edit_session.model)
	if not error.is_empty():
		status_label.text = error
		return
	apply_requested.emit(edit_session.model.duplicate(true))

func set_apply_result(success: bool, text: String) -> void:
	status_label.text = text
	if success:
		_equipment = preview_character.equipment_visuals.equipped_ids.duplicate()

func request_close() -> void:
	request_transition(_finish_close)

func request_transition(next: Callable) -> void:
	_flush_parameters()
	_commit_name()
	if edit_session.dirty():
		_pending_transition = next
		unsaved_dialog.popup_centered()
	else:
		next.call()

func _continue_transition() -> void:
	var next := _pending_transition
	_pending_transition = Callable()
	if next.is_valid():
		next.call()

func _finish_close() -> void:
	set_pose(0)
	visible = false
	closed.emit()

func cancel_edit() -> bool:
	if unsaved_dialog.visible:
		unsaved_dialog.hide()
		_pending_transition = Callable()
		return true
	if not _drag_translation.is_empty():
		edit_session.cancel_translation(_drag_translation)
		_drag_translation = {}
		return true
	if not _drag_snapshot.is_empty():
		edit_session.restore_snapshot(_drag_snapshot)
		_drag_snapshot = PackedByteArray()
		_drag_joint = ""
		return true
	if _box_selecting:
		_box_selecting = false
		_selection_overlay.queue_redraw()
		return true
	return false

func _feedback(success: bool) -> void:
	status_label.text = "修改已应用 · Ctrl+Z 撤销" if success else (edit_session.last_error if not edit_session.last_error.is_empty() else "请选择可编辑的方块或关节")

func _update_camera() -> void:
	if camera == null:
		return
	var direction := Vector3(sin(orbit_yaw) * cos(orbit_pitch), -sin(orbit_pitch), cos(orbit_yaw) * cos(orbit_pitch))
	camera.look_at_from_position(look_center + direction * orbit_distance, look_center)
	_ghost_dirty = true

func focus_selection() -> void:
	var point: Vector3 = Definition.rest_origins(edit_session.model)[selected_bone]
	if not edit_session.selection.is_empty():
		var index: int = edit_session.find(edit_session.selection[0])
		if index >= 0:
			var cube: Dictionary = edit_session.model.cubes[index]
			point = Vector3(Definition.rest_origins(edit_session.model)[cube.bone]) + Definition.vector(cube.center)
	look_center = preview_character.global_transform * point
	orbit_distance = maxf(1.1, float(Definition.metrics(edit_session.model).height) * 1.2)
	_update_camera()

func _draw_skeleton(preview_data: Dictionary = {}) -> void:
	if skeleton_lines == null or edit_session.model.is_empty():
		return
	skeleton_lines.visible = pose == 0 and show_bones.button_pressed
	joint_handles.visible = skeleton_lines.visible
	if not skeleton_lines.visible:
		return
	var mesh := ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	var origins := Definition.rest_origins(edit_session.model if preview_data.is_empty() else preview_data)
	var handles := MultiMesh.new()
	handles.transform_format = MultiMesh.TRANSFORM_3D
	handles.use_colors = true
	var sphere := SphereMesh.new()
	sphere.radius = 1.0
	sphere.height = 2.0
	sphere.radial_segments = 12
	sphere.rings = 6
	handles.mesh = sphere
	handles.instance_count = Definition.BONES.size() - 1
	var handle_index := 0
	for bone in Definition.BONES:
		var point: Vector3 = preview_character.global_transform * Vector3(origins[bone])
		var radius: float = 0.022 * Definition.unit(edit_session.model)
		for axis in [Vector3.RIGHT, Vector3.UP, Vector3.BACK]:
			mesh.surface_add_vertex(point - Vector3(axis) * radius)
			mesh.surface_add_vertex(point + Vector3(axis) * radius)
		if bone != "body":
			var handle_radius: float = (0.035 if bone == selected_bone else 0.022) * Definition.unit(edit_session.model)
			handles.set_instance_transform(handle_index,Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * handle_radius),point))
			handles.set_instance_color(handle_index,Color("a5e9ff") if bone == selected_bone else Color("f6cc78"))
			handle_index += 1
			mesh.surface_add_vertex(point)
			mesh.surface_add_vertex(preview_character.global_transform * Vector3(origins[Definition.PARENTS[bone]]))
	mesh.surface_end()
	skeleton_lines.mesh = mesh
	joint_handles.multimesh = handles

func _ray(position: Vector2) -> Dictionary:
	var point := position * Vector2(viewport.size) / preview.size
	var inverse := preview_character.global_transform.affine_inverse()
	return {"origin": inverse * camera.project_ray_origin(point), "direction": (inverse.basis * camera.project_ray_normal(point)).normalized()}

func _hit_box(origin: Vector3, direction: Vector3, box: AABB) -> Dictionary:
	var near := -INF
	var far := INF
	var normal := Vector3.ZERO
	for axis in range(3):
		if absf(direction[axis]) < 0.000001:
			if origin[axis] < box.position[axis] or origin[axis] > box.end[axis]:
				return {}
			continue
		var a: float = (box.position[axis] - origin[axis]) / direction[axis]
		var b: float = (box.end[axis] - origin[axis]) / direction[axis]
		var entry := minf(a, b)
		if entry > near:
			near = entry
			normal = Vector3.ZERO
			normal[axis] = -signf(direction[axis])
		far = minf(far, maxf(a, b))
		if near > far:
			return {}
	if far < 0.0:
		return {}
	return {"distance": maxf(0.0, near), "normal": normal}

func pick_cube(position: Vector2) -> Dictionary:
	var ray := _ray(position)
	var candidates := {}
	for bone in _bone_bounds:
		if isolate_bone.button_pressed and bone != selected_bone:
			continue
		if not _hit_box(ray.origin, ray.direction, _bone_bounds[bone]).is_empty():
			candidates[bone] = true
	var result := {}
	var nearest := INF
	for bone in candidates:
		for cube in _cubes_by_bone[bone].values():
			if bool(cube.get("hidden",false)):
				continue
			var center: Vector3 = _origins[bone] + Definition.vector(cube.center)
			var hit := _hit_box(ray.origin, ray.direction, AABB(center - Vector3.ONE * float(cube.edge) * 0.5, Vector3.ONE * float(cube.edge)))
			if not hit.is_empty() and float(hit.distance) < nearest:
				nearest = float(hit.distance)
				result = {"cube": cube, "point": Vector3(ray.origin) + Vector3(ray.direction) * nearest, "normal": hit.normal}
	return result

func _placement(position: Vector2) -> Vector3:
	var hit := pick_cube(position)
	if not hit.is_empty():
		return Vector3(hit.point) + Vector3(hit.normal) * float(edge_spin.value) * 0.5
	var ray := _ray(position)
	var origin: Vector3 = Definition.rest_origins(edit_session.model)[selected_bone]
	var point: Variant = Plane(Vector3.BACK, origin.z).intersects_ray(ray.origin, ray.direction)
	return origin if point == null else Vector3(point).snapped(Vector3.ONE * float(edge_spin.value))

func _update_ghost(position: Vector2) -> void:
	if pose > 0 or tool != 0:
		ghost.visible = false
		return
	ghost.mesh.size = Vector3.ONE * float(edge_spin.value)
	ghost.global_position = preview_character.global_transform * _placement(position)
	ghost.visible = true

func _preview_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_mouse_position = event.position
		_ghost_dirty = true
		if _orbiting:
			orbit_yaw -= event.relative.x * 0.008
			orbit_pitch = clampf(orbit_pitch - event.relative.y * 0.008, -1.4, 1.4)
			_update_camera()
		elif _panning:
			look_center += (camera.global_basis.x * -event.relative.x + camera.global_basis.y * event.relative.y) * orbit_distance * 0.0012
			_update_camera()
		elif not _drag_translation.is_empty() and event.button_mask & MOUSE_BUTTON_MASK_LEFT:
			var ray := _ray(event.position)
			var point: Variant = _drag_plane.intersects_ray(ray.origin, ray.direction)
			if point != null and event.position.distance_to(_drag_start) > 3.0:
				var delta := (Vector3(point) - _drag_point).snapped(Vector3.ONE * 0.0325)
				edit_session.preview_patch_translation(_drag_translation,delta)
		elif not _drag_joint.is_empty() and event.button_mask & MOUSE_BUTTON_MASK_LEFT:
			var ray := _ray(event.position)
			var point: Variant = _drag_plane.intersects_ray(ray.origin, ray.direction)
			if point != null:
				_drag_joint_position = Vector3(point).snapped(Vector3.ONE * 0.01)
				var origins := Definition.rest_origins(edit_session.model)
				var preview_data: Dictionary = edit_session.model.duplicate(true)
				var delta: Vector3 = _drag_joint_position - Vector3(origins[_drag_joint])
				Definition.move_branch(preview_data,_drag_joint,delta,origins)
				if symmetric.button_pressed:
					var other := Session.mirror_bone(_drag_joint)
					if other != _drag_joint:
						var opposite := Vector3(-_drag_joint_position.x,_drag_joint_position.y,_drag_joint_position.z)
						Definition.move_branch(preview_data,other,opposite-Vector3(origins[other]),origins)
				Definition.normalize_joints(preview_data)
				preview_character._reset_rig(preview_data)
				_draw_skeleton(preview_data)
		_selection_overlay.queue_redraw()
		return
	if not event is InputEventMouseButton:
		return
	_mouse_position = event.position
	if event.button_index == MOUSE_BUTTON_MIDDLE or (event.button_index == MOUSE_BUTTON_LEFT and event.alt_pressed):
		_panning = event.pressed and event.shift_pressed
		_orbiting = event.pressed and not event.shift_pressed
		return
	if event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
		orbit_distance = clampf(orbit_distance * (0.9 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.1), 0.5, 10.0)
		_update_camera()
		return
	if event.button_index != MOUSE_BUTTON_LEFT or pose > 0:
		return
	if not event.pressed:
		_finish_pointer_edit(event.ctrl_pressed)
		return
	if tool == 4:
		_start_joint_drag(event.position)
		return
	var hit := pick_cube(event.position)
	if tool == 0:
		var origin: Vector3 = Definition.rest_origins(edit_session.model)[selected_bone]
		_feedback(edit_session.add(selected_bone, _placement(event.position) - origin, edge_spin.value, color_picker.color))
	elif not hit.is_empty():
		var cube: Dictionary = hit.cube
		if tool == 1:
			if not bool(cube.get("locked", false)):
				if cube.id not in edit_session.selection or event.ctrl_pressed:
					edit_session.select([cube.id], event.ctrl_pressed)
				_choose_bone(str(cube.bone))
				if not event.ctrl_pressed:
					_drag_translation = edit_session.begin_translation()
					_drag_start = event.position
					_drag_point = hit.point
					_drag_plane = Plane((preview_character.global_basis.inverse() * camera.global_basis.z).normalized(), _drag_point)
		else:
			var paint_color := color_picker.color.to_html(false)
			edit_session.select([cube.id])
			_feedback(edit_session.set_properties({"color": paint_color}) if tool == 2 else edit_session.erase_selected())
	elif tool == 1:
		_box_selecting = true
		_box_start = event.position
		if not event.ctrl_pressed:
			edit_session.select([])

func _start_joint_drag(position: Vector2) -> void:
	var origins := Definition.rest_origins(edit_session.model)
	var nearest := 18.0
	var chosen := ""
	for bone in Definition.BONES:
		if bone == "body":
			continue
		var point: Vector2 = camera.unproject_position(preview_character.global_transform * Vector3(origins[bone])) * preview.size / Vector2(viewport.size)
		var distance := point.distance_to(position)
		if distance < nearest:
			nearest = distance
			chosen = bone
	if chosen.is_empty():
		return
	_choose_bone(chosen)
	_drag_joint = chosen
	_drag_snapshot = edit_session.snapshot()
	_drag_joint_position = origins[chosen]
	_drag_plane = Plane((preview_character.global_basis.inverse() * camera.global_basis.z).normalized(), _drag_joint_position)

func _finish_pointer_edit(additive: bool) -> void:
	if not _drag_joint.is_empty():
		var bone := _drag_joint
		_drag_joint = ""
		_drag_snapshot = PackedByteArray()
		_feedback(edit_session.move_joint(bone, _drag_joint_position, symmetric.button_pressed, reshape_body.button_pressed))
	elif not _drag_translation.is_empty():
		var before := _drag_translation
		_drag_translation = {}
		edit_session.commit_translation(before)
	if _box_selecting:
		_box_selecting = false
		var rect := Rect2(_box_start, _mouse_position - _box_start).abs()
		var ids: Array = []
		var origins := Definition.rest_origins(edit_session.model)
		for cube in edit_session.model.cubes:
			if cube.get("hidden", false) or cube.get("locked", false) or (isolate_bone.button_pressed and cube.bone != selected_bone):
				continue
			var point: Vector3 = preview_character.global_transform * (Vector3(origins[cube.bone]) + Definition.vector(cube.center))
			var screen: Vector2 = camera.unproject_position(point) * preview.size / Vector2(viewport.size)
			if not camera.is_position_behind(point) and rect.has_point(screen):
				ids.append(cube.id)
		edit_session.select(ids, additive)
		_selection_overlay.queue_redraw()

func _unhandled_key_input(event: InputEvent) -> void:
	if not visible or not event is InputEventKey or not event.pressed or event.echo:
		return
	var code: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
	if event.ctrl_pressed and code == KEY_S:
		save_model()
		get_viewport().set_input_as_handled()
		return
	var focused := get_viewport().gui_get_focus_owner()
	if focused is LineEdit or focused is TextEdit:
		return
	if pose == 0:
		if event.ctrl_pressed and code == KEY_Z:
			edit_session.redo() if event.shift_pressed else edit_session.undo()
		elif event.ctrl_pressed and code == KEY_Y:
			edit_session.redo()
		elif event.ctrl_pressed and code == KEY_D:
			edit_session.duplicate_selected()
		elif code == KEY_DELETE:
			_feedback(edit_session.erase_selected())
		elif code in [KEY_B,KEY_V,KEY_C,KEY_X]:
			tool = [KEY_B,KEY_V,KEY_C,KEY_X].find(code)
			tool_box.select(tool)
		elif code == KEY_F:
			focus_selection()
		else:
			return
	else:
		return
	get_viewport().set_input_as_handled()

func _label(text: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color("3d3931"))
	return label

func _button(text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", 15)
	button.pressed.connect(action)
	return button

func _spin(minimum: float, maximum: float, step_size: float) -> SpinBox:
	var spin := SpinBox.new()
	spin.min_value = minimum
	spin.max_value = maximum
	spin.step = step_size
	spin.custom_minimum_size.x = 70
	return spin

func _coordinate_inputs(parent: Node) -> Array[SpinBox]:
	var result: Array[SpinBox] = []
	for axis in ["X", "Y", "Z"]:
		var row := HBoxContainer.new()
		parent.add_child(row)
		row.add_child(_label(axis, 14))
		var spin := _spin(-4.0, 4.0, 0.005)
		spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(spin)
		result.append(spin)
	return result

func _coordinates(inputs: Array[SpinBox]) -> Vector3:
	return Vector3(inputs[0].value, inputs[1].value, inputs[2].value)

func _guide_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
	material.no_depth_test = true
	if color.a < 1.0:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return material

func _set_editing_enabled(node: Node, enabled: bool) -> void:
	if node is BaseButton:
		node.disabled = not enabled
	elif node is SpinBox or node is LineEdit or node is Slider:
		node.editable = enabled
	for child in node.get_children():
		_set_editing_enabled(child,enabled)

func _setup_theme() -> void:
	theme = Theme.new()
	theme.default_font_size = 16
	var ink := Color("423a2f")
	for type in ["Label","CheckBox","ItemList","LineEdit"]:
		theme.set_color("font_color",type,ink)
	theme.set_color("font_uneditable_color","LineEdit",Color("8c8476"))
	theme.set_color("font_selected_color","TabContainer",ink)
	theme.set_color("font_unselected_color","TabContainer",Color("746957"))
	var paper := StyleBoxFlat.new()
	paper.bg_color = Color("f4ecdc")
	paper.set_corner_radius_all(5)
	paper.set_content_margin_all(5)
	for type in ["ItemList","TabContainer"]:
		theme.set_stylebox("panel",type,paper)
	theme.set_stylebox("panel","AcceptDialog",paper)
	theme.set_stylebox("panel","PopupPanel",paper)
	theme.set_stylebox("normal","LineEdit",paper)
	var disabled := paper.duplicate()
	disabled.bg_color = Color("ded5c4")
	theme.set_stylebox("read_only","LineEdit",disabled)
	var wood := StyleBoxFlat.new()
	wood.bg_color = Color("69583c")
	wood.set_corner_radius_all(5)
	wood.content_margin_left = 8
	wood.content_margin_right = 8
	wood.content_margin_top = 6
	wood.content_margin_bottom = 6
	for type in ["Button","OptionButton"]:
		theme.set_stylebox("normal",type,wood)
		var hover := wood.duplicate()
		hover.bg_color = Color("887348")
		theme.set_stylebox("hover",type,hover)
		theme.set_stylebox("pressed",type,hover)
		theme.set_stylebox("disabled",type,disabled)
		theme.set_color("font_color",type,Color("fff1d5"))
		theme.set_color("font_disabled_color",type,Color("8c8476"))
	theme.set_stylebox("tab_selected","TabContainer",paper)
	theme.set_stylebox("tab_unselected","TabContainer",disabled)

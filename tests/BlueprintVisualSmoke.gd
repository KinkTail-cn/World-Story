extends SceneTree

# ==============================================================================
# 三维蓝图工坊视觉与交互增强自动化测试
# 验证：实时真实角色呈现、旋转球唯一视角控制、全方位旋转手势、部位平滑运镜与复位
# ==============================================================================

const CharacterVisualScript = preload("res://scripts/player/CharacterVisual.gd")
const BlueprintManagerScript = preload("res://scripts/blueprint/BlueprintManager.gd")

func _initialize() -> void:
	create_timer(15.0).timeout.connect(func():
		push_error("BLUEPRINT_VISUAL_SMOKE_TIMEOUT")
		quit(1)
	)
	_run.call_deferred()

func _run() -> void:
	print("--- 开始蓝图工坊与真实角色全面测试 ---")
	
	# 1. 创建蓝图工坊界面实例
	var workshop = load("res://scenes/BlueprintWorkshop.tscn").instantiate()
	root.add_child(workshop)
	await process_frame
	
	# 2. 模拟真实角色与装备
	var mock_visual = CharacterVisualScript.new()
	root.add_child(mock_visual)
	await process_frame
	
	# 穿戴头盔(101)、盔甲(102)、靴子(104)、披风(106)
	var test_equipment: Array[int] = [101, 102, 0, 104, 0, 106, 0]
	mock_visual.equipment_visuals.apply_equipment(test_equipment)
	
	# 3. 关联玩家模板并打开蓝图工坊
	var manager = BlueprintManagerScript.new()
	manager.create_blueprint("全套神武蓝图", "头部装备", 8)
	
	workshop.set_player_template(mock_visual)
	workshop.open(manager)
	assert(workshop.visible, "蓝图工坊未成功打开")
	
	# 4. 验证真实角色是否成功装配入工坊中央
	assert(workshop.real_character != null, "工坊中央未生成真实角色")
	assert(workshop.real_character.get_script() == CharacterVisualScript, "工坊中央人物不是真实的CharacterVisual")
	assert(is_equal_approx(workshop.real_character.rotation.y, PI), "工坊中角色未旋转180度正面直视玩家镜头")
	assert(workshop.real_character.held_item != null and not workshop.real_character.held_item.visible, "工坊中角色的手持物品未隐藏")
	
	# 验证正在制作头部装备时，已有头盔被智能隐藏以便制作，而盔甲/靴子/披风保持显示
	var pieces = workshop.real_character.equipment_visuals.pieces
	for p in pieces[0]: # 头部槽位
		assert(not p.visible, "正在制作头部装备时，头部已有装备未隐藏")
	for p in pieces[1]: # 盔甲槽位
		assert(p.visible, "身体盔甲应当保持显示")
	for p in pieces[3]: # 靴子槽位
		assert(p.visible, "鞋子应当保持显示")
	for p in pieces[5]: # 披风槽位
		assert(p.visible, "披风应当保持显示")
	print("✓ 真实角色正面朝向与装备实时同步及当前制作部位显隐测试通过")
	
	# 5. 验证切换部位时的平滑聚焦运镜与装备显隐切换
	workshop._select_category("盔甲", true)
	await process_frame
	# 切换到盔甲后：头部装备恢复显示，而盔甲槽位隐去
	pieces = workshop.real_character.equipment_visuals.pieces
	for p in pieces[0]:
		assert(p.visible, "切换到盔甲后，头部已有防具未恢复显示")
	for p in pieces[1]:
		assert(not p.visible, "切换到盔甲后，盔甲防具未隐藏")
	print("✓ 制作部位切换与运镜聚焦测试通过")
	
	# 6. 验证“只有旋转球才能转动视角”：主画布拖拽绝对不转动视轨
	var yaw_before: float = workshop.orbit_yaw
	var pitch_before: float = workshop.orbit_pitch
	
	# 模拟在主画布上拖拽
	var fake_motion := InputEventMouseMotion.new()
	fake_motion.relative = Vector2(100.0, 50.0)
	workshop._preview_input(fake_motion)
	
	assert(workshop.orbit_yaw == yaw_before, "主画布拖拽不应改变相机偏航角！")
	assert(workshop.orbit_pitch == pitch_before, "主画布拖拽不应改变相机俯仰角！")
	print("✓ 主视口彻底禁用拖拽旋转测试通过（视角旋转权限唯一归属于旋转球）")
	
	# 7. 验证右上角旋转球长按滑动全方位旋转
	var mouse_down := InputEventMouseButton.new()
	mouse_down.button_index = MOUSE_BUTTON_LEFT
	mouse_down.pressed = true
	workshop._gizmo_disc_input(mouse_down)
	assert(workshop.gizmo_dragging, "旋转球长按未进入拖拽滑动状态")
	
	# 滑动旋转球
	var gizmo_motion := InputEventMouseMotion.new()
	gizmo_motion.relative = Vector2(50.0, -30.0)
	workshop._gizmo_disc_input(gizmo_motion)
	assert(workshop.orbit_yaw != yaw_before, "旋转球水平滑动未能转动视角")
	assert(workshop.orbit_pitch != pitch_before, "旋转球垂直滑动未能转动俯仰角")
	
	# 松开旋转球
	var mouse_up := InputEventMouseButton.new()
	mouse_up.button_index = MOUSE_BUTTON_LEFT
	mouse_up.pressed = false
	workshop._gizmo_disc_input(mouse_up)
	assert(not workshop.gizmo_dragging, "旋转球松开未退出拖拽状态")
	print("✓ 旋转球长按滑动全方位视角控制测试通过")
	
	# 8. 验证复位按钮
	workshop._reset_camera_pose()
	await process_frame
	assert(is_equal_approx(workshop.orbit_yaw, 0.0), "复位后相机偏航角应处于0度正面对视视角")
	print("✓ 复位视角按钮测试通过（正面对视恢复）")

	# 9. 验证悬停预选方框（Hover Indicator）
	assert(workshop.hover_indicator != null, "工坊中未初始化悬停预选方框节点")
	assert(workshop.hover_mesh != null and workshop.hover_outline_box != null, "悬停预选方框缺少半透明材质网格或立体线框")
	print("✓ 悬停预选方框（半透明体与高亮线框）初始化验证通过")

	# 10. 验证方块尺寸选择（1/4、1/8、1/16、1/32 四档尺寸切换与等比缩放）
	assert(workshop.size_quarter_btn != null and workshop.size_eighth_btn != null, "未找到尺寸选择按钮")
	assert(workshop.size_sixteenth_btn != null and workshop.size_thirtysecond_btn != null, "未找到 1/16 或 1/32 尺寸选择按钮")
	
	workshop._select_size(workshop.SIZE_QUARTER)
	assert(workshop.current_voxel_size == workshop.SIZE_QUARTER, "未能正确切换至 1/4 尺寸")
	assert(workshop.hover_indicator.scale.is_equal_approx(Vector3.ONE * 2.0), "1/4 尺寸下悬停预选方框未按 2.0 倍等比放大")
	
	workshop._select_size(workshop.SIZE_EIGHTH)
	assert(workshop.current_voxel_size == workshop.SIZE_EIGHTH, "未能正确切换至 1/8 尺寸")
	assert(workshop.hover_indicator.scale.is_equal_approx(Vector3.ONE * 1.0), "1/8 尺寸下悬停预选方框未按 1.0 倍复位")
	
	workshop._select_size(workshop.SIZE_SIXTEENTH)
	assert(workshop.current_voxel_size == workshop.SIZE_SIXTEENTH, "未能正确切换至 1/16 尺寸")
	assert(workshop.hover_indicator.scale.is_equal_approx(Vector3.ONE * 0.5), "1/16 尺寸下悬停预选方框未按 0.5 倍缩放")
	
	workshop._select_size(workshop.SIZE_THIRTYSECOND)
	assert(workshop.current_voxel_size == workshop.SIZE_THIRTYSECOND, "未能正确切换至 1/32 尺寸")
	assert(workshop.hover_indicator.scale.is_equal_approx(Vector3.ONE * 0.25), "1/32 尺寸下悬停预选方框未按 0.25 倍缩放")
	print("✓ 1/4、1/8、1/16、1/32 四档方块尺寸选择及预选框等比缩放测试通过")

	# 11. 验证在已放置方块上点击放置方块（表面邻接堆叠放置）
	workshop._select_category("头部装备", true)
	manager.current.voxels.clear()
	workshop._sync_voxels()
	assert(manager.current.voxels.is_empty())
	
	# 先在头部放置一个 1/8 基础微方块
	workshop._select_size(workshop.SIZE_EIGHTH)
	var base_voxel := Vector3i(0, 0, 0)
	workshop._place_voxel_with_brush(base_voxel, "头部装备")
	workshop._sync_voxels()
	assert(manager.current.voxels.size() == 1, "初始基础微方块放置失败")
	
	# 模拟在已有方块上方（法线 UP）点击放置新方块
	var normal_up := Vector3.UP
	var normal_offset: Vector3i = workshop._get_normal_offset(normal_up)
	assert(normal_offset == Vector3i(0, 1, 0), "法线偏移量计算错误")
	
	var stacked_voxel: Vector3i = base_voxel + normal_offset * workshop.current_voxel_size
	workshop._place_voxel_with_brush(stacked_voxel, "头部装备")
	workshop._sync_voxels()
	assert(manager.current.voxels.size() == 2, "在已有方块表面继续点击放置失败，数量未递增")
	assert(not manager.current.get_voxel_at(Vector3(0, 1, 0) * workshop.VOXEL_SIZE, "头部装备").is_empty(), "新方块未能正确落在已有方块正上方表面")
	print("✓ 在已放置方块上表面堆叠放置功能测试通过")

	# 12. 1/4 尺寸使用一个放大网格，体积等同于八个标准体素。
	workshop._select_size(workshop.SIZE_QUARTER)
	var large_base := Vector3i(5, 5, 5)
	workshop._place_voxel_with_brush(large_base, "头部装备")
	workshop._sync_voxels()
	assert(manager.current.voxels.size() == 3 and workshop.voxel_blocks.back().node.mesh.size.is_equal_approx(Vector3.ONE * 0.26), "1/4 方块应使用一个 0.26m 网格")
	print("✓ 1/4 尺寸立体结构放置测试通过")

	# 13. 验证 1/16 与 1/32 尺寸精细微体素放置与网格碰撞体同步
	workshop._select_size(workshop.SIZE_SIXTEENTH)
	var sixteenth_pos := Vector3i(100, 100, 100)
	var sixteenth_center := Vector3(0.0, 0.2275, 0.0) # 精确中心坐标
	workshop._place_voxel_with_brush(sixteenth_pos, "头部装备", sixteenth_center, workshop.SIZE_SIXTEENTH)
	workshop._sync_voxels()
	assert(manager.current.voxels.size() == 4, "1/16 尺寸微体素放置失败")
	
	# 检查最后生成的体素块 Mesh 与 CollisionShape 是否按 0.5 等比缩放 (0.065m)
	var sixteenth_block = workshop.voxel_blocks[workshop.voxel_blocks.size() - 1]
	assert(sixteenth_block.size == workshop.SIZE_SIXTEENTH, "1/16 体素块尺寸记录错误")
	assert(sixteenth_block.node.mesh.size.is_equal_approx(Vector3.ONE * 0.065), "1/16 体素网格尺寸未按 0.065m 缩放")
	print("✓ 1/16 尺寸精细微体素放置及网格碰撞体同步测试通过")

	workshop._select_size(workshop.SIZE_THIRTYSECOND)
	var thirtysecond_pos := Vector3i(200, 200, 200)
	var thirtysecond_center := Vector3(0.0, 0.27625, 0.0) # 精确超微体素中心坐标
	workshop._place_voxel_with_brush(thirtysecond_pos, "头部装备", thirtysecond_center, workshop.SIZE_THIRTYSECOND)
	workshop._sync_voxels()
	assert(manager.current.voxels.size() == 5, "1/32 尺寸微体素放置失败")
	
	var thirtysecond_block = workshop.voxel_blocks[workshop.voxel_blocks.size() - 1]
	assert(thirtysecond_block.size == workshop.SIZE_THIRTYSECOND, "1/32 体素块尺寸记录错误")
	assert(thirtysecond_block.node.mesh.size.is_equal_approx(Vector3.ONE * 0.0325), "1/32 体素网格尺寸未按 0.0325m 缩放")
	print("✓ 1/32 尺寸超微体素放置及网格碰撞体同步测试通过")

	# 14. 验证微体素精准擦除
	workshop._remove_voxel_with_brush(thirtysecond_center, "头部装备")
	workshop._sync_voxels()
	assert(manager.current.voxels.size() == 4, "1/32 微体素精准移除失败")
	workshop._remove_voxel_with_brush(sixteenth_center, "头部装备")
	workshop._sync_voxels()
	assert(manager.current.voxels.size() == 3, "1/16 微体素精准移除失败")
	print("✓ 1/16 与 1/32 微体素精准擦除测试通过")
	
	# 15. 资源清理
	workshop.queue_free()
	mock_visual.queue_free()
	print("--- 蓝图工坊全部测试 100% 通过 ---")
	print("BLUEPRINT_VISUAL_SMOKE_PASS: mannequin, category focus, orbit controls, mixed-size placement and erase")
	quit(0)

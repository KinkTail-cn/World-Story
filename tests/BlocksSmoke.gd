extends SceneTree

const Inventory = preload("res://scripts/inventory/Inventory.gd")
const ItemCatalog = preload("res://scripts/inventory/ItemCatalog.gd")
const BlockCatalog = preload("res://scripts/content/BlockCatalog.gd")
const HeldBlockScene = preload("res://scenes/HeldBlock.tscn")
const ItemDisplay3D = preload("res://scripts/ui/ItemDisplay3D.gd")

func _initialize() -> void:
	create_timer(10.0).timeout.connect(func(): push_error("BLOCKS_SMOKE_TIMEOUT"); quit(1))
	_run.call_deferred()

func _run() -> void:
	print("--- 开始各类方块系统全方位自动化测试 ---")
	
	# 1. 验证方块注册表、ID 范围与合法性
	print("1. 验证方块定义与合法性...")
	var all_ids: Array[int] = BlockCatalog.ids()
	assert(all_ids.size() == 20, "必须实装 20 类标准动漫方块")
	for id in range(1, 21):
		assert(ItemCatalog.is_block(id), "ID %d 必须判定为方块" % id)
		assert(BlockCatalog.is_valid_block(id), "BlockCatalog.is_valid_block(%d) 应为 true" % id)
		assert(not ItemCatalog.is_tool_item(id), "方块 ID %d 不能是工具" % id)
		assert(not ItemCatalog.is_equipment(id), "方块 ID %d 不能是装备" % id)
		assert(not ItemCatalog.is_document(id), "方块 ID %d 不能是图纸笔记" % id)
	
	assert(not ItemCatalog.is_block(0), "ID 0 不能是方块")
	assert(not ItemCatalog.is_block(21), "未注册 ID 21 不能是方块")
	assert(not ItemCatalog.is_block(101), "头盔不能是方块")
	assert(not ItemCatalog.is_block(201), "木镐不能是方块")
	print("✓ 20 类方块注册表与合法性验证通过")
	
	# 2. 验证方块名称规范
	print("2. 验证方块中文名称...")
	assert(BlockCatalog.title(1) == "草方块")
	assert(BlockCatalog.title(2) == "泥土")
	assert(BlockCatalog.title(3) == "原木")
	assert(BlockCatalog.title(4) == "树叶")
	assert(BlockCatalog.title(5) == "石头")
	assert(BlockCatalog.title(6) == "沙子")
	assert(BlockCatalog.title(7) == "木板")
	assert(BlockCatalog.title(8) == "陶瓦")
	assert(BlockCatalog.title(9) == "高纯生铁矿")
	assert(BlockCatalog.title(10) == "煤矿石")
	assert(BlockCatalog.title(11) == "金矿石")
	assert(BlockCatalog.title(12) == "生铁块")
	assert(BlockCatalog.title(13) == "鹅卵石")
	assert(BlockCatalog.title(14) == "石砖")
	assert(BlockCatalog.title(15) == "粗糙花岗岩")
	assert(BlockCatalog.title(16) == "纯净玻璃")
	assert(BlockCatalog.title(17) == "砂岩")
	assert(BlockCatalog.title(18) == "高山雪块")
	assert(BlockCatalog.title(19) == "黑曜石")
	assert(BlockCatalog.title(20) == "工作台")
	# 验证 ItemCatalog 同步名称
	for id in range(1, 21):
		assert(ItemCatalog.title(id) == BlockCatalog.title(id), "ItemCatalog 必须与 BlockCatalog 标题同步")
	print("✓ 20 类方块中文名称规范验证通过")
	
	# 3. 验证动漫调色板矩阵与特殊顶面独立材质
	print("3. 验证色彩矩阵与顶面特殊材质...")
	for id in range(1, 21):
		var c: Color = BlockCatalog.color(id)
		assert(c != Color.TRANSPARENT and c.a > 0.0, "方块 %d 必须具备有效色彩" % id)
		assert(ItemCatalog.color(id) == c, "ItemCatalog 色彩必须与 BlockCatalog 同步")
	
	# 顶面特殊材质断言
	assert(BlockCatalog.has_special_top(1), "草方块必须具备独立顶面草色")
	assert(BlockCatalog.has_special_top(3), "原木必须具备独立顶面年轮色")
	assert(BlockCatalog.has_special_top(20), "工作台必须具备独立工坊台面顶面色")
	assert(not BlockCatalog.has_special_top(2), "泥土无特殊独立顶面")
	assert(not BlockCatalog.has_special_top(5), "石头无特殊独立顶面")
	assert(BlockCatalog.top_color(3) == Color("b88b58"), "原木顶面年轮色必须精确符合基准方案 #B88B58")
	print("✓ 动漫色彩矩阵与特殊顶面独立材质验证通过")
	
	# 4. 验证方块挖掘耗时与适性工具匹配
	print("4. 验证方块挖掘耗时与适性工具匹配...")
	# 耗时数值校验
	assert(BlockCatalog.mine_time(4) == 0.10, "树叶挖掘耗时应为 0.10s")
	assert(BlockCatalog.mine_time(1) == 0.35, "草皮挖掘耗时应为 0.35s")
	assert(BlockCatalog.mine_time(2) == 0.35, "泥土挖掘耗时应为 0.35s")
	assert(BlockCatalog.mine_time(6) == 0.25, "沙子挖掘耗时应为 0.25s")
	assert(BlockCatalog.mine_time(7) == 0.60, "木板挖掘耗时应为 0.60s")
	assert(BlockCatalog.mine_time(3) == 0.70, "原木挖掘耗时应为 0.70s")
	assert(BlockCatalog.mine_time(5) == 1.10, "石头挖掘耗时应为 1.10s")
	assert(BlockCatalog.mine_time(9) == 1.60, "高纯生铁矿挖掘耗时应为 1.60s")
	assert(BlockCatalog.mine_time(10) == 1.30, "煤矿石挖掘耗时应为 1.30s")
	assert(BlockCatalog.mine_time(11) == 1.80, "金矿石挖掘耗时应为 1.80s")
	assert(BlockCatalog.mine_time(12) == 2.00, "生铁块挖掘耗时应为 2.00s")
	assert(BlockCatalog.mine_time(19) == 3.50, "黑曜石挖掘耗时应为 3.50s")
	
	# 适性工具判定校验
	assert(BlockCatalog.effective_tool(5) == "pickaxe", "石头适性工具为镐")
	assert(BlockCatalog.effective_tool(9) == "pickaxe", "铁矿适性工具为镐")
	assert(BlockCatalog.effective_tool(10) == "pickaxe", "煤矿适性工具为镐")
	assert(BlockCatalog.effective_tool(11) == "pickaxe", "金矿适性工具为镐")
	assert(BlockCatalog.effective_tool(12) == "pickaxe", "生铁块适性工具为镐")
	assert(BlockCatalog.effective_tool(13) == "pickaxe", "鹅卵石适性工具为镐")
	assert(BlockCatalog.effective_tool(14) == "pickaxe", "石砖适性工具为镐")
	assert(BlockCatalog.effective_tool(15) == "pickaxe", "花岗岩适性工具为镐")
	assert(BlockCatalog.effective_tool(17) == "pickaxe", "砂岩适性工具为镐")
	assert(BlockCatalog.effective_tool(19) == "pickaxe", "黑曜石适性工具为镐")
	
	assert(BlockCatalog.effective_tool(3) == "axe", "原木适性工具为斧")
	assert(BlockCatalog.effective_tool(4) == "axe", "树叶适性工具为斧")
	assert(BlockCatalog.effective_tool(7) == "axe", "木板适性工具为斧")
	assert(BlockCatalog.effective_tool(20) == "axe", "工作台适性工具为斧")
	
	assert(BlockCatalog.effective_tool(1) == "shovel", "草方块适性工具为锹")
	assert(BlockCatalog.effective_tool(2) == "shovel", "泥土适性工具为锹")
	assert(BlockCatalog.effective_tool(6) == "shovel", "沙子适性工具为锹")
	assert(BlockCatalog.effective_tool(18) == "shovel", "高山雪块适性工具为锹")
	print("✓ 方块挖掘时长与适性工具属性验证通过")
	
	# 5. 验证工具对全部方块的挖掘速度倍率
	print("5. 验证工具全量适性挖掘加速...")
	# 铁镐 (ID 207, 6.0倍) 对全部矿石与岩石加速
	var pick_targets := [5, 8, 9, 10, 11, 12, 13, 14, 15, 17, 19]
	for tid in pick_targets:
		assert(ItemCatalog.get_mining_speed(207, tid) == 6.0, "铁镐对方块 %d 应当加速 6.0 倍" % tid)
		assert(ItemCatalog.get_mining_speed(204, tid) == 3.5, "石镐对方块 %d 应当加速 3.5 倍" % tid)
		assert(ItemCatalog.get_mining_speed(201, tid) == 2.0, "木镐对方块 %d 应当加速 2.0 倍" % tid)
	# 铁镐对木系方块不加速
	assert(ItemCatalog.get_mining_speed(207, 3) == 1.0, "铁镐挖原木不加速")
	assert(ItemCatalog.get_mining_speed(207, 20) == 1.0, "铁镐挖工作台不加速")
	
	# 铁斧 (ID 208, 6.0倍) 对原木、木板、工作台、树叶加速
	var axe_targets := [3, 4, 7, 20]
	for tid in axe_targets:
		assert(ItemCatalog.get_mining_speed(208, tid) == 6.0, "铁斧对木质方块 %d 应当加速 6.0 倍" % tid)
		assert(ItemCatalog.get_mining_speed(205, tid) == 3.5, "石斧对木质方块 %d 应当加速 3.5 倍" % tid)
		assert(ItemCatalog.get_mining_speed(202, tid) == 2.0, "木斧对木质方块 %d 应当加速 2.0 倍" % tid)
	# 铁斧对石头不加速
	assert(ItemCatalog.get_mining_speed(208, 5) == 1.0, "铁斧挖石头不加速")
	
	# 铁锹 (ID 209, 6.0倍) 对草皮、泥土、沙子、雪块加速
	var shovel_targets := [1, 2, 6, 18]
	for tid in shovel_targets:
		assert(ItemCatalog.get_mining_speed(209, tid) == 6.0, "铁锹对壤土方块 %d 应当加速 6.0 倍" % tid)
		assert(ItemCatalog.get_mining_speed(206, tid) == 3.5, "石锹对壤土方块 %d 应当加速 3.5 倍" % tid)
		assert(ItemCatalog.get_mining_speed(203, tid) == 2.0, "木锹对壤土方块 %d 应当加速 2.0 倍" % tid)
	print("✓ 工具全量适性挖掘加速倍率验证通过")
	
	# 6. 验证扩展方块合成配方
	print("6. 验证扩展方块与生铁工具合成配方...")
	var inv = Inventory.new("survival")
	var block_recipes := [
		{"slots": [5, 5],       "expected_id": 14, "expected_count": 4, "name": "石头 ×2 → 石砖 ×4"},
		{"slots": [6, 6],       "expected_id": 17, "expected_count": 2, "name": "沙子 ×2 → 砂岩 ×2"},
		{"slots": [6, 6, 6],    "expected_id": 16, "expected_count": 3, "name": "沙子 ×3 → 纯净玻璃 ×3"},
		{"slots": [9, 9],       "expected_id": 12, "expected_count": 1, "name": "高纯生铁 ×2 → 生铁块"},
		{"slots": [3, 7, 7],    "expected_id": 20, "expected_count": 1, "name": "原木 + 木板 ×2 → 工作台"},
		{"slots": [9, 9, 9],    "expected_id": 207, "expected_count": 1, "name": "高纯生铁 ×3 → 铁镐"},
		{"slots": [3, 9],       "expected_id": 208, "expected_count": 1, "name": "原木 + 高纯生铁 → 铁斧"},
		{"slots": [7, 9],       "expected_id": 209, "expected_count": 1, "name": "木板 + 高纯生铁 → 铁锹"},
		{"slots": [13, 13, 13], "expected_id": 204, "expected_count": 1, "name": "鹅卵石 ×3 → 石镐"},
		{"slots": [3, 13],      "expected_id": 205, "expected_count": 1, "name": "原木 + 鹅卵石 → 石斧"},
		{"slots": [7, 13],      "expected_id": 206, "expected_count": 1, "name": "木板 + 鹅卵石 → 石锹"},
	]
	
	for rec in block_recipes:
		for i in range(3):
			inv.crafting[i] = {"id": 0, "count": 0}
		var inputs: Array = rec.slots
		for i in range(inputs.size()):
			inv.crafting[i] = {"id": inputs[i], "count": 1}
		var res: Dictionary = inv.get_slot("result", 0)
		assert(res.id == rec.expected_id, "%s 合成结果 ID 错误，得到 %d 期望 %d" % [rec.name, res.id, rec.expected_id])
		assert(res.count == rec.expected_count, "%s 产物数量错误，得到 %d 期望 %d" % [rec.name, res.count, rec.expected_count])
	print("✓ 扩展方块与生铁工具合成配方全部验证通过")
	
	# 7. 验证 3D 手持与物品栏渲染节点完整契约
	print("7. 验证 3D 物品节点契约...")
	var held = HeldBlockScene.instantiate()
	var dummy_root := Node3D.new()
	dummy_root.add_child(held)
	
	for id in range(1, 21):
		held.set_block(id)
		assert(held.visible, "方块 %d 手持必须可见" % id)
		assert(held.get_node("Block").visible, "方块 %d 基础立方体必须可见" % id)
		if BlockCatalog.has_special_top(id):
			assert(held.get_node("Top").visible, "方块 %d 顶面独立层必须可见" % id)
	
	var display = ItemDisplay3D.new()
	dummy_root.add_child(display)
	display._ready()
	for id in range(1, 21):
		display.set_item(id)
		assert(display.visible, "方块 %d 在 3D 物品槽必须可见" % id)
		assert(display.block_instance.visible, "方块 %d block_instance 必须可见" % id)
	
	dummy_root.queue_free()
	print("✓ 3D 手持与物品栏渲染节点全量契约测试通过")
	
	# 8. 验证创造模式全量方块与装备选择库
	print("8. 验证创造模式全量方块与装备选择库...")
	var panel = load("res://scenes/InventoryPanel.tscn").instantiate()
	var test_root = Control.new()
	get_root().add_child(test_root)
	test_root.add_child(panel)
	await process_frame
	var creative_inv = Inventory.new("creative")
	panel.bind_inventory(creative_inv)
	panel.open()
	
	# 切换至创造万象库
	panel._set_creative_view(true)
	assert(panel.creative_section.is_visible_in_tree(), "创造模式下物品库必须实际可见")
	assert(not panel.crafting_box.is_visible_in_tree(), "创造物品库视图下合成栏必须实际隐藏")
	panel._set_creative_view(false)
	assert(panel.crafting_box.is_visible_in_tree() and not panel.creative_section.is_visible_in_tree(), "合成页必须显示合成栏并隐藏物品库")
	panel._set_creative_view(true)
	
	# 测试全部分类 (64)
	panel._select_category("all")
	await process_frame
	assert(panel.creative_grid.get_child_count() == 64, "全部分类下应展示全部 64 种物品（含三套新装备）")
	
	# 测试方块分类 (20)
	panel._select_category("blocks")
	await process_frame
	assert(panel.creative_grid.get_child_count() == 20, "方块分类下应展示 20 种标准方块")
	
	# 测试装备分类 (7)
	panel._select_category("equipment")
	await process_frame
	assert(panel.creative_grid.get_child_count() == 28, "装备分类下应展示基础装备和三套新装备，共 28 件")
	
	# 测试工具分类 (9)
	panel._select_category("tools")
	await process_frame
	assert(panel.creative_grid.get_child_count() == 9, "工具分类下应展示 9 种基础工具")
	
	# 测试图纸分类 (2)
	panel._select_category("docs")
	await process_frame
	assert(panel.creative_grid.get_child_count() == 2, "图纸分类下应展示 2 种图纸笔记")
	
	# 测试通过 give_creative_item 获取物品
	assert(creative_inv.give_creative_item(11, 23), "获取金矿石放入背包第 23 格成功")
	assert(creative_inv.bag[23].id == 11 and creative_inv.bag[23].count == -1, "创造模式获取的方块应为无限数量")
	
	# 测试从创造物品库拖拽至指定背包槽
	assert(creative_inv.can_move("creative", 14, "bag", 22), "创造库石砖应可拖入背包第 22 格")
	assert(creative_inv.move_item("creative", 14, "bag", 22), "执行拖拽放入成功")
	assert(creative_inv.bag[22].id == 14 and creative_inv.bag[22].count == -1, "拖拽放入的石砖数量应为无限")
	
	test_root.queue_free()
	print("✓ 创造模式全量方块与装备选择库功能验证通过")
	
	# 9. 验证创造模式全量 20 类方块在世界中实际放置与开采
	print("9. 验证创造模式全量方块在世界中的放置与开采回收...")
	var VoxelWorldScript = load("res://scripts/world/VoxelWorld.gd")
	var world_node: Node3D = Node3D.new()
	world_node.set_script(VoxelWorldScript)
	world_node.world_type = "infinite"
	get_root().add_child(world_node)
	await process_frame
	await process_frame
	
	for id in range(1, 21):
		var test_cell := Vector3i(10, 5, 10)
		assert(world_node.set_block(test_cell, id), "方块 ID %d 必须能够成功放置到世界中" % id)
		assert(world_node.get_block(test_cell) == id, "世界中对应坐标的方块 ID 应为 %d" % id)
		assert(world_node.set_block(test_cell, 0), "测试方块 ID %d 必须能够成功开采消除" % id)
		assert(world_node.get_block(test_cell) == 0, "测试坐标应恢复为空气")
		
	# 验证非法方块 ID 被正确拦截拒绝
	assert(not world_node.set_block(Vector3i(10, 5, 10), -1), "非法负数 ID 必须被拒绝")
	assert(not world_node.set_block(Vector3i(10, 5, 10), 21), "未注册方块 ID 21 必须被拒绝")
	assert(not world_node.set_block(Vector3i(10, 5, 10), 101), "装备 ID 不能当作方块放置到世界中")
	
	world_node.queue_free()
	print("✓ 创造模式全量方块世界放置与边界防御验证全部通过")
	
	print("==========================================")
	print("BLOCKS_SMOKE_PASS: all block features 100%!")
	print("==========================================")
	quit(0)

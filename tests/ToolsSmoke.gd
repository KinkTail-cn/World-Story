extends SceneTree

const Inventory = preload("res://scripts/inventory/Inventory.gd")
const ItemCatalog = preload("res://scripts/inventory/ItemCatalog.gd")
const BlockCatalog = preload("res://scripts/content/BlockCatalog.gd")
const ToolVisual = preload("res://scripts/player/ToolVisual.gd")
const HeldBlockScene = preload("res://scenes/HeldBlock.tscn")
const ItemDisplay3D = preload("res://scripts/ui/ItemDisplay3D.gd")

func _initialize() -> void:
	create_timer(10.0).timeout.connect(func(): push_error("TOOLS_SMOKE_TIMEOUT"); quit(1))
	_run.call_deferred()

func _run() -> void:
	print("--- 开始基础工具系统全方位自动化测试 ---")
	
	# 1. 验证工具定义、分类、材质与名称
	print("1. 验证工具定义与属性判断...")
	for id in range(201, 210):
		assert(ItemCatalog.is_tool_item(id), "ID %d 必须判定为工具" % id)
		assert(not ItemCatalog.is_block(id), "工具 ID %d 不能是方块" % id)
		assert(not ItemCatalog.is_equipment(id), "工具 ID %d 不能是穿戴装备" % id)
	
	assert(not ItemCatalog.is_tool_item(0), "ID 0 不是工具")
	assert(not ItemCatalog.is_tool_item(1), "方块不是工具")
	assert(not ItemCatalog.is_tool_item(101), "铁头盔不是工具")
	
	# 类型断言
	assert(ItemCatalog.tool_type(201) == "pickaxe" and ItemCatalog.tool_type(204) == "pickaxe" and ItemCatalog.tool_type(207) == "pickaxe")
	assert(ItemCatalog.tool_type(202) == "axe" and ItemCatalog.tool_type(205) == "axe" and ItemCatalog.tool_type(208) == "axe")
	assert(ItemCatalog.tool_type(203) == "shovel" and ItemCatalog.tool_type(206) == "shovel" and ItemCatalog.tool_type(209) == "shovel")
	
	# 材质断言
	assert(ItemCatalog.tool_material(201) == "wood" and ItemCatalog.tool_material(202) == "wood" and ItemCatalog.tool_material(203) == "wood")
	assert(ItemCatalog.tool_material(204) == "stone" and ItemCatalog.tool_material(205) == "stone" and ItemCatalog.tool_material(206) == "stone")
	assert(ItemCatalog.tool_material(207) == "iron" and ItemCatalog.tool_material(208) == "iron" and ItemCatalog.tool_material(209) == "iron")
	
	# 名称断言
	assert(ItemCatalog.title(201) == "木镐" and ItemCatalog.title(202) == "木斧" and ItemCatalog.title(203) == "木锹")
	assert(ItemCatalog.title(204) == "石镐" and ItemCatalog.title(205) == "石斧" and ItemCatalog.title(206) == "石锹")
	assert(ItemCatalog.title(207) == "铁镐" and ItemCatalog.title(208) == "铁斧" and ItemCatalog.title(209) == "铁锹")
	print("✓ 工具定义、类型、材质分类验证通过")
	
	# 2. 验证挖掘加速倍率阶梯与适性
	print("2. 验证挖掘效率倍率机制...")
	# 镐加速：对石头(5)、陶瓦(8)加速；对泥土(2)、原木(3)不加速
	assert(ItemCatalog.get_mining_speed(201, 5) == 2.0, "木镐挖石头倍率应为 2.0")
	assert(ItemCatalog.get_mining_speed(204, 5) == 3.5, "石镐挖石头倍率应为 3.5")
	assert(ItemCatalog.get_mining_speed(207, 5) == 6.0, "铁镐挖石头倍率应为 6.0")
	assert(ItemCatalog.get_mining_speed(207, 8) == 6.0, "铁镐挖陶瓦倍率应为 6.0")
	assert(ItemCatalog.get_mining_speed(207, 2) == 1.0, "铁镐挖泥土不应加速")
	assert(ItemCatalog.get_mining_speed(207, 3) == 1.0, "铁镐砍原木不应加速")
	
	# 斧加速：对原木(3)、木板(7)加速；对石头(5)不加速
	assert(ItemCatalog.get_mining_speed(202, 3) == 2.0, "木斧砍原木倍率应为 2.0")
	assert(ItemCatalog.get_mining_speed(205, 3) == 3.5, "石斧砍原木倍率应为 3.5")
	assert(ItemCatalog.get_mining_speed(208, 3) == 6.0, "铁斧砍原木倍率应为 6.0")
	assert(ItemCatalog.get_mining_speed(208, 7) == 6.0, "铁斧砍木板倍率应为 6.0")
	assert(ItemCatalog.get_mining_speed(208, 5) == 1.0, "铁斧挖石头不应加速")
	
	# 锹加速：对草方块(1)、泥土(2)、沙子(6)加速；对石头(5)不加速
	assert(ItemCatalog.get_mining_speed(203, 2) == 2.0, "木锹挖泥土倍率应为 2.0")
	assert(ItemCatalog.get_mining_speed(206, 2) == 3.5, "石锹挖泥土倍率应为 3.5")
	assert(ItemCatalog.get_mining_speed(209, 2) == 6.0, "铁锹挖泥土倍率应为 6.0")
	assert(ItemCatalog.get_mining_speed(209, 1) == 6.0, "铁锹挖草皮倍率应为 6.0")
	assert(ItemCatalog.get_mining_speed(209, 6) == 6.0, "铁锹挖沙子倍率应为 6.0")
	assert(ItemCatalog.get_mining_speed(209, 5) == 1.0, "铁锹挖石头不应加速")
	
	# 空手及普通方块
	assert(ItemCatalog.get_mining_speed(0, 5) == 1.0, "空手挖掘倍率为 1.0")
	assert(ItemCatalog.get_mining_speed(1, 5) == 1.0, "手持方块挖掘倍率为 1.0")
	print("✓ 挖掘效率倍率梯次验证通过")
	
	# 3. 验证 9 种基础工具合成配方
	print("3. 验证基础工具工坊合成配方...")
	var inv = Inventory.new("survival")
	
	var recipes_test := [
		# 木制系列
		{"slots": [7, 7, 7], "expected_id": 201, "name": "木镐"},
		{"slots": [3, 7],    "expected_id": 202, "name": "木斧"},
		{"slots": [7, 7],    "expected_id": 203, "name": "木锹"},
		# 石制系列
		{"slots": [5, 5, 5], "expected_id": 204, "name": "石镐"},
		{"slots": [3, 5],    "expected_id": 205, "name": "石斧"},
		{"slots": [5, 7],    "expected_id": 206, "name": "石锹"},
		# 铁制系列
		{"slots": [8, 8, 8], "expected_id": 207, "name": "铁镐"},
		{"slots": [3, 8],    "expected_id": 208, "name": "铁斧"},
		{"slots": [7, 8],    "expected_id": 209, "name": "铁锹"}
	]
	
	for rec in recipes_test:
		# 清空合成台
		for i in range(3):
			inv.crafting[i] = {"id": 0, "count": 0}
		var inputs: Array = rec.slots
		for i in range(inputs.size()):
			inv.crafting[i] = {"id": inputs[i], "count": 1}
		var res: Dictionary = inv.get_slot("result", 0)
		assert(res.id == rec.expected_id, "%s 配方合成结果 ID 错误，得到 %d 期望 %d" % [rec.name, res.id, rec.expected_id])
		assert(res.count == 1, "%s 合成产物数量应为 1" % rec.name)
	print("✓ 9 种基础工具合成配方全部验证通过")
	
	# 4. 验证工具不可堆叠规则
	print("4. 验证工具单格独占（不可堆叠）规则...")
	inv.bag[0] = {"id": 201, "count": 1}
	inv.bag[1] = {"id": 201, "count": 1}
	assert(not inv._can_add_to_bag(201, 1, 0), "工具槽位已有相同工具时不应允许堆叠增加")
	inv.move_item("bag", 0, "bag", 1)
	assert(inv.bag[0].id == 201 and inv.bag[1].id == 201, "工具之间移动应当是互换而非合并堆叠")
	print("✓ 工具不可堆叠与独立槽位存放验证通过")
	
	# 5. 验证 3D 模型渲染节点创建
	print("5. 验证 3D 视觉展示与手持节点集成...")
	# ToolVisual 单独测试
	var tv := ToolVisual.new()
	root.add_child(tv)
	for id in range(201, 210):
		tv.set_tool(id, false)
		assert(tv.get_child_count() > 0, "ToolVisual 应为工具 %d 构建 3D 子节点" % id)
		tv.set_tool(id, true)
		assert(tv.get_child_count() > 0, "ToolVisual 应为工具 %d 构建展示模式 3D 子节点" % id)
	tv.queue_free()
	
	# ItemDisplay3D 测试
	var disp := ItemDisplay3D.new()
	root.add_child(disp)
	disp.set_item(201)
	assert(disp.visible, "ItemDisplay3D 显示工具时应可见")
	disp.set_item(207)
	assert(disp.visible, "ItemDisplay3D 切换铁镐应正常显示")
	disp.queue_free()
	
	# HeldBlock 手持测试
	var held = HeldBlockScene.instantiate()
	root.add_child(held)
	held.set_block(201)
	assert(held.visible, "手持木镐时 HeldBlock 必须可见")
	assert(held.tool_visual != null and is_instance_valid(held.tool_visual), "手持工具时 tool_visual 节点必须成功创建")
	held.set_block(207)
	assert(held.visible and held.tool_visual != null, "切换至手持铁镐时正常维持")
	held.set_block(1)
	assert(held.tool_visual == null, "切换回普通方块时工具模型应被安全清理")
	held.queue_free()
	print("✓ 3D 视觉组件与手持节点集成测试通过")
	
	await process_frame
	print("==========================================")
	print("TOOLS_SMOKE_PASS: all tool features 100%!")
	print("==========================================")
	quit(0)

extends SceneTree

## 多元化特色基础武器与现代物品介绍窗口全方位自动化验证

const ItemCatalog = preload("res://scripts/inventory/ItemCatalog.gd")
const Inventory = preload("res://scripts/inventory/Inventory.gd")
const WeaponVisual = preload("res://scripts/player/WeaponVisual.gd")
const ItemDisplay3D = preload("res://scripts/ui/ItemDisplay3D.gd")
const HeldBlockScene = preload("res://scenes/HeldBlock.tscn")
const ItemTooltip = preload("res://scripts/ui/ItemTooltip.gd")
const InventoryPanelScene = preload("res://scenes/InventoryPanel.tscn")

func _initialize() -> void:
	create_timer(10.0).timeout.connect(func(): push_error("WEAPONS_SMOKE_TIMEOUT"); quit(1))
	_run.call_deferred()

func _run() -> void:
	print("--- 开始多元化特色武器与物品介绍窗口自动化测试 ---")
	
	# 1. 验证 5 类特色武器定义与合法性
	print("1. 验证 5 类特色武器定义与属性...")
	var weapon_ids: Array[int] = [301, 302, 303, 304, 305]
	for wid in weapon_ids:
		assert(ItemCatalog.is_weapon(wid), "ID %d 必须判定为武器" % wid)
		assert(not ItemCatalog.is_tool_item(wid), "武器 ID %d 不能是开采工具" % wid)
		assert(not ItemCatalog.is_block(wid), "武器 ID %d 不能是方块" % wid)
		assert(not ItemCatalog.is_equipment(wid), "武器 ID %d 不能是防具" % wid)
		assert(not ItemCatalog.is_document(wid), "武器 ID %d 不能是图纸" % wid)
		
	assert(ItemCatalog.title(301) == "原木轻短剑")
	assert(ItemCatalog.title(302) == "砥石破山斧")
	assert(ItemCatalog.title(303) == "精炼铁长剑")
	assert(ItemCatalog.title(304) == "灵蕴金晶细剑")
	assert(ItemCatalog.title(305) == "暗渊黑曜石巨剑")
	
	assert(ItemCatalog.weapon_type(301) == "sword")
	assert(ItemCatalog.weapon_type(302) == "battleaxe")
	assert(ItemCatalog.weapon_type(303) == "greatsword")
	assert(ItemCatalog.weapon_type(304) == "rapier")
	assert(ItemCatalog.weapon_type(305) == "colossus")
	print("✓ 5 类特色武器名称与类型映射验证通过")
	
	# 2. 验证武器战斗属性梯级（伤害、攻速、击退）
	print("2. 验证武器战斗属性梯级...")
	assert(ItemCatalog.weapon_damage(301) == 4, "木短剑伤害为 4")
	assert(ItemCatalog.weapon_damage(302) == 7, "石战斧伤害为 7")
	assert(ItemCatalog.weapon_damage(303) == 9, "铁长剑伤害为 9")
	assert(ItemCatalog.weapon_damage(304) == 12, "金细剑伤害为 12")
	assert(ItemCatalog.weapon_damage(305) == 16, "黑曜石巨剑伤害为 16")
	
	assert(ItemCatalog.weapon_speed(304) > ItemCatalog.weapon_speed(301), "金细剑攻速应极快")
	assert(ItemCatalog.weapon_knockback(305) >= 2.0, "黑曜石巨剑击退最强")
	print("✓ 武器战斗数值梯度验证通过")
	
	# 3. 验证武器单格独占（不可堆叠）规则
	print("3. 验证武器不可堆叠规则...")
	var inv = Inventory.new("survival")
	assert(inv.add_item(303, 1), "放入第 1 把铁长剑成功")
	assert(inv.bag[0].id == 303 and inv.bag[0].count == 1, "第 0 格为铁长剑且数量为 1")
	assert(inv.add_item(303, 1), "放入第 2 把铁长剑成功")
	assert(inv.bag[1].id == 303 and inv.bag[1].count == 1, "第 2 把铁长剑必须单独占用新格子")
	assert(inv.bag[0].count == 1, "第 1 把铁长剑不能堆叠增加数量")
	print("✓ 武器单格独占性验证通过")
	
	# 4. 验证特色武器工坊合成配方
	print("4. 验证特色武器工坊合成配方...")
	var craft_inv = Inventory.new("survival")
	
	# 原木轻短剑：原木 ×2 (3, 3)
	craft_inv.crafting[0] = {"id": 3, "count": 1}
	craft_inv.crafting[1] = {"id": 3, "count": 1}
	var res1 = craft_inv.get_slot("result", 0)
	assert(res1.id == 301 and res1.count == 1, "原木×2 必须合成原木轻短剑")
	
	# 砥石破山斧：原木 + 鹅卵石 ×2 (3, 13, 13)
	craft_inv.crafting[0] = {"id": 3, "count": 1}
	craft_inv.crafting[1] = {"id": 13, "count": 1}
	craft_inv.crafting[2] = {"id": 13, "count": 1}
	var res2 = craft_inv.get_slot("result", 0)
	assert(res2.id == 302 and res2.count == 1, "原木+鹅卵石×2 必须合成砥石破山斧")
	
	# 精炼铁长剑：原木 + 高纯生铁 ×2 (3, 9, 9)
	craft_inv.crafting[0] = {"id": 3, "count": 1}
	craft_inv.crafting[1] = {"id": 9, "count": 1}
	craft_inv.crafting[2] = {"id": 9, "count": 1}
	var res3 = craft_inv.get_slot("result", 0)
	assert(res3.id == 303 and res3.count == 1, "原木+生铁×2 必须合成精炼铁长剑")
	
	# 灵蕴金晶细剑：原木 + 金矿石 (3, 11)
	craft_inv.crafting[0] = {"id": 3, "count": 1}
	craft_inv.crafting[1] = {"id": 11, "count": 1}
	craft_inv.crafting[2] = {"id": 0, "count": 0}
	var res4 = craft_inv.get_slot("result", 0)
	assert(res4.id == 304 and res4.count == 1, "原木+金矿石 必须合成灵蕴金晶细剑")
	
	# 暗渊黑曜石巨剑：原木 + 黑曜石 ×2 (3, 19, 19)
	craft_inv.crafting[0] = {"id": 3, "count": 1}
	craft_inv.crafting[1] = {"id": 19, "count": 1}
	craft_inv.crafting[2] = {"id": 19, "count": 1}
	var res5 = craft_inv.get_slot("result", 0)
	assert(res5.id == 305 and res5.count == 1, "原木+黑曜石×2 必须合成暗渊黑曜石巨剑")
	print("✓ 5 类特色武器工坊合成配方全部验证通过")
	
	# 5. 验证 3D 视觉组件与手持渲染契约
	print("5. 验证 3D 视觉展示与手持契约...")
	var root_node = Node3D.new()
	root.add_child(root_node)
	
	for wid in weapon_ids:
		var display = ItemDisplay3D.new()
		root_node.add_child(display)
		display.set_item(wid)
		assert(display.visible, "武器 3D 展示节点必须可见")
		display.queue_free()
		
	var held = HeldBlockScene.instantiate()
	root_node.add_child(held)
	for wid in weapon_ids:
		held.set_block(wid)
		assert(held.visible, "手持武器节点必须可见")
		assert(held.weapon_visual != null, "手持节点中必须包含 weapon_visual 实体")
	held.queue_free()
	root_node.queue_free()
	print("✓ 3D 视觉组件与手持渲染契约测试通过")
	
	# 6. 验证创造模式面板武器分类与道具总数
	print("6. 验证创造模式面板武器分类...")
	var test_root = Control.new()
	root.add_child(test_root)
	var panel = InventoryPanelScene.instantiate()
	test_root.add_child(panel)
	panel.bind_inventory(Inventory.new("creative"))
	panel.open()
	await process_frame
	
	# 验证全部道具列表 (64)
	panel._select_category("all")
	await process_frame
	assert(panel.creative_grid.get_child_count() == 64, "全量道具应为 64 种（包含 5 种武器与 28 件装备）")
	
	# 验证独立武器分类 (5)
	panel._select_category("weapons")
	await process_frame
	assert(panel.creative_grid.get_child_count() == 5, "武器专属分类下应恰好展示 5 种特色武器")
	test_root.queue_free()
	print("✓ 创造模式面板武器分类与 64 种全道具集成验证通过")
	
	# 7. 验证现代物品介绍窗口结构化数据获取与各字段契约
	print("7. 验证物品介绍窗口数据结构与品质系统...")
	for wid in weapon_ids:
		var info = ItemCatalog.get_item_info(wid)
		assert(info.has("title") and not info.title.is_empty(), "必须包含有效标题")
		assert(info.category == "近战武器", "分类必须为近战武器")
		assert(info.has("rarity_color"), "必须具备品质颜色")
		assert(info.has("description") and not info.description.is_empty(), "必须具备沉浸式故事描述")
		assert(info.has("usage_tip") and not info.usage_tip.is_empty(), "必须具备操作指引")
		assert(info.attributes.size() >= 3, "武器必须提供攻击、攻速、击退三维属性条")
		
	# 验证方块与装备的介绍数据完整性
	var block_info = ItemCatalog.get_item_info(1)
	assert(block_info.category == "建筑方块")
	assert(not block_info.attributes.is_empty(), "方块必须提供硬度与堆叠属性")
	
	var equip_info = ItemCatalog.get_item_info(102)
	assert(equip_info.category == "灵蕴防具")
	assert(not equip_info.attributes.is_empty(), "防具必须提供防护属性")
	print("✓ 物品介绍窗口结构化数据包验证全部通过")
	
	print("==========================================")
	print("WEAPONS_SMOKE_PASS: all features 100%!")
	print("==========================================")
	quit(0)

extends RefCounted

const BlockCatalog = preload("res://scripts/content/BlockCatalog.gd")
const EquipmentSets = preload("res://scripts/content/EquipmentSets.gd")

static func title(id: int) -> String:
	if is_block(id):
		return BlockCatalog.title(id)
	if EquipmentSets.is_new(id):
		return EquipmentSets.title(id)
	match id:
		101: return "铁头盔"
		102: return "铁盔甲"
		103: return "铁裤甲"
		104: return "铁鞋"
		105: return "铁手套"
		106: return "旅人披风"
		107: return "皮腰带"
		108: return "笔记本"
		109: return "蓝色图纸"
		201: return "木镐"
		202: return "木斧"
		203: return "木锹"
		204: return "石镐"
		205: return "石斧"
		206: return "石锹"
		207: return "铁镐"
		208: return "铁斧"
		209: return "铁锹"
		301: return "原木轻短剑"
		302: return "砥石破山斧"
		303: return "精炼铁长剑"
		304: return "灵蕴金晶细剑"
		305: return "暗渊黑曜石巨剑"
		_: return "空气"

static func color(id: int) -> Color:
	if is_block(id):
		return BlockCatalog.color(id)
	if EquipmentSets.is_new(id):
		return EquipmentSets.color(id)
	match id:
		101, 102, 103, 104, 105: return Color("aabfcd")
		106: return Color("c85f88")
		107: return Color("78513f")
		108: return Color("efe0b2")
		109: return Color("4c8fbd")
		201, 202, 203: return Color("#c89f64") # 木制
		204, 205, 206: return Color("#9aa6b2") # 石制
		207, 208, 209: return Color("#e2edf8") # 铁制
		301: return Color("#c89f64") # 原木轻短剑
		302: return Color("#8e9aa5") # 砥石破山斧
		303: return Color("#e2edf8") # 精炼铁长剑
		304: return Color("#f3d258") # 灵蕴金晶细剑
		305: return Color("#5d368e") # 暗渊黑曜石巨剑
		_: return Color.TRANSPARENT

static func is_equipment(id: int) -> bool:
	return EquipmentSets.slot(id) >= 0

static func equipment_slot(id: int) -> int:
	return EquipmentSets.slot(id)

static func equipment_ids() -> Array[int]:
	return EquipmentSets.ALL_IDS.duplicate()

static func is_block(id: int) -> bool:
	return BlockCatalog.is_valid_block(id)

static func is_document(id: int) -> bool:
	return id == 108 or id == 109

## 判断是否为工具（ID 201 ~ 209）
static func is_tool_item(id: int) -> bool:
	return id >= 201 and id <= 209

## 获取工具类型：pickaxe（镐）、axe（斧）、shovel（锹）
static func tool_type(id: int) -> String:
	match id:
		201, 204, 207: return "pickaxe"
		202, 205, 208: return "axe"
		203, 206, 209: return "shovel"
		_: return ""

static func is_pickaxe(id: int) -> bool:
	return tool_type(id) == "pickaxe"

static func is_axe(id: int) -> bool:
	return tool_type(id) == "axe"

static func is_shovel(id: int) -> bool:
	return tool_type(id) == "shovel"


## 获取工具材质梯级：wood（木）、stone（石）、iron（铁）
static func tool_material(id: int) -> String:
	match id:
		201, 202, 203: return "wood"
		204, 205, 206: return "stone"
		207, 208, 209: return "iron"
		_: return ""

## 计算针对特定方块的挖掘速度倍率
static func get_mining_speed(tool_id: int, block_id: int) -> float:
	if not is_tool_item(tool_id) or block_id <= 0:
		return 1.0
	
	var type: String = tool_type(tool_id)
	var material: String = tool_material(tool_id)
	
	# 根据材质确定挖掘加速基准倍率（木：2.0倍，石：3.5倍，铁：6.0倍）
	var speed_tier: float = 1.0
	match material:
		"wood": speed_tier = 2.0
		"stone": speed_tier = 3.5
		"iron": speed_tier = 6.0
	
	# 检查工具与方块类型的适性匹配
	var is_effective: bool = false
	match type:
		"pickaxe":
			# 镐擅长：石头(5)、陶瓦(8)、铁矿(9)、煤矿(10)、金矿(11)、生铁块(12)、鹅卵石(13)、石砖(14)、花岗岩(15)、砂岩(17)、黑曜石(19)
			is_effective = (block_id in [5, 8, 9, 10, 11, 12, 13, 14, 15, 17, 19])
		"axe":
			# 斧擅长：原木(3)、木板(7)、树叶(4)、工作台(20)
			is_effective = (block_id in [3, 7, 4, 20])
		"shovel":
			# 锹擅长：草方块(1)、泥土(2)、沙子(6)、高山雪块(18)
			is_effective = (block_id in [1, 2, 6, 18])
	
	return speed_tier if is_effective else 1.0


## 判断是否为武器（ID 301 ~ 305）
static func is_weapon(id: int) -> bool:
	return id >= 301 and id <= 305

## 获取武器类型：sword（短剑）、battleaxe（战斧）、greatsword（长剑）、rapier（细剑）、colossus（巨剑）
static func weapon_type(id: int) -> String:
	match id:
		301: return "sword"
		302: return "battleaxe"
		303: return "greatsword"
		304: return "rapier"
		305: return "colossus"
		_: return ""

## 获取武器材质：wood, stone, iron, gold, obsidian
static func weapon_material(id: int) -> String:
	match id:
		301: return "wood"
		302: return "stone"
		303: return "iron"
		304: return "gold"
		305: return "obsidian"
		_: return ""

## 获取武器基础物理伤害
static func weapon_damage(id: int) -> int:
	match id:
		301: return 4
		302: return 7
		303: return 9
		304: return 12
		305: return 16
		_: return 1

## 获取武器攻击频率（每秒挥击次数）
static func weapon_speed(id: int) -> float:
	match id:
		301: return 1.6
		302: return 1.1
		303: return 1.5
		304: return 1.9
		305: return 0.95
		_: return 1.0

## 获取武器击退力量倍率
static func weapon_knockback(id: int) -> float:
	match id:
		301: return 1.0
		302: return 1.6
		303: return 1.3
		304: return 0.8
		305: return 2.2
		_: return 1.0

## 获取物品分类标签
static func item_category(id: int) -> String:
	if is_weapon(id): return "近战武器"
	if is_tool_item(id): return "开采工具"
	if is_equipment(id): return "灵蕴防具"
	if is_document(id): return "工坊图纸"
	if is_block(id): return "建筑方块"
	return "未知物品"

## 获取物品品质：common（普通）, uncommon（精良）, rare（稀有）, epic（史诗）, legendary（传说）
static func rarity(id: int) -> String:
	match EquipmentSets.style(id):
		"ranger": return "uncommon"
		"knight": return "rare"
		"mage": return "epic"
	if id == 305 or id == 19: return "legendary"
	if id == 304 or id == 11 or id == 12 or id == 106: return "epic"
	if id == 303 or id == 207 or id == 208 or id == 209 or id == 9 or (id >= 101 and id <= 105): return "rare"
	if id == 302 or id == 204 or id == 205 or id == 206 or id == 107 or id in [8, 10, 14, 15, 17, 20]: return "uncommon"
	return "common"

## 获取品质对应的日系动漫主题色彩
static func rarity_color(id: int) -> Color:
	match rarity(id):
		"legendary": return Color("#ffb347") # 传说金橙
		"epic": return Color("#c576f6")      # 史诗幽紫
		"rare": return Color("#5ec4f8")      # 稀有蔚蓝
		"uncommon": return Color("#5fe284")  # 精良翠绿
		_: return Color("#e8edf2")           # 普通纯白

## 沉浸式奇幻背景故事文本
static func description(id: int) -> String:
	if EquipmentSets.is_new(id):
		return EquipmentSets.description(id)
	match id:
		# 武器
		301: return "以轻韧原木切削打磨而成的练习轻刃，轻快称手，是初出茅庐的开拓者最可靠的防身伙伴。"
		302: return "选用海岛原生坚石打造的粗犷战斧，重心靠前，势大力沉，具有开山裂石般的厚重劈砍力。"
		303: return "以高纯生铁千锤百炼锻造的骑士佩剑，剑身平滑笔挺，锋刃寒芒凛冽，攻守兼备。"
		304: return "熔铸金矿与微量魔力灵晶的华丽细剑，剑身轻若无物，可在瞬息之间发动疾风骤雨般的连续突刺。"
		305: return "深渊黑曜石凝结的毁灭重刃，散发着沉郁的幽暗晶光，每一次挥砍都能引起空气撕裂与强劲冲击波。"
		# 工具
		201: return "用轻便木板拼合的简易镐，能够开采基础石料与矿质。"
		202: return "以原木与木板结合制作的开荒斧，砍伐林木效率提升。"
		203: return "用于挖掘松软泥沙的木制平锹，适宜初期土地平整。"
		204: return "坚硬石材凿磨而成的耐用石镐，开采效率明显跃升。"
		205: return "锋利的石斧，能迅速伐倒茂密树冠与硬质林木。"
		206: return "坚固的石锹，挖掘泥土和沙滩得心应手。"
		207: return "生铁精打细磨的高效铁镐，坚固耐用，能迅速破开各类坚硬岩石与深层矿脉。"
		208: return "伐木者的利器，刀口锋利，斩断巨树如履平地。"
		209: return "开山修路的生铁精锹，能以惊人速度搬运土石沙土。"
		# 防具
		101: return "精炼生铁铸造的头盔，保护头部免受落石击打。"
		102: return "质地坚实的生铁胸甲，提供极高的防护稳定性。"
		103: return "防护膝盖与大腿的重型腿甲，兼顾机动与防护。"
		104: return "坚实的行军铁靴，在泥泞与岩滩中稳步行进。"
		105: return "覆盖手腕的生铁护手，增强握持力与防割伤能力。"
		106: return "编织灵蕴纺线的旅人披风，在海风与奔跑中轻柔摇曳。"
		107: return "厚实耐磨的生皮腰带，用于系紧全身防具与行囊。"
		108: return "记录岛屿探索见闻与图纸设计的日志随笔。"
		109: return "刻绘有工坊精准三维微体素结构的建筑工程蓝图。"
		# 方块精选
		1: return "晴风岛生机勃勃的草皮方块，散发着青草与泥土的清香。"
		2: return "湿润肥沃的自然泥土，适合植物生根与地形改造。"
		3: return "笔直挺拔的原木树干，年轮清晰，是建造工坊的基石。"
		4: return "苍翠茂密的自然树叶，透着阳光的温和斑驳。"
		5: return "海岛基础素雅岩石，坚硬致密，开采可获得石材。"
		6: return "阳光照耀下的金米色海滩细沙，踩上去松软温润。"
		7: return "规整拼装的白桦原木板材，四角带有金属铆钉加固。"
		8: return "古典红陶经过烧结成型的方砖，色泽温暖古朴。"
		9: return "地底蕴藏的高纯度生铁矿石，闪烁着温润的黄铜金属光泽。"
		10: return "深藏地层的煤矿结晶，工业与锻造的核心热能来源。"
		11: return "深层岩体中闪耀的珍贵金矿，蕴含奇妙的魔力传导特性。"
		12: return "高纯生铁冶炼压铸成型的致密金属实心块，坚不可摧。"
		13: return "天然碎石砌筑的鹅卵石块，适合铺设古朴小道。"
		14: return "经过工匠精心打磨切削的规整石砖，现代城堡的构筑基石。"
		15: return "粉润温雅的天然粗糙花岗岩，质感细腻高贵。"
		16: return "经过高温熔炼净化的澄澈玻璃，清澈通透，采光绝佳。"
		17: return "岁月沉积而成的金黄沙岩，具有沙漠文明的沧桑韵味。"
		18: return "极高山巅常年积压的纯净雪块，寒气四溢，质感洁白。"
		19: return "火山熔岩与海水瞬间交融而成的黑曜石，硬度登峰造极。"
		20: return "配备精细量尺与木工工具的操作台，创造世界的起点。"
		_: return "一种蕴含着无限可能的奇妙方块物品。"

## 物品操作与使用提示
static func usage_tip(id: int) -> String:
	if is_weapon(id):
		return "【鼠标左键】挥动与采集，战斗功能尚未开放\n【拖拽】放入快捷栏切换手持武器"
	elif is_tool_item(id):
		var t_name: String = "镐" if is_pickaxe(id) else ("斧" if is_axe(id) else "锹")
		return "【鼠标左键】按住挖掘对应适性方块（%s加速）\n【拖拽】整理至行囊或放入快捷栏" % t_name
	elif is_equipment(id):
		return "【双击 / 右键】快速穿戴至角色对应装备部位\n【拖拽】手动放置到左侧装备槽"
	elif is_document(id):
		return "【放置】放入快捷栏，右键对准地面放置实体\n【查看】瞄准地面实体按 R 键展开工坊详情"
	elif is_block(id):
		return "【鼠标右键】放置到目标方块表面\n【鼠标左键】敲碎开采回收方块"
	return "【拖拽】在背包与快捷栏间调整位置"

## 获取用于构建现代化悬浮介绍卡片的结构化数据包
static func get_item_info(id: int) -> Dictionary:
	var t: String = title(id)
	var cat: String = item_category(id)
	var r: String = rarity(id)
	var r_col: Color = rarity_color(id)
	var desc: String = description(id)
	var tip: String = usage_tip(id)
	
	var attrs: Array[Dictionary] = []
	if is_weapon(id):
		attrs.append({"icon": "🗡️", "label": "伤害（尚未生效）", "val": "%d 点" % weapon_damage(id), "color": Color("#ff7b72")})
		attrs.append({"icon": "⚡", "label": "挥斩攻速", "val": "%.2f 次/秒" % weapon_speed(id), "color": Color("#79c0ff")})
		var kb_text: String = "中等"
		var kb_val: float = weapon_knockback(id)
		if kb_val > 2.0: kb_text = "极强击飞"
		elif kb_val > 1.4: kb_text = "强力击退"
		elif kb_val < 1.0: kb_text = "轻微僵直"
		attrs.append({"icon": "💥", "label": "击退（尚未生效）", "val": kb_text, "color": Color("#e3b341")})
	elif is_tool_item(id):
		var t_type_str: String = "开山镐" if is_pickaxe(id) else ("伐木斧" if is_axe(id) else "掘土锹")
		attrs.append({"icon": "⛏️", "label": "工具类别", "val": t_type_str, "color": Color("#d2a8ff")})
		var spd: float = 2.0 if tool_material(id) == "wood" else (3.5 if tool_material(id) == "stone" else 6.0)
		attrs.append({"icon": "⏩", "label": "挖掘倍率", "val": "%.1f 倍加速" % spd, "color": Color("#56d364")})
	elif is_equipment(id):
		var slot_names := ["头部护具", "胸部重铠", "腿部战甲", "足部战靴", "手部护手", "背部披风", "腰部腰带"]
		var s_idx: int = equipment_slot(id)
		var s_name: String = slot_names[s_idx] if (s_idx >= 0 and s_idx < slot_names.size()) else "防具"
		attrs.append({"icon": "🛡️", "label": "穿戴部位", "val": s_name, "color": Color("#79c0ff")})
		if EquipmentSets.is_new(id):
			attrs.append({"icon": "◆", "label": "装备风格", "val": EquipmentSets.TITLES[EquipmentSets.style(id)], "color": Color("#d5b37b")})
		else:
			attrs.append({"icon": "✨", "label": "装备效果", "val": "外观装饰", "color": Color("#7ee787")})
	elif is_block(id):
		attrs.append({"icon": "🧱", "label": "方块硬度", "val": "%.2f 秒" % BlockCatalog.mine_time(id), "color": Color("#e3b341")})
		attrs.append({"icon": "📦", "label": "堆叠上限", "val": "64 个/格", "color": Color("#8b949e")})
		
	return {
		"id": id,
		"title": t,
		"category": cat,
		"rarity": r,
		"rarity_color": r_col,
		"description": desc,
		"usage_tip": tip,
		"attributes": attrs
	}

static func draw_icon(canvas: Control, id: int, origin: Vector2, extent: float) -> void:
	if id == 0:
		return
	if is_block(id):
		_draw_real_block(canvas, id, origin, extent)
	elif is_equipment(id):
		_draw_real_equipment(canvas, id, origin, extent)
	elif is_document(id):
		_draw_real_document(canvas, id, origin, extent)
	elif is_tool_item(id):
		_draw_real_tool(canvas, id, origin, extent)
	elif is_weapon(id):
		_draw_real_weapon(canvas, id, origin, extent)


# -----------------------------------------------------------------------------
# 原方块 3D 侧上方视角立体显示 (ID 1 ~ 8)
# -----------------------------------------------------------------------------

static func _draw_real_block(canvas: Control, id: int, origin: Vector2, extent: float) -> void:
	var w: float = extent * 0.42
	var h: float = extent * 0.24
	var d: float = extent * 0.38
	var cy: float = origin.y - d * 0.16
	
	var p_top := Vector2(origin.x, cy - h)
	var p_right := Vector2(origin.x + w, cy)
	var p_mid := Vector2(origin.x, cy + h)
	var p_left := Vector2(origin.x - w, cy)
	
	var p_left_bot := Vector2(origin.x - w, cy + d)
	var p_mid_bot := Vector2(origin.x, cy + h + d)
	var p_right_bot := Vector2(origin.x + w, cy + d)
	
	var top_c := Color.WHITE
	var left_c := Color.WHITE
	var right_c := Color.WHITE
	
	match id:
		1: # 草方块：鲜嫩草绿顶面 + 侧面鲜明草皮层与暖咖啡泥土层
			top_c = Color("#69cf3a")
			var grass_left := Color("#5cbf30")
			var dirt_left := Color("#986438")
			var grass_right := Color("#459622")
			var dirt_right := Color("#7c4c28")
			
			# 顶面草坪
			canvas.draw_colored_polygon(PackedVector2Array([p_top, p_right, p_mid, p_left]), top_c)
			
			# 侧面上部平齐草皮层 (28% 高度)
			var f_ratio: float = 0.28
			var pl_f := p_left + (p_left_bot - p_left) * f_ratio
			var pm_f := p_mid + (p_mid_bot - p_mid) * f_ratio
			var pr_f := p_right + (p_right_bot - p_right) * f_ratio
			
			canvas.draw_colored_polygon(PackedVector2Array([p_left, p_mid, pm_f, pl_f]), grass_left)
			canvas.draw_colored_polygon(PackedVector2Array([pl_f, pm_f, p_mid_bot, p_left_bot]), dirt_left)
			
			canvas.draw_colored_polygon(PackedVector2Array([p_mid, p_right, pr_f, pm_f]), grass_right)
			canvas.draw_colored_polygon(PackedVector2Array([pm_f, pr_f, p_right_bot, p_mid_bot]), dirt_right)
			
			# 泥土微体素细碎点缀
			canvas.draw_circle((pl_f + p_mid_bot) * 0.5 + Vector2(2, 2), 1.5, Color("#b07a4a"))
			canvas.draw_circle((pm_f + p_right_bot) * 0.5 + Vector2(-2, 1), 1.5, Color("#663c1e"))
		
		2: # 泥土：暖色调天然金褐泥土
			top_c = Color("#a87448")
			left_c = Color("#92623a")
			right_c = Color("#764d2a")
			canvas.draw_colored_polygon(PackedVector2Array([p_top, p_right, p_mid, p_left]), top_c)
			canvas.draw_colored_polygon(PackedVector2Array([p_left, p_mid, p_mid_bot, p_left_bot]), left_c)
			canvas.draw_colored_polygon(PackedVector2Array([p_mid, p_right, p_right_bot, p_mid_bot]), right_c)
			# 微细颗粒
			canvas.draw_circle((p_top + p_mid) * 0.5 + Vector2(-3, 0), 1.5, Color("#bc8858"))
			canvas.draw_circle((p_left + p_mid_bot) * 0.5 + Vector2(2, -1), 1.5, Color("#b07a4a"))
		
		3: # 原木：顶面年轮金黄木芯 + 侧面垂直树皮沟槽
			top_c = Color("#dab068")
			left_c = Color("#7e542c")
			right_c = Color("#5e3b1c")
			canvas.draw_colored_polygon(PackedVector2Array([p_top, p_right, p_mid, p_left]), top_c)
			# 顶面同心年轮木芯
			canvas.draw_circle((p_top + p_mid) * 0.5, w * 0.35, Color("#c89a50"))
			canvas.draw_circle((p_top + p_mid) * 0.5, w * 0.18, Color("#a87c3c"))
			
			canvas.draw_colored_polygon(PackedVector2Array([p_left, p_mid, p_mid_bot, p_left_bot]), left_c)
			canvas.draw_colored_polygon(PackedVector2Array([p_mid, p_right, p_right_bot, p_mid_bot]), right_c)
			# 树皮纵向木纹
			canvas.draw_line(p_left + (p_mid - p_left) * 0.35, p_left_bot + (p_mid_bot - p_left_bot) * 0.35, Color("#5e3a1a"), 1.2)
			canvas.draw_line(p_left + (p_mid - p_left) * 0.70, p_left_bot + (p_mid_bot - p_left_bot) * 0.70, Color("#5e3a1a"), 1.2)
			canvas.draw_line(p_mid + (p_right - p_mid) * 0.45, p_mid_bot + (p_right_bot - p_mid_bot) * 0.45, Color("#482b12"), 1.2)
		
		4: # 树叶：生机明艳苹果绿
			top_c = Color("#4ecc4a")
			left_c = Color("#3ba838")
			right_c = Color("#268028")
			canvas.draw_colored_polygon(PackedVector2Array([p_top, p_right, p_mid, p_left]), top_c)
			canvas.draw_colored_polygon(PackedVector2Array([p_left, p_mid, p_mid_bot, p_left_bot]), left_c)
			canvas.draw_colored_polygon(PackedVector2Array([p_mid, p_right, p_right_bot, p_mid_bot]), right_c)
		
		5: # 石头：明亮硬朗白灰花岗岩石
			top_c = Color("#c0ccd6")
			left_c = Color("#a0b0bc")
			right_c = Color("#7e909c")
			canvas.draw_colored_polygon(PackedVector2Array([p_top, p_right, p_mid, p_left]), top_c)
			canvas.draw_colored_polygon(PackedVector2Array([p_left, p_mid, p_mid_bot, p_left_bot]), left_c)
			canvas.draw_colored_polygon(PackedVector2Array([p_mid, p_right, p_right_bot, p_mid_bot]), right_c)
		
		6: # 沙子：阳光金米沙
			top_c = Color("#f6e8b4")
			left_c = Color("#e0cb88")
			right_c = Color("#c2aa66")
			canvas.draw_colored_polygon(PackedVector2Array([p_top, p_right, p_mid, p_left]), top_c)
			canvas.draw_colored_polygon(PackedVector2Array([p_left, p_mid, p_mid_bot, p_left_bot]), left_c)
			canvas.draw_colored_polygon(PackedVector2Array([p_mid, p_right, p_right_bot, p_mid_bot]), right_c)
		
		7: # 木板：金黄白桦木板拼装条
			top_c = Color("#e4bf86")
			left_c = Color("#c89f64")
			right_c = Color("#aa8248")
			canvas.draw_colored_polygon(PackedVector2Array([p_top, p_right, p_mid, p_left]), top_c)
			canvas.draw_colored_polygon(PackedVector2Array([p_left, p_mid, p_mid_bot, p_left_bot]), left_c)
			canvas.draw_colored_polygon(PackedVector2Array([p_mid, p_right, p_right_bot, p_mid_bot]), right_c)
			# 平行拼板接缝
			canvas.draw_line(p_left + (p_left_bot - p_left) * 0.5, p_mid + (p_mid_bot - p_mid) * 0.5, Color("#8c6436"), 1.2)
			canvas.draw_line(p_mid + (p_mid_bot - p_mid) * 0.5, p_right + (p_right_bot - p_right) * 0.5, Color("#765026"), 1.2)
		
		8: # 陶瓦：鲜活红陶烧结砖红
			top_c = Color("#e27e60")
			left_c = Color("#c66746")
			right_c = Color("#a44e32")
			canvas.draw_colored_polygon(PackedVector2Array([p_top, p_right, p_mid, p_left]), top_c)
			canvas.draw_colored_polygon(PackedVector2Array([p_left, p_mid, p_mid_bot, p_left_bot]), left_c)
			canvas.draw_colored_polygon(PackedVector2Array([p_mid, p_right, p_right_bot, p_mid_bot]), right_c)
		
		9: # 高纯生铁矿：素雅岩石底色内嵌金黄铜色反光金属块（基准方案 2.1 节 #C8A870）
			top_c = Color("#c0ccd6")
			left_c = Color("#a0b0bc")
			right_c = Color("#7e909c")
			canvas.draw_colored_polygon(PackedVector2Array([p_top, p_right, p_mid, p_left]), top_c)
			canvas.draw_colored_polygon(PackedVector2Array([p_left, p_mid, p_mid_bot, p_left_bot]), left_c)
			canvas.draw_colored_polygon(PackedVector2Array([p_mid, p_right, p_right_bot, p_mid_bot]), right_c)
			# 顶面生铁金属矿斑
			canvas.draw_circle((p_top + p_mid) * 0.5 + Vector2(-2, -1), 2.2, Color("#e6c888"))
			canvas.draw_circle((p_top + p_right) * 0.5 + Vector2(-3, 2), 1.8, Color("#c8a870"))
			# 侧面金属矿晶
			canvas.draw_circle((p_left + p_mid_bot) * 0.5 + Vector2(2, -2), 2.0, Color("#d4b070"))
			canvas.draw_circle((p_mid + p_right_bot) * 0.5 + Vector2(-2, 1), 2.2, Color("#ba9456"))
		
		10: # 煤矿石：素雅岩石底色内嵌墨黑反光动漫晶石
			top_c = Color("#c0ccd6")
			left_c = Color("#a0b0bc")
			right_c = Color("#7e909c")
			canvas.draw_colored_polygon(PackedVector2Array([p_top, p_right, p_mid, p_left]), top_c)
			canvas.draw_colored_polygon(PackedVector2Array([p_left, p_mid, p_mid_bot, p_left_bot]), left_c)
			canvas.draw_colored_polygon(PackedVector2Array([p_mid, p_right, p_right_bot, p_mid_bot]), right_c)
			# 顶面与侧面墨黑晶斑
			canvas.draw_circle((p_top + p_mid) * 0.5 + Vector2(-1, 0), 2.2, Color("#26292d"))
			canvas.draw_circle((p_top + p_mid) * 0.5 + Vector2(-1, 0), 1.0, Color("#555c66"))
			canvas.draw_circle((p_left + p_mid_bot) * 0.5 + Vector2(3, -1), 2.0, Color("#222528"))
			canvas.draw_circle((p_mid + p_right_bot) * 0.5 + Vector2(-3, 2), 2.0, Color("#1a1c1e"))
		
		11: # 金矿石：素雅岩石内嵌明亮灿金耀眼矿核
			top_c = Color("#c0ccd6")
			left_c = Color("#a0b0bc")
			right_c = Color("#7e909c")
			canvas.draw_colored_polygon(PackedVector2Array([p_top, p_right, p_mid, p_left]), top_c)
			canvas.draw_colored_polygon(PackedVector2Array([p_left, p_mid, p_mid_bot, p_left_bot]), left_c)
			canvas.draw_colored_polygon(PackedVector2Array([p_mid, p_right, p_right_bot, p_mid_bot]), right_c)
			# 灿金反光矿斑
			canvas.draw_circle((p_top + p_mid) * 0.5 + Vector2(-2, -1), 2.4, Color("#ffd84d"))
			canvas.draw_circle((p_top + p_right) * 0.5 + Vector2(-2, 1), 1.8, Color("#f5be24"))
			canvas.draw_circle((p_left + p_mid_bot) * 0.5 + Vector2(2, -2), 2.2, Color("#e6ab18"))
			canvas.draw_circle((p_mid + p_right_bot) * 0.5 + Vector2(-2, 0), 2.2, Color("#cca010"))
		
		12: # 生铁块：纯净金属方块，日系冷调银灰与工艺内倒角高光
			top_c = Color("#eef5fb")
			left_c = Color("#d0dce8")
			right_c = Color("#b2c2d2")
			canvas.draw_colored_polygon(PackedVector2Array([p_top, p_right, p_mid, p_left]), top_c)
			canvas.draw_colored_polygon(PackedVector2Array([p_left, p_mid, p_mid_bot, p_left_bot]), left_c)
			canvas.draw_colored_polygon(PackedVector2Array([p_mid, p_right, p_right_bot, p_mid_bot]), right_c)
			# 金属切角内高光轮廓
			var inset_top := PackedVector2Array([
				p_top + (p_mid - p_top) * 0.18,
				p_right + (p_left - p_right) * 0.18,
				p_mid + (p_top - p_mid) * 0.18,
				p_left + (p_right - p_left) * 0.18
			])
			canvas.draw_polyline(PackedVector2Array([inset_top[0], inset_top[1], inset_top[2], inset_top[3], inset_top[0]]), Color(1, 1, 1, 0.45), 1.0)
		
		13: # 鹅卵石：天然粗碎石面与动漫圆润石缝
			top_c = Color("#8a96a2")
			left_c = Color("#72808c")
			right_c = Color("#5a6874")
			canvas.draw_colored_polygon(PackedVector2Array([p_top, p_right, p_mid, p_left]), top_c)
			canvas.draw_colored_polygon(PackedVector2Array([p_left, p_mid, p_mid_bot, p_left_bot]), left_c)
			canvas.draw_colored_polygon(PackedVector2Array([p_mid, p_right, p_right_bot, p_mid_bot]), right_c)
			# 碎石拼嵌缝纹
			canvas.draw_line((p_top + p_left) * 0.5, (p_mid + p_right) * 0.5, Color("#48535d", 0.65), 1.1)
			canvas.draw_line(p_left + (p_left_bot - p_left) * 0.45, p_mid + (p_mid_bot - p_mid) * 0.55, Color("#3a434c", 0.6), 1.1)
			canvas.draw_line(p_mid + (p_mid_bot - p_mid) * 0.45, p_right + (p_right_bot - p_right) * 0.55, Color("#2c343c", 0.6), 1.1)
		
		14: # 石砖：规整切削建筑石砖与精致错缝
			top_c = Color("#b4c0cc")
			left_c = Color("#95a4b2")
			right_c = Color("#768492")
			canvas.draw_colored_polygon(PackedVector2Array([p_top, p_right, p_mid, p_left]), top_c)
			canvas.draw_colored_polygon(PackedVector2Array([p_left, p_mid, p_mid_bot, p_left_bot]), left_c)
			canvas.draw_colored_polygon(PackedVector2Array([p_mid, p_right, p_right_bot, p_mid_bot]), right_c)
			# 规整横竖错开砖缝
			canvas.draw_line(p_left + (p_left_bot - p_left) * 0.5, p_mid + (p_mid_bot - p_mid) * 0.5, Color("#525e6a", 0.7), 1.2)
			canvas.draw_line(p_mid + (p_mid_bot - p_mid) * 0.5, p_right + (p_right_bot - p_right) * 0.5, Color("#424d58", 0.7), 1.2)
			canvas.draw_line(p_left + (p_mid - p_left) * 0.5, p_left_bot + (p_mid_bot - p_left_bot) * 0.5, Color("#525e6a", 0.6), 1.0)
			canvas.draw_line(p_mid + (p_right - p_mid) * 0.5, p_mid_bot + (p_right_bot - p_mid_bot) * 0.5, Color("#424d58", 0.6), 1.0)
		
		15: # 粗糙花岗岩：暖淡粉红花岗岩底色（GDD 3.3 #B87B6A）
			top_c = Color("#cfa090")
			left_c = Color("#b68474")
			right_c = Color("#986858")
			canvas.draw_colored_polygon(PackedVector2Array([p_top, p_right, p_mid, p_left]), top_c)
			canvas.draw_colored_polygon(PackedVector2Array([p_left, p_mid, p_mid_bot, p_left_bot]), left_c)
			canvas.draw_colored_polygon(PackedVector2Array([p_mid, p_right, p_right_bot, p_mid_bot]), right_c)
			# 花岗岩深色长石斑
			canvas.draw_circle((p_top + p_mid) * 0.5 + Vector2(-2, 1), 1.6, Color("#804d3f"))
			canvas.draw_circle((p_left + p_mid_bot) * 0.5 + Vector2(2, -1), 1.5, Color("#754436"))
		
		16: # 纯净玻璃：通透浅天青半透明方块与高光反光条
			top_c = Color(0.72, 0.90, 1.0, 0.75)
			left_c = Color(0.60, 0.82, 0.96, 0.75)
			right_c = Color(0.50, 0.74, 0.90, 0.75)
			canvas.draw_colored_polygon(PackedVector2Array([p_top, p_right, p_mid, p_left]), top_c)
			canvas.draw_colored_polygon(PackedVector2Array([p_left, p_mid, p_mid_bot, p_left_bot]), left_c)
			canvas.draw_colored_polygon(PackedVector2Array([p_mid, p_right, p_right_bot, p_mid_bot]), right_c)
			# 晶莹高光对角切线
			canvas.draw_line(p_left + Vector2(4, 2), p_mid + Vector2(-2, -3), Color(1, 1, 1, 0.85), 1.4)
			canvas.draw_line(p_mid + (p_right - p_mid) * 0.35 + (p_mid_bot - p_mid) * 0.15, p_mid + (p_right - p_mid) * 0.75 + (p_mid_bot - p_mid) * 0.75, Color(1, 1, 1, 0.75), 1.4)
		
		17: # 砂岩：暖金沙沉积层叠岩
			top_c = Color("#ebd89e")
			left_c = Color("#d2be84")
			right_c = Color("#b4a066")
			canvas.draw_colored_polygon(PackedVector2Array([p_top, p_right, p_mid, p_left]), top_c)
			canvas.draw_colored_polygon(PackedVector2Array([p_left, p_mid, p_mid_bot, p_left_bot]), left_c)
			canvas.draw_colored_polygon(PackedVector2Array([p_mid, p_right, p_right_bot, p_mid_bot]), right_c)
			# 水平沉积层理
			canvas.draw_line(p_left + (p_left_bot - p_left) * 0.35, p_mid + (p_mid_bot - p_mid) * 0.35, Color("#8c7a48", 0.55), 1.0)
			canvas.draw_line(p_left + (p_left_bot - p_left) * 0.70, p_mid + (p_mid_bot - p_mid) * 0.70, Color("#8c7a48", 0.55), 1.0)
			canvas.draw_line(p_mid + (p_right_bot - p_mid) * 0.35, p_right + (p_right_bot - p_right) * 0.35, Color("#746436", 0.55), 1.0)
		
		18: # 高山雪块：纯白天光漫反射雪色
			top_c = Color("#ffffff")
			left_c = Color("#e5f0f8")
			right_c = Color("#cce0ee")
			canvas.draw_colored_polygon(PackedVector2Array([p_top, p_right, p_mid, p_left]), top_c)
			canvas.draw_colored_polygon(PackedVector2Array([p_left, p_mid, p_mid_bot, p_left_bot]), left_c)
			canvas.draw_colored_polygon(PackedVector2Array([p_mid, p_right, p_right_bot, p_mid_bot]), right_c)
			# 雪面纯净微蓝光晕
			canvas.draw_circle((p_top + p_mid) * 0.5 + Vector2(1, -1), 1.8, Color(0.85, 0.95, 1.0, 0.8))
		
		19: # 黑曜石：深邃幽紫墨色（GDD 3.3 #2B243B）与暗紫镜面反光
			top_c = Color("#3d3352")
			left_c = Color("#2c233d")
			right_c = Color("#1e162d")
			canvas.draw_colored_polygon(PackedVector2Array([p_top, p_right, p_mid, p_left]), top_c)
			canvas.draw_colored_polygon(PackedVector2Array([p_left, p_mid, p_mid_bot, p_left_bot]), left_c)
			canvas.draw_colored_polygon(PackedVector2Array([p_mid, p_right, p_right_bot, p_mid_bot]), right_c)
			# 幽紫反光切面
			canvas.draw_line(p_left + (p_top - p_left) * 0.5, p_mid + (p_right - p_mid) * 0.5, Color("#6d588c", 0.7), 1.1)
			canvas.draw_line(p_left + (p_left_bot - p_left) * 0.4, p_mid_bot, Color("#554270", 0.6), 1.1)
		
		20: # 工作台：浅暖实木操作台面 + 工坊箱体与工具简笔画
			top_c = Color("#e4bf86") # 台面木拼花
			left_c = Color("#9e6b42") # 箱体
			right_c = Color("#7f512c")
			canvas.draw_colored_polygon(PackedVector2Array([p_top, p_right, p_mid, p_left]), top_c)
			# 台面四格木工拼接线
			canvas.draw_line((p_top + p_mid) * 0.5, (p_left + p_right) * 0.5, Color("#8c6232"), 1.1)
			canvas.draw_line((p_top + p_left) * 0.5, (p_mid + p_right) * 0.5, Color("#8c6232"), 1.1)
			
			canvas.draw_colored_polygon(PackedVector2Array([p_left, p_mid, p_mid_bot, p_left_bot]), left_c)
			canvas.draw_colored_polygon(PackedVector2Array([p_mid, p_right, p_right_bot, p_mid_bot]), right_c)
			# 侧面微型工具剪影（小铁锤与小锯子手绘）
			var l_mid_pos: Vector2 = (p_left + p_mid_bot) * 0.5
			canvas.draw_line(l_mid_pos + Vector2(-3, -2), l_mid_pos + Vector2(3, 3), Color("#3e2612"), 1.4)
			canvas.draw_line(l_mid_pos + Vector2(1, -3), l_mid_pos + Vector2(4, 0), Color("#d4dce4"), 1.6)
		
		_: # 未指定方块回退至基准着色
			top_c = BlockCatalog.color(id).lightened(0.18)
			left_c = BlockCatalog.color(id).darkened(0.05)
			right_c = BlockCatalog.color(id).darkened(0.14)
			canvas.draw_colored_polygon(PackedVector2Array([p_top, p_right, p_mid, p_left]), top_c)
			canvas.draw_colored_polygon(PackedVector2Array([p_left, p_mid, p_mid_bot, p_left_bot]), left_c)
			canvas.draw_colored_polygon(PackedVector2Array([p_mid, p_right, p_right_bot, p_mid_bot]), right_c)
	
	# 3D 体素外轮廓与内棱脊线（清晰分明手绘质感）
	var outline_c := Color(0.18, 0.12, 0.08, 0.70)
	var ridge_c := Color(0.24, 0.16, 0.10, 0.55)
	canvas.draw_polyline(PackedVector2Array([p_top, p_right, p_right_bot, p_mid_bot, p_left_bot, p_left, p_top]), outline_c, 1.4, true)
	canvas.draw_line(p_mid, p_top, ridge_c, 1.1)
	canvas.draw_line(p_mid, p_left, ridge_c, 1.1)
	canvas.draw_line(p_mid, p_right, ridge_c, 1.1)
	canvas.draw_line(p_mid, p_mid_bot, outline_c, 1.3)


# -----------------------------------------------------------------------------
# 通用 3D 侧上方立方体组件绘制辅助函数
# -----------------------------------------------------------------------------

static func _draw_isometric_box(canvas: Control, center: Vector2, w: float, h: float, d: float, box_color: Color, outline_alpha: float = 0.45) -> void:
	var cy: float = center.y - d * 0.16
	var p_top := Vector2(center.x, cy - h)
	var p_right := Vector2(center.x + w, cy)
	var p_mid := Vector2(center.x, cy + h)
	var p_left := Vector2(center.x - w, cy)
	
	var p_left_bot := Vector2(center.x - w, cy + d)
	var p_mid_bot := Vector2(center.x, cy + h + d)
	var p_right_bot := Vector2(center.x + w, cy + d)
	
	canvas.draw_colored_polygon(PackedVector2Array([p_top, p_right, p_mid, p_left]), box_color.lightened(0.18))
	canvas.draw_colored_polygon(PackedVector2Array([p_left, p_mid, p_mid_bot, p_left_bot]), box_color.darkened(0.05))
	canvas.draw_colored_polygon(PackedVector2Array([p_mid, p_right, p_right_bot, p_mid_bot]), box_color.darkened(0.14))
	
	if outline_alpha > 0.0:
		var outline_c := Color(0.15, 0.10, 0.06, outline_alpha)
		canvas.draw_polyline(PackedVector2Array([p_top, p_right, p_right_bot, p_mid_bot, p_left_bot, p_left, p_top]), outline_c, 1.2, true)
		canvas.draw_line(p_mid, p_top, outline_c, 1.0)
		canvas.draw_line(p_mid, p_left, outline_c, 1.0)
		canvas.draw_line(p_mid, p_right, outline_c, 1.0)
		canvas.draw_line(p_mid, p_mid_bot, outline_c, 1.2)


# -----------------------------------------------------------------------------
# 原装备 3D 侧上方视角立体显示 (ID 101 ~ 107)
# -----------------------------------------------------------------------------

static func _draw_real_equipment(canvas: Control, id: int, origin: Vector2, extent: float) -> void:
	var c_steel: Color = color(id)
	
	match 101 + equipment_slot(id):
		101: # 铁头盔：侧上方视角 3D 方块头盔
			_draw_isometric_box(canvas, origin + Vector2(0, -extent * 0.12), extent * 0.34, extent * 0.18, extent * 0.14, c_steel)
			_draw_isometric_box(canvas, origin + Vector2(-extent * 0.20, extent * 0.10), extent * 0.10, extent * 0.12, extent * 0.24, c_steel)
			_draw_isometric_box(canvas, origin + Vector2(extent * 0.20, extent * 0.10), extent * 0.10, extent * 0.12, extent * 0.24, c_steel)
		
		102: # 铁盔甲：侧上方视角 3D 胸甲与护肩
			_draw_isometric_box(canvas, origin + Vector2(-extent * 0.28, -extent * 0.08), extent * 0.12, extent * 0.12, extent * 0.18, c_steel)
			_draw_isometric_box(canvas, origin + Vector2(extent * 0.28, -extent * 0.08), extent * 0.12, extent * 0.12, extent * 0.18, c_steel)
			_draw_isometric_box(canvas, origin + Vector2(0, extent * 0.06), extent * 0.26, extent * 0.16, extent * 0.38, c_steel)
		
		103: # 铁裤甲：侧上方视角 3D 护腿与护膝
			var gap: float = extent * 0.12
			_draw_isometric_box(canvas, origin + Vector2(-gap, 0), extent * 0.12, extent * 0.12, extent * 0.44, c_steel)
			_draw_isometric_box(canvas, origin + Vector2(gap, 0), extent * 0.12, extent * 0.12, extent * 0.44, c_steel)
			_draw_isometric_box(canvas, origin + Vector2(-gap, extent * 0.08), extent * 0.13, extent * 0.08, extent * 0.12, c_steel.lightened(0.08))
			_draw_isometric_box(canvas, origin + Vector2(gap, extent * 0.08), extent * 0.13, extent * 0.08, extent * 0.12, c_steel.lightened(0.08))
		
		104: # 铁鞋：侧上方视角 3D 方块战靴
			var gap: float = extent * 0.14
			_draw_isometric_box(canvas, origin + Vector2(-gap, 0), extent * 0.14, extent * 0.14, extent * 0.26, c_steel)
			_draw_isometric_box(canvas, origin + Vector2(gap, 0), extent * 0.14, extent * 0.14, extent * 0.26, c_steel)
		
		105: # 铁手套：侧上方视角 3D 方块护手
			var gap: float = extent * 0.18
			_draw_isometric_box(canvas, origin + Vector2(-gap, 0), extent * 0.14, extent * 0.14, extent * 0.28, c_steel)
			_draw_isometric_box(canvas, origin + Vector2(gap, 0), extent * 0.14, extent * 0.14, extent * 0.28, c_steel)
		
		106: # 旅人披风：侧上方视角 3D 斗篷
			_draw_isometric_box(canvas, origin + Vector2(0, -extent * 0.24), extent * 0.22, extent * 0.10, extent * 0.08, Color("e3b768"))
			_draw_isometric_box(canvas, origin + Vector2(0, extent * 0.08), extent * 0.28, extent * 0.16, extent * 0.48, color(id))
		
		107: # 皮腰带：侧上方视角 3D 皮带与金属扣
			_draw_isometric_box(canvas, origin, extent * 0.38, extent * 0.16, extent * 0.18, color(id))
			_draw_isometric_box(canvas, origin + Vector2(0, extent * 0.02), extent * 0.14, extent * 0.09, extent * 0.16, Color("d5b46b"))


# -----------------------------------------------------------------------------
# 原书本文档 3D 侧上方视角立体显示 (ID 108 ~ 109)
# -----------------------------------------------------------------------------

static func _draw_real_document(canvas: Control, id: int, origin: Vector2, extent: float) -> void:
	if id == 108:
		# 笔记本：侧上方视角 3D 皮面书籍
		_draw_isometric_box(canvas, origin + Vector2(0, extent * 0.04), extent * 0.34, extent * 0.22, extent * 0.16, Color("fff2cd"))
		_draw_isometric_box(canvas, origin + Vector2(0, -extent * 0.04), extent * 0.35, extent * 0.23, extent * 0.08, Color("bd8155"))
		_draw_isometric_box(canvas, origin + Vector2(-extent * 0.22, -extent * 0.03), extent * 0.07, extent * 0.22, extent * 0.09, Color("e3b768"))
	elif id == 109:
		# 蓝色图纸：侧上方视角 3D 天青色工程图纸台
		var w: float = extent * 0.38
		var h: float = extent * 0.24
		var d: float = extent * 0.08
		var cy: float = origin.y - d * 0.20
		var p_top := Vector2(origin.x, cy - h)
		var p_right := Vector2(origin.x + w, cy)
		var p_mid := Vector2(origin.x, cy + h)
		var p_left := Vector2(origin.x - w, cy)
		
		var p_left_bot := Vector2(origin.x - w, cy + d)
		var p_mid_bot := Vector2(origin.x, cy + h + d)
		var p_right_bot := Vector2(origin.x + w, cy + d)
		
		var blue_c := Color("397db3")
		canvas.draw_colored_polygon(PackedVector2Array([p_top, p_right, p_mid, p_left]), blue_c.lightened(0.12))
		canvas.draw_colored_polygon(PackedVector2Array([p_left, p_mid, p_mid_bot, p_left_bot]), blue_c.darkened(0.08))
		canvas.draw_colored_polygon(PackedVector2Array([p_mid, p_right, p_right_bot, p_mid_bot]), blue_c.darkened(0.22))
		
		# 顶面正交设计网格线
		var grid_c := Color("89bad9", 0.65)
		for i in range(1, 4):
			var t: float = float(i) / 4.0
			canvas.draw_line(p_top + (p_left - p_top) * t, p_right + (p_mid - p_right) * t, grid_c, 1.0)
			canvas.draw_line(p_top + (p_right - p_top) * t, p_left + (p_mid - p_left) * t, grid_c, 1.0)
		
		canvas.draw_circle((p_top + p_mid) * 0.5, 2.0, Color.WHITE)
		
		var outline_c := Color(0.12, 0.20, 0.35, 0.45)
		canvas.draw_polyline(PackedVector2Array([p_top, p_right, p_right_bot, p_mid_bot, p_left_bot, p_left, p_top]), outline_c, 1.1, true)
		canvas.draw_line(p_mid, p_top, outline_c, 1.0)
		canvas.draw_line(p_mid, p_left, outline_c, 1.0)
		canvas.draw_line(p_mid, p_right, outline_c, 1.0)
		canvas.draw_line(p_mid, p_mid_bot, outline_c, 1.1)


# -----------------------------------------------------------------------------
# 基础工具 2D 矢量图标绘制 (ID 201 ~ 209)
# -----------------------------------------------------------------------------

static func _draw_real_tool(canvas: Control, id: int, origin: Vector2, extent: float) -> void:
	var type: String = tool_type(id)
	var material: String = tool_material(id)
	
	# 材质基础色彩与高光
	var head_color := Color("#c89f64") # 默认木制
	var highlight_color := Color("#dfbc84")
	var dark_color := Color("#8c6436")
	
	match material:
		"stone":
			head_color = Color("#9aa6b2")
			highlight_color = Color("#c0ccd6")
			dark_color = Color("#6c7884")
		"iron":
			head_color = Color("#d8e6f2")
			highlight_color = Color("#ffffff")
			dark_color = Color("#8ea6ba")
	
	# 手柄木质长杆（自左下至右上倾斜 45°）
	var handle_c := Color("#7e4e2a")
	var handle_hi := Color("#a2683a")
	var p_start := origin + Vector2(-extent * 0.28, extent * 0.28)
	var p_end := origin + Vector2(extent * 0.16, -extent * 0.16)
	
	# 手柄阴影与主干
	canvas.draw_line(p_start + Vector2(1, 1), p_end + Vector2(1, 1), Color(0.15, 0.1, 0.05, 0.45), 3.2)
	canvas.draw_line(p_start, p_end, handle_c, 2.8)
	canvas.draw_line(p_start + Vector2(-0.5, -0.5), p_end + Vector2(-0.5, -0.5), handle_hi, 1.2)
	
	# 头部连接点
	var head_center := p_end + Vector2(extent * 0.04, -extent * 0.04)
	
	match type:
		"pickaxe":
			# 镐：弯月双向尖角横跨手柄顶部
			var p_top_tip := head_center + Vector2(-extent * 0.26, -extent * 0.08)
			var p_top_mid := head_center + Vector2(-extent * 0.05, -extent * 0.22)
			var p_top_peak := head_center + Vector2(extent * 0.14, -extent * 0.20)
			var p_bot_tip := head_center + Vector2(extent * 0.24, 0.0)
			var p_inner := head_center + Vector2(extent * 0.04, -extent * 0.06)
			
			var poly := PackedVector2Array([p_top_tip, p_top_mid, p_top_peak, p_bot_tip, p_inner])
			canvas.draw_colored_polygon(poly, head_color)
			canvas.draw_polyline(poly, dark_color, 1.2, true)
			# 镐尖与顶部锋刃高光
			canvas.draw_line(p_top_tip, p_top_mid, highlight_color, 1.4)
			canvas.draw_line(p_top_mid, p_top_peak, highlight_color, 1.4)
			
		"axe":
			# 斧：厚重侧向斧面与斧背
			var p0 := head_center + Vector2(-extent * 0.18, -extent * 0.18)
			var p1 := head_center + Vector2(extent * 0.16, -extent * 0.20)
			var p2 := head_center + Vector2(extent * 0.22, -extent * 0.02)
			var p3 := head_center + Vector2(extent * 0.02, extent * 0.12)
			var p4 := head_center + Vector2(-extent * 0.12, 0.0)
			
			var poly := PackedVector2Array([p0, p1, p2, p3, p4])
			canvas.draw_colored_polygon(poly, head_color)
			canvas.draw_polyline(poly, dark_color, 1.3, true)
			# 锋刃高光边
			canvas.draw_line(p1, p2, highlight_color, 1.6)
			canvas.draw_line(p2, p3, highlight_color, 1.6)
			
		"shovel":
			# 锹：前端圆弧平铲
			var s_center := head_center + Vector2(extent * 0.08, -extent * 0.08)
			var r: float = extent * 0.18
			var p_tip := s_center + Vector2(r * 0.7, -r * 0.7)
			var p_l := s_center + Vector2(-r * 0.6, -r * 0.4)
			var p_r := s_center + Vector2(r * 0.4, r * 0.6)
			var p_b := head_center
			
			var poly := PackedVector2Array([p_b, p_l, p_tip, p_r])
			canvas.draw_colored_polygon(poly, head_color)
			canvas.draw_polyline(poly, dark_color, 1.3, true)
			# 铲沿高光
			canvas.draw_line(p_l, p_tip, highlight_color, 1.5)
			canvas.draw_line(p_tip, p_r, highlight_color, 1.5)


# -----------------------------------------------------------------------------
# 多元化特色近战武器 2D 矢量图标绘制 (ID 301 ~ 305)
# -----------------------------------------------------------------------------

static func _draw_real_weapon(canvas: Control, id: int, origin: Vector2, extent: float) -> void:
	var p_start := origin + Vector2(-extent * 0.30, extent * 0.30)
	var p_end := origin + Vector2(extent * 0.28, -extent * 0.28)
	var dir := (p_end - p_start).normalized()
	var normal := Vector2(-dir.y, dir.x)
	
	match id:
		301: # 原木轻短剑
			var hilt_c := Color("#5a3418")
			var guard_c := Color("#8c6436")
			var blade_c := Color("#c89f64")
			var blade_hi := Color("#e2bf8a")
			# 剑柄
			var p_guard := p_start + dir * (extent * 0.22)
			canvas.draw_line(p_start, p_guard, hilt_c, 3.5)
			# 十字护手
			canvas.draw_line(p_guard - normal * (extent * 0.14), p_guard + normal * (extent * 0.14), guard_c, 3.2)
			# 短剑身
			var p_tip := p_start + dir * (extent * 0.65)
			var b_poly := PackedVector2Array([
				p_guard - normal * 3.0,
				p_tip - dir * 5.0 - normal * 3.0,
				p_tip,
				p_tip - dir * 5.0 + normal * 3.0,
				p_guard + normal * 3.0
			])
			canvas.draw_colored_polygon(b_poly, blade_c)
			canvas.draw_line(p_guard, p_tip, blade_hi, 1.2)
			
		302: # 砥石破山斧（双手重战斧）
			var handle_c := Color("#4d321d")
			var stone_c := Color("#8a96a0")
			var stone_dark := Color("#58646e")
			var edge_c := Color("#c8d6e2")
			# 粗重斧柄
			canvas.draw_line(p_start, p_end, handle_c, 3.8)
			var p_head := p_end - dir * (extent * 0.15)
			# 双面大月牙石质斧刃
			var a1 := p_head + normal * (extent * 0.26) + dir * (extent * 0.08)
			var a2 := p_head + normal * (extent * 0.28) - dir * (extent * 0.12)
			var a3 := p_head - normal * (extent * 0.15) - dir * (extent * 0.08)
			var a4 := p_head - normal * (extent * 0.14) + dir * (extent * 0.10)
			var axe_poly := PackedVector2Array([a1, a2, p_head - dir * 6.0, a3, a4, p_head + dir * 6.0])
			canvas.draw_colored_polygon(axe_poly, stone_c)
			canvas.draw_polyline(axe_poly, stone_dark, 1.3, true)
			canvas.draw_line(a1, a2, edge_c, 2.0)
			canvas.draw_line(a3, a4, edge_c, 1.8)
			
		303: # 精炼铁长剑
			var steel_c := Color("#e8f2fc")
			var steel_dark := Color("#8ba2b8")
			var gold_guard := Color("#e6b422")
			var p_guard := p_start + dir * (extent * 0.20)
			# 配重球与剑柄
			canvas.draw_circle(p_start, 2.8, gold_guard)
			canvas.draw_line(p_start, p_guard, Color("#2b2c30"), 3.2)
			# 弯弧骑士剑格
			canvas.draw_line(p_guard - normal * (extent * 0.18), p_guard + normal * (extent * 0.18), gold_guard, 3.2)
			# 锋锐双刃长剑身
			var p_tip := p_start + dir * (extent * 0.78)
			var blade_poly := PackedVector2Array([
				p_guard - normal * 3.5,
				p_tip - dir * 8.0 - normal * 2.5,
				p_tip,
				p_tip - dir * 8.0 + normal * 2.5,
				p_guard + normal * 3.5
			])
			canvas.draw_colored_polygon(blade_poly, steel_c)
			canvas.draw_polyline(blade_poly, steel_dark, 1.1, true)
			# 中线剑脊高光
			canvas.draw_line(p_guard, p_tip - dir * 3.0, Color.WHITE, 1.3)
			
		304: # 灵蕴金晶细剑（刺剑）
			var gold_c := Color("#ffea75")
			var gold_hi := Color("#ffffff")
			var p_guard := p_start + dir * (extent * 0.22)
			canvas.draw_line(p_start, p_guard, Color("#7a5214"), 2.4)
			# 优雅圆弧笼手护盾
			canvas.draw_arc(p_guard, extent * 0.14, -PI * 0.5, PI * 0.5, 8, gold_c, 2.2)
			# 极细长针剑刃
			var p_tip := p_start + dir * (extent * 0.82)
			canvas.draw_line(p_guard, p_tip, gold_c, 2.2)
			canvas.draw_line(p_guard + dir * 4.0, p_tip, gold_hi, 1.2)
			# 剑尖魔力闪烁点
			canvas.draw_circle(p_tip, 2.0, Color("#fff4b8"))
			
		305: # 暗渊黑曜石巨剑
			var obs_base := Color("#191224")
			var obs_purple := Color("#6c349a")
			var obs_glow := Color("#b968f8")
			var p_guard := p_start + dir * (extent * 0.18)
			# 加长双手剑柄
			canvas.draw_line(p_start, p_guard, Color("#100c18"), 4.0)
			# 宽阔黑曜石剑格
			canvas.draw_line(p_guard - normal * (extent * 0.22), p_guard + normal * (extent * 0.22), obs_purple, 4.0)
			# 沉重阔刃巨剑
			var p_tip := p_start + dir * (extent * 0.80)
			var giant_poly := PackedVector2Array([
				p_guard - normal * 6.5,
				p_tip - dir * 10.0 - normal * 5.5,
				p_tip,
				p_tip - dir * 10.0 + normal * 5.5,
				p_guard + normal * 6.5
			])
			canvas.draw_colored_polygon(giant_poly, obs_base)
			canvas.draw_polyline(giant_poly, obs_purple, 1.6, true)
			# 晶核破损紫芒刻纹
			canvas.draw_line(p_guard + dir * 6.0, p_tip - dir * 10.0, obs_glow, 1.6)



extends RefCounted

## 方块名称检索
static func title(id: int) -> String:
	match id:
		1: return "草方块"
		2: return "泥土"
		3: return "原木"
		4: return "树叶"
		5: return "石头"
		6: return "沙子"
		7: return "木板"
		8: return "陶瓦"
		9: return "高纯生铁矿"
		10: return "煤矿石"
		11: return "金矿石"
		12: return "生铁块"
		13: return "鹅卵石"
		14: return "石砖"
		15: return "粗糙花岗岩"
		16: return "纯净玻璃"
		17: return "砂岩"
		18: return "高山雪块"
		19: return "黑曜石"
		20: return "工作台"
		_: return "空气"


## 方块基准动漫色彩（严格依照规划基准方案与日系纯净手绘色谱）
static func color(id: int) -> Color:
	match id:
		1: return Color("709d5c") # 柔和的自然草绿
		2: return Color("8d5a38") # 肥沃泥土（温润手绘土褐）
		3: return Color("6d4a2b") # 冷杉原木（深邃日系树皮木纹）
		4: return Color("59894f") # 自然树冠绿
		5: return Color("8a96a0") # 素雅岩石（偏蓝灰纯净石材）
		6: return Color("c8b58e") # 米棕色沙子
		7: return Color("c99559") # 原木木板（温润木纹拼板）
		8: return Color("c86f50") # 陶瓦（古典红陶砖瓦色）
		9: return Color("c8a870") # 高纯生铁矿（金黄铜色反光金属矿斑，基准方案2.1节）
		10: return Color("3a3e45") # 煤矿石（素雅岩石内嵌墨黑晶核）
		11: return Color("e6b422") # 金矿石（素雅岩石内嵌明亮耀眼金晶）
		12: return Color("d0dce5") # 生铁块（纯净高光冷调金属方块）
		13: return Color("77828c") # 鹅卵石（天然碎石切削色）
		14: return Color("95a1ab") # 石砖（规整打磨建筑石砖色）
		15: return Color("b87b6a") # 粗糙花岗岩（暖淡粉红花岗岩，GDD 3.3）
		16: return Color("a6dcf2") # 纯净玻璃（清澈通透动漫玻璃天青色）
		17: return Color("bca67b") # 温和的沉积砂岩色
		18: return Color("ecf4f8") # 高山雪块（纯白天光漫反射雪色）
		19: return Color("2b243b") # 黑曜石（深邃幽紫墨色极硬晶体，GDD 3.3）
		20: return Color("9e6b42") # 工作台（工坊实木箱体色）
		_: return Color.TRANSPARENT


## 方块顶面专属色彩（如原木横截面年轮、工作台台面等）
static func top_color(id: int) -> Color:
	match id:
		1: return color(1)
		3: return Color("b88b58") # 原木年轮横截面（基准方案 2.1 节 #B88B58）
		20: return Color("c89f64") # 工作台顶面为浅金实木操作台面
		_: return color(id)


## 是否具备特殊的顶面独立色彩材质
static func has_special_top(id: int) -> bool:
	return id == 1 or id == 3 or id == 20


## 徒手挖掘基础耗时（秒，严格遵循策划基准方案与手感参数）
static func mine_time(id: int) -> float:
	match id:
		1: return 0.35 # 草皮
		2: return 0.35 # 泥土
		3: return 0.70 # 原木
		4: return 0.10 # 树叶（轻击即碎）
		5: return 1.10 # 岩石
		6: return 0.25 # 沙子
		7: return 0.60 # 木板
		8: return 0.75 # 陶瓦
		9: return 1.60 # 高纯生铁矿（硬质矿脉）
		10: return 1.30 # 煤矿石
		11: return 1.80 # 金矿石（致密矿核）
		12: return 2.00 # 生铁块（高纯金属）
		13: return 1.00 # 鹅卵石
		14: return 1.10 # 石砖
		15: return 1.20 # 粗糙花岗岩
		16: return 0.15 # 纯净玻璃（极易击破）
		17: return 0.70 # 砂岩
		18: return 0.20 # 高山雪块
		19: return 3.50 # 黑曜石（极高硬度抗冲击晶体）
		20: return 0.70 # 工作台
		_: return 0.0


## 方块适性挖掘工具类型（pickaxe: 镐, axe: 斧, shovel: 锹, "": 任意）
static func effective_tool(id: int) -> String:
	match id:
		5, 8, 9, 10, 11, 12, 13, 14, 15, 17, 19:
			return "pickaxe"
		3, 4, 7, 20:
			return "axe"
		1, 2, 6, 18:
			return "shovel"
		_:
			return ""


## 方块破坏后的标准掉落物（默认掉落自身）
static func drop_id(id: int) -> int:
	return id


## 方块破坏后的掉落物数量
static func drop_count(id: int) -> int:
	return 1 if id > 0 else 0


## 获取当前所有注册实装的方块 ID 列表
static func ids() -> Array[int]:
	return [
		1, 2, 3, 4, 5, 6, 7, 8,
		9, 10, 11, 12, 13, 14, 15, 16,
		17, 18, 19, 20
	]


## 检查是否为有效方块 ID
static func is_valid_block(id: int) -> bool:
	return id >= 1 and id <= 20

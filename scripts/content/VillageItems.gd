extends RefCounted

const FACILITIES: Array[int] = [501, 502, 503, 504, 505, 506, 507, 508, 509]
const SUPPLIES: Array[int] = [601, 602, 603, 604, 605, 606, 607, 608, 609, 610]
const NAMES := {501: "储物箱", 502: "熔炉", 503: "木床", 504: "木椅", 505: "提灯", 506: "木桶", 507: "种植箱", 508: "井台", 509: "蓝图工作台", 601: "木棍", 602: "铁锭", 603: "小麦种子", 604: "小麦", 605: "面包", 606: "苹果", 607: "木炭", 608: "金锭", 609: "空木桶", 610: "水桶"}
const KINDS := {501: "chest", 502: "furnace", 503: "bed", 504: "chair", 505: "lamp", 506: "barrel", 507: "crop", 508: "well", 509: "workbench"}
const RECIPES := {
	"7": {"id": 601, "count": 4}, "4": {"id": 603, "count": 2},
	"5": {"id": 13, "count": 1},
	"601,601,602": {"id": 207, "count": 1}, "601,602,602": {"id": 208, "count": 1}, "601,602": {"id": 209, "count": 1},
	"602,602,602": {"id": 101, "count": 1}, "4,602,602": {"id": 102, "count": 1},
	"7,7,601": {"id": 501, "count": 1}, "5,13,601": {"id": 502, "count": 1},
	"4,7,601": {"id": 503, "count": 1}, "7,601,601": {"id": 504, "count": 1},
	"10,16,601": {"id": 505, "count": 2}, "3,7,601": {"id": 506, "count": 1},
	"2,7,601": {"id": 507, "count": 1}, "5,13,13": {"id": 508, "count": 1},
	"7,20,601": {"id": 509, "count": 1}, "3,601,601": {"id": 609, "count": 1}
}
const SMELTING := {9: {"id": 602, "count": 2, "seconds": 8.0}, 11: {"id": 608, "count": 2, "seconds": 10.0}, 6: {"id": 16, "count": 1, "seconds": 6.0}, 3: {"id": 607, "count": 2, "seconds": 6.0}, 604: {"id": 605, "count": 1, "seconds": 5.0}}
const FUELS := {10: 8, 607: 8, 3: 2, 7: 1, 601: 1}

static func food_health(id: int) -> float:
	return 28.0 if id == 605 else (12.0 if id == 606 else 0.0)

static func size(id: int) -> Vector3:
	match id:
		503: return Vector3(0.95, 0.65, 1.85)
		504: return Vector3(0.65, 0.95, 0.65)
		505: return Vector3(0.35, 0.65, 0.35)
		507: return Vector3(0.95, 0.85, 0.95)
		508: return Vector3(1.5, 1.7, 1.5)
		509: return Vector3(0.95, 0.9, 0.95)
	return Vector3(0.9, 0.85, 0.9)

static func description(id: int) -> String:
	match id:
		501, 506: return "可存放与取回物品，内容随世界保存。拆除前请取出所有物品。"
		502: return "投入原料和燃料加工铁锭、金锭、玻璃、木炭与面包；加工进度随世界保存。"
		503: return "休息恢复生命，并把附近安全位置设为当前世界的返回点。"
		504: return "可坐下休息，使用起身操作恢复行动。"
		505: return "可开关的暖色照明，摆放位置与开关状态随世界保存。"
		507: return "放入小麦种子种植，浇水加快生长，成熟后可收获小麦和种子。"
		508: return "可用空木桶取水，水桶用于浇灌种植箱。"
		509: return "设计与制作装备、工具、武器和生活设施；按蓝图实际体积计算用料。"
		601: return "木板加工得到的基础材料，可制作生活设施。"
		602, 608: return "由对应矿石冶炼得到，可用于工具、装备与交易。"
		603: return "可在种植箱播种，也可由树叶整理获得。"
		604: return "成熟小麦，可在熔炉中烘烤成面包或用于交易。"
		605, 606: return "食用可恢复生命。"
		607: return "木材烧制的燃料。"
		609, 610: return "在井台取水，将水带到种植箱浇灌后保留空桶。"
	return "村落生活物品。"

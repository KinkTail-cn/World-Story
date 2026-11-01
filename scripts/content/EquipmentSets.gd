extends RefCounted

const STYLES: Array[String] = ["ranger", "knight", "mage"]
const ALL_IDS: Array[int] = [
	101, 102, 103, 104, 105, 106, 107,
	401, 402, 403, 404, 405, 406, 407,
	411, 412, 413, 414, 415, 416, 417,
	421, 422, 423, 424, 425, 426, 427
]
const STARTS := {"basic": 101, "ranger": 401, "knight": 411, "mage": 421}
const TITLES := {"basic": "基础装备", "ranger": "林地游侠", "knight": "曙光骑士", "mage": "星辉法师"}
const NAMES := {
	"ranger": ["林地兜帽", "林地猎装", "林地绑腿", "林地行靴", "林地护腕", "林地短披风", "林地腰带"],
	"knight": ["曙光翼盔", "曙光胸甲", "曙光腿甲", "曙光战靴", "曙光护手", "曙光战旗披风", "曙光腰带"],
	"mage": ["星辉尖帽", "星辉法袍", "星辉长裤", "星辉短靴", "星辉手套", "星辉星纹披风", "星辉束带"]
}
const PALETTES := {
	"ranger": {"main": Color("6d8b55"), "dark": Color("4b6142"), "trim": Color("c3ac78"), "leather": Color("916b48"), "cloth": Color("668252"), "gem": Color("afbf86")},
	"knight": {"main": Color("c7d1d4"), "dark": Color("677d8c"), "trim": Color("c7a465"), "leather": Color("5e4741"), "cloth": Color("973f4d"), "gem": Color("558d9e")},
	"mage": {"main": Color("505c8b"), "dark": Color("323c65"), "trim": Color("c3ad79"), "leather": Color("45445d"), "cloth": Color("554671"), "gem": Color("8fb9ca")}
}
const RECIPES := {
	"3,4,13": 401, "4,7,13": 402, "3,7,13": 403, "3,6,13": 404,
	"4,7,17": 405, "4,4,7": 406, "3,7,17": 407,
	"9,9,11": 411, "9,11,12": 412, "9,12,14": 413, "9,11,14": 414,
	"9,11,13": 415, "7,11,18": 416, "3,11,12": 417,
	"11,16,19": 421, "4,16,19": 422, "7,16,19": 423, "3,16,19": 424,
	"9,16,19": 425, "4,11,19": 426, "3,11,19": 427
}

static func style(id: int) -> String:
	for key in STARTS:
		if id >= int(STARTS[key]) and id < int(STARTS[key]) + 7:
			return key
	return ""

static func is_new(id: int) -> bool:
	return id >= 401 and not style(id).is_empty()

static func slot(id: int) -> int:
	var key := style(id)
	return id - int(STARTS[key]) if not key.is_empty() else -1

static func ids(key: String) -> Array[int]:
	var result: Array[int] = []
	if STARTS.has(key):
		for index in range(7):
			result.append(int(STARTS[key]) + index)
	return result

static func title(id: int) -> String:
	return str(NAMES[style(id)][slot(id)]) if is_new(id) else ""

static func color(id: int) -> Color:
	var palette: Dictionary = PALETTES.get(style(id), {})
	if palette.is_empty():
		return Color.TRANSPARENT
	match slot(id):
		3, 4, 6: return palette.leather if style(id) == "ranger" else palette.main
		5: return palette.cloth
	return palette.main

static func description(id: int) -> String:
	match style(id):
		"ranger": return "林地游侠的旅行装备。兜帽、轻便皮革与苔绿色短披风相配，护肩和腰间小袋适合森林探险的装扮。"
		"knight": return "曙光骑士的仪仗装备。银白甲片、金色饰边和宽大护肩构成挺拔轮廓，红色战旗披风配有十字纹章。"
		"mage": return "星辉法师的观星服饰。高尖帽、深蓝分片长袍与紫色星纹披风相配，以浅色晶饰和金边点缀。"
	return ""

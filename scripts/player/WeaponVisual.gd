extends Node3D

## 多元化特色近战武器 3D 视觉模型构建组件
## 为木短剑、石战斧、铁长剑、金细剑、黑曜石巨剑提供日系体素 3D 模型与展示姿态

const ItemCatalog = preload("res://scripts/inventory/ItemCatalog.gd")

var weapon_id: int = 301
var is_display: bool = false

func _ready() -> void:
	build()

## 设置武器 ID 与展示模式
func set_weapon(id: int, display_mode: bool = false) -> void:
	weapon_id = id
	is_display = display_mode
	build()

## 构建全量 3D 体素模型
func build() -> void:
	# 清空现有子节点
	for child in get_children():
		child.queue_free()
		
	if not ItemCatalog.is_weapon(weapon_id):
		return
		
	var root := Node3D.new()
	root.name = "WeaponRoot"
	add_child(root)
	
	if is_display:
		root.position = Vector3(0, -0.10, 0)
		root.rotation_degrees = Vector3(18, 55, 45)
		root.scale = Vector3.ONE * 0.68
		
	match weapon_id:
		301: # 原木轻短剑
			_build_wooden_sword(root)
		302: # 砥石破山斧（重战斧）
			_build_stone_battleaxe(root)
		303: # 精炼铁长剑
			_build_iron_greatsword(root)
		304: # 灵蕴金晶细剑
			_build_gold_rapier(root)
		305: # 暗渊黑曜石巨剑
			_build_obsidian_colossus(root)

# -----------------------------------------------------------------------------
# 1. 原木轻短剑模型（Z 轴为前后锋刃劈砍纵深，X 轴为左右纤细刀身）
# -----------------------------------------------------------------------------
func _build_wooden_sword(root: Node3D) -> void:
	var wood_dark := Color("#5a3418")
	var wood_main := Color("#8c6436")
	var blade_c := Color("#c89f64")
	var blade_hi := Color("#e2bf8a")
	
	# 剑柄（手心握持点在原点）
	_box(root, Vector3(0, -0.05, 0), Vector3(0.044, 0.05, 0.044), wood_dark) # 柄首配重块
	_box(root, Vector3(0, 0.05, 0), Vector3(0.036, 0.15, 0.036), wood_dark)  # 握柄
	# 护手剑格（左右 X 轴张开保护手腕）
	_box(root, Vector3(0, 0.13, 0), Vector3(0.14, 0.032, 0.052), wood_main)
	# 短剑刃身（前后 Z 轴为破风锋刃，左右 X 为薄刃）
	_box(root, Vector3(0, 0.30, 0), Vector3(0.024, 0.32, 0.068), blade_c)
	# 剑尖收缩
	_box(root, Vector3(0, 0.48, 0), Vector3(0.020, 0.06, 0.046), blade_hi)
	# 剑脊高光中心线（沿左右两侧隆起）
	_box(root, Vector3(0.012, 0.31, 0), Vector3(0.008, 0.34, 0.018), blade_hi)
	_box(root, Vector3(-0.012, 0.31, 0), Vector3(0.008, 0.34, 0.018), blade_hi)

# -----------------------------------------------------------------------------
# 2. 砥石破山斧（双手重战斧）模型
# -----------------------------------------------------------------------------
func _build_stone_battleaxe(root: Node3D) -> void:
	var handle_c := Color("#4d321d")
	var dark_iron := Color("#40464d")
	var stone_c := Color("#8a96a0")
	var stone_hi := Color("#c8d6e2")
	
	# 厚重长斧柄（原点延伸至 0.52m）
	_box(root, Vector3(0, -0.06, 0), Vector3(0.048, 0.06, 0.048), handle_c)
	_box(root, Vector3(0, 0.22, 0), Vector3(0.042, 0.50, 0.042), handle_c)
	# 顶部金属加固紧固箍
	_box(root, Vector3(0, 0.46, 0), Vector3(0.064, 0.08, 0.064), dark_iron)
	# 前主斧刃（朝向 -Z 前方，饱满厚重双弧度月牙劈砍面）
	_box(root, Vector3(0, 0.46, -0.08), Vector3(0.054, 0.18, 0.10), stone_c)
	_box(root, Vector3(0, 0.46, -0.16), Vector3(0.036, 0.24, 0.07), stone_hi)
	# 后破甲战斧凿尾（朝向 +Z 后方，粗壮破甲齿）
	_box(root, Vector3(0, 0.46, 0.07), Vector3(0.050, 0.12, 0.08), stone_c)
	_box(root, Vector3(0, 0.46, 0.13), Vector3(0.032, 0.08, 0.05), stone_hi)
	# 顶部破甲矛尖
	_box(root, Vector3(0, 0.53, 0), Vector3(0.036, 0.08, 0.036), dark_iron)

# -----------------------------------------------------------------------------
# 3. 精炼铁长剑（骑士单手剑）模型（前后 Z 轴为破风锋刃，左右 X 轴为纤细刀脊）
# -----------------------------------------------------------------------------
func _build_iron_greatsword(root: Node3D) -> void:
	var grip_c := Color("#202428")
	var gold_c := Color("#d6a83e")
	var steel_c := Color("#d8e6f2")
	var steel_hi := Color("#ffffff")
	
	# 黄金圆环配重球
	_box(root, Vector3(0, -0.06, 0), Vector3(0.048, 0.05, 0.048), gold_c)
	# 皮革缠绕剑柄
	_box(root, Vector3(0, 0.06, 0), Vector3(0.034, 0.18, 0.034), grip_c)
	# 镀金飞翼十字护手剑格（左右 X 轴展开 0.18m 护手）
	_box(root, Vector3(0, 0.16, 0), Vector3(0.18, 0.034, 0.052), gold_c)
	_box(root, Vector3(-0.09, 0.175, 0), Vector3(0.03, 0.03, 0.04), gold_c)
	_box(root, Vector3(0.09, 0.175, 0), Vector3(0.03, 0.03, 0.04), gold_c)
	# 修长钢剑身（前后 Z 轴展开 0.065m 锋刃，左右 X 轴仅 0.022m 锋薄）
	_box(root, Vector3(0, 0.40, 0), Vector3(0.022, 0.46, 0.065), steel_c)
	# 剑尖锐利收窄
	_box(root, Vector3(0, 0.66, 0), Vector3(0.018, 0.08, 0.042), steel_hi)
	# 前后锋刃双侧白银高光边（朝向 -Z 前锋刃与 +Z 后锋刃）
	_box(root, Vector3(0, 0.41, -0.034), Vector3(0.020, 0.48, 0.008), steel_hi)
	_box(root, Vector3(0, 0.41, 0.034), Vector3(0.020, 0.48, 0.008), steel_hi)

# -----------------------------------------------------------------------------
# 4. 灵蕴金晶细剑（极速刺剑）模型
# -----------------------------------------------------------------------------
func _build_gold_rapier(root: Node3D) -> void:
	var hilt_gold := Color("#e8be48")
	var grip_dark := Color("#5a3c10")
	var blade_gold := Color("#fae478")
	var crystal_hi := Color("#ffffff")
	
	# 泪滴配重球
	_box(root, Vector3(0, -0.055, 0), Vector3(0.038, 0.045, 0.038), hilt_gold)
	# 纤细握把
	_box(root, Vector3(0, 0.05, 0), Vector3(0.030, 0.16, 0.030), grip_dark)
	# 优雅半球形立体镂空护手笼（Cup Guard）
	_box(root, Vector3(0, 0.14, 0), Vector3(0.12, 0.03, 0.12), hilt_gold)
	_box(root, Vector3(0, 0.16, -0.05), Vector3(0.10, 0.06, 0.02), hilt_gold)
	_box(root, Vector3(0, 0.16, 0.05), Vector3(0.10, 0.06, 0.02), hilt_gold)
	_box(root, Vector3(-0.05, 0.16, 0), Vector3(0.02, 0.06, 0.10), hilt_gold)
	_box(root, Vector3(0.05, 0.16, 0), Vector3(0.02, 0.06, 0.10), hilt_gold)
	# 超长金晶细剑针（长达 0.58m，极致轻巧）
	_box(root, Vector3(0, 0.46, 0), Vector3(0.024, 0.60, 0.024), blade_gold)
	# 针尖聚光结晶
	_box(root, Vector3(0, 0.77, 0), Vector3(0.016, 0.04, 0.016), crystal_hi)

# -----------------------------------------------------------------------------
# 5. 暗渊黑曜石巨剑（重型毁灭大剑）模型（前后 Z 轴为 0.12m 阔刃纵向劈砍，左右 X 轴为厚重剑体）
# -----------------------------------------------------------------------------
func _build_obsidian_colossus(root: Node3D) -> void:
	var obs_black := Color("#161022")
	var obs_purple := Color("#4b266e")
	var obs_glow := Color("#a254ee")
	var grip_leather := Color("#0c0914")
	
	# 破甲十字锤首
	_box(root, Vector3(0, -0.09, 0), Vector3(0.065, 0.06, 0.065), obs_purple)
	# 加长双手巨剑握柄（手心上方与下方均有空间）
	_box(root, Vector3(0, 0.08, 0), Vector3(0.044, 0.28, 0.044), grip_leather)
	# 沉重厚实黑曜石剑格（左右 X 轴展开 0.24m 重型护手）
	_box(root, Vector3(0, 0.23, 0), Vector3(0.24, 0.055, 0.08), obs_purple)
	_box(root, Vector3(0, 0.26, 0), Vector3(0.10, 0.035, 0.09), obs_black)
	# 阔刃重剑主体（前后 Z 轴宽达 0.12m，左右 X 轴厚 0.038m，长 0.55m）
	_box(root, Vector3(0, 0.54, 0), Vector3(0.038, 0.55, 0.12), obs_black)
	# 剑刃前后两侧深紫斜切锋刃（朝向 -Z 前方劈砍面与 +Z 后方配重脊）
	_box(root, Vector3(0, 0.54, -0.065), Vector3(0.032, 0.55, 0.024), obs_purple)
	_box(root, Vector3(0, 0.54, 0.065), Vector3(0.032, 0.55, 0.024), obs_purple)
	# 巨剑尖端钝角劈裂斜角
	_box(root, Vector3(0, 0.84, 0), Vector3(0.030, 0.06, 0.08), obs_purple)
	# 剑身中心晶核断裂紫芒流纹（分布在左右两侧剑面上）
	_box(root, Vector3(0.020, 0.55, 0), Vector3(0.008, 0.44, 0.025), obs_glow)
	_box(root, Vector3(-0.020, 0.55, 0), Vector3(0.008, 0.44, 0.025), obs_glow)

## 辅助快速体素立方体构造函数
func _box(parent: Node, pos: Vector3, size: Vector3, tint: Color) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var material := StandardMaterial3D.new()
	material.albedo_color = tint
	material.roughness = 0.72
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.position = pos
	instance.material_override = material
	parent.add_child(instance)
	return instance

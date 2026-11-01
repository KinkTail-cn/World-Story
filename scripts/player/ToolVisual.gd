extends Node3D

const ItemCatalog = preload("res://scripts/inventory/ItemCatalog.gd")

var tool_id: int = 201
var is_display: bool = false

func _ready() -> void:
	build()

func set_tool(id: int, display_mode: bool = false) -> void:
	tool_id = id
	is_display = display_mode
	build()

func build() -> void:
	# 清空现有子节点
	for child in get_children():
		child.queue_free()
	
	if not ItemCatalog.is_tool_item(tool_id):
		return
	
	var type: String = ItemCatalog.tool_type(tool_id)
	var material: String = ItemCatalog.tool_material(tool_id)
	
	# 根据材质确定头部颜色
	var head_c := Color("#c89f64") # 木制
	var dark_c := Color("#8c6436")
	var highlight_c := Color("#dfbc84")
	
	match material:
		"stone":
			head_c = Color("#9aa6b2")
			dark_c = Color("#6c7884")
			highlight_c = Color("#c0ccd6")
		"iron":
			head_c = Color("#d8e6f2")
			dark_c = Color("#8ea6ba")
			highlight_c = Color("#ffffff")
	
	# 木质手柄
	var wood_c := Color("#7e4e2a")
	var wood_dark := Color("#5a3418")
	
	# 根旋转节点（用于展示模式或手持姿态调整）
	var root := Node3D.new()
	add_child(root)
	
	if is_display:
		root.position = Vector3(0, -0.09, 0)
		root.rotation_degrees = Vector3(15, -25, 45)
		root.scale = Vector3.ONE * 0.74
	
	# 1. 手柄主干（原点 (0, 0, 0) 为手心握拳中心）
	# 手柄底端外露把手（拳头下方外露约 7.5cm，带防滑加粗底盖）
	_box(root, Vector3(0, -0.075, 0), Vector3(0.052, 0.08, 0.052), wood_dark)
	# 手柄主杆（自手心向上挺立延伸至 0.44m 处）
	_box(root, Vector3(0, 0.19, 0), Vector3(0.044, 0.45, 0.044), wood_c)
	# 手柄顶端金属紧固箍
	_box(root, Vector3(0, 0.41, 0), Vector3(0.056, 0.05, 0.056), dark_c)
	
	# 2. 工具头部组件（标准工坊比例：前向 -Z，左右 X 轴）
	var top_y: float = 0.43
	match type:
		"pickaxe":
			# 鹤嘴镐：前后纵向布局（击打前向为 -Z，配重后背为 +Z，左右 X 为纤细侧身）
			# 1. 中心套箍（包裹手柄顶端）
			_box(root, Vector3(0, top_y, 0), Vector3(0.064, 0.082, 0.076), dark_c)
			# 中心顶拱加强块
			_box(root, Vector3(0, top_y + 0.025, -0.01), Vector3(0.054, 0.045, 0.09), head_c)
			# 顶部紧固压盖
			_box(root, Vector3(0, top_y + 0.050, -0.005), Vector3(0.048, 0.018, 0.065), dark_c)
			
			# 2. 前镐喙（朝向 -Z 前方，优美连续下弯啄击岩石的锐利弯月嘴）
			# 前近端拱梁
			_box(root, Vector3(0, top_y + 0.012, -0.075), Vector3(0.052, 0.058, 0.075), head_c)
			# 前中段弯梁（向下且向前伸展）
			_box(root, Vector3(0, top_y - 0.022, -0.140), Vector3(0.046, 0.052, 0.075), head_c)
			# 前远段弧梁（加速下钩）
			_box(root, Vector3(0, top_y - 0.070, -0.200), Vector3(0.040, 0.046, 0.065), head_c)
			# 前端尖锐镐尖（最前端高光锋刃，锐利下啄）
			_box(root, Vector3(0, top_y - 0.128, -0.245), Vector3(0.034, 0.058, 0.055), highlight_c)
			
			# 3. 后配重镐喙（朝向 +Z 后方，经典平衡与后凿设计）
			# 后近端拱梁
			_box(root, Vector3(0, top_y + 0.010, 0.065), Vector3(0.052, 0.056, 0.065), head_c)
			# 后中段弧梁（平缓向后微下钩）
			_box(root, Vector3(0, top_y - 0.018, 0.125), Vector3(0.046, 0.048, 0.065), head_c)
			# 后配重方锤/凿尾
			_box(root, Vector3(0, top_y - 0.052, 0.175), Vector3(0.040, 0.042, 0.050), dark_c)
			
		"axe":
			# 斧：中心套箍
			_box(root, Vector3(0, top_y, 0), Vector3(0.07, 0.085, 0.07), dark_c)
			# 斧身前部主体（向前 -Z 展开）
			_box(root, Vector3(0, top_y + 0.005, -0.08), Vector3(0.052, 0.16, 0.11), head_c)
			# 弧形主斧刃锋口（在最前端 -Z，带有上凸下收的劈砍弧线）
			_box(root, Vector3(0, top_y + 0.01, -0.15), Vector3(0.036, 0.22, 0.055), highlight_c)
			# 斧背配重锤部（向后 +Z）
			_box(root, Vector3(0, top_y, 0.05), Vector3(0.065, 0.10, 0.045), dark_c)
			
		"shovel":
			# 锹：中心套筒
			_box(root, Vector3(0, top_y, 0), Vector3(0.065, 0.065, 0.065), dark_c)
			# 铲身主体（沿 X 轴展宽至 0.18m，向前 -Z 偏凹）
			_box(root, Vector3(0, top_y + 0.08, -0.02), Vector3(0.18, 0.18, 0.03), head_c)
			# 铲刃锋边（顶端微体素收尖）
			_box(root, Vector3(0, top_y + 0.18, -0.025), Vector3(0.16, 0.05, 0.024), highlight_c)
			# 铲后脊骨加固筋
			_box(root, Vector3(0, top_y + 0.07, 0.008), Vector3(0.044, 0.15, 0.03), dark_c)

func _box(parent: Node, pos: Vector3, size: Vector3, tint: Color) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var material := StandardMaterial3D.new()
	material.albedo_color = tint
	material.roughness = 0.75
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.position = pos
	instance.material_override = material
	parent.add_child(instance)
	return instance

extends Node3D

const Catalog = preload("res://scripts/inventory/ItemCatalog.gd")
const SHADER = preload("res://shaders/character.gdshader")
const CAPE_SHADER = preload("res://shaders/cape.gdshader")
const BlueprintEquipment = preload("res://scripts/blueprint/BlueprintEquipment.gd")
const BlueprintVisual = preload("res://scripts/player/BlueprintEquipmentVisual.gd")
const EquipmentSets = preload("res://scripts/content/EquipmentSets.gd")
const SetVisual = preload("res://scripts/player/EquipmentSetVisual.gd")
var pieces: Array[Array] = [[], [], [], [], [], [], []]
var custom_visuals: Array[Node3D] = [null, null, null, null, null, null, null]
var set_visuals: Array[Node3D] = [null, null, null, null, null, null, null]
var equipped_ids: Array[int] = [0, 0, 0, 0, 0, 0, 0]
var equipped_items: Array = []
var cape_material := ShaderMaterial.new()
var cape_wind: float = 0.0

func _ready() -> void:
	var character = get_parent()
	var body = character.body
	_piece(0, character.head, Vector3(0, 0.215, 0), Vector3(0.5, 0.12, 0.5))
	_piece(0, character.head, Vector3(0, 0.135, -0.25), Vector3(0.5, 0.05, 0.04))
	for x in [-0.235, 0.235]:
		_piece(0, character.head, Vector3(x, 0.125, 0.03), Vector3(0.045, 0.21, 0.45))
	_piece(1, body, Vector3(0, 1.02, 0), Vector3(0.48, 0.61, 0.26))
	# 护肩（slot 1）：挂在大臂上
	for arm in [character.left_arm, character.right_arm]:
		_piece(1, arm, Vector3(0, -0.09, 0), Vector3(0.27, 0.18, 0.27))
	
	# 护手/手套（slot 4）：挂在前臂手腕处
	var forearms = [character.left_forearm, character.right_forearm] if ("left_forearm" in character and character.left_forearm != null) else [character.left_arm, character.right_arm]
	for fa in forearms:
		var pos_y: float = -0.225 if fa != character.left_arm else -0.565
		_piece(4, fa, Vector3(0, pos_y, 0), Vector3(0.25, 0.23, 0.25))
	
	# 裤甲大腿（slot 2）：挂在大腿上
	for leg in [character.left_leg, character.right_leg]:
		_piece(2, leg, Vector3(0, -0.17, 0), Vector3(0.235, 0.34, 0.245))
	
	# 护膝（slot 2）与战靴（slot 3）：挂在小腿上随膝盖弯曲
	var lower_legs = [character.left_lower_leg, character.right_lower_leg] if ("left_lower_leg" in character and character.left_lower_leg != null) else [character.left_leg, character.right_leg]
	for ll in lower_legs:
		var is_sub: bool = ll != character.left_leg
		var knee_y: float = -0.02 if is_sub else -0.47
		var boot_y: float = -0.24 if is_sub else -0.58
		_piece(2, ll, Vector3(0, knee_y, -0.135), Vector3(0.24, 0.12, 0.04))
		_piece(3, ll, Vector3(0, boot_y, 0), Vector3(0.25, 0.20, 0.28))
	_create_cape(body)
	_piece(6, body, Vector3(0, 0.715, 0), Vector3(0.50, 0.10, 0.29))
	_piece(6, body, Vector3(0, 0.715, -0.155), Vector3(0.11, 0.09, 0.025), Color("d5b46b"))

func _create_cape(parent: Node3D) -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	# 采用 8 列 x 16 行的高密度细腻网格，使风中波浪如丝绸般圆润饱满
	for y in range(16):
		for x in range(8):
			for corner in [Vector2(0, 0), Vector2(1, 1), Vector2(1, 0), Vector2(0, 0), Vector2(0, 1), Vector2(1, 1)]:
				var uv := Vector2((float(x) + corner.x) / 8.0, (float(y) + corner.y) / 16.0)
				surface.set_uv(uv)
				surface.set_normal(Vector3.BACK)
				# 顶点坐标：肩宽 0.40m，下摆自然微扩至 0.48m，垂长 0.82m
				surface.add_vertex(Vector3((uv.x - 0.5) * (0.40 + uv.y * 0.08), -uv.y * 0.82, 0))
	cape_material.shader = CAPE_SHADER
	cape_material.set_shader_parameter("base_color", Catalog.color(106))
	var cape := MeshInstance3D.new()
	cape.name = "Equipment_Cape"
	cape.mesh = surface.commit()
	cape.material_override = cape_material
	cape.position = Vector3(0, 1.30, 0.155)
	# 扩展视锥体包围盒，防止疾跑大后扬时被视锥剔除
	cape.custom_aabb = AABB(Vector3(-0.6, -1.2, -0.2), Vector3(1.2, 1.4, 1.6))
	cape.visible = false
	parent.add_child(cape)
	pieces[5].append(cape)
	_piece(5, parent, Vector3(0, 1.30, 0.17), Vector3(0.42, 0.045, 0.04))

## 实时更新披风空气动力学风力响应与飘动缓动
func update_motion(delta: float, speed: float, airborne: bool, swimming: bool, sitting: bool) -> void:
	# 奔跑时风力响应更自然澎湃，速度达到 4.8（跑步）时具有良好飘拂感，冲刺（7.8）时完全展开
	var desired: float = clampf(speed / 5.2, 0.0, 1.65)
	if airborne and speed > 0.5:
		desired = maxf(desired, 1.1)
	if swimming:
		desired *= 0.65
	if sitting:
		desired = 0.0
	# 敏捷气流动力响应：起步灵敏飘扬，静止或坐下时平稳归位贴服
	var lerp_speed: float = 8.5 if (desired > cape_wind or sitting) else 7.5
	cape_wind = lerpf(cape_wind, desired, minf(delta * lerp_speed, 1.0))
	cape_material.set_shader_parameter("wind_strength", cape_wind)
	if is_instance_valid(set_visuals[5]):
		set_visuals[5].set_wind(cape_wind)

func _piece(slot: int, parent: Node3D, pos: Vector3, size: Vector3, tint: Color = Color.TRANSPARENT) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	var material := ShaderMaterial.new()
	material.shader = SHADER
	material.set_shader_parameter("base_color", tint if tint.a > 0.0 else Catalog.color(101 + slot))
	var piece := MeshInstance3D.new()
	piece.name = "Equipment_%d_%d" % [slot, pieces[slot].size()]
	piece.mesh = mesh
	piece.material_override = material
	piece.position = pos
	piece.visible = false
	parent.add_child(piece)
	pieces[slot].append(piece)

func apply_equipment(ids: Array[int], items: Array = []) -> void:
	equipped_ids = ids.duplicate()
	equipped_items = items.duplicate(true)
	for slot in range(7):
		var item: Dictionary = items[slot] if slot < items.size() and items[slot] is Dictionary else {}
		var custom := ids[slot] != 0 and int(item.get("id", 0)) == ids[slot] and BlueprintEquipment.is_custom_item(item)
		for piece in pieces[slot]:
			piece.visible = ids[slot] == 101 + slot and not custom
		var set_id: int = ids[slot] if EquipmentSets.is_new(ids[slot]) and Catalog.equipment_slot(ids[slot]) == slot else 0
		var set_visual = set_visuals[slot]
		if is_instance_valid(set_visual) and set_visual.item_id != set_id:
			remove_child(set_visual)
			set_visual.queue_free()
			set_visuals[slot] = null
		if set_id != 0 and not is_instance_valid(set_visuals[slot]):
			var created = SetVisual.new()
			add_child(created)
			created.build(set_id, get_parent())
			created.set_wind(cape_wind)
			set_visuals[slot] = created
		var previous = custom_visuals[slot]
		if is_instance_valid(previous):
			if custom and previous.blueprint == item.blueprint:
				continue
			previous.hide_pieces()
			remove_child(previous)
			previous.queue_free()
			custom_visuals[slot] = null
		if custom:
			var visual = BlueprintVisual.new()
			add_child(visual)
			visual.build(item.blueprint, get_parent())
			custom_visuals[slot] = visual

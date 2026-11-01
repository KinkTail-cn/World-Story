extends Node3D

const Catalog = preload("res://scripts/content/BlockCatalog.gd")
const ItemCatalog = preload("res://scripts/inventory/ItemCatalog.gd")
const BlockTextures = preload("res://scripts/content/BlockTextures.gd")
const SHADER = preload("res://shaders/character.gdshader")
const DocumentVisual = preload("res://scripts/player/DocumentVisual.gd")
const ToolVisual = preload("res://scripts/player/ToolVisual.gd")
const WeaponVisual = preload("res://scripts/player/WeaponVisual.gd")
const ToolSwing = preload("res://scripts/player/ToolSwing.gd")
const REST_GRIP_ROTATION := ToolSwing.REST_ROTATION
const SWING_GRIP_ROTATION := Vector3(-1.3264502, 0.1745329, -0.0872665)

var block_id: int = 1
var block_material := ShaderMaterial.new()
var top_material := ShaderMaterial.new()
var document_visual: Node3D
var tool_visual: Node3D
var weapon_visual: Node3D
var is_first_person: bool = false

func _ready() -> void:
	block_material.shader = SHADER
	top_material.shader = SHADER
	$Block.material_override = block_material
	$Top.material_override = top_material
	set_block(block_id)

func set_block(id: int) -> void:
	block_id = id
	var is_blk: bool = ItemCatalog.is_block(id)
	visible = is_blk or id in [108, 109] or ItemCatalog.is_tool_item(id) or ItemCatalog.is_weapon(id)
	$Block.visible = is_blk
	if document_visual != null:
		remove_child(document_visual)
		document_visual.queue_free()
		document_visual = null
	if tool_visual != null:
		remove_child(tool_visual)
		tool_visual.queue_free()
		tool_visual = null
	if weapon_visual != null:
		remove_child(weapon_visual)
		weapon_visual.queue_free()
		weapon_visual = null
		
	if id in [108, 109]:
		document_visual = DocumentVisual.new()
		document_visual.item_id = id
		document_visual.scale = Vector3.ONE * 0.7
		add_child(document_visual)
	elif ItemCatalog.is_tool_item(id):
		tool_visual = ToolVisual.new()
		tool_visual.set_tool(id, false)
		
		# 判断是否处于第一人称相机下
		var in_fp: bool = is_first_person or (get_parent() != null and get_parent() is Camera3D)
		if in_fp:
			# 第一人称：手柄自右下方向前上方自然伸展，镐尖朝前，充满敲击感
			tool_visual.scale = Vector3.ONE * 0.95
			tool_visual.position = Vector3(0.0, -0.08, 0.04)
			tool_visual.rotation_degrees = Vector3(-45, 30, -20)
		else:
			# Third-person grip is centered on the palm; its resting direction is
			# resolved against the torso after the arm animation has been applied.
			tool_visual.scale = Vector3.ONE * 1.05
			tool_visual.position = Vector3.ZERO
			tool_visual.rotation = SWING_GRIP_ROTATION
			
		add_child(tool_visual)
	elif ItemCatalog.is_weapon(id):
		weapon_visual = WeaponVisual.new()
		weapon_visual.set_weapon(id, false)
		
		var in_fp_w: bool = is_first_person or (get_parent() != null and get_parent() is Camera3D)
		if in_fp_w:
			# 第一人称：手持长剑向前伸展，剑尖微微上扬指准十字准星
			weapon_visual.scale = Vector3.ONE * 0.95
			weapon_visual.position = Vector3(0.0, -0.06, 0.05)
			weapon_visual.rotation_degrees = Vector3(-50, 25, -25)
		else:
			# Use the same palm-centered grip for short and long weapons.
			weapon_visual.scale = Vector3.ONE * 1.05
			weapon_visual.position = Vector3.ZERO
			weapon_visual.rotation = SWING_GRIP_ROTATION
			
		add_child(weapon_visual)
		
	if is_blk:
		$Block.mesh = BlockTextures.create_block_mesh(Vector3(0.32, 0.32, 0.32))
		$Block.material_override = BlockTextures.get_material(id)
		var has_top: bool = Catalog.has_special_top(id)
		$Top.visible = has_top
		var in_fp_block: bool = is_first_person or (get_parent() != null and get_parent() is Camera3D)
		if in_fp_block:
			# 第一人称下保持原点对齐（由 Camera3D 下的 _update_first_person_motion 动态姿态矩阵接管）
			$Block.position = Vector3.ZERO
			$Block.rotation_degrees = Vector3.ZERO
			var blk_scale: float = 0.65
			$Block.scale = Vector3.ONE * blk_scale
			$Top.scale = (Vector3.ZERO if has_top else Vector3.ONE) * blk_scale
			$Top.position = Vector3(0, 0.136, 0)
			$Top.rotation_degrees = Vector3.ZERO
		else:
			# 第三人称：掌心托握黄金等角立方体姿态
			# 彻底消除右小臂穿模，顶面以明亮菱形朝上、双侧面呈黄金人字形展开，展现与世界放置方块 100% 同比例的饱满正六面体手办神韵
			$Block.position = Vector3(0.01, 0.04, 0.06)
			$Block.rotation_degrees = Vector3(-56, -38, 12)
			var blk_scale: float = 0.96
			$Block.scale = Vector3.ONE * blk_scale
			$Top.scale = (Vector3.ZERO if has_top else Vector3.ONE) * blk_scale
			$Top.position = Vector3(0.01, 0.04, 0.06)
			$Top.rotation_degrees = Vector3(-56, -38, 12)

func update_third_person_grip(torso_basis: Basis, action_weight: float, grip_rotation: Variant = null) -> void:
	if is_first_person or get_parent() is Camera3D:
		return
	var model: Node3D = tool_visual if tool_visual != null else weapon_visual
	if not is_instance_valid(model):
		return
	# Cancel the complete shoulder/elbow/wrist rotation at rest. A fixed local
	# pitch only cancels one joint and tips the item backward when running.
	var rest := global_basis.orthonormalized().inverse() * torso_basis.orthonormalized() * Basis.from_euler(REST_GRIP_ROTATION)
	var action := Basis.from_euler(SWING_GRIP_ROTATION)
	if grip_rotation is Vector3:
		action = global_basis.orthonormalized().inverse() * torso_basis.orthonormalized() * Basis.from_euler(grip_rotation)
	var weight := smoothstep(0.0, 1.0, clampf(action_weight, 0.0, 1.0))
	model.basis = Basis(rest.get_rotation_quaternion().slerp(action.get_rotation_quaternion(), weight)).scaled(Vector3.ONE * 1.05)

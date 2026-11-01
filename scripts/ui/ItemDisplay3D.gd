extends Node3D

const BlockCatalog = preload("res://scripts/content/BlockCatalog.gd")
const ItemCatalog = preload("res://scripts/inventory/ItemCatalog.gd")
const BlockTextures = preload("res://scripts/content/BlockTextures.gd")
const SHADER = preload("res://shaders/character.gdshader")
const DocumentVisual = preload("res://scripts/player/DocumentVisual.gd")
const ToolVisual = preload("res://scripts/player/ToolVisual.gd")
const WeaponVisual = preload("res://scripts/player/WeaponVisual.gd")
const BlueprintEquipment = preload("res://scripts/blueprint/BlueprintEquipment.gd")
const BlueprintVisual = preload("res://scripts/player/BlueprintEquipmentVisual.gd")
const EquipmentSets = preload("res://scripts/content/EquipmentSets.gd")
const SetVisual = preload("res://scripts/player/EquipmentSetVisual.gd")

var block_instance: Node3D
var block_material := ShaderMaterial.new()
var top_material := ShaderMaterial.new()
var current_id: int = 0
var current_data: Dictionary = {}

func _ready() -> void:
	block_material.shader = SHADER
	top_material.shader = SHADER
	_build_block_nodes()

func _build_block_nodes() -> void:
	block_instance = Node3D.new()
	block_instance.name = "BlockRoot"
	add_child(block_instance)
	
	var base_mesh := MeshInstance3D.new()
	base_mesh.name = "BaseMesh"
	base_mesh.mesh = BlockTextures.create_block_mesh(Vector3(0.32, 0.32, 0.32))
	block_instance.add_child(base_mesh)
	
	var top_mesh := MeshInstance3D.new()
	top_mesh.name = "TopMesh"
	top_mesh.visible = false
	block_instance.add_child(top_mesh)

func set_item(id: int, data: Dictionary = {}) -> void:
	if current_id == id and current_data == data:
		return
	current_id = id
	current_data = data.duplicate(true)
	visible = id > 0
	if id == 0:
		return
	
	# 清理可能存在的动态挂载物（文档、装备或工具）
	for child in get_children():
		if child != block_instance:
			child.queue_free()
	
	if ItemCatalog.is_block(id):
		block_instance.visible = true
		block_instance.scale = Vector3.ONE
		var base_mesh: MeshInstance3D = block_instance.get_node("BaseMesh")
		base_mesh.mesh = BlockTextures.create_block_mesh(Vector3(0.32, 0.32, 0.32))
		base_mesh.material_override = BlockTextures.get_material(id)
		var top_mesh: MeshInstance3D = block_instance.get_node("TopMesh")
		top_mesh.visible = false
	elif id in [108, 109]:
		block_instance.visible = false
		var doc: Node3D = DocumentVisual.new()
		doc.item_id = id
		doc.scale = Vector3.ONE * 0.72
		add_child(doc)
	elif BlueprintEquipment.is_custom_item(data):
		block_instance.visible = false
		var custom = BlueprintVisual.new()
		add_child(custom)
		custom.build(data.blueprint)
	elif EquipmentSets.is_new(id):
		block_instance.visible = false
		var equipment = SetVisual.new()
		add_child(equipment)
		equipment.build(id)
	elif ItemCatalog.is_equipment(id):
		block_instance.visible = false
		_build_equipment_visual(id)
	elif ItemCatalog.is_tool_item(id):
		block_instance.visible = false
		var tool_vis: Node3D = ToolVisual.new()
		tool_vis.set_tool(id, true)
		add_child(tool_vis)
	elif ItemCatalog.is_weapon(id):
		block_instance.visible = false
		var weapon_vis: Node3D = WeaponVisual.new()
		weapon_vis.set_weapon(id, true)
		add_child(weapon_vis)

func _build_equipment_visual(id: int) -> void:
	var equip_node := Node3D.new()
	add_child(equip_node)
	equip_node.scale = Vector3.ONE * 0.75
	var steel_mat := ShaderMaterial.new()
	steel_mat.shader = SHADER
	steel_mat.set_shader_parameter("base_color", ItemCatalog.color(101))
	
	match id:
		101: # 头盔
			_add_box(equip_node, Vector3(0, 0.06, 0), Vector3(0.36, 0.12, 0.36), steel_mat)
			_add_box(equip_node, Vector3(-0.14, -0.06, 0), Vector3(0.08, 0.18, 0.36), steel_mat)
			_add_box(equip_node, Vector3(0.14, -0.06, 0), Vector3(0.08, 0.18, 0.36), steel_mat)
		102: # 盔甲
			_add_box(equip_node, Vector3(0, 0, 0), Vector3(0.34, 0.40, 0.20), steel_mat)
			_add_box(equip_node, Vector3(-0.24, 0.12, 0), Vector3(0.18, 0.14, 0.22), steel_mat)
			_add_box(equip_node, Vector3(0.24, 0.12, 0), Vector3(0.18, 0.14, 0.22), steel_mat)
		103: # 裤甲
			_add_box(equip_node, Vector3(-0.10, 0, 0), Vector3(0.15, 0.38, 0.16), steel_mat)
			_add_box(equip_node, Vector3(0.10, 0, 0), Vector3(0.15, 0.38, 0.16), steel_mat)
			_add_box(equip_node, Vector3(-0.10, -0.02, 0.06), Vector3(0.16, 0.10, 0.06), steel_mat)
			_add_box(equip_node, Vector3(0.10, -0.02, 0.06), Vector3(0.16, 0.10, 0.06), steel_mat)
		104: # 战靴
			_add_box(equip_node, Vector3(-0.11, 0, 0), Vector3(0.16, 0.20, 0.24), steel_mat)
			_add_box(equip_node, Vector3(0.11, 0, 0), Vector3(0.16, 0.20, 0.24), steel_mat)
		105: # 手套
			_add_box(equip_node, Vector3(-0.14, 0, 0), Vector3(0.18, 0.22, 0.18), steel_mat)
			_add_box(equip_node, Vector3(0.14, 0, 0), Vector3(0.18, 0.22, 0.18), steel_mat)
		106: # 披风
			var cape_mat := ShaderMaterial.new()
			cape_mat.shader = SHADER
			cape_mat.set_shader_parameter("base_color", ItemCatalog.color(106))
			var gold_mat := ShaderMaterial.new()
			gold_mat.shader = SHADER
			gold_mat.set_shader_parameter("base_color", Color("e3b768"))
			_add_box(equip_node, Vector3(0, 0.18, 0), Vector3(0.32, 0.06, 0.06), gold_mat)
			_add_box(equip_node, Vector3(0, -0.05, 0), Vector3(0.30, 0.44, 0.04), cape_mat)
		107: # 腰带
			var leather_mat := ShaderMaterial.new()
			leather_mat.shader = SHADER
			leather_mat.set_shader_parameter("base_color", ItemCatalog.color(107))
			var buckle_mat := ShaderMaterial.new()
			buckle_mat.shader = SHADER
			buckle_mat.set_shader_parameter("base_color", Color("d5b46b"))
			_add_box(equip_node, Vector3(0, 0, 0), Vector3(0.38, 0.10, 0.22), leather_mat)
			_add_box(equip_node, Vector3(0, 0, 0.115), Vector3(0.12, 0.12, 0.03), buckle_mat)

func _add_box(parent: Node3D, pos: Vector3, size: Vector3, mat: Material) -> void:
	var mesh_inst := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh_inst.mesh = box
	mesh_inst.position = pos
	mesh_inst.material_override = mat
	parent.add_child(mesh_inst)

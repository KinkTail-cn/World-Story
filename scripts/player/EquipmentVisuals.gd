extends Node3D

const Catalog = preload("res://scripts/inventory/ItemCatalog.gd")
const SHADER = preload("res://shaders/character.gdshader")
const Cubes = preload("res://scripts/content/CubeParts.gd")
const Materials = preload("res://scripts/blueprint/BlueprintMaterials.gd")
const BlueprintEquipment = preload("res://scripts/blueprint/BlueprintEquipment.gd")
const BlueprintVisual = preload("res://scripts/player/BlueprintEquipmentVisual.gd")
const EquipmentSets = preload("res://scripts/content/EquipmentSets.gd")
const SetVisual = preload("res://scripts/player/EquipmentSetVisual.gd")
var pieces: Array[Array] = [[], [], [], [], [], [], []]
var custom_visuals: Array[Node3D] = [null, null, null, null, null, null, null]
var set_visuals: Array[Node3D] = [null, null, null, null, null, null, null]
var equipped_ids: Array[int] = [0, 0, 0, 0, 0, 0, 0]
var equipped_items: Array = []
var motion_enabled: bool = true
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
	_piece(5, parent, Vector3(0, 0.89, 0.175), Vector3(0.42, 0.82, 0.0325))
	_piece(5, parent, Vector3(0, 1.30, 0.17), Vector3(0.42, 0.045, 0.04))

func update_motion(delta: float, speed: float, airborne: bool, swimming: bool, sitting: bool) -> void:
	if not motion_enabled:
		return
	var desired := clampf(speed / 5.2, 0.0, 1.65)
	if airborne and speed > 0.5:
		desired = maxf(desired, 1.1)
	if swimming:
		desired *= 0.65
	if sitting:
		desired = 0.0
	cape_wind = lerpf(cape_wind, desired, minf(delta * (8.5 if desired > cape_wind or sitting else 7.5), 1.0))
	_sync_cape_motion()

func set_motion_enabled(enabled: bool) -> void:
	motion_enabled = enabled
	if not enabled:
		cape_wind = 0.0
	_sync_cape_motion()

func _sync_cape_motion() -> void:
	for piece in pieces[5]:
		piece.material_override.set_shader_parameter("motion_scale", 1.0 if motion_enabled else 0.0)
		piece.material_override.set_shader_parameter("wind_strength", cape_wind)
	for visual in [set_visuals[5], custom_visuals[5]]:
		if is_instance_valid(visual):
			visual.set_motion_enabled(motion_enabled)
			visual.set_wind(cape_wind)

func _piece(slot: int, parent: Node3D, pos: Vector3, size: Vector3, tint: Color = Color.TRANSPARENT) -> void:
	var mesh := Cubes.mesh(size)
	var material := ShaderMaterial.new()
	material.shader = SHADER
	material.set_shader_parameter("base_color", tint if tint.a > 0.0 else Catalog.color(101 + slot))
	if slot == 5:
		material = Materials.create_cape({"tint": Catalog.color(106).to_html(false), "surface": "cloth"})
		material.set_shader_parameter("cape_uv_scale", Vector2(size.x / 0.42, size.y / 0.82))
		material.set_shader_parameter("cape_uv_offset", Vector2((pos.x - size.x * 0.5) / 0.42 + 0.5, (1.30 - pos.y - size.y * 0.5) / 0.82))
		material.set_shader_parameter("motion_scale", 1.0 if motion_enabled else 0.0)
	var piece := MeshInstance3D.new()
	piece.name = "Equipment_%d_%d" % [slot, pieces[slot].size()]
	piece.mesh = mesh
	piece.material_override = material
	piece.position = pos
	if slot == 5:
		piece.custom_aabb = mesh.get_aabb().grow(1.0)
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
	_sync_cape_motion()

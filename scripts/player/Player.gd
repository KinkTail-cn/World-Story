extends CharacterBody3D

signal status_changed(target: String, progress: float, first_person: bool, mined: int, placed: int)
signal selection_changed(slot: int)
signal message(text: String)
signal water_status_changed(swimming: bool, submerged: bool, camera_underwater: bool, depth: float)
signal function_changed(function: int, seated: bool)
signal document_requested(document: Node3D)
signal document_mined(document: Node3D)

const Catalog = preload("res://scripts/content/BlockCatalog.gd")
const HELD_BLOCK = preload("res://scenes/HeldBlock.tscn")
const ItemCatalog = preload("res://scripts/inventory/ItemCatalog.gd")
const ToolSwing = preload("res://scripts/player/ToolSwing.gd")
const WeaponSwing = preload("res://scripts/player/WeaponSwing.gd")
const REACH: float = 4.8
const CAMERA_DISTANCE: float = 3.2
const CAMERA_OFFSET := Vector3(0.90, 0.12, 3.2)
const CAMERA_CLEARANCE: float = 0.22
const CAMERA_HIDE_DISTANCE: float = 1.2
var world: Node3D
var inventory: RefCounted
var target_document: Node3D
var selected_slot: int = 0
var first_person: bool = false
var mouse_sensitivity: float = 0.0025
var target_cell := Vector3i(-1, -1, -1)
var target_normal := Vector3i.ZERO
var target_id: int = 0
var mining_time: float = 0.0
var mined: int = 0
var placed: int = 0
var query := PhysicsRayQueryParameters3D.new()
var outline: Node3D
var place_delay: float = 0.0
var debris: Array[Dictionary] = []
var first_person_item: Node3D
var swimming: bool = false
var submerged: bool = false
var active_function: int = 0
var sitting: bool = false
var seat_cell := Vector3i.ZERO
var interaction_blocked: bool = false
var controls_enabled: bool = true
var effects_root: Node3D
var standing_shape := CapsuleShape3D.new()
var sitting_shape := CapsuleShape3D.new()
var occupancy_query := PhysicsShapeQueryParameters3D.new()
var swing_timer: float = 0.0
var _hit_spark_cooldown: float = 0.0
var _last_feet_y: float = 999.0
var fp_look_sway: Vector2 = Vector2.ZERO
var camera_query := PhysicsShapeQueryParameters3D.new()

@onready var visual = $Visual
@onready var rig: Node3D = $CameraRig
@onready var pitch: Node3D = $CameraRig/Pitch
@onready var arm: SpringArm3D = $CameraRig/Pitch/SpringArm
@onready var camera: Camera3D = $CameraRig/Pitch/SpringArm/Camera
@onready var collision: CollisionShape3D = $Collision
@onready var water_splash: Node3D = $WaterSplash if has_node("WaterSplash") else null

func _ready() -> void:
	if water_splash == null:
		var splash_scene = preload("res://scenes/WaterSplash.tscn")
		water_splash = splash_scene.instantiate()
		add_child(water_splash)
	query.collision_mask = 1
	query.exclude = [get_rid()]
	arm.add_excluded_object(get_rid())
	arm.shape = arm.shape.duplicate()
	camera_query.exclude = [get_rid()]
	camera_query.collision_mask = arm.collision_mask
	camera_query.margin = 0.0
	_create_outline()
	first_person_item = HELD_BLOCK.instantiate()
	first_person_item.is_first_person = true
	first_person_item.position = Vector3(0.36, -0.23, -0.54)
	first_person_item.rotation = Vector3(0.38, -0.61, 0.17)
	first_person_item.visible = false
	camera.add_child(first_person_item)
	select_slot(selected_slot)
	standing_shape.radius = 0.36
	standing_shape.height = 1.8
	sitting_shape.radius = 0.36
	sitting_shape.height = 1.3
	occupancy_query.collision_mask = 1
	occupancy_query.exclude = [get_rid()]
	occupancy_query.margin = 0.001
	_update_camera_height()
	_update_camera_clearance()
	effects_root = Node3D.new()
	effects_root.name = "PlayerEffects"
	effects_root.top_level = true
	add_child(effects_root)
	effects_root.global_transform = Transform3D.IDENTITY

func _process(_delta: float) -> void:
	_update_camera_clearance()
	_resolve_camera_collision()
	# The boom can collapse to eye distance in a tight corner. Hide the body
	# before the near plane enters the head or shoulder meshes.
	visual.visible = not first_person and camera.global_position.distance_to(rig.global_position) > CAMERA_HIDE_DISTANCE

func _update_camera_clearance() -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	var aspect := viewport_size.x / maxf(1.0, viewport_size.y)
	var half_height := camera.near * tan(deg_to_rad(camera.fov * 0.5))
	var half_width := half_height * aspect
	if camera.keep_aspect == Camera3D.KEEP_WIDTH:
		half_width = half_height
		half_height = half_width / maxf(0.01, aspect)
	# Sweep a volume enclosing the lens and all near-plane corners, including
	# wider windows and the sprint FOV.
	var near_radius := Vector3(half_width, half_height, camera.near).length() + 0.04
	var radius := maxf(CAMERA_CLEARANCE, near_radius)
	if not is_equal_approx(arm.shape.radius, radius):
		arm.shape.radius = radius

func _resolve_camera_collision() -> void:
	if first_person:
		camera.position = Vector3.ZERO
		return
	camera_query.shape = arm.shape
	camera_query.transform = Transform3D(Basis.IDENTITY, arm.global_position)
	camera_query.motion = arm.global_basis.z * arm.spring_length
	var fractions := get_world_3d().direct_space_state.cast_motion(camera_query)
	var distance := arm.spring_length
	if fractions[0] < 1.0:
		distance = maxf(0.0, arm.spring_length * fractions[0] - arm.margin)
	# Mouse motion can rotate the rig between physics ticks. Recheck before
	# rendering as well as aiming, so that frame cannot enter the wall either.
	camera.position = Vector3(0, 0, distance)

func _unhandled_input(event: InputEvent) -> void:
	if not controls_enabled or get_tree().paused:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rig.rotation.y -= event.relative.x * mouse_sensitivity
		pitch.rotation.x = clampf(pitch.rotation.x - event.relative.y * mouse_sensitivity, -1.25, 1.15)
		# 视角惯性漂移滞后阻尼累积（水平与垂直方向阻尼滞后）
		fp_look_sway.x = clampf(fp_look_sway.x - event.relative.x * 0.0006, -0.045, 0.045)
		fp_look_sway.y = clampf(fp_look_sway.y - event.relative.y * 0.0006, -0.035, 0.035)
	if event.is_action_pressed("switch_view"):
		set_first_person(not first_person)

	if event.is_action_pressed("sit"):
		select_function(1)
	if event.is_action_pressed("interact") and target_document != null:
		document_requested.emit(target_document)
	for slot in range(8):
		if event.is_action_pressed("slot_%d" % (slot + 1)):
			select_slot(slot)
	if event.is_action_pressed("next_slot"):
		select_slot((selected_slot + 1) % 8)
	if event.is_action_pressed("previous_slot"):
		select_slot((selected_slot + 7) % 8)

## 显式切换或设置第一人称视角模式
func set_first_person(enabled: bool) -> void:
	first_person = enabled
	visual.visible = not first_person
	first_person_item.visible = first_person and (ItemCatalog.is_block(selected_item_id()) or ItemCatalog.is_document(selected_item_id()) or ItemCatalog.is_tool_item(selected_item_id()) or ItemCatalog.is_weapon(selected_item_id()))
	_update_camera_height()
	camera.fov = 80.0 if first_person else 70.0
	_emit_status()


func select_slot(slot: int) -> void:
	selected_slot = clampi(slot, 0, 7)
	var id: int = selected_item_id()
	visual.set_held_block(id)
	first_person_item.set_block(id)
	first_person_item.visible = first_person and (ItemCatalog.is_block(id) or ItemCatalog.is_document(id) or ItemCatalog.is_tool_item(id) or ItemCatalog.is_weapon(id))
	selection_changed.emit(selected_slot)

func selected_item_id() -> int:
	return inventory.get_slot("bag", selected_slot).id if inventory != null else selected_slot + 1

func select_function(function: int) -> void:
	interaction_blocked = true
	mining_time = 0.0
	if sitting:
		if not _stand_up():
			return
		if function == 1:
			return
	active_function = clampi(function, 0, 1)
	if active_function == 1:
		if target_id <= 0:
			message.emit("坐下功能：瞄准方块，按左键坐到顶面")
		else:
			_sit_on_target()
	else:
		message.emit("挖掘 / 建造：左键挖掘，右键放置")
	function_changed.emit(active_function, sitting)

func _can_occupy(pos: Vector3, seated: bool) -> bool:
	var height: float = 1.3 if seated else 1.8
	var minimum := Vector3i((pos + Vector3(-0.36, 0.005, -0.36)).floor())
	var maximum := Vector3i((pos + Vector3(0.36, height - 0.005, 0.36)).floor())
	for x in range(minimum.x, maximum.x + 1):
		for y in range(minimum.y, maximum.y + 1):
			for z in range(minimum.z, maximum.z + 1):
				if world.get_block(Vector3i(x, y, z)) != 0:
					return false
	occupancy_query.shape = sitting_shape if seated else standing_shape
	occupancy_query.transform = Transform3D(Basis.IDENTITY, pos + Vector3(0, height * 0.5, 0))
	return get_world_3d().direct_space_state.intersect_shape(occupancy_query, 1).is_empty()

func _sit_on_target() -> bool:
	if target_id <= 0 or world.get_block(target_cell) == 0:
		return false
	var pos := Vector3(target_cell) + Vector3(0.5, 1.01, 0.5)
	if pos.distance_to(global_position + Vector3(0, 0.9, 0)) > REACH:
		message.emit("方块太远，请靠近后坐下")
		return false
	var facing := -rig.global_basis.z
	var feet: Vector3i = Vector3i((pos + facing * 0.68 + Vector3(0, 0.1, 0)).floor())
	if not _can_occupy(pos, true) or world.get_block(feet) != 0:
		message.emit("方块上方或前方空间不足，无法坐下")
		return false
	seat_cell = target_cell
	sitting = true
	swimming = false
	velocity = Vector3.ZERO
	global_position = pos
	collision.shape = sitting_shape
	collision.position.y = 0.65
	visual.position.y = -0.5625
	visual.rotation.y = rig.rotation.y
	visual.animate(0.0, 0.0, false, false, false, false, true)
	_update_camera_height()
	function_changed.emit(active_function, sitting)
	message.emit("已坐下 · F、WASD 或空格起身")
	return true

func _stand_up(force: bool = false) -> bool:
	var destination: Vector3 = global_position
	var found: bool = false
	for offset in [Vector3.ZERO, Vector3.RIGHT, Vector3.LEFT, Vector3.FORWARD, Vector3.BACK]:
		var candidate: Vector3 = global_position + offset
		if _can_occupy(candidate, false):
			destination = candidate
			found = true
			break
	if not found:
		if not force:
			message.emit("周围没有安全的起身空间")
			return false
		destination = world.get_spawn_position()
	sitting = false
	active_function = 0
	global_position = destination
	velocity = Vector3.ZERO
	collision.shape = standing_shape
	collision.position.y = 0.9
	visual.position.y = 0.0
	visual.animate(0.0, 0.0, false, false)
	_update_camera_height()
	interaction_blocked = true
	function_changed.emit(active_function, sitting)
	return true

## Sweep from the player's center to the entire over-shoulder camera position.
func _update_camera_height() -> void:
	rig.position = Vector3(0.0, 0.95 if sitting else (1.6 if first_person else 1.62), 0.0)
	arm.position = Vector3.ZERO
	arm.spring_length = 0.0 if first_person else CAMERA_DISTANCE
	# Keep the sweep origin inside the character's free space. Encode both
	# lateral shoulder offset and camera distance in the boom direction so a
	# side wall shortens them together, rather than embedding the pivot.
	arm.basis = Basis.IDENTITY if first_person else Basis(Quaternion(Vector3.BACK, CAMERA_OFFSET.normalized()))
	camera.basis = arm.basis.inverse()
	camera.position = Vector3.ZERO

func _physics_process(delta: float) -> void:
	if world == null or not controls_enabled:
		return
	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	if interaction_blocked and not Input.is_action_pressed("mine") and not Input.is_action_pressed("place"):
		interaction_blocked = false
	if sitting:
		if world.get_block(seat_cell) == 0:
			_stand_up(true)
		elif input.length_squared() > 0.0 or Input.is_action_just_pressed("jump"):
			_stand_up()
		if sitting:
			velocity = Vector3.ZERO
			mining_time = 0.0
			_resolve_camera_collision()
			_update_target()
			visual.animate(delta, 0.0, false, false, false, false, true)
			_update_debris(delta)
			_emit_status()
			return
	var direction := rig.global_basis * Vector3(input.x, 0, input.y)
	direction.y = 0.0
	var torso := global_position + Vector3(0, 0.85, 0)
	var was_swimming: bool = swimming
	var rising_out: bool = velocity.y > 0.0 and torso.y > world.SEA_LEVEL - 0.15 and not swimming
	var swim_threshold: float = 0.12 if swimming else -0.04
	swimming = torso.y < world.SEA_LEVEL + swim_threshold and world.is_water_at(torso) and not rising_out
	if swimming and not was_swimming:
		velocity.y = maxf(velocity.y, -1.5)
	submerged = world.is_water_at(global_position + Vector3(0, 1.45, 0))
	if swimming:
		var swim_speed: float = 6.0 if Input.is_action_pressed("sprint") else 4.2
		if submerged:
			direction = pitch.global_basis * Vector3(input.x, 0, input.y)
		var desired := direction * swim_speed
		var vertical: float = Input.get_axis("dive", "jump")
		if vertical != 0.0:
			desired.y = vertical * 3.4
		elif not submerged:
			desired.y = clampf((world.SEA_LEVEL - 1.25 - global_position.y) * 5.0, -1.8, 1.8)
		velocity = velocity.move_toward(desired, delta * 9.0)
		# Breach the surface with enough momentum to jump onto the shoreline.
		if vertical > 0.0 and torso.y >= world.SEA_LEVEL - 0.08:
			velocity.y = 8.0
			swimming = false
	else:
		var speed: float = 7.8 if Input.is_action_pressed("sprint") else 4.8
		velocity.x = move_toward(velocity.x, direction.x * speed, 24.0 * delta)
		velocity.z = move_toward(velocity.z, direction.z * speed, 24.0 * delta)
		if is_on_floor():
			velocity.y = 0.0
			if Input.is_action_just_pressed("jump"):
				velocity.y = 7.0
		else:
			velocity.y -= 18.0 * delta
	move_and_slide()
	if direction.length_squared() > 0.01:
		visual.rotation.y = lerp_angle(visual.rotation.y, atan2(-direction.x, -direction.z), minf(delta * 15.0, 1.0))
	if global_position.y < world.SEA_FLOOR - 5.0:
		global_position = world.get_spawn_position()
		velocity = Vector3.ZERO
		message.emit("已返回岛屿出生点")
	_resolve_camera_collision()
	_update_target()
	if active_function == 1 and not interaction_blocked and Input.is_action_just_pressed("mine"):
		_sit_on_target()
	place_delay = maxf(0.0, place_delay - delta)
	swing_timer = maxf(0.0, swing_timer - delta)
	_hit_spark_cooldown = maxf(0.0, _hit_spark_cooldown - delta)
	
	# 响应左键点击与长按，支持空挥和连续挥击交互
	if active_function == 0 and not sitting and not interaction_blocked:
		if Input.is_action_just_pressed("mine"):
			var complete_cycle: bool = ItemCatalog.is_tool_item(selected_item_id()) or ItemCatalog.is_weapon(selected_item_id())
			swing_timer = 0.06 if complete_cycle else 0.38
			if not complete_cycle and visual.swing <= 0.15:
				visual.swing_phase = 0.0
		elif Input.is_action_pressed("mine") and not ItemCatalog.is_tool_item(selected_item_id()) and not ItemCatalog.is_weapon(selected_item_id()):
			swing_timer = maxf(swing_timer, 0.16)
			
	var is_swinging: bool = active_function == 0 and not sitting and not interaction_blocked and (Input.is_action_pressed("mine") or swing_timer > 0.0)
	var is_mining_target: bool = is_swinging and (target_id > 0 or target_document != null)
	
	if is_swinging or visual.swing_cycle_running:
		visual.rotation.y = lerp_angle(visual.rotation.y, rig.rotation.y, minf(delta * 15.0, 1.0))
		
	if is_mining_target:
		mining_time += delta
		var held_id: int = selected_item_id()
		var speed_mult: float = ItemCatalog.get_mining_speed(held_id, target_id)
		var required_time: float = 0.35 if target_document != null else (Catalog.mine_time(target_id) / speed_mult)
		
		if mining_time >= required_time:
			_mine()
	else:
		mining_time = 0.0
		
	if active_function == 0 and not sitting and not interaction_blocked:
		if Input.is_action_just_pressed("place"):
			_place()
			place_delay = 0.25
		elif Input.is_action_pressed("place") and place_delay <= 0.0:
			_place()
			place_delay = 0.20
	var horizontal_speed: float = Vector2(velocity.x, velocity.z).length()
	var is_sprinting: bool = Input.is_action_pressed("sprint") and horizontal_speed > 5.0 and not swimming and not sitting
	var base_fov: float = 80.0 if first_person else 70.0
	var target_fov: float = base_fov + (7.5 if is_sprinting else 0.0)
	camera.fov = lerpf(camera.fov, target_fov, minf(delta * 8.0, 1.0))
	visual.animate(delta, horizontal_speed, not is_on_floor(), is_swinging, swimming, submerged, sitting, is_sprinting)
	if active_function == 0 and not interaction_blocked and visual.swing_contact and (target_id > 0 or target_document != null) and _hit_spark_cooldown <= 0.0:
		_hit_spark_cooldown = 0.28
		_spawn_hit_spark()
	
	# 第一人称手持物 3D 动力学姿态（视角惯性漂移、多流派定制挥击下砸、弹性质感放置与呼吸微震）
	if first_person and first_person_item != null and is_instance_valid(first_person_item) and first_person_item.visible:
		_update_first_person_motion(delta, horizontal_speed, is_swinging, visual.swing_phase, visual.place_time, is_mining_target)

	
	# 水花特效触发与动力学更新
	if is_instance_valid(world) and water_splash != null and is_instance_valid(water_splash):
		var sea_level: float = world.SEA_LEVEL
		var feet_y: float = global_position.y
		
		# 1. 涉水浅滩与水面游泳判定
		var in_water: bool = swimming or world.is_water_at(Vector3(global_position.x, sea_level - 0.1, global_position.z)) or world.is_water_at(Vector3(global_position.x, feet_y + 0.1, global_position.z))
		var is_on_water_surface: bool = in_water and (feet_y < sea_level) and (not submerged) and (horizontal_speed > 0.8)
		var is_fast_moving: bool = is_sprinting or (swimming and Input.is_action_pressed("sprint"))
		
		# 2. 从高处跃入水面的扑通浪花爆发 (Impact Burst)
		if _last_feet_y >= sea_level - 0.05 and feet_y < sea_level and velocity.y < -2.2:
			if in_water:
				water_splash.trigger_impact(sea_level, global_position, absf(velocity.y))
				
		_last_feet_y = feet_y
		
		# 3. 逐帧更新水花发射器方向与强度
		var move_dir := Vector3(velocity.x, 0, velocity.z).normalized()
		water_splash.update_splash(delta, is_on_water_surface, horizontal_speed, is_fast_moving, move_dir, sea_level, global_position)
	
	_update_debris(delta)
	_emit_status()

func _emit_status() -> void:
	var held_id: int = selected_item_id()
	var speed_mult: float = ItemCatalog.get_mining_speed(held_id, target_id)
	var max_time: float = 0.35 if target_document != null else (Catalog.mine_time(target_id) / speed_mult if target_id > 0 else 0.0)
	var progress: float = (mining_time / max_time) if max_time > 0.0 else 0.0
	water_status_changed.emit(swimming, submerged, world.is_water_at(camera.global_position), maxf(0.0, world.SEA_LEVEL - global_position.y - 1.45))
	
	var block_name: String = ""
	if target_document != null:
		block_name = ItemCatalog.title(target_document.item_id) + " · 左键挖掘回收 / R或右键打开"
	elif target_id > 0:
		block_name = Catalog.title(target_id)
		if ItemCatalog.is_tool_item(held_id) and speed_mult > 1.0:
			block_name += " [工具加速 ×%.1f]" % speed_mult
		var is_underwater: bool = is_instance_valid(world) and (float(target_cell.y) + 1.0 <= world.SEA_LEVEL)
		if is_underwater and not submerged:
			block_name += " (水下)"
	else:
		block_name = "瞄准方块开始建造"
		
	status_changed.emit(block_name, progress, first_person, mined, placed)

func _update_target() -> void:
	if sitting or get_tree().paused:
		return
	var previous := target_cell
	target_id = 0
	target_document = null
	outline.visible = false
	var center := get_viewport().get_visible_rect().size * 0.5
	query.from = camera.project_ray_origin(center)
	query.to = query.from + camera.project_ray_normal(center) * 12.0
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		mining_time = 0.0
		return
	var point: Vector3 = hit.position
	var normal: Vector3 = hit.normal
	if point.distance_to(global_position + Vector3(0, 1.2, 0)) > REACH:
		mining_time = 0.0
		return
	target_cell = Vector3i((point - normal * 0.01).floor())
	if hit.collider.has_meta("document"):
		target_document = hit.collider
		target_cell = target_document.support_cell
		if target_cell != previous:
			mining_time = 0.0
		return
	target_normal = Vector3i(normal.round())
	target_id = world.get_block(target_cell)
	if target_id <= 0:
		return
	if target_cell != previous:
		mining_time = 0.0
	outline.global_position = Vector3(target_cell) + Vector3.ONE * 0.5
	outline.visible = true

func _mine() -> void:
	if sitting:
		return
	if target_document != null:
		var doc: Node3D = target_document
		var doc_id: int = int(doc.get("item_id"))
		if doc_id <= 0:
			doc_id = 109
		var doc_pos: Vector3 = doc.global_position
		var doc_title: String = ItemCatalog.title(doc_id)
		
		var data: Dictionary = doc.save_data().duplicate(true)
		if data.get("blueprints", []).is_empty() and doc.contents.current != null and not doc.contents.current.voxels.is_empty():
			data["blueprints"] = [doc.contents.current.to_dictionary()]
		data["custom_name"] = doc.inventory_name()
		# Commit the pickup before notifying listeners or removing its world identity.
		if inventory == null or not inventory.add_document_item(doc_id, data):
			message.emit("背包已满，文档保留在原处")
			mining_time = 0.0
			return
		_spawn_debris(doc_pos, ItemCatalog.color(doc_id))
		document_mined.emit(doc)
		world.remove_document(doc)
		target_document = null
		message.emit("已回收：" + doc_title)
		
		mined += 1
		mining_time = 0.0
		return
	var cell := target_cell
	var id: int = target_id
	if inventory != null and not inventory.can_add_item(id, 1):
		message.emit("背包已满，方块保留在原处")
		mining_time = 0.0
		return
	if world.set_block(cell, 0):
		_spawn_debris(Vector3(cell) + Vector3.ONE * 0.5, Catalog.color(id))
		if inventory != null:
			if not inventory.add_item(id, 1):
				message.emit("背包已满，方块没有被拾取")
		mined += 1
	else:
		message.emit("岛屿底层是保护基岩")
	mining_time = 0.0

func _place() -> void:
	if sitting:
		return
	if target_document != null:
		document_requested.emit(target_document)
		return
	var id: int = selected_item_id()
	if ItemCatalog.is_document(id):
		if target_id <= 0 or target_normal != Vector3i.UP:
			message.emit("请瞄准方块顶面放置纸笔")
			return
		var pos := Vector3(target_cell) + Vector3(0.5, 1.005, 0.5)
		var occupied := AABB(global_position + Vector3(-0.36, 0, -0.36), Vector3(0.72, 1.8, 0.72))
		if occupied.intersects(AABB(pos + Vector3(-0.31, 0, -0.24), Vector3(0.62, 0.1, 0.48))):
			message.emit("请退后一点再放置纸笔")
			return
		var placed_doc = world.place_document(target_cell, id)
		if placed_doc != null:
			place_delay = maxf(place_delay, 0.25)
			# 如果手持槽位的图纸携带了保存的蓝图数据，完整恢复给新生成的蓝图实体
			if inventory != null and inventory.has_method("get_slot"):
				var slot_data: Dictionary = inventory.get_slot("bag", selected_slot)
				if inventory.is_unique_document(slot_data):
					placed_doc.restore_data(slot_data.duplicate(true))
					if slot_data.has("custom_name"):
						placed_doc.set_meta("inventory_custom_name", slot_data.custom_name)
				inventory.consume_slot(selected_slot)
			placed += 1
			visual.play_place()
			message.emit("纸笔已放置 · 瞄准后按 R 打开")
		return
	if ItemCatalog.is_equipment(id):
		if inventory != null and inventory.equip_from_bag(selected_slot):
			message.emit("已穿戴：" + ItemCatalog.title(id))
		return
	if not ItemCatalog.is_block(id):
		return
	if target_id <= 0:
		return
	var cell := target_cell + target_normal
	if not world.contains(cell) or world.get_block(cell) != 0:
		message.emit("这里没有可用的建造空间")
		return
	var block_box := AABB(Vector3(cell), Vector3.ONE)
	var player_box := AABB(global_position + Vector3(-0.36, 0.01, -0.36), Vector3(0.72, 1.78, 0.72))
	if block_box.intersects(player_box):
		message.emit("方块太靠近角色，请稍微退后")
		return
	if world.set_block(cell, id):
		place_delay = maxf(place_delay, 0.20)
		if inventory != null:
			inventory.consume_slot(selected_slot)
		placed += 1
		visual.rotation.y = rig.rotation.y
		visual.play_place()

func _create_outline() -> void:
	outline = Node3D.new()
	add_child(outline)
	outline.top_level = true
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color("fff1bf")
	var corners: Array[Vector3] = []
	for x in [-0.506, 0.506]:
		for y in [-0.506, 0.506]:
			for z in [-0.506, 0.506]:
				corners.append(Vector3(x, y, z))
	for a in range(8):
		for b in range(a + 1, 8):
			var difference: Vector3 = (corners[a] - corners[b]).abs()
			if int(difference.x > 0.0) + int(difference.y > 0.0) + int(difference.z > 0.0) != 1:
				continue
			var mesh := BoxMesh.new()
			mesh.size = difference + Vector3.ONE * 0.016
			var edge := MeshInstance3D.new()
			edge.mesh = mesh
			edge.material_override = material
			edge.position = (corners[a] + corners[b]) * 0.5
			outline.add_child(edge)
	outline.visible = false

func _spawn_debris(pos: Vector3, color: Color) -> void:
	const MAX_DEBRIS: int = 135
	if debris.size() >= MAX_DEBRIS:
		for i in range(27):
			if debris.size() > 0:
				debris[0].node.queue_free()
				debris.remove_at(0)
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	for i in range(9):
		var fragment := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3.ONE * 0.12
		fragment.mesh = mesh
		fragment.material_override = material
		effects_root.add_child(fragment)
		fragment.global_position = pos + Vector3(randf_range(-0.3, 0.3), randf_range(-0.2, 0.3), randf_range(-0.3, 0.3))
		debris.append({"node": fragment, "velocity": Vector3(randf_range(-2.5, 2.5), randf_range(1.0, 3.0), randf_range(-2.5, 2.5)), "age": 0.0})

func _update_debris(delta: float) -> void:
	for i in range(debris.size() - 1, -1, -1):
		var item: Dictionary = debris[i]
		item.age += delta
		if item.age >= 0.7:
			item.node.queue_free()
			debris.remove_at(i)
			continue
		item.velocity.y -= 9.0 * delta
		item.node.position += item.velocity * delta
		item.node.rotate_x(delta * 5.0)
		item.node.rotate_z(delta * 3.0)
		item.node.scale = Vector3.ONE * (1.0 - item.age / 0.7)

## 在挖掘敲击瞬间产生真实的石屑/木屑打击飞溅微粒
func _spawn_hit_spark() -> void:
	if target_id <= 0 and target_document == null:
		return
	var c_color: Color = ItemCatalog.color(target_document.item_id) if target_document != null else Catalog.color(target_id)
	var hit_surface: Vector3 = Vector3(target_cell) + Vector3(0.5, 0.5, 0.5) + Vector3(target_normal) * 0.48
	var material := StandardMaterial3D.new()
	material.albedo_color = c_color.lightened(0.2)
	for i in range(2):
		var spark := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3.ONE * 0.065
		spark.mesh = mesh
		spark.material_override = material
		effects_root.add_child(spark)
		spark.global_position = hit_surface + Vector3(randf_range(-0.15, 0.15), randf_range(-0.15, 0.15), randf_range(-0.15, 0.15))
		var bounce_dir := (Vector3(target_normal) + Vector3(randf_range(-0.5, 0.5), randf_range(0.2, 0.8), randf_range(-0.5, 0.5))).normalized()
		debris.append({
			"node": spark,
			"velocity": bounce_dir * randf_range(1.8, 3.2),
			"age": 0.0
		})

## 计算当前手持物品对应的第一人称基准空间变换（等角精致手办方块、自然手持工具与图纸）
func _get_fp_base_transform(held_id: int) -> Dictionary:
	var base_pos := Vector3(0.36, -0.23, -0.54)
	var base_rot := Vector3(0.1, -0.25, 0.1)
	
	if ItemCatalog.is_block(held_id):
		# 方块：黄金等角透视（Pitch 25度展露顶面，Yaw -42度展露正面与侧面，Roll 12度，避开底栏）
		base_pos = Vector3(0.33, -0.19, -0.49)
		base_rot = Vector3(deg_to_rad(25.0), deg_to_rad(-42.0), deg_to_rad(12.0))

	elif ItemCatalog.is_tool_item(held_id):
		# 工具类：手柄自右下角自然伸出，刃部指向前方，不挡准星
		if ItemCatalog.is_pickaxe(held_id):
			base_pos = Vector3(0.38, -0.27, -0.52)
			base_rot = Vector3(deg_to_rad(6.0), deg_to_rad(-16.0), deg_to_rad(2.0))
		elif ItemCatalog.is_axe(held_id):
			base_pos = Vector3(0.38, -0.27, -0.52)
			base_rot = Vector3(deg_to_rad(8.0), deg_to_rad(-18.0), deg_to_rad(-2.0))
		elif ItemCatalog.is_shovel(held_id):
			base_pos = Vector3(0.38, -0.27, -0.52)
			base_rot = Vector3(deg_to_rad(4.0), deg_to_rad(-14.0), deg_to_rad(4.0))
		else:
			base_pos = Vector3(0.38, -0.27, -0.52)
			base_rot = Vector3(deg_to_rad(6.0), deg_to_rad(-16.0), deg_to_rad(2.0))
	elif held_id in [108, 109]:
		# 纸笔/图纸：双手微倾捧读姿态
		base_pos = Vector3(0.32, -0.22, -0.48)
		base_rot = Vector3(deg_to_rad(22.0), deg_to_rad(-24.0), deg_to_rad(6.0))
	elif ItemCatalog.is_weapon(held_id):
		# 武器类：剑刃向前方挺拔斜指，十字剑格微挑，视线开阔通透
		base_pos = Vector3(0.36, -0.24, -0.52)
		base_rot = Vector3(deg_to_rad(12.0), deg_to_rad(-20.0), deg_to_rad(5.0))
		
	return {"pos": base_pos, "rot": base_rot}

## 第一人称视角手持物动态变换（视角惯性漂移、多流派定制挥击下砸、弹性质感放置与打击微震）
func _update_first_person_motion(delta: float, horizontal_speed: float, is_swinging: bool, s_phase: float, p_time: float, is_mining_target: bool = false) -> void:
	var held_id: int = selected_item_id()
	var base_trans := _get_fp_base_transform(held_id)
	var base_pos: Vector3 = base_trans.pos
	var base_rot: Vector3 = base_trans.rot
	
	var motion_offset := Vector3.ZERO
	var rot_offset := Vector3.ZERO
	
	# 1. 视角转动惯性漂移（Mouse Look Sway & Tilt）
	fp_look_sway = fp_look_sway.lerp(Vector2.ZERO, minf(delta * 9.0, 1.0))
	motion_offset += Vector3(fp_look_sway.x * 0.5, fp_look_sway.y * 0.4, 0.0)
	rot_offset += Vector3(fp_look_sway.y * 0.7, fp_look_sway.x * 1.0, -fp_look_sway.x * 1.4)
	
	# 2. 步行动力学呼吸摇晃（Bobbing & Idle Breathing）
	var run_factor: float = clampf(horizontal_speed / 4.8, 0.0, 1.0)
	var bob_x: float = cos(visual.phase) * 0.012 * run_factor
	var bob_y: float = -absf(sin(visual.phase)) * 0.016 * run_factor
	var bob_roll: float = -cos(visual.phase) * 0.022 * run_factor
	var idle_bob: float = sin(visual.idle_phase * 1.5) * 0.0025 * (1.0 - run_factor)
	motion_offset += Vector3(bob_x, bob_y + idle_bob, 0.0)
	rot_offset.z += bob_roll
	
	# 3. 放置方块工匠微沉按入与弹簧回弹手势（Craftsman Settle & Micro Spring，彻底消灭直拳推手）
	if p_time > 0.0:
		var p: float = 1.0 - clampf(p_time / 0.20, 0.0, 1.0)
		if p < 0.45:
			var t: float = p / 0.45
			var push_w: float = sin(t * PI * 0.5)
			# 向下沉按为主，微幅向前贴平（彻底消除冲拳向前捅）
			motion_offset += Vector3(0.008 * push_w, -0.065 * push_w, -0.035 * push_w)
			rot_offset += Vector3(0.18 * push_w, -0.03 * push_w, 0.02 * push_w)
		else:
			var t: float = (p - 0.45) / 0.55
			var spring: float = sin(t * PI) * 0.012 * (1.0 - t)
			var settle: float = (1.0 - t)
			motion_offset += Vector3(0.008 * settle, -0.065 * settle + spring * 0.8, -0.035 * settle)
			rot_offset += Vector3(0.18 * settle, -0.03 * settle, 0.02 * settle)
	
	# 4. 多流派深度定制挥击动作（Swing Animation）
	if visual.swing > 0.01:
		var s_weight: float = visual.swing
		var u: float = fposmod(s_phase, TAU) / TAU
		
		if ItemCatalog.is_tool_item(held_id):
			var motion: Dictionary = ToolSwing.sample(held_id, u)
			motion_offset += Vector3(motion.fp_position) * s_weight
			rot_offset += Vector3(motion.fp_rotation) * s_weight
		elif ItemCatalog.is_weapon(held_id):
			var motion: Dictionary = WeaponSwing.sample(held_id, u)
			motion_offset += Vector3(motion.fp_position) * s_weight
			rot_offset += Vector3(motion.fp_rotation) * s_weight
		else:
			# 流派 E：手持方块 / 纸笔 / 其它 —— 自然下扣敲击（Downward Hammer Tap，彻底消灭冲拳打人感）
			if u < 0.28:
				var t: float = u / 0.28
				var w: float = (1.0 - cos(t * PI)) * 0.5
				motion_offset += Vector3(0.015 * w, 0.035 * w, 0.015 * w) * s_weight
				rot_offset += Vector3(0.32 * w, -0.08 * w, 0.10 * w) * s_weight
			elif u < 0.55:
				var t: float = (u - 0.28) / 0.27
				var s: float = pow(t, 1.8)
				motion_offset += Vector3(lerpf(0.015, -0.02, s), lerpf(0.035, -0.07, s), lerpf(0.015, -0.04, s)) * s_weight
				rot_offset += Vector3(lerpf(0.32, -0.42, s), lerpf(-0.08, 0.12, s), lerpf(0.10, -0.15, s)) * s_weight
			else:
				var t: float = (u - 0.55) / 0.45
				var r: float = (1.0 - cos(t * PI)) * 0.5
				motion_offset += Vector3(lerpf(-0.02, 0.0, r), lerpf(-0.07, 0.0, r), lerpf(-0.04, 0.0, r)) * s_weight
				rot_offset += Vector3(lerpf(-0.42, 0.0, r), lerpf(0.12, 0.0, r), lerpf(-0.15, 0.0, r)) * s_weight
				
		# A short, decaying tool impact follows the shared contact phase.
		if is_mining_target and (ItemCatalog.is_tool_item(held_id) or ItemCatalog.is_weapon(held_id)):
			var hit_t := (u - ToolSwing.IMPACT_PHASE) / 0.10
			if hit_t >= 0.0 and hit_t <= 1.0:
				var impulse := sin(hit_t * PI) * (1.0 - hit_t)
				motion_offset += Vector3(0.0, -0.007, 0.005) * impulse
				rot_offset.x += 0.022 * impulse
		elif is_mining_target and u >= 0.54 and u <= 0.68:
			motion_offset += Vector3(randf_range(-0.003, 0.003), randf_range(-0.003, 0.003), randf_range(-0.003, 0.003))
			rot_offset += Vector3(randf_range(-0.02, 0.02), randf_range(-0.02, 0.02), randf_range(-0.02, 0.02))
	
	first_person_item.position = first_person_item.position.lerp(base_pos + motion_offset, minf(delta * 24.0, 1.0))
	first_person_item.rotation = first_person_item.rotation.lerp(base_rot + rot_offset, minf(delta * 24.0, 1.0))

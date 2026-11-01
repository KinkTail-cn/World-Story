extends Node3D

const CHARACTER_SHADER = preload("res://shaders/character.gdshader")
const HELD_BLOCK = preload("res://scenes/HeldBlock.tscn")
const EQUIPMENT_VISUALS = preload("res://scripts/player/EquipmentVisuals.gd")
const ItemCatalog = preload("res://scripts/inventory/ItemCatalog.gd")
const ToolSwing = preload("res://scripts/player/ToolSwing.gd")
const WeaponSwing = preload("res://scripts/player/WeaponSwing.gd")
const PALM_POSITION := Vector3(0, -0.225, 0)
const BLOCK_HOLD_POSITION := Vector3(0.12, -0.225, -0.18)

var left_arm: Node3D
var right_arm: Node3D
var left_forearm: Node3D
var right_forearm: Node3D
var left_leg: Node3D
var right_leg: Node3D
var left_lower_leg: Node3D
var right_lower_leg: Node3D
var body: Node3D
var head: Node3D
var phase: float = 0.0
var swing: float = 0.0
var held_item: Node3D
var swing_phase: float = 0.0
var place_time: float = 0.0
var equipment_visuals: Node3D
var swim_phase: float = 0.0
var idle_phase: float = 0.0
var run_blend: float = 0.0
var sprint_blend: float = 0.0
var swing_cycle_running: bool = false
var swing_cycle_time: float = 0.0
var swing_contact: bool = false

func _ready() -> void:
	var skin := _material("f5d3b0")
	var hair := _material("563e3d")
	var tunic := _material("4f98aa")
	var cream := _material("fff0cf")
	var leather := _material("78513f")
	var pants := _material("384862")
	body = Node3D.new()
	add_child(body)
	_box(body, Vector3(0, 1.0125, 0), Vector3(0.45, 0.675, 0.225), tunic)
	_box(body, Vector3(0, 0.715, 0), Vector3(0.46, 0.08, 0.24), leather)
	_box(body, Vector3(0, 0.715, -0.13), Vector3(0.09, 0.07, 0.025), cream)
	head = Node3D.new()
	body.add_child(head)
	_box(head, Vector3(0, 1.575, 0), Vector3(0.45, 0.45, 0.45), skin)
	_box(head, Vector3(0, 1.765, 0), Vector3(0.47, 0.11, 0.47), hair)
	_box(head, Vector3(0, 1.575, 0.22), Vector3(0.47, 0.3, 0.05), hair)
	for x in [-0.225, 0.225]:
		_box(head, Vector3(x, 1.66, 0), Vector3(0.04, 0.19, 0.46), hair)
	_box(head, Vector3(-0.09, 1.69, -0.23), Vector3(0.28, 0.1, 0.04), hair)
	var eye := _material("304354")
	for x in [-0.105, 0.105]:
		_box(head, Vector3(x, 1.57, -0.23), Vector3(0.1, 0.065, 0.015), cream)
		_box(head, Vector3(x, 1.57, -0.241), Vector3(0.045, 0.065, 0.01), eye)
	_box(head, Vector3(0, 1.45, -0.23), Vector3(0.08, 0.018, 0.015), leather)
	for part in head.get_children():
		part.position.y -= 1.575
	head.position.y = 1.575
	_box(body, Vector3(0, 1.325, 0), Vector3(0.47, 0.055, 0.25), cream)
	_box(body, Vector3(-0.13, 1.18, -0.13), Vector3(0.09, 0.24, 0.025), cream)
	
	# 手臂骨骼系统（大臂 + 前臂手肘关节）
	left_arm = Node3D.new()
	left_arm.position = Vector3(-0.3375, 1.35, 0)
	body.add_child(left_arm)
	_box(left_arm, Vector3(0, -0.17, 0), Vector3(0.225, 0.34, 0.225), tunic)
	
	left_forearm = Node3D.new()
	left_forearm.position = Vector3(0, -0.34, 0)
	left_arm.add_child(left_forearm)
	_box(left_forearm, Vector3(0, -0.07, 0), Vector3(0.225, 0.14, 0.225), tunic)
	_box(left_forearm, Vector3(0, -0.225, 0), Vector3(0.227, 0.195, 0.227), skin)
	
	right_arm = Node3D.new()
	right_arm.position = Vector3(0.3375, 1.35, 0)
	body.add_child(right_arm)
	_box(right_arm, Vector3(0, -0.17, 0), Vector3(0.225, 0.34, 0.225), tunic)
	
	right_forearm = Node3D.new()
	right_forearm.position = Vector3(0, -0.34, 0)
	right_arm.add_child(right_forearm)
	_box(right_forearm, Vector3(0, -0.07, 0), Vector3(0.225, 0.14, 0.225), tunic)
	_box(right_forearm, Vector3(0, -0.225, 0), Vector3(0.227, 0.195, 0.227), skin)
	
	# 腿部骨骼系统（大腿 + 小腿膝盖关节）
	left_leg = Node3D.new()
	left_leg.position = Vector3(-0.1125, 0.675, 0)
	body.add_child(left_leg)
	_box(left_leg, Vector3(0, -0.17, 0), Vector3(0.215, 0.34, 0.225), pants)
	
	left_lower_leg = Node3D.new()
	left_lower_leg.position = Vector3(0, -0.34, 0)
	left_leg.add_child(left_lower_leg)
	_box(left_lower_leg, Vector3(0, -0.0775, 0), Vector3(0.215, 0.155, 0.225), pants)
	_box(left_lower_leg, Vector3(0, -0.245, 0), Vector3(0.217, 0.18, 0.255), leather)
	
	right_leg = Node3D.new()
	right_leg.position = Vector3(0.1125, 0.675, 0)
	body.add_child(right_leg)
	_box(right_leg, Vector3(0, -0.17, 0), Vector3(0.215, 0.34, 0.225), pants)
	
	right_lower_leg = Node3D.new()
	right_lower_leg.position = Vector3(0, -0.34, 0)
	right_leg.add_child(right_lower_leg)
	_box(right_lower_leg, Vector3(0, -0.0775, 0), Vector3(0.215, 0.155, 0.225), pants)
	_box(right_lower_leg, Vector3(0, -0.245, 0), Vector3(0.217, 0.18, 0.255), leather)
	
	held_item = HELD_BLOCK.instantiate()
	held_item.position = BLOCK_HOLD_POSITION
	right_forearm.add_child(held_item)
	equipment_visuals = EQUIPMENT_VISUALS.new()
	add_child(equipment_visuals)

func set_held_block(id: int) -> void:
	if held_item.block_id != id:
		swing_cycle_running = false
		swing_cycle_time = 0.0
		swing_phase = 0.0
		swing = 0.0
		swing_contact = false
	held_item.position = PALM_POSITION if ItemCatalog.is_tool_item(id) or ItemCatalog.is_weapon(id) else BLOCK_HOLD_POSITION
	held_item.set_block(id)
	held_item.update_third_person_grip(body.global_basis, swing, _compute_swing_motion().get("grip_rotation"))

func play_place() -> void:
	place_time = 0.25

func animate(delta: float, speed: float, airborne: bool, mining: bool, swimming: bool = false, submerged: bool = false, sitting: bool = false, sprinting: bool = false) -> void:
	equipment_visuals.update_motion(delta, speed, airborne, swimming, sitting)
	var previous_left: Vector3 = left_arm.rotation
	var previous_right: Vector3 = right_arm.rotation
	
	# 1. 坐下姿态（完全保持原有物理与自动化测试断言规范）
	if sitting:
		swing_cycle_running = false
		swing_cycle_time = 0.0
		swing_contact = false
		body.position = Vector3.ZERO
		body.rotation = Vector3.ZERO
		left_leg.rotation = Vector3(PI * 0.5, 0.0, 0.0)
		right_leg.rotation = Vector3(PI * 0.5, 0.0, 0.0)
		if left_lower_leg != null:
			left_lower_leg.rotation = Vector3(-PI * 0.5, 0.0, 0.0)
		if right_lower_leg != null:
			right_lower_leg.rotation = Vector3(-PI * 0.5, 0.0, 0.0)
		left_arm.rotation = Vector3(0.5, 0, -0.05)
		right_arm.rotation = Vector3(0.5, 0, 0.05)
		if left_forearm != null:
			left_forearm.rotation = Vector3(0.25, 0.0, 0.0)
		if right_forearm != null:
			right_forearm.rotation = Vector3(0.25, 0.0, 0.0)
		swing = 0.0
		place_time = 0.0
		head.rotation = Vector3.ZERO
		run_blend = 0.0
		sprint_blend = 0.0
		_update_held_item(delta)
		return
	_advance_swing(delta, mining)
	
	# 2. 游泳姿态（完全保持原有水中游动与潜水管线）
	if swimming:
		run_blend = 0.0
		sprint_blend = 0.0
		var moving_in_water: bool = speed > 0.3 or submerged
		swim_phase += delta * (6.0 if speed > 0.3 else 2.5)
		var stroke: float = sin(swim_phase)
		var tilt: float = -1.35 if submerged else (-1.2 if speed > 0.3 else -0.15)
		body.rotation.x = lerpf(body.rotation.x, tilt, minf(delta * 8.0, 1.0))
		body.rotation.y = lerpf(body.rotation.y, 0.0, minf(delta * 8.0, 1.0))
		body.rotation.z = lerpf(body.rotation.z, 0.0, minf(delta * 8.0, 1.0))
		body.position = Vector3(0, 0.9, 0) + Basis(Vector3.RIGHT, body.rotation.x) * Vector3(0, -0.9, 0)
		body.position.y += 0.15
		
		var left_pose := Vector3(2.05 + stroke * 0.95, -0.2 * cos(swim_phase), -0.30 - 0.20 * cos(swim_phase)) if moving_in_water else Vector3(0.7 + stroke * 0.15, -0.1, -0.3)
		var right_pose := Vector3(2.05 - stroke * 0.95, 0.2 * cos(swim_phase), 0.30 - 0.20 * cos(swim_phase)) if moving_in_water else Vector3(0.7 - stroke * 0.15, 0.1, 0.3)
		left_arm.rotation = previous_left.lerp(left_pose, minf(delta * 12.0, 1.0))
		right_arm.rotation = previous_right.lerp(right_pose, minf(delta * 12.0, 1.0))
		left_leg.rotation = Vector3(sin(swim_phase * 1.7) * (0.22 if moving_in_water else 0.12), 0, 0)
		right_leg.rotation = Vector3(-left_leg.rotation.x, 0, 0)
		
		# 游泳时手肘与小腿划水弯曲
		if left_forearm != null:
			left_forearm.rotation = Vector3(0.45 + stroke * 0.25, 0, 0)
		if right_forearm != null:
			right_forearm.rotation = Vector3(0.45 - stroke * 0.25, 0, 0)
		if left_lower_leg != null:
			left_lower_leg.rotation = Vector3(-0.25 - absf(sin(swim_phase * 1.7)) * 0.2, 0, 0)
		if right_lower_leg != null:
			right_lower_leg.rotation = Vector3(-0.25 - absf(cos(swim_phase * 1.7)) * 0.2, 0, 0)
			
		head.rotation.x = lerpf(head.rotation.x, 0.55 if submerged else (0.95 if moving_in_water else 0.12), minf(delta * 8.0, 1.0))
		head.rotation.y = lerpf(head.rotation.y, 0.0, minf(delta * 8.0, 1.0))
		if (ItemCatalog.is_tool_item(held_item.block_id) or ItemCatalog.is_weapon(held_item.block_id)) and swing > 0.01:
			var motion := _compute_swing_motion()
			right_arm.rotation = right_arm.rotation.lerp(Vector3(motion.arm_x, motion.arm_y, motion.arm_z), swing)
			right_forearm.rotation.x = lerpf(right_forearm.rotation.x, motion.elbow, swing)
			_update_held_item(delta, swing, 0.0, motion.grip_rotation)
		else:
			_update_held_item(delta)
		return
	
	# 3. 动力学与运动融合权重
	place_time = maxf(0.0, place_time - delta)
	idle_phase += delta * 2.4
	
	var is_moving: bool = speed > 0.15 and not airborne
	var target_run: float = clampf(speed / 4.8, 0.0, 1.0) if is_moving else 0.0
	var is_sprint: bool = is_moving and (sprinting or speed > 5.2)
	var target_sprint: float = clampf((speed - 4.6) / 2.8, 0.0, 1.0) if is_sprint else 0.0
	
	run_blend = lerpf(run_blend, target_run, minf(delta * 10.0, 1.0))
	sprint_blend = lerpf(sprint_blend, target_sprint, minf(delta * 8.0, 1.0))
	
	if is_moving:
		var step_freq: float = lerpf(speed * 2.2, speed * 2.3 + 1.6, sprint_blend)
		phase += delta * step_freq
	
	# 4. 滞空状态（Airborne / 跳跃）
	var s_motion: Dictionary = _compute_swing_motion()
	if airborne:
		run_blend = lerpf(run_blend, 0.0, minf(delta * 6.0, 1.0))
		sprint_blend = lerpf(sprint_blend, 0.0, minf(delta * 6.0, 1.0))
		body.rotation.x = lerpf(body.rotation.x, -0.08 + s_motion.body_pitch * swing * 0.5, minf(delta * 8.0, 1.0))
		body.rotation.y = lerpf(body.rotation.y, s_motion.body_yaw * swing * 0.5, minf(delta * 8.0, 1.0))
		body.rotation.z = lerpf(body.rotation.z, 0.0, minf(delta * 8.0, 1.0))
		body.position = Vector3(0, 0.9, 0) + Basis.from_euler(body.rotation) * Vector3(0, -0.9, 0)
		
		left_leg.rotation = Vector3(-0.35, 0.0, -0.02)
		right_leg.rotation = Vector3(0.40, 0.0, 0.02)
		if left_lower_leg != null:
			left_lower_leg.rotation = Vector3(-0.65, 0, 0)
		if right_lower_leg != null:
			right_lower_leg.rotation = Vector3(-0.25, 0, 0)
		
		var jump_left_arm := Vector3(0.38, -0.05, -0.22)
		var jump_right_arm := Vector3(0.38, 0.05, 0.22)
		if mining or place_time > 0.0 or swing > 0.05:
			jump_right_arm.x = lerpf(0.38, s_motion.arm_x, swing)
			jump_right_arm.y = s_motion.arm_y * swing
			jump_right_arm.z = lerpf(0.22, s_motion.arm_z, swing)
			jump_left_arm.x += s_motion.left_counter * swing
		left_arm.rotation = left_arm.rotation.lerp(jump_left_arm, minf(delta * 10.0, 1.0))
		right_arm.rotation = right_arm.rotation.lerp(jump_right_arm, minf(delta * 18.0, 1.0))
		if left_forearm != null:
			left_forearm.rotation = Vector3(0.45, 0, 0)
		if right_forearm != null:
			var target_jump_elbow: float = 0.45 if (not mining and place_time <= 0.0 and swing <= 0.05) else s_motion.elbow
			right_forearm.rotation = Vector3(target_jump_elbow, 0, 0)
			
		head.rotation.x = lerpf(head.rotation.x, 0.06 + s_motion.head_pitch * swing, minf(delta * 8.0, 1.0))
		head.rotation.y = lerpf(head.rotation.y, 0.0, minf(delta * 8.0, 1.0))
		_update_held_item(delta, swing, s_motion.wrist_pitch * swing, s_motion.get("grip_rotation"))
		return
	
	# 5. 地面陆地移动（行走与跑步动力学优化：消除左右晃动，重心沉稳前冲）
	var target_tilt: float = lerpf(-0.09, -0.26, sprint_blend) * run_blend
	var target_yaw: float = sin(phase) * lerpf(0.008, 0.018, sprint_blend) * run_blend
	var target_roll: float = cos(phase) * lerpf(0.003, 0.008, sprint_blend) * run_blend
	
	var base_hip_pos: Vector3 = Vector3(0, 0.9, 0) + Basis.from_euler(body.rotation) * Vector3(0, -0.9, 0)
	var idle_bob: float = sin(idle_phase) * 0.006 * (1.0 - run_blend)
	var run_bounce: float = absf(sin(phase)) * lerpf(0.026, 0.046, sprint_blend) * run_blend
	body.position = base_hip_pos + Vector3(0, idle_bob + run_bounce + s_motion.hip_drop * swing, 0)
	
	# 双腿动力学：大腿前后迈步与侧展微调，保持中轴平稳扎实
	var leg_sin: float = sin(phase)
	var left_kick: float = maxf(0.0, -leg_sin) * 0.14 * sprint_blend
	var right_kick: float = maxf(0.0, leg_sin) * 0.14 * sprint_blend
	var leg_amp: float = lerpf(0.60, 0.88, sprint_blend)
	
	var target_left_leg_x: float = (leg_sin * leg_amp - left_kick) * run_blend
	var target_right_leg_x: float = (-leg_sin * leg_amp - right_kick) * run_blend
	var target_left_leg_z: float = -0.015 * run_blend
	var target_right_leg_z: float = 0.015 * run_blend
	
	left_leg.rotation.x = lerpf(left_leg.rotation.x, target_left_leg_x, minf(delta * 15.0, 1.0))
	right_leg.rotation.x = lerpf(right_leg.rotation.x, target_right_leg_x, minf(delta * 15.0, 1.0))
	left_leg.rotation.z = lerpf(left_leg.rotation.z, target_left_leg_z, minf(delta * 10.0, 1.0))
	right_leg.rotation.z = lerpf(right_leg.rotation.z, target_right_leg_z, minf(delta * 10.0, 1.0))
	left_leg.rotation.y = lerpf(left_leg.rotation.y, 0.0, minf(delta * 10.0, 1.0))
	right_leg.rotation.y = lerpf(right_leg.rotation.y, 0.0, minf(delta * 10.0, 1.0))
	
	# 膝盖弯曲动力学
	var left_back_knee: float = maxf(0.0, -leg_sin) * lerpf(0.55, 1.20, sprint_blend)
	var left_front_knee: float = maxf(0.0, leg_sin) * lerpf(0.18, 0.42, sprint_blend)
	var target_left_knee: float = -(left_back_knee + left_front_knee + 0.06) * run_blend - 0.03 * (1.0 - run_blend)
	
	var right_back_knee: float = maxf(0.0, leg_sin) * lerpf(0.55, 1.20, sprint_blend)
	var right_front_knee: float = maxf(0.0, -leg_sin) * lerpf(0.18, 0.42, sprint_blend)
	var target_right_knee: float = -(right_back_knee + right_front_knee + 0.06) * run_blend - 0.03 * (1.0 - run_blend)
	
	if left_lower_leg != null:
		left_lower_leg.rotation.x = lerpf(left_lower_leg.rotation.x, target_left_knee, minf(delta * 18.0, 1.0))
		left_lower_leg.rotation.y = 0.0
		left_lower_leg.rotation.z = 0.0
	if right_lower_leg != null:
		right_lower_leg.rotation.x = lerpf(right_lower_leg.rotation.x, target_right_knee, minf(delta * 18.0, 1.0))
		right_lower_leg.rotation.y = 0.0
		right_lower_leg.rotation.z = 0.0
	
	# 双臂大臂动力学
	var arm_sin: float = sin(phase)
	var arm_amp: float = lerpf(0.52, 0.92, sprint_blend)
	var base_arm_x: float = lerpf(0.0, 0.22, sprint_blend) * run_blend
	var idle_arm_x: float = sin(idle_phase) * 0.025 * (1.0 - run_blend)
	var target_left_arm_x: float = (-arm_sin * arm_amp + base_arm_x) * run_blend + idle_arm_x
	var target_right_arm_x: float = (arm_sin * arm_amp + base_arm_x) * run_blend + idle_arm_x
	var target_left_arm_z: float = lerpf(-0.05, -0.055, run_blend)
	var target_right_arm_z: float = lerpf(0.05, 0.055, run_blend)
	var target_left_arm_y: float = 0.0
	var target_right_arm_y: float = 0.0
	
	# Keep long-item grips below the face, with a small running sway.
	var has_held: bool = held_item != null and held_item.visible
	var long_item: bool = has_held and (held_item.tool_visual != null or held_item.weapon_visual != null)
	if has_held and not mining and place_time <= 0.0 and swing <= 0.05:
		target_right_arm_x = lerpf(0.48, 0.58 + arm_sin * 0.06 * sprint_blend, run_blend) if long_item else lerpf(0.68, 0.92 + arm_sin * 0.22 * sprint_blend, run_blend)
		target_right_arm_z = 0.08 if long_item else 0.06
	
	# 方块放置动作权重（柔和工匠手势：单手微俯轻按下按，消除冲拳）
	var place_blend: float = sin(clampf(place_time / 0.22, 0.0, 1.0) * PI)
	var action_weight: float = clampf(swing + place_blend, 0.0, 1.0)
	
	# 融合躯干力量协同发力（劈砍沉腰扭胯，放置微俯专注）
	var torso_pitch: float = s_motion.body_pitch * swing - 0.045 * place_blend
	body.rotation.x = lerpf(body.rotation.x, target_tilt + torso_pitch, minf(delta * 12.0, 1.0))
	body.rotation.y = lerpf(body.rotation.y, target_yaw + s_motion.body_yaw * swing, minf(delta * 12.0, 1.0))
	body.rotation.z = lerpf(body.rotation.z, target_roll, minf(delta * 12.0, 1.0))
	
	# 融合大臂与左臂对抗平衡（下劈时左臂后展保持重心，放置时平稳）
	target_left_arm_x += s_motion.left_counter * swing
	
	# 计算大臂的目标姿态（根据挥击与放置权重平滑过渡）
	var target_act_arm_x: float = s_motion.arm_x if swing > 0.02 else (0.78 + place_blend * 0.16)
	var target_act_arm_y: float = s_motion.arm_y if swing > 0.02 else 0.0
	var target_act_arm_z: float = s_motion.arm_z if swing > 0.02 else 0.08
	
	var final_right_x: float = lerpf(target_right_arm_x, target_act_arm_x, action_weight)
	var final_right_y: float = lerpf(target_right_arm_y, target_act_arm_y, action_weight)
	var final_right_z: float = lerpf(target_right_arm_z, target_act_arm_z, action_weight)
	
	left_arm.rotation.x = lerpf(left_arm.rotation.x, target_left_arm_x, minf(delta * 15.0, 1.0))
	left_arm.rotation.y = lerpf(left_arm.rotation.y, target_left_arm_y, minf(delta * 12.0, 1.0))
	left_arm.rotation.z = lerpf(left_arm.rotation.z, target_left_arm_z, minf(delta * 12.0, 1.0))
	
	right_arm.rotation.x = lerpf(right_arm.rotation.x, final_right_x, minf(delta * 22.0, 1.0) if action_weight > 0.05 else minf(delta * 15.0, 1.0))
	right_arm.rotation.y = lerpf(right_arm.rotation.y, final_right_y, minf(delta * 20.0, 1.0))
	right_arm.rotation.z = lerpf(right_arm.rotation.z, final_right_z, minf(delta * 20.0, 1.0))
	
	# 手肘小臂弯曲动力学
	var idle_elbow: float = 0.14 + sin(idle_phase) * 0.025
	var left_elbow_walk: float = 0.32 - arm_sin * 0.18
	var left_elbow_sprint: float = 1.15 - arm_sin * 0.35
	var target_left_elbow: float = lerpf(idle_elbow, lerpf(left_elbow_walk, left_elbow_sprint, sprint_blend), run_blend)
	
	var right_elbow_walk: float = 0.32 + arm_sin * 0.18
	var right_elbow_sprint: float = 1.15 + arm_sin * 0.35
	var target_right_elbow: float = lerpf(idle_elbow, lerpf(right_elbow_walk, right_elbow_sprint, sprint_blend), run_blend)
	if has_held and not mining and place_time <= 0.0:
		target_right_elbow = lerpf(0.85, 0.92 + sin(phase) * 0.035 * sprint_blend, run_blend) if long_item else lerpf(0.95, 1.15 + sin(phase) * 0.06 * sprint_blend, run_blend)
	
	var target_act_elbow: float = s_motion.elbow if swing > 0.02 else (1.10 + place_blend * 0.12)
	target_right_elbow = lerpf(target_right_elbow, target_act_elbow, action_weight)
	
	if left_forearm != null:
		left_forearm.rotation.x = lerpf(left_forearm.rotation.x, target_left_elbow, minf(delta * 16.0, 1.0))
		left_forearm.rotation.y = 0.0
		left_forearm.rotation.z = 0.0
	if right_forearm != null:
		right_forearm.rotation.x = lerpf(right_forearm.rotation.x, target_right_elbow, minf(delta * 22.0, 1.0))
		right_forearm.rotation.y = 0.0
		right_forearm.rotation.z = 0.0
	
	# 头部补偿与视线平视稳定
	var head_compensate: float = -target_tilt * 0.76
	var head_nod: float = cos(phase * 2.0) * lerpf(0.012, 0.025, sprint_blend) * run_blend
	var idle_head: float = sin(idle_phase - 0.4) * 0.012 * (1.0 - run_blend)
	
	head.rotation.x = lerpf(head.rotation.x, head_compensate + head_nod + idle_head + s_motion.head_pitch * swing, minf(delta * 12.0, 1.0))
	head.rotation.y = lerpf(head.rotation.y, 0.0, minf(delta * 12.0, 1.0))
	
	_update_held_item(delta, swing, s_motion.wrist_pitch * swing - 0.38 * place_blend, s_motion.get("grip_rotation"))

func _update_held_item(delta: float, action_weight: float = 0.0, wrist_pitch: float = 0.0, grip_rotation: Variant = null) -> void:
	if is_instance_valid(held_item):
		held_item.rotation.x = lerpf(held_item.rotation.x, wrist_pitch, minf(delta * 26.0, 1.0))
		held_item.update_third_person_grip(body.global_basis, action_weight, grip_rotation)

func _advance_swing(delta: float, requested: bool) -> void:
	swing_contact = false
	if not ItemCatalog.is_tool_item(held_item.block_id) and not ItemCatalog.is_weapon(held_item.block_id):
		var previous := fposmod(swing_phase, TAU) / TAU
		swing_phase += delta * 12.0
		var current := fposmod(swing_phase, TAU) / TAU
		swing_contact = requested and ((previous < 0.58 and current >= 0.58) or (current < previous and current >= 0.58))
		swing = move_toward(swing, 1.0 if requested else 0.0, delta * 8.0)
		return
	var duration: float = WeaponSwing.duration(held_item.block_id) if ItemCatalog.is_weapon(held_item.block_id) else ToolSwing.duration(held_item.block_id)
	if requested and not swing_cycle_running:
		swing_cycle_running = true
		swing_cycle_time = 0.0
	if swing_cycle_running:
		var previous := swing_cycle_time
		swing_cycle_time += maxf(0.0, delta)
		swing_contact = previous < duration * ToolSwing.IMPACT_PHASE and swing_cycle_time >= duration * ToolSwing.IMPACT_PHASE
		if swing_cycle_time >= duration:
			if requested:
				swing_cycle_time = fposmod(swing_cycle_time, duration)
				swing_contact = swing_contact or swing_cycle_time >= duration * ToolSwing.IMPACT_PHASE
			else:
				swing_cycle_running = false
				swing_cycle_time = duration
	swing_phase = (swing_cycle_time / duration) * TAU
	swing = move_toward(swing, 1.0 if swing_cycle_running else 0.0, delta * 12.0)

## 计算自然、优雅且富含打击力量感的武器与工具下劈劈砍动力学
func _compute_swing_motion() -> Dictionary:
	var u: float = fposmod(swing_phase, TAU) / TAU
	if ItemCatalog.is_tool_item(held_item.block_id):
		return ToolSwing.sample(held_item.block_id, u)
	if ItemCatalog.is_weapon(held_item.block_id):
		return WeaponSwing.sample(held_item.block_id, u)
	var arm_x: float = 0.85
	var arm_y: float = 0.0
	var arm_z: float = 0.05
	var elbow: float = 0.95
	var wrist_pitch: float = 0.0
	var body_pitch: float = 0.0
	var body_yaw: float = 0.0
	var hip_drop: float = 0.0
	var head_pitch: float = 0.0
	var left_counter: float = 0.0
	
	if u < 0.28:
		# 1. 高举蓄势阶段（大臂向后上方高高拉起过肩，小臂大幅深折贴肩，武器与镐尖高高耸立天际！）
		var t: float = u / 0.28
		var w: float = (1.0 - cos(t * PI)) * 0.5
		arm_x = lerpf(0.68, -0.55, w)       # 大臂由身前持械位向后上方大幅后拉过肩！
		arm_y = lerpf(0.0, 0.18, w)         # 肩部向右外展展开胸膛
		arm_z = lerpf(0.06, 0.25, w)        # 饱满展翅蓄力
		elbow = lerpf(0.95, 1.85, w)        # 小臂大幅深折曲肘（>105度），剑锋与斧刃高指头顶天际！
		wrist_pitch = -0.45 * w             # 手腕向后蓄力拉满
		body_pitch = 0.08 * w               # 躯干挺胸微仰
		body_yaw = 0.12 * w                 # 右肩后拉转体蓄势
		hip_drop = 0.0
		left_counter = 0.22 * w             # 左臂向前探出平衡重力
	elif u < 0.58:
		# 2. 雷霆万钧圆弧下劈（躯干沉腰拧转爆发，大臂自高空怒砸而下，手腕大角度暴扣75度，划出超大半月形破风斩击圆弧！）
		var t: float = (u - 0.28) / 0.30
		var s: float = pow(t, 1.8)
		arm_x = lerpf(-0.55, 1.62, s)       # 大臂自苍穹雷霆下砸下劈！
		arm_y = lerpf(0.18, -0.12, s)       # 向胸前中央内收聚力
		arm_z = lerpf(0.25, -0.06, s)       # 紧凑收力
		elbow = lerpf(1.85, 1.20, s)        # 小臂随挥动如皮鞭甩开，保持饱满力量微曲（绝不伸直出拳！）
		wrist_pitch = lerpf(-0.45, 1.40, s) # 手腕极速向前下方大角度暴扣下劈（向下翻腕75度！），剑刃/斧刃/镐尖雷霆下劈！
		body_pitch = lerpf(0.08, -0.16, s)  # 躯干沉腰前弓全力下砸
		body_yaw = lerpf(0.12, -0.12, s)    # 扭腰核心力量爆发
		hip_drop = -0.038 * s               # 双腿蹬地下沉重心
		head_pitch = 0.12 * s               # 头部目光紧锁正前方目标
		left_counter = lerpf(0.22, -0.42, s)# 左臂向后猛挥对抗后坐力
	elif u < 0.70:
		# 3. 接触撞击微反震（锋刃与镐尖命中方块瞬间的反冲微颤）
		var t: float = (u - 0.58) / 0.12
		var recoil: float = sin(t * PI) * 0.14
		arm_x = 1.62 - recoil * 0.25
		arm_y = -0.12
		arm_z = -0.06
		elbow = 1.20 + recoil * 0.18
		wrist_pitch = 1.40 - recoil * 1.8
		body_pitch = -0.16 + recoil * 0.05
		body_yaw = -0.12
		hip_drop = -0.038
		head_pitch = 0.12
		left_counter = -0.42
	else:
		# 4. 余威顺畅收回复位（平滑回到待机姿态）
		var t: float = (u - 0.70) / 0.30
		var r: float = (1.0 - cos(t * PI)) * 0.5
		arm_x = lerpf(1.62, 0.68, r)
		arm_y = lerpf(-0.12, 0.0, r)
		arm_z = lerpf(-0.06, 0.06, r)
		elbow = lerpf(1.20, 0.95, r)
		wrist_pitch = lerpf(1.40, 0.0, r)
		body_pitch = lerpf(-0.16, 0.0, r)
		body_yaw = lerpf(-0.12, 0.0, r)
		hip_drop = lerpf(-0.038, 0.0, r)
		head_pitch = lerpf(0.12, 0.0, r)
		left_counter = lerpf(-0.42, 0.0, r)
		
	return {
		"arm_x": arm_x, "arm_y": arm_y, "arm_z": arm_z,
		"elbow": elbow, "wrist_pitch": wrist_pitch,
		"body_pitch": body_pitch, "body_yaw": body_yaw, "hip_drop": hip_drop,
		"head_pitch": head_pitch, "left_counter": left_counter
	}

func _material(hex: String) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = CHARACTER_SHADER
	material.set_shader_parameter("base_color", Color(hex))
	return material

func _box(parent: Node3D, pos: Vector3, size: Vector3, material: Material) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	instance.position = pos
	parent.add_child(instance)

func _limb(parent: Node3D, pos: Vector3, size: Vector3, material: Material) -> Node3D:
	var pivot := Node3D.new()
	pivot.position = pos
	parent.add_child(pivot)
	_box(pivot, Vector3(0, -size.y / 2, 0), size, material)
	return pivot

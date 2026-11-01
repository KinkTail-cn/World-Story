extends RefCounted

const Items = preload("res://scripts/inventory/ItemCatalog.gd")
const REST_ROTATION := Vector3(-0.4363323, 0.0, -0.1396263)
const IMPACT_PHASE: float = 0.52
const WINDUP_END: float = 0.30
const REBOUND_END: float = 0.65
static var _profiles: Dictionary = {}

static func duration(id: int) -> float:
	match Items.tool_material(id):
		"wood": return 0.56
		"stone": return 0.50
		"iron": return 0.44
	return 0.52

static func sample(id: int, phase: float) -> Dictionary:
	var kind := Items.tool_type(id)
	if not _profiles.has(kind):
		_profiles[kind] = _make_profile(kind)
	var poses: Array = _profiles[kind]
	return sample_poses(poses, phase)

static func sample_poses(poses: Array, phase: float) -> Dictionary:
	var u := clampf(phase, 0.0, 1.0)
	var index: int
	var blend: float
	if u < WINDUP_END:
		index = 0
		blend = _ease(u / WINDUP_END)
	elif u < IMPACT_PHASE:
		index = 1
		var t := (u - WINDUP_END) / (IMPACT_PHASE - WINDUP_END)
		blend = t * t
	elif u < REBOUND_END:
		index = 2
		blend = _ease((u - IMPACT_PHASE) / (REBOUND_END - IMPACT_PHASE))
	else:
		index = 3
		blend = _ease((u - REBOUND_END) / (1.0 - REBOUND_END))
	var result := {}
	if blend <= 0.0:
		result = poses[index].duplicate()
	elif blend >= 1.0:
		result = poses[index + 1].duplicate()
	else:
		for key in poses[index]:
			var start: Variant = poses[index][key]
			var finish: Variant = poses[index + 1][key]
			result[key] = start.lerp(finish, blend) if start is Vector3 else lerpf(float(start), float(finish), blend)
	var arm: Vector3 = result.arm
	result["arm_x"] = arm.x
	result["arm_y"] = arm.y
	result["arm_z"] = arm.z
	result["wrist_pitch"] = 0.0
	return result

static func _ease(t: float) -> float:
	var x := clampf(t, 0.0, 1.0)
	return x * x * x * (x * (x * 6.0 - 15.0) + 10.0)

static func pose(arm: Vector3, elbow: float, grip_rotation: Vector3, body_pitch: float = 0.0, body_yaw: float = 0.0, fp_position: Vector3 = Vector3.ZERO, fp_rotation: Vector3 = Vector3.ZERO) -> Dictionary:
	return {
		"arm": arm, "elbow": elbow, "grip_rotation": grip_rotation,
		"body_pitch": body_pitch, "body_yaw": body_yaw,
		"hip_drop": -0.018 if body_pitch < -0.05 else 0.0,
		"head_pitch": maxf(0.0, -body_pitch * 0.5),
		"left_counter": -body_yaw * 1.4,
		"fp_position": fp_position, "fp_rotation": fp_rotation
	}

static func _make_profile(kind: String) -> Array[Dictionary]:
	var rest := pose(Vector3(0.48, 0, 0.08), 0.85, REST_ROTATION)
	match kind:
		"axe":
			return [rest,
				pose(Vector3(1.12, -0.12, 0.28), 1.02, Vector3(-0.18, -0.25, -0.18), 0.025, 0.10, Vector3(0.07, 0.035, 0.045), Vector3(0.35, -0.30, 0.25)),
				pose(Vector3(0.78, 0.16, 0.04), 0.48, Vector3(-1.48, 0.28, 0.12), -0.095, -0.11, Vector3(-0.07, -0.05, -0.08), Vector3(-0.62, 0.32, -0.30)),
				pose(Vector3(0.72, 0.12, 0.08), 0.62, Vector3(-1.24, 0.20, 0.06), -0.055, -0.065, Vector3(-0.045, -0.035, -0.045), Vector3(-0.44, 0.22, -0.20)), rest]
		"shovel":
			return [rest,
				pose(Vector3(0.72, -0.035, 0.12), 1.00, Vector3(-0.44, -0.06, -0.12), 0.015, 0.025, Vector3(0.025, 0.02, 0.05), Vector3(0.20, -0.08, 0.06)),
				pose(Vector3(0.64, 0.025, 0.07), 0.38, Vector3(-1.94, 0.04, -0.08), -0.09, -0.025, Vector3(-0.025, -0.065, -0.13), Vector3(-0.60, 0.12, -0.12)),
				pose(Vector3(0.80, 0.01, 0.09), 0.62, Vector3(-1.48, 0.02, -0.08), -0.04, -0.015, Vector3(0.0, -0.035, -0.08), Vector3(-0.25, 0.08, -0.08)), rest]
		_:
			return [rest,
				pose(Vector3(1.25, -0.04, 0.18), 1.10, Vector3(-0.12, -0.035, -0.10), 0.025, 0.035, Vector3(0.018, 0.06, 0.04), Vector3(0.55, -0.12, 0.12)),
				pose(Vector3(0.68, 0.025, 0.08), 0.45, Vector3(-1.65, 0.025, -0.10), -0.10, -0.04, Vector3(-0.03, -0.09, -0.08), Vector3(-0.88, 0.12, -0.12)),
				pose(Vector3(0.74, 0.015, 0.10), 0.64, Vector3(-1.39, 0.015, -0.10), -0.055, -0.02, Vector3(-0.02, -0.055, -0.045), Vector3(-0.62, 0.08, -0.08)), rest]

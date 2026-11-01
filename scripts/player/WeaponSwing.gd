extends RefCounted

const Motion = preload("res://scripts/player/ToolSwing.gd")
const Items = preload("res://scripts/inventory/ItemCatalog.gd")
static var _profiles: Dictionary = {}

static func duration(id: int) -> float:
	return 1.0 / maxf(0.1, Items.weapon_speed(id))

static func sample(id: int, phase: float) -> Dictionary:
	if not _profiles.has(id):
		_profiles[id] = _make_profile(id)
	return Motion.sample_poses(_profiles[id], phase)

static func _make_profile(id: int) -> Array[Dictionary]:
	var rest := Motion.pose(Vector3(0.48, 0, 0.08), 0.85, Motion.REST_ROTATION)
	if id == 304: # Rapier: draw back a bent elbow, thrust and withdraw.
		return [rest,
			Motion.pose(Vector3(0.42, -0.06, 0.13), 1.05, Vector3(-0.98, -0.06, -0.08), 0.01, 0.045, Vector3(0.035, 0.01, 0.075), Vector3(0.14, -0.10, 0.05)),
			Motion.pose(Vector3(1.10, 0.03, 0.07), 0.18, Vector3(-1.56, 0.02, -0.05), -0.055, -0.035, Vector3(-0.045, -0.02, -0.19), Vector3(-0.64, 0.10, -0.06)),
			Motion.pose(Vector3(0.72, 0.01, 0.09), 0.67, Vector3(-1.22, 0.01, -0.06), -0.025, -0.015, Vector3(-0.015, -0.01, -0.06), Vector3(-0.28, 0.05, -0.03)), rest]
	if id in [302, 305]: # Heavy axe/greatsword: controlled overhead diagonal cut.
		var axe := id == 302
		return [rest,
			Motion.pose(Vector3(1.12, -0.14, 0.24), 1.00, Vector3(-0.12, -0.15, -0.26), 0.025, 0.09, Vector3(0.065, 0.065, 0.065), Vector3(0.45, -0.25, 0.24)),
			Motion.pose(Vector3(0.74, 0.18, 0.02), 0.48, Vector3(-1.58, 0.24, 0.28 if axe else 0.18), -0.11, -0.11, Vector3(-0.075, -0.075, -0.095), Vector3(-0.85, 0.29, -0.32)),
			Motion.pose(Vector3(0.68, 0.12, 0.05), 0.65, Vector3(-1.35, 0.15, 0.14), -0.06, -0.06, Vector3(-0.05, -0.045, -0.055), Vector3(-0.57, 0.18, -0.19)), rest]
	# Short sword / iron sword: a compact diagonal slash in front of the torso.
	var reach := 0.08 if id == 303 else 0.0
	return [rest,
		Motion.pose(Vector3(0.95, -0.18, 0.22), 0.98, Vector3(-0.20, -0.25, -0.28), 0.015, 0.075, Vector3(0.06, 0.04, 0.055), Vector3(0.29, -0.29, 0.25)),
		Motion.pose(Vector3(0.76 + reach, 0.23, -0.03), 0.48, Vector3(-1.42, 0.32, 0.35), -0.075, -0.09, Vector3(-0.08, -0.045, -0.10), Vector3(-0.66, 0.35, -0.34)),
		Motion.pose(Vector3(0.68, 0.14, 0.035), 0.66, Vector3(-1.14, 0.20, 0.18), -0.04, -0.045, Vector3(-0.045, -0.025, -0.045), Vector3(-0.39, 0.20, -0.17)), rest]

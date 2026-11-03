extends RefCounted

const Models = preload("res://scripts/player/EquipmentModels.gd")
const Cubes = preload("res://scripts/content/CubeParts.gd")
const ORIGINS: Dictionary = Models.BONE_ORIGINS
const ANCHORS: Array[String] = ["head", "body", "left_arm", "right_arm", "left_forearm", "right_forearm", "left_leg", "right_leg", "left_lower_leg", "right_lower_leg"]
const ANCHOR_NAMES: Array[String] = ["头部", "躯干", "左大臂", "右大臂", "左前臂", "右前臂", "左大腿", "右大腿", "左小腿", "右小腿"]
const SHAPES: Array[String] = ["box"]
const SHAPE_NAMES: Array[String] = ["正放立方体"]
const UNIT: float = 0.13
const PREVIEW_FLIP := Basis(Vector3(-1, 0, 0), Vector3(0, 1, 0), Vector3(0, 0, -1))
static var _meshes: Dictionary = {}

static func vector(value: Variant, fallback: Vector3 = Vector3.ZERO) -> Vector3:
	if value is Vector3 or value is Vector3i:
		return Vector3(value)
	if value is Array and value.size() == 3:
		return Vector3(float(value[0]), float(value[1]), float(value[2]))
	return fallback

static func array(value: Vector3) -> Array:
	return [value.x, value.y, value.z]

static func size_scale(mode: int) -> float:
	return [1.0, 1.0, 2.0, 0.5, 0.25][clampi(mode, 0, 4)]

static func dimensions(part: Dictionary) -> Vector3:
	return vector(part.get("dimensions"), Vector3.ONE * UNIT * size_scale(int(part.get("size", 1))))

static func is_cube(part: Dictionary) -> bool:
	return Cubes.is_cube(dimensions(part)) and str(part.get("shape", "box")) == "box" and vector(part.get("rotation")).is_zero_approx() and not part.has("cloth")

static func center(part: Dictionary) -> Vector3:
	return vector(part.center) if part.has("center") else vector(part.get("pos")) * UNIT

static func template_origin(category: String) -> Vector3:
	match category:
		"头部装备": return Vector3(0, 1.575, 0)
		"盔甲": return Vector3(0, 1.0125, 0)
		"裤甲": return Vector3(0, 0.38, 0)
		"鞋子": return Vector3(0, 0.09, 0)
		"手套": return Vector3(-0.3375, 0.78, 0)
		"披风": return Vector3(0, 1.30, -0.16)
		"腰带": return Vector3(0, 0.715, 0)
	return Vector3.ZERO

static func auto_anchor(category: String, pos: Vector3) -> String:
	var side := "right" if pos.x >= 0.0 else "left"
	match category:
		"头部装备": return "head"
		"手套": return side + "_forearm"
		"裤甲", "鞋子": return side + ("_lower_leg" if category == "鞋子" or pos.y < 0.335 else "_leg")
		"盔甲":
			if absf(pos.x) > 0.26:
				return side + ("_forearm" if pos.y < 1.01 else "_arm")
	return "body"

static func anchor(part: Dictionary, category: String) -> String:
	return str(part.anchor) if ORIGINS.has(str(part.get("anchor", ""))) else auto_anchor(category, PREVIEW_FLIP * (template_origin(category) + center(part)))

static func character_transform(part: Dictionary, category: String) -> Transform3D:
	var pos := PREVIEW_FLIP * (template_origin(category) + center(part))
	if part.has("offset"):
		pos = Vector3(ORIGINS[anchor(part, category)]) + vector(part.offset)
	return Transform3D(Basis.IDENTITY, pos)

static func local_transform(part: Dictionary, category: String) -> Transform3D:
	var transform := character_transform(part, category)
	transform.origin -= Vector3(ORIGINS[anchor(part, category)])
	return transform

static func preview_transform(part: Dictionary, category: String) -> Transform3D:
	return Transform3D(PREVIEW_FLIP, Vector3.ZERO) * character_transform(part, category)

static func set_character_transform(part: Dictionary, category: String, transform: Transform3D, target_anchor: String = "") -> void:
	var bone := target_anchor if ORIGINS.has(target_anchor) else anchor(part, category)
	part["anchor"] = bone
	part["offset"] = array(transform.origin - Vector3(ORIGINS[bone]))
	part["shape"] = "box"
	part.erase("rotation")
	part.erase("cloth")
	var legacy_center := PREVIEW_FLIP * transform.origin - template_origin(category)
	part["center"] = array(legacy_center)
	part["pos"] = Vector3i((legacy_center / UNIT).round())

static func primitive(category: String, preview_pos: Vector3, extent: Vector3, bone: String = "") -> Dictionary:
	var char_pos := PREVIEW_FLIP * preview_pos
	var chosen := bone if ORIGINS.has(bone) else auto_anchor(category, char_pos)
	if not Cubes.is_cube(extent):
		return {}
	var part := {"part": category, "mat": 1, "size": 1, "shape": "box", "dimensions": array(extent)}
	set_character_transform(part, category, Transform3D(Basis.IDENTITY, char_pos), chosen)
	return part

static func mirrored(part: Dictionary, category: String) -> Dictionary:
	var copy := part.duplicate(true)
	var transform := character_transform(part, category)
	transform.origin.x = -transform.origin.x
	var bone := anchor(part, category)
	if bone.begins_with("left_"):
		bone = bone.replace("left_", "right_")
	elif bone.begins_with("right_"):
		bone = bone.replace("right_", "left_")
	set_character_transform(copy, category, transform, bone)
	return copy

static func volume(part: Dictionary) -> float:
	var extent := dimensions(part)
	return extent.x * extent.y * extent.z

static func vertices(part: Dictionary) -> PackedVector3Array:
	var result := PackedVector3Array()
	for x in [-0.5, 0.5]:
		for y in [-0.5, 0.5]:
			for z in [-0.5, 0.5]:
				result.append(Vector3(x, y, z) * dimensions(part))
	return result

static func placement(hit: Vector3, normal: Vector3, part: Dictionary, preview_basis: Basis, grid_step: float = 0.0) -> Vector3:
	var n := normal.normalized()
	var surface := hit
	if grid_step > 0.000001:
		surface += (hit.snapped(Vector3.ONE * grid_step) - hit).slide(n)
	var minimum := INF
	for point in vertices(part):
		minimum = minf(minimum, n.dot(preview_basis * point))
	return surface - n * minimum

static func collision_shape(part: Dictionary) -> Shape3D:
	var box := BoxShape3D.new()
	box.size = dimensions(part)
	return box

static func mesh(part: Dictionary) -> Mesh:
	var extent := dimensions(part)
	var key := "%.6f" % extent.x
	if not _meshes.has(key):
		var box := BoxMesh.new()
		box.size = extent
		if _meshes.size() >= 512:
			_meshes.erase(_meshes.keys()[0])
		_meshes[key] = box
	return _meshes[key]

extends RefCounted

const Models = preload("res://scripts/player/EquipmentModels.gd")
const ORIGINS: Dictionary = Models.BONE_ORIGINS
const ANCHORS: Array[String] = ["head", "body", "left_arm", "right_arm", "left_forearm", "right_forearm", "left_leg", "right_leg", "left_lower_leg", "right_lower_leg"]
const ANCHOR_NAMES: Array[String] = ["头部", "躯干", "左大臂", "右大臂", "左前臂", "右前臂", "左大腿", "右大腿", "左小腿", "右小腿"]
const SHAPES: Array[String] = ["box", "wedge", "cone", "cloth"]
const SHAPE_NAMES: Array[String] = ["长方体", "楔形块", "四棱锥", "布料片"]
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

static func auto_anchor(category: String, character_pos: Vector3) -> String:
	var side := "right" if character_pos.x >= 0.0 else "left"
	match category:
		"头部装备": return "head"
		"手套": return side + "_forearm"
		"裤甲", "鞋子": return side + ("_lower_leg" if category == "鞋子" or character_pos.y < 0.335 else "_leg")
		"盔甲":
			if absf(character_pos.x) > 0.26:
				return side + ("_forearm" if character_pos.y < 1.01 else "_arm")
	return "body"

static func anchor(part: Dictionary, category: String) -> String:
	if ORIGINS.has(str(part.get("anchor", ""))):
		return str(part.anchor)
	return auto_anchor(category, PREVIEW_FLIP * (template_origin(category) + center(part)))

static func character_transform(part: Dictionary, category: String) -> Transform3D:
	var rotation := vector(part.get("rotation")) * (PI / 180.0)
	var pos := PREVIEW_FLIP * (template_origin(category) + center(part))
	if part.has("offset"):
		pos = Vector3(ORIGINS[anchor(part, category)]) + vector(part.offset)
	return Transform3D(Basis.from_euler(rotation), pos)

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
	part["rotation"] = array(transform.basis.orthonormalized().get_euler() * (180.0 / PI))
	var legacy_center := PREVIEW_FLIP * transform.origin - template_origin(category)
	part["center"] = array(legacy_center)
	part["pos"] = Vector3i((legacy_center / UNIT).round())

static func primitive(category: String, preview_pos: Vector3, extent: Vector3, rotation: Vector3 = Vector3.ZERO, shape: String = "box", bone: String = "") -> Dictionary:
	var char_pos := PREVIEW_FLIP * preview_pos
	var chosen := bone if ORIGINS.has(bone) else auto_anchor(category, char_pos)
	var part := {"part": category, "mat": 1, "size": 1, "shape": shape, "dimensions": array(extent)}
	set_character_transform(part, category, Transform3D(Basis.from_euler(rotation * (PI / 180.0)), char_pos), chosen)
	return part

static func mirrored(part: Dictionary, category: String) -> Dictionary:
	var copy := part.duplicate(true)
	var transform := character_transform(part, category)
	var reflection := Basis(Vector3(-1, 0, 0), Vector3.UP, Vector3.BACK)
	transform.origin.x = -transform.origin.x
	transform.basis = reflection * transform.basis * reflection
	var bone := anchor(part, category)
	if bone.begins_with("left_"):
		bone = bone.replace("left_", "right_")
	elif bone.begins_with("right_"):
		bone = bone.replace("right_", "left_")
	set_character_transform(copy, category, transform, bone)
	return copy

static func volume(part: Dictionary) -> float:
	var extent := dimensions(part)
	if part.get("shape", "box") == "cloth":
		return (extent.x + float(part.get("cloth", {}).get("flare", 0.06)) * 0.5) * extent.y * extent.z
	var factor := 0.5 if part.get("shape", "box") == "wedge" else (1.0 / 3.0 if part.get("shape", "box") == "cone" else 1.0)
	return extent.x * extent.y * extent.z * factor

static func vertices(part: Dictionary) -> PackedVector3Array:
	var extent := dimensions(part)
	if part.get("shape", "box") == "cloth":
		extent.x = maxf(extent.x, extent.x + float(part.get("cloth", {}).get("flare", 0.06)))
	var points: Array[Vector3] = []
	match str(part.get("shape", "box")):
		"wedge":
			points = [Vector3(-0.5, -0.5, -0.5), Vector3(0.5, -0.5, -0.5), Vector3(-0.5, -0.5, 0.5), Vector3(0.5, -0.5, 0.5), Vector3(-0.5, 0.5, 0.5), Vector3(0.5, 0.5, 0.5)]
		"cone":
			points = [Vector3(-0.5, -0.5, -0.5), Vector3(0.5, -0.5, -0.5), Vector3(-0.5, -0.5, 0.5), Vector3(0.5, -0.5, 0.5), Vector3(0, 0.5, 0)]
		_:
			for x in [-0.5, 0.5]:
				for y in [-0.5, 0.5]:
					for z in [-0.5, 0.5]:
						points.append(Vector3(x, y, z))
	var result := PackedVector3Array()
	for point in points:
		result.append(point * extent)
	return result

static func placement(hit: Vector3, normal: Vector3, part: Dictionary, preview_basis: Basis, grid_step: float = 0.0) -> Vector3:
	var n := normal.normalized()
	var surface := hit
	if grid_step > 0.000001:
		var snapped := hit.snapped(Vector3.ONE * grid_step)
		surface += (snapped - hit).slide(n)
	var minimum := INF
	for point in vertices(part):
		minimum = minf(minimum, n.dot(preview_basis * point))
	return surface - n * minimum

static func collision_shape(part: Dictionary) -> Shape3D:
	if part.get("shape", "box") in ["box", "cloth"]:
		var box := BoxShape3D.new()
		box.size = dimensions(part)
		if part.get("shape", "box") == "cloth":
			box.size.x = maxf(box.size.x, box.size.x + float(part.get("cloth", {}).get("flare", 0.06)))
		return box
	var convex := ConvexPolygonShape3D.new()
	convex.points = vertices(part)
	return convex

static func mesh(part: Dictionary) -> Mesh:
	var extent := dimensions(part)
	var shape := str(part.get("shape", "box"))
	var key := shape + ":" + str(extent)
	if shape == "cloth":
		key += ":" + str(float(part.get("cloth", {}).get("flare", 0.06)))
	if _meshes.has(key):
		return _meshes[key]
	var result: Mesh
	if shape == "box":
		var box := BoxMesh.new()
		box.size = extent
		result = box
	elif shape == "cloth":
		result = _cloth_mesh(extent, float(part.get("cloth", {}).get("flare", 0.06)))
	else:
		var points := vertices(part)
		var surface := SurfaceTool.new()
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		if shape == "wedge":
			_face(surface, points, [0, 2, 3, 1], Vector3.DOWN)
			_face(surface, points, [2, 4, 5, 3], Vector3.BACK)
			_face(surface, points, [0, 4, 2], Vector3.LEFT)
			_face(surface, points, [1, 3, 5], Vector3.RIGHT)
			_face(surface, points, [0, 1, 5, 4], Vector3(0, extent.z, -extent.y).normalized())
		else:
			_face(surface, points, [0, 2, 3, 1], Vector3.DOWN)
			for triangle in [[0, 1, 4], [1, 3, 4], [3, 2, 4], [2, 0, 4]]:
				var middle: Vector3 = (points[triangle[0]] + points[triangle[1]]) * 0.5
				var normal := (points[triangle[1]] - points[triangle[0]]).cross(points[4] - points[triangle[0]]).normalized()
				if normal.dot(Vector3(middle.x, 0, middle.z)) < 0:
					normal = -normal
				_face(surface, points, triangle, normal)
		result = surface.commit()
	if _meshes.size() >= 512:
		_meshes.erase(_meshes.keys()[0])
	_meshes[key] = result
	return result

static func _face(surface: SurfaceTool, points: PackedVector3Array, indices: Array, normal: Vector3) -> void:
	for i in range(1, indices.size() - 1):
		var triangle := [points[indices[0]], points[indices[i]], points[indices[i + 1]]]
		if (triangle[1] - triangle[0]).cross(triangle[2] - triangle[0]).dot(normal) > 0:
			var swap: Vector3 = triangle[1]
			triangle[1] = triangle[2]
			triangle[2] = swap
		for point in triangle:
			surface.set_normal(normal)
			surface.add_vertex(point)

static func _cloth_mesh(extent: Vector3, flare: float) -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for y in range(16):
		for x in range(8):
			for corner in [Vector2(0, 0), Vector2(1, 1), Vector2(1, 0), Vector2(0, 0), Vector2(0, 1), Vector2(1, 1)]:
				var uv := Vector2((float(x) + corner.x) / 8.0, (float(y) + corner.y) / 16.0)
				surface.set_uv(uv)
				surface.set_normal(Vector3.BACK)
				surface.add_vertex(Vector3((uv.x - 0.5) * (extent.x + uv.y * flare), (0.5 - uv.y) * extent.y, 0))
	return surface.commit()

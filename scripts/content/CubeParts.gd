extends RefCounted

# A shared voxel sampler for legacy designs and built-in item silhouettes.
# Every output element is an unrotated cube, including thin trims and capes.
const MIN_EDGE: float = 0.005
const DETAIL_EDGE: float = 0.0325
static var _meshes: Dictionary = {}

static func is_cube(extent: Vector3) -> bool:
	return absf(extent.x - extent.y) < 0.000001 and absf(extent.x - extent.z) < 0.000001

static func bounds(extent: Vector3, angles: Vector3, shape: String, cloth: Dictionary) -> AABB:
	var size := extent
	if shape == "cloth":
		size.x += maxf(0.0, float(cloth.get("flare", 0.06)))
	return Transform3D(Basis.from_euler(angles), Vector3.ZERO) * AABB(-size * 0.5, size)

static func weight(extent: Vector3, angles: Vector3 = Vector3.ZERO, shape: String = "box", cloth: Dictionary = {}) -> int:
	if shape == "box" and angles.is_zero_approx() and is_cube(extent):
		return 1
	var edge := maxf(MIN_EDGE, minf(DETAIL_EDGE, minf(extent.x, minf(extent.y, extent.z))))
	var size := bounds(extent, angles, shape, cloth).size
	return mini(1000000, maxi(1, int(ceil(size.x / edge) * ceil(size.y / edge) * ceil(size.z / edge))))

static func budgets(weights: Array[int], limit: int) -> Array[int]:
	var result: Array[int] = []
	var total: int = 0
	for amount in weights:
		total += maxi(0, amount - 1)
	var spare := maxi(0, limit - weights.size())
	for amount in weights:
		result.append(1 + (int(float(spare) * float(maxi(0, amount - 1)) / float(total)) if total > 0 else 0))
	return result

static func sample(extent: Vector3, angles: Vector3 = Vector3.ZERO, shape: String = "box", cloth: Dictionary = {}, budget: int = 4096) -> Array[Dictionary]:
	if budget <= 0:
		return []
	if shape == "box" and angles.is_zero_approx() and is_cube(extent):
		return [{"pos": Vector3.ZERO, "edge": extent.x}]
	var box := bounds(extent, angles, shape, cloth)
	var edge := maxf(MIN_EDGE, minf(DETAIL_EDGE, minf(extent.x, minf(extent.y, extent.z))))
	var count := _counts(box.size, edge)
	# Bound the candidate grid before sampling, even for a very large old part.
	while count.x * count.y * count.z > budget:
		edge *= maxf(1.05, pow(float(count.x * count.y * count.z) / float(budget), 1.0 / 3.0))
		count = _counts(box.size, edge)
	if edge > 4.0:
		return [{"pos": box.get_center(), "edge": 4.0}]
	edge = ceilf(edge * 1000000.0) / 1000000.0
	count = _counts(box.size, edge)
	var size := Vector3(count) * edge
	var inverse := Basis.from_euler(angles).inverse()
	var result: Array[Dictionary] = []
	for y in count.y:
		for z in count.z:
			for x in count.x:
				var point := box.get_center() - size * 0.5 + (Vector3(x, y, z) + Vector3.ONE * 0.5) * edge
				var local := inverse * point
				if _inside(extent, shape, cloth, local):
					var cell := {"pos": point, "edge": edge}
					if shape == "cloth" and _is_trim(extent, cloth, local):
						cell["tint"] = str(cloth.get("trim", "c3ad79"))
					result.append(cell)
	if result.is_empty():
		result.append({"pos": box.get_center(), "edge": maxf(MIN_EDGE, minf(box.size.x, minf(box.size.y, box.size.z)))})
	return result

static func _counts(extent: Vector3, edge: float) -> Vector3i:
	return Vector3i(maxi(1, roundi(extent.x / edge)), maxi(1, roundi(extent.y / edge)), maxi(1, roundi(extent.z / edge)))

static func _inside(extent: Vector3, shape: String, cloth: Dictionary, point: Vector3) -> bool:
	var half := extent * 0.5
	if absf(point.y) > half.y + 0.000001 or absf(point.z) > half.z + 0.000001:
		return false
	match shape:
		"wedge": return absf(point.x) <= half.x + 0.000001 and point.y <= point.z * extent.y / extent.z + 0.000001
		"cone":
			var ratio := (half.y - point.y) / extent.y
			return absf(point.x) <= half.x * ratio + 0.000001 and absf(point.z) <= half.z * ratio + 0.000001
		"cloth":
			var ratio := clampf(0.5 - point.y / extent.y, 0, 1)
			return absf(point.x) <= (extent.x + ratio * float(cloth.get("flare", 0.06))) * 0.5 + 0.000001
	return absf(point.x) <= half.x + 0.000001

static func _is_trim(extent: Vector3, cloth: Dictionary, point: Vector3) -> bool:
	var ratio := clampf(0.5 - point.y / extent.y, 0, 1)
	var width := extent.x + ratio * float(cloth.get("flare", 0.06))
	var uv := Vector2(point.x / width + 0.5, ratio)
	var border := minf(0.10, DETAIL_EDGE / width)
	var mark := uv.x < border or uv.x > 1.0 - border or uv.y > 0.95
	match int(cloth.get("emblem", 0)):
		1:
			var p := (uv - Vector2(0.5, 0.34)).abs()
			mark = mark or p.x * 0.7 + p.y < 0.09
		2:
			mark = mark or (absf(uv.x - 0.5) < 0.05 and uv.y > 0.23 and uv.y < 0.65) or (absf(uv.x - 0.5) < 0.19 and absf(uv.y - 0.35) < 0.04)
		3:
			for star in [Vector3(0.5, 0.30, 0.13), Vector3(0.28, 0.57, 0.065), Vector3(0.73, 0.65, 0.085)]:
				var p: Vector2 = ((uv - Vector2(star.x, star.y)) / star.z).abs()
				mark = mark or minf(p.x * 3.5 + p.y, p.x + p.y * 3.5) < 1.0
	return mark

static func mesh(extent: Vector3) -> Mesh:
	var key := "%.6f:%.6f:%.6f" % [extent.x, extent.y, extent.z]
	if _meshes.has(key):
		return _meshes[key]
	var cells := sample(extent, Vector3.ZERO, "box", {}, 1024)
	var cube := BoxMesh.new()
	cube.size = Vector3.ONE * float(cells[0].edge)
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for cell in cells:
		surface.append_from(cube, 0, Transform3D(Basis.IDENTITY, cell.pos))
	var source := surface.commit()
	var arrays := source.surface_get_arrays(0)
	var uvs := PackedVector2Array()
	var corners_per_cube := int(source.surface_get_array_len(0) / cells.size())
	# Constant UVs identify a cube's center to the cape animation shader.
	# Ordinary item materials do not sample these coordinates.
	for cell in cells:
		var uv := Vector2(0.5 + cell.pos.x / extent.x, 0.5 - cell.pos.y / extent.y)
		for _corner in corners_per_cube:
			uvs.append(uv)
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	var result := ArrayMesh.new()
	result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	result.set_meta("cube_count", cells.size())
	result.set_meta("cube_edge", cells[0].edge)
	if _meshes.size() >= 512:
		_meshes.erase(_meshes.keys()[0])
	_meshes[key] = result
	return result

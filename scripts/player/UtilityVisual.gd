extends Node3D

const Models = preload("res://scripts/content/UtilityModels.gd")
const Geometry = preload("res://scripts/blueprint/BlueprintGeometry.gd")
const Design = preload("res://scripts/blueprint/BlueprintEquipment.gd")
var bounds := AABB()
var cache_identity: String = ""
static var _cache: Dictionary = {}

func build(id: int, item: Dictionary = {}, display: bool = false, door_section: int = 0) -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	var blueprint: Variant = item.get("blueprint", {})
	var cache_key := str(id) + ":" + str(blueprint.hash() if blueprint is Dictionary else 0) + ":" + str(door_section)
	cache_identity = cache_key
	if _cache.has(cache_key):
		bounds = _cache[cache_key].bounds
		_instances(_cache[cache_key].meshes, display)
		return
	var parts := item_parts(id, item)
	if door_section != 0:
		parts = parts.filter(func(part: Dictionary):
			var frame: bool = absf(part.pos.x) > 0.91 or part.pos.y > 2.9
			return frame if door_section == 2 else (not frame and (part.pos.x < 0 if door_section < 0 else part.pos.x >= 0))
		)
	var surfaces := {}
	var first := true
	for part in parts:
		var edge: float = part.edge
		var box := AABB(Vector3(part.pos) - Vector3.ONE * edge * 0.5, Vector3.ONE * edge)
		bounds = box if first else bounds.merge(box)
		first = false
		var tint: Color = part.tint
		var key := tint.to_html()
		if not surfaces.has(key):
			var tool := SurfaceTool.new()
			tool.begin(Mesh.PRIMITIVE_TRIANGLES)
			surfaces[key] = tool
		var cube := BoxMesh.new()
		cube.size = Vector3.ONE * edge
		surfaces[key].append_from(cube, 0, Transform3D(Basis.IDENTITY, part.pos))
	var meshes: Array = []
	for key in surfaces:
		var material := StandardMaterial3D.new()
		material.albedo_color = Color(key)
		material.roughness = 0.85
		meshes.append({"mesh": surfaces[key].commit(), "material": material})
	if _cache.size() >= 64: _cache.erase(_cache.keys()[0])
	_cache[cache_key] = {"bounds": bounds, "meshes": meshes}
	_instances(meshes, display)

func _instances(meshes: Array, display: bool) -> void:
	var root := Node3D.new()
	add_child(root)
	for entry in meshes:
		var mesh := MeshInstance3D.new()
		mesh.mesh = entry.mesh
		mesh.material_override = entry.material
		root.add_child(mesh)
	if display and not meshes.is_empty():
		var fit := 0.4 / maxf(bounds.size.x, maxf(bounds.size.y, bounds.size.z))
		root.scale = Vector3.ONE * fit
		root.position = -bounds.get_center() * fit

func collision_shape() -> Shape3D:
	if not _cache.has(cache_identity): return null
	var cached: Dictionary = _cache[cache_identity]
	if cached.has("shape"): return cached.shape
	var faces := PackedVector3Array()
	for entry in cached.meshes: faces.append_array(entry.mesh.get_faces())
	if faces.is_empty(): return null
	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(faces)
	cached["shape"] = shape
	return shape

static func item_parts(id: int, item: Dictionary = {}) -> Array[Dictionary]:
	if not Design.is_custom_item(item):
		return Models.parts(id)
	var data: Dictionary = item.blueprint
	var category := str(data.category)
	var result: Array[Dictionary] = []
	var box := AABB()
	var first := true
	for part in Design.active_voxels(data):
		var pos := Geometry.preview_transform(part, category).origin
		if category in ["工具", "武器"]:
			pos -= Vector3(-0.34, 0.78, 0.18)
		var edge := Geometry.dimensions(part).x
		result.append({"pos": pos, "edge": edge, "tint": preload("res://scripts/blueprint/BlueprintMaterials.gd").tint(part)})
		var extent := AABB(pos - Vector3.ONE * edge * 0.5, Vector3.ONE * edge)
		box = extent if first else box.merge(extent)
		first = false
	if category == "道具摆件":
		var offset := Vector3(-box.get_center().x, -box.position.y, -box.get_center().z)
		for part in result:
			part.pos += offset
	return result

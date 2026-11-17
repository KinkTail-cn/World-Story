extends Node3D

const Models = preload("res://scripts/content/UtilityModels.gd")
const Geometry = preload("res://scripts/blueprint/BlueprintGeometry.gd")
const Design = preload("res://scripts/blueprint/BlueprintEquipment.gd")
var bounds := AABB()
var cache_identity: String = ""
var groups: Dictionary = {}
var group_pivots: Dictionary = {}
var group_bounds: Dictionary = {}
var material_meshes: Array[MeshInstance3D] = []
var held_phase: float = 0.0
var held_light: OmniLight3D
static var _cache: Dictionary = {}

func build(id: int, item: Dictionary = {}, display: bool = false, door_section: int = 0) -> void:
	set_physics_process(false)
	held_light = null
	for child in get_children():
		remove_child(child)
		child.queue_free()
	groups.clear()
	material_meshes.clear()
	group_pivots.clear()
	group_bounds.clear()
	bounds = AABB()
	var blueprint: Variant = item.get("blueprint", {})
	var cache_key := str(id) + ":" + str(blueprint.hash() if blueprint is Dictionary else 0) + ":" + str(door_section)
	cache_identity = cache_key
	if _cache.has(cache_key):
		bounds = _cache[cache_key].bounds
		group_bounds = _cache[cache_key].groups.duplicate()
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
		var group := str(part.get("group", "body"))
		var profile := str(part.get("surface", "wood"))
		group_bounds[group] = AABB(group_bounds[group]).merge(box) if group_bounds.has(group) else box
		var key := tint.to_html() + ":" + profile + ":" + group
		if not surfaces.has(key):
			var tool := SurfaceTool.new()
			tool.begin(Mesh.PRIMITIVE_TRIANGLES)
			surfaces[key] = {"tool": tool, "color": tint, "surface": profile, "group": group}
		var cube := BoxMesh.new()
		cube.size = Vector3.ONE * edge
		surfaces[key].tool.append_from(cube, 0, Transform3D(Basis.IDENTITY, part.pos))
	var meshes: Array = []
	for key in surfaces:
		var source: Dictionary = surfaces[key]
		var material := preload("res://scripts/blueprint/BlueprintMaterials.gd").create_utility(source.color, source.surface)
		meshes.append({"mesh": source.tool.commit(), "material": material, "surface": source.surface, "group": source.group})
	if _cache.size() >= 64: _cache.erase(_cache.keys()[0])
	_cache[cache_key] = {"bounds": bounds, "meshes": meshes, "groups": group_bounds.duplicate()}
	_instances(meshes, display)

func _instances(meshes: Array, display: bool) -> void:
	var root := Node3D.new()
	root.name = "ModelRoot"
	add_child(root)
	for entry in meshes:
		var group := str(entry.get("group", "body"))
		if not groups.has(group):
			var pivot := _pivot(group)
			var node := Node3D.new()
			node.name = group
			node.position = pivot
			root.add_child(node)
			groups[group] = node
			group_pivots[group] = pivot
		var mesh := MeshInstance3D.new()
		mesh.mesh = entry.mesh
		mesh.material_override = entry.material
		mesh.position = -Vector3(group_pivots[group])
		mesh.set_meta("visual_surface", entry.get("surface", "wood"))
		mesh.set_meta("animation_group", group)
		if entry.get("surface", "") in ["glass", "water", "glow"]: mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		groups[group].add_child(mesh)
		material_meshes.append(mesh)
	if display and not meshes.is_empty():
		var fit := 0.4 / maxf(bounds.size.x, maxf(bounds.size.y, bounds.size.z))
		root.scale = Vector3.ONE * fit
		root.position = -bounds.get_center() * fit

func collision_shape(group: String = "") -> Shape3D:
	if not _cache.has(cache_identity): return null
	var cached: Dictionary = _cache[cache_identity]
	var key := "shape:" + group
	if cached.has(key): return cached[key]
	var faces := PackedVector3Array()
	for entry in cached.meshes:
		var name := str(entry.get("group", "body"))
		if group.begins_with("!") and name == group.substr(1): continue
		if not group.is_empty() and not group.begins_with("!") and name != group: continue
		if entry.get("surface", "") in ["water", "glow"]: continue
		faces.append_array(entry.mesh.get_faces())
	if faces.is_empty(): return null
	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(faces)
	cached[key] = shape
	return shape

func _pivot(group: String) -> Vector3:
	var box: AABB = group_bounds.get(group, AABB())
	if group == "lid": return Vector3(box.get_center().x, box.position.y, box.end.z - 0.025)
	if group == "crank": return box.get_center()
	return Vector3.ZERO

func pose(group: String, rotation_value: Vector3 = Vector3.ZERO, offset: Vector3 = Vector3.ZERO) -> void:
	if groups.has(group):
		groups[group].rotation = rotation_value
		groups[group].position = Vector3(group_pivots[group]) + offset

func enable_held_effects(id: int) -> void:
	if id == 505 and groups.has("glow"):
		held_light = OmniLight3D.new()
		held_light.light_color = Color("ffcf84")
		held_light.omni_range = 6.5
		held_light.shadow_enabled = false
		add_child(held_light)
		held_light.position = to_local(groups.glow.to_global(AABB(group_bounds.glow).get_center()))
	set_physics_process(id == 610 or held_light != null)

func _physics_process(delta: float) -> void:
	held_phase += delta
	pose("water", Vector3.ZERO, Vector3(0, sin(held_phase * 2.1) * 0.005, 0))
	if held_light != null: held_light.light_energy = 1.1 + sin(held_phase * 7.3) * 0.04

static func item_parts(id: int, item: Dictionary = {}) -> Array[Dictionary]:
	if not Design.is_custom_item(item):
		return Models.parts(id)
	var data: Dictionary = item.blueprint
	var category := str(data.category)
	var result: Array[Dictionary] = []
	var box := AABB()
	var first := true
	var has_authored_groups := false
	for part in Design.active_voxels(data):
		has_authored_groups = has_authored_groups or part.has("animation_group")
		var pos := Geometry.preview_transform(part, category).origin
		if category in ["工具", "武器"]:
			pos -= Vector3(-0.34, 0.78, 0.18)
		var edge := Geometry.dimensions(part).x
		result.append({"pos": pos, "edge": edge, "tint": preload("res://scripts/blueprint/BlueprintMaterials.gd").tint(part), "group": str(part.get("animation_group", "body")), "surface": preload("res://scripts/blueprint/BlueprintMaterials.gd").utility_surface(part)})
		var extent := AABB(pos - Vector3.ONE * edge * 0.5, Vector3.ONE * edge)
		box = extent if first else box.merge(extent)
		first = false
	if category == "道具摆件":
		var offset := Vector3(-box.get_center().x, -box.position.y, -box.get_center().z)
		for part in result:
			part.pos += offset
		# Older custom containers did not store an animation group. Infer a lid
		# from their highest cubes while preserving the authored positions.
		if id in [501, 506] and not has_authored_groups:
			for part in result:
				if part.pos.y >= box.size.y * 0.78: part.group = "lid"
	return result

extends SceneTree

const Cubes = preload("res://scripts/content/CubeParts.gd")
const Tool = preload("res://scripts/player/ToolVisual.gd")
const Weapon = preload("res://scripts/player/WeaponVisual.gd")
const Document = preload("res://scripts/player/DocumentVisual.gd")
const Character = preload("res://scripts/player/CharacterVisual.gd")
const Display = preload("res://scripts/ui/ItemDisplay3D.gd")
var checks: int = 0
var failures: int = 0

func _initialize() -> void:
	create_timer(30.0).timeout.connect(func(): push_error("ITEM_CUBE_TIMEOUT"); quit(1))
	_run.call_deferred()

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(label)

func _run() -> void:
	for id in range(201, 210):
		var tool = Tool.new()
		tool.tool_id = id
		root.add_child(tool)
		check(all_meshes_are_cubes(tool), "Tool " + str(id) + " uses actual cube vertices and no part rotation")
		tool.free()
	for id in range(301, 306):
		var weapon = Weapon.new()
		weapon.weapon_id = id
		root.add_child(weapon)
		check(all_meshes_are_cubes(weapon), "Weapon " + str(id) + " uses actual cube vertices and no part rotation")
		weapon.free()
	for id in [108, 109]:
		var document = Document.new()
		document.item_id = id
		root.add_child(document)
		check(all_meshes_are_cubes(document), "Paper, cover and pen " + str(id) + " contain only cubes")
		document.free()
	var character = Character.new()
	root.add_child(character)
	for slot in range(7):
		check(character.equipment_visuals.pieces[slot].all(func(p): return cube_mesh(p.mesh) and p.basis.is_equal_approx(Basis.IDENTITY)), "Base worn equipment slot " + str(slot) + " is a rigid cube assembly")
		var display = Display.new()
		root.add_child(display)
		display.set_item(101 + slot)
		check(all_meshes_are_cubes(display), "Base equipment icon " + str(slot) + " contains cubes")
		display.free()
	character.free()
	for extent in [Vector3(0.5, 0.61, 0.26), Vector3(0.008, 0.44, 0.025), Vector3(0.58, 0.016, 0.43)]:
		var mesh := Cubes.mesh(extent)
		check(cube_mesh(mesh), "Long and thin legacy shapes are tiled with cubes, never stretched cells")
		var error: Vector3 = (mesh.get_aabb().size - extent).abs()
		var edge := float(mesh.get_meta("cube_edge"))
		check(maxf(error.x, maxf(error.y, error.z)) <= edge and mesh.get_meta("cube_count") <= 1024, "Tiling preserves the silhouette within one cube and bounds the part count")
	print("ITEM_CUBE_INTEGRITY_PASS: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

func all_meshes_are_cubes(node: Node) -> bool:
	var meshes := node.find_children("*", "MeshInstance3D", true, false)
	if meshes.is_empty():
		return false
	for instance in meshes:
		if instance.is_queued_for_deletion() or not instance.visible:
			continue
		if not instance.basis.is_equal_approx(Basis.IDENTITY) or not cube_mesh(instance.mesh):
			return false
	return true

func cube_mesh(mesh: Mesh) -> bool:
	# get_faces() builds a physics TriangleMesh, which snaps positions to
	# 0.0001m. Inspect the original render arrays to measure equal edges.
	var arrays := mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
	var faces := PackedVector3Array()
	for index in range(indices.size() if not indices.is_empty() else vertices.size()):
		faces.append(vertices[indices[index]] if not indices.is_empty() else vertices[index])
	if faces.is_empty() or faces.size() % 36 != 0:
		return false
	for start in range(0, faces.size(), 36):
		var minimum: Vector3 = faces[start]
		var maximum: Vector3 = minimum
		for index in range(start, start + 36):
			minimum = minimum.min(faces[index])
			maximum = maximum.max(faces[index])
		var extent := maximum - minimum
		if not Cubes.is_cube(extent) or extent.x <= 0:
			return false
		for index in range(start, start + 36):
			var point := faces[index]
			for axis in range(3):
				if not is_equal_approx(point[axis], minimum[axis]) and not is_equal_approx(point[axis], maximum[axis]):
					return false
	return true

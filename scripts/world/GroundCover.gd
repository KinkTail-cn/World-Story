extends RefCounted

# Sparse decorative grass blades. These cubes never enter the terrain collider
# or the saved block data; one mesh serves the whole chunk.
static func build(cells: Array[Vector3i]) -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var cube := BoxMesh.new()
	cube.size = Vector3.ONE * 0.035
	var arrays := cube.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var count := 0
	for cell in cells:
		var seed_value: int = hash(cell)
		if posmod(seed_value, 12) != 0:
			continue
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_value
		var root := Vector3(cell) + Vector3(rng.randf_range(0.2, 0.8), 1.0, rng.randf_range(0.2, 0.8))
		for stem in range(3):
			var height := 4 if stem == 1 else 2
			for level in range(height):
				var center := root + Vector3((stem - 1) * 0.035, 0.0175 + level * 0.035, 0.0)
				var tint := Color("739a60")
				tint.a = 0.02 + float(level) * 0.045
				for index in indices:
					surface.set_normal(normals[index])
					surface.set_color(tint)
					surface.set_uv(Vector2(20.5 / 48.0, 8.5 / 320.0))
					surface.set_uv2(Vector2(root.x, root.z))
					surface.add_vertex(vertices[index] + center)
				count += 1
	if count == 0:
		return null
	var mesh := surface.commit()
	mesh.set_meta("grass_cube_count", count)
	return mesh

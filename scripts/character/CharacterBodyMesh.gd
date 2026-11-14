extends RefCounted

const Definition = preload("res://scripts/character/CharacterDefinition.gd")
const SHADER = preload("res://shaders/character_cubes.gdshader")

static func build(data: Dictionary, editing: bool = false) -> Dictionary:
	var groups := {}
	for cube in data.get("cubes", []):
		if editing and bool(cube.get("hidden", false)):
			continue
		if not groups.has(cube.bone):
			var surface := SurfaceTool.new()
			surface.begin(Mesh.PRIMITIVE_TRIANGLES)
			groups[cube.bone] = surface
		append_cube(groups[cube.bone], Definition.vector(cube.center), float(cube.edge), Color(cube.color))
	var result := {}
	for bone in groups:
		result[bone] = groups[bone].commit()
	return result

static func append_cube(surface: SurfaceTool, center: Vector3, edge: float, color: Color) -> void:
	var normals := [Vector3.RIGHT, Vector3.LEFT, Vector3.UP, Vector3.DOWN, Vector3.BACK, Vector3.FORWARD]
	var directions := [Vector3.UP, Vector3.UP, Vector3.RIGHT, Vector3.RIGHT, Vector3.RIGHT, Vector3.LEFT]
	var across := [Vector3.BACK, Vector3.FORWARD, Vector3.FORWARD, Vector3.BACK, Vector3.UP, Vector3.UP]
	for face in range(6):
		var n: Vector3 = normals[face]
		var u: Vector3 = directions[face]
		var v: Vector3 = across[face]
		var corners := [n-u-v, n+u-v, n+u+v, n-u+v]
		for corner in [0,2,1,0,3,2]:
			surface.set_normal(n)
			surface.set_color(color)
			surface.add_vertex(center + Vector3(corners[corner]) * edge * 0.5)

static func material() -> ShaderMaterial:
	var result := ShaderMaterial.new()
	result.shader = SHADER
	return result

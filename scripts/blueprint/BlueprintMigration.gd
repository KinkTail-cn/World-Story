extends RefCounted

const Geometry = preload("res://scripts/blueprint/BlueprintGeometry.gd")
const Cubes = preload("res://scripts/content/CubeParts.gd")

static func required(part: Dictionary) -> bool:
	return not Geometry.is_cube(part)

static func convert_all(parts: Array[Dictionary], category: String, limit: int) -> Array[Dictionary]:
	var weights: Array[int] = []
	for part in parts:
		weights.append(Cubes.weight(Geometry.dimensions(part), Geometry.vector(part.get("rotation")) * (PI / 180.0), str(part.get("shape", "box")), part.get("cloth", {})))
	var allowances := Cubes.budgets(weights, limit)
	var result: Array[Dictionary] = []
	for index in parts.size():
		result.append_array(convert_part(parts[index], str(parts[index].get("part", category)), allowances[index]))
	return result

static func convert_part(part: Dictionary, category: String, budget: int) -> Array[Dictionary]:
	if not required(part):
		var copy := part.duplicate(true)
		copy.erase("rotation")
		return [copy]
	var cells := Cubes.sample(Geometry.dimensions(part), Geometry.vector(part.get("rotation")) * (PI / 180.0), str(part.get("shape", "box")), part.get("cloth", {}), budget)
	var result: Array[Dictionary] = []
	for cell in cells:
		var copy := part.duplicate(true)
		var transform := Geometry.character_transform(part, category)
		transform.origin += Vector3(cell.pos)
		Geometry.set_character_transform(copy, category, transform)
		copy["dimensions"] = Geometry.array(Vector3.ONE * float(cell.edge))
		if not result.is_empty():
			copy["uid"] = str(part.get("uid", "converted")) + "_cube_" + str(result.size())
		copy["label"] = str(part.get("label", "转换部件")) + "·方块" + str(result.size() + 1)
		if cell.has("tint"):
			copy["tint"] = cell.tint
		result.append(copy)
	return result

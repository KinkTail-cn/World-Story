extends RefCounted

static func design(id: int) -> Dictionary:
	var category := "工具" if id in range(201, 210) else ("武器" if id in range(301, 306) else "道具摆件")
	var data = preload("res://scripts/blueprint/BlueprintData.gd").new(preload("res://scripts/inventory/ItemCatalog.gd").title(id) + " 副本", category)
	data.target_item_id = id
	var Geometry = preload("res://scripts/blueprint/BlueprintGeometry.gd")
	for cube in preload("res://scripts/content/UtilityModels.gd").parts(id):
		var pos: Vector3 = cube.pos
		if category != "道具摆件": pos += Vector3(-0.34, 0.78, 0.18)
		var part := Geometry.primitive(category, pos, Vector3.ONE * float(cube.edge))
		part["tint"] = Color(cube.tint).to_html(false)
		part["mat"] = 4
		data.add_part(part)
	return data.to_dictionary()

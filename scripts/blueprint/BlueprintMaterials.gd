extends RefCounted

const NAMES: Array[String] = ["岩纹石", "海纹玉", "暖阳金", "苔痕木", "暮紫晶", "寒铁", "赤陶土", "云母矿"]
const COLORS: Array[Color] = [Color("d28f62"), Color("82a8b8"), Color("d8bf73"), Color("8ca77d"), Color("b38ca8"), Color("7e8798"), Color("d17c6d"), Color("e7d9b2")]
const RESOURCE_IDS: Array[int] = [5, 16, 11, 3, 19, 9, 8, 17]
const SURFACES: Array[String] = ["solid", "metal", "leather", "cloth"]
const SURFACE_NAMES: Array[String] = ["实体", "金属", "皮革", "布料"]
const SHADER = preload("res://shaders/character.gdshader")
const CAPE_SHADER = preload("res://shaders/cape.gdshader")

static func tint(part: Dictionary) -> Color:
	return Color(str(part.tint)) if part.has("tint") else COLORS[clampi(int(part.get("mat", 1)) - 1, 0, 7)]

static func create(part: Dictionary, ghost: bool = false) -> Material:
	if ghost:
		var preview := StandardMaterial3D.new()
		preview.albedo_color = Color(tint(part), 0.48)
		preview.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		preview.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		preview.cull_mode = BaseMaterial3D.CULL_DISABLED
		return preview
	var surface := str(part.get("surface", "solid"))
	if part.get("shape", "box") != "cloth" and surface != "solid":
		var material := StandardMaterial3D.new()
		material.albedo_color = tint(part)
		material.roughness = {"metal": 0.42, "leather": 0.88, "cloth": 0.98}.get(surface, 0.8)
		material.metallic = 0.18 if surface == "metal" else 0.0
		material.metallic_specular = 0.25 if surface == "metal" else 0.10
		return material
	var material := ShaderMaterial.new()
	material.shader = CAPE_SHADER if part.get("shape", "box") == "cloth" else SHADER
	material.set_shader_parameter("base_color", tint(part))
	if part.get("shape", "box") == "cloth":
		var cloth: Dictionary = part.get("cloth", {})
		material.set_shader_parameter("trim_color", Color(str(cloth.get("trim", "c3ad79"))))
		material.set_shader_parameter("emblem", int(cloth.get("emblem", 0)))
	else:
		var roughness := {"solid": 0.8, "metal": 0.42, "leather": 0.88, "cloth": 0.98}
		material.set_shader_parameter("surface_roughness", roughness.get(str(part.get("surface", "solid")), 0.8))
	return material

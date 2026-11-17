extends RefCounted

const NAMES: Array[String] = ["岩纹石", "海纹玉", "暖阳金", "苔痕木", "暮紫晶", "寒铁", "赤陶土", "云母矿"]
const COLORS: Array[Color] = [Color("d28f62"), Color("82a8b8"), Color("d8bf73"), Color("8ca77d"), Color("b38ca8"), Color("7e8798"), Color("d17c6d"), Color("e7d9b2")]
const RESOURCE_IDS: Array[int] = [5, 16, 11, 3, 19, 9, 8, 17]
const SURFACES: Array[String] = ["solid", "metal", "leather", "cloth"]
const SURFACE_NAMES: Array[String] = ["实体", "金属", "皮革", "布料"]
const SHADER = preload("res://shaders/character.gdshader")
const CAPE_SHADER = preload("res://shaders/cube_cape.gdshader")
const SOFT_SHADER = preload("res://shaders/soft_motion.gdshader")
const MOTIONS: Array[String] = ["fixed", "cloth", "leather", "feather", "paper"]
const MOTION_NAMES: Array[String] = ["固定", "布料轻摆", "皮革轻摆", "羽饰轻摆", "纸张微动"]
const ANIMATION_GROUPS: Array[String] = ["body", "lid", "crank", "rope", "bucket", "water", "glow", "glass", "soil", "quilt", "seat", "drawer", "paper", "tool", "crop"]
const ANIMATION_NAMES: Array[String] = ["固定主体", "容器盖子", "井台摇柄", "吊绳", "井桶", "水面", "灯芯", "玻璃", "土壤", "床被与枕头", "椅垫", "工作台抽屉", "桌面图纸", "桌面工具", "作物"]
const VISUAL_SURFACES: Array[String] = ["wood", "metal", "stone", "glass", "water", "fabric", "soil", "plant", "grain", "food", "paper", "glow"]
const VISUAL_SURFACE_NAMES: Array[String] = ["木质", "金属", "石材", "玻璃", "水面", "织物", "土壤", "植物", "谷粒", "食物", "纸张", "灯芯"]

static func tint(part: Dictionary) -> Color:
	return Color(str(part.tint)) if part.has("tint") else COLORS[clampi(int(part.get("mat", 1)) - 1, 0, 7)]

static func utility_surface(part: Dictionary) -> String:
	return str(part.get("visual_surface", {"metal": "metal", "cloth": "fabric", "leather": "fabric"}.get(str(part.get("surface", "solid")), "wood")))

static func create_cape(part: Dictionary) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = CAPE_SHADER
	material.set_shader_parameter("base_color", tint(part))
	material.set_shader_parameter("surface_roughness", {"solid": 0.8, "metal": 0.42, "leather": 0.88, "cloth": 0.98}.get(str(part.get("surface", "cloth")), 0.98))
	material.set_shader_parameter("surface_metallic", 0.18 if part.get("surface", "cloth") == "metal" else 0.0)
	return material

static func create_soft(part: Dictionary, profile: String) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = SOFT_SHADER
	material.set_shader_parameter("base_color", tint(part))
	material.set_shader_parameter("motion_profile", maxi(0, MOTIONS.find(profile) - 1))
	material.set_shader_parameter("surface_roughness", {"metal": 0.42, "leather": 0.88, "cloth": 0.98}.get(str(part.get("surface", "cloth")), 0.9))
	material.set_shader_parameter("surface_metallic", 0.18 if part.get("surface") == "metal" else 0.0)
	return material

static func create(part: Dictionary, ghost: bool = false) -> Material:
	if ghost:
		var preview := StandardMaterial3D.new()
		preview.albedo_color = Color(tint(part), 0.48)
		preview.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		preview.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		preview.cull_mode = BaseMaterial3D.CULL_DISABLED
		return preview
	if VISUAL_SURFACES.has(str(part.get("visual_surface", ""))):
		return create_utility(tint(part), str(part.visual_surface))
	var surface := str(part.get("surface", "solid"))
	if surface != "solid":
		var material := StandardMaterial3D.new()
		material.albedo_color = tint(part)
		material.roughness = {"metal": 0.42, "leather": 0.88, "cloth": 0.98}.get(surface, 0.8)
		material.metallic = 0.18 if surface == "metal" else 0.0
		material.metallic_specular = 0.25 if surface == "metal" else 0.10
		return material
	var material := ShaderMaterial.new()
	material.shader = SHADER
	material.set_shader_parameter("base_color", tint(part))
	material.set_shader_parameter("surface_roughness", 0.8)
	return material

static func create_utility(color: Color, profile: String) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = {"metal": 0.3, "glass": 0.16, "water": 0.18, "fabric": 0.98, "soil": 1.0, "plant": 0.9, "food": 0.85}.get(profile, 0.8)
	material.metallic = 0.45 if profile == "metal" else 0.0
	material.metallic_specular = 0.4 if profile in ["metal", "glass", "water"] else 0.18
	if profile in ["glass", "water"]:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.albedo_color.a = 0.28 if profile == "glass" else 0.78
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
	if profile == "glow":
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = 1.5
	return material

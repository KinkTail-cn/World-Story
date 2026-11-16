extends SubViewportContainer

# The title uses the same terrain, water and sky as the playable island.
# It never loads a player's save, and stops rendering while the menu is hidden.
const World = preload("res://scripts/world/VoxelWorld.gd")
const Atmosphere = preload("res://scripts/world/SkyAtmosphere.gd")
var vista_viewport: SubViewport
var camera: Camera3D
var elapsed: float = 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	stretch = true
	stretch_shrink = 1
	vista_viewport = SubViewport.new()
	vista_viewport.own_world_3d = true
	vista_viewport.msaa_3d = Viewport.MSAA_2X
	add_child(vista_viewport)
	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var material := ShaderMaterial.new()
	material.shader = preload("res://shaders/coastal_sky.gdshader")
	sky.sky_material = material
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("d4e6eb")
	environment.ambient_light_energy = 0.58
	environment.fog_enabled = true
	environment.fog_light_color = Color("c5dbe2")
	environment.fog_density = 0.0018
	var sky_node := WorldEnvironment.new()
	sky_node.environment = environment
	vista_viewport.add_child(sky_node)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-36, -32, 0)
	sun.light_color = Color("fff1d9")
	sun.light_energy = 0.82
	sun.shadow_enabled = true
	vista_viewport.add_child(sun)
	camera = Camera3D.new()
	camera.fov = 48.0
	camera.far = 1400.0
	vista_viewport.add_child(camera)
	var world := World.new()
	world.world_type = "island"
	vista_viewport.add_child(world)
	vista_viewport.add_child(Atmosphere.new())
	visibility_changed.connect(_update_visibility)
	_update_visibility()
	_process(0.0)

func _update_visibility() -> void:
	vista_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS if is_visible_in_tree() else SubViewport.UPDATE_DISABLED
	vista_viewport.process_mode = Node.PROCESS_MODE_ALWAYS if is_visible_in_tree() else Node.PROCESS_MODE_DISABLED
	set_process(is_visible_in_tree())

func _process(delta: float) -> void:
	elapsed += delta
	var angle := 0.64 + sin(elapsed * 0.035) * 0.045
	camera.position = Vector3(16, 17.5, 16) + Vector3(sin(angle), 0, cos(angle)) * 49.0
	camera.look_at(Vector3(9.5, 5.0, 16))

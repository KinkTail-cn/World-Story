extends Node3D

const CLOUD_SHADER = preload("res://shaders/clouds.gdshader")
const CLOUD_COUNT: int = 36
const PERIOD: float = 512.0
const CELL: float = 2.4
const DIRECTIONS: Array[Vector3i] = [Vector3i.RIGHT, Vector3i.LEFT, Vector3i.UP, Vector3i.DOWN, Vector3i.BACK, Vector3i.FORWARD]
const CORNERS: Array = [
	[Vector3(0.5, 0.5, 0.5), Vector3(0.5, 0.5, -0.5), Vector3(0.5, -0.5, -0.5), Vector3(0.5, -0.5, 0.5)],
	[Vector3(-0.5, 0.5, -0.5), Vector3(-0.5, 0.5, 0.5), Vector3(-0.5, -0.5, 0.5), Vector3(-0.5, -0.5, -0.5)],
	[Vector3(-0.5, 0.5, -0.5), Vector3(0.5, 0.5, -0.5), Vector3(0.5, 0.5, 0.5), Vector3(-0.5, 0.5, 0.5)],
	[Vector3(-0.5, -0.5, 0.5), Vector3(0.5, -0.5, 0.5), Vector3(0.5, -0.5, -0.5), Vector3(-0.5, -0.5, -0.5)],
	[Vector3(-0.5, 0.5, 0.5), Vector3(0.5, 0.5, 0.5), Vector3(0.5, -0.5, 0.5), Vector3(-0.5, -0.5, 0.5)],
	[Vector3(0.5, 0.5, -0.5), Vector3(-0.5, 0.5, -0.5), Vector3(-0.5, -0.5, -0.5), Vector3(0.5, -0.5, -0.5)]
]
static var _meshes: Dictionary = {}
var world_seed: int = 1337
var clouds: Array[Dictionary] = []
var elapsed: float = 0.0
var motion_enabled: bool = true
var sun_direction := Vector3(0.4, 0.6, 0.6)

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	var material := ShaderMaterial.new()
	material.shader = CLOUD_SHADER
	material.set_shader_parameter("sun_direction", sun_direction)
	var rng := RandomNumberGenerator.new()
	rng.seed = world_seed + 23041
	for index in CLOUD_COUNT:
		var upper := index % 3 == 0
		var cloud := MeshInstance3D.new()
		cloud.name = "HighCloud_%d" % index if upper else "Cumulus_%d" % index
		cloud.mesh = cloud_mesh(index % 6)
		cloud.material_override = material
		cloud.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		cloud.scale = Vector3.ONE * (1.3 if upper else rng.randf_range(0.85, 1.15))
		add_child(cloud)
		var origin := Vector3((float(index % 6) + 0.5) * PERIOD / 6.0 + rng.randf_range(-24, 24), rng.randf_range(112, 132) if upper else rng.randf_range(58, 72), (floorf(float(index) / 6.0) + 0.5) * PERIOD / 6.0 + rng.randf_range(-24, 24))
		clouds.append({"node": cloud, "origin": origin, "speed": rng.randf_range(0.22, 0.32) if upper else rng.randf_range(0.48, 0.68)})
	_process(0.0)

func _process(delta: float) -> void:
	if motion_enabled:
		elapsed += delta
	var camera := get_viewport().get_camera_3d()
	if camera != null:
		place_around(camera.global_position)

func place_around(camera_position: Vector3) -> void:
	for entry in clouds:
		var origin: Vector3 = entry.origin
		var drift := elapsed * float(entry.speed)
		entry.node.global_position = Vector3(camera_position.x + wrapf(origin.x + drift - camera_position.x, -PERIOD * 0.5, PERIOD * 0.5), origin.y, camera_position.z + wrapf(origin.z + drift * 0.35 - camera_position.z, -PERIOD * 0.5, PERIOD * 0.5))
		var horizontal := Vector2(entry.node.global_position.x - camera_position.x, entry.node.global_position.z - camera_position.z)
		entry.node.visible = horizontal.length_squared() < 242.0 * 242.0

static func cloud_mesh(variant: int) -> ArrayMesh:
	if _meshes.has(variant):
		return _meshes[variant]
	var rng := RandomNumberGenerator.new()
	rng.seed = 7741 + variant * 937
	var cells := {}
	var lobe_count := 3 if variant % 2 == 0 else 4
	for lobe in lobe_count:
		var center := Vector2i(lobe * 3 - 4, rng.randi_range(-2, 2))
		var radius_x := rng.randi_range(3, 4)
		var radius_z := rng.randi_range(2, 3)
		var peak := rng.randi_range(2, 4)
		for x in range(-radius_x, radius_x + 1):
			for z in range(-radius_z, radius_z + 1):
				var distance := pow(float(x) / float(radius_x), 2.0) + pow(float(z) / float(radius_z), 2.0)
				if distance > 1.0:
					continue
				var height := maxi(1, roundi((1.0 - distance * 0.75) * float(peak)))
				for y in height:
					cells[Vector3i(center.x + x, y, center.y + z)] = true
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for cell in cells:
		for face in range(6):
			if cells.has(cell + DIRECTIONS[face]):
				continue
			for corner in [0, 1, 2, 0, 2, 3]:
				surface.set_normal(Vector3(DIRECTIONS[face]))
				surface.add_vertex((Vector3(cell) + Vector3(CORNERS[face][corner])) * CELL)
	var mesh := surface.commit()
	mesh.set_meta("cloud_cube_count", cells.size())
	_meshes[variant] = mesh
	return mesh

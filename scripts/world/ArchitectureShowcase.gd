extends Node3D

signal showcase_ready

const Houses = preload("res://scripts/world/HouseTemplates.gd")
const Villages = preload("res://scripts/world/VillageGenerator.gd")
@export_enum("房屋样式", "随机村庄") var showcase_kind: int = 0
@export var layout_seed: int = 1337
var plan: Dictionary = {}
var world: Node3D
var yaw: float = 0.35
var pitch: float = 0.65
var distance: float = 105.0
var focus := Vector3(0, 7, 0)

class StageWorld extends "res://scripts/world/VoxelWorld.gd":
	var solids: Dictionary = {}
	func _init_origin_island() -> void:
		_origin_blocks.resize(32 * 24 * 32)
		for z in 32:
			for x in 32:
				for y in 24:
					_origin_blocks[_origin_index(Vector3i(x, y, z))] = _get_procedural_block_at(x, y, z)
	func _get_procedural_height(_x: int, _z: int) -> int:
		return 5
	func _get_procedural_block_at(x: int, y: int, z: int) -> int:
		var cell := Vector3i(x, y, z)
		if solids.has(cell):
			return solids[cell]
		return 5 if y <= 2 else (2 if y < 5 else (1 if y == 5 else 0))
	func _is_tree_trunk_at(_x: int, _z: int) -> bool:
		return false
	func _generate_chunk_blocks(coord: Vector2i) -> PackedByteArray:
		var blocks := PackedByteArray()
		blocks.resize(16 * 24 * 16)
		for z in 16:
			for x in 16:
				for y in 24:
					blocks[_chunk_local_index(x, y, z)] = _get_procedural_block_at(coord.x * 16 + x, y, coord.y * 16 + z)
		return blocks

func _ready() -> void:
	var stage := StageWorld.new()
	stage.name = "ArchitectureWorld"
	stage.world_type = "infinite"
	stage.village_generation_version = 0
	if showcase_kind == 0:
		for index in Houses.STYLES.size():
			var shape := Houses.model(Houses.STYLES[index], layout_seed + index)
			var origin := Vector3i(index * 19 - 44, 5, -5)
			for cell in shape.cells:
				stage.solids[origin + cell] = shape.cells[cell]
			for z in range(shape.size.z - 1, 19):
				for x in range(shape.entrance.x - 1, shape.entrance.x + 2):
					stage.solids[origin + Vector3i(x, 0, z)] = 13
		for z in range(12, 15):
			for x in range(-49, 52):
				stage.solids[Vector3i(x, 5, z)] = 13
	else:
		plan = Villages.make_layout(layout_seed)
		var columns := Villages.compile(plan, _flat_height)
		for point in columns:
			var values: PackedInt32Array = columns[point]
			for y in 24:
				if values[y] >= 0:
					stage.solids[Vector3i(point.x, y, point.y)] = values[y]
		distance = 195.0
		focus = Vector3(0, 8, 0)
	world = stage
	stage.world_ready.connect(_finish_stage, CONNECT_ONE_SHOT)
	add_child(stage)
	stage.set_process(false)
	# The flat surroundings keep the complete silhouettes readable in the gallery.
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(512, 512)
	ground.mesh = plane
	ground.position.y = 5.4
	var surface := StandardMaterial3D.new()
	surface.albedo_color = Color("739a60")
	surface.roughness = 1.0
	ground.material_override = surface
	add_child(ground)
	_camera()

func _flat_height(_x: int, _z: int) -> int:
	return 5

func _finish_stage() -> void:
	var rect := Rect2i(-52, -18, 108, 45) if showcase_kind == 0 else Rect2i(plan.bounds).grow(6)
	for z in range(floori(float(rect.position.y) / 16), floori(float(rect.end.y - 1) / 16) + 1):
		for x in range(floori(float(rect.position.x) / 16), floori(float(rect.end.x - 1) / 16) + 1):
			world._load_or_create_chunk(Vector2i(x, z))
		await get_tree().process_frame
	showcase_ready.emit()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		yaw -= event.relative.x * 0.006
		pitch = clampf(pitch + event.relative.y * 0.006, 0.2, 1.3)
		_camera()
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			distance = maxf(18, distance * 0.9)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			distance = minf(260, distance / 0.9)
		_camera()

func _camera() -> void:
	$Camera.position = focus + Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch)) * distance
	$Camera.look_at(focus)

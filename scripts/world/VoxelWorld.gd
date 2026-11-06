extends Node3D

# 方块发生破坏或放置时的全局信号
signal block_changed(cell: Vector3i, id: int)
signal loading_progress(ratio: float, message: String)
signal loading_started
signal world_ready

# 基础资源与着色器预加载
const Catalog = preload("res://scripts/content/BlockCatalog.gd")
const BlockTextures = preload("res://scripts/content/BlockTextures.gd")
const TERRAIN_SHADER: Shader = preload("res://shaders/terrain.gdshader")
const GLASS_SHADER: Shader = preload("res://shaders/glass.gdshader")
const WATER_SHADER: Shader = preload("res://shaders/water.gdshader")
const Document = preload("res://scripts/world/DocumentItem.gd")

# 体素世界基础常量规范
const CHUNK_SIZE: int = 16
const CHUNK_HEIGHT: int = 24
const SIZE: Vector3i = Vector3i(32, 24, 32)
const SEA_LEVEL: float = 2.2
const SEA_FLOOR: float = -18.0
const SPAWN: Vector3 = Vector3(16.5, 6.1, 21.5)

# 六个相邻邻居方向
const DIRECTIONS: Array[Vector3i] = [
	Vector3i(1, 0, 0), Vector3i(-1, 0, 0),
	Vector3i(0, 1, 0), Vector3i(0, -1, 0),
	Vector3i(0, 0, 1), Vector3i(0, 0, -1),
]

# 面片渲染基础常量
const FACE_ORIGINS: Array[Vector3] = [
	Vector3(1, 0, 0), Vector3(0, 0, 1), Vector3(0, 1, 1),
	Vector3(0, 0, 0), Vector3(0, 0, 1), Vector3(1, 0, 0),
]
const FACE_U: Array[Vector3] = [
	Vector3.UP, Vector3.UP, Vector3.RIGHT,
	Vector3.RIGHT, Vector3.RIGHT, Vector3.LEFT,
]
const FACE_V: Array[Vector3] = [
	Vector3.BACK, Vector3.FORWARD, Vector3.FORWARD,
	Vector3.BACK, Vector3.UP, Vector3.UP,
]
const QUAD_UVS: Array[Vector2] = [
	Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1),
]
const TRIANGLE_ORDER: Array[int] = [0, 2, 1, 0, 3, 2]

# 地图模式与世界种子（"infinite": 真实无限大世界, "island": 晴风群岛经典有限地图）
@export var world_type: String = "island"
@export var world_seed: int = 1337

# 视距半径：加载中心区块外围 3 圈（即 7x7 = 49 个区块）
const VIEW_DISTANCE: int = 3
const LOAD_BUDGET_USEC: int = 8000

# 原点晴风岛基础缓存（扁平一维数组：32 * 24 * 32 = 24576 字节）
var _origin_blocks: PackedByteArray = PackedByteArray()

# 活跃区块字典：Vector2i(cx, cz) -> Dictionary(node, visual, collider, blocks)
var _active_chunks: Dictionary = {}

# 玩家修改记录：Vector3i -> int，卸载后再加载时自动覆盖应用，保证建造与破坏永久保留
var _modified_blocks: Dictionary = {}
var _chunk_modifications: Dictionary = {}
var _dirty_chunks: Dictionary = {}

# 区块加载队列与平滑加载状态
var _chunk_load_queue: Array[Vector2i] = []
var _last_player_chunk: Vector2i = Vector2i(-999999, -999999)

# 程序化噪声生成器
var _terrain_noise: FastNoiseLite = FastNoiseLite.new()
var _detail_noise: FastNoiseLite = FastNoiseLite.new()

# 材质与环境引用
var _terrain_material: ShaderMaterial
var _glass_material: ShaderMaterial
var _generated: bool = false
var is_loading: bool = true
var initial_load_position: Vector3 = SPAWN
var _loading_revision: int = 0
var documents: Array[Node3D] = []
var _water: MeshInstance3D
var _sea_floor: MeshInstance3D
var _block_face_uvs: PackedVector2Array = PackedVector2Array()


func _ready() -> void:
	# 1. 初始化程序化噪声配置
	_setup_noise()
	
	# 2. 生成经典起源晴风群岛（地形、3棵树木与新手木屋）至一维扁平预分配缓存
	_init_origin_island()
	
	# 3. 初始化地形着色器材质与贴图图集
	_terrain_material = ShaderMaterial.new()
	_terrain_material.shader = TERRAIN_SHADER
	_terrain_material.set_shader_parameter("block_atlas", BlockTextures.get_atlas_texture())
	_glass_material = ShaderMaterial.new()
	_glass_material.shader = GLASS_SHADER
	_glass_material.set_shader_parameter("block_atlas", BlockTextures.get_atlas_texture())
	_init_uv_cache()
	_create_water()
	
	_generated = true
	
	# 4. 延迟到第一帧启动分帧流式构建，让 UI 有序捕获加载进度并平滑展示加载界面
	_request_initial_load()


## 初始化方块图集 6 面 UV 高速查找表（21种方块 * 6面 * 4角 = 504 个Vector2，查表O(1)无运行时额外开销）
func _init_uv_cache() -> void:
	_block_face_uvs.resize(21 * 6 * 4)
	_block_face_uvs.fill(Vector2.ZERO)
	
	var v_step: float = 1.0 / 20.0
	
	for id in range(1, 21):
		var v_start: float = float(id - 1) * v_step
		for face in range(6):
			var u_offset: float = 0.0
			if face == 2: # 顶面 (+Y)
				u_offset = 1.0 / 3.0
			elif face == 3: # 底面 (-Y)
				u_offset = 2.0 / 3.0
			else: # 四个侧面 (+X, -X, +Z, -Z)
				u_offset = 0.0
				
			for corner in range(4):
				var q_uv: Vector2 = QUAD_UVS[corner]
				var lu: float = 0.0
				var lv: float = 0.0
				if face < 2: # +X, -X
					lu = q_uv.y
					lv = 1.0 - q_uv.x
				elif face == 2: # +Y
					lu = q_uv.x
					lv = 1.0 - q_uv.y
				elif face == 3: # -Y
					lu = q_uv.x
					lv = q_uv.y
				else: # +Z, -Z
					lu = q_uv.x
					lv = 1.0 - q_uv.y
					
				# Keep the full face inside its tile; exact atlas borders can
				# sample dirt or a neighboring block as thin seams on the grass.
				var final_uv := Vector2(u_offset + (0.5 + lu * 15.0) / 48.0, v_start + (0.5 + lv * 15.0) / 320.0)
				var idx: int = (id * 6 + face) * 4 + corner
				_block_face_uvs[idx] = final_uv


func _request_initial_load() -> void:
	is_loading = true
	_loading_revision += 1
	loading_started.emit()
	_build_initial_world.call_deferred(_loading_revision)

## One loading path serves new games and saves, centered on the restored player.
func _build_initial_world(revision: int) -> void:
	if not is_inside_tree() or revision != _loading_revision:
		return
	loading_progress.emit(0.15, "正在准备附近地形与碰撞...")
	var center_chunk := _chunk_coord(Vector3i(initial_load_position.floor()))
	if world_type == "infinite":
		_update_chunks_around(center_chunk, false)
	else:
		_chunk_load_queue.clear()
		for cz in range(2):
			for cx in range(2):
				_chunk_load_queue.append(Vector2i(cx, cz))
	var total := _chunk_load_queue.size()
	var processed := 0
	while not _chunk_load_queue.is_empty():
		var deadline := Time.get_ticks_usec() + LOAD_BUDGET_USEC
		var batch := 0
		while not _chunk_load_queue.is_empty() and batch < 2:
			_load_or_create_chunk(_chunk_load_queue.pop_front())
			processed += 1
			batch += 1
			if Time.get_ticks_usec() >= deadline:
				break
		loading_progress.emit(0.15 + 0.80 * float(processed) / maxf(1.0, total), "正在准备附近区块 (%d/%d)..." % [processed, total])
		await get_tree().process_frame
		if not is_inside_tree() or revision != _loading_revision:
			return
	# Collision shapes are assigned deferred. Let a physics tick commit them.
	await get_tree().physics_frame
	await get_tree().process_frame
	if not is_inside_tree() or revision != _loading_revision:
		return
	_last_player_chunk = center_chunk
	is_loading = false
	loading_progress.emit(1.0, "附近世界已就绪，即将启程！")
	world_ready.emit()


func _process(_delta: float) -> void:
	var camera: Camera3D = get_viewport().get_camera_3d()
	if camera == null:
		return
	
	# 水面和海床随着玩家移动在世界中无缝吸附居中，展现无限海洋
	var center := Vector3(snappedf(camera.global_position.x, 128.0), SEA_LEVEL, snappedf(camera.global_position.z, 128.0))
	if _water != null:
		_water.global_position = center
	if _sea_floor != null:
		_sea_floor.global_position = Vector3(center.x, SEA_FLOOR, center.z)
	
	# 无限地图模式下进行视距区块的流式加载与远距离卸载
	if world_type == "infinite" and not is_loading:
		_update_infinite_chunks(camera.global_position)


## 初始化程序化噪声参数
func _setup_noise() -> void:
	_terrain_noise.seed = world_seed
	_terrain_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_terrain_noise.frequency = 0.012
	_terrain_noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	_terrain_noise.fractal_octaves = 4
	_terrain_noise.fractal_lacunarity = 2.0
	_terrain_noise.fractal_gain = 0.5
	
	_detail_noise.seed = world_seed + 99
	_detail_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_detail_noise.frequency = 0.035


## 将经典晴风群岛、三棵自然树木与新手木屋写入原点一维缓存
func _init_origin_island() -> void:
	_origin_blocks.resize(SIZE.x * SIZE.y * SIZE.z)
	_origin_blocks.fill(0)
	
	# 绘制经典圆形晴风岛与海滩
	for z in range(SIZE.z):
		for x in range(SIZE.x):
			var dx: float = (float(x) - 15.5) / 15.5
			var dz: float = (float(z) - 15.5) / 15.5
			var radius: float = sqrt(dx * dx + dz * dz)
			_origin_put(Vector3i(x, 0, z), 5) # 基岩保护层
			if radius > 0.98:
				continue
			var height: int = 4
			if radius > 0.86:
				height = 2
			elif radius > 0.73:
				height = 3
			elif z < 16 and (x < 12 or x > 20):
				height = 5
				if z < 12 and (x < 11 or x > 22):
					height = 6
				if z < 9 and (x < 10 or x > 23):
					height = 7
			for y in range(1, height + 1):
				var id: int = 5 if y < height - 2 else 2
				if y == height:
					id = 6 if radius > 0.73 else 1
				_origin_put(Vector3i(x, y, z), id)
				
	# 生成三棵经典树木
	_generate_origin_tree(Vector3i(8, 5, 19), 4)
	_generate_origin_tree(Vector3i(24, 6, 14), 4)
	_generate_origin_tree(Vector3i(10, 7, 8), 4)
	
	# 生成新手木屋与露天屋顶结构
	_generate_origin_cottage()


func _origin_index(cell: Vector3i) -> int:
	return cell.x + SIZE.x * (cell.z + SIZE.z * cell.y)


func _origin_put(cell: Vector3i, id: int) -> void:
	if cell.x >= 0 and cell.x < SIZE.x and cell.y >= 0 and cell.y < SIZE.y and cell.z >= 0 and cell.z < SIZE.z:
		_origin_blocks[_origin_index(cell)] = id


func _origin_get(cell: Vector3i) -> int:
	if cell.x >= 0 and cell.x < SIZE.x and cell.y >= 0 and cell.y < SIZE.y and cell.z >= 0 and cell.z < SIZE.z:
		return int(_origin_blocks[_origin_index(cell)])
	return 0


func _generate_origin_tree(base: Vector3i, trunk_height: int) -> void:
	var ground: int = 0
	for y in range(SIZE.y - 1, -1, -1):
		if _origin_get(Vector3i(base.x, y, base.z)) != 0:
			ground = y
			break
	for y in range(ground + 1, ground + trunk_height + 1):
		_origin_put(Vector3i(base.x, y, base.z), 3)
	for layer in range(3):
		var radius: int = 1 if layer == 2 else 2
		for dz in range(-radius, radius + 1):
			for dx in range(-radius, radius + 1):
				if abs(dx) + abs(dz) > radius + 1:
					continue
				var cell: Vector3i = Vector3i(base.x + dx, ground + trunk_height - 1 + layer, base.z + dz)
				if _origin_get(cell) == 0:
					_origin_put(cell, 4)


func _generate_origin_cottage() -> void:
	for z in range(8, 14):
		for x in range(14, 20):
			_origin_put(Vector3i(x, 5, z), 7)
			if x != 14 and x != 19 and z != 8 and z != 13:
				continue
			for y in range(6, 9):
				if z == 13 and (x == 16 or x == 17) and y < 8:
					continue
				if y == 7 and (x == 14 or x == 19) and (z == 10 or z == 11):
					continue
				var corner: bool = (x == 14 or x == 19) and (z == 8 or z == 13)
				_origin_put(Vector3i(x, y, z), 3 if corner else 7)
	for z in range(7, 14):
		for x in range(13, 21):
			if z > 10 and x > 16:
				continue
			var roof_y: int = 9 + (mini(x - 13, 20 - x) >> 1)
			_origin_put(Vector3i(x, roof_y, z), 8)


## 单个区块本地一维扁平索引：16 * 16 * 24 = 6144
func _chunk_local_index(lx: int, y: int, lz: int) -> int:
	return lx + CHUNK_SIZE * (lz + CHUNK_SIZE * y)

func _chunk_coord(cell: Vector3i) -> Vector2i:
	return Vector2i(floori(float(cell.x) / CHUNK_SIZE), floori(float(cell.z) / CHUNK_SIZE))

func _record_modification(cell: Vector3i, id: int) -> void:
	_modified_blocks[cell] = id
	var coord := _chunk_coord(cell)
	if not _chunk_modifications.has(coord):
		_chunk_modifications[coord] = {}
	_chunk_modifications[coord][_chunk_local_index(posmod(cell.x, CHUNK_SIZE), cell.y, posmod(cell.z, CHUNK_SIZE))] = id

func _mark_chunk_dirty(coord: Vector2i) -> void:
	if not _active_chunks.has(coord):
		return
	if _dirty_chunks.is_empty():
		_flush_dirty_chunks.call_deferred()
	_dirty_chunks[coord] = true

func _flush_dirty_chunks() -> void:
	var pending: Array = _dirty_chunks.keys()
	_dirty_chunks.clear()
	for coord in pending:
		_rebuild_chunk_mesh(coord)


## 判断指定坐标是否在世界有效范围内
func contains(cell: Vector3i) -> bool:
	if cell.y < 0 or cell.y >= CHUNK_HEIGHT:
		return false
	if world_type == "island":
		return cell.x >= 0 and cell.x < SIZE.x and cell.z >= 0 and cell.z < SIZE.z
	# 无限世界中，X 和 Z 坐标无边界约束
	return true


## 获取任意世界坐标下的方块 ID
func get_block(cell: Vector3i) -> int:
	if cell.y < 0 or cell.y >= CHUNK_HEIGHT:
		return 0
	if world_type == "island":
		if cell.x < 0 or cell.x >= SIZE.x or cell.z < 0 or cell.z >= SIZE.z:
			return 0
	
	# 优先检查玩家对该方块的持久化修改（挖掘/放置）
	if _modified_blocks.has(cell):
		return _modified_blocks[cell]
		
	var cx: int = floori(float(cell.x) / float(CHUNK_SIZE))
	var cz: int = floori(float(cell.z) / float(CHUNK_SIZE))
	var coord := Vector2i(cx, cz)
	
	# 若该区块处于当前活跃加载状态，从扁平一维数组极速提取
	if _active_chunks.has(coord):
		var chunk_data: Dictionary = _active_chunks[coord]
		var lx: int = cell.x - cx * CHUNK_SIZE
		var lz: int = cell.z - cz * CHUNK_SIZE
		return int(chunk_data.blocks[_chunk_local_index(lx, cell.y, lz)])
		
	# 若处于起源岛屿坐标范围内，从经典岛屿缓存读取
	if cx >= 0 and cx < 2 and cz >= 0 and cz < 2 and not _origin_blocks.is_empty():
		return int(_origin_blocks[_origin_index(cell)])
		
	# 若处于无限世界的远处未加载区块，通过确定性算法即时计算（用于边界相邻遮挡剔除）
	if world_type == "infinite":
		return _get_procedural_block_at(cell.x, cell.y, cell.z)
		
	return 0


## 设置或修改指定世界坐标下的方块
func set_block(cell: Vector3i, id: int) -> bool:
	for document in documents:
		if document.support_cell == cell or document.support_cell + Vector3i.UP == cell:
			return false
	if not _generated or not contains(cell) or cell.y == 0 or id < 0 or (id > 0 and not Catalog.is_valid_block(id)):
		return false
	if get_block(cell) == id:
		return false
		
	# 记录玩家持久化修改
	_record_modification(cell, id)
	
	var cx: int = floori(float(cell.x) / float(CHUNK_SIZE))
	var cz: int = floori(float(cell.z) / float(CHUNK_SIZE))
	var coord := Vector2i(cx, cz)
	
	# 若目标区块已在场景树激活，更新其内部方块数据并重建网格
	if _active_chunks.has(coord):
		var chunk_data: Dictionary = _active_chunks[coord]
		var lx: int = cell.x - cx * CHUNK_SIZE
		var lz: int = cell.z - cz * CHUNK_SIZE
		chunk_data.blocks[_chunk_local_index(lx, cell.y, lz)] = id
		_mark_chunk_dirty(coord)
	
	# 若修改位于区块四周边沿，跨区块联动刷新相邻区块，确保遮挡面完美剔除
	var lx: int = posmod(cell.x, CHUNK_SIZE)
	var lz: int = posmod(cell.z, CHUNK_SIZE)
	if lx == 0:
		_mark_chunk_dirty(Vector2i(cx - 1, cz))
	elif lx == CHUNK_SIZE - 1:
		_mark_chunk_dirty(Vector2i(cx + 1, cz))
	if lz == 0:
		_mark_chunk_dirty(Vector2i(cx, cz - 1))
	elif lz == CHUNK_SIZE - 1:
		_mark_chunk_dirty(Vector2i(cx, cz + 1))
		
	block_changed.emit(cell, id)
	return true


## 判断指定坐标是否位于水体中
func is_water_at(point: Vector3) -> bool:
	return point.y < SEA_LEVEL and point.y > SEA_FLOOR and get_block(Vector3i(to_local(point).floor())) == 0


## 获取初始玩家出生点
func get_spawn_position() -> Vector3:
	if not _generated:
		return to_global(SPAWN)
	var preferred: Vector3i = Vector3i(16, 0, 21)
	for attempt in range(SIZE.x * SIZE.z + 1):
		var x: int = preferred.x if attempt == 0 else (attempt - 1) % SIZE.x
		var z: int = preferred.z if attempt == 0 else floori(float(attempt - 1) / float(SIZE.x))
		for y in range(CHUNK_HEIGHT - 1, 1, -1):
			if get_block(Vector3i(x, y, z)) == 0:
				continue
			if get_block(Vector3i(x, y + 1, z)) == 0 and get_block(Vector3i(x, y + 2, z)) == 0 and get_block(Vector3i(x, y + 3, z)) == 0:
				return to_global(Vector3(float(x) + 0.5, float(y) + 2.1, float(z) + 0.5))
	return to_global(SPAWN)


## 放置图纸/蓝图实体
func place_document(cell: Vector3i, id: int) -> Node3D:
	if id not in [108, 109] or get_block(cell) == 0 or get_block(cell + Vector3i.UP) != 0:
		return null
	for document in documents:
		if document.support_cell == cell:
			return null
	var document = Document.new()
	document.item_id = id
	document.support_cell = cell
	document.position = Vector3(cell) + Vector3(0.5, 1.005, 0.5)
	add_child(document)
	documents.append(document)
	return document


## 移除图纸实体
func remove_document(document: Node3D) -> void:
	documents.erase(document)
	document.queue_free()


## 保存世界数据（包含世界模式、种子、修改方块与图纸列表）
func save_data() -> Dictionary:
	var entries: Array[Dictionary] = []
	for document in documents:
		entries.append(document.save_data())
		
	var mods: Array = []
	for cell in _modified_blocks:
		mods.append([cell.x, cell.y, cell.z, _modified_blocks[cell]])
		
	return {
		"world_type": world_type,
		"world_seed": world_seed,
		"modified_blocks": mods,
		"documents": entries,
		"blocks": Marshalls.raw_to_base64(_origin_blocks) # 兼容原点数据
	}


## 加载并恢复世界数据
func load_data(data: Dictionary, focus_position: Vector3 = SPAWN) -> void:
	initial_load_position = focus_position
	if data.has("world_type"):
		world_type = str(data.world_type)
	if data.has("world_seed"):
		world_seed = int(data.world_seed)
		_setup_noise()
		
	# 还原原点岛屿体素缓存
	var encoded: String = str(data.get("blocks", ""))
	if not encoded.is_empty():
		var blocks := Marshalls.base64_to_raw(encoded)
		if blocks.size() == SIZE.x * SIZE.y * SIZE.z:
			_origin_blocks = blocks
			
	# 还原玩家全局修改记录
	_modified_blocks.clear()
	_chunk_modifications.clear()
	for entry in data.get("modified_blocks", []):
		if entry is Array and entry.size() >= 4:
			var cell := Vector3i(int(entry[0]), int(entry[1]), int(entry[2]))
			var id := int(entry[3])
			if contains(cell) and cell.y > 0 and id >= 0 and id <= 20:
				_record_modification(cell, id)
			
	# 卸载全部现有活跃区块并重新根据当前坐标加载
	for coord in _active_chunks.keys():
		_active_chunks[coord].node.queue_free()
	_active_chunks.clear()
	_chunk_load_queue.clear()
	_dirty_chunks.clear()
	_last_player_chunk = Vector2i(-999999, -999999)
				
	# 还原全部图纸与笔记实体
	for document in documents:
		document.queue_free()
	documents.clear()
	for entry in data.get("documents", []):
		var support: Array = entry.get("support", [])
		if support.size() != 3:
			continue
		var document = place_document(Vector3i(int(support[0]), int(support[1]), int(support[2])), int(entry.get("id", 0)))
		if document != null:
			document.restore_data(entry)
	_request_initial_load()


## 加载或创建单个区块
func _load_or_create_chunk(coord: Vector2i) -> void:
	if _active_chunks.has(coord):
		return
		
	var chunk: Node3D = Node3D.new()
	chunk.name = "Chunk_%d_%d" % [coord.x, coord.y]
	add_child(chunk)
	
	var visual: MeshInstance3D = MeshInstance3D.new()
	visual.material_override = _terrain_material
	chunk.add_child(visual)
	var glass := MeshInstance3D.new()
	glass.name = "Glass"
	glass.material_override = _glass_material
	glass.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	chunk.add_child(glass)
	
	var body: StaticBody3D = StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 1
	chunk.add_child(body)
	
	var collider: CollisionShape3D = CollisionShape3D.new()
	body.add_child(collider)
	
	# 生成并填充该区块的一维扁平体素数据
	var blocks: PackedByteArray = _generate_chunk_blocks(coord)
	
	_active_chunks[coord] = {
		"node": chunk,
		"visual": visual,
		"glass": glass,
		"collider": collider,
		"blocks": blocks
	}
	
	_rebuild_chunk_mesh(coord)


## 生成指定区块的一维扁平数据（16 * 24 * 16）
func _generate_chunk_blocks(coord: Vector2i) -> PackedByteArray:
	var blocks: PackedByteArray = PackedByteArray()
	blocks.resize(CHUNK_SIZE * CHUNK_HEIGHT * CHUNK_SIZE)
	blocks.fill(0)
	
	# 若为起源晴风群岛范围（(0,0), (1,0), (0,1), (1,1)），直接从经典缓存提取
	if coord.x >= 0 and coord.x < 2 and coord.y >= 0 and coord.y < 2:
		for y in range(CHUNK_HEIGHT):
			for lz in range(CHUNK_SIZE):
				var wz: int = coord.y * CHUNK_SIZE + lz
				for lx in range(CHUNK_SIZE):
					var wx: int = coord.x * CHUNK_SIZE + lx
					var origin_idx: int = wx + SIZE.x * (wz + SIZE.z * y)
					blocks[_chunk_local_index(lx, y, lz)] = _origin_blocks[origin_idx]
	else:
		# 极速按列计算地形与树木分布，避免重复噪声运算
		for lz in range(CHUNK_SIZE):
			var wz: int = coord.y * CHUNK_SIZE + lz
			for lx in range(CHUNK_SIZE):
				var wx: int = coord.x * CHUNK_SIZE + lx
				
				# 1. 单列仅计算一次地表高度，避免在每个 Y 上重复执行 2D 噪声
				var ground_h: int = _get_procedural_height(wx, wz)
				
				# (1) 填充基岩与地底岩石/矿石/泥土/沙滩/雪山/草皮
				blocks[_chunk_local_index(lx, 0, lz)] = 5 # 坚不可摧基岩
				for y in range(1, mini(ground_h + 1, CHUNK_HEIGHT)):
					var id: int = 5
					if ground_h <= 2:
						id = 6 if y == ground_h else 5
					elif ground_h == 3:
						id = 6 if y == ground_h else (17 if y == ground_h - 1 else _get_ore_at(wx, y, wz))
					elif ground_h <= 7:
						if y == ground_h:
							id = 1 # 丘陵草方块
						elif y >= ground_h - 2:
							id = 2 # 泥土层
						else:
							id = _get_ore_at(wx, y, wz) # 深层矿石与岩石
					else:
						# 高耸山脉石峰
						if y == ground_h and ground_h >= 8:
							id = 18 # 高耸山顶纯白积雪方块
						elif y >= ground_h - 2:
							id = 5 # 山表素雅岩石
						else:
							id = _get_ore_at(wx, y, wz) # 山脉深层矿石
					blocks[_chunk_local_index(lx, y, lz)] = id
					
				# (2) 快速检查周围自然树木并精准投射树干与树冠
				for dz in range(-2, 3):
					for dx in range(-2, 3):
						var tx: int = wx + dx
						var tz: int = wz + dz
						if _is_tree_trunk_at(tx, tz):
							var th: int = _get_procedural_height(tx, tz)
							if th >= 4 and th <= 7:
								var trunk_height: int = 4
								# 树干原木
								if dx == 0 and dz == 0:
									for y in range(th + 1, mini(th + trunk_height + 1, CHUNK_HEIGHT)):
										blocks[_chunk_local_index(lx, y, lz)] = 3
								# 伞状三层树冠
								var leaf_bottom: int = th + trunk_height - 1
								var adx: int = abs(dx)
								var adz: int = abs(dz)
								for layer in range(3):
									var y: int = leaf_bottom + layer
									if y < CHUNK_HEIGHT:
										var leaf_rad: int = 1 if layer == 2 else 2
										if adx <= leaf_rad and adz <= leaf_rad and (adx + adz <= leaf_rad + 1):
											var idx: int = _chunk_local_index(lx, y, lz)
											if blocks[idx] == 0:
												blocks[idx] = 4
						
	# Only visit edits belonging to this chunk, independent of global history size.
	var modifications: Dictionary = _chunk_modifications.get(coord, {})
	for index in modifications:
		blocks[index] = modifications[index]
			
	return blocks


## 基于数学确定性函数计算无限世界任意坐标的方块种类
func _get_procedural_block_at(wx: int, y: int, wz: int) -> int:
	if y <= 0:
		return 5 # 基岩坚不可摧底层
	if y >= CHUNK_HEIGHT:
		return 0 # 虚空上限
		
	var ground_h: int = _get_procedural_height(wx, wz)
	
	# 1. 地面与地底体素材质判断
	if y <= ground_h:
		if ground_h <= 2:
			return 6 if y == ground_h else 5 # 海底沙石
		elif ground_h == 3:
			return 6 if y == ground_h else (17 if y == ground_h - 1 else _get_ore_at(wx, y, wz)) # 海滩沙子、砂岩与深层矿石
		elif ground_h <= 7:
			if y == ground_h:
				return 1 # 丘陵草方块
			elif y >= ground_h - 2:
				return 2 # 泥土层
			else:
				return _get_ore_at(wx, y, wz) # 深层矿石与岩石
		else:
			# 高耸山脉石峰
			if y == ground_h and ground_h >= 8:
				return 18 # 山顶纯白积雪方块
			elif y >= ground_h - 2:
				return 5 # 山表素雅岩石
			else:
				return _get_ore_at(wx, y, wz) # 深层矿石与岩石
			
	# 2. 自然程序化完整大橡树生成（检查以当前格为中心周围半径2格的树木）
	# 彻底告别单格立柱，生成丰满伞状树冠与坚实树干
	for dz in range(-2, 3):
		for dx in range(-2, 3):
			var tx: int = wx + dx
			var tz: int = wz + dz
			if _is_tree_trunk_at(tx, tz):
				var th: int = _get_procedural_height(tx, tz)
				# 树木仅健康生长于平原与绿草丘陵（高度 4 ~ 7）
				if th >= 4 and th <= 7:
					var trunk_height: int = 4
					# (1) 树干原木（严格同心 dx==0 and dz==0）
					if dx == 0 and dz == 0 and y > th and y <= th + trunk_height:
						return 3 # 原木
						
					# (2) 饱满三维伞状树冠（3层厚实树叶）
					var leaf_bottom: int = th + trunk_height - 1
					if y >= leaf_bottom and y <= leaf_bottom + 2:
						var layer: int = y - leaf_bottom
						var leaf_rad: int = 1 if layer == 2 else 2
						var adx: int = abs(dx)
						var adz: int = abs(dz)
						if adx <= leaf_rad and adz <= leaf_rad and (adx + adz <= leaf_rad + 1):
							return 4 # 苍翠树叶
							
	return 0


## 计算无限世界任意水平坐标的地表基础高度
func _get_procedural_height(wx: int, wz: int) -> int:
	var dist: float = sqrt(pow(float(wx) - 15.5, 2.0) + pow(float(wz) - 15.5, 2.0))
	if dist < 24.0:
		return 1 # 晴风岛环岛内海浅水
	elif dist < 36.0:
		var t: float = (dist - 24.0) / 12.0
		var n: float = _terrain_noise.get_noise_2d(float(wx), float(wz))
		var target_h: float = lerp(1.0, 3.5, (n + 1.0) * 0.5)
		return int(round(lerp(1.0, target_h, t)))
	else:
		var n: float = _terrain_noise.get_noise_2d(float(wx), float(wz))
		var dn: float = _detail_noise.get_noise_2d(float(wx), float(wz)) * 0.12
		var val: float = clampf(n + dn, -1.0, 1.0)
		
		if val < -0.22:
			return 1 # 深海海沟与远洋海底
		elif val < 0.02:
			return 2 # 浅海海床
		elif val < 0.14:
			return 3 # 金黄海滩
		elif val < 0.50:
			# 苍翠平原与起伏丘陵（高度 4 ~ 7）
			return int(round(lerp(4.0, 7.0, (val - 0.14) / 0.36)))
		else:
			# 雄奇高耸的山脉石峰（高度 8 ~ 16）
			return int(round(lerp(8.0, 16.0, (val - 0.50) / 0.50)))


## 依据三维空间确定性哈希生成地底天然矿石与地质构造（高纯生铁、煤矿、金矿、粗糙花岗岩、黑曜石）
func _get_ore_at(wx: int, y: int, wz: int) -> int:
	var h: int = ((wx * 73856093) ^ (y * 19349663) ^ (wz * 83492791)) & 0x7FFFFFFF
	var r: float = float(h % 1000) / 1000.0
	
	# 煤矿石 (ID 10)：高度 2 ~ 14 广泛分布，富存率约 4.5%
	if y >= 2 and y <= 14 and r < 0.045:
		return 10
	# 高纯生铁矿 (ID 9)：高度 2 ~ 10，核心金属资源，富存率约 2.8%
	elif y >= 2 and y <= 10 and r >= 0.045 and r < 0.073:
		return 9
	# 粗糙花岗岩 (ID 15)：高度 3 ~ 15，伴生花岗岩体，富存率约 3.0%
	elif y >= 3 and y <= 15 and r >= 0.073 and r < 0.103:
		return 15
	# 金矿石 (ID 11)：深层高度 1 ~ 6，稀有贵金属，富存率约 1.2%
	elif y >= 1 and y <= 6 and r >= 0.103 and r < 0.115:
		return 11
	# 黑曜石 (ID 19)：底层高度 1 ~ 2 靠近基岩层，超硬晶体，富存率约 0.8%
	elif y >= 1 and y <= 2 and r >= 0.115 and r < 0.123:
		return 19
		
	return 5 # 默认素雅岩石


## 判断指定水平坐标是否生长自然树木（网格抖动采样，确保合理间距与自然森林感）
func _is_tree_trunk_at(tx: int, tz: int) -> bool:
	var dist: float = sqrt(pow(float(tx) - 15.5, 2.0) + pow(float(tz) - 15.5, 2.0))
	# 晴风岛中心 32x32 范围内的树木已由经典函数手工生成，外围才进行程序化生成
	if dist < 36.0:
		return false
		
	var cell_size: int = 8
	var gx: int = floori(float(tx) / float(cell_size))
	var gz: int = floori(float(tz) / float(cell_size))
	
	# 空间哈希确定该 8x8 单元是否有树（平原区域约 40% 的网格有树）
	var h: int = int(posmod(gx * 73856093 ^ gz * 19349663, 1000000007))
	if h % 100 > 40:
		return false
		
	var off_x: int = 2 + (h % (cell_size - 4))
	var off_z: int = 2 + ((h / 10) % (cell_size - 4))
	
	return (tx == gx * cell_size + off_x) and (tz == gz * cell_size + off_z)


## 重建指定区块的三维网格与碰撞体
func _rebuild_chunk_mesh(coord: Vector2i) -> void:
	if not _active_chunks.has(coord):
		return
	var chunk_data: Dictionary = _active_chunks[coord]
	var visual: MeshInstance3D = chunk_data.visual
	var collider: CollisionShape3D = chunk_data.collider
	var blocks: PackedByteArray = chunk_data.blocks
	
	var vertices: PackedVector3Array = PackedVector3Array()
	var normals: PackedVector3Array = PackedVector3Array()
	var colors: PackedColorArray = PackedColorArray()
	var uvs: PackedVector2Array = PackedVector2Array()
	var indices: PackedInt32Array = PackedInt32Array()
	var glass_vertices := PackedVector3Array()
	var glass_normals := PackedVector3Array()
	var glass_colors := PackedColorArray()
	var glass_uvs := PackedVector2Array()
	var glass_indices := PackedInt32Array()
	
	var origin_x: int = coord.x * CHUNK_SIZE
	var origin_z: int = coord.y * CHUNK_SIZE
	
	for y in range(CHUNK_HEIGHT):
		for lz in range(CHUNK_SIZE):
			var wz: int = origin_z + lz
			for lx in range(CHUNK_SIZE):
				var wx: int = origin_x + lx
				var local_idx: int = lx + CHUNK_SIZE * (lz + CHUNK_SIZE * y)
				var id: int = int(blocks[local_idx])
				if id == 0:
					continue
					
				var cell := Vector3i(wx, y, wz)
				
				# 针对 6 个相邻面进行遮挡判定：90% 以上邻居在本区块内，直接纳秒级数组寻址
				for face in range(6):
					var neighbor_id: int = 0
					match face:
						0: # +X
							if lx < CHUNK_SIZE - 1:
								neighbor_id = int(blocks[(lx + 1) + CHUNK_SIZE * (lz + CHUNK_SIZE * y)])
							else:
								neighbor_id = get_block(Vector3i(wx + 1, y, wz))
						1: # -X
							if lx > 0:
								neighbor_id = int(blocks[(lx - 1) + CHUNK_SIZE * (lz + CHUNK_SIZE * y)])
							else:
								neighbor_id = get_block(Vector3i(wx - 1, y, wz))
						2: # +Y
							if y < CHUNK_HEIGHT - 1:
								neighbor_id = int(blocks[lx + CHUNK_SIZE * (lz + CHUNK_SIZE * (y + 1))])
							else:
								neighbor_id = 0 # 顶部天空虚空
						3: # -Y
							if y > 0:
								neighbor_id = int(blocks[lx + CHUNK_SIZE * (lz + CHUNK_SIZE * (y - 1))])
							else:
								neighbor_id = 0 # 底部世界底层
						4: # +Z
							if lz < CHUNK_SIZE - 1:
								neighbor_id = int(blocks[lx + CHUNK_SIZE * ((lz + 1) + CHUNK_SIZE * y)])
							else:
								neighbor_id = get_block(Vector3i(wx, y, wz + 1))
						5: # -Z
							if lz > 0:
								neighbor_id = int(blocks[lx + CHUNK_SIZE * ((lz - 1) + CHUNK_SIZE * y)])
							else:
								neighbor_id = get_block(Vector3i(wx, y, wz - 1))
								
					# Glass hides other glass faces, but must not hide opaque neighbors.
					if neighbor_id != 0 and (neighbor_id != 16 or id == 16):
						continue
						
					var first: int = glass_vertices.size() if id == 16 else vertices.size()
					var face_origin: Vector3 = Vector3(cell) + FACE_ORIGINS[face]
					var tint: Color = Catalog.color(id)
					if id == 1 and face != 2:
						tint = Catalog.color(2)
						if face != 3:
							tint.a = 0.5 # 侧面草缘过渡标记
					elif Catalog.has_special_top(id) and face == 2:
						tint = Catalog.top_color(id)
					elif id == 3 and face == 3:
						tint = Catalog.top_color(3) # 原木底部年轮截面色
							
					var uv_base: int = (id * 6 + face) * 4 if (id >= 1 and id <= 20 and _block_face_uvs.size() >= 504) else -1
					for corner in range(4):
						var uv: Vector2 = QUAD_UVS[corner]
						var vertex := face_origin + FACE_U[face] * uv.x + FACE_V[face] * uv.y
						var texture_uv: Vector2 = _block_face_uvs[uv_base + corner] if uv_base >= 0 else (Vector2(uv.y, uv.x) if face < 2 else uv)
						if id == 16:
							glass_vertices.append(vertex)
							glass_normals.append(Vector3(DIRECTIONS[face]))
							glass_colors.append(tint)
							glass_uvs.append(texture_uv)
						else:
							vertices.append(vertex)
							normals.append(Vector3(DIRECTIONS[face]))
							colors.append(tint)
							uvs.append(texture_uv)
						
					for corner_index in TRIANGLE_ORDER:
						if id == 16:
							glass_indices.append(first + corner_index)
						else:
							indices.append(first + corner_index)

	var mesh := _make_chunk_mesh(vertices, normals, colors, uvs, indices)
	var glass_mesh := _make_chunk_mesh(glass_vertices, glass_normals, glass_colors, glass_uvs, glass_indices)
	visual.mesh = mesh
	chunk_data.glass.mesh = glass_mesh
	var faces := PackedVector3Array()
	if mesh != null:
		faces = mesh.get_faces()
	if glass_mesh != null:
		faces.append_array(glass_mesh.get_faces())
	var shape: ConcavePolygonShape3D = null
	if not faces.is_empty():
		shape = ConcavePolygonShape3D.new()
		shape.set_faces(faces)
	collider.set_deferred("shape", shape)

func _make_chunk_mesh(vertices: PackedVector3Array, normals: PackedVector3Array, colors: PackedColorArray, uvs: PackedVector2Array, indices: PackedInt32Array) -> ArrayMesh:
	if vertices.is_empty():
		return null
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	
	var mesh: ArrayMesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


## 无限世界视距流式加载与卸载更新
func _update_infinite_chunks(player_pos: Vector3) -> void:
	var center_chunk := Vector2i(floori(player_pos.x / float(CHUNK_SIZE)), floori(player_pos.z / float(CHUNK_SIZE)))
	
	if center_chunk != _last_player_chunk:
		_last_player_chunk = center_chunk
		_update_chunks_around(center_chunk, false)
		
	# Limit background work to one chunk; initial loading uses its own time budget.
	if not _chunk_load_queue.is_empty():
		var load_count: int = mini(1, _chunk_load_queue.size())
		for i in range(load_count):
			var c: Vector2i = _chunk_load_queue.pop_front()
			if not _active_chunks.has(c):
				_load_or_create_chunk(c)


## 以目标区块为中心刷新视距加载与卸载范围
func _update_chunks_around(center_chunk: Vector2i, instant: bool) -> void:
	# 1. 卸载超出视距范围的区块
	var unload_distance: int = VIEW_DISTANCE + 1
	var to_unload: Array[Vector2i] = []
	for c in _active_chunks.keys():
		if abs(c.x - center_chunk.x) > unload_distance or abs(c.y - center_chunk.y) > unload_distance:
			to_unload.append(c)
			
	for c in to_unload:
		if _active_chunks.has(c):
			_active_chunks[c].node.queue_free()
			_active_chunks.erase(c)
			
	# 2. 收集视距内所有需要的区块坐标
	var needed: Array[Vector2i] = []
	for dz in range(-VIEW_DISTANCE, VIEW_DISTANCE + 1):
		for dx in range(-VIEW_DISTANCE, VIEW_DISTANCE + 1):
			var c := Vector2i(center_chunk.x + dx, center_chunk.y + dz)
			if not _active_chunks.has(c):
				needed.append(c)
				
	# 按距离由近及远排序，近处区块优先生成
	needed.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return center_chunk.distance_squared_to(a) < center_chunk.distance_squared_to(b)
	)
	
	if instant:
		for c in needed:
			_load_or_create_chunk(c)
		_chunk_load_queue.clear()
	else:
		_chunk_load_queue = needed


## 创建广阔的海水与海床背景平面
func _create_water() -> void:
	var water: MeshInstance3D = MeshInstance3D.new()
	water.name = "Water"
	var plane: PlaneMesh = PlaneMesh.new()
	plane.size = Vector2(2048, 2048)
	water.mesh = plane
	water.position = Vector3(16, SEA_LEVEL, 16)
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = WATER_SHADER
	water.material_override = material
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(water)
	_water = water
	
	var floor_body := StaticBody3D.new()
	floor_body.name = "SeaFloor"
	floor_body.collision_layer = 1
	floor_body.collision_mask = 2
	var shape := WorldBoundaryShape3D.new()
	shape.plane = Plane(Vector3.UP, SEA_FLOOR)
	var collider := CollisionShape3D.new()
	collider.shape = shape
	floor_body.add_child(collider)
	add_child(floor_body)
	
	_sea_floor = MeshInstance3D.new()
	var floor_mesh := PlaneMesh.new()
	floor_mesh.size = Vector2(2048, 2048)
	_sea_floor.mesh = floor_mesh
	_sea_floor.position = Vector3(16, SEA_FLOOR, 16)
	var floor_material := StandardMaterial3D.new()
	floor_material.albedo_color = Color("afc9b5")
	floor_material.roughness = 1.0
	_sea_floor.material_override = floor_material
	add_child(_sea_floor)

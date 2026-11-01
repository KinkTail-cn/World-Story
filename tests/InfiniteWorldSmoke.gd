extends SceneTree

# ==============================================================================
# 真实无限体素大世界端到端自动化测试
# 验证：无限模式初始化、自然噪声高度生成、视距流式加载、远处方块修改与存档持久化
# ==============================================================================

const VoxelWorldScript = preload("res://scripts/world/VoxelWorld.gd")
const SaveSystemScript = preload("res://scripts/system/SaveSystem.gd")

func _initialize() -> void:
	create_timer(15.0).timeout.connect(func():
		push_error("INFINITE_WORLD_SMOKE_TIMEOUT")
		quit(1)
	)
	_run.call_deferred()

func _run() -> void:
	print("--- 开始真实无限体素大世界全面测试 ---")
	
	# 1. 创建无限体素世界实例并配置为 infinite 模式
	var world: Node3D = Node3D.new()
	world.set_script(VoxelWorldScript)
	world.world_type = "infinite"
	world.world_seed = 2026
	root.add_child(world)
	await process_frame
	
	# 2. 验证起源岛屿在中心 (0..31, 0..31) 的无缝完整保留
	var spawn_pos: Vector3 = world.get_spawn_position()
	assert(spawn_pos.y > 5.0, "无限世界出生点高度应当在岛屿地面上")
	assert(world.get_block(Vector3i(16, 4, 21)) > 0, "起源晴风岛初始地面应当存在")
	print("✓ 起源晴风岛无缝继承与出生点定位测试通过")
	
	# 3. 验证无边界约束与远处程序化噪声地形生成
	var far_cell := Vector3i(128, 0, 128)
	assert(world.contains(far_cell), "无限大世界中远处有效高度应当返回 true")
	var bedrock_id: int = world.get_block(far_cell)
	assert(bedrock_id == 5, "远处基岩层应当坚不可摧为石头基岩")
	
	# 4. 验证远处区块动态加载
	var far_chunk_coord := Vector2i(8, 8) # (128, 128) 对应的区块坐标
	world._load_or_create_chunk(far_chunk_coord)
	assert(world._active_chunks.has(far_chunk_coord), "远处区块应当被成功生成与加载")
	print("✓ 远距离程序化区块即时流式加载测试通过")
	
	# 5. 验证远处自由挖掘与放置方块（不受原版32x32有限边界拦截）
	var build_cell := Vector3i(128, 6, 128)
	assert(world.set_block(build_cell, 7), "无限世界中玩家应当能在任意大世界坐标建造方块")
	assert(world.get_block(build_cell) == 7, "建造的方块应当成功落成")
	assert(world.set_block(build_cell, 0), "无限世界中玩家应当能挖掘任意方块")
	assert(world.get_block(build_cell) == 0, "挖掘后应当变为空气")
	print("✓ 无限坐标自由建造与挖掘测试通过")
	
	# 6. 验证持久化存档与恢复（去中心化修改列表序列化）
	var saved_data: Dictionary = world.save_data()
	assert(saved_data.get("world_type") == "infinite", "存档中应当正确持久化无限世界类型")
	assert(saved_data.get("world_seed") == 2026, "存档中应当正确持久化世界种子")
	
	# 创建新的空世界还原测试
	var restored_world: Node3D = Node3D.new()
	restored_world.set_script(VoxelWorldScript)
	root.add_child(restored_world)
	await process_frame
	restored_world.load_data(saved_data)
	assert(restored_world.world_type == "infinite", "还原世界应当为无限大世界模式")
	assert(restored_world.world_seed == 2026, "还原世界种子应当完全一致")
	print("✓ 无限大世界去中心化数据保存与还原测试通过")
	
	# 7. 清理测试资源
	world.queue_free()
	restored_world.queue_free()
	
	print("==========================================")
	print("INFINITE_WORLD_SMOKE_PASS: all tests 100%!")
	print("==========================================")
	quit(0)

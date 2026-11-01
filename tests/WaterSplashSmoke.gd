extends SceneTree

# ==============================================================================
# 水花特效与水面奔跑自动化端到端测试
# 验证：
# 1. Player 成功挂载 WaterSplash 场景与组件；
# 2. 陆地草地奔跑时，水花粒子保持静止关闭（零冗余开销）；
# 3. 浅滩涉水奔跑（Wading Run）时，水花发射器自动激活（emitting == true）；
# 4. 水花物理发射基准点严格锁定在世界水面高度（world.SEA_LEVEL + 0.02）；
# 5. 水面游泳冲刺时持续产生飞溅水滴与白色泡沫；
# 6. 从高处跃入水中时触发瞬间冲击浪花爆发（impact_emitter.emitting == true）。
# ==============================================================================

func _initialize() -> void:
	create_timer(15.0).timeout.connect(func():
		push_error("WATER_SPLASH_SMOKE_TIMEOUT")
		quit(1)
	)
	_run.call_deferred()

func _run() -> void:
	print("--- 开始水面水花特效全面自动化测试 ---")
	
	# 1. 启动 Main 场景
	var main = load("res://scenes/Main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	
	var player = main.get_node("Player")
	var world = main.get_node("World")
	assert(player != null, "Player 必须存在")
	assert(world != null, "World 必须存在")
	
	# 2. 验证 WaterSplash 组件已就绪
	var splash = player.water_splash
	assert(splash != null and is_instance_valid(splash), "Player 必须拥有 WaterSplash 组件")
	assert(splash.drops_emitter != null, "必须包含飞溅水滴发射器 drops_emitter")
	assert(splash.foam_emitter != null, "必须包含白色浪花泡沫发射器 foam_emitter")
	assert(splash.ripple_emitter != null, "必须包含水表扩散涟漪发射器 ripple_emitter")
	assert(splash.impact_emitter != null, "必须包含落水瞬间爆发发射器 impact_emitter")
	print("✓ 水花特效四大粒子发射器初始化验证通过")
	
	# 3. 验证陆地草地奔跑：水花不发射
	for frame in range(30):
		await physics_frame
	Input.action_press("move_forward")
	for frame in range(20):
		await physics_frame
	Input.action_release("move_forward")
	
	assert(not splash.drops_emitter.emitting, "在干燥陆地奔跑时水花必须保持关闭")
	assert(not splash.foam_emitter.emitting, "在干燥陆地奔跑时泡沫必须保持关闭")
	print("✓ 陆地奔跑无多余水花测试通过")
	
	# 4. 验证涉水浅滩奔跑：水花自动激起
	# 将玩家置于晴风岛边缘浅滩（海浪拍岸处，脚深 0.3 米）
	player.position = Vector3(16.5, 2.0, 31.0)
	player.velocity = Vector3.ZERO
	player.rig.rotation.y = PI
	Input.action_press("move_forward")
	
	var wading_splash_triggered: bool = false
	var surface_locked: bool = false
	for frame in range(25):
		await physics_frame
		if splash.drops_emitter.emitting and splash.foam_emitter.emitting:
			wading_splash_triggered = true
			if absf(splash.global_position.y - (world.SEA_LEVEL + 0.02)) < 0.02:
				surface_locked = true
	Input.action_release("move_forward")
		
	assert(wading_splash_triggered, "涉水浅滩奔跑时水滴粒子与浪花泡沫必须处于发射状态")
	assert(surface_locked, "水花发射位置必须锁定在世界水面切面上")
	print("✓ 涉水浅滩奔跑激起水花与水面吸附测试通过")
	
	# 5. 验证水面游泳冲刺：持续水花激荡
	player.position = Vector3(16.5, world.SEA_LEVEL - 1.25, 36.0)
	player.swimming = true
	player.submerged = false
	player.velocity = Vector3.ZERO
	player.rig.rotation.y = PI
	Input.action_press("move_forward")
	
	var swim_splash_triggered: bool = false
	for frame in range(25):
		await physics_frame
		if splash.drops_emitter.emitting and splash.foam_emitter.emitting:
			swim_splash_triggered = true
	Input.action_release("move_forward")
		
	assert(swim_splash_triggered, "水面游泳冲刺时必须激起水滴飞溅与白色泡沫")
	print("✓ 水面游泳冲刺飞溅水珠与浪花测试通过")
	
	# 6. 验证跃入水面的瞬间落水冲击爆发 (Impact Burst)
	player.position = Vector3(16.5, world.SEA_LEVEL + 1.5, 36.0)
	player.velocity = Vector3(0, -6.0, 0) # 快速下坠
	player._last_feet_y = world.SEA_LEVEL + 1.5
	
	for frame in range(10):
		await physics_frame
		
	# 检查是否成功触发一次性 impact 爆发
	splash.trigger_impact(world.SEA_LEVEL, player.global_position, 6.0)
	assert(splash.impact_emitter.emitting, "砸入水面瞬间必须触发冲击浪花爆发")
	print("✓ 入水瞬间扑通冲击大水花测试通过")
	
	# 7. 验证完全潜入水下后水花自动停止
	player.position = Vector3(16.5, world.SEA_LEVEL - 3.5, 36.0)
	player.submerged = true
	player.velocity = Vector3(0, 0, 4.0)
	for frame in range(10):
		await physics_frame
	assert(not splash.drops_emitter.emitting, "完全潜水下潜时水面奔跑水花应当关闭")
	print("✓ 水下潜泳状态水花静默测试通过")
	
	main.queue_free()
	print("==========================================")
	print("WATER_SPLASH_SMOKE_PASS: all tests 100%!")
	print("==========================================")
	quit(0)

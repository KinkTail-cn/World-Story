extends Node3D

# ==============================================================================
# 水花特效组件 (WaterSplashEffect)
# 职责：在角色涉水奔跑、水面游泳加速或跃入水中时，在水面高度产生真实的
# 晶莹飞溅水珠 (Drops)、白色水花泡沫 (Foam) 与水表扩散涟漪 (Ripples)。
# ==============================================================================

# 粒子发射器节点
var drops_emitter: CPUParticles3D
var foam_emitter: CPUParticles3D
var ripple_emitter: CPUParticles3D
var impact_emitter: CPUParticles3D

# 运行状态控制
var is_active: bool = false
var current_speed: float = 0.0


func _ready() -> void:
	top_level = true # 脱离父节点变换层次，发射器直接在世界坐标系定位
	_build_particles()


## 构建四大粒子发射系统（预实例化与资源复用，避免频繁 add/free）
func _build_particles() -> void:
	# 1. 晶莹飞溅水珠 (Drops)
	drops_emitter = CPUParticles3D.new()
	drops_emitter.name = "WaterDrops"
	drops_emitter.emitting = false
	drops_emitter.amount = 32
	drops_emitter.lifetime = 0.42
	drops_emitter.one_shot = false
	drops_emitter.explosiveness = 0.12
	drops_emitter.randomness = 0.45
	drops_emitter.local_coords = false # 粒子留在世界水面轨迹上
	drops_emitter.gravity = Vector3(0, -11.5, 0)
	drops_emitter.direction = Vector3(0, 1, -0.6)
	drops_emitter.spread = 42.0
	drops_emitter.initial_velocity_min = 2.4
	drops_emitter.initial_velocity_max = 4.8
	
	var drop_mesh := BoxMesh.new()
	drop_mesh.size = Vector3(0.08, 0.08, 0.08)
	var drop_mat := StandardMaterial3D.new()
	drop_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	drop_mat.albedo_color = Color(0.85, 0.96, 1.0, 0.90)
	drop_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	drop_mesh.material = drop_mat
	drops_emitter.mesh = drop_mesh
	add_child(drops_emitter)
	
	# 2. 白色水花喷雾与气泡 (Foam)
	foam_emitter = CPUParticles3D.new()
	foam_emitter.name = "WaterFoam"
	foam_emitter.emitting = false
	foam_emitter.amount = 24
	foam_emitter.lifetime = 0.35
	foam_emitter.one_shot = false
	foam_emitter.explosiveness = 0.18
	foam_emitter.randomness = 0.5
	foam_emitter.local_coords = false
	foam_emitter.gravity = Vector3(0, 0.8, 0)
	foam_emitter.direction = Vector3(0, 1, 0)
	foam_emitter.spread = 55.0
	foam_emitter.initial_velocity_min = 1.0
	foam_emitter.initial_velocity_max = 2.2
	
	var foam_mesh := BoxMesh.new()
	foam_mesh.size = Vector3(0.14, 0.10, 0.14)
	var foam_mat := StandardMaterial3D.new()
	foam_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	foam_mat.albedo_color = Color(0.92, 0.98, 1.0, 0.65)
	foam_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	foam_mesh.material = foam_mat
	foam_emitter.mesh = foam_mesh
	add_child(foam_emitter)
	
	# 3. 水表扩散波纹圆环 (Ripples)
	ripple_emitter = CPUParticles3D.new()
	ripple_emitter.name = "WaterRipples"
	ripple_emitter.emitting = false
	ripple_emitter.amount = 12
	ripple_emitter.lifetime = 0.58
	ripple_emitter.one_shot = false
	ripple_emitter.explosiveness = 0.2
	ripple_emitter.local_coords = false
	ripple_emitter.gravity = Vector3.ZERO
	ripple_emitter.direction = Vector3.UP
	ripple_emitter.spread = 15.0
	ripple_emitter.initial_velocity_min = 0.1
	ripple_emitter.initial_velocity_max = 0.3
	
	# 水平平卧扁圆柱模拟波纹圈
	var ripple_mesh := CylinderMesh.new()
	ripple_mesh.top_radius = 0.36
	ripple_mesh.bottom_radius = 0.42
	ripple_mesh.height = 0.015
	var ripple_mat := StandardMaterial3D.new()
	ripple_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ripple_mat.albedo_color = Color(0.82, 0.94, 1.0, 0.35)
	ripple_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ripple_mesh.material = ripple_mat
	ripple_emitter.mesh = ripple_mesh
	add_child(ripple_emitter)
	
	# 4. 入水扑通环形浪花爆发 (Impact)
	impact_emitter = CPUParticles3D.new()
	impact_emitter.name = "WaterImpact"
	impact_emitter.emitting = false
	impact_emitter.amount = 45
	impact_emitter.lifetime = 0.52
	impact_emitter.one_shot = true
	impact_emitter.explosiveness = 0.95
	impact_emitter.local_coords = false
	impact_emitter.gravity = Vector3(0, -12.0, 0)
	impact_emitter.direction = Vector3(0, 1, 0)
	impact_emitter.spread = 75.0
	impact_emitter.initial_velocity_min = 3.2
	impact_emitter.initial_velocity_max = 6.2
	
	var impact_mesh := BoxMesh.new()
	impact_mesh.size = Vector3(0.11, 0.11, 0.11)
	var impact_mat := StandardMaterial3D.new()
	impact_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	impact_mat.albedo_color = Color(0.88, 0.97, 1.0, 0.92)
	impact_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	impact_mesh.material = impact_mat
	impact_emitter.mesh = impact_mesh
	add_child(impact_emitter)


## 逐帧更新水花发射状态与水面空间对齐
func update_splash(
	_delta: float,
	is_in_water: bool,
	speed: float,
	is_sprinting: bool,
	move_dir: Vector3,
	sea_level: float,
	player_pos: Vector3
) -> void:
	if not is_in_water or speed < 0.8:
		# 停止发射，原有粒子平滑淡出完毕
		if drops_emitter.emitting:
			drops_emitter.emitting = false
		if foam_emitter.emitting:
			foam_emitter.emitting = false
		if ripple_emitter.emitting:
			ripple_emitter.emitting = false
		return
		
	# 发射源物理位置锁定在角色脚下的水面高度 (略高 2 厘米防止闪烁)
	var water_surface_pos := Vector3(player_pos.x, sea_level + 0.02, player_pos.z)
	global_position = water_surface_pos
	
	# 根据运动方向计算喷射反方向（向后向斜上方抛出浪花）
	var splash_dir := Vector3.UP * 0.75
	if move_dir.length_squared() > 0.01:
		splash_dir += -move_dir * 0.65
	splash_dir = splash_dir.normalized()
	
	drops_emitter.direction = splash_dir
	
	# 根据奔跑冲刺与游动速度动态调节初速度与发射强度
	var speed_factor: float = clampf(speed / 6.0, 0.6, 1.6)
	if is_sprinting:
		speed_factor *= 1.35
		
	drops_emitter.initial_velocity_min = 2.4 * speed_factor
	drops_emitter.initial_velocity_max = 4.8 * speed_factor
	drops_emitter.amount = int(32 * clampf(speed_factor, 0.8, 1.8))
	
	foam_emitter.initial_velocity_min = 1.0 * speed_factor
	foam_emitter.initial_velocity_max = 2.2 * speed_factor
	
	if not drops_emitter.emitting:
		drops_emitter.emitting = true
	if not foam_emitter.emitting:
		foam_emitter.emitting = true
	if not ripple_emitter.emitting:
		ripple_emitter.emitting = true


## 触发砸入水面的瞬间大浪花爆发 (Impact)
func trigger_impact(sea_level: float, player_pos: Vector3, impact_strength: float) -> void:
	var water_surface_pos := Vector3(player_pos.x, sea_level + 0.02, player_pos.z)
	global_position = water_surface_pos
	
	var power: float = clampf(impact_strength / 5.0, 0.8, 2.0)
	impact_emitter.initial_velocity_min = 3.2 * power
	impact_emitter.initial_velocity_max = 6.2 * power
	impact_emitter.amount = int(45 * power)
	impact_emitter.restart()
	impact_emitter.emitting = true

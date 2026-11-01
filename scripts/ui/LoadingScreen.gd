extends Control

# 加载完全完成并淡出后的信号通知
signal loading_completed

@onready var progress_bar: ProgressBar = $Center/Card/Margin/VBox/ProgressSection/ProgressBar
@onready var status_label: Label = $Center/Card/Margin/VBox/ProgressSection/InfoRow/Status
@onready var percent_label: Label = $Center/Card/Margin/VBox/ProgressSection/InfoRow/Percent
@onready var tip_label: Label = $Center/Card/Margin/VBox/TipPanel/TipMargin/TipLabel
@onready var particles_canvas: Control = $ParticlesCanvas

# 旅行小贴士库
const TIPS: Array[String] = [
	"💡 旅行贴士：采集原木与泥土，可以建造你的第一座海岛小屋。",
	"💡 旅行贴士：在三维蓝图工坊中，可以雕刻 1/32 微体素装备，也能编辑武器与摆件蓝图。",
	"💡 旅行贴士：瞄准方块按 F 坐下，可以安静地欣赏海面与天空浮云。",
	"💡 旅行贴士：潜水时按住空格上浮，按住 C 或 Ctrl 下潜，水下 HUD 显示当前深度。",
	"💡 旅行贴士：按下 B 键可随时整理背包，装备不同的武器、工具与防具。",
	"💡 旅行贴士：无限地图中，向晴风岛外探索能发现大陆与山峰；经典岛屿适合专心建造。",
	"💡 旅行贴士：书写笔记与蓝图图纸可以长久摆放在地面或桌台，随时查阅与临摹。",
	"💡 旅行贴士：加载完成后按 F5 保存世界、背包和笔记；退出前记得保存进度。"
]

var target_value: float = 0.0
var current_value: float = 0.0
var is_finishing: bool = false
var motes: Array[Dictionary] = []
var anim_time: float = 0.0
var fade_tween: Tween
var _loading_revision: int = 0

func start_loading() -> void:
	_loading_revision += 1
	if fade_tween != null and fade_tween.is_valid():
		fade_tween.kill()
	is_finishing = false
	visible = true
	modulate.a = 1.0
	target_value = 0.0
	current_value = 0.0
	progress_bar.value = 0.0
	percent_label.text = "0%"


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = true
	modulate.a = 1.0
	progress_bar.value = 0.0
	percent_label.text = "0%"
	
	# 随机精选一条旅行提示
	randomize()
	tip_label.text = TIPS[randi() % TIPS.size()]
	
	# 初始化金光荧火流动粒子
	for i in range(20):
		motes.append({
			"pos": Vector2(randf() * 1280.0, randf() * 720.0),
			"speed": randf_range(15.0, 32.0),
			"radius": randf_range(1.8, 3.6),
			"phase": randf() * TAU,
			"color": Color("#fce488") if randf() > 0.3 else Color("#9efba4")
		})
		
	particles_canvas.draw.connect(_draw_particles)
	set_process(true)


func _process(delta: float) -> void:
	anim_time += delta
	
	# 进度平滑插值缓动
	if current_value < target_value:
		current_value = move_toward(current_value, target_value, delta * 85.0)
		progress_bar.value = current_value
		percent_label.text = "%d%%" % int(current_value)
		
	# 驱动金光粒子飘动
	var vp_size := get_viewport_rect().size
	for p in motes:
		p.pos.y -= p.speed * delta
		p.pos.x += sin(anim_time * 1.5 + p.phase) * 12.0 * delta
		if p.pos.y < -10.0:
			p.pos.y = vp_size.y + 10.0
			p.pos.x = randf() * vp_size.x
			
	particles_canvas.queue_redraw()


func _draw_particles() -> void:
	for p in motes:
		var alpha: float = 0.35 + 0.35 * sin(anim_time * 2.0 + p.phase)
		var c: Color = p.color
		c.a = alpha
		particles_canvas.draw_circle(p.pos, p.radius, c)
		particles_canvas.draw_circle(p.pos, p.radius * 0.4, Color(1, 1, 1, alpha * 0.8))


## 供外部调用：更新加载百分比（0.0 ~ 1.0）与阶段说明
func update_progress(ratio: float, message: String = "") -> void:
	target_value = clampf(ratio * 100.0, 0.0, 100.0)
	if not message.is_empty():
		status_label.text = message


## 供外部调用：世界加载完毕，播放平滑淡出动画
func finish_loading() -> void:
	if is_finishing:
		return
	is_finishing = true
	var revision := _loading_revision
	target_value = 100.0
	current_value = 100.0
	progress_bar.value = 100.0
	percent_label.text = "100%"
	status_label.text = "体素大世界构建完毕，即将启程！"
	
	# 停留 0.15 秒让玩家感知加载完成，随后平滑淡出
	await get_tree().create_timer(0.18).timeout
	if revision != _loading_revision:
		return
	fade_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	fade_tween.tween_property(self, "modulate:a", 0.0, 0.35)
	await fade_tween.finished
	if revision != _loading_revision:
		return
	visible = false
	loading_completed.emit()

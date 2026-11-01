extends Node3D

const INVENTORY = preload("res://scripts/inventory/Inventory.gd")
const BLUEPRINT_MANAGER = preload("res://scripts/blueprint/BlueprintManager.gd")
var inventory
var game_mode: String = "creative"
var world_type: String = "island"
var blueprint_manager = BLUEPRINT_MANAGER.new()
var save_system
var settings_system
var loaded_data: Dictionary = {}
var is_loading: bool = false
var editing_document: Node3D
signal return_to_menu
signal regenerate_requested

@onready var world = $World
@onready var player = $Player
@onready var hud = $HUD
@onready var environment: WorldEnvironment = $Environment
var camera_in_water: bool = false
var surface_fog_color: Color
var surface_fog_density: float

func _ready() -> void:
	if save_system == null:
		save_system = preload("res://scripts/system/SaveSystem.gd").new()
	if settings_system == null:
		settings_system = preload("res://scripts/system/SettingsSystem.gd").new()
	_connect_settings()
	_apply_settings()
	if is_instance_valid(world) and "world_type" in world:
		world.world_type = world_type
	if is_instance_valid(world) and is_instance_valid(hud):
		if world.has_signal("loading_progress"):
			world.loading_progress.connect(hud.update_loading)
		if world.has_signal("world_ready"):
			world.world_ready.connect(hud.finish_loading)
		world.loading_started.connect(_begin_loading)
	hud.loading_screen.loading_completed.connect(_finish_loading)
	_begin_loading()
	inventory = INVENTORY.new(game_mode)
	player.world = world
	player.inventory = inventory
	player.global_position = world.get_spawn_position()
	player.status_changed.connect(hud.update_status)
	player.selection_changed.connect(hud.select_slot)
	player.message.connect(hud.show_message)
	player.water_status_changed.connect(hud.update_water_status)
	player.water_status_changed.connect(_update_water_environment)
	player.function_changed.connect(hud.update_function)
	player.document_requested.connect(_open_document)
	player.document_mined.connect(_on_document_mined)
	hud.function_selected.connect(_choose_function)
	hud.function_cancelled.connect(_close_function_wheel)
	hud.inventory_panel.close_requested.connect(_close_inventory)
	hud.design_closed.connect(_close_design)
	hud.blueprint_workshop.blueprint_saved.connect(_on_blueprint_saved)
	hud.blueprint_workshop.item_crafted.connect(func(item: Dictionary): hud.show_message("已制作：" + str(item.custom_name) + " · B 背包中右键穿戴，F5 保存进度"))
	inventory.changed.connect(_refresh_inventory)
	hud.bind_inventory(inventory)
	blueprint_manager.load_json()
	hud.bind_blueprints(blueprint_manager)
	environment.environment = environment.environment.duplicate()
	surface_fog_color = environment.environment.fog_light_color
	surface_fog_density = environment.environment.fog_density
	hud.resume_requested.connect(_resume)
	hud.restart_requested.connect(_restart)
	hud.quit_requested.connect(func(): get_tree().quit())
	hud.slot_requested.connect(player.select_slot)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	hud.select_slot(0)
	hud.update_function(player.active_function, player.sitting)
	_refresh_inventory()
	_create_clouds()
	if not loaded_data.is_empty():
		save_system.apply_player(player, loaded_data.get("player", {}))
		world.load_data(loaded_data.get("world", {}), player.global_position)
		if not loaded_data.get("player", {}).has("global_position"):
			player.global_position = world.get_spawn_position()
			world.initial_load_position = player.global_position
	else:
		world.initial_load_position = player.global_position

func _begin_loading() -> void:
	is_loading = true
	player.controls_enabled = false
	player.velocity = Vector3.ZERO
	hud.loading_screen.start_loading()

func _finish_loading() -> void:
	is_loading = false
	player.controls_enabled = true
	player.interaction_blocked = true

func setup_lifecycle(value, settings, data: Dictionary) -> void:
	if settings_system != null and settings_system.changed.is_connected(_apply_settings):
		settings_system.changed.disconnect(_apply_settings)
	save_system = value
	settings_system = settings
	_connect_settings()
	if is_node_ready():
		_apply_settings()
	loaded_data = data
	if not data.is_empty():
		var world_dict: Dictionary = data.get("world", {})
		if world_dict.has("world_type"):
			world_type = str(world_dict.world_type)
			if is_instance_valid(world) and "world_type" in world:
				world.world_type = world_type
	if is_node_ready() and not data.is_empty():
		save_system.apply_player(player, data.get("player", {}))
		if is_instance_valid(world):
			world.load_data(data.get("world", {}), player.global_position)
		_refresh_inventory()

func _connect_settings() -> void:
	if not settings_system.changed.is_connected(_apply_settings):
		settings_system.changed.connect(_apply_settings)

func _apply_settings() -> void:
	if is_inside_tree():
		settings_system.apply(get_viewport(), player)

func save_progress() -> bool:
	if is_loading:
		hud.show_message("正在准备世界，请加载完成后再保存")
		return false
	if save_system == null:
		return false
	var data := {"mode": inventory.mode, "player": save_system.save_player(player), "world": world.save_data()}
	if not save_system.save_game(data):
		hud.show_message("保存失败")
		return false
	if not blueprint_manager.save_json():
		hud.show_message("世界已保存，但蓝图库与笔记保存失败 · 请检查存储空间后重试 F5")
		return false
	hud.show_message("世界进度已保存")
	return true

func _update_water_environment(_swimming: bool, _submerged: bool, underwater: bool, _depth: float) -> void:
	if camera_in_water == underwater:
		return
	camera_in_water = underwater
	environment.environment.fog_light_color = Color("438caa") if underwater else surface_fog_color
	environment.environment.fog_density = 0.055 if underwater else surface_fog_density

func _create_clouds() -> void:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color("e9f0f2")
	var positions: Array[Vector3] = [Vector3(-24, 23, -32), Vector3(18, 28, -48), Vector3(50, 24, -21), Vector3(-35, 25, 25), Vector3(47, 27, 50), Vector3(10, 25, 70)]
	for pos in positions:
		for i in range(5):
			var mesh := SphereMesh.new()
			mesh.radius = 1.0
			mesh.height = 2.0
			var cloud := MeshInstance3D.new()
			cloud.mesh = mesh
			cloud.material_override = material
			cloud.position = pos + Vector3(i * 2.8 - 5.6, sin(i * 1.8) * 0.7, cos(i * 2.4))
			cloud.scale = Vector3(4.4, 1.4 + sin(i * 0.9) * 0.4, 2.7)
			cloud.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(cloud)

func _input(event: InputEvent) -> void:
	if is_loading:
		return
	if event.is_action_pressed("save_game"):
		save_progress()
		get_viewport().set_input_as_handled()
		return
	if hud.blueprint_workshop.visible or hud.notebook_panel.visible:
		if event.is_action_pressed("pause"):
			hud.close_design()
			get_viewport().set_input_as_handled()
		return
	if hud.inventory_panel.visible and hud.inventory_panel.is_editing_text() and not event.is_action_pressed("pause"):
		return
	if event.is_action_pressed("blueprint") and not event.is_echo():
		if not hud.pause_panel.visible:
			if hud.blueprint_workshop.visible:
				hud.close_design()
			else:
				_close_function_wheel()
				_close_inventory()
				get_tree().paused = true
				hud.open_blueprint(player.visual)
				Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("notebook") and not event.is_echo():
		if not hud.pause_panel.visible:
			if hud.notebook_panel.visible:
				hud.close_design()
			else:
				_close_function_wheel()
				_close_inventory()
				get_tree().paused = true
				hud.open_notebook()
				Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("inventory") and not event.is_echo():
		if not hud.pause_panel.visible:
			if hud.inventory_panel.visible:
				_close_inventory()
			else:
				_close_function_wheel()
				get_tree().paused = true
				hud.inventory_panel.open()
				Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("function_wheel") and not event.is_echo():
		if not hud.pause_panel.visible and not hud.inventory_panel.visible:
			if hud.function_wheel.visible:
				_close_function_wheel()
			else:
				player._update_target()
				get_tree().paused = true
				hud.open_function_wheel(player.active_function, player.sitting)
				Input.warp_mouse(get_viewport().get_visible_rect().size * 0.5)
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("pause"):
		if hud.inventory_panel.visible:
			_close_inventory()
			get_viewport().set_input_as_handled()
			return
		if hud.function_wheel.visible:
			_close_function_wheel()
			get_viewport().set_input_as_handled()
			return
		var paused: bool = not get_tree().paused
		get_tree().paused = paused
		hud.set_paused(paused)
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if paused else Input.MOUSE_MODE_CAPTURED
		get_viewport().set_input_as_handled()

func _close_function_wheel() -> void:
	hud.function_wheel.close()
	player.interaction_blocked = true
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _choose_function(index: int) -> void:
	_close_function_wheel()
	player.select_function(index)

func _close_inventory() -> void:
	hud.inventory_panel.close()
	get_tree().paused = false
	player.interaction_blocked = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _close_design() -> void:
	hud.blueprint_workshop.visible = false
	hud.notebook_panel.visible = false
	editing_document = null
	get_tree().paused = false
	player.interaction_blocked = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _open_document(document: Node3D) -> void:
	if hud.any_modal_visible():
		return
	editing_document = document
	get_tree().paused = true
	if document.item_id == 108:
		hud.notebook_panel.open(document.contents)
	else:
		hud.blueprint_workshop.set_player_template(player.visual)
		hud.blueprint_workshop.open(document.contents)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _on_document_mined(document: Node3D) -> void:
	if document == null:
		return
	if editing_document == document:
		_close_design()
	if document.item_id == 109 and document.contents != null and not document.contents.blueprints.is_empty():
		if blueprint_manager.import_blueprints(document.contents.blueprints) and not blueprint_manager.save_json():
			hud.show_message("图纸已保留在背包，蓝图库保存失败 · F5 重试保存")

func _refresh_inventory() -> void:
	player.select_slot(player.selected_slot)
	hud.refresh_inventory()
	if is_instance_valid(player.visual) and is_instance_valid(player.visual.equipment_visuals):
		player.visual.equipment_visuals.apply_equipment(inventory.equipment, inventory.equipment_items)

func _on_blueprint_saved(_blueprint: Dictionary) -> void:
	if editing_document != null:
		hud.show_message("蓝图已写入这张图纸 · F5 保存世界进度")
		hud.blueprint_workshop.status_label.text = "蓝图已写入这张图纸 · F5 保存世界进度"
	elif not blueprint_manager.save_json():
		hud.show_message("蓝图库保存失败，请检查存储空间")
		hud.blueprint_workshop.status_label.text = "蓝图库保存失败，请检查存储空间"

func _resume() -> void:
	get_tree().paused = false
	hud.set_paused(false)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _restart() -> void:
	get_tree().paused = false
	if regenerate_requested.has_connections():
		regenerate_requested.emit()
	else:
		var replacement = load("res://scenes/Main.tscn").instantiate()
		replacement.game_mode = game_mode
		replacement.world_type = world_type
		replacement.setup_lifecycle(save_system, settings_system, {})
		get_parent().add_child(replacement)
		if get_tree().current_scene == self:
			get_tree().current_scene = replacement
		queue_free()

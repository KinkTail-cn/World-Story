extends Node3D

const Sounds = preload("res://scripts/system/FacilitySounds.gd")
const Models = preload("res://scripts/content/FacilityModels.gd")
const Catalog = preload("res://scripts/inventory/ItemCatalog.gd")
var host: StaticBody3D
var service: Node
var record: Dictionary
var model: Node3D
var quiet: bool = false
var phase: float = 0.0
var openness: float = 0.0
var interacting: bool = false
var burning: bool = false
var lit: bool = true
var initialized: bool = false
var crop_stage: int = -1
var grow_amount: float = 1.0
var crop_scale: float = 1.0
var action_age: float = 10.0
var action: String = ""
var seated_actor: WeakRef
var smoke_remaining: float = 0.0
var action_voice: AudioStreamPlayer3D
var fire_voice: AudioStreamPlayer3D
var fire: MultiMeshInstance3D
var smoke: MultiMeshInstance3D
var sparks: MultiMeshInstance3D
var burst: MultiMeshInstance3D
var rope: MultiMeshInstance3D
var contents: MultiMeshInstance3D
var contents_hash: int = 0
var contents_ready: bool = false
var private_surfaces: Array[Dictionary] = []

func _ready() -> void:
	phase = float(posmod(str(record.key).hash(), 1000)) * 0.01
	for mesh in model.material_meshes:
		var profile := str(mesh.get_meta("visual_surface", "wood"))
		if profile in ["glow", "water", "soil"]:
			var material: StandardMaterial3D = mesh.material_override.duplicate()
			mesh.material_override = material
			private_surfaces.append({"material": material, "color": material.albedo_color, "profile": profile})
	if not quiet:
		action_voice = _voice(-24.0)
		if record.kind == "furnace":
			fire_voice = _voice(-34.0)
			fire_voice.stream = Sounds.clip("fire")
	if record.kind in ["furnace", "lamp"]:
		host.light = OmniLight3D.new()
		host.light.position = Vector3(0, 0.37, -0.24 if record.kind == "furnace" else 0)
		host.light.light_color = Color("ffb75b") if record.kind == "furnace" else Color("ffcf84")
		host.light.omni_range = 4.8 if record.kind == "furnace" else 7.5
		host.light.shadow_enabled = false
		add_child(host.light)
	if record.kind == "furnace":
		fire = _instances(14, true)
		smoke = _instances(8, false, true)
		sparks = _instances(5, true)
	if record.kind == "well": rope = _instances(36)
	if record.kind in ["chest", "barrel"]: contents = _instances(6)
	if record.kind == "crop":
		host.crop_root = Node3D.new()
		var soil: AABB = model.group_bounds.get("soil", model.bounds)
		host.crop_root.position = Vector3(soil.get_center().x, soil.end.y, soil.get_center().z)
		crop_scale = minf(1.0, minf(soil.size.x, soil.size.z) / 0.65)
		host.add_child(host.crop_root)
	burst = _instances(16, false, true)
	burst.visible = false
	if service != null and service.has_signal("feedback_requested"):
		service.feedback_requested.connect(_receive)
	update_state()

func _voice(volume: float) -> AudioStreamPlayer3D:
	var voice := AudioStreamPlayer3D.new()
	voice.volume_db = volume
	voice.max_distance = 12.0
	voice.unit_size = 2.0
	add_child(voice)
	return voice

func _instances(count: int, emissive: bool = false, transparent: bool = false) -> MultiMeshInstance3D:
	var renderer := MultiMeshInstance3D.new()
	var instances := MultiMesh.new()
	instances.transform_format = MultiMesh.TRANSFORM_3D
	instances.use_colors = true
	var cube := BoxMesh.new()
	cube.size = Vector3.ONE
	instances.mesh = cube
	instances.instance_count = count
	instances.visible_instance_count = 0
	renderer.multimesh = instances
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.albedo_color = Color.WHITE
	material.roughness = 1.0
	if emissive:
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.emission_enabled = true
		material.emission = Color("f7a650")
		material.emission_energy_multiplier = 1.6
	if transparent:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	renderer.material_override = material
	renderer.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	renderer.custom_aabb = AABB(Vector3(-2, -0.2, -2), Vector3(4, 4, 4))
	add_child(renderer)
	return renderer

func _put(renderer: MultiMeshInstance3D, index: int, position: Vector3, edge: float, color: Color) -> void:
	renderer.multimesh.set_instance_transform(index, Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * edge), position))
	renderer.multimesh.set_instance_color(index, color)

func _sound(kind: String) -> void:
	if action_voice != null:
		action_voice.stream = Sounds.clip(kind)
		action_voice.play()

func update_state() -> void:
	var active := service != null and str(service.active_interaction) == str(record.key)
	if initialized and active != interacting:
		if record.kind in ["chest", "barrel"]: _sound("wood_open" if active else "wood_close")
		elif record.kind == "workbench": _sound("wood_open" if active else "wood_close")
	interacting = active
	var job: Dictionary = record.get("current", {})
	var now := float(service.clock) if service != null else 0.0
	var is_burning: bool = record.kind == "furnace" and not job.is_empty() and now < float(job.get("due", 0))
	if initialized and is_burning != burning:
		_sound("ignite" if is_burning else "fabric")
	burning = is_burning
	var new_lit := bool(record.get("lit", true))
	if initialized and record.kind == "lamp" and new_lit != lit: _sound("switch")
	lit = new_lit
	if host.light != null:
		host.light.visible = burning if record.kind == "furnace" else lit
	if fire_voice != null:
		if burning and not fire_voice.playing: fire_voice.play()
		elif not burning and fire_voice.playing: fire_voice.stop()
	if record.kind == "crop": _crop(int(record.get("growth_stage", 0)))
	if contents != null:
		var slots: Array = record.get("storage", [])
		var signature := slots.hash()
		if not contents_ready or contents_hash != signature:
			contents_ready = true
			contents_hash = signature
			var count := mini(6, slots.size())
			contents.multimesh.visible_instance_count = count
			for index in count:
				_put(contents, index, Vector3(-0.18 + (index % 3) * 0.18, 0.23 + (index / 3) * 0.11, -0.08 + (index / 3) * 0.18), 0.12, Catalog.color(int(slots[index].id)))
	initialized = true
	set_physics_process(true)

func _crop(stage: int) -> void:
	if stage == crop_stage: return
	crop_stage = stage
	for child in host.crop_root.get_children():
		host.crop_root.remove_child(child)
		child.queue_free()
	var parts := Models.crop_parts(stage)
	if parts.is_empty(): return
	var renderer := _instances(parts.size())
	renderer.reparent(host.crop_root, false)
	renderer.multimesh.visible_instance_count = parts.size()
	for index in parts.size(): _put(renderer, index, parts[index].pos, parts[index].edge, parts[index].tint)
	grow_amount = 0.75 if initialized else 1.0

func _receive(key: String, event: String, actor: Node3D) -> void:
	if key != str(record.key): return
	update_state()
	action = event
	action_age = 0.0
	if event == "sit" and is_instance_valid(actor): seated_actor = weakref(actor)
	if event in ["water", "draw_water"]: _sound("water")
	elif event in ["plant", "harvest", "clear_crop"]: _sound("plant")
	elif event in ["rest", "sit"]: _sound("fabric")
	elif event in ["fuel", "smelt", "collect", "deposit", "withdraw"]:
		if not (burning and event in ["fuel", "smelt"]): _sound("metal" if record.kind == "furnace" else "wood_close")
	if event == "plant": grow_amount = 0.25
	set_physics_process(true)

func _physics_process(delta: float) -> void:
	if get_tree().paused or (service != null and service.world.is_loading): return
	phase += delta
	action_age += delta
	update_state()
	var target := 1.0 if interacting else 0.0
	var next_openness := move_toward(openness, target, delta * 4.0)
	if record.kind in ["chest", "barrel"]:
		if quiet and service != null and service.nodes.has(str(record.key)):
			next_openness = service.nodes[str(record.key)].effects.openness
		var amount := next_openness * next_openness * (3.0 - 2.0 * next_openness)
		var angle := amount * (1.32 if record.kind == "chest" else 0.28)
		var shift := Vector3(0, amount * 0.24, 0) if record.kind == "barrel" else Vector3.ZERO
		if host.can_move_lid(angle, shift):
			openness = next_openness
			model.pose("lid", Vector3(angle, 0, 0), shift)
			if host.lid_body != null:
				host.lid_body.rotation.x = angle
				host.lid_body.position = Vector3(model.group_pivots.get("lid", Vector3.ZERO)) + shift
	elif record.kind == "workbench":
		openness = next_openness
		model.pose("drawer", Vector3.ZERO, Vector3(0, 0, -openness * 0.17))
		model.pose("paper", Vector3.ZERO, Vector3(0, sin(phase * 3.0) * 0.002 * openness, 0))
		var tap := sin(clampf(action_age / 0.6, 0, 1) * PI) if action in ["craft", "design"] else 0.0
		model.pose("tool", Vector3.ZERO, Vector3(0, tap * 0.035, 0))
	elif record.kind == "chair":
		var actor: Node3D = seated_actor.get_ref() if seated_actor != null else null
		var occupied := is_instance_valid(actor) and bool(actor.sitting) and actor.global_position.distance_to(host.global_position) < 1.4
		model.pose("seat", Vector3.ZERO, Vector3(0, -0.015 if occupied else 0.0, 0))
	elif record.kind == "bed":
		var settle := sin(clampf(action_age / 1.1, 0, 1) * PI) if action == "rest" else 0.0
		model.pose("quilt", Vector3.ZERO, Vector3(0, -settle * 0.025, 0))
	elif record.kind == "well":
		var pump := clampf(action_age / 1.25, 0, 1) if action == "draw_water" else 1.0
		var drop := sin(pump * PI) * 0.28
		model.pose("crank", Vector3(pump * TAU, 0, 0))
		model.pose("bucket", Vector3.ZERO, Vector3(0, -drop, 0))
		if model.groups.has("rope") and model.groups.has("bucket"):
			model.groups.rope.visible = false
			var rope_bounds: AABB = model.group_bounds.rope
			var bucket_bounds: AABB = model.group_bounds.bucket
			var top := Vector3(rope_bounds.get_center().x, rope_bounds.end.y - 0.0125, rope_bounds.get_center().z)
			var length := maxf(0, top.y - bucket_bounds.end.y + drop)
			var count := mini(36, ceili(length / 0.025))
			rope.multimesh.visible_instance_count = count
			for index in count: _put(rope, index, top + Vector3.DOWN * index * 0.025, 0.025, Color("b9a078"))
		model.pose("water", Vector3.ZERO, Vector3(0, sin(phase * 1.7) * 0.003, 0))
	if record.kind == "crop":
		grow_amount = move_toward(grow_amount, 1.0, delta * 1.8)
		host.crop_root.scale = Vector3.ONE * grow_amount * crop_scale
	for entry in private_surfaces:
		var material: StandardMaterial3D = entry.material
		if entry.profile == "glow":
			var glowing: bool = burning if record.kind == "furnace" else lit
			material.emission_energy_multiplier = 1.4 + sin(phase * 7.0) * 0.12 if glowing else 0.0
			material.albedo_color = entry.color if glowing else Color(entry.color).darkened(0.75)
		elif entry.profile == "soil": material.albedo_color = Color(entry.color).darkened(0.28) if record.get("watered", false) else entry.color
	if host.light != null:
		host.light.light_energy = (1.0 if record.kind == "furnace" else 1.4) * (0.95 + sin(phase * 8.3) * 0.05 + sin(phase * 13.1) * 0.025)
	_fire(delta)
	_burst()
	if record.kind in ["chest", "barrel", "workbench", "chair", "bed", "crop"] and absf(openness - target) < 0.001 and action_age > 1.4 and grow_amount >= 1.0:
		var actor: Node3D = seated_actor.get_ref() if seated_actor != null else null
		if record.kind != "chair" or not is_instance_valid(actor) or not bool(actor.sitting): set_physics_process(false)

func _fire(delta: float) -> void:
	if fire == null: return
	fire.multimesh.visible_instance_count = 14 if burning else 0
	sparks.multimesh.visible_instance_count = 5 if burning else 0
	smoke_remaining = 1.8 if burning else maxf(0.0, smoke_remaining - delta)
	smoke.multimesh.visible_instance_count = 8 if smoke_remaining > 0 else 0
	for index in range(14):
		var wave := 0.5 + 0.5 * sin(phase * (4.0 + index * 0.2) + index * 2.3)
		var position := Vector3(-0.22 + (index % 5) * 0.11, 0.23 + (index / 5) * 0.055 + wave * 0.09, -0.19 + (index % 3) * 0.04)
		_put(fire, index, position, 0.045 + wave * 0.06, Color("ffcc67") if index % 3 else Color("ed7d35"))
	for index in range(8):
		var progress := fposmod(phase * 0.42 + index * 0.125, 1.0)
		_put(smoke, index, Vector3(0.22 + sin(phase * 0.7 + index) * progress * 0.12, 1.12 + progress * 1.05, 0.22 + progress * 0.1), 0.06 + progress * 0.1, Color(0.35, 0.36, 0.35, (1.0 - progress) * 0.3 * minf(1, smoke_remaining)))
	for index in range(5):
		var progress := fposmod(phase * 0.9 + index * 0.21, 1.0)
		_put(sparks, index, Vector3(-0.18 + index * 0.085, 0.28 + progress * 0.3, -0.37 - progress * 0.08), 0.014 * (1.0 - progress), Color("ffe1a0"))

func _burst() -> void:
	var enabled := action in ["plant", "water", "draw_water", "harvest", "rest", "smelt", "fuel"] and action_age < 1.1
	burst.visible = enabled
	burst.multimesh.visible_instance_count = 16 if enabled else 0
	if not enabled: return
	var water := action in ["water", "draw_water"]
	var color := Color("7fc5d3") if water else (Color("c8e2bf") if action == "rest" else Color("d8ba76"))
	for index in range(16):
		var angle := float(index) * 2.399
		var age := maxf(0, action_age - float(index % 4) * 0.05)
		var radius := 0.05 + age * (0.24 if water else 0.32)
		var y := (0.34 if record.kind in ["crop", "well"] else 0.65) + (age * 0.18 if action == "rest" else age * 0.4 - age * age * 0.65)
		_put(burst, index, Vector3(cos(angle) * radius, maxf(0.28, y), sin(angle) * radius), (0.018 if action == "plant" else 0.028) * clampf(1.0 - age, 0, 1), Color(color, clampf(1.0 - age, 0, 1)))

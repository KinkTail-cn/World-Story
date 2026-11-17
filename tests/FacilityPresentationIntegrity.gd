extends SceneTree

const Models = preload("res://scripts/content/UtilityModels.gd")
const Visual = preload("res://scripts/player/UtilityVisual.gd")
const Items = preload("res://scripts/content/VillageItems.gd")
const Materials = preload("res://scripts/blueprint/BlueprintMaterials.gd")
const Data = preload("res://scripts/blueprint/BlueprintData.gd")
const Presets = preload("res://scripts/blueprint/UtilityPresets.gd")
const Design = preload("res://scripts/blueprint/BlueprintEquipment.gd")
var checks: int = 0
var failures: int = 0
var capture_enabled: bool = false

func _initialize() -> void:
	capture_enabled = "--capture" in OS.get_cmdline_user_args()
	create_timer(38.0).timeout.connect(func(): push_error("FACILITY_PRESENTATION_TIMEOUT"); quit(1))
	_run.call_deferred()

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)

func frames(count: int = 4) -> void:
	for index in count: await physics_frame

func _run() -> void:
	for id in range(501, 510):
		var source := Models.parts(id)
		var blueprint := Presets.design(id)
		check(source.size() > 100 and source.size() <= Data.MAX_PARTS and blueprint.voxels.size() == source.size(), "Detailed facility fits the editable cube budget without dropping parts: " + str(id))
		check(Data.validation_error(blueprint).is_empty() and blueprint.voxels.all(func(part: Dictionary): return Data.Geometry.is_cube(part)), "All facility parts remain upright equal-edge cubes: " + str(id))
		var rendered = Visual.new()
		root.add_child(rendered)
		rendered.build(id)
		var bounds: AABB = rendered.bounds
		var extent := Items.size(id)
		check(bounds.position.y >= -0.001 and bounds.end.y <= extent.y + 0.001 and absf(bounds.position.x) <= extent.x * 0.5 + 0.001 and bounds.end.x <= extent.x * 0.5 + 0.001 and absf(bounds.position.z) <= extent.z * 0.5 + 0.001 and bounds.end.z <= extent.z * 0.5 + 0.001, "Rendered structure stays inside its reserved footprint: " + str(id))
		rendered.free()
	for id in Items.SUPPLIES:
		var source := Models.parts(id)
		check(source.size() > 8 and source.size() < 1024 and source.all(func(part: Dictionary): return float(part.edge) >= 0.005 and is_finite(float(part.edge)) and Materials.VISUAL_SURFACES.has(part.surface)), "Material and food silhouettes use bounded, valid cube assemblies: " + str(id))
	var reused = Visual.new()
	root.add_child(reused)
	reused.build(501)
	reused.build(505)
	reused.build(501)
	check(reused.group_bounds.has("lid") and reused.group_pivots.lid.y > 0.4, "Reusing a display preserves other instances' cached animation pivots")
	reused.free()
	var authored := Presets.design(501)
	var restored = Data.from_dictionary(JSON.parse_string(JSON.stringify(authored)))
	check(restored.to_dictionary() == authored, "Animation groups and material profiles survive an exact blueprint JSON round trip")
	var legacy := authored.duplicate(true)
	for part in legacy.voxels: part.erase("animation_group")
	check(Visual.item_parts(501, Design.make_item(legacy)).any(func(part: Dictionary): return part.group == "lid"), "Old container blueprints gain a lid without rewriting the saved geometry")
	var fixed := authored.duplicate(true)
	for part in fixed.voxels: part.animation_group = "body"
	check(not Visual.item_parts(501, Design.make_item(fixed)).any(func(part: Dictionary): return part.group == "lid"), "Explicitly authored fixed parts are not reassigned by legacy inference")
	for fields in [{"animation_group": "unknown"}, {"visual_surface": "unknown"}]:
		var invalid := authored.duplicate(true)
		invalid.voxels[0].merge(fields, true)
		check(not Data.validation_error(invalid).is_empty(), "Unknown presentation metadata is rejected")
	var game = preload("res://scenes/Main.tscn").instantiate()
	game.game_mode = "survival"
	root.add_child(game)
	current_scene = game
	while game.is_loading: await process_frame
	var world = game.world
	var life = world.life
	var player = game.player
	player.set_physics_process(false)
	player.global_position = Vector3(40.5, 6.02, 51.5)
	world.world_type = "infinite"
	world.set_process(false)
	life.set_process(false)
	for z in range(39, 54):
		for x in range(39, 64):
			world.set_block(Vector3i(x, 5, z), 14)
			for y in range(6, 13): world.set_block(Vector3i(x, y, z), 0)
	for z in range(2, 4):
		for x in range(2, 4): world._load_or_create_chunk(Vector2i(x, z))
	await frames()
	var away := AABB(Vector3(-100, 50, -100), Vector3.ONE)
	var keys := {}
	for pair in [[501, 42, 42], [502, 46, 42], [503, 50, 42], [504, 54, 42], [505, 58, 42], [506, 42, 47], [507, 46, 47], [508, 51, 47], [509, 57, 47]]:
		var placed: Dictionary = life.place({"id": pair[0], "count": 1}, Vector3i(pair[1], 5, pair[2]), away)
		check(placed.ok, "Detailed model places on real terrain: " + str(pair[0]))
		if placed.ok: keys[pair[0]] = placed.record.key
	if keys.size() != 9: quit(1); return
	await frames()
	var panel = game.facility_panel
	var chest = life.nodes[keys[501]]
	game._open_facility(keys[501])
	await frames(24)
	check(chest.model.groups.lid.rotation.x > 1.3 and is_equal_approx(chest.lid_body.rotation.x, chest.model.groups.lid.rotation.x), "Opening a real chest moves the visible lid and its collision together")
	check(panel.preview_root != null and panel.preview_root.effects.action_voice == null and panel.preview_root.model.groups.lid.rotation.x > 1.3, "The menu shows the actual open state without a second sound source")
	check(preview_fits(panel), "The open lid and container fit inside the narrow live-preview column")
	await capture_view(game, keys[501], "chest-open")
	panel.close_panel()
	await frames(24)
	check(is_zero_approx(chest.model.groups.lid.rotation.x), "Closing the menu smoothly closes the chest")
	player.global_position = chest.global_position + Vector3(0, chest.model.bounds.end.y + 0.002, 0)
	await frames(2)
	game._open_facility(keys[501])
	await frames(24)
	check(chest.effects.openness < 0.9, "A person standing on the lid prevents it from opening through their body")
	player.global_position = Vector3(40.5, 6.02, 51.5)
	await frames(24)
	check(chest.effects.openness > 0.99, "The lid resumes opening when the obstruction clears")
	panel.close_panel()
	await frames(24)
	await capture_view(game, keys[501], "chest-closed")
	game._open_facility(keys[506])
	await frames(24)
	var barrel = life.nodes[keys[506]]
	check(barrel.model.groups.lid.position.y > float(barrel.model.group_pivots.lid.y) + 0.23, "The barrel lifts its own fitted lid")
	panel.close_panel()
	game.inventory.add_item(9, 2)
	game.inventory.add_item(10, 1)
	check(life.act(keys[502], "smelt", game.inventory, player, 9).ok and life.act(keys[502], "fuel", game.inventory, player, 10).ok, "Actual ore and fuel start the furnace")
	var furnace = life.nodes[keys[502]]
	game._open_facility(keys[502])
	await frames(4)
	check(furnace.light.visible and furnace.effects.fire.multimesh.visible_instance_count > 0 and furnace.effects.fire_voice.playing, "A running furnace produces flame, warm light and a fire loop")
	check(panel.preview_root.effects.burning and panel.preview_root.effects.fire_voice == null, "The furnace menu mirrors processing without duplicating fire audio")
	check(preview_fits(panel), "The furnace fits the tall preview without cutting off its sides")
	life.set_process(true)
	var clock_before: float = life.clock
	await frames(8)
	check(life.clock > clock_before, "The live preview keeps production running while its menu is open")
	paused = true
	var paused_phase: float = furnace.effects.phase
	var preview_phase: float = panel.preview_root.effects.phase
	var paused_clock: float = life.clock
	await frames(6)
	check(furnace.effects.phase == paused_phase and panel.preview_root.effects.phase == preview_phase and life.clock == paused_clock, "A formal pause freezes world effects, menu effects and production together")
	paused = false
	life.set_process(false)
	await capture_view(game, keys[502], "furnace-active")
	panel.close_panel()
	life.clock += 9.0
	life._simulate(furnace.record)
	furnace.update_state()
	await frames(3)
	check(not furnace.light.visible and not furnace.effects.fire_voice.playing and furnace.effects.fire.multimesh.visible_instance_count == 0 and not furnace.record.output.is_empty(), "Completed work stops flame, light and sound while preserving the output")
	await frames(115)
	check(furnace.effects.smoke.multimesh.visible_instance_count == 0, "Residual smoke dissipates after the fire stops")
	game.inventory.add_item(603, 2)
	game.inventory.add_item(609, 1)
	var well = life.nodes[keys[508]]
	check(life.act(keys[508], "draw_water", game.inventory, player).ok, "The well consumes an empty bucket")
	await frames(20)
	check(well.model.groups.bucket.position.y < -0.15 and absf(well.model.groups.crank.rotation.x) > 0.5 and well.effects.burst.visible, "Drawing water lowers the bucket, turns the crank and splashes")
	await capture_view(game, keys[508], "well-drawing")
	await frames(80)
	check(absf(well.model.groups.bucket.position.y) < 0.001, "The well bucket returns to rest after drawing water")
	var crop = life.nodes[keys[507]]
	check(life.act(keys[507], "plant", game.inventory, player).ok, "Seeds create a real planted crop")
	await frames(3)
	check(crop.crop_root.get_child_count() == 1 and crop.effects.grow_amount < 1.0, "New seedlings emerge instead of appearing as mature wheat")
	check(life.act(keys[507], "water", game.inventory, player).ok and game.inventory.count_item(609) == 1, "Watering returns the empty bucket")
	await frames(3)
	var soil_darkened := false
	for surface in crop.effects.private_surfaces:
		if surface.profile == "soil": soil_darkened = surface.material.albedo_color.v < Color(surface.color).v
	check(soil_darkened and crop.effects.burst.visible, "Water visibly darkens the soil and produces droplets")
	var action_before: String = crop.effects.action
	check(not life.act(keys[507], "plant", game.inventory, player).ok and crop.effects.action == action_before, "A failed action does not produce a success animation")
	life.clock += 100.0
	life._simulate(crop.record)
	crop.update_state()
	await frames(70)
	check(crop.record.growth_stage == 3 and crop.effects.crop_stage == 3, "Saved game time produces the mature wheat model")
	check(crop.crop_root.get_child(0).scale.is_equal_approx(Vector3.ONE) and crop.crop_root.position.y > 0.27 and crop.crop_root.position.y + 0.563 <= Items.size(507).y, "Changing growth stages keeps wheat rooted in the soil and inside the planter footprint")
	await capture_view(game, keys[507], "wheat-grown")
	check(life.act(keys[507], "harvest", game.inventory, player).ok and crop.crop_root.get_child_count() == 0, "Harvest removes the visible wheat and returns actual supplies")
	var lamp = life.nodes[keys[505]]
	var lamp_ray := PhysicsRayQueryParameters3D.create(lamp.global_position + Vector3(0, 0.34, -1), lamp.global_position + Vector3(0, 0.34, 1), 1)
	check(world.get_world_3d().direct_space_state.intersect_ray(lamp_ray).get("collider") == lamp, "Aiming at the lantern glass identifies a usable facility")
	var other_lamp: Dictionary = life.place({"id": 505, "count": 1}, Vector3i(61, 5, 42), away)
	check(other_lamp.ok, "A second light can be placed independently")
	await capture_view(game, keys[505], "lamp-lit")
	check(life.act(keys[505], "lamp", game.inventory, player).ok, "The lamp has a working switch")
	await frames(2)
	var wick_dark := false
	for surface in lamp.effects.private_surfaces:
		if surface.profile == "glow": wick_dark = is_zero_approx(surface.material.emission_energy_multiplier)
	check(not lamp.light.visible and wick_dark and life.nodes[other_lamp.record.key].light.visible, "Switching one lamp off darkens its wick without changing another instance")
	await capture_view(game, keys[505], "lamp-off")
	for id in [610, 505]:
		game.inventory.bag[0] = {"id": id, "count": 1}
		player.select_slot(0)
		var held = player.visual.held_item.utility_visual
		if id == 610:
			var water_position: Vector3 = held.groups.water.position
			await frames(8)
			check(not held.groups.water.position.is_equal_approx(water_position), "A carried water bucket has a moving water surface")
		else: check(held.held_light != null and held.held_light.visible, "A carried lantern illuminates its surroundings")
	game.inventory.bag[0] = {"id": 605, "count": 2}
	player.select_slot(0)
	player.health = 50.0
	check(player.use_food_slot(0) and player.health == 78.0 and game.inventory.bag[0].count == 1 and player.visual.consume_time > 0 and player.debris.size() == 8, "Eating a held loaf consumes one, heals, raises the hand and creates small crumbs")
	player.visual.animate(0.2, 0, false, false)
	check(player.visual.right_arm.rotation.x > 1.0, "The eating gesture reaches the mouth rather than the ordinary carry pose")
	player._update_debris(0.8)
	check(player.debris.is_empty(), "Food crumbs are released after their brief lifetime")
	check(player.use_food_slot(0) and game.inventory.bag[0].id == 0 and player.visual.held_item.block_id == 605 and player.first_person_item.block_id == 605, "The final bite is consumed immediately but stays visible for both eating gestures")
	player.set_physics_process(true)
	await frames(45)
	player.set_physics_process(false)
	check(not player.food_display_active and player.visual.held_item.block_id == 0, "The normal player update releases the temporary food model after eating")
	var workshop = game.hud.blueprint_workshop
	workshop.open(game.blueprint_manager)
	workshop._select_category("道具摆件", true)
	workshop.product_selector.select(workshop.product_selector.get_item_index(501))
	workshop.product_selector.item_selected.emit(workshop.product_selector.selected)
	workshop._open_product_template()
	# Select an actual authored lid cube through the normal editor session.
	var lid: Dictionary = workshop.blueprint.voxels.filter(func(part: Dictionary): return part.get("animation_group", "") == "lid")[0]
	workshop.edit_session.select([str(lid.uid)])
	var before_edit: Dictionary = workshop.blueprint.to_dictionary()
	workshop.inspector.animation_box.select(Materials.ANIMATION_GROUPS.find("body"))
	workshop.inspector.animation_box.item_selected.emit(workshop.inspector.animation_box.selected)
	workshop.inspector.visual_surface_box.select(Materials.VISUAL_SURFACES.find("metal"))
	workshop.inspector.visual_surface_box.item_selected.emit(workshop.inspector.visual_surface_box.selected)
	workshop._editor_action("apply")
	check(workshop.edit_session.selected_parts()[0].animation_group == "body" and workshop.edit_session.selected_parts()[0].visual_surface == "metal", "The editor applies functional group and material choices to selected cubes")
	check(workshop.edit_session.undo() and workshop.blueprint.to_dictionary() == before_edit, "Presentation edits participate in exact undo and preserve geometry")
	workshop.edit_session.select([])
	workshop.inspector.animation_box.select(Materials.ANIMATION_GROUPS.find("lid"))
	workshop.inspector.animation_box.item_selected.emit(workshop.inspector.animation_box.selected)
	workshop.inspector.visual_surface_box.select(Materials.VISUAL_SURFACES.find("metal"))
	workshop.inspector.visual_surface_box.item_selected.emit(workshop.inspector.visual_surface_box.selected)
	var placement: Dictionary = workshop._placement_from_hit({"position": Vector3(0, 0.9, 0), "normal": Vector3.UP, "collider": workshop.template_root})
	check(placement.get("animation_group") == "lid" and placement.get("visual_surface") == "metal", "Newly drawn cubes inherit the chosen animation group and material")
	workshop._finish_close()
	var custom: Dictionary = life.place(Design.make_item(authored), Vector3i(60, 5, 47), away)
	check(custom.ok, "An authored container places with its presentation metadata")
	game._open_facility(custom.record.key)
	await frames(24)
	check(life.nodes[custom.record.key].model.groups.lid.rotation.x > 1.3, "A crafted blueprint container retains its lid animation")
	panel.close_panel()
	game.inventory.add_item(9, 1)
	check(life.act(keys[502], "smelt", game.inventory, player, 9).ok, "A saved furnace can contain another active job")
	check(life.act(keys[507], "plant", game.inventory, player).ok, "A saved planter can contain new seedlings")
	var custom_planter: Dictionary = life.place(Design.make_item(Presets.design(507)), Vector3i(60, 5, 50), away)
	check(custom_planter.ok and life.bounds_for(custom_planter.record).size.y > float(custom_planter.record.size[1]) + 0.56, "Authored planters reserve space for their growing crop above the saved structure")
	await capture_gallery(game, keys, false)
	await capture_gallery(game, keys, true)
	check(game.save_progress() and game.save_system.load_world().ok, "Presentation metadata survives the normal validated world save")
	var saved: Dictionary = game.save_system.load_world().data.world.village_life
	life.load_data(saved)
	await frames(3)
	life.refresh()
	await frames(3)
	check(not life.nodes[keys[505]].light.visible and life.nodes[keys[502]].effects.burning and life.nodes[keys[507]].effects.crop_stage == 1, "Reload restores switches, active furnace effects and crop stage")
	check(life.records[custom.record.key].item.blueprint == authored and is_zero_approx(life.nodes[custom.record.key].effects.openness), "Reload preserves authored groups and closes transient container interactions")
	game.queue_free()
	await frames()
	print("FACILITY_PRESENTATION_INTEGRITY_PASS: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

func preview_fits(panel: Control) -> bool:
	var camera: Camera3D = panel.preview_viewport.get_camera_3d()
	var area := Rect2(Vector2.ZERO, Vector2(panel.preview_viewport.size)).grow(2)
	for mesh in panel.preview_root.model.material_meshes:
		var box: AABB = mesh.mesh.get_aabb()
		for corner in range(8):
			var vertex := box.position + Vector3(box.size.x if corner & 1 else 0.0, box.size.y if corner & 2 else 0.0, box.size.z if corner & 4 else 0.0)
			if not area.has_point(camera.unproject_position(mesh.global_transform * vertex)): return false
	return true

func capture_view(game: Node3D, key: String, tag: String) -> void:
	if not capture_enabled: return
	var object: Node3D = game.world.life.nodes[key]
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 2.65 if object.record.kind != "well" else 3.25
	game.add_child(camera)
	var centre: Vector3 = object.global_position + Vector3(0, object.model.bounds.size.y * 0.5, 0)
	camera.global_position = centre + Vector3(1.7, 1.15, -2.3)
	camera.look_at(centre)
	camera.current = true
	game.hud.hide()
	await frames(3)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("C:/Users/Qi/AppData/Local/Temp/opencode/facility-presentation-" + tag + ".png")
	game.hud.show()
	camera.queue_free()
	game.player.camera.current = true

func capture_gallery(game: Node3D, keys: Dictionary, supplies: bool) -> void:
	if not capture_enabled: return
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 800)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.own_world_3d = true
	viewport.msaa_3d = Viewport.MSAA_4X
	game.add_child(viewport)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("24464e")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color("d8e5df")
	environment.environment.ambient_light_energy = 0.8
	viewport.add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40, -30, 0)
	sun.light_energy = 1.0
	viewport.add_child(sun)
	var gallery := Node3D.new()
	viewport.add_child(gallery)
	var ids: Array = Items.SUPPLIES if supplies else range(501, 510)
	var columns := 5 if supplies else 3
	for index in ids.size():
		var id: int = ids[index]
		var model: Node3D
		if supplies:
			model = Visual.new()
			gallery.add_child(model)
			model.build(id, {}, true)
			model.scale = Vector3.ONE * 2.7
		else:
			model = preload("res://scripts/world/FacilityObject.gd").new()
			model.record = game.world.life.records[keys[id]].duplicate(true)
			if id == 507: model.record.growth_stage = 3
			if id == 505: model.record.lit = true
			model.service = game.world.life
			model.preview = true
			gallery.add_child(model)
		model.position = Vector3(((columns - 1) * 0.5 - index % columns) * 2.0, 0, (index / columns) * 2.5)
		var label := Label3D.new()
		label.text = Items.NAMES[id]
		label.font_size = 40
		label.pixel_size = 0.006
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.no_depth_test = true
		label.modulate = Color("f0e6cb")
		label.outline_modulate = Color("233d42")
		gallery.add_child(label)
		label.position = model.position + Vector3(0, -0.35, -0.3)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 7.0 if supplies else 6.5
	gallery.add_child(camera)
	var centre := gallery.global_position + Vector3(0, 0.25, 1.4 if supplies else 2.4)
	camera.global_position = centre + Vector3(0.8, 6, -8)
	camera.look_at(centre)
	camera.current = true
	await frames(4)
	await RenderingServer.frame_post_draw
	viewport.get_texture().get_image().save_png("C:/Users/Qi/AppData/Local/Temp/opencode/facility-presentation-" + ("supplies" if supplies else "facilities") + ".png")
	viewport.queue_free()

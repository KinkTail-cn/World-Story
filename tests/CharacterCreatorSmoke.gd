extends SceneTree

const Definition = preload("res://scripts/character/CharacterDefinition.gd")
const Saves = preload("res://scripts/system/SaveSystem.gd")
const Settings = preload("res://scripts/system/SettingsSystem.gd")
const Sets = preload("res://scripts/content/EquipmentSets.gd")
const Geometry = preload("res://scripts/blueprint/BlueprintGeometry.gd")
const BlueprintDataScript = preload("res://scripts/blueprint/BlueprintData.gd")
var checks: int = 0
var failures: int = 0
var started_msec: int = 0

func _initialize() -> void:
	create_timer(35.0).timeout.connect(func(): push_error("CHARACTER_CREATOR_TIMEOUT"); quit(1))
	_run.call_deferred()

func check(condition: bool, text: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(text)

func frames(count: int = 4) -> void:
	for i in count:
		await process_frame

func _run() -> void:
	started_msec = Time.get_ticks_msec()
	var saves = Saves.new("user://character_creator_world.json")
	var settings = Settings.new("user://character_creator_settings.json")
	var game = preload("res://scenes/Main.tscn").instantiate()
	game.setup_lifecycle(saves,settings,{})
	root.add_child(game)
	current_scene = game
	while game.is_loading:
		await process_frame
	game.player.set_physics_process(false)
	key(KEY_K)
	await frames()
	var editor = game.hud.character_creator
	check(paused and editor.visible and game.hud.any_modal_visible(), "K opens the actual paused character creator")
	check(Definition.validation_error(editor.edit_session.model).is_empty(), "Creator begins with a complete editable body")
	check(editor.preview_character.rig_nodes.size() == 17, "Preview uses the configurable character rig")
	trace("opened")
	await capture("default")
	editor.parameter_inputs.height.spin.value = 2.4
	await create_timer(0.3).timeout
	await frames()
	check(is_equal_approx(float(editor.edit_session.model.parameters.height),2.4), "Actual height control updates the draft")
	check(editor.preview_character.body_metrics.height > 2.35, "Height control updates the displayed body")
	editor.name_edit.text = "高个方块人物"
	editor.name_edit.text_submitted.emit(editor.name_edit.text)
	editor.tool = 4
	editor.tool_box.select(4)
	var arm: Vector3 = Definition.rest_origins(editor.edit_session.model).right_arm
	var arm_screen: Vector2 = editor.camera.unproject_position(editor.preview_character.global_transform * arm) * editor.preview.size / Vector2(editor.viewport.size)
	var undo_count: int = editor.edit_session.undo_stack.size()
	drag(editor.preview.get_global_transform() * arm_screen,editor.preview.get_global_transform() * (arm_screen + Vector2(22,0)))
	await frames()
	check(not editor.edit_session.model.joints.is_empty() and editor.edit_session.undo_stack.size() == undo_count + 1, "Actual skeleton drag records one complete joint-and-body transaction")
	var moved_origins := Definition.rest_origins(editor.edit_session.model)
	check(is_equal_approx(Vector3(moved_origins.right_arm).x,-Vector3(moved_origins.left_arm).x), "Skeleton drag preserves the enabled left/right symmetry")
	key(KEY_Z,true)
	await frames()
	check(editor.edit_session.model.joints.is_empty(), "Undo restores the complete pre-drag skeleton")
	trace("height-and-joint")
	editor._choose_bone("head")
	var point: Vector2 = cube_screen_point(editor)
	var old_count: int = editor.edit_session.model.cubes.size()
	editor.tool = 0
	editor.tool_box.select(0)
	click_point(editor.preview.get_global_transform() * point)
	await frames()
	check(editor.edit_session.model.cubes.size() == old_count + 1, "A real preview click attaches a cube to the selected joint")
	var added_id: String = str(editor.edit_session.model.cubes.back().id)
	check(editor.edit_session.model.cubes.back().bone == "head", "Placed cube retains its explicit bone attachment")
	editor.tool = 2
	editor.tool_box.select(2)
	editor.color_picker.color = Color("df5e66")
	click_point(editor.preview.get_global_transform() * point)
	await frames()
	check(editor.edit_session.model.cubes[editor.edit_session.find(added_id)].color == "df5e66", "Actual paint click uses the brush color rather than replacing it with the target's color")
	key(KEY_D,true)
	await frames()
	check(editor.edit_session.model.cubes.size() == old_count + 2, "Ctrl+D duplicates a selected character cube")
	key(KEY_Z,true)
	await frames()
	check(editor.edit_session.model.cubes.size() == old_count + 1 and editor.edit_session.find(added_id) >= 0, "Ctrl+Z restores model geometry and selection")
	click(find_button(editor,"保存"))
	await frames()
	check(editor.library.designs.size() == 1 and not editor.edit_session.dirty(), "Real save button persists the character library")
	click(find_button(editor,"应用人物"))
	await frames()
	check(game.player.character_definition.get("name") == "高个方块人物", "Apply button replaces the actual player model")
	check(game.player.collision.shape.height > 2.35 and game.player.rig.position.y > 2.0, "Player collision and camera follow the new body")
	check(game.hud.inventory_panel.character_definition == game.player.character_definition, "Backpack preview receives the exact same character definition")
	var saved: Dictionary = saves.load_world()
	check(saved.ok and saved.data.player.character.name == "高个方块人物", "Applying a character saves its independent world snapshot")
	trace("saved-and-applied")
	var applied_body: Dictionary = game.player.character_definition.duplicate(true)
	editor.edit_session.add("head",Vector3(0.3,0,0),0.065,Color.WHITE)
	check(game.player.character_definition == applied_body, "Editing a draft after applying never changes the live player implicitly")
	editor.edit_session.undo()
	for cube in editor.edit_session.model.cubes:
		var center := Definition.vector(cube.center)
		if cube.bone == "head" and absf(snappedf(center.y,0.005)-center.y) > 0.000001:
			editor.edit_session.select([cube.id])
			var exact_edge: float = cube.edge
			editor.cube_xyz[0].value += 0.005
			editor._apply_cube_properties()
			var edited_cube: Dictionary = editor.edit_session.model.cubes[editor.edit_session.find(str(cube.id))]
			check(is_equal_approx(Definition.vector(edited_cube.center).y,center.y) and is_equal_approx(Definition.vector(edited_cube.center).z,center.z) and is_equal_approx(float(edited_cube.edge),exact_edge), "Editing one coordinate preserves untouched precision and cube size")
			editor.edit_session.undo()
			break
	for pose in range(1,7):
		editor.set_pose(pose)
		await frames()
		var before: int = editor.edit_session.model.cubes.size()
		click_point(editor.preview.get_global_transform() * point)
		check(editor.edit_session.model.cubes.size() == before and editor.edit_session.read_only, "Animation preview freezes cube modeling")
	editor.set_pose(0)
	editor.tool = 1
	editor.tool_box.select(1)
	await capture("tall")
	check(editor.edit_session.set_parameters({"height":1.65,"body_width":1.6,"body_depth":1.5,"leg_width":1.2}), "Live body reshaping supports a short broad build without stretching individual cubes")
	editor.set_pose(2)
	await frames(8)
	await capture("broad-running")
	editor.set_pose(0)
	check(editor.edit_session.undo() and editor.edit_session.model == applied_body, "Undo restores the saved tall character after broad-body preview")
	trace("body-reshape-and-preview")
	var content := root.content_scale_size
	root.content_scale_size = Vector2i.ZERO
	for dimensions in [Vector2i(800,500),Vector2i(960,600),Vector2i(1920,1080),Vector2i(2560,1080)]:
		root.size = dimensions
		await frames()
		check(root.get_visible_rect().grow(-2.0).encloses(editor.card.get_global_rect()), "Creator fits the current window " + str(dimensions))
		check(root.get_visible_rect().encloses(find_button(editor,"应用人物").get_global_rect()), "Apply action remains reachable")
		if dimensions.x == 800:
			await capture("small")
	root.content_scale_size = content
	root.size = Vector2i(1280,800)
	key(KEY_F11)
	await frames(6)
	check(bool(settings.get_value("fullscreen")) and editor.visible and paused, "F11 works inside the creator without losing its modal state")
	key(KEY_F11)
	await frames(6)
	check(not bool(settings.get_value("fullscreen")) and editor.visible and paused, "Creator survives returning from fullscreen")
	key(KEY_ESCAPE)
	await frames()
	check(not paused and not editor.visible, "Escape closes a saved character and restores gameplay")
	trace("layout-and-fullscreen")
	game.inventory.equip_creative_set(Sets.ids("knight"))
	await frames()
	check(game.player.visual.equipment_visuals.equipped_ids[0] == 411, "Existing equipment still equips on a custom body")
	check(game.hud.inventory_panel.preview_character.character_definition == game.player.character_definition, "Backpack equipment preview retains the custom body")
	check(game.save_progress(), "Equipped custom character can save")
	var data: Dictionary = saves.load_world().data
	game.queue_free()
	await frames()
	game = preload("res://scenes/Main.tscn").instantiate()
	game.setup_lifecycle(saves,settings,data)
	root.add_child(game)
	current_scene = game
	while game.is_loading:
		await process_frame
	game.player.set_physics_process(false)
	check(game.player.character_definition.name == "高个方块人物" and game.player.collision.shape.height > 2.35, "Reload restores the body and its playable dimensions")
	check(game.inventory.equipment[0] == 411 and game.player.visual.equipment_visuals.equipped_ids[0] == 411, "Reload restores equipment on the same body")
	trace("reloaded")
	game.player.set_first_person(false)
	await capture("equipped-game")
	game._input(action("blueprint"))
	await frames()
	check(game.hud.blueprint_workshop.visible, "Existing blueprint workshop still opens after character replacement")
	var workshop = game.hud.blueprint_workshop
	check(workshop.real_character.character_definition == game.player.character_definition, "Blueprint workshop displays the actual custom character")
	workshop._open_official(401)
	await frames()
	var reference: Dictionary = Definition.rig_reference(game.player.character_definition)
	check(workshop.blueprint.rig_reference == reference, "Equipment editing uses the current body's reference rig")
	var pick: Node3D = workshop.template_root.find_child("Pick_head",true,false)
	var shape: BoxShape3D = pick.get_child(0).shape
	var hit := {"position": pick.global_position + Vector3.UP * shape.size.y * 0.5, "normal": Vector3.UP, "collider": pick}
	var part: Dictionary = workshop._placement_from_hit(hit)
	var point_on_character: Vector3 = Geometry.character_transform(part,"头部装备",reference).origin
	check(point_on_character.y > game.player.visual.rest_origin("head").y, "Placement on a tall head uses actual body coordinates")
	check(not workshop.edit_session.add(part).is_empty(), "A new equipment cube can be added on the current body")
	check(BlueprintDataScript.validation_error(workshop._design_snapshot()).is_empty(), "Body-aware equipment remains a valid upright-cube blueprint")
	check(workshop._save_pressed(), "Body-aware blueprint can save")
	var item: Dictionary = game.inventory.craft_blueprint(workshop._design_snapshot())
	check(item.ok and item.item.blueprint.rig_reference == reference, "Crafting preserves the design's reference body")
	check(game.inventory.equip_from_bag(int(item.index)), "Body-aware equipment can be worn by the real player")
	var custom_before: Dictionary = game.inventory.get_slot("equipment",0).duplicate(true)
	check(game.player.apply_character({},false).ok, "A fitted item can also be worn by the default body")
	check(game.inventory.get_slot("equipment",0) == custom_before, "Switching bodies never rewrites a crafted item's design")
	trace("body-aware-blueprints")
	workshop._finish_close()
	game._open_character_creator()
	await frames()
	editor = game.hud.character_creator
	check(editor.edit_session.add("head",Vector3(0.3,0,0),0.065,Color.WHITE), "Create an unsaved character edit for lifecycle protection")
	editor.request_close()
	check(editor.unsaved_dialog.visible and editor.visible and paused, "Unsaved character blocks accidental close")
	check(editor.cancel_edit() and editor.visible and not editor.unsaved_dialog.visible, "Cancel keeps the character draft open")
	var library_path: String = editor.library.storage.save_path
	editor.library.storage.save_path = "user://missing_creator_folder/characters.json"
	editor.request_close()
	editor.unsaved_dialog.confirmed.emit()
	check(editor.visible and editor.edit_session.dirty() and editor.status_label.text.contains("失败"), "Character save failure preserves both the editor and draft")
	editor.cancel_edit()
	editor.library.storage.save_path = library_path
	check(editor.save_model(), "A failed character save can be retried successfully")
	editor.request_close()
	await frames()
	check(not editor.visible and not paused, "Saved character closes normally after recovery")
	game.queue_free()
	await frames()
	paused = false
	check(saves.delete_save(), "Isolated world is cleaned up")
	trace("finished")
	print("CHARACTER_CREATOR_SMOKE_PASS: %d checks, %d failures" % [checks,failures])
	quit(0 if failures == 0 else 1)

func cube_screen_point(editor) -> Vector2:
	var origins := Definition.rest_origins(editor.edit_session.model)
	var world: Vector3 = editor.preview_character.global_transform * (Vector3(origins.head) + Vector3(0,0,-0.225) * Definition.unit(editor.edit_session.model))
	return editor.camera.unproject_position(world) * editor.preview.size / Vector2(editor.viewport.size)

func find_button(parent: Node, text: String) -> Button:
	for button in parent.find_children("*","Button",true,false):
		if button.text == text:
			return button
	return null

func click(button: Control) -> void:
	check(button != null, "Requested creator action exists")
	if button != null:
		click_point(button.get_global_rect().get_center())

func click_point(point: Vector2) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = point
	event.pressed = true
	root.push_input(event,true)
	event = event.duplicate()
	event.pressed = false
	root.push_input(event,true)

func drag(start: Vector2, finish: Vector2) -> void:
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.position = start
	press.pressed = true
	root.push_input(press,true)
	var motion := InputEventMouseMotion.new()
	motion.position = finish
	motion.relative = finish - start
	motion.button_mask = MOUSE_BUTTON_MASK_LEFT
	root.push_input(motion,true)
	press = press.duplicate()
	press.position = finish
	press.pressed = false
	root.push_input(press,true)

func key(code: int, ctrl: bool = false) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.ctrl_pressed = ctrl
	event.pressed = true
	root.push_input(event,true)
	event = event.duplicate()
	event.pressed = false
	root.push_input(event,true)

func action(name: String) -> InputEventAction:
	var event := InputEventAction.new()
	event.action = name
	event.pressed = true
	return event

func capture(tag: String) -> void:
	if "--capture" in OS.get_cmdline_user_args() and DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("C:/Users/Qi/AppData/Local/Temp/opencode/world-story-character-" + tag + ".png")

func trace(tag: String) -> void:
	if "--profile" in OS.get_cmdline_user_args():
		print("CHARACTER_PROFILE_MS: %s %d" % [tag,Time.get_ticks_msec()-started_msec])

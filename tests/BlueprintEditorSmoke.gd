extends SceneTree

const Manager = preload("res://scripts/blueprint/BlueprintManager.gd")
const Geometry = preload("res://scripts/blueprint/BlueprintGeometry.gd")
var checks: int = 0
var failures: int = 0
var scene

func _initialize() -> void:
	create_timer(35.0).timeout.connect(func(): push_error("BLUEPRINT_EDITOR_TIMEOUT"); quit(1))
	_run.call_deferred()

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(label)

func _run() -> void:
	scene = preload("res://scenes/BlueprintWorkshop.tscn").instantiate()
	root.add_child(scene)
	var manager = Manager.new()
	scene.open(manager)
	await frames()
	check(scene.get_node("%OfficialDesigns").item_count == 22, "All 21 official designs are accessible from the editor")
	scene._open_official(412)
	scene._set_editor_mode("select")
	var first: Dictionary = scene.blueprint.voxels[0]
	var uid: String = first.uid
	scene.edit_session.select([uid])
	var original_dimensions: Array = first.dimensions.duplicate()
	scene.inspector.get_node("%Edge").value = 0.065
	scene.inspector.get_node("%Apply").pressed.emit()
	check(Geometry.dimensions(scene.blueprint.voxels[0]).is_equal_approx(Vector3.ONE * 0.065), "One edge input changes all three dimensions together")
	check(scene.inspector.get_node_or_null("%Rotation") == null and scene.inspector.get_node_or_null("%Dimensions") == null and scene.inspector.get_node_or_null("%Wind") == null, "Inspector exposes no rotation, axis stretching or cloth deformation controls")
	var key := InputEventKey.new()
	key.pressed = true
	key.ctrl_pressed = true
	key.keycode = KEY_Z
	scene._unhandled_input(key)
	check(scene.blueprint.voxels[0].dimensions == original_dimensions, "Ctrl+Z undoes the edge transaction")
	key.keycode = KEY_Y
	scene._unhandled_input(key)
	check(Geometry.dimensions(scene.blueprint.voxels[0]).is_equal_approx(Vector3.ONE * 0.065), "Ctrl+Y restores all equal edges")
	check(scene.get_node("%PartList").item_count == scene.blueprint.voxels.size(), "Every official geometry piece appears in the parts list")
	await capture("official")
	var original_size := root.size
	var original_scale := root.content_scale_size
	root.content_scale_size = Vector2i.ZERO
	root.size = Vector2i(960, 600)
	await frames()
	check(root.get_visible_rect().encloses(scene.get_node("LeftDrawer/Panel").get_global_rect()), "Design sources and part list fit the small window")
	check(root.get_visible_rect().encloses(scene.get_node("RightDrawer/Panel/Margin/Stack/Actions").get_global_rect()), "Save and craft actions remain visible without scrolling")
	check(not scene.get_node("%EditorToolbar").get_global_rect().intersects(scene.rotate_gizmo.get_global_rect()), "Small-window tools never overlap the orbit controls")
	await capture("small")
	root.size = original_size
	root.content_scale_size = original_scale
	await frames()
	scene._select_category("头部装备", true)
	scene._create_new_design()
	var cube := Geometry.primitive("头部装备", Vector3(0, 1.8, 1.0), Vector3.ONE * 0.26, "head")
	var cube_uid: String = scene.edit_session.add(cube)
	var box := Geometry.primitive("头部装备", Vector3(0.70, 1.8, 1.0), Vector3.ONE * 0.13, "head")
	var box_uid: String = scene.edit_session.add(box)
	scene._set_editor_mode("add")
	scene.brush = {"shape": "box", "dimensions": [0.065, 0.065, 0.065], "mat": 1, "size": 1}
	scene.inspector.set_values(scene.brush)
	var surface := Vector3(0, 1.8, 1.13)
	var normal := Vector3.BACK
	scene.preview_camera.position = surface + normal * 2.0
	scene.preview_camera.look_at(surface)
	await frames()
	var point := project(surface)
	var hit: Dictionary = scene._ray_hit(point)
	check(not hit.is_empty() and hit.collider.get_meta("uid", "") == cube_uid, "Real viewport ray picks an editable cube face")
	scene._update_hover_preview(point)
	var preview: Transform3D = scene.hover_indicator.transform
	var history_size: int = scene.edit_session.undo_stack.size()
	click(point)
	await frames()
	var added: Dictionary = scene.blueprint.voxels.back()
	check(scene.blueprint.voxels.size() == 3 and Geometry.preview_transform(added, "头部装备").is_equal_approx(preview) and Geometry.is_cube(added), "Cube click exactly matches the placement preview")
	check(is_equal_approx(Geometry.preview_transform(added, "头部装备").origin.z - 0.0325, surface.z), "A custom-edge cube sits flush on the target face")
	check(scene.edit_session.undo_stack.size() == history_size + 1, "Placement is one undo transaction")
	await capture("cubes")
	scene._set_editor_mode("select")
	scene.preview_camera.position = Vector3(0.4, 2.3, 4.2)
	scene.preview_camera.look_at(Vector3(0.35, 1.8, 1.0))
	await frames()
	click(project(Vector3(0.70, 1.8, 1.0)))
	check(scene.edit_session.selection.has(box_uid), "Selection tool picks a component in the canvas")
	scene._handle_click(Vector2(-10000, -10000), false)
	check(scene.edit_session.selection.is_empty(), "Clicking empty canvas clears the current selection")
	scene.edit_session.select([box_uid])
	scene.edit_session.set_properties({"locked": true})
	scene.preview_press_position = Vector2.ONE
	scene._box_select(scene.preview_container.size - Vector2.ONE, false)
	check(not scene.edit_session.selection.has(box_uid) and scene.edit_session.selection.has(cube_uid), "Box selection excludes locked parts")
	scene.edit_session.select([box_uid])
	scene.inspector.get_node("%Locked").set_pressed_no_signal(false)
	scene.inspector.flags_changed.emit("locked", false)
	await frames()
	var before_drag: Dictionary = scene.blueprint.to_dictionary()
	var start := project(Vector3(0.70, 1.8, 1.0))
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = start
	scene._preview_input(press)
	var motion := InputEventMouseMotion.new()
	motion.position = start + Vector2(35, 0)
	motion.relative = Vector2(35, 0)
	motion.button_mask = MOUSE_BUTTON_MASK_LEFT
	scene._preview_input(motion)
	var release := press.duplicate()
	release.pressed = false
	release.position = motion.position
	scene._preview_input(release)
	check(scene.blueprint.to_dictionary() != before_drag and scene.edit_session.undo(), "Dragging a selected component commits one reversible move")
	check(scene.blueprint.to_dictionary() == before_drag, "Drag undo restores geometry and all metadata")
	await frames()
	scene._preview_input(press)
	scene._preview_input(motion)
	check(scene.cancel_edit() and scene.blueprint.to_dictionary() == before_drag, "Escape cancels an in-progress drag without recording it")
	var yaw: float = scene.orbit_yaw
	press.button_index = MOUSE_BUTTON_MIDDLE
	scene._preview_input(press)
	scene._preview_input(motion)
	release.button_index = MOUSE_BUTTON_MIDDLE
	scene._preview_input(release)
	check(scene.orbit_yaw != yaw, "Middle drag rotates the observation camera")
	var center: Vector3 = scene.current_look_center
	press.shift_pressed = true
	scene._preview_input(press)
	scene._preview_input(motion)
	scene._preview_input(release)
	check(not scene.current_look_center.is_equal_approx(center), "Shift-middle drag pans the observation center")
	press.button_index = MOUSE_BUTTON_LEFT
	press.shift_pressed = false
	press.alt_pressed = true
	scene._preview_input(press)
	scene._preview_input(motion)
	release.button_index = MOUSE_BUTTON_LEFT
	release.alt_pressed = true
	scene._preview_input(release)
	check(not scene.camera_dragging, "Alt-left orbit ends cleanly on release")
	scene.name_edit.grab_focus()
	key.ctrl_pressed = false
	key.keycode = KEY_B
	scene._unhandled_input(key)
	check(scene.editor_mode == "select", "Typing in the name field does not switch tools")
	scene.name_edit.text = "立方体测试"
	scene.name_edit.text_changed.emit("立方体测试")
	key.ctrl_pressed = true
	key.keycode = KEY_S
	scene._unhandled_input(key)
	check(manager.blueprints.size() == 1 and not scene.edit_session.dirty(), "Ctrl+S saves while the name field is focused")
	scene.name_edit.release_focus()
	scene._open_official(426)
	scene.edit_session.select([scene.blueprint.voxels[0].uid])
	scene.inspector.get_node("%Edge").value = 0.0325
	scene._editor_action("apply")
	check(Geometry.dimensions(scene.blueprint.voxels[0]).is_equal_approx(Vector3.ONE * 0.0325), "Cloak decoration edits use the same cube edge control")
	scene._set_preview_pose(1)
	var preview_data: Dictionary = scene.blueprint.to_dictionary()
	scene._handle_click(Vector2(200, 200), true)
	scene._editor_action("delete")
	scene._clear_all()
	scene._mirror_x()
	check(scene.blueprint.to_dictionary() == preview_data, "Action preview blocks geometry edits")
	for frame in range(20):
		await process_frame
	check(scene.pose_renderer.source_part_count == scene.blueprint.voxels.size() and scene.pose_renderer.pieces.all(func(p): return p.basis.is_equal_approx(Basis.IDENTITY) and p.material_override is StandardMaterial3D), "Running preview keeps cloak cubes rigid and axis aligned to their anchor")
	await capture("cloak")
	scene._set_preview_pose(0)
	check(scene.voxel_container.visible and scene.pose_renderer == null, "Stopping preview restores static editable geometry")
	scene._open_official(412)
	await frames()
	var body_count: int = scene.preview_root.find_children("*", "StaticBody3D", true, false).size()
	for iteration in range(4):
		scene._open_official(426)
		scene._set_preview_pose(1)
		await frames()
		scene._set_preview_pose(0)
		scene._open_official(412)
		await frames()
	check(scene.preview_root.find_children("*", "StaticBody3D", true, false).size() == body_count, "Repeated design/animation changes do not accumulate picking bodies")
	scene.edit_session.select([scene.blueprint.voxels[0].uid])
	scene.edit_session.translate_selected(Vector3(0, 0.0325, 0))
	var fail_save := func(_design: Dictionary): scene.set_save_result(false)
	var saved_library: Array = manager.blueprints.duplicate(true)
	scene.blueprint_saved.connect(fail_save)
	scene.request_close()
	check(scene.get_node("%UnsavedDialog").visible and scene.visible, "Leaving a modified design asks about unsaved work")
	scene.get_node("%UnsavedDialog").confirmed.emit()
	check(scene.visible and scene.get_node("%UnsavedDialog").visible and scene.edit_session.dirty(), "Failed save keeps the design and editor open")
	check(manager.blueprints == saved_library, "A failed save rolls back the saved-library entries")
	scene.blueprint_saved.disconnect(fail_save)
	scene.get_node("%UnsavedDialog").custom_action.emit("discard")
	check(not scene.visible, "Explicit discard completes the pending close")
	check(scene.blueprint.to_dictionary() == scene.edit_session.saved_state, "Discard restores the last saved or initially loaded design")
	scene.queue_free()
	await process_frame
	print("BLUEPRINT_EDITOR_SMOKE_PASS: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

func frames() -> void:
	await physics_frame
	await physics_frame
	await process_frame
	await process_frame

func project(point: Vector3) -> Vector2:
	return scene.preview_camera.unproject_position(point) * scene.preview_container.size / Vector2(scene.preview_viewport.size)

func click(point: Vector2) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	event.position = point
	scene._preview_input(event)
	event.pressed = false
	scene._preview_input(event)

func capture(tag: String) -> void:
	if "--capture" in OS.get_cmdline_user_args():
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("C:/Users/Qi/AppData/Local/Temp/opencode/world-story-blueprint-editor-" + tag + ".png")

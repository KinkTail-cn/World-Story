extends SceneTree

const Settings = preload("res://scripts/system/SettingsSystem.gd")
var checks: int = 0
var failures: int = 0

func _initialize() -> void:
	create_timer(35.0).timeout.connect(func(): push_error("INTERFACE_LAYOUT_TIMEOUT"); quit(1))
	_run.call_deferred()

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)

func fits(control: Control, message: String) -> void:
	check(root.get_visible_rect().grow(-3.0).encloses(control.get_global_rect()), message + " " + str(root.size))

func frames(count: int = 4) -> void:
	for frame in range(count):
		await process_frame

func _run() -> void:
	var original_size := root.size
	var original_content := root.content_scale_size
	root.content_scale_size = Vector2i.ZERO
	var menu = preload("res://scenes/MainMenu.tscn").instantiate()
	root.add_child(menu)
	var settings = preload("res://scenes/SettingsPanel.tscn").instantiate()
	root.add_child(settings)
	var preferences = Settings.new("user://interface_layout_settings.json")
	var loading = preload("res://scenes/LoadingScreen.tscn").instantiate()
	root.add_child(loading)
	var game = preload("res://scenes/Main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	while game.is_loading:
		await process_frame
	game.player.set_physics_process(false)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var hud = game.hud
	for dimensions in [Vector2i(800, 500), Vector2i(800, 600), Vector2i(960, 540), Vector2i(960, 600), Vector2i(1280, 800), Vector2i(1920, 1080), Vector2i(2560, 1080), Vector2i(800, 500)]:
		root.size = dimensions
		hud.visible = false
		menu.visible = true
		loading.visible = false
		settings.visible = false
		await frames()
		fits(menu.get_node("Center/Card"), "Main menu fits")
		if dimensions == Vector2i(1280, 800):
			await capture("title")
		menu._open_mode_popup()
		await frames()
		fits(menu.get_node("ModePopup/Card"), "World creation choices fit")
		if dimensions == Vector2i(1280, 800):
			await capture("world-creation")
		menu.world_type_box.select(2)
		menu._describe_choices()
		await frames()
		fits(menu.get_node("ModePopup/Card"), "Village creation fits with the seed field")
		fits(menu.get_node("ModePopup/Card/Body/Seed"), "Village seed input remains reachable")
		if dimensions == Vector2i(800, 500):
			await capture("village-creation-small")
		menu.world_type_box.select(0)
		menu._describe_choices()
		menu._close_mode_popup()
		menu.show_error("无法读取存档，请检查存档备份。".repeat(5))
		await frames()
		fits(menu.get_node("Center/Card"), "Menu errors remain on screen")
		menu.refresh()
		menu.visible = false
		settings.open(preferences)
		await frames()
		fits(settings.get_node("Center/Card"), "Settings fit")
		fits(settings.get_node("Center/Card/Body/Buttons/Apply"), "Settings save button is reachable")
		if dimensions == Vector2i(1280, 800):
			await capture("settings")
		settings.close()
		loading.visible = true
		loading.update_progress(0.64, "准备海岸与树林…")
		await frames()
		fits(loading.get_node("Center/Card"), "Loading progress and tips fit")
		if dimensions == Vector2i(1280, 800):
			await capture("loading")
		loading.visible = false
		hud.visible = true
		await frames()
		fits(hud.get_node("Root/Bottom"), "All eight hotbar slots and help fit")
		check(not hud.get_node("Root/TopLeftPanel").is_visible_in_tree(), "Left corner information remains removed")
		check(not hud.get_node("Root/TopRightPanel").is_visible_in_tree(), "Right corner instructions remain removed")
		check(not hud.target.is_visible_in_tree() and not hud.get_node("Root/Bottom/Help").is_visible_in_tree() and not hud.get_node("Root/Bottom/Selected").is_visible_in_tree(), "Resizing does not restore gameplay text hints")
		if dimensions == Vector2i(1280, 800):
			await capture("hud")
		hud.set_paused(true)
		await frames()
		fits(hud.get_node("Root/Pause/Panel"), "Pause actions fit")
		if dimensions in [Vector2i(800, 500), Vector2i(1280, 800)]:
			await capture("pause-" + str(dimensions.x))
		hud.set_paused(false)
		hud.function_wheel.open(0, false)
		await frames()
		var wheel = hud.function_wheel
		check(wheel.center.y + wheel.radius + 84.0 <= wheel.size.y, "Function wheel and confirmation hint fit")
		if dimensions == Vector2i(1280, 800):
			await capture("actions")
		wheel.close()
		hud.inventory_panel.open()
		await frames()
		fits(hud.inventory_panel.card, "Backpack fits")
		fits(hud.inventory_panel.close_button, "Backpack close button fits")
		check(hud.inventory_panel.get_bag_slot(0).get_global_rect().size.x >= 32.0, "Scaled item slots retain a usable mouse target")
		for creative in [true, false]:
			hud.inventory_panel._set_creative_view(creative)
			await frames()
			fits(hud.inventory_panel.hotbar_grid, "Pinned bag hotbar fits")
			fits(hud.inventory_panel.creative_section if creative else hud.inventory_panel.craft_section, "Library or crafting controls fit")
			if dimensions == Vector2i(1280, 800):
				await capture("inventory" if creative else "crafting")
		hud.inventory_panel.close()
		hud.notebook_panel.open(game.blueprint_manager)
		await frames()
		fits(hud.notebook_panel.get_node("Card"), "Notebook fits")
		fits(hud.notebook_panel.get_node("Card/Body/Actions/Save"), "Notebook save action fits")
		if dimensions == Vector2i(800, 500):
			await capture("notebook-small")
		if dimensions == Vector2i(1280, 800):
			await capture("notebook")
		hud.notebook_panel.close()
		var editor = hud.blueprint_workshop
		editor.open(game.blueprint_manager)
		await frames()
		fits(editor.get_node("LeftDrawer/Panel"), "Blueprint sources and part list fit")
		fits(editor.get_node("RightDrawer/Panel"), "Blueprint inspector fits")
		fits(editor.get_node("RightDrawer/Panel/Margin/Stack/Actions"), "Blueprint save/craft stay visible")
		fits(editor.get_node("%EditorToolbar"), "Blueprint toolbar fits")
		check(not editor.get_node("%EditorToolbar").get_global_rect().intersects(editor.rotate_gizmo.get_global_rect()), "Canvas tools and orbit controls do not overlap")
		if dimensions in [Vector2i(800, 500), Vector2i(1920, 1080)]:
			await capture("blueprint-" + str(dimensions.x))
		editor._finish_close()
		hud.item_tooltip.follow_mouse = false
		hud.item_tooltip.display_item(108, Vector2(dimensions) - Vector2(8, 8), {"custom_name": "很长的自定义笔记本名称".repeat(8)})
		await frames()
		fits(hud.item_tooltip.get_node("TooltipCard"), "Long item names and edge tooltips fit")
		if dimensions == Vector2i(1280, 800):
			await capture("tooltip")
		hud.item_tooltip.dismiss()
	var editor = hud.blueprint_workshop
	editor.open(game.blueprint_manager)
	editor._toggle_left_drawer()
	editor._toggle_right_drawer()
	await create_timer(0.32).timeout
	fits(editor.left_toggle_btn, "Collapsed left drawer can be reopened in a small window")
	fits(editor.right_toggle_btn, "Collapsed right drawer can be reopened in a small window")
	root.size = Vector2i(960, 600)
	await frames()
	editor._toggle_left_drawer()
	editor._toggle_right_drawer()
	await create_timer(0.32).timeout
	fits(editor.get_node("LeftDrawer/Panel"), "Left drawer reopens after a resize")
	fits(editor.get_node("RightDrawer/Panel"), "Right drawer reopens after a resize")
	editor._finish_close()
	# Exercise an actual mouse click after the card has been scaled.
	root.size = Vector2i(800, 500)
	hud.notebook_panel.open(game.blueprint_manager)
	hud.notebook_panel.editor.text = "小窗输入和保存"
	await frames()
	click(hud.notebook_panel.get_node("Card/Body/Actions/Save"))
	check(game.blueprint_manager.notes.has("小窗输入和保存"), "Mouse hit coordinates still work on a scaled notebook")
	hud.notebook_panel.close()
	if DisplayServer.get_name() != "headless":
		hud.visible = false
		settings.open(preferences)
		root.size = Vector2i(960, 600)
		await frames()
		preferences.changed.connect(func(): preferences.apply(root))
		var windowed_size := DisplayServer.window_get_size()
		settings.fullscreen.button_pressed = true
		await frames(8)
		check(DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN, "Fullscreen checkbox actually enters fullscreen")
		fits(settings.get_node("Center/Card"), "Settings fit the native fullscreen resolution")
		settings.fullscreen.button_pressed = false
		await frames(8)
		check(DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_WINDOWED and DisplayServer.window_get_size() == windowed_size, "Exiting fullscreen restores the previous small window size")
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MAXIMIZED)
		await frames(4)
		preferences.set_value("master_volume", 0.8)
		await frames()
		check(DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_MAXIMIZED, "Changing settings preserves a maximized window")
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		await frames()
	settings.queue_free()
	menu.queue_free()
	loading.queue_free()
	game.queue_free()
	await frames()
	root.size = original_size
	root.content_scale_size = original_content
	print("INTERFACE_LAYOUT_SMOKE_PASS: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

func click(control: Control) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = control.get_global_rect().get_center()
	event.pressed = true
	root.push_input(event, true)
	event = event.duplicate()
	event.pressed = false
	root.push_input(event, true)

func capture(tag: String) -> void:
	if "--capture" in OS.get_cmdline_user_args():
		await create_timer(0.22).timeout
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("C:/Users/Qi/AppData/Local/Temp/opencode/world-story-interface-" + tag + ".png")

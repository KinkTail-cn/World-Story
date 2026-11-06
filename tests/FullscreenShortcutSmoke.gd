extends SceneTree

const Settings = preload("res://scripts/system/SettingsSystem.gd")
const Saves = preload("res://scripts/system/SaveSystem.gd")
var checks: int = 0
var failures: int = 0
var changes: int = 0

func _initialize() -> void:
	create_timer(35.0).timeout.connect(func(): push_error("FULLSCREEN_SHORTCUT_TIMEOUT"); quit(1))
	_run.call_deferred()

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)

func frames(count: int = 4) -> void:
	for frame in count:
		await process_frame

func key(pressed: bool = true, echo: bool = false, control: bool = false) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = KEY_F11
	event.keycode = KEY_F11
	event.pressed = pressed
	event.echo = echo
	event.ctrl_pressed = control
	root.push_input(event, true)

func toggle(preferences, label: String) -> void:
	var before := bool(preferences.get_value("fullscreen"))
	key()
	key(false)
	await frames(6)
	var enabled := bool(preferences.get_value("fullscreen"))
	check(enabled != before, label + ": F11 toggles once")
	check(Settings.new(preferences.settings_path).get_value("fullscreen") == enabled, label + ": preference is saved")
	if DisplayServer.get_name() != "headless":
		var mode := DisplayServer.window_get_mode()
		check((mode == DisplayServer.WINDOW_MODE_FULLSCREEN) == enabled, label + ": actual window mode matches")

func action(name: String) -> InputEventAction:
	var event := InputEventAction.new()
	event.action = name
	event.pressed = true
	return event

func _run() -> void:
	var original_size := root.size
	root.size = Vector2i(960, 600)
	var boot = preload("res://scenes/Boot.tscn").instantiate()
	boot.settings_system = Settings.new("user://f11_boot_settings.json")
	boot.save_system = Saves.new("user://f11_boot_save.json")
	root.add_child(boot)
	current_scene = boot
	await frames()
	var preferences = boot.settings_system
	preferences.changed.connect(func(): changes += 1)
	var windowed_size := root.size
	await toggle(preferences, "Main menu")
	var before := bool(preferences.get_value("fullscreen"))
	var change_count := changes
	key(true, true)
	key(false)
	key(true, false, true)
	await frames()
	check(preferences.get_value("fullscreen") == before and changes == change_count, "Key repeat, release and Ctrl+F11 do not toggle")
	boot._open_settings()
	await frames()
	check(boot.settings.fullscreen.button_pressed, "Settings initially reflect the shortcut state")
	await toggle(preferences, "Open settings")
	check(not boot.settings.fullscreen.button_pressed and boot.settings.visible, "F11 updates the visible checkbox without closing settings")
	if DisplayServer.get_name() != "headless":
		check(root.size == windowed_size, "F11 restores the prior small window size")
	var handler: Node = root.get_meta("world_story_window_shortcuts")
	for iteration in range(4):
		preferences.apply(root)
	await frames()
	check(root.find_children("WindowShortcuts", "Node", false, false).size() == 1 and root.get_meta("world_story_window_shortcuts") == handler, "Repeated settings applications share one global shortcut handler")
	boot.settings.close_requested.emit()
	boot._start_game({}, "creative", "island")
	check(boot.game.is_loading, "New game starts in loading state")
	await toggle(preferences, "Loading screen")
	while boot.game.is_loading:
		await process_frame
	var game = boot.game
	game.player.set_physics_process(false)
	game._input(action("inventory"))
	game.hud.inventory_panel.search.text = "铁"
	game.hud.inventory_panel.search.grab_focus()
	check(paused and game.hud.inventory_panel.visible, "Backpack pauses the game")
	change_count = changes
	await toggle(preferences, "Paused backpack search")
	check(changes == change_count + 1, "Boot and game sharing settings never double-toggle")
	check(paused and game.hud.inventory_panel.visible and game.hud.inventory_panel.search.text == "铁", "Fullscreen preserves the backpack, pause and search text")
	game._close_inventory()
	game._input(action("notebook"))
	game.hud.notebook_panel.editor.text = "F11 保留正在输入的笔记"
	game.hud.notebook_panel.editor.grab_focus()
	await toggle(preferences, "Notebook input")
	check(paused and game.hud.notebook_panel.editor.text == "F11 保留正在输入的笔记", "Fullscreen preserves notebook text and pause state")
	game.hud.close_design()
	game._input(action("blueprint"))
	var editor = game.hud.blueprint_workshop
	var design: Dictionary = editor.blueprint.to_dictionary()
	await toggle(preferences, "Blueprint editor")
	check(paused and editor.visible and editor.blueprint.to_dictionary() == design, "Fullscreen preserves the current blueprint")
	check(root.get_visible_rect().encloses(editor.get_node("RightDrawer/Panel/Margin/Stack/Actions").get_global_rect()), "Blueprint actions remain visible after F11")
	editor._finish_close()
	game._input(action("pause"))
	await toggle(preferences, "Pause menu")
	check(paused and game.hud.pause_panel.visible, "F11 works while paused and leaves the pause menu open")
	game._input(action("pause"))
	boot._return_to_menu()
	await frames()
	await toggle(preferences, "Return to menu")
	check(boot.menu.visible and not paused, "The shortcut remains valid after the game is freed")
	boot.free()
	var direct = preload("res://scenes/Main.tscn").instantiate()
	var direct_preferences = Settings.new("user://f11_direct_settings.json")
	direct.setup_lifecycle(Saves.new("user://f11_direct_save.json"), direct_preferences, {})
	root.add_child(direct)
	current_scene = direct
	await frames()
	check(root.get_meta("world_story_window_shortcuts") == handler, "Direct Main scene reuses the same handler")
	await toggle(direct_preferences, "Direct Main scene")
	check(handler.settings == direct_preferences, "Shortcut follows the active scene's settings instance")
	if bool(direct_preferences.get_value("fullscreen")):
		direct_preferences.toggle_fullscreen(root)
	await frames()
	direct.queue_free()
	await frames()
	root.size = original_size
	print("FULLSCREEN_SHORTCUT_SMOKE_PASS: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

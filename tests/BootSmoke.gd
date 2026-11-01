extends SceneTree

func _initialize() -> void:
	create_timer(15.0).timeout.connect(func(): push_error("BOOT_SMOKE_TIMEOUT"); quit(1))
	_run.call_deferred()

func _run() -> void:
	var boot = load("res://scenes/Boot.tscn").instantiate()
	root.add_child(boot)
	await process_frame
	assert(boot.menu.visible and not boot.settings.visible, "Boot must open on the main menu")
	boot._open_settings()
	await process_frame
	assert(boot.settings.visible and not boot.menu.visible, "Settings must be modal from the menu")
	boot.settings.close_requested.emit()
	await process_frame
	assert(not boot.settings.visible and boot.menu.visible)
	boot._new_game()
	for frame in range(90):
		await physics_frame
	assert(boot.game != null and boot.game.hud != null and boot.game.hud.blueprint_workshop != null)
	boot.game._input(_action("blueprint"))
	await process_frame
	assert(boot.game.hud.blueprint_workshop.visible and paused, "P must open blueprint workshop")
	boot.game.hud.close_design()
	boot.game._close_design()
	assert(not boot.game.hud.blueprint_workshop.visible and not paused)
	boot.game._input(_action("notebook"))
	await process_frame
	assert(boot.game.hud.notebook_panel.visible and paused, "N must open notebook")
	boot.game.hud.close_design()
	boot.game._close_design()
	boot.game.save_progress()
	assert(FileAccess.file_exists("user://world_story_save.json"), "F5/save API must create a save")
	print("BOOT_SMOKE_PASS: menu, settings, new game, blueprint, notebook, save lifecycle")
	quit(0)

func _action(name: String) -> InputEventAction:
	var event := InputEventAction.new()
	event.action = name
	event.pressed = true
	return event

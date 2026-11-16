extends SceneTree

const Saves = preload("res://scripts/system/SaveSystem.gd")
const Settings = preload("res://scripts/system/SettingsSystem.gd")
var checks: int = 0
var failures: int = 0

func _initialize() -> void:
	create_timer(35.0).timeout.connect(func(): push_error("SANDBOX_EXPERIENCE_TIMEOUT"); quit(1))
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
	var saves = Saves.new("user://sandbox_experience.json")
	var settings = Settings.new("user://sandbox_settings.json")
	var game = preload("res://scenes/Main.tscn").instantiate()
	game.game_mode = "survival"
	game.setup_lifecycle(saves, settings, {})
	root.add_child(game)
	current_scene = game
	while game.is_loading:
		await process_frame
	var player = game.player
	var hud = game.hud
	for i in range(20):
		await physics_frame
	check(not InputMap.has_action("journey") and not game.has_node("JourneyDirector"), "Sandbox starts directly without a task system")
	check(hud.find_children("*Journey*", "", true, false).is_empty(), "HUD has no chapter tracker or story panel")
	check(not InputMap.has_action("character_creator") and hud.find_children("*CharacterCreator*", "", true, false).is_empty(), "The retired character creator has no input action or scene nodes")
	key(KEY_K)
	await frames()
	check(not paused and not hud.any_modal_visible(), "K no longer opens a character editor")
	check(game.inventory.count_item(3) == 0 and game.inventory.bag.size() == 24, "Survival keeps its normal empty bag and resource rules")
	check(not hud.get_node("Root/TopLeftPanel").visible and not hud.get_node("Root/TopRightPanel").visible, "Gameplay omits corner information and shortcut text")
	check(not hud.target.visible and not hud.get_node("Root/Bottom/Help").visible and not hud.get_node("Root/Bottom/Selected").visible, "Gameplay omits aim, held-item and keyboard instructions")
	hud.show_message("世界进度已保存")
	await frames()
	check(not hud.toast.visible and not hud.vitals_label.visible, "Routine save feedback and text status stay off the world view")
	check(hud.slots.is_visible_in_tree() and hud.health_bar.is_visible_in_tree(), "Hotbar and visual survival status remain available")
	await capture("survival")
	var old_content := root.content_scale_size
	root.content_scale_size = Vector2i.ZERO
	for dimensions in [Vector2i(800, 500), Vector2i(960, 540), Vector2i(1280, 800), Vector2i(1920, 1080), Vector2i(2560, 1080)]:
		root.size = dimensions
		key(KEY_ESCAPE)
		await frames()
		check(paused and hud.pause_panel.visible, "Physical Escape pauses the sandbox")
		check(find_button(hud.pause_panel, "人物创造器  K") == null, "Pause menu contains only the current sandbox actions")
		fits(hud.get_node("Root/Pause/Panel"), "All pause actions fit")
		fits(hud.vitals_panel, "Visual vital signs fit")
		if dimensions.x == 800:
			await capture("pause-small")
		click(find_button(hud.pause_panel, "游戏设置"))
		await frames()
		check(game.game_settings.visible and paused, "A real settings button opens in-game settings")
		fits(game.game_settings.get_node("Center/Card"), "In-game settings fit")
		key(KEY_ESCAPE)
		await frames()
		check(hud.pause_panel.visible and not game.game_settings.visible and paused, "Escape from settings returns to pause")
		key(KEY_ESCAPE)
		await frames()
		check(not paused, "Escape resumes gameplay")
	root.content_scale_size = old_content
	root.size = Vector2i(1280, 800)
	player.set_physics_process(false)
	player.global_position = Vector3(38, 0, 38)
	player.air = 0.05
	player.health = 100.0
	player.damage_grace = 0.0
	player._update_vitals(0.1)
	check(player.air == 0.0 and player.health == 91.0, "Survival loses air and then health underwater")
	check(not player.take_damage(20.0), "Damage grace prevents repeated immediate hits")
	player.global_position = game.world.get_spawn_position()
	player._damage_age = 6.0
	player._update_vitals(1.0)
	check(player.air > 0.0 and player.health > 91.0, "Air and health recover near the spawn")
	game.inventory.add_item(3, 3)
	check(game.inventory.prepare_recipe("3") and game.inventory.take_result(), "Actual crafting still works without any goal or unlock")
	check(game.inventory.count_item(7) == 4, "Crafting grants only the normal recipe output")
	check(game.game_audio.sounds.size() == 6 and game.game_audio.voices.size() == 6, "Audio uses a bounded effect and voice pool")
	check(game.game_audio._last.has("craft"), "The successful craft transaction triggers sound")
	for kind in game.game_audio.sounds:
		var sound: AudioStreamWAV = game.game_audio.sounds[kind]
		check(sound.data.size() > 0 and sound.mix_rate == 22050, "Generated sound has playable PCM data: " + kind)
	key(KEY_ESCAPE)
	await frames()
	var frozen_air: float = player.air
	var frozen_health: float = player.health
	await frames(8)
	check(player.air == frozen_air and player.health == frozen_health, "Menus freeze survival simulation")
	click(find_button(hud.pause_panel, "返回出生点"))
	await frames()
	check(not paused and player.global_position.distance_to(game.world.get_spawn_position()) < 3.0, "Return button finds safe ground and resumes play")
	check(game.inventory.count_item(3) == 2 and game.inventory.count_item(7) == 4, "Returning preserves actual collected and crafted items")
	var survival = player.inventory
	var creative = preload("res://scripts/inventory/Inventory.gd").new()
	player.inventory = creative
	player.health = 100.0
	player.damage_grace = 0.0
	check(not player.take_damage(100.0) and player.health == 100.0, "Creative mode is invulnerable")
	player.inventory = survival
	player.damage_grace = 0.0
	player.take_damage(1000.0)
	check(player.health >= 65.0 and game.inventory.count_item(7) == 4, "Exhaustion safely returns the player without losing items")
	player.mined = 12
	player.placed = 8
	check(game.save_progress(), "Sandbox saves without quest state")
	var saved: Dictionary = saves.load_world()
	check(saved.ok and not saved.data.has("journey") and saved.data.player.mined == 12 and saved.data.player.placed == 8, "Save contains persistent statistics and no storyline progress")
	game.queue_free()
	await frames()
	check(saves.delete_save(), "Isolated experience data is cleaned up")
	print("SANDBOX_EXPERIENCE_SMOKE_PASS: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

func fits(control: Control, text: String) -> void:
	check(root.get_visible_rect().grow(-2.0).encloses(control.get_global_rect()), text + " " + str(root.size))

func find_button(parent: Node, text: String) -> Button:
	for button in parent.find_children("*", "Button", true, false):
		if button.text == text:
			return button
	return null

func key(code: int) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = true
	root.push_input(event, true)
	event = event.duplicate()
	event.pressed = false
	root.push_input(event, true)

func click(control: Control) -> void:
	check(control != null, "Requested sandbox action exists")
	if control == null:
		return
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = control.get_global_rect().get_center()
	event.pressed = true
	root.push_input(event, true)
	event = event.duplicate()
	event.pressed = false
	root.push_input(event, true)

func capture(tag: String) -> void:
	if "--capture" in OS.get_cmdline_user_args() and DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("C:/Users/Qi/AppData/Local/Temp/opencode/world-story-sandbox-" + tag + ".png")

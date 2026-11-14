extends SceneTree

const Definition = preload("res://scripts/character/CharacterDefinition.gd")
const Saves = preload("res://scripts/system/SaveSystem.gd")
const Settings = preload("res://scripts/system/SettingsSystem.gd")
var checks: int = 0
var failures: int = 0

func _initialize() -> void:
	create_timer(35.0).timeout.connect(func(): push_error("CHARACTER_GAMEPLAY_TIMEOUT"); quit(1))
	_run.call_deferred()

func check(condition: bool, text: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(text)

func frames(count: int = 4) -> void:
	for i in count:
		await process_frame

func physics(count: int = 4) -> void:
	for i in count:
		await physics_frame

func _run() -> void:
	var saves = Saves.new("user://character_gameplay.json")
	var settings = Settings.new("user://character_gameplay_settings.json")
	var game = preload("res://scenes/Main.tscn").instantiate()
	game.game_mode = "survival"
	game.setup_lifecycle(saves,settings,{})
	root.add_child(game)
	current_scene = game
	while game.is_loading:
		await process_frame
	var player = game.player
	await physics(30)
	check(player.is_on_floor(), "Default player lands before changing body")
	var tall := Definition.new_model("高个测试",{"height":2.6})
	var short_body := Definition.new_model("矮个测试",{"height":1.15})
	short_body.sockets.eyes.offset[0] = 0.025
	short_body.sockets.eyes.offset[2] = -0.025
	var ceiling := Vector3i(16,7,21)
	game.world.set_block(ceiling,5)
	player.set_physics_process(false)
	player.global_position = Vector3(16.5,5.02,21.5)
	var before_position: Vector3 = player.global_position
	var old_shape: float = player.collision.shape.height
	var result: Dictionary = player.apply_character(tall)
	check(not result.ok and player.character_definition.is_empty() and player.collision.shape.height == old_shape, "Insufficient headroom rejects the body atomically")
	check(player.global_position == before_position, "Rejected body does not teleport or displace the player")
	game.world.set_block(ceiling,0)
	check(player.apply_character(tall).ok, "The same body applies in open space")
	check(player.collision.shape.height > 2.55 and player.collision.position.y > 1.25, "Collision size and center match the new height")
	player.target_cell = Vector3i(20,4,21)
	player.target_id = game.world.get_block(player.target_cell)
	check(player._sit_on_target(), "A tall body can sit on a world block")
	check(is_equal_approx(player.visual.position.y,float(player.body_metrics.seat_offset)), "Sitting uses the model's pelvis offset")
	check(player.collision.shape == player.sitting_shape and player.collision.shape.height < float(player.body_metrics.height), "Sitting uses a separate fitted collision shape")
	check(player._stand_up(), "A tall body can stand up in adequate space")
	check(player.visual.position.y == 0.0 and player.collision.shape == player.standing_shape, "Standing restores the actual body collision and visual origin")
	check(player.apply_character(short_body).ok, "Small body applies after standing")
	player.set_first_person(true)
	check(player.rig.position.y < 1.1 and player.rig.position.y > 0.8, "Short body has a genuinely lower first-person eye position")
	check(is_equal_approx(player.rig.position.x,0.025) and is_equal_approx(player.rig.position.z,-0.025), "First-person camera uses all three eye socket coordinates")
	player.rig.rotation.y = PI * 0.5
	player._update_eye_position()
	check(is_equal_approx(player.rig.position.x,-0.025) and is_equal_approx(player.rig.position.z,-0.025), "Eye offset follows first-person viewing direction")
	player.rig.rotation.y = 0.0
	player._update_eye_position()
	player.global_position = Vector3(38,1.05,38)
	player.velocity = Vector3.ZERO
	player.set_physics_process(true)
	await physics(6)
	check(player.submerged and player.air < 18.0, "Short body's real breathing point detects submersion where the old fixed head height would be dry")
	check(game.camera_in_water, "The actual short-player camera also applies the underwater environment")
	player.return_home()
	await physics(15)
	check(player.global_position.distance_to(game.world.get_spawn_position()) < 3.0 and player.is_on_floor(), "Custom body safely returns and settles on spawn terrain")
	check(player.air == 18.0 and not player.submerged, "Returning restores air using the custom body's height")
	var start: Vector3 = player.global_position
	Input.action_press("move_forward")
	await physics(25)
	Input.action_release("move_forward")
	check(player.global_position.z < start.z - 1.0, "Actual movement input works with a short collision body")
	Input.action_press("jump")
	await physics_frame
	Input.action_release("jump")
	await physics(12)
	check(player.global_position.y > start.y + 0.5, "Actual jump input works with the custom body")
	await physics(50)
	check(player.is_on_floor(), "Custom body lands after jumping")
	game.inventory.add_item(201)
	player.select_slot(0)
	player.rig.rotation.y = 0.0
	player.pitch.rotation.x = deg_to_rad(-60.0)
	await physics(3)
	player._update_target()
	check(player.target_id > 0, "Short camera's actual center ray can select nearby terrain")
	var mined_before: int = player.mined
	Input.action_press("mine")
	await physics(55)
	Input.action_release("mine")
	check(player.mined > mined_before, "Held mining input edits the real world from a custom character")
	player.set_physics_process(false)
	game.inventory.add_item(7,2)
	var wood := -1
	for i in game.inventory.bag.size():
		if game.inventory.bag[i].id == 7:
			wood = i
	game.inventory.move_item("bag",wood,"bag",0)
	player.select_slot(0)
	player.global_position = Vector3(16.5,5.02,21.5)
	player.target_cell = Vector3i(player.global_position.floor()) + Vector3i.DOWN
	player.target_id = 5
	player.target_normal = Vector3i.UP
	var before_count: int = game.inventory.count_item(7)
	player._place()
	check(game.inventory.count_item(7) == before_count, "Placement overlap guard uses the new body's occupied volume")
	check(game.save_progress(), "Played custom character saves with collected resources")
	var saved: Dictionary = saves.load_world()
	check(saved.ok and saved.data.player.character.name == "矮个测试" and saved.data.player.character.cubes.size() == short_body.cubes.size(), "Validated save preserves the actual model snapshot")
	var invalid: Dictionary = saved.data.duplicate(true)
	invalid.player.character.cubes[0].bone = "missing_bone"
	check(not saves.world_validation_error(invalid).is_empty(), "Corrupt character attachments invalidate a world save")
	invalid = saved.data.duplicate(true)
	invalid.player.character.cubes[0].dimensions = [1,2,1]
	check(not saves.world_validation_error(invalid).is_empty(), "Non-cube model data cannot enter a world save")
	game.queue_free()
	await frames()
	check(saves.delete_save(), "Isolated gameplay save is cleaned up")
	print("CHARACTER_GAMEPLAY_INTEGRITY_PASS: %d checks, %d failures" % [checks,failures])
	quit(0 if failures == 0 else 1)

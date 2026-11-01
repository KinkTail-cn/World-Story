extends SceneTree

const Data = preload("res://scripts/blueprint/BlueprintData.gd")
const Design = preload("res://scripts/blueprint/BlueprintEquipment.gd")
const Inventory = preload("res://scripts/inventory/Inventory.gd")
const Saves = preload("res://scripts/system/SaveSystem.gd")
const Character = preload("res://scripts/player/CharacterVisual.gd")
var failures: int = 0
var checks: int = 0

func _initialize() -> void:
	create_timer(30.0).timeout.connect(func(): push_error("BLUEPRINT_CRAFT_TIMEOUT"); quit(1))
	_run.call_deferred()

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(label)

func _run() -> void:
	var data = Data.new("晴风翼盔", "头部装备", 8)
	data.add_voxel(Vector3i(0, 3, 0), 4, "头部装备", 1, [0.017, 0.33, 0.11])
	data.add_voxel(Vector3i(1, 3, 0), 6, "头部装备", 3, [0.15, 0.33, 0.11])
	data.add_voxel(Vector3i.ZERO, 3, "盔甲")
	var design: Dictionary = data.to_dictionary()
	check(Design.material_cost(design) == {3: 1, 9: 1}, "Only selected part contributes to cost")
	var volume = Data.new("volume", "头部装备", 8)
	for i in range(64):
		volume.add_voxel(Vector3i(i, 0, 0), 1, "头部装备", 2)
	check(Design.material_cost(volume.to_dictionary()) == {5: 1}, "64 quarter voxels use one block")
	volume.add_voxel(Vector3i(65, 0, 0), 1, "头部装备", 4)
	check(Design.material_cost(volume.to_dictionary()) == {5: 2}, "Smallest brush rounds cost up only after whole-block boundary")
	var survival = Inventory.new("survival")
	survival.bag[0] = {"id": 3, "count": 2}
	var before: Array = survival.bag.duplicate(true)
	check(not survival.craft_blueprint(design).ok and survival.bag == before, "Missing material leaves bag untouched")
	for i in range(2, 24):
		survival.bag[i] = {"id": 301, "count": 1}
	survival.bag[1] = {"id": 9, "count": 2}
	before = survival.bag.duplicate(true)
	check(not survival.craft_blueprint(design).ok and survival.bag == before, "Full bag failure does not consume materials")
	survival.bag[1].count = 1
	var made: Dictionary = survival.craft_blueprint(design)
	check(made.ok and survival.bag.size() == 24 and survival.bag[0].count == 1, "Material consumption can free the output slot")
	check(survival.bag[1].id == 101 and survival.bag[1].blueprint.voxels.size() == 2, "Produced gear keeps only its own category")
	check(survival.equip_from_bag(1) and survival.get_slot("equipment", 0).custom_name == "晴风翼盔", "Survival output is equippable")
	before = survival.bag.duplicate(true)
	check(not survival.craft_blueprint(Data.new("empty", "头部装备").to_dictionary()).ok and survival.bag == before, "Empty design cannot consume resources")
	check(not survival.craft_blueprint(Data.new("tool", "工具").to_dictionary()).ok, "Unsupported categories cannot produce armor")

	var game = preload("res://scenes/Main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	for frame in range(60):
		await physics_frame
	var event := InputEventAction.new()
	event.action = "blueprint"
	event.pressed = true
	game._input(event)
	var workshop = game.hud.blueprint_workshop
	check(paused and workshop.visible, "P opens the workshop")
	workshop.blueprint = Data.from_dictionary(design)
	workshop.name_edit.text = "晴风翼盔"
	workshop._select_category("头部装备", true)
	check(not workshop.craft_btn.disabled and workshop.cost_label.text.contains("原木"), "Workshop exposes the real material cost")
	workshop._save_pressed()
	check(workshop.saved_designs.item_count > 0 and not workshop.saved_designs.disabled, "Saved designs are available for selection")
	workshop._new_design()
	check(workshop.blueprint.voxels.is_empty(), "New design starts empty")
	workshop._load_design(game.blueprint_manager.blueprints.size() - 1)
	check(workshop.blueprint.voxels.size() == 3 and workshop.name_edit.text == "晴风翼盔", "Saved designs can be reopened for production")
	if "--capture" in OS.get_cmdline_user_args():
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("C:/Users/Qi/AppData/Local/Temp/opencode/world-story-workshop-crafting.png")
	var original_size: int = game.inventory.bag.size()
	workshop.craft_btn.pressed.emit()
	check(game.inventory.bag.size() == original_size + 1, "Creative crafting grows a full bag")
	var item: Dictionary = game.inventory.bag.back().duplicate(true)
	workshop.blueprint.voxels[0].mat = 8
	check(game.inventory.bag.back().blueprint.voxels[0].mat == 4, "Editing the design does not mutate crafted gear")
	check(game.inventory.equip_from_bag(original_size), "Crafted helmet equips through normal inventory")
	var rendered = game.player.visual.equipment_visuals.custom_visuals[0]
	check(rendered != null and rendered.pieces.size() == 2, "Equipping builds the actual design")
	check(rendered.pieces[0].get_parent() == game.player.visual.head, "Helmet follows head bone")
	check(rendered.pieces[0].position.is_equal_approx(Vector3(-0.017, 0.33, -0.11)), "Workshop and in-game orientation agree")
	check(rendered.pieces[1].mesh.size.is_equal_approx(Vector3.ONE * 0.065), "Fine brush dimensions survive production")
	check(not game.player.visual.equipment_visuals.pieces[0][0].visible, "Custom gear replaces the default helmet")
	check(game.inventory.unequip(0), "Custom gear can be removed")
	check(game.inventory.bag[original_size] == item, "Removing gear retains its complete metadata")
	game.inventory.move_item("bag", original_size, "bag", 0)
	check(game.hud.slots.get_child(0).get_node("Icon")._display3d.current_data == item, "Hotbar preview receives the same design")
	game.inventory.equip_from_bag(0)
	game.inventory.equip_from_bag(10)
	check(game.inventory.bag[10] == item and game.player.visual.equipment_visuals.custom_visuals[0] == null, "Swapping to built-in armor returns custom gear intact")
	game.inventory.equip_from_bag(10)
	game.hud.close_design()
	if "--capture" in OS.get_cmdline_user_args():
		game.player.rig.rotation.y = PI
		game.player.pitch.rotation.x = -0.15
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		for frame in range(4):
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("C:/Users/Qi/AppData/Local/Temp/opencode/world-story-crafted-helmet.png")

	var path := "user://blueprint_craft_%d_%d.json" % [OS.get_process_id(), Time.get_ticks_usec()]
	var saves = Saves.new(path)
	game.save_system = saves
	check(game.save_progress(), "Game saves the equipped custom design")
	var loaded: Dictionary = saves.load_game()
	var restored = preload("res://scenes/Main.tscn").instantiate()
	restored.setup_lifecycle(saves, game.settings_system, loaded)
	root.add_child(restored)
	for frame in range(4):
		await physics_frame
	check(restored.inventory.get_slot("equipment", 0) == item, "Equipped design survives an actual JSON save/load")
	check(restored.player.visual.equipment_visuals.custom_visuals[0].pieces.size() == 2, "Load rebuilds the worn model")
	check(restored.inventory.unequip(0), "Restored custom gear is removable")
	var legacy = Inventory.new()
	saves.apply_inventory(legacy, {"equipment": [101, 0, 0, 0, 0, 0, 0]})
	check(legacy.get_slot("equipment", 0).id == 101 and not legacy.get_slot("equipment", 0).has("blueprint"), "Old equipment saves still load")
	saves.delete_save()
	restored.queue_free()
	game.queue_free()
	await process_frame

	var character = Character.new()
	root.add_child(character)
	var ids: Array[int] = []
	var items: Array[Dictionary] = []
	for slot in range(7):
		var part: String = Design.CATEGORIES[slot]
		var one = Data.new(part, part)
		one.add_voxel(Vector3i.ZERO, slot + 1, part, 4, [0.0, 0.0, 0.2])
		ids.append(101 + slot)
		items.append(Design.make_item(one.to_dictionary()))
	character.equipment_visuals.apply_equipment(ids, items)
	for slot in range(7):
		check(character.equipment_visuals.custom_visuals[slot].pieces.size() == 1, "All seven equipment categories render: " + Design.CATEGORIES[slot])
	var glove = character.equipment_visuals.custom_visuals[4].pieces[0]
	var glove_local: Vector3 = glove.position
	character.animate(0.1, 4.8, false, false)
	check(glove.get_parent() == character.right_forearm and glove.position == glove_local, "Glove follows animated forearm without changing its local shape")
	character.queue_free()
	await process_frame
	print("BLUEPRINT_CRAFT_SMOKE: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

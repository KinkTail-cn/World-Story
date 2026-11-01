extends SceneTree

const Sets = preload("res://scripts/content/EquipmentSets.gd")
const Models = preload("res://scripts/player/EquipmentModels.gd")
const Items = preload("res://scripts/inventory/ItemCatalog.gd")
const Inventory = preload("res://scripts/inventory/Inventory.gd")
const Character = preload("res://scripts/player/CharacterVisual.gd")
const Display = preload("res://scripts/ui/ItemDisplay3D.gd")
const Save = preload("res://scripts/system/SaveSystem.gd")
var checks: int = 0
var failures: int = 0

func _initialize() -> void:
	create_timer(30.0).timeout.connect(func(): push_error("EQUIPMENT_SETS_TIMEOUT"); quit(1))
	_run.call_deferred()

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(label)

func _run() -> void:
	check(Items.equipment_ids().size() == 28, "Catalog exposes seven original and 21 new equipment pieces")
	var recipes: Dictionary = Inventory.recipe_definitions()
	var seen := {}
	var character = Character.new()
	root.add_child(character)
	for key in Sets.STYLES:
		var ids := Sets.ids(key)
		check(ids.size() == 7, key + " is a complete seven-slot outfit")
		for slot in range(7):
			var id: int = ids[slot]
			check(not seen.has(id) and Items.is_equipment(id) and Items.equipment_slot(id) == slot, "Stable unique ID and slot for " + str(id))
			seen[id] = true
			check(not Items.is_tool_item(id) and not Items.is_weapon(id) and not Items.is_document(id) and Items.title(id) != "空气", "Equipment classification and title for " + str(id))
			check(Items.color(id).a > 0 and Items.description(id).length() > 10 and Items.get_item_info(id).attributes.size() == 2, "Description, style and color for " + str(id))
			var recipe_key := ""
			for candidate in Sets.RECIPES:
				if Sets.RECIPES[candidate] == id:
					recipe_key = candidate
			check(not recipe_key.is_empty() and recipes[recipe_key].id == id, "No recipe collision for " + str(id))
			var inv = Inventory.new("survival")
			for ingredient in recipe_key.split(","):
				inv.add_item(int(ingredient), 1)
			check(inv.prepare_recipe(recipe_key) and inv.get_slot("result", 0).id == id and inv.take_result(), "Survival recipe produces " + str(id))
			check(inv.bag[0].id == id and inv.equip_from_bag(0) and inv.equipment[slot] == id, "Crafted piece equips to the intended slot")
			check(inv.unequip(slot) and inv.bag[0].id == id, "New piece can be removed intact")
			inv.add_item(id, 1)
			check(inv.bag[0].count == 1 and inv.bag[1].id == id and inv.bag[1].count == 1, "Equipment never stacks")
			var display = Display.new()
			root.add_child(display)
			display.set_item(id)
			check(not display.block_instance.visible and display.get_child_count() > 1, "Inventory preview renders a real equipment model")
			display.queue_free()
		character.equipment_visuals.apply_equipment(ids)
		await process_frame
		for slot in range(7):
			var visual = character.equipment_visuals.set_visuals[slot]
			check(visual != null and visual.item_id == ids[slot] and visual.pieces.size() == Models.parts(ids[slot]).size(), "Worn geometry matches item geometry for " + str(ids[slot]))
			check(character.equipment_visuals.pieces[slot].all(func(piece): return not piece.visible), "New outfit hides the replaced base piece")
			var correct_bones := true
			var parts: Array[Dictionary] = Models.parts(ids[slot])
			for index in range(parts.size()):
				correct_bones = correct_bones and visual.pieces[index].get_parent() == character.get(parts[index].bone)
			check(correct_bones, "Every mesh follows its animated body part")
		var original = character.equipment_visuals.set_visuals[0]
		character.equipment_visuals.apply_equipment(ids)
		check(character.equipment_visuals.set_visuals[0] == original, "Unchanged loadout reuses its models")
		for frame in range(90):
			character.animate(1.0 / 60.0, 7.8, false, false, false, false, false, true)
		check(float(character.equipment_visuals.set_visuals[5].cloth_materials[0].get_shader_parameter("wind_strength")) > 0.8, "New cape responds to running wind")
		character.animate(0.1, 0.0, false, false, false, false, true)
		check(character.equipment_visuals.set_visuals[2].pieces[0].global_transform.is_finite(), "Outfit remains attached while sitting")
	check(seen.size() == 21, "All 21 new pieces have been exercised")
	character.queue_free()
	await process_frame

	var game = preload("res://scenes/Main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	for frame in range(70):
		await physics_frame
	var inventory = game.inventory
	inventory.bag[10] = {"id": 101, "count": 1, "custom_name": "保留的自制帽", "blueprint": {"name": "keep", "category": "头部装备", "voxels": [{"pos": [0, 3, 0], "mat": 4, "part": "头部装备", "size": 1}]}}
	var custom: Dictionary = inventory.bag[10].duplicate(true)
	inventory.equip_from_bag(10)
	check(inventory.equip_creative_set(Sets.ids("ranger")) and inventory.bag.has(custom), "Whole-outfit change preserves a worn custom item")
	var bag_before: Array = inventory.bag.duplicate(true)
	var equipment_before: Array = inventory.equipment.duplicate()
	var invalid: Array[int] = [401, 401, 403, 404, 405, 406, 407]
	check(not inventory.equip_creative_set(invalid) and inventory.bag == bag_before and inventory.equipment == equipment_before, "Invalid outfit change is atomic")
	var survival = Inventory.new("survival")
	check(not survival.equip_creative_set(Sets.ids("knight")), "Survival cannot use a creative outfit grant")
	var event := InputEventAction.new()
	event.action = "inventory"
	event.pressed = true
	game._input(event)
	var panel = game.hud.inventory_panel
	panel._select_category("equipment")
	check(panel.creative_grid.get_child_count() == 28, "Equipment library contains all original and new gear")
	for index in range(2, 5):
		panel.equipment_style.select(index)
		panel.equipment_style.item_selected.emit(index)
		check(panel.creative_grid.get_child_count() == 7 and not panel.wear_set.disabled, "Style filter exposes one complete outfit")
		panel.wear_set.pressed.emit()
		var key: String = Sets.STYLES[index - 2]
		check(inventory.equipment == Sets.ids(key) and panel.preview_character.equipment_visuals.equipped_ids == Sets.ids(key), "Whole-outfit button updates player and backpack mannequin")
		for frame in range(5):
			await process_frame
		await _capture(key)
	check(panel.preview_camera.size > 2.3, "Mannequin framing includes the mage's tall pointed hat")
	var original_size := root.size
	var original_scale_size := root.content_scale_size
	root.content_scale_size = Vector2i.ZERO
	root.size = Vector2i(960, 600)
	for frame in range(5):
		await process_frame
	check(root.get_visible_rect().encloses(panel.card.get_global_rect()) and panel.card.get_global_rect().encloses(panel.get_node("%EquipmentStyleRow").get_global_rect()), "Outfit filter and full-set button fit a small window")
	root.size = original_size
	root.content_scale_size = original_scale_size
	var mixed: Array[int] = [401, 412, 423, 404, 415, 426, 427]
	check(inventory.equip_creative_set(mixed), "Different outfit styles can be mixed by slot")
	game._close_inventory()
	game.hud.blueprint_workshop.set_player_template(game.player.visual)
	game.hud.blueprint_workshop.open(game.blueprint_manager)
	game.hud.blueprint_workshop._select_category("头部装备", true)
	var mannequin = game.hud.blueprint_workshop.real_character
	check(mannequin.equipment_visuals.set_visuals[0] == null and mannequin.equipment_visuals.set_visuals[1].item_id == 412, "Blueprint workshop hides only the part currently being designed")
	game.hud.close_design()
	var path := "user://equipment_sets_%d_%d.json" % [OS.get_process_id(), Time.get_ticks_usec()]
	var saves = Save.new(path)
	game.save_system = saves
	check(game.save_progress(), "Actual game saves a mixed new outfit")
	var restored = preload("res://scenes/Main.tscn").instantiate()
	restored.setup_lifecycle(saves, game.settings_system, saves.load_game())
	root.add_child(restored)
	for frame in range(5):
		await physics_frame
	check(restored.inventory.equipment == mixed, "Saved mixed outfit IDs survive loading")
	for slot in range(7):
		check(restored.player.visual.equipment_visuals.set_visuals[slot].item_id == mixed[slot], "Loading rebuilds each new equipment model")
	check(restored.inventory.bag.has(custom), "Saved backpack keeps replaced custom gear")
	saves.delete_save()
	restored.queue_free()
	game.queue_free()
	await process_frame
	print("EQUIPMENT_SETS_SMOKE_PASS: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

func _capture(style: String) -> void:
	if "--capture" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("C:/Users/Qi/AppData/Local/Temp/opencode/world-story-equipment-library-" + style + ".png")

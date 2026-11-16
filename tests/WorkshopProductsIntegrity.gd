extends SceneTree

const Catalog = preload("res://scripts/inventory/ItemCatalog.gd")
const Inventory = preload("res://scripts/inventory/Inventory.gd")
const Design = preload("res://scripts/blueprint/BlueprintEquipment.gd")
const Data = preload("res://scripts/blueprint/BlueprintData.gd")
const Presets = preload("res://scripts/blueprint/UtilityPresets.gd")
var checks: int = 0
var failures: int = 0

func _initialize() -> void:
	create_timer(35.0).timeout.connect(func(): push_error("WORKSHOP_PRODUCTS_TIMEOUT"); quit(1))
	_run.call_deferred()

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)

func _run() -> void:
	for category in ["工具", "武器", "道具摆件"]:
		for id in Design.product_ids(category):
			var blueprint := Presets.design(id)
			check(Data.validation_error(blueprint).is_empty() and Design.validation_error(blueprint).is_empty(), "Editable basic template is valid: " + str(id))
			check(blueprint.target_item_id == id and blueprint.category == category, "Template keeps the selected functional item class")
			var inventory := Inventory.new("survival")
			var costs := Design.material_cost(blueprint)
			for resource in costs: inventory.add_item(int(resource), int(costs[resource]))
			var result := inventory.craft_blueprint(blueprint)
			check(result.ok and result.item.id == id and Design.is_custom_item(result.item), "Selected class produces a usable custom item: " + str(id))
			if not result.ok: continue
			for resource in costs: check(inventory.count_item(int(resource)) == 0, "Survival consumes exactly the displayed material cost")
			var item: Dictionary = result.item
			blueprint.voxels.clear()
			check(not item.blueprint.voxels.is_empty(), "Crafted geometry remains an independent snapshot")
			var visual = preload("res://scripts/player/UtilityVisual.gd").new()
			root.add_child(visual)
			visual.build(id, item, false)
			check(visual.get_child_count() > 0 and visual.bounds.size.length() > 0, "Custom product has a visible full-size model")
			visual.queue_free()
	var tool := Presets.design(207)
	check(Design.material_cost(tool).has(602), "Iron-class blueprints require a smelted iron component")
	var wrong := tool.duplicate(true)
	wrong.target_item_id = 501
	check(not Design.validation_error(wrong).is_empty(), "A tool cannot masquerade as a storage facility")
	var authored = Data.from_dictionary(tool)
	var session = preload("res://scripts/blueprint/BlueprintEditSession.gd").new()
	session.bind(authored)
	var saved: Dictionary = session.snapshot()
	authored.target_item_id = 208
	session.restore_snapshot(saved)
	check(authored.target_item_id == 207, "Discarding edits restores the functional item class with the geometry")
	var game = preload("res://scenes/Main.tscn").instantiate()
	root.add_child(game)
	while game.is_loading: await process_frame
	var workshop = game.hud.blueprint_workshop
	workshop.open(game.blueprint_manager)
	workshop._select_category("工具", true)
	check(workshop.product_selector.visible and workshop.product_selector.item_count == 9, "Workshop exposes the actual tool-class selector")
	workshop.product_selector.select(workshop.product_selector.get_item_index(207))
	workshop.product_selector.item_selected.emit(workshop.product_selector.selected)
	workshop._open_product_template()
	check(workshop.blueprint.target_item_id == 207 and not workshop.blueprint.voxels.is_empty(), "The template button loads the selected tool for editing")
	workshop._craft_pressed()
	var crafted: Dictionary = game.inventory.bag.back()
	check(crafted.id == 207 and Design.is_custom_item(crafted), "The real craft button puts a custom tool into the bag")
	game.inventory.move_item("bag", game.inventory.bag.size() - 1, "bag", 0)
	game.player.select_slot(0)
	check(game.player.visual.held_item.tool_visual != null and game.player.visual.held_item.item_data.has("blueprint"), "Actual third-person grip displays the crafted tool snapshot")
	check(Catalog.get_mining_speed(game.player.selected_item_id(), 5) == 6.0, "A crafted iron pickaxe uses its chosen mining function")
	game.player.set_first_person(true)
	check(game.player.first_person_item.tool_visual != null and game.player.first_person_item.item_data.has("blueprint"), "Actual first-person grip uses the same crafted geometry")
	check(game.save_progress() and game.save_system.load_world().ok, "Custom tools and new product metadata survive validated save/load")
	game.queue_free()
	for frame in range(4): await process_frame
	print("WORKSHOP_PRODUCTS_INTEGRITY_PASS: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

extends SceneTree

const Inventory = preload("res://scripts/inventory/Inventory.gd")
const Document = preload("res://scripts/world/DocumentItem.gd")
const SaveSystem = preload("res://scripts/system/SaveSystem.gd")
const Blueprint = preload("res://scripts/blueprint/BlueprintData.gd")
var failures: int = 0
var checks: int = 0

class TestPlayer extends "res://scripts/player/Player.gd":
	func _ready() -> void:
		pass
	func _physics_process(_delta: float) -> void:
		pass
	func _spawn_debris(_pos: Vector3, _color: Color) -> void:
		pass

class TestVisual extends Node3D:
	func play_place() -> void:
		pass

class TestWorld extends Node3D:
	var block: int = 3
	var removed: bool = false
	var reject: bool = false
	var placed_document: Node3D
	func set_block(_cell: Vector3i, id: int) -> bool:
		if reject:
			return false
		block = id
		return true
	func remove_document(doc: Node3D) -> void:
		removed = true
		doc.queue_free()
	func place_document(cell: Vector3i, id: int) -> Node3D:
		placed_document = Document.new()
		placed_document.item_id = id
		placed_document.support_cell = cell
		add_child(placed_document)
		return placed_document

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(label)

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var survival = Inventory.new("survival")
	check(survival.bag.size() == 24, "Survival has 24 slots")
	check(not survival.give_creative_item(3), "Survival rejects catalog grant")
	check(not survival.move_item("creative", 3, "bag", 0), "Survival rejects catalog drag")
	for i in 24:
		survival.bag[i] = {"id": 3, "count": 64}
	survival.bag[0].count = 63
	var before: Array = survival.bag.duplicate(true)
	check(not survival.add_item(3, 2) and survival.bag == before, "Failed bulk pickup is atomic")
	check(survival.add_item(3), "Last available stack unit is usable")
	check(not survival.add_document_item(108, {"notes": ["keep"]}), "Full bag rejects unique notebook")

	var creative = Inventory.new()
	before = creative.bag.duplicate(true)
	check(creative.give_creative_item(301), "Full creative bag grows")
	check(creative.bag.size() == 25 and creative.bag.slice(0, 24) == before, "Catalog grant preserves all existing slots")
	var payload := {"notes": ["field notes"], "blueprints": [{"name": "House", "category": "building", "voxels": [{"pos": [1, 2, 3], "mat": 5, "part": "building", "size": 1}]}], "custom_name": "Journal"}
	check(creative.add_document_item(108, payload), "Creative unique document grows bag")
	var doc_index: int = creative.bag.size() - 1
	payload.notes.append("external mutation")
	check(creative.bag[doc_index].notes.size() == 1, "Document insertion deep copies metadata")
	var original: Dictionary = creative.get_slot("bag", doc_index)
	check(creative.give_creative_item(5, doc_index), "Explicit catalog drop relocates occupied item")
	check(creative.bag.back() == original, "Catalog drop preserves unique document")
	check(creative.move_item("bag", creative.bag.size() - 1, "bag", 0), "Unique document transfers")
	check(creative.bag[0] == original, "Transfer preserves metadata")
	var copied: Dictionary = creative.get_slot("bag", 0)
	copied.notes.append("copy mutation")
	check(creative.bag[0].notes.size() == 1, "Slot getter deep copies metadata")
	check(creative.consume_slot(0) and creative.bag[0].id == 0, "Creative unique placement consumes identity")
	creative.bag[0] = {"id": 14, "count": 4}
	check(creative.consume_slot(0) and creative.bag[0].count == 4, "Creative finite crafted blocks do not decrement")
	var weapons = Inventory.new("survival")
	check(weapons.add_item(301, 2), "Multiple weapons can be added")
	weapons.move_item("bag", 0, "bag", 1)
	check(weapons.bag[0].count == 1 and weapons.bag[1].count == 1, "Weapons never merge")

	var world := TestWorld.new()
	root.add_child(world)
	var player := TestPlayer.new()
	# Supply scene children so inherited onready bindings resolve without game startup.
	var visual := TestVisual.new()
	visual.name = "Visual"
	player.add_child(visual)
	var rig := Node3D.new()
	rig.name = "CameraRig"
	player.add_child(rig)
	var pitch := Node3D.new()
	pitch.name = "Pitch"
	rig.add_child(pitch)
	var arm := SpringArm3D.new()
	arm.name = "SpringArm"
	pitch.add_child(arm)
	var camera := Camera3D.new()
	camera.name = "Camera"
	arm.add_child(camera)
	var collision := CollisionShape3D.new()
	collision.name = "Collision"
	player.add_child(collision)
	root.add_child(player)
	player.world = world
	player.inventory = survival
	player.target_id = 3
	player._mine()
	check(world.block == 3 and player.mined == 0, "Full survival bag cannot delete mined block")
	survival.bag[0] = {"id": 0, "count": 0}
	world.reject = true
	before = survival.bag.duplicate(true)
	player._mine()
	check(survival.bag == before, "Rejected world edit grants no block")
	world.reject = false
	player._mine()
	check(world.block == 0 and survival.bag[0].id == 3, "Successful mining grants block")

	var migrated_original := original.duplicate(true)
	migrated_original.blueprints = original.blueprints.map(func(design): return Blueprint.from_dictionary(design).to_dictionary())
	check(migrated_original.blueprints[0].name == "House" and migrated_original.blueprints[0].voxels[0].pos == [1, 2, 3] and migrated_original.blueprints[0].voxels[0].mat == 5, "Schema migration preserves document title, geometry and material")
	for id in [108, 109]:
		var doc := Document.new()
		doc.item_id = id
		world.add_child(doc)
		doc.restore_data(original.duplicate(true))
		player.target_document = doc
		for i in 24:
			survival.bag[i] = {"id": 3, "count": 64}
		world.removed = false
		player._mine()
		check(not world.removed and not doc.is_queued_for_deletion(), "Full bag retains world document %d" % id)
		survival.bag[0] = {"id": 0, "count": 0}
		var order_check := func(_doc): check(survival.bag[0].id == id, "Pickup committed before document_mined")
		player.document_mined.connect(order_check)
		player._mine()
		player.document_mined.disconnect(order_check)
		check(world.removed and survival.bag[0].notes == original.notes and survival.bag[0].blueprints == migrated_original.blueprints, "Recovery preserves notes and migrated blueprint contents")
		player.target_id = 3
		player.target_cell = Vector3i(10, 1, 10)
		player.target_normal = Vector3i.UP
		player._place()
		check(world.placed_document.contents.notes == original.notes and world.placed_document.contents.blueprints == migrated_original.blueprints, "Placement restores notes and migrated blueprint contents")
		check(survival.bag[0].id == 0, "Placed document consumes slot")
	player.inventory = creative
	creative.bag[0] = original.duplicate(true)
	player._place()
	check(creative.bag[0].id == 0, "Creative world placement consumes unique document")
	check(world.placed_document.get_meta("inventory_custom_name") == original.custom_name, "Placement retains document title")
	player.target_document = world.placed_document
	player._mine()
	check(creative.bag[0] == migrated_original, "Creative recovery preserves identity metadata while upgrading the blueprint schema")
	creative.bag[0] = {"id": 14, "count": 4}

	var panel = preload("res://scenes/InventoryPanel.tscn").instantiate()
	root.add_child(panel)
	panel.bind_inventory(creative)
	panel._set_creative_view(true)
	var catalog_slot: Control = panel.creative_grid.get_child(0)
	var count_before: int = creative.bag.size()
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	catalog_slot._gui_input(press)
	check(creative.bag.size() == count_before, "Catalog press does not grant")
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.position = Vector2.ONE
	catalog_slot.size = Vector2(86, 86)
	catalog_slot._gui_input(release)
	check(creative.bag.size() == count_before + 1, "Catalog release grants once")
	check(panel.creative_grid.get_child(0) == catalog_slot, "Inventory changes preserve catalog nodes")
	check(panel.bag_grid.get_child_count() + panel.hotbar_grid.get_child_count() == creative.bag.size() and panel.bag_grid.get_parent() is ScrollContainer, "Expanded storage scrolls while the eight hotbar slots stay pinned")
	# Drag start clears this flag in _get_drag_data; release must not grant again.
	catalog_slot._click_pending = false
	catalog_slot._gui_input(release)
	check(creative.bag.size() == count_before + 1, "Release after drag does not grant")
	var notebook = preload("res://scenes/NotebookPanel.tscn").instantiate()
	root.add_child(notebook)
	notebook.editor.text = "stale text"
	notebook.open(preload("res://scripts/blueprint/BlueprintManager.gd").new())
	check(notebook.editor.text.is_empty(), "Notebook open clears editor")
	notebook.editor.text = "original note"
	notebook._save_note()
	notebook.list.item_selected.emit(0)
	notebook.editor.text = "edited note"
	notebook._save_note()
	check(notebook.manager.notes == ["edited note"], "Editing a selected note replaces its contents")
	notebook.get_node("Card/Body/Actions/New").pressed.emit()
	notebook.editor.text = "another note"
	notebook._save_note()
	check(notebook.manager.notes == ["edited note", "another note"], "New note leaves the edited note intact")

	var path := "user://inventory_integrity_%d_%d.json" % [OS.get_process_id(), Time.get_ticks_usec()]
	var saves = SaveSystem.new(path)
	creative.add_document_item(108, original)
	var saved: Dictionary = saves.save_inventory(creative)
	creative.bag.back().notes.append("after snapshot")
	check(saved.bag.back().notes.size() == 1, "Inventory save snapshot deep copies notes")
	creative.bag.back().notes.pop_back()
	check(saves.save_game({"inventory": saved}), "Isolated inventory save writes")
	var loaded = Inventory.new()
	saves.apply_inventory(loaded, saves.load_game().inventory)
	check(loaded.bag.size() == creative.bag.size(), "Save round trip preserves expanded capacity")
	var expected_bag: Array = creative.bag.duplicate(true)
	for item in expected_bag:
		if item.has("blueprints"):
			item.blueprints = item.blueprints.map(func(design): return Blueprint.from_dictionary(design).to_dictionary())
	check(loaded.bag == expected_bag, "Save round trip preserves all content and upgrades historical blueprint schemas")
	saves.delete_save()
	panel.free()
	notebook.free()
	player.free()
	world.free()
	await process_frame
	print("InventoryIntegrity: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

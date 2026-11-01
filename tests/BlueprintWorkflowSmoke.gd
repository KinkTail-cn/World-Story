extends SceneTree

const Presets = preload("res://scripts/blueprint/BlueprintPresets.gd")
const Geometry = preload("res://scripts/blueprint/BlueprintGeometry.gd")
const Manager = preload("res://scripts/blueprint/BlueprintManager.gd")
const Save = preload("res://scripts/system/SaveSystem.gd")
var checks: int = 0
var failures: int = 0

func _initialize() -> void:
	create_timer(35.0).timeout.connect(func(): push_error("BLUEPRINT_WORKFLOW_TIMEOUT"); quit(1))
	_run.call_deferred()

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(label)

func _run() -> void:
	var game = preload("res://scenes/Main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	for frame in range(100):
		await physics_frame
	var path := "user://blueprint_workflow_%d_%d.json" % [OS.get_process_id(), Time.get_ticks_usec()]
	var saves = Save.new(path)
	game.save_system = saves
	game._input(action("blueprint"))
	var editor = game.hud.blueprint_workshop
	check(editor.visible and paused, "P opens the modeling editor from the running game")
	var official := Presets.design_for_item(412)
	editor._open_official(412)
	editor.name_edit.text = "我的斜肩甲"
	editor.name_edit.text_changed.emit("我的斜肩甲")
	var shoulder: String = editor.blueprint.voxels[4].uid
	var original_dimensions: Array = editor.blueprint.voxels[4].dimensions.duplicate()
	var original_offset: Array = editor.blueprint.voxels[4].offset.duplicate()
	editor._set_editor_mode("select")
	editor.edit_session.select([shoulder])
	editor.inspector.get_node("%Rotation").get_child(2).value = 30.0
	editor.inspector.tint_picker.color = Color("5b8799")
	editor.inspector.tint_picker.color_changed.emit(Color("5b8799"))
	editor.inspector.get_node("%Apply").pressed.emit()
	var source_index: int = editor.blueprint.find_part(shoulder)
	check(absf(float(editor.blueprint.voxels[source_index].rotation[2]) - 30.0) < 0.001 and editor.blueprint.voxels[source_index].anchor == "left_arm", "User edits the official shoulder with an explicit arm anchor")
	check(int(editor.blueprint.voxels[source_index].mat) == int(official.voxels[4].mat), "Editing angles and tint preserves the selected part's physical material")
	check(editor.blueprint.voxels[source_index].dimensions == original_dimensions and editor.blueprint.voxels[source_index].offset == original_offset, "Changing angle/dye never rounds untouched dimensions or anchor offsets")
	check(editor._save_pressed() and not editor.edit_session.dirty(), "Save button persists the edited design through the actual game")
	var library = Manager.new()
	check(library.load_json() and library.blueprints.any(func(design): return design.name == "我的斜肩甲" and int(design.schema_version) == 2), "An independent library instance reads the saved version-two design")
	check(Presets.design_for_item(412) == official, "User changes never alter the official template")
	var armor: Dictionary = editor._design_snapshot()
	editor.craft_btn.pressed.emit()
	var armor_slot: int = game.inventory.bag.size() - 1
	check(game.inventory.bag[armor_slot].get("custom_name", "") == "我的斜肩甲" and game.inventory.equip_from_bag(armor_slot), "Editor craft button creates an equippable design snapshot")
	check(game.player.visual.equipment_visuals.custom_visuals[1].source_part_count == armor.voxels.size(), "Actual player uses every edited armor component")
	check(game.hud.inventory_panel.preview_character.equipment_visuals.custom_visuals[1] != null, "Backpack mannequin displays the same custom armor")
	editor._open_official(426)
	editor.name_edit.text = "我的星纹披风"
	editor.name_edit.text_changed.emit("我的星纹披风")
	editor.edit_session.select([editor.blueprint.voxels[0].uid])
	editor.inspector.tint_picker.color = Color("3d6873")
	editor.inspector.tint_picker.color_changed.emit(Color("3d6873"))
	editor.inspector.get_node("%Flare").value = 0.12
	editor.inspector.get_node("%Wind").value = 0.7
	editor.inspector.get_node("%Emblem").select(3)
	editor._editor_action("apply")
	check(editor._save_pressed(), "Edited cloth pattern and width profile save")
	editor.craft_btn.pressed.emit()
	var cloak_slot: int = game.inventory.bag.size() - 1
	check(game.inventory.equip_from_bag(cloak_slot), "The cloth component is producible and wearable")
	var cloak: Dictionary = game.inventory.get_slot("equipment", 5)
	check(cloak.blueprint.voxels[0].cloth.emblem == 3 and is_equal_approx(cloak.blueprint.voxels[0].cloth.wind, 0.7), "Cloth parameters are captured by the crafted item")
	editor.blueprint.voxels[0].tint = "ffffff"
	check(game.inventory.get_slot("equipment", 5).blueprint.voxels[0].tint == "3d6873", "Editing after crafting leaves the earlier item unchanged")
	# Save the later edit so normal close can finish without discarding work.
	editor._save_pressed()
	check(editor.cancel_edit(), "First Escape clears the current selection")
	game._input(action("pause"))
	check(not editor.visible and not paused, "Second Escape closes a saved design and restores gameplay")
	var document = game.world.place_document(Vector3i(20, 4, 21), 109)
	document.restore_data({"blueprints": [armor], "custom_name": "斜肩甲图纸"})
	check(game.save_progress(), "F5/save API writes the world, custom gear and placed version-two document")
	var loaded_data: Dictionary = saves.load_game()
	check(saves.world_validation_error(loaded_data).is_empty(), "World save validation accepts supported shapes and new component fields")
	var restored = preload("res://scenes/Main.tscn").instantiate()
	restored.setup_lifecycle(saves, game.settings_system, loaded_data)
	root.add_child(restored)
	for frame in range(30):
		await physics_frame
	check(restored.inventory.get_slot("equipment", 1).blueprint == armor, "Loading restores the exact edited shoulder design")
	check(restored.inventory.get_slot("equipment", 5) == cloak, "Loading restores cloth, tint, pattern, width and anchors")
	check(restored.player.visual.equipment_visuals.custom_visuals[1] != null and restored.player.visual.equipment_visuals.custom_visuals[5].cloth_materials.size() == 1, "Load rebuilds real rigid and animated cloth models")
	check(restored.world.documents.size() == 1 and restored.world.documents[0].contents.current.to_dictionary() == armor, "Placed paper restores an editable advanced design")
	for frame in range(60):
		restored.player.visual.animate(1.0 / 60.0, 7.8, false, false, false, false, false, true)
	check(float(restored.player.visual.equipment_visuals.custom_visuals[5].cloth_materials[0].get_shader_parameter("wind_strength")) > 0.5, "Restored custom cloth follows the character's running motion")
	var bad := armor.duplicate(true)
	bad.voxels[0].dimensions = [0, 1, 1]
	var before: Array = restored.inventory.bag.duplicate(true)
	check(not restored.inventory.craft_blueprint(bad).ok and restored.inventory.bag == before, "Invalid advanced geometry cannot consume materials or create an item")
	saves.delete_save()
	restored.queue_free()
	game.queue_free()
	await process_frame
	print("BLUEPRINT_WORKFLOW_SMOKE_PASS: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

func action(name: String) -> InputEventAction:
	var event := InputEventAction.new()
	event.action = name
	event.pressed = true
	return event

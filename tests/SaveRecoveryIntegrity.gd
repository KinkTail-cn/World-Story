extends SceneTree

const Saves = preload("res://scripts/system/SaveSystem.gd")
const Settings = preload("res://scripts/system/SettingsSystem.gd")
const Manager = preload("res://scripts/blueprint/BlueprintManager.gd")
var checks: int = 0
var failures: int = 0

func _initialize() -> void:
	create_timer(30.0).timeout.connect(func(): push_error("SAVE_RECOVERY_TIMEOUT"); quit(1))
	_run.call_deferred()

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(label)

func write_text(path: String, text: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()

func _run() -> void:
	var directory := "user://recovery_%d_%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	DirAccess.make_dir_absolute(directory)
	var saves = Saves.new(directory + "/world.json")
	var terrain := PackedByteArray()
	terrain.resize(32 * 24 * 32)
	terrain.fill(0)
	var first := {"mode": "survival", "world": {"world_type": "island", "blocks": Marshalls.raw_to_base64(terrain)}, "player": {"global_position": Vector3(16.5, 5.1, 21.5)}}
	check(saves.save_game(first), "Write first valid world")
	var second: Dictionary = first.duplicate(true)
	second.player.global_position = Vector3(20, 8, 20)
	check(saves.save_game(second) and FileAccess.file_exists(saves.save_path + ".bak"), "Successful replacement retains the previous file")
	write_text(saves.save_path, "{broken")
	var result: Dictionary = saves.load_world()
	check(result.ok and result.recovered and result.data.player.global_position == first.player.global_position, "Broken primary recovers the previous world")
	check(saves.save_game(second), "Recovered session can save again")
	write_text(saves.save_path, "{broken again")
	check(saves.load_world().data.player.global_position == first.player.global_position, "Saving after recovery never replaces the good backup with broken JSON")
	DirAccess.remove_absolute(saves.save_path)
	check(saves.has_save() and saves.load_world().ok, "Backup-only world remains continuable")
	DirAccess.remove_absolute(saves.save_path + ".bak")
	write_text(saves.save_path, JSON.stringify({"mode": "survival", "world": [], "player": {}}))
	check(not saves.load_world().ok, "Wrong world field type is rejected")
	write_text(saves.save_path, JSON.stringify({"world": {"modified_blocks": [[0, 1, 0, 500]]}, "player": {}}))
	check(not saves.load_world().ok, "Unknown world block is rejected")
	var fractional: Dictionary = first.duplicate(true)
	fractional.player["inventory"] = {"bag": [{"id": 7.5, "count": 1}], "mode": "survival"}
	write_text(saves.save_path, JSON.stringify(fractional))
	check(not saves.load_world().ok, "Fractional IDs are rejected instead of silently becoming another item")
	var invalid: Dictionary = first.duplicate(true)
	invalid.player.global_position = {"__type": "Vector3", "x": "invalid", "y": [], "z": 0}
	write_text(saves.save_path, JSON.stringify(invalid))
	check(not saves.load_world().ok, "Malformed serialized vector returns a load error")
	var all_equipment: Array[int] = preload("res://scripts/inventory/ItemCatalog.gd").equipment_ids()
	var inventory = preload("res://scripts/inventory/Inventory.gd").new("survival")
	for id in all_equipment:
		inventory.bag[0] = {"id": id, "count": 1}
		inventory.equip_from_bag(0)
		var compatible: Dictionary = first.duplicate(true)
		compatible.player["inventory"] = saves.save_inventory(inventory)
		check(saves.world_validation_error(compatible).is_empty(), "Registered equipment is accepted by save validation: %d" % id)
	# Retired custom-body metadata must not prevent restoring useful world,
	# inventory or blueprint data after the editor has been removed.
	var design := {"schema_version": 3, "name": "原有自制头饰", "category": "头部装备", "grid_size": 8, "created_at": "2026-11-14T00:00:00", "rig_reference": {"parameters": {"height": 2.4}, "joints": {}}, "voxels": [{"uid": "kept_cube", "pos": [0, 0, 0], "part": "头部装备", "anchor": "head", "offset": [0, 0.25, -0.025], "dimensions": [0.065, 0.065, 0.065], "mat": 4, "tint": "aabbcc", "size": 1, "motion": "fixed"}]}
	var former_inventory = preload("res://scripts/inventory/Inventory.gd").new("survival")
	former_inventory.bag[0] = {"id": 101, "count": 1, "custom_name": design.name, "blueprint": design.duplicate(true)}
	check(former_inventory.equip_from_bag(0), "Prepare an item created while custom bodies were available")
	check(former_inventory.add_document_item(109, {"custom_name": "保留图纸", "blueprints": [design]}), "Prepare a saved document with retired reference metadata")
	var former_world: Dictionary = first.duplicate(true)
	former_world.player.character = {"schema_version": 1, "parameters": {"height": 1.1}, "cubes": []}
	former_world.player.inventory = saves.save_inventory(former_inventory)
	check(saves.world_validation_error(former_world).is_empty(), "Retired character metadata does not reject a usable world")
	var fixed_inventory = preload("res://scripts/inventory/Inventory.gd").new("survival")
	saves.apply_inventory(fixed_inventory, former_world.player.inventory)
	var restored_design: Dictionary = fixed_inventory.get_slot("equipment", 0).blueprint
	check(fixed_inventory.equipment[0] == 101 and restored_design.name == design.name, "Existing custom equipment restores on the fixed player")
	check(restored_design.voxels == design.voxels and not restored_design.has("rig_reference"), "Restore preserves blueprint cubes while dropping unused body metadata")
	check(fixed_inventory.bag[0].blueprints[0].voxels == design.voxels, "Stored document keeps its original design contents")
	var former_library = Manager.new()
	check(former_library.import_blueprints([design]) and former_library.blueprints[0].voxels == design.voxels, "The normal blueprint library can still import those designs")
	var player := {"global_position": Vector3(16, 6, 21), "rotation": Vector3(0, 1, 0)}
	saves.apply_player(player, {})
	check(player.global_position == Vector3(16, 6, 21) and player.rotation.y == 1, "Missing player fields preserve the safe spawn")

	var boot = preload("res://scenes/Boot.tscn").instantiate()
	boot.save_system = saves
	boot.settings_system = Settings.new(directory + "/settings.json")
	root.add_child(boot)
	boot._continue_game()
	check(boot.game == null and boot.menu.visible and boot.menu.get_node("Center/Card/Body/Error").visible, "Failed continue stays in the menu with a readable error")
	check(saves.save_game(first), "Replace isolated invalid test file with a valid world")
	DirAccess.remove_absolute(saves.save_path + ".bak")
	check(saves.save_game(second), "Create valid rolling backup")
	DirAccess.remove_absolute(saves.save_path)
	boot.menu.refresh()
	check(boot.menu.continue_button.visible, "Menu discovers a backup-only save through the shared storage instance")
	boot._continue_game()
	check(boot.game != null and boot.game.inventory.mode == "survival" and boot.game.loaded_data.player.global_position == first.player.global_position, "Continue actually starts the recovered game")
	boot.queue_free()
	await process_frame

	var library := directory + "/library.json"
	var manager = Manager.new()
	manager.save_note("keep this note")
	check(manager.save_json(library), "Create the initial library")
	DirAccess.make_dir_absolute(library + ".bak")
	manager.save_note("new note")
	check(not manager.save_json(library), "Failed backup prevents library replacement")
	var restored = Manager.new()
	check(restored.load_json(library) and restored.notes == ["keep this note"], "Failed library write keeps the old notes readable")
	DirAccess.remove_absolute(library + ".bak")
	check(manager.save_json(library), "Library replacement succeeds after storage is available")
	write_text(library, "{broken library")
	check(restored.load_json(library) and restored.notes == ["keep this note"], "Library can recover from its own backup")
	for path in DirAccess.get_files_at(directory):
		DirAccess.remove_absolute(directory + "/" + path)
	DirAccess.remove_absolute(directory)
	print("SAVE_RECOVERY_INTEGRITY_PASS: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

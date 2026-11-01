extends SceneTree

func _initialize() -> void:
	var Save = load("res://scripts/system/SaveSystem.gd")
	var Settings = load("res://scripts/system/SettingsSystem.gd")
	var suffix := "%d_%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	var save = Save.new("user://save_smoke_" + suffix + ".json")
	var settings_path := "user://settings_smoke_" + suffix + ".json"
	var settings = Settings.new(settings_path)
	var payload := {"player": {"position": Vector3(4, 5, 6), "slot": 3}, "version": 1}
	assert(save.save_game(payload))
	var loaded: Dictionary = save.load_game()
	assert(loaded.player.position == Vector3(4, 5, 6) and loaded.player.slot == 3)
	settings.set_value("fullscreen", true)
	assert(settings.save())
	var other = Settings.new(settings_path)
	other.load_settings()
	assert(other.get_value("fullscreen") == true)
	save.delete_save()
	DirAccess.remove_absolute(settings_path)
	print("SAVE_SETTINGS_SMOKE_PASS: JSON vector save/load and settings persistence")
	quit(0)

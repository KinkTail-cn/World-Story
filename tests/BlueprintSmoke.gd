extends SceneTree

const BlueprintManagerScript = preload("res://scripts/blueprint/BlueprintManager.gd")

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var manager = BlueprintManagerScript.new()
	var created: Dictionary = manager.create_blueprint("测试蓝图", "武器", 8)
	assert(created.category == "武器" and created.grid_size == 8)
	assert(manager.set_cell(0, 3) and manager.set_cell(9, 2))
	var saved: Dictionary = manager.save_current()
	assert(saved.cells[0] == 3 and manager.blueprints.size() == 1)
	var path := "user://blueprint_smoke.json"
	assert(manager.save_json(path))
	var loaded = BlueprintManagerScript.new()
	assert(loaded.load_json(path) and loaded.blueprints.size() == 1)
	assert(loaded.blueprints[0].category == "武器")
	var workshop = load("res://scenes/BlueprintWorkshop.tscn").instantiate()
	root.add_child(workshop)
	var notebook = load("res://scenes/NotebookPanel.tscn").instantiate()
	root.add_child(notebook)
	await process_frame
	workshop.open(loaded)
	assert(workshop.visible)
	workshop.close()
	notebook.open(loaded)
	assert(notebook.visible)
	notebook.close()
	assert(loaded.save_note("蓝图草稿") == "蓝图草稿" and loaded.notes.size() == 1)
	workshop.queue_free()
	notebook.queue_free()
	print("BLUEPRINT_SMOKE_PASS: manager roundtrip, workshop open/close, notebook save")
	quit(0)

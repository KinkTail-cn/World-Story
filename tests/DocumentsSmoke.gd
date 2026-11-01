extends SceneTree

const Save = preload("res://scripts/system/SaveSystem.gd")
const Inventory = preload("res://scripts/inventory/Inventory.gd")

func _initialize() -> void:
	create_timer(25.0).timeout.connect(func(): push_error("DOCUMENTS_SMOKE_TIMEOUT"); quit(1))
	_run.call_deferred()

func _run() -> void:
	var menu = load("res://scenes/MainMenu.tscn").instantiate()
	root.add_child(menu)
	await process_frame
	var chosen := {"mode": "", "count": 0}
	menu.new_game.connect(func(mode: String): chosen.mode = mode; chosen.count += 1)
	menu.get_node("Center/Card/Body/Buttons/NewGame").pressed.emit()
	assert(menu.mode_popup.visible and chosen.count == 0, "New game must open a popup without creating a world")
	menu.get_node("ModePopup/Card/Body/Cancel").pressed.emit()
	assert(not menu.mode_popup.visible and chosen.count == 0)
	menu._open_mode_popup()
	menu.mode_box.select(1)
	menu.get_node("ModePopup/Card/Body/Start").pressed.emit()
	assert(chosen.mode == "survival" and chosen.count == 1 and not menu.mode_popup.visible)
	menu.queue_free()
	await process_frame
	var game = load("res://scenes/Main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	for frame in range(90):
		await physics_frame
	assert(game.inventory.bag[8].id == 108 and game.inventory.bag[9].id == 109)
	assert(game.inventory.move_item("bag", 8, "bag", 0))
	assert(game.player.visual.held_item.document_visual != null, "Documents must have a held model")
	game.player.target_cell = Vector3i(18, 4, 21)
	game.player.target_id = 1
	game.player.target_normal = Vector3i.UP
	game.player._place()
	assert(game.world.documents.size() == 1 and game.inventory.bag[0].count == -1)
	var notebook = game.world.documents[0]
	game._open_document(notebook)
	assert(paused and game.hud.notebook_panel.visible)
	game.hud.notebook_panel.editor.text = "这本笔记只属于第一本纸笔。"
	game.hud.notebook_panel._save_note()
	game.hud.notebook_panel.get_node("Card/Body/Actions/Close").pressed.emit()
	assert(not paused and not game.hud.notebook_panel.visible)
	var second = game.world.place_document(Vector3i(19, 4, 21), 108)
	assert(second != null and second.contents.notes.is_empty(), "Two notebooks must have independent contents")
	var blueprint = game.world.place_document(Vector3i(20, 4, 21), 109)
	game._open_document(blueprint)
	assert(paused and game.hud.blueprint_workshop.visible)
	game.hud.blueprint_workshop._set_cell(0, 3)
	game.hud.blueprint_workshop.name_edit.text = "第一张蓝图"
	game.hud.blueprint_workshop._save_pressed()
	game._input(_action("pause"))
	assert(not paused and not game.hud.blueprint_workshop.visible)
	assert(not game.world.set_block(notebook.support_cell, 0), "A document support must not be removed")
	assert(game.world.place_document(notebook.support_cell, 109) == null, "Cannot overlap placed documents")
	var save = Save.new()
	save.save_path = "user://document_smoke_isolated.json"
	var data := {"mode": game.inventory.mode, "player": save.save_player(game.player), "world": game.world.save_data()}
	assert(save.save_game(data))
	var recovered: Dictionary = save.load_game()
	game.world.load_data(recovered.world)
	var inv = Inventory.new("survival")
	save.apply_inventory(inv, recovered.player.inventory)
	assert(inv.bag[0].id == 108 and inv.is_creative())
	assert(game.world.documents[0].contents.notes.size() == 1 and game.world.documents[1].contents.notes.is_empty())
	assert(game.world.documents[2].contents.blueprints[0].voxels.size() > 0 and game.world.documents[2].contents.blueprints[0].voxels[0].mat == 3)
	assert(save.delete_save())
	var survival = Inventory.new("survival")
	assert(survival.add_item(108, 1))
	game.player.inventory = survival
	game.player.select_slot(0)
	game.player.target_document = null
	game.player.target_cell = Vector3i(21, 4, 21)
	game.player.target_id = 1
	game.player.target_normal = Vector3i.UP
	game.player._place()
	assert(survival.bag[0].id == 0 and game.world.documents.size() == 4, "Survival document placement must consume the item")
	
	# 核心测试：蓝图（ID 109）在生存模式下放置与左键挖掘正常掉落回收
	assert(survival.add_item(109, 1), "向生存背包添加蓝图失败")
	game.player.select_slot(0)
	assert(survival.bag[0].id == 109 and survival.bag[0].count == 1)
	game.player.target_document = null
	game.player.target_cell = Vector3i(22, 4, 21)
	game.player.target_id = 1
	game.player.target_normal = Vector3i.UP
	game.player._place()
	assert(survival.bag[0].id == 0 and game.world.documents.size() == 5, "生存模式下放置蓝图应消耗背包图纸")
	
	var placed_blueprint = game.world.documents[game.world.documents.size() - 1]
	assert(placed_blueprint.item_id == 109, "新放置的实体不是蓝图")
	assert(placed_blueprint.support_cell == Vector3i(22, 4, 21))
	
	# 模拟玩家瞄准该蓝图并左键挖掘
	game.player.target_document = placed_blueprint
	game.player.target_cell = placed_blueprint.support_cell
	game.player._mine()
	
	# 验证蓝图从世界移除，且正常掉落回收到背包
	assert(game.world.documents.size() == 4, "蓝图左键挖掘后未从世界移除")
	assert(survival.bag[0].id == 109 and survival.bag[0].count == 1, "蓝图左键挖掘后未能正常掉落回收到背包")
	
	# 验证蓝图移除后，原本受保护的支撑方块现在可以正常破坏
	assert(game.world.set_block(Vector3i(22, 4, 21), 0), "蓝图回收后底部的支撑方块应可正常破坏")

	# 核心测试：保存了东西并且敲碎后的图纸必须单独一个格子存放
	# 1. 再次放置这张空白蓝图
	game.player.select_slot(0)
	game.player.target_document = null
	game.player.target_cell = Vector3i(23, 4, 21)
	if game.world.get_block(Vector3i(23, 4, 21)) == 0:
		game.world.set_block(Vector3i(23, 4, 21), 1)
	game.player.target_id = 1
	game.player.target_normal = Vector3i.UP
	game.player._place()
	assert(survival.bag[0].id == 0, "放置后第0格清空")
	
	# 2. 获取实体并在其中绘制并保存一份蓝图
	var bp_doc = game.world.documents[game.world.documents.size() - 1]
	bp_doc.contents.create_blueprint("专属神武战甲", "盔甲", 8)
	bp_doc.contents.current.add_voxel(Vector3i(0, 1, 0), 2, "盔甲")
	bp_doc.contents.save_current()
	assert(bp_doc.contents.blueprints.size() == 1, "蓝图实体未能成功保存设计数据")
	
	# 3. 再向背包第0格放入一张普通空白蓝图
	assert(survival.add_item(109, 1))
	assert(survival.bag[0].id == 109 and survival.bag[0].count == 1 and not survival.is_unique_blueprint(survival.bag[0]), "第0格应为普通空白图纸")
	
	# 4. 模拟左键挖掘敲碎该保存了东西的蓝图
	game.player.target_document = bp_doc
	game.player.target_cell = bp_doc.support_cell
	game.player._mine()
	
	# 5. 严格断言：
	# 第0格依然保持为普通空白图纸（未被合并！），而敲碎后的专属图纸单独存放在第1格！
	assert(survival.bag[0].id == 109 and not survival.is_unique_blueprint(survival.bag[0]), "第0格普通图纸不应被覆盖或合入")
	assert(survival.bag[1].id == 109 and survival.is_unique_blueprint(survival.bag[1]), "保存了东西的图纸必须单独占用一个新格子存放")
	assert(survival.bag[1].custom_name == "蓝图: 专属神武战甲", "专属图纸未能正确记录自定义蓝图名称")
	assert(survival.bag[1].blueprints.size() == 1, "专属图纸未能携带保存的蓝图数据")
	
	# 6. 验证把该专属图纸放置到世界后，设计数据完整恢复
	game.player.select_slot(1)
	game.player.target_document = null
	game.player.target_cell = Vector3i(24, 4, 21)
	if game.world.get_block(Vector3i(24, 4, 21)) == 0:
		game.world.set_block(Vector3i(24, 4, 21), 1)
	game.player.target_id = 1
	game.player.target_normal = Vector3i.UP
	game.player._place()
	assert(survival.bag[1].id == 0, "放置后该专属格子被正常消耗清空")
	
	var restored_doc = game.world.documents[game.world.documents.size() - 1]
	assert(restored_doc.contents.blueprints.size() == 1, "重新放置的蓝图未能还原保存的蓝图列表")
	assert(restored_doc.contents.blueprints[0].name == "专属神武战甲", "重新放置的蓝图还原名称错误")
	var restored_cell: Vector3i = restored_doc.support_cell
	game.world.load_data(game.world.save_data())
	var named_document = null
	for document in game.world.documents:
		if document.support_cell == restored_cell:
			named_document = document
	assert(named_document != null and named_document.inventory_name() == "蓝图: 专属神武战甲", "纸笔实体存档必须保留自定义名称")
	print("✓ 保存了东西并且碎后的图纸单独格子存放及还原测试通过")
	
	game.player.inventory = game.inventory
	game.player.select_slot(0)
	game.player.position = Vector3(17.5, 5.01, 23.0)
	game.player.rig.rotation = Vector3.ZERO
	game.player.pitch.rotation.x = -0.55
	for frame in range(8):
		await physics_frame
	if "--capture" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("C:/Users/Qi/AppData/Local/Temp/opencode/world-story-documents.png")
	print("DOCUMENTS_SMOKE_PASS: new-game popup, cancel/confirm, paper inventory, held/placed models, independent notes/blueprints, modal exit, save/load, survival consumption")
	quit(0)

func _action(name: String) -> InputEventAction:
	var event := InputEventAction.new()
	event.action = name
	event.pressed = true
	return event

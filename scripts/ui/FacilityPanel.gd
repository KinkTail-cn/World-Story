extends Control

signal closed
signal blueprint_requested
signal crafting_requested
const UI = preload("res://scripts/ui/UIStyle.gd")
const Layout = preload("res://scripts/ui/ResponsiveLayout.gd")
const Items = preload("res://scripts/content/VillageItems.gd")
const Catalog = preload("res://scripts/inventory/ItemCatalog.gd")
var life: Node
var inventory: RefCounted
var player: Node3D
var key: String = ""
var card: PanelContainer
var body: VBoxContainer
var title: Label
var status: Label
var detail: Label
var bag_list: ItemList
var contents: ItemList
var input_choice: OptionButton
var fuel_choice: OptionButton
var refresh_time: float = 0.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	theme = UI.theme(false)
	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = UI.SHADE
	add_child(dim)
	card = PanelContainer.new()
	card.name = "Card"
	card.custom_minimum_size.x = 820
	UI.panel(card, false, Vector2(28, 24))
	add_child(card)
	card.minimum_size_changed.connect(_layout.call_deferred)
	body = VBoxContainer.new()
	body.add_theme_constant_override("separation", 12)
	card.add_child(body)
	var header := HBoxContainer.new()
	body.add_child(header)
	title = Label.new()
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UI.label(title, 26, UI.INK, true)
	header.add_child(title)
	var close := Button.new()
	close.text = "关闭  Esc"
	close.pressed.connect(close_panel)
	header.add_child(close)
	status = Label.new()
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UI.label(status, 14, UI.TEAL)
	body.add_child(status)
	resized.connect(_layout)
	visible = false

func _layout() -> void:
	if card != null: Layout.fit_centered(card, size, Vector2(820, 0), 22)

func open_for(value: String, service: Node, model: RefCounted, actor: Node3D) -> void:
	life = service
	inventory = model
	player = actor
	key = value
	life.active_interaction = key
	life.interacting_actor = actor
	for child in body.get_children().slice(1):
		body.remove_child(child)
		if child != status: child.queue_free()
	bag_list = null
	contents = null
	input_choice = null
	fuel_choice = null
	var record: Dictionary = life.records.get(key, {"kind": "workbench", "item": {"id": 509}})
	var kind := str(record.kind)
	title.text = {"farmer": "农夫", "smith": "铁匠", "trader": "行商", "keeper": "仓房管理员"}.get(str(record.get("role", "")), Catalog.title(int(record.get("item", {}).get("id", 509))))
	detail = Label.new()
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UI.label(detail, 14, UI.MUTED)
	body.add_child(detail)
	if kind == "workbench":
		detail.text = "设计自己的装备、工具、武器和生活设施，或从配方制作基础物品。"
		_add_button("蓝图设计与制作", func(): blueprint_requested.emit(), true)
		_add_button("基础配方与合成", func(): crafting_requested.emit())
	elif kind in ["chest", "barrel", "furnace"]:
		_storage_layout(kind == "furnace")
		if kind == "furnace":
			var choices := HBoxContainer.new()
			body.add_child(choices)
			input_choice = OptionButton.new()
			fuel_choice = OptionButton.new()
			for id in Items.SMELTING: input_choice.add_item(Catalog.title(id), id)
			for id in Items.FUELS: fuel_choice.add_item(Catalog.title(id), id)
			for choice in [input_choice, fuel_choice]:
				choice.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				choices.add_child(choice)
			_add_button("加入一份原料", func(): _act("smelt", input_choice.get_selected_id()), true)
			_add_button("加入一份燃料", func(): _act("fuel", fuel_choice.get_selected_id()))
			_add_button("取回待加工原料", func(): _act("return_input"))
	elif kind == "crop":
		_add_button("播种  ·  小麦种子 ×1", func(): _act("plant"), true)
		_add_button("用水桶浇灌", func(): _act("water"))
		_add_button("收获小麦与种子", func(): _act("harvest"), true)
		_add_button("清理作物并取回种子", func(): _act("clear_crop"))
	elif kind == "bed":
		detail.text = "休息可恢复生命，并把床边的安全地面设为返回位置。"
		_add_button("休息并设置返回点", func(): _act("rest"), true)
	elif kind == "chair":
		detail.text = "坐下休息。按 F、空格或移动键可以起身。"
		_add_button("坐下", func():
			var result: Dictionary = _act("sit")
			if result.ok: close_panel()
		, true)
	elif kind == "lamp":
		_add_button("切换照明开关", func(): _act("lamp"), true)
	elif kind == "well":
		detail.text = "使用空木桶取水，带到种植箱浇灌。"
		_add_button("取水  ·  空木桶 ×1", func(): _act("draw_water"), true)
	elif kind == "resident":
		detail.text = "使用材料交换物品，每项交易有独立库存，稍后会补货。"
		contents = ItemList.new()
		contents.custom_minimum_size = Vector2(0, 220)
		body.add_child(contents)
		_add_button("交换所选物品", func():
			var selected := contents.get_selected_items()
			if not selected.is_empty(): _act("trade", selected[0])
		, true)
	body.add_child(status)
	status.text = life.last_message
	life.last_message = ""
	visible = true
	_refresh()
	_layout.call_deferred()
	UI.reveal(card)

func _storage_layout(furnace: bool) -> void:
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 16)
	body.add_child(columns)
	for side in range(2):
		var column := VBoxContainer.new()
		column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		columns.add_child(column)
		var heading := Label.new()
		heading.text = "背包物品" if side == 0 else ("加工成品" if furnace else "容器内容")
		column.add_child(heading)
		var list := ItemList.new()
		list.custom_minimum_size = Vector2(300, 200 if furnace else 280)
		column.add_child(list)
		var button := Button.new()
		column.add_child(button)
		if side == 0:
			bag_list = list
			button.text = "存入所选一格"
			button.visible = not furnace
			button.pressed.connect(func():
				var selected := bag_list.get_selected_items()
				if not selected.is_empty(): _result(life.deposit(key, inventory, int(bag_list.get_item_metadata(selected[0]))))
			)
		else:
			contents = list
			button.text = "取出所选物品"
			button.pressed.connect(func():
				var selected := contents.get_selected_items()
				if not selected.is_empty(): _result(life.withdraw(key, inventory, int(contents.get_item_metadata(selected[0])), furnace))
			)

func _add_button(text: String, callback: Callable, primary: bool = false) -> void:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = 42
	body.add_child(button)
	UI.button(button, "primary" if primary else "secondary", true)
	button.pressed.connect(callback)

func _act(action: String, value: int = 0) -> Dictionary:
	var result: Dictionary = life.act(key, action, inventory, player, value)
	_result(result)
	return result

func _result(result: Dictionary) -> void:
	status.text = str(result.message)
	life.last_message = ""
	status.add_theme_color_override("font_color", UI.TEAL if result.ok else Color("aa5144"))
	_refresh()

func _rows(list: ItemList, rows: Array) -> void:
	if list == null: return
	var signature := str(rows)
	if list.get_meta("rows", "") == signature: return
	list.set_meta("rows", signature)
	var selected := list.get_selected_items()
	var previous: Variant = list.get_item_metadata(selected[0]) if not selected.is_empty() else -1
	list.clear()
	for row in rows:
		var index := list.add_item(row.text)
		list.set_item_metadata(index, row.id)
		if row.id == previous: list.select(index)

func _refresh() -> void:
	if life == null: return
	var record: Dictionary = life.records.get(key, {})
	if record.is_empty(): return
	life._simulate(record)
	if bag_list != null:
		var rows: Array = []
		for index in inventory.bag.size():
			var item: Dictionary = inventory.bag[index]
			if item.id != 0: rows.append({"id": index, "text": "%02d  %s ×%s" % [index + 1, str(item.get("custom_name", Catalog.title(item.id))), "∞" if item.count == -1 else str(item.count)]})
		_rows(bag_list, rows)
	if record.kind in ["chest", "barrel", "furnace"]:
		var rows: Array = []
		var slots: Array = record.output if record.kind == "furnace" else record.storage
		for index in slots.size(): rows.append({"id": index, "text": "%s ×%d" % [str(slots[index].get("custom_name", Catalog.title(slots[index].id))), slots[index].count]})
		_rows(contents, rows)
		detail.text = "使用 %d / %d 格。自定义成品与图纸内容会完整保留。" % [slots.size(), 24 if record.kind == "chest" else 12]
		if record.kind == "furnace":
			var queued := 0
			for amount in record.input.values(): queued += int(amount)
			var job: Dictionary = record.get("current", {})
			detail.text = "待加工 %d 份 · 燃料余量 %d 次%s" % [queued, record.fuel, " · 距完成 %.1f 秒" % maxf(0, float(job.due) - life.clock) if not job.is_empty() else " · 等待原料或燃料"]
	elif record.kind == "crop":
		detail.text = ["空种植箱，可以播种", "幼苗正在生长", "小麦即将成熟", "小麦成熟，可以收获"][clampi(record.growth_stage, 0, 3)] + (" · 已浇水" if record.watered else " · 浇水可加快生长")
	elif record.kind == "lamp": detail.text = "灯光已开启" if record.lit else "灯光已关闭"
	elif record.kind == "resident":
		var rows: Array = []
		var offers: Array = life.trades(record.role)
		for index in offers.size():
			var cost := PackedStringArray()
			for id in offers[index].cost: cost.append("%s×%d" % [Catalog.title(int(id)), offers[index].cost[id]])
			rows.append({"id": index, "text": "%s → %s×%d   余量 %d" % [" + ".join(cost), Catalog.title(offers[index].item.id), offers[index].item.count, 8 - int(record.stock.get(str(index), 0))]})
		_rows(contents, rows)

func _process(delta: float) -> void:
	if not visible: return
	refresh_time -= delta
	if refresh_time <= 0:
		refresh_time = 0.3
		_refresh()

func close_panel() -> void:
	if life != null:
		life.active_interaction = ""
		life.interacting_actor = null
	hide()
	closed.emit()

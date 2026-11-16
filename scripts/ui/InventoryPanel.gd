extends Control

signal close_requested
signal item_used(id: int)
signal slot_requested(index: int)

const SlotScript = preload("res://scripts/ui/InventorySlot.gd")
const SlotScene = preload("res://scenes/InventorySlot.tscn")
const CreativeSlotScript = preload("res://scripts/ui/CreativeSlot.gd")
const ItemCatalog = preload("res://scripts/inventory/ItemCatalog.gd")
const ItemTooltip = preload("res://scripts/ui/ItemTooltip.gd")
const Character = preload("res://scripts/player/CharacterVisual.gd")
const EquipmentSets = preload("res://scripts/content/EquipmentSets.gd")
const CARD_SIZE := Vector2(1320, 780)
const BLOCKS_LIST: Array[int] = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20]
const EQUIP_LIST: Array[int] = EquipmentSets.ALL_IDS
const TOOLS_LIST: Array[int] = [201, 202, 203, 204, 205, 206, 207, 208, 209]
const WEAPONS_LIST: Array[int] = [301, 302, 303, 304, 305]
const DOCS_LIST: Array[int] = [108, 109]

var model: RefCounted
var slots: Array[Control] = []
var bag_slots: Array[Control] = []
var selected_hotbar: int = 0
var is_creative_view: bool = true
var current_category: String = "all"
var _category_buttons: Dictionary = {}
var _populated_key: String = ""
var _populated_model: RefCounted
var _hovered_slot: Control
var _feedback_time: float = 0.0
var preview_character: Node3D
var preview_viewport: SubViewport
var preview_camera: Camera3D

@onready var card: Panel = $Card
@onready var close_button: Button = %CloseButton
@onready var tab_creative: Button = %TabCreative
@onready var tab_crafting: Button = %TabCrafting
@onready var equipment_grid: GridContainer = %Equipment
@onready var bag_grid: GridContainer = %Bag
@onready var hotbar_grid: GridContainer = %Hotbar
@onready var bag_scroll: ScrollContainer = %StorageScroll
@onready var creative_section: VBoxContainer = %CreativeSection
@onready var creative_grid: GridContainer = %CreativeGrid
@onready var craft_section: VBoxContainer = %CraftSection
@onready var crafting_box: HBoxContainer = %Crafting
@onready var recipe_label: Label = %Recipe
@onready var result_slot: Control = %Output
@onready var search: LineEdit = %Search
@onready var recipe_search: LineEdit = %RecipeSearch
@onready var recipe_list: ItemList = %RecipeList
@onready var feedback: Label = %Feedback
@onready var equipment_style: OptionButton = %EquipmentStyle
@onready var wear_set: Button = %WearSet

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_collect_slots(self)
	_reindex_bag()
	close_button.pressed.connect(func(): close_requested.emit())
	tab_creative.pressed.connect(func(): _set_creative_view(true))
	tab_crafting.pressed.connect(func(): _set_creative_view(false))
	search.text_changed.connect(func(_text: String): _populate_creative_items())
	recipe_search.text_changed.connect(func(_text: String): _build_recipes())
	%Sort.pressed.connect(func(): model.sort_storage(); show_feedback("已整理储物格，快捷栏顺序已保留"))
	%ReturnMaterials.pressed.connect(_return_materials)
	%TakeResult.pressed.connect(_take_result)
	recipe_list.item_selected.connect(_choose_recipe)
	equipment_style.add_item("所有装备风格")
	equipment_style.set_item_metadata(0, "")
	for key in EquipmentSets.STARTS:
		var index := equipment_style.item_count
		equipment_style.add_item(str(EquipmentSets.TITLES[key]))
		equipment_style.set_item_metadata(index, key)
	equipment_style.item_selected.connect(func(_index: int): _update_set_button(); _populate_creative_items())
	wear_set.pressed.connect(_wear_set)
	var categories := ["all", "blocks", "equipment", "tools", "weapons", "docs"]
	var buttons := %CategoryBar.get_children()
	for i in categories.size():
		var key: String = categories[i]
		_category_buttons[key] = buttons[i]
		buttons[i].pressed.connect(_select_category.bind(key))
	buttons[0].text = "全部 %d" % (BLOCKS_LIST.size() + EQUIP_LIST.size() + TOOLS_LIST.size() + WEAPONS_LIST.size() + DOCS_LIST.size())
	buttons[2].text = "装备 %d" % EQUIP_LIST.size()
	resized.connect(_layout_card)
	_setup_preview()
	_layout_card()
	visibility_changed.connect(func():
		if preview_viewport != null:
			preview_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS if visible else SubViewport.UPDATE_DISABLED
	)

func _layout_card() -> void:
	if card == null:
		return
	var available := size if size.x > 1.0 and size.y > 1.0 else get_viewport_rect().size
	var fit := minf(1.0, minf((available.x - 32.0) / CARD_SIZE.x, (available.y - 32.0) / CARD_SIZE.y))
	card.size = CARD_SIZE
	card.scale = Vector2.ONE * maxf(0.1, fit)
	card.position = (available - CARD_SIZE * card.scale) * 0.5

func _collect_slots(node: Node) -> void:
	for child in node.get_children():
		if child is Control and child.get_script() == SlotScript:
			slots.append(child)
			_wire_slot(child)
		_collect_slots(child)

func _wire_slot(slot: Control) -> void:
	slot.item_focused.connect(func(item: Dictionary): _show_item(item); _hovered_slot = slot)
	slot.mouse_exited.connect(func():
		if _hovered_slot == slot:
			_hovered_slot = null
	)
	slot.quick_move_requested.connect(func(group: String, index: int):
		show_feedback("已快速移动物品" if model.quick_move(group, index) else "没有可用空格或可移动的物品")
	)
	slot.slot_selected.connect(func(index: int): select_hotbar(index); slot_requested.emit(index))

func _reindex_bag() -> void:
	bag_slots.clear()
	bag_slots.append_array(hotbar_grid.get_children())
	bag_slots.append_array(bag_grid.get_children())

func get_bag_slot(index: int) -> Control:
	return bag_slots[index] if index >= 0 and index < bag_slots.size() else null

func bind_inventory(value: RefCounted) -> void:
	if model != null and model.changed.is_connected(_refresh):
		model.changed.disconnect(_refresh)
	var different := model != value
	model = value
	if model != null:
		model.changed.connect(_refresh)
		if different:
			is_creative_view = model.is_creative()
			_build_recipes()
	_refresh()

func open() -> void:
	visible = true
	_layout_card()
	_refresh()

func close() -> void:
	search.release_focus()
	recipe_search.release_focus()
	ItemTooltip.hide_card()
	_hovered_slot = null
	visible = false

func is_editing_text() -> bool:
	return visible and (search.has_focus() or recipe_search.has_focus())

func select_hotbar(index: int) -> void:
	selected_hotbar = clampi(index, 0, 7)
	for slot in hotbar_grid.get_children():
		slot.selected_hotbar = slot.index == selected_hotbar
		slot.queue_redraw()
	for slot in creative_grid.get_children():
		slot.target_hotbar = selected_hotbar

func _set_creative_view(show_creative: bool) -> void:
	is_creative_view = show_creative and model != null and model.is_creative()
	search.release_focus()
	recipe_search.release_focus()
	ItemTooltip.hide_card()
	_update_view_visibility()

func _select_category(category: String) -> void:
	current_category = category
	_update_set_button()
	_populate_creative_items()
	_update_category_buttons()

func _update_view_visibility() -> void:
	var creative: bool = model != null and model.is_creative()
	tab_creative.visible = creative
	creative_section.visible = creative and is_creative_view
	craft_section.visible = not creative_section.visible
	var normal: StyleBox = theme.get_stylebox("normal", "Button")
	var active: StyleBox = theme.get_stylebox("pressed", "Button")
	tab_creative.add_theme_stylebox_override("normal", active if creative_section.visible else normal)
	tab_crafting.add_theme_stylebox_override("normal", active if craft_section.visible else normal)
	if creative_section.visible:
		_populate_creative_items()
	_update_set_button()

func _update_set_button() -> void:
	%EquipmentStyleRow.visible = current_category == "equipment"
	wear_set.disabled = model == null or not model.is_creative() or _style_key().is_empty()

func _style_key() -> String:
	return str(equipment_style.get_item_metadata(equipment_style.selected)) if equipment_style.selected >= 0 else ""

func _wear_set() -> void:
	var key := _style_key()
	if model != null and model.equip_creative_set(EquipmentSets.ids(key)):
		show_feedback("已穿戴：" + str(EquipmentSets.TITLES[key]) + " · 原装备已放入背包")

func _update_category_buttons() -> void:
	for key in _category_buttons:
		var button: Button = _category_buttons[key]
		button.add_theme_stylebox_override("normal", theme.get_stylebox("pressed" if key == current_category else "normal", "Button"))

func _populate_creative_items() -> void:
	var selected_style := _style_key() if current_category == "equipment" else ""
	var key := current_category + ":" + selected_style + ":" + search.text.strip_edges().to_lower()
	if key == _populated_key and model == _populated_model:
		return
	_populated_key = key
	_populated_model = model
	for child in creative_grid.get_children():
		creative_grid.remove_child(child)
		child.queue_free()
	_hovered_slot = null
	var items: Array[int] = []
	match current_category:
		"blocks": items = BLOCKS_LIST.duplicate()
		"equipment": items = EQUIP_LIST.duplicate()
		"tools": items = TOOLS_LIST.duplicate()
		"weapons": items = WEAPONS_LIST.duplicate()
		"docs": items = DOCS_LIST.duplicate()
		_:
			for list in [BLOCKS_LIST, EQUIP_LIST, TOOLS_LIST, WEAPONS_LIST, DOCS_LIST]:
				items.append_array(list)
	var term := search.text.strip_edges().to_lower()
	for id in items:
		if not selected_style.is_empty() and EquipmentSets.style(id) != selected_style:
			continue
		if not term.is_empty() and not ItemCatalog.title(id).to_lower().contains(term):
			continue
		var slot = CreativeSlotScript.new()
		creative_grid.add_child(slot)
		slot.target_hotbar = selected_hotbar
		slot.set_item(id, model)
		slot.item_focused.connect(_show_item)
		slot.selected.connect(func(item_id: int): show_feedback("已领取：" + ItemCatalog.title(item_id)))
		slot.quick_equipped.connect(func(item_id: int): show_feedback("已穿戴装备" if ItemCatalog.is_equipment(item_id) else "已放入快捷格 " + str(selected_hotbar + 1)); slot_requested.emit(selected_hotbar))
	%CatalogCount.text = "找到 %d 件物品" % creative_grid.get_child_count()
	%EmptySearch.visible = creative_grid.get_child_count() == 0
	%CatalogScroll.scroll_vertical = 0

func _build_recipes() -> void:
	recipe_list.clear()
	var recipes: Dictionary = model.recipe_definitions()
	var term := recipe_search.text.strip_edges()
	for key in recipes:
		var recipe: Dictionary = recipes[key]
		var ingredients := PackedStringArray()
		for id in str(key).split(","):
			ingredients.append(ItemCatalog.title(int(id)))
		var title := ItemCatalog.title(recipe.id) + " ×" + str(recipe.count) + "    ← " + " + ".join(ingredients)
		if not term.is_empty() and not title.contains(term):
			continue
		var index := recipe_list.add_item(title)
		recipe_list.set_item_metadata(index, key)
		recipe_list.set_item_tooltip(index, "点击自动放入材料；生存模式需要背包里有对应材料。")

func _choose_recipe(index: int) -> void:
	var key := str(recipe_list.get_item_metadata(index))
	if model.prepare_recipe(key):
		show_feedback("材料已放入，点击成品或“领取成品”完成合成")
	else:
		show_feedback("材料不足，或背包没有空间取回原材料")

func _return_materials() -> void:
	show_feedback("材料已全部取回" if model.clear_crafting() else "背包空间不足，材料保留在合成台")

func _take_result() -> void:
	show_feedback("合成成功，成品已放入背包" if model.take_result() else "背包没有足够空间领取成品")

func _show_item(item: Dictionary) -> void:
	if int(item.get("id", 0)) == 0:
		return
	%ItemName.text = str(item.get("custom_name", ItemCatalog.title(item.id))) + "  ·  " + ItemCatalog.item_category(item.id)
	%ItemHint.text = ItemCatalog.description(item.id)

func show_feedback(text: String) -> void:
	feedback.text = text
	_feedback_time = 5.0

func _process(delta: float) -> void:
	if not visible:
		return
	if _feedback_time > 0.0:
		_feedback_time = maxf(0.0, _feedback_time - delta)
		if _feedback_time == 0.0:
			feedback.text = "拖动交换 · 右键穿戴 · Shift + 点击快速移动"

func _unhandled_key_input(event: InputEvent) -> void:
	if not visible or is_editing_text() or not event.is_pressed() or event.is_echo():
		return
	if event is InputEventKey and event.ctrl_pressed and event.keycode == KEY_F:
		(search if creative_section.visible else recipe_search).grab_focus()
		get_viewport().set_input_as_handled()
		return
	if not is_instance_valid(_hovered_slot) or _hovered_slot.group != "bag":
		return
	for index in range(8):
		if event.is_action_pressed("slot_%d" % (index + 1)):
			if model.move_item("bag", _hovered_slot.index, "bag", index):
				select_hotbar(index)
				slot_requested.emit(index)
				show_feedback("已放入快捷格 " + str(index + 1))
			get_viewport().set_input_as_handled()

func _refresh() -> void:
	if model == null:
		return
	while bag_slots.size() > model.bag.size():
		var removed: Control = bag_slots.pop_back()
		slots.erase(removed)
		bag_grid.remove_child(removed)
		removed.queue_free()
	var previous_size := bag_slots.size()
	while bag_slots.size() < model.bag.size():
		var slot = SlotScene.instantiate()
		slot.index = bag_slots.size()
		bag_grid.add_child(slot)
		bag_slots.append(slot)
		slots.append(slot)
		_wire_slot(slot)
	if model.bag.size() > previous_size:
		bag_scroll.ensure_control_visible.call_deferred(bag_slots.back())
	for slot in slots:
		slot.bind_inventory(model)
	select_hotbar(selected_hotbar)
	for slot in creative_grid.get_children():
		slot.target_hotbar = selected_hotbar
	recipe_label.text = model.recipe_text()
	%TakeResult.disabled = model.get_slot("result", 0).id == 0
	%ReturnMaterials.disabled = model.crafting.all(func(item: Dictionary): return item.id == 0)
	var used := 0
	for item in model.bag:
		used += 1 if item.id != 0 else 0
	%Capacity.text = "%d / %d 格%s" % [used, model.bag.size(), " · 可扩展" if model.is_creative() else ""]
	%Mode.text = model.mode_title() + (" · 无限物品" if model.is_creative() else " · 有限资源")
	preview_character.equipment_visuals.apply_equipment(model.equipment, model.equipment_items)
	var tall_hat := EquipmentSets.style(model.equipment[0]) == "mage"
	var new_helmet := EquipmentSets.is_new(model.equipment[0])
	preview_camera.size = 2.55 if tall_hat else (2.25 if new_helmet else 2.05)
	preview_camera.look_at(Vector3(0, 1.13 if tall_hat else (1.05 if new_helmet else 0.95), 0))
	_update_view_visibility()
	_update_category_buttons()

func _setup_preview() -> void:
	preview_viewport = SubViewport.new()
	preview_viewport.own_world_3d = true
	preview_viewport.transparent_bg = true
	preview_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	%Preview.add_child(preview_viewport)
	var environment := WorldEnvironment.new()
	var settings := Environment.new()
	settings.background_mode = Environment.BG_COLOR
	settings.background_color = Color.TRANSPARENT
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color = Color("b4c4cf")
	settings.ambient_light_energy = 0.7
	environment.environment = settings
	preview_viewport.add_child(environment)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-30, -35, 0)
	light.light_energy = 1.1
	preview_viewport.add_child(light)
	preview_character = Character.new()
	preview_character.rotation.y = PI - 0.3
	preview_viewport.add_child(preview_character)
	preview_character.held_item.visible = false
	preview_camera = Camera3D.new()
	preview_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	preview_camera.size = 2.05
	preview_viewport.add_child(preview_camera)
	preview_camera.position = Vector3(0, 1.15, 3)
	preview_camera.look_at(Vector3(0, 0.95, 0))

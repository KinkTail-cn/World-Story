extends VBoxContainer

signal parameters_changed
signal action_requested(action: String)
signal flags_changed(key: String, value: bool)

const Geometry = preload("res://scripts/blueprint/BlueprintGeometry.gd")
const Materials = preload("res://scripts/blueprint/BlueprintMaterials.gd")
var refreshing: bool = false
var has_selection: bool = false
var selection_count: int = 0
var _display_anchor: String = ""
var _dirty: Dictionary = {}
var _dirty_axes: Array[int] = []
var _base_offset := Vector3.ZERO
var _source_offset: Array = [0.0, 0.0, 0.0]
var _base_edge: float = 0.13
@onready var anchor_box: OptionButton = %Anchor
@onready var surface_box: OptionButton = %Surface
@onready var tint_picker: ColorPickerButton = %Tint

func _ready() -> void:
	anchor_box.add_item("挂点：自动判断")
	for title in Geometry.ANCHOR_NAMES:
		anchor_box.add_item("挂点：" + title)
	for title in Materials.SURFACE_NAMES:
		surface_box.add_item("表面：" + title)
	surface_box.item_selected.connect(func(_index: int): _notify("surface"))
	anchor_box.item_selected.connect(func(index: int):
		if not refreshing and has_selection and index > 0 and Geometry.ORIGINS.has(_display_anchor):
			var new_anchor: String = Geometry.ANCHORS[index - 1]
			_base_offset = _edited_offset() + Vector3(Geometry.ORIGINS[_display_anchor]) - Vector3(Geometry.ORIGINS[new_anchor])
			_source_offset = Geometry.array(_base_offset)
			_dirty_axes.clear()
			refreshing = true
			_set_offset_row(_base_offset)
			refreshing = false
			_display_anchor = new_anchor
			_dirty["offset"] = true
		_notify("anchor")
	)
	%Edge.value_changed.connect(func(_value: float): _notify("dimensions"))
	for axis in range(3):
		var index: int = axis
		%Position.get_child(axis).value_changed.connect(func(_value: float):
			if not refreshing and not _dirty_axes.has(index):
				_dirty_axes.append(index)
			_notify("offset")
		)
	tint_picker.color_changed.connect(func(_color: Color): _notify("tint"))
	%PartName.text_changed.connect(func(_text: String): _notify("label"))
	%Apply.pressed.connect(func(): action_requested.emit("apply"))
	%Paint.pressed.connect(func(): action_requested.emit("paint"))
	$Actions/Duplicate.pressed.connect(func(): action_requested.emit("duplicate"))
	$Actions/Delete.pressed.connect(func(): action_requested.emit("delete"))
	%Hidden.toggled.connect(func(value: bool):
		if not refreshing:
			flags_changed.emit("hidden", value)
	)
	%Locked.toggled.connect(func(value: bool):
		if not refreshing:
			flags_changed.emit("locked", value)
	)

func _notify(key: String) -> void:
	if not refreshing:
		_dirty[key] = true
		parameters_changed.emit()

func properties() -> Dictionary:
	var edge := float(%Edge.value) if not has_selection or _dirty.has("dimensions") else _base_edge
	var result := {"shape": "box", "dimensions": Geometry.array(Vector3.ONE * edge), "tint": tint_picker.color.to_html(false), "surface": Materials.SURFACES[maxi(0, surface_box.selected)]}
	if anchor_box.selected > 0:
		result["anchor"] = Geometry.ANCHORS[anchor_box.selected - 1]
	if selection_count == 1:
		var offset := _source_offset.duplicate()
		for axis in _dirty_axes:
			offset[axis] = float(%Position.get_child(axis).value)
		result["offset"] = offset
		if not %PartName.text.strip_edges().is_empty():
			result["label"] = %PartName.text.strip_edges()
	if has_selection:
		for key in result.keys():
			if not _dirty.has(key):
				result.erase(key)
	return result

func set_values(part: Dictionary, selected_count: int = 0, category: String = "头部装备") -> void:
	refreshing = true
	_dirty.clear()
	_dirty_axes.clear()
	has_selection = selected_count > 0
	selection_count = selected_count
	%SelectionInfo.text = "已选 %d 个方块 · 属性需点击应用" % selected_count if has_selection else "放置属性 · 仅正放立方体"
	%PartName.text = str(part.get("label", "")) if has_selection else ""
	%PartName.editable = has_selection and selected_count == 1
	var bone := Geometry.anchor(part, category) if has_selection else str(part.get("anchor", ""))
	_display_anchor = bone
	anchor_box.select(Geometry.ANCHORS.find(bone) + 1)
	surface_box.select(maxi(0, Materials.SURFACES.find(str(part.get("surface", "solid")))))
	tint_picker.color = Materials.tint(part)
	_base_edge = Geometry.dimensions(part).x
	%Edge.value = _base_edge
	_base_offset = Geometry.local_transform(part, category).origin if has_selection else Vector3.ZERO
	_source_offset = part.get("offset", Geometry.array(_base_offset)).duplicate()
	_set_offset_row(_base_offset)
	%Hidden.button_pressed = bool(part.get("hidden", false)) if has_selection else false
	%Locked.button_pressed = bool(part.get("locked", false)) if has_selection else false
	%Apply.disabled = not has_selection or bool(part.get("locked", false))
	%Paint.disabled = %Apply.disabled
	$Actions/Duplicate.disabled = %Apply.disabled
	$Actions/Delete.disabled = %Apply.disabled
	%Hidden.disabled = not has_selection
	%Locked.disabled = not has_selection
	refreshing = false

func set_dimensions(extent: Vector3) -> void:
	refreshing = true
	_base_edge = extent.x
	%Edge.value = _base_edge
	if has_selection:
		_dirty["dimensions"] = true
	refreshing = false

func _edited_offset() -> Vector3:
	var result := _base_offset
	for axis in _dirty_axes:
		result[axis] = %Position.get_child(axis).value
	return result

func _set_offset_row(value: Vector3) -> void:
	for axis in range(3):
		%Position.get_child(axis).value = value[axis]

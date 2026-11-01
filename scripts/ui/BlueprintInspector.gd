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
var _dirty_axes: Dictionary = {}
var _base_vectors: Dictionary = {}
@onready var shape_box: OptionButton = %Shape
@onready var anchor_box: OptionButton = %Anchor
@onready var surface_box: OptionButton = %Surface
@onready var tint_picker: ColorPickerButton = %Tint
@onready var step_box: OptionButton = %AngleStep

func _ready() -> void:
	for title in Geometry.SHAPE_NAMES:
		shape_box.add_item(title)
	anchor_box.add_item("挂点：自动判断")
	for title in Geometry.ANCHOR_NAMES:
		anchor_box.add_item("挂点：" + title)
	for title in Materials.SURFACE_NAMES:
		surface_box.add_item("表面：" + title)
	for title in ["旋转按钮：15°", "旋转按钮：45°", "旋转按钮：90°", "旋转按钮：0.1°"]:
		step_box.add_item(title)
	for title in ["图案：无", "图案：叶形", "图案：十字", "图案：星纹"]:
		%Emblem.add_item(title)
	for box in [shape_box, surface_box, %Emblem]:
		var key: String = "shape" if box == shape_box else ("surface" if box == surface_box else "cloth")
		box.item_selected.connect(func(_index: int): _notify(key))
	anchor_box.item_selected.connect(func(index: int):
		if not refreshing and has_selection and index > 0 and Geometry.ORIGINS.has(_display_anchor):
			var new_anchor: String = Geometry.ANCHORS[index - 1]
			var offset := _edited_row("offset", %Position) + Vector3(Geometry.ORIGINS[_display_anchor]) - Vector3(Geometry.ORIGINS[new_anchor])
			_base_vectors["offset"] = offset
			_dirty_axes["offset"] = []
			refreshing = true
			_set_row(%Position, offset)
			refreshing = false
			_display_anchor = new_anchor
			_dirty["offset"] = true
		_notify("anchor")
	)
	for row in [%Dimensions, %Position, %Rotation]:
		var key: String = "dimensions" if row == %Dimensions else ("offset" if row == %Position else "rotation")
		for axis in range(3):
			var index: int = axis
			row.get_child(axis).step = 0.1 if key == "rotation" else 0.0001
			row.get_child(axis).value_changed.connect(func(_value: float):
				if not refreshing:
					if not _dirty_axes.has(key):
						_dirty_axes[key] = []
					if not _dirty_axes[key].has(index):
						_dirty_axes[key].append(index)
				_notify(key)
			)
	for color in [tint_picker, %Trim]:
		var key: String = "tint" if color == tint_picker else "cloth"
		color.color_changed.connect(func(_color: Color): _notify(key))
	%PartName.text_changed.connect(func(_text: String): _notify("label"))
	%Wind.value_changed.connect(func(_value: float): _notify("cloth"))
	%Flare.value_changed.connect(func(_value: float): _notify("cloth"))
	%AlignSurface.toggled.connect(func(_value: bool): _notify())
	%Apply.pressed.connect(func(): action_requested.emit("apply"))
	%Paint.pressed.connect(func(): action_requested.emit("paint"))
	$Actions/Duplicate.pressed.connect(func(): action_requested.emit("duplicate"))
	$Actions/Delete.pressed.connect(func(): action_requested.emit("delete"))
	for axis in ["X", "Y", "Z"]:
		get_node("Tabs/变换/RotateButtons/" + axis).pressed.connect(func(): action_requested.emit("rotate_" + axis.to_lower()))
	%Hidden.toggled.connect(func(value: bool):
		if not refreshing:
			flags_changed.emit("hidden", value)
	)
	%Locked.toggled.connect(func(value: bool):
		if not refreshing:
			flags_changed.emit("locked", value)
	)

func _notify(key: String = "") -> void:
	if not refreshing:
		if not key.is_empty():
			_dirty[key] = true
		parameters_changed.emit()

func angle_step() -> float:
	return [15.0, 45.0, 90.0, 0.1][maxi(0, step_box.selected)]

func pivot_at_anchor() -> bool:
	return %Pivot.button_pressed

func properties() -> Dictionary:
	var result := {"shape": Geometry.SHAPES[maxi(0, shape_box.selected)], "dimensions": Geometry.array(_edited_row("dimensions", %Dimensions)), "rotation": Geometry.array(_edited_row("rotation", %Rotation)), "tint": tint_picker.color.to_html(false), "surface": Materials.SURFACES[maxi(0, surface_box.selected)]}
	if result.shape == "cloth":
		result["cloth"] = {"trim": %Trim.color.to_html(false), "emblem": maxi(0, %Emblem.selected), "wind": float(%Wind.value), "flare": float(%Flare.value)}
	if anchor_box.selected > 0:
		result["anchor"] = Geometry.ANCHORS[anchor_box.selected - 1]
	if selection_count == 1:
		result["offset"] = Geometry.array(_edited_row("offset", %Position))
		if not %PartName.text.strip_edges().is_empty():
			result["label"] = %PartName.text.strip_edges()
	if has_selection:
		for key in result.keys():
			if not _dirty.has(key):
				result.erase(key)
	return result

func align_surface() -> bool:
	return %AlignSurface.button_pressed

func set_values(part: Dictionary, selected_count: int = 0, category: String = "头部装备") -> void:
	refreshing = true
	_dirty.clear()
	_dirty_axes.clear()
	has_selection = selected_count > 0
	selection_count = selected_count
	%SelectionInfo.text = "已选 %d 个部件 · 属性需点击应用" % selected_count if has_selection else "放置属性 · 修改后用于新部件"
	%PartName.text = str(part.get("label", "")) if has_selection else ""
	%PartName.editable = has_selection and selected_count == 1
	shape_box.select(maxi(0, Geometry.SHAPES.find(str(part.get("shape", "box")))))
	var bone := Geometry.anchor(part, category) if has_selection else str(part.get("anchor", ""))
	_display_anchor = bone
	anchor_box.select(Geometry.ANCHORS.find(bone) + 1)
	surface_box.select(maxi(0, Materials.SURFACES.find(str(part.get("surface", "solid")))))
	tint_picker.color = Materials.tint(part)
	_set_row(%Dimensions, Geometry.dimensions(part))
	_set_row(%Position, Geometry.local_transform(part, category).origin if has_selection else Vector3.ZERO)
	_set_row(%Rotation, Geometry.vector(part.get("rotation")))
	_base_vectors = {"dimensions": Geometry.dimensions(part), "offset": Geometry.local_transform(part, category).origin if has_selection else Vector3.ZERO, "rotation": Geometry.vector(part.get("rotation"))}
	var cloth: Dictionary = part.get("cloth", {})
	%Trim.color = Color(str(cloth.get("trim", "c3ad79")))
	%Emblem.select(int(cloth.get("emblem", 0)))
	%Wind.value = float(cloth.get("wind", 1.0))
	%Flare.value = float(cloth.get("flare", 0.06))
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
	_set_row(%Dimensions, extent)
	if has_selection:
		_base_vectors["dimensions"] = extent
		_dirty["dimensions"] = true
		_dirty_axes["dimensions"] = []
	refreshing = false

func _row(row: HBoxContainer) -> Vector3:
	return Vector3(row.get_child(0).value, row.get_child(1).value, row.get_child(2).value)

func _edited_row(key: String, row: HBoxContainer) -> Vector3:
	if not has_selection or not _base_vectors.has(key):
		return _row(row)
	var result: Vector3 = _base_vectors[key]
	for axis in _dirty_axes.get(key, []):
		result[int(axis)] = row.get_child(int(axis)).value
	return result

func _set_row(row: HBoxContainer, value: Vector3) -> void:
	for axis in range(3):
		row.get_child(axis).value = value[axis]

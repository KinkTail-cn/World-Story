extends RefCounted

# Shared player-facing palette, typography and control states.
const INK := Color("203a43")
const MUTED := Color("647b80")
const PAPER := Color("f5f3ec")
const NAVY := Color("142b34")
const SURFACE := Color("1d3741")
const LIGHT := Color("eef2ec")
const TEAL := Color("277e83")
const GOLD := Color("dfbd7d")
const ERROR := Color("d88072")
const SHADE := Color(0.025, 0.065, 0.085, 0.76)
static var _themes: Dictionary = {}
static var _icons: Dictionary = {}

static func font(weight: int = 400) -> SystemFont:
	var result := SystemFont.new()
	result.font_names = PackedStringArray(["Microsoft YaHei UI", "Microsoft YaHei", "Noto Sans CJK SC", "sans-serif"])
	result.font_weight = weight
	return result

static func box(fill: Color, border: Color = Color.TRANSPARENT, radius: int = 10, padding: Vector2 = Vector2(14, 9)) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(1 if border.a > 0.0 else 0)
	style.set_corner_radius_all(radius)
	style.content_margin_left = padding.x
	style.content_margin_right = padding.x
	style.content_margin_top = padding.y
	style.content_margin_bottom = padding.y
	return style

static func icon(kind: String, color: Color = LIGHT) -> Texture2D:
	var key := kind + color.to_html()
	if _icons.has(key):
		return _icons[key]
	var paths := {
		"arrow": '<path d="m5 8 5 5 5-5"/>',
		"check": '<path d="m5 10 3.5 3.5L15 7"/>',
		"empty": '<rect x="3" y="3" width="14" height="14" rx="4"/>',
		"checked": '<rect x="3" y="3" width="14" height="14" rx="4"/><path d="m6 10 3 3 5-6"/>',
		"knob": '<circle cx="10" cy="10" r="6" fill="#%s" stroke="none"/>' % color.to_html(false),
		"close": '<path d="m6 6 8 8m0-8-8 8"/>',
		"forward": '<path d="M4 10h12m-5-5 5 5-5 5"/>',
		"plus": '<path d="M4 10h12M10 4v12"/>',
		"heart": '<path d="M10 16 3.5 9.5C-.5 5.5 5 0 10 5c5-5 10.5.5 6.5 4.5Z"/>',
		"air": '<circle cx="9" cy="12" r="5"/><circle cx="15" cy="4" r="2"/>',
	}
	var svg := '<svg xmlns="http://www.w3.org/2000/svg" width="20" height="20" viewBox="0 0 20 20"><g fill="none" stroke="#%s" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round">%s</g></svg>' % [color.to_html(false), paths.get(kind, paths.arrow)]
	var image := Image.new()
	image.load_svg_from_string(svg)
	var texture := ImageTexture.create_from_image(image)
	_icons[key] = texture
	return texture

static func theme(dark: bool = false) -> Theme:
	if _themes.has(dark):
		return _themes[dark]
	var result := Theme.new()
	result.default_font = font()
	result.default_font_size = 15
	var text := LIGHT if dark else INK
	var muted := Color("9cb1b5") if dark else MUTED
	var base := SURFACE if dark else Color("e9ede7")
	var line := Color("3c5660") if dark else Color("cdd6cf")
	var hover := Color("2a4a55") if dark else Color("e0e9e2")
	var selected := Color("31555e") if dark else Color("d6e7df")
	var field := Color("10262f") if dark else Color("fbfcf7")
	var normal := box(base, line)
	var over := box(hover, Color("75a7a3") if dark else TEAL)
	var active := box(selected, GOLD if dark else TEAL)
	var focus := box(Color.TRANSPARENT, GOLD if dark else TEAL)
	focus.set_border_width_all(2)
	for type in ["Button", "OptionButton", "MenuButton", "CheckButton", "CheckBox", "ColorPickerButton"]:
		for state in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
			result.set_stylebox(state, type, focus if state == "focus" else (over if state.begins_with("hover") else (active if state == "pressed" else normal)))
		for state in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
			result.set_color(state, type, text)
		result.set_color("font_disabled_color", type, Color(muted, 0.48))
		result.set_constant("outline_size", type, 0)
		result.set_constant("h_separation", type, 8)
	result.set_icon("arrow", "OptionButton", icon("arrow", muted))
	result.set_constant("arrow_margin", "OptionButton", 10)
	for type in ["CheckBox", "CheckButton"]:
		result.set_icon("checked", type, icon("checked", GOLD if dark else TEAL))
		result.set_icon("unchecked", type, icon("empty", muted))
		result.set_icon("checked_disabled", type, icon("checked", muted))
		result.set_icon("unchecked_disabled", type, icon("empty", muted))
		result.set_stylebox("normal", type, box(Color.TRANSPARENT, Color.TRANSPARENT, 6, Vector2(5, 6)))
	for type in ["Label", "RichTextLabel", "ItemList", "LineEdit", "TextEdit", "PopupMenu", "TabBar"]:
		result.set_color("font_color", type, text)
		result.set_color("font_selected_color", type, text)
		result.set_color("font_placeholder_color", type, muted)
		result.set_color("font_unselected_color", type, muted)
		result.set_color("caret_color", type, GOLD if dark else TEAL)
		result.set_color("selection_color", type, Color(TEAL, 0.28))
	for type in ["LineEdit", "TextEdit", "ItemList"]:
		result.set_stylebox("normal" if type != "ItemList" else "panel", type, box(field, line, 8, Vector2(12, 9)))
		result.set_stylebox("focus", type, box(field, TEAL if not dark else Color("78a9a6"), 8, Vector2(12, 9)))
		result.set_stylebox("read_only", type, box(field, line))
	result.set_stylebox("selected", "ItemList", active)
	result.set_stylebox("selected_focus", "ItemList", active)
	result.set_stylebox("hovered", "ItemList", over)
	result.set_constant("v_separation", "ItemList", 10)
	result.set_constant("h_separation", "ItemList", 8)
	result.set_stylebox("panel", "PanelContainer", box(base, Color.TRANSPARENT, 12, Vector2(16, 16)))
	result.set_stylebox("panel", "PopupMenu", box(SURFACE if dark else PAPER, line, 10, Vector2(10, 10)))
	result.set_stylebox("hover", "PopupMenu", active)
	result.set_constant("v_separation", "PopupMenu", 14)
	for type in ["TabBar", "TabContainer"]:
		result.set_stylebox("tab_selected", type, active)
		result.set_stylebox("tab_unselected", type, normal)
		result.set_stylebox("tab_hovered", type, over)
		result.set_color("font_selected_color", type, text)
		result.set_color("font_unselected_color", type, muted)
		result.set_color("font_hovered_color", type, text)
	result.set_stylebox("panel", "TabContainer", box(field, line, 8, Vector2(12, 12)))
	var separator := StyleBoxLine.new()
	separator.color = line
	separator.thickness = 1
	result.set_stylebox("separator", "HSeparator", separator)
	result.set_stylebox("background", "ProgressBar", box(field, Color.TRANSPARENT, 4, Vector2.ZERO))
	result.set_stylebox("fill", "ProgressBar", box(GOLD if dark else TEAL, Color.TRANSPARENT, 4, Vector2.ZERO))
	for type in ["HSlider", "VSlider"]:
		var track := box(line, Color.TRANSPARENT, 3, Vector2.ZERO)
		track.set_content_margin(SIDE_TOP, 3)
		track.set_content_margin(SIDE_BOTTOM, 3)
		result.set_stylebox("slider", type, track)
		result.set_stylebox("grabber_area", type, box(TEAL, Color.TRANSPARENT, 3, Vector2.ZERO))
		result.set_stylebox("grabber_area_highlight", type, box(TEAL.lightened(0.18), Color.TRANSPARENT, 3, Vector2.ZERO))
		result.set_icon("grabber", type, icon("knob", GOLD if dark else TEAL))
		result.set_icon("grabber_highlight", type, icon("knob", GOLD if dark else TEAL))
	for type in ["VScrollBar", "HScrollBar"]:
		result.set_stylebox("scroll", type, box(Color.TRANSPARENT, Color.TRANSPARENT, 3, Vector2(4, 4)))
		result.set_stylebox("grabber", type, box(line, Color.TRANSPARENT, 3, Vector2(4, 4)))
		result.set_stylebox("grabber_highlight", type, box(muted, Color.TRANSPARENT, 3, Vector2(4, 4)))
		result.set_stylebox("grabber_pressed", type, box(TEAL, Color.TRANSPARENT, 3, Vector2(4, 4)))
	result.set_stylebox("panel", "TooltipPanel", box(NAVY, Color("4c6569"), 8))
	result.set_color("font_color", "TooltipLabel", LIGHT)
	result.set_font_size("font_size", "TooltipLabel", 13)
	var window_border := box(PAPER, Color("cbd6cc"), 14, Vector2(24, 24))
	window_border.content_margin_top = 42
	result.set_stylebox("embedded_border", "Window", window_border)
	result.set_color("title_color", "Window", INK)
	result.set_font("title_font", "Window", font(600))
	result.set_font_size("title_font_size", "Window", 18)
	result.set_constant("title_height", "Window", 38)
	result.set_icon("close", "Window", icon("close", MUTED))
	for type in ["AcceptDialog", "ConfirmationDialog"]:
		result.set_stylebox("panel", type, box(PAPER, Color("cbd6cc"), 12, Vector2(24, 24)))
	_themes[dark] = result
	return result

static func apply(root: Control, dark: bool = false) -> void:
	root.theme = theme(dark)
	_clean_overrides(root, root)

static func _clean_overrides(node: Node, root: Control) -> void:
	if node != root and not node.scene_file_path.is_empty():
		return
	if node is Control:
		for property in node.get_property_list():
			var key := str(property.name)
			if key.begins_with("theme_override_colors/"):
				node.remove_theme_color_override(key.get_slice("/", 1))
			elif key.begins_with("theme_override_styles/"):
				node.remove_theme_stylebox_override(key.get_slice("/", 1))
		if node is BaseButton:
			node.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			node.focus_mode = Control.FOCUS_ALL
		if node is Label:
			node.add_theme_color_override("font_shadow_color", Color.TRANSPARENT)
			node.add_theme_constant_override("shadow_outline_size", 0)
	for child in node.get_children():
		_clean_overrides(child, root)

static func panel(control: Control, dark: bool = false, padding: Vector2 = Vector2(24, 24)) -> void:
	var style := box(NAVY if dark else PAPER, Color("3a545c") if dark else Color("cbd6cc"), 16, padding)
	style.shadow_color = Color(0.01, 0.035, 0.045, 0.28)
	style.shadow_size = 22
	style.shadow_offset = Vector2(0, 10)
	control.add_theme_stylebox_override("panel", style)

static func button(control: Button, role: String = "secondary", compact: bool = false) -> void:
	var dark := control.get_theme_color("font_color", "Label").get_luminance() > 0.5
	var primary := role == "primary"
	var danger := role == "danger"
	var fill := TEAL if primary else (Color("513b3a") if danger and dark else (SURFACE if dark else Color("e8ede5")))
	var text := LIGHT if primary or dark else INK
	var edge := TEAL.lightened(0.2) if primary else (ERROR if danger else (Color("45616a") if dark else Color("cad6cd")))
	var pad := Vector2(14, 7) if compact else Vector2(18, 12)
	control.add_theme_stylebox_override("normal", box(fill, edge, 8, pad))
	control.add_theme_stylebox_override("hover", box(fill.lightened(0.09), GOLD if primary else TEAL.lightened(0.22), 8, pad))
	control.add_theme_stylebox_override("pressed", box(fill.darkened(0.10), GOLD, 8, pad))
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		control.add_theme_color_override(state, text)
	control.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

static func label(control: Label, points: int = 15, color: Color = INK, heading: bool = false) -> void:
	control.add_theme_font_size_override("font_size", points)
	control.add_theme_color_override("font_color", color)
	if heading:
		control.add_theme_font_override("font", font(600))

static func dialog(control: AcceptDialog) -> void:
	var dialog_theme := theme(false).duplicate()
	var surface := box(PAPER, Color("cbd6cc"), 14, Vector2(24, 24))
	surface.content_margin_top = 62
	surface.shadow_color = Color(0.01, 0.035, 0.045, 0.28)
	surface.shadow_size = 18
	for type in ["AcceptDialog", "ConfirmationDialog"]:
		dialog_theme.set_stylebox("panel", type, surface)
	control.theme = dialog_theme
	control.unresizable = true
	control.borderless = true
	control.get_label().add_theme_color_override("font_color", INK)
	control.get_label().add_theme_font_size_override("font_size", 15)
	control.get_label().autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	control.min_size = Vector2i(420, 220)
	button(control.get_ok_button(), "primary")
	if control is ConfirmationDialog:
		button(control.get_cancel_button())
	if not control.has_node("DialogHeading"):
		# AcceptDialog resizes direct Control children into its body rectangle.
		# A plain Node keeps this header in its own top margin.
		var header_host := Node.new()
		header_host.name = "DialogHeading"
		control.add_child(header_host)
		var header := HBoxContainer.new()
		header.name = "Layout"
		header_host.add_child(header)
		header.anchor_right = 1.0
		header.offset_left = 24
		header.offset_right = -24
		header.offset_top = 14
		header.offset_bottom = 48
		var heading := Label.new()
		heading.text = control.title
		heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label(heading, 19, INK, true)
		header.add_child(heading)
		var close := Button.new()
		close.icon = icon("close", MUTED)
		close.custom_minimum_size = Vector2(34, 32)
		close.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		close.add_theme_stylebox_override("normal", box(Color.TRANSPARENT, Color.TRANSPARENT, 6, Vector2(4, 4)))
		close.add_theme_stylebox_override("hover", box(Color("e0e9e2"), Color.TRANSPARENT, 6, Vector2(4, 4)))
		close.add_theme_stylebox_override("pressed", box(Color("d6e7df"), TEAL, 6, Vector2(4, 4)))
		header.add_child(close)
		close.pressed.connect(func():
			control.hide()
			control.canceled.emit()
		)

static func reveal(control: Control) -> void:
	control.modulate.a = 0.0
	control.create_tween().tween_property(control, "modulate:a", 1.0, 0.16).set_trans(Tween.TRANS_SINE)

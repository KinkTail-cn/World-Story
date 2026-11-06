extends Node

var settings: RefCounted

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func _input(event: InputEvent) -> void:
	if not event is InputEventKey or (event.keycode != KEY_F11 and event.physical_keycode != KEY_F11):
		return
	if event.ctrl_pressed or event.alt_pressed or event.meta_pressed or event.shift_pressed:
		return
	get_viewport().set_input_as_handled()
	if event.pressed and not event.echo and settings != null:
		settings.toggle_fullscreen(get_viewport())

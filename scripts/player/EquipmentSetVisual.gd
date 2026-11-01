extends Node3D

const Presets = preload("res://scripts/blueprint/BlueprintPresets.gd")
const Renderer = preload("res://scripts/player/BlueprintEquipmentVisual.gd")
const Sets = preload("res://scripts/content/EquipmentSets.gd")
var item_id: int = 0
var pieces: Array[MeshInstance3D] = []
var cloth_materials: Array[ShaderMaterial] = []
var source_part_count: int = 0
var renderer: Node3D

func build(id: int, character: Node3D = null) -> void:
	if is_instance_valid(renderer):
		renderer.hide_pieces()
		remove_child(renderer)
		renderer.queue_free()
	item_id = id
	renderer = Renderer.new()
	renderer.icon_size = 0.42
	add_child(renderer)
	renderer.build(Presets.design_for_item(id), character)
	pieces = renderer.pieces
	cloth_materials = renderer.cloth_materials
	source_part_count = renderer.source_part_count
	if character == null:
		rotation.y = 0.0 if Sets.slot(id) == 5 else PI

func set_wind(strength: float) -> void:
	if is_instance_valid(renderer):
		renderer.set_wind(strength)

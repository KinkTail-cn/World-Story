extends RefCounted

# Fit a dialog's design size to the available viewport while retaining its
# node hierarchy, container layout and transformed mouse coordinates.
static func fit_centered(card: Control, available: Vector2, design: Vector2, margin: float = 20.0) -> void:
	var extent := design.max(card.get_combined_minimum_size()).max(Vector2.ONE)
	var factor := minf(1.0, minf((available.x - margin * 2.0) / extent.x, (available.y - margin * 2.0) / extent.y))
	card.set_anchors_preset(Control.PRESET_TOP_LEFT)
	card.size = extent
	card.scale = Vector2.ONE * maxf(0.1, factor)
	card.position = (available - extent * card.scale) * 0.5

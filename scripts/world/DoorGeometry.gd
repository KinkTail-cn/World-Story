extends RefCounted

# Two hinged leaves fit the existing 2 x 3 block openings. Only complete leaves
# rotate; the cubes inside each leaf keep their relative shape and dimensions.
const SIZE := Vector3(2.0, 3.0, 0.16)
const HINGE: float = 0.92
const LEAF_SIZE := Vector3(0.92, 2.84, 0.10)
const LEAF_BOTTOM: float = 0.04
const DURATION: float = 0.22

static func transform_for(record: Dictionary) -> Transform3D:
	var position: Array = record.position
	return Transform3D(Basis(Vector3.UP, int(record.get("turns", 0)) * PI * 0.5), Vector3(position[0], position[1], position[2]))

static func leaf_transform(side: int, amount: float) -> Transform3D:
	var hinge := Vector3(float(side) * HINGE, 0, 0)
	var rotation := Basis(Vector3.UP, -float(side) * amount * PI * 0.5)
	return Transform3D(rotation, hinge + rotation * Vector3(-float(side) * LEAF_SIZE.x * 0.5, LEAF_BOTTOM + LEAF_SIZE.y * 0.5, 0))

static func reserved_bounds(record: Dictionary) -> AABB:
	# Keep the threshold and inward opening arc available to both leaves.
	return transform_for(record) * AABB(Vector3(-1, 0, -1.0), Vector3(2, 3, 1.08))

static func threshold_bounds(record: Dictionary) -> AABB:
	return transform_for(record) * AABB(Vector3(-1, 0, -0.08), SIZE)

extends RefCounted

const Houses = preload("res://scripts/world/HouseTemplates.gd")
const VERSION := 1
const REGION_SIZE := 320 # Multiple of the world's 16-block chunk size.
const MIN_HOUSES := 16
const MAX_HOUSES := 28
const ROAD_WIDTH := 3
const MIN_HOUSE_GAP := 3
const MIN_SHORT_EDGE := 90
const MAX_SHORT_EDGE := 190
const MIN_LONG_EDGE := 100
const MAX_LONG_EDGE := 210
const BLEND_MARGIN := 4
const MAX_RELIEF := 8
const MAX_REGIONS := 16
const MAX_COMPILED := 4
const START_SEARCH_RADIUS := 12
const HEIGHT := 24

var world_seed: int = 1337
var sample_height: Callable
var _regions: Dictionary = {}
var _region_order: Array[Vector2i] = []
var _compiled: Dictionary = {}
var _compiled_order: Array[Vector2i] = []

func configure(seed_value: int, height_sampler: Callable) -> void:
	world_seed = seed_value
	sample_height = height_sampler
	_regions.clear()
	_region_order.clear()
	_compiled.clear()
	_compiled_order.clear()

static func region_at(point: Vector2i) -> Vector2i:
	return Vector2i(floori(float(point.x) / REGION_SIZE), floori(float(point.y) / REGION_SIZE))

static func seed_for(seed_value: int, region: Vector2i) -> int:
	return ((seed_value * 1664525) ^ (region.x * 73856093) ^ (region.y * 19349663) ^ 0x3141592) & 0x7fffffff

static func rural_centre(seed_value: int, region: Vector2i) -> Vector2i:
	var value := seed_for(seed_value, region)
	return region * REGION_SIZE + Vector2i(148 + value % 25, 148 + (value / 97) % 25)

static func countryside_height(seed_value: int, point: Vector2i, natural: int) -> int:
	var region := region_at(point)
	if region != Vector2i.ZERO and seed_for(seed_value, region) % 100 >= 72:
		return natural
	var centre := rural_centre(seed_value, region)
	var distance := Vector2(point - centre).length()
	var mix_value := clampf((distance - 108.0) / 40.0, 0.0, 1.0)
	if mix_value >= 1.0:
		return natural
	# A broad, gently rolling countryside supports a whole settlement. The
	# outer forty metres blend into the original coast, rather than cutting it.
	var country := 5.0 + sin(float(point.x + seed_value % 997) * 0.024) * 0.8 + sin(float(point.y) * 0.029) * 0.6
	var eased := mix_value * mix_value * (3.0 - 2.0 * mix_value)
	return roundi(lerpf(country, natural, eased))

static func rotate_point(point: Vector2i, turns: int) -> Vector2i:
	match posmod(turns, 4):
		1: return Vector2i(-point.y, point.x)
		2: return -point
		3: return Vector2i(point.y, -point.x)
	return point

static func rotate_rect(rect: Rect2i, turns: int) -> Rect2i:
	var first := rotate_point(rect.position, turns)
	var result := Rect2i(first, Vector2i.ONE)
	for point in [Vector2i(rect.end.x - 1, rect.position.y), Vector2i(rect.position.x, rect.end.y - 1), rect.end - Vector2i.ONE]:
		result = result.merge(Rect2i(rotate_point(point, turns), Vector2i.ONE))
	return result

# Pure layout construction also serves the house/village showcases and tests.
static func make_layout(layout_seed: int, centre: Vector2i = Vector2i.ZERO, floor_y: int = 5, route_streets: bool = true) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = layout_seed
	var count := rng.randi_range(MIN_HOUSES, MAX_HOUSES)
	var orientation := rng.randi_range(0, 3)
	var hubs: Array[Vector2i] = []
	for corner in [Vector2i(-1, -1), Vector2i(1, -1), Vector2i(1, 1), Vector2i(-1, 1)]:
		hubs.append(Vector2i(corner.x * rng.randi_range(30, 36), corner.y * rng.randi_range(30, 36)))
	var styles: Array[String] = Houses.STYLES.duplicate()
	while styles.size() < count:
		styles.append(["cottage", "cottage", "lodge", "stone", "courtyard"][rng.randi_range(0, 4)])
	for index in range(styles.size() - 1, 0, -1):
		var swap := rng.randi_range(0, index)
		var previous := styles[index]
		styles[index] = styles[swap]
		styles[swap] = previous
	var buildings: Array[Dictionary] = []
	var has_storehouse := false
	var local_plaza := Rect2i(-6, -6, 13, 13)
	var bounds := local_plaza
	for index in count:
		var variation := rng.randi_range(0, 2)
		var role := "home"
		if styles[index] == "workshop":
			role = "workshop"
		elif styles[index] == "lodge" and not has_storehouse:
			role = "storehouse"
			has_storehouse = true
		var neighbourhood := index % 4
		var hub := hubs[neighbourhood]
		var chosen: Dictionary = {}
		for attempt in 900:
			var angle := rng.randf() * TAU
			var radius := rng.randf_range(19, 34 if attempt < 200 else 44)
			if role != "home":
				angle = atan2(hub.y, hub.x) + rng.randf_range(-0.7, 0.7)
				radius = rng.randf_range(28, 38 if attempt < 200 else 46)
			var point := hub + Vector2i(roundi(cos(angle) * radius), roundi(sin(angle) * radius))
			var toward := hub - point
			var local_turns := (3 if toward.x > 0 else 1) if absi(toward.x) > absi(toward.y) else (0 if toward.y > 0 else 2)
			var shape := Houses.oriented(styles[index], variation, local_turns)
			var footprint := Rect2i(point - Vector2i(shape.size.x / 2, shape.size.z / 2), Vector2i(shape.size.x, shape.size.z))
			if not Rect2i(-MAX_SHORT_EDGE / 2, -MAX_LONG_EDGE / 2, MAX_SHORT_EDGE, MAX_LONG_EDGE).encloses(footprint.grow(8)):
				continue
			if footprint.grow(3).intersects(local_plaza.grow(3)):
				continue
			if hubs.any(func(yard: Vector2i): return footprint.grow(3).intersects(Rect2i(yard - Vector2i(5, 5), Vector2i(11, 11)))):
				continue
			var facing := rotate_point(Vector2i.DOWN, local_turns)
			var entrance := footprint.position + Vector2i(shape.entrance.x, shape.entrance.z)
			var approach := Rect2i(entrance, Vector2i.ONE).merge(Rect2i(entrance + facing * 4, Vector2i.ONE)).grow(1)
			var collision := false
			for previous in buildings:
				if footprint.grow(MIN_HOUSE_GAP).intersects(previous.bounds) or approach.intersects(previous.bounds.grow(1)) or footprint.grow(1).intersects(previous.approach):
					collision = true
					break
			if collision:
				continue
			chosen = {"style": styles[index], "title": shape.title, "role": role, "variation": variation, "turns": local_turns, "bounds": footprint, "approach": approach, "neighbourhood": neighbourhood}
			break
		if chosen.is_empty():
			return {} # A site never receives a partially assembled village.
		buildings.append(chosen)
		bounds = bounds.merge(chosen.bounds).merge(chosen.approach)
	bounds = bounds.grow(8)
	var padded := Vector2i(maxi(MIN_SHORT_EDGE, bounds.size.x), maxi(MIN_LONG_EDGE, bounds.size.y))
	bounds.position -= Vector2i((padded.x - bounds.size.x) / 2, (padded.y - bounds.size.y) / 2)
	bounds.size = padded
	for building in buildings:
		building.turns = posmod(building.turns + orientation, 4)
		building.bounds = rotate_rect(building.bounds, orientation)
		building.bounds.position += centre
		building.approach = rotate_rect(building.approach, orientation)
		building.approach.position += centre
		var shape := Houses.oriented(building.style, building.variation, building.turns)
		building.origin = Vector3i(building.bounds.position.x, floor_y, building.bounds.position.y)
		building.door = building.origin + Vector3i(shape.door)
		building.entrance = building.origin + Vector3i(shape.entrance)
		building.facing = rotate_point(Vector2i.DOWN, building.turns)
	var greens: Array[Rect2i] = []
	var waypoints: Array[Vector2i] = []
	for hub in hubs:
		greens.append(Rect2i(rotate_point(hub, orientation) + centre - Vector2i(4, 4), Vector2i(9, 9)))
		waypoints.append(rotate_point(hub + Vector2i(7, 0), orientation) + centre)
	var plaza := Rect2i(centre - Vector2i(6, 6), Vector2i(13, 13))
	var final_bounds := rotate_rect(bounds, orientation)
	final_bounds.position += centre
	var plan := {
		"seed": layout_seed, "centre": centre, "floor_y": floor_y,
		"orientation": orientation, "houses": buildings, "roads": [],
		"plaza": plaza, "bounds": final_bounds, "greens": greens,
		"waypoints": waypoints, "version": VERSION
	}
	if route_streets:
		_route_streets(plan)
	return plan

static func _route_streets(plan: Dictionary) -> void:
	var grid := AStarGrid2D.new()
	grid.region = plan.bounds.grow(-2)
	grid.cell_size = Vector2.ONE
	grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	grid.default_compute_heuristic = AStarGrid2D.HEURISTIC_MANHATTAN
	grid.default_estimate_heuristic = AStarGrid2D.HEURISTIC_MANHATTAN
	grid.update()
	var noise := FastNoiseLite.new()
	noise.seed = plan.seed
	noise.frequency = 0.085
	for z in range(grid.region.position.y, grid.region.end.y):
		for x in range(grid.region.position.x, grid.region.end.x):
			grid.set_point_weight_scale(Vector2i(x, z), 1.4 + (noise.get_noise_2d(x, z) + 1.0) * 1.6)
	for building in plan.houses:
		grid.fill_solid_region(building.bounds.grow(2))
	for green in plan.greens:
		grid.fill_solid_region(green.grow(1))
	# Reserve the square's shelter posts and benches before finding roads.
	for local in [Vector2i(2, -1), Vector2i(2, 1), Vector2i(4, -1), Vector2i(4, 1), Vector2i(-4, -4), Vector2i(-4, 4), Vector2i(4, -4), Vector2i(4, 4)]:
		var point := rotate_point(local, plan.orientation) + Vector2i(plan.centre)
		grid.fill_solid_region(Rect2i(point - Vector2i.ONE, Vector2i(3, 3)))
	var network := {}
	var routes: Array[Rect2i] = []
	# A connected loop links the four neighbourhoods; two winding approaches
	# bring it into the square, leaving the remaining spaces as gardens and yards.
	for index in 4:
		_add_route(grid, plan.waypoints[index], plan.waypoints[(index + 1) % 4], network, routes, false)
	for point in network:
		grid.set_point_weight_scale(point, 0.45)
	_add_route(grid, plan.centre, plan.waypoints[0], network, routes)
	_add_route(grid, plan.centre, plan.waypoints[2], network, routes)
	for building in plan.houses:
		var entry := Vector2i(building.entrance.x, building.entrance.z)
		var start: Vector2i = entry + building.facing * 4
		var closest: Vector2i = plan.centre
		var best := 2147483647
		for point in network:
			var dist: int = absi(point.x - start.x) + absi(point.y - start.y)
			if dist < best:
				closest = point
				best = dist
		_add_route(grid, start, closest, network, routes)
		routes.append(Rect2i(entry, Vector2i.ONE).merge(Rect2i(start, Vector2i.ONE)).grow(1))
	plan.roads = routes
	plan.road_centres = network.keys()

static func _add_route(grid: AStarGrid2D, start: Vector2i, finish: Vector2i, network: Dictionary, routes: Array[Rect2i], favour_existing: bool = true) -> void:
	var path := grid.get_id_path(start, finish)
	if path.is_empty():
		return
	var segment: Vector2i = path[0]
	var previous: Vector2i = path[0]
	var direction := Vector2i.ZERO
	for point in path:
		var step: Vector2i = point - previous
		if step != direction and direction != Vector2i.ZERO:
			routes.append(Rect2i(segment, Vector2i.ONE).merge(Rect2i(previous, Vector2i.ONE)).grow(1))
			segment = previous
		if step != Vector2i.ZERO:
			direction = step
		previous = point
		network[point] = true
		if favour_existing:
			grid.set_point_weight_scale(point, 0.45)
	routes.append(Rect2i(segment, Vector2i.ONE).merge(Rect2i(previous, Vector2i.ONE)).grow(1))

func plan_for_region(region: Vector2i) -> Dictionary:
	if _regions.has(region):
		_touch(_region_order, region)
		return _regions[region]
	var result: Dictionary = {}
	var regional_seed := seed_for(world_seed, region)
	# Empty regions and unsuitable coast/mountain sites remain natural terrain.
	if region == Vector2i.ZERO or regional_seed % 100 < 72:
		var rng := RandomNumberGenerator.new()
		rng.seed = regional_seed ^ 0x59a37
		var prototype := make_layout(regional_seed, Vector2i.ZERO, 5, false)
		if prototype.is_empty():
			_regions[region] = {}
			_touch(_region_order, region)
			while _region_order.size() > MAX_REGIONS:
				_regions.erase(_region_order.pop_front())
			return {}
		for attempt in 56:
			var centre := region * REGION_SIZE + Vector2i(rng.randi_range(-prototype.bounds.position.x + 12, REGION_SIZE - prototype.bounds.end.x - 12), rng.randi_range(-prototype.bounds.position.y + 12, REGION_SIZE - prototype.bounds.end.y - 12))
			if attempt == 0:
				centre = rural_centre(world_seed, region)
			var site: Rect2i = prototype.bounds
			site.position += centre
			if site.grow(BLEND_MARGIN).intersects(Rect2i(-8, -8, 48, 48)):
				continue
			var level := _site_level(site)
			if level < 0:
				continue
			result = make_layout(regional_seed, centre, level)
			result["region"] = region
			break
	_regions[region] = result
	_touch(_region_order, region)
	while _region_order.size() > MAX_REGIONS:
		var oldest: Vector2i = _region_order.pop_front()
		_regions.erase(oldest)
	return result

func is_managed(point: Vector2i) -> bool:
	var plan := plan_for_region(region_at(point))
	return not plan.is_empty() and plan.bounds.grow(BLEND_MARGIN).has_point(point)

func column_at(point: Vector2i) -> PackedInt32Array:
	var region := region_at(point)
	var plan := plan_for_region(region)
	if plan.is_empty() or not plan.bounds.grow(BLEND_MARGIN).has_point(point):
		return PackedInt32Array()
	return _columns(region, plan).get(point, PackedInt32Array())

func columns_for_chunk(coord: Vector2i) -> Dictionary:
	var chunk := Rect2i(coord * 16, Vector2i(16, 16))
	var region := region_at(chunk.position)
	var plan := plan_for_region(region)
	if plan.is_empty() or not plan.bounds.grow(BLEND_MARGIN).intersects(chunk):
		return {}
	var all := _columns(region, plan)
	var result: Dictionary = {}
	for z in range(chunk.position.y, chunk.end.y):
		for x in range(chunk.position.x, chunk.end.x):
			var point := Vector2i(x, z)
			if all.has(point):
				result[point] = all[point]
	return result

func _site_level(bounds: Rect2i) -> int:
	if not sample_height.is_valid():
		return -1
	var middle := bounds.get_center()
	if int(sample_height.call(middle.x, middle.y)) < 4:
		return -1
	var low := HEIGHT
	var high := 0
	var dry := 0
	var samples := 0
	# Reject bad sites cheaply before checking every column of the final footprint.
	for z in range(bounds.position.y, bounds.end.y, 8):
		for x in range(bounds.position.x, bounds.end.x, 8):
			var height: int = sample_height.call(x, z)
			low = mini(low, height)
			high = maxi(high, height)
			dry += 1 if height >= 3 else 0
			samples += 1
			if high > 10 or high - low > MAX_RELIEF:
				return -1
	if dry * 100 < samples * 72:
		return -1
	var counts := PackedInt32Array()
	counts.resize(HEIGHT)
	var shallows := 0
	for z in range(bounds.position.y, bounds.end.y):
		for x in range(bounds.position.x, bounds.end.x):
			var height: int = sample_height.call(x, z)
			low = mini(low, height)
			high = maxi(high, height)
			if high > 10 or high - low > MAX_RELIEF:
				return -1
			if height < 3:
				shallows += 1
				if shallows * 100 > bounds.get_area() * 28:
					return -1
			counts[height] += 1
	var accumulated := 0
	for height in range(1, 11):
		accumulated += counts[height]
		if accumulated * 2 >= bounds.get_area():
			return clampi(height, 4, 7)
	return -1

func _columns(region: Vector2i, plan: Dictionary) -> Dictionary:
	if _compiled.has(region):
		_touch(_compiled_order, region)
		return _compiled[region]
	var columns := compile(plan, sample_height)
	_compiled[region] = columns
	_touch(_compiled_order, region)
	while _compiled_order.size() > MAX_COMPILED:
		_compiled.erase(_compiled_order.pop_front())
	return columns

static func compile(plan: Dictionary, height_sampler: Callable) -> Dictionary:
	var columns: Dictionary = {}
	var level: int = plan.floor_y
	var grading := {}
	var areas: Array[Rect2i] = [plan.plaza.grow(2)]
	areas.append_array(plan.roads)
	areas.append_array(plan.greens)
	for building in plan.houses:
		areas.append(building.bounds.grow(1))
	for area in areas:
		for z in range(area.position.y - BLEND_MARGIN, area.end.y + BLEND_MARGIN):
			for x in range(area.position.x - BLEND_MARGIN, area.end.x + BLEND_MARGIN):
				var point := Vector2i(x, z)
				var distance := maxi(0, maxi(maxi(area.position.x - x, x - area.end.x + 1), maxi(area.position.y - z, z - area.end.y + 1)))
				grading[point] = mini(grading.get(point, BLEND_MARGIN), distance)
	# Grade only plots, paths and shared yards. Empty gaps retain their terrain,
	# so the village edge follows gardens and lanes instead of a rectangular pad.
	for point in grading:
		var native_height: int = height_sampler.call(point.x, point.y)
		var floor_y := roundi(lerpf(level, native_height, float(grading[point]) / BLEND_MARGIN))
		var values := PackedInt32Array()
		values.resize(HEIGHT)
		values.fill(-1)
		for y in range(maxi(1, mini(native_height + 1, floor_y - 2)), floor_y):
			values[y] = 2
		values[floor_y] = 1 if floor_y >= 4 else 6
		for y in range(floor_y + 1, HEIGHT):
			values[y] = 0
		columns[point] = values
	_pave(columns, plan.plaza, level, 14)
	for road in plan.roads:
		_pave(columns, road, level, 2)
	# Stone is concentrated at the square and thresholds; lanes are village dirt.
	_pave(columns, plan.plaza, level, 13)
	for building in plan.houses:
		var shape := Houses.oriented(building.style, building.variation, building.turns)
		for cell in shape.cells:
			_stamp(columns, Vector3i(building.origin) + cell, shape.cells[cell])
		if building.role == "storehouse":
			var source := Houses.model(building.style, building.variation)
			for x in [2, source.size.x - 3]:
				for z in [2, 3]:
					for y in [1, 2]:
						_stamp(columns, building.origin + Houses.rotate_cell(Vector3i(x, y, z), building.turns, source.size), 7)
	for index in plan.greens.size():
		var yard: Rect2i = plan.greens[index]
		for z in range(yard.position.y, yard.end.y):
			for x in range(yard.position.x, yard.end.x):
				var border := x in [yard.position.x, yard.end.x - 1] or z in [yard.position.y, yard.end.y - 1]
				_stamp(columns, Vector3i(x, level, z), 13 if border else (2 if index % 2 == 0 else 1))
				if index % 2 == 0 and not border and (x - yard.position.x) % 2 == 0 and z % 3 != 0:
					_stamp(columns, Vector3i(x, level + 1, z), 4)
		if index % 2 == 1:
			var tree: Vector2i = yard.get_center()
			for y in range(1, 5):
				_stamp(columns, Vector3i(tree.x, level + y, tree.y), 3)
			for layer in range(3):
				for z in range(-2, 3):
					for x in range(-2, 3):
						if absi(x) + absi(z) <= 3 - layer / 2 and (x != 0 or z != 0 or layer > 0):
							_stamp(columns, Vector3i(tree.x + x, level + 4 + layer, tree.y + z), 4)
			for x in [-2, 2]:
				_stamp(columns, Vector3i(tree.x + x, level + 1, tree.y + 2), 7)
	# A small public shelter sits beside, rather than across, the main street.
	for x in [2, 4]:
		for z in [-1, 1]:
			for y in range(1, 4):
				_feature(columns, plan, Vector3i(x, y, z), 3)
	for z in range(-2, 3):
		for x in range(1, 6):
			for y in range(4, 5 + mini(x - 1, 5 - x)):
				_feature(columns, plan, Vector3i(x, y, z), 8)
	for x in [-4, 4]:
		_feature(columns, plan, Vector3i(x, 1, -4), 7)
		_feature(columns, plan, Vector3i(x, 1, 4), 7)
	return columns

static func _feature(columns: Dictionary, plan: Dictionary, local: Vector3i, id: int) -> void:
	var point := rotate_point(Vector2i(local.x, local.z), plan.orientation) + Vector2i(plan.centre)
	_stamp(columns, Vector3i(point.x, plan.floor_y + local.y, point.y), id)

static func _stamp(columns: Dictionary, cell: Vector3i, id: int) -> void:
	var point := Vector2i(cell.x, cell.z)
	if cell.y >= 1 and cell.y < HEIGHT and columns.has(point):
		var values: PackedInt32Array = columns[point]
		values[cell.y] = id
		columns[point] = values

static func _pave(columns: Dictionary, rect: Rect2i, floor_y: int, id: int) -> void:
	for z in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			_stamp(columns, Vector3i(x, floor_y, z), id)

static func _touch(order: Array[Vector2i], region: Vector2i) -> void:
	order.erase(region)
	order.append(region)

static func search_ring(centre: Vector2i, radius: int) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for z in range(-radius, radius + 1):
		for x in range(-radius, radius + 1):
			if maxi(absi(x), absi(z)) == radius:
				result.append(centre + Vector2i(x, z))
	return result

extends SceneTree

const Houses = preload("res://scripts/world/HouseTemplates.gd")
const Villages = preload("res://scripts/world/VillageGenerator.gd")
const Blocks = preload("res://scripts/content/BlockCatalog.gd")
var checks: int = 0
var failures: int = 0

func _initialize() -> void:
	create_timer(30.0).timeout.connect(func(): push_error("VILLAGE_INTEGRITY_TIMEOUT"); quit(1))
	_run.call_deferred()

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)

func flat(_x: int, _z: int) -> int:
	return 5

func sea(_x: int, _z: int) -> int:
	return 1

func mountains(x: int, _z: int) -> int:
	return 4 + posmod(x, 12)

func _run() -> void:
	for style in Houses.STYLES:
		for variation in range(3):
			var original := Houses.model(style, variation)
			var within := true
			var registered := true
			for cell in original.cells:
				within = within and cell.x >= 0 and cell.x < original.size.x and cell.y >= 0 and cell.y < original.size.y and cell.z >= 0 and cell.z < original.size.z
				registered = registered and Blocks.is_valid_block(original.cells[cell])
			check(within and original.size.y <= 12, "House stays inside its declared grid bounds: " + style)
			check(registered, "House uses real registered world cubes: " + style)
			check(_supported(original.cells), "Roof, windows and furniture connect to the ground: " + style)
			for turns in range(4):
				var oriented := Houses.oriented(style, variation, turns)
				check(oriented.cells.size() == original.cells.size(), "Quarter turns preserve every building cube: " + style)
				var entry_clear := true
				for dx in range(2):
					for y in range(1, 4):
						var cell: Vector3i = original.door + Vector3i(dx, y - 1, 0)
						entry_clear = entry_clear and not oriented.cells.has(Houses.rotate_cell(cell, turns, original.size))
				check(entry_clear, "Two-wide three-high doorway survives rotation: " + style)
				check(oriented.cells.has(oriented.entrance + Vector3i.DOWN), "The approach has a real supported floor: " + style)
	var counts := {}
	var orientations := {}
	for seed_value in range(64):
		var plan := Villages.make_layout(seed_value, Vector2i(-81, 117))
		check(not plan.is_empty(), "The requested neighbourhoods produce a complete layout")
		if plan.is_empty():
			continue
		counts[plan.houses.size()] = true
		orientations[plan.orientation] = true
		check(plan == Villages.make_layout(seed_value, Vector2i(-81, 117)), "The seed reproduces layout, styles and rotations")
		check(plan.houses.size() >= Villages.MIN_HOUSES and plan.houses.size() <= Villages.MAX_HOUSES, "House count remains bounded")
		var short_edge: int = mini(plan.bounds.size.x, plan.bounds.size.y)
		var long_edge: int = maxi(plan.bounds.size.x, plan.bounds.size.y)
		check(short_edge >= Villages.MIN_SHORT_EDGE and short_edge <= Villages.MAX_SHORT_EDGE and long_edge >= Villages.MIN_LONG_EDGE and long_edge <= Villages.MAX_LONG_EDGE, "Village extent remains inside its published limits")
		var styles := {}
		var workshop_count := 0
		var separated := true
		var enclosed := true
		var roads_reach_entries := true
		for index in plan.houses.size():
			var building: Dictionary = plan.houses[index]
			styles[building.style] = true
			workshop_count += 1 if building.style == "workshop" else 0
			enclosed = enclosed and plan.bounds.encloses(building.bounds)
			var entrance := Vector2i(building.entrance.x, building.entrance.z)
			roads_reach_entries = roads_reach_entries and plan.roads.any(func(road: Rect2i): return road.has_point(entrance))
			for other_index in range(index + 1, plan.houses.size()):
				separated = separated and not building.bounds.grow(Villages.MIN_HOUSE_GAP).intersects(plan.houses[other_index].bounds)
		check(styles.size() == 5 and workshop_count == 1, "Every village mixes five styles with exactly one workshop")
		check(separated and enclosed, "Roofs, porches and yards retain spacing and stay inside the village")
		check(roads_reach_entries and plan.plaza.size == Vector2i(13, 13) and plan.greens.size() == 4, "Doors connect to the road system, shared square and four garden neighbourhoods")
		if seed_value < 8:
			var columns := Villages.compile(plan, flat)
			var reachable := _reachable(plan, columns)
			check(plan.houses.all(func(building: Dictionary): return reachable.has(Vector2i(building.door.x, building.door.z))), "Every front door is walkable from the square")
			var street_clear := true
			for point in plan.road_centres:
				var column: PackedInt32Array = columns[point]
				street_clear = street_clear and column[plan.floor_y] != 0 and column[plan.floor_y + 1] == 0 and column[plan.floor_y + 2] == 0
			check(street_clear, "Connected street centres remain unobstructed after buildings and gardens are placed, seed " + str(seed_value))
			var crossing := _street_path(plan)
			check(crossing.size() > 2 and not _street_path(plan, crossing[crossing.size() / 2]).is_empty(), "The neighbourhood ring retains an alternate route around a blocked lane")
	check(counts.has(Villages.MIN_HOUSES) and counts.has(Villages.MAX_HOUSES) and counts.size() >= 10 and orientations.size() == 4, "Seeds vary across the larger 16–28 house range and all four orientations")
	var generator := Villages.new()
	generator.configure(1337, sea)
	check(generator.plan_for_region(Vector2i.ZERO).is_empty(), "Open sea cannot become a village")
	generator.configure(1337, mountains)
	check(generator.plan_for_region(Vector2i.ZERO).is_empty(), "Steep mountain sites are rejected")
	generator.configure(1337, flat)
	var first := generator.plan_for_region(Vector2i.ZERO).duplicate(true)
	var point: Vector2i = first.centre
	var expected := generator.column_at(point)
	for index in range(36):
		var region := Vector2i(index, -2)
		var plan := generator.plan_for_region(region)
		if not plan.is_empty():
			generator.column_at(plan.centre)
	check(generator._regions.size() <= Villages.MAX_REGIONS and generator._compiled.size() <= Villages.MAX_COMPILED, "Exploration bounds layout and compiled-column memory")
	check(generator.plan_for_region(Vector2i.ZERO) == first and generator.column_at(point) == expected, "Eviction and reverse exploration reproduce the same village")
	check(Villages.region_at(Vector2i(-1, -321)) == Vector2i(-1, -2), "Negative coordinates select the correct generation region")
	print("VILLAGE_INTEGRITY_PASS: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

func _supported(cells: Dictionary) -> bool:
	var visited := {}
	var queue: Array[Vector3i] = []
	for cell in cells:
		if cell.y <= 1:
			visited[cell] = true
			queue.append(cell)
	var cursor := 0
	while cursor < queue.size():
		var current := queue[cursor]
		cursor += 1
		for direction in [Vector3i.LEFT, Vector3i.RIGHT, Vector3i.UP, Vector3i.DOWN, Vector3i.FORWARD, Vector3i.BACK]:
			var next: Vector3i = current + direction
			if cells.has(next) and not visited.has(next):
				visited[next] = true
				queue.append(next)
	return visited.size() == cells.size()

func _reachable(plan: Dictionary, columns: Dictionary) -> Dictionary:
	var start: Vector2i = plan.centre + Villages.rotate_point(Vector2i(-1, 0), plan.orientation)
	var visited := {start: true}
	var queue: Array[Vector2i] = [start]
	var cursor := 0
	while cursor < queue.size():
		var current := queue[cursor]
		cursor += 1
		for direction in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var next: Vector2i = current + direction
			if visited.has(next) or not plan.bounds.has_point(next) or not columns.has(next):
				continue
			var column: PackedInt32Array = columns[next]
			if column[plan.floor_y] > 0 and column[plan.floor_y + 1] == 0 and column[plan.floor_y + 2] == 0:
				visited[next] = true
				queue.append(next)
	return visited

func _street_path(plan: Dictionary, blocked: Vector2i = Vector2i(2147483647, 2147483647)) -> Array[Vector2i]:
	var network := {}
	for point in plan.road_centres:
		network[point] = true
	var start: Vector2i = plan.waypoints[0]
	var finish: Vector2i = plan.waypoints[2]
	var parents := {start: start}
	var queue: Array[Vector2i] = [start]
	var cursor := 0
	while cursor < queue.size() and not parents.has(finish):
		var current := queue[cursor]
		cursor += 1
		for direction in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var next: Vector2i = current + direction
			if next != blocked and network.has(next) and not parents.has(next):
				parents[next] = current
				queue.append(next)
	var result: Array[Vector2i] = []
	if parents.has(finish):
		var point := finish
		while point != start:
			result.append(point)
			point = parents[point]
		result.append(start)
	return result

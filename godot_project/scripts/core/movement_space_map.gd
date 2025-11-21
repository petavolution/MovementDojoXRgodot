## MovementSpaceMap - 3D grid tracking movement coverage
## Maps all reachable space relative to head position
class_name MovementSpaceMap
extends RefCounted

# Grid configuration
const CELL_SIZE := 0.1  # 10cm cells
const GRID_RADIUS := 15  # 1.5m radius (reasonable arm reach)
const GRID_SIZE := GRID_RADIUS * 2 + 1  # 31x31x31 = 29,791 cells

# Vertical offset range (relative to head)
const VERTICAL_MIN := -1.0  # 1m below head (waist/floor reach)
const VERTICAL_MAX := 0.8   # 0.8m above head (overhead reach)

# Visit tracking arrays (flat index for memory efficiency)
var left_visits: PackedInt32Array
var right_visits: PackedInt32Array
var first_visit_time: PackedFloat32Array  # When cell was first visited

# Statistics
var total_left_visits := 0
var total_right_visits := 0
var unique_cells_visited := 0
var _reachable_cells_cache := 0


func _init() -> void:
	var total_cells := GRID_SIZE * GRID_SIZE * GRID_SIZE
	left_visits.resize(total_cells)
	right_visits.resize(total_cells)
	first_visit_time.resize(total_cells)

	# Initialize arrays
	for i in range(total_cells):
		left_visits[i] = 0
		right_visits[i] = 0
		first_visit_time[i] = -1.0

	_reachable_cells_cache = _calculate_reachable_cells()


func reset() -> void:
	var total_cells := GRID_SIZE * GRID_SIZE * GRID_SIZE
	for i in range(total_cells):
		left_visits[i] = 0
		right_visits[i] = 0
		first_visit_time[i] = -1.0

	total_left_visits = 0
	total_right_visits = 0
	unique_cells_visited = 0


## Record a position and return true if this is a newly explored cell
func record_position(hand: String, world_pos: Vector3, head_pos: Vector3) -> bool:
	var relative_pos := world_pos - head_pos
	var cell := _world_to_cell(relative_pos)

	if not _is_valid_cell(cell):
		return false

	var idx := _cell_to_index(cell)
	var is_new := (left_visits[idx] == 0 and right_visits[idx] == 0)

	if hand == "left":
		left_visits[idx] += 1
		total_left_visits += 1
	else:
		right_visits[idx] += 1
		total_right_visits += 1

	if is_new:
		first_visit_time[idx] = Time.get_ticks_msec() / 1000.0
		unique_cells_visited += 1
		return true

	return false


func get_visits_at(relative_pos: Vector3) -> Dictionary:
	var cell := _world_to_cell(relative_pos)
	if not _is_valid_cell(cell):
		return {"left": 0, "right": 0, "total": 0}

	var idx := _cell_to_index(cell)
	return {
		"left": left_visits[idx],
		"right": right_visits[idx],
		"total": left_visits[idx] + right_visits[idx]
	}


func get_coverage_percentage() -> float:
	if _reachable_cells_cache <= 0:
		return 0.0
	return (float(unique_cells_visited) / float(_reachable_cells_cache)) * 100.0


func get_hand_coverage(hand: String) -> float:
	var visited := 0
	var visits_array := left_visits if hand == "left" else right_visits

	for i in range(visits_array.size()):
		if visits_array[i] > 0:
			visited += 1

	if _reachable_cells_cache <= 0:
		return 0.0
	return (float(visited) / float(_reachable_cells_cache)) * 100.0


func get_symmetry_score() -> float:
	var left_total := 0
	var right_total := 0

	for i in range(left_visits.size()):
		left_total += left_visits[i]
		right_total += right_visits[i]

	var total := left_total + right_total
	if total == 0:
		return 100.0  # Perfect symmetry when no data

	var balance := float(mini(left_total, right_total)) / float(maxi(left_total, right_total))
	return balance * 100.0


## Get unexplored zones that are within reasonable reach
func get_unexplored_zones(max_count: int = 50) -> Array[Vector3]:
	var unexplored: Array[Vector3] = []

	for x in range(GRID_SIZE):
		for y in range(GRID_SIZE):
			for z in range(GRID_SIZE):
				var cell := Vector3i(x, y, z)
				var idx := _cell_to_index(cell)

				if left_visits[idx] == 0 and right_visits[idx] == 0:
					var world_pos := _cell_to_world(cell)

					# Only include cells within reachable distance
					if world_pos.length() <= GRID_RADIUS * CELL_SIZE:
						unexplored.append(world_pos)

						if unexplored.size() >= max_count:
							return unexplored

	return unexplored


## Get heat map data for visualization (positions and intensities)
func get_heat_map_data() -> Array[Dictionary]:
	var data: Array[Dictionary] = []
	var max_visits := 1

	# Find max visits for normalization
	for i in range(left_visits.size()):
		var total := left_visits[i] + right_visits[i]
		if total > max_visits:
			max_visits = total

	# Build data array
	for x in range(GRID_SIZE):
		for y in range(GRID_SIZE):
			for z in range(GRID_SIZE):
				var cell := Vector3i(x, y, z)
				var idx := _cell_to_index(cell)
				var total := left_visits[idx] + right_visits[idx]

				if total > 0:
					var world_pos := _cell_to_world(cell)
					var intensity := float(total) / float(max_visits)

					data.append({
						"position": world_pos,
						"intensity": intensity,
						"left_visits": left_visits[idx],
						"right_visits": right_visits[idx]
					})

	return data


## Get zones grouped by movement direction (for pattern analysis)
func get_directional_coverage() -> Dictionary:
	var zones := {
		"overhead": 0,      # Above head
		"front": 0,         # In front
		"left_side": 0,     # Left side
		"right_side": 0,    # Right side
		"behind": 0,        # Behind (limited)
		"below": 0          # Below waist level
	}

	var zone_totals := zones.duplicate()

	for x in range(GRID_SIZE):
		for y in range(GRID_SIZE):
			for z in range(GRID_SIZE):
				var cell := Vector3i(x, y, z)
				var world_pos := _cell_to_world(cell)

				if world_pos.length() > GRID_RADIUS * CELL_SIZE:
					continue

				var idx := _cell_to_index(cell)
				var visited := (left_visits[idx] + right_visits[idx]) > 0

				# Categorize by position
				var zone := _categorize_position(world_pos)
				zone_totals[zone] += 1
				if visited:
					zones[zone] += 1

	# Convert to percentages
	var result := {}
	for zone_name in zones:
		if zone_totals[zone_name] > 0:
			result[zone_name] = (float(zones[zone_name]) / float(zone_totals[zone_name])) * 100.0
		else:
			result[zone_name] = 0.0

	return result


func _world_to_cell(pos: Vector3) -> Vector3i:
	var x := int(round(pos.x / CELL_SIZE)) + GRID_RADIUS
	var y := int(round((pos.y - VERTICAL_MIN) / CELL_SIZE))
	var z := int(round(pos.z / CELL_SIZE)) + GRID_RADIUS
	return Vector3i(x, y, z)


func _cell_to_world(cell: Vector3i) -> Vector3:
	var x := (cell.x - GRID_RADIUS) * CELL_SIZE
	var y := cell.y * CELL_SIZE + VERTICAL_MIN
	var z := (cell.z - GRID_RADIUS) * CELL_SIZE
	return Vector3(x, y, z)


func _cell_to_index(cell: Vector3i) -> int:
	return cell.x + cell.y * GRID_SIZE + cell.z * GRID_SIZE * GRID_SIZE


func _index_to_cell(idx: int) -> Vector3i:
	var x := idx % GRID_SIZE
	var y := (idx / GRID_SIZE) % GRID_SIZE
	var z := idx / (GRID_SIZE * GRID_SIZE)
	return Vector3i(x, y, z)


func _is_valid_cell(cell: Vector3i) -> bool:
	return (
		cell.x >= 0 and cell.x < GRID_SIZE and
		cell.y >= 0 and cell.y < GRID_SIZE and
		cell.z >= 0 and cell.z < GRID_SIZE
	)


func _calculate_reachable_cells() -> int:
	var count := 0
	var max_distance := GRID_RADIUS * CELL_SIZE

	for x in range(GRID_SIZE):
		for y in range(GRID_SIZE):
			for z in range(GRID_SIZE):
				var cell := Vector3i(x, y, z)
				var world_pos := _cell_to_world(cell)

				# Rough sphere approximation for reachable space
				if world_pos.length() <= max_distance:
					count += 1

	return count


func _categorize_position(pos: Vector3) -> String:
	# Vertical categories first
	if pos.y > 0.3:  # Above shoulder height
		return "overhead"
	if pos.y < -0.5:  # Below waist
		return "below"

	# Horizontal categories
	if pos.z < -0.2:  # Behind
		return "behind"
	if pos.x < -0.3:  # Left side
		return "left_side"
	if pos.x > 0.3:  # Right side
		return "right_side"

	return "front"  # Default center-front


func to_dict() -> Dictionary:
	return {
		"grid_size": GRID_SIZE,
		"cell_size": CELL_SIZE,
		"left_visits": Array(left_visits),
		"right_visits": Array(right_visits),
		"unique_cells": unique_cells_visited,
		"total_left": total_left_visits,
		"total_right": total_right_visits
	}


static func from_dict(data: Dictionary) -> MovementSpaceMap:
	var map := MovementSpaceMap.new()

	if data.has("left_visits"):
		for i in range(mini(data["left_visits"].size(), map.left_visits.size())):
			map.left_visits[i] = data["left_visits"][i]

	if data.has("right_visits"):
		for i in range(mini(data["right_visits"].size(), map.right_visits.size())):
			map.right_visits[i] = data["right_visits"][i]

	map.unique_cells_visited = data.get("unique_cells", 0)
	map.total_left_visits = data.get("total_left", 0)
	map.total_right_visits = data.get("total_right", 0)

	return map

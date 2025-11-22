## Integration Tests for Data Pipeline
## Tests the flow of data through the movement tracking system
extends RefCounted
class_name TestDataPipeline


static func run_all() -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	results.append_array(_test_frame_to_space_map())
	results.append_array(_test_session_flow())
	results.append_array(_test_coverage_tracking())
	results.append_array(_test_symmetry_calculation())
	results.append_array(_test_directional_coverage())
	results.append_array(_test_serialization_pipeline())
	return results


static func _test_frame_to_space_map() -> Array[Dictionary]:
	var results: Array[Dictionary] = []

	# Simulate typical VR session: head at ~1.6m, hands moving around
	var space_map := MovementSpaceMap.new()
	var head_pos := Vector3(0, 1.6, 0)

	# First frame: neutral position
	var frame := MovementFrame.create(
		0.0, 0.011,
		head_pos, Quaternion.IDENTITY,
		Vector3(-0.3, 1.0, -0.2), Quaternion.IDENTITY,
		Vector3(0.3, 1.0, -0.2), Quaternion.IDENTITY
	)

	var left_new := space_map.record_position("left", frame.left_position, frame.head_position)
	var right_new := space_map.record_position("right", frame.right_position, frame.head_position)

	results.append(_true(left_new, "first_left_is_new"))
	results.append(_true(right_new, "first_right_is_new"))
	results.append(_eq(space_map.unique_cells_visited, 2, "two_cells_after_first_frame"))

	# Simulate 100 frames of movement
	for i in range(100):
		var t := float(i) * 0.011
		var sway := sin(t * 2.0) * 0.3

		var left_pos := Vector3(-0.3 + sway, 1.0, -0.2)
		var right_pos := Vector3(0.3 - sway, 1.0, -0.2)

		space_map.record_position("left", left_pos, head_pos)
		space_map.record_position("right", right_pos, head_pos)

	results.append(_true(space_map.unique_cells_visited > 2, "movement_explores_cells"))
	results.append(_true(space_map.total_left_visits >= 100, "left_visits_accumulated"))
	results.append(_true(space_map.total_right_visits >= 100, "right_visits_accumulated"))

	return results


static func _test_session_flow() -> Array[Dictionary]:
	var results: Array[Dictionary] = []

	# Simulate a complete training session
	var frames: Array[MovementFrame] = []
	var space_map := MovementSpaceMap.new()

	# Generate 500 frames (~5.5 seconds at 90 FPS)
	var head_pos := Vector3(0, 1.6, 0)
	for i in range(500):
		var t := float(i) * 0.011
		var frame := MovementFrame.create(
			t, 0.011,
			head_pos + Vector3(0, sin(t) * 0.02, 0),  # Slight head bob
			Quaternion.IDENTITY,
			Vector3(-0.3 + sin(t * 3) * 0.4, 1.0 + sin(t * 2) * 0.3, -0.3 + cos(t) * 0.2),
			Quaternion.IDENTITY,
			Vector3(0.3 + cos(t * 3) * 0.4, 1.0 + cos(t * 2) * 0.3, -0.3 + sin(t) * 0.2),
			Quaternion.IDENTITY
		)

		if i > 0:
			frame.compute_velocities(frames[i - 1])

		frame.compute_derived_metrics()
		frames.append(frame)

		space_map.record_position("left", frame.left_position, frame.head_position)
		space_map.record_position("right", frame.right_position, frame.head_position)

	# Verify session data
	results.append(_eq(frames.size(), 500, "frame_count"))

	var duration := frames[-1].timestamp - frames[0].timestamp
	results.append(_near(duration, 5.489, 0.1, "session_duration"))

	# Verify velocity computation worked
	var has_velocity := false
	for frame in frames:
		if frame.left_velocity.length() > 0.1:
			has_velocity = true
			break
	results.append(_true(has_velocity, "velocities_computed"))

	# Verify coverage
	results.append(_true(space_map.get_coverage_percentage() > 0, "coverage_tracked"))
	results.append(_true(space_map.unique_cells_visited > 10, "multiple_cells_explored"))

	return results


static func _test_coverage_tracking() -> Array[Dictionary]:
	var results: Array[Dictionary] = []

	var space_map := MovementSpaceMap.new()
	var head_pos := Vector3(0, 1.6, 0)

	# Initial coverage should be 0
	results.append(_near(space_map.get_coverage_percentage(), 0.0, 0.01, "initial_coverage"))

	# Explore some cells
	var positions := [
		Vector3(0.3, 1.0, -0.2),
		Vector3(-0.3, 1.0, -0.2),
		Vector3(0, 1.5, -0.3),
		Vector3(0.5, 0.8, -0.4),
		Vector3(-0.5, 0.8, -0.4),
	]

	for pos in positions:
		space_map.record_position("right", pos, head_pos)

	var coverage := space_map.get_coverage_percentage()
	results.append(_true(coverage > 0, "coverage_increases"))

	# Hand-specific coverage
	var right_coverage := space_map.get_hand_coverage("right")
	var left_coverage := space_map.get_hand_coverage("left")

	results.append(_true(right_coverage > 0, "right_coverage_tracked"))
	results.append(_near(left_coverage, 0.0, 0.01, "left_coverage_zero"))

	# Add some left hand movement
	for pos in positions:
		var mirrored := Vector3(-pos.x, pos.y, pos.z)
		space_map.record_position("left", mirrored, head_pos)

	left_coverage = space_map.get_hand_coverage("left")
	results.append(_true(left_coverage > 0, "left_coverage_updated"))

	return results


static func _test_symmetry_calculation() -> Array[Dictionary]:
	var results: Array[Dictionary] = []

	var space_map := MovementSpaceMap.new()
	var head_pos := Vector3(0, 1.6, 0)

	# Perfect symmetry with no data
	results.append(_near(space_map.get_symmetry_score(), 100.0, 0.01, "initial_symmetry"))

	# Add equal movement to both hands
	for i in range(50):
		var pos := Vector3(sin(float(i) * 0.1) * 0.3, 1.0, -0.2)
		space_map.record_position("left", pos, head_pos)
		space_map.record_position("right", pos, head_pos)

	var symmetry := space_map.get_symmetry_score()
	results.append(_near(symmetry, 100.0, 1.0, "equal_movement_symmetry"))

	# Add imbalanced movement (more left)
	for i in range(100):
		var pos := Vector3(-0.3 + sin(float(i) * 0.05) * 0.2, 1.0, -0.2)
		space_map.record_position("left", pos, head_pos)

	symmetry = space_map.get_symmetry_score()
	results.append(_true(symmetry < 100.0, "imbalanced_symmetry"))
	results.append(_true(symmetry > 0.0, "symmetry_positive"))

	return results


static func _test_directional_coverage() -> Array[Dictionary]:
	var results: Array[Dictionary] = []

	var space_map := MovementSpaceMap.new()
	var head_pos := Vector3(0, 1.6, 0)

	# Get initial directional coverage
	var coverage := space_map.get_directional_coverage()
	results.append(_true(coverage.has("overhead"), "has_overhead"))
	results.append(_true(coverage.has("front"), "has_front"))
	results.append(_true(coverage.has("left_side"), "has_left_side"))
	results.append(_true(coverage.has("right_side"), "has_right_side"))
	results.append(_true(coverage.has("below"), "has_below"))

	# Explore overhead zone (y > 0.3 relative to head)
	space_map.record_position("right", Vector3(0, 2.0, -0.1), head_pos)  # 0.4m above head

	coverage = space_map.get_directional_coverage()
	results.append(_true(coverage["overhead"] > 0, "overhead_explored"))

	# Explore below zone (y < -0.5 relative to head)
	space_map.record_position("left", Vector3(0, 0.5, -0.2), head_pos)  # 1.1m below head

	coverage = space_map.get_directional_coverage()
	results.append(_true(coverage["below"] > 0, "below_explored"))

	# Explore right side (x > 0.3)
	space_map.record_position("right", Vector3(0.5, 1.4, 0), head_pos)

	coverage = space_map.get_directional_coverage()
	results.append(_true(coverage["right_side"] > 0, "right_side_explored"))

	return results


static func _test_serialization_pipeline() -> Array[Dictionary]:
	var results: Array[Dictionary] = []

	# Create a realistic session dataset
	var frames: Array[MovementFrame] = []
	var space_map := MovementSpaceMap.new()
	var head_pos := Vector3(0, 1.7, 0)

	for i in range(100):
		var t := float(i) * 0.011
		var frame := MovementFrame.create(
			t, 0.011,
			head_pos, Quaternion.IDENTITY,
			Vector3(-0.3 + sin(t) * 0.2, 1.1, -0.25), Quaternion.IDENTITY,
			Vector3(0.3 + cos(t) * 0.2, 1.1, -0.25), Quaternion.IDENTITY
		)
		frame.left_grip = 0.8
		frame.right_grip = 0.5

		if i > 0:
			frame.compute_velocities(frames[i - 1])

		frames.append(frame)
		space_map.record_position("left", frame.left_position, frame.head_position)
		space_map.record_position("right", frame.right_position, frame.head_position)

	# Serialize frames
	var frame_dicts: Array[Dictionary] = []
	for frame in frames:
		frame_dicts.append(frame.to_dict())

	# Verify JSON encoding works
	var json_str := JSON.stringify({"frames": frame_dicts})
	results.append(_true(json_str.length() > 0, "json_encode"))

	# Parse back
	var parsed := JSON.parse_string(json_str)
	results.append(_true(parsed is Dictionary, "json_parse_dict"))
	results.append(_true(parsed.has("frames"), "json_has_frames"))
	results.append(_eq(parsed["frames"].size(), 100, "json_frame_count"))

	# Deserialize frames
	var restored_frames: Array[MovementFrame] = []
	for frame_dict in parsed["frames"]:
		restored_frames.append(MovementFrame.from_dict(frame_dict))

	results.append(_eq(restored_frames.size(), 100, "restored_frame_count"))

	# Verify first and last frames
	results.append(_near(restored_frames[0].timestamp, frames[0].timestamp, 0.001, "first_timestamp"))
	results.append(_near(restored_frames[-1].timestamp, frames[-1].timestamp, 0.001, "last_timestamp"))
	results.append(_near(restored_frames[0].left_grip, 0.8, 0.001, "restored_grip"))

	# Serialize space map
	var map_dict := space_map.to_dict()
	results.append(_true(map_dict.has("left_visits"), "map_has_left_visits"))
	results.append(_true(map_dict.has("right_visits"), "map_has_right_visits"))

	# Restore space map
	var restored_map := MovementSpaceMap.from_dict(map_dict)
	results.append(_eq(restored_map.unique_cells_visited, space_map.unique_cells_visited, "map_unique_match"))
	results.append(_eq(restored_map.total_left_visits, space_map.total_left_visits, "map_left_match"))

	return results


# =============================================================================
# Test Helpers
# =============================================================================

static func _eq(actual, expected, name: String) -> Dictionary:
	return {"name": name, "suite": "DataPipeline", "passed": actual == expected,
			"expected": expected, "actual": actual}

static func _near(actual: float, expected: float, epsilon: float, name: String) -> Dictionary:
	return {"name": name, "suite": "DataPipeline", "passed": abs(actual - expected) <= epsilon,
			"expected": expected, "actual": actual, "message": "epsilon=" + str(epsilon)}

static func _true(condition: bool, name: String) -> Dictionary:
	return {"name": name, "suite": "DataPipeline", "passed": condition,
			"expected": true, "actual": condition}

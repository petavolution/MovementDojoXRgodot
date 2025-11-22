## TestRunner - Headless test runner for CLI execution
## Run with: godot --headless --script tests/test_runner.gd
extends SceneTree

const SOURCE := "TestRunner"
const EXIT_SUCCESS := 0
const EXIT_FAILURE := 1

var test_results: Array[Dictionary] = []
var total_tests := 0
var passed_tests := 0
var failed_tests := 0
var current_suite := ""

# Log file for test results
var _log_file: FileAccess
var _log_path: String


func _init() -> void:
	# Setup test log file
	_setup_test_log()

	# Run all tests
	_log_and_print("\n" + "=".repeat(60))
	_log_and_print("Movement Dojo XR - Test Suite")
	_log_and_print("=".repeat(60) + "\n")

	_run_all_tests()
	_print_summary()

	# Close log file
	_close_test_log()

	# Exit with appropriate code
	quit(EXIT_SUCCESS if failed_tests == 0 else EXIT_FAILURE)


func _setup_test_log() -> void:
	var user_dir := OS.get_user_data_dir()
	_log_path = user_dir + "/test-results.txt"

	# Ensure directory exists
	DirAccess.make_dir_recursive_absolute(user_dir)

	_log_file = FileAccess.open(_log_path, FileAccess.WRITE)
	if _log_file:
		var datetime := Time.get_datetime_dict_from_system()
		_log_file.store_line("=".repeat(80))
		_log_file.store_line("TEST RUN: %04d-%02d-%02d %02d:%02d:%02d" % [
			datetime.year, datetime.month, datetime.day,
			datetime.hour, datetime.minute, datetime.second
		])
		_log_file.store_line("=".repeat(80))
		_log_file.store_line("")


func _close_test_log() -> void:
	if _log_file:
		_log_file.store_line("")
		_log_file.store_line("Log saved to: " + _log_path)
		_log_file.close()
		print("Test log saved to: " + _log_path)


func _log_and_print(message: String) -> void:
	print(message)
	if _log_file:
		_log_file.store_line(message)


func _run_all_tests() -> void:
	# Unit Tests - Modular test classes
	_run_suite("MovementFrame", TestMovementFrame.run_all())
	_run_suite("ScoreSystem", TestScoreSystem.run_all())

	# Unit Tests - Inline (for systems without separate test class)
	_run_suite("MovementSpaceMap", _test_movement_space_map())
	_run_suite("ProprioceptionMath", _test_proprioception_math())
	_run_suite("HapticPatterns", _test_haptic_patterns())
	_run_suite("Serialization", _test_serialization())

	# Integration Tests
	_run_suite("DataPipeline", TestDataPipeline.run_all())
	_run_suite("DataFlow", _test_data_flow())


func _run_suite(name: String, results: Array[Dictionary]) -> void:
	current_suite = name
	_log_and_print("[SUITE] " + name)

	for result in results:
		total_tests += 1
		if result.passed:
			passed_tests += 1
			_log_and_print("  [PASS] " + result.name)
		else:
			failed_tests += 1
			_log_and_print("  [FAIL] " + result.name)
			_log_and_print("         Expected: " + str(result.expected))
			_log_and_print("         Got:      " + str(result.actual))
			if result.has("message"):
				_log_and_print("         Message:  " + result.message)

		test_results.append(result)

	_log_and_print("")


func _print_summary() -> void:
	_log_and_print("=".repeat(60))
	_log_and_print("RESULTS: %d passed, %d failed, %d total" % [passed_tests, failed_tests, total_tests])
	_log_and_print("=".repeat(60))

	if failed_tests > 0:
		_log_and_print("\nFailed tests:")
		for result in test_results:
			if not result.passed:
				_log_and_print("  - [%s] %s" % [result.suite, result.name])


# =============================================================================
# TEST HELPERS
# =============================================================================

func _assert_eq(actual, expected, name: String) -> Dictionary:
	var passed := actual == expected
	return {
		"name": name,
		"suite": current_suite,
		"passed": passed,
		"expected": expected,
		"actual": actual
	}


func _assert_near(actual: float, expected: float, epsilon: float, name: String) -> Dictionary:
	var passed := abs(actual - expected) <= epsilon
	return {
		"name": name,
		"suite": current_suite,
		"passed": passed,
		"expected": expected,
		"actual": actual,
		"message": "epsilon: " + str(epsilon)
	}


func _assert_true(condition: bool, name: String, message: String = "") -> Dictionary:
	return {
		"name": name,
		"suite": current_suite,
		"passed": condition,
		"expected": true,
		"actual": condition,
		"message": message
	}


func _assert_not_null(value, name: String) -> Dictionary:
	return {
		"name": name,
		"suite": current_suite,
		"passed": value != null,
		"expected": "not null",
		"actual": "null" if value == null else "not null"
	}


# =============================================================================
# MOVEMENT FRAME TESTS
# =============================================================================

func _test_movement_frame() -> Array[Dictionary]:
	var results: Array[Dictionary] = []

	# Test: Create frame with basic data
	var frame := MovementFrame.create(
		1.0,  # timestamp
		0.011,  # delta (~90 FPS)
		Vector3(0, 1.6, 0),  # head pos
		Quaternion.IDENTITY,
		Vector3(-0.3, 1.0, -0.2),  # left pos
		Quaternion.IDENTITY,
		Vector3(0.3, 1.0, -0.2),  # right pos
		Quaternion.IDENTITY
	)

	results.append(_assert_near(frame.timestamp, 1.0, 0.001, "create_timestamp"))
	results.append(_assert_near(frame.frame_delta, 0.011, 0.001, "create_delta"))
	results.append(_assert_near(frame.head_position.y, 1.6, 0.001, "create_head_pos_y"))

	# Test: Velocity computation
	var frame1 := MovementFrame.create(0.0, 0.01, Vector3.ZERO, Quaternion.IDENTITY,
		Vector3.ZERO, Quaternion.IDENTITY, Vector3.ZERO, Quaternion.IDENTITY)
	var frame2 := MovementFrame.create(0.1, 0.1, Vector3(0, 0, 0), Quaternion.IDENTITY,
		Vector3(1, 0, 0), Quaternion.IDENTITY, Vector3.ZERO, Quaternion.IDENTITY)

	frame2.compute_velocities(frame1)
	# Left hand moved 1m in 0.1s = 10 m/s
	results.append(_assert_near(frame2.left_velocity.x, 10.0, 0.001, "velocity_computation_x"))
	results.append(_assert_near(frame2.left_velocity.y, 0.0, 0.001, "velocity_computation_y"))

	# Test: Derived metrics
	var metric_frame := MovementFrame.create(0.0, 0.01,
		Vector3(0, 1.6, 0), Quaternion.IDENTITY,  # Head at 1.6m
		Vector3(-0.5, 1.0, -0.3), Quaternion.IDENTITY,  # Left hand
		Vector3(0.5, 1.8, -0.3), Quaternion.IDENTITY)  # Right hand above head
	metric_frame.compute_derived_metrics()

	results.append(_assert_true(metric_frame.left_height_relative < 0,
		"derived_left_below_head", "Left hand should be below head"))
	results.append(_assert_true(metric_frame.right_height_relative > 0,
		"derived_right_above_head", "Right hand should be above head"))

	# Test: Quaternion to angular velocity edge cases
	var identity_frame := MovementFrame.new()
	var identity_angular := identity_frame._quaternion_to_angular_velocity(Quaternion.IDENTITY, 0.01)
	results.append(_assert_near(identity_angular.length(), 0.0, 0.001, "angular_velocity_identity"))

	# Test: Zero delta protection
	var zero_delta_frame := MovementFrame.new()
	var zero_angular := zero_delta_frame._quaternion_to_angular_velocity(Quaternion.IDENTITY, 0.0)
	results.append(_assert_near(zero_angular.length(), 0.0, 0.001, "angular_velocity_zero_delta"))

	return results


# =============================================================================
# MOVEMENT SPACE MAP TESTS
# =============================================================================

func _test_movement_space_map() -> Array[Dictionary]:
	var results: Array[Dictionary] = []

	var space_map := MovementSpaceMap.new()

	# Test: Initial state
	results.append(_assert_eq(space_map.unique_cells_visited, 0, "initial_unique_cells"))
	results.append(_assert_near(space_map.get_coverage_percentage(), 0.0, 0.001, "initial_coverage"))
	results.append(_assert_near(space_map.get_symmetry_score(), 100.0, 0.001, "initial_symmetry"))

	# Test: Record first position (should return true for new cell)
	var is_new := space_map.record_position("left", Vector3(0.3, 1.0, -0.2), Vector3(0, 1.6, 0))
	results.append(_assert_true(is_new, "first_record_is_new"))
	results.append(_assert_eq(space_map.unique_cells_visited, 1, "unique_after_first"))

	# Test: Record same position again (should return false)
	is_new = space_map.record_position("left", Vector3(0.3, 1.0, -0.2), Vector3(0, 1.6, 0))
	results.append(_assert_true(not is_new, "second_record_not_new"))
	results.append(_assert_eq(space_map.unique_cells_visited, 1, "unique_unchanged"))

	# Test: Record different hand same position
	is_new = space_map.record_position("right", Vector3(0.3, 1.0, -0.2), Vector3(0, 1.6, 0))
	results.append(_assert_true(not is_new, "different_hand_same_cell_not_new"))

	# Test: Record different position
	is_new = space_map.record_position("right", Vector3(-0.5, 0.8, -0.5), Vector3(0, 1.6, 0))
	results.append(_assert_true(is_new, "different_position_is_new"))
	results.append(_assert_eq(space_map.unique_cells_visited, 2, "unique_after_second_cell"))

	# Test: Coverage increases
	results.append(_assert_true(space_map.get_coverage_percentage() > 0.0,
		"coverage_increases", "Coverage should be > 0 after visits"))

	# Test: Get visits at position
	var visits := space_map.get_visits_at(Vector3(0.3, -0.6, -0.2))  # Relative to head
	results.append(_assert_eq(visits.left, 2, "visits_left_count"))
	results.append(_assert_eq(visits.right, 1, "visits_right_count"))

	# Test: Out of bounds handling
	is_new = space_map.record_position("left", Vector3(10, 10, 10), Vector3(0, 1.6, 0))
	results.append(_assert_true(not is_new, "out_of_bounds_returns_false"))

	# Test: Reset
	space_map.reset()
	results.append(_assert_eq(space_map.unique_cells_visited, 0, "reset_unique_cells"))
	results.append(_assert_eq(space_map.total_left_visits, 0, "reset_left_visits"))

	# Test: Cell coordinate conversion roundtrip
	var test_pos := Vector3(0.25, 0.5, -0.35)
	var cell := space_map._world_to_cell(test_pos)
	var back_pos := space_map._cell_to_world(cell)
	results.append(_assert_near(back_pos.x, test_pos.x, 0.05, "cell_roundtrip_x"))
	results.append(_assert_near(back_pos.z, test_pos.z, 0.05, "cell_roundtrip_z"))

	# Test: Index conversion roundtrip
	var test_cell := Vector3i(5, 10, 15)
	var index := space_map._cell_to_index(test_cell)
	var back_cell := space_map._index_to_cell(index)
	results.append(_assert_eq(back_cell, test_cell, "index_roundtrip"))

	return results


# =============================================================================
# SCORE CALCULATION TESTS
# =============================================================================

func _test_score_calculations() -> Array[Dictionary]:
	var results: Array[Dictionary] = []

	# Test combo multiplier calculation (using the formula from score_manager.gd)
	results.append(_assert_near(_calc_combo_mult(0), 1.0, 0.001, "combo_mult_0"))
	results.append(_assert_near(_calc_combo_mult(4), 1.0, 0.001, "combo_mult_4"))
	results.append(_assert_near(_calc_combo_mult(5), 1.5, 0.001, "combo_mult_5"))
	results.append(_assert_near(_calc_combo_mult(9), 1.5, 0.001, "combo_mult_9"))
	results.append(_assert_near(_calc_combo_mult(10), 2.0, 0.001, "combo_mult_10"))
	results.append(_assert_near(_calc_combo_mult(19), 2.0, 0.001, "combo_mult_19"))
	results.append(_assert_near(_calc_combo_mult(20), 2.5, 0.001, "combo_mult_20"))
	results.append(_assert_near(_calc_combo_mult(50), 4.0, 0.001, "combo_mult_50"))

	# Test combo bonus calculation
	results.append(_assert_eq(_calc_combo_bonus(0), 0, "combo_bonus_0"))
	results.append(_assert_eq(_calc_combo_bonus(4), 0, "combo_bonus_4"))
	results.append(_assert_eq(_calc_combo_bonus(5), 100, "combo_bonus_5"))  # 5 * 20
	results.append(_assert_eq(_calc_combo_bonus(10), 400, "combo_bonus_10"))  # 10 * 40
	results.append(_assert_eq(_calc_combo_bonus(20), 1200, "combo_bonus_20"))  # 20 * 60
	results.append(_assert_eq(_calc_combo_bonus(35), 3500, "combo_bonus_35"))  # 35 * 100

	# Test accuracy calculation
	results.append(_assert_near(_calc_accuracy(10, 0), 100.0, 0.001, "accuracy_perfect"))
	results.append(_assert_near(_calc_accuracy(5, 5), 50.0, 0.001, "accuracy_half"))
	results.append(_assert_near(_calc_accuracy(0, 10), 0.0, 0.001, "accuracy_zero"))
	results.append(_assert_near(_calc_accuracy(0, 0), 100.0, 0.001, "accuracy_no_attempts"))

	# Test point calculation with multipliers
	var base_points := 100
	var combo_mult := 2.0
	var base_mult := 1.5
	var expected := int(100 * 2.0 * 1.5)  # 300
	results.append(_assert_eq(_calc_points(base_points, combo_mult, base_mult), expected, "points_with_multipliers"))

	return results


func _calc_combo_mult(combo: int) -> float:
	if combo < 5:
		return 1.0
	elif combo < 10:
		return 1.5
	elif combo < 20:
		return 2.0
	elif combo < 35:
		return 2.5
	elif combo < 50:
		return 3.0
	else:
		return 4.0


func _calc_combo_bonus(combo: int) -> int:
	if combo < 5:
		return 0
	elif combo < 10:
		return combo * 20
	elif combo < 20:
		return combo * 40
	elif combo < 35:
		return combo * 60
	else:
		return combo * 100


func _calc_accuracy(hits: int, misses: int) -> float:
	var total := hits + misses
	if total == 0:
		return 100.0
	return float(hits) / total * 100.0


func _calc_points(base: int, combo_mult: float, base_mult: float) -> int:
	return int(base * combo_mult * base_mult)


# =============================================================================
# PROPRIOCEPTION MATH TESTS
# =============================================================================

func _test_proprioception_math() -> Array[Dictionary]:
	var results: Array[Dictionary] = []

	# Test: Position deviation calculation
	var current := Vector3(0.3, 1.0, -0.2)
	var target := Vector3(0.3, 1.1, -0.2)
	var deviation := current.distance_to(target)
	results.append(_assert_near(deviation, 0.1, 0.001, "position_deviation"))

	# Test: Within tolerance check
	var tolerance := 0.1
	results.append(_assert_true(deviation <= tolerance, "within_tolerance"))

	current = Vector3(0.5, 1.0, -0.2)
	deviation = current.distance_to(target)
	results.append(_assert_true(deviation > tolerance, "outside_tolerance"))

	# Test: Rotation deviation (simplified max component)
	var current_rot := Vector3(10, 20, 30)
	var target_rot := Vector3(15, 25, 35)
	var rot_dev := _calc_rot_deviation(current_rot, target_rot)
	results.append(_assert_near(rot_dev, 5.0, 0.001, "rotation_deviation"))

	# Test: Rotation tolerance
	var rot_tolerance := 15.0
	results.append(_assert_true(rot_dev <= rot_tolerance, "rotation_within_tolerance"))

	# Test: Accuracy from deviation
	tolerance = 0.1
	deviation = 0.05  # Half of tolerance
	var accuracy := 1.0 - (deviation / tolerance)
	results.append(_assert_near(accuracy, 0.5, 0.001, "accuracy_from_deviation"))

	# Test: Accuracy clamping
	deviation = 0.15  # Beyond tolerance
	accuracy = clampf(1.0 - (deviation / tolerance), 0.0, 1.0)
	results.append(_assert_near(accuracy, 0.0, 0.001, "accuracy_clamped_low"))

	deviation = -0.05  # Negative (shouldn't happen but test clamping)
	accuracy = clampf(1.0 - (deviation / tolerance), 0.0, 1.0)
	results.append(_assert_near(accuracy, 1.0, 0.001, "accuracy_clamped_high"))

	# Test: Position adjustment with scale
	var relative_pos := Vector3(0.5, 1.0, -0.3)
	var origin := Vector3(1.0, 0.0, 2.0)
	var scale := 1.2  # Taller player
	var adjusted := origin + relative_pos * scale
	results.append(_assert_near(adjusted.x, 1.6, 0.001, "adjusted_position_x"))
	results.append(_assert_near(adjusted.y, 1.2, 0.001, "adjusted_position_y"))

	return results


func _calc_rot_deviation(current: Vector3, target: Vector3) -> float:
	var diff := current - target
	return maxf(abs(diff.x), maxf(abs(diff.y), abs(diff.z)))


# =============================================================================
# HAPTIC PATTERNS TESTS
# =============================================================================

func _test_haptic_patterns() -> Array[Dictionary]:
	var results: Array[Dictionary] = []

	# Test: Pattern structure validation
	var light_tap := _get_test_pattern("LIGHT_TAP")
	results.append(_assert_true(light_tap.size() > 0, "light_tap_has_pulses"))
	results.append(_assert_true(light_tap[0].has("duration"), "pulse_has_duration"))
	results.append(_assert_true(light_tap[0].has("amplitude"), "pulse_has_amplitude"))

	# Test: Amplitude bounds
	for pulse in light_tap:
		results.append(_assert_true(pulse.amplitude >= 0.0 and pulse.amplitude <= 1.0,
			"amplitude_bounds", "Amplitude: " + str(pulse.amplitude)))

	# Test: Duration positive
	for pulse in light_tap:
		results.append(_assert_true(pulse.duration > 0,
			"duration_positive", "Duration: " + str(pulse.duration)))

	# Test: Frequency reasonable (0-500 Hz typical for VR haptics)
	for pulse in light_tap:
		if pulse.has("frequency"):
			results.append(_assert_true(pulse.frequency >= 0 and pulse.frequency <= 500,
				"frequency_bounds", "Frequency: " + str(pulse.frequency)))

	# Test: Velocity-based intensity calculation
	var intensity := _calc_velocity_intensity(0.0, 1.0, 8.0)
	results.append(_assert_near(intensity, 0.0, 0.01, "velocity_intensity_min"))

	intensity = _calc_velocity_intensity(8.0, 1.0, 8.0)
	results.append(_assert_near(intensity, 1.0, 0.01, "velocity_intensity_max"))

	intensity = _calc_velocity_intensity(4.5, 1.0, 8.0)
	results.append(_assert_near(intensity, 0.5, 0.01, "velocity_intensity_mid"))

	return results


func _get_test_pattern(name: String) -> Array[Dictionary]:
	# Simplified pattern definitions for testing
	match name:
		"LIGHT_TAP":
			return [{"delay": 0, "duration": 50, "frequency": 150, "amplitude": 0.3}]
		"STRONG_TAP":
			return [{"delay": 0, "duration": 100, "frequency": 200, "amplitude": 0.8}]
		_:
			return []


func _calc_velocity_intensity(velocity: float, min_vel: float, max_vel: float) -> float:
	return clampf((velocity - min_vel) / (max_vel - min_vel), 0.0, 1.0)


# =============================================================================
# SERIALIZATION TESTS
# =============================================================================

func _test_serialization() -> Array[Dictionary]:
	var results: Array[Dictionary] = []

	# Test: MovementFrame serialization roundtrip
	var original_frame := MovementFrame.create(
		1.5, 0.011,
		Vector3(0, 1.65, 0.1), Quaternion(0.1, 0.2, 0.3, 0.9).normalized(),
		Vector3(-0.4, 1.1, -0.3), Quaternion(0, 0, 0.1, 0.995).normalized(),
		Vector3(0.35, 1.05, -0.25), Quaternion(0.05, 0, 0, 0.999).normalized()
	)
	original_frame.left_grip = 0.8
	original_frame.right_trigger = 0.5

	var dict := original_frame.to_dict()
	var restored_frame := MovementFrame.from_dict(dict)

	results.append(_assert_near(restored_frame.timestamp, original_frame.timestamp, 0.001, "frame_serialize_timestamp"))
	results.append(_assert_near(restored_frame.head_position.x, original_frame.head_position.x, 0.001, "frame_serialize_head_x"))
	results.append(_assert_near(restored_frame.head_position.y, original_frame.head_position.y, 0.001, "frame_serialize_head_y"))
	results.append(_assert_near(restored_frame.left_grip, 0.8, 0.001, "frame_serialize_left_grip"))
	results.append(_assert_near(restored_frame.right_trigger, 0.5, 0.001, "frame_serialize_right_trigger"))

	# Test: MovementSpaceMap serialization roundtrip
	var original_map := MovementSpaceMap.new()
	original_map.record_position("left", Vector3(0.2, 1.0, -0.2), Vector3(0, 1.6, 0))
	original_map.record_position("right", Vector3(-0.3, 0.9, -0.4), Vector3(0, 1.6, 0))
	original_map.record_position("left", Vector3(0.2, 1.0, -0.2), Vector3(0, 1.6, 0))  # Revisit

	var map_dict := original_map.to_dict()
	var restored_map := MovementSpaceMap.from_dict(map_dict)

	results.append(_assert_eq(restored_map.unique_cells_visited, original_map.unique_cells_visited, "map_serialize_unique"))
	results.append(_assert_eq(restored_map.total_left_visits, original_map.total_left_visits, "map_serialize_left"))
	results.append(_assert_eq(restored_map.total_right_visits, original_map.total_right_visits, "map_serialize_right"))

	# Test: JSON string encoding/decoding
	var json_str := JSON.stringify(dict)
	results.append(_assert_true(json_str.length() > 0, "json_stringify"))

	var parsed = JSON.parse_string(json_str)
	results.append(_assert_not_null(parsed, "json_parse"))
	results.append(_assert_true(parsed is Dictionary, "json_is_dict"))

	return results


# =============================================================================
# DATA FLOW INTEGRATION TESTS
# =============================================================================

func _test_data_flow() -> Array[Dictionary]:
	var results: Array[Dictionary] = []

	# Test: Frame → SpaceMap integration
	var frame := MovementFrame.create(
		0.0, 0.011,
		Vector3(0, 1.6, 0), Quaternion.IDENTITY,
		Vector3(-0.4, 1.0, -0.3), Quaternion.IDENTITY,
		Vector3(0.4, 1.2, -0.2), Quaternion.IDENTITY
	)

	var space_map := MovementSpaceMap.new()
	var left_new := space_map.record_position("left", frame.left_position, frame.head_position)
	var right_new := space_map.record_position("right", frame.right_position, frame.head_position)

	results.append(_assert_true(left_new, "integration_left_recorded"))
	results.append(_assert_true(right_new, "integration_right_recorded"))
	results.append(_assert_eq(space_map.unique_cells_visited, 2, "integration_two_cells"))

	# Test: Multiple frames update map correctly
	for i in range(10):
		var offset := Vector3(i * 0.05, 0, 0)
		space_map.record_position("left", frame.left_position + offset, frame.head_position)

	results.append(_assert_true(space_map.unique_cells_visited >= 2, "integration_multiple_frames"))
	results.append(_assert_true(space_map.total_left_visits >= 11, "integration_visit_count"))

	# Test: Coverage increases with exploration
	var coverage := space_map.get_coverage_percentage()

	# Add more diverse positions
	space_map.record_position("right", Vector3(0.5, 1.5, -0.1), frame.head_position)
	space_map.record_position("right", Vector3(-0.5, 0.8, -0.5), frame.head_position)

	var new_coverage := space_map.get_coverage_percentage()
	results.append(_assert_true(new_coverage >= coverage, "integration_coverage_increases"))

	# Test: Symmetry affected by imbalanced exploration
	var symmetry := space_map.get_symmetry_score()
	results.append(_assert_true(symmetry < 100.0, "integration_symmetry_imbalanced"))

	return results

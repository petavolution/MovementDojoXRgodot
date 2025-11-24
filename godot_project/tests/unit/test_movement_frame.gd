## Unit Tests for MovementFrame
## Tests velocity computation, derived metrics, and serialization
extends RefCounted
class_name TestMovementFrame


static func run_all() -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	results.append_array(_test_creation())
	results.append_array(_test_velocity_computation())
	results.append_array(_test_derived_metrics())
	results.append_array(_test_angular_velocity())
	results.append_array(_test_serialization())
	results.append_array(_test_edge_cases())
	return results


static func _test_creation() -> Array[Dictionary]:
	var results: Array[Dictionary] = []

	# Basic creation
	var frame := MovementFrame.create(
		1.5, 0.011,
		Vector3(0, 1.6, 0), Quaternion.IDENTITY,
		Vector3(-0.3, 1.0, -0.2), Quaternion.IDENTITY,
		Vector3(0.3, 1.0, -0.2), Quaternion.IDENTITY
	)

	results.append(_eq(frame.timestamp, 1.5, "create_timestamp"))
	results.append(_near(frame.frame_delta, 0.011, 0.0001, "create_delta"))
	results.append(_near(frame.head_position.y, 1.6, 0.001, "create_head_y"))
	results.append(_near(frame.left_position.x, -0.3, 0.001, "create_left_x"))
	results.append(_near(frame.right_position.x, 0.3, 0.001, "create_right_x"))

	# Default values
	results.append(_near(frame.left_grip, 0.0, 0.001, "default_left_grip"))
	results.append(_near(frame.right_trigger, 0.0, 0.001, "default_right_trigger"))
	results.append(_eq(frame.left_velocity, Vector3.ZERO, "default_left_velocity"))

	return results


static func _test_velocity_computation() -> Array[Dictionary]:
	var results: Array[Dictionary] = []

	# Frame 1: Starting position
	var frame1 := MovementFrame.create(
		0.0, 0.01,
		Vector3(0, 1.6, 0), Quaternion.IDENTITY,
		Vector3(0, 1.0, 0), Quaternion.IDENTITY,
		Vector3(0, 1.0, 0), Quaternion.IDENTITY
	)

	# Frame 2: Hand moved 1m in X over 0.1 seconds = 10 m/s
	var frame2 := MovementFrame.create(
		0.1, 0.1,
		Vector3(0, 1.6, 0), Quaternion.IDENTITY,
		Vector3(1.0, 1.0, 0), Quaternion.IDENTITY,
		Vector3(0, 1.0, 0), Quaternion.IDENTITY
	)

	frame2.compute_velocities(frame1)

	results.append(_near(frame2.left_velocity.x, 10.0, 0.01, "velocity_left_x"))
	results.append(_near(frame2.left_velocity.y, 0.0, 0.01, "velocity_left_y"))
	results.append(_near(frame2.left_velocity.z, 0.0, 0.01, "velocity_left_z"))
	results.append(_near(frame2.right_velocity.length(), 0.0, 0.01, "velocity_right_stationary"))
	results.append(_near(frame2.head_velocity.length(), 0.0, 0.01, "velocity_head_stationary"))

	# Test diagonal movement
	var frame3 := MovementFrame.create(
		0.2, 0.1,
		Vector3(0, 1.6, 0), Quaternion.IDENTITY,
		Vector3(1.0, 1.0, 0), Quaternion.IDENTITY,
		Vector3(1.0, 1.0, 1.0), Quaternion.IDENTITY  # Moved diagonally
	)

	frame3.compute_velocities(frame2)

	var expected_speed := sqrt(100.0 + 100.0)  # sqrt(10^2 + 10^2) ≈ 14.14
	results.append(_near(frame3.right_velocity.length(), expected_speed, 0.1, "velocity_diagonal"))

	return results


static func _test_derived_metrics() -> Array[Dictionary]:
	var results: Array[Dictionary] = []

	# Head at 1.6m, left hand at 1.0m (0.6m below head)
	var frame := MovementFrame.create(
		0.0, 0.01,
		Vector3(0, 1.6, 0), Quaternion.IDENTITY,
		Vector3(-0.4, 1.0, -0.3), Quaternion.IDENTITY,
		Vector3(0.4, 1.8, -0.2), Quaternion.IDENTITY  # Right hand above head
	)

	frame.compute_derived_metrics()

	# Left hand below head
	results.append(_true(frame.left_height_relative < 0, "left_below_head"))
	results.append(_near(frame.left_height_relative, -0.6, 0.01, "left_height_value"))

	# Right hand above head
	results.append(_true(frame.right_height_relative > 0, "right_above_head"))
	results.append(_near(frame.right_height_relative, 0.2, 0.01, "right_height_value"))

	# Reach distances should be positive
	results.append(_true(frame.left_reach_distance > 0, "left_reach_positive"))
	results.append(_true(frame.right_reach_distance > 0, "right_reach_positive"))

	return results


static func _test_angular_velocity() -> Array[Dictionary]:
	var results: Array[Dictionary] = []

	var frame := MovementFrame.new()

	# Identity quaternion should give zero angular velocity
	var angular := frame._quaternion_to_angular_velocity(Quaternion.IDENTITY, 0.01)
	results.append(_near(angular.length(), 0.0, 0.001, "angular_identity"))

	# Zero delta should return zero (division protection)
	angular = frame._quaternion_to_angular_velocity(Quaternion(0.1, 0, 0, 0.995).normalized(), 0.0)
	results.append(_eq(angular, Vector3.ZERO, "angular_zero_delta"))

	# Small rotation should give small angular velocity
	var small_rot := Quaternion.from_euler(Vector3(0.1, 0, 0))  # ~5.7 degrees
	angular = frame._quaternion_to_angular_velocity(small_rot, 0.01)
	results.append(_true(angular.length() > 0, "angular_small_rotation"))
	results.append(_true(angular.length() < 20, "angular_reasonable_magnitude"))

	return results


static func _test_serialization() -> Array[Dictionary]:
	var results: Array[Dictionary] = []

	# Create frame with all fields populated
	var original := MovementFrame.create(
		2.5, 0.0111,
		Vector3(0.1, 1.65, 0.05), Quaternion(0.1, 0.2, 0.3, 0.9).normalized(),
		Vector3(-0.45, 1.12, -0.28), Quaternion(0, 0, 0.1, 0.995).normalized(),
		Vector3(0.38, 1.08, -0.22), Quaternion(0.05, 0, 0, 0.999).normalized()
	)
	original.left_grip = 0.75
	original.left_trigger = 0.5
	original.right_grip = 0.25
	original.right_trigger = 0.9
	original.left_velocity = Vector3(1.5, 0.2, -0.8)
	original.right_velocity = Vector3(-0.3, 0.1, 0.4)

	# Serialize to dict
	var dict := original.to_dict()

	# Verify dict structure
	results.append(_true(dict.has("t"), "dict_has_timestamp"))
	results.append(_true(dict.has("head"), "dict_has_head"))
	results.append(_true(dict.has("left"), "dict_has_left"))
	results.append(_true(dict.has("right"), "dict_has_right"))

	# Deserialize
	var restored := MovementFrame.from_dict(dict)

	# Verify all fields match
	results.append(_near(restored.timestamp, original.timestamp, 0.001, "serialize_timestamp"))
	results.append(_near(restored.frame_delta, original.frame_delta, 0.0001, "serialize_delta"))

	results.append(_near(restored.head_position.x, original.head_position.x, 0.001, "serialize_head_x"))
	results.append(_near(restored.head_position.y, original.head_position.y, 0.001, "serialize_head_y"))

	results.append(_near(restored.left_position.x, original.left_position.x, 0.001, "serialize_left_x"))
	results.append(_near(restored.left_grip, original.left_grip, 0.001, "serialize_left_grip"))
	results.append(_near(restored.left_trigger, original.left_trigger, 0.001, "serialize_left_trigger"))

	results.append(_near(restored.right_position.x, original.right_position.x, 0.001, "serialize_right_x"))
	results.append(_near(restored.right_grip, original.right_grip, 0.001, "serialize_right_grip"))

	return results


static func _test_edge_cases() -> Array[Dictionary]:
	var results: Array[Dictionary] = []

	# Null previous frame
	var frame := MovementFrame.new()
	frame.frame_delta = 0.01
	frame.compute_velocities(null)  # Should not crash
	results.append(_eq(frame.left_velocity, Vector3.ZERO, "null_previous_frame"))

	# Zero delta (prevents division by zero)
	var frame1 := MovementFrame.create(
		0, 0.01, Vector3.ZERO, Quaternion.IDENTITY,
		Vector3.ZERO, Quaternion.IDENTITY, Vector3.ZERO, Quaternion.IDENTITY
	)
	var frame2 := MovementFrame.create(
		0, 0,  # Zero delta
		Vector3.ZERO, Quaternion.IDENTITY,
		Vector3(1, 0, 0), Quaternion.IDENTITY, Vector3.ZERO, Quaternion.IDENTITY
	)
	frame2.compute_velocities(frame1)
	results.append(_eq(frame2.left_velocity, Vector3.ZERO, "zero_delta_protection"))

	# Very large positions (edge of play space)
	var far_frame := MovementFrame.create(
		0, 0.01,
		Vector3(0, 5, 0), Quaternion.IDENTITY,  # Very high head
		Vector3(-2, 0.5, -2), Quaternion.IDENTITY,  # Far reach
		Vector3(2, 3, 2), Quaternion.IDENTITY
	)
	far_frame.compute_derived_metrics()
	results.append(_true(far_frame.left_reach_distance > 0, "far_reach_valid"))

	# Deserialize partial data
	var partial_dict := {"t": 1.0}  # Missing most fields
	var partial_frame := MovementFrame.from_dict(partial_dict)
	results.append(_near(partial_frame.timestamp, 1.0, 0.001, "partial_deserialize"))
	results.append(_eq(partial_frame.head_position, Vector3.ZERO, "partial_defaults"))

	return results


# =============================================================================
# Test Helpers
# =============================================================================

static func _eq(actual, expected, name: String) -> Dictionary:
	return {"name": name, "suite": "MovementFrame", "passed": actual == expected,
			"expected": expected, "actual": actual}

static func _near(actual: float, expected: float, epsilon: float, name: String) -> Dictionary:
	return {"name": name, "suite": "MovementFrame", "passed": abs(actual - expected) <= epsilon,
			"expected": expected, "actual": actual, "message": "epsilon=" + str(epsilon)}

static func _true(condition: bool, name: String) -> Dictionary:
	return {"name": name, "suite": "MovementFrame", "passed": condition,
			"expected": true, "actual": condition}

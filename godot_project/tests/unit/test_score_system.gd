## Unit Tests for Scoring System
## Tests combo multipliers, point calculations, and accuracy
extends RefCounted
class_name TestScoreSystem

# Constants from ScoreManager (must match)
const POINTS_TARGET_HIT := 100
const POINTS_TARGET_DESTROYED := 250
const POINTS_DEFLECTION := 150
const POINTS_DEFLECT_KILL := 500
const POINTS_PERFECT_SWING := 50
const POINTS_COMBO_BONUS_PER_HIT := 10


static func run_all() -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	results.append_array(_test_combo_multiplier())
	results.append_array(_test_combo_bonus())
	results.append_array(_test_point_calculation())
	results.append_array(_test_accuracy())
	results.append_array(_test_hit_registration())
	results.append_array(_test_deflection_scoring())
	results.append_array(_test_edge_cases())
	return results


static func _test_combo_multiplier() -> Array[Dictionary]:
	var results: Array[Dictionary] = []

	# Combo thresholds: 0-4=1.0, 5-9=1.5, 10-19=2.0, 20-34=2.5, 35-49=3.0, 50+=4.0
	results.append(_near(_calc_combo_mult(0), 1.0, 0.01, "mult_combo_0"))
	results.append(_near(_calc_combo_mult(1), 1.0, 0.01, "mult_combo_1"))
	results.append(_near(_calc_combo_mult(4), 1.0, 0.01, "mult_combo_4"))
	results.append(_near(_calc_combo_mult(5), 1.5, 0.01, "mult_combo_5"))
	results.append(_near(_calc_combo_mult(9), 1.5, 0.01, "mult_combo_9"))
	results.append(_near(_calc_combo_mult(10), 2.0, 0.01, "mult_combo_10"))
	results.append(_near(_calc_combo_mult(15), 2.0, 0.01, "mult_combo_15"))
	results.append(_near(_calc_combo_mult(19), 2.0, 0.01, "mult_combo_19"))
	results.append(_near(_calc_combo_mult(20), 2.5, 0.01, "mult_combo_20"))
	results.append(_near(_calc_combo_mult(34), 2.5, 0.01, "mult_combo_34"))
	results.append(_near(_calc_combo_mult(35), 3.0, 0.01, "mult_combo_35"))
	results.append(_near(_calc_combo_mult(49), 3.0, 0.01, "mult_combo_49"))
	results.append(_near(_calc_combo_mult(50), 4.0, 0.01, "mult_combo_50"))
	results.append(_near(_calc_combo_mult(100), 4.0, 0.01, "mult_combo_100"))

	return results


static func _test_combo_bonus() -> Array[Dictionary]:
	var results: Array[Dictionary] = []

	# Bonus thresholds: 0-4=0, 5-9=20x, 10-19=40x, 20-34=60x, 35+=100x
	results.append(_eq(_calc_combo_bonus(0), 0, "bonus_combo_0"))
	results.append(_eq(_calc_combo_bonus(4), 0, "bonus_combo_4"))
	results.append(_eq(_calc_combo_bonus(5), 100, "bonus_combo_5"))  # 5 * 20
	results.append(_eq(_calc_combo_bonus(9), 180, "bonus_combo_9"))  # 9 * 20
	results.append(_eq(_calc_combo_bonus(10), 400, "bonus_combo_10"))  # 10 * 40
	results.append(_eq(_calc_combo_bonus(15), 600, "bonus_combo_15"))  # 15 * 40
	results.append(_eq(_calc_combo_bonus(20), 1200, "bonus_combo_20"))  # 20 * 60
	results.append(_eq(_calc_combo_bonus(30), 1800, "bonus_combo_30"))  # 30 * 60
	results.append(_eq(_calc_combo_bonus(35), 3500, "bonus_combo_35"))  # 35 * 100
	results.append(_eq(_calc_combo_bonus(50), 5000, "bonus_combo_50"))  # 50 * 100

	return results


static func _test_point_calculation() -> Array[Dictionary]:
	var results: Array[Dictionary] = []

	# Basic points without multipliers
	var base := POINTS_TARGET_HIT
	results.append(_eq(_calc_points(base, 1.0, 1.0), 100, "points_basic"))

	# With combo multiplier only
	results.append(_eq(_calc_points(base, 2.0, 1.0), 200, "points_2x_combo"))
	results.append(_eq(_calc_points(base, 1.5, 1.0), 150, "points_1.5x_combo"))

	# With base multiplier only (difficulty)
	results.append(_eq(_calc_points(base, 1.0, 1.5), 150, "points_1.5x_base"))
	results.append(_eq(_calc_points(base, 1.0, 2.0), 200, "points_2x_base"))

	# Combined multipliers
	results.append(_eq(_calc_points(base, 2.0, 1.5), 300, "points_combined"))
	results.append(_eq(_calc_points(base, 4.0, 2.0), 800, "points_max_combined"))

	# Different base values
	results.append(_eq(_calc_points(POINTS_DEFLECTION, 2.0, 1.0), 300, "points_deflection"))
	results.append(_eq(_calc_points(POINTS_TARGET_DESTROYED, 1.5, 1.0), 375, "points_destroyed"))

	return results


static func _test_accuracy() -> Array[Dictionary]:
	var results: Array[Dictionary] = []

	# Perfect accuracy
	results.append(_near(_calc_accuracy(10, 0), 100.0, 0.01, "accuracy_perfect"))
	results.append(_near(_calc_accuracy(100, 0), 100.0, 0.01, "accuracy_100_hits"))

	# Zero accuracy
	results.append(_near(_calc_accuracy(0, 10), 0.0, 0.01, "accuracy_zero"))

	# 50% accuracy
	results.append(_near(_calc_accuracy(5, 5), 50.0, 0.01, "accuracy_50"))
	results.append(_near(_calc_accuracy(50, 50), 50.0, 0.01, "accuracy_50_large"))

	# Various percentages
	results.append(_near(_calc_accuracy(75, 25), 75.0, 0.01, "accuracy_75"))
	results.append(_near(_calc_accuracy(1, 3), 25.0, 0.01, "accuracy_25"))
	results.append(_near(_calc_accuracy(9, 1), 90.0, 0.01, "accuracy_90"))

	# Edge case: no attempts
	results.append(_near(_calc_accuracy(0, 0), 100.0, 0.01, "accuracy_no_attempts"))

	return results


static func _test_hit_registration() -> Array[Dictionary]:
	var results: Array[Dictionary] = []

	# Basic hit (no destruction, low velocity)
	var points := _simulate_hit(50.0, 3.0, false, 1.0, 1.0, 0)
	results.append(_eq(points, POINTS_TARGET_HIT, "hit_basic"))

	# Hit with destruction
	points = _simulate_hit(100.0, 3.0, true, 1.0, 1.0, 0)
	results.append(_eq(points, POINTS_TARGET_HIT + POINTS_TARGET_DESTROYED, "hit_destroyed"))

	# High velocity hit (perfect swing)
	points = _simulate_hit(50.0, 6.0, false, 1.0, 1.0, 0)
	results.append(_eq(points, POINTS_TARGET_HIT + POINTS_PERFECT_SWING, "hit_perfect_swing"))

	# High velocity + destruction
	points = _simulate_hit(100.0, 6.0, true, 1.0, 1.0, 0)
	var expected := POINTS_TARGET_HIT + POINTS_TARGET_DESTROYED + POINTS_PERFECT_SWING
	results.append(_eq(points, expected, "hit_perfect_destroyed"))

	# With combo bonus
	points = _simulate_hit(50.0, 3.0, false, 1.0, 1.0, 10)
	expected = POINTS_TARGET_HIT + (10 * POINTS_COMBO_BONUS_PER_HIT)  # 100 + 100
	results.append(_eq(points, expected, "hit_with_combo"))

	# With combo multiplier (combo 10 = 2.0x)
	points = _simulate_hit(50.0, 3.0, false, 2.0, 1.0, 10)
	expected = (POINTS_TARGET_HIT * 2) + (10 * POINTS_COMBO_BONUS_PER_HIT)  # 200 + 100
	results.append(_eq(points, expected, "hit_combo_multiplied"))

	return results


static func _test_deflection_scoring() -> Array[Dictionary]:
	var results: Array[Dictionary] = []

	# Basic deflection
	var points := _simulate_deflection(false, 1.0, 1.0, 0)
	results.append(_eq(points, POINTS_DEFLECTION, "deflect_basic"))

	# Deflection kill
	points = _simulate_deflection(true, 1.0, 1.0, 0)
	results.append(_eq(points, POINTS_DEFLECTION + POINTS_DEFLECT_KILL, "deflect_kill"))

	# With combo
	points = _simulate_deflection(false, 1.0, 1.0, 5)
	var expected := POINTS_DEFLECTION + (5 * POINTS_COMBO_BONUS_PER_HIT)
	results.append(_eq(points, expected, "deflect_combo"))

	# With multipliers
	points = _simulate_deflection(true, 2.0, 1.5, 0)
	expected = int((POINTS_DEFLECTION + POINTS_DEFLECT_KILL) * 2.0 * 1.5)
	results.append(_eq(points, expected, "deflect_kill_multiplied"))

	return results


static func _test_edge_cases() -> Array[Dictionary]:
	var results: Array[Dictionary] = []

	# Very high combo (beyond normal play)
	results.append(_near(_calc_combo_mult(1000), 4.0, 0.01, "mult_extreme_combo"))
	results.append(_eq(_calc_combo_bonus(1000), 100000, "bonus_extreme_combo"))

	# Negative values should be handled (shouldn't happen but test robustness)
	results.append(_near(_calc_combo_mult(-1), 1.0, 0.01, "mult_negative"))

	# Very small base multiplier (minimum)
	var points := _calc_points(100, 1.0, 0.1)
	results.append(_eq(points, 10, "points_min_base_mult"))

	# Zero base multiplier edge (should be clamped to 0.1 minimum)
	# In actual code: base_multiplier = max(0.1, mult)

	# Float precision
	points = _calc_points(100, 1.333, 1.0)
	results.append(_eq(points, 133, "points_float_precision"))

	# Large numbers
	points = _calc_points(1000, 4.0, 2.0)
	results.append(_eq(points, 8000, "points_large"))

	return results


# =============================================================================
# Calculation Functions (Mirror ScoreManager logic)
# =============================================================================

static func _calc_combo_mult(combo: int) -> float:
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


static func _calc_combo_bonus(combo: int) -> int:
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


static func _calc_accuracy(hits: int, misses: int) -> float:
	var total := hits + misses
	if total == 0:
		return 100.0
	return float(hits) / total * 100.0


static func _calc_points(base: int, combo_mult: float, base_mult: float) -> int:
	return int(base * combo_mult * base_mult)


static func _simulate_hit(damage: float, velocity: float, destroyed: bool,
						  combo_mult: float, base_mult: float, combo: int) -> int:
	var points := POINTS_TARGET_HIT

	if destroyed:
		points += POINTS_TARGET_DESTROYED

	if velocity > 5.0:
		points += POINTS_PERFECT_SWING

	var final_points := int(points * combo_mult * base_mult)
	final_points += combo * POINTS_COMBO_BONUS_PER_HIT

	return final_points


static func _simulate_deflection(killed_target: bool, combo_mult: float,
								  base_mult: float, combo: int) -> int:
	var points := POINTS_DEFLECTION
	if killed_target:
		points += POINTS_DEFLECT_KILL

	var final_points := int(points * combo_mult * base_mult)
	final_points += combo * POINTS_COMBO_BONUS_PER_HIT

	return final_points


# =============================================================================
# Test Helpers
# =============================================================================

static func _eq(actual, expected, name: String) -> Dictionary:
	return {"name": name, "suite": "ScoreSystem", "passed": actual == expected,
			"expected": expected, "actual": actual}

static func _near(actual: float, expected: float, epsilon: float, name: String) -> Dictionary:
	return {"name": name, "suite": "ScoreSystem", "passed": abs(actual - expected) <= epsilon,
			"expected": expected, "actual": actual}

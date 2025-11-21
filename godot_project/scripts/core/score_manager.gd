## ScoreManager - Tracks score, combos, and multipliers
## Autoloaded as "ScoreManager"
extends Node

signal score_changed(new_score: int, delta: int)
signal combo_changed(combo: int)
signal combo_ended(final_combo: int, bonus: int)
signal multiplier_changed(multiplier: float)
signal high_score_achieved(score: int)

# Current session
var current_score := 0
var current_combo := 0
var combo_multiplier := 1.0
var base_multiplier := 1.0

# Combo timing
var combo_timeout := 2.0  # Seconds before combo resets
var _combo_timer := 0.0
var is_combo_active := false

# Streak tracking
var hits_this_session := 0
var deflections_this_session := 0
var misses_this_session := 0

# High scores
var high_score := 0
var best_combo := 0

# Score values
const POINTS_TARGET_HIT := 100
const POINTS_TARGET_DESTROYED := 250
const POINTS_DEFLECTION := 150
const POINTS_DEFLECT_KILL := 500
const POINTS_PERFECT_SWING := 50  # High velocity hit
const POINTS_COMBO_BONUS_PER_HIT := 10


func _ready() -> void:
	_load_high_scores()

	GameEvents.target_hit.connect(_on_target_hit)
	GameEvents.session_started.connect(_on_session_started)
	GameEvents.session_ended.connect(_on_session_ended)


func _process(delta: float) -> void:
	if is_combo_active:
		_combo_timer -= delta
		if _combo_timer <= 0:
			_end_combo()


func _on_session_started(_session_id: String) -> void:
	reset()


func _on_session_ended(_session_id: String, _summary: Dictionary) -> void:
	_check_high_score()


func reset() -> void:
	current_score = 0
	current_combo = 0
	combo_multiplier = 1.0
	is_combo_active = false
	_combo_timer = 0.0
	hits_this_session = 0
	deflections_this_session = 0
	misses_this_session = 0


## Add points with combo calculation
func add_points(base_points: int, combo_eligible: bool = true) -> int:
	var final_points := int(base_points * combo_multiplier * base_multiplier)

	if combo_eligible:
		_extend_combo()
		final_points += current_combo * POINTS_COMBO_BONUS_PER_HIT

	current_score += final_points
	score_changed.emit(current_score, final_points)

	return final_points


## Register a target hit
func register_hit(damage: float, velocity: float, destroyed: bool) -> int:
	hits_this_session += 1

	var points := POINTS_TARGET_HIT

	# Bonus for destruction
	if destroyed:
		points += POINTS_TARGET_DESTROYED

	# Perfect swing bonus (high velocity)
	if velocity > 5.0:
		points += POINTS_PERFECT_SWING

	return add_points(points, true)


## Register a deflection
func register_deflection(killed_target: bool) -> int:
	deflections_this_session += 1

	var points := POINTS_DEFLECTION
	if killed_target:
		points += POINTS_DEFLECT_KILL

	return add_points(points, true)


## Register a miss (breaks combo)
func register_miss() -> void:
	misses_this_session += 1
	_end_combo()


## Set base multiplier (for difficulty, etc.)
func set_base_multiplier(mult: float) -> void:
	base_multiplier = max(0.1, mult)
	multiplier_changed.emit(combo_multiplier * base_multiplier)


func get_accuracy() -> float:
	var total := hits_this_session + misses_this_session
	if total == 0:
		return 100.0
	return float(hits_this_session) / total * 100.0


func get_session_stats() -> Dictionary:
	return {
		"score": current_score,
		"hits": hits_this_session,
		"deflections": deflections_this_session,
		"misses": misses_this_session,
		"accuracy": get_accuracy(),
		"best_combo": best_combo,
		"high_score": high_score
	}


func _extend_combo() -> void:
	current_combo += 1
	_combo_timer = combo_timeout
	is_combo_active = true

	# Update multiplier based on combo
	combo_multiplier = _calculate_combo_multiplier(current_combo)

	combo_changed.emit(current_combo)
	multiplier_changed.emit(combo_multiplier * base_multiplier)

	# Track best combo
	if current_combo > best_combo:
		best_combo = current_combo

	# Combo achievements
	if current_combo == 10:
		Achievements.unlock("combo_10")
	elif current_combo == 25:
		Achievements.unlock("combo_25")


func _end_combo() -> void:
	if not is_combo_active:
		return

	var final_combo := current_combo
	var bonus := _calculate_combo_bonus(final_combo)

	if bonus > 0:
		current_score += bonus
		score_changed.emit(current_score, bonus)

	combo_ended.emit(final_combo, bonus)

	current_combo = 0
	combo_multiplier = 1.0
	is_combo_active = false

	combo_changed.emit(0)
	multiplier_changed.emit(base_multiplier)


func _calculate_combo_multiplier(combo: int) -> float:
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


func _calculate_combo_bonus(combo: int) -> int:
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


func _check_high_score() -> void:
	if current_score > high_score:
		high_score = current_score
		_save_high_scores()
		high_score_achieved.emit(high_score)


func _load_high_scores() -> void:
	var stats := SessionManager.get_lifetime_stats()
	high_score = stats.get("high_score", 0)
	best_combo = stats.get("best_combo", 0)


func _save_high_scores() -> void:
	# Would save via SessionManager
	pass


func _on_target_hit(target: Node3D, damage: float, _position: Vector3) -> void:
	var frame := MovementTracker.get_current_frame()
	var velocity := 0.0
	if frame:
		velocity = max(frame.left_velocity.length(), frame.right_velocity.length())

	var destroyed := false
	if target is TrainingTarget:
		destroyed = target.is_destroyed

	register_hit(damage, velocity, destroyed)

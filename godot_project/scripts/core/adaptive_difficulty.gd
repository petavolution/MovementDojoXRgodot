## AdaptiveDifficulty - Dynamic difficulty adjustment based on player performance
## Keeps the game challenging but not frustrating
class_name AdaptiveDifficulty
extends Node

signal difficulty_changed(old_level: float, new_level: float)
signal difficulty_zone_changed(zone: DifficultyZone)

enum DifficultyZone { EASY, NORMAL, HARD, EXTREME }

## Current difficulty level (0.0 - 1.0)
var difficulty_level: float = 0.5

## Performance tracking
var recent_hits: Array[bool] = []
var recent_reaction_times: Array[float] = []
var recent_scores: Array[int] = []

const HISTORY_SIZE := 20
const ADJUSTMENT_INTERVAL := 5.0  # Seconds between adjustments

## Difficulty parameters
var target_accuracy: float = 0.75  # Target 75% hit rate
var accuracy_tolerance: float = 0.1  # +/- 10%

## Difficulty ranges for different zones
const ZONE_THRESHOLDS := {
	DifficultyZone.EASY: 0.0,
	DifficultyZone.NORMAL: 0.3,
	DifficultyZone.HARD: 0.6,
	DifficultyZone.EXTREME: 0.85
}

## Game parameters affected by difficulty
class DifficultyParams:
	var target_speed: float = 1.0
	var target_lifetime: float = 3.0
	var spawn_rate: float = 1.0
	var projectile_speed: float = 1.0
	var target_size_multiplier: float = 1.0
	var score_multiplier: float = 1.0
	var combo_decay_rate: float = 1.0
	var grace_period: float = 0.5


var current_params: DifficultyParams
var adjustment_timer: float = 0.0

## Player skill estimation
var estimated_skill: float = 0.5
var skill_confidence: float = 0.0  # 0-1, increases with more data

## Bounds
@export var min_difficulty: float = 0.1
@export var max_difficulty: float = 1.0
@export var adjustment_rate: float = 0.05  # Max change per adjustment


func _ready() -> void:
	current_params = DifficultyParams.new()
	_update_params()


func _process(delta: float) -> void:
	adjustment_timer += delta

	if adjustment_timer >= ADJUSTMENT_INTERVAL:
		adjustment_timer = 0.0
		_evaluate_and_adjust()


## Record a hit/miss
func record_hit(was_hit: bool, reaction_time: float = 0.0, score: int = 0) -> void:
	recent_hits.append(was_hit)
	if recent_hits.size() > HISTORY_SIZE:
		recent_hits.pop_front()

	if reaction_time > 0:
		recent_reaction_times.append(reaction_time)
		if recent_reaction_times.size() > HISTORY_SIZE:
			recent_reaction_times.pop_front()

	if score > 0:
		recent_scores.append(score)
		if recent_scores.size() > HISTORY_SIZE:
			recent_scores.pop_front()


func _evaluate_and_adjust() -> void:
	if recent_hits.size() < 5:
		return  # Not enough data

	var old_level := difficulty_level

	# Calculate current accuracy
	var hits := 0
	for hit in recent_hits:
		if hit:
			hits += 1
	var accuracy := float(hits) / recent_hits.size()

	# Calculate average reaction time
	var avg_reaction := 0.0
	if recent_reaction_times.size() > 0:
		for rt in recent_reaction_times:
			avg_reaction += rt
		avg_reaction /= recent_reaction_times.size()

	# Estimate player skill
	_update_skill_estimate(accuracy, avg_reaction)

	# Adjust difficulty based on performance
	var target_low := target_accuracy - accuracy_tolerance
	var target_high := target_accuracy + accuracy_tolerance

	if accuracy > target_high:
		# Player doing too well, increase difficulty
		var excess := accuracy - target_high
		var adjustment := adjustment_rate * (1.0 + excess * 2)
		difficulty_level = minf(difficulty_level + adjustment, max_difficulty)

	elif accuracy < target_low:
		# Player struggling, decrease difficulty
		var deficit := target_low - accuracy
		var adjustment := adjustment_rate * (1.0 + deficit * 2)
		difficulty_level = maxf(difficulty_level - adjustment, min_difficulty)

	# Apply skill-based smoothing
	difficulty_level = lerpf(difficulty_level, estimated_skill, 0.1)

	# Clamp to bounds
	difficulty_level = clampf(difficulty_level, min_difficulty, max_difficulty)

	if abs(difficulty_level - old_level) > 0.01:
		_update_params()
		difficulty_changed.emit(old_level, difficulty_level)

		# Check for zone change
		var old_zone := _get_zone(old_level)
		var new_zone := _get_zone(difficulty_level)
		if old_zone != new_zone:
			difficulty_zone_changed.emit(new_zone)


func _update_skill_estimate(accuracy: float, reaction_time: float) -> void:
	# Combine accuracy and reaction time into skill estimate
	var accuracy_skill := accuracy
	var reaction_skill := 1.0 - clampf(reaction_time / 2.0, 0.0, 1.0)  # 2 seconds = 0 skill

	var new_estimate := (accuracy_skill * 0.7 + reaction_skill * 0.3)

	# Weighted average with existing estimate
	skill_confidence = minf(skill_confidence + 0.1, 1.0)
	estimated_skill = lerpf(estimated_skill, new_estimate, 0.3 * skill_confidence)


func _update_params() -> void:
	var d := difficulty_level

	# Target speed: 0.5x at easy, 2.0x at hard
	current_params.target_speed = lerpf(0.5, 2.0, d)

	# Target lifetime: 5s at easy, 1.5s at hard
	current_params.target_lifetime = lerpf(5.0, 1.5, d)

	# Spawn rate: 0.5/s at easy, 2.0/s at hard
	current_params.spawn_rate = lerpf(0.5, 2.0, d)

	# Projectile speed: slower at easy
	current_params.projectile_speed = lerpf(0.6, 1.5, d)

	# Target size: larger at easy
	current_params.target_size_multiplier = lerpf(1.3, 0.8, d)

	# Score multiplier: higher at hard
	current_params.score_multiplier = lerpf(0.8, 1.5, d)

	# Combo decay: slower at easy
	current_params.combo_decay_rate = lerpf(0.7, 1.3, d)

	# Grace period for hits: longer at easy
	current_params.grace_period = lerpf(0.8, 0.2, d)


func _get_zone(level: float) -> DifficultyZone:
	if level >= ZONE_THRESHOLDS[DifficultyZone.EXTREME]:
		return DifficultyZone.EXTREME
	elif level >= ZONE_THRESHOLDS[DifficultyZone.HARD]:
		return DifficultyZone.HARD
	elif level >= ZONE_THRESHOLDS[DifficultyZone.NORMAL]:
		return DifficultyZone.NORMAL
	return DifficultyZone.EASY


## Get current difficulty parameters
func get_params() -> DifficultyParams:
	return current_params


func get_zone() -> DifficultyZone:
	return _get_zone(difficulty_level)


func get_zone_name() -> String:
	match get_zone():
		DifficultyZone.EASY: return "Easy"
		DifficultyZone.NORMAL: return "Normal"
		DifficultyZone.HARD: return "Hard"
		DifficultyZone.EXTREME: return "Extreme"
	return "Unknown"


## Manual difficulty control
func set_difficulty(level: float) -> void:
	var old := difficulty_level
	difficulty_level = clampf(level, min_difficulty, max_difficulty)
	_update_params()
	difficulty_changed.emit(old, difficulty_level)


func increase_difficulty(amount: float = 0.1) -> void:
	set_difficulty(difficulty_level + amount)


func decrease_difficulty(amount: float = 0.1) -> void:
	set_difficulty(difficulty_level - amount)


## Reset for new session
func reset() -> void:
	recent_hits.clear()
	recent_reaction_times.clear()
	recent_scores.clear()
	difficulty_level = estimated_skill  # Start at estimated skill level
	_update_params()


## Apply difficulty to a target spawner
func apply_to_spawner(spawner: TargetSpawner) -> void:
	if spawner == null:
		return

	spawner.difficulty = difficulty_level
	spawner.spawn_interval = 1.0 / current_params.spawn_rate


## Apply difficulty to a projectile launcher
func apply_to_launcher(launcher: ProjectileLauncher) -> void:
	if launcher == null:
		return

	launcher.projectile_speed_multiplier = current_params.projectile_speed


## Get scaled score
func scale_score(base_score: int) -> int:
	return int(base_score * current_params.score_multiplier)


## Get target lifetime adjusted for difficulty
func get_target_lifetime(base_lifetime: float) -> float:
	return base_lifetime * (current_params.target_lifetime / 3.0)


## Serialize state
func to_dict() -> Dictionary:
	return {
		"difficulty_level": difficulty_level,
		"estimated_skill": estimated_skill,
		"skill_confidence": skill_confidence
	}


func from_dict(data: Dictionary) -> void:
	difficulty_level = data.get("difficulty_level", 0.5)
	estimated_skill = data.get("estimated_skill", 0.5)
	skill_confidence = data.get("skill_confidence", 0.0)
	_update_params()

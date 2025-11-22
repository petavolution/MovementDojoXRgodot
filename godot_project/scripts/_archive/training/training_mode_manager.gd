## TrainingModeManager - Manages structured training sessions
## Handles different training modes, progression, and scoring
class_name TrainingModeManager
extends Node

signal mode_started(mode: TrainingMode)
signal mode_ended(mode: TrainingMode, results: TrainingResults)
signal wave_started(wave_number: int, total_waves: int)
signal wave_completed(wave_number: int, wave_score: int)
signal target_hit(target: TrainingTarget, score: int)
signal target_missed(target: TrainingTarget)
signal perfect_hit(target: TrainingTarget)
signal combo_achieved(combo: int)

enum TrainingMode {
	FREE_PLAY,
	BEGINNER_DRILLS,
	INTERMEDIATE_TRAINING,
	ADVANCED_COMBAT,
	ENDURANCE,
	PRECISION,
	SPEED,
	MOVEMENT_FOCUS,
	DEFLECTION_TRAINING,
	FORCE_MASTERY,
	WELLNESS_WARMUP,
	CUSTOM
}

## Training results container
class TrainingResults:
	var mode: TrainingMode
	var duration_seconds: float = 0.0
	var targets_spawned: int = 0
	var targets_hit: int = 0
	var targets_missed: int = 0
	var perfect_hits: int = 0
	var total_score: int = 0
	var max_combo: int = 0
	var accuracy: float = 0.0
	var average_reaction_time: float = 0.0
	var calories_estimate: float = 0.0
	var movement_coverage: float = 0.0
	var zones_discovered: int = 0

	func calculate_accuracy() -> void:
		if targets_spawned > 0:
			accuracy = float(targets_hit) / float(targets_spawned) * 100.0

	func to_dict() -> Dictionary:
		return {
			"mode": mode,
			"duration": duration_seconds,
			"targets_spawned": targets_spawned,
			"targets_hit": targets_hit,
			"targets_missed": targets_missed,
			"perfect_hits": perfect_hits,
			"total_score": total_score,
			"max_combo": max_combo,
			"accuracy": accuracy,
			"avg_reaction_time": average_reaction_time,
			"calories": calories_estimate,
			"coverage": movement_coverage,
			"zones": zones_discovered
		}


## Mode configurations
class ModeConfig:
	var name: String
	var description: String
	var wave_count: int = 5
	var targets_per_wave: int = 10
	var target_lifetime: float = 3.0
	var spawn_interval: float = 1.0
	var difficulty_ramp: float = 0.1
	var enable_projectiles: bool = false
	var projectile_ratio: float = 0.0
	var required_zones: Array[Vector3] = []
	var movement_bonus: bool = false
	var precision_mode: bool = false
	var time_limit: float = 0.0  # 0 = no limit


var current_mode: TrainingMode = TrainingMode.FREE_PLAY
var current_config: ModeConfig
var current_results: TrainingResults
var is_active: bool = false

var current_wave: int = 0
var targets_in_wave: int = 0
var targets_hit_in_wave: int = 0

var session_timer: float = 0.0
var spawn_timer: float = 0.0
var reaction_times: Array[float] = []

# References
var target_spawner: TargetSpawner
var projectile_launcher: ProjectileLauncher
var movement_tracker: Node  # MovementTracker autoload
var score_manager: Node  # ScoreManager autoload
var calibration: CalibrationSystem

# Mode configurations
var mode_configs: Dictionary = {}


func _ready() -> void:
	_setup_mode_configs()


func _setup_mode_configs() -> void:
	# Free Play
	var free := ModeConfig.new()
	free.name = "Free Play"
	free.description = "Practice at your own pace with no time limits."
	free.wave_count = 0
	free.target_lifetime = 5.0
	free.spawn_interval = 2.0
	mode_configs[TrainingMode.FREE_PLAY] = free

	# Beginner Drills
	var beginner := ModeConfig.new()
	beginner.name = "Beginner Drills"
	beginner.description = "Learn the basics with slow, predictable targets."
	beginner.wave_count = 3
	beginner.targets_per_wave = 8
	beginner.target_lifetime = 4.0
	beginner.spawn_interval = 1.5
	beginner.difficulty_ramp = 0.05
	mode_configs[TrainingMode.BEGINNER_DRILLS] = beginner

	# Intermediate Training
	var intermediate := ModeConfig.new()
	intermediate.name = "Intermediate Training"
	intermediate.description = "Step up your skills with faster targets."
	intermediate.wave_count = 5
	intermediate.targets_per_wave = 12
	intermediate.target_lifetime = 3.0
	intermediate.spawn_interval = 1.0
	intermediate.difficulty_ramp = 0.1
	mode_configs[TrainingMode.INTERMEDIATE_TRAINING] = intermediate

	# Advanced Combat
	var advanced := ModeConfig.new()
	advanced.name = "Advanced Combat"
	advanced.description = "Face rapid targets and incoming projectiles."
	advanced.wave_count = 7
	advanced.targets_per_wave = 15
	advanced.target_lifetime = 2.5
	advanced.spawn_interval = 0.8
	advanced.difficulty_ramp = 0.15
	advanced.enable_projectiles = true
	advanced.projectile_ratio = 0.3
	mode_configs[TrainingMode.ADVANCED_COMBAT] = advanced

	# Endurance
	var endurance := ModeConfig.new()
	endurance.name = "Endurance"
	endurance.description = "How long can you last? Targets never stop."
	endurance.wave_count = 0  # Infinite
	endurance.target_lifetime = 3.0
	endurance.spawn_interval = 1.2
	endurance.difficulty_ramp = 0.02  # Slow ramp
	mode_configs[TrainingMode.ENDURANCE] = endurance

	# Precision
	var precision := ModeConfig.new()
	precision.name = "Precision"
	precision.description = "Hit targets in their exact center for bonus points."
	precision.wave_count = 5
	precision.targets_per_wave = 10
	precision.target_lifetime = 4.0
	precision.spawn_interval = 1.5
	precision.precision_mode = true
	mode_configs[TrainingMode.PRECISION] = precision

	# Speed
	var speed := ModeConfig.new()
	speed.name = "Speed"
	speed.description = "React fast! Targets disappear quickly."
	speed.wave_count = 5
	speed.targets_per_wave = 15
	speed.target_lifetime = 1.5
	speed.spawn_interval = 0.6
	speed.difficulty_ramp = 0.1
	mode_configs[TrainingMode.SPEED] = speed

	# Movement Focus
	var movement := ModeConfig.new()
	movement.name = "Movement Focus"
	movement.description = "Targets spawn in unexplored zones. Move your whole body!"
	movement.wave_count = 5
	movement.targets_per_wave = 12
	movement.target_lifetime = 4.0
	movement.spawn_interval = 1.2
	movement.movement_bonus = true
	mode_configs[TrainingMode.MOVEMENT_FOCUS] = movement

	# Deflection Training
	var deflection := ModeConfig.new()
	deflection.name = "Deflection Training"
	deflection.description = "Deflect incoming projectiles with your saber."
	deflection.wave_count = 5
	deflection.targets_per_wave = 0
	deflection.enable_projectiles = true
	deflection.projectile_ratio = 1.0
	mode_configs[TrainingMode.DEFLECTION_TRAINING] = deflection

	# Force Mastery
	var force := ModeConfig.new()
	force.name = "Force Mastery"
	force.description = "Use Force push and pull to manipulate targets."
	force.wave_count = 5
	force.targets_per_wave = 10
	force.target_lifetime = 5.0
	force.spawn_interval = 1.5
	mode_configs[TrainingMode.FORCE_MASTERY] = force

	# Wellness Warmup
	var wellness := ModeConfig.new()
	wellness.name = "Wellness Warmup"
	wellness.description = "Gentle movements to warm up before intense training."
	wellness.wave_count = 3
	wellness.targets_per_wave = 6
	wellness.target_lifetime = 5.0
	wellness.spawn_interval = 2.0
	wellness.difficulty_ramp = 0.0
	mode_configs[TrainingMode.WELLNESS_WARMUP] = wellness


func setup(spawner: TargetSpawner, launcher: ProjectileLauncher = null, cal: CalibrationSystem = null) -> void:
	target_spawner = spawner
	projectile_launcher = launcher
	calibration = cal

	if target_spawner:
		target_spawner.target_destroyed.connect(_on_target_destroyed)
		target_spawner.target_missed.connect(_on_target_missed)


func start_mode(mode: TrainingMode) -> void:
	if is_active:
		end_mode()

	current_mode = mode
	current_config = mode_configs.get(mode, mode_configs[TrainingMode.FREE_PLAY])

	current_results = TrainingResults.new()
	current_results.mode = mode

	current_wave = 0
	targets_in_wave = 0
	targets_hit_in_wave = 0
	session_timer = 0.0
	spawn_timer = 0.0
	reaction_times.clear()

	is_active = true
	mode_started.emit(mode)

	if current_config.wave_count > 0:
		_start_wave()
	else:
		# Continuous mode (free play, endurance)
		_spawn_target()


func end_mode() -> void:
	if not is_active:
		return

	is_active = false
	current_results.duration_seconds = session_timer
	current_results.calculate_accuracy()

	if reaction_times.size() > 0:
		var sum := 0.0
		for rt in reaction_times:
			sum += rt
		current_results.average_reaction_time = sum / reaction_times.size()

	# Get movement data
	if movement_tracker and movement_tracker.has_method("get_session_stats"):
		var stats: Dictionary = movement_tracker.get_session_stats()
		current_results.movement_coverage = stats.get("space_coverage", 0.0)
		current_results.zones_discovered = stats.get("zones_discovered", 0)

	# Estimate calories (rough: ~5 cal per minute of active VR)
	current_results.calories_estimate = (session_timer / 60.0) * 5.0

	if target_spawner:
		target_spawner.stop_spawning()

	mode_ended.emit(current_mode, current_results)


func _process(delta: float) -> void:
	if not is_active:
		return

	session_timer += delta

	# Check time limit
	if current_config.time_limit > 0 and session_timer >= current_config.time_limit:
		end_mode()
		return

	# Spawn logic for continuous modes
	if current_config.wave_count == 0:
		spawn_timer += delta
		if spawn_timer >= current_config.spawn_interval:
			spawn_timer = 0.0
			_spawn_target()


func _start_wave() -> void:
	current_wave += 1
	targets_in_wave = 0
	targets_hit_in_wave = 0

	wave_started.emit(current_wave, current_config.wave_count)

	# Adjust difficulty for this wave
	var wave_difficulty := current_config.difficulty_ramp * (current_wave - 1)
	if target_spawner:
		target_spawner.difficulty = clampf(wave_difficulty, 0.0, 1.0)

	# Spawn targets for wave
	_spawn_wave_targets()


func _spawn_wave_targets() -> void:
	if not is_active or target_spawner == null:
		return

	var remaining := current_config.targets_per_wave - targets_in_wave

	if remaining <= 0:
		return

	# Spawn one target
	if current_config.enable_projectiles and randf() < current_config.projectile_ratio:
		if projectile_launcher:
			projectile_launcher.launch_projectile()
	else:
		_spawn_target()

	targets_in_wave += 1
	current_results.targets_spawned += 1

	# Schedule next spawn
	if targets_in_wave < current_config.targets_per_wave:
		var timer := get_tree().create_timer(current_config.spawn_interval)
		timer.timeout.connect(_spawn_wave_targets)


func _spawn_target() -> void:
	if target_spawner == null:
		return

	var spawn_pos: Vector3

	if current_config.movement_bonus and movement_tracker:
		# Spawn in unexplored zones
		if movement_tracker.has_method("get_least_visited_zone"):
			spawn_pos = movement_tracker.get_least_visited_zone()
		else:
			spawn_pos = _get_random_spawn_position()
	else:
		spawn_pos = _get_random_spawn_position()

	# Adjust for calibration
	if calibration:
		spawn_pos = calibration.get_adjusted_target_position(spawn_pos, target_spawner.difficulty)

	target_spawner.spawn_target_at(spawn_pos)
	current_results.targets_spawned += 1


func _get_random_spawn_position() -> Vector3:
	var angle := randf() * TAU
	var distance := randf_range(1.0, 2.0)
	var height := randf_range(0.5, 1.8)

	return Vector3(
		cos(angle) * distance,
		height,
		sin(angle) * distance - 1.5  # Offset forward
	)


func _on_target_destroyed(target: TrainingTarget, hit_velocity: float) -> void:
	if not is_active:
		return

	current_results.targets_hit += 1
	targets_hit_in_wave += 1

	# Calculate score based on mode
	var score := 100
	if current_config.precision_mode:
		# Bonus for center hits (would need hit position data)
		score = int(100 + hit_velocity * 10)

	if hit_velocity > 5.0:
		current_results.perfect_hits += 1
		score = int(score * 1.5)
		perfect_hit.emit(target)

	current_results.total_score += score
	target_hit.emit(target, score)

	# Track reaction time
	var lifetime := current_config.target_lifetime
	var time_alive := target.get_time_alive() if target.has_method("get_time_alive") else 0.0
	var reaction := lifetime - time_alive
	if reaction > 0:
		reaction_times.append(reaction)

	# Check wave completion
	_check_wave_completion()


func _on_target_missed(target: TrainingTarget) -> void:
	if not is_active:
		return

	current_results.targets_missed += 1
	target_missed.emit(target)

	_check_wave_completion()


func _check_wave_completion() -> void:
	if current_config.wave_count == 0:
		return  # Continuous mode

	var wave_total := targets_hit_in_wave + (current_results.targets_missed - (current_results.targets_spawned - targets_in_wave))

	if targets_in_wave >= current_config.targets_per_wave:
		# Wave complete
		var wave_score := targets_hit_in_wave * 100
		wave_completed.emit(current_wave, wave_score)

		if current_wave >= current_config.wave_count:
			# All waves complete
			end_mode()
		else:
			# Start next wave after delay
			var timer := get_tree().create_timer(2.0)
			timer.timeout.connect(_start_wave)


func get_current_results() -> TrainingResults:
	return current_results


func get_mode_config(mode: TrainingMode) -> ModeConfig:
	return mode_configs.get(mode)


func get_available_modes() -> Array[TrainingMode]:
	return [
		TrainingMode.FREE_PLAY,
		TrainingMode.BEGINNER_DRILLS,
		TrainingMode.INTERMEDIATE_TRAINING,
		TrainingMode.ADVANCED_COMBAT,
		TrainingMode.ENDURANCE,
		TrainingMode.PRECISION,
		TrainingMode.SPEED,
		TrainingMode.MOVEMENT_FOCUS,
		TrainingMode.DEFLECTION_TRAINING,
		TrainingMode.FORCE_MASTERY,
		TrainingMode.WELLNESS_WARMUP
	]

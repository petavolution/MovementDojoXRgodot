## TrainingSequenceController - Execution engine for data-driven training sequences
## Steps through Sequence → Phase → Wave, managing spawning and completion
##
## Design: Stateless configuration, stateful execution
## Load a TrainingSequence resource, call start(), respond to signals
class_name TrainingSequenceController
extends Node

const SOURCE := "TrnSeqCtrl"

# =============================================================================
# SIGNALS
# =============================================================================

## Sequence lifecycle
signal sequence_loaded(sequence: TrainingSequence)
signal sequence_started(sequence: TrainingSequence)
signal sequence_completed(sequence: TrainingSequence, results: Dictionary)
signal sequence_aborted(sequence: TrainingSequence, reason: String)

## Phase lifecycle
signal phase_started(phase: TrainingPhase, phase_index: int, total_phases: int)
signal phase_completed(phase: TrainingPhase, phase_stats: Dictionary)
signal phase_skipped(phase: TrainingPhase)

## Wave lifecycle
signal wave_started(wave: TrainingWave, wave_index: int, total_waves: int)
signal wave_completed(wave: TrainingWave, wave_stats: Dictionary)
signal wave_failed(wave: TrainingWave, reason: String)

## Progress updates
signal objective_progress(current: int, target: int, description: String)
signal feedback_message(message: String, message_type: String)  # type: info, success, warning, error

# =============================================================================
# STATE
# =============================================================================

enum ControllerState {
	IDLE,              # No sequence loaded or ready
	READY,             # Sequence loaded, waiting for start
	RUNNING,           # Actively executing
	PAUSED,            # Temporarily paused
	PHASE_TRANSITION,  # Between phases
	WAVE_TRANSITION,   # Between waves
	COMPLETED,         # Sequence finished successfully
	ABORTED,           # Sequence ended early
}

var state := ControllerState.IDLE

## Loaded sequence definition
var active_sequence: TrainingSequence

## Current position in sequence
var current_phase_index := -1
var current_wave_index := -1

## Convenience references
var current_phase: TrainingPhase:
	get:
		if active_sequence and current_phase_index >= 0 and current_phase_index < active_sequence.phases.size():
			return active_sequence.phases[current_phase_index]
		return null

var current_wave: TrainingWave:
	get:
		if current_phase and current_wave_index >= 0 and current_wave_index < current_phase.waves.size():
			return current_phase.waves[current_wave_index]
		return null

# =============================================================================
# TIMING
# =============================================================================

var sequence_start_time := 0.0
var phase_start_time := 0.0
var wave_start_time := 0.0

var sequence_elapsed := 0.0
var phase_elapsed := 0.0
var wave_elapsed := 0.0

# =============================================================================
# STATS TRACKING
# =============================================================================

## Overall sequence stats
var sequence_stats := {}

## Current phase stats
var phase_stats := {}

## Current wave stats
var wave_stats := {}

## Completion tracking for current wave
var wave_enemies_spawned := 0
var wave_enemies_destroyed := 0
var wave_projectiles_blocked := 0
var wave_hits_landed := 0

# =============================================================================
# DEPENDENCIES
# =============================================================================

## Spawner for creating enemies
var spawner: TrainingSpawner

## Feedback controller (optional, for UI updates)
var feedback_controller: Node

## Player target for spawner positioning
var player_target: Node3D

## Parent node for spawned entities
var spawn_parent: Node3D

# =============================================================================
# INTERNAL STATE
# =============================================================================

var _transition_timer: SceneTreeTimer
var _spawn_queue: Array[WaveSpawnEntry] = []
var _spawn_timer: SceneTreeTimer

# =============================================================================
# LIFECYCLE
# =============================================================================

func _ready() -> void:
	DebugLogger.debug(SOURCE, "TrainingSequenceController initialized")


func _process(delta: float) -> void:
	if state != ControllerState.RUNNING:
		return

	# Update elapsed timers
	sequence_elapsed += delta
	phase_elapsed += delta
	wave_elapsed += delta

	# Process current state
	_process_wave(delta)


func _exit_tree() -> void:
	if state == ControllerState.RUNNING:
		abort("Controller destroyed")


# =============================================================================
# SETUP
# =============================================================================

## Configure the controller with required dependencies
func setup(target: Node3D, parent: Node3D, feedback: Node = null) -> void:
	player_target = target
	spawn_parent = parent
	feedback_controller = feedback

	# Create spawner if needed
	if not spawner:
		spawner = TrainingSpawner.new()
		add_child(spawner)

	spawner.setup(target, parent)

	# Connect spawner signals
	spawner.enemy_destroyed.connect(_on_enemy_destroyed)
	spawner.projectile_blocked.connect(_on_projectile_blocked)
	spawner.projectile_hit_player.connect(_on_projectile_hit_player)
	spawner.all_enemies_destroyed.connect(_on_all_enemies_destroyed)
	spawner.dive_started.connect(_on_dive_started)
	spawner.dive_completed.connect(_on_dive_completed)

	DebugLogger.debug(SOURCE, "Controller configured")


# =============================================================================
# PUBLIC API
# =============================================================================

## Load a training sequence (does not start it)
func load_sequence(sequence: TrainingSequence) -> bool:
	if state == ControllerState.RUNNING:
		DebugLogger.warn(SOURCE, "Cannot load sequence while running")
		return false

	# Validate sequence
	var errors := sequence.validate()
	if not errors.is_empty():
		DebugLogger.error(SOURCE, "Invalid sequence '%s':" % sequence.sequence_id)
		for err in errors:
			DebugLogger.error(SOURCE, "  - %s" % err)
		return false

	active_sequence = sequence
	state = ControllerState.READY
	_reset_all_stats()

	DebugLogger.info(SOURCE, "Loaded sequence: %s" % sequence.get_summary())
	sequence_loaded.emit(sequence)

	return true


## Start the loaded sequence from the beginning
func start() -> void:
	if state != ControllerState.READY:
		DebugLogger.warn(SOURCE, "Cannot start - state is %s (need READY)" % ControllerState.keys()[state])
		return

	if not active_sequence:
		DebugLogger.error(SOURCE, "No sequence loaded")
		return

	DebugLogger.info(SOURCE, "")
	DebugLogger.info(SOURCE, "╔═══════════════════════════════════════════════════════════╗")
	DebugLogger.info(SOURCE, "║  TRAINING SEQUENCE: %s" % active_sequence.display_name.to_upper().substr(0, 40).rpad(40))
	DebugLogger.info(SOURCE, "╚═══════════════════════════════════════════════════════════╝")
	DebugLogger.info(SOURCE, "")

	sequence_start_time = Time.get_ticks_msec() / 1000.0
	sequence_elapsed = 0.0
	state = ControllerState.RUNNING

	sequence_started.emit(active_sequence)

	# Start first phase
	_advance_to_phase(0)


## Pause the sequence
func pause() -> void:
	if state != ControllerState.RUNNING:
		return

	state = ControllerState.PAUSED
	DebugLogger.info(SOURCE, "Sequence paused")


## Resume from paused state
func resume() -> void:
	if state != ControllerState.PAUSED:
		return

	state = ControllerState.RUNNING
	DebugLogger.info(SOURCE, "Sequence resumed")


## Abort the sequence early
func abort(reason: String = "") -> void:
	if state in [ControllerState.IDLE, ControllerState.COMPLETED, ControllerState.ABORTED]:
		return

	var abort_reason := reason if reason else "User abort"
	DebugLogger.warn(SOURCE, "")
	DebugLogger.warn(SOURCE, "═══ SEQUENCE ABORTED ═══")
	DebugLogger.warn(SOURCE, "Reason: %s" % abort_reason)
	DebugLogger.warn(SOURCE, "Phase: %d/%d (%s)" % [
		current_phase_index + 1,
		active_sequence.phases.size() if active_sequence else 0,
		current_phase.display_name if current_phase else "none"
	])
	DebugLogger.warn(SOURCE, "Wave: %d/%d (%s)" % [
		current_wave_index + 1,
		current_phase.waves.size() if current_phase else 0,
		current_wave.wave_id if current_wave else "none"
	])
	DebugLogger.warn(SOURCE, "Duration: %.1fs" % sequence_elapsed)

	# Cancel any pending timers
	_cancel_pending_timers()

	# Cleanup spawner
	if spawner:
		var metrics := spawner.end_wave()
		DebugLogger.debug(SOURCE, "Final wave metrics: %s" % str(metrics))

	_finalize_stats()
	state = ControllerState.ABORTED

	sequence_aborted.emit(active_sequence, abort_reason)


## Cancel any pending transition or spawn timers
func _cancel_pending_timers() -> void:
	if _transition_timer:
		# Can't cancel SceneTreeTimer, just null the reference
		_transition_timer = null
	if _spawn_timer:
		_spawn_timer = null
	_spawn_queue.clear()


## Skip to a specific phase (by index)
func skip_to_phase(phase_index: int) -> void:
	if state != ControllerState.RUNNING:
		return

	if phase_index < 0 or phase_index >= active_sequence.phases.size():
		DebugLogger.warn(SOURCE, "Invalid phase index: %d" % phase_index)
		return

	DebugLogger.info(SOURCE, "Skipping to phase %d" % phase_index)

	# Record skip in stats
	if current_phase:
		phase_skipped.emit(current_phase)

	_exit_current_phase()
	_advance_to_phase(phase_index)


## Skip the current wave
func skip_current_wave() -> void:
	if state != ControllerState.RUNNING or not current_wave:
		return

	DebugLogger.info(SOURCE, "Skipping wave: %s" % current_wave.wave_id)
	_complete_wave(false, "skipped")


## Skip the current phase
func skip_current_phase() -> void:
	if state != ControllerState.RUNNING or not current_phase:
		return

	DebugLogger.info(SOURCE, "Skipping phase: %s" % current_phase.phase_id)
	phase_skipped.emit(current_phase)
	_exit_current_phase()
	_advance_to_next_phase()


## Manually trigger wave completion (for MANUAL completion type)
func trigger_wave_complete() -> void:
	if current_wave and current_wave.completion_type == TrainingWave.CompletionType.MANUAL:
		_complete_wave(true, "manual trigger")


## Get current progress as dictionary
func get_progress() -> Dictionary:
	return {
		"state": ControllerState.keys()[state],
		"phase_index": current_phase_index,
		"phase_count": active_sequence.phases.size() if active_sequence else 0,
		"wave_index": current_wave_index,
		"wave_count": current_phase.waves.size() if current_phase else 0,
		"sequence_elapsed": sequence_elapsed,
		"phase_elapsed": phase_elapsed,
		"wave_elapsed": wave_elapsed,
	}


## Check if controller is currently running
func is_running() -> bool:
	return state == ControllerState.RUNNING


# =============================================================================
# PHASE MANAGEMENT
# =============================================================================

func _advance_to_phase(index: int) -> void:
	if index >= active_sequence.phases.size():
		_complete_sequence()
		return

	current_phase_index = index
	current_wave_index = -1

	var phase := current_phase
	phase_start_time = Time.get_ticks_msec() / 1000.0
	phase_elapsed = 0.0
	_reset_phase_stats()

	DebugLogger.info(SOURCE, "")
	DebugLogger.info(SOURCE, "=== PHASE %d/%d: %s ===" % [
		index + 1, active_sequence.phases.size(), phase.display_name
	])
	DebugLogger.info(SOURCE, "Type: %s | Waves: %d | Objective: %s" % [
		TrainingPhase.get_phase_type_name(phase.phase_type),
		phase.waves.size(),
		phase.objective_text if phase.objective_text else "(none)"
	])
	DebugLogger.info(SOURCE, "")

	# Show phase intro
	if phase.has_intro_message():
		feedback_message.emit(phase.intro_message, "info")

	phase_started.emit(phase, index, active_sequence.phases.size())

	# Handle non-combat phases
	if phase.is_non_combat():
		_handle_non_combat_phase(phase)
	elif phase.waves.is_empty():
		# No waves, complete immediately
		_complete_phase()
	else:
		# Start first wave
		_advance_to_wave(0)


func _handle_non_combat_phase(phase: TrainingPhase) -> void:
	match phase.completion_type:
		TrainingPhase.CompletionType.TIMED:
			# Auto-complete after duration
			_transition_timer = get_tree().create_timer(phase.timed_duration)
			_transition_timer.timeout.connect(_complete_phase)

		TrainingPhase.CompletionType.MANUAL:
			# Wait for external trigger or skip
			pass

		_:
			# Default: complete after brief delay
			_transition_timer = get_tree().create_timer(2.0)
			_transition_timer.timeout.connect(_complete_phase)


func _exit_current_phase() -> void:
	if spawner:
		spawner.despawn_all()

	# Cancel any pending timers
	if _transition_timer and _transition_timer.time_left > 0:
		_transition_timer = null

	# Record phase stats
	phase_stats["duration"] = phase_elapsed


func _advance_to_next_phase() -> void:
	_advance_to_phase(current_phase_index + 1)


func _complete_phase() -> void:
	var phase := current_phase
	if not phase:
		return

	phase_stats["duration"] = phase_elapsed

	DebugLogger.info(SOURCE, "Phase '%s' completed in %.1fs" % [phase.display_name, phase_elapsed])

	# Show success message
	if phase.success_message:
		feedback_message.emit(phase.success_message, "success")

	# Record in sequence stats
	sequence_stats["phases"][phase.phase_id] = phase_stats.duplicate()

	phase_completed.emit(phase, phase_stats.duplicate())

	_exit_current_phase()

	# Auto-advance or wait
	if phase.auto_advance:
		state = ControllerState.PHASE_TRANSITION
		_transition_timer = get_tree().create_timer(phase.advance_delay)
		_transition_timer.timeout.connect(_on_phase_transition_complete)
	else:
		# Wait for manual advance
		pass


func _on_phase_transition_complete() -> void:
	state = ControllerState.RUNNING
	_advance_to_next_phase()


# =============================================================================
# WAVE MANAGEMENT
# =============================================================================

func _advance_to_wave(index: int) -> void:
	if not current_phase or index >= current_phase.waves.size():
		_complete_phase()
		return

	current_wave_index = index
	var wave := current_wave

	wave_start_time = Time.get_ticks_msec() / 1000.0
	wave_elapsed = 0.0
	_reset_wave_stats()

	# Initialize spawner wave tracking
	if spawner:
		spawner.start_wave(wave.wave_id)

	DebugLogger.info(SOURCE, "")
	DebugLogger.info(SOURCE, "--- Wave %d/%d: %s ---" % [
		index + 1, current_phase.waves.size(), wave.wave_id
	])
	DebugLogger.info(SOURCE, "  Spawns: %s" % wave.get_spawn_summary())
	DebugLogger.info(SOURCE, "  Completion: %s" % wave.get_completion_description())

	# Show wave message
	if wave.start_message:
		feedback_message.emit(wave.start_message, "info")

	wave_started.emit(wave, index, current_phase.waves.size())

	# Start spawning after delay
	if wave.spawn_delay > 0:
		_spawn_timer = get_tree().create_timer(wave.spawn_delay)
		_spawn_timer.timeout.connect(_start_wave_spawning)
	else:
		_start_wave_spawning()


func _start_wave_spawning() -> void:
	var wave := current_wave
	if not wave:
		return

	if wave.spawn_simultaneous:
		# Spawn all entries at once
		for entry in wave.spawn_entries:
			_spawn_entry(entry)
		_on_wave_spawning_complete()
	else:
		# Queue entries for staggered spawning
		_spawn_queue = wave.spawn_entries.duplicate()
		_process_spawn_queue()


func _spawn_entry(entry: WaveSpawnEntry) -> void:
	if not spawner:
		DebugLogger.error(SOURCE, "No spawner available - cannot spawn enemies")
		return

	var enemies := spawner.spawn_from_entry(entry)
	wave_enemies_spawned += enemies.size()
	wave_stats["enemies_spawned"] = wave_enemies_spawned

	if enemies.is_empty() and entry.count > 0:
		DebugLogger.error(SOURCE, "Spawn failed for entry: %s" % entry.get_summary())


func _process_spawn_queue() -> void:
	if _spawn_queue.is_empty():
		_on_wave_spawning_complete()
		return

	var entry := _spawn_queue.pop_front()
	_spawn_entry(entry)

	# Schedule next spawn
	if not _spawn_queue.is_empty():
		var interval := current_wave.default_spawn_interval
		if entry.spawn_stagger > 0:
			interval = entry.spawn_stagger

		_spawn_timer = get_tree().create_timer(interval)
		_spawn_timer.timeout.connect(_process_spawn_queue)
	else:
		_on_wave_spawning_complete()


## Called when all spawn entries have been processed
func _on_wave_spawning_complete() -> void:
	if spawner:
		spawner.mark_spawning_complete()
	DebugLogger.debug(SOURCE, "Wave spawning complete: %d enemies total" % wave_enemies_spawned)


func _process_wave(_delta: float) -> void:
	var wave := current_wave
	if not wave:
		return

	# Check completion conditions
	var enemies_remaining := spawner.get_active_enemy_count() if spawner else 0
	var completion_value := _get_completion_value()

	if wave.check_completion(completion_value, enemies_remaining, wave_elapsed):
		_complete_wave(true, "objective met")
		return

	# Check timeout
	if wave.check_timeout(wave_elapsed):
		_complete_wave(wave.timeout_is_success, "timeout")
		return

	# Update progress for count-based completions
	if wave.show_progress and wave.completion_type in [
		TrainingWave.CompletionType.DESTROY_COUNT,
		TrainingWave.CompletionType.BLOCK_COUNT,
		TrainingWave.CompletionType.HIT_COUNT
	]:
		objective_progress.emit(
			completion_value,
			wave.completion_value,
			wave.get_completion_description()
		)


func _get_completion_value() -> int:
	var wave := current_wave
	if not wave:
		return 0

	match wave.completion_type:
		TrainingWave.CompletionType.DESTROY_ALL, TrainingWave.CompletionType.DESTROY_COUNT:
			return wave_enemies_destroyed
		TrainingWave.CompletionType.BLOCK_COUNT:
			return wave_projectiles_blocked
		TrainingWave.CompletionType.HIT_COUNT:
			return wave_hits_landed
		_:
			return 0


func _complete_wave(success: bool, reason: String) -> void:
	var wave := current_wave
	if not wave:
		return

	# Get metrics from spawner before cleanup
	var spawner_metrics := {}
	if spawner:
		spawner_metrics = spawner.end_wave()

	# Build comprehensive wave stats
	wave_stats["duration"] = wave_elapsed
	wave_stats["success"] = success
	wave_stats["completion_reason"] = reason
	wave_stats["enemies_spawned"] = spawner_metrics.get("enemies_spawned", wave_enemies_spawned)
	wave_stats["enemies_destroyed"] = spawner_metrics.get("enemies_killed", wave_enemies_destroyed)
	wave_stats["projectiles_blocked"] = spawner_metrics.get("projectiles_blocked", wave_projectiles_blocked)
	wave_stats["hits_taken"] = spawner_metrics.get("hits_taken", 0)

	# Log wave completion with metrics
	DebugLogger.info(SOURCE, "")
	if success:
		DebugLogger.info(SOURCE, "Wave '%s' COMPLETED: %s (%.1fs)" % [
			wave.wave_id, reason, wave_elapsed
		])
	else:
		DebugLogger.warn(SOURCE, "Wave '%s' FAILED: %s (%.1fs)" % [
			wave.wave_id, reason, wave_elapsed
		])

	DebugLogger.info(SOURCE, "  Metrics: spawned=%d, killed=%d, blocked=%d, hits_taken=%d" % [
		wave_stats["enemies_spawned"],
		wave_stats["enemies_destroyed"],
		wave_stats["projectiles_blocked"],
		wave_stats["hits_taken"]
	])

	# Show feedback message
	if success:
		if wave.complete_message:
			feedback_message.emit(wave.complete_message, "success")
		wave_completed.emit(wave, wave_stats.duplicate())
	else:
		if wave.timeout_message:
			feedback_message.emit(wave.timeout_message, "warning")
		wave_failed.emit(wave, reason)

	# Update phase stats with wave data
	phase_stats["enemies_destroyed"] = phase_stats.get("enemies_destroyed", 0) + wave_stats["enemies_destroyed"]
	phase_stats["projectiles_blocked"] = phase_stats.get("projectiles_blocked", 0) + wave_stats["projectiles_blocked"]
	phase_stats["hits_taken"] = phase_stats.get("hits_taken", 0) + wave_stats["hits_taken"]
	phase_stats["waves_completed"] = phase_stats.get("waves_completed", 0) + (1 if success else 0)

	# Advance to next wave after delay
	state = ControllerState.WAVE_TRANSITION
	var delay := current_phase.inter_wave_delay if current_phase else 1.0
	_transition_timer = get_tree().create_timer(delay)
	_transition_timer.timeout.connect(_on_wave_transition_complete)


func _on_wave_transition_complete() -> void:
	state = ControllerState.RUNNING
	_advance_to_wave(current_wave_index + 1)


# =============================================================================
# SEQUENCE COMPLETION
# =============================================================================

func _complete_sequence() -> void:
	_finalize_stats()
	state = ControllerState.COMPLETED

	DebugLogger.info(SOURCE, "")
	DebugLogger.info(SOURCE, "╔═══════════════════════════════════════════════════════════╗")
	DebugLogger.info(SOURCE, "║              SEQUENCE COMPLETE!                           ║")
	DebugLogger.info(SOURCE, "╚═══════════════════════════════════════════════════════════╝")
	DebugLogger.info(SOURCE, "")
	DebugLogger.info(SOURCE, "Total duration: %.1fs" % sequence_stats["total_duration"])
	DebugLogger.info(SOURCE, "Phases completed: %d" % sequence_stats["phases_completed"])
	DebugLogger.info(SOURCE, "")

	sequence_completed.emit(active_sequence, sequence_stats.duplicate())


func _finalize_stats() -> void:
	sequence_stats["total_duration"] = sequence_elapsed
	sequence_stats["phases_completed"] = current_phase_index + 1 if current_phase_index >= 0 else 0


# =============================================================================
# STATS MANAGEMENT
# =============================================================================

func _reset_all_stats() -> void:
	sequence_stats = {
		"total_duration": 0.0,
		"phases_completed": 0,
		"phases": {}
	}
	_reset_phase_stats()


func _reset_phase_stats() -> void:
	phase_stats = {
		"duration": 0.0,
		"waves_completed": 0,
		"enemies_destroyed": 0,
		"projectiles_blocked": 0,
		"hits_taken": 0,
	}
	_reset_wave_stats()


func _reset_wave_stats() -> void:
	wave_stats = {
		"duration": 0.0,
		"success": false,
		"enemies_spawned": 0,
		"enemies_destroyed": 0,
		"projectiles_blocked": 0,
	}
	wave_enemies_spawned = 0
	wave_enemies_destroyed = 0
	wave_projectiles_blocked = 0
	wave_hits_landed = 0


# =============================================================================
# EVENT HANDLERS (from spawner)
# =============================================================================

func _on_enemy_destroyed(_enemy: Node3D, by_player: bool) -> void:
	if not by_player:
		return

	wave_enemies_destroyed += 1
	wave_stats["enemies_destroyed"] = wave_enemies_destroyed
	phase_stats["enemies_destroyed"] = phase_stats.get("enemies_destroyed", 0) + 1

	DebugLogger.debug(SOURCE, "Enemy destroyed (%d/%d in wave)" % [
		wave_enemies_destroyed, wave_enemies_spawned
	])


func _on_projectile_blocked(_projectile: Node3D) -> void:
	wave_projectiles_blocked += 1
	wave_stats["projectiles_blocked"] = wave_projectiles_blocked
	phase_stats["projectiles_blocked"] = phase_stats.get("projectiles_blocked", 0) + 1

	DebugLogger.debug(SOURCE, "Projectile blocked (%d total)" % wave_projectiles_blocked)

	# Update progress for block objectives
	if current_wave and current_wave.completion_type == TrainingWave.CompletionType.BLOCK_COUNT:
		objective_progress.emit(
			wave_projectiles_blocked,
			current_wave.completion_value,
			"Block %d projectiles" % current_wave.completion_value
		)


func _on_projectile_hit_player(_projectile: Node3D) -> void:
	phase_stats["hits_taken"] = phase_stats.get("hits_taken", 0) + 1
	DebugLogger.debug(SOURCE, "Player hit by projectile")


func _on_all_enemies_destroyed() -> void:
	DebugLogger.debug(SOURCE, "All enemies destroyed")
	# Completion check happens in _process_wave


func _on_dive_started(_enemy: Node3D) -> void:
	feedback_message.emit("DIVE ATTACK INCOMING!", "warning")


func _on_dive_completed(_enemy: Node3D, hit_player: bool) -> void:
	if hit_player:
		phase_stats["hits_taken"] = phase_stats.get("hits_taken", 0) + 1
		feedback_message.emit("Dive hit!", "error")
	else:
		feedback_message.emit("Dive evaded!", "success")

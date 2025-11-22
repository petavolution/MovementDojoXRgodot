## Level1Controller - Dojo Training Level 1: Gentle Introduction
## State machine managing the "first training experience" flow
## Phases: INTRO → SABER_DRILL → BLASTER_DRILL → MIXED_DRILL → SUMMARY
##
## Design goals:
## - Relaxed, tutorial-like pacing
## - Clear state transitions with logging
## - Defensive coding (handles missing subsystems)
## - Easy to extend with actual gameplay later
extends Node
class_name Level1Controller

const SOURCE := "Level1"

# =============================================================================
# STATE MACHINE
# =============================================================================

enum Level1State {
	IDLE,           # Not started
	INTRO,          # Explain controls, show weapons
	SABER_DRILL,    # Practice saber strikes + blocking
	BLASTER_DRILL,  # Practice blaster aiming + shooting
	MIXED_DRILL,    # Combined: drones + projectiles + dive attack
	SUMMARY,        # Show stats, offer restart/exit
	COMPLETE        # Level finished, waiting for cleanup
}

# State names for logging
const STATE_NAMES := {
	Level1State.IDLE: "IDLE",
	Level1State.INTRO: "INTRO",
	Level1State.SABER_DRILL: "SABER_DRILL",
	Level1State.BLASTER_DRILL: "BLASTER_DRILL",
	Level1State.MIXED_DRILL: "MIXED_DRILL",
	Level1State.SUMMARY: "SUMMARY",
	Level1State.COMPLETE: "COMPLETE"
}

# =============================================================================
# CONFIGURATION
# =============================================================================

## Phase durations (seconds) - can be overridden
@export var intro_duration := 10.0
@export var auto_advance_intro := true  # Auto-advance after duration, or wait for input

## Drill completion requirements (placeholder - will be replaced with actual counts)
@export var saber_targets_required := 5
@export var saber_projectiles_required := 3
@export var blaster_targets_required := 4
@export var mixed_drones_required := 2
@export var mixed_dive_required := true

# =============================================================================
# SIGNALS
# =============================================================================

signal state_changed(old_state: Level1State, new_state: Level1State)
signal level_started()
signal level_completed(stats: Dictionary)
signal phase_completed(phase: Level1State, phase_stats: Dictionary)

# =============================================================================
# STATE
# =============================================================================

var current_state := Level1State.IDLE
var previous_state := Level1State.IDLE

# Timing
var level_start_time := 0.0
var state_start_time := 0.0
var state_elapsed := 0.0

# Stats tracking
var stats := {
	# Overall
	"total_duration": 0.0,
	"states_visited": [] as Array[String],

	# INTRO
	"intro_duration": 0.0,
	"intro_skipped": false,

	# SABER_DRILL
	"saber_targets_hit": 0,
	"saber_targets_missed": 0,
	"saber_projectiles_blocked": 0,
	"saber_projectiles_missed": 0,
	"saber_duration": 0.0,

	# BLASTER_DRILL
	"blaster_shots_fired": 0,
	"blaster_hits": 0,
	"blaster_misses": 0,
	"blaster_duration": 0.0,

	# MIXED_DRILL
	"mixed_drones_destroyed": 0,
	"mixed_dive_blocked": false,
	"mixed_duration": 0.0,
}

# XR References (set by parent scene)
var xr_origin: XROrigin3D
var xr_camera: XRCamera3D
var left_controller: XRController3D
var right_controller: XRController3D

# Weapon references (set by parent scene or found in tree)
var lightsaber: Node3D  # Lightsaber on right hand
var blaster: Node3D     # Blaster on left hand (may be null if not implemented)

# Environment reference
var dojo_environment: Node3D

# Active entities container
var active_entities: Node3D

# Drone spawner reference
var drone_spawner: Level1DroneSpawner

# Drill completion tracking
var _saber_drill_complete := false
var _blaster_drill_complete := false
var _mixed_drill_complete := false

# =============================================================================
# LIFECYCLE
# =============================================================================

func _ready() -> void:
	DebugLogger.info(SOURCE, "Level1Controller initialized")
	_reset_stats()


func _process(delta: float) -> void:
	if current_state == Level1State.IDLE or current_state == Level1State.COMPLETE:
		return

	state_elapsed += delta

	# Process current state
	match current_state:
		Level1State.INTRO:
			_process_intro(delta)
		Level1State.SABER_DRILL:
			_process_saber_drill(delta)
		Level1State.BLASTER_DRILL:
			_process_blaster_drill(delta)
		Level1State.MIXED_DRILL:
			_process_mixed_drill(delta)
		Level1State.SUMMARY:
			_process_summary(delta)


func _exit_tree() -> void:
	DebugLogger.info(SOURCE, "Level1Controller exiting")
	_cleanup_active_entities()


# =============================================================================
# PUBLIC API
# =============================================================================

## Start Level 1 from the beginning
func start_level() -> void:
	if current_state != Level1State.IDLE:
		DebugLogger.warn(SOURCE, "Cannot start level - already running (state: %s)" % STATE_NAMES[current_state])
		return

	DebugLogger.info(SOURCE, "")
	DebugLogger.info(SOURCE, "╔══════════════════════════════════════╗")
	DebugLogger.info(SOURCE, "║       LEVEL 1: DOJO TRAINING         ║")
	DebugLogger.info(SOURCE, "╚══════════════════════════════════════╝")
	DebugLogger.info(SOURCE, "")

	_reset_stats()
	level_start_time = Time.get_ticks_msec() / 1000.0

	level_started.emit()
	_change_state(Level1State.INTRO)


## Force transition to a specific state (for debugging)
func force_state(new_state: Level1State) -> void:
	DebugLogger.warn(SOURCE, "Force state transition: %s → %s" % [STATE_NAMES[current_state], STATE_NAMES[new_state]])
	_change_state(new_state)


## Skip current phase (for testing or accessibility)
func skip_current_phase() -> void:
	DebugLogger.info(SOURCE, "Skipping phase: %s" % STATE_NAMES[current_state])

	match current_state:
		Level1State.INTRO:
			stats.intro_skipped = true
			_change_state(Level1State.SABER_DRILL)
		Level1State.SABER_DRILL:
			_change_state(Level1State.BLASTER_DRILL)
		Level1State.BLASTER_DRILL:
			_change_state(Level1State.MIXED_DRILL)
		Level1State.MIXED_DRILL:
			_change_state(Level1State.SUMMARY)
		Level1State.SUMMARY:
			_change_state(Level1State.COMPLETE)


## Restart level from beginning
func restart_level() -> void:
	DebugLogger.info(SOURCE, "Restarting Level 1")
	_exit_current_state()
	current_state = Level1State.IDLE
	start_level()


## Get current state name
func get_state_name() -> String:
	return STATE_NAMES.get(current_state, "UNKNOWN")


## Check if level is active
func is_running() -> bool:
	return current_state != Level1State.IDLE and current_state != Level1State.COMPLETE


# =============================================================================
# SETUP
# =============================================================================

## Setup XR references (call before start_level)
func setup_xr(origin: XROrigin3D, camera: XRCamera3D, left: XRController3D, right: XRController3D) -> void:
	xr_origin = origin
	xr_camera = camera
	left_controller = left
	right_controller = right

	DebugLogger.debug(SOURCE, "XR references configured")


## Setup weapon references
func setup_weapons(saber: Node3D, blaster_node: Node3D = null) -> void:
	lightsaber = saber
	blaster = blaster_node

	var saber_status := "OK" if lightsaber else "MISSING"
	var blaster_status := "OK" if blaster else "MISSING (placeholder mode)"
	DebugLogger.debug(SOURCE, "Weapons: Saber=%s, Blaster=%s" % [saber_status, blaster_status])


## Setup environment reference
func setup_environment(env: Node3D) -> void:
	dojo_environment = env
	DebugLogger.debug(SOURCE, "Environment: %s" % ("OK" if dojo_environment else "MISSING"))


## Setup active entities container
func setup_entities_container(container: Node3D) -> void:
	active_entities = container
	DebugLogger.debug(SOURCE, "Entities container: %s" % ("OK" if active_entities else "MISSING"))


## Setup drone spawner reference
func setup_drone_spawner(spawner: Level1DroneSpawner) -> void:
	drone_spawner = spawner

	if drone_spawner:
		# Connect spawner signals for stats tracking
		drone_spawner.drone_destroyed.connect(_on_spawner_drone_destroyed)
		drone_spawner.projectile_blocked.connect(_on_spawner_projectile_blocked)
		drone_spawner.projectile_hit_player.connect(_on_spawner_projectile_hit_player)
		drone_spawner.dive_completed.connect(_on_spawner_dive_completed)
		drone_spawner.all_drones_destroyed.connect(_on_all_drones_destroyed)
		DebugLogger.debug(SOURCE, "Drone spawner: OK")
	else:
		DebugLogger.warn(SOURCE, "Drone spawner: MISSING (drills will use timeout mode)")


# =============================================================================
# STATE MACHINE
# =============================================================================

func _change_state(new_state: Level1State) -> void:
	if new_state == current_state:
		return

	previous_state = current_state
	var old_name := STATE_NAMES[previous_state]
	var new_name := STATE_NAMES[new_state]

	# Exit current state
	_exit_current_state()

	# Record state visit
	if new_name not in stats.states_visited:
		stats.states_visited.append(new_name)

	# Update state
	current_state = new_state
	state_start_time = Time.get_ticks_msec() / 1000.0
	state_elapsed = 0.0

	DebugLogger.info(SOURCE, "State: %s → %s" % [old_name, new_name])

	# Enter new state
	_enter_state(new_state)

	state_changed.emit(previous_state, new_state)


func _enter_state(state: Level1State) -> void:
	match state:
		Level1State.INTRO:
			_enter_intro()
		Level1State.SABER_DRILL:
			_enter_saber_drill()
		Level1State.BLASTER_DRILL:
			_enter_blaster_drill()
		Level1State.MIXED_DRILL:
			_enter_mixed_drill()
		Level1State.SUMMARY:
			_enter_summary()
		Level1State.COMPLETE:
			_enter_complete()


func _exit_current_state() -> void:
	match current_state:
		Level1State.INTRO:
			_exit_intro()
		Level1State.SABER_DRILL:
			_exit_saber_drill()
		Level1State.BLASTER_DRILL:
			_exit_blaster_drill()
		Level1State.MIXED_DRILL:
			_exit_mixed_drill()
		Level1State.SUMMARY:
			_exit_summary()


# =============================================================================
# INTRO STATE
# =============================================================================

func _enter_intro() -> void:
	DebugLogger.info(SOURCE, "")
	DebugLogger.info(SOURCE, "=== INTRO PHASE ===")
	DebugLogger.info(SOURCE, "Welcome to Dojo Training Level 1")
	DebugLogger.info(SOURCE, "")
	DebugLogger.info(SOURCE, "Controls:")
	DebugLogger.info(SOURCE, "  Right Hand: Lightsaber (trigger to activate)")
	DebugLogger.info(SOURCE, "  Left Hand:  Blaster (trigger to fire)")
	DebugLogger.info(SOURCE, "")

	# Ensure weapons are visible/activated
	if lightsaber and lightsaber.has_method("show_hilt"):
		lightsaber.show_hilt()

	# TODO: Show world-space instruction text panel
	# TODO: Play intro audio cue


func _process_intro(_delta: float) -> void:
	# Auto-advance after duration, or wait for input
	if auto_advance_intro and state_elapsed >= intro_duration:
		_change_state(Level1State.SABER_DRILL)
		return

	# Manual advance with any trigger press
	if _any_trigger_pressed():
		stats.intro_skipped = state_elapsed < intro_duration * 0.5
		_change_state(Level1State.SABER_DRILL)


func _exit_intro() -> void:
	stats.intro_duration = state_elapsed
	DebugLogger.debug(SOURCE, "Intro completed in %.1fs" % state_elapsed)


# =============================================================================
# SABER DRILL STATE
# =============================================================================

func _enter_saber_drill() -> void:
	DebugLogger.info(SOURCE, "")
	DebugLogger.info(SOURCE, "=== SABER DRILL ===")
	DebugLogger.info(SOURCE, "Objective: Block incoming projectiles with your saber!")
	DebugLogger.info(SOURCE, "  Projectiles to block: %d" % saber_projectiles_required)
	DebugLogger.info(SOURCE, "")

	_saber_drill_complete = false

	# Spawn drones that fire projectiles
	if drone_spawner:
		drone_spawner.spawn_saber_drill_drones()
	else:
		DebugLogger.warn(SOURCE, "No drone spawner - using timeout mode")


func _process_saber_drill(_delta: float) -> void:
	# Check completion: blocked enough projectiles
	if stats.saber_projectiles_blocked >= saber_projectiles_required:
		if not _saber_drill_complete:
			_saber_drill_complete = true
			DebugLogger.info(SOURCE, "Saber drill objective complete! Transitioning...")
			# Brief pause before advancing
			await get_tree().create_timer(1.0).timeout
			_change_state(Level1State.BLASTER_DRILL)
		return

	# Timeout fallback (if no spawner or player struggling)
	if state_elapsed >= 25.0:
		DebugLogger.debug(SOURCE, "Saber drill timeout - advancing")
		_change_state(Level1State.BLASTER_DRILL)


func _exit_saber_drill() -> void:
	stats.saber_duration = state_elapsed

	# Despawn remaining drones
	if drone_spawner:
		drone_spawner.despawn_all()

	var phase_stats := {
		"targets_hit": stats.saber_targets_hit,
		"targets_missed": stats.saber_targets_missed,
		"projectiles_blocked": stats.saber_projectiles_blocked,
		"projectiles_missed": stats.saber_projectiles_missed,
		"duration": state_elapsed
	}

	DebugLogger.info(SOURCE, "Saber Drill complete: %d/%d blocks in %.1fs" % [
		stats.saber_projectiles_blocked, saber_projectiles_required,
		state_elapsed
	])

	phase_completed.emit(Level1State.SABER_DRILL, phase_stats)


# =============================================================================
# BLASTER DRILL STATE
# =============================================================================

func _enter_blaster_drill() -> void:
	DebugLogger.info(SOURCE, "")
	DebugLogger.info(SOURCE, "=== BLASTER DRILL ===")
	DebugLogger.info(SOURCE, "Objective: Destroy the target drones!")
	DebugLogger.info(SOURCE, "  Drones to destroy: %d" % blaster_targets_required)
	DebugLogger.info(SOURCE, "")

	_blaster_drill_complete = false

	# Spawn target drones (non-shooting)
	if drone_spawner:
		drone_spawner.spawn_blaster_drill_drones()
	else:
		DebugLogger.warn(SOURCE, "No drone spawner - using timeout mode")


func _process_blaster_drill(_delta: float) -> void:
	# Check completion: destroyed enough drones
	if stats.blaster_hits >= blaster_targets_required:
		if not _blaster_drill_complete:
			_blaster_drill_complete = true
			DebugLogger.info(SOURCE, "Blaster drill objective complete! Transitioning...")
			await get_tree().create_timer(1.0).timeout
			_change_state(Level1State.MIXED_DRILL)
		return

	# Also complete if all drones destroyed (even if fewer than required)
	if drone_spawner and not drone_spawner.has_active_drones() and stats.blaster_hits > 0:
		if not _blaster_drill_complete:
			_blaster_drill_complete = true
			DebugLogger.info(SOURCE, "All drones destroyed! Transitioning...")
			await get_tree().create_timer(1.0).timeout
			_change_state(Level1State.MIXED_DRILL)
		return

	# Timeout fallback
	if state_elapsed >= 30.0:
		DebugLogger.debug(SOURCE, "Blaster drill timeout - advancing")
		_change_state(Level1State.MIXED_DRILL)


func _exit_blaster_drill() -> void:
	stats.blaster_duration = state_elapsed

	# Despawn remaining drones
	if drone_spawner:
		drone_spawner.despawn_all()

	var phase_stats := {
		"drones_destroyed": stats.blaster_hits,
		"duration": state_elapsed
	}

	DebugLogger.info(SOURCE, "Blaster Drill complete: %d/%d drones destroyed in %.1fs" % [
		stats.blaster_hits, blaster_targets_required,
		state_elapsed
	])

	phase_completed.emit(Level1State.BLASTER_DRILL, phase_stats)


# =============================================================================
# MIXED DRILL STATE
# =============================================================================

func _enter_mixed_drill() -> void:
	DebugLogger.info(SOURCE, "")
	DebugLogger.info(SOURCE, "=== MIXED DRILL ===")
	DebugLogger.info(SOURCE, "Objective: Handle shooting drones AND a dive attack!")
	DebugLogger.info(SOURCE, "  Drones to destroy: %d" % mixed_drones_required)
	if mixed_dive_required:
		DebugLogger.info(SOURCE, "  WARNING: Watch for the DIVE attack!")
	DebugLogger.info(SOURCE, "")

	_mixed_drill_complete = false

	# Spawn mixed drones (shooters + optional dive)
	if drone_spawner:
		drone_spawner.spawn_mixed_drill_drones()
	else:
		DebugLogger.warn(SOURCE, "No drone spawner - using timeout mode")


func _process_mixed_drill(_delta: float) -> void:
	# Check completion: destroyed enough drones AND handled dive
	var drones_done := stats.mixed_drones_destroyed >= mixed_drones_required
	var dive_done := not mixed_dive_required or stats.mixed_dive_blocked

	# Complete when all objectives met
	if drones_done and dive_done:
		if not _mixed_drill_complete:
			_mixed_drill_complete = true
			DebugLogger.info(SOURCE, "Mixed drill objectives complete! Great work!")
			await get_tree().create_timer(1.5).timeout
			_change_state(Level1State.SUMMARY)
		return

	# Also complete if all drones gone (dive drone self-destructs after dive)
	if drone_spawner and not drone_spawner.has_active_drones() and stats.mixed_drones_destroyed > 0:
		if not _mixed_drill_complete:
			_mixed_drill_complete = true
			DebugLogger.info(SOURCE, "All threats neutralized! Transitioning...")
			await get_tree().create_timer(1.5).timeout
			_change_state(Level1State.SUMMARY)
		return

	# Timeout fallback
	if state_elapsed >= 45.0:
		DebugLogger.debug(SOURCE, "Mixed drill timeout - advancing")
		_change_state(Level1State.SUMMARY)


func _exit_mixed_drill() -> void:
	stats.mixed_duration = state_elapsed

	# Despawn remaining drones
	if drone_spawner:
		drone_spawner.despawn_all()

	var phase_stats := {
		"drones_destroyed": stats.mixed_drones_destroyed,
		"dive_blocked": stats.mixed_dive_blocked,
		"duration": state_elapsed
	}

	DebugLogger.info(SOURCE, "Mixed Drill complete: %d/%d drones, dive=%s in %.1fs" % [
		stats.mixed_drones_destroyed, mixed_drones_required,
		"BLOCKED" if stats.mixed_dive_blocked else "missed",
		state_elapsed
	])

	phase_completed.emit(Level1State.MIXED_DRILL, phase_stats)


# =============================================================================
# SUMMARY STATE
# =============================================================================

func _enter_summary() -> void:
	stats.total_duration = (Time.get_ticks_msec() / 1000.0) - level_start_time

	DebugLogger.info(SOURCE, "")
	DebugLogger.info(SOURCE, "╔══════════════════════════════════════╗")
	DebugLogger.info(SOURCE, "║        TRAINING COMPLETE!            ║")
	DebugLogger.info(SOURCE, "╚══════════════════════════════════════╝")
	DebugLogger.info(SOURCE, "")
	DebugLogger.info(SOURCE, "=== LEVEL 1 SUMMARY ===")
	DebugLogger.info(SOURCE, "")
	DebugLogger.info(SOURCE, "SABER DRILL:")
	DebugLogger.info(SOURCE, "  Targets Hit:      %d/%d" % [stats.saber_targets_hit, saber_targets_required])
	DebugLogger.info(SOURCE, "  Blocks:           %d/%d" % [stats.saber_projectiles_blocked, saber_projectiles_required])
	DebugLogger.info(SOURCE, "  Time:             %.1fs" % stats.saber_duration)
	DebugLogger.info(SOURCE, "")
	DebugLogger.info(SOURCE, "BLASTER DRILL:")
	var blaster_accuracy := 0.0
	if stats.blaster_shots_fired > 0:
		blaster_accuracy = float(stats.blaster_hits) / float(stats.blaster_shots_fired) * 100.0
	DebugLogger.info(SOURCE, "  Accuracy:         %.0f%% (%d/%d)" % [blaster_accuracy, stats.blaster_hits, stats.blaster_shots_fired])
	DebugLogger.info(SOURCE, "  Time:             %.1fs" % stats.blaster_duration)
	DebugLogger.info(SOURCE, "")
	DebugLogger.info(SOURCE, "MIXED DRILL:")
	DebugLogger.info(SOURCE, "  Drones Destroyed: %d/%d" % [stats.mixed_drones_destroyed, mixed_drones_required])
	DebugLogger.info(SOURCE, "  Dive Blocked:     %s" % ("YES" if stats.mixed_dive_blocked else "NO"))
	DebugLogger.info(SOURCE, "  Time:             %.1fs" % stats.mixed_duration)
	DebugLogger.info(SOURCE, "")
	DebugLogger.info(SOURCE, "TOTAL TIME: %.1fs" % stats.total_duration)
	DebugLogger.info(SOURCE, "")
	DebugLogger.info(SOURCE, "Press MENU to exit, or TRIGGER to restart")

	# TODO: Show world-space summary panel
	# TODO: Play completion audio


func _process_summary(_delta: float) -> void:
	# Wait for player input
	if _menu_pressed():
		_change_state(Level1State.COMPLETE)
	elif _any_trigger_pressed():
		restart_level()


func _exit_summary() -> void:
	pass


# =============================================================================
# COMPLETE STATE
# =============================================================================

func _enter_complete() -> void:
	DebugLogger.info(SOURCE, "")
	DebugLogger.info(SOURCE, "=== LEVEL 1 COMPLETE ===")
	DebugLogger.info(SOURCE, "Total duration: %.1fs" % stats.total_duration)
	DebugLogger.info(SOURCE, "States visited: %s" % ", ".join(stats.states_visited))
	DebugLogger.info(SOURCE, "")

	level_completed.emit(stats.duplicate())


# =============================================================================
# HELPERS
# =============================================================================

func _reset_stats() -> void:
	stats = {
		"total_duration": 0.0,
		"states_visited": [] as Array[String],
		"intro_duration": 0.0,
		"intro_skipped": false,
		"saber_targets_hit": 0,
		"saber_targets_missed": 0,
		"saber_projectiles_blocked": 0,
		"saber_projectiles_missed": 0,
		"saber_duration": 0.0,
		"blaster_shots_fired": 0,
		"blaster_hits": 0,
		"blaster_misses": 0,
		"blaster_duration": 0.0,
		"mixed_drones_destroyed": 0,
		"mixed_dive_blocked": false,
		"mixed_duration": 0.0,
	}


func _cleanup_active_entities() -> void:
	if active_entities == null:
		return

	var count := 0
	for child in active_entities.get_children():
		child.queue_free()
		count += 1

	if count > 0:
		DebugLogger.debug(SOURCE, "Cleaned up %d active entities" % count)


func _any_trigger_pressed() -> bool:
	# Check via XRInputManager if available
	var input_mgr := _get_input_manager()
	if input_mgr:
		return input_mgr.is_trigger_pressed(XRInputManager.Hand.LEFT) or \
			   input_mgr.is_trigger_pressed(XRInputManager.Hand.RIGHT)

	# Fallback: check controllers directly
	if left_controller:
		var left_trigger := left_controller.get_float("trigger")
		if left_trigger >= 0.7:
			return true
	if right_controller:
		var right_trigger := right_controller.get_float("trigger")
		if right_trigger >= 0.7:
			return true

	return false


func _menu_pressed() -> bool:
	# Check for menu button or ESC
	if Input.is_action_just_pressed("ui_cancel"):
		return true

	# Check controller menu buttons
	var input_mgr := _get_input_manager()
	if input_mgr:
		return input_mgr.is_button_pressed(XRInputManager.Hand.LEFT, "menu_button") or \
			   input_mgr.is_button_pressed(XRInputManager.Hand.RIGHT, "menu_button")

	return false


func _get_input_manager() -> XRInputManager:
	var mgr := get_node_or_null("/root/XRInputManager")
	return mgr as XRInputManager


# =============================================================================
# COMBAT EVENT HANDLERS (to be connected when spawning entities)
# =============================================================================

## Called when a saber target is hit
func _on_saber_target_hit(_target: Node3D) -> void:
	stats.saber_targets_hit += 1
	DebugLogger.debug(SOURCE, "Saber target hit! (%d/%d)" % [stats.saber_targets_hit, saber_targets_required])


## Called when a saber target is missed (timed out)
func _on_saber_target_missed(_target: Node3D) -> void:
	stats.saber_targets_missed += 1
	DebugLogger.debug(SOURCE, "Saber target missed")


## Called when a projectile is blocked by the saber
func _on_projectile_blocked(_projectile: Node3D) -> void:
	stats.saber_projectiles_blocked += 1
	DebugLogger.debug(SOURCE, "Projectile blocked! (%d/%d)" % [stats.saber_projectiles_blocked, saber_projectiles_required])


## Called when a projectile hits the player
func _on_projectile_hit_player(_projectile: Node3D) -> void:
	stats.saber_projectiles_missed += 1
	DebugLogger.debug(SOURCE, "Projectile hit player (missed block)")


## Called when blaster fires
func _on_blaster_fired() -> void:
	stats.blaster_shots_fired += 1


## Called when blaster hits a target
func _on_blaster_hit(_target: Node3D) -> void:
	stats.blaster_hits += 1
	DebugLogger.debug(SOURCE, "Blaster hit! (%d hits)" % stats.blaster_hits)


## Called when a drone is destroyed
func _on_drone_destroyed(_drone: Node3D) -> void:
	stats.mixed_drones_destroyed += 1
	DebugLogger.debug(SOURCE, "Drone destroyed! (%d/%d)" % [stats.mixed_drones_destroyed, mixed_drones_required])


## Called when dive attack is blocked
func _on_dive_blocked(_droid: Node3D) -> void:
	stats.mixed_dive_blocked = true
	DebugLogger.info(SOURCE, "DIVE ATTACK BLOCKED!")


# =============================================================================
# SPAWNER SIGNAL HANDLERS
# =============================================================================

## Called when spawner reports a drone destroyed
func _on_spawner_drone_destroyed(drone: SimpleDrone, by_player: bool) -> void:
	if not by_player:
		return  # Don't count self-destructs

	# Track based on current state
	match current_state:
		Level1State.SABER_DRILL:
			stats.saber_targets_hit += 1
			DebugLogger.debug(SOURCE, "Saber target destroyed! (%d)" % stats.saber_targets_hit)
		Level1State.BLASTER_DRILL:
			stats.blaster_hits += 1
			DebugLogger.debug(SOURCE, "Blaster target destroyed! (%d/%d)" % [stats.blaster_hits, blaster_targets_required])
		Level1State.MIXED_DRILL:
			stats.mixed_drones_destroyed += 1
			DebugLogger.debug(SOURCE, "Mixed drone destroyed! (%d/%d)" % [stats.mixed_drones_destroyed, mixed_drones_required])


## Called when spawner reports a projectile was blocked/deflected
func _on_spawner_projectile_blocked(_projectile: Projectile) -> void:
	stats.saber_projectiles_blocked += 1
	DebugLogger.info(SOURCE, "PROJECTILE BLOCKED! (%d/%d)" % [stats.saber_projectiles_blocked, saber_projectiles_required])


## Called when spawner reports a projectile hit the player
func _on_spawner_projectile_hit_player(_projectile: Projectile) -> void:
	stats.saber_projectiles_missed += 1
	DebugLogger.debug(SOURCE, "Projectile hit player (missed block)")


## Called when spawner reports a dive completed
func _on_spawner_dive_completed(drone: SimpleDrone, hit_player: bool) -> void:
	if hit_player:
		# Player got hit by dive - that's a miss for them
		DebugLogger.warn(SOURCE, "DIVE HIT PLAYER! Ouch!")
	else:
		# Player dodged or the dive timed out - count as blocked
		stats.mixed_dive_blocked = true
		DebugLogger.info(SOURCE, "DIVE ATTACK EVADED/BLOCKED!")


## Called when all drones are destroyed
func _on_all_drones_destroyed() -> void:
	DebugLogger.debug(SOURCE, "All active drones destroyed")

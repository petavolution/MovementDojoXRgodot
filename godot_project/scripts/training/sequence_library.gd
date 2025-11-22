## SequenceLibrary - Factory for creating predefined training sequences
## Provides programmatic sequence creation for built-in training programs
##
## Design: Central repository for all built-in sequences
## Sequences can also be loaded from .tres resource files
class_name SequenceLibrary
extends RefCounted

# =============================================================================
# SEQUENCE CATALOG
# =============================================================================

## Get list of all available built-in sequence IDs
static func get_available_sequences() -> Array[String]:
	return [
		"level1_fundamentals",
		"level2_intermediate",  # Placeholder for future
		"endless_survival",     # Placeholder for future
	]


## Get sequence by ID
static func get_sequence(sequence_id: String) -> TrainingSequence:
	match sequence_id:
		"level1_fundamentals":
			return create_level1_fundamentals()
		"level2_intermediate":
			return create_level2_intermediate()
		"endless_survival":
			return create_endless_survival()
		_:
			push_error("Unknown sequence ID: %s" % sequence_id)
			return null


# =============================================================================
# LEVEL 1: FUNDAMENTALS
# =============================================================================

## Create the Level 1 training sequence - gentle introduction to combat
static func create_level1_fundamentals() -> TrainingSequence:
	var sequence := TrainingSequence.new()
	sequence.sequence_id = "level1_fundamentals"
	sequence.display_name = "Level 1: Fundamentals"
	sequence.description = "Learn the basics of saber defense and ranged combat"
	sequence.long_description = """Welcome to the Dojo!

This introductory training will teach you:
• How to block incoming projectiles with your saber
• How to aim and shoot with your blaster
• How to handle mixed threats including dive attacks

Take your time - this is a relaxed training environment."""

	sequence.difficulty = 1
	sequence.estimated_duration_minutes = 5
	sequence.focus_areas = ["deflection", "accuracy", "awareness"]
	sequence.tags = ["beginner", "tutorial"]
	sequence.preferred_environment = "dojo"
	sequence.always_available = true
	sequence.allow_phase_skip = true
	sequence.show_summary = true

	# Build phases
	sequence.phases.append(_create_level1_intro())
	sequence.phases.append(_create_level1_saber_drill())
	sequence.phases.append(_create_level1_blaster_drill())
	sequence.phases.append(_create_level1_mixed_drill())
	sequence.phases.append(_create_level1_summary())

	return sequence


static func _create_level1_intro() -> TrainingPhase:
	var phase := TrainingPhase.new()
	phase.phase_id = "intro"
	phase.display_name = "Welcome"
	phase.description = "Introduction to the training"
	phase.phase_type = TrainingPhase.PhaseType.INTRO

	phase.objective_text = "Prepare for training"
	phase.intro_message = "Welcome to the Dojo! Relax and prepare for your training."
	phase.success_message = "Let's begin!"

	phase.completion_type = TrainingPhase.CompletionType.TIMED
	phase.timed_duration = 8.0
	phase.allow_skip = true
	phase.skip_hint = "Pull any trigger to skip"
	phase.auto_advance = true
	phase.advance_delay = 1.0

	# No waves for intro
	phase.waves = []

	return phase


static func _create_level1_saber_drill() -> TrainingPhase:
	var phase := TrainingPhase.new()
	phase.phase_id = "saber_basics"
	phase.display_name = "Saber Basics"
	phase.description = "Learn to block incoming projectiles"
	phase.phase_type = TrainingPhase.PhaseType.DRILL

	phase.objective_text = "Block incoming projectiles with your saber"
	phase.hint_text = "Hold your saber in the path of incoming orbs"
	phase.intro_message = "SABER DRILL: Block the incoming projectiles!"
	phase.success_message = "Excellent blocking!"

	phase.completion_type = TrainingPhase.CompletionType.ALL_WAVES
	phase.auto_advance = true
	phase.advance_delay = 1.5
	phase.inter_wave_delay = 1.0

	phase.tracked_metrics = ["projectiles_blocked", "hits_taken", "duration"]
	phase.show_phase_stats = true
	phase.base_difficulty = 1

	# Wave 1: Two slow shooters, block 3 projectiles
	var wave1 := TrainingWave.new()
	wave1.wave_id = "saber_w1"
	wave1.display_name = "Wave 1"
	wave1.description = "Basic blocking practice"

	var shooter1 := WaveSpawnEntry.new()
	shooter1.entry_id = "shooter_pair"
	shooter1.enemy_type = WaveSpawnEntry.EnemyType.FLYING_DRONE
	shooter1.count = 2
	shooter1.behavior = WaveSpawnEntry.SpawnBehavior.STATIONARY
	shooter1.formation = WaveSpawnEntry.SpawnFormation.ARC
	shooter1.can_shoot = true
	shooter1.fire_interval = 3.5
	shooter1.projectile_speed = 3.0
	shooter1.spawn_distance = 3.0
	shooter1.spawn_height_offset = 0.0
	shooter1.spawn_arc_degrees = 60.0
	shooter1.use_default_color = true

	wave1.spawn_entries.append(shooter1)
	wave1.completion_type = TrainingWave.CompletionType.BLOCK_COUNT
	wave1.completion_value = 3
	wave1.timeout_seconds = 25.0
	wave1.timeout_is_success = true
	wave1.show_progress = true
	wave1.start_message = "Block 3 projectiles!"
	wave1.complete_message = "Great blocking!"

	phase.waves.append(wave1)

	return phase


static func _create_level1_blaster_drill() -> TrainingPhase:
	var phase := TrainingPhase.new()
	phase.phase_id = "blaster_basics"
	phase.display_name = "Blaster Basics"
	phase.description = "Practice aiming and shooting"
	phase.phase_type = TrainingPhase.PhaseType.DRILL

	phase.objective_text = "Destroy the target drones with your blaster"
	phase.hint_text = "Aim with your left hand and pull the trigger to fire"
	phase.intro_message = "BLASTER DRILL: Destroy the targets!"
	phase.success_message = "Nice shooting!"

	phase.completion_type = TrainingPhase.CompletionType.ALL_WAVES
	phase.auto_advance = true
	phase.advance_delay = 1.5
	phase.inter_wave_delay = 1.0

	phase.tracked_metrics = ["shots_fired", "accuracy", "duration"]
	phase.base_difficulty = 1

	# Wave 1: Three target dummies
	var wave1 := TrainingWave.new()
	wave1.wave_id = "blaster_w1"
	wave1.display_name = "Wave 1"
	wave1.description = "Target practice"

	var targets := WaveSpawnEntry.new()
	targets.entry_id = "target_dummies"
	targets.enemy_type = WaveSpawnEntry.EnemyType.TARGET_DUMMY
	targets.count = 3
	targets.behavior = WaveSpawnEntry.SpawnBehavior.ORBIT
	targets.formation = WaveSpawnEntry.SpawnFormation.ARC
	targets.can_shoot = false
	targets.spawn_distance = 3.0
	targets.spawn_arc_degrees = 90.0
	targets.health_multiplier = 0.6  # Easier to destroy
	targets.movement_speed = 0.3
	targets.orbit_radius = 0.8

	wave1.spawn_entries.append(targets)
	wave1.completion_type = TrainingWave.CompletionType.DESTROY_ALL
	wave1.timeout_seconds = 30.0
	wave1.timeout_is_success = true
	wave1.show_progress = true
	wave1.start_message = "Destroy 3 targets!"
	wave1.complete_message = "Targets eliminated!"

	phase.waves.append(wave1)

	return phase


static func _create_level1_mixed_drill() -> TrainingPhase:
	var phase := TrainingPhase.new()
	phase.phase_id = "mixed_combat"
	phase.display_name = "Mixed Combat"
	phase.description = "Handle multiple threat types"
	phase.phase_type = TrainingPhase.PhaseType.COMBAT

	phase.objective_text = "Deal with shooting drones AND a dive attack"
	phase.hint_text = "Watch for the dive warning - dodge or block!"
	phase.intro_message = "MIXED DRILL: Stay alert for dive attacks!"
	phase.success_message = "Combat training complete!"

	phase.completion_type = TrainingPhase.CompletionType.ALL_WAVES
	phase.auto_advance = true
	phase.advance_delay = 2.0
	phase.inter_wave_delay = 1.5

	phase.tracked_metrics = ["enemies_destroyed", "projectiles_blocked", "dive_evaded", "duration"]
	phase.base_difficulty = 2

	# Wave 1: Two shooters + one dive attacker
	var wave1 := TrainingWave.new()
	wave1.wave_id = "mixed_w1"
	wave1.display_name = "Wave 1"
	wave1.description = "Mixed threats"

	# Shooting drones
	var shooters := WaveSpawnEntry.new()
	shooters.entry_id = "shooters"
	shooters.enemy_type = WaveSpawnEntry.EnemyType.FLYING_DRONE
	shooters.count = 2
	shooters.behavior = WaveSpawnEntry.SpawnBehavior.ORBIT
	shooters.formation = WaveSpawnEntry.SpawnFormation.ARC
	shooters.can_shoot = true
	shooters.fire_interval = 2.5
	shooters.projectile_speed = 4.0
	shooters.spawn_distance = 3.0
	shooters.spawn_arc_degrees = 60.0
	shooters.orbit_radius = 1.0
	shooters.orbit_speed = 0.4

	# Dive attacker
	var diver := WaveSpawnEntry.new()
	diver.entry_id = "diver"
	diver.enemy_type = WaveSpawnEntry.EnemyType.DIVE_ATTACKER
	diver.count = 1
	diver.behavior = WaveSpawnEntry.SpawnBehavior.STATIONARY  # Until it dives
	diver.formation = WaveSpawnEntry.SpawnFormation.SINGLE
	diver.can_shoot = false
	diver.spawn_distance = 4.0
	diver.spawn_height_offset = 0.5
	diver.spawn_delay = 3.0  # Spawn dive drone after 3 seconds

	wave1.spawn_entries.append(shooters)
	wave1.spawn_entries.append(diver)
	wave1.spawn_simultaneous = false  # Stagger spawns
	wave1.default_spawn_interval = 3.0

	wave1.completion_type = TrainingWave.CompletionType.DESTROY_ALL
	wave1.timeout_seconds = 45.0
	wave1.timeout_is_success = true
	wave1.start_message = "Watch for dive attacks!"
	wave1.complete_message = "All threats neutralized!"

	phase.waves.append(wave1)

	return phase


static func _create_level1_summary() -> TrainingPhase:
	var phase := TrainingPhase.new()
	phase.phase_id = "summary"
	phase.display_name = "Training Summary"
	phase.description = "Review your performance"
	phase.phase_type = TrainingPhase.PhaseType.SUMMARY

	phase.objective_text = ""
	phase.intro_message = "Training Complete! Review your stats."

	phase.completion_type = TrainingPhase.CompletionType.MANUAL
	phase.allow_skip = true
	phase.skip_hint = "Press MENU to exit, TRIGGER to restart"
	phase.auto_advance = false  # Wait for player input

	phase.waves = []

	return phase


# =============================================================================
# LEVEL 2: INTERMEDIATE (Placeholder)
# =============================================================================

static func create_level2_intermediate() -> TrainingSequence:
	var sequence := TrainingSequence.new()
	sequence.sequence_id = "level2_intermediate"
	sequence.display_name = "Level 2: Intermediate"
	sequence.description = "Build on your fundamentals with faster enemies"
	sequence.difficulty = 2
	sequence.estimated_duration_minutes = 8
	sequence.preferred_environment = "ocean"
	sequence.required_sequences = ["level1_fundamentals"]
	sequence.always_available = false

	# TODO: Add phases when ready
	var placeholder := TrainingPhase.new()
	placeholder.phase_id = "placeholder"
	placeholder.display_name = "Coming Soon"
	placeholder.phase_type = TrainingPhase.PhaseType.INTRO
	placeholder.intro_message = "Level 2 content coming soon!"
	placeholder.completion_type = TrainingPhase.CompletionType.TIMED
	placeholder.timed_duration = 3.0
	sequence.phases.append(placeholder)

	return sequence


# =============================================================================
# ENDLESS SURVIVAL (Placeholder)
# =============================================================================

static func create_endless_survival() -> TrainingSequence:
	var sequence := TrainingSequence.new()
	sequence.sequence_id = "endless_survival"
	sequence.display_name = "Endless Survival"
	sequence.description = "How long can you last?"
	sequence.difficulty = 3
	sequence.estimated_duration_minutes = 0  # Endless
	sequence.preferred_environment = "hyperspace"
	sequence.always_available = true
	sequence.allow_phase_skip = false
	sequence.show_summary = true
	sequence.adaptive_enabled = true

	# TODO: Add endless wave generation
	var placeholder := TrainingPhase.new()
	placeholder.phase_id = "placeholder"
	placeholder.display_name = "Coming Soon"
	placeholder.phase_type = TrainingPhase.PhaseType.INTRO
	placeholder.intro_message = "Endless mode coming soon!"
	placeholder.completion_type = TrainingPhase.CompletionType.TIMED
	placeholder.timed_duration = 3.0
	sequence.phases.append(placeholder)

	return sequence

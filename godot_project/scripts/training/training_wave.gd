## TrainingWave - Defines a single wave (encounter) within a training phase
## Contains spawn entries and completion conditions
##
## Design: Data-driven resource - each wave knows what to spawn and when it's done
## Waves are the atomic unit of combat encounters
class_name TrainingWave
extends Resource

# =============================================================================
# COMPLETION TYPES
# =============================================================================

enum CompletionType {
	DESTROY_ALL,       # Wave ends when all spawned enemies are destroyed
	DESTROY_COUNT,     # Wave ends when N enemies destroyed (completion_value)
	SURVIVE_TIME,      # Wave ends after surviving N seconds (completion_value)
	BLOCK_COUNT,       # Wave ends after blocking N projectiles (completion_value)
	HIT_COUNT,         # Wave ends after landing N hits (completion_value)
	MANUAL,            # Wave ends only via external signal (for scripted moments)
}

# =============================================================================
# IDENTITY
# =============================================================================

## Unique identifier for this wave
@export var wave_id: String = ""

## Display name shown to player (optional)
@export var display_name: String = ""

## Description for debugging/design docs
@export var description: String = ""

# =============================================================================
# SPAWN CONFIGURATION
# =============================================================================

@export_group("Spawning")
## List of spawn entries (what enemies to create)
@export var spawn_entries: Array[WaveSpawnEntry] = []

## Delay before spawning begins (seconds after wave start)
@export var spawn_delay: float = 0.0

## Default interval between spawn entries (can be overridden per-entry)
@export var default_spawn_interval: float = 0.5

## Whether to spawn all entries simultaneously or sequentially
@export var spawn_simultaneous: bool = false

# =============================================================================
# COMPLETION CONDITIONS
# =============================================================================

@export_group("Completion")
## Primary completion condition
@export var completion_type: CompletionType = CompletionType.DESTROY_ALL

## Value for count/time-based completions
@export var completion_value: int = 0

## Maximum wave duration before auto-complete (0 = no timeout)
@export var timeout_seconds: float = 60.0

## Allow timeout to count as successful completion
@export var timeout_is_success: bool = true

## Minimum time wave must run before completion (prevents instant completion)
@export var minimum_duration: float = 0.0

# =============================================================================
# FEEDBACK
# =============================================================================

@export_group("Feedback")
## Text to display when wave starts (empty = no display)
@export var start_message: String = ""

## Text to display when wave completes successfully
@export var complete_message: String = ""

## Text to display on wave failure/timeout
@export var timeout_message: String = ""

## Show progress indicator for count-based completions
@export var show_progress: bool = true

# =============================================================================
# DIFFICULTY MODIFIERS
# =============================================================================

@export_group("Difficulty")
## Difficulty multiplier for this wave (affects spawn stats)
@export var difficulty_multiplier: float = 1.0

## Additional health multiplier on top of entry settings
@export var wave_health_multiplier: float = 1.0

## Additional speed multiplier on top of entry settings
@export var wave_speed_multiplier: float = 1.0

# =============================================================================
# HELPER METHODS
# =============================================================================

## Get total enemy count across all spawn entries
func get_total_enemy_count() -> int:
	var total := 0
	for entry in spawn_entries:
		total += entry.count
	return total


## Get summary of enemies for logging
func get_spawn_summary() -> String:
	if spawn_entries.is_empty():
		return "No spawns"

	var parts: Array[String] = []
	for entry in spawn_entries:
		parts.append(entry.get_summary())

	return ", ".join(parts)


## Get display name for completion type
static func get_completion_type_name(type: CompletionType) -> String:
	match type:
		CompletionType.DESTROY_ALL: return "Destroy All"
		CompletionType.DESTROY_COUNT: return "Destroy Count"
		CompletionType.SURVIVE_TIME: return "Survive"
		CompletionType.BLOCK_COUNT: return "Block Projectiles"
		CompletionType.HIT_COUNT: return "Land Hits"
		CompletionType.MANUAL: return "Manual"
		_: return "Unknown"


## Get completion condition as readable string
func get_completion_description() -> String:
	match completion_type:
		CompletionType.DESTROY_ALL:
			return "Destroy all enemies"
		CompletionType.DESTROY_COUNT:
			return "Destroy %d enemies" % completion_value
		CompletionType.SURVIVE_TIME:
			return "Survive for %d seconds" % completion_value
		CompletionType.BLOCK_COUNT:
			return "Block %d projectiles" % completion_value
		CompletionType.HIT_COUNT:
			return "Land %d hits" % completion_value
		CompletionType.MANUAL:
			return "Complete objective"
		_:
			return "Unknown condition"


## Check if a given progress value meets completion (for count-based types)
func check_completion(current_value: int, enemies_remaining: int, elapsed_time: float) -> bool:
	# Enforce minimum duration
	if elapsed_time < minimum_duration:
		return false

	match completion_type:
		CompletionType.DESTROY_ALL:
			return enemies_remaining <= 0
		CompletionType.DESTROY_COUNT:
			return current_value >= completion_value
		CompletionType.SURVIVE_TIME:
			return elapsed_time >= float(completion_value)
		CompletionType.BLOCK_COUNT:
			return current_value >= completion_value
		CompletionType.HIT_COUNT:
			return current_value >= completion_value
		CompletionType.MANUAL:
			return false  # Only completes via external trigger
		_:
			return false


## Check if wave has timed out
func check_timeout(elapsed_time: float) -> bool:
	if timeout_seconds <= 0:
		return false
	return elapsed_time >= timeout_seconds


## Validate this wave definition (returns array of error messages)
func validate() -> Array[String]:
	var errors: Array[String] = []

	if wave_id.is_empty():
		errors.append("wave_id is required")

	if spawn_entries.is_empty() and completion_type != CompletionType.SURVIVE_TIME:
		errors.append("Non-survival waves should have spawn_entries")

	# Validate count-based completions have valid values
	if completion_type in [CompletionType.DESTROY_COUNT, CompletionType.BLOCK_COUNT, CompletionType.HIT_COUNT]:
		if completion_value <= 0:
			errors.append("Count-based completion requires completion_value > 0")

	if completion_type == CompletionType.SURVIVE_TIME and completion_value <= 0:
		errors.append("SURVIVE_TIME completion requires completion_value > 0 (seconds)")

	# Validate each spawn entry
	for i in range(spawn_entries.size()):
		var entry_errors := spawn_entries[i].validate()
		for err in entry_errors:
			errors.append("spawn_entries[%d]: %s" % [i, err])

	# Check completion is achievable
	if completion_type == CompletionType.DESTROY_COUNT:
		var total := get_total_enemy_count()
		if completion_value > total:
			errors.append("DESTROY_COUNT value (%d) exceeds total enemies (%d)" % [completion_value, total])

	return errors


## Create a deep copy of this wave
func duplicate_deep() -> TrainingWave:
	var copy := TrainingWave.new()
	copy.wave_id = wave_id
	copy.display_name = display_name
	copy.description = description
	copy.spawn_delay = spawn_delay
	copy.default_spawn_interval = default_spawn_interval
	copy.spawn_simultaneous = spawn_simultaneous
	copy.completion_type = completion_type
	copy.completion_value = completion_value
	copy.timeout_seconds = timeout_seconds
	copy.timeout_is_success = timeout_is_success
	copy.minimum_duration = minimum_duration
	copy.start_message = start_message
	copy.complete_message = complete_message
	copy.timeout_message = timeout_message
	copy.show_progress = show_progress
	copy.difficulty_multiplier = difficulty_multiplier
	copy.wave_health_multiplier = wave_health_multiplier
	copy.wave_speed_multiplier = wave_speed_multiplier

	for entry in spawn_entries:
		copy.spawn_entries.append(entry.duplicate())

	return copy

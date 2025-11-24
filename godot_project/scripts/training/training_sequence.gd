## TrainingSequence - Top-level container for a complete training program
## Contains phases and represents a full training experience (e.g., "Level 1")
##
## Design: Data-driven resource that defines an entire training level
## Can be saved as .tres files and loaded at runtime
class_name TrainingSequence
extends Resource

# =============================================================================
# IDENTITY
# =============================================================================

## Unique identifier for this sequence (used for save data, unlocks, etc.)
@export var sequence_id: String = ""

## Display name shown to player
@export var display_name: String = ""

## Description for menu/selection screen
@export var description: String = ""

## Detailed description (for expanded view)
@export_multiline var long_description: String = ""

# =============================================================================
# METADATA
# =============================================================================

@export_group("Metadata")
## Difficulty level (1-5)
@export_range(1, 5) var difficulty: int = 1

## Estimated duration in minutes
@export var estimated_duration_minutes: int = 5

## Focus areas for this training (for filtering/recommendations)
@export var focus_areas: Array[String] = []

## Tags for categorization
@export var tags: Array[String] = []

## Sequence icon (for UI)
@export var icon: Texture2D

## Version number (for save compatibility)
@export var version: int = 1

# =============================================================================
# PREREQUISITES
# =============================================================================

@export_group("Prerequisites")
## Other sequence IDs that must be completed before this one unlocks
@export var required_sequences: Array[String] = []

## Minimum player level (if applicable)
@export var required_level: int = 0

## Whether this sequence is always available (ignores prerequisites)
@export var always_available: bool = true

# =============================================================================
# ENVIRONMENT
# =============================================================================

@export_group("Environment")
## Preferred training environment (dojo, ocean, hyperspace)
@export var preferred_environment: String = "dojo"

## Allow environment override via settings
@export var allow_environment_override: bool = true

## Specific environment settings (lighting, ambiance, etc.)
@export var environment_config: Dictionary = {}

# =============================================================================
# PHASES
# =============================================================================

@export_group("Phases")
## Ordered list of phases in this sequence
@export var phases: Array[TrainingPhase] = []

## Whether phases must be completed in order
@export var linear_progression: bool = true

## Allow jumping to any phase (for practice mode)
@export var allow_phase_select: bool = false

# =============================================================================
# PROGRESSION
# =============================================================================

@export_group("Progression")
## Allow skipping phases
@export var allow_phase_skip: bool = true

## Show progress indicator (phase X of Y)
@export var show_progress: bool = true

## Allow restarting from current phase (vs full restart)
@export var allow_checkpoint_restart: bool = true

## Show summary screen at end
@export var show_summary: bool = true

## Awards/unlocks granted on completion
@export var completion_rewards: Array[String] = []

# =============================================================================
# SCORING
# =============================================================================

@export_group("Scoring")
## Enable scoring for this sequence
@export var scoring_enabled: bool = true

## Score thresholds for grades (e.g., {"S": 10000, "A": 8000, "B": 6000, "C": 4000})
@export var grade_thresholds: Dictionary = {}

## Track high scores
@export var track_high_score: bool = true

## Metrics to display in summary
@export var summary_metrics: Array[String] = [
	"total_duration",
	"accuracy",
	"blocks",
	"hits",
	"max_combo"
]

# =============================================================================
# ADAPTIVE DIFFICULTY
# =============================================================================

@export_group("Adaptive")
## Enable adaptive difficulty
@export var adaptive_enabled: bool = false

## Minimum difficulty multiplier
@export var adaptive_min: float = 0.5

## Maximum difficulty multiplier
@export var adaptive_max: float = 2.0

## How quickly difficulty adjusts
@export var adaptive_rate: float = 0.1

# =============================================================================
# HELPER METHODS
# =============================================================================

## Get total phase count
func get_phase_count() -> int:
	return phases.size()


## Get total wave count across all phases
func get_total_wave_count() -> int:
	var total := 0
	for phase in phases:
		total += phase.waves.size()
	return total


## Get total enemy count across entire sequence
func get_total_enemy_count() -> int:
	var total := 0
	for phase in phases:
		total += phase.get_total_enemy_count()
	return total


## Get phase by ID
func get_phase_by_id(phase_id: String) -> TrainingPhase:
	for phase in phases:
		if phase.phase_id == phase_id:
			return phase
	return null


## Get phase index by ID (-1 if not found)
func get_phase_index(phase_id: String) -> int:
	for i in range(phases.size()):
		if phases[i].phase_id == phase_id:
			return i
	return -1


## Get sequence summary for logging
func get_summary() -> String:
	var phase_count := phases.size()
	var wave_count := get_total_wave_count()
	var enemy_count := get_total_enemy_count()

	return "'%s' (difficulty %d, %d phases, %d waves, ~%d enemies)" % [
		display_name, difficulty, phase_count, wave_count, enemy_count
	]


## Get difficulty display string
func get_difficulty_display() -> String:
	match difficulty:
		1: return "Beginner"
		2: return "Easy"
		3: return "Normal"
		4: return "Hard"
		5: return "Expert"
		_: return "Unknown"


## Get estimated duration as formatted string
func get_duration_display() -> String:
	if estimated_duration_minutes < 1:
		return "< 1 min"
	elif estimated_duration_minutes == 1:
		return "1 min"
	else:
		return "%d mins" % estimated_duration_minutes


## Check if prerequisites are met
func check_prerequisites(completed_sequences: Array[String], player_level: int = 0) -> bool:
	if always_available:
		return true

	# Check required sequences
	for req in required_sequences:
		if req not in completed_sequences:
			return false

	# Check level requirement
	if required_level > 0 and player_level < required_level:
		return false

	return true


## Get list of unmet prerequisites
func get_unmet_prerequisites(completed_sequences: Array[String], player_level: int = 0) -> Array[String]:
	var unmet: Array[String] = []

	if always_available:
		return unmet

	for req in required_sequences:
		if req not in completed_sequences:
			unmet.append("Complete: %s" % req)

	if required_level > 0 and player_level < required_level:
		unmet.append("Reach level %d" % required_level)

	return unmet


## Validate this sequence definition
func validate() -> Array[String]:
	var errors: Array[String] = []

	if sequence_id.is_empty():
		errors.append("sequence_id is required")

	if display_name.is_empty():
		errors.append("display_name is required")

	if phases.is_empty():
		errors.append("Sequence must have at least one phase")

	# Check for duplicate phase IDs
	var seen_ids: Dictionary = {}
	for phase in phases:
		if phase.phase_id in seen_ids:
			errors.append("Duplicate phase_id: %s" % phase.phase_id)
		seen_ids[phase.phase_id] = true

	# Validate each phase
	for i in range(phases.size()):
		var phase_errors := phases[i].validate()
		for err in phase_errors:
			errors.append("phases[%d] (%s): %s" % [i, phases[i].phase_id, err])

	# Check grade thresholds are valid
	if not grade_thresholds.is_empty():
		var prev_value := -1
		for grade in ["S", "A", "B", "C", "D"]:
			if grade in grade_thresholds:
				var value: int = grade_thresholds[grade]
				if prev_value >= 0 and value >= prev_value:
					errors.append("Grade thresholds must be in descending order")
					break
				prev_value = value

	return errors


## Get validation status
func is_valid() -> bool:
	return validate().is_empty()


## Create a deep copy of this sequence
func duplicate_deep() -> TrainingSequence:
	var copy := TrainingSequence.new()
	copy.sequence_id = sequence_id
	copy.display_name = display_name
	copy.description = description
	copy.long_description = long_description
	copy.difficulty = difficulty
	copy.estimated_duration_minutes = estimated_duration_minutes
	copy.focus_areas = focus_areas.duplicate()
	copy.tags = tags.duplicate()
	copy.icon = icon
	copy.version = version
	copy.required_sequences = required_sequences.duplicate()
	copy.required_level = required_level
	copy.always_available = always_available
	copy.preferred_environment = preferred_environment
	copy.allow_environment_override = allow_environment_override
	copy.environment_config = environment_config.duplicate(true)
	copy.linear_progression = linear_progression
	copy.allow_phase_select = allow_phase_select
	copy.allow_phase_skip = allow_phase_skip
	copy.show_progress = show_progress
	copy.allow_checkpoint_restart = allow_checkpoint_restart
	copy.show_summary = show_summary
	copy.completion_rewards = completion_rewards.duplicate()
	copy.scoring_enabled = scoring_enabled
	copy.grade_thresholds = grade_thresholds.duplicate()
	copy.track_high_score = track_high_score
	copy.summary_metrics = summary_metrics.duplicate()
	copy.adaptive_enabled = adaptive_enabled
	copy.adaptive_min = adaptive_min
	copy.adaptive_max = adaptive_max
	copy.adaptive_rate = adaptive_rate

	for phase in phases:
		copy.phases.append(phase.duplicate_deep())

	return copy


## Convert to dictionary for serialization
func to_dict() -> Dictionary:
	return {
		"sequence_id": sequence_id,
		"display_name": display_name,
		"difficulty": difficulty,
		"phase_count": phases.size(),
		"wave_count": get_total_wave_count(),
		"enemy_count": get_total_enemy_count(),
		"estimated_duration": estimated_duration_minutes,
		"version": version
	}

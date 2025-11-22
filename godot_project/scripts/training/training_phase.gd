## TrainingPhase - Defines a phase (learning segment) within a training sequence
## Contains one or more waves and represents a specific training goal
##
## Design: Phases group waves around a learning objective
## Example: "Saber Basics" phase has 3 waves of increasing deflection difficulty
class_name TrainingPhase
extends Resource

# =============================================================================
# PHASE TYPES
# =============================================================================

enum PhaseType {
	INTRO,             # Non-combat introduction (controls, story, etc.)
	TUTORIAL,          # Guided tutorial with prompts
	DRILL,             # Focused skill practice
	COMBAT,            # Full combat engagement
	BOSS,              # Single powerful enemy or climactic fight
	CHALLENGE,         # Optional difficulty spike
	SUMMARY,           # End-of-sequence stats display
	TRANSITION,        # Brief pause between major sections
	CUSTOM,            # For scripted/special phases
}

enum CompletionType {
	ALL_WAVES,         # Phase ends when all waves complete
	ANY_WAVE,          # Phase ends when any wave completes (for branching)
	OBJECTIVE,         # Phase ends when specific objective met
	TIMED,             # Phase ends after duration (for intros)
	MANUAL,            # Phase ends via external trigger
}

# =============================================================================
# IDENTITY
# =============================================================================

## Unique identifier for this phase
@export var phase_id: String = ""

## Display name shown to player
@export var display_name: String = ""

## Description of learning goal
@export var description: String = ""

## Phase category
@export var phase_type: PhaseType = PhaseType.DRILL

# =============================================================================
# LEARNING OBJECTIVE
# =============================================================================

@export_group("Objective")
## Main objective text (shown during phase)
@export var objective_text: String = ""

## Hint text for struggling players
@export var hint_text: String = ""

## Secondary objectives (optional challenges)
@export var bonus_objectives: Array[String] = []

# =============================================================================
# WAVES
# =============================================================================

@export_group("Waves")
## Waves in this phase (executed in order unless completion_type says otherwise)
@export var waves: Array[TrainingWave] = []

## Delay between waves (seconds)
@export var inter_wave_delay: float = 1.5

## Whether to show wave number to player
@export var show_wave_numbers: bool = false

# =============================================================================
# COMPLETION
# =============================================================================

@export_group("Completion")
## How this phase completes
@export var completion_type: CompletionType = CompletionType.ALL_WAVES

## Duration for TIMED completion type (seconds)
@export var timed_duration: float = 10.0

## Maximum phase duration before auto-complete (0 = no limit)
@export var timeout_seconds: float = 0.0

## Allow player to skip this phase
@export var allow_skip: bool = false

## Skip input hint (e.g., "Press A to skip")
@export var skip_hint: String = ""

## Auto-advance to next phase after completion
@export var auto_advance: bool = true

## Delay before auto-advance (seconds)
@export var advance_delay: float = 1.5

# =============================================================================
# FEEDBACK
# =============================================================================

@export_group("Feedback")
## Message shown when phase starts
@export var intro_message: String = ""

## Message shown when phase completes successfully
@export var success_message: String = ""

## Message shown if phase times out or fails
@export var failure_message: String = ""

## Play a sound/effect on phase start (resource path)
@export var start_sound: String = ""

## Play a sound/effect on completion
@export var complete_sound: String = ""

# =============================================================================
# METRICS TRACKING
# =============================================================================

@export_group("Metrics")
## Which metrics to track for this phase
@export var tracked_metrics: Array[String] = ["duration", "hits", "misses"]

## Whether to show metrics at phase end
@export var show_phase_stats: bool = false

# =============================================================================
# DIFFICULTY
# =============================================================================

@export_group("Difficulty")
## Base difficulty level (1-5, used for adaptive difficulty)
@export var base_difficulty: int = 1

## Allow adaptive difficulty adjustments
@export var allow_adaptive: bool = true

## Difficulty ramp per wave (multiplier increase)
@export var difficulty_ramp: float = 0.0

# =============================================================================
# HELPER METHODS
# =============================================================================

## Get total wave count
func get_wave_count() -> int:
	return waves.size()


## Get total enemy count across all waves
func get_total_enemy_count() -> int:
	var total := 0
	for wave in waves:
		total += wave.get_total_enemy_count()
	return total


## Get display name for phase type
static func get_phase_type_name(type: PhaseType) -> String:
	match type:
		PhaseType.INTRO: return "Introduction"
		PhaseType.TUTORIAL: return "Tutorial"
		PhaseType.DRILL: return "Drill"
		PhaseType.COMBAT: return "Combat"
		PhaseType.BOSS: return "Boss"
		PhaseType.CHALLENGE: return "Challenge"
		PhaseType.SUMMARY: return "Summary"
		PhaseType.TRANSITION: return "Transition"
		PhaseType.CUSTOM: return "Custom"
		_: return "Unknown"


## Get phase summary for logging
func get_summary() -> String:
	var type_name := get_phase_type_name(phase_type)
	var wave_count := waves.size()
	var enemy_count := get_total_enemy_count()

	if wave_count == 0:
		return "%s '%s' (no waves)" % [type_name, display_name]
	else:
		return "%s '%s' (%d waves, %d enemies)" % [type_name, display_name, wave_count, enemy_count]


## Check if this is a non-combat phase
func is_non_combat() -> bool:
	return phase_type in [PhaseType.INTRO, PhaseType.SUMMARY, PhaseType.TRANSITION]


## Check if phase should show intro message
func has_intro_message() -> bool:
	return not intro_message.is_empty()


## Get estimated duration (rough calculation)
func get_estimated_duration() -> float:
	if completion_type == CompletionType.TIMED:
		return timed_duration

	var duration := 0.0
	for wave in waves:
		# Estimate based on timeout or reasonable default
		if wave.timeout_seconds > 0:
			duration += wave.timeout_seconds * 0.5  # Assume average completion
		else:
			duration += 30.0  # Default estimate per wave
		duration += inter_wave_delay

	return duration


## Validate this phase definition
func validate() -> Array[String]:
	var errors: Array[String] = []

	if phase_id.is_empty():
		errors.append("phase_id is required")

	if display_name.is_empty():
		errors.append("display_name is recommended")

	# Non-combat phases don't need waves
	if not is_non_combat() and waves.is_empty():
		errors.append("Combat phases should have waves")

	# TIMED completion needs duration
	if completion_type == CompletionType.TIMED and timed_duration <= 0:
		errors.append("TIMED completion requires timed_duration > 0")

	# Validate each wave
	for i in range(waves.size()):
		var wave_errors := waves[i].validate()
		for err in wave_errors:
			errors.append("waves[%d] (%s): %s" % [i, waves[i].wave_id, err])

	return errors


## Get wave by ID
func get_wave_by_id(wave_id: String) -> TrainingWave:
	for wave in waves:
		if wave.wave_id == wave_id:
			return wave
	return null


## Create a deep copy of this phase
func duplicate_deep() -> TrainingPhase:
	var copy := TrainingPhase.new()
	copy.phase_id = phase_id
	copy.display_name = display_name
	copy.description = description
	copy.phase_type = phase_type
	copy.objective_text = objective_text
	copy.hint_text = hint_text
	copy.bonus_objectives = bonus_objectives.duplicate()
	copy.inter_wave_delay = inter_wave_delay
	copy.show_wave_numbers = show_wave_numbers
	copy.completion_type = completion_type
	copy.timed_duration = timed_duration
	copy.timeout_seconds = timeout_seconds
	copy.allow_skip = allow_skip
	copy.skip_hint = skip_hint
	copy.auto_advance = auto_advance
	copy.advance_delay = advance_delay
	copy.intro_message = intro_message
	copy.success_message = success_message
	copy.failure_message = failure_message
	copy.start_sound = start_sound
	copy.complete_sound = complete_sound
	copy.tracked_metrics = tracked_metrics.duplicate()
	copy.show_phase_stats = show_phase_stats
	copy.base_difficulty = base_difficulty
	copy.allow_adaptive = allow_adaptive
	copy.difficulty_ramp = difficulty_ramp

	for wave in waves:
		copy.waves.append(wave.duplicate_deep())

	return copy

## Level1Feedback - Tutorial prompts and visual feedback for Level 1 training
## Shows phase instructions, combat feedback, and summary panel
## Gracefully degrades if UI systems are missing
extends Node3D
class_name Level1Feedback

const SOURCE := "L1Feedback"

# =============================================================================
# CONFIGURATION
# =============================================================================

@export_group("Positioning")
## Distance in front of player for main prompt
@export var prompt_distance := 2.0
## Height offset for main prompt
@export var prompt_height := 1.4
## Distance for quick feedback text
@export var feedback_distance := 1.5

@export_group("Timing")
## Duration for quick feedback messages
@export var feedback_duration := 1.5
## Duration for phase instruction display
@export var instruction_duration := 5.0

@export_group("Colors")
@export var instruction_color := Color(0.9, 0.9, 1.0)  # Soft white
@export var success_color := Color(0.3, 1.0, 0.4)     # Green
@export var warning_color := Color(1.0, 0.8, 0.2)      # Yellow
@export var danger_color := Color(1.0, 0.3, 0.3)       # Red
@export var info_color := Color(0.4, 0.8, 1.0)         # Cyan

# =============================================================================
# STATE
# =============================================================================

var camera: XRCamera3D
var active_prompts: Array[WorldText] = []
var main_instruction: WorldText
var summary_panel: Node3D

# Feedback counters for throttling
var _last_block_time := 0.0
var _last_hit_time := 0.0
const FEEDBACK_COOLDOWN := 0.3  # Don't spam feedback

# =============================================================================
# LIFECYCLE
# =============================================================================

func _ready() -> void:
	DebugLogger.debug(SOURCE, "Level1Feedback initialized")


func _exit_tree() -> void:
	clear_all()


# =============================================================================
# SETUP
# =============================================================================

func setup(xr_camera: XRCamera3D) -> void:
	camera = xr_camera
	DebugLogger.debug(SOURCE, "Feedback system configured with camera")


# =============================================================================
# PHASE INSTRUCTIONS
# =============================================================================

## Show main instruction for a phase
func show_phase_instruction(phase: String, instruction: String, objective: String = "") -> void:
	# Clear previous instruction
	if main_instruction and is_instance_valid(main_instruction):
		main_instruction.queue_free()

	# Calculate position in front of player
	var pos := _get_position_in_front(prompt_distance, prompt_height)

	# Create instruction text
	main_instruction = WorldText.new()
	main_instruction.name = "PhaseInstruction"
	main_instruction.font_size = 48
	main_instruction.text_color = instruction_color
	main_instruction.fade_in_duration = 0.5
	main_instruction.fade_out_duration = 0.5
	add_child(main_instruction)
	main_instruction.global_position = pos

	# Format: "PHASE NAME\nInstruction text\nObjective"
	var full_text := "— %s —\n%s" % [phase, instruction]
	if objective != "":
		full_text += "\n\n[%s]" % objective

	main_instruction.show_text(full_text, instruction_duration)

	# Log for debugging
	DebugLogger.info(SOURCE, "Showing instruction: %s - %s" % [phase, instruction])


## Clear the main instruction
func clear_phase_instruction() -> void:
	if main_instruction and is_instance_valid(main_instruction):
		main_instruction.dismiss()


# =============================================================================
# QUICK FEEDBACK
# =============================================================================

## Show quick feedback text (e.g., "BLOCKED!", "HIT!")
func show_feedback(text: String, color: Color = Color.WHITE, size: int = 36) -> void:
	# Throttle feedback to prevent spam
	var now := Time.get_ticks_msec() / 1000.0
	if now - _last_block_time < FEEDBACK_COOLDOWN:
		return
	_last_block_time = now

	# Calculate position (slightly randomized for variety)
	var pos := _get_position_in_front(feedback_distance, 1.2)
	pos += Vector3(
		randf_range(-0.3, 0.3),
		randf_range(-0.1, 0.1),
		randf_range(-0.1, 0.1)
	)

	var feedback := WorldText.create(text, pos, color, size, feedback_duration)
	feedback.name = "QuickFeedback"
	add_child(feedback)
	active_prompts.append(feedback)

	# Connect cleanup
	feedback.dismissed.connect(_on_feedback_dismissed.bind(feedback))


## Show "BLOCKED!" feedback
func show_blocked_feedback() -> void:
	show_feedback("BLOCKED!", success_color, 42)


## Show "HIT!" feedback for hitting a target
func show_hit_feedback() -> void:
	show_feedback("HIT!", success_color, 38)


## Show "DESTROYED!" feedback
func show_destroyed_feedback() -> void:
	show_feedback("DESTROYED!", info_color, 40)


## Show "OUCH!" feedback when player is hit
func show_player_hit_feedback() -> void:
	show_feedback("OUCH!", danger_color, 44)


## Show "WATCH OUT!" warning
func show_warning_feedback(text: String = "WATCH OUT!") -> void:
	show_feedback(text, warning_color, 46)


## Show dive attack warning
func show_dive_warning() -> void:
	show_feedback("⚠ DIVE ATTACK!", warning_color, 52)


## Show dive evaded feedback
func show_dive_evaded_feedback() -> void:
	show_feedback("EVADED!", success_color, 44)


# =============================================================================
# PROGRESS FEEDBACK
# =============================================================================

## Show progress update (e.g., "2/3 blocked")
func show_progress(current: int, total: int, action: String) -> void:
	var text := "%d/%d %s" % [current, total, action]
	var color := info_color if current < total else success_color
	show_feedback(text, color, 32)


## Show completion message
func show_phase_complete(phase: String) -> void:
	show_feedback("%s COMPLETE!" % phase, success_color, 48)


# =============================================================================
# SUMMARY DISPLAY
# =============================================================================

## Show summary panel with stats
func show_summary(stats: Dictionary) -> void:
	# Clear previous summary if exists
	if summary_panel and is_instance_valid(summary_panel):
		summary_panel.queue_free()

	# Create summary container
	summary_panel = Node3D.new()
	summary_panel.name = "SummaryPanel"
	add_child(summary_panel)

	# Position in front of player
	var base_pos := _get_position_in_front(2.5, 1.5)
	summary_panel.global_position = base_pos

	# Create title
	var title := WorldText.create(
		"— TRAINING COMPLETE —",
		Vector3.ZERO,
		success_color,
		56,
		0.0  # Don't auto-dismiss
	)
	title.fade_in_duration = 0.8
	summary_panel.add_child(title)

	# Calculate stats
	var saber_blocks: int = stats.get("saber_projectiles_blocked", 0)
	var saber_missed: int = stats.get("saber_projectiles_missed", 0)
	var blaster_hits: int = stats.get("blaster_hits", 0)
	var mixed_drones: int = stats.get("mixed_drones_destroyed", 0)
	var dive_blocked: bool = stats.get("mixed_dive_blocked", false)
	var total_time: float = stats.get("total_duration", 0.0)

	# Calculate accuracy
	var total_shots := blaster_hits + stats.get("blaster_misses", 0)
	var accuracy := 100.0 if total_shots == 0 else (float(blaster_hits) / float(max(total_shots, 1)) * 100.0)

	# Build stats text
	var stats_lines := [
		"",
		"SABER DRILL",
		"  Projectiles Blocked: %d" % saber_blocks,
		"  Hits Taken: %d" % saber_missed,
		"",
		"BLASTER DRILL",
		"  Targets Destroyed: %d" % blaster_hits,
		"",
		"MIXED DRILL",
		"  Drones Destroyed: %d" % mixed_drones,
		"  Dive Attack: %s" % ("EVADED" if dive_blocked else "missed"),
		"",
		"TOTAL TIME: %.0fs" % total_time,
	]

	var stats_text := "\n".join(stats_lines)

	var stats_label := WorldText.create(
		stats_text,
		Vector3(0, -0.4, 0),
		instruction_color,
		28,
		0.0
	)
	stats_label.fade_in_duration = 1.0
	summary_panel.add_child(stats_label)

	# Add instruction to exit
	var exit_hint := WorldText.create(
		"\n\nPress MENU to exit  •  TRIGGER to restart",
		Vector3(0, -0.9, 0),
		Color(0.6, 0.6, 0.7),
		22,
		0.0
	)
	exit_hint.fade_in_duration = 1.5
	summary_panel.add_child(exit_hint)

	# Log summary
	_log_structured_summary(stats)


## Clear summary panel
func clear_summary() -> void:
	if summary_panel and is_instance_valid(summary_panel):
		summary_panel.queue_free()
		summary_panel = null


# =============================================================================
# HELPERS
# =============================================================================

func _get_position_in_front(distance: float, height: float) -> Vector3:
	if camera == null:
		# Fallback: use origin
		return Vector3(0, height, -distance)

	# Get camera position and forward direction
	var cam_pos := camera.global_position
	var cam_forward := -camera.global_transform.basis.z

	# Project forward on XZ plane (ignore vertical component)
	cam_forward.y = 0
	cam_forward = cam_forward.normalized()

	# Calculate world position
	var pos := cam_pos + cam_forward * distance
	pos.y = height

	return pos


func _on_feedback_dismissed(feedback: WorldText) -> void:
	var idx := active_prompts.find(feedback)
	if idx >= 0:
		active_prompts.remove_at(idx)
	if is_instance_valid(feedback):
		feedback.queue_free()


func clear_all() -> void:
	# Clear main instruction
	if main_instruction and is_instance_valid(main_instruction):
		main_instruction.queue_free()
		main_instruction = null

	# Clear active prompts
	for prompt in active_prompts:
		if is_instance_valid(prompt):
			prompt.queue_free()
	active_prompts.clear()

	# Clear summary
	clear_summary()


# =============================================================================
# STRUCTURED LOGGING
# =============================================================================

func _log_structured_summary(stats: Dictionary) -> void:
	DebugLogger.info(SOURCE, "")
	DebugLogger.info(SOURCE, "╔════════════════════════════════════════╗")
	DebugLogger.info(SOURCE, "║      LEVEL 1 TRAINING SUMMARY          ║")
	DebugLogger.info(SOURCE, "╚════════════════════════════════════════╝")
	DebugLogger.info(SOURCE, "")

	# Saber drill
	var saber_blocks: int = stats.get("saber_projectiles_blocked", 0)
	var saber_missed: int = stats.get("saber_projectiles_missed", 0)
	var saber_duration: float = stats.get("saber_duration", 0.0)
	DebugLogger.info(SOURCE, "SABER_DRILL: blocks=%d hits_taken=%d duration=%.1fs" % [
		saber_blocks, saber_missed, saber_duration
	])

	# Blaster drill
	var blaster_shots: int = stats.get("blaster_shots_fired", 0)
	var blaster_hits: int = stats.get("blaster_hits", 0)
	var blaster_duration: float = stats.get("blaster_duration", 0.0)
	DebugLogger.info(SOURCE, "BLASTER_DRILL: shots=%d hits=%d duration=%.1fs" % [
		blaster_shots, blaster_hits, blaster_duration
	])

	# Mixed drill
	var mixed_drones: int = stats.get("mixed_drones_destroyed", 0)
	var dive_blocked: bool = stats.get("mixed_dive_blocked", false)
	var mixed_duration: float = stats.get("mixed_duration", 0.0)
	DebugLogger.info(SOURCE, "MIXED_DRILL: drones=%d dive_evaded=%s duration=%.1fs" % [
		mixed_drones, dive_blocked, mixed_duration
	])

	# Overall
	var total_duration: float = stats.get("total_duration", 0.0)
	DebugLogger.info(SOURCE, "")
	DebugLogger.info(SOURCE, "TOTAL: duration=%.1fs states=%s" % [
		total_duration,
		", ".join(stats.get("states_visited", []))
	])
	DebugLogger.info(SOURCE, "")


# =============================================================================
# PHASE-SPECIFIC PROMPTS
# =============================================================================

## Show intro phase prompt
func show_intro_prompt() -> void:
	show_phase_instruction(
		"WELCOME",
		"Welcome to Dojo Training!\nGet ready to practice combat basics.",
		"Trigger to skip"
	)


## Show saber drill prompt
func show_saber_drill_prompt(required_blocks: int) -> void:
	show_phase_instruction(
		"SABER DRILL",
		"Block the incoming projectiles\nwith your lightsaber!",
		"Block %d projectiles" % required_blocks
	)


## Show blaster drill prompt
func show_blaster_drill_prompt(required_hits: int) -> void:
	show_phase_instruction(
		"BLASTER DRILL",
		"Aim with your left hand and\ndestroy the target drones!",
		"Destroy %d drones" % required_hits
	)


## Show mixed drill prompt
func show_mixed_drill_prompt(required_drones: int, has_dive: bool) -> void:
	var objective := "Destroy %d drones" % required_drones
	if has_dive:
		objective += " + evade DIVE"

	show_phase_instruction(
		"MIXED DRILL",
		"Handle both threats!\nShoot drones and block projectiles.",
		objective
	)

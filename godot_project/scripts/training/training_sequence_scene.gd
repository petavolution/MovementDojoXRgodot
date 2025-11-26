## TrainingSequenceScene - Entry point for data-driven training sequences
## Extends BaseVRScene for consistent XR initialization
## Loads a sequence from SequenceLibrary and runs it
##
## Launch with: godot --training-sequence=level1
## Or: godot --training-sequence-level1
class_name TrainingSequenceScene
extends BaseVRScene

const SOURCE := "TrnSeqScene"

# =============================================================================
# STATE
# =============================================================================

# Training-specific components
var sequence_controller: TrainingSequenceController
var environment_loader: EnvironmentLoader
var feedback_ui: Level1Feedback  # Reuse existing feedback system

var entities_container: Node3D

var is_initialized := false
var selected_sequence_id: String = ""
var selected_environment: XRHelpers.EnvironmentType = XRHelpers.EnvironmentType.DOJO

# =============================================================================
# LIFECYCLE
# =============================================================================

func _ready() -> void:
	DebugLogger.info(SOURCE, "")
	DebugLogger.info(SOURCE, "╔═══════════════════════════════════════════════════════════╗")
	DebugLogger.info(SOURCE, "║       TRAINING SEQUENCE MODE (Data-Driven)                ║")
	DebugLogger.info(SOURCE, "╚═══════════════════════════════════════════════════════════╝")
	DebugLogger.info(SOURCE, "")

	# Get sequence ID from command line (if not already set by parent)
	if selected_sequence_id.is_empty():
		selected_sequence_id = XRHelpers.get_training_sequence_id()
	if selected_sequence_id.is_empty():
		selected_sequence_id = "level1_fundamentals"  # Default
	DebugLogger.info(SOURCE, "Selected sequence: %s" % selected_sequence_id)

	# Get environment preference
	selected_environment = XRHelpers.get_environment_flag()
	DebugLogger.info(SOURCE, "Selected environment: %s" % XRHelpers.get_environment_name(selected_environment))

	# Validate sequence exists and is valid (before XR initialization)
	if not _validate_sequence():
		DebugLogger.error(SOURCE, "Sequence validation failed - aborting")
		_abort_with_error("Invalid sequence")
		return

	# Call base class to handle XR initialization
	# This will call _on_xr_initialized() when ready
	super._ready()


## Validate sequence exists and is structurally correct (training-specific preflight)
func _validate_sequence() -> bool:
	DebugLogger.info(SOURCE, "Validating sequence...")

	# Check sequence exists
	var available := SequenceLibrary.get_available_sequences()
	var sequence_exists := false
	for seq_id in available:
		if seq_id == selected_sequence_id or seq_id.begins_with(selected_sequence_id):
			sequence_exists = true
			selected_sequence_id = seq_id  # Use full ID
			break

	if not sequence_exists:
		DebugLogger.error(SOURCE, "  FAIL: Unknown sequence '%s'" % selected_sequence_id)
		DebugLogger.info(SOURCE, "  Available sequences: %s" % ", ".join(available))
		return false
	DebugLogger.info(SOURCE, "  ✓ Sequence '%s' found" % selected_sequence_id)

	# Check sequence is valid
	var sequence := SequenceLibrary.get_sequence(selected_sequence_id)
	if sequence == null:
		DebugLogger.error(SOURCE, "  FAIL: Could not create sequence")
		return false

	var errors := sequence.validate()
	if not errors.is_empty():
		DebugLogger.error(SOURCE, "  FAIL: Sequence validation errors:")
		for err in errors:
			DebugLogger.error(SOURCE, "    - %s" % err)
		return false
	DebugLogger.info(SOURCE, "  ✓ Sequence is valid")

	DebugLogger.info(SOURCE, "Sequence validation: PASSED")
	return true


## Called by BaseVRScene after successful XR initialization
func _on_xr_initialized() -> void:
	DebugLogger.info(SOURCE, "XR initialized, building training scene...")

	# Build scene components
	DebugLogger.info(SOURCE, "Building scene components...")
	_build_environment()
	_build_entities_container()
	_build_feedback_ui()
	_build_sequence_controller()

	# Validate critical components
	if sequence_controller == null:
		DebugLogger.error(SOURCE, "CRITICAL: Sequence controller not created")
		_abort_with_error("Sequence controller creation failed")
		return

	# Load and start sequence
	_load_and_start_sequence()

	is_initialized = true
	DebugLogger.info(SOURCE, "Training sequence scene initialized successfully")
	DebugLogger.info(SOURCE, "Ready for VR training!")
	DebugLogger.flush()  # Ensure initialization is logged before VR starts


## Called by BaseVRScene when XR initialization fails
func _on_xr_failed(reason: String) -> void:
	DebugLogger.error(SOURCE, "XR initialization failed: %s" % reason)
	_abort_with_error(reason)


# =============================================================================
# XR SETUP COMPLETE - Now handled by BaseVRScene
# Removed ~170 lines of duplicated XR initialization code
# See godot_project/scripts/core/base_vr_scene.gd for implementation
# =============================================================================

# =============================================================================
# SCENE BUILDING (Training-Specific)
# =============================================================================

func _build_environment() -> void:
	DebugLogger.debug(SOURCE, "Building environment...")

	environment_loader = EnvironmentLoader.new()
	environment_loader.name = "EnvironmentLoader"
	add_child(environment_loader)

	# Override with sequence's preferred environment if not specified on CLI
	var cli_env := XRHelpers.get_environment_flag()
	if cli_env == XRHelpers.EnvironmentType.DOJO:
		# Check if sequence has a preference
		var sequence := SequenceLibrary.get_sequence(selected_sequence_id)
		if sequence and sequence.preferred_environment:
			var pref := sequence.preferred_environment.to_lower()
			if pref == "ocean":
				selected_environment = XRHelpers.EnvironmentType.OCEAN
			elif pref == "hyperspace":
				selected_environment = XRHelpers.EnvironmentType.HYPERSPACE

	environment_loader.load_environment(selected_environment)
	DebugLogger.debug(SOURCE, "Environment loaded: %s" % XRHelpers.get_environment_name(selected_environment))


func _build_entities_container() -> void:
	entities_container = Node3D.new()
	entities_container.name = "Entities"
	add_child(entities_container)
	DebugLogger.debug(SOURCE, "Entities container created")


func _build_feedback_ui() -> void:
	feedback_ui = Level1Feedback.new()
	feedback_ui.name = "Feedback"
	add_child(feedback_ui)
	feedback_ui.setup(xr_camera)
	DebugLogger.debug(SOURCE, "Feedback UI created")


func _build_sequence_controller() -> void:
	sequence_controller = TrainingSequenceController.new()
	sequence_controller.name = "SequenceController"
	add_child(sequence_controller)

	# Setup controller with dependencies
	sequence_controller.setup(xr_camera, entities_container, feedback_ui)

	# Connect signals for feedback and logging
	sequence_controller.sequence_started.connect(_on_sequence_started)
	sequence_controller.sequence_completed.connect(_on_sequence_completed)
	sequence_controller.sequence_aborted.connect(_on_sequence_aborted)
	sequence_controller.phase_started.connect(_on_phase_started)
	sequence_controller.phase_completed.connect(_on_phase_completed)
	sequence_controller.wave_started.connect(_on_wave_started)
	sequence_controller.wave_completed.connect(_on_wave_completed)
	sequence_controller.objective_progress.connect(_on_objective_progress)
	sequence_controller.feedback_message.connect(_on_feedback_message)

	# Enable debug mode if flag is present
	if XRHelpers.has_training_debug_flag():
		sequence_controller.enable_debug_mode()

	DebugLogger.debug(SOURCE, "Sequence controller created")


# =============================================================================
# SEQUENCE EXECUTION
# =============================================================================

func _load_and_start_sequence() -> void:
	DebugLogger.info(SOURCE, "Loading sequence: %s" % selected_sequence_id)

	# Get sequence from library
	var sequence := SequenceLibrary.get_sequence(selected_sequence_id)
	if sequence == null:
		DebugLogger.error(SOURCE, "Failed to get sequence from library")
		_abort_with_error("Sequence not found")
		return

	# Load into controller
	if not sequence_controller.load_sequence(sequence):
		DebugLogger.error(SOURCE, "Failed to load sequence into controller")
		_abort_with_error("Sequence load failed")
		return

	# Start execution
	DebugLogger.info(SOURCE, "Starting sequence execution...")
	sequence_controller.start()


# =============================================================================
# SIGNAL HANDLERS
# =============================================================================

func _on_sequence_started(sequence: TrainingSequence) -> void:
	DebugLogger.info(SOURCE, "Sequence started: %s" % sequence.display_name)
	if feedback_ui:
		feedback_ui.show_phase_instruction(
			"Training: %s" % sequence.display_name,
			sequence.description
		)


func _on_sequence_completed(sequence: TrainingSequence, results: Dictionary) -> void:
	DebugLogger.info(SOURCE, "")
	DebugLogger.info(SOURCE, "=== SEQUENCE COMPLETED ===")
	DebugLogger.info(SOURCE, "Sequence: %s" % sequence.display_name)
	DebugLogger.info(SOURCE, "Duration: %.1fs" % results.get("total_duration", 0.0))
	DebugLogger.info(SOURCE, "Phases completed: %d" % results.get("phases_completed", 0))
	DebugLogger.info(SOURCE, "")

	# Show summary in VR
	if feedback_ui:
		feedback_ui.show_summary(results)


func _on_sequence_aborted(sequence: TrainingSequence, reason: String) -> void:
	DebugLogger.warn(SOURCE, "Sequence aborted: %s - Reason: %s" % [sequence.display_name, reason])
	if feedback_ui:
		feedback_ui.show_phase_instruction("Training Aborted", reason)


func _on_phase_started(phase: TrainingPhase, phase_index: int, total_phases: int) -> void:
	DebugLogger.info(SOURCE, "Phase %d/%d started: %s" % [phase_index + 1, total_phases, phase.display_name])

	if feedback_ui:
		# Build instruction text with objective and optional hint
		var instruction := phase.objective_text if phase.objective_text else phase.description
		if phase.hint_text and not phase.hint_text.is_empty():
			instruction += "\n\n💡 %s" % phase.hint_text

		feedback_ui.show_phase_instruction(
			phase.display_name,
			instruction
		)


func _on_phase_completed(phase: TrainingPhase, phase_stats: Dictionary) -> void:
	DebugLogger.info(SOURCE, "Phase completed: %s (%.1fs)" % [
		phase.display_name,
		phase_stats.get("duration", 0.0)
	])


func _on_wave_started(wave: TrainingWave, wave_index: int, total_waves: int) -> void:
	DebugLogger.debug(SOURCE, "Wave %d/%d started: %s" % [wave_index + 1, total_waves, wave.wave_id])

	if feedback_ui:
		# Show wave number indicator
		feedback_ui.show_wave_info(wave_index, total_waves, wave.display_name)

		# Show start message if present
		if wave.start_message:
			# Small delay so wave info shows first
			await get_tree().create_timer(0.3).timeout
			feedback_ui.show_quick_feedback(wave.start_message, Color.WHITE)


func _on_wave_completed(wave: TrainingWave, wave_stats: Dictionary) -> void:
	var success: bool = wave_stats.get("success", false)
	DebugLogger.debug(SOURCE, "Wave completed: %s (success=%s)" % [wave.wave_id, success])

	if feedback_ui and success:
		# Show wave summary with rating
		var kills := wave_stats.get("enemies_destroyed", 0)
		var blocks := wave_stats.get("projectiles_blocked", 0)
		var hits := wave_stats.get("hits_taken", 0)
		var rating := wave_stats.get("rating", 1)
		feedback_ui.show_wave_summary(kills, blocks, hits, rating)


func _on_objective_progress(current: int, target: int, description: String) -> void:
	if feedback_ui:
		feedback_ui.show_progress(current, target, description)


func _on_feedback_message(message: String, message_type: String) -> void:
	if not feedback_ui:
		return

	var color := Color.WHITE
	match message_type:
		"success":
			color = Color.GREEN
		"warning":
			color = Color.YELLOW
		"error":
			color = Color.RED
		"info":
			color = Color.CYAN

	feedback_ui.show_quick_feedback(message, color)


# =============================================================================
# UTILITIES
# =============================================================================

func _request_exit() -> void:
	DebugLogger.info(SOURCE, "Exit requested")
	if sequence_controller and sequence_controller.is_running():
		sequence_controller.abort("User exit")
	get_tree().quit(0)


func _abort_with_error(reason: String) -> void:
	DebugLogger.error(SOURCE, "ABORT: %s" % reason)
	# Wait a frame then quit with error
	await get_tree().process_frame
	get_tree().quit(1)

## TrainingSequenceScene - Entry point for data-driven training sequences
## Initializes XR, loads a sequence from SequenceLibrary, and runs it
##
## Launch with: godot --training-sequence=level1
## Or: godot --training-sequence-level1
class_name TrainingSequenceScene
extends Node3D

const SOURCE := "TrnSeqScene"

# =============================================================================
# STATE
# =============================================================================

var xr_interface: XRInterface
var xr_origin: XROrigin3D
var xr_camera: XRCamera3D
var left_controller: XRController3D
var right_controller: XRController3D

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

	# Run preflight checks
	if not _run_preflight_checks():
		DebugLogger.error(SOURCE, "Preflight checks failed - aborting")
		_abort_with_error("Preflight checks failed")
		return

	# Build scene with validation
	DebugLogger.info(SOURCE, "Building scene components...")
	_build_xr_scene()
	if not _validate_xr_scene():
		_abort_with_error("XR scene validation failed")
		return

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


## Validate XR scene was built correctly
func _validate_xr_scene() -> bool:
	var valid := true

	if xr_origin == null:
		DebugLogger.error(SOURCE, "CRITICAL: XROrigin3D not created")
		valid = false
	if xr_camera == null:
		DebugLogger.error(SOURCE, "CRITICAL: XRCamera3D not created")
		valid = false

	# Controllers are expected but not strictly required
	if left_controller == null:
		DebugLogger.warn(SOURCE, "Left controller not created")
	if right_controller == null:
		DebugLogger.warn(SOURCE, "Right controller not created")

	if valid:
		DebugLogger.debug(SOURCE, "XR scene validation passed")
	return valid


func _process(delta: float) -> void:
	if not is_initialized:
		return

	# Check for exit input
	if Input.is_action_just_pressed("ui_cancel"):
		_request_exit()


func _exit_tree() -> void:
	DebugLogger.info(SOURCE, "Training sequence scene exiting")
	if sequence_controller and sequence_controller.is_running():
		sequence_controller.abort("Scene exit")


# =============================================================================
# PREFLIGHT CHECKS
# =============================================================================

func _run_preflight_checks() -> bool:
	DebugLogger.info(SOURCE, "Running preflight checks...")
	DebugLogger.flush()  # Ensure we capture logs even if VR crashes

	# Check 1: OpenXR initialization
	DebugLogger.info(SOURCE, "  [1/4] OpenXR initialization...")
	xr_interface = XRServer.find_interface("OpenXR")
	if xr_interface == null:
		DebugLogger.error(SOURCE, "  FAIL: OpenXR interface not found")
		DebugLogger.error(SOURCE, "  Check: Is SteamVR running and set as active OpenXR runtime?")
		DebugLogger.flush()
		return false

	if not xr_interface.is_initialized():
		DebugLogger.info(SOURCE, "  Initializing OpenXR interface...")
		var init_success := xr_interface.initialize()
		if not init_success:
			DebugLogger.error(SOURCE, "  FAIL: OpenXR failed to initialize")
			DebugLogger.error(SOURCE, "  Check: Is HMD connected via Virtual Desktop?")
			DebugLogger.error(SOURCE, "  Check: Is SteamVR detecting the Quest 3?")
			DebugLogger.flush()
			return false
	DebugLogger.info(SOURCE, "  PASS: OpenXR initialized")
	_log_xr_state()

	# Check 2: Sequence exists
	DebugLogger.info(SOURCE, "  [2/4] Sequence validation...")
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
	DebugLogger.info(SOURCE, "  PASS: Sequence '%s' found" % selected_sequence_id)

	# Check 3: Sequence is valid
	DebugLogger.info(SOURCE, "  [3/4] Sequence structure check...")
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
	DebugLogger.info(SOURCE, "  PASS: Sequence is valid")

	# Check 4: XR session is ready
	DebugLogger.info(SOURCE, "  [4/4] XR session ready check...")
	if xr_interface and xr_interface.is_initialized():
		var refresh := xr_interface.get_display_refresh_rate()
		if refresh > 0:
			DebugLogger.info(SOURCE, "  PASS: XR session ready (%.0f Hz)" % refresh)
		else:
			DebugLogger.warn(SOURCE, "  WARN: Refresh rate unknown, continuing anyway")
	else:
		DebugLogger.error(SOURCE, "  FAIL: XR interface lost during preflight")
		return false

	DebugLogger.info(SOURCE, "Preflight checks: ALL PASSED")
	DebugLogger.flush()  # Ensure preflight results are saved
	return true


## Log current XR system state for debugging
func _log_xr_state() -> void:
	if xr_interface == null:
		DebugLogger.warn(SOURCE, "  XR State: Interface is null")
		return

	DebugLogger.info(SOURCE, "  XR State:")
	DebugLogger.info(SOURCE, "    Interface: %s" % xr_interface.get_name())
	DebugLogger.info(SOURCE, "    Initialized: %s" % xr_interface.is_initialized())

	var refresh := xr_interface.get_display_refresh_rate()
	if refresh > 0:
		DebugLogger.info(SOURCE, "    Refresh Rate: %.0f Hz" % refresh)

	var render_size := xr_interface.get_render_target_size()
	if render_size.x > 0:
		DebugLogger.info(SOURCE, "    Render Size: %dx%d per eye" % [int(render_size.x), int(render_size.y)])


# =============================================================================
# SCENE BUILDING
# =============================================================================

func _build_xr_scene() -> void:
	DebugLogger.debug(SOURCE, "Building XR scene...")

	# Create XR Origin
	xr_origin = XROrigin3D.new()
	xr_origin.name = "XROrigin3D"
	add_child(xr_origin)

	# Create XR Camera
	xr_camera = XRCamera3D.new()
	xr_camera.name = "XRCamera3D"
	xr_origin.add_child(xr_camera)

	# Create left controller
	left_controller = XRController3D.new()
	left_controller.name = "LeftController"
	left_controller.tracker = "left_hand"
	xr_origin.add_child(left_controller)

	# Create right controller
	right_controller = XRController3D.new()
	right_controller.name = "RightController"
	right_controller.tracker = "right_hand"
	xr_origin.add_child(right_controller)

	# Enable XR
	get_viewport().use_xr = true

	DebugLogger.debug(SOURCE, "XR scene built")


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

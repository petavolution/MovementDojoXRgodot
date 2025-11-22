## Main VR Scene - Entry point and scene management
## Initializes XR, sets up tracking, and manages game state
## Enhanced with robust OpenXR error handling for Quest 3 + Virtual Desktop + SteamVR
extends Node3D

const SOURCE := "MainVR"
const XR_STARTUP_STEPS := 5

enum GameState {
	INITIALIZING,
	MENU,
	TRAINING,
	WELLNESS_ROUTINE,
	PAUSED
}

# XR nodes (required)
@onready var xr_origin: XROrigin3D = $XROrigin3D
@onready var xr_camera: XRCamera3D = $XROrigin3D/XRCamera3D
@onready var left_controller: XRController3D = $XROrigin3D/LeftController
@onready var right_controller: XRController3D = $XROrigin3D/RightController

# Game components (optional - null-safe access)
var left_saber: Lightsaber
var right_saber: Lightsaber
var movement_trail: MovementTrail
var heat_map: MovementHeatMap
var gap_indicators: GapIndicator
var movement_hud: MovementHUD
var dojo_environment: Node3D
var target_spawner: Node3D

# State
var current_state := GameState.INITIALIZING
var xr_interface: XRInterface
var xr_initialized := false
var desktop_mode := false
var xr_init_state := XRHelpers.XRInitState.NOT_STARTED
var xr_startup_results: XRHelpers.DiagnosticResults

# Desktop mode settings
var mouse_sensitivity := 0.003
var move_speed := 3.0

# Systems manager (lazy-loads secondary systems)
var systems: SystemsManager


func _ready() -> void:
	# Check for VR diagnostics mode
	if XRHelpers.has_diagnostics_flag():
		DebugLogger.info(SOURCE, "VR Diagnostics mode detected - switching to diagnostics scene")
		get_tree().change_scene_to_file("res://scenes/vr_diagnostics.tscn")
		return

	DebugLogger.info(SOURCE, "=== Starting initialization ===")
	xr_startup_results = XRHelpers.DiagnosticResults.new()

	# 1. CRITICAL: Validate required XR nodes exist BEFORE anything else
	DebugLogger.debug(SOURCE, "Step 1: Validating scene structure")
	if not _validate_scene_structure():
		DebugLogger.error(SOURCE, "Scene structure validation failed - aborting")
		return

	# 2. Initialize XR EARLY with enhanced error handling
	DebugLogger.debug(SOURCE, "Step 2: Initializing OpenXR")
	_initialize_xr_enhanced()

	# 3. Setup systems manager (for lazy-loading)
	DebugLogger.debug(SOURCE, "Step 3: Creating SystemsManager")
	systems = SystemsManager.new()
	add_child(systems)

	# 4. Safely get optional node references
	DebugLogger.debug(SOURCE, "Step 4: Setting up optional nodes")
	_setup_optional_nodes()

	# 5. Setup tracking (after XR is initialized)
	DebugLogger.debug(SOURCE, "Step 5: Setting up controllers")
	_setup_controllers()

	# 6. Connect signals
	DebugLogger.debug(SOURCE, "Step 6: Connecting signals")
	_connect_signals()

	# 7. Start in menu state
	DebugLogger.debug(SOURCE, "Step 7: Entering menu state")
	_change_state(GameState.MENU)

	DebugLogger.info(SOURCE, "=== Initialization complete (mode: %s) ===" % ("Desktop" if desktop_mode else "VR"))


func _validate_scene_structure() -> bool:
	# Validate critical XR nodes exist (required for rendering)
	var valid := true

	if xr_origin == null:
		DebugLogger.error(SOURCE, "CRITICAL: XROrigin3D not found in scene!")
		valid = false

	if xr_camera == null:
		DebugLogger.error(SOURCE, "CRITICAL: XRCamera3D not found in scene!")
		valid = false

	# Controllers are optional but warn if missing
	if left_controller == null:
		DebugLogger.warn(SOURCE, "Left controller not found")
	if right_controller == null:
		DebugLogger.warn(SOURCE, "Right controller not found")

	return valid


func _setup_optional_nodes() -> void:
	# Safely get references to optional nodes
	left_saber = get_node_or_null("XROrigin3D/LeftController/LeftSaber")
	right_saber = get_node_or_null("XROrigin3D/RightController/RightSaber")
	movement_trail = get_node_or_null("MovementTrail")
	heat_map = get_node_or_null("MovementHeatMap")
	gap_indicators = get_node_or_null("GapIndicators")
	movement_hud = get_node_or_null("MovementHUD")
	dojo_environment = get_node_or_null("DojoEnvironment")
	target_spawner = get_node_or_null("TargetSpawner")


func _process(delta: float) -> void:
	if not xr_initialized:
		return

	# Handle pause (both VR and desktop)
	if Input.is_action_just_pressed("xr_menu") or (desktop_mode and Input.is_action_just_pressed("ui_accept")):
		if current_state == GameState.PAUSED:
			_resume_session()
		elif current_state != GameState.MENU:
			_pause_session()

	# Desktop mode controls
	if desktop_mode:
		_handle_desktop_input(delta)


func _input(event: InputEvent) -> void:
	# Desktop mouse look
	if desktop_mode and event is InputEventMouseMotion:
		if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
			var motion := event as InputEventMouseMotion
			xr_camera.rotate_y(-motion.relative.x * mouse_sensitivity)
			xr_camera.rotate_x(-motion.relative.y * mouse_sensitivity)
			xr_camera.rotation.x = clamp(xr_camera.rotation.x, -PI/2, PI/2)

	# Toggle mouse capture
	if event.is_action_pressed("ui_cancel"):
		if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		else:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


func _handle_desktop_input(delta: float) -> void:
	# WASD movement
	var input_dir := Vector3.ZERO
	if Input.is_key_pressed(KEY_W):
		input_dir.z -= 1
	if Input.is_key_pressed(KEY_S):
		input_dir.z += 1
	if Input.is_key_pressed(KEY_A):
		input_dir.x -= 1
	if Input.is_key_pressed(KEY_D):
		input_dir.x += 1

	if input_dir != Vector3.ZERO:
		input_dir = input_dir.normalized()
		var direction := xr_camera.global_transform.basis * input_dir
		direction.y = 0
		direction = direction.normalized()
		xr_origin.global_position += direction * move_speed * delta

	# Simulate hand positions for testing (follows camera)
	if left_controller:
		left_controller.global_position = xr_camera.global_position + xr_camera.global_transform.basis * Vector3(-0.3, -0.2, -0.4)
	if right_controller:
		right_controller.global_position = xr_camera.global_position + xr_camera.global_transform.basis * Vector3(0.3, -0.2, -0.4)


func _initialize_xr_enhanced() -> void:
	DebugLogger.info(SOURCE, "=== OPENXR STARTUP SEQUENCE ===")
	xr_init_state = XRHelpers.XRInitState.FINDING_INTERFACE

	# Step 1: Find OpenXR interface
	XRHelpers.log_startup_step(1, XR_STARTUP_STEPS, "Finding OpenXR interface")
	xr_interface = XRServer.find_interface("OpenXR")

	var check := XRHelpers.check_interface_exists(xr_interface, "xrFindInterface")
	if not check.success:
		xr_startup_results.openxr_available = false
		xr_startup_results.failure_reason = "OpenXR interface not found"
		xr_init_state = XRHelpers.XRInitState.FAILED
		_fallback_to_desktop()
		return

	xr_startup_results.openxr_available = true
	XRHelpers.log_startup_result(1, true, "OpenXR interface found")

	# Step 2: Query runtime properties
	XRHelpers.log_startup_step(2, XR_STARTUP_STEPS, "Querying runtime properties")
	xr_init_state = XRHelpers.XRInitState.CHECKING_RUNTIME

	var runtime_info := XRHelpers.detect_runtime()
	xr_startup_results.runtime_name = runtime_info.name
	xr_startup_results.runtime_version = xr_interface.get_name()
	xr_startup_results.graphics_api = XRHelpers.get_graphics_api_name()

	XRHelpers.log_runtime_properties(xr_startup_results.runtime_name, xr_startup_results.runtime_version)
	DebugLogger.info(SOURCE, "Graphics API: %s" % xr_startup_results.graphics_api)
	XRHelpers.log_startup_result(2, true)

	# Step 3: Initialize OpenXR (creates instance, gets system/HMD)
	XRHelpers.log_startup_step(3, XR_STARTUP_STEPS, "Initializing OpenXR (instance + system)")
	xr_init_state = XRHelpers.XRInitState.INITIALIZING

	# CRITICAL: Set viewport to XR mode BEFORE initializing
	# This ensures first frame renders correctly in stereo
	get_viewport().use_xr = true

	var init_success := xr_interface.is_initialized()
	if not init_success:
		init_success = xr_interface.initialize()

	check = XRHelpers.xr_check(init_success, "xrInitialize")
	if not check.success:
		xr_startup_results.hmd_detected = false
		xr_startup_results.failure_reason = "OpenXR initialization failed - HMD may not be connected"
		xr_init_state = XRHelpers.XRInitState.FAILED
		_fallback_to_desktop()
		return

	xr_startup_results.hmd_detected = true
	XRHelpers.log_startup_result(3, true, "HMD detected and bound")

	# Query system properties
	_query_xr_system_properties()

	# Step 4: Configure display
	XRHelpers.log_startup_step(4, XR_STARTUP_STEPS, "Configuring display and view")
	xr_init_state = XRHelpers.XRInitState.CONFIGURING_DISPLAY

	# Sync physics rate to display refresh (90Hz typical for VR)
	var refresh_rate := xr_interface.get_display_refresh_rate()
	if refresh_rate > 0:
		xr_startup_results.refresh_rate = refresh_rate
		Engine.physics_ticks_per_second = int(refresh_rate)
		DebugLogger.info(SOURCE, "Physics rate synced to display: %d Hz" % int(refresh_rate))
	else:
		xr_startup_results.refresh_rate = 90.0
		Engine.physics_ticks_per_second = 90
		DebugLogger.info(SOURCE, "Using default 90Hz physics rate")

	# Get render target size
	var render_size := xr_interface.get_render_target_size()
	xr_startup_results.resolution_per_eye = Vector2i(int(render_size.x), int(render_size.y))

	XRHelpers.log_startup_result(4, true, "%.0fHz @ %dx%d" % [
		xr_startup_results.refresh_rate,
		xr_startup_results.resolution_per_eye.x,
		xr_startup_results.resolution_per_eye.y
	])

	# Step 5: Verify session ready
	XRHelpers.log_startup_step(5, XR_STARTUP_STEPS, "Verifying session ready")
	xr_init_state = XRHelpers.XRInitState.STARTING_SESSION

	# Check action map
	var action_map_path := ProjectSettings.get_setting("xr/openxr/default_action_map", "")
	if action_map_path and ResourceLoader.exists(action_map_path):
		DebugLogger.info(SOURCE, "Action map: %s" % action_map_path)
	else:
		DebugLogger.warn(SOURCE, "Action map not found - controller bindings may not work")

	xr_initialized = true
	xr_init_state = XRHelpers.XRInitState.READY
	XRHelpers.log_startup_result(5, true, "Session ready")

	# Log startup summary
	DebugLogger.info(SOURCE, "")
	XRHelpers.log_startup_summary(xr_startup_results)
	DebugLogger.info(SOURCE, "XR rendering enabled")


func _query_xr_system_properties() -> void:
	# Query HMD/system info
	xr_startup_results.hmd_system_name = xr_interface.get_name()

	# Form factor
	var form_factor_setting := ProjectSettings.get_setting("xr/openxr/form_factor", 0)
	match form_factor_setting:
		0: xr_startup_results.form_factor = "Head-Mounted Display"
		1: xr_startup_results.form_factor = "Handheld"
		_: xr_startup_results.form_factor = "Unknown"

	# View configuration
	var view_config := ProjectSettings.get_setting("xr/openxr/view_configuration", 1)
	match view_config:
		1: xr_startup_results.view_configuration = "Stereo"
		2: xr_startup_results.view_configuration = "Mono"
		_: xr_startup_results.view_configuration = "Config %d" % view_config

	# Foveation
	xr_startup_results.foveation_level = ProjectSettings.get_setting("xr/openxr/foveation_level", -1)

	XRHelpers.log_system_properties(
		xr_startup_results.hmd_system_name,
		xr_startup_results.hmd_vendor_id,
		xr_startup_results.form_factor
	)


func _fallback_to_desktop() -> void:
	DebugLogger.warn(SOURCE, "Running in desktop mode (no VR)")
	desktop_mode = true
	xr_initialized = true  # Allow _process to run

	# CRITICAL: Disable XR viewport mode for desktop rendering
	get_viewport().use_xr = false

	# Position camera at eye height (1.6m) for desktop view
	if xr_camera:
		xr_camera.position.y = 1.6

	# Position simulated controllers at rest position
	if left_controller:
		left_controller.position = Vector3(-0.3, 1.0, -0.3)
	if right_controller:
		right_controller.position = Vector3(0.3, 1.0, -0.3)

	# Enable mouse capture for FPS-style controls
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

	# Use standard 60Hz physics for desktop
	Engine.physics_ticks_per_second = 60

	DebugLogger.info(SOURCE, "Desktop controls: WASD=move, Mouse=look, ESC=release mouse, Space=menu")


func _setup_controllers() -> void:
	# Validate XR nodes before configuring
	if xr_origin == null:
		DebugLogger.error(SOURCE, "XR Origin not found - check scene structure")
		return
	if xr_camera == null:
		DebugLogger.error(SOURCE, "XR Camera not found - check scene structure")
		return

	# Configure movement tracker with XR nodes
	var tracker_ready := MovementTracker.setup_xr_nodes(xr_origin, xr_camera, left_controller, right_controller)
	if not tracker_ready:
		DebugLogger.warn(SOURCE, "Movement tracker partially configured")

	# Initialize XRInputManager with controller references
	XRInputManager.setup(left_controller, right_controller)
	DebugLogger.debug(SOURCE, "XRInputManager configured")

	# Setup HUD references
	if movement_hud:
		movement_hud.setup_references(xr_camera, left_controller)

	# Connect controller signals (with null checks)
	if left_controller:
		left_controller.button_pressed.connect(_on_left_button_pressed)
		DebugLogger.debug(SOURCE, "Left controller signals connected")
	else:
		DebugLogger.warn(SOURCE, "Left controller not available")

	if right_controller:
		right_controller.button_pressed.connect(_on_right_button_pressed)
		DebugLogger.debug(SOURCE, "Right controller signals connected")
	else:
		DebugLogger.warn(SOURCE, "Right controller not available")


func _connect_signals() -> void:
	# Game events
	GameEvents.session_started.connect(_on_session_started)
	GameEvents.session_ended.connect(_on_session_ended)
	GameEvents.achievement_unlocked.connect(_on_achievement_unlocked)
	GameEvents.target_hit.connect(_on_target_hit)


func _change_state(new_state: GameState) -> void:
	var old_state := current_state
	current_state = new_state

	match new_state:
		GameState.MENU:
			_enter_menu_state()
		GameState.TRAINING:
			_enter_training_state()
		GameState.WELLNESS_ROUTINE:
			_enter_wellness_state()
		GameState.PAUSED:
			_enter_paused_state()

	DebugLogger.info(SOURCE, "State changed: %s -> %s" % [GameState.keys()[old_state], GameState.keys()[new_state]])


func _enter_menu_state() -> void:
	# Stop and hide training elements
	if target_spawner:
		if target_spawner.has_method("stop_training"):
			target_spawner.stop_training()
		target_spawner.visible = false

	# Deactivate sabers
	if left_saber:
		left_saber.deactivate()
	if right_saber:
		right_saber.deactivate()


func _enter_training_state() -> void:
	# Preload training systems via lazy loader
	if systems:
		systems.preload_training_systems()

	# Start session if not already running
	if not SessionManager.session_active:
		SessionManager.start_session()

	# Show and start training elements
	if target_spawner:
		target_spawner.visible = true
		if target_spawner.has_method("start_training"):
			target_spawner.start_training()
			DebugLogger.info(SOURCE, "Training started - targets spawning")

	# Enable visualizations based on settings
	var settings := SessionManager.get_settings()
	if movement_trail:
		movement_trail.visible = settings.get("trail_visible", true)
	if heat_map:
		heat_map.visible = settings.get("heat_map_visible", false)
	if gap_indicators:
		gap_indicators.visible = settings.get("gap_indicators_visible", true)
	if movement_hud:
		movement_hud.visible = settings.get("hud_visible", true)


func _enter_wellness_state() -> void:
	# Preload wellness systems via lazy loader
	if systems:
		systems.preload_wellness_systems()

	# Start session
	if not SessionManager.session_active:
		SessionManager.start_session()

	# Hide combat elements
	if target_spawner:
		target_spawner.visible = false

	# Show all movement visualizations
	if movement_trail:
		movement_trail.visible = true
	if heat_map:
		heat_map.visible = true
	if gap_indicators:
		gap_indicators.visible = true


func _enter_paused_state() -> void:
	SessionManager.pause_session()


func _pause_session() -> void:
	_change_state(GameState.PAUSED)


func _resume_session() -> void:
	SessionManager.resume_session()
	# Return to previous state (simplified - just go to training)
	_change_state(GameState.TRAINING)


func start_training() -> void:
	_change_state(GameState.TRAINING)


func start_wellness_routine(routine_name: String) -> void:
	_change_state(GameState.WELLNESS_ROUTINE)
	# TODO: Load and start specific routine


func return_to_menu() -> void:
	if SessionManager.session_active:
		SessionManager.end_session()
	_change_state(GameState.MENU)


func _on_left_button_pressed(button: String) -> void:
	_handle_controller_button("left", button)


func _on_right_button_pressed(button: String) -> void:
	_handle_controller_button("right", button)


func _handle_controller_button(_hand: String, button: String) -> void:
	match button:
		"menu_button":
			if current_state == GameState.MENU:
				start_training()
			else:
				return_to_menu()

		"by_button":  # B/Y button
			# Toggle heat map (null-safe)
			if heat_map:
				var new_visible := not heat_map.visible
				heat_map.visible = new_visible
				SessionManager.update_setting("heat_map_visible", new_visible)


func _on_session_started(session_id: String) -> void:
	DebugLogger.info(SOURCE, "Session started: %s" % session_id)


func _on_session_ended(session_id: String, summary: Dictionary) -> void:
	DebugLogger.info(SOURCE, "Session ended: %s" % session_id)
	var coverage: float = summary.get("space_map_summary", {}).get("coverage", 0.0)
	DebugLogger.info(SOURCE, "Coverage: %.1f%%" % coverage)


func _on_achievement_unlocked(achievement_id: String) -> void:
	DebugLogger.info(SOURCE, "Achievement unlocked: %s" % achievement_id)
	# TODO: Show achievement notification in VR


func _on_target_hit(target: Node3D, damage: float, position: Vector3) -> void:
	if target.has_method("take_damage"):
		target.take_damage(damage, position)

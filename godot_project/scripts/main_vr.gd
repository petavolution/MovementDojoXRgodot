## Main VR Scene - Entry point and scene management
## Initializes XR, sets up tracking, and manages game state
extends Node3D

const SOURCE := "MainVR"

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

# Desktop mode settings
var mouse_sensitivity := 0.003
var move_speed := 3.0

# Systems manager (lazy-loads secondary systems)
var systems: SystemsManager


func _ready() -> void:
	DebugLogger.info(SOURCE, "=== Starting initialization ===")

	# 1. CRITICAL: Validate required XR nodes exist BEFORE anything else
	DebugLogger.debug(SOURCE, "Step 1: Validating scene structure")
	if not _validate_scene_structure():
		DebugLogger.error(SOURCE, "Scene structure validation failed - aborting")
		return

	# 2. Initialize XR EARLY (sets viewport mode before first render)
	DebugLogger.debug(SOURCE, "Step 2: Initializing XR")
	_initialize_xr()

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


func _initialize_xr() -> void:
	xr_interface = XRServer.find_interface("OpenXR")

	if xr_interface == null:
		DebugLogger.warn(SOURCE, "OpenXR interface not found")
		_fallback_to_desktop()
		return

	# CRITICAL: Set viewport to XR mode BEFORE initializing
	# This ensures first frame renders correctly in stereo
	get_viewport().use_xr = true

	# Handle both fresh init and already-initialized cases
	var init_success := xr_interface.is_initialized()
	if not init_success:
		init_success = xr_interface.initialize()

	if init_success:
		DebugLogger.info(SOURCE, "OpenXR %s" % ("already initialized" if xr_interface.is_initialized() else "initialized"))

		# Sync physics rate to display refresh (90Hz typical for VR)
		var refresh_rate := xr_interface.get_display_refresh_rate()
		if refresh_rate > 0:
			Engine.physics_ticks_per_second = int(refresh_rate)
			DebugLogger.info(SOURCE, "Physics rate synced to display: %d Hz" % int(refresh_rate))
		else:
			# Fallback to standard VR rate
			Engine.physics_ticks_per_second = 90
			DebugLogger.info(SOURCE, "Using default 90Hz physics rate")

		xr_initialized = true
		DebugLogger.info(SOURCE, "XR rendering enabled")
	else:
		DebugLogger.error(SOURCE, "Failed to initialize OpenXR!")
		_fallback_to_desktop()


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
	# Show menu, hide training elements
	if target_spawner:
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

	# Show training elements
	if target_spawner:
		target_spawner.visible = true

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

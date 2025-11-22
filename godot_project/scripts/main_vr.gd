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

# Systems manager (lazy-loads secondary systems)
var systems: SystemsManager


func _ready() -> void:
	DebugLogger.info(SOURCE, "=== Starting initialization ===")

	# 1. Setup systems manager first (for lazy-loading)
	DebugLogger.debug(SOURCE, "Step 1: Creating SystemsManager")
	systems = SystemsManager.new()
	add_child(systems)

	# 2. Safely get optional node references
	DebugLogger.debug(SOURCE, "Step 2: Setting up optional nodes")
	_setup_optional_nodes()

	# 3. Initialize XR
	DebugLogger.debug(SOURCE, "Step 3: Initializing XR")
	_initialize_xr()

	# 4. Setup tracking
	DebugLogger.debug(SOURCE, "Step 4: Setting up controllers")
	_setup_controllers()

	# 5. Connect signals
	DebugLogger.debug(SOURCE, "Step 5: Connecting signals")
	_connect_signals()

	# 6. Start in menu state
	DebugLogger.debug(SOURCE, "Step 6: Entering menu state")
	_change_state(GameState.MENU)
	DebugLogger.info(SOURCE, "=== Initialization complete ===")


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


func _process(_delta: float) -> void:
	if not xr_initialized:
		return

	# Handle pause
	if Input.is_action_just_pressed("xr_menu"):
		if current_state == GameState.PAUSED:
			_resume_session()
		elif current_state != GameState.MENU:
			_pause_session()


func _initialize_xr() -> void:
	xr_interface = XRServer.find_interface("OpenXR")

	if xr_interface == null:
		DebugLogger.error(SOURCE, "OpenXR interface not found!")
		_fallback_to_desktop()
		return

	if not xr_interface.is_initialized():
		if xr_interface.initialize():
			DebugLogger.info(SOURCE, "OpenXR initialized successfully")

			# Configure viewport for VR
			get_viewport().use_xr = true

			# Get refresh rate
			var refresh_rate := xr_interface.get_display_refresh_rate()
			if refresh_rate > 0:
				Engine.physics_ticks_per_second = int(refresh_rate)
				DebugLogger.info(SOURCE, "Physics rate set to: %d" % int(refresh_rate))

			xr_initialized = true
		else:
			DebugLogger.error(SOURCE, "Failed to initialize OpenXR!")
			_fallback_to_desktop()


func _fallback_to_desktop() -> void:
	DebugLogger.warn(SOURCE, "Running in desktop mode (no VR)")
	# Could add mouse/keyboard controls here for testing


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

## Main VR Scene - Entry point and scene management
## Initializes XR, sets up tracking, and manages game state
extends Node3D

enum GameState {
	INITIALIZING,
	MENU,
	TRAINING,
	WELLNESS_ROUTINE,
	PAUSED
}

# XR nodes
@onready var xr_origin: XROrigin3D = $XROrigin3D
@onready var xr_camera: XRCamera3D = $XROrigin3D/XRCamera3D
@onready var left_controller: XRController3D = $XROrigin3D/LeftController
@onready var right_controller: XRController3D = $XROrigin3D/RightController

# Game components
@onready var left_saber: Lightsaber = $XROrigin3D/LeftController/LeftSaber
@onready var right_saber: Lightsaber = $XROrigin3D/RightController/RightSaber
@onready var movement_trail: MovementTrail = $MovementTrail
@onready var heat_map: MovementHeatMap = $MovementHeatMap
@onready var gap_indicators: GapIndicator = $GapIndicators
@onready var movement_hud: MovementHUD = $MovementHUD
@onready var dojo_environment: Node3D = $DojoEnvironment
@onready var target_spawner: Node3D = $TargetSpawner

# State
var current_state := GameState.INITIALIZING
var xr_interface: XRInterface
var xr_initialized := false


func _ready() -> void:
	_initialize_xr()
	_setup_controllers()
	_connect_signals()

	# Start in menu state
	_change_state(GameState.MENU)


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
		push_error("OpenXR interface not found!")
		_fallback_to_desktop()
		return

	if not xr_interface.is_initialized():
		if xr_interface.initialize():
			print("[MainVR] OpenXR initialized successfully")

			# Configure viewport for VR
			get_viewport().use_xr = true

			# Get refresh rate
			var refresh_rate := xr_interface.get_display_refresh_rate()
			if refresh_rate > 0:
				Engine.physics_ticks_per_second = int(refresh_rate)
				print("[MainVR] Physics rate set to: ", refresh_rate)

			xr_initialized = true
		else:
			push_error("Failed to initialize OpenXR!")
			_fallback_to_desktop()


func _fallback_to_desktop() -> void:
	print("[MainVR] Running in desktop mode (no VR)")
	# Could add mouse/keyboard controls here for testing


func _setup_controllers() -> void:
	# Configure movement tracker with XR nodes
	MovementTracker.setup_xr_nodes(xr_origin, xr_camera, left_controller, right_controller)

	# Setup HUD references
	if movement_hud:
		movement_hud.setup_references(xr_camera, left_controller)

	# Connect controller signals
	left_controller.button_pressed.connect(_on_left_button_pressed)
	right_controller.button_pressed.connect(_on_right_button_pressed)


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

	print("[MainVR] State changed: ", GameState.keys()[old_state], " -> ", GameState.keys()[new_state])


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


func _handle_controller_button(hand: String, button: String) -> void:
	match button:
		"menu_button":
			if current_state == GameState.MENU:
				start_training()
			else:
				return_to_menu()

		"by_button":  # B/Y button
			# Toggle heat map
			var new_visible := not heat_map.visible
			heat_map.visible = new_visible
			SessionManager.update_setting("heat_map_visible", new_visible)


func _on_session_started(session_id: String) -> void:
	print("[MainVR] Session started: ", session_id)


func _on_session_ended(session_id: String, summary: Dictionary) -> void:
	print("[MainVR] Session ended: ", session_id)
	print("[MainVR] Coverage: ", summary.get("space_map_summary", {}).get("coverage", 0), "%")


func _on_achievement_unlocked(achievement_id: String) -> void:
	print("[MainVR] Achievement unlocked: ", achievement_id)
	# TODO: Show achievement notification in VR


func _on_target_hit(target: Node3D, damage: float, position: Vector3) -> void:
	if target.has_method("take_damage"):
		target.take_damage(damage, position)

## ApplicationManager - Central orchestrator following layered architecture
## Coordinates all subsystems: XR, Training, UI, Physics, Audio, etc.
class_name ApplicationManager
extends Node

signal application_ready
signal subsystem_initialized(subsystem: String)
signal subsystem_error(subsystem: String, error: String)
signal state_changed(old_state: AppState, new_state: AppState)
signal fatal_error(message: String)

## Application states
enum AppState {
	BOOT,               # Initial startup
	INITIALIZING,       # Loading subsystems
	MAIN_MENU,          # Main menu active
	TRAINING,           # Active training session
	WELLNESS,           # Wellness routine active
	PAUSED,             # Game paused
	SETTINGS,           # Settings menu
	CALIBRATION,        # Calibrating user
	ERROR,              # Error state
	SHUTTING_DOWN       # Cleanup before exit
}

## Subsystem initialization order (dependency-ordered)
const INIT_ORDER := [
	"xr_session",       # XR runtime (must be first)
	"settings",         # Load user preferences
	"audio",            # Audio system
	"save_system",      # Persistence
	"haptics",          # Haptic feedback
	"input",            # Input handling
	"physics",          # Physics abstraction
	"scene_manager",    # Scene loading
	"safety",           # Boundary system
	"comfort",          # Comfort features
	"calibration",      # User calibration
	"movement_tracker", # Movement capture
	"training",         # Training modules
	"ui",               # User interface
	"analytics"         # Analytics/telemetry
]

## Current state
var current_state: AppState = AppState.BOOT
var previous_state: AppState = AppState.BOOT
var is_ready: bool = false

## Subsystem references (dependency injection)
var subsystems: Dictionary = {}
var initialization_progress: float = 0.0
var initialization_errors: Array[String] = []

## Core subsystem references (frequently accessed)
var xr_session: XRSessionManager
var settings: Node
var training: Node
var ui_manager: Node
var safety_system: Node
var comfort_system: Node

## Configuration
@export var auto_initialize: bool = true
@export var verbose_logging: bool = true


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	if auto_initialize:
		call_deferred("initialize_application")


## Initialize all subsystems in dependency order
func initialize_application() -> void:
	_log("Starting application initialization...")
	_change_state(AppState.INITIALIZING)

	var total := INIT_ORDER.size()
	var completed := 0

	for subsystem_name in INIT_ORDER:
		_log("Initializing subsystem: %s" % subsystem_name)

		var success := await _initialize_subsystem(subsystem_name)

		if success:
			completed += 1
			subsystem_initialized.emit(subsystem_name)
		else:
			var error := "Failed to initialize: %s" % subsystem_name
			initialization_errors.append(error)
			subsystem_error.emit(subsystem_name, error)

			# Some subsystems are critical
			if subsystem_name in ["xr_session", "settings", "input"]:
				_log("CRITICAL: %s" % error)
				_change_state(AppState.ERROR)
				fatal_error.emit(error)
				return

		initialization_progress = float(completed) / total
		_log("Progress: %.0f%%" % (initialization_progress * 100))

	# All subsystems initialized
	is_ready = true
	_log("Application initialization complete!")
	application_ready.emit()

	# Transition to main menu
	_change_state(AppState.MAIN_MENU)


func _initialize_subsystem(name: String) -> bool:
	match name:
		"xr_session":
			return _init_xr_session()
		"settings":
			return _init_settings()
		"audio":
			return _init_audio()
		"save_system":
			return _init_save_system()
		"haptics":
			return _init_haptics()
		"input":
			return _init_input()
		"physics":
			return _init_physics()
		"scene_manager":
			return _init_scene_manager()
		"safety":
			return _init_safety()
		"comfort":
			return _init_comfort()
		"calibration":
			return _init_calibration()
		"movement_tracker":
			return _init_movement_tracker()
		"training":
			return _init_training()
		"ui":
			return _init_ui()
		"analytics":
			return _init_analytics()
	return false


func _init_xr_session() -> bool:
	# Create or find XR session manager
	xr_session = _find_or_create_node("XRSessionManager", XRSessionManager)
	if xr_session == null:
		return false

	subsystems["xr_session"] = xr_session

	# Initialize XR
	if not xr_session.initialize():
		_log("XR initialization failed, running in desktop mode")
		# Continue anyway for testing

	return true


func _init_settings() -> bool:
	settings = _find_autoload("SettingsManager")
	if settings:
		subsystems["settings"] = settings
		return true

	# Create minimal settings if not found
	_log("SettingsManager not found as autoload")
	return true  # Non-critical


func _init_audio() -> bool:
	var audio := _find_autoload("AudioManager")
	if audio:
		subsystems["audio"] = audio
	return true  # Non-critical


func _init_save_system() -> bool:
	var save_sys := _find_autoload("SaveSystem")
	if save_sys:
		subsystems["save_system"] = save_sys
	return true  # Non-critical


func _init_haptics() -> bool:
	# HapticPatterns is typically a static utility class
	subsystems["haptics"] = null
	return true


func _init_input() -> bool:
	var input_mgr := _find_or_create_node("XRInputManager", XRInputManager)
	subsystems["input"] = input_mgr
	return input_mgr != null


func _init_physics() -> bool:
	var physics := _find_or_create_node("PhysicsManager", PhysicsManager)
	subsystems["physics"] = physics
	return true  # Physics manager is optional enhancement


func _init_scene_manager() -> bool:
	var scene_mgr := _find_or_create_node("SceneVariantSystem", SceneVariantSystem)
	subsystems["scene_manager"] = scene_mgr
	return true


func _init_safety() -> bool:
	safety_system = _find_or_create_node("SafetyBoundarySystem", SafetyBoundarySystem)
	subsystems["safety"] = safety_system
	return true


func _init_comfort() -> bool:
	comfort_system = _find_or_create_node("ComfortSystem", ComfortSystem)
	subsystems["comfort"] = comfort_system
	return true


func _init_calibration() -> bool:
	var calibration := _find_or_create_node("CalibrationSystem", CalibrationSystem)
	subsystems["calibration"] = calibration
	return true


func _init_movement_tracker() -> bool:
	var tracker := _find_autoload("MovementTracker")
	if tracker:
		subsystems["movement_tracker"] = tracker
	return true


func _init_training() -> bool:
	training = _find_or_create_node("TrainingModeManager", TrainingModeManager)
	subsystems["training"] = training
	return true


func _init_ui() -> bool:
	ui_manager = _find_or_create_node("VRMenu", VRMenu)
	subsystems["ui"] = ui_manager
	return true


func _init_analytics() -> bool:
	var analytics := _find_or_create_node("MovementAnalytics", MovementAnalytics)
	subsystems["analytics"] = analytics
	return true


## State management
func _change_state(new_state: AppState) -> void:
	if new_state == current_state:
		return

	previous_state = current_state
	current_state = new_state

	_log("State: %s -> %s" % [_state_name(previous_state), _state_name(new_state)])
	state_changed.emit(previous_state, new_state)

	_on_state_enter(new_state)


func _on_state_enter(state: AppState) -> void:
	match state:
		AppState.MAIN_MENU:
			_show_main_menu()
		AppState.TRAINING:
			_start_training_session()
		AppState.WELLNESS:
			_start_wellness_session()
		AppState.PAUSED:
			_pause_application()
		AppState.SETTINGS:
			_show_settings()
		AppState.CALIBRATION:
			_start_calibration()


func _show_main_menu() -> void:
	if ui_manager and ui_manager.has_method("show_menu"):
		ui_manager.show_menu()
	GameEvents.menu_opened.emit()


func _start_training_session() -> void:
	if training and training.has_method("start_session"):
		training.start_session()
	GameEvents.session_started.emit()


func _start_wellness_session() -> void:
	GameEvents.wellness_routine_started.emit()


func _pause_application() -> void:
	get_tree().paused = true
	GameEvents.game_paused.emit()


func _show_settings() -> void:
	if ui_manager and ui_manager.has_method("show_settings"):
		ui_manager.show_settings()


func _start_calibration() -> void:
	var calibration := subsystems.get("calibration")
	if calibration and calibration.has_method("start_calibration"):
		calibration.start_calibration()


## Public API for state transitions
func go_to_main_menu() -> void:
	_change_state(AppState.MAIN_MENU)


func start_training(mode: String = "") -> void:
	_change_state(AppState.TRAINING)


func start_wellness(routine: String = "") -> void:
	_change_state(AppState.WELLNESS)


func pause() -> void:
	if current_state in [AppState.TRAINING, AppState.WELLNESS]:
		_change_state(AppState.PAUSED)


func resume() -> void:
	if current_state == AppState.PAUSED:
		_change_state(previous_state)
		get_tree().paused = false
		GameEvents.game_resumed.emit()


func open_settings() -> void:
	_change_state(AppState.SETTINGS)


func start_calibration() -> void:
	_change_state(AppState.CALIBRATION)


func shutdown() -> void:
	_log("Shutting down application...")
	_change_state(AppState.SHUTTING_DOWN)

	# Save any pending data
	var save_sys := subsystems.get("save_system")
	if save_sys and save_sys.has_method("save_all"):
		save_sys.save_all()

	# End XR session
	if xr_session:
		xr_session.end_session()

	# Quit application
	get_tree().quit()


## Subsystem access
func get_subsystem(name: String) -> Node:
	return subsystems.get(name)


func has_subsystem(name: String) -> bool:
	return subsystems.has(name) and subsystems[name] != null


## Utility functions
func _find_autoload(name: String) -> Node:
	if has_node("/root/" + name):
		return get_node("/root/" + name)
	return null


func _find_or_create_node(name: String, type: GDScript) -> Node:
	# First check if it exists as child
	var existing := get_node_or_null(name)
	if existing:
		return existing

	# Check as autoload
	var autoload := _find_autoload(name)
	if autoload:
		return autoload

	# Create new instance
	if type:
		var instance := type.new()
		instance.name = name
		add_child(instance)
		return instance

	return null


func _state_name(state: AppState) -> String:
	match state:
		AppState.BOOT: return "Boot"
		AppState.INITIALIZING: return "Initializing"
		AppState.MAIN_MENU: return "Main Menu"
		AppState.TRAINING: return "Training"
		AppState.WELLNESS: return "Wellness"
		AppState.PAUSED: return "Paused"
		AppState.SETTINGS: return "Settings"
		AppState.CALIBRATION: return "Calibration"
		AppState.ERROR: return "Error"
		AppState.SHUTTING_DOWN: return "Shutting Down"
	return "Unknown"


func _log(message: String) -> void:
	if verbose_logging:
		print("[ApplicationManager] %s" % message)


## Get application status report
func get_status() -> Dictionary:
	var status := {
		"state": _state_name(current_state),
		"is_ready": is_ready,
		"initialization_progress": initialization_progress,
		"errors": initialization_errors,
		"subsystems": {}
	}

	for name in subsystems:
		status.subsystems[name] = subsystems[name] != null

	if xr_session:
		status["xr"] = xr_session.get_capabilities()

	return status

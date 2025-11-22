## Level1Scene - Dojo Training Level 1 Scene Setup
## Handles XR initialization and wires up Level1Controller
## Run with: godot --dojo-level1
##
## This is a hardened entry point with comprehensive preflight checks:
## - OpenXR session validation
## - Input binding verification
## - Graceful failure with clear logging
extends Node3D
class_name Level1Scene

const SOURCE := "Level1"

# =============================================================================
# PREFLIGHT CHECK CONFIGURATION
# =============================================================================

## Required action bindings that must exist for Level 1 to function
const REQUIRED_ACTIONS := [
	"trigger",      # Both controllers - weapon activation
	"grip",         # Optional but checked
]

## Optional assets to check (warn if missing, don't fail)
const OPTIONAL_ASSETS := [
	"res://audio/voice/welcome.ogg",
	"res://audio/sfx/block.ogg",
]

# =============================================================================
# SCENE COMPONENTS
# =============================================================================

# XR Nodes (created dynamically)
var xr_origin: XROrigin3D
var xr_camera: XRCamera3D
var left_controller: XRController3D
var right_controller: XRController3D

# Core components
var level_controller: Level1Controller
var drone_spawner: Level1DroneSpawner
var feedback_ui: Level1Feedback
var dojo_environment: Node3D
var active_entities: Node3D

# Weapon placeholders (until real implementations)
var debug_saber: Node3D
var debug_blaster: Node3D

# XR State
var xr_interface: XRInterface
var xr_initialized := false

# Preflight check results
var preflight_passed := false
var preflight_warnings: Array[String] = []

# =============================================================================
# LIFECYCLE
# =============================================================================

func _ready() -> void:
	DebugLogger.info(SOURCE, "=== DOJO LEVEL 1 ===")
	DebugLogger.info(SOURCE, "Starting Level 1 dojo experience (chilled training mode)")
	DebugLogger.info(SOURCE, "")

	# Run comprehensive preflight checks
	if not _run_preflight_checks():
		_abort_level("Preflight checks failed")
		return

	# Build scene components
	_build_scene_structure()
	_build_dojo_environment()
	_setup_debug_weapons()

	# Create and configure level controller
	_setup_level_controller()

	# Connect input for exit
	_connect_input_signals()

	# Log any warnings from preflight
	if preflight_warnings.size() > 0:
		DebugLogger.warn(SOURCE, "Preflight warnings (%d):" % preflight_warnings.size())
		for warning in preflight_warnings:
			DebugLogger.warn(SOURCE, "  - %s" % warning)

	# Start the level after a short delay (let everything settle)
	DebugLogger.info(SOURCE, "Preflight complete - starting level in 0.5s...")
	await get_tree().create_timer(0.5).timeout
	level_controller.start_level()


func _process(_delta: float) -> void:
	if not xr_initialized:
		return

	# Check for exit
	if Input.is_action_just_pressed("ui_cancel"):
		_request_exit()


func _exit_tree() -> void:
	DebugLogger.info(SOURCE, "Level 1 completed successfully")
	DebugLogger.flush()


# =============================================================================
# PREFLIGHT CHECKS
# =============================================================================

## Run all preflight checks before starting Level 1
## Returns true if all critical checks pass
func _run_preflight_checks() -> bool:
	DebugLogger.info(SOURCE, "Running preflight checks...")
	preflight_warnings.clear()
	var all_passed := true

	# Check 1: OpenXR setup
	DebugLogger.info(SOURCE, "  [1/4] OpenXR initialization...")
	if not _setup_xr():
		DebugLogger.error(SOURCE, "  FAIL: OpenXR initialization failed")
		return false
	DebugLogger.info(SOURCE, "  PASS: OpenXR initialized")

	# Check 2: XR session validity
	DebugLogger.info(SOURCE, "  [2/4] XR session validation...")
	if not _check_xr_session():
		DebugLogger.error(SOURCE, "  FAIL: XR session not valid")
		return false
	DebugLogger.info(SOURCE, "  PASS: XR session valid")

	# Check 3: Input bindings
	DebugLogger.info(SOURCE, "  [3/4] Input binding verification...")
	if not _check_input_bindings():
		DebugLogger.warn(SOURCE, "  WARN: Some input bindings may be missing (continuing anyway)")
		# Don't fail on input bindings - controllers might not be on yet

	# Check 4: Optional assets (warn only)
	DebugLogger.info(SOURCE, "  [4/4] Optional asset check...")
	_check_optional_assets()

	preflight_passed = all_passed
	if all_passed:
		DebugLogger.info(SOURCE, "Preflight checks: ALL PASSED")
	return all_passed


## Verify XR session is in a valid state
func _check_xr_session() -> bool:
	if xr_interface == null:
		return false

	if not xr_interface.is_initialized():
		return false

	# Check for common session issues
	# Note: We can't check session state directly in Godot's OpenXR binding,
	# but we can verify the interface is ready
	var check := XRHelpers.check_initialized(xr_interface, "Level1-SessionCheck")
	return check.success


## Verify input bindings exist (at least for action map)
func _check_input_bindings() -> bool:
	var bindings_ok := true

	# Check that the default action map exists
	var action_map_path := ProjectSettings.get_setting("xr/openxr/default_action_map", "")
	if action_map_path == "":
		preflight_warnings.append("No OpenXR action map configured in project settings")
		bindings_ok = false
	elif not ResourceLoader.exists(action_map_path):
		preflight_warnings.append("OpenXR action map not found: %s" % action_map_path)
		bindings_ok = false
	else:
		DebugLogger.debug(SOURCE, "  Action map: %s" % action_map_path)

	# Check if InputMap has our expected actions (these are Godot Input actions, not OpenXR)
	for action in REQUIRED_ACTIONS:
		# We check XR controller actions, which are bound dynamically
		# Just log what we expect for now
		DebugLogger.debug(SOURCE, "  Expected XR action: %s" % action)

	if bindings_ok:
		DebugLogger.info(SOURCE, "  PASS: Input bindings configured")
	return bindings_ok


## Check if optional assets exist (warn but don't fail)
func _check_optional_assets() -> void:
	var missing_count := 0
	for asset_path in OPTIONAL_ASSETS:
		if not ResourceLoader.exists(asset_path):
			preflight_warnings.append("Optional asset missing: %s" % asset_path)
			missing_count += 1

	if missing_count == 0:
		DebugLogger.info(SOURCE, "  PASS: All optional assets present")
	else:
		DebugLogger.info(SOURCE, "  INFO: %d optional assets missing (non-critical)" % missing_count)


## Abort Level 1 initialization with clear error
func _abort_level(reason: String) -> void:
	DebugLogger.error(SOURCE, "Level 1 aborted: %s" % reason)
	DebugLogger.error(SOURCE, "Check configuration/assets/XR runtime.")
	DebugLogger.info(SOURCE, "")
	DebugLogger.info(SOURCE, "Troubleshooting:")
	DebugLogger.info(SOURCE, "  1. Ensure SteamVR is running and set as active OpenXR runtime")
	DebugLogger.info(SOURCE, "  2. Verify Quest 3 is connected via Virtual Desktop")
	DebugLogger.info(SOURCE, "  3. Run 'godot --vr-diagnostics' for detailed XR status")
	DebugLogger.info(SOURCE, "")

	# Use centralized shutdown for clean exit
	EngineShutdown.startup_failure("Level1", reason)


# =============================================================================
# XR SETUP
# =============================================================================

func _setup_xr() -> bool:
	DebugLogger.debug(SOURCE, "Setting up XR...")

	# Create XR scene structure
	xr_origin = XROrigin3D.new()
	xr_origin.name = "XROrigin3D"
	add_child(xr_origin)

	xr_camera = XRCamera3D.new()
	xr_camera.name = "XRCamera3D"
	xr_origin.add_child(xr_camera)

	left_controller = XRController3D.new()
	left_controller.name = "LeftController"
	left_controller.tracker = "left_hand"
	xr_origin.add_child(left_controller)

	right_controller = XRController3D.new()
	right_controller.name = "RightController"
	right_controller.tracker = "right_hand"
	xr_origin.add_child(right_controller)

	# Initialize OpenXR
	xr_interface = XRServer.find_interface("OpenXR")
	if xr_interface == null:
		DebugLogger.error(SOURCE, "OpenXR interface not found")
		return false

	get_viewport().use_xr = true

	if not xr_interface.is_initialized():
		if not xr_interface.initialize():
			DebugLogger.error(SOURCE, "Failed to initialize OpenXR")
			return false

	xr_initialized = true

	# Sync physics to display
	var refresh_rate := xr_interface.get_display_refresh_rate()
	if refresh_rate > 0:
		Engine.physics_ticks_per_second = int(refresh_rate)
	else:
		Engine.physics_ticks_per_second = 90

	DebugLogger.info(SOURCE, "XR initialized at %.0f Hz" % Engine.physics_ticks_per_second)
	return true


# =============================================================================
# SCENE BUILDING
# =============================================================================

func _build_scene_structure() -> void:
	# Container for runtime-spawned entities (targets, projectiles, drones)
	active_entities = Node3D.new()
	active_entities.name = "ActiveEntities"
	add_child(active_entities)

	DebugLogger.debug(SOURCE, "Scene structure created")


func _build_dojo_environment() -> void:
	DebugLogger.info(SOURCE, "Building dojo environment...")

	# Create environment container
	dojo_environment = Node3D.new()
	dojo_environment.name = "DojoEnvironment"
	add_child(dojo_environment)

	# Floor (octagonal-ish, but simple plane for now)
	var floor_mesh := PlaneMesh.new()
	floor_mesh.size = Vector2(12.0, 12.0)

	var floor_mat := StandardMaterial3D.new()
	floor_mat.albedo_color = Color(0.12, 0.12, 0.15)
	floor_mat.roughness = 0.8

	var floor := MeshInstance3D.new()
	floor.name = "Floor"
	floor.mesh = floor_mesh
	floor.material_override = floor_mat
	dojo_environment.add_child(floor)

	# Walls (8 segments for octagonal dojo feel)
	_create_octagonal_walls()

	# Ambient lighting
	var main_light := DirectionalLight3D.new()
	main_light.name = "MainLight"
	main_light.light_energy = 0.6
	main_light.shadow_enabled = true
	main_light.rotation_degrees = Vector3(-50, 30, 0)
	dojo_environment.add_child(main_light)

	# Accent lights (blue tint for dojo atmosphere)
	_create_accent_lights()

	# Environment settings
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.03, 0.03, 0.06)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.15, 0.15, 0.25)
	env.ambient_light_energy = 0.4

	var world_env := WorldEnvironment.new()
	world_env.name = "WorldEnvironment"
	world_env.environment = env
	dojo_environment.add_child(world_env)

	DebugLogger.debug(SOURCE, "Dojo environment built")


func _create_octagonal_walls() -> void:
	var wall_height := 4.0
	var wall_distance := 5.5
	var wall_width := 4.5

	var wall_mesh := BoxMesh.new()
	wall_mesh.size = Vector3(wall_width, wall_height, 0.3)

	var wall_mat := StandardMaterial3D.new()
	wall_mat.albedo_color = Color(0.15, 0.15, 0.18)
	wall_mat.roughness = 0.9

	# Create 8 wall segments
	for i in range(8):
		var angle := i * PI / 4.0  # 45 degrees each
		var pos := Vector3(
			cos(angle) * wall_distance,
			wall_height / 2.0,
			sin(angle) * wall_distance
		)

		var wall := MeshInstance3D.new()
		wall.name = "Wall%d" % i
		wall.mesh = wall_mesh
		wall.material_override = wall_mat
		wall.position = pos
		wall.rotation.y = angle + PI / 2.0  # Face center
		dojo_environment.add_child(wall)


func _create_accent_lights() -> void:
	var light_positions := [
		Vector3(4, 2.5, 0),
		Vector3(-4, 2.5, 0),
		Vector3(0, 2.5, 4),
		Vector3(0, 2.5, -4),
	]

	var accent_color := Color(0.3, 0.5, 1.0)  # Blue tint

	for i in range(light_positions.size()):
		var light := OmniLight3D.new()
		light.name = "AccentLight%d" % i
		light.position = light_positions[i]
		light.light_color = accent_color
		light.light_energy = 0.3
		light.omni_range = 6.0
		light.omni_attenuation = 1.5
		dojo_environment.add_child(light)


# =============================================================================
# WEAPONS SETUP
# =============================================================================

func _setup_debug_weapons() -> void:
	DebugLogger.info(SOURCE, "Setting up debug weapons...")

	# Right hand: Debug Lightsaber (cyan blade)
	_create_debug_saber()

	# Left hand: Debug Blaster
	_create_debug_blaster()


func _create_debug_saber() -> void:
	debug_saber = Node3D.new()
	debug_saber.name = "DebugSaber"
	right_controller.add_child(debug_saber)

	# Hilt
	var hilt_mesh := CylinderMesh.new()
	hilt_mesh.top_radius = 0.018
	hilt_mesh.bottom_radius = 0.022
	hilt_mesh.height = 0.18

	var hilt_mat := StandardMaterial3D.new()
	hilt_mat.albedo_color = Color(0.3, 0.3, 0.35)
	hilt_mat.metallic = 0.8
	hilt_mat.roughness = 0.3

	var hilt := MeshInstance3D.new()
	hilt.name = "Hilt"
	hilt.mesh = hilt_mesh
	hilt.material_override = hilt_mat
	hilt.rotation_degrees = Vector3(90, 0, 0)
	debug_saber.add_child(hilt)

	# Blade (always visible for Level 1 - training mode)
	var blade_mesh := CylinderMesh.new()
	blade_mesh.top_radius = 0.012
	blade_mesh.bottom_radius = 0.015
	blade_mesh.height = 0.9

	var blade_mat := StandardMaterial3D.new()
	blade_mat.albedo_color = Color(0.3, 0.8, 1.0)
	blade_mat.emission_enabled = true
	blade_mat.emission = Color(0.3, 0.8, 1.0)
	blade_mat.emission_energy_multiplier = 1.5

	var blade := MeshInstance3D.new()
	blade.name = "Blade"
	blade.mesh = blade_mesh
	blade.material_override = blade_mat
	blade.position = Vector3(0, 0, -0.54)  # Extend from hilt
	blade.rotation_degrees = Vector3(90, 0, 0)
	debug_saber.add_child(blade)

	# Blade glow light
	var blade_light := OmniLight3D.new()
	blade_light.name = "BladeLight"
	blade_light.light_color = Color(0.3, 0.8, 1.0)
	blade_light.light_energy = 0.5
	blade_light.omni_range = 1.5
	blade_light.position = Vector3(0, 0, -0.5)
	debug_saber.add_child(blade_light)

	DebugLogger.debug(SOURCE, "Debug saber created (right hand)")


func _create_debug_blaster() -> void:
	debug_blaster = Node3D.new()
	debug_blaster.name = "DebugBlaster"
	left_controller.add_child(debug_blaster)

	# Body
	var body_mesh := BoxMesh.new()
	body_mesh.size = Vector3(0.04, 0.07, 0.14)

	var body_mat := StandardMaterial3D.new()
	body_mat.albedo_color = Color(0.2, 0.2, 0.22)
	body_mat.metallic = 0.6
	body_mat.roughness = 0.4

	var body := MeshInstance3D.new()
	body.name = "Body"
	body.mesh = body_mesh
	body.material_override = body_mat
	body.position = Vector3(0, 0, -0.07)
	debug_blaster.add_child(body)

	# Barrel
	var barrel_mesh := CylinderMesh.new()
	barrel_mesh.top_radius = 0.008
	barrel_mesh.bottom_radius = 0.01
	barrel_mesh.height = 0.08

	var barrel_mat := StandardMaterial3D.new()
	barrel_mat.albedo_color = Color(0.15, 0.15, 0.15)
	barrel_mat.metallic = 0.9
	barrel_mat.roughness = 0.2

	var barrel := MeshInstance3D.new()
	barrel.name = "Barrel"
	barrel.mesh = barrel_mesh
	barrel.material_override = barrel_mat
	barrel.position = Vector3(0, 0, -0.18)
	barrel.rotation_degrees = Vector3(90, 0, 0)
	debug_blaster.add_child(barrel)

	DebugLogger.debug(SOURCE, "Debug blaster created (left hand)")


# =============================================================================
# LEVEL CONTROLLER SETUP
# =============================================================================

func _setup_level_controller() -> void:
	# Create drone spawner first
	drone_spawner = Level1DroneSpawner.new()
	drone_spawner.name = "Level1DroneSpawner"
	add_child(drone_spawner)

	# Configure spawner
	drone_spawner.setup(xr_camera, active_entities)

	# Create feedback UI
	feedback_ui = Level1Feedback.new()
	feedback_ui.name = "Level1Feedback"
	add_child(feedback_ui)

	# Configure feedback
	feedback_ui.setup(xr_camera)

	# Create level controller
	level_controller = Level1Controller.new()
	level_controller.name = "Level1Controller"
	add_child(level_controller)

	# Configure controller with scene references
	level_controller.setup_xr(xr_origin, xr_camera, left_controller, right_controller)
	level_controller.setup_weapons(debug_saber, debug_blaster)
	level_controller.setup_environment(dojo_environment)
	level_controller.setup_entities_container(active_entities)
	level_controller.setup_drone_spawner(drone_spawner)
	level_controller.setup_feedback(feedback_ui)

	# Connect signals
	level_controller.level_completed.connect(_on_level_completed)
	level_controller.state_changed.connect(_on_state_changed)

	DebugLogger.debug(SOURCE, "Level controller, spawner, and feedback configured")


# =============================================================================
# INPUT HANDLING
# =============================================================================

func _connect_input_signals() -> void:
	# Connect controller menu buttons for exit
	if left_controller:
		left_controller.button_pressed.connect(_on_controller_button)
	if right_controller:
		right_controller.button_pressed.connect(_on_controller_button)


func _on_controller_button(button: String) -> void:
	if button == "menu_button":
		# Only exit if level is complete or we're in summary
		if level_controller.current_state == Level1Controller.Level1State.COMPLETE:
			_request_exit()
		elif level_controller.current_state == Level1Controller.Level1State.SUMMARY:
			level_controller.skip_current_phase()


# =============================================================================
# EVENT HANDLERS
# =============================================================================

func _on_level_completed(stats: Dictionary) -> void:
	DebugLogger.info(SOURCE, "Level 1 completed successfully")
	DebugLogger.info(SOURCE, "Session stats: %s" % str(stats))

	# Allow exit after completion
	await get_tree().create_timer(2.0).timeout
	_request_exit()


func _on_state_changed(old_state: Level1Controller.Level1State, new_state: Level1Controller.Level1State) -> void:
	# Could trigger visual/audio feedback here
	pass


# =============================================================================
# EXIT HANDLING
# =============================================================================

func _request_exit() -> void:
	DebugLogger.info(SOURCE, "Exit requested - shutting down cleanly")
	EngineShutdown.request_shutdown("Level 1 session ended", 0)


# =============================================================================
# STATIC HELPERS
# =============================================================================

## Check if --dojo-level1 flag is present
static func has_level1_flag() -> bool:
	var args := OS.get_cmdline_args()
	return "--dojo-level1" in args or "-dojo-level1" in args or "--level1" in args

## BaseVRScene - Shared XR initialization and error handling for all VR scenes
## Provides consistent OpenXR setup with comprehensive error handling and logging
## All VR scenes should extend this class to eliminate code duplication
##
## Usage:
##   extends BaseVRScene
##   func _on_xr_initialized() -> void:
##       # Your scene setup here
##       pass
class_name BaseVRScene
extends Node3D

const SOURCE := "BaseVRScene"
const XR_STARTUP_STEPS := 5

# =============================================================================
# XR NODES (Created by base class or discovered from scene)
# =============================================================================

var xr_origin: XROrigin3D
var xr_camera: XRCamera3D
var left_controller: XRController3D
var right_controller: XRController3D

# =============================================================================
# XR STATE
# =============================================================================

var xr_interface: XRInterface
var xr_initialized := false
var desktop_mode := false
var init_state := XRHelpers.XRInitState.NOT_STARTED
var startup_results: XRHelpers.DiagnosticResults

# Desktop mode fallback settings
var desktop_mode_enabled := true  # Set to false to fail instead of fallback
var desktop_mouse_sensitivity := 0.003
var desktop_move_speed := 3.0

# =============================================================================
# LIFECYCLE
# =============================================================================

func _ready() -> void:
	DebugLogger.info(SOURCE, "Initializing BaseVRScene")
	startup_results = XRHelpers.DiagnosticResults.new()

	# Step 1: Discover or create XR scene structure
	DebugLogger.debug(SOURCE, "Step 1: Setting up XR nodes")
	_setup_xr_nodes()

	# Step 2: Validate scene structure
	DebugLogger.debug(SOURCE, "Step 2: Validating scene structure")
	if not _validate_scene_structure():
		DebugLogger.error(SOURCE, "Scene structure validation failed - aborting")
		_handle_xr_failure("Required XR nodes missing from scene")
		return

	# Step 3: Initialize OpenXR
	DebugLogger.debug(SOURCE, "Step 3: Initializing OpenXR")
	_initialize_openxr_enhanced()

	# Check if initialization succeeded
	if xr_initialized:
		DebugLogger.info(SOURCE, "BaseVRScene initialization complete (mode: %s)" % ("Desktop" if desktop_mode else "VR"))
		_on_xr_initialized()
	else:
		DebugLogger.error(SOURCE, "BaseVRScene initialization failed")


func _setup_xr_nodes() -> void:
	"""Discover XR nodes from scene or create them programmatically"""

	# Try to find XROrigin3D in scene first
	xr_origin = get_node_or_null("XROrigin3D")
	if xr_origin == null:
		DebugLogger.debug(SOURCE, "Creating XROrigin3D programmatically")
		xr_origin = XROrigin3D.new()
		xr_origin.name = "XROrigin3D"
		add_child(xr_origin)
	else:
		DebugLogger.debug(SOURCE, "Found XROrigin3D in scene")

	# Try to find XRCamera3D
	xr_camera = xr_origin.get_node_or_null("XRCamera3D")
	if xr_camera == null:
		DebugLogger.debug(SOURCE, "Creating XRCamera3D programmatically")
		xr_camera = XRCamera3D.new()
		xr_camera.name = "XRCamera3D"
		xr_camera.position.y = 1.6  # Standard eye height
		xr_origin.add_child(xr_camera)
	else:
		DebugLogger.debug(SOURCE, "Found XRCamera3D in scene")

	# Try to find left controller
	left_controller = xr_origin.get_node_or_null("LeftController")
	if left_controller == null:
		DebugLogger.debug(SOURCE, "Creating LeftController programmatically")
		left_controller = XRController3D.new()
		left_controller.name = "LeftController"
		left_controller.tracker = "left_hand"
		xr_origin.add_child(left_controller)
	else:
		DebugLogger.debug(SOURCE, "Found LeftController in scene")
		# Ensure tracker is set
		if left_controller.tracker != "left_hand":
			left_controller.tracker = "left_hand"

	# Try to find right controller
	right_controller = xr_origin.get_node_or_null("RightController")
	if right_controller == null:
		DebugLogger.debug(SOURCE, "Creating RightController programmatically")
		right_controller = XRController3D.new()
		right_controller.name = "RightController"
		right_controller.tracker = "right_hand"
		xr_origin.add_child(right_controller)
	else:
		DebugLogger.debug(SOURCE, "Found RightController in scene")
		# Ensure tracker is set
		if right_controller.tracker != "right_hand":
			right_controller.tracker = "right_hand"

	DebugLogger.debug(SOURCE, "XR node structure ready")


func _validate_scene_structure() -> bool:
	"""Validate critical XR nodes exist"""
	var valid := true

	if xr_origin == null:
		DebugLogger.error(SOURCE, "CRITICAL: XROrigin3D not found!")
		valid = false

	if xr_camera == null:
		DebugLogger.error(SOURCE, "CRITICAL: XRCamera3D not found!")
		valid = false

	# Controllers are optional but log warnings
	if left_controller == null:
		DebugLogger.warn(SOURCE, "Left controller not found")
	if right_controller == null:
		DebugLogger.warn(SOURCE, "Right controller not found")

	return valid


func _initialize_openxr_enhanced() -> void:
	"""Initialize OpenXR with comprehensive error handling and logging"""

	DebugLogger.info(SOURCE, "=== OPENXR STARTUP SEQUENCE ===")
	init_state = XRHelpers.XRInitState.FINDING_INTERFACE

	# Step 1: Find OpenXR interface
	XRHelpers.log_startup_step(1, XR_STARTUP_STEPS, "Finding OpenXR interface")
	xr_interface = XRServer.find_interface("OpenXR")

	var check := XRHelpers.check_interface_exists(xr_interface, "xrFindInterface")
	if not check.success:
		startup_results.openxr_available = false
		startup_results.failure_reason = "OpenXR interface not found"
		init_state = XRHelpers.XRInitState.FAILED
		_fallback_to_desktop()
		return

	startup_results.openxr_available = true
	XRHelpers.log_startup_result(1, true, "OpenXR interface found")

	# Step 2: Query runtime properties
	XRHelpers.log_startup_step(2, XR_STARTUP_STEPS, "Querying runtime properties")
	init_state = XRHelpers.XRInitState.CHECKING_RUNTIME

	var runtime_info := XRHelpers.detect_runtime()
	startup_results.runtime_name = runtime_info.name
	startup_results.runtime_version = xr_interface.get_name()
	startup_results.graphics_api = XRHelpers.get_graphics_api_name()

	XRHelpers.log_runtime_properties(startup_results.runtime_name, startup_results.runtime_version)
	DebugLogger.info(SOURCE, "Graphics API: %s" % startup_results.graphics_api)
	XRHelpers.log_startup_result(2, true)

	# Step 3: Initialize OpenXR (creates instance, gets system/HMD)
	XRHelpers.log_startup_step(3, XR_STARTUP_STEPS, "Initializing OpenXR (instance + system)")
	init_state = XRHelpers.XRInitState.INITIALIZING

	# CRITICAL: Set viewport to XR mode BEFORE initializing
	# This ensures first frame renders correctly in stereo
	get_viewport().use_xr = true

	var init_success := xr_interface.is_initialized()
	if not init_success:
		init_success = xr_interface.initialize()

	check = XRHelpers.xr_check(init_success, "xrInitialize")
	if not check.success:
		startup_results.hmd_detected = false
		startup_results.failure_reason = "OpenXR initialization failed - HMD may not be connected"
		init_state = XRHelpers.XRInitState.FAILED
		_fallback_to_desktop()
		return

	startup_results.hmd_detected = true
	XRHelpers.log_startup_result(3, true, "HMD detected and bound")

	# Query system properties
	_query_xr_system_properties()

	# Step 4: Configure display
	XRHelpers.log_startup_step(4, XR_STARTUP_STEPS, "Configuring display and view")
	init_state = XRHelpers.XRInitState.CONFIGURING_DISPLAY

	# Sync physics rate to display refresh (90Hz typical for VR)
	var refresh_rate := xr_interface.get_display_refresh_rate()
	if refresh_rate > 0:
		startup_results.refresh_rate = refresh_rate
		Engine.physics_ticks_per_second = int(refresh_rate)
		DebugLogger.info(SOURCE, "Physics rate synced to display: %d Hz" % int(refresh_rate))
	else:
		startup_results.refresh_rate = 90.0
		Engine.physics_ticks_per_second = 90
		DebugLogger.info(SOURCE, "Using default 90Hz physics rate")

	# Get render target size
	var render_size := xr_interface.get_render_target_size()
	startup_results.resolution_per_eye = Vector2i(int(render_size.x), int(render_size.y))

	XRHelpers.log_startup_result(4, true, "%.0fHz @ %dx%d" % [
		startup_results.refresh_rate,
		startup_results.resolution_per_eye.x,
		startup_results.resolution_per_eye.y
	])

	# Step 5: Verify session ready
	XRHelpers.log_startup_step(5, XR_STARTUP_STEPS, "Verifying session ready")
	init_state = XRHelpers.XRInitState.STARTING_SESSION

	# Check action map
	var action_map_path := ProjectSettings.get_setting("xr/openxr/default_action_map", "")
	if action_map_path and ResourceLoader.exists(action_map_path):
		DebugLogger.info(SOURCE, "Action map: %s" % action_map_path)
	else:
		DebugLogger.warn(SOURCE, "Action map not found - controller bindings may not work")

	xr_initialized = true
	init_state = XRHelpers.XRInitState.READY
	XRHelpers.log_startup_result(5, true, "Session ready")

	# Log startup summary
	DebugLogger.info(SOURCE, "")
	XRHelpers.log_startup_summary(startup_results)
	DebugLogger.info(SOURCE, "XR rendering enabled")


func _query_xr_system_properties() -> void:
	"""Query HMD/system information"""

	# HMD system name
	startup_results.hmd_system_name = xr_interface.get_name()

	# Form factor
	var form_factor_setting := ProjectSettings.get_setting("xr/openxr/form_factor", 0)
	match form_factor_setting:
		0: startup_results.form_factor = "Head-Mounted Display"
		1: startup_results.form_factor = "Handheld"
		_: startup_results.form_factor = "Unknown"

	# View configuration
	var view_config := ProjectSettings.get_setting("xr/openxr/view_configuration", 1)
	match view_config:
		1: startup_results.view_configuration = "Stereo"
		2: startup_results.view_configuration = "Mono"
		_: startup_results.view_configuration = "Config %d" % view_config

	# Foveation
	startup_results.foveation_level = ProjectSettings.get_setting("xr/openxr/foveation_level", -1)

	XRHelpers.log_system_properties(
		startup_results.hmd_system_name,
		startup_results.hmd_vendor_id,
		startup_results.form_factor
	)


func _fallback_to_desktop() -> void:
	"""Fallback to desktop mode when XR initialization fails"""

	if not desktop_mode_enabled:
		DebugLogger.error(SOURCE, "XR initialization failed and desktop mode disabled - aborting")
		_handle_xr_failure(startup_results.failure_reason)
		return

	DebugLogger.warn(SOURCE, "Falling back to desktop mode (no VR)")
	DebugLogger.warn(SOURCE, "Reason: %s" % startup_results.failure_reason)
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

	# Capture mouse for desktop controls
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

	DebugLogger.info(SOURCE, "Desktop mode active - use WASD + mouse to move")


func _handle_xr_failure(reason: String) -> void:
	"""Handle critical XR initialization failure"""

	DebugLogger.error(SOURCE, "XR initialization failed: %s" % reason)
	init_state = XRHelpers.XRInitState.FAILED

	# Call subclass hook
	_on_xr_failed(reason)

	# Use centralized shutdown for clean exit
	EngineShutdown.startup_failure(SOURCE, reason)


# =============================================================================
# DESKTOP MODE INPUT (Fallback controls)
# =============================================================================

func _process(delta: float) -> void:
	if not xr_initialized:
		return

	# Desktop mode controls
	if desktop_mode:
		_handle_desktop_input(delta)


func _input(event: InputEvent) -> void:
	if not desktop_mode:
		return

	# Desktop mouse look
	if event is InputEventMouseMotion:
		if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
			var motion := event as InputEventMouseMotion
			xr_camera.rotate_y(-motion.relative.x * desktop_mouse_sensitivity)
			xr_camera.rotate_x(-motion.relative.y * desktop_mouse_sensitivity)
			xr_camera.rotation.x = clamp(xr_camera.rotation.x, -PI/2, PI/2)

	# Toggle mouse capture (ESC)
	if event.is_action_pressed("ui_cancel"):
		if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		else:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


func _handle_desktop_input(delta: float) -> void:
	"""Handle WASD movement and simulated hand positions in desktop mode"""

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
		xr_origin.global_position += direction * desktop_move_speed * delta

	# Simulate hand positions for testing (follow camera)
	if left_controller:
		left_controller.global_position = xr_camera.global_position + xr_camera.global_transform.basis * Vector3(-0.3, -0.2, -0.4)
	if right_controller:
		right_controller.global_position = xr_camera.global_position + xr_camera.global_transform.basis * Vector3(0.3, -0.2, -0.4)


# =============================================================================
# SUBCLASS HOOKS (Override these in your scene)
# =============================================================================

func _on_xr_initialized() -> void:
	"""Called after successful XR initialization (either VR or desktop mode)
	Override this in your scene to setup game-specific nodes and logic"""
	pass


func _on_xr_failed(reason: String) -> void:
	"""Called when XR initialization fails critically (no desktop fallback)
	Override this if you need custom failure handling"""
	pass


# =============================================================================
# UTILITY METHODS (Available to subclasses)
# =============================================================================

func get_hmd_position() -> Vector3:
	"""Get current HMD position in world space"""
	if xr_camera:
		return xr_camera.global_position
	return Vector3.ZERO


func get_controller_position(hand: String) -> Vector3:
	"""Get controller position ('left' or 'right')"""
	if hand == "left" and left_controller:
		return left_controller.global_position
	elif hand == "right" and right_controller:
		return right_controller.global_position
	return Vector3.ZERO


func get_controller_transform(hand: String) -> Transform3D:
	"""Get controller transform ('left' or 'right')"""
	if hand == "left" and left_controller:
		return left_controller.global_transform
	elif hand == "right" and right_controller:
		return right_controller.global_transform
	return Transform3D.IDENTITY


func is_xr_active() -> bool:
	"""Check if XR is initialized and running"""
	return xr_initialized and not desktop_mode and xr_interface != null and xr_interface.is_initialized()


func is_desktop_mode() -> bool:
	"""Check if running in desktop fallback mode"""
	return desktop_mode


func get_refresh_rate() -> float:
	"""Get HMD refresh rate (or default if not available)"""
	if xr_interface:
		var rate := xr_interface.get_display_refresh_rate()
		return rate if rate > 0 else 90.0
	return 90.0


func log_xr_state() -> void:
	"""Log current XR state for debugging"""
	DebugLogger.info(SOURCE, "XR State: initialized=%s, desktop_mode=%s" % [xr_initialized, desktop_mode])
	if xr_interface:
		DebugLogger.info(SOURCE, "  Interface: %s" % xr_interface.get_name())
		DebugLogger.info(SOURCE, "  Refresh: %.1f Hz" % get_refresh_rate())
	DebugLogger.info(SOURCE, "  HMD pos: %v" % get_hmd_position())
	DebugLogger.info(SOURCE, "  Left controller: %v" % get_controller_position("left"))
	DebugLogger.info(SOURCE, "  Right controller: %v" % get_controller_position("right"))

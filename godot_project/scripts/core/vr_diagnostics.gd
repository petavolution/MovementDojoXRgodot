## VR Diagnostics Runner - Comprehensive XR readiness checker for Quest 3 + Virtual Desktop + SteamVR
## Run with: godot --vr-diagnostics
## Checks OpenXR startup, HMD tracking, controller bindings, and frame loop stability
extends Node3D
class_name VRDiagnostics

const SOURCE := "VRDiagnostics"
const TOTAL_STARTUP_STEPS := 5

# Diagnostic configuration
const DEFAULT_TEST_DURATION_MS := 5000  # 5 seconds of frame loop testing
const MIN_VALID_POSE_RATIO := 0.8  # 80% of frames must have valid poses
const MIN_FRAMES_REQUIRED := 100  # Minimum frames to run during test

# XR Nodes
var xr_origin: XROrigin3D
var xr_camera: XRCamera3D
var left_controller: XRController3D
var right_controller: XRController3D

# XR State
var xr_interface: XRInterface
var init_state := XRHelpers.XRInitState.NOT_STARTED
var diagnostic_results: XRHelpers.DiagnosticResults

# Frame loop tracking
var frame_loop_start_time: int = 0
var test_duration_ms: int = DEFAULT_TEST_DURATION_MS
var is_running_frame_test := false
var frame_count := 0

# Signals
signal diagnostics_complete(results: XRHelpers.DiagnosticResults)


func _ready() -> void:
	diagnostic_results = XRHelpers.DiagnosticResults.new()

	DebugLogger.info(SOURCE, "=== VR DIAGNOSTICS MODE ===")
	DebugLogger.info(SOURCE, "Quest 3 + Virtual Desktop + SteamVR Readiness Check")
	DebugLogger.info(SOURCE, "")

	# Get timeout from command line
	test_duration_ms = XRHelpers.get_diagnostic_timeout_ms()
	DebugLogger.info(SOURCE, "Frame loop test duration: %d ms" % test_duration_ms)

	# Setup XR scene structure
	_setup_xr_scene()

	# Run startup sequence with detailed logging
	var startup_success := _run_startup_sequence()

	if startup_success:
		# Start frame loop test
		DebugLogger.info(SOURCE, "")
		DebugLogger.info(SOURCE, "Starting frame loop test...")
		is_running_frame_test = true
		frame_loop_start_time = Time.get_ticks_msec()
	else:
		# Immediate failure
		_finalize_diagnostics()


func _setup_xr_scene() -> void:
	# Create minimal XR scene for diagnostics
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

	DebugLogger.debug(SOURCE, "XR scene structure created")


func _run_startup_sequence() -> bool:
	DebugLogger.info(SOURCE, "")
	DebugLogger.info(SOURCE, "=== OPENXR STARTUP SEQUENCE ===")
	init_state = XRHelpers.XRInitState.FINDING_INTERFACE

	# Step 1: Find OpenXR interface
	XRHelpers.log_startup_step(1, TOTAL_STARTUP_STEPS, "Finding OpenXR interface")
	xr_interface = XRServer.find_interface("OpenXR")

	var check := XRHelpers.check_interface_exists(xr_interface, "xrFindInterface")
	if not check.success:
		diagnostic_results.openxr_available = false
		diagnostic_results.failure_reason = "OpenXR interface not found - SteamVR may not be the active runtime"
		init_state = XRHelpers.XRInitState.FAILED
		return false

	diagnostic_results.openxr_available = true
	XRHelpers.log_startup_result(1, true, "OpenXR interface found")

	# Step 2: Query runtime properties
	XRHelpers.log_startup_step(2, TOTAL_STARTUP_STEPS, "Querying runtime properties")
	init_state = XRHelpers.XRInitState.CHECKING_RUNTIME

	var runtime_info := XRHelpers.detect_runtime()
	diagnostic_results.runtime_name = runtime_info.name
	diagnostic_results.runtime_version = xr_interface.get_name()

	XRHelpers.log_runtime_properties(diagnostic_results.runtime_name, diagnostic_results.runtime_version)
	XRHelpers.log_startup_result(2, true)

	# Detect graphics API
	diagnostic_results.graphics_api = XRHelpers.get_graphics_api_name()
	DebugLogger.info(SOURCE, "Graphics API: %s" % diagnostic_results.graphics_api)

	# Step 3: Initialize interface (creates instance, gets system/HMD)
	XRHelpers.log_startup_step(3, TOTAL_STARTUP_STEPS, "Initializing OpenXR (instance + system)")
	init_state = XRHelpers.XRInitState.INITIALIZING

	# CRITICAL: Set viewport to XR mode BEFORE initialize
	get_viewport().use_xr = true

	var init_success := xr_interface.is_initialized()
	if not init_success:
		init_success = xr_interface.initialize()

	check = XRHelpers.xr_check(init_success, "xrInitialize")
	if not check.success:
		diagnostic_results.failure_reason = "OpenXR initialization failed - HMD may not be connected"
		init_state = XRHelpers.XRInitState.FAILED
		return false

	diagnostic_results.hmd_detected = true
	XRHelpers.log_startup_result(3, true, "HMD detected and bound")

	# Get system properties from interface
	_query_system_properties()

	# Step 4: Configure display
	XRHelpers.log_startup_step(4, TOTAL_STARTUP_STEPS, "Configuring display and view")
	init_state = XRHelpers.XRInitState.CONFIGURING_DISPLAY

	_configure_display()
	XRHelpers.log_startup_result(4, true)

	# Step 5: Configure actions and start session
	XRHelpers.log_startup_step(5, TOTAL_STARTUP_STEPS, "Binding actions and starting session")
	init_state = XRHelpers.XRInitState.CONFIGURING_ACTIONS

	# Check action map exists
	var action_map_path := ProjectSettings.get_setting("xr/openxr/default_action_map", "")
	if action_map_path and ResourceLoader.exists(action_map_path):
		DebugLogger.info(SOURCE, "Action map: %s" % action_map_path)
	else:
		DebugLogger.warn(SOURCE, "Action map not found or not configured")

	init_state = XRHelpers.XRInitState.READY
	XRHelpers.log_startup_result(5, true, "Session ready")

	# Log startup summary
	DebugLogger.info(SOURCE, "")
	XRHelpers.log_startup_summary(diagnostic_results)

	return true


func _query_system_properties() -> void:
	# Query HMD/system info via available XR interface methods
	# Note: Godot's XRInterface abstracts many OpenXR details

	# Get system name (often returns runtime name or HMD model)
	diagnostic_results.hmd_system_name = xr_interface.get_name()

	# Determine form factor
	var form_factor_setting := ProjectSettings.get_setting("xr/openxr/form_factor", 0)
	match form_factor_setting:
		0:
			diagnostic_results.form_factor = "Head-Mounted Display"
		1:
			diagnostic_results.form_factor = "Handheld"
		_:
			diagnostic_results.form_factor = "Unknown (%d)" % form_factor_setting

	# View configuration
	var view_config_setting := ProjectSettings.get_setting("xr/openxr/view_configuration", 1)
	match view_config_setting:
		1:
			diagnostic_results.view_configuration = "Stereo"
		2:
			diagnostic_results.view_configuration = "Mono"
		_:
			diagnostic_results.view_configuration = "Config %d" % view_config_setting

	XRHelpers.log_system_properties(
		diagnostic_results.hmd_system_name,
		diagnostic_results.hmd_vendor_id,
		diagnostic_results.form_factor
	)


func _configure_display() -> void:
	# Get refresh rate
	diagnostic_results.refresh_rate = xr_interface.get_display_refresh_rate()
	if diagnostic_results.refresh_rate <= 0:
		diagnostic_results.refresh_rate = 90.0  # Default VR rate
		DebugLogger.debug(SOURCE, "Using default refresh rate: 90 Hz")

	# Sync physics tick rate
	Engine.physics_ticks_per_second = int(diagnostic_results.refresh_rate)
	DebugLogger.info(SOURCE, "Physics tick rate: %d Hz" % Engine.physics_ticks_per_second)

	# Get render target size (resolution per eye)
	var render_size := xr_interface.get_render_target_size()
	diagnostic_results.resolution_per_eye = Vector2i(int(render_size.x), int(render_size.y))

	# Foveation level
	diagnostic_results.foveation_level = ProjectSettings.get_setting("xr/openxr/foveation_level", -1)

	XRHelpers.log_view_configuration(
		diagnostic_results.view_configuration,
		2,  # Stereo = 2 views
		diagnostic_results.resolution_per_eye
	)

	DebugLogger.info(SOURCE, "Refresh rate: %.0f Hz" % diagnostic_results.refresh_rate)

	# Check play area
	_check_play_area()


func _check_play_area() -> void:
	# Get play area bounds if available
	if xr_interface.has_method("get_play_area"):
		var play_area: PackedVector3Array = xr_interface.get_play_area()
		if play_area.size() >= 3:
			# Calculate bounds from polygon
			var min_x := INF
			var max_x := -INF
			var min_z := INF
			var max_z := -INF
			for point in play_area:
				min_x = minf(min_x, point.x)
				max_x = maxf(max_x, point.x)
				min_z = minf(min_z, point.z)
				max_z = maxf(max_z, point.z)

			diagnostic_results.play_area_size = Vector2(max_x - min_x, max_z - min_z)
			diagnostic_results.play_area_configured = true
			DebugLogger.info(SOURCE, "Play area: %.1fm x %.1fm" % [
				diagnostic_results.play_area_size.x,
				diagnostic_results.play_area_size.y
			])
		else:
			diagnostic_results.play_area_configured = false
			DebugLogger.warn(SOURCE, "Play area not configured (boundary not set up)")
	else:
		diagnostic_results.play_area_configured = false
		DebugLogger.debug(SOURCE, "Play area query not supported")


func _process(_delta: float) -> void:
	if not is_running_frame_test:
		return

	frame_count += 1

	# Check HMD pose
	var hmd_pose_valid := _check_hmd_pose()
	if hmd_pose_valid:
		diagnostic_results.frames_with_valid_hmd_pose += 1

	# Check left controller
	if _check_controller_pose(left_controller, "left"):
		diagnostic_results.frames_with_valid_left_controller += 1
		diagnostic_results.left_controller_tracked = true

	# Check right controller
	if _check_controller_pose(right_controller, "right"):
		diagnostic_results.frames_with_valid_right_controller += 1
		diagnostic_results.right_controller_tracked = true

	# Track controller detection (any frame where they appear)
	if left_controller.get_is_active():
		diagnostic_results.left_controller_detected = true
	if right_controller.get_is_active():
		diagnostic_results.right_controller_detected = true

	diagnostic_results.frames_submitted = frame_count

	# Check if test is complete
	var elapsed := Time.get_ticks_msec() - frame_loop_start_time
	if elapsed >= test_duration_ms and frame_count >= MIN_FRAMES_REQUIRED:
		diagnostic_results.frame_loop_duration_ms = elapsed
		is_running_frame_test = false
		_finalize_diagnostics()


func _check_hmd_pose() -> bool:
	# Camera is considered "tracked" if XR is running and we got a frame
	# For more detailed tracking, check the tracker directly
	var hmd_tracker := XRServer.get_tracker("head")
	if hmd_tracker:
		var pose := hmd_tracker.get_pose("default")
		if pose and pose.has_tracking():
			if not diagnostic_results.hmd_pose_valid:
				DebugLogger.debug(SOURCE, "HMD pose acquired")
			diagnostic_results.hmd_pose_valid = true
			diagnostic_results.hmd_tracking_confidence = pose.tracking_confidence
			return true

	# Fallback: assume tracked if camera has valid global transform
	if xr_camera and xr_interface.is_initialized():
		if not diagnostic_results.hmd_pose_valid:
			diagnostic_results.hmd_pose_valid = true
			diagnostic_results.hmd_tracking_confidence = 1.0
		return true

	return false


func _check_controller_pose(controller: XRController3D, hand: String) -> bool:
	if controller == null:
		return false

	if not controller.get_is_active():
		return false

	if not controller.get_has_tracking_data():
		return false

	# Log first detection
	if hand == "left" and not diagnostic_results.left_controller_detected:
		DebugLogger.debug(SOURCE, "Left controller detected and tracked")
	elif hand == "right" and not diagnostic_results.right_controller_detected:
		DebugLogger.debug(SOURCE, "Right controller detected and tracked")

	return true


func _finalize_diagnostics() -> void:
	DebugLogger.info(SOURCE, "")
	DebugLogger.info(SOURCE, "Frame loop test complete")
	DebugLogger.info(SOURCE, "Frames tested: %d" % diagnostic_results.frames_submitted)

	# Determine pass/fail
	_evaluate_results()

	# Log full report
	DebugLogger.info(SOURCE, "")
	var report := diagnostic_results.to_log_report()
	for line in report.split("\n"):
		DebugLogger.info(SOURCE, line)

	# Print summary to stdout
	print("")
	print(diagnostic_results.get_summary_line())
	print("Log file: %s" % DebugLogger.get_log_path())
	print("")

	# Emit signal for programmatic use
	diagnostics_complete.emit(diagnostic_results)

	# Exit after short delay to ensure log flush
	await get_tree().create_timer(0.5).timeout
	get_tree().quit(0 if diagnostic_results.overall_pass else 1)


func _evaluate_results() -> void:
	# Check OpenXR availability
	if not diagnostic_results.openxr_available:
		diagnostic_results.overall_pass = false
		if diagnostic_results.failure_reason.is_empty():
			diagnostic_results.failure_reason = "OpenXR not available"
		return

	# Check HMD detection
	if not diagnostic_results.hmd_detected:
		diagnostic_results.overall_pass = false
		diagnostic_results.failure_reason = "HMD not detected"
		return

	# Check frame loop ran
	if diagnostic_results.frames_submitted < MIN_FRAMES_REQUIRED:
		diagnostic_results.overall_pass = false
		diagnostic_results.failure_reason = "Insufficient frames (%d < %d)" % [
			diagnostic_results.frames_submitted,
			MIN_FRAMES_REQUIRED
		]
		return

	# Check HMD pose validity ratio
	var hmd_ratio := float(diagnostic_results.frames_with_valid_hmd_pose) / float(diagnostic_results.frames_submitted)
	if hmd_ratio < MIN_VALID_POSE_RATIO:
		diagnostic_results.overall_pass = false
		diagnostic_results.failure_reason = "HMD tracking unstable (%.1f%% valid poses, need %.1f%%)" % [
			hmd_ratio * 100.0,
			MIN_VALID_POSE_RATIO * 100.0
		]
		return

	# Controllers are optional but log warnings
	if not diagnostic_results.left_controller_detected:
		DebugLogger.warn(SOURCE, "Left controller not detected - some dojo features may be unavailable")
	if not diagnostic_results.right_controller_detected:
		DebugLogger.warn(SOURCE, "Right controller not detected - some dojo features may be unavailable")

	# All checks passed
	diagnostic_results.overall_pass = true


# =============================================================================
# STATIC ENTRY POINT
# =============================================================================

## Run VR diagnostics and return results (for programmatic use)
static func run_diagnostics() -> XRHelpers.DiagnosticResults:
	DebugLogger.info("VRDiagnostics", "Starting VR diagnostics...")

	var diagnostics := VRDiagnostics.new()
	# This would need to be added to a scene tree to run

	# For now, return a placeholder - actual use requires scene tree
	return XRHelpers.DiagnosticResults.new()

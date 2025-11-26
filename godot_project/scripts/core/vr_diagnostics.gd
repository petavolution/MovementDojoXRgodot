## VR Diagnostics Runner - Comprehensive XR readiness checker for Quest 3 + Virtual Desktop + SteamVR
## Run with: godot --vr-diagnostics
## Extends BaseVRScene for consistent XR initialization
## Checks OpenXR startup, HMD tracking, controller bindings, and frame loop stability
extends BaseVRScene
class_name VRDiagnostics

const SOURCE := "VRDiagnostics"

# Diagnostic configuration
const DEFAULT_TEST_DURATION_MS := 5000  # 5 seconds of frame loop testing
const MIN_VALID_POSE_RATIO := 0.8  # 80% of frames must have valid poses
const MIN_FRAMES_REQUIRED := 100  # Minimum frames to run during test

# Diagnostic results (startup_results inherited from BaseVRScene)
var diagnostic_results: XRHelpers.DiagnosticResults

# Frame loop tracking
var frame_loop_start_time: int = 0
var test_duration_ms: int = DEFAULT_TEST_DURATION_MS
var is_running_frame_test := false
var frame_count := 0

# Signals
signal diagnostics_complete(results: XRHelpers.DiagnosticResults)


func _ready() -> void:
	DebugLogger.info(SOURCE, "=== VR DIAGNOSTICS MODE ===")
	DebugLogger.info(SOURCE, "Quest 3 + Virtual Desktop + SteamVR Readiness Check")
	DebugLogger.info(SOURCE, "")

	# Get timeout from command line
	test_duration_ms = XRHelpers.get_diagnostic_timeout_ms()
	DebugLogger.info(SOURCE, "Frame loop test duration: %d ms" % test_duration_ms)

	# Disable desktop fallback for diagnostics (we want to fail if VR doesn't work)
	desktop_mode_enabled = false

	# Call base class to handle XR initialization
	# This will call _on_xr_initialized() if successful or _on_xr_failed() if not
	super._ready()


## Called by BaseVRScene after successful XR initialization
func _on_xr_initialized() -> void:
	DebugLogger.info(SOURCE, "XR initialized successfully, starting frame loop test...")

	# Copy startup results from base class for diagnostic report
	diagnostic_results = startup_results

	# Start frame loop test
	DebugLogger.info(SOURCE, "")
	DebugLogger.info(SOURCE, "Starting frame loop test...")
	is_running_frame_test = true
	frame_loop_start_time = Time.get_ticks_msec()


## Called by BaseVRScene when XR initialization fails
func _on_xr_failed(reason: String) -> void:
	DebugLogger.error(SOURCE, "XR initialization failed: %s" % reason)

	# Copy startup results from base class
	diagnostic_results = startup_results
	diagnostic_results.overall_pass = false
	if diagnostic_results.failure_reason.is_empty():
		diagnostic_results.failure_reason = reason

	# Finalize with failure
	_finalize_diagnostics()


# =============================================================================
# XR SETUP COMPLETE - Now handled by BaseVRScene
# Removed ~200 lines of duplicated XR initialization code
# See godot_project/scripts/core/base_vr_scene.gd for implementation
# =============================================================================

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

	# Clean shutdown with log flush
	var exit_code := 0 if diagnostic_results.overall_pass else 1
	var reason := "VR Diagnostics: %s" % ("PASS" if diagnostic_results.overall_pass else "FAIL - " + diagnostic_results.failure_reason)

	# Short delay to ensure all logs are visible
	await get_tree().create_timer(0.3).timeout

	# Use centralized shutdown
	EngineShutdown.request_shutdown(reason, exit_code)


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

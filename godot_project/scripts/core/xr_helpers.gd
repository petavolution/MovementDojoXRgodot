## XR Helpers - OpenXR error handling and startup utilities for Quest 3 + Virtual Desktop + SteamVR
## Provides XR_CHECK-style error handling, error code explanations, and diagnostic utilities
## Designed for robust dojo combat training startup
extends Node
class_name XRHelpers

const SOURCE := "XRHelpers"

# =============================================================================
# OPENXR ERROR CODES (Common codes relevant to SteamVR/Virtual Desktop/Quest 3)
# =============================================================================

## OpenXR result codes mapped to human-readable explanations
## These cover the most common failure modes for Quest 3 + Virtual Desktop + SteamVR
const XR_ERROR_EXPLANATIONS := {
	# Success codes (not errors, but useful for logging)
	0: {"name": "XR_SUCCESS", "explanation": "Operation succeeded"},
	1: {"name": "XR_TIMEOUT_EXPIRED", "explanation": "Timeout occurred waiting for operation"},
	3: {"name": "XR_SESSION_LOSS_PENDING", "explanation": "Session will be lost soon - app should clean up"},
	4: {"name": "XR_EVENT_UNAVAILABLE", "explanation": "No event currently available"},
	5: {"name": "XR_SPACE_BOUNDS_UNAVAILABLE", "explanation": "Play area bounds not configured"},
	7: {"name": "XR_SESSION_NOT_FOCUSED", "explanation": "Session not currently focused (another app has priority)"},
	8: {"name": "XR_FRAME_DISCARDED", "explanation": "Frame was discarded (compositor skipped it)"},

	# Generic errors
	-1: {"name": "XR_ERROR_VALIDATION_FAILURE", "explanation": "Invalid parameter or state"},
	-2: {"name": "XR_ERROR_RUNTIME_FAILURE", "explanation": "OpenXR runtime crashed or failed unexpectedly. Restart SteamVR."},
	-3: {"name": "XR_ERROR_OUT_OF_MEMORY", "explanation": "System ran out of memory"},
	-4: {"name": "XR_ERROR_API_VERSION_UNSUPPORTED", "explanation": "OpenXR API version not supported by runtime"},
	-6: {"name": "XR_ERROR_INITIALIZATION_FAILED", "explanation": "OpenXR failed to initialize. Check SteamVR is running and set as active runtime."},
	-7: {"name": "XR_ERROR_FUNCTION_UNSUPPORTED", "explanation": "Function not supported by this runtime"},
	-8: {"name": "XR_ERROR_FEATURE_UNSUPPORTED", "explanation": "Feature not available (check Quest 3 compatibility)"},
	-9: {"name": "XR_ERROR_EXTENSION_NOT_PRESENT", "explanation": "Required extension not available in this runtime"},
	-10: {"name": "XR_ERROR_LIMIT_REACHED", "explanation": "Resource limit reached"},
	-11: {"name": "XR_ERROR_SIZE_INSUFFICIENT", "explanation": "Buffer too small"},
	-12: {"name": "XR_ERROR_HANDLE_INVALID", "explanation": "Invalid handle (possible use-after-free)"},

	# Instance errors
	-13: {"name": "XR_ERROR_INSTANCE_LOST", "explanation": "OpenXR instance lost. SteamVR may have restarted - need full reinit."},

	# Session errors
	-29: {"name": "XR_ERROR_SESSION_RUNNING", "explanation": "Session already running - cannot start again"},
	-30: {"name": "XR_ERROR_SESSION_NOT_RUNNING", "explanation": "Session not running - start it first"},
	-31: {"name": "XR_ERROR_SESSION_LOST", "explanation": "Session was lost (SteamVR reset?). Need to recreate session."},

	# System errors
	-14: {"name": "XR_ERROR_SYSTEM_INVALID", "explanation": "System ID invalid. HMD may have disconnected."},
	-15: {"name": "XR_ERROR_PATH_INVALID", "explanation": "Action path is invalid"},
	-16: {"name": "XR_ERROR_PATH_COUNT_EXCEEDED", "explanation": "Too many action paths"},
	-17: {"name": "XR_ERROR_PATH_FORMAT_INVALID", "explanation": "Action path format is wrong"},
	-18: {"name": "XR_ERROR_PATH_UNSUPPORTED", "explanation": "Action path not supported by bindings"},
	-19: {"name": "XR_ERROR_LAYER_INVALID", "explanation": "Composition layer invalid"},
	-20: {"name": "XR_ERROR_LAYER_LIMIT_EXCEEDED", "explanation": "Too many composition layers"},
	-21: {"name": "XR_ERROR_SWAPCHAIN_RECT_INVALID", "explanation": "Swapchain rectangle invalid"},
	-22: {"name": "XR_ERROR_SWAPCHAIN_FORMAT_UNSUPPORTED", "explanation": "Swapchain format not supported"},

	# Action errors (controller bindings)
	-23: {"name": "XR_ERROR_ACTION_TYPE_MISMATCH", "explanation": "Action type doesn't match binding"},
	-26: {"name": "XR_ERROR_ACTIONSET_NOT_ATTACHED", "explanation": "Action set not attached to session - bindings won't work"},
	-27: {"name": "XR_ERROR_ACTIONSETS_ALREADY_ATTACHED", "explanation": "Action sets already attached"},

	# Graphics errors
	-48: {"name": "XR_ERROR_GRAPHICS_DEVICE_INVALID", "explanation": "Graphics device invalid. Check Vulkan/D3D setup."},
	-49: {"name": "XR_ERROR_GRAPHICS_REQUIREMENTS_CALL_MISSING", "explanation": "Must query graphics requirements before creating session"},

	# Form factor errors
	-50: {"name": "XR_ERROR_FORM_FACTOR_UNAVAILABLE", "explanation": "HMD not connected or SteamVR not detecting Quest 3"},
	-51: {"name": "XR_ERROR_FORM_FACTOR_UNSUPPORTED", "explanation": "Form factor not supported by runtime"},

	# Pose/tracking errors
	-38: {"name": "XR_ERROR_POSE_INVALID", "explanation": "Tracking pose invalid - HMD may have lost tracking"},
	-39: {"name": "XR_ERROR_INDEX_OUT_OF_RANGE", "explanation": "Index out of valid range"},

	# View errors
	-41: {"name": "XR_ERROR_VIEW_CONFIGURATION_TYPE_UNSUPPORTED", "explanation": "View configuration not supported (stereo mode issue)"},
	-42: {"name": "XR_ERROR_ENVIRONMENT_BLEND_MODE_UNSUPPORTED", "explanation": "Blend mode not supported"},

	# Reference space errors
	-40: {"name": "XR_ERROR_REFERENCE_SPACE_UNSUPPORTED", "explanation": "Reference space (stage/local) not supported"},

	# Runtime/platform specific
	-52: {"name": "XR_ERROR_RUNTIME_UNAVAILABLE", "explanation": "No OpenXR runtime available. Install SteamVR and set as active runtime."},
}

# Common failure modes for Quest 3 + Virtual Desktop + SteamVR
const VD_STEAMVR_COMMON_ISSUES := {
	"steamvr_not_active_runtime": {
		"symptoms": ["XR_ERROR_RUNTIME_UNAVAILABLE", "XR_ERROR_INITIALIZATION_FAILED"],
		"fix": "1. Open SteamVR settings\n2. Go to Developer tab\n3. Click 'Set SteamVR as OpenXR Runtime'\n4. Restart Virtual Desktop"
	},
	"virtual_desktop_not_streaming": {
		"symptoms": ["XR_ERROR_FORM_FACTOR_UNAVAILABLE"],
		"fix": "1. Ensure Virtual Desktop is streaming from Quest 3\n2. Check 'Games' tab shows SteamVR available\n3. Launch SteamVR from Virtual Desktop first"
	},
	"hmd_not_detected": {
		"symptoms": ["XR_ERROR_FORM_FACTOR_UNAVAILABLE", "XR_ERROR_SYSTEM_INVALID"],
		"fix": "1. Check Virtual Desktop is connected\n2. In SteamVR, verify headset shows as tracked\n3. Remove and re-add headset in SteamVR settings"
	},
	"graphics_api_mismatch": {
		"symptoms": ["XR_ERROR_GRAPHICS_DEVICE_INVALID", "XR_ERROR_GRAPHICS_REQUIREMENTS_CALL_MISSING"],
		"fix": "1. Ensure Godot project uses compatible graphics API\n2. Check SteamVR graphics settings\n3. Try switching between Vulkan/D3D12 in project settings"
	},
	"action_binding_issues": {
		"symptoms": ["XR_ERROR_ACTIONSET_NOT_ATTACHED", "XR_ERROR_PATH_UNSUPPORTED"],
		"fix": "1. Verify openxr_action_map.tres exists and is valid\n2. Check controller bindings in SteamVR controller settings\n3. Ensure Quest 3 Touch Pro controllers are bound"
	}
}

# =============================================================================
# XR INITIALIZATION STATES
# =============================================================================

enum XRInitState {
	NOT_STARTED,
	FINDING_INTERFACE,
	CHECKING_RUNTIME,
	INITIALIZING,
	CONFIGURING_DISPLAY,
	CONFIGURING_ACTIONS,
	STARTING_SESSION,
	READY,
	FAILED,
	DEGRADED  # Partially working (e.g., HMD but no controllers)
}

# =============================================================================
# XR CHECK RESULT
# =============================================================================

## Result of an XR operation check
class XRCheckResult:
	var success: bool
	var error_code: int
	var error_name: String
	var error_explanation: String
	var context_tag: String
	var timestamp_ms: int

	func _init(p_success: bool = true, p_code: int = 0, p_tag: String = ""):
		success = p_success
		error_code = p_code
		context_tag = p_tag
		timestamp_ms = Time.get_ticks_msec()

		if p_code in XRHelpers.XR_ERROR_EXPLANATIONS:
			error_name = XRHelpers.XR_ERROR_EXPLANATIONS[p_code].name
			error_explanation = XRHelpers.XR_ERROR_EXPLANATIONS[p_code].explanation
		else:
			error_name = "XR_ERROR_UNKNOWN_%d" % p_code
			error_explanation = "Unknown OpenXR error code"

	func to_log_string() -> String:
		if success:
			return "[%s] OK" % context_tag
		return "[%s] FAILED: %s (code=%d) - %s" % [context_tag, error_name, error_code, error_explanation]

# =============================================================================
# XR DIAGNOSTIC RESULTS
# =============================================================================

## Comprehensive diagnostic results for VR readiness
class DiagnosticResults:
	var overall_pass: bool = false
	var failure_reason: String = ""

	# Runtime info
	var runtime_name: String = ""
	var runtime_version: String = ""
	var openxr_available: bool = false

	# System info
	var hmd_detected: bool = false
	var hmd_vendor_id: int = 0
	var hmd_system_name: String = ""
	var form_factor: String = ""

	# Display info
	var refresh_rate: float = 0.0
	var resolution_per_eye: Vector2i = Vector2i.ZERO
	var view_configuration: String = ""
	var graphics_api: String = ""
	var foveation_level: int = -1

	# Tracking info
	var hmd_pose_valid: bool = false
	var hmd_tracking_confidence: float = 0.0
	var left_controller_detected: bool = false
	var left_controller_tracked: bool = false
	var right_controller_detected: bool = false
	var right_controller_tracked: bool = false

	# Play area
	var play_area_configured: bool = false
	var play_area_size: Vector2 = Vector2.ZERO

	# Frame loop test
	var frames_submitted: int = 0
	var frames_with_valid_hmd_pose: int = 0
	var frames_with_valid_left_controller: int = 0
	var frames_with_valid_right_controller: int = 0
	var frame_loop_duration_ms: int = 0

	func get_summary_line() -> String:
		if overall_pass:
			return "VR Diagnostics: PASS - Ready for dojo prototype."
		return "VR Diagnostics: FAIL - Reason: %s. See log for details." % failure_reason

	func to_log_report() -> String:
		var lines: Array[String] = []
		lines.append("=== VR DIAGNOSTIC REPORT ===")
		lines.append("")
		lines.append("[Runtime]")
		lines.append("  OpenXR Available: %s" % openxr_available)
		lines.append("  Runtime: %s" % runtime_name)
		lines.append("  Version: %s" % runtime_version)
		lines.append("")
		lines.append("[System]")
		lines.append("  HMD Detected: %s" % hmd_detected)
		lines.append("  System Name: %s" % hmd_system_name)
		lines.append("  Form Factor: %s" % form_factor)
		lines.append("  Vendor ID: %d" % hmd_vendor_id)
		lines.append("")
		lines.append("[Display]")
		lines.append("  Graphics API: %s" % graphics_api)
		lines.append("  Refresh Rate: %.0f Hz" % refresh_rate)
		lines.append("  Resolution Per Eye: %dx%d" % [resolution_per_eye.x, resolution_per_eye.y])
		lines.append("  View Configuration: %s" % view_configuration)
		if foveation_level >= 0:
			lines.append("  Foveation Level: %d" % foveation_level)
		lines.append("")
		lines.append("[Tracking]")
		lines.append("  HMD Pose Valid: %s (confidence: %.2f)" % [hmd_pose_valid, hmd_tracking_confidence])
		lines.append("  Left Controller: detected=%s tracked=%s" % [left_controller_detected, left_controller_tracked])
		lines.append("  Right Controller: detected=%s tracked=%s" % [right_controller_detected, right_controller_tracked])
		lines.append("")
		lines.append("[Play Area]")
		lines.append("  Configured: %s" % play_area_configured)
		if play_area_configured:
			lines.append("  Size: %.1fm x %.1fm" % [play_area_size.x, play_area_size.y])
		lines.append("")
		lines.append("[Frame Loop Test - %d ms]" % frame_loop_duration_ms)
		lines.append("  Frames Submitted: %d" % frames_submitted)
		lines.append("  Frames with Valid HMD Pose: %d (%.1f%%)" % [
			frames_with_valid_hmd_pose,
			100.0 * frames_with_valid_hmd_pose / maxf(1, frames_submitted)
		])
		lines.append("  Frames with Left Controller: %d (%.1f%%)" % [
			frames_with_valid_left_controller,
			100.0 * frames_with_valid_left_controller / maxf(1, frames_submitted)
		])
		lines.append("  Frames with Right Controller: %d (%.1f%%)" % [
			frames_with_valid_right_controller,
			100.0 * frames_with_valid_right_controller / maxf(1, frames_submitted)
		])
		lines.append("")
		lines.append("[Result]")
		if overall_pass:
			lines.append("  STATUS: PASS")
			lines.append("  Ready for dojo prototype!")
		else:
			lines.append("  STATUS: FAIL")
			lines.append("  Reason: %s" % failure_reason)
		lines.append("")
		lines.append("=== END DIAGNOSTIC REPORT ===")

		return "\n".join(lines)

# =============================================================================
# XR_CHECK - Error Checking Helper
# =============================================================================

## Check an XR operation result and log appropriately
## Returns XRCheckResult with success status and error details
static func xr_check(success: bool, context_tag: String, error_code: int = -6) -> XRCheckResult:
	var result := XRCheckResult.new(success, error_code if not success else 0, context_tag)

	if success:
		DebugLogger.debug("OpenXR", "[%s] OK" % context_tag)
	else:
		DebugLogger.error("OpenXR", result.to_log_string())
		_suggest_fixes_for_error(error_code)

	return result


## Check if XR interface exists
static func check_interface_exists(xr_interface: XRInterface, context_tag: String) -> XRCheckResult:
	if xr_interface == null:
		var result := XRCheckResult.new(false, -52, context_tag)  # XR_ERROR_RUNTIME_UNAVAILABLE
		DebugLogger.error("OpenXR", result.to_log_string())
		_suggest_fixes_for_error(-52)
		return result
	return XRCheckResult.new(true, 0, context_tag)


## Check if XR interface is initialized
static func check_initialized(xr_interface: XRInterface, context_tag: String) -> XRCheckResult:
	if xr_interface == null:
		return check_interface_exists(xr_interface, context_tag)

	if not xr_interface.is_initialized():
		var result := XRCheckResult.new(false, -6, context_tag)  # XR_ERROR_INITIALIZATION_FAILED
		DebugLogger.error("OpenXR", result.to_log_string())
		_suggest_fixes_for_error(-6)
		return result

	return XRCheckResult.new(true, 0, context_tag)


## Log suggested fixes for common error codes
static func _suggest_fixes_for_error(error_code: int) -> void:
	for issue_key in VD_STEAMVR_COMMON_ISSUES:
		var issue: Dictionary = VD_STEAMVR_COMMON_ISSUES[issue_key]
		var error_name := ""
		if error_code in XR_ERROR_EXPLANATIONS:
			error_name = XR_ERROR_EXPLANATIONS[error_code].name

		if error_name in issue.symptoms:
			DebugLogger.warn("OpenXR", "Possible issue: %s" % issue_key)
			DebugLogger.warn("OpenXR", "Suggested fix:\n%s" % issue.fix)
			return


# =============================================================================
# STARTUP LOGGING HELPERS
# =============================================================================

## Log startup step with step number
static func log_startup_step(step: int, total: int, description: String) -> void:
	DebugLogger.info("OpenXR", "Step %d/%d - %s" % [step, total, description])


## Log startup step result
static func log_startup_result(step: int, success: bool, details: String = "") -> void:
	if success:
		var msg := "Step %d: OK" % step
		if details:
			msg += " - %s" % details
		DebugLogger.info("OpenXR", msg)
	else:
		DebugLogger.error("OpenXR", "Step %d: FAILED - %s" % [step, details])


## Log XR runtime properties
static func log_runtime_properties(runtime_name: String, runtime_version: String) -> void:
	DebugLogger.info("OpenXR", "Runtime: %s" % runtime_name)
	DebugLogger.info("OpenXR", "Version: %s" % runtime_version)
	DebugLogger.xr_runtime(runtime_name, runtime_version, true)


## Log XR system properties
static func log_system_properties(system_name: String, vendor_id: int, form_factor: String) -> void:
	DebugLogger.info("OpenXR", "System: %s" % system_name)
	DebugLogger.info("OpenXR", "Vendor ID: %d" % vendor_id)
	DebugLogger.info("OpenXR", "Form Factor: %s" % form_factor)


## Log graphics binding info
static func log_graphics_binding(api_name: String, success: bool) -> void:
	if success:
		DebugLogger.info("OpenXR", "Graphics API: %s - bound successfully" % api_name)
	else:
		DebugLogger.error("OpenXR", "Graphics API: %s - binding FAILED" % api_name)


## Log view configuration
static func log_view_configuration(config_type: String, view_count: int, resolution: Vector2i) -> void:
	DebugLogger.info("OpenXR", "View Configuration: %s" % config_type)
	DebugLogger.info("OpenXR", "View Count: %d" % view_count)
	DebugLogger.info("OpenXR", "Recommended Resolution: %dx%d per eye" % [resolution.x, resolution.y])


## Log startup summary block
static func log_startup_summary(results: DiagnosticResults) -> void:
	DebugLogger.info("OpenXR", "=== STARTUP SUMMARY ===")
	DebugLogger.info("OpenXR", "Runtime: %s v%s" % [results.runtime_name, results.runtime_version])
	DebugLogger.info("OpenXR", "System: %s (vendor=%d)" % [results.hmd_system_name, results.hmd_vendor_id])
	DebugLogger.info("OpenXR", "Display: %.0fHz @ %dx%d (%s)" % [
		results.refresh_rate,
		results.resolution_per_eye.x,
		results.resolution_per_eye.y,
		results.graphics_api
	])
	DebugLogger.info("OpenXR", "View Config: %s" % results.view_configuration)
	if results.foveation_level >= 0:
		DebugLogger.info("OpenXR", "Foveation: Level %d" % results.foveation_level)
	DebugLogger.info("OpenXR", "======================")


# =============================================================================
# RUNTIME DETECTION
# =============================================================================

## Detect OpenXR runtime (SteamVR, Oculus, WMR, etc.)
static func detect_runtime() -> Dictionary:
	var result := {
		"name": "Unknown",
		"version": "0.0.0",
		"is_steamvr": false,
		"is_oculus": false,
		"is_virtual_desktop": false,
	}

	# Check environment variables
	var runtime_json := OS.get_environment("XR_RUNTIME_JSON")
	if runtime_json:
		if "steamxr" in runtime_json.to_lower() or "steamvr" in runtime_json.to_lower():
			result.name = "SteamVR"
			result.is_steamvr = true
		elif "oculus" in runtime_json.to_lower():
			result.name = "Oculus"
			result.is_oculus = true

	# Check for Virtual Desktop indicators
	# Virtual Desktop appears as SteamVR but with Quest 3 hardware
	if OS.get_environment("VIRTUAL_DESKTOP_MODE") != "":
		result.is_virtual_desktop = true

	return result


## Get graphics API name from Godot's renderer
static func get_graphics_api_name() -> String:
	var rendering_method := ProjectSettings.get_setting("rendering/renderer/rendering_method", "forward_plus")
	var driver_name := RenderingServer.get_video_adapter_name()

	# Detect API from context
	if OS.get_name() == "Windows":
		# Check Vulkan vs D3D12
		if "vulkan" in driver_name.to_lower():
			return "Vulkan"
		return "D3D12"
	elif OS.get_name() == "Linux":
		return "Vulkan"
	elif OS.get_name() == "macOS":
		return "Metal"

	return "Unknown (%s)" % rendering_method


# =============================================================================
# TRACKING UTILITIES
# =============================================================================

## Check if a tracker is currently providing valid data
static func is_tracker_valid(tracker: XRPositionalTracker) -> bool:
	if tracker == null:
		return false
	return tracker.get_pose("default") != null


## Get tracking confidence for a pose (0.0 to 1.0)
static func get_pose_confidence(pose: XRPose) -> float:
	if pose == null:
		return 0.0

	# XRPose has tracking_confidence property
	if pose.has_tracking():
		return pose.tracking_confidence
	return 0.0


## Check if we're in a degraded tracking state
static func check_tracking_degraded(xr_origin: XROrigin3D) -> Dictionary:
	var result := {
		"degraded": false,
		"hmd_ok": false,
		"left_ok": false,
		"right_ok": false,
		"issues": [] as Array[String]
	}

	if xr_origin == null:
		result.degraded = true
		result.issues.append("XROrigin3D not available")
		return result

	# Check camera (HMD)
	var camera := xr_origin.get_node_or_null("XRCamera3D") as XRCamera3D
	if camera:
		# Camera is always "tracked" if XR is active
		result.hmd_ok = true
	else:
		result.issues.append("XRCamera3D not found")

	# Check controllers
	for child in xr_origin.get_children():
		if child is XRController3D:
			var controller := child as XRController3D
			var is_active := controller.get_is_active()
			var has_tracking := controller.get_has_tracking_data()

			if "left" in controller.name.to_lower():
				result.left_ok = is_active and has_tracking
				if not result.left_ok:
					result.issues.append("Left controller: active=%s tracking=%s" % [is_active, has_tracking])
			elif "right" in controller.name.to_lower():
				result.right_ok = is_active and has_tracking
				if not result.right_ok:
					result.issues.append("Right controller: active=%s tracking=%s" % [is_active, has_tracking])

	# Determine if degraded
	if not result.hmd_ok:
		result.degraded = true
	# Controllers are optional but log if missing

	return result


# =============================================================================
# COMMAND LINE UTILITIES
# =============================================================================

## Check if --vr-diagnostics flag is present
static func has_diagnostics_flag() -> bool:
	var args := OS.get_cmdline_args()
	return "--vr-diagnostics" in args or "-vr-diagnostics" in args


## Check if --vr-smoke-test flag is present
static func has_smoke_test_flag() -> bool:
	var args := OS.get_cmdline_args()
	return "--vr-smoke-test" in args or "-vr-smoke-test" in args


## Check if --headless flag is present (for CI/testing)
static func has_headless_flag() -> bool:
	var args := OS.get_cmdline_args()
	return "--headless" in args


## Get diagnostic timeout from command line (default 5 seconds)
static func get_diagnostic_timeout_ms() -> int:
	var args := OS.get_cmdline_args()
	for i in range(args.size() - 1):
		if args[i] == "--diagnostic-timeout":
			return int(args[i + 1]) * 1000
	return 5000  # Default 5 seconds

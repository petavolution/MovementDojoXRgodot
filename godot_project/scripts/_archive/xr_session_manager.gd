## XRSessionManager - Abstraction layer over OpenXR/SteamVR runtimes
## Provides unified interface for XR session lifecycle and capabilities
class_name XRSessionManager
extends Node

signal session_initialized(runtime_info: RuntimeInfo)
signal session_started
signal session_ended
signal session_focused
signal session_unfocused
signal runtime_error(error_code: int, message: String)
signal tracking_lost(device: String)
signal tracking_restored(device: String)
signal reference_space_changed(space_type: String)
signal bounds_changed(bounds: PackedVector3Array)

## Runtime information
class RuntimeInfo:
	var runtime_name: String = ""
	var runtime_version: String = ""
	var system_name: String = ""
	var is_openxr: bool = false
	var is_steamvr: bool = false
	var supports_hand_tracking: bool = false
	var supports_eye_tracking: bool = false
	var supports_passthrough: bool = false
	var supports_foveation: bool = false
	var refresh_rates: Array[float] = []
	var current_refresh_rate: float = 90.0
	var play_area_mode: String = "stage"  # stage, local, unbounded
	var play_area_size: Vector2 = Vector2.ZERO

## Session states (following OpenXR session lifecycle)
enum SessionState {
	UNKNOWN,
	IDLE,
	READY,
	SYNCHRONIZED,
	VISIBLE,
	FOCUSED,
	STOPPING,
	LOSS_PENDING,
	EXITING
}

## Reference space types
enum ReferenceSpace {
	LOCAL,          # Head-locked
	STAGE,          # Room-scale with floor
	VIEW,           # View-locked (HMD relative)
	LOCAL_FLOOR,    # Local with floor estimate
	UNBOUNDED       # Large-scale tracking
}

## State
var current_state: SessionState = SessionState.UNKNOWN
var runtime_info: RuntimeInfo = RuntimeInfo.new()
var is_initialized: bool = false
var is_session_active: bool = false

## XR references
var xr_interface: XRInterface
var xr_origin: XROrigin3D
var xr_camera: XRCamera3D
var left_controller: XRController3D
var right_controller: XRController3D
var left_hand: XRNode3D  # For hand tracking
var right_hand: XRNode3D

## Configuration
@export var preferred_runtime: String = "openxr"  # "openxr", "steamvr"
@export var target_refresh_rate: float = 90.0
@export var reference_space: ReferenceSpace = ReferenceSpace.STAGE
@export var enable_hand_tracking: bool = true
@export var enable_passthrough: bool = false

## Tracking state
var headset_tracked: bool = false
var left_controller_tracked: bool = false
var right_controller_tracked: bool = false
var left_hand_tracked: bool = false
var right_hand_tracked: bool = false

## Bounds
var stage_bounds: PackedVector3Array = []
var play_area_center: Vector3 = Vector3.ZERO


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


## Initialize XR session with automatic runtime detection
func initialize() -> bool:
	if is_initialized:
		return true

	# Find available XR interface
	xr_interface = _find_xr_interface()
	if xr_interface == null:
		runtime_error.emit(-1, "No XR interface found")
		return false

	# Initialize the interface
	if not xr_interface.is_initialized():
		if not xr_interface.initialize():
			runtime_error.emit(-2, "Failed to initialize XR interface")
			return false

	# Gather runtime information
	_query_runtime_info()

	# Configure based on capabilities
	_configure_session()

	# Set as primary interface
	get_viewport().use_xr = true

	is_initialized = true
	current_state = SessionState.READY
	session_initialized.emit(runtime_info)

	return true


func _find_xr_interface() -> XRInterface:
	# Try to find OpenXR first (preferred)
	var interfaces := XRServer.get_interfaces()

	for interface_info in interfaces:
		var interface_name: String = interface_info.get("name", "")
		if preferred_runtime == "openxr" and interface_name == "OpenXR":
			return XRServer.find_interface("OpenXR")
		elif preferred_runtime == "steamvr" and interface_name == "OpenVR":
			return XRServer.find_interface("OpenVR")

	# Fallback: try any available
	for interface_info in interfaces:
		var interface_name: String = interface_info.get("name", "")
		if interface_name in ["OpenXR", "OpenVR"]:
			return XRServer.find_interface(interface_name)

	return null


func _query_runtime_info() -> void:
	if xr_interface == null:
		return

	runtime_info.runtime_name = xr_interface.name
	runtime_info.is_openxr = xr_interface.name == "OpenXR"
	runtime_info.is_steamvr = xr_interface.name == "OpenVR"

	# Query capabilities
	if runtime_info.is_openxr:
		_query_openxr_capabilities()

	# Get refresh rates
	if xr_interface.has_method("get_available_display_refresh_rates"):
		var rates = xr_interface.get_available_display_refresh_rates()
		if rates is Array:
			for rate in rates:
				runtime_info.refresh_rates.append(float(rate))

	# Default refresh rate
	if runtime_info.refresh_rates.is_empty():
		runtime_info.refresh_rates = [72.0, 80.0, 90.0, 120.0]

	runtime_info.current_refresh_rate = 90.0

	# Get play area
	if xr_interface.has_method("get_play_area"):
		var area = xr_interface.get_play_area()
		if area is PackedVector3Array and area.size() >= 4:
			stage_bounds = area
			_calculate_play_area_size()


func _query_openxr_capabilities() -> void:
	# OpenXR-specific capability detection
	var openxr := xr_interface as OpenXRInterface if xr_interface is OpenXRInterface else null
	if openxr == null:
		return

	# Check for extensions
	runtime_info.supports_hand_tracking = _check_openxr_extension("XR_EXT_hand_tracking")
	runtime_info.supports_eye_tracking = _check_openxr_extension("XR_EXT_eye_gaze_interaction")
	runtime_info.supports_passthrough = _check_openxr_extension("XR_FB_passthrough")
	runtime_info.supports_foveation = _check_openxr_extension("XR_FB_foveation")


func _check_openxr_extension(extension_name: String) -> bool:
	# Would check OpenXR enabled extensions
	# Godot's OpenXR implementation handles this internally
	return false


func _configure_session() -> void:
	if xr_interface == null:
		return

	# Set target refresh rate
	if xr_interface.has_method("set_display_refresh_rate"):
		var target := target_refresh_rate
		# Find closest available rate
		var closest := 90.0
		var min_diff := 999.0
		for rate in runtime_info.refresh_rates:
			var diff := absf(rate - target)
			if diff < min_diff:
				min_diff = diff
				closest = rate
		xr_interface.set_display_refresh_rate(closest)
		runtime_info.current_refresh_rate = closest


func _calculate_play_area_size() -> void:
	if stage_bounds.size() < 4:
		return

	# Calculate bounds rectangle
	var min_x := INF
	var max_x := -INF
	var min_z := INF
	var max_z := -INF

	for point in stage_bounds:
		min_x = minf(min_x, point.x)
		max_x = maxf(max_x, point.x)
		min_z = minf(min_z, point.z)
		max_z = maxf(max_z, point.z)

	runtime_info.play_area_size = Vector2(max_x - min_x, max_z - min_z)
	play_area_center = Vector3((min_x + max_x) / 2.0, 0, (min_z + max_z) / 2.0)


## Setup XR node references
func setup_xr_nodes(origin: XROrigin3D, camera: XRCamera3D, left: XRController3D, right: XRController3D) -> void:
	xr_origin = origin
	xr_camera = camera
	left_controller = left
	right_controller = right

	# Connect tracking signals
	if left_controller:
		if not left_controller.tracking_changed.is_connected(_on_left_controller_tracking_changed):
			left_controller.tracking_changed.connect(_on_left_controller_tracking_changed)

	if right_controller:
		if not right_controller.tracking_changed.is_connected(_on_right_controller_tracking_changed):
			right_controller.tracking_changed.connect(_on_right_controller_tracking_changed)


## Start XR session
func start_session() -> bool:
	if not is_initialized:
		if not initialize():
			return false

	is_session_active = true
	current_state = SessionState.FOCUSED
	session_started.emit()

	return true


## End XR session
func end_session() -> void:
	is_session_active = false
	current_state = SessionState.STOPPING
	session_ended.emit()


## Pause session (unfocus)
func pause_session() -> void:
	if is_session_active:
		current_state = SessionState.VISIBLE
		session_unfocused.emit()


## Resume session (refocus)
func resume_session() -> void:
	if is_session_active:
		current_state = SessionState.FOCUSED
		session_focused.emit()


func _on_left_controller_tracking_changed(tracking: bool) -> void:
	left_controller_tracked = tracking
	if tracking:
		tracking_restored.emit("left_controller")
	else:
		tracking_lost.emit("left_controller")


func _on_right_controller_tracking_changed(tracking: bool) -> void:
	right_controller_tracked = tracking
	if tracking:
		tracking_restored.emit("right_controller")
	else:
		tracking_lost.emit("right_controller")


## Get headset position in world space
func get_headset_position() -> Vector3:
	if xr_camera:
		return xr_camera.global_position
	return Vector3.ZERO


## Get headset rotation
func get_headset_rotation() -> Quaternion:
	if xr_camera:
		return xr_camera.global_transform.basis.get_rotation_quaternion()
	return Quaternion.IDENTITY


## Get controller position
func get_controller_position(hand: String) -> Vector3:
	match hand:
		"left":
			if left_controller:
				return left_controller.global_position
		"right":
			if right_controller:
				return right_controller.global_position
	return Vector3.ZERO


## Get controller rotation
func get_controller_rotation(hand: String) -> Quaternion:
	match hand:
		"left":
			if left_controller:
				return left_controller.global_transform.basis.get_rotation_quaternion()
		"right":
			if right_controller:
				return right_controller.global_transform.basis.get_rotation_quaternion()
	return Quaternion.IDENTITY


## Check if point is within play area bounds
func is_within_bounds(point: Vector3) -> bool:
	if stage_bounds.size() < 3:
		return true  # No bounds defined

	# Simple AABB check
	var margin := 0.1
	var size := runtime_info.play_area_size
	var half_width := size.x / 2.0 - margin
	var half_depth := size.y / 2.0 - margin

	var local_point := point - play_area_center
	return absf(local_point.x) <= half_width and absf(local_point.z) <= half_depth


## Get distance to nearest boundary
func get_distance_to_boundary(point: Vector3) -> float:
	if stage_bounds.size() < 4:
		return INF

	var min_distance := INF

	for i in range(stage_bounds.size()):
		var p1 := stage_bounds[i]
		var p2 := stage_bounds[(i + 1) % stage_bounds.size()]

		var distance := _point_to_line_distance(Vector2(point.x, point.z),
			Vector2(p1.x, p1.z), Vector2(p2.x, p2.z))
		min_distance = minf(min_distance, distance)

	return min_distance


func _point_to_line_distance(point: Vector2, line_start: Vector2, line_end: Vector2) -> float:
	var line := line_end - line_start
	var length_sq := line.length_squared()

	if length_sq < 0.0001:
		return point.distance_to(line_start)

	var t := clampf(((point - line_start).dot(line)) / length_sq, 0.0, 1.0)
	var projection := line_start + line * t
	return point.distance_to(projection)


## Request specific reference space
func set_reference_space(space: ReferenceSpace) -> bool:
	reference_space = space
	# Would configure OpenXR reference space
	reference_space_changed.emit(_space_name(space))
	return true


func _space_name(space: ReferenceSpace) -> String:
	match space:
		ReferenceSpace.LOCAL: return "local"
		ReferenceSpace.STAGE: return "stage"
		ReferenceSpace.VIEW: return "view"
		ReferenceSpace.LOCAL_FLOOR: return "local_floor"
		ReferenceSpace.UNBOUNDED: return "unbounded"
	return "unknown"


## Get current session state name
func get_state_name() -> String:
	match current_state:
		SessionState.UNKNOWN: return "Unknown"
		SessionState.IDLE: return "Idle"
		SessionState.READY: return "Ready"
		SessionState.SYNCHRONIZED: return "Synchronized"
		SessionState.VISIBLE: return "Visible"
		SessionState.FOCUSED: return "Focused"
		SessionState.STOPPING: return "Stopping"
		SessionState.LOSS_PENDING: return "Loss Pending"
		SessionState.EXITING: return "Exiting"
	return "Unknown"


## Get runtime capabilities summary
func get_capabilities() -> Dictionary:
	return {
		"runtime": runtime_info.runtime_name,
		"is_openxr": runtime_info.is_openxr,
		"is_steamvr": runtime_info.is_steamvr,
		"hand_tracking": runtime_info.supports_hand_tracking,
		"eye_tracking": runtime_info.supports_eye_tracking,
		"passthrough": runtime_info.supports_passthrough,
		"foveation": runtime_info.supports_foveation,
		"refresh_rates": runtime_info.refresh_rates,
		"current_refresh_rate": runtime_info.current_refresh_rate,
		"play_area_mode": runtime_info.play_area_mode,
		"play_area_size": runtime_info.play_area_size
	}


## Check if specific feature is available
func has_feature(feature: String) -> bool:
	match feature:
		"hand_tracking": return runtime_info.supports_hand_tracking
		"eye_tracking": return runtime_info.supports_eye_tracking
		"passthrough": return runtime_info.supports_passthrough
		"foveation": return runtime_info.supports_foveation
	return false

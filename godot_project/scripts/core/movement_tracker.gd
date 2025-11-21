## MovementTracker - Core VR movement data capture system
## Autoloaded as "MovementTracker"
## Records all controller/headset movements at physics tick rate
extends Node

# Configuration
const MAX_FRAME_BUFFER := 9000  # ~100 seconds at 90Hz
const FRAME_SAMPLE_RATE := 1  # Record every N physics frames (1 = all)

# XR references (set by main scene)
var xr_origin: XROrigin3D
var xr_camera: XRCamera3D
var left_controller: XRController3D
var right_controller: XRController3D

# State
var is_tracking := false
var session_start_time := 0.0
var frame_counter := 0
var previous_frame: MovementFrame = null

# Frame buffer (ring buffer for memory efficiency)
var frame_buffer: Array[MovementFrame] = []
var buffer_write_index := 0
var total_frames_recorded := 0

# Movement space map reference
var space_map: MovementSpaceMap


func _ready() -> void:
	space_map = MovementSpaceMap.new()
	process_physics_priority = -100  # Run before other physics processing


func _physics_process(delta: float) -> void:
	if not is_tracking:
		return

	if not _validate_xr_references():
		return

	frame_counter += 1
	if frame_counter % FRAME_SAMPLE_RATE != 0:
		return

	var frame := _capture_frame(delta)
	_store_frame(frame)
	_update_space_map(frame)

	GameEvents.movement_frame_recorded.emit(frame)


func start_tracking() -> void:
	if is_tracking:
		return

	is_tracking = true
	session_start_time = Time.get_ticks_msec() / 1000.0
	frame_counter = 0
	buffer_write_index = 0
	total_frames_recorded = 0
	previous_frame = null
	frame_buffer.clear()
	space_map.reset()

	print("[MovementTracker] Tracking started")


func stop_tracking() -> void:
	is_tracking = false
	print("[MovementTracker] Tracking stopped. Total frames: ", total_frames_recorded)


func setup_xr_nodes(origin: XROrigin3D, camera: XRCamera3D, left: XRController3D, right: XRController3D) -> void:
	xr_origin = origin
	xr_camera = camera
	left_controller = left
	right_controller = right
	print("[MovementTracker] XR nodes configured")


func get_current_frame() -> MovementFrame:
	if frame_buffer.is_empty():
		return null
	var idx := (buffer_write_index - 1 + frame_buffer.size()) % frame_buffer.size()
	return frame_buffer[idx]


func get_recent_frames(count: int) -> Array[MovementFrame]:
	var result: Array[MovementFrame] = []
	var available := mini(count, frame_buffer.size())

	for i in range(available):
		var idx := (buffer_write_index - 1 - i + frame_buffer.size()) % frame_buffer.size()
		if idx >= 0 and idx < frame_buffer.size():
			result.append(frame_buffer[idx])

	result.reverse()  # Oldest first
	return result


func get_all_frames() -> Array[MovementFrame]:
	return frame_buffer.duplicate()


func get_space_map() -> MovementSpaceMap:
	return space_map


func get_session_duration() -> float:
	if not is_tracking:
		return 0.0
	return Time.get_ticks_msec() / 1000.0 - session_start_time


func _validate_xr_references() -> bool:
	return xr_origin != null and xr_camera != null and left_controller != null and right_controller != null


func _capture_frame(delta: float) -> MovementFrame:
	var current_time := Time.get_ticks_msec() / 1000.0 - session_start_time

	var frame := MovementFrame.create(
		current_time,
		delta,
		xr_camera.global_position,
		xr_camera.global_transform.basis.get_rotation_quaternion(),
		left_controller.global_position,
		left_controller.global_transform.basis.get_rotation_quaternion(),
		right_controller.global_position,
		right_controller.global_transform.basis.get_rotation_quaternion()
	)

	# Capture input state
	frame.left_grip = left_controller.get_float("grip")
	frame.left_trigger = left_controller.get_float("trigger")
	frame.right_grip = right_controller.get_float("grip")
	frame.right_trigger = right_controller.get_float("trigger")

	# Compute velocities from previous frame
	frame.compute_velocities(previous_frame)

	# Compute derived metrics
	frame.compute_derived_metrics()

	return frame


func _store_frame(frame: MovementFrame) -> void:
	if frame_buffer.size() < MAX_FRAME_BUFFER:
		frame_buffer.append(frame)
	else:
		frame_buffer[buffer_write_index] = frame

	buffer_write_index = (buffer_write_index + 1) % MAX_FRAME_BUFFER
	total_frames_recorded += 1
	previous_frame = frame


func _update_space_map(frame: MovementFrame) -> void:
	var left_explored := space_map.record_position("left", frame.left_position, frame.head_position)
	var right_explored := space_map.record_position("right", frame.right_position, frame.head_position)

	if left_explored:
		GameEvents.movement_zone_explored.emit(frame.left_position, "left")
	if right_explored:
		GameEvents.movement_zone_explored.emit(frame.right_position, "right")

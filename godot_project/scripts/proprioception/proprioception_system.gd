## ProprioceptionSystem - Core body awareness and spatial training
## Tracks limb positions and provides real-time feedback for proprioceptive development
class_name ProprioceptionSystem
extends Node

signal position_deviation(limb: String, deviation: float, direction: Vector3)
signal posture_achieved(posture_name: String, accuracy: float)
signal posture_lost(posture_name: String)
signal proprioception_score_updated(score: float)
signal guidance_triggered(limb: String, target_direction: Vector3)

## Limb tracking
enum Limb { HEAD, LEFT_HAND, RIGHT_HAND, LEFT_ELBOW, RIGHT_ELBOW }

## Target posture definition
class TargetPosture:
	var name: String = ""
	var description: String = ""
	var head_position: Vector3 = Vector3.ZERO  # Relative to origin
	var head_rotation: Vector3 = Vector3.ZERO  # Euler angles
	var left_hand_position: Vector3 = Vector3.ZERO
	var left_hand_rotation: Vector3 = Vector3.ZERO
	var right_hand_position: Vector3 = Vector3.ZERO
	var right_hand_rotation: Vector3 = Vector3.ZERO
	var position_tolerance: float = 0.1  # meters
	var rotation_tolerance: float = 15.0  # degrees
	var hold_duration: float = 2.0  # seconds to hold for success
	var use_relative_positions: bool = true  # Relative to player calibration


## Current tracking state
var current_head_pos: Vector3 = Vector3.ZERO
var current_head_rot: Vector3 = Vector3.ZERO
var current_left_pos: Vector3 = Vector3.ZERO
var current_left_rot: Vector3 = Vector3.ZERO
var current_right_pos: Vector3 = Vector3.ZERO
var current_right_rot: Vector3 = Vector3.ZERO

## Target state
var active_posture: TargetPosture
var is_tracking_posture: bool = false
var posture_hold_timer: float = 0.0
var posture_achieved_flag: bool = false

## Deviation tracking
var head_deviation: float = 0.0
var left_hand_deviation: float = 0.0
var right_hand_deviation: float = 0.0
var total_deviation: float = 0.0

## Scoring
var proprioception_score: float = 0.0
var accuracy_history: Array[float] = []
const HISTORY_SIZE := 100

## Guidance settings
@export var guidance_haptic_enabled: bool = true
@export var guidance_visual_enabled: bool = true
@export var guidance_threshold: float = 0.15  # Start guiding when deviation > threshold
@export var guidance_intensity_curve: Curve  # Haptic intensity based on deviation

## References
var xr_camera: XRCamera3D
var left_controller: XRController3D
var right_controller: XRController3D
var calibration: CalibrationSystem

## Predefined postures
var posture_library: Dictionary = {}


func _ready() -> void:
	_setup_posture_library()


func setup(camera: XRCamera3D, left: XRController3D, right: XRController3D, cal: CalibrationSystem = null) -> void:
	xr_camera = camera
	left_controller = left
	right_controller = right
	calibration = cal


func _process(delta: float) -> void:
	_update_tracking()

	if is_tracking_posture and active_posture != null:
		_evaluate_posture(delta)


func _update_tracking() -> void:
	if xr_camera:
		current_head_pos = xr_camera.global_position
		current_head_rot = xr_camera.rotation_degrees

	if left_controller:
		current_left_pos = left_controller.global_position
		current_left_rot = left_controller.rotation_degrees

	if right_controller:
		current_right_pos = right_controller.global_position
		current_right_rot = right_controller.rotation_degrees


func _setup_posture_library() -> void:
	# Ready Stance - Basic neutral position
	var ready := TargetPosture.new()
	ready.name = "Ready Stance"
	ready.description = "Stand with saber at chest height, blade pointing up"
	ready.right_hand_position = Vector3(0.2, 1.2, -0.3)
	ready.right_hand_rotation = Vector3(-45, 0, 0)
	ready.left_hand_position = Vector3(-0.2, 1.0, -0.2)
	ready.hold_duration = 3.0
	posture_library["ready_stance"] = ready

	# High Guard - Saber overhead
	var high_guard := TargetPosture.new()
	high_guard.name = "High Guard"
	high_guard.description = "Raise saber above head, blade pointing forward"
	high_guard.right_hand_position = Vector3(0.1, 1.8, -0.1)
	high_guard.right_hand_rotation = Vector3(0, 0, 0)
	high_guard.left_hand_position = Vector3(-0.1, 1.7, -0.1)
	high_guard.hold_duration = 3.0
	posture_library["high_guard"] = high_guard

	# Low Guard - Defensive low position
	var low_guard := TargetPosture.new()
	low_guard.name = "Low Guard"
	low_guard.description = "Lower saber to hip level, blade pointing forward-down"
	low_guard.right_hand_position = Vector3(0.3, 0.8, -0.2)
	low_guard.right_hand_rotation = Vector3(30, 0, 0)
	low_guard.left_hand_position = Vector3(-0.2, 0.9, -0.1)
	low_guard.hold_duration = 3.0
	posture_library["low_guard"] = low_guard

	# Side Guard Right - Blade to the right
	var side_right := TargetPosture.new()
	side_right.name = "Right Side Guard"
	side_right.description = "Extend saber to your right side"
	side_right.right_hand_position = Vector3(0.7, 1.1, -0.1)
	side_right.right_hand_rotation = Vector3(0, 90, 0)
	side_right.left_hand_position = Vector3(0.0, 1.0, -0.2)
	side_right.hold_duration = 3.0
	posture_library["side_guard_right"] = side_right

	# Side Guard Left - Blade across body to left
	var side_left := TargetPosture.new()
	side_left.name = "Left Side Guard"
	side_left.description = "Bring saber across to your left side"
	side_left.right_hand_position = Vector3(-0.3, 1.1, -0.2)
	side_left.right_hand_rotation = Vector3(0, -90, 0)
	side_left.left_hand_position = Vector3(-0.5, 1.0, -0.1)
	side_left.hold_duration = 3.0
	posture_library["side_guard_left"] = side_left

	# Thrust Position - Lunge forward
	var thrust := TargetPosture.new()
	thrust.name = "Thrust Position"
	thrust.description = "Extend saber forward in a thrusting stance"
	thrust.right_hand_position = Vector3(0.1, 1.1, -0.7)
	thrust.right_hand_rotation = Vector3(0, 0, 0)
	thrust.left_hand_position = Vector3(-0.2, 1.0, -0.3)
	thrust.position_tolerance = 0.12
	thrust.hold_duration = 2.0
	posture_library["thrust"] = thrust

	# T-Pose meditation
	var t_pose := TargetPosture.new()
	t_pose.name = "T-Pose Meditation"
	t_pose.description = "Arms extended to sides, palms down"
	t_pose.right_hand_position = Vector3(0.7, 1.2, 0.0)
	t_pose.right_hand_rotation = Vector3(0, 0, 90)
	t_pose.left_hand_position = Vector3(-0.7, 1.2, 0.0)
	t_pose.left_hand_rotation = Vector3(0, 0, -90)
	t_pose.hold_duration = 5.0
	posture_library["t_pose"] = t_pose

	# Gathering Qi - Hands at center
	var gather := TargetPosture.new()
	gather.name = "Gathering Qi"
	gather.description = "Bring both hands together at chest level"
	gather.right_hand_position = Vector3(0.1, 1.1, -0.25)
	gather.left_hand_position = Vector3(-0.1, 1.1, -0.25)
	gather.position_tolerance = 0.08
	gather.hold_duration = 4.0
	posture_library["gathering_qi"] = gather


## Start tracking a posture
func start_posture_tracking(posture_id: String) -> bool:
	if not posture_library.has(posture_id):
		push_error("Unknown posture: " + posture_id)
		return false

	active_posture = posture_library[posture_id]
	is_tracking_posture = true
	posture_hold_timer = 0.0
	posture_achieved_flag = false

	return true


func start_custom_posture(posture: TargetPosture) -> void:
	active_posture = posture
	is_tracking_posture = true
	posture_hold_timer = 0.0
	posture_achieved_flag = false


func stop_posture_tracking() -> void:
	is_tracking_posture = false
	active_posture = null


func _evaluate_posture(delta: float) -> void:
	if active_posture == null:
		return

	# Get target positions (adjusted for player if using relative)
	var target_right := _get_adjusted_position(active_posture.right_hand_position)
	var target_left := _get_adjusted_position(active_posture.left_hand_position)

	# Calculate deviations
	right_hand_deviation = current_right_pos.distance_to(target_right)
	left_hand_deviation = current_left_pos.distance_to(target_left)

	# Rotation deviation (simplified - just comparing primary axis)
	var rot_dev_right := _rotation_deviation(current_right_rot, active_posture.right_hand_rotation)
	var rot_dev_left := _rotation_deviation(current_left_rot, active_posture.left_hand_rotation)

	# Total deviation (weighted)
	total_deviation = (right_hand_deviation + left_hand_deviation) / 2.0

	# Check if within tolerance
	var position_ok := (right_hand_deviation <= active_posture.position_tolerance and
						left_hand_deviation <= active_posture.position_tolerance)
	var rotation_ok := (rot_dev_right <= active_posture.rotation_tolerance and
						rot_dev_left <= active_posture.rotation_tolerance)

	var in_position := position_ok  # Can add rotation_ok if needed

	if in_position:
		posture_hold_timer += delta

		if posture_hold_timer >= active_posture.hold_duration and not posture_achieved_flag:
			posture_achieved_flag = true
			var accuracy := 1.0 - (total_deviation / active_posture.position_tolerance)
			accuracy = clampf(accuracy, 0.0, 1.0)
			posture_achieved.emit(active_posture.name, accuracy)
			_update_score(accuracy)
	else:
		if posture_achieved_flag:
			posture_lost.emit(active_posture.name)
			posture_achieved_flag = false

		posture_hold_timer = maxf(0.0, posture_hold_timer - delta * 0.5)  # Decay timer

		# Provide guidance
		_provide_guidance(target_right, target_left)

	# Emit deviation signals for UI
	if right_hand_deviation > active_posture.position_tolerance * 0.5:
		var direction := (target_right - current_right_pos).normalized()
		position_deviation.emit("right_hand", right_hand_deviation, direction)

	if left_hand_deviation > active_posture.position_tolerance * 0.5:
		var direction := (target_left - current_left_pos).normalized()
		position_deviation.emit("left_hand", left_hand_deviation, direction)


func _get_adjusted_position(relative_pos: Vector3) -> Vector3:
	if not active_posture.use_relative_positions:
		return relative_pos

	# Adjust based on player position and calibration
	var origin := Vector3.ZERO
	if xr_camera:
		origin = xr_camera.global_position
		origin.y = 0  # Ground level

	# Scale based on calibration if available
	var scale := 1.0
	if calibration:
		scale = calibration.calibration_data.height / 1.7

	return origin + relative_pos * scale


func _rotation_deviation(current: Vector3, target: Vector3) -> float:
	# Simple angular difference
	var diff := current - target
	return maxf(abs(diff.x), maxf(abs(diff.y), abs(diff.z)))


func _provide_guidance(target_right: Vector3, target_left: Vector3) -> void:
	# Haptic guidance - nudge toward correct position
	if guidance_haptic_enabled:
		if right_hand_deviation > guidance_threshold:
			var direction := (target_right - current_right_pos).normalized()
			var intensity := _calculate_guidance_intensity(right_hand_deviation)
			_trigger_guidance_haptic(XRInputManager.Hand.RIGHT, intensity)
			guidance_triggered.emit("right_hand", direction)

		if left_hand_deviation > guidance_threshold:
			var direction := (target_left - current_left_pos).normalized()
			var intensity := _calculate_guidance_intensity(left_hand_deviation)
			_trigger_guidance_haptic(XRInputManager.Hand.LEFT, intensity)
			guidance_triggered.emit("left_hand", direction)


func _calculate_guidance_intensity(deviation: float) -> float:
	if guidance_intensity_curve:
		return guidance_intensity_curve.sample(clampf(deviation, 0.0, 1.0))

	# Default: linear ramp
	return clampf(deviation / 0.5, 0.1, 1.0)


func _trigger_guidance_haptic(hand: XRInputManager.Hand, intensity: float) -> void:
	# Short pulse to indicate direction
	GameEvents.haptic_feedback.emit(hand, null, intensity * 0.3)


func _update_score(accuracy: float) -> void:
	accuracy_history.append(accuracy)
	if accuracy_history.size() > HISTORY_SIZE:
		accuracy_history.pop_front()

	var sum := 0.0
	for a in accuracy_history:
		sum += a
	proprioception_score = sum / accuracy_history.size()

	proprioception_score_updated.emit(proprioception_score)


## Get current deviation info for UI
func get_deviation_info() -> Dictionary:
	return {
		"right_hand": right_hand_deviation,
		"left_hand": left_hand_deviation,
		"total": total_deviation,
		"in_position": posture_achieved_flag,
		"hold_progress": posture_hold_timer / active_posture.hold_duration if active_posture else 0.0
	}


## Get available postures
func get_posture_list() -> Array[String]:
	var list: Array[String] = []
	for key in posture_library:
		list.append(key)
	return list


func get_posture(posture_id: String) -> TargetPosture:
	return posture_library.get(posture_id)


## Get proprioception score
func get_score() -> float:
	return proprioception_score

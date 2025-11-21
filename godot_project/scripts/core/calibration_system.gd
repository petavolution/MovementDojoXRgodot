## CalibrationSystem - Player body measurement and calibration
## Measures height, arm span, and creates personalized play space
class_name CalibrationSystem
extends Node

signal calibration_started
signal calibration_step_changed(step: CalibrationStep, instruction: String)
signal calibration_progress(step: CalibrationStep, progress: float)
signal calibration_completed(data: PlayerCalibration)
signal calibration_cancelled

enum CalibrationStep {
	NONE,
	STAND_STRAIGHT,    # Measure height
	ARMS_OUT,          # Measure arm span (T-pose)
	REACH_UP,          # Measure max reach height
	REACH_DOWN,        # Measure comfortable low reach
	STEP_FORWARD,      # Measure forward reach
	COMPLETED
}

## Calibration data container
class PlayerCalibration:
	var height: float = 1.7          # meters
	var arm_span: float = 1.7        # meters
	var shoulder_height: float = 1.4 # meters
	var max_reach_up: float = 2.1    # meters
	var comfortable_low: float = 0.3 # meters
	var forward_reach: float = 0.7   # meters
	var play_space_radius: float = 1.0  # meters

	func to_dict() -> Dictionary:
		return {
			"height": height,
			"arm_span": arm_span,
			"shoulder_height": shoulder_height,
			"max_reach_up": max_reach_up,
			"comfortable_low": comfortable_low,
			"forward_reach": forward_reach,
			"play_space_radius": play_space_radius
		}

	static func from_dict(data: Dictionary) -> PlayerCalibration:
		var cal := PlayerCalibration.new()
		cal.height = data.get("height", 1.7)
		cal.arm_span = data.get("arm_span", 1.7)
		cal.shoulder_height = data.get("shoulder_height", 1.4)
		cal.max_reach_up = data.get("max_reach_up", 2.1)
		cal.comfortable_low = data.get("comfortable_low", 0.3)
		cal.forward_reach = data.get("forward_reach", 0.7)
		cal.play_space_radius = data.get("play_space_radius", 1.0)
		return cal


var current_step: CalibrationStep = CalibrationStep.NONE
var calibration_data: PlayerCalibration
var is_calibrating: bool = false

# References
var xr_camera: XRCamera3D
var left_controller: XRController3D
var right_controller: XRController3D

# Measurement buffers
var measurement_samples: Array[Vector3] = []
var measurement_duration: float = 2.0
var measurement_timer: float = 0.0
var samples_needed: int = 60  # ~2 seconds at 30fps

# Step instructions
const STEP_INSTRUCTIONS := {
	CalibrationStep.STAND_STRAIGHT: "Stand straight and look forward.\nHold still for measurement.",
	CalibrationStep.ARMS_OUT: "Extend both arms straight out to your sides.\nForm a T-pose and hold.",
	CalibrationStep.REACH_UP: "Reach up with both hands as high as comfortable.\nHold at your maximum reach.",
	CalibrationStep.REACH_DOWN: "Reach down toward the floor comfortably.\nDon't strain - find your comfortable low point.",
	CalibrationStep.STEP_FORWARD: "Reach forward with one hand as far as comfortable.\nKeep your feet planted.",
	CalibrationStep.COMPLETED: "Calibration complete!\nYour play space is now personalized."
}


func _ready() -> void:
	calibration_data = PlayerCalibration.new()


func setup(camera: XRCamera3D, left_ctrl: XRController3D, right_ctrl: XRController3D) -> void:
	xr_camera = camera
	left_controller = left_ctrl
	right_controller = right_ctrl


func start_calibration() -> void:
	if is_calibrating:
		return

	is_calibrating = true
	calibration_data = PlayerCalibration.new()
	calibration_started.emit()
	_advance_to_step(CalibrationStep.STAND_STRAIGHT)


func cancel_calibration() -> void:
	is_calibrating = false
	current_step = CalibrationStep.NONE
	measurement_samples.clear()
	calibration_cancelled.emit()


func skip_calibration_with_defaults() -> void:
	calibration_data = PlayerCalibration.new()
	# Estimate from head height
	if xr_camera:
		var head_height := xr_camera.global_position.y
		calibration_data.height = head_height + 0.1  # Head to top of head
		calibration_data.shoulder_height = head_height - 0.2
		calibration_data.arm_span = calibration_data.height  # Common approximation
		calibration_data.max_reach_up = calibration_data.height + 0.4
		calibration_data.comfortable_low = 0.3
		calibration_data.forward_reach = 0.6
		calibration_data.play_space_radius = calibration_data.arm_span / 2.0

	is_calibrating = false
	calibration_completed.emit(calibration_data)


func _process(delta: float) -> void:
	if not is_calibrating or current_step == CalibrationStep.NONE:
		return

	if current_step == CalibrationStep.COMPLETED:
		return

	_collect_measurement_sample()
	measurement_timer += delta

	var progress := measurement_timer / measurement_duration
	calibration_progress.emit(current_step, clampf(progress, 0.0, 1.0))

	if measurement_samples.size() >= samples_needed:
		_process_measurement()


func _collect_measurement_sample() -> void:
	match current_step:
		CalibrationStep.STAND_STRAIGHT:
			if xr_camera:
				measurement_samples.append(xr_camera.global_position)

		CalibrationStep.ARMS_OUT:
			if left_controller and right_controller:
				var left_pos := left_controller.global_position
				var right_pos := right_controller.global_position
				var span_vec := right_pos - left_pos
				measurement_samples.append(Vector3(span_vec.length(), left_pos.y, right_pos.y))

		CalibrationStep.REACH_UP:
			if left_controller and right_controller:
				var max_y := maxf(left_controller.global_position.y, right_controller.global_position.y)
				measurement_samples.append(Vector3(0, max_y, 0))

		CalibrationStep.REACH_DOWN:
			if left_controller and right_controller:
				var min_y := minf(left_controller.global_position.y, right_controller.global_position.y)
				measurement_samples.append(Vector3(0, min_y, 0))

		CalibrationStep.STEP_FORWARD:
			if left_controller and right_controller and xr_camera:
				var head_pos := xr_camera.global_position
				var left_dist := Vector2(left_controller.global_position.x - head_pos.x,
										  left_controller.global_position.z - head_pos.z).length()
				var right_dist := Vector2(right_controller.global_position.x - head_pos.x,
										   right_controller.global_position.z - head_pos.z).length()
				measurement_samples.append(Vector3(maxf(left_dist, right_dist), 0, 0))


func _process_measurement() -> void:
	if measurement_samples.is_empty():
		_advance_to_next_step()
		return

	match current_step:
		CalibrationStep.STAND_STRAIGHT:
			var avg_height := _calculate_average_y()
			calibration_data.height = avg_height + 0.1  # Add a bit for top of head
			calibration_data.shoulder_height = avg_height - 0.2

		CalibrationStep.ARMS_OUT:
			var avg_span := _calculate_average_x()
			calibration_data.arm_span = avg_span + 0.15  # Add hand width estimate
			calibration_data.play_space_radius = calibration_data.arm_span / 2.0

		CalibrationStep.REACH_UP:
			calibration_data.max_reach_up = _calculate_average_y()

		CalibrationStep.REACH_DOWN:
			calibration_data.comfortable_low = _calculate_average_y()

		CalibrationStep.STEP_FORWARD:
			calibration_data.forward_reach = _calculate_average_x()

	_advance_to_next_step()


func _calculate_average_y() -> float:
	if measurement_samples.is_empty():
		return 0.0
	var sum := 0.0
	for sample in measurement_samples:
		sum += sample.y
	return sum / measurement_samples.size()


func _calculate_average_x() -> float:
	if measurement_samples.is_empty():
		return 0.0
	var sum := 0.0
	for sample in measurement_samples:
		sum += sample.x
	return sum / measurement_samples.size()


func _advance_to_next_step() -> void:
	var next_step: CalibrationStep
	match current_step:
		CalibrationStep.STAND_STRAIGHT:
			next_step = CalibrationStep.ARMS_OUT
		CalibrationStep.ARMS_OUT:
			next_step = CalibrationStep.REACH_UP
		CalibrationStep.REACH_UP:
			next_step = CalibrationStep.REACH_DOWN
		CalibrationStep.REACH_DOWN:
			next_step = CalibrationStep.STEP_FORWARD
		CalibrationStep.STEP_FORWARD:
			next_step = CalibrationStep.COMPLETED
		_:
			next_step = CalibrationStep.COMPLETED

	_advance_to_step(next_step)


func _advance_to_step(step: CalibrationStep) -> void:
	current_step = step
	measurement_samples.clear()
	measurement_timer = 0.0

	var instruction := STEP_INSTRUCTIONS.get(step, "")
	calibration_step_changed.emit(step, instruction)

	if step == CalibrationStep.COMPLETED:
		is_calibrating = false
		calibration_completed.emit(calibration_data)


func get_calibration() -> PlayerCalibration:
	return calibration_data


func set_calibration(data: PlayerCalibration) -> void:
	calibration_data = data


## Get normalized position within player's calibrated space
func get_normalized_position(world_pos: Vector3) -> Vector3:
	if xr_camera == null:
		return world_pos

	var origin := xr_camera.global_position
	origin.y = 0  # Floor level

	var relative := world_pos - origin

	# Normalize to player's reach
	return Vector3(
		relative.x / calibration_data.play_space_radius,
		(relative.y - calibration_data.comfortable_low) / (calibration_data.max_reach_up - calibration_data.comfortable_low),
		relative.z / calibration_data.forward_reach
	)


## Check if a position is within comfortable reach
func is_within_comfortable_reach(world_pos: Vector3) -> bool:
	if xr_camera == null:
		return true

	var head_pos := xr_camera.global_position
	var horizontal_dist := Vector2(world_pos.x - head_pos.x, world_pos.z - head_pos.z).length()

	return (horizontal_dist <= calibration_data.play_space_radius and
			world_pos.y >= calibration_data.comfortable_low and
			world_pos.y <= calibration_data.max_reach_up)


## Get difficulty-adjusted target position
func get_adjusted_target_position(base_pos: Vector3, difficulty: float) -> Vector3:
	# difficulty 0.0 = easy (close to center), 1.0 = hard (edges of reach)
	var normalized := get_normalized_position(base_pos)

	# Scale position based on difficulty
	var scale := 0.5 + 0.5 * difficulty
	normalized *= scale

	# Convert back to world position
	if xr_camera == null:
		return base_pos

	var origin := xr_camera.global_position
	origin.y = 0

	return origin + Vector3(
		normalized.x * calibration_data.play_space_radius,
		calibration_data.comfortable_low + normalized.y * (calibration_data.max_reach_up - calibration_data.comfortable_low),
		normalized.z * calibration_data.forward_reach
	)

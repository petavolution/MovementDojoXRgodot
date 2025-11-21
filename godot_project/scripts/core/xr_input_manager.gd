## XRInputManager - Centralized VR input handling
## Supports controllers and hand tracking with gesture recognition
class_name XRInputManager
extends Node

signal trigger_pressed(hand: Hand)
signal trigger_released(hand: Hand)
signal grip_pressed(hand: Hand)
signal grip_released(hand: Hand)
signal button_pressed(hand: Hand, button: String)
signal button_released(hand: Hand, button: String)
signal thumbstick_moved(hand: Hand, position: Vector2)
signal gesture_detected(hand: Hand, gesture: Gesture)
signal hand_tracking_started
signal hand_tracking_lost

enum Hand { LEFT, RIGHT }
enum Gesture { NONE, FIST, OPEN_PALM, POINT, THUMBS_UP, PEACE, GRAB, PINCH }

## Controller references
var left_controller: XRController3D
var right_controller: XRController3D

## Hand tracking nodes (for Quest native)
var left_hand_tracker: XRNode3D
var right_hand_tracker: XRNode3D

## Input state
var left_trigger_value: float = 0.0
var right_trigger_value: float = 0.0
var left_grip_value: float = 0.0
var right_grip_value: float = 0.0
var left_thumbstick: Vector2 = Vector2.ZERO
var right_thumbstick: Vector2 = Vector2.ZERO

## Button states
var left_buttons: Dictionary = {}
var right_buttons: Dictionary = {}

## Hand tracking state
var hand_tracking_active: bool = false
var left_hand_joints: Array[Transform3D] = []
var right_hand_joints: Array[Transform3D] = []

## Gesture detection
var left_gesture: Gesture = Gesture.NONE
var right_gesture: Gesture = Gesture.NONE
var gesture_confidence_threshold: float = 0.7

## Thresholds
const TRIGGER_THRESHOLD := 0.7
const GRIP_THRESHOLD := 0.7
const THUMBSTICK_DEADZONE := 0.15

## Hand joint indices (OpenXR standard)
enum HandJoint {
	PALM = 0,
	WRIST = 1,
	THUMB_METACARPAL = 2,
	THUMB_PROXIMAL = 3,
	THUMB_DISTAL = 4,
	THUMB_TIP = 5,
	INDEX_METACARPAL = 6,
	INDEX_PROXIMAL = 7,
	INDEX_INTERMEDIATE = 8,
	INDEX_DISTAL = 9,
	INDEX_TIP = 10,
	MIDDLE_METACARPAL = 11,
	MIDDLE_PROXIMAL = 12,
	MIDDLE_INTERMEDIATE = 13,
	MIDDLE_DISTAL = 14,
	MIDDLE_TIP = 15,
	RING_METACARPAL = 16,
	RING_PROXIMAL = 17,
	RING_INTERMEDIATE = 18,
	RING_DISTAL = 19,
	RING_TIP = 20,
	LITTLE_METACARPAL = 21,
	LITTLE_PROXIMAL = 22,
	LITTLE_INTERMEDIATE = 23,
	LITTLE_DISTAL = 24,
	LITTLE_TIP = 25
}


func _ready() -> void:
	# Initialize button states
	for button in ["ax_button", "by_button", "menu_button", "thumbstick_click"]:
		left_buttons[button] = false
		right_buttons[button] = false

	# Initialize hand joint arrays
	left_hand_joints.resize(26)
	right_hand_joints.resize(26)


func setup(left_ctrl: XRController3D, right_ctrl: XRController3D) -> void:
	left_controller = left_ctrl
	right_controller = right_ctrl

	# Connect controller signals
	if left_controller:
		left_controller.button_pressed.connect(_on_left_button_pressed)
		left_controller.button_released.connect(_on_left_button_released)
		left_controller.input_float_changed.connect(_on_left_float_changed)
		left_controller.input_vector2_changed.connect(_on_left_vector2_changed)

	if right_controller:
		right_controller.button_pressed.connect(_on_right_button_pressed)
		right_controller.button_released.connect(_on_right_button_released)
		right_controller.input_float_changed.connect(_on_right_float_changed)
		right_controller.input_vector2_changed.connect(_on_right_vector2_changed)


func setup_hand_tracking(left_tracker: XRNode3D, right_tracker: XRNode3D) -> void:
	left_hand_tracker = left_tracker
	right_hand_tracker = right_tracker
	hand_tracking_active = true
	hand_tracking_started.emit()


func _process(_delta: float) -> void:
	if hand_tracking_active:
		_update_hand_tracking()
		_detect_gestures()


func _update_hand_tracking() -> void:
	# Update hand joint data from XR interface
	var xr_interface := XRServer.primary_interface
	if xr_interface == null:
		return

	# Hand tracking data would come from XRHandTracker in Godot 4.3+
	# This is a placeholder for the tracking update
	pass


func _detect_gestures() -> void:
	if left_hand_joints.size() >= 26:
		var new_gesture := _analyze_hand_pose(left_hand_joints)
		if new_gesture != left_gesture:
			left_gesture = new_gesture
			if new_gesture != Gesture.NONE:
				gesture_detected.emit(Hand.LEFT, new_gesture)

	if right_hand_joints.size() >= 26:
		var new_gesture := _analyze_hand_pose(right_hand_joints)
		if new_gesture != right_gesture:
			right_gesture = new_gesture
			if new_gesture != Gesture.NONE:
				gesture_detected.emit(Hand.RIGHT, new_gesture)


func _analyze_hand_pose(joints: Array[Transform3D]) -> Gesture:
	if joints.size() < 26:
		return Gesture.NONE

	var palm_pos := joints[HandJoint.PALM].origin
	var wrist_pos := joints[HandJoint.WRIST].origin

	# Get fingertip positions
	var thumb_tip := joints[HandJoint.THUMB_TIP].origin
	var index_tip := joints[HandJoint.INDEX_TIP].origin
	var middle_tip := joints[HandJoint.MIDDLE_TIP].origin
	var ring_tip := joints[HandJoint.RING_TIP].origin
	var little_tip := joints[HandJoint.LITTLE_TIP].origin

	# Get finger base positions (proximal joints)
	var index_base := joints[HandJoint.INDEX_PROXIMAL].origin
	var middle_base := joints[HandJoint.MIDDLE_PROXIMAL].origin
	var ring_base := joints[HandJoint.RING_PROXIMAL].origin
	var little_base := joints[HandJoint.LITTLE_PROXIMAL].origin

	# Calculate finger curl (distance from tip to base)
	var index_curl := index_tip.distance_to(index_base)
	var middle_curl := middle_tip.distance_to(middle_base)
	var ring_curl := ring_tip.distance_to(ring_base)
	var little_curl := little_tip.distance_to(little_base)

	# Thresholds (in meters, approximate)
	var extended_threshold := 0.08
	var curled_threshold := 0.04

	var index_extended := index_curl > extended_threshold
	var middle_extended := middle_curl > extended_threshold
	var ring_extended := ring_curl > extended_threshold
	var little_extended := little_curl > extended_threshold

	var index_curled := index_curl < curled_threshold
	var middle_curled := middle_curl < curled_threshold
	var ring_curled := ring_curl < curled_threshold
	var little_curled := little_curl < curled_threshold

	# Pinch detection (thumb tip close to index tip)
	var pinch_distance := thumb_tip.distance_to(index_tip)
	if pinch_distance < 0.03:
		return Gesture.PINCH

	# Fist (all fingers curled)
	if index_curled and middle_curled and ring_curled and little_curled:
		return Gesture.FIST

	# Open palm (all fingers extended)
	if index_extended and middle_extended and ring_extended and little_extended:
		return Gesture.OPEN_PALM

	# Point (only index extended)
	if index_extended and middle_curled and ring_curled and little_curled:
		return Gesture.POINT

	# Peace sign (index and middle extended)
	if index_extended and middle_extended and ring_curled and little_curled:
		return Gesture.PEACE

	# Thumbs up (thumb extended, others curled, hand orientation check needed)
	# Simplified: just check thumb is far from palm while fingers curled
	var thumb_extended := thumb_tip.distance_to(palm_pos) > 0.1
	if thumb_extended and index_curled and middle_curled and ring_curled and little_curled:
		return Gesture.THUMBS_UP

	# Grab (partial curl, like holding something)
	var partial_curl := not index_extended and not index_curled
	if partial_curl:
		return Gesture.GRAB

	return Gesture.NONE


## Controller input callbacks
func _on_left_button_pressed(button: String) -> void:
	left_buttons[button] = true
	button_pressed.emit(Hand.LEFT, button)


func _on_left_button_released(button: String) -> void:
	left_buttons[button] = false
	button_released.emit(Hand.LEFT, button)


func _on_right_button_pressed(button: String) -> void:
	right_buttons[button] = true
	button_pressed.emit(Hand.RIGHT, button)


func _on_right_button_released(button: String) -> void:
	right_buttons[button] = false
	button_released.emit(Hand.RIGHT, button)


func _on_left_float_changed(name: String, value: float) -> void:
	match name:
		"trigger":
			var was_pressed := left_trigger_value >= TRIGGER_THRESHOLD
			left_trigger_value = value
			var is_pressed := value >= TRIGGER_THRESHOLD
			if is_pressed and not was_pressed:
				trigger_pressed.emit(Hand.LEFT)
			elif not is_pressed and was_pressed:
				trigger_released.emit(Hand.LEFT)
		"grip":
			var was_pressed := left_grip_value >= GRIP_THRESHOLD
			left_grip_value = value
			var is_pressed := value >= GRIP_THRESHOLD
			if is_pressed and not was_pressed:
				grip_pressed.emit(Hand.LEFT)
			elif not is_pressed and was_pressed:
				grip_released.emit(Hand.LEFT)


func _on_right_float_changed(name: String, value: float) -> void:
	match name:
		"trigger":
			var was_pressed := right_trigger_value >= TRIGGER_THRESHOLD
			right_trigger_value = value
			var is_pressed := value >= TRIGGER_THRESHOLD
			if is_pressed and not was_pressed:
				trigger_pressed.emit(Hand.RIGHT)
			elif not is_pressed and was_pressed:
				trigger_released.emit(Hand.RIGHT)
		"grip":
			var was_pressed := right_grip_value >= GRIP_THRESHOLD
			right_grip_value = value
			var is_pressed := value >= GRIP_THRESHOLD
			if is_pressed and not was_pressed:
				grip_pressed.emit(Hand.RIGHT)
			elif not is_pressed and was_pressed:
				grip_released.emit(Hand.RIGHT)


func _on_left_vector2_changed(name: String, value: Vector2) -> void:
	if name == "primary":
		if value.length() > THUMBSTICK_DEADZONE:
			left_thumbstick = value
			thumbstick_moved.emit(Hand.LEFT, value)
		else:
			left_thumbstick = Vector2.ZERO


func _on_right_vector2_changed(name: String, value: Vector2) -> void:
	if name == "primary":
		if value.length() > THUMBSTICK_DEADZONE:
			right_thumbstick = value
			thumbstick_moved.emit(Hand.RIGHT, value)
		else:
			right_thumbstick = Vector2.ZERO


## Utility functions
func get_controller(hand: Hand) -> XRController3D:
	return left_controller if hand == Hand.LEFT else right_controller


func get_trigger_value(hand: Hand) -> float:
	return left_trigger_value if hand == Hand.LEFT else right_trigger_value


func get_grip_value(hand: Hand) -> float:
	return left_grip_value if hand == Hand.LEFT else right_grip_value


func get_thumbstick(hand: Hand) -> Vector2:
	return left_thumbstick if hand == Hand.LEFT else right_thumbstick


func is_trigger_pressed(hand: Hand) -> bool:
	var value := left_trigger_value if hand == Hand.LEFT else right_trigger_value
	return value >= TRIGGER_THRESHOLD


func is_grip_pressed(hand: Hand) -> bool:
	var value := left_grip_value if hand == Hand.LEFT else right_grip_value
	return value >= GRIP_THRESHOLD


func is_button_pressed(hand: Hand, button: String) -> bool:
	var buttons := left_buttons if hand == Hand.LEFT else right_buttons
	return buttons.get(button, false)


func get_gesture(hand: Hand) -> Gesture:
	return left_gesture if hand == Hand.LEFT else right_gesture


func trigger_haptic(hand: Hand, frequency: float, amplitude: float, duration: float) -> void:
	var controller := get_controller(hand)
	if controller:
		controller.trigger_haptic_pulse("haptic", frequency, amplitude, duration, 0.0)


func trigger_haptic_pattern(hand: Hand, pattern: HapticPatterns.Pattern, intensity: float = 1.0) -> void:
	var controller := get_controller(hand)
	if controller:
		HapticPatterns.play(controller, pattern, intensity)

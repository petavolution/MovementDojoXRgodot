## MovementFrame - Single frame of movement tracking data
## Captures all tracking data for one physics tick
class_name MovementFrame
extends RefCounted

# Timestamp
var timestamp: float = 0.0
var frame_delta: float = 0.0

# Head tracking
var head_position: Vector3 = Vector3.ZERO
var head_rotation: Quaternion = Quaternion.IDENTITY
var head_velocity: Vector3 = Vector3.ZERO
var head_angular_velocity: Vector3 = Vector3.ZERO

# Left hand tracking
var left_position: Vector3 = Vector3.ZERO
var left_rotation: Quaternion = Quaternion.IDENTITY
var left_velocity: Vector3 = Vector3.ZERO
var left_angular_velocity: Vector3 = Vector3.ZERO
var left_grip: float = 0.0
var left_trigger: float = 0.0

# Right hand tracking
var right_position: Vector3 = Vector3.ZERO
var right_rotation: Quaternion = Quaternion.IDENTITY
var right_velocity: Vector3 = Vector3.ZERO
var right_angular_velocity: Vector3 = Vector3.ZERO
var right_grip: float = 0.0
var right_trigger: float = 0.0

# Derived metrics (computed after capture)
var left_reach_distance: float = 0.0  # Distance from body center
var right_reach_distance: float = 0.0
var left_height_relative: float = 0.0  # Height relative to head
var right_height_relative: float = 0.0
var movement_intensity: float = 0.0  # Combined velocity magnitude


static func create(
	time: float,
	delta: float,
	head_pos: Vector3,
	head_rot: Quaternion,
	left_pos: Vector3,
	left_rot: Quaternion,
	right_pos: Vector3,
	right_rot: Quaternion
) -> MovementFrame:
	var frame := MovementFrame.new()
	frame.timestamp = time
	frame.frame_delta = delta
	frame.head_position = head_pos
	frame.head_rotation = head_rot
	frame.left_position = left_pos
	frame.left_rotation = left_rot
	frame.right_position = right_pos
	frame.right_rotation = right_rot
	return frame


func compute_velocities(previous_frame: MovementFrame) -> void:
	if previous_frame == null or frame_delta <= 0:
		return

	var inv_delta := 1.0 / frame_delta

	# Linear velocities
	head_velocity = (head_position - previous_frame.head_position) * inv_delta
	left_velocity = (left_position - previous_frame.left_position) * inv_delta
	right_velocity = (right_position - previous_frame.right_position) * inv_delta

	# Angular velocities (simplified - quaternion derivative)
	var head_rot_diff := head_rotation * previous_frame.head_rotation.inverse()
	head_angular_velocity = _quaternion_to_angular_velocity(head_rot_diff, frame_delta)

	var left_rot_diff := left_rotation * previous_frame.left_rotation.inverse()
	left_angular_velocity = _quaternion_to_angular_velocity(left_rot_diff, frame_delta)

	var right_rot_diff := right_rotation * previous_frame.right_rotation.inverse()
	right_angular_velocity = _quaternion_to_angular_velocity(right_rot_diff, frame_delta)


func compute_derived_metrics() -> void:
	# Body center estimate (between hands, below head)
	var body_center := head_position - Vector3(0, 0.4, 0)  # Approximate shoulder height

	# Reach distances (horizontal plane primarily)
	var left_horizontal := Vector3(left_position.x, 0, left_position.z) - Vector3(body_center.x, 0, body_center.z)
	var right_horizontal := Vector3(right_position.x, 0, right_position.z) - Vector3(body_center.x, 0, body_center.z)

	left_reach_distance = left_horizontal.length() + abs(left_position.y - body_center.y) * 0.5
	right_reach_distance = right_horizontal.length() + abs(right_position.y - body_center.y) * 0.5

	# Height relative to head
	left_height_relative = left_position.y - head_position.y
	right_height_relative = right_position.y - head_position.y

	# Movement intensity
	movement_intensity = (left_velocity.length() + right_velocity.length() + head_velocity.length()) / 3.0


func _quaternion_to_angular_velocity(q: Quaternion, dt: float) -> Vector3:
	if dt <= 0:
		return Vector3.ZERO
	# Convert quaternion difference to axis-angle, then to angular velocity
	var axis := Vector3.ZERO
	var angle := 0.0

	# Ensure quaternion is normalized
	q = q.normalized()

	# Handle near-identity quaternion
	if abs(q.w) > 0.9999:
		return Vector3.ZERO

	angle = 2.0 * acos(clamp(q.w, -1.0, 1.0))
	var s := sqrt(1.0 - q.w * q.w)

	if s < 0.001:
		axis = Vector3(q.x, q.y, q.z)
	else:
		axis = Vector3(q.x / s, q.y / s, q.z / s)

	return axis * (angle / dt)


func to_dict() -> Dictionary:
	return {
		"t": timestamp,
		"dt": frame_delta,
		"head": {
			"p": [head_position.x, head_position.y, head_position.z],
			"r": [head_rotation.x, head_rotation.y, head_rotation.z, head_rotation.w],
			"v": [head_velocity.x, head_velocity.y, head_velocity.z]
		},
		"left": {
			"p": [left_position.x, left_position.y, left_position.z],
			"r": [left_rotation.x, left_rotation.y, left_rotation.z, left_rotation.w],
			"v": [left_velocity.x, left_velocity.y, left_velocity.z],
			"grip": left_grip,
			"trigger": left_trigger
		},
		"right": {
			"p": [right_position.x, right_position.y, right_position.z],
			"r": [right_rotation.x, right_rotation.y, right_rotation.z, right_rotation.w],
			"v": [right_velocity.x, right_velocity.y, right_velocity.z],
			"grip": right_grip,
			"trigger": right_trigger
		}
	}


static func from_dict(data: Dictionary) -> MovementFrame:
	var frame := MovementFrame.new()
	frame.timestamp = data.get("t", 0.0)
	frame.frame_delta = data.get("dt", 0.0)

	if data.has("head"):
		var h: Dictionary = data["head"]
		var hp: Array = h.get("p", [0, 0, 0])
		var hr: Array = h.get("r", [0, 0, 0, 1])
		frame.head_position = Vector3(hp[0], hp[1], hp[2])
		frame.head_rotation = Quaternion(hr[0], hr[1], hr[2], hr[3])
		if h.has("v"):
			var hv: Array = h["v"]
			frame.head_velocity = Vector3(hv[0], hv[1], hv[2])

	if data.has("left"):
		var l: Dictionary = data["left"]
		var lp: Array = l.get("p", [0, 0, 0])
		var lr: Array = l.get("r", [0, 0, 0, 1])
		frame.left_position = Vector3(lp[0], lp[1], lp[2])
		frame.left_rotation = Quaternion(lr[0], lr[1], lr[2], lr[3])
		if l.has("v"):
			var lv: Array = l["v"]
			frame.left_velocity = Vector3(lv[0], lv[1], lv[2])
		frame.left_grip = l.get("grip", 0.0)
		frame.left_trigger = l.get("trigger", 0.0)

	if data.has("right"):
		var r: Dictionary = data["right"]
		var rp: Array = r.get("p", [0, 0, 0])
		var rr: Array = r.get("r", [0, 0, 0, 1])
		frame.right_position = Vector3(rp[0], rp[1], rp[2])
		frame.right_rotation = Quaternion(rr[0], rr[1], rr[2], rr[3])
		if r.has("v"):
			var rv: Array = r["v"]
			frame.right_velocity = Vector3(rv[0], rv[1], rv[2])
		frame.right_grip = r.get("grip", 0.0)
		frame.right_trigger = r.get("trigger", 0.0)

	return frame

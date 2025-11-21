## MovementAnalytics - Pattern analysis and movement classification
## Autoloaded as "MovementAnalytics"
extends Node

# Movement type classification
enum MovementType {
	IDLE,
	HORIZONTAL_SWEEP,    # Side-to-side
	VERTICAL_SWEEP,      # Up-down
	THRUST,              # Forward push
	PULL,                # Backward pull
	CIRCULAR,            # Rotational
	DIAGONAL,            # Multi-axis
	OVERHEAD_REACH,      # Above head
	BEHIND_REACH,        # Behind body
	LOW_REACH,           # Below waist
	CROSS_BODY,          # Reaching across midline
}

# Pose detection thresholds
const POSE_HOLD_TIME := 0.5  # Seconds to hold for pose detection
const VELOCITY_IDLE_THRESHOLD := 0.1  # m/s
const VELOCITY_SLOW_THRESHOLD := 0.5
const VELOCITY_FAST_THRESHOLD := 2.0

# Analysis state
var current_session_stats := SessionStats.new()
var movement_type_history: Array[MovementType] = []
var pose_detector: PoseDetector
var analysis_interval := 0.1  # Analyze every 100ms
var _analysis_timer := 0.0

# Frame window for analysis
const ANALYSIS_WINDOW := 30  # Frames to analyze (about 0.33s at 90Hz)


func _ready() -> void:
	pose_detector = PoseDetector.new()
	GameEvents.movement_frame_recorded.connect(_on_movement_frame)
	GameEvents.session_started.connect(_on_session_started)
	GameEvents.session_ended.connect(_on_session_ended)


func _process(delta: float) -> void:
	_analysis_timer += delta
	if _analysis_timer >= analysis_interval:
		_analysis_timer = 0.0
		_perform_analysis()


func _on_session_started(_session_id: String) -> void:
	current_session_stats = SessionStats.new()
	movement_type_history.clear()


func _on_session_ended(_session_id: String, _summary: Dictionary) -> void:
	pass  # Stats already captured


func _on_movement_frame(frame: MovementFrame) -> void:
	# Update running statistics
	current_session_stats.total_frames += 1
	current_session_stats.session_duration = frame.timestamp

	# Track distance traveled
	if current_session_stats.total_frames > 1:
		current_session_stats.left_distance_traveled += frame.left_velocity.length() * frame.frame_delta
		current_session_stats.right_distance_traveled += frame.right_velocity.length() * frame.frame_delta
		current_session_stats.head_distance_traveled += frame.head_velocity.length() * frame.frame_delta

	# Track peak velocities
	var left_speed := frame.left_velocity.length()
	var right_speed := frame.right_velocity.length()
	if left_speed > current_session_stats.peak_left_velocity:
		current_session_stats.peak_left_velocity = left_speed
	if right_speed > current_session_stats.peak_right_velocity:
		current_session_stats.peak_right_velocity = right_speed


func _perform_analysis() -> void:
	var frames := MovementTracker.get_recent_frames(ANALYSIS_WINDOW)
	if frames.size() < 10:
		return

	# Classify current movement
	var left_type := _classify_movement(frames, "left")
	var right_type := _classify_movement(frames, "right")

	# Record movement types
	_record_movement_type(left_type)
	_record_movement_type(right_type)

	# Update movement type duration
	var dominant_type := left_type if _get_movement_intensity(frames, "left") > _get_movement_intensity(frames, "right") else right_type
	current_session_stats.add_movement_type_time(dominant_type, analysis_interval)

	# Check for poses
	var detected_poses := pose_detector.detect_poses(frames)
	for pose in detected_poses:
		if pose not in current_session_stats.poses_detected:
			current_session_stats.poses_detected.append(pose)
			GameEvents.pose_detected.emit(pose, 1.0)

	# Update coverage stats
	var space_map := MovementTracker.get_space_map()
	current_session_stats.movement_coverage = space_map.get_coverage_percentage()
	current_session_stats.symmetry_score = space_map.get_symmetry_score()
	current_session_stats.directional_coverage = space_map.get_directional_coverage()

	# Emit analytics update
	GameEvents.analytics_updated.emit(get_current_stats())
	GameEvents.symmetry_updated.emit(current_session_stats.symmetry_score)


func _classify_movement(frames: Array[MovementFrame], hand: String) -> MovementType:
	if frames.size() < 2:
		return MovementType.IDLE

	# Get velocity data
	var velocities: Array[Vector3] = []
	var positions: Array[Vector3] = []

	for frame in frames:
		if hand == "left":
			velocities.append(frame.left_velocity)
			positions.append(frame.left_position - frame.head_position)
		else:
			velocities.append(frame.right_velocity)
			positions.append(frame.right_position - frame.head_position)

	# Calculate average velocity magnitude
	var avg_speed := 0.0
	for v in velocities:
		avg_speed += v.length()
	avg_speed /= velocities.size()

	# Check for idle
	if avg_speed < VELOCITY_IDLE_THRESHOLD:
		return MovementType.IDLE

	# Analyze movement direction
	var avg_velocity := Vector3.ZERO
	for v in velocities:
		avg_velocity += v
	avg_velocity /= velocities.size()

	var avg_position := Vector3.ZERO
	for p in positions:
		avg_position += p
	avg_position /= positions.size()

	# Check for position-based classifications
	if avg_position.y > 0.3:  # Above shoulder height
		return MovementType.OVERHEAD_REACH
	if avg_position.y < -0.4:  # Below waist
		return MovementType.LOW_REACH
	if avg_position.z < -0.3:  # Behind body
		return MovementType.BEHIND_REACH

	# Check for cross-body
	var is_left := hand == "left"
	if (is_left and avg_position.x > 0.2) or (not is_left and avg_position.x < -0.2):
		return MovementType.CROSS_BODY

	# Analyze velocity direction
	var horizontal := Vector2(avg_velocity.x, avg_velocity.z)
	var vertical := avg_velocity.y

	# Check for circular motion (high angular velocity)
	var avg_angular := Vector3.ZERO
	for frame in frames:
		if hand == "left":
			avg_angular += frame.left_angular_velocity
		else:
			avg_angular += frame.right_angular_velocity
	avg_angular /= frames.size()

	if avg_angular.length() > 2.0:  # Significant rotation
		return MovementType.CIRCULAR

	# Directional classification
	var abs_horizontal := horizontal.length()
	var abs_vertical := abs(vertical)
	var abs_forward := abs(avg_velocity.z)

	if abs_vertical > abs_horizontal and abs_vertical > abs_forward:
		return MovementType.VERTICAL_SWEEP
	if abs_horizontal > abs_vertical and horizontal.length() > abs_forward:
		return MovementType.HORIZONTAL_SWEEP
	if avg_velocity.z > 0.5:
		return MovementType.THRUST
	if avg_velocity.z < -0.5:
		return MovementType.PULL

	return MovementType.DIAGONAL


func _get_movement_intensity(frames: Array[MovementFrame], hand: String) -> float:
	var total_speed := 0.0
	for frame in frames:
		if hand == "left":
			total_speed += frame.left_velocity.length()
		else:
			total_speed += frame.right_velocity.length()
	return total_speed / frames.size()


func _record_movement_type(type: MovementType) -> void:
	movement_type_history.append(type)
	# Keep history manageable
	if movement_type_history.size() > 1000:
		movement_type_history = movement_type_history.slice(500)


func get_current_stats() -> Dictionary:
	return current_session_stats.to_dict()


func get_movement_type_name(type: MovementType) -> String:
	match type:
		MovementType.IDLE: return "Idle"
		MovementType.HORIZONTAL_SWEEP: return "Horizontal Sweep"
		MovementType.VERTICAL_SWEEP: return "Vertical Sweep"
		MovementType.THRUST: return "Thrust"
		MovementType.PULL: return "Pull"
		MovementType.CIRCULAR: return "Circular"
		MovementType.DIAGONAL: return "Diagonal"
		MovementType.OVERHEAD_REACH: return "Overhead Reach"
		MovementType.BEHIND_REACH: return "Behind Reach"
		MovementType.LOW_REACH: return "Low Reach"
		MovementType.CROSS_BODY: return "Cross Body"
		_: return "Unknown"


## SessionStats - Container for session statistics
class SessionStats:
	var session_duration := 0.0
	var total_frames := 0

	# Distance tracking
	var left_distance_traveled := 0.0
	var right_distance_traveled := 0.0
	var head_distance_traveled := 0.0

	# Velocity tracking
	var peak_left_velocity := 0.0
	var peak_right_velocity := 0.0

	# Coverage
	var movement_coverage := 0.0
	var symmetry_score := 100.0
	var directional_coverage := {}

	# Movement types (seconds spent in each)
	var movement_type_times := {}

	# Poses
	var poses_detected: Array[String] = []

	# Achievements
	var achievements_earned: Array[String] = []


	func add_movement_type_time(type: MovementType, duration: float) -> void:
		var type_name := MovementAnalytics.get_movement_type_name(MovementAnalytics, type)
		if not movement_type_times.has(type_name):
			movement_type_times[type_name] = 0.0
		movement_type_times[type_name] += duration


	func to_dict() -> Dictionary:
		return {
			"duration": session_duration,
			"frames": total_frames,
			"distance": {
				"left": left_distance_traveled,
				"right": right_distance_traveled,
				"head": head_distance_traveled,
				"total": left_distance_traveled + right_distance_traveled
			},
			"peak_velocity": {
				"left": peak_left_velocity,
				"right": peak_right_velocity
			},
			"coverage": movement_coverage,
			"symmetry": symmetry_score,
			"directional_coverage": directional_coverage,
			"movement_types": movement_type_times,
			"poses": poses_detected,
			"achievements": achievements_earned
		}


## PoseDetector - Detects yoga/qi gong poses from movement data
class PoseDetector:
	var pose_hold_timers := {}

	func detect_poses(frames: Array[MovementFrame]) -> Array[String]:
		var detected: Array[String] = []

		if frames.is_empty():
			return detected

		var latest := frames[-1]

		# T-Pose detection (arms extended horizontally)
		if _check_t_pose(latest):
			detected.append("T-Pose")

		# Arms raised (both hands above head)
		if _check_arms_raised(latest):
			detected.append("Arms Raised")

		# Warrior stance (wide, low stance with one arm forward)
		if _check_warrior_stance(frames):
			detected.append("Warrior Stance")

		# Gathering pose (hands low, coming together)
		if _check_gathering_pose(latest):
			detected.append("Gathering Qi")

		# Meditation pose (hands together at chest height, still)
		if _check_meditation_pose(frames):
			detected.append("Meditation")

		return detected


	func _check_t_pose(frame: MovementFrame) -> bool:
		var left_rel := frame.left_position - frame.head_position
		var right_rel := frame.right_position - frame.head_position

		# Arms should be at roughly shoulder height
		var left_height_ok := abs(left_rel.y + 0.2) < 0.15  # Slightly below head
		var right_height_ok := abs(right_rel.y + 0.2) < 0.15

		# Arms should be extended outward
		var left_extended := left_rel.x < -0.5
		var right_extended := right_rel.x > 0.5

		return left_height_ok and right_height_ok and left_extended and right_extended


	func _check_arms_raised(frame: MovementFrame) -> bool:
		var left_rel := frame.left_position - frame.head_position
		var right_rel := frame.right_position - frame.head_position

		return left_rel.y > 0.3 and right_rel.y > 0.3


	func _check_warrior_stance(frames: Array[MovementFrame]) -> bool:
		if frames.size() < 10:
			return false

		# Check for relatively still pose
		var avg_velocity := 0.0
		for frame in frames:
			avg_velocity += frame.left_velocity.length() + frame.right_velocity.length()
		avg_velocity /= frames.size() * 2

		if avg_velocity > 0.3:  # Too much movement
			return false

		var latest := frames[-1]
		var left_rel := latest.left_position - latest.head_position
		var right_rel := latest.right_position - latest.head_position

		# One hand forward, one back or to side
		var forward_diff := abs(left_rel.z - right_rel.z)
		return forward_diff > 0.4


	func _check_gathering_pose(frame: MovementFrame) -> bool:
		var left_rel := frame.left_position - frame.head_position
		var right_rel := frame.right_position - frame.head_position

		# Both hands low
		var hands_low := left_rel.y < -0.3 and right_rel.y < -0.3

		# Hands relatively close together
		var hand_distance := (frame.left_position - frame.right_position).length()
		var hands_close := hand_distance < 0.4

		return hands_low and hands_close


	func _check_meditation_pose(frames: Array[MovementFrame]) -> bool:
		if frames.size() < 20:
			return false

		# Check for stillness
		var avg_velocity := 0.0
		for frame in frames:
			avg_velocity += frame.left_velocity.length() + frame.right_velocity.length()
		avg_velocity /= frames.size() * 2

		if avg_velocity > 0.1:  # Must be very still
			return false

		var latest := frames[-1]
		var left_rel := latest.left_position - latest.head_position
		var right_rel := latest.right_position - latest.head_position

		# Hands at chest height
		var chest_height := left_rel.y > -0.4 and left_rel.y < 0.0
		var chest_height_r := right_rel.y > -0.4 and right_rel.y < 0.0

		# Hands close together
		var hand_distance := (latest.left_position - latest.right_position).length()

		return chest_height and chest_height_r and hand_distance < 0.3

## ReplaySystem - Records and plays back VR movement sessions
## Captures all tracking data for review and analysis
class_name ReplaySystem
extends Node

signal recording_started
signal recording_stopped(replay: ReplayData)
signal playback_started(replay: ReplayData)
signal playback_paused
signal playback_resumed
signal playback_stopped
signal playback_frame(frame_index: int, total_frames: int)

## Replay data container
class ReplayData:
	var id: String = ""
	var timestamp: int = 0
	var duration: float = 0.0
	var frame_rate: float = 90.0
	var frames: Array[ReplayFrame] = []
	var events: Array[ReplayEvent] = []
	var metadata: Dictionary = {}

	func to_dict() -> Dictionary:
		var frame_data: Array[Dictionary] = []
		for frame in frames:
			frame_data.append(frame.to_dict())

		var event_data: Array[Dictionary] = []
		for event in events:
			event_data.append(event.to_dict())

		return {
			"id": id,
			"timestamp": timestamp,
			"duration": duration,
			"frame_rate": frame_rate,
			"frames": frame_data,
			"events": event_data,
			"metadata": metadata
		}

	static func from_dict(data: Dictionary) -> ReplayData:
		var replay := ReplayData.new()
		replay.id = data.get("id", "")
		replay.timestamp = data.get("timestamp", 0)
		replay.duration = data.get("duration", 0.0)
		replay.frame_rate = data.get("frame_rate", 90.0)
		replay.metadata = data.get("metadata", {})

		for frame_dict in data.get("frames", []):
			replay.frames.append(ReplayFrame.from_dict(frame_dict))

		for event_dict in data.get("events", []):
			replay.events.append(ReplayEvent.from_dict(event_dict))

		return replay


## Single frame of replay data
class ReplayFrame:
	var time: float = 0.0
	var head_position: Vector3 = Vector3.ZERO
	var head_rotation: Quaternion = Quaternion.IDENTITY
	var left_hand_position: Vector3 = Vector3.ZERO
	var left_hand_rotation: Quaternion = Quaternion.IDENTITY
	var right_hand_position: Vector3 = Vector3.ZERO
	var right_hand_rotation: Quaternion = Quaternion.IDENTITY
	var left_trigger: float = 0.0
	var right_trigger: float = 0.0
	var left_grip: float = 0.0
	var right_grip: float = 0.0

	func to_dict() -> Dictionary:
		return {
			"t": time,
			"hp": _vec3_to_array(head_position),
			"hr": _quat_to_array(head_rotation),
			"lp": _vec3_to_array(left_hand_position),
			"lr": _quat_to_array(left_hand_rotation),
			"rp": _vec3_to_array(right_hand_position),
			"rr": _quat_to_array(right_hand_rotation),
			"lt": left_trigger,
			"rt": right_trigger,
			"lg": left_grip,
			"rg": right_grip
		}

	static func from_dict(data: Dictionary) -> ReplayFrame:
		var frame := ReplayFrame.new()
		frame.time = data.get("t", 0.0)
		frame.head_position = _array_to_vec3(data.get("hp", [0, 0, 0]))
		frame.head_rotation = _array_to_quat(data.get("hr", [0, 0, 0, 1]))
		frame.left_hand_position = _array_to_vec3(data.get("lp", [0, 0, 0]))
		frame.left_hand_rotation = _array_to_quat(data.get("lr", [0, 0, 0, 1]))
		frame.right_hand_position = _array_to_vec3(data.get("rp", [0, 0, 0]))
		frame.right_hand_rotation = _array_to_quat(data.get("rr", [0, 0, 0, 1]))
		frame.left_trigger = data.get("lt", 0.0)
		frame.right_trigger = data.get("rt", 0.0)
		frame.left_grip = data.get("lg", 0.0)
		frame.right_grip = data.get("rg", 0.0)
		return frame

	static func _vec3_to_array(v: Vector3) -> Array:
		return [v.x, v.y, v.z]

	static func _array_to_vec3(a: Array) -> Vector3:
		if a.size() < 3:
			return Vector3.ZERO
		return Vector3(a[0], a[1], a[2])

	static func _quat_to_array(q: Quaternion) -> Array:
		return [q.x, q.y, q.z, q.w]

	static func _array_to_quat(a: Array) -> Quaternion:
		if a.size() < 4:
			return Quaternion.IDENTITY
		return Quaternion(a[0], a[1], a[2], a[3])


## Discrete event during replay (hits, misses, etc.)
class ReplayEvent:
	var time: float = 0.0
	var event_type: String = ""
	var data: Dictionary = {}

	func to_dict() -> Dictionary:
		return {
			"time": time,
			"type": event_type,
			"data": data
		}

	static func from_dict(d: Dictionary) -> ReplayEvent:
		var event := ReplayEvent.new()
		event.time = d.get("time", 0.0)
		event.event_type = d.get("type", "")
		event.data = d.get("data", {})
		return event


## Recording state
var is_recording: bool = false
var current_recording: ReplayData
var recording_start_time: float = 0.0

## Playback state
var is_playing: bool = false
var is_paused: bool = false
var current_playback: ReplayData
var playback_time: float = 0.0
var playback_speed: float = 1.0
var current_frame_index: int = 0

## References for recording
var xr_camera: XRCamera3D
var left_controller: XRController3D
var right_controller: XRController3D

## Ghost visualization for playback
var ghost_head: Node3D
var ghost_left_hand: Node3D
var ghost_right_hand: Node3D

## Settings
@export var record_frame_rate: float = 90.0
var record_interval: float = 1.0 / 90.0
var record_timer: float = 0.0

## Storage
const REPLAY_DIR := "user://replays/"
const MAX_STORED_REPLAYS := 50


func _ready() -> void:
	# Ensure replay directory exists
	DirAccess.make_dir_recursive_absolute(REPLAY_DIR)


func setup(camera: XRCamera3D, left: XRController3D, right: XRController3D) -> void:
	xr_camera = camera
	left_controller = left
	right_controller = right


func setup_ghost_visualization(head: Node3D, left_hand: Node3D, right_hand: Node3D) -> void:
	ghost_head = head
	ghost_left_hand = left_hand
	ghost_right_hand = right_hand

	# Initially hide ghosts
	if ghost_head:
		ghost_head.visible = false
	if ghost_left_hand:
		ghost_left_hand.visible = false
	if ghost_right_hand:
		ghost_right_hand.visible = false


func _process(delta: float) -> void:
	if is_recording:
		_process_recording(delta)
	elif is_playing and not is_paused:
		_process_playback(delta)


func _process_recording(delta: float) -> void:
	record_timer += delta

	if record_timer >= record_interval:
		record_timer -= record_interval
		_capture_frame()


func _capture_frame() -> void:
	if current_recording == null:
		return

	var frame := ReplayFrame.new()
	frame.time = Time.get_ticks_msec() / 1000.0 - recording_start_time

	if xr_camera:
		frame.head_position = xr_camera.global_position
		frame.head_rotation = xr_camera.global_transform.basis.get_rotation_quaternion()

	if left_controller:
		frame.left_hand_position = left_controller.global_position
		frame.left_hand_rotation = left_controller.global_transform.basis.get_rotation_quaternion()
		frame.left_trigger = left_controller.get_float("trigger")
		frame.left_grip = left_controller.get_float("grip")

	if right_controller:
		frame.right_hand_position = right_controller.global_position
		frame.right_hand_rotation = right_controller.global_transform.basis.get_rotation_quaternion()
		frame.right_trigger = right_controller.get_float("trigger")
		frame.right_grip = right_controller.get_float("grip")

	current_recording.frames.append(frame)


func _process_playback(delta: float) -> void:
	if current_playback == null or current_playback.frames.is_empty():
		return

	playback_time += delta * playback_speed

	# Find the appropriate frame
	while current_frame_index < current_playback.frames.size() - 1:
		if current_playback.frames[current_frame_index + 1].time <= playback_time:
			current_frame_index += 1
		else:
			break

	# Check for end of playback
	if current_frame_index >= current_playback.frames.size() - 1:
		stop_playback()
		return

	# Interpolate between frames
	var frame_a := current_playback.frames[current_frame_index]
	var frame_b := current_playback.frames[mini(current_frame_index + 1, current_playback.frames.size() - 1)]

	var t := 0.0
	if frame_b.time > frame_a.time:
		t = (playback_time - frame_a.time) / (frame_b.time - frame_a.time)

	_apply_interpolated_frame(frame_a, frame_b, t)

	# Process events at this time
	_process_events_at_time(playback_time)

	playback_frame.emit(current_frame_index, current_playback.frames.size())


func _apply_interpolated_frame(a: ReplayFrame, b: ReplayFrame, t: float) -> void:
	if ghost_head:
		ghost_head.global_position = a.head_position.lerp(b.head_position, t)
		ghost_head.global_transform.basis = Basis(a.head_rotation.slerp(b.head_rotation, t))

	if ghost_left_hand:
		ghost_left_hand.global_position = a.left_hand_position.lerp(b.left_hand_position, t)
		ghost_left_hand.global_transform.basis = Basis(a.left_hand_rotation.slerp(b.left_hand_rotation, t))

	if ghost_right_hand:
		ghost_right_hand.global_position = a.right_hand_position.lerp(b.right_hand_position, t)
		ghost_right_hand.global_transform.basis = Basis(a.right_hand_rotation.slerp(b.right_hand_rotation, t))


var last_event_index: int = 0

func _process_events_at_time(time: float) -> void:
	if current_playback == null:
		return

	while last_event_index < current_playback.events.size():
		var event := current_playback.events[last_event_index]
		if event.time <= time:
			_trigger_event(event)
			last_event_index += 1
		else:
			break


func _trigger_event(event: ReplayEvent) -> void:
	# Emit appropriate signals based on event type
	match event.event_type:
		"target_hit":
			GameEvents.target_destroyed.emit(null, event.data.get("velocity", 0.0))
		"target_miss":
			GameEvents.target_missed.emit(null)
		"combo":
			GameEvents.combo_changed.emit(event.data.get("combo", 0))
		"achievement":
			GameEvents.achievement_unlocked.emit(event.data.get("id", ""))


## Recording controls
func start_recording(metadata: Dictionary = {}) -> void:
	if is_recording:
		return

	current_recording = ReplayData.new()
	current_recording.id = str(Time.get_unix_time_from_system())
	current_recording.timestamp = Time.get_unix_time_from_system()
	current_recording.frame_rate = record_frame_rate
	current_recording.metadata = metadata

	recording_start_time = Time.get_ticks_msec() / 1000.0
	record_timer = 0.0
	is_recording = true

	recording_started.emit()


func stop_recording() -> ReplayData:
	if not is_recording:
		return null

	is_recording = false

	if current_recording.frames.size() > 0:
		current_recording.duration = current_recording.frames[-1].time

	var replay := current_recording
	current_recording = null

	recording_stopped.emit(replay)
	return replay


func add_event(event_type: String, data: Dictionary = {}) -> void:
	if not is_recording or current_recording == null:
		return

	var event := ReplayEvent.new()
	event.time = Time.get_ticks_msec() / 1000.0 - recording_start_time
	event.event_type = event_type
	event.data = data

	current_recording.events.append(event)


## Playback controls
func start_playback(replay: ReplayData) -> void:
	if replay == null or replay.frames.is_empty():
		return

	stop_playback()

	current_playback = replay
	playback_time = 0.0
	current_frame_index = 0
	last_event_index = 0
	is_playing = true
	is_paused = false

	# Show ghost visualization
	if ghost_head:
		ghost_head.visible = true
	if ghost_left_hand:
		ghost_left_hand.visible = true
	if ghost_right_hand:
		ghost_right_hand.visible = true

	playback_started.emit(replay)


func pause_playback() -> void:
	if is_playing:
		is_paused = true
		playback_paused.emit()


func resume_playback() -> void:
	if is_playing and is_paused:
		is_paused = false
		playback_resumed.emit()


func stop_playback() -> void:
	is_playing = false
	is_paused = false
	current_playback = null

	# Hide ghost visualization
	if ghost_head:
		ghost_head.visible = false
	if ghost_left_hand:
		ghost_left_hand.visible = false
	if ghost_right_hand:
		ghost_right_hand.visible = false

	playback_stopped.emit()


func seek_to(time: float) -> void:
	if current_playback == null:
		return

	playback_time = clampf(time, 0.0, current_playback.duration)

	# Find corresponding frame
	current_frame_index = 0
	for i in range(current_playback.frames.size()):
		if current_playback.frames[i].time <= playback_time:
			current_frame_index = i
		else:
			break

	# Reset event index
	last_event_index = 0
	for i in range(current_playback.events.size()):
		if current_playback.events[i].time <= playback_time:
			last_event_index = i + 1
		else:
			break


func set_playback_speed(speed: float) -> void:
	playback_speed = clampf(speed, 0.1, 4.0)


## Storage
func save_replay(replay: ReplayData, filename: String = "") -> bool:
	if replay == null:
		return false

	if filename.is_empty():
		filename = "replay_%s.json" % replay.id

	var path := REPLAY_DIR + filename
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("Failed to save replay: " + path)
		return false

	var json_string := JSON.stringify(replay.to_dict())
	file.store_string(json_string)
	file.close()

	# Cleanup old replays if needed
	_cleanup_old_replays()

	return true


func load_replay(filename: String) -> ReplayData:
	var path := REPLAY_DIR + filename
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Failed to load replay: " + path)
		return null

	var json_string := file.get_as_text()
	file.close()

	var json := JSON.new()
	var error := json.parse(json_string)
	if error != OK:
		push_error("Failed to parse replay JSON")
		return null

	return ReplayData.from_dict(json.data)


func get_saved_replays() -> Array[String]:
	var replays: Array[String] = []
	var dir := DirAccess.open(REPLAY_DIR)
	if dir:
		dir.list_dir_begin()
		var filename := dir.get_next()
		while filename != "":
			if filename.ends_with(".json"):
				replays.append(filename)
			filename = dir.get_next()
		dir.list_dir_end()

	return replays


func delete_replay(filename: String) -> bool:
	var path := REPLAY_DIR + filename
	return DirAccess.remove_absolute(path) == OK


func _cleanup_old_replays() -> void:
	var replays := get_saved_replays()
	if replays.size() <= MAX_STORED_REPLAYS:
		return

	# Sort by name (timestamp-based names will sort chronologically)
	replays.sort()

	# Delete oldest replays
	var to_delete := replays.size() - MAX_STORED_REPLAYS
	for i in range(to_delete):
		delete_replay(replays[i])

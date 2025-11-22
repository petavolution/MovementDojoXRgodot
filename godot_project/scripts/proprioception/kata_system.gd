## KataSystem - Choreographed movement sequences combining postures and paths
## Implements traditional form training with ghost visualization and scoring
class_name KataSystem
extends Node3D

signal kata_started(kata_name: String)
signal kata_completed(kata_name: String, score: float, grade: String)
signal kata_failed(kata_name: String, reason: String)
signal step_started(step_index: int, step_name: String)
signal step_completed(step_index: int, accuracy: float)
signal ghost_position_updated(position: Vector3, rotation: Vector3)

## Kata step types
enum StepType {
	POSTURE,      # Hold a posture for duration
	PATH,         # Trace a path
	TRANSITION,   # Move between positions (timed)
	STRIKE,       # Quick strike in direction
	BLOCK,        # Block incoming direction
	BREATH        # Breathing pause
}

## Single kata step
class KataStep:
	var name: String = ""
	var type: StepType = StepType.POSTURE
	var duration: float = 2.0
	var target_position: Vector3 = Vector3.ZERO
	var target_rotation: Vector3 = Vector3.ZERO
	var path_points: Array[Vector3] = []
	var tolerance: float = 0.1
	var is_optional: bool = false
	var breath_in: bool = true  # For BREATH type


## Complete kata definition
class Kata:
	var id: String = ""
	var name: String = ""
	var description: String = ""
	var style: String = "lightsaber"  # lightsaber, tai_chi, yoga
	var difficulty: float = 0.5
	var steps: Array[KataStep] = []
	var total_duration: float = 0.0
	var music_track: String = ""
	var ghost_recording: String = ""  # Path to recorded ghost data

	func calculate_duration() -> void:
		total_duration = 0.0
		for step in steps:
			total_duration += step.duration


## State
var current_kata: Kata
var current_step_index: int = 0
var is_active: bool = false
var is_paused: bool = false
var step_timer: float = 0.0
var kata_timer: float = 0.0

## Scoring
var step_scores: Array[float] = []
var total_score: float = 0.0
var current_step_deviation: float = 0.0

## Ghost visualization
var ghost_avatar: Node3D
var ghost_saber: Node3D
var ghost_data: Array[Dictionary] = []
var ghost_playback_index: int = 0
var show_ghost: bool = true

## References
var proprioception: ProprioceptionSystem
var path_following: PathFollowing
var xr_camera: XRCamera3D
var right_controller: XRController3D

## Kata library
var kata_library: Dictionary = {}


func _ready() -> void:
	_setup_kata_library()
	_create_ghost_visualization()


func setup(proprio: ProprioceptionSystem, paths: PathFollowing, camera: XRCamera3D, right: XRController3D) -> void:
	proprioception = proprio
	path_following = paths
	xr_camera = camera
	right_controller = right

	# Connect to subsystem signals
	if proprioception:
		proprioception.posture_achieved.connect(_on_posture_achieved)

	if path_following:
		path_following.path_completed.connect(_on_path_completed)


func _process(delta: float) -> void:
	if not is_active or is_paused:
		return

	kata_timer += delta
	step_timer += delta

	_update_ghost(delta)
	_evaluate_current_step(delta)


func _setup_kata_library() -> void:
	# Basic Form 1 - Beginner lightsaber kata
	var form1 := Kata.new()
	form1.id = "basic_form_1"
	form1.name = "Basic Form I - Shii-Cho"
	form1.description = "The most fundamental lightsaber form, focusing on basic strikes and parries"
	form1.style = "lightsaber"
	form1.difficulty = 0.3

	# Ready stance
	var step1 := KataStep.new()
	step1.name = "Ready Stance"
	step1.type = StepType.POSTURE
	step1.target_position = Vector3(0.2, 1.2, -0.3)
	step1.duration = 3.0
	form1.steps.append(step1)

	# Overhead strike
	var step2 := KataStep.new()
	step2.name = "Overhead Strike"
	step2.type = StepType.PATH
	step2.path_points = [
		Vector3(0.1, 1.8, -0.2),
		Vector3(0.1, 0.6, -0.5)
	]
	step2.duration = 1.5
	form1.steps.append(step2)

	# Return to guard
	var step3 := KataStep.new()
	step3.name = "Return to Guard"
	step3.type = StepType.TRANSITION
	step3.target_position = Vector3(0.2, 1.2, -0.3)
	step3.duration = 1.0
	form1.steps.append(step3)

	# Horizontal slash
	var step4 := KataStep.new()
	step4.name = "Horizontal Slash"
	step4.type = StepType.PATH
	step4.path_points = [
		Vector3(-0.5, 1.2, -0.3),
		Vector3(0.6, 1.2, -0.4)
	]
	step4.duration = 1.2
	form1.steps.append(step4)

	# Return and hold
	var step5 := KataStep.new()
	step5.name = "Final Stance"
	step5.type = StepType.POSTURE
	step5.target_position = Vector3(0.2, 1.2, -0.3)
	step5.duration = 2.0
	form1.steps.append(step5)

	form1.calculate_duration()
	kata_library["basic_form_1"] = form1

	# Meditation Form - Qi Gong inspired
	var meditation := Kata.new()
	meditation.id = "meditation_flow"
	meditation.name = "Meditation Flow"
	meditation.description = "Slow, breathing-focused movements for centering"
	meditation.style = "tai_chi"
	meditation.difficulty = 0.2

	var m_step1 := KataStep.new()
	m_step1.name = "Centering Breath"
	m_step1.type = StepType.BREATH
	m_step1.breath_in = true
	m_step1.duration = 4.0
	meditation.steps.append(m_step1)

	var m_step2 := KataStep.new()
	m_step2.name = "Hands Rise"
	m_step2.type = StepType.PATH
	m_step2.path_points = [
		Vector3(0, 0.8, -0.3),
		Vector3(0, 1.4, -0.25)
	]
	m_step2.duration = 4.0
	m_step2.tolerance = 0.15
	meditation.steps.append(m_step2)

	var m_step3 := KataStep.new()
	m_step3.name = "Hold at Heart"
	m_step3.type = StepType.POSTURE
	m_step3.target_position = Vector3(0, 1.2, -0.2)
	m_step3.duration = 3.0
	meditation.steps.append(m_step3)

	var m_step4 := KataStep.new()
	m_step4.name = "Release Breath"
	m_step4.type = StepType.BREATH
	m_step4.breath_in = false
	m_step4.duration = 4.0
	meditation.steps.append(m_step4)

	var m_step5 := KataStep.new()
	m_step5.name = "Hands Lower"
	m_step5.type = StepType.PATH
	m_step5.path_points = [
		Vector3(0, 1.4, -0.25),
		Vector3(0, 0.8, -0.3)
	]
	m_step5.duration = 4.0
	meditation.steps.append(m_step5)

	meditation.calculate_duration()
	kata_library["meditation_flow"] = meditation

	# Combat Form - Advanced
	var combat := Kata.new()
	combat.id = "combat_sequence_1"
	combat.name = "Combat Sequence Alpha"
	combat.description = "A flowing combat sequence with strikes, blocks, and transitions"
	combat.style = "lightsaber"
	combat.difficulty = 0.6

	# Series of combat moves
	var c1 := KataStep.new()
	c1.name = "High Guard"
	c1.type = StepType.POSTURE
	c1.target_position = Vector3(0.1, 1.7, -0.2)
	c1.duration = 1.5
	combat.steps.append(c1)

	var c2 := KataStep.new()
	c2.name = "Diagonal Strike"
	c2.type = StepType.STRIKE
	c2.path_points = [Vector3(0.1, 1.7, -0.2), Vector3(-0.4, 0.7, -0.5)]
	c2.duration = 0.8
	combat.steps.append(c2)

	var c3 := KataStep.new()
	c3.name = "Side Block"
	c3.type = StepType.BLOCK
	c3.target_position = Vector3(-0.5, 1.1, -0.2)
	c3.duration = 1.0
	combat.steps.append(c3)

	var c4 := KataStep.new()
	c4.name = "Counter Strike"
	c4.type = StepType.STRIKE
	c4.path_points = [Vector3(-0.5, 1.1, -0.2), Vector3(0.5, 1.0, -0.5)]
	c4.duration = 0.7
	combat.steps.append(c4)

	var c5 := KataStep.new()
	c5.name = "Spin Guard"
	c5.type = StepType.PATH
	c5.path_points = _generate_spin_path()
	c5.duration = 1.5
	combat.steps.append(c5)

	var c6 := KataStep.new()
	c6.name = "Final Thrust"
	c6.type = StepType.STRIKE
	c6.path_points = [Vector3(0.2, 1.2, -0.2), Vector3(0.2, 1.2, -0.8)]
	c6.duration = 0.6
	combat.steps.append(c6)

	var c7 := KataStep.new()
	c7.name = "Return to Ready"
	c7.type = StepType.POSTURE
	c7.target_position = Vector3(0.2, 1.2, -0.3)
	c7.duration = 2.0
	combat.steps.append(c7)

	combat.calculate_duration()
	kata_library["combat_sequence_1"] = combat


func _generate_spin_path() -> Array[Vector3]:
	var points: Array[Vector3] = []
	var center := Vector3(0, 1.1, -0.3)
	var radius := 0.4

	for i in range(17):
		var t := float(i) / 16 * TAU
		points.append(center + Vector3(cos(t) * radius, sin(t) * 0.2, sin(t) * radius * 0.5))

	return points


func _create_ghost_visualization() -> void:
	ghost_avatar = Node3D.new()
	ghost_avatar.name = "GhostAvatar"
	ghost_avatar.visible = false
	add_child(ghost_avatar)

	# Create translucent ghost body
	var body := MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.15
	capsule.height = 0.6

	var body_mat := StandardMaterial3D.new()
	body_mat.albedo_color = Color(0.3, 0.7, 1.0, 0.3)
	body_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	body_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	capsule.material = body_mat

	body.mesh = capsule
	body.position = Vector3(0, 0.3, 0)
	ghost_avatar.add_child(body)

	# Ghost saber
	ghost_saber = Node3D.new()
	ghost_saber.name = "GhostSaber"

	var blade := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.015
	cyl.bottom_radius = 0.015
	cyl.height = 0.8

	var blade_mat := StandardMaterial3D.new()
	blade_mat.albedo_color = Color(0.4, 0.8, 1.0, 0.5)
	blade_mat.emission_enabled = true
	blade_mat.emission = Color(0.4, 0.8, 1.0)
	blade_mat.emission_energy_multiplier = 1.5
	blade_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	cyl.material = blade_mat

	blade.mesh = cyl
	blade.rotation_degrees = Vector3(90, 0, 0)
	blade.position = Vector3(0, 0, -0.4)
	ghost_saber.add_child(blade)

	ghost_avatar.add_child(ghost_saber)


## Start a kata
func start_kata(kata_id: String) -> bool:
	if not kata_library.has(kata_id):
		push_error("Unknown kata: " + kata_id)
		return false

	current_kata = kata_library[kata_id]
	return _begin_kata()


func start_custom_kata(kata: Kata) -> bool:
	current_kata = kata
	return _begin_kata()


func _begin_kata() -> bool:
	if current_kata == null or current_kata.steps.is_empty():
		return false

	is_active = true
	is_paused = false
	current_step_index = 0
	step_timer = 0.0
	kata_timer = 0.0
	step_scores.clear()
	total_score = 0.0

	# Show ghost if available
	if show_ghost:
		ghost_avatar.visible = true
		_load_ghost_data()

	kata_started.emit(current_kata.name)
	_start_step(0)

	return true


func pause_kata() -> void:
	is_paused = true


func resume_kata() -> void:
	is_paused = false


func stop_kata() -> void:
	is_active = false
	ghost_avatar.visible = false
	_cleanup_step()


func _start_step(index: int) -> void:
	if index >= current_kata.steps.size():
		_complete_kata()
		return

	current_step_index = index
	step_timer = 0.0
	current_step_deviation = 0.0

	var step := current_kata.steps[index]
	step_started.emit(index, step.name)

	# Setup based on step type
	match step.type:
		StepType.POSTURE:
			_start_posture_step(step)
		StepType.PATH, StepType.STRIKE:
			_start_path_step(step)
		StepType.TRANSITION:
			# Just timed movement
			pass
		StepType.BLOCK:
			_start_posture_step(step)
		StepType.BREATH:
			_start_breath_step(step)


func _start_posture_step(step: KataStep) -> void:
	if proprioception == null:
		return

	var posture := ProprioceptionSystem.TargetPosture.new()
	posture.name = step.name
	posture.right_hand_position = step.target_position
	posture.position_tolerance = step.tolerance
	posture.hold_duration = step.duration * 0.5  # Hold for half duration

	proprioception.start_custom_posture(posture)


func _start_path_step(step: KataStep) -> void:
	if path_following == null or step.path_points.size() < 2:
		return

	var path := PathFollowing.TracePath.new()
	path.name = step.name
	path.points = step.path_points
	path.tolerance = step.tolerance
	path.time_limit = step.duration * 1.5  # Give some buffer

	path_following.start_custom_path(path)


func _start_breath_step(step: KataStep) -> void:
	# Visual/audio cue for breathing
	if step.breath_in:
		GameEvents.tutorial_step_changed.emit("breath", "Breathe In...")
	else:
		GameEvents.tutorial_step_changed.emit("breath", "Breathe Out...")


func _evaluate_current_step(delta: float) -> void:
	if current_step_index >= current_kata.steps.size():
		return

	var step := current_kata.steps[current_step_index]

	# Check if step duration elapsed
	if step_timer >= step.duration:
		_complete_step()
		return

	# Evaluate based on type
	match step.type:
		StepType.POSTURE, StepType.BLOCK:
			if proprioception:
				var info := proprioception.get_deviation_info()
				current_step_deviation += info.total * delta

		StepType.PATH, StepType.STRIKE:
			if path_following and path_following.is_active:
				# Path following handles its own evaluation
				pass


func _complete_step() -> void:
	var step := current_kata.steps[current_step_index]

	# Calculate step score
	var score := 1.0

	match step.type:
		StepType.POSTURE, StepType.BLOCK:
			if proprioception:
				proprioception.stop_posture_tracking()
			var avg_deviation := current_step_deviation / step.duration if step.duration > 0 else 0.0
			score = 1.0 - clampf(avg_deviation / step.tolerance, 0.0, 1.0)

		StepType.PATH, StepType.STRIKE:
			if path_following:
				score = path_following.get_progress()
				path_following.stop_path()

		StepType.TRANSITION, StepType.BREATH:
			score = 1.0  # Always pass

	step_scores.append(score)
	step_completed.emit(current_step_index, score)

	# Move to next step
	_cleanup_step()
	_start_step(current_step_index + 1)


func _cleanup_step() -> void:
	if proprioception:
		proprioception.stop_posture_tracking()
	if path_following:
		path_following.stop_path()


func _complete_kata() -> void:
	is_active = false
	ghost_avatar.visible = false

	# Calculate final score
	if step_scores.is_empty():
		total_score = 0.0
	else:
		var sum := 0.0
		for s in step_scores:
			sum += s
		total_score = sum / step_scores.size()

	var grade := _calculate_grade(total_score)

	kata_completed.emit(current_kata.name, total_score, grade)
	_cleanup_step()


func _calculate_grade(score: float) -> String:
	if score >= 0.95:
		return "S"
	elif score >= 0.9:
		return "A"
	elif score >= 0.8:
		return "B"
	elif score >= 0.7:
		return "C"
	elif score >= 0.6:
		return "D"
	return "F"


func _update_ghost(delta: float) -> void:
	if not show_ghost or ghost_data.is_empty():
		return

	# Find ghost frame for current time
	while ghost_playback_index < ghost_data.size() - 1:
		if ghost_data[ghost_playback_index + 1].time <= kata_timer:
			ghost_playback_index += 1
		else:
			break

	if ghost_playback_index >= ghost_data.size():
		return

	var frame: Dictionary = ghost_data[ghost_playback_index]
	ghost_avatar.global_position = frame.position
	ghost_saber.global_position = frame.saber_position
	ghost_saber.rotation = frame.saber_rotation

	ghost_position_updated.emit(frame.position, frame.saber_rotation)


func _load_ghost_data() -> void:
	ghost_data.clear()
	ghost_playback_index = 0

	# Generate procedural ghost data from kata steps
	var time := 0.0
	for step in current_kata.steps:
		match step.type:
			StepType.POSTURE, StepType.BLOCK:
				_add_ghost_posture(time, step.duration, step.target_position)
			StepType.PATH, StepType.STRIKE:
				_add_ghost_path(time, step.duration, step.path_points)
			_:
				_add_ghost_hold(time, step.duration)

		time += step.duration


func _add_ghost_posture(start_time: float, duration: float, position: Vector3) -> void:
	var frames := int(duration * 30)  # 30 fps
	for i in range(frames):
		var t := float(i) / frames
		ghost_data.append({
			"time": start_time + t * duration,
			"position": Vector3(0, 0, 0),  # Body at origin
			"saber_position": position,
			"saber_rotation": Vector3.ZERO
		})


func _add_ghost_path(start_time: float, duration: float, points: Array[Vector3]) -> void:
	if points.size() < 2:
		return

	var total_length := 0.0
	for i in range(points.size() - 1):
		total_length += points[i].distance_to(points[i + 1])

	var frames := int(duration * 30)
	for i in range(frames):
		var t := float(i) / frames
		var target_dist := t * total_length

		# Find position along path
		var pos := points[0]
		var accumulated := 0.0
		for j in range(points.size() - 1):
			var seg_len := points[j].distance_to(points[j + 1])
			if accumulated + seg_len >= target_dist:
				var seg_t := (target_dist - accumulated) / seg_len
				pos = points[j].lerp(points[j + 1], seg_t)
				break
			accumulated += seg_len

		ghost_data.append({
			"time": start_time + t * duration,
			"position": Vector3(0, 0, 0),
			"saber_position": pos,
			"saber_rotation": Vector3.ZERO
		})


func _add_ghost_hold(start_time: float, duration: float) -> void:
	var last_pos := ghost_data[-1].saber_position if not ghost_data.is_empty() else Vector3(0.2, 1.2, -0.3)
	var frames := int(duration * 30)
	for i in range(frames):
		ghost_data.append({
			"time": start_time + float(i) / frames * duration,
			"position": Vector3(0, 0, 0),
			"saber_position": last_pos,
			"saber_rotation": Vector3.ZERO
		})


## Signal handlers
func _on_posture_achieved(posture_name: String, accuracy: float) -> void:
	# Posture was held successfully during a kata step
	pass


func _on_path_completed(path_name: String, score: float, time: float) -> void:
	# Path was completed during a kata step
	pass


## Getters
func get_kata_list() -> Array[String]:
	var list: Array[String] = []
	for key in kata_library:
		list.append(key)
	return list


func get_kata(kata_id: String) -> Kata:
	return kata_library.get(kata_id)


func get_progress() -> float:
	if current_kata == null or current_kata.steps.is_empty():
		return 0.0
	return float(current_step_index) / current_kata.steps.size()


func is_running() -> bool:
	return is_active


func toggle_ghost(enabled: bool) -> void:
	show_ghost = enabled
	if not enabled:
		ghost_avatar.visible = false

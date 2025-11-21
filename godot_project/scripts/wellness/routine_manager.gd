## RoutineManager - Executes wellness routines with guidance
## Provides visual and audio cues, tracks completion
extends Node
class_name RoutineManager

signal routine_started(routine: WellnessRoutine)
signal routine_completed(routine: WellnessRoutine, stats: Dictionary)
signal routine_cancelled()
signal step_started(step: WellnessRoutine.RoutineStep, index: int)
signal step_progress(progress: float, time_remaining: float)
signal step_completed(step: WellnessRoutine.RoutineStep, index: int)

@export var guide_voice_enabled := true
@export var visual_guides_enabled := true
@export var haptic_cues_enabled := true

# Current state
var current_routine: WellnessRoutine
var is_running := false
var current_step_start_time := 0.0
var current_step_duration := 0.0
var auto_advance := true

# Statistics
var steps_completed := 0
var total_time := 0.0
var movement_matches := 0

# References
var audio_player: AudioStreamPlayer3D
var guide_visualizer: Node3D


func _ready() -> void:
	_setup_audio()


func _process(delta: float) -> void:
	if not is_running or current_routine == null:
		return

	var current_step := current_routine.get_current_step()
	if current_step == null:
		return

	# Calculate step progress
	var elapsed := Time.get_ticks_msec() / 1000.0 - current_step_start_time
	var progress := clamp(elapsed / current_step.duration, 0.0, 1.0)
	var remaining := max(0.0, current_step.duration - elapsed)

	step_progress.emit(progress, remaining)

	# Auto-advance when step duration complete
	if auto_advance and elapsed >= current_step.duration:
		_complete_current_step()


func start_routine(routine_id: String) -> bool:
	var routine := RoutineLibrary.get_routine(routine_id)
	if routine == null:
		push_error("[RoutineManager] Routine not found: ", routine_id)
		return false

	return start_routine_instance(routine)


func start_routine_instance(routine: WellnessRoutine) -> bool:
	if is_running:
		cancel_routine()

	current_routine = routine
	is_running = true
	steps_completed = 0
	total_time = 0.0
	movement_matches = 0

	# Connect to routine signals
	current_routine.step_started.connect(_on_routine_step_started)
	current_routine.step_completed.connect(_on_routine_step_completed)
	current_routine.routine_completed.connect(_on_routine_completed)

	# Start session tracking
	if not SessionManager.session_active:
		SessionManager.start_session()

	current_routine.start()
	routine_started.emit(current_routine)

	return true


func cancel_routine() -> void:
	if not is_running:
		return

	is_running = false

	if current_routine:
		current_routine.stop()
		# Disconnect signals
		if current_routine.step_started.is_connected(_on_routine_step_started):
			current_routine.step_started.disconnect(_on_routine_step_started)
		if current_routine.step_completed.is_connected(_on_routine_step_completed):
			current_routine.step_completed.disconnect(_on_routine_step_completed)
		if current_routine.routine_completed.is_connected(_on_routine_completed):
			current_routine.routine_completed.disconnect(_on_routine_completed)

	current_routine = null
	routine_cancelled.emit()


func skip_step() -> void:
	if is_running and current_routine:
		_complete_current_step()


func pause_routine() -> void:
	is_running = false


func resume_routine() -> void:
	if current_routine:
		is_running = true


func get_current_step_info() -> Dictionary:
	if not is_running or current_routine == null:
		return {}

	var step := current_routine.get_current_step()
	if step == null:
		return {}

	var elapsed := Time.get_ticks_msec() / 1000.0 - current_step_start_time

	return {
		"name": step.name,
		"instruction": step.instruction,
		"duration": step.duration,
		"elapsed": elapsed,
		"remaining": max(0.0, step.duration - elapsed),
		"progress": clamp(elapsed / step.duration, 0.0, 1.0),
		"step_index": current_routine.current_step_index,
		"total_steps": current_routine.steps.size()
	}


func _complete_current_step() -> void:
	if current_routine == null:
		return

	var elapsed := Time.get_ticks_msec() / 1000.0 - current_step_start_time
	total_time += elapsed
	steps_completed += 1

	current_routine.complete_current_step()


func _on_routine_step_started(index: int, step: WellnessRoutine.RoutineStep) -> void:
	current_step_start_time = Time.get_ticks_msec() / 1000.0
	current_step_duration = step.duration

	step_started.emit(step, index)

	# Play audio cue
	if guide_voice_enabled and step.audio_cue != "":
		_play_audio_cue(step.audio_cue)

	# Show visual guide
	if visual_guides_enabled:
		_show_visual_guide(step)

	# Haptic pulse
	if haptic_cues_enabled:
		_trigger_step_haptic()


func _on_routine_step_completed(index: int, step: WellnessRoutine.RoutineStep) -> void:
	step_completed.emit(step, index)


func _on_routine_completed(routine: WellnessRoutine) -> void:
	is_running = false

	var stats := {
		"routine_id": routine.id,
		"routine_name": routine.name,
		"steps_completed": steps_completed,
		"total_steps": routine.steps.size(),
		"total_time": total_time,
		"movement_matches": movement_matches,
		"completion_rate": float(steps_completed) / routine.steps.size() * 100.0
	}

	routine_completed.emit(routine, stats)

	# Unlock achievement for first routine
	SessionManager.unlock_achievement("first_routine_completed")

	# Category-specific achievements
	match routine.category:
		"yoga":
			SessionManager.unlock_achievement("yoga_complete")
		"qi_gong":
			SessionManager.unlock_achievement("qi_gong_complete")
		"meditation":
			SessionManager.unlock_achievement("meditation_complete")


func _setup_audio() -> void:
	audio_player = AudioStreamPlayer3D.new()
	audio_player.name = "RoutineAudio"
	audio_player.unit_size = 5.0
	add_child(audio_player)


func _play_audio_cue(cue_name: String) -> void:
	# In production, load and play the audio file
	# var audio = load("res://audio/routine_cues/" + cue_name + ".ogg")
	# audio_player.stream = audio
	# audio_player.play()
	pass


func _show_visual_guide(step: WellnessRoutine.RoutineStep) -> void:
	# Show target zones if specified
	if step.target_zones.size() > 0:
		for zone in step.target_zones:
			# Would spawn visual indicator at zone position
			pass


func _trigger_step_haptic() -> void:
	# Find controllers and trigger haptic
	var xr_origin := get_tree().get_first_node_in_group("xr_origin")
	if xr_origin:
		for child in xr_origin.get_children():
			if child is XRController3D:
				child.trigger_haptic_pulse("haptic", 40.0, 0.3, 0.1, 0.0)

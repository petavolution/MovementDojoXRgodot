## WellnessRoutine - Guided movement sequences for yoga, qi gong, meditation
## Defines structured routines with steps and guidance
class_name WellnessRoutine
extends RefCounted

signal step_started(step_index: int, step: RoutineStep)
signal step_completed(step_index: int, step: RoutineStep)
signal routine_completed(routine: WellnessRoutine)
signal progress_updated(progress: float)

var id: String
var name: String
var description: String
var category: String  # "yoga", "qi_gong", "meditation", "warmup"
var duration_estimate: float  # Total estimated duration in seconds
var difficulty: int  # 1-5

var steps: Array[RoutineStep] = []
var current_step_index := -1
var is_active := false
var start_time := 0.0


## Single step in a routine
class RoutineStep:
	var name: String
	var instruction: String
	var duration: float  # Seconds to hold/perform
	var movement_type: int  # MovementAnalytics.MovementType or -1 for any
	var target_zones: Array[Vector3] = []  # Relative positions to reach
	var pose_name: String = ""  # Expected pose detection
	var audio_cue: String = ""  # Audio file to play
	var visual_guide: String = ""  # Visual indicator type

	static func create(n: String, instr: String, dur: float, move_type: int = -1) -> RoutineStep:
		var step := RoutineStep.new()
		step.name = n
		step.instruction = instr
		step.duration = dur
		step.movement_type = move_type
		return step


static func create_routine(routine_id: String, routine_name: String, desc: String, cat: String) -> WellnessRoutine:
	var routine := WellnessRoutine.new()
	routine.id = routine_id
	routine.name = routine_name
	routine.description = desc
	routine.category = cat
	return routine


func add_step(step: RoutineStep) -> WellnessRoutine:
	steps.append(step)
	duration_estimate += step.duration
	return self


func start() -> void:
	if steps.is_empty():
		return

	is_active = true
	current_step_index = -1
	start_time = Time.get_ticks_msec() / 1000.0
	advance_step()


func stop() -> void:
	is_active = false
	current_step_index = -1


func advance_step() -> bool:
	current_step_index += 1

	if current_step_index >= steps.size():
		is_active = false
		routine_completed.emit(self)
		return false

	step_started.emit(current_step_index, steps[current_step_index])
	return true


func complete_current_step() -> void:
	if current_step_index >= 0 and current_step_index < steps.size():
		step_completed.emit(current_step_index, steps[current_step_index])
	advance_step()


func get_current_step() -> RoutineStep:
	if current_step_index >= 0 and current_step_index < steps.size():
		return steps[current_step_index]
	return null


func get_progress() -> float:
	if steps.is_empty():
		return 0.0
	return float(current_step_index + 1) / steps.size()


func to_dict() -> Dictionary:
	var steps_data: Array[Dictionary] = []
	for step in steps:
		steps_data.append({
			"name": step.name,
			"instruction": step.instruction,
			"duration": step.duration,
			"movement_type": step.movement_type,
			"pose_name": step.pose_name
		})

	return {
		"id": id,
		"name": name,
		"description": description,
		"category": category,
		"duration": duration_estimate,
		"difficulty": difficulty,
		"steps": steps_data
	}

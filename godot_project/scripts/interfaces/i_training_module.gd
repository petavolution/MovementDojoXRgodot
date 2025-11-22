## ITrainingModule - Interface for all training modules
## Defines contract for training systems to implement
class_name ITrainingModule
extends RefCounted

## Training module state
enum ModuleState {
	INACTIVE,
	LOADING,
	READY,
	ACTIVE,
	PAUSED,
	COMPLETING,
	COMPLETED,
	FAILED
}

## Training result
class TrainingResult:
	var module_id: String = ""
	var score: int = 0
	var accuracy: float = 0.0
	var completion_time: float = 0.0
	var targets_hit: int = 0
	var targets_missed: int = 0
	var max_combo: int = 0
	var grade: String = ""  # S, A, B, C, D, F
	var metrics: Dictionary = {}

## Interface methods - must be overridden by implementations

## Get unique module identifier
func get_module_id() -> String:
	push_error("ITrainingModule.get_module_id() not implemented")
	return ""

## Get human-readable module name
func get_display_name() -> String:
	push_error("ITrainingModule.get_display_name() not implemented")
	return ""

## Get module description
func get_description() -> String:
	push_error("ITrainingModule.get_description() not implemented")
	return ""

## Get current module state
func get_state() -> ModuleState:
	push_error("ITrainingModule.get_state() not implemented")
	return ModuleState.INACTIVE

## Initialize the module
func initialize() -> bool:
	push_error("ITrainingModule.initialize() not implemented")
	return false

## Start the training session
func start() -> void:
	push_error("ITrainingModule.start() not implemented")

## Pause the training session
func pause() -> void:
	push_error("ITrainingModule.pause() not implemented")

## Resume the training session
func resume() -> void:
	push_error("ITrainingModule.resume() not implemented")

## Stop and cleanup the module
func stop() -> void:
	push_error("ITrainingModule.stop() not implemented")

## Update called each frame
func update(delta: float) -> void:
	push_error("ITrainingModule.update() not implemented")

## Get training result when completed
func get_result() -> TrainingResult:
	push_error("ITrainingModule.get_result() not implemented")
	return TrainingResult.new()

## Get current progress (0.0 to 1.0)
func get_progress() -> float:
	push_error("ITrainingModule.get_progress() not implemented")
	return 0.0

## Check if module requires specific hardware
func get_required_hardware() -> Array[String]:
	return []  # Default: no special hardware required

## Get module configuration options
func get_config_options() -> Dictionary:
	return {}  # Default: no configurable options

## Apply configuration
func apply_config(config: Dictionary) -> void:
	pass  # Default: no configuration to apply

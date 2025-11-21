## TargetSpawner - Manages training target spawning and waves
extends Node3D
class_name TargetSpawner

signal wave_completed(wave_number: int)
signal all_waves_completed()
signal target_destroyed(target: TrainingTarget)

@export_group("Spawning")
@export var spawn_radius_min := 1.5
@export var spawn_radius_max := 3.0
@export var spawn_height_min := 0.8
@export var spawn_height_max := 2.0
@export var max_active_targets := 5
@export var spawn_interval := 2.0

@export_group("Difficulty")
@export var base_targets_per_wave := 5
@export var targets_increase_per_wave := 2
@export var max_waves := 10

@export_group("Target Types")
@export var stationary_weight := 0.6
@export var moving_weight := 0.4

# State
var current_wave := 0
var targets_spawned_this_wave := 0
var targets_destroyed_this_wave := 0
var targets_needed_this_wave := 0
var active_targets: Array[TrainingTarget] = []
var is_spawning := false

var _spawn_timer := 0.0
var _head_position := Vector3(0, 1.6, 0)


func _ready() -> void:
	GameEvents.movement_frame_recorded.connect(_on_movement_frame)


func _process(delta: float) -> void:
	if not is_spawning:
		return

	# Update spawn timer
	_spawn_timer += delta
	if _spawn_timer >= spawn_interval and active_targets.size() < max_active_targets:
		_spawn_timer = 0.0
		_spawn_target()


func _on_movement_frame(frame: MovementFrame) -> void:
	_head_position = frame.head_position


func start_training() -> void:
	current_wave = 0
	is_spawning = true
	_start_next_wave()


func stop_training() -> void:
	is_spawning = false
	_clear_all_targets()


func _start_next_wave() -> void:
	current_wave += 1

	if current_wave > max_waves:
		is_spawning = false
		all_waves_completed.emit()
		return

	targets_spawned_this_wave = 0
	targets_destroyed_this_wave = 0
	targets_needed_this_wave = base_targets_per_wave + (current_wave - 1) * targets_increase_per_wave

	print("[TargetSpawner] Wave ", current_wave, " started. Targets: ", targets_needed_this_wave)


func _spawn_target() -> void:
	if targets_spawned_this_wave >= targets_needed_this_wave:
		return

	# Determine target type
	var type := _get_random_target_type()

	# Calculate spawn position
	var position := _get_spawn_position()

	# Create target
	var target := TrainingTarget.create_target(type, position, _get_target_color())
	target.destroyed.connect(_on_target_destroyed)

	add_child(target)
	active_targets.append(target)
	targets_spawned_this_wave += 1


func _get_random_target_type() -> TrainingTarget.TargetType:
	var roll := randf()
	if roll < stationary_weight:
		return TrainingTarget.TargetType.STATIONARY
	else:
		return TrainingTarget.TargetType.MOVING


func _get_spawn_position() -> Vector3:
	var angle := randf() * TAU
	var distance := randf_range(spawn_radius_min, spawn_radius_max)
	var height := randf_range(spawn_height_min, spawn_height_max)

	# Position relative to head, but in world space
	var offset := Vector3(
		cos(angle) * distance,
		height - _head_position.y + randf_range(-0.3, 0.3),
		sin(angle) * distance
	)

	# Bias towards front hemisphere
	if offset.z < 0:
		offset.z = -offset.z * 0.3  # Reduce behind spawns

	return _head_position + offset


func _get_target_color() -> Color:
	# Vary colors slightly for visual interest
	var hue := randf_range(0.0, 0.1)  # Orange-red range
	return Color.from_hsv(hue, 0.8, 1.0)


func _on_target_destroyed(target: TrainingTarget, _position: Vector3) -> void:
	active_targets.erase(target)
	targets_destroyed_this_wave += 1
	target_destroyed.emit(target)

	# Check wave completion
	if targets_destroyed_this_wave >= targets_needed_this_wave:
		wave_completed.emit(current_wave)
		_start_next_wave()


func _clear_all_targets() -> void:
	for target in active_targets:
		if is_instance_valid(target):
			target.queue_free()
	active_targets.clear()


## Get current wave info for UI
func get_wave_info() -> Dictionary:
	return {
		"wave": current_wave,
		"max_waves": max_waves,
		"targets_destroyed": targets_destroyed_this_wave,
		"targets_needed": targets_needed_this_wave,
		"active_targets": active_targets.size()
	}

## ForcePowers - Gesture-based Force push/pull abilities
## Detects hand gestures and applies physics forces
extends Node3D
class_name ForcePowers

signal force_push_activated(hand: String, direction: Vector3, power: float)
signal force_pull_activated(hand: String, direction: Vector3, power: float)
signal force_power_ready(hand: String, power_type: String)

@export_group("Force Settings")
@export var push_force := 15.0
@export var pull_force := 10.0
@export var force_range := 10.0
@export var cooldown := 1.0

@export_group("Gesture Detection")
@export var thrust_velocity_threshold := 3.0  # m/s for push
@export var pull_velocity_threshold := 2.5    # m/s for pull
@export var gesture_window := 0.3             # seconds to complete gesture

@export_group("Effects")
@export var effect_color := Color(0.4, 0.6, 1.0)

# State per hand
var left_state := HandState.new()
var right_state := HandState.new()

# References
var left_controller: XRController3D
var right_controller: XRController3D

# Effect nodes
var push_particles: GPUParticles3D
var pull_particles: GPUParticles3D


class HandState:
	var is_ready := true
	var cooldown_timer := 0.0
	var gesture_start_time := 0.0
	var gesture_start_position := Vector3.ZERO
	var is_gesture_active := false
	var current_power := 0.0


func _ready() -> void:
	_setup_effects()


func _physics_process(delta: float) -> void:
	_update_cooldowns(delta)
	_check_gestures()


func setup_controllers(left: XRController3D, right: XRController3D) -> void:
	left_controller = left
	right_controller = right


func _update_cooldowns(delta: float) -> void:
	if not left_state.is_ready:
		left_state.cooldown_timer -= delta
		if left_state.cooldown_timer <= 0:
			left_state.is_ready = true
			force_power_ready.emit("left", "all")

	if not right_state.is_ready:
		right_state.cooldown_timer -= delta
		if right_state.cooldown_timer <= 0:
			right_state.is_ready = true
			force_power_ready.emit("right", "all")


func _check_gestures() -> void:
	if left_controller:
		_check_hand_gesture("left", left_controller, left_state)
	if right_controller:
		_check_hand_gesture("right", right_controller, right_state)


func _check_hand_gesture(hand: String, controller: XRController3D, state: HandState) -> void:
	if not state.is_ready:
		return

	var frame := MovementTracker.get_current_frame()
	if frame == null:
		return

	var velocity: Vector3
	var position: Vector3
	var grip: float

	if hand == "left":
		velocity = frame.left_velocity
		position = frame.left_position
		grip = frame.left_grip
	else:
		velocity = frame.right_velocity
		position = frame.right_position
		grip = frame.right_grip

	# Grip must be held for Force powers
	if grip < 0.7:
		state.is_gesture_active = false
		return

	var speed := velocity.length()
	var direction := velocity.normalized() if speed > 0.1 else Vector3.ZERO

	# Check for push (forward thrust)
	if speed > thrust_velocity_threshold and direction.z < -0.5:
		_execute_push(hand, controller, direction, speed, state)

	# Check for pull (backward motion with palm forward)
	elif speed > pull_velocity_threshold and direction.z > 0.5:
		_execute_pull(hand, controller, -direction, speed, state)


func _execute_push(hand: String, controller: XRController3D, direction: Vector3, speed: float, state: HandState) -> void:
	state.is_ready = false
	state.cooldown_timer = cooldown

	var power := clamp((speed - thrust_velocity_threshold) / 3.0, 0.5, 1.5)
	var force_direction := -controller.global_transform.basis.z  # Forward from controller

	# Find targets in range
	var targets := _find_targets_in_cone(controller.global_position, force_direction, force_range, 45.0)

	for target in targets:
		_apply_force_to_target(target, force_direction * push_force * power)

	# Spawn effect
	_spawn_push_effect(controller.global_position, force_direction)

	# Haptic feedback
	controller.trigger_haptic_pulse("haptic", 60.0, 0.8, 0.2, 0.0)

	force_push_activated.emit(hand, force_direction, power)


func _execute_pull(hand: String, controller: XRController3D, direction: Vector3, speed: float, state: HandState) -> void:
	state.is_ready = false
	state.cooldown_timer = cooldown

	var power := clamp((speed - pull_velocity_threshold) / 2.0, 0.5, 1.5)
	var pull_direction := -controller.global_transform.basis.z

	# Find targets
	var targets := _find_targets_in_cone(controller.global_position, pull_direction, force_range, 30.0)

	for target in targets:
		var to_hand := controller.global_position - target.global_position
		_apply_force_to_target(target, to_hand.normalized() * pull_force * power)

	# Spawn effect
	_spawn_pull_effect(controller.global_position, pull_direction)

	# Haptic
	controller.trigger_haptic_pulse("haptic", 40.0, 0.6, 0.3, 0.0)

	force_pull_activated.emit(hand, pull_direction, power)


func _find_targets_in_cone(origin: Vector3, direction: Vector3, range_dist: float, angle_deg: float) -> Array[Node3D]:
	var targets: Array[Node3D] = []

	# Get all physics bodies in range
	var space := get_world_3d().direct_space_state
	var shape := SphereShape3D.new()
	shape.radius = range_dist

	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = Transform3D.IDENTITY.translated(origin)
	query.collision_mask = 4 | 8  # Enemies and physics objects

	var results := space.intersect_shape(query, 32)

	var cos_angle := cos(deg_to_rad(angle_deg))

	for result in results:
		var collider: Node3D = result.get("collider")
		if collider == null:
			continue

		var to_target := (collider.global_position - origin).normalized()
		var dot := direction.dot(to_target)

		if dot >= cos_angle:
			targets.append(collider)

	return targets


func _apply_force_to_target(target: Node3D, force: Vector3) -> void:
	if target is RigidBody3D:
		target.apply_central_impulse(force)
	elif target.has_method("apply_force"):
		target.apply_force(force)
	elif target is TrainingTarget:
		# Push targets take damage
		target.take_damage(force.length() * 2.0, target.global_position)


func _setup_effects() -> void:
	# Push effect particles
	push_particles = GPUParticles3D.new()
	push_particles.name = "PushParticles"
	push_particles.emitting = false
	push_particles.one_shot = true
	push_particles.amount = 50
	push_particles.lifetime = 0.5
	push_particles.explosiveness = 0.9

	var push_mat := ParticleProcessMaterial.new()
	push_mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	push_mat.emission_sphere_radius = 0.1
	push_mat.direction = Vector3(0, 0, -1)
	push_mat.spread = 30.0
	push_mat.initial_velocity_min = 8.0
	push_mat.initial_velocity_max = 12.0
	push_mat.gravity = Vector3.ZERO
	push_mat.scale_min = 0.02
	push_mat.scale_max = 0.05
	push_mat.color = effect_color

	push_particles.process_material = push_mat
	add_child(push_particles)

	# Pull effect (reverse direction)
	pull_particles = push_particles.duplicate()
	pull_particles.name = "PullParticles"
	var pull_mat: ParticleProcessMaterial = pull_particles.process_material.duplicate()
	pull_mat.direction = Vector3(0, 0, 1)
	pull_particles.process_material = pull_mat
	add_child(pull_particles)


func _spawn_push_effect(position: Vector3, direction: Vector3) -> void:
	push_particles.global_position = position
	push_particles.global_transform = push_particles.global_transform.looking_at(position + direction, Vector3.UP)
	push_particles.restart()
	push_particles.emitting = true


func _spawn_pull_effect(position: Vector3, direction: Vector3) -> void:
	pull_particles.global_position = position + direction * 3.0
	pull_particles.global_transform = pull_particles.global_transform.looking_at(position, Vector3.UP)
	pull_particles.restart()
	pull_particles.emitting = true

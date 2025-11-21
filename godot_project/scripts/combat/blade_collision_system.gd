## BladeCollisionSystem - Physics-based lightsaber collision detection
## Handles blade-to-blade clashes, deflections, and environmental interactions
class_name BladeCollisionSystem
extends Node3D

signal blade_clash(point: Vector3, velocity: float, other_blade: Node3D)
signal blade_deflection(projectile: Node3D, deflect_direction: Vector3)
signal blade_hit_surface(point: Vector3, normal: Vector3, surface_type: int)
signal blade_entered_target(target: Node3D, entry_point: Vector3, velocity: Vector3)
signal blade_exited_target(target: Node3D, exit_point: Vector3)

enum SurfaceType { DEFAULT, METAL, WOOD, FLESH, ENERGY, FORCE_FIELD }

## Blade configuration
@export var blade_length: float = 1.0
@export var blade_radius: float = 0.02
@export var collision_segments: int = 8
@export var deflection_angle_threshold: float = 45.0  # Degrees

## Physics settings
@export var clash_velocity_threshold: float = 2.0
@export var deflection_force_multiplier: float = 1.5
@export var surface_penetration_depth: float = 0.05

## References
var blade_base: Node3D
var blade_tip: Node3D

## Collision state
var previous_positions: Array[Vector3] = []
var current_positions: Array[Vector3] = []
var segment_velocities: Array[Vector3] = []

## Active collisions
var active_target_collisions: Dictionary = {}  # target -> entry data

## Ray cast queries
var space_state: PhysicsDirectSpaceState3D

## Collision layers
const LAYER_BLADE := 1
const LAYER_TARGET := 2
const LAYER_PROJECTILE := 4
const LAYER_ENVIRONMENT := 8
const LAYER_BLADE_OTHER := 16


func _ready() -> void:
	# Initialize position arrays
	previous_positions.resize(collision_segments + 1)
	current_positions.resize(collision_segments + 1)
	segment_velocities.resize(collision_segments + 1)

	for i in range(collision_segments + 1):
		previous_positions[i] = Vector3.ZERO
		current_positions[i] = Vector3.ZERO
		segment_velocities[i] = Vector3.ZERO


func setup(base: Node3D, tip: Node3D) -> void:
	blade_base = base
	blade_tip = tip


func _physics_process(delta: float) -> void:
	if blade_base == null or blade_tip == null:
		return

	space_state = get_world_3d().direct_space_state
	if space_state == null:
		return

	_update_segment_positions(delta)
	_check_collisions(delta)


func _update_segment_positions(delta: float) -> void:
	var base_pos := blade_base.global_position
	var tip_pos := blade_tip.global_position
	var blade_dir := (tip_pos - base_pos).normalized()

	for i in range(collision_segments + 1):
		var t := float(i) / collision_segments
		var segment_pos := base_pos.lerp(tip_pos, t)

		# Store previous position
		previous_positions[i] = current_positions[i]
		current_positions[i] = segment_pos

		# Calculate velocity
		if delta > 0:
			segment_velocities[i] = (current_positions[i] - previous_positions[i]) / delta


func _check_collisions(delta: float) -> void:
	for i in range(collision_segments + 1):
		var from := previous_positions[i]
		var to := current_positions[i]
		var velocity := segment_velocities[i]

		if from.is_equal_approx(Vector3.ZERO):
			continue  # Skip first frame

		# Cast ray from previous to current position
		var query := PhysicsRayQueryParameters3D.create(from, to)
		query.collision_mask = LAYER_TARGET | LAYER_PROJECTILE | LAYER_ENVIRONMENT | LAYER_BLADE_OTHER
		query.collide_with_areas = true

		var result := space_state.intersect_ray(query)

		if result.is_empty():
			continue

		var collider := result["collider"]
		var point: Vector3 = result["position"]
		var normal: Vector3 = result["normal"]

		_handle_collision(collider, point, normal, velocity, i)


func _handle_collision(collider: Node, point: Vector3, normal: Vector3, velocity: Vector3, segment: int) -> void:
	var speed := velocity.length()

	# Check collision type
	if collider.is_in_group("blade"):
		_handle_blade_clash(collider, point, velocity, speed)

	elif collider.is_in_group("projectile"):
		_handle_projectile_deflection(collider, point, normal, velocity)

	elif collider.is_in_group("target"):
		_handle_target_collision(collider, point, velocity, segment)

	elif collider.is_in_group("environment"):
		_handle_environment_collision(collider, point, normal, velocity)


func _handle_blade_clash(other_blade: Node, point: Vector3, velocity: Vector3, speed: float) -> void:
	if speed < clash_velocity_threshold:
		return

	blade_clash.emit(point, speed, other_blade)

	# Apply haptic feedback based on clash intensity
	var intensity := clampf(speed / 10.0, 0.3, 1.0)
	GameEvents.haptic_feedback.emit(
		XRInputManager.Hand.RIGHT,  # Assume right hand for now
		HapticPatterns.BLADE_CLASH,
		intensity
	)

	# Spawn clash effect
	GameEvents.vfx_requested.emit("blade_clash", point, velocity.normalized())


func _handle_projectile_deflection(projectile: Node, point: Vector3, normal: Vector3, blade_velocity: Vector3) -> void:
	# Calculate deflection direction
	var incoming_dir := Vector3.ZERO

	if projectile.has_method("get_velocity"):
		var proj_vel: Vector3 = projectile.get_velocity()
		incoming_dir = proj_vel.normalized()

	# Reflect based on blade angle and velocity
	var blade_normal := _get_blade_normal_at_point(point)
	var deflect_dir := incoming_dir.bounce(blade_normal)

	# Add blade velocity influence
	deflect_dir = deflect_dir.lerp(blade_velocity.normalized(), 0.3).normalized()

	# Check if deflection angle is valid
	var deflect_angle := rad_to_deg(acos(incoming_dir.dot(-deflect_dir)))
	if deflect_angle < deflection_angle_threshold:
		# Too shallow, projectile passes through
		return

	blade_deflection.emit(projectile, deflect_dir)

	# Apply deflection to projectile
	if projectile.has_method("deflect"):
		var deflect_speed: float = projectile.get_velocity().length() * deflection_force_multiplier
		projectile.deflect(deflect_dir * deflect_speed)

	# Haptic feedback
	GameEvents.haptic_feedback.emit(
		XRInputManager.Hand.RIGHT,
		HapticPatterns.DEFLECTION,
		0.8
	)


func _handle_target_collision(target: Node, point: Vector3, velocity: Vector3, segment: int) -> void:
	if not active_target_collisions.has(target):
		# New entry
		active_target_collisions[target] = {
			"entry_point": point,
			"entry_velocity": velocity,
			"entry_segment": segment,
			"entry_time": Time.get_ticks_msec()
		}

		blade_entered_target.emit(target, point, velocity)

		# Trigger target hit
		if target.has_method("on_blade_hit"):
			target.on_blade_hit(point, velocity)

		# Haptic feedback
		GameEvents.haptic_feedback.emit(
			XRInputManager.Hand.RIGHT,
			HapticPatterns.BLADE_HIT,
			clampf(velocity.length() / 8.0, 0.4, 1.0)
		)


func _check_target_exits() -> void:
	var to_remove: Array[Node] = []

	for target in active_target_collisions:
		if not is_instance_valid(target):
			to_remove.append(target)
			continue

		# Check if blade has exited target
		var entry_data: Dictionary = active_target_collisions[target]
		var time_in_target := Time.get_ticks_msec() - entry_data["entry_time"]

		# Simple exit detection: if we've been "in" target for a while without continuous contact
		if time_in_target > 100:  # 100ms
			# Check if any segment is still in target bounds
			var still_inside := false

			if target.has_method("contains_point"):
				for pos in current_positions:
					if target.contains_point(pos):
						still_inside = true
						break

			if not still_inside:
				to_remove.append(target)
				var exit_point := current_positions[entry_data["entry_segment"]]
				blade_exited_target.emit(target, exit_point)

	for target in to_remove:
		active_target_collisions.erase(target)


func _handle_environment_collision(surface: Node, point: Vector3, normal: Vector3, velocity: Vector3) -> void:
	var surface_type := SurfaceType.DEFAULT

	if surface.has_meta("surface_type"):
		surface_type = surface.get_meta("surface_type")
	elif surface.is_in_group("metal"):
		surface_type = SurfaceType.METAL
	elif surface.is_in_group("wood"):
		surface_type = SurfaceType.WOOD

	blade_hit_surface.emit(point, normal, surface_type)

	# Different effects based on surface
	match surface_type:
		SurfaceType.METAL:
			GameEvents.vfx_requested.emit("sparks", point, normal)
			GameEvents.sfx_requested.emit("blade_metal", point)
		SurfaceType.WOOD:
			GameEvents.vfx_requested.emit("burn_wood", point, normal)
			GameEvents.sfx_requested.emit("blade_wood", point)
		SurfaceType.ENERGY:
			GameEvents.vfx_requested.emit("energy_clash", point, normal)
		_:
			GameEvents.vfx_requested.emit("blade_contact", point, normal)


func _get_blade_normal_at_point(point: Vector3) -> Vector3:
	if blade_base == null or blade_tip == null:
		return Vector3.UP

	var blade_dir := (blade_tip.global_position - blade_base.global_position).normalized()

	# Get perpendicular to blade direction
	var up := Vector3.UP
	if abs(blade_dir.dot(up)) > 0.9:
		up = Vector3.RIGHT

	return blade_dir.cross(up).normalized()


## Get the current blade velocity at a normalized position (0=base, 1=tip)
func get_velocity_at(t: float) -> Vector3:
	var index := int(t * collision_segments)
	index = clampi(index, 0, collision_segments)
	return segment_velocities[index]


## Get average blade velocity
func get_average_velocity() -> Vector3:
	var sum := Vector3.ZERO
	for vel in segment_velocities:
		sum += vel
	return sum / segment_velocities.size()


## Get max blade velocity (usually at tip)
func get_max_velocity() -> float:
	var max_vel := 0.0
	for vel in segment_velocities:
		max_vel = maxf(max_vel, vel.length())
	return max_vel


## Check if blade is moving fast enough for effective strikes
func is_striking() -> bool:
	return get_max_velocity() > clash_velocity_threshold


## Perform a sphere cast along the blade for broader collision detection
func sphere_cast_blade(radius: float, mask: int) -> Array[Dictionary]:
	var results: Array[Dictionary] = []

	if space_state == null:
		return results

	for i in range(collision_segments):
		var from := current_positions[i]
		var to := current_positions[i + 1]

		var shape := SphereShape3D.new()
		shape.radius = radius

		var params := PhysicsShapeQueryParameters3D.new()
		params.shape = shape
		params.collision_mask = mask
		params.transform = Transform3D(Basis(), from)

		var hits := space_state.intersect_shape(params, 4)
		for hit in hits:
			if not results.has(hit):
				results.append(hit)

	return results

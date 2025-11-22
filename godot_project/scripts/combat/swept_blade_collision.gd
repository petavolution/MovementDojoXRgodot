## SweptBladeCollision - Continuous Collision Detection for lightsaber blade
## Prevents fast-moving blade from passing through objects (tunneling)
class_name SweptBladeCollision
extends Node3D

signal collision_detected(collision: BladeCollision)
signal slice_started(entry_point: Vector3, entry_normal: Vector3)
signal slice_completed(exit_point: Vector3, slice_plane: Plane)

## Collision data
class BladeCollision:
	var point: Vector3 = Vector3.ZERO
	var normal: Vector3 = Vector3.ZERO
	var velocity: Vector3 = Vector3.ZERO
	var speed: float = 0.0
	var collider: Node3D
	var blade_segment: int = 0
	var time_of_impact: float = 0.0
	var is_entry: bool = true


## Blade configuration
@export var blade_length: float = 1.0
@export var blade_radius: float = 0.025
@export var segments: int = 10
@export var enable_ccd: bool = true

## Physics
@export var collision_mask: int = 0xFFFFFFFF
@export var min_velocity_for_ccd: float = 1.0  # Only use CCD above this speed

## State
var blade_base: Node3D
var blade_tip: Node3D
var is_active: bool = false

## Position history for swept collision
var prev_base_pos: Vector3 = Vector3.ZERO
var prev_tip_pos: Vector3 = Vector3.ZERO
var prev_segment_positions: Array[Vector3] = []

## Current frame
var curr_base_pos: Vector3 = Vector3.ZERO
var curr_tip_pos: Vector3 = Vector3.ZERO
var curr_segment_positions: Array[Vector3] = []

## Velocity
var base_velocity: Vector3 = Vector3.ZERO
var tip_velocity: Vector3 = Vector3.ZERO
var segment_velocities: Array[Vector3] = []
var max_velocity: float = 0.0

## Active slice tracking
var is_slicing: bool = false
var slice_entry_point: Vector3 = Vector3.ZERO
var slice_entry_normal: Vector3 = Vector3.ZERO
var slice_collider: Node3D

## Physics space
var space_state: PhysicsDirectSpaceState3D

## Debug visualization
@export var debug_draw: bool = false
var debug_mesh: ImmediateMesh


func _ready() -> void:
	prev_segment_positions.resize(segments + 1)
	curr_segment_positions.resize(segments + 1)
	segment_velocities.resize(segments + 1)

	for i in range(segments + 1):
		prev_segment_positions[i] = Vector3.ZERO
		curr_segment_positions[i] = Vector3.ZERO
		segment_velocities[i] = Vector3.ZERO

	if debug_draw:
		_setup_debug_visualization()


func setup(base: Node3D, tip: Node3D) -> void:
	blade_base = base
	blade_tip = tip


func activate() -> void:
	is_active = true
	_initialize_positions()


func deactivate() -> void:
	is_active = false
	is_slicing = false


func _physics_process(delta: float) -> void:
	if not is_active or blade_base == null:
		return

	space_state = get_world_3d().direct_space_state
	if space_state == null:
		return

	_update_positions(delta)
	_perform_collision_detection(delta)

	if debug_draw:
		_update_debug_visualization()


func _initialize_positions() -> void:
	if blade_base == null:
		return

	curr_base_pos = blade_base.global_position
	curr_tip_pos = blade_tip.global_position if blade_tip else curr_base_pos + Vector3(0, blade_length, 0)

	_calculate_segment_positions(curr_segment_positions, curr_base_pos, curr_tip_pos)

	# Initialize previous to current (no movement on first frame)
	prev_base_pos = curr_base_pos
	prev_tip_pos = curr_tip_pos

	for i in range(segments + 1):
		prev_segment_positions[i] = curr_segment_positions[i]


func _update_positions(delta: float) -> void:
	# Store previous
	prev_base_pos = curr_base_pos
	prev_tip_pos = curr_tip_pos

	for i in range(segments + 1):
		prev_segment_positions[i] = curr_segment_positions[i]

	# Get current
	curr_base_pos = blade_base.global_position
	curr_tip_pos = blade_tip.global_position if blade_tip else curr_base_pos + blade_base.global_transform.basis.y * blade_length

	_calculate_segment_positions(curr_segment_positions, curr_base_pos, curr_tip_pos)

	# Calculate velocities
	if delta > 0:
		base_velocity = (curr_base_pos - prev_base_pos) / delta
		tip_velocity = (curr_tip_pos - prev_tip_pos) / delta

		max_velocity = 0.0
		for i in range(segments + 1):
			segment_velocities[i] = (curr_segment_positions[i] - prev_segment_positions[i]) / delta
			max_velocity = maxf(max_velocity, segment_velocities[i].length())


func _calculate_segment_positions(out_positions: Array[Vector3], base: Vector3, tip: Vector3) -> void:
	for i in range(segments + 1):
		var t := float(i) / segments
		out_positions[i] = base.lerp(tip, t)


func _perform_collision_detection(delta: float) -> void:
	# Use CCD only if moving fast enough
	if enable_ccd and max_velocity >= min_velocity_for_ccd:
		_swept_collision_detection(delta)
	else:
		_discrete_collision_detection()


func _discrete_collision_detection() -> void:
	# Standard point-based collision for slow movements
	for i in range(segments):
		var from := curr_segment_positions[i]
		var to := curr_segment_positions[i + 1]

		var query := PhysicsRayQueryParameters3D.create(from, to)
		query.collision_mask = collision_mask

		var result := space_state.intersect_ray(query)
		if not result.is_empty():
			var collision := BladeCollision.new()
			collision.point = result.position
			collision.normal = result.normal
			collision.collider = result.collider
			collision.blade_segment = i
			collision.velocity = segment_velocities[i]
			collision.speed = segment_velocities[i].length()

			collision_detected.emit(collision)
			_handle_potential_slice(collision)


func _swept_collision_detection(delta: float) -> void:
	# Continuous collision detection using swept shapes
	for i in range(segments + 1):
		var prev_pos := prev_segment_positions[i]
		var curr_pos := curr_segment_positions[i]

		# Skip if didn't move significantly
		if prev_pos.distance_squared_to(curr_pos) < 0.0001:
			continue

		# Cast sphere along movement path
		var collision := _sphere_cast(prev_pos, curr_pos, blade_radius, i)
		if collision != null:
			collision_detected.emit(collision)
			_handle_potential_slice(collision)

	# Also check the blade surface (triangles between segments)
	_check_swept_surface()


func _sphere_cast(from: Vector3, to: Vector3, radius: float, segment: int) -> BladeCollision:
	# Create sphere shape
	var shape := SphereShape3D.new()
	shape.radius = radius

	var params := PhysicsShapeQueryParameters3D.new()
	params.shape = shape
	params.collision_mask = collision_mask
	params.transform = Transform3D(Basis(), from)

	# Motion vector
	var motion := to - from

	# Cast the shape
	var results := space_state.cast_motion(params, motion)

	if results[0] < 1.0:  # Collision occurred
		# Find exact contact point
		var contact_pos := from + motion * results[0]

		# Do a ray cast to get normal
		var ray_query := PhysicsRayQueryParameters3D.create(from, contact_pos + motion.normalized() * radius * 2)
		ray_query.collision_mask = collision_mask

		var ray_result := space_state.intersect_ray(ray_query)

		var collision := BladeCollision.new()
		collision.point = contact_pos
		collision.blade_segment = segment
		collision.time_of_impact = results[0]
		collision.velocity = segment_velocities[segment]
		collision.speed = segment_velocities[segment].length()

		if not ray_result.is_empty():
			collision.normal = ray_result.normal
			collision.collider = ray_result.collider
			collision.point = ray_result.position

		return collision

	return null


func _check_swept_surface() -> void:
	# Check for collisions on the surface swept by the blade
	# This catches objects that pass between segments

	for i in range(segments):
		# Create a quad from previous and current segment positions
		var p0 := prev_segment_positions[i]
		var p1 := prev_segment_positions[i + 1]
		var p2 := curr_segment_positions[i + 1]
		var p3 := curr_segment_positions[i]

		# Calculate the center and normal of this swept quad
		var center := (p0 + p1 + p2 + p3) / 4.0
		var edge1 := p1 - p0
		var edge2 := p3 - p0
		var normal := edge1.cross(edge2).normalized()

		# Check for objects passing through this surface
		# Use the convex hull formed by the 4 points

		var points: PackedVector3Array = PackedVector3Array([p0, p1, p2, p3])

		# Simplified: cast rays through the center
		var ray_dirs := [normal, -normal]
		for dir in ray_dirs:
			var query := PhysicsRayQueryParameters3D.create(center, center + dir * blade_radius * 2)
			query.collision_mask = collision_mask

			var result := space_state.intersect_ray(query)
			if not result.is_empty():
				var collision := BladeCollision.new()
				collision.point = result.position
				collision.normal = result.normal
				collision.collider = result.collider
				collision.blade_segment = i
				collision.velocity = (segment_velocities[i] + segment_velocities[i + 1]) / 2.0
				collision.speed = collision.velocity.length()

				collision_detected.emit(collision)
				_handle_potential_slice(collision)
				break


func _handle_potential_slice(collision: BladeCollision) -> void:
	if collision.collider == null:
		return

	# Check if this collider is sliceable
	if not collision.collider.is_in_group("sliceable"):
		return

	if not is_slicing:
		# Start a new slice
		is_slicing = true
		slice_collider = collision.collider
		slice_entry_point = collision.point
		slice_entry_normal = collision.normal
		collision.is_entry = true

		slice_started.emit(slice_entry_point, slice_entry_normal)
	else:
		# Check if we've exited the object
		if collision.collider == slice_collider:
			# Still inside or re-entering
			pass
		else:
			# Exited to a different object or air
			_complete_slice(collision.point)


func _complete_slice(exit_point: Vector3) -> void:
	if not is_slicing:
		return

	# Calculate slice plane
	var slice_direction := (exit_point - slice_entry_point).normalized()
	var blade_direction := (curr_tip_pos - curr_base_pos).normalized()
	var slice_normal := slice_direction.cross(blade_direction).normalized()

	var slice_plane := Plane(slice_normal, slice_entry_point)

	slice_completed.emit(exit_point, slice_plane)

	# Notify the sliceable object
	if is_instance_valid(slice_collider) and slice_collider.has_method("on_sliced"):
		slice_collider.on_sliced(slice_plane, slice_entry_point, exit_point)

	is_slicing = false
	slice_collider = null


func _process(_delta: float) -> void:
	# Check if we've exited a slice without hitting another object
	if is_slicing and slice_collider != null:
		# Ray cast to see if we're still inside
		var center := (curr_base_pos + curr_tip_pos) / 2.0
		var query := PhysicsRayQueryParameters3D.create(center, center + Vector3(0.001, 0, 0))
		query.collision_mask = collision_mask

		if space_state:
			var result := space_state.intersect_ray(query)
			if result.is_empty() or result.collider != slice_collider:
				_complete_slice(center)


func _setup_debug_visualization() -> void:
	debug_mesh = ImmediateMesh.new()
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.mesh = debug_mesh

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1, 0, 0, 0.5)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.no_depth_test = true
	mesh_instance.material_override = mat

	add_child(mesh_instance)


func _update_debug_visualization() -> void:
	if debug_mesh == null:
		return

	debug_mesh.clear_surfaces()
	debug_mesh.surface_begin(Mesh.PRIMITIVE_LINES)

	# Draw current blade
	for i in range(segments):
		debug_mesh.surface_add_vertex(curr_segment_positions[i])
		debug_mesh.surface_add_vertex(curr_segment_positions[i + 1])

	# Draw swept surface
	for i in range(segments):
		# Quad edges
		debug_mesh.surface_add_vertex(prev_segment_positions[i])
		debug_mesh.surface_add_vertex(curr_segment_positions[i])

		debug_mesh.surface_add_vertex(prev_segment_positions[i + 1])
		debug_mesh.surface_add_vertex(curr_segment_positions[i + 1])

	debug_mesh.surface_end()


## Get blade velocity at normalized position (0=base, 1=tip)
func get_velocity_at(t: float) -> Vector3:
	var index := int(t * segments)
	index = clampi(index, 0, segments)
	return segment_velocities[index]


## Get maximum blade velocity
func get_max_velocity() -> float:
	return max_velocity


## Get blade direction
func get_blade_direction() -> Vector3:
	return (curr_tip_pos - curr_base_pos).normalized()


## Check if blade is moving fast enough for effective attack
func is_attacking() -> bool:
	return max_velocity >= min_velocity_for_ccd


## Get interpolated position along blade
func get_position_at(t: float) -> Vector3:
	return curr_base_pos.lerp(curr_tip_pos, t)

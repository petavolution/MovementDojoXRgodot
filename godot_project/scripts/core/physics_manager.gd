## PhysicsManager - Abstraction layer over Godot physics
## Provides unified interface for physics queries, collision detection, and simulation
class_name PhysicsManager
extends Node

signal collision_detected(collision: CollisionInfo)
signal physics_step_completed(delta: float)

## Collision information structure
class CollisionInfo:
	var point: Vector3 = Vector3.ZERO
	var normal: Vector3 = Vector3.ZERO
	var collider: Node3D
	var collider_id: int = 0
	var velocity: Vector3 = Vector3.ZERO
	var impulse: float = 0.0
	var shape_index: int = 0

## Raycast result structure
class RaycastResult:
	var hit: bool = false
	var point: Vector3 = Vector3.ZERO
	var normal: Vector3 = Vector3.ZERO
	var collider: Node3D
	var collider_id: int = 0
	var distance: float = 0.0
	var shape_index: int = 0

## Collision layers (matching project settings)
const LAYER_DEFAULT := 1
const LAYER_PLAYER := 2
const LAYER_WEAPON := 4
const LAYER_TARGET := 8
const LAYER_ENVIRONMENT := 16
const LAYER_TRIGGER := 32
const LAYER_INTERACTABLE := 64

## Configuration
@export var physics_tick_rate: int = 90  # Hz, matches VR refresh
@export var max_queries_per_frame: int = 100
@export var enable_query_caching: bool = true
@export var cache_duration: float = 0.016  # ~1 frame at 60fps

## State
var space_state: PhysicsDirectSpaceState3D
var query_cache: Dictionary = {}
var cache_timestamps: Dictionary = {}
var queries_this_frame: int = 0

## Pre-allocated query parameters (avoid GC)
var ray_params: PhysicsRayQueryParameters3D
var shape_params: PhysicsShapeQueryParameters3D
var sphere_shape: SphereShape3D
var box_shape: BoxShape3D


func _ready() -> void:
	_initialize_query_objects()


func _physics_process(delta: float) -> void:
	# Update space state reference
	space_state = get_viewport().world_3d.direct_space_state

	# Clear query cache periodically
	_cleanup_cache()

	# Reset query counter
	queries_this_frame = 0

	physics_step_completed.emit(delta)


func _initialize_query_objects() -> void:
	# Pre-allocate commonly used objects to avoid runtime allocation
	ray_params = PhysicsRayQueryParameters3D.new()
	shape_params = PhysicsShapeQueryParameters3D.new()
	sphere_shape = SphereShape3D.new()
	box_shape = BoxShape3D.new()


## Perform a raycast
func raycast(from: Vector3, to: Vector3, mask: int = LAYER_DEFAULT, exclude: Array[RID] = []) -> RaycastResult:
	var result := RaycastResult.new()

	if space_state == null:
		return result

	if queries_this_frame >= max_queries_per_frame:
		push_warning("PhysicsManager: Max queries per frame exceeded")
		return result

	# Check cache
	var cache_key := _ray_cache_key(from, to, mask)
	if enable_query_caching and query_cache.has(cache_key):
		return query_cache[cache_key]

	# Configure ray parameters
	ray_params.from = from
	ray_params.to = to
	ray_params.collision_mask = mask
	ray_params.exclude = exclude
	ray_params.collide_with_areas = true
	ray_params.collide_with_bodies = true

	# Perform query
	var hit := space_state.intersect_ray(ray_params)
	queries_this_frame += 1

	if not hit.is_empty():
		result.hit = true
		result.point = hit.position
		result.normal = hit.normal
		result.collider = hit.collider
		result.collider_id = hit.collider_id
		result.distance = from.distance_to(hit.position)
		result.shape_index = hit.shape

	# Cache result
	if enable_query_caching:
		query_cache[cache_key] = result
		cache_timestamps[cache_key] = Time.get_ticks_msec()

	return result


## Perform multiple raycasts (batch query)
func raycast_batch(rays: Array[Dictionary]) -> Array[RaycastResult]:
	var results: Array[RaycastResult] = []

	for ray in rays:
		var from: Vector3 = ray.get("from", Vector3.ZERO)
		var to: Vector3 = ray.get("to", Vector3.ZERO)
		var mask: int = ray.get("mask", LAYER_DEFAULT)
		results.append(raycast(from, to, mask))

	return results


## Sphere cast (swept sphere collision)
func sphere_cast(from: Vector3, to: Vector3, radius: float, mask: int = LAYER_DEFAULT) -> RaycastResult:
	var result := RaycastResult.new()

	if space_state == null:
		return result

	if queries_this_frame >= max_queries_per_frame:
		return result

	# Configure sphere shape
	sphere_shape.radius = radius

	# Configure shape parameters
	shape_params.shape = sphere_shape
	shape_params.transform = Transform3D(Basis(), from)
	shape_params.collision_mask = mask
	shape_params.collide_with_areas = true
	shape_params.collide_with_bodies = true

	var motion := to - from

	# Cast motion
	var cast_result := space_state.cast_motion(shape_params, motion)
	queries_this_frame += 1

	if cast_result[0] < 1.0:  # Hit something
		result.hit = true
		result.point = from + motion * cast_result[0]
		result.distance = motion.length() * cast_result[0]

		# Get collision details with shape query at contact point
		shape_params.transform.origin = result.point
		var contacts := space_state.get_rest_info(shape_params)
		if not contacts.is_empty():
			result.normal = contacts.normal
			result.collider_id = contacts.collider_id
			result.collider = instance_from_id(contacts.collider_id) as Node3D

	return result


## Box cast
func box_cast(from: Vector3, to: Vector3, half_extents: Vector3, rotation: Basis = Basis.IDENTITY, mask: int = LAYER_DEFAULT) -> RaycastResult:
	var result := RaycastResult.new()

	if space_state == null:
		return result

	# Configure box shape
	box_shape.size = half_extents * 2.0

	# Configure shape parameters
	shape_params.shape = box_shape
	shape_params.transform = Transform3D(rotation, from)
	shape_params.collision_mask = mask

	var motion := to - from

	# Cast motion
	var cast_result := space_state.cast_motion(shape_params, motion)
	queries_this_frame += 1

	if cast_result[0] < 1.0:
		result.hit = true
		result.point = from + motion * cast_result[0]
		result.distance = motion.length() * cast_result[0]

	return result


## Check sphere overlap
func overlap_sphere(center: Vector3, radius: float, mask: int = LAYER_DEFAULT, max_results: int = 32) -> Array[Node3D]:
	var results: Array[Node3D] = []

	if space_state == null:
		return results

	sphere_shape.radius = radius
	shape_params.shape = sphere_shape
	shape_params.transform = Transform3D(Basis(), center)
	shape_params.collision_mask = mask

	var collisions := space_state.intersect_shape(shape_params, max_results)
	queries_this_frame += 1

	for collision in collisions:
		var collider := instance_from_id(collision.collider_id) as Node3D
		if collider:
			results.append(collider)

	return results


## Check box overlap
func overlap_box(center: Vector3, half_extents: Vector3, rotation: Basis = Basis.IDENTITY, mask: int = LAYER_DEFAULT, max_results: int = 32) -> Array[Node3D]:
	var results: Array[Node3D] = []

	if space_state == null:
		return results

	box_shape.size = half_extents * 2.0
	shape_params.shape = box_shape
	shape_params.transform = Transform3D(rotation, center)
	shape_params.collision_mask = mask

	var collisions := space_state.intersect_shape(shape_params, max_results)
	queries_this_frame += 1

	for collision in collisions:
		var collider := instance_from_id(collision.collider_id) as Node3D
		if collider:
			results.append(collider)

	return results


## Point collision check
func point_check(point: Vector3, mask: int = LAYER_DEFAULT) -> Array[Node3D]:
	var results: Array[Node3D] = []

	if space_state == null:
		return results

	var params := PhysicsPointQueryParameters3D.new()
	params.position = point
	params.collision_mask = mask
	params.collide_with_areas = true
	params.collide_with_bodies = true

	var collisions := space_state.intersect_point(params)
	queries_this_frame += 1

	for collision in collisions:
		var collider := instance_from_id(collision.collider_id) as Node3D
		if collider:
			results.append(collider)

	return results


## Get closest point on collider surface
func get_closest_point(from: Vector3, to_collider: CollisionObject3D) -> Vector3:
	if to_collider == null:
		return from

	# Raycast towards collider center
	var target := to_collider.global_position
	var result := raycast(from, target)

	if result.hit:
		return result.point

	return target


## Calculate impact force from collision
func calculate_impact_force(velocity: Vector3, mass: float, collision_normal: Vector3) -> float:
	var impact_velocity := absf(velocity.dot(collision_normal))
	return impact_velocity * mass


## Predictive collision check (for fast-moving objects)
func predictive_collision(current_pos: Vector3, velocity: Vector3, delta: float, radius: float, mask: int = LAYER_DEFAULT) -> RaycastResult:
	var future_pos := current_pos + velocity * delta
	return sphere_cast(current_pos, future_pos, radius, mask)


## Line of sight check
func has_line_of_sight(from: Vector3, to: Vector3, mask: int = LAYER_ENVIRONMENT) -> bool:
	var result := raycast(from, to, mask)
	return not result.hit or result.distance >= from.distance_to(to) - 0.01


## Find nearest collider in direction
func find_nearest_in_direction(from: Vector3, direction: Vector3, max_distance: float, mask: int = LAYER_DEFAULT) -> RaycastResult:
	var to := from + direction.normalized() * max_distance
	return raycast(from, to, mask)


## Get all colliders in cone
func cone_cast(origin: Vector3, direction: Vector3, max_distance: float, cone_angle: float, mask: int = LAYER_DEFAULT, ray_count: int = 8) -> Array[Node3D]:
	var results: Array[Node3D] = []
	var found_ids: Array[int] = []

	# Cast rays in a cone pattern
	var angle_rad := deg_to_rad(cone_angle)
	var right := direction.cross(Vector3.UP).normalized()
	if right.length() < 0.1:
		right = direction.cross(Vector3.FORWARD).normalized()
	var up := right.cross(direction).normalized()

	for i in range(ray_count):
		var ring_angle := TAU * float(i) / ray_count
		for j in range(3):  # Multiple rings
			var ring_spread := angle_rad * float(j + 1) / 3.0
			var offset_dir := (right * cos(ring_angle) + up * sin(ring_angle)) * sin(ring_spread)
			var ray_dir := (direction + offset_dir).normalized()

			var result := raycast(origin, origin + ray_dir * max_distance, mask)
			if result.hit and result.collider_id not in found_ids:
				found_ids.append(result.collider_id)
				results.append(result.collider)

	return results


## Cache management
func _ray_cache_key(from: Vector3, to: Vector3, mask: int) -> String:
	return "%s_%s_%d" % [from, to, mask]


func _cleanup_cache() -> void:
	if not enable_query_caching:
		return

	var current_time := Time.get_ticks_msec()
	var expired_keys: Array[String] = []

	for key in cache_timestamps:
		if current_time - cache_timestamps[key] > cache_duration * 1000:
			expired_keys.append(key)

	for key in expired_keys:
		query_cache.erase(key)
		cache_timestamps.erase(key)


## Clear all cached queries
func clear_cache() -> void:
	query_cache.clear()
	cache_timestamps.clear()


## Get physics statistics
func get_stats() -> Dictionary:
	return {
		"queries_this_frame": queries_this_frame,
		"max_queries": max_queries_per_frame,
		"cache_entries": query_cache.size(),
		"cache_enabled": enable_query_caching
	}

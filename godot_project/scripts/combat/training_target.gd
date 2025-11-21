## TrainingTarget - Destructible target for lightsaber training
## Can be a stationary target or moving droid
extends Node3D
class_name TrainingTarget

signal destroyed(target: TrainingTarget, position: Vector3)
signal hit(damage: float, position: Vector3)

@export_group("Target Properties")
@export var max_health := 100.0
@export var target_type := TargetType.STATIONARY
@export var point_value := 10

@export_group("Movement (for MOVING type)")
@export var movement_speed := 1.0
@export var movement_range := 2.0
@export var hover_height := 1.5

@export_group("Appearance")
@export var target_color := Color(1.0, 0.3, 0.1)
@export var hit_flash_color := Color(1.0, 1.0, 1.0)
@export var target_radius := 0.15

enum TargetType {
	STATIONARY,
	MOVING,
	PROJECTILE_LAUNCHER
}

# State
var current_health: float
var is_destroyed := false
var _flash_timer := 0.0
var _original_position := Vector3.ZERO
var _movement_phase := 0.0

# Nodes
var mesh: MeshInstance3D
var collision_body: StaticBody3D
var hit_area: Area3D
var material: StandardMaterial3D


func _ready() -> void:
	current_health = max_health
	_original_position = position

	_setup_mesh()
	_setup_collision()

	# Random movement phase for variety
	_movement_phase = randf() * TAU


func _process(delta: float) -> void:
	if is_destroyed:
		return

	# Flash effect
	if _flash_timer > 0:
		_flash_timer -= delta
		var flash_amount := _flash_timer / 0.1
		material.albedo_color = target_color.lerp(hit_flash_color, flash_amount)
		material.emission = hit_flash_color * flash_amount * 2.0
	else:
		material.emission = Color.BLACK

	# Movement for moving targets
	if target_type == TargetType.MOVING:
		_update_movement(delta)


func _setup_mesh() -> void:
	mesh = MeshInstance3D.new()

	var sphere := SphereMesh.new()
	sphere.radius = target_radius
	sphere.height = target_radius * 2
	sphere.radial_segments = 16
	sphere.rings = 8

	material = StandardMaterial3D.new()
	material.albedo_color = target_color
	material.emission_enabled = true
	material.emission = Color.BLACK
	material.metallic = 0.3
	material.roughness = 0.7

	sphere.material = material
	mesh.mesh = sphere

	add_child(mesh)


func _setup_collision() -> void:
	# Static body for physical presence
	collision_body = StaticBody3D.new()
	collision_body.collision_layer = 4  # Enemy layer

	var body_shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = target_radius
	body_shape.shape = sphere
	collision_body.add_child(body_shape)

	add_child(collision_body)

	# Area for detecting lightsaber hits
	hit_area = Area3D.new()
	hit_area.collision_layer = 4
	hit_area.collision_mask = 2  # Blade layer

	var area_shape := CollisionShape3D.new()
	var area_sphere := SphereShape3D.new()
	area_sphere.radius = target_radius * 1.2
	area_shape.shape = area_sphere
	hit_area.add_child(area_shape)

	add_child(hit_area)


func _update_movement(delta: float) -> void:
	_movement_phase += delta * movement_speed

	# Figure-8 pattern
	var offset := Vector3(
		sin(_movement_phase) * movement_range,
		sin(_movement_phase * 2) * movement_range * 0.3 + hover_height,
		cos(_movement_phase) * movement_range * 0.5
	)

	position = _original_position + offset


func take_damage(damage: float, hit_position: Vector3 = Vector3.ZERO) -> void:
	if is_destroyed:
		return

	current_health -= damage
	_flash_timer = 0.1

	hit.emit(damage, hit_position)

	if current_health <= 0:
		_destroy()


func _destroy() -> void:
	is_destroyed = true

	destroyed.emit(self, global_position)

	# Spawn destruction effect
	_spawn_destruction_particles()

	# Award points
	# ScoreManager.add_points(point_value)

	# Remove after short delay
	var tween := create_tween()
	tween.tween_property(mesh, "scale", Vector3.ZERO, 0.2)
	tween.tween_callback(queue_free)


func _spawn_destruction_particles() -> void:
	var particles := GPUParticles3D.new()
	particles.emitting = true
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.amount = 20
	particles.lifetime = 0.5

	var particle_material := ParticleProcessMaterial.new()
	particle_material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	particle_material.emission_sphere_radius = target_radius
	particle_material.direction = Vector3(0, 1, 0)
	particle_material.spread = 180.0
	particle_material.initial_velocity_min = 2.0
	particle_material.initial_velocity_max = 4.0
	particle_material.gravity = Vector3(0, -5, 0)
	particle_material.scale_min = 0.02
	particle_material.scale_max = 0.05
	particle_material.color = target_color

	particles.process_material = particle_material
	particles.position = global_position

	get_tree().root.add_child(particles)

	# Auto-remove particles
	var timer := get_tree().create_timer(1.0)
	timer.timeout.connect(particles.queue_free)


## Factory method for creating targets
static func create_target(type: TargetType, pos: Vector3, color: Color = Color(1.0, 0.3, 0.1)) -> TrainingTarget:
	var target := TrainingTarget.new()
	target.target_type = type
	target.position = pos
	target.target_color = color
	return target

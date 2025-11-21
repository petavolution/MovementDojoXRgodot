## Projectile - Deflectable projectile for training
## Can be deflected by lightsaber blade
extends RigidBody3D
class_name Projectile

signal deflected(projectile: Projectile, new_direction: Vector3)
signal hit_target(target: Node3D)
signal expired()

@export var speed := 8.0
@export var damage := 20.0
@export var lifetime := 5.0
@export var can_be_deflected := true
@export var projectile_color := Color(1.0, 0.3, 0.1)

var direction := Vector3.FORWARD
var is_deflected := false
var deflection_count := 0
var max_deflections := 3
var _lifetime_timer := 0.0

var mesh: MeshInstance3D
var trail: GPUParticles3D
var collision_area: Area3D


func _ready() -> void:
	_setup_visuals()
	_setup_collision()

	gravity_scale = 0.0
	linear_damp = 0.0

	# Initial velocity
	linear_velocity = direction * speed


func _physics_process(delta: float) -> void:
	_lifetime_timer += delta
	if _lifetime_timer >= lifetime:
		_expire()


func _setup_visuals() -> void:
	mesh = MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.05
	sphere.height = 0.1

	var mat := StandardMaterial3D.new()
	mat.albedo_color = projectile_color
	mat.emission_enabled = true
	mat.emission = projectile_color
	mat.emission_energy_multiplier = 2.0
	sphere.material = mat

	mesh.mesh = sphere
	add_child(mesh)

	# Trail particles
	trail = GPUParticles3D.new()
	trail.amount = 20
	trail.lifetime = 0.3
	trail.local_coords = false

	var trail_mat := ParticleProcessMaterial.new()
	trail_mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_POINT
	trail_mat.direction = Vector3.ZERO
	trail_mat.spread = 0.0
	trail_mat.initial_velocity_min = 0.0
	trail_mat.initial_velocity_max = 0.1
	trail_mat.gravity = Vector3.ZERO
	trail_mat.scale_min = 0.03
	trail_mat.scale_max = 0.01
	trail_mat.color = projectile_color

	trail.process_material = trail_mat
	add_child(trail)


func _setup_collision() -> void:
	# Physics collision
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.05
	shape.shape = sphere
	add_child(shape)

	collision_layer = 16  # Projectile layer
	collision_mask = 1 | 2 | 4  # World, blades, enemies

	# Area for blade detection
	collision_area = Area3D.new()
	collision_area.collision_layer = 16
	collision_area.collision_mask = 2  # Blade layer

	var area_shape := CollisionShape3D.new()
	var area_sphere := SphereShape3D.new()
	area_sphere.radius = 0.08
	area_shape.shape = area_sphere
	collision_area.add_child(area_shape)

	add_child(collision_area)
	collision_area.area_entered.connect(_on_blade_contact)

	# Body collision
	body_entered.connect(_on_body_entered)


func deflect(blade_velocity: Vector3, blade_position: Vector3) -> void:
	if not can_be_deflected or deflection_count >= max_deflections:
		return

	is_deflected = true
	deflection_count += 1

	# Calculate deflection direction
	var to_blade := (blade_position - global_position).normalized()
	var reflection := direction.bounce(to_blade)

	# Add some of blade's velocity for more dynamic deflection
	var blade_influence := blade_velocity.normalized() * 0.5
	direction = (reflection + blade_influence).normalized()

	# Reverse and redirect
	linear_velocity = direction * speed * 1.2  # Slightly faster after deflection

	# Change color to indicate deflection
	var mat: StandardMaterial3D = mesh.mesh.material
	mat.albedo_color = Color(0.2, 0.8, 1.0)
	mat.emission = Color(0.2, 0.8, 1.0)

	# Change collision to hit enemies
	collision_mask = 4  # Only enemies now

	deflected.emit(self, direction)

	# Achievement
	if deflection_count == 1:
		Achievements.unlock("deflect_first")
	Achievements.add_progress("deflect_50", 1)


func _on_blade_contact(area: Area3D) -> void:
	# Check if it's a lightsaber blade
	var parent := area.get_parent()
	if parent is Lightsaber and parent.is_active:
		var frame := MovementTracker.get_current_frame()
		if frame:
			# Determine which hand's velocity to use
			var blade_vel := frame.right_velocity
			if "Left" in parent.name:
				blade_vel = frame.left_velocity

			deflect(blade_vel, area.global_position)


func _on_body_entered(body: Node) -> void:
	if body is TrainingTarget:
		body.take_damage(damage, global_position)
		hit_target.emit(body)
		_destroy()
	elif body.is_in_group("player"):
		# Player hit - could trigger damage/feedback
		_destroy()
	elif not body.is_in_group("projectile"):
		# Hit world geometry
		_destroy()


func _expire() -> void:
	expired.emit()
	queue_free()


func _destroy() -> void:
	# Spawn hit effect
	var particles := GPUParticles3D.new()
	particles.emitting = true
	particles.one_shot = true
	particles.amount = 15
	particles.lifetime = 0.3
	particles.explosiveness = 1.0

	var mat := ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	mat.emission_sphere_radius = 0.05
	mat.direction = Vector3(0, 1, 0)
	mat.spread = 180.0
	mat.initial_velocity_min = 2.0
	mat.initial_velocity_max = 4.0
	mat.gravity = Vector3(0, -5, 0)
	mat.scale_min = 0.01
	mat.scale_max = 0.03
	mat.color = projectile_color

	particles.process_material = mat
	particles.global_position = global_position

	get_tree().root.add_child(particles)

	# Auto-cleanup
	var timer := get_tree().create_timer(0.5)
	timer.timeout.connect(particles.queue_free)

	queue_free()


## Factory method
static func create_at(pos: Vector3, dir: Vector3, proj_speed: float = 8.0) -> Projectile:
	var proj := Projectile.new()
	proj.position = pos
	proj.direction = dir.normalized()
	proj.speed = proj_speed
	return proj

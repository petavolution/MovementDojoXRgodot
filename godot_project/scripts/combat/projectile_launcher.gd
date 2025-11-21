## ProjectileLauncher - Spawns projectiles aimed at player
## Used by training droids or stationary turrets
extends Node3D
class_name ProjectileLauncher

signal projectile_fired(projectile: Projectile)

@export var fire_rate := 1.0  # Projectiles per second
@export var projectile_speed := 8.0
@export var projectile_damage := 20.0
@export var aim_ahead := true  # Lead the target
@export var accuracy := 0.9  # 1.0 = perfect aim
@export var enabled := true

var target: Node3D
var _fire_timer := 0.0
var _fire_interval := 1.0


func _ready() -> void:
	_fire_interval = 1.0 / fire_rate


func _physics_process(delta: float) -> void:
	if not enabled or target == null:
		return

	_fire_timer += delta
	if _fire_timer >= _fire_interval:
		_fire_timer = 0.0
		fire()


func set_target(new_target: Node3D) -> void:
	target = new_target


func fire() -> void:
	if target == null:
		return

	var spawn_pos := global_position
	var target_pos := target.global_position

	# Lead the target if enabled
	if aim_ahead and target is CharacterBody3D:
		var target_vel := target.velocity
		var time_to_target := spawn_pos.distance_to(target_pos) / projectile_speed
		target_pos += target_vel * time_to_target * 0.5

	# Calculate direction with accuracy spread
	var direction := (target_pos - spawn_pos).normalized()

	if accuracy < 1.0:
		var spread := (1.0 - accuracy) * 0.2
		direction += Vector3(
			randf_range(-spread, spread),
			randf_range(-spread, spread),
			randf_range(-spread, spread)
		)
		direction = direction.normalized()

	# Create projectile
	var projectile := Projectile.create_at(spawn_pos, direction, projectile_speed)
	projectile.damage = projectile_damage

	get_tree().root.add_child(projectile)
	projectile_fired.emit(projectile)

## TrainingDroid - AI opponent for combat training
## Provides dynamic, adaptive challenge with various behavior patterns
class_name TrainingDroid
extends CharacterBody3D

signal droid_activated
signal droid_deactivated
signal attack_started(attack_type: String)
signal attack_completed(attack_type: String, was_blocked: bool)
signal droid_hit(damage: float, position: Vector3)
signal droid_destroyed

enum DroidState {
	INACTIVE,
	IDLE,
	APPROACHING,
	CIRCLING,
	ATTACKING,
	RECOVERING,
	RETREATING,
	STUNNED
}

enum AttackType {
	NONE,
	HORIZONTAL_LEFT,
	HORIZONTAL_RIGHT,
	VERTICAL_DOWN,
	VERTICAL_UP,
	DIAGONAL_LEFT,
	DIAGONAL_RIGHT,
	THRUST,
	SPIN
}

## Configuration
@export var max_health: float = 100.0
@export var move_speed: float = 2.0
@export var attack_range: float = 1.5
@export var attack_cooldown: float = 2.0
@export var difficulty: float = 0.5  # 0-1

## State
var current_state: DroidState = DroidState.INACTIVE
var health: float = 100.0
var is_active: bool = false

## Combat
var current_attack: AttackType = AttackType.NONE
var attack_timer: float = 0.0
var recovery_timer: float = 0.0
var stun_timer: float = 0.0

## Movement
var target_position: Vector3 = Vector3.ZERO
var orbit_angle: float = 0.0
var orbit_direction: int = 1

## References
var player_head: Node3D
var player_left_hand: Node3D
var player_right_hand: Node3D

## Visual components
var body_mesh: MeshInstance3D
var blade_mesh: MeshInstance3D
var eye_light: OmniLight3D

## Attack patterns based on difficulty
var attack_patterns: Array[AttackType] = []
var pattern_index: int = 0

## Telegraphing
var telegraph_duration: float = 0.5
var telegraph_timer: float = 0.0
var is_telegraphing: bool = false

## Audio
var audio_player: AudioStreamPlayer3D


func _ready() -> void:
	_create_visual()
	_setup_attack_patterns()
	health = max_health


func _physics_process(delta: float) -> void:
	if not is_active:
		return

	match current_state:
		DroidState.IDLE:
			_process_idle(delta)
		DroidState.APPROACHING:
			_process_approaching(delta)
		DroidState.CIRCLING:
			_process_circling(delta)
		DroidState.ATTACKING:
			_process_attacking(delta)
		DroidState.RECOVERING:
			_process_recovering(delta)
		DroidState.RETREATING:
			_process_retreating(delta)
		DroidState.STUNNED:
			_process_stunned(delta)

	_update_visuals()


func setup(head: Node3D, left_hand: Node3D, right_hand: Node3D) -> void:
	player_head = head
	player_left_hand = left_hand
	player_right_hand = right_hand


func activate() -> void:
	if is_active:
		return

	is_active = true
	health = max_health
	current_state = DroidState.IDLE
	_setup_attack_patterns()
	droid_activated.emit()

	# Start eye glow
	if eye_light:
		eye_light.light_energy = 1.0


func deactivate() -> void:
	is_active = false
	current_state = DroidState.INACTIVE
	droid_deactivated.emit()

	if eye_light:
		eye_light.light_energy = 0.0


func _create_visual() -> void:
	# Create droid body
	body_mesh = MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.2
	capsule.height = 0.8

	var body_mat := StandardMaterial3D.new()
	body_mat.albedo_color = Color(0.3, 0.3, 0.35)
	body_mat.metallic = 0.8
	body_mat.roughness = 0.3
	capsule.material = body_mat

	body_mesh.mesh = capsule
	body_mesh.position = Vector3(0, 0.4, 0)
	add_child(body_mesh)

	# Create blade
	blade_mesh = MeshInstance3D.new()
	var blade := CylinderMesh.new()
	blade.top_radius = 0.02
	blade.bottom_radius = 0.02
	blade.height = 0.8

	var blade_mat := StandardMaterial3D.new()
	blade_mat.albedo_color = Color(1.0, 0.2, 0.1)
	blade_mat.emission_enabled = true
	blade_mat.emission = Color(1.0, 0.2, 0.1)
	blade_mat.emission_energy_multiplier = 2.0
	blade.material = blade_mat

	blade_mesh.mesh = blade
	blade_mesh.position = Vector3(0.4, 0.5, 0)
	blade_mesh.rotation_degrees = Vector3(0, 0, 90)
	blade_mesh.visible = false
	add_child(blade_mesh)

	# Create eye light
	eye_light = OmniLight3D.new()
	eye_light.light_color = Color(1.0, 0.3, 0.1)
	eye_light.light_energy = 0.0
	eye_light.omni_range = 1.0
	eye_light.position = Vector3(0, 0.6, 0.15)
	add_child(eye_light)

	# Audio player
	audio_player = AudioStreamPlayer3D.new()
	add_child(audio_player)


func _setup_attack_patterns() -> void:
	attack_patterns.clear()

	# Basic patterns for lower difficulty
	if difficulty < 0.3:
		attack_patterns = [
			AttackType.HORIZONTAL_LEFT,
			AttackType.HORIZONTAL_RIGHT,
			AttackType.VERTICAL_DOWN
		]
	elif difficulty < 0.6:
		attack_patterns = [
			AttackType.HORIZONTAL_LEFT,
			AttackType.HORIZONTAL_RIGHT,
			AttackType.VERTICAL_DOWN,
			AttackType.DIAGONAL_LEFT,
			AttackType.DIAGONAL_RIGHT
		]
	else:
		attack_patterns = [
			AttackType.HORIZONTAL_LEFT,
			AttackType.HORIZONTAL_RIGHT,
			AttackType.VERTICAL_DOWN,
			AttackType.VERTICAL_UP,
			AttackType.DIAGONAL_LEFT,
			AttackType.DIAGONAL_RIGHT,
			AttackType.THRUST,
			AttackType.SPIN
		]

	attack_patterns.shuffle()
	pattern_index = 0


func _process_idle(delta: float) -> void:
	attack_timer += delta

	# Look at player
	if player_head:
		var look_target := player_head.global_position
		look_target.y = global_position.y
		look_at(look_target, Vector3.UP)

	# Decide next action
	var distance_to_player := _get_distance_to_player()

	if distance_to_player > attack_range * 1.5:
		current_state = DroidState.APPROACHING
	elif attack_timer >= attack_cooldown:
		if randf() < 0.7:
			_start_attack()
		else:
			current_state = DroidState.CIRCLING
			orbit_direction = 1 if randf() > 0.5 else -1


func _process_approaching(delta: float) -> void:
	if player_head == null:
		return

	var target := player_head.global_position
	target.y = global_position.y

	var direction := (target - global_position).normalized()
	velocity = direction * move_speed

	move_and_slide()

	# Face player
	look_at(target, Vector3.UP)

	# Check if in range
	if _get_distance_to_player() <= attack_range:
		current_state = DroidState.IDLE
		velocity = Vector3.ZERO


func _process_circling(delta: float) -> void:
	if player_head == null:
		current_state = DroidState.IDLE
		return

	var player_pos := player_head.global_position
	player_pos.y = global_position.y

	# Orbit around player
	orbit_angle += delta * move_speed * 0.5 * orbit_direction

	var orbit_radius := attack_range * 0.8
	var target := player_pos + Vector3(
		cos(orbit_angle) * orbit_radius,
		0,
		sin(orbit_angle) * orbit_radius
	)

	var direction := (target - global_position).normalized()
	velocity = direction * move_speed * 0.7

	move_and_slide()

	# Face player
	look_at(player_pos, Vector3.UP)

	# Randomly decide to attack
	attack_timer += delta
	if attack_timer >= attack_cooldown * 0.5 and randf() < 0.02:
		_start_attack()


func _process_attacking(delta: float) -> void:
	if is_telegraphing:
		telegraph_timer += delta
		if telegraph_timer >= telegraph_duration:
			is_telegraphing = false
			_execute_attack()
	else:
		# Attack animation would play here
		attack_timer += delta
		if attack_timer >= 0.5:  # Attack duration
			_finish_attack(false)


func _process_recovering(delta: float) -> void:
	recovery_timer += delta

	var recovery_time := 1.0 - (difficulty * 0.5)  # Faster recovery at higher difficulty
	if recovery_timer >= recovery_time:
		recovery_timer = 0.0
		current_state = DroidState.IDLE


func _process_retreating(delta: float) -> void:
	if player_head == null:
		current_state = DroidState.IDLE
		return

	var away_dir := (global_position - player_head.global_position).normalized()
	away_dir.y = 0

	velocity = away_dir * move_speed * 1.5
	move_and_slide()

	if _get_distance_to_player() > attack_range * 2:
		current_state = DroidState.IDLE
		velocity = Vector3.ZERO


func _process_stunned(delta: float) -> void:
	stun_timer += delta
	if stun_timer >= 1.0:
		stun_timer = 0.0
		current_state = DroidState.RECOVERING


func _start_attack() -> void:
	current_state = DroidState.ATTACKING
	attack_timer = 0.0

	# Pick next attack from pattern
	current_attack = attack_patterns[pattern_index]
	pattern_index = (pattern_index + 1) % attack_patterns.size()

	# Telegraph the attack
	is_telegraphing = true
	telegraph_timer = 0.0

	# Shorter telegraph at higher difficulty
	telegraph_duration = 0.8 - (difficulty * 0.4)

	attack_started.emit(_attack_type_name(current_attack))

	# Show blade
	blade_mesh.visible = true

	# Visual telegraph (rotate blade to show incoming direction)
	_telegraph_attack_visual()


func _telegraph_attack_visual() -> void:
	match current_attack:
		AttackType.HORIZONTAL_LEFT:
			blade_mesh.rotation_degrees = Vector3(0, 0, 0)
			blade_mesh.position = Vector3(-0.5, 0.5, 0)
		AttackType.HORIZONTAL_RIGHT:
			blade_mesh.rotation_degrees = Vector3(0, 0, 0)
			blade_mesh.position = Vector3(0.5, 0.5, 0)
		AttackType.VERTICAL_DOWN:
			blade_mesh.rotation_degrees = Vector3(90, 0, 0)
			blade_mesh.position = Vector3(0, 1.0, 0)
		AttackType.VERTICAL_UP:
			blade_mesh.rotation_degrees = Vector3(90, 0, 0)
			blade_mesh.position = Vector3(0, 0.2, 0)
		AttackType.DIAGONAL_LEFT:
			blade_mesh.rotation_degrees = Vector3(45, 0, 0)
			blade_mesh.position = Vector3(-0.4, 0.8, 0)
		AttackType.DIAGONAL_RIGHT:
			blade_mesh.rotation_degrees = Vector3(-45, 0, 0)
			blade_mesh.position = Vector3(0.4, 0.8, 0)
		AttackType.THRUST:
			blade_mesh.rotation_degrees = Vector3(90, 90, 0)
			blade_mesh.position = Vector3(0, 0.5, -0.5)
		AttackType.SPIN:
			blade_mesh.rotation_degrees = Vector3(0, 0, 45)
			blade_mesh.position = Vector3(0.3, 0.5, 0)


func _execute_attack() -> void:
	# Attack animation/movement would happen here
	# Check if player blocked
	pass


func _finish_attack(was_blocked: bool) -> void:
	attack_completed.emit(_attack_type_name(current_attack), was_blocked)
	current_attack = AttackType.NONE
	blade_mesh.visible = false

	if was_blocked:
		current_state = DroidState.RECOVERING
		recovery_timer = 0.0
	else:
		# Successful hit on player (if we had player health)
		current_state = DroidState.RETREATING


func take_damage(damage: float, hit_position: Vector3) -> void:
	health -= damage
	droid_hit.emit(damage, hit_position)

	if health <= 0:
		_destroy()
	else:
		# Stagger based on damage
		if damage > 20:
			current_state = DroidState.STUNNED
			stun_timer = 0.0


func block_attack() -> void:
	# Called when player successfully blocks the droid's attack
	_finish_attack(true)


func _destroy() -> void:
	droid_destroyed.emit()
	deactivate()

	# Would spawn destruction particles/effects
	GameEvents.vfx_requested.emit("target_destroy", global_position, Vector3.UP)


func _get_distance_to_player() -> float:
	if player_head == null:
		return INF

	var player_pos := player_head.global_position
	player_pos.y = global_position.y
	return global_position.distance_to(player_pos)


func _attack_type_name(attack: AttackType) -> String:
	match attack:
		AttackType.HORIZONTAL_LEFT: return "horizontal_left"
		AttackType.HORIZONTAL_RIGHT: return "horizontal_right"
		AttackType.VERTICAL_DOWN: return "vertical_down"
		AttackType.VERTICAL_UP: return "vertical_up"
		AttackType.DIAGONAL_LEFT: return "diagonal_left"
		AttackType.DIAGONAL_RIGHT: return "diagonal_right"
		AttackType.THRUST: return "thrust"
		AttackType.SPIN: return "spin"
	return "none"


func _update_visuals() -> void:
	# Pulse eye based on state
	if eye_light:
		match current_state:
			DroidState.ATTACKING:
				eye_light.light_energy = 2.0
				eye_light.light_color = Color(1.0, 0.1, 0.0)
			DroidState.STUNNED:
				eye_light.light_energy = 0.5
				eye_light.light_color = Color(0.5, 0.5, 0.0)
			_:
				eye_light.light_energy = 1.0
				eye_light.light_color = Color(1.0, 0.3, 0.1)


func set_difficulty(new_difficulty: float) -> void:
	difficulty = clampf(new_difficulty, 0.0, 1.0)
	_setup_attack_patterns()

	# Adjust stats based on difficulty
	move_speed = 1.5 + difficulty * 1.5
	attack_cooldown = 3.0 - difficulty * 1.5


func get_block_direction() -> Vector3:
	# Return the direction player should block to parry current attack
	match current_attack:
		AttackType.HORIZONTAL_LEFT:
			return Vector3.RIGHT
		AttackType.HORIZONTAL_RIGHT:
			return Vector3.LEFT
		AttackType.VERTICAL_DOWN:
			return Vector3.UP
		AttackType.VERTICAL_UP:
			return Vector3.DOWN
		AttackType.DIAGONAL_LEFT:
			return Vector3(1, 1, 0).normalized()
		AttackType.DIAGONAL_RIGHT:
			return Vector3(-1, 1, 0).normalized()
		AttackType.THRUST:
			return Vector3.FORWARD
		AttackType.SPIN:
			return Vector3.ZERO  # Any direction works
	return Vector3.ZERO

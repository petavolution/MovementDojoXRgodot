## WeaponComponent - Manages entity weapons and firing
##
## Responsibilities:
## - Fire projectiles at targets
## - Handle fire rate and cooldowns
## - Manage ammo (if enabled)
## - Spawn muzzle effects
## - Track targeting
##
## Configuration: WeaponComponentConfig Resource
##
## Usage:
## ```gdscript
## var weapon = entity.get_component(WeaponComponent)
## weapon.set_target(player)
## weapon.start_firing()  // Auto-fires based on config
## ```
class_name WeaponComponent
extends EntityComponent

# =============================================================================
# SIGNALS
# =============================================================================

signal weapon_fired(projectile: Node, direction: Vector3)
signal ammo_changed(current: int, max: int)
signal reload_started()
signal reload_completed()
signal weapon_empty()

# =============================================================================
# PROPERTIES
# =============================================================================

var weapon_type: WeaponComponentConfig.WeaponType
var fire_interval: float = 1.0
var projectile_speed: float = 10.0
var projectile_damage: float = 10.0
var is_firing: bool = false

# Ammo
var current_ammo: int = 30
var max_ammo: int = 30
var is_reloading: bool = false

# Target
var target: Node3D

# Private state
var _config: WeaponComponentConfig
var _fire_timer: float = 0.0
var _reload_timer: float = 0.0
var _burst_count: int = 0
var _burst_timer: float = 0.0
var _projectiles_fired: int = 0

# =============================================================================
# INITIALIZATION
# =============================================================================

func _on_initialized() -> void:
	component_id = "Weapon"

	# Load from config
	if config is WeaponComponentConfig:
		_config = config
		weapon_type = _config.weapon_type
		fire_interval = _config.fire_interval
		projectile_speed = _config.projectile_speed
		projectile_damage = _config.projectile_damage

		# Ammo setup
		if _config.has_ammo and not _config.infinite_ammo:
			max_ammo = _config.max_ammo
			current_ammo = _config.starting_ammo
		else:
			current_ammo = 999  # Effectively infinite
			max_ammo = 999

		log_debug("Initialized: type=%s, rate=%.1fs, damage=%.0f" % [
			WeaponComponentConfig.WeaponType.keys()[weapon_type],
			fire_interval,
			projectile_damage
		])
	else:
		log_warn("No WeaponComponentConfig provided, using defaults")
		weapon_type = WeaponComponentConfig.WeaponType.PROJECTILE


func on_entity_spawned() -> void:
	super.on_entity_spawned()

	# Auto-start firing if configured
	if _config and _config.auto_fire:
		start_firing()

# =============================================================================
# UPDATE
# =============================================================================

func process_component(delta: float) -> void:
	# Handle reloading
	if is_reloading:
		_process_reload(delta)
		return

	# Handle burst mode
	if _config and _config.burst_mode and _burst_count > 0:
		_process_burst(delta)
		return

	# Handle firing
	if is_firing:
		_process_firing(delta)


func _process_firing(delta: float) -> void:
	_fire_timer += delta

	if _fire_timer >= fire_interval:
		_fire_timer = 0.0
		attempt_fire()


func _process_burst(delta: float) -> void:
	_burst_timer += delta

	if _burst_timer >= (_config.burst_delay if _config else 0.1):
		_burst_timer = 0.0
		_burst_count -= 1

		_fire_single_shot()

		if _burst_count <= 0:
			# Burst complete, reset fire timer
			_fire_timer = 0.0


func _process_reload(delta: float) -> void:
	_reload_timer += delta

	var reload_time := _config.reload_time if _config else 2.0
	if _reload_timer >= reload_time:
		_complete_reload()

# =============================================================================
# FIRING
# =============================================================================

## Attempt to fire weapon (checks ammo, cooldown, target)
func attempt_fire() -> bool:
	# Check if weapon can fire
	if not can_fire():
		return false

	# Burst mode
	if _config and _config.burst_mode:
		_start_burst()
		return true

	# Single shot
	return _fire_single_shot()


func _fire_single_shot() -> bool:
	# Check ammo
	if _config and _config.has_ammo and not _config.infinite_ammo:
		if current_ammo <= 0:
			weapon_empty.emit()
			if _config.auto_reload:
				start_reload()
			return false

		# Consume ammo
		current_ammo -= _config.ammo_per_shot
		ammo_changed.emit(current_ammo, max_ammo)

	# Fire based on weapon type
	match weapon_type:
		WeaponComponentConfig.WeaponType.PROJECTILE:
			return _fire_projectile()
		WeaponComponentConfig.WeaponType.MELEE:
			return _fire_melee()
		_:
			log_warn("Weapon type not implemented: %s" % weapon_type)
			return false


func _fire_projectile() -> bool:
	if not target and _config and _config.requires_target:
		return false

	# Calculate spawn position
	var spawn_pos := entity.global_position
	if _config:
		spawn_pos += entity.global_transform.basis * _config.spawn_offset

	# Calculate direction
	var direction := Vector3.FORWARD
	if target:
		direction = (target.global_position - spawn_pos).normalized()

		# Add spread/inaccuracy
		if _config and _config.projectile_spread > 0:
			var spread_rad := deg_to_rad(_config.projectile_spread)
			direction += Vector3(
				randf_range(-spread_rad, spread_rad),
				randf_range(-spread_rad * 0.5, spread_rad * 0.5),
				randf_range(-spread_rad, spread_rad)
			)
			direction = direction.normalized()
	else:
		# No target, fire forward
		direction = -entity.global_transform.basis.z

	# Spawn projectile(s)
	var projectile_count := _config.projectiles_per_shot if _config else 1
	for i in range(projectile_count):
		var projectile := _spawn_projectile(spawn_pos, direction)
		if projectile:
			weapon_fired.emit(projectile, direction)
			_projectiles_fired += 1

	log_debug("Fired projectile #%d" % _projectiles_fired)

	# Muzzle flash
	if _config and _config.muzzle_flash:
		_spawn_muzzle_flash(spawn_pos)

	# Fire sound
	if _config and _config.fire_sound:
		_play_sound(_config.fire_sound)

	return true


func _spawn_projectile(spawn_pos: Vector3, direction: Vector3) -> Node:
	# Use Projectile class from existing system
	if not ClassDB.class_exists("Projectile"):
		log_error("Projectile class not found")
		return null

	var projectile = ClassDB.instantiate("Projectile")
	if not projectile:
		log_error("Failed to instantiate Projectile")
		return null

	# Set projectile properties
	projectile.global_position = spawn_pos
	projectile.set("velocity", direction * projectile_speed)
	projectile.set("damage", projectile_damage)

	if _config:
		projectile.set("projectile_color", _config.projectile_color)
		projectile.set("projectile_size", _config.projectile_size)
		if _config.projectile_lifetime > 0:
			projectile.set("lifetime", _config.projectile_lifetime)

	# Add to scene
	entity.get_tree().root.add_child(projectile)

	return projectile


func _fire_melee() -> bool:
	# TODO: Implement melee attack
	log_warn("Melee weapon not yet implemented")
	return false


func _start_burst() -> void:
	if not _config:
		return

	_burst_count = _config.burst_count
	_burst_timer = 0.0
	log_debug("Starting burst: %d shots" % _burst_count)


func _spawn_muzzle_flash(position: Vector3) -> void:
	if not _config or not _config.muzzle_flash:
		return

	var flash := _config.muzzle_flash.instantiate()
	flash.global_position = position
	entity.get_tree().root.add_child(flash)

	# Auto-cleanup
	var timer := entity.get_tree().create_timer(_config.muzzle_flash_duration)
	timer.timeout.connect(flash.queue_free)

# =============================================================================
# FIRING CONTROL
# =============================================================================

## Start automatic firing
func start_firing() -> void:
	if is_firing:
		return

	is_firing = true
	_fire_timer = fire_interval  # Fire immediately
	log_debug("Started firing")


## Stop automatic firing
func stop_firing() -> void:
	if not is_firing:
		return

	is_firing = false
	log_debug("Stopped firing")


## Fire once immediately
func fire_once() -> bool:
	return attempt_fire()


## Check if weapon can fire
func can_fire() -> bool:
	if is_reloading:
		return false

	if _config and _config.has_ammo and not _config.infinite_ammo:
		if current_ammo <= 0:
			return false

	if _config and _config.requires_target and target == null:
		return false

	if _config and _config.max_range > 0 and target:
		var dist := entity.global_position.distance_to(target.global_position)
		if dist > _config.max_range:
			return false

	return true

# =============================================================================
# TARGETING
# =============================================================================

## Set firing target
func set_target(new_target: Node3D) -> void:
	target = new_target
	log_debug("Target set: %s" % (target.name if target else "null"))


## Clear target
func clear_target() -> void:
	target = null
	log_debug("Target cleared")


## Get target
func get_target() -> Node3D:
	return target

# =============================================================================
# AMMO & RELOAD
# =============================================================================

## Start reload
func start_reload() -> void:
	if is_reloading:
		return

	if not _config or not _config.has_ammo or _config.infinite_ammo:
		return

	if current_ammo >= max_ammo:
		return

	is_reloading = true
	_reload_timer = 0.0
	reload_started.emit()
	log_debug("Reloading (%.1fs)" % (_config.reload_time if _config else 2.0))

	# Reload sound
	if _config and _config.reload_sound:
		_play_sound(_config.reload_sound)


func _complete_reload() -> void:
	is_reloading = false
	current_ammo = max_ammo
	ammo_changed.emit(current_ammo, max_ammo)
	reload_completed.emit()
	log_debug("Reload complete")


## Add ammo
func add_ammo(amount: int) -> void:
	if not _config or not _config.has_ammo or _config.infinite_ammo:
		return

	current_ammo = mini(current_ammo + amount, max_ammo)
	ammo_changed.emit(current_ammo, max_ammo)


## Set ammo
func set_ammo(amount: int) -> void:
	if not _config or not _config.has_ammo or _config.infinite_ammo:
		return

	current_ammo = clampi(amount, 0, max_ammo)
	ammo_changed.emit(current_ammo, max_ammo)

# =============================================================================
# HELPER METHODS
# =============================================================================

func _play_sound(sound: AudioStream) -> void:
	if not sound or not entity:
		return

	# Try to use entity's audio component
	var audio = get_sibling_component(preload("res://scripts/entities/components/audio_component.gd"))
	if audio and audio.has_method("play_sound"):
		audio.call("play_sound", sound)
	else:
		# Fallback: create temporary audio player
		var player := AudioStreamPlayer3D.new()
		entity.add_child(player)
		player.stream = sound
		player.play()
		await player.finished
		player.queue_free()


## Get ammo percentage (0.0-1.0)
func get_ammo_percentage() -> float:
	if max_ammo <= 0:
		return 1.0
	return float(current_ammo) / float(max_ammo)


## Check if ammo is full
func is_ammo_full() -> bool:
	return current_ammo >= max_ammo


## Check if ammo is empty
func is_ammo_empty() -> bool:
	return current_ammo <= 0

# =============================================================================
# VALIDATION
# =============================================================================

func validate() -> Array[String]:
	var errors := super.validate()

	if fire_interval <= 0:
		errors.append("fire_interval must be > 0")

	if projectile_speed <= 0:
		errors.append("projectile_speed must be > 0")

	return errors

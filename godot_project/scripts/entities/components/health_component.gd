## HealthComponent - Manages entity health, damage, and death
##
## Responsibilities:
## - Track current/max health
## - Process damage and healing
## - Handle invulnerability
## - Emit signals for UI/feedback
## - Trigger death when health reaches zero
##
## Configuration: HealthComponentConfig Resource
##
## Usage:
## ```gdscript
## var health = entity.get_component(HealthComponent)
## health.take_damage(25.0, projectile)
## if health.is_alive():
##     print("Health: %d%%" % (health.get_health_percentage() * 100))
## ```
class_name HealthComponent
extends EntityComponent

# =============================================================================
# SIGNALS
# =============================================================================

signal health_changed(current: float, max: float, percentage: float)
signal damage_taken(amount: float, final_amount: float, source: Node)
signal healed(amount: float)
signal death(final_position: Vector3)
signal invulnerability_changed(is_invulnerable: bool)

# =============================================================================
# PROPERTIES
# =============================================================================

var max_health: float = 100.0
var current_health: float = 100.0
var is_invulnerable: bool = false
var regeneration_rate: float = 0.0

# Private state
var _config: HealthComponentConfig
var _regeneration_timer: float = 0.0
var _invulnerability_timer: float = 0.0
var _damage_flash_timer: float = 0.0
var _visual: EntityComponent  # VisualComponent reference

# =============================================================================
# INITIALIZATION
# =============================================================================

func _on_initialized() -> void:
	component_id = "Health"

	# Load from config
	if config is HealthComponentConfig:
		_config = config
		max_health = _config.max_health
		current_health = _config.get_starting_health()
		regeneration_rate = _config.regeneration_rate
		is_invulnerable = _config.invulnerable

		log_debug("Initialized: %.0f/%.0f HP, regen %.1f/s" % [current_health, max_health, regeneration_rate])
	else:
		log_warn("No HealthComponentConfig provided, using defaults")
		current_health = max_health


func on_entity_spawned() -> void:
	super.on_entity_spawned()

	# Get visual component reference for damage flash
	_visual = get_sibling_component(preload("res://scripts/entities/components/visual_component.gd"))

	# Apply spawn invulnerability
	if _config and _config.spawn_invulnerability > 0:
		_invulnerability_timer = _config.spawn_invulnerability
		is_invulnerable = true
		invulnerability_changed.emit(true)
		log_debug("Spawn invulnerability: %.1fs" % _invulnerability_timer)

# =============================================================================
# UPDATE
# =============================================================================

func process_component(delta: float) -> void:
	# Update invulnerability timer
	if _invulnerability_timer > 0:
		_invulnerability_timer -= delta
		if _invulnerability_timer <= 0:
			is_invulnerable = _config.invulnerable if _config else false
			invulnerability_changed.emit(is_invulnerable)
			log_debug("Spawn invulnerability ended")

	# Health regeneration
	if regeneration_rate > 0 and current_health < max_health:
		if _regeneration_timer > 0:
			_regeneration_timer -= delta
		else:
			var regen_amount := regeneration_rate * delta
			heal(regen_amount, false)  # Silent regen

	# Damage flash timer
	if _damage_flash_timer > 0:
		_damage_flash_timer -= delta
		if _damage_flash_timer <= 0 and _visual:
			_visual.call("clear_damage_flash")

# =============================================================================
# DAMAGE & HEALING
# =============================================================================

## Take damage from a source
## Returns true if damage was fatal
func take_damage(amount: float, source: Node = null) -> bool:
	if not is_active or current_health <= 0:
		return false

	if is_invulnerable:
		log_debug("Invulnerable - damage ignored")
		return false

	# Apply config modifiers
	var final_damage := amount
	if _config:
		# Apply damage multiplier
		final_damage *= _config.damage_multiplier

		# Check damage threshold
		if final_damage < _config.damage_threshold:
			log_debug("Damage %.1f below threshold %.1f" % [final_damage, _config.damage_threshold])
			return false

		# Cap max damage per hit
		if final_damage > _config.max_damage_per_hit:
			final_damage = _config.max_damage_per_hit

	# Apply damage
	current_health = maxf(0, current_health - final_damage)

	log_debug("Took %.1f damage (%.0f/%.0f HP)" % [final_damage, current_health, max_health])

	# Emit signals
	damage_taken.emit(amount, final_damage, source)
	health_changed.emit(current_health, max_health, get_health_percentage())

	# Reset regeneration delay
	if _config and _config.regeneration_delay > 0:
		_regeneration_timer = _config.regeneration_delay

	# Damage flash
	if _config and _config.damage_flash_enabled:
		_trigger_damage_flash()

	# Play damage sound
	if _config and _config.damage_sound:
		_play_sound(_config.damage_sound)

	# Check for death
	if current_health <= 0:
		_on_death()
		return true

	# Check for low health sound
	if _config and _config.low_health_sound and get_health_percentage() < 0.25:
		_play_sound(_config.low_health_sound)

	return false


## Heal the entity
func heal(amount: float, emit_signal: bool = true) -> void:
	if current_health >= max_health:
		return

	var old_health := current_health
	current_health = minf(max_health, current_health + amount)

	var actual_heal := current_health - old_health

	if emit_signal:
		healed.emit(actual_heal)
		health_changed.emit(current_health, max_health, get_health_percentage())
		log_debug("Healed %.1f HP (%.0f/%.0f)" % [actual_heal, current_health, max_health])

		# Play heal sound
		if _config and _config.heal_sound:
			_play_sound(_config.heal_sound)


## Set health directly (for initialization or special effects)
func set_health(value: float) -> void:
	current_health = clampf(value, 0, max_health)
	health_changed.emit(current_health, max_health, get_health_percentage())


## Set max health and optionally adjust current health
func set_max_health(value: float, maintain_percentage: bool = false) -> void:
	if maintain_percentage:
		var pct := get_health_percentage()
		max_health = value
		current_health = max_health * pct
	else:
		max_health = value
		current_health = minf(current_health, max_health)

	health_changed.emit(current_health, max_health, get_health_percentage())

# =============================================================================
# DEATH
# =============================================================================

func _on_death() -> void:
	log_info("Entity died")

	death.emit(entity.global_position)

	# Play death sound
	if _config and _config.death_sound:
		_play_sound(_config.death_sound)

	# Spawn death effect
	if _config and _config.death_effect:
		var effect = _config.death_effect.instantiate()
		entity.get_tree().root.add_child(effect)
		effect.global_position = entity.global_position

	# Trigger death dissolve visual
	if _visual and _config and _config.death_delay > 0:
		_visual.call("play_death_dissolve", _config.death_delay)

	# Destroy entity after delay
	var delay := _config.death_delay if _config else 0.5
	await entity.get_tree().create_timer(delay).timeout

	if entity and is_instance_valid(entity):
		entity.destroy()

# =============================================================================
# HELPER METHODS
# =============================================================================

## Get health as percentage (0.0 - 1.0)
func get_health_percentage() -> float:
	return current_health / max_health if max_health > 0 else 0.0


## Check if entity is alive
func is_alive() -> bool:
	return current_health > 0


## Check if health is full
func is_full_health() -> bool:
	return current_health >= max_health


## Check if health is low (< 25%)
func is_low_health() -> bool:
	return get_health_percentage() < 0.25


## Set invulnerability state
func set_invulnerable(value: bool) -> void:
	if is_invulnerable == value:
		return

	is_invulnerable = value
	invulnerability_changed.emit(value)
	log_debug("Invulnerability: %s" % value)


## Temporary invulnerability for duration
func set_invulnerable_for(duration: float) -> void:
	is_invulnerable = true
	_invulnerability_timer = duration
	invulnerability_changed.emit(true)
	log_debug("Temporary invulnerability: %.1fs" % duration)


## Instant kill
func kill() -> void:
	current_health = 0
	_on_death()

# =============================================================================
# VISUAL/AUDIO FEEDBACK
# =============================================================================

func _trigger_damage_flash() -> void:
	if not _visual or not _config:
		return

	_damage_flash_timer = _config.damage_flash_duration

	# Call visual component's damage flash
	if _visual.has_method("play_damage_flash"):
		_visual.call("play_damage_flash", _config.damage_flash_color, _config.damage_flash_duration)


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

# =============================================================================
# VALIDATION
# =============================================================================

func validate() -> Array[String]:
	var errors := super.validate()

	if max_health <= 0:
		errors.append("max_health must be > 0")

	if current_health < 0:
		errors.append("current_health cannot be negative")

	return errors

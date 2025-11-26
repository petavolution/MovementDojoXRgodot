## HealthComponentConfig - Configuration for HealthComponent
##
## Data-driven health system configuration
## Save as .tres and assign to EntityDefinition.health_config
class_name HealthComponentConfig
extends Resource

# =============================================================================
# HEALTH PROPERTIES
# =============================================================================

## Maximum health points
@export var max_health: float = 100.0

## Starting health (if different from max)
@export var starting_health: float = -1.0  # -1 = use max_health

## Health regeneration per second (0 = no regen)
@export var regeneration_rate: float = 0.0

## Delay before regeneration starts after taking damage
@export var regeneration_delay: float = 3.0

## Is entity invulnerable (cannot take damage)
@export var invulnerable: bool = false

## Invulnerability duration at spawn (seconds)
@export var spawn_invulnerability: float = 0.0

# =============================================================================
# DAMAGE PROPERTIES
# =============================================================================

@export_group("Damage")

## Damage multiplier (for difficulty scaling)
@export var damage_multiplier: float = 1.0

## Minimum damage threshold (ignore damage below this)
@export var damage_threshold: float = 0.0

## Maximum damage per hit (cap)
@export var max_damage_per_hit: float = 999.0

## Damage types this entity is immune to
@export var damage_immunities: Array[String] = []

## Damage types this entity is resistant to (50% damage)
@export var damage_resistances: Array[String] = []

## Damage types this entity is vulnerable to (2x damage)
@export var damage_vulnerabilities: Array[String] = []

# =============================================================================
# VISUAL FEEDBACK
# =============================================================================

@export_group("Visual Feedback")

## Enable damage flash effect
@export var damage_flash_enabled: bool = true

## Flash color when damaged
@export var damage_flash_color: Color = Color(1.0, 0.3, 0.3)

## Flash duration (seconds)
@export var damage_flash_duration: float = 0.1

## Enable health bar
@export var health_bar_enabled: bool = false

## Health bar scene (custom UI)
@export var health_bar_scene: PackedScene

# =============================================================================
# AUDIO FEEDBACK
# =============================================================================

@export_group("Audio")

## Sound when taking damage
@export var damage_sound: AudioStream

## Sound when health is low (< 25%)
@export var low_health_sound: AudioStream

## Sound when healed
@export var heal_sound: AudioStream

# =============================================================================
# DEATH PROPERTIES
# =============================================================================

@export_group("Death")

## Death effect/explosion scene
@export var death_effect: PackedScene

## Death sound
@export var death_sound: AudioStream

## Delay before entity removal after death
@export var death_delay: float = 0.5

## Ragdoll on death (if physics body)
@export var ragdoll_on_death: bool = false

# =============================================================================
# VALIDATION
# =============================================================================

func validate() -> Array[String]:
	var errors: Array[String] = []

	if max_health <= 0:
		errors.append("max_health must be > 0")

	if starting_health > max_health:
		errors.append("starting_health cannot exceed max_health")

	if regeneration_rate < 0:
		errors.append("regeneration_rate cannot be negative")

	if damage_multiplier < 0:
		errors.append("damage_multiplier cannot be negative")

	return errors


func get_starting_health() -> float:
	return starting_health if starting_health >= 0 else max_health

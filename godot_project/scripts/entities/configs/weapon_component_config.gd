## WeaponComponentConfig - Configuration for WeaponComponent
##
## Data-driven weapon system configuration
## Supports projectile shooting, melee attacks, and more
class_name WeaponComponentConfig
extends Resource

# =============================================================================
# WEAPON TYPE
# =============================================================================

enum WeaponType {
	NONE,            ## No weapon
	PROJECTILE,      ## Ranged projectile weapon
	MELEE,           ## Melee/swing weapon
	BEAM,            ## Continuous beam weapon
	CUSTOM           ## Custom weapon behavior
}

@export var weapon_type: WeaponType = WeaponType.PROJECTILE

# =============================================================================
# PROJECTILE SETTINGS
# =============================================================================

@export_group("Projectile")

## Projectile scene to spawn
@export var projectile_scene: PackedScene

## Projectile speed (units/second)
@export var projectile_speed: float = 10.0

## Projectile damage
@export var projectile_damage: float = 10.0

## Projectile color
@export var projectile_color: Color = Color(1.0, 0.4, 0.1)

## Projectile size multiplier
@export var projectile_size: float = 1.0

## Projectile lifetime (seconds, 0 = infinite)
@export var projectile_lifetime: float = 5.0

## Spread/inaccuracy (degrees)
@export var projectile_spread: float = 0.0

## Projectile count per shot (for burst/shotgun)
@export var projectiles_per_shot: int = 1

# =============================================================================
# FIRING SETTINGS
# =============================================================================

@export_group("Firing")

## Fire rate (seconds between shots)
@export var fire_interval: float = 1.0

## Can fire automatically
@export var auto_fire: bool = true

## Burst fire mode (fire multiple shots quickly)
@export var burst_mode: bool = false

## Burst count (shots per burst)
@export var burst_count: int = 3

## Burst delay (seconds between burst shots)
@export var burst_delay: float = 0.1

## Charge time before firing (seconds)
@export var charge_time: float = 0.0

## Cooldown after firing (seconds)
@export var cooldown_time: float = 0.0

# =============================================================================
# AMMO SETTINGS
# =============================================================================

@export_group("Ammo")

## Enable ammo system
@export var has_ammo: bool = false

## Max ammo capacity
@export var max_ammo: int = 30

## Starting ammo
@export var starting_ammo: int = 30

## Ammo consumed per shot
@export var ammo_per_shot: int = 1

## Auto-reload when empty
@export var auto_reload: bool = true

## Reload time (seconds)
@export var reload_time: float = 2.0

## Infinite ammo (never runs out)
@export var infinite_ammo: bool = true

# =============================================================================
# TARGETING SETTINGS
# =============================================================================

@export_group("Targeting")

## Require target to fire
@export var requires_target: bool = true

## Target tracking (lead target movement)
@export var track_target: bool = false

## Track amount (0 = no tracking, 1 = perfect tracking)
@export_range(0.0, 1.0) var track_amount: float = 0.0

## Max firing range (0 = unlimited)
@export var max_range: float = 0.0

## Fire at player specifically
@export var shoot_at_player: bool = true

# =============================================================================
# SPAWN SETTINGS
# =============================================================================

@export_group("Spawn")

## Spawn offset from entity (forward direction)
@export var spawn_offset: Vector3 = Vector3(0, 0, -0.3)

## Muzzle flash effect
@export var muzzle_flash: PackedScene

## Muzzle flash duration
@export var muzzle_flash_duration: float = 0.1

# =============================================================================
# AUDIO/VISUAL FEEDBACK
# =============================================================================

@export_group("Feedback")

## Fire sound
@export var fire_sound: AudioStream

## Reload sound
@export var reload_sound: AudioStream

## Empty click sound
@export var empty_sound: AudioStream

## Visual recoil
@export var visual_recoil: bool = false

## Recoil amount
@export var recoil_amount: float = 0.1

# =============================================================================
# MELEE SETTINGS
# =============================================================================

@export_group("Melee")

## Melee damage
@export var melee_damage: float = 25.0

## Melee range
@export var melee_range: float = 1.5

## Melee swing duration
@export var melee_swing_duration: float = 0.3

## Melee knockback force
@export var melee_knockback: float = 5.0

# =============================================================================
# VALIDATION
# =============================================================================

func validate() -> Array[String]:
	var errors: Array[String] = []

	if weapon_type == WeaponType.PROJECTILE:
		if projectile_speed <= 0:
			errors.append("projectile_speed must be > 0")

		if projectile_damage < 0:
			errors.append("projectile_damage cannot be negative")

		if fire_interval <= 0:
			errors.append("fire_interval must be > 0")

	if weapon_type == WeaponType.MELEE:
		if melee_damage < 0:
			errors.append("melee_damage cannot be negative")

		if melee_range <= 0:
			errors.append("melee_range must be > 0")

	if has_ammo and not infinite_ammo:
		if max_ammo <= 0:
			errors.append("max_ammo must be > 0")

		if starting_ammo > max_ammo:
			errors.append("starting_ammo cannot exceed max_ammo")

	return errors

## EntityDefinition - Data-driven entity configuration
##
## Design: Resource-based entity configuration (similar to TrainingSequence)
## Defines what components an entity has and how they're configured
##
## Usage:
## 1. Create .tres file in Godot Editor or via script
## 2. Configure component configs (health, movement, visual, etc.)
## 3. Load definition and create entity from it
##
## Example:
## ```gdscript
## var def = load("res://resources/entity_definitions/training_drone.tres")
## var entity = BaseEntity.new()
## entity.entity_definition = def
## add_child(entity)  # Components auto-spawn from definition
## ```
##
## Benefits:
## - No code changes needed for new entities
## - Version control friendly (.tres text format)
## - Can be edited in Godot Inspector
## - Validated before use
class_name EntityDefinition
extends Resource

# =============================================================================
# IDENTITY
# =============================================================================

## Unique identifier for this entity type
@export var entity_id: String = ""

## Display name for UI/debugging
@export var display_name: String = ""

## Description of this entity
@export_multiline var description: String = ""

## Entity category (enemy, ally, neutral, object)
@export var category: String = "enemy"

## Tags for filtering/searching
@export var tags: Array[String] = []

# =============================================================================
# COMPONENT CONFIGURATIONS
# =============================================================================

@export_group("Component Configs")

## Health component configuration
@export var health_config: Resource  # HealthComponentConfig

## Movement component configuration
@export var movement_config: Resource  # MovementComponentConfig

## Visual component configuration
@export var visual_config: Resource  # VisualComponentConfig

## Behavior/AI component configuration
@export var behavior_config: Resource  # BehaviorComponentConfig

## Weapon component configuration
@export var weapon_config: Resource  # WeaponComponentConfig

## Targeting component configuration
@export var targeting_config: Resource  # TargetingComponentConfig

## Audio component configuration
@export var audio_config: Resource  # AudioComponentConfig

## Physics component configuration
@export var physics_config: Resource  # PhysicsComponentConfig

# =============================================================================
# GAMEPLAY PROPERTIES
# =============================================================================

@export_group("Gameplay")

## Experience/points awarded when destroyed
@export var xp_value: int = 10

## Score points awarded
@export var score_value: int = 100

## Difficulty rating (affects spawn costs)
@export_range(1, 10) var difficulty_rating: int = 1

## Can be targeted by player
@export var is_targetable: bool = true

## Can be damaged
@export var is_damageable: bool = true

## Collides with other entities
@export var is_solid: bool = true

# =============================================================================
# SPAWN PROPERTIES
# =============================================================================

@export_group("Spawning")

## Default spawn height offset
@export var spawn_height_offset: float = 0.0

## Spawn effect scene (particles, flash, etc.)
@export var spawn_effect: PackedScene

## Spawn sound
@export var spawn_sound: AudioStream

## Spawn animation duration
@export var spawn_duration: float = 0.5

# =============================================================================
# DESTRUCTION PROPERTIES
# =============================================================================

@export_group("Destruction")

## Death effect scene
@export var death_effect: PackedScene

## Death sound
@export var death_sound: AudioStream

## Items/loot to drop on death
@export var loot_table: Array[Resource] = []  # LootEntry resources

## Delay before removing corpse
@export var corpse_lifetime: float = 2.0

# =============================================================================
# METADATA
# =============================================================================

@export_group("Metadata")

## Version number (for save compatibility)
@export var version: int = 1

## Author/creator
@export var author: String = ""

## Creation date
@export var created_date: String = ""

## Last modified date
@export var modified_date: String = ""

# =============================================================================
# HELPER METHODS
# =============================================================================

## Get entity identifier
func get_entity_id() -> String:
	return entity_id


## Check if entity has a specific component configured
func has_component_config(component_name: String) -> bool:
	match component_name:
		"health", "Health", "HealthComponent":
			return health_config != null
		"movement", "Movement", "MovementComponent":
			return movement_config != null
		"visual", "Visual", "VisualComponent":
			return visual_config != null
		"behavior", "Behavior", "BehaviorComponent":
			return behavior_config != null
		"weapon", "Weapon", "WeaponComponent":
			return weapon_config != null
		"targeting", "Targeting", "TargetingComponent":
			return targeting_config != null
		"audio", "Audio", "AudioComponent":
			return audio_config != null
		"physics", "Physics", "PhysicsComponent":
			return physics_config != null
		_:
			return false


## Get component count
func get_component_count() -> int:
	var count := 0
	if health_config != null: count += 1
	if movement_config != null: count += 1
	if visual_config != null: count += 1
	if behavior_config != null: count += 1
	if weapon_config != null: count += 1
	if targeting_config != null: count += 1
	if audio_config != null: count += 1
	if physics_config != null: count += 1
	return count


## Validate entity definition
func validate() -> Array[String]:
	var errors: Array[String] = []

	# Required fields
	if entity_id.is_empty():
		errors.append("entity_id is required")

	if display_name.is_empty():
		errors.append("display_name is required")

	# Must have at least one component
	if get_component_count() == 0:
		errors.append("Entity must have at least one component configured")

	# Validate component configs (if they have validate() method)
	if health_config != null and health_config.has_method("validate"):
		var comp_errors := health_config.validate()
		for err in comp_errors:
			errors.append("health_config: %s" % err)

	if movement_config != null and movement_config.has_method("validate"):
		var comp_errors := movement_config.validate()
		for err in comp_errors:
			errors.append("movement_config: %s" % err)

	if visual_config != null and visual_config.has_method("validate"):
		var comp_errors := visual_config.validate()
		for err in comp_errors:
			errors.append("visual_config: %s" % err)

	if behavior_config != null and behavior_config.has_method("validate"):
		var comp_errors := behavior_config.validate()
		for err in comp_errors:
			errors.append("behavior_config: %s" % err)

	if weapon_config != null and weapon_config.has_method("validate"):
		var comp_errors := weapon_config.validate()
		for err in comp_errors:
			errors.append("weapon_config: %s" % err)

	return errors


## Check if definition is valid
func is_valid() -> bool:
	return validate().is_empty()


## Get summary for logging
func get_summary() -> String:
	return "%s (%s) - %d components, difficulty %d" % [
		display_name,
		entity_id,
		get_component_count(),
		difficulty_rating
	]


## Convert to dictionary for serialization
func to_dict() -> Dictionary:
	return {
		"entity_id": entity_id,
		"display_name": display_name,
		"category": category,
		"component_count": get_component_count(),
		"difficulty": difficulty_rating,
		"xp_value": xp_value,
		"score_value": score_value,
		"version": version
	}

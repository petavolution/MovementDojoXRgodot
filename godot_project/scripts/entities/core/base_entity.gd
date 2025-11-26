## BaseEntity - Composition root for component-based entities
##
## Design Philosophy:
## - Entity is a lightweight container that owns components
## - Components do the actual work (health, movement, visuals, etc.)
## - Entity routes lifecycle events to all components
## - Data-driven configuration via EntityDefinition Resource
## - Minimal game logic in entity (delegate to components)
##
## Architecture Pattern: Composition over Inheritance
## Instead of:
##   TrainingDroid extends Entity (500 lines of mixed logic)
## We have:
##   TrainingDroid extends BaseEntity
##     ├─ HealthComponent
##     ├─ MovementComponent
##     ├─ VisualComponent
##     ├─ WeaponComponent
##     └─ BehaviorComponent
##
## Lifecycle:
## 1. Entity created with EntityDefinition
## 2. _ready() spawns components from definition
## 3. Components initialized with entity reference
## 4. spawn() activates entity and components
## 5. process_components() routes updates to components
## 6. destroy() cleans up entity and components
##
## Usage:
## ```gdscript
## var entity = BaseEntity.new()
## entity.entity_definition = preload("res://resources/entity_definitions/drone.tres")
## add_child(entity)
## # Components auto-spawn from definition
## ```
class_name BaseEntity
extends Node3D

const SOURCE := "BaseEntity"

# =============================================================================
# SIGNALS
# =============================================================================

signal entity_spawned(entity: BaseEntity)
signal entity_destroyed(entity: BaseEntity)
signal entity_activated(entity: BaseEntity)
signal entity_deactivated(entity: BaseEntity)

# =============================================================================
# CONFIGURATION
# =============================================================================

## Entity definition (data-driven configuration)
## Load from .tres file or create programmatically
@export var entity_definition: Resource  # EntityDefinition type

## Entity unique identifier (set from definition or manually)
@export var entity_id: String = ""

## Display name for debugging
@export var display_name: String = ""

# =============================================================================
# STATE
# =============================================================================

## Whether this entity is currently active
var is_active: bool = false

## Whether entity has been spawned
var is_spawned: bool = false

## Whether entity has been initialized
var is_initialized: bool = false

# =============================================================================
# COMPONENT REFERENCES
# =============================================================================
## Common component shortcuts (populated automatically)
## Access via: entity.health.take_damage(10)

var health: EntityComponent
var movement: EntityComponent
var visual: EntityComponent
var behavior: EntityComponent
var weapon: EntityComponent
var targeting: EntityComponent
var audio: EntityComponent
var physics_comp: EntityComponent  # 'physics' conflicts with built-in

# =============================================================================
# INITIALIZATION
# =============================================================================

func _ready() -> void:
	# Load from definition if provided
	if entity_definition != null:
		_load_from_definition()

	# Set default identifiers
	if entity_id.is_empty():
		entity_id = name
	if display_name.is_empty():
		display_name = name

	# Discover any manually-added components
	_discover_components()

	# Initialize all components
	_initialize_components()

	is_initialized = true

	# Auto-spawn unless disabled
	if not is_spawned:
		spawn()


## Load entity configuration from EntityDefinition resource
func _load_from_definition() -> void:
	if entity_definition == null:
		return

	# Check if this is actually an EntityDefinition
	if not entity_definition.has_method("get_entity_id"):
		log_warn("entity_definition doesn't appear to be EntityDefinition type")
		return

	# Load identity
	entity_id = entity_definition.get("entity_id", entity_id)
	display_name = entity_definition.get("display_name", display_name)

	log_debug("Loading entity from definition: %s" % entity_id)

	# Spawn components based on definition
	_spawn_components_from_definition()


## Create component instances based on EntityDefinition
func _spawn_components_from_definition() -> void:
	if entity_definition == null:
		return

	# Health component
	if entity_definition.has("health_config") and entity_definition.health_config != null:
		var comp = _create_component("HealthComponent")
		if comp:
			comp.config = entity_definition.health_config

	# Movement component
	if entity_definition.has("movement_config") and entity_definition.movement_config != null:
		var comp = _create_component("MovementComponent")
		if comp:
			comp.config = entity_definition.movement_config

	# Visual component
	if entity_definition.has("visual_config") and entity_definition.visual_config != null:
		var comp = _create_component("VisualComponent")
		if comp:
			comp.config = entity_definition.visual_config

	# Behavior component
	if entity_definition.has("behavior_config") and entity_definition.behavior_config != null:
		var comp = _create_component("BehaviorComponent")
		if comp:
			comp.config = entity_definition.behavior_config

	# Weapon component
	if entity_definition.has("weapon_config") and entity_definition.weapon_config != null:
		var comp = _create_component("WeaponComponent")
		if comp:
			comp.config = entity_definition.weapon_config


## Create and add a component by class name
func _create_component(class_name: String) -> EntityComponent:
	if not ClassDB.class_exists(class_name):
		log_warn("Component class '%s' not found" % class_name)
		return null

	var comp = ClassDB.instantiate(class_name) as EntityComponent
	if comp == null:
		log_warn("Failed to instantiate component '%s'" % class_name)
		return null

	comp.name = class_name.replace("Component", "")
	add_child(comp)
	log_debug("Created component: %s" % class_name)

	return comp


## Discover components that were manually added as children
func _discover_components() -> void:
	health = null
	movement = null
	visual = null
	behavior = null
	weapon = null
	targeting = null
	audio = null
	physics_comp = null

	for child in get_children():
		if not child is EntityComponent:
			continue

		var comp := child as EntityComponent
		var type_name := comp.get_script().get_global_name() if comp.get_script() else ""

		# Populate component shortcuts
		match type_name:
			"HealthComponent":
				health = comp
			"MovementComponent":
				movement = comp
			"VisualComponent":
				visual = comp
			"BehaviorComponent":
				behavior = comp
			"WeaponComponent":
				weapon = comp
			"TargetingComponent":
				targeting = comp
			"AudioComponent":
				audio = comp
			"PhysicsComponent":
				physics_comp = comp


## Initialize all components
func _initialize_components() -> void:
	for child in get_children():
		if child is EntityComponent:
			var comp := child as EntityComponent
			comp.initialize(self, comp.config)


# =============================================================================
# LIFECYCLE
# =============================================================================

## Spawn/activate the entity
func spawn() -> void:
	if is_spawned:
		log_warn("Entity already spawned")
		return

	is_spawned = true
	is_active = true

	log_debug("Spawning entity: %s" % entity_id)

	# Notify all components
	for child in get_children():
		if child is EntityComponent:
			child.on_entity_spawned()

	entity_spawned.emit(self)
	entity_activated.emit(self)


## Destroy the entity
func destroy() -> void:
	if not is_spawned:
		log_warn("Entity not spawned, cannot destroy")
		return

	log_debug("Destroying entity: %s" % entity_id)

	is_active = false

	# Notify all components
	for child in get_children():
		if child is EntityComponent:
			child.on_entity_destroyed()

	entity_destroyed.emit(self)

	# Queue for removal
	queue_free()


## Activate entity (enable component updates)
func activate() -> void:
	if is_active:
		return

	is_active = true
	entity_activated.emit(self)
	log_debug("Entity activated: %s" % entity_id)


## Deactivate entity (disable component updates)
func deactivate() -> void:
	if not is_active:
		return

	is_active = false
	entity_deactivated.emit(self)
	log_debug("Entity deactivated: %s" % entity_id)


# =============================================================================
# UPDATE
# =============================================================================

func _process(delta: float) -> void:
	if not is_active or not is_spawned:
		return

	process_components(delta)


## Update all components
func process_components(delta: float) -> void:
	for child in get_children():
		if child is EntityComponent and child.is_active:
			child.process_component(delta)


# =============================================================================
# COMPONENT ACCESS
# =============================================================================

## Get component by type (type-safe)
## Example: var health = entity.get_component(HealthComponent)
func get_component(component_class: GDScript) -> EntityComponent:
	for child in get_children():
		if is_instance_of(child, component_class):
			return child
	return null


## Check if entity has a component type
func has_component(component_class: GDScript) -> bool:
	return get_component(component_class) != null


## Get all components
func get_components() -> Array[EntityComponent]:
	var components: Array[EntityComponent] = []
	for child in get_children():
		if child is EntityComponent:
			components.append(child)
	return components


## Get components by tag/category
func get_components_by_tag(tag: String) -> Array[EntityComponent]:
	var components: Array[EntityComponent] = []
	for child in get_children():
		if child is EntityComponent:
			# Check if component has matching tag (if implemented)
			if child.has_method("has_tag") and child.has_tag(tag):
				components.append(child)
	return components


# =============================================================================
# HELPER METHODS
# =============================================================================

## Log debug message with entity context
func log_debug(message: String) -> void:
	DebugLogger.debug(SOURCE, "[%s] %s" % [entity_id, message])


## Log info message with entity context
func log_info(message: String) -> void:
	DebugLogger.info(SOURCE, "[%s] %s" % [entity_id, message])


## Log warning with entity context
func log_warn(message: String) -> void:
	DebugLogger.warn(SOURCE, "[%s] %s" % [entity_id, message])


## Log error with entity context
func log_error(message: String) -> void:
	DebugLogger.error(SOURCE, "[%s] %s" % [entity_id, message])


# =============================================================================
# DEBUGGING
# =============================================================================

## Get entity status for debugging
func get_debug_info() -> Dictionary:
	var component_info := []
	for comp in get_components():
		component_info.append(comp.get_debug_info())

	return {
		"entity_id": entity_id,
		"display_name": display_name,
		"is_active": is_active,
		"is_spawned": is_spawned,
		"is_initialized": is_initialized,
		"component_count": get_components().size(),
		"components": component_info
	}


## Print debug information
func print_debug_info() -> void:
	var info := get_debug_info()
	print("\n=== Entity Debug Info ===")
	print("Entity: %s (%s)" % [info.display_name, info.entity_id])
	print("Active: %s | Spawned: %s | Initialized: %s" % [info.is_active, info.is_spawned, info.is_initialized])
	print("Components: %d" % info.component_count)
	for comp_info in info.components:
		print("  - %s (%s) [Active: %s]" % [comp_info.component_id, comp_info.type, comp_info.is_active])
	print("=========================\n")

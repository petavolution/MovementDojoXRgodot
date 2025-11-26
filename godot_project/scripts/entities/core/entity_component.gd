## EntityComponent - Base class for all entity components
##
## Design Philosophy:
## - Components are modular, reusable building blocks
## - Each component handles ONE responsibility (Single Responsibility Principle)
## - Components communicate via signals, not direct coupling
## - Components are configured via Resource objects (data-driven)
## - Entity owns components; components reference entity
##
## Lifecycle:
## 1. Component created and added as child to BaseEntity
## 2. initialize() called with entity reference and config
## 3. on_entity_spawned() called when entity becomes active
## 4. process_component() called every frame while entity active
## 5. on_entity_destroyed() called before entity removal
##
## Usage:
## ```gdscript
## class_name HealthComponent
## extends EntityComponent
##
## func _on_initialized() -> void:
##     # Setup from config
##     pass
##
## func process_component(delta: float) -> void:
##     # Per-frame logic
##     pass
## ```
class_name EntityComponent
extends Node

const SOURCE := "EntityComponent"

# =============================================================================
# PROPERTIES
# =============================================================================

## Reference to owning entity (set during initialize())
var entity: Node3D

## Configuration resource for this component (optional)
## Subclasses should use typed configs (e.g., HealthComponentConfig)
var config: Resource

## Whether this component is currently active
var is_active: bool = false

## Component identifier (for debugging)
var component_id: String = ""

# =============================================================================
# LIFECYCLE
# =============================================================================

## Initialize component with owner entity and optional config
## Called by BaseEntity after component is added as child
func initialize(owner_entity: Node3D, component_config: Resource = null) -> void:
	if owner_entity == null:
		push_error("EntityComponent.initialize() called with null entity")
		return

	entity = owner_entity
	config = component_config
	component_id = name if component_id.is_empty() else component_id

	DebugLogger.debug(SOURCE, "Initializing component '%s' for entity '%s'" % [component_id, entity.name])

	# Call subclass initialization
	_on_initialized()

	# Validate after initialization
	var errors := validate()
	if not errors.is_empty():
		DebugLogger.warn(SOURCE, "Component '%s' validation warnings:" % component_id)
		for error in errors:
			DebugLogger.warn(SOURCE, "  - %s" % error)


## Override in subclasses for custom initialization logic
## Called after entity and config are set
func _on_initialized() -> void:
	pass


## Called every frame if entity is active
## Override in subclasses for per-frame logic
func process_component(delta: float) -> void:
	pass


## Called when entity spawns/activates
## Override in subclasses for spawn logic
func on_entity_spawned() -> void:
	is_active = true
	DebugLogger.debug(SOURCE, "Component '%s' spawned" % component_id)


## Called when entity is destroyed
## Override in subclasses for cleanup logic
func on_entity_destroyed() -> void:
	is_active = false
	DebugLogger.debug(SOURCE, "Component '%s' destroyed" % component_id)


# =============================================================================
# VALIDATION
# =============================================================================

## Validate component configuration and state
## Override in subclasses to add validation rules
## Returns array of error strings (empty = valid)
func validate() -> Array[String]:
	var errors: Array[String] = []

	if entity == null:
		errors.append("Component '%s' has no entity reference" % component_id)

	return errors


# =============================================================================
# HELPER METHODS
# =============================================================================

## Get sibling component by type (type-safe)
## Example: var health = get_sibling_component(HealthComponent)
func get_sibling_component(component_class: GDScript) -> EntityComponent:
	if entity == null:
		return null

	for child in entity.get_children():
		if is_instance_of(child, component_class):
			return child

	return null


## Check if entity has a specific component type
func has_sibling_component(component_class: GDScript) -> bool:
	return get_sibling_component(component_class) != null


## Get all sibling components
func get_sibling_components() -> Array[EntityComponent]:
	var components: Array[EntityComponent] = []

	if entity == null:
		return components

	for child in entity.get_children():
		if child is EntityComponent and child != self:
			components.append(child)

	return components


## Log debug message with component context
func log_debug(message: String) -> void:
	DebugLogger.debug(SOURCE, "[%s/%s] %s" % [entity.name if entity else "null", component_id, message])


## Log info message with component context
func log_info(message: String) -> void:
	DebugLogger.info(SOURCE, "[%s/%s] %s" % [entity.name if entity else "null", component_id, message])


## Log warning with component context
func log_warn(message: String) -> void:
	DebugLogger.warn(SOURCE, "[%s/%s] %s" % [entity.name if entity else "null", component_id, message])


## Log error with component context
func log_error(message: String) -> void:
	DebugLogger.error(SOURCE, "[%s/%s] %s" % [entity.name if entity else "null", component_id, message])


# =============================================================================
# DEBUGGING
# =============================================================================

## Get component status summary for debugging
func get_debug_info() -> Dictionary:
	return {
		"component_id": component_id,
		"type": get_script().get_global_name(),
		"is_active": is_active,
		"has_entity": entity != null,
		"has_config": config != null,
		"validation_errors": validate()
	}


## Print debug information about this component
func print_debug_info() -> void:
	var info := get_debug_info()
	print("\n=== Component Debug Info ===")
	print("Component: %s (%s)" % [info.component_id, info.type])
	print("Active: %s" % info.is_active)
	print("Has Entity: %s" % info.has_entity)
	print("Has Config: %s" % info.has_config)
	if not info.validation_errors.is_empty():
		print("Validation Errors:")
		for error in info.validation_errors:
			print("  - %s" % error)
	print("============================\n")

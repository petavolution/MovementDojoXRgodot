# Entity Component System

This directory contains the modular entity component architecture for Movement Dojo XR.

## Philosophy

**Composition over Inheritance** - Instead of creating large monolithic entity classes, entities are composed of small, reusable components.

**Data-Driven Configuration** - Entity behavior is configured via Resource (.tres) files, not hardcoded in scripts.

**Single Responsibility** - Each component handles one concern (health, movement, visuals, etc.)

**Testability** - Components can be tested in isolation.

**Extensibility** - New entity types = new combinations of components.

## Architecture

```
BaseEntity (Node3D)
├── EntityDefinition (.tres) - Data-driven configuration
└── Components (children)
    ├── HealthComponent - Health, damage, death
    ├── MovementComponent - Position, velocity, pathing
    ├── VisualComponent - Mesh, materials, effects
    ├── BehaviorComponent - AI, state machine
    ├── WeaponComponent - Shooting, melee
    └── ... (extensible)
```

## Directory Structure

```
entities/
├── core/
│   ├── entity_component.gd         # Base class for all components
│   ├── base_entity.gd              # Composition root
│   └── entity_definition.gd        # Resource configuration
│
├── components/                     # Component implementations
│   ├── health_component.gd
│   ├── movement_component.gd
│   ├── visual_component.gd
│   ├── behavior_component.gd       # TODO
│   ├── weapon_component.gd         # TODO
│   └── ... (add more as needed)
│
├── configs/                        # Component configurations
│   ├── health_component_config.gd
│   ├── movement_component_config.gd
│   ├── visual_component_config.gd
│   └── ... (one per component type)
│
├── behaviors/                      # Behavior implementations
│   ├── hover_behavior.gd           # TODO
│   ├── orbit_behavior.gd           # TODO
│   └── ... (reusable AI behaviors)
│
└── types/                          # Concrete entity subclasses
    ├── training_drone_entity.gd    # TODO
    └── ... (entity-specific logic)
```

## Quick Start

### 1. Create Entity Definition (.tres)

```gdscript
# In Godot Editor:
# 1. Right-click resources/entity_definitions/
# 2. New Resource → EntityDefinition
# 3. Configure component configs
# 4. Save as training_drone.tres
```

### 2. Use in Scene

```gdscript
# Load and spawn entity
var entity_def = preload("res://resources/entity_definitions/training_drone.tres")
var entity = BaseEntity.new()
entity.entity_definition = entity_def
add_child(entity)
# Components auto-spawn from definition
```

### 3. Access Components

```gdscript
# Type-safe component access
var health = entity.health as HealthComponent
health.take_damage(25.0)

# Or use get_component()
var movement = entity.get_component(MovementComponent)
movement.set_orbit(player.position, 3.0, 1.0)
```

## Core Components

### HealthComponent

**Responsibilities:**
- Track current/max health
- Process damage and healing
- Handle invulnerability
- Trigger death effects

**Config:** `HealthComponentConfig`

**Key Methods:**
```gdscript
health.take_damage(amount: float, source: Node) -> bool
health.heal(amount: float) -> void
health.is_alive() -> bool
health.get_health_percentage() -> float
health.set_invulnerable(value: bool) -> void
health.kill() -> void
```

**Signals:**
```gdscript
health_changed(current, max, percentage)
damage_taken(amount, final_amount, source)
healed(amount)
death(final_position)
invulnerability_changed(is_invulnerable)
```

### MovementComponent

**Responsibilities:**
- Update entity position
- Handle movement patterns (hover, orbit, follow, patrol)
- Enforce movement constraints
- Path to targets

**Config:** `MovementComponentConfig`

**Movement Types:**
- `STATIC` - No movement
- `HOVER` - Bob in place
- `ORBIT` - Circle around point
- `FOLLOW` - Follow target node
- `PATROL` - Waypoint patrol
- `WANDER` - Random movement
- `CUSTOM` - Behavior-driven

**Key Methods:**
```gdscript
movement.move_to(target: Vector3) -> void
movement.stop() -> void
movement.set_orbit(center: Vector3, radius: float, speed: float) -> void
movement.set_follow_target(target: Node3D) -> void
movement.teleport_to(position: Vector3) -> void
```

**Signals:**
```gdscript
movement_started()
movement_stopped()
target_reached(target)
waypoint_reached(index)
```

### VisualComponent

**Responsibilities:**
- Create/load mesh
- Manage materials and colors
- Play visual effects (damage flash, death dissolve)
- Handle idle animations
- Add lights and particles

**Config:** `VisualComponentConfig`

**Visual Types:**
- `PROCEDURAL_MESH` - Create sphere/cube/cylinder/capsule
- `SCENE` - Load .tscn/.glb file
- `MESH_RESOURCE` - Load .mesh file

**Key Methods:**
```gdscript
visual.set_color(color: Color) -> void
visual.play_damage_flash(color: Color, duration: float) -> void
visual.play_death_dissolve(duration: float) -> void
visual.set_emission(color: Color, energy: float) -> void
visual.set_visible(visible: bool) -> void
```

**Signals:**
```gdscript
visual_created()
color_changed(new_color)
damage_flash_started()
death_dissolve_started()
```

## Creating New Components

### 1. Create Component Config

```gdscript
# scripts/entities/configs/my_component_config.gd
class_name MyComponentConfig
extends Resource

@export var property1: float = 1.0
@export var property2: String = "default"

func validate() -> Array[String]:
    var errors: Array[String] = []
    if property1 < 0:
        errors.append("property1 cannot be negative")
    return errors
```

### 2. Create Component Implementation

```gdscript
# scripts/entities/components/my_component.gd
class_name MyComponent
extends EntityComponent

var property1: float
var _config: MyComponentConfig

func _on_initialized() -> void:
    component_id = "MyComponent"
    if config is MyComponentConfig:
        _config = config
        property1 = _config.property1

func process_component(delta: float) -> void:
    # Per-frame logic here
    pass

func on_entity_spawned() -> void:
    super.on_entity_spawned()
    # Spawn logic here

func on_entity_destroyed() -> void:
    super.on_entity_destroyed()
    # Cleanup logic here
```

### 3. Add to EntityDefinition

```gdscript
# scripts/entities/core/entity_definition.gd
@export var my_component_config: Resource  # MyComponentConfig

# In base_entity.gd _spawn_components_from_definition():
if entity_definition.has("my_component_config") and entity_definition.my_component_config != null:
    var comp = _create_component("MyComponent")
    if comp:
        comp.config = entity_definition.my_component_config
```

## Component Lifecycle

```
1. Entity created with EntityDefinition
   ↓
2. _ready() called on BaseEntity
   ↓
3. Components spawned from definition
   ↓
4. initialize(entity, config) called on each component
   ↓
5. _on_initialized() called (component setup)
   ↓
6. spawn() called on entity
   ↓
7. on_entity_spawned() called on each component
   ↓
8. process_component(delta) called every frame
   ↓
9. destroy() called on entity
   ↓
10. on_entity_destroyed() called on each component
    ↓
11. Components queue_free()
```

## Component Communication

### Via Signals (Preferred)

```gdscript
# HealthComponent
func take_damage(amount: float) -> void:
    # ...
    damage_taken.emit(amount, source)

# BehaviorComponent listens
func _on_initialized() -> void:
    var health = get_sibling_component(HealthComponent)
    health.damage_taken.connect(_on_damage_taken)

func _on_damage_taken(amount: float, source: Node) -> void:
    # React to damage (flee, attack back, etc.)
```

### Via Direct Access (When Needed)

```gdscript
# Get sibling component
var health = get_sibling_component(HealthComponent)
if health:
    var is_low = health.is_low_health()
```

### Via Entity Events

```gdscript
# Entity signals bubble up
entity.entity_destroyed.connect(_on_entity_destroyed)
```

## Data-Driven Workflow

### Design Workflow

1. **Define components** - What does this entity need? (health, movement, visual)
2. **Configure in Inspector** - Create EntityDefinition .tres, set properties
3. **Test and iterate** - Tweak values in Inspector, no code changes
4. **Version control** - Commit .tres files (text format, git-friendly)

### Example: Create Training Drone

```
1. Create HealthComponentConfig .tres:
   - max_health: 50
   - damage_flash: true
   - death_effect: explosion.tscn

2. Create MovementComponentConfig .tres:
   - movement_type: ORBIT
   - orbit_radius: 2.0
   - orbit_speed: 1.0

3. Create VisualComponentConfig .tres:
   - mesh_shape: SPHERE
   - mesh_size: 0.25
   - color: Color(0.8, 0.2, 0.2)
   - idle_animation: ROTATE_Y

4. Create EntityDefinition .tres:
   - entity_id: "training_drone_basic"
   - health_config: → HealthComponentConfig
   - movement_config: → MovementComponentConfig
   - visual_config: → VisualComponentConfig

5. Done! No code written.
```

## Migration from Monolithic Entities

### Before (Monolithic)

```gdscript
# training_droid.gd (500+ lines)
class_name TrainingDroid
extends CharacterBody3D

var health: float = 100.0
var max_health: float = 100.0
var move_speed: float = 2.0
var attack_range: float = 1.5
# ... 50 more properties

func _ready():
    _create_visual()
    _setup_attack_patterns()
    # ... 100 lines of setup

func _physics_process(delta):
    _process_movement(delta)
    _process_combat(delta)
    _process_visual(delta)
    # ... mixed responsibilities

func take_damage(amount: float):
    # ... 50 lines of damage logic
```

### After (Component-Based)

```gdscript
# Entity definition (.tres file)
EntityDefinition:
  entity_id: "training_droid"
  health_config: → HealthComponentConfig
  movement_config: → MovementComponentConfig
  visual_config: → VisualComponentConfig
  behavior_config: → BehaviorComponentConfig

# Usage
var entity = BaseEntity.new()
entity.entity_definition = preload("res://resources/entity_definitions/training_droid.tres")
add_child(entity)

# That's it! Components handle everything.
```

## Benefits

### For Developers

✅ **Modularity** - Components are 100-200 lines, not 500+
✅ **Reusability** - Share HealthComponent across all entities
✅ **Testability** - Test HealthComponent in isolation
✅ **Maintainability** - Fix health bugs in one place
✅ **Extensibility** - New entity = combine existing components

### For Designers

✅ **No coding required** - Configure entities in Inspector
✅ **Fast iteration** - Tweak values, see results immediately
✅ **Visual editing** - See properties with nice UI
✅ **Safe experimentation** - Can't break code structure

### For the Project

✅ **Fewer bugs** - Components are well-tested
✅ **Faster development** - Reuse instead of rewrite
✅ **Better collaboration** - Designers don't need programmers
✅ **Easier onboarding** - Clear component boundaries
✅ **Game variations** - Swap components for different modes

## Next Steps

### Phase 2: Additional Components

- [ ] BehaviorComponent (AI, state machines)
- [ ] WeaponComponent (shooting, melee)
- [ ] TargetingComponent (player tracking)
- [ ] AudioComponent (spatial sound)
- [ ] PhysicsComponent (collision, forces)

### Phase 3: Refactor Existing Entities

- [ ] Convert SimpleDrone to component-based
- [ ] Convert TrainingTarget to component-based
- [ ] Convert TrainingDroid to component-based
- [ ] Remove old monolithic scripts

### Phase 4: Advanced Features

- [ ] Component tags/categories
- [ ] Component dependencies
- [ ] Hot-reloading entity definitions
- [ ] Visual entity editor
- [ ] Entity templates/presets

## Best Practices

1. **Keep components focused** - One responsibility per component
2. **Use signals for communication** - Avoid tight coupling
3. **Validate configurations** - Implement validate() methods
4. **Log generously** - Use component logging helpers
5. **Handle null gracefully** - Components may not exist
6. **Document component APIs** - Clear docstrings
7. **Test components individually** - Unit test each component
8. **Version entity definitions** - Track changes in git

## Troubleshooting

### Components not spawning

- Check EntityDefinition has configs set
- Verify component class names match
- Look for initialization errors in logs

### Components not communicating

- Use signals instead of direct calls
- Check component is active (is_active)
- Verify sibling components exist

### Visual not appearing

- Check VisualComponentConfig is complete
- Verify mesh_size > 0
- Check entity is visible in scene tree

### Movement not working

- Verify movement_type is set
- Check is_moving = true
- Ensure entity.is_active = true

## See Also

- `core/entity_component.gd` - Base component class
- `core/base_entity.gd` - Entity composition root
- `core/entity_definition.gd` - Configuration resource
- `docs/ACTION_PLAN.md` - Development roadmap
- `docu/project-vision5.md` - Project architecture

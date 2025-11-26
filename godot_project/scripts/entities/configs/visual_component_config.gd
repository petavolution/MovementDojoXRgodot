## VisualComponentConfig - Configuration for VisualComponent
##
## Data-driven visual appearance configuration
## Save as .tres and assign to EntityDefinition.visual_config
class_name VisualComponentConfig
extends Resource

# =============================================================================
# MESH/MODEL
# =============================================================================

enum VisualType {
	PROCEDURAL_MESH,  ## Create mesh procedurally
	SCENE,            ## Load from .tscn/.glb file
	MESH_RESOURCE     ## Load from .mesh/.res file
}

@export var visual_type: VisualType = VisualType.PROCEDURAL_MESH

## Mesh shape (for procedural)
enum MeshShape {
	SPHERE,
	CUBE,
	CYLINDER,
	CAPSULE,
	CUSTOM
}

@export var mesh_shape: MeshShape = MeshShape.SPHERE

## Mesh radius/size
@export var mesh_size: float = 0.25

## Mesh detail level (segments/subdivisions)
@export_range(4, 64) var mesh_detail: int = 16

## Scene file to load (for SCENE type)
@export var scene_path: String = ""

## Mesh resource to load (for MESH_RESOURCE type)
@export var mesh_resource: Mesh

# =============================================================================
# MATERIALS
# =============================================================================

@export_group("Materials")

## Base color/albedo
@export var color: Color = Color(0.8, 0.2, 0.2)

## Metallic value (0-1)
@export_range(0.0, 1.0) var metallic: float = 0.3

## Roughness value (0-1)
@export_range(0.0, 1.0) var roughness: float = 0.7

## Enable emission
@export var emission_enabled: bool = false

## Emission color
@export var emission_color: Color = Color.BLACK

## Emission energy
@export var emission_energy: float = 1.0

## Custom material (overrides procedural material)
@export var custom_material: Material

# =============================================================================
# EFFECTS
# =============================================================================

@export_group("Effects")

## Enable glow/bloom effect
@export var glow_enabled: bool = false

## Glow intensity
@export var glow_intensity: float = 1.0

## Enable outline effect
@export var outline_enabled: bool = false

## Outline color
@export var outline_color: Color = Color.WHITE

## Outline width
@export var outline_width: float = 0.05

## Shield effect (bubble around entity)
@export var shield_effect: PackedScene

# =============================================================================
# ANIMATION
# =============================================================================

@export_group("Animation")

## Idle animation (rotation, bob, etc.)
enum IdleAnimation {
	NONE,
	ROTATE_Y,       ## Spin around Y axis
	BOB,            ## Vertical bobbing
	PULSE,          ## Scale pulsing
	ROTATE_AND_BOB  ## Both rotation and bob
}

@export var idle_animation: IdleAnimation = IdleAnimation.NONE

## Animation speed multiplier
@export var animation_speed: float = 1.0

## Animation amplitude (for bob/pulse)
@export var animation_amplitude: float = 0.1

# =============================================================================
# VISUAL FEEDBACK
# =============================================================================

@export_group("Visual Feedback")

## Flash on damage
@export var damage_flash: bool = true

## Damage flash color
@export var damage_flash_color: Color = Color(1.0, 0.3, 0.3)

## Damage flash duration
@export var damage_flash_duration: float = 0.1

## Dissolve/fade on death
@export var death_dissolve: bool = true

## Death dissolve duration
@export var death_dissolve_duration: float = 0.5

# =============================================================================
# LIGHTS
# =============================================================================

@export_group("Lights")

## Add omni light
@export var has_light: bool = false

## Light color
@export var light_color: Color = Color.WHITE

## Light energy/brightness
@export var light_energy: float = 1.0

## Light range
@export var light_range: float = 2.0

# =============================================================================
# PARTICLES
# =============================================================================

@export_group("Particles")

## Idle particle effect
@export var idle_particles: PackedScene

## Trail particle effect
@export var trail_particles: PackedScene

## Spawn particle effect
@export var spawn_particles: PackedScene

# =============================================================================
# SCALE/TRANSFORM
# =============================================================================

@export_group("Transform")

## Base scale multiplier
@export var scale_multiplier: float = 1.0

## Billboard mode (always face camera)
@export var billboard: bool = false

## Offset from entity origin
@export var visual_offset: Vector3 = Vector3.ZERO

## Rotation offset
@export var rotation_offset: Vector3 = Vector3.ZERO

# =============================================================================
# OPTIMIZATION
# =============================================================================

@export_group("Optimization")

## LOD (Level of Detail) distances
@export var lod_distances: Array[float] = []

## Shadow casting mode
enum ShadowMode {
	OFF,
	ON,
	SHADOWS_ONLY
}

@export var shadow_mode: ShadowMode = ShadowMode.ON

## Visibility range (cull beyond this distance)
@export var visibility_range: float = 50.0

# =============================================================================
# VALIDATION
# =============================================================================

func validate() -> Array[String]:
	var errors: Array[String] = []

	if mesh_size <= 0:
		errors.append("mesh_size must be > 0")

	if visual_type == VisualType.SCENE and scene_path.is_empty():
		errors.append("scene_path required for SCENE visual type")

	if visual_type == VisualType.MESH_RESOURCE and mesh_resource == null:
		errors.append("mesh_resource required for MESH_RESOURCE visual type")

	if scale_multiplier <= 0:
		errors.append("scale_multiplier must be > 0")

	return errors

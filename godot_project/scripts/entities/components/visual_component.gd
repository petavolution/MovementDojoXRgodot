## VisualComponent - Manages entity visual appearance
##
## Responsibilities:
## - Create/load mesh and materials
## - Handle visual effects (damage flash, death dissolve)
## - Manage lights and particles
## - Play idle animations (rotation, bob, pulse)
##
## Configuration: VisualComponentConfig Resource
##
## Usage:
## ```gdscript
## var visual = entity.get_component(VisualComponent)
## visual.play_damage_flash(Color.RED, 0.1)
## visual.set_color(Color.BLUE)
## ```
class_name VisualComponent
extends EntityComponent

# =============================================================================
# SIGNALS
# =============================================================================

signal visual_created()
signal color_changed(new_color: Color)
signal damage_flash_started()
signal death_dissolve_started()

# =============================================================================
# PROPERTIES
# =============================================================================

var current_color: Color = Color(0.8, 0.2, 0.2)
var current_emission: Color = Color.BLACK

# Visual nodes
var mesh_instance: MeshInstance3D
var material: StandardMaterial3D
var light: OmniLight3D

# Private state
var _config: VisualComponentConfig
var _base_color: Color
var _damage_flash_timer: float = 0.0
var _damage_flash_color: Color
var _animation_phase: float = 0.0
var _base_scale: Vector3

# =============================================================================
# INITIALIZATION
# =============================================================================

func _on_initialized() -> void:
	component_id = "Visual"

	# Load from config
	if config is VisualComponentConfig:
		_config = config
		current_color = _config.color
		_base_color = _config.color

		log_debug("Initialized: shape=%s, color=%s" % [
			VisualComponentConfig.MeshShape.keys()[_config.mesh_shape],
			_config.color
		])
	else:
		log_warn("No VisualComponentConfig provided, using defaults")


func on_entity_spawned() -> void:
	super.on_entity_spawned()

	# Create visual representation
	_create_visual()

	# Add light if configured
	if _config and _config.has_light:
		_create_light()

	# Store base scale for animations
	if mesh_instance:
		_base_scale = mesh_instance.scale

	# Random animation phase
	_animation_phase = randf() * TAU

	visual_created.emit()

# =============================================================================
# VISUAL CREATION
# =============================================================================

func _create_visual() -> void:
	if not _config:
		log_warn("No config, cannot create visual")
		return

	match _config.visual_type:
		VisualComponentConfig.VisualType.PROCEDURAL_MESH:
			_create_procedural_mesh()

		VisualComponentConfig.VisualType.SCENE:
			_load_scene()

		VisualComponentConfig.VisualType.MESH_RESOURCE:
			_load_mesh_resource()


func _create_procedural_mesh() -> void:
	mesh_instance = MeshInstance3D.new()
	mesh_instance.name = "Mesh"

	# Create mesh based on shape
	var mesh: Mesh
	match _config.mesh_shape:
		VisualComponentConfig.MeshShape.SPHERE:
			var sphere := SphereMesh.new()
			sphere.radius = _config.mesh_size
			sphere.height = _config.mesh_size * 2
			sphere.radial_segments = _config.mesh_detail
			sphere.rings = _config.mesh_detail / 2
			mesh = sphere

		VisualComponentConfig.MeshShape.CUBE:
			var cube := BoxMesh.new()
			cube.size = Vector3.ONE * _config.mesh_size * 2
			mesh = cube

		VisualComponentConfig.MeshShape.CYLINDER:
			var cylinder := CylinderMesh.new()
			cylinder.top_radius = _config.mesh_size
			cylinder.bottom_radius = _config.mesh_size
			cylinder.height = _config.mesh_size * 2
			cylinder.radial_segments = _config.mesh_detail
			mesh = cylinder

		VisualComponentConfig.MeshShape.CAPSULE:
			var capsule := CapsuleMesh.new()
			capsule.radius = _config.mesh_size
			capsule.height = _config.mesh_size * 3
			capsule.radial_segments = _config.mesh_detail
			mesh = capsule

	# Create material
	if _config.custom_material:
		material = _config.custom_material
	else:
		_create_standard_material()

	mesh_instance.mesh = mesh
	mesh_instance.material_override = material

	# Apply transform
	mesh_instance.position = _config.visual_offset
	mesh_instance.rotation = _config.rotation_offset
	mesh_instance.scale = Vector3.ONE * _config.scale_multiplier

	entity.add_child(mesh_instance)

	log_debug("Created procedural mesh: %s" % VisualComponentConfig.MeshShape.keys()[_config.mesh_shape])


func _create_standard_material() -> void:
	material = StandardMaterial3D.new()
	material.albedo_color = _config.color
	material.metallic = _config.metallic
	material.roughness = _config.roughness

	if _config.emission_enabled:
		material.emission_enabled = true
		material.emission = _config.emission_color
		material.emission_energy_multiplier = _config.emission_energy
		current_emission = _config.emission_color
	else:
		material.emission_enabled = false
		material.emission = Color.BLACK
		current_emission = Color.BLACK


func _load_scene() -> void:
	if _config.scene_path.is_empty():
		log_error("Scene path is empty")
		return

	var scene := load(_config.scene_path) as PackedScene
	if not scene:
		log_error("Failed to load scene: %s" % _config.scene_path)
		return

	var instance := scene.instantiate()
	entity.add_child(instance)

	# Try to find MeshInstance3D in scene
	mesh_instance = _find_mesh_instance(instance)

	log_debug("Loaded scene: %s" % _config.scene_path)


func _load_mesh_resource() -> void:
	if not _config.mesh_resource:
		log_error("Mesh resource is null")
		return

	mesh_instance = MeshInstance3D.new()
	mesh_instance.mesh = _config.mesh_resource
	_create_standard_material()
	mesh_instance.material_override = material
	entity.add_child(mesh_instance)

	log_debug("Loaded mesh resource")


func _find_mesh_instance(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D:
		return node

	for child in node.get_children():
		var result := _find_mesh_instance(child)
		if result:
			return result

	return null


func _create_light() -> void:
	light = OmniLight3D.new()
	light.name = "Light"
	light.light_color = _config.light_color
	light.light_energy = _config.light_energy
	light.omni_range = _config.light_range

	entity.add_child(light)

	log_debug("Created light")

# =============================================================================
# UPDATE
# =============================================================================

func process_component(delta: float) -> void:
	# Damage flash
	if _damage_flash_timer > 0:
		_damage_flash_timer -= delta
		if _damage_flash_timer <= 0:
			clear_damage_flash()

	# Idle animation
	if _config and mesh_instance:
		_process_idle_animation(delta)


func _process_idle_animation(delta: float) -> void:
	_animation_phase += delta * _config.animation_speed

	match _config.idle_animation:
		VisualComponentConfig.IdleAnimation.NONE:
			pass

		VisualComponentConfig.IdleAnimation.ROTATE_Y:
			mesh_instance.rotation.y = _animation_phase

		VisualComponentConfig.IdleAnimation.BOB:
			var bob := sin(_animation_phase) * _config.animation_amplitude
			mesh_instance.position.y = _config.visual_offset.y + bob

		VisualComponentConfig.IdleAnimation.PULSE:
			var pulse := 1.0 + sin(_animation_phase) * _config.animation_amplitude
			mesh_instance.scale = _base_scale * pulse

		VisualComponentConfig.IdleAnimation.ROTATE_AND_BOB:
			mesh_instance.rotation.y = _animation_phase
			var bob := sin(_animation_phase * 0.5) * _config.animation_amplitude
			mesh_instance.position.y = _config.visual_offset.y + bob

# =============================================================================
# VISUAL EFFECTS
# =============================================================================

## Play damage flash effect
func play_damage_flash(flash_color: Color, duration: float) -> void:
	if not material:
		return

	_damage_flash_color = flash_color
	_damage_flash_timer = duration

	material.albedo_color = flash_color
	material.emission = flash_color * 2.0

	damage_flash_started.emit()


## Clear damage flash effect
func clear_damage_flash() -> void:
	if not material:
		return

	material.albedo_color = _base_color
	material.emission = current_emission


## Play death dissolve effect
func play_death_dissolve(duration: float) -> void:
	if not mesh_instance:
		return

	death_dissolve_started.emit()

	# Fade out using transparency
	var tween := entity.get_tree().create_tween()
	tween.tween_property(material, "transparency", BaseMaterial3D.TRANSPARENCY_ALPHA, 0.0)
	tween.tween_property(material, "albedo_color:a", 0.0, duration)

	log_debug("Death dissolve: %.1fs" % duration)


## Set entity color
func set_color(new_color: Color) -> void:
	current_color = new_color
	_base_color = new_color

	if material:
		material.albedo_color = new_color

	color_changed.emit(new_color)


## Set emission color
func set_emission(emission_color: Color, energy: float = 1.0) -> void:
	current_emission = emission_color

	if material:
		material.emission_enabled = true
		material.emission = emission_color
		material.emission_energy_multiplier = energy


## Clear emission
func clear_emission() -> void:
	current_emission = Color.BLACK

	if material:
		material.emission = Color.BLACK


## Set visibility
func set_visible(visible: bool) -> void:
	if mesh_instance:
		mesh_instance.visible = visible


## Get visibility
func is_visible() -> bool:
	return mesh_instance.visible if mesh_instance else false

# =============================================================================
# HELPER METHODS
# =============================================================================

## Get mesh instance (for custom modifications)
func get_mesh() -> MeshInstance3D:
	return mesh_instance


## Get material (for custom modifications)
func get_material() -> StandardMaterial3D:
	return material


## Get light (for custom modifications)
func get_light() -> OmniLight3D:
	return light

# =============================================================================
# VALIDATION
# =============================================================================

func validate() -> Array[String]:
	var errors := super.validate()

	if _config and _config.visual_type == VisualComponentConfig.VisualType.SCENE:
		if _config.scene_path.is_empty():
			errors.append("scene_path required for SCENE visual type")

	if _config and _config.visual_type == VisualComponentConfig.VisualType.MESH_RESOURCE:
		if _config.mesh_resource == null:
			errors.append("mesh_resource required for MESH_RESOURCE visual type")

	return errors

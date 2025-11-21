## ParticleManager - Centralized VFX system for Movement Dojo
## Manages particle effects with pooling for performance
class_name ParticleManager
extends Node3D

## Effect types
enum EffectType {
	BLADE_TRAIL,
	BLADE_CLASH,
	BLADE_HIT,
	TARGET_DESTROY,
	TARGET_SPAWN,
	DEFLECTION,
	FORCE_PUSH,
	FORCE_PULL,
	ACHIEVEMENT,
	COMBO_BURST,
	ZONE_DISCOVER,
	SPARKS,
	ENERGY_BURST
}

## Effect pool entry
class PooledEffect:
	var particles: GPUParticles3D
	var is_active: bool = false
	var effect_type: EffectType
	var return_time: float = 0.0


## Object pools for each effect type
var effect_pools: Dictionary = {}
var active_effects: Array[PooledEffect] = []

## Pool settings
const INITIAL_POOL_SIZE := 5
const MAX_POOL_SIZE := 20

## Effect configurations
var effect_configs: Dictionary = {}


func _ready() -> void:
	_setup_effect_configs()
	_initialize_pools()

	# Connect to game events
	if GameEvents:
		GameEvents.vfx_requested.connect(_on_vfx_requested)


func _process(delta: float) -> void:
	var current_time := Time.get_ticks_msec() / 1000.0

	# Return expired effects to pool
	var to_return: Array[PooledEffect] = []
	for effect in active_effects:
		if effect.return_time > 0 and current_time >= effect.return_time:
			to_return.append(effect)

	for effect in to_return:
		_return_to_pool(effect)


func _setup_effect_configs() -> void:
	# Blade trail - continuous effect
	effect_configs[EffectType.BLADE_TRAIL] = {
		"amount": 50,
		"lifetime": 0.5,
		"emission_shape": "sphere",
		"emission_radius": 0.02,
		"direction": Vector3(0, 0, 1),
		"spread": 10.0,
		"initial_velocity_min": 0.5,
		"initial_velocity_max": 1.0,
		"gravity": Vector3.ZERO,
		"scale_min": 0.01,
		"scale_max": 0.03,
		"color": Color(0.3, 0.8, 1.0, 0.8),
		"color_end": Color(0.1, 0.4, 1.0, 0.0),
		"duration": 0.0  # Continuous
	}

	# Blade clash - burst effect
	effect_configs[EffectType.BLADE_CLASH] = {
		"amount": 100,
		"lifetime": 0.8,
		"emission_shape": "point",
		"direction": Vector3(0, 1, 0),
		"spread": 180.0,
		"initial_velocity_min": 3.0,
		"initial_velocity_max": 6.0,
		"gravity": Vector3(0, -2, 0),
		"scale_min": 0.02,
		"scale_max": 0.05,
		"color": Color(1.0, 0.9, 0.5, 1.0),
		"color_end": Color(1.0, 0.5, 0.1, 0.0),
		"duration": 1.0
	}

	# Blade hit
	effect_configs[EffectType.BLADE_HIT] = {
		"amount": 50,
		"lifetime": 0.5,
		"emission_shape": "point",
		"direction": Vector3(0, 1, 0),
		"spread": 90.0,
		"initial_velocity_min": 2.0,
		"initial_velocity_max": 4.0,
		"gravity": Vector3(0, -3, 0),
		"scale_min": 0.015,
		"scale_max": 0.03,
		"color": Color(0.4, 0.8, 1.0, 1.0),
		"color_end": Color(0.2, 0.4, 1.0, 0.0),
		"duration": 0.8
	}

	# Target destroy
	effect_configs[EffectType.TARGET_DESTROY] = {
		"amount": 150,
		"lifetime": 1.0,
		"emission_shape": "sphere",
		"emission_radius": 0.1,
		"direction": Vector3(0, 0, 0),
		"spread": 180.0,
		"initial_velocity_min": 2.0,
		"initial_velocity_max": 5.0,
		"gravity": Vector3(0, -5, 0),
		"scale_min": 0.02,
		"scale_max": 0.06,
		"color": Color(1.0, 0.3, 0.1, 1.0),
		"color_end": Color(0.5, 0.1, 0.0, 0.0),
		"duration": 1.5
	}

	# Target spawn
	effect_configs[EffectType.TARGET_SPAWN] = {
		"amount": 30,
		"lifetime": 0.8,
		"emission_shape": "ring",
		"emission_radius": 0.2,
		"direction": Vector3(0, 1, 0),
		"spread": 30.0,
		"initial_velocity_min": 1.0,
		"initial_velocity_max": 2.0,
		"gravity": Vector3.ZERO,
		"scale_min": 0.02,
		"scale_max": 0.04,
		"color": Color(0.2, 1.0, 0.4, 0.8),
		"color_end": Color(0.1, 0.5, 0.2, 0.0),
		"duration": 1.0
	}

	# Deflection
	effect_configs[EffectType.DEFLECTION] = {
		"amount": 80,
		"lifetime": 0.6,
		"emission_shape": "point",
		"direction": Vector3(0, 0, 1),
		"spread": 45.0,
		"initial_velocity_min": 4.0,
		"initial_velocity_max": 8.0,
		"gravity": Vector3(0, -1, 0),
		"scale_min": 0.02,
		"scale_max": 0.04,
		"color": Color(1.0, 0.8, 0.2, 1.0),
		"color_end": Color(1.0, 0.4, 0.0, 0.0),
		"duration": 0.8
	}

	# Force push
	effect_configs[EffectType.FORCE_PUSH] = {
		"amount": 200,
		"lifetime": 1.0,
		"emission_shape": "ring",
		"emission_radius": 0.3,
		"direction": Vector3(0, 0, -1),
		"spread": 20.0,
		"initial_velocity_min": 5.0,
		"initial_velocity_max": 10.0,
		"gravity": Vector3.ZERO,
		"scale_min": 0.03,
		"scale_max": 0.08,
		"color": Color(0.5, 0.7, 1.0, 0.6),
		"color_end": Color(0.2, 0.4, 0.8, 0.0),
		"duration": 1.2
	}

	# Force pull
	effect_configs[EffectType.FORCE_PULL] = {
		"amount": 200,
		"lifetime": 1.0,
		"emission_shape": "sphere",
		"emission_radius": 2.0,
		"direction": Vector3(0, 0, 0),
		"spread": 0.0,
		"initial_velocity_min": -8.0,
		"initial_velocity_max": -4.0,
		"gravity": Vector3.ZERO,
		"scale_min": 0.03,
		"scale_max": 0.08,
		"color": Color(0.8, 0.5, 1.0, 0.6),
		"color_end": Color(0.4, 0.2, 0.8, 0.0),
		"duration": 1.2
	}

	# Achievement
	effect_configs[EffectType.ACHIEVEMENT] = {
		"amount": 100,
		"lifetime": 2.0,
		"emission_shape": "sphere",
		"emission_radius": 0.5,
		"direction": Vector3(0, 1, 0),
		"spread": 60.0,
		"initial_velocity_min": 1.0,
		"initial_velocity_max": 3.0,
		"gravity": Vector3(0, 0.5, 0),
		"scale_min": 0.03,
		"scale_max": 0.08,
		"color": Color(1.0, 0.85, 0.0, 1.0),
		"color_end": Color(1.0, 0.6, 0.0, 0.0),
		"duration": 2.5
	}

	# Combo burst
	effect_configs[EffectType.COMBO_BURST] = {
		"amount": 60,
		"lifetime": 0.8,
		"emission_shape": "ring",
		"emission_radius": 0.15,
		"direction": Vector3(0, 1, 0),
		"spread": 45.0,
		"initial_velocity_min": 2.0,
		"initial_velocity_max": 4.0,
		"gravity": Vector3.ZERO,
		"scale_min": 0.02,
		"scale_max": 0.05,
		"color": Color(1.0, 0.5, 0.0, 1.0),
		"color_end": Color(1.0, 0.2, 0.0, 0.0),
		"duration": 1.0
	}

	# Zone discover
	effect_configs[EffectType.ZONE_DISCOVER] = {
		"amount": 40,
		"lifetime": 1.5,
		"emission_shape": "box",
		"emission_box": Vector3(0.1, 0.1, 0.1),
		"direction": Vector3(0, 0, 0),
		"spread": 180.0,
		"initial_velocity_min": 0.5,
		"initial_velocity_max": 1.5,
		"gravity": Vector3.ZERO,
		"scale_min": 0.02,
		"scale_max": 0.05,
		"color": Color(0.2, 1.0, 0.8, 0.8),
		"color_end": Color(0.1, 0.5, 0.4, 0.0),
		"duration": 2.0
	}

	# Sparks
	effect_configs[EffectType.SPARKS] = {
		"amount": 30,
		"lifetime": 0.5,
		"emission_shape": "point",
		"direction": Vector3(0, 1, 0),
		"spread": 60.0,
		"initial_velocity_min": 3.0,
		"initial_velocity_max": 6.0,
		"gravity": Vector3(0, -10, 0),
		"scale_min": 0.005,
		"scale_max": 0.015,
		"color": Color(1.0, 0.9, 0.6, 1.0),
		"color_end": Color(1.0, 0.5, 0.0, 0.0),
		"duration": 0.6
	}

	# Energy burst
	effect_configs[EffectType.ENERGY_BURST] = {
		"amount": 120,
		"lifetime": 0.8,
		"emission_shape": "sphere",
		"emission_radius": 0.05,
		"direction": Vector3(0, 0, 0),
		"spread": 180.0,
		"initial_velocity_min": 3.0,
		"initial_velocity_max": 7.0,
		"gravity": Vector3.ZERO,
		"scale_min": 0.02,
		"scale_max": 0.06,
		"color": Color(0.6, 0.8, 1.0, 1.0),
		"color_end": Color(0.2, 0.4, 1.0, 0.0),
		"duration": 1.0
	}


func _initialize_pools() -> void:
	for effect_type in EffectType.values():
		effect_pools[effect_type] = []
		for i in range(INITIAL_POOL_SIZE):
			var effect := _create_effect(effect_type)
			effect_pools[effect_type].append(effect)


func _create_effect(effect_type: EffectType) -> PooledEffect:
	var pooled := PooledEffect.new()
	pooled.effect_type = effect_type
	pooled.is_active = false

	var particles := GPUParticles3D.new()
	particles.emitting = false
	particles.one_shot = true

	var config: Dictionary = effect_configs.get(effect_type, {})

	# Create process material
	var material := ParticleProcessMaterial.new()

	# Emission shape
	match config.get("emission_shape", "point"):
		"sphere":
			material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
			material.emission_sphere_radius = config.get("emission_radius", 0.1)
		"box":
			material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
			material.emission_box_extents = config.get("emission_box", Vector3(0.1, 0.1, 0.1))
		"ring":
			material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
			material.emission_ring_radius = config.get("emission_radius", 0.2)
			material.emission_ring_inner_radius = config.get("emission_radius", 0.2) * 0.8
		_:
			material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_POINT

	# Direction and spread
	material.direction = config.get("direction", Vector3(0, 1, 0))
	material.spread = config.get("spread", 45.0)

	# Velocity
	material.initial_velocity_min = config.get("initial_velocity_min", 1.0)
	material.initial_velocity_max = config.get("initial_velocity_max", 3.0)

	# Gravity
	material.gravity = config.get("gravity", Vector3(0, -9.8, 0))

	# Scale
	material.scale_min = config.get("scale_min", 0.01)
	material.scale_max = config.get("scale_max", 0.05)

	# Color
	var color_ramp := Gradient.new()
	color_ramp.set_color(0, config.get("color", Color.WHITE))
	color_ramp.set_color(1, config.get("color_end", Color(1, 1, 1, 0)))
	var color_texture := GradientTexture1D.new()
	color_texture.gradient = color_ramp
	material.color_ramp = color_texture

	particles.process_material = material
	particles.amount = config.get("amount", 50)
	particles.lifetime = config.get("lifetime", 1.0)

	# Create simple quad mesh for particles
	var quad := QuadMesh.new()
	quad.size = Vector2(1, 1)

	var draw_mat := StandardMaterial3D.new()
	draw_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	draw_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	draw_mat.vertex_color_use_as_albedo = true
	draw_mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	quad.material = draw_mat

	particles.draw_pass_1 = quad

	pooled.particles = particles
	add_child(particles)

	return pooled


func _get_from_pool(effect_type: EffectType) -> PooledEffect:
	var pool: Array = effect_pools.get(effect_type, [])

	# Find inactive effect
	for effect in pool:
		if not effect.is_active:
			return effect

	# Pool exhausted, create new if under limit
	if pool.size() < MAX_POOL_SIZE:
		var new_effect := _create_effect(effect_type)
		pool.append(new_effect)
		return new_effect

	# Over limit, return null
	return null


func _return_to_pool(effect: PooledEffect) -> void:
	effect.is_active = false
	effect.particles.emitting = false
	effect.return_time = 0.0
	active_effects.erase(effect)


func spawn_effect(effect_type: EffectType, position: Vector3, direction: Vector3 = Vector3.UP) -> void:
	var effect := _get_from_pool(effect_type)
	if effect == null:
		return

	effect.is_active = true
	effect.particles.global_position = position

	# Orient particles toward direction
	if direction != Vector3.ZERO:
		effect.particles.look_at(position + direction, Vector3.UP)

	# Set return time based on config
	var config: Dictionary = effect_configs.get(effect_type, {})
	var duration: float = config.get("duration", 1.0)
	if duration > 0:
		effect.return_time = Time.get_ticks_msec() / 1000.0 + duration

	effect.particles.emitting = true
	active_effects.append(effect)


func _on_vfx_requested(effect_name: String, position: Vector3, direction: Vector3) -> void:
	var effect_type := _name_to_type(effect_name)
	spawn_effect(effect_type, position, direction)


func _name_to_type(name: String) -> EffectType:
	match name.to_lower():
		"blade_trail": return EffectType.BLADE_TRAIL
		"blade_clash": return EffectType.BLADE_CLASH
		"blade_hit": return EffectType.BLADE_HIT
		"target_destroy": return EffectType.TARGET_DESTROY
		"target_spawn": return EffectType.TARGET_SPAWN
		"deflection": return EffectType.DEFLECTION
		"force_push": return EffectType.FORCE_PUSH
		"force_pull": return EffectType.FORCE_PULL
		"achievement": return EffectType.ACHIEVEMENT
		"combo_burst": return EffectType.COMBO_BURST
		"zone_discover": return EffectType.ZONE_DISCOVER
		"sparks": return EffectType.SPARKS
		"energy_burst", _: return EffectType.ENERGY_BURST


## Convenience methods
func spawn_blade_clash(position: Vector3) -> void:
	spawn_effect(EffectType.BLADE_CLASH, position)


func spawn_target_destroy(position: Vector3) -> void:
	spawn_effect(EffectType.TARGET_DESTROY, position)


func spawn_deflection(position: Vector3, direction: Vector3) -> void:
	spawn_effect(EffectType.DEFLECTION, position, direction)


func spawn_force_push(position: Vector3, direction: Vector3) -> void:
	spawn_effect(EffectType.FORCE_PUSH, position, direction)


func spawn_force_pull(position: Vector3) -> void:
	spawn_effect(EffectType.FORCE_PULL, position)


func spawn_achievement(position: Vector3) -> void:
	spawn_effect(EffectType.ACHIEVEMENT, position)


func spawn_combo_burst(position: Vector3) -> void:
	spawn_effect(EffectType.COMBO_BURST, position)

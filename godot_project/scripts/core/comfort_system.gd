## ComfortSystem - VR comfort features and motion sickness prevention
## Implements industry best practices for comfortable VR experiences
class_name ComfortSystem
extends Node3D

signal comfort_level_changed(level: ComfortLevel)
signal vignette_intensity_changed(intensity: float)
signal snap_turn_performed(direction: int)
signal world_stabilization_toggled(enabled: bool)

## Comfort presets
enum ComfortLevel {
	MINIMAL,        # Maximum freedom, minimal assists
	STANDARD,       # Balanced comfort features
	COMFORTABLE,    # Enhanced comfort, some restrictions
	MAXIMUM         # Maximum comfort, all features enabled
}

## Movement types that can cause discomfort
enum MovementType {
	SMOOTH_ROTATION,
	SNAP_ROTATION,
	SMOOTH_LOCOMOTION,
	TELEPORT,
	ARTIFICIAL_ACCELERATION,
	CAMERA_SHAKE
}

## Configuration
@export var comfort_level: ComfortLevel = ComfortLevel.STANDARD

## Vignette settings
@export var vignette_enabled: bool = true
@export var vignette_base_intensity: float = 0.0
@export var vignette_max_intensity: float = 0.5
@export var vignette_ramp_speed: float = 5.0
@export var vignette_color: Color = Color(0, 0, 0, 1)

## Snap turn settings
@export var snap_turn_enabled: bool = true
@export var snap_turn_angle: float = 45.0  # degrees
@export var snap_turn_cooldown: float = 0.2  # seconds

## Smooth turn settings (when snap is disabled)
@export var smooth_turn_speed: float = 90.0  # degrees per second

## World stabilization (horizon lock)
@export var horizon_stabilization: bool = false
@export var stabilization_strength: float = 0.5

## Acceleration comfort
@export var smooth_acceleration: bool = true
@export var max_acceleration: float = 2.0  # m/s^2

## Visual comfort
@export var reduced_motion: bool = false
@export var limit_peripheral_movement: bool = false
@export var camera_shake_reduction: float = 0.0  # 0-1

## State
var current_vignette_intensity: float = 0.0
var target_vignette_intensity: float = 0.0
var snap_turn_timer: float = 0.0
var is_snap_turning: bool = false

## Movement tracking for vignette
var angular_velocity: float = 0.0
var linear_velocity: float = 0.0
var prev_rotation: Quaternion = Quaternion.IDENTITY
var prev_position: Vector3 = Vector3.ZERO

## References
var xr_origin: XROrigin3D
var xr_camera: XRCamera3D
var vignette_overlay: MeshInstance3D
var vignette_material: ShaderMaterial


func _ready() -> void:
	_create_vignette_overlay()
	_apply_comfort_level(comfort_level)


func setup_xr_nodes(origin: XROrigin3D, camera: XRCamera3D) -> void:
	xr_origin = origin
	xr_camera = camera

	if camera:
		prev_rotation = camera.global_transform.basis.get_rotation_quaternion()
		prev_position = camera.global_position


func _process(delta: float) -> void:
	_update_movement_tracking(delta)
	_update_vignette(delta)
	_update_snap_turn_cooldown(delta)
	_update_vignette_position()


func _update_movement_tracking(delta: float) -> void:
	if xr_camera == null or delta <= 0:
		return

	# Track angular velocity (rotation speed)
	var current_rot := xr_camera.global_transform.basis.get_rotation_quaternion()
	var rot_diff := prev_rotation.inverse() * current_rot
	var angle := 2.0 * acos(clampf(rot_diff.w, -1.0, 1.0))
	angular_velocity = rad_to_deg(angle) / delta
	prev_rotation = current_rot

	# Track linear velocity
	var current_pos := xr_camera.global_position
	linear_velocity = current_pos.distance_to(prev_position) / delta
	prev_position = current_pos

	# Calculate target vignette based on movement
	if vignette_enabled:
		_calculate_vignette_target()


func _calculate_vignette_target() -> void:
	target_vignette_intensity = vignette_base_intensity

	# Increase vignette based on angular velocity
	if angular_velocity > 30.0:  # degrees per second threshold
		var angular_factor := clampf((angular_velocity - 30.0) / 120.0, 0.0, 1.0)
		target_vignette_intensity += angular_factor * vignette_max_intensity * 0.5

	# Increase vignette based on linear velocity (if not from natural walking)
	if linear_velocity > 2.0:  # m/s threshold (artificial locomotion)
		var linear_factor := clampf((linear_velocity - 2.0) / 5.0, 0.0, 1.0)
		target_vignette_intensity += linear_factor * vignette_max_intensity * 0.5

	target_vignette_intensity = clampf(target_vignette_intensity, 0.0, vignette_max_intensity)


func _update_vignette(delta: float) -> void:
	if not vignette_enabled:
		current_vignette_intensity = 0.0
		_set_vignette_intensity(0.0)
		return

	# Smooth interpolation to target
	current_vignette_intensity = lerpf(current_vignette_intensity, target_vignette_intensity, delta * vignette_ramp_speed)

	_set_vignette_intensity(current_vignette_intensity)


func _update_vignette_position() -> void:
	if vignette_overlay and xr_camera:
		# Keep vignette centered on camera
		vignette_overlay.global_position = xr_camera.global_position
		vignette_overlay.global_rotation = xr_camera.global_rotation


func _update_snap_turn_cooldown(delta: float) -> void:
	if snap_turn_timer > 0:
		snap_turn_timer -= delta


func _create_vignette_overlay() -> void:
	vignette_overlay = MeshInstance3D.new()
	vignette_overlay.name = "ComfortVignette"

	# Create inverted sphere for vignette
	var sphere := SphereMesh.new()
	sphere.radius = 0.4
	sphere.height = 0.8
	sphere.radial_segments = 32
	sphere.rings = 16

	# Create vignette shader
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode unshaded, cull_front, depth_test_disabled, depth_draw_never;

uniform float vignette_intensity : hint_range(0.0, 1.0) = 0.0;
uniform float vignette_softness : hint_range(0.1, 1.0) = 0.4;
uniform vec4 vignette_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);

void vertex() {
	// Disable view transform to keep sphere around camera
	VERTEX = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	// Calculate vignette based on view angle from center
	vec2 centered_uv = UV * 2.0 - 1.0;
	float distance_from_center = length(centered_uv);

	// Circular vignette
	float vignette = smoothstep(1.0 - vignette_softness, 1.0, distance_from_center);
	vignette *= vignette_intensity;

	ALBEDO = vignette_color.rgb;
	ALPHA = vignette * vignette_color.a;
}
"""

	vignette_material = ShaderMaterial.new()
	vignette_material.shader = shader
	vignette_material.set_shader_parameter("vignette_intensity", 0.0)
	vignette_material.set_shader_parameter("vignette_softness", 0.4)
	vignette_material.set_shader_parameter("vignette_color", vignette_color)

	sphere.material = vignette_material
	vignette_overlay.mesh = sphere
	vignette_overlay.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	add_child(vignette_overlay)


func _set_vignette_intensity(intensity: float) -> void:
	if vignette_material:
		vignette_material.set_shader_parameter("vignette_intensity", intensity)

	if intensity != current_vignette_intensity:
		vignette_intensity_changed.emit(intensity)


## Perform snap turn
func snap_turn(direction: int) -> void:
	if not snap_turn_enabled:
		return

	if snap_turn_timer > 0:
		return  # Still in cooldown

	if xr_origin == null:
		return

	var angle_rad := deg_to_rad(snap_turn_angle * direction)
	xr_origin.rotate_y(angle_rad)

	snap_turn_timer = snap_turn_cooldown
	is_snap_turning = true

	# Brief vignette flash for snap turn
	if vignette_enabled:
		target_vignette_intensity = vignette_max_intensity * 0.7
		current_vignette_intensity = target_vignette_intensity

	snap_turn_performed.emit(direction)

	# Reset snap turn state after a frame
	await get_tree().process_frame
	is_snap_turning = false


## Perform smooth turn
func smooth_turn(direction: float, delta: float) -> void:
	if snap_turn_enabled:
		return  # Use snap turn instead

	if xr_origin == null:
		return

	var angle := direction * smooth_turn_speed * delta
	xr_origin.rotate_y(deg_to_rad(angle))


## Apply smooth acceleration to a velocity vector
func apply_smooth_acceleration(current_velocity: Vector3, target_velocity: Vector3, delta: float) -> Vector3:
	if not smooth_acceleration:
		return target_velocity

	var diff := target_velocity - current_velocity
	var accel := diff.normalized() * minf(diff.length() / delta, max_acceleration)

	return current_velocity + accel * delta


## Reduce camera shake effect
func apply_camera_shake_reduction(shake_amount: Vector3) -> Vector3:
	return shake_amount * (1.0 - camera_shake_reduction)


## Check if movement type is allowed by current comfort settings
func is_movement_allowed(movement: MovementType) -> bool:
	match movement:
		MovementType.SMOOTH_ROTATION:
			return not snap_turn_enabled
		MovementType.SNAP_ROTATION:
			return snap_turn_enabled
		MovementType.CAMERA_SHAKE:
			return camera_shake_reduction < 1.0
		_:
			return true


## Set comfort level preset
func set_comfort_level(level: ComfortLevel) -> void:
	comfort_level = level
	_apply_comfort_level(level)
	comfort_level_changed.emit(level)


func _apply_comfort_level(level: ComfortLevel) -> void:
	match level:
		ComfortLevel.MINIMAL:
			vignette_enabled = false
			snap_turn_enabled = false
			horizon_stabilization = false
			reduced_motion = false
			camera_shake_reduction = 0.0
			vignette_max_intensity = 0.3

		ComfortLevel.STANDARD:
			vignette_enabled = true
			snap_turn_enabled = true
			snap_turn_angle = 45.0
			horizon_stabilization = false
			reduced_motion = false
			camera_shake_reduction = 0.3
			vignette_max_intensity = 0.5

		ComfortLevel.COMFORTABLE:
			vignette_enabled = true
			snap_turn_enabled = true
			snap_turn_angle = 30.0
			horizon_stabilization = true
			stabilization_strength = 0.3
			reduced_motion = true
			camera_shake_reduction = 0.7
			vignette_max_intensity = 0.6

		ComfortLevel.MAXIMUM:
			vignette_enabled = true
			snap_turn_enabled = true
			snap_turn_angle = 30.0
			horizon_stabilization = true
			stabilization_strength = 0.7
			reduced_motion = true
			camera_shake_reduction = 1.0
			vignette_max_intensity = 0.7
			limit_peripheral_movement = true


## Trigger immediate vignette (for teleportation, etc.)
func trigger_vignette(intensity: float, duration: float = 0.3) -> void:
	if not vignette_enabled:
		return

	current_vignette_intensity = intensity
	target_vignette_intensity = intensity
	_set_vignette_intensity(intensity)

	# Fade out after duration
	await get_tree().create_timer(duration).timeout
	target_vignette_intensity = vignette_base_intensity


## Toggle world stabilization (horizon lock)
func set_world_stabilization(enabled: bool) -> void:
	horizon_stabilization = enabled
	world_stabilization_toggled.emit(enabled)


## Get comfort settings summary
func get_settings() -> Dictionary:
	return {
		"comfort_level": comfort_level,
		"vignette_enabled": vignette_enabled,
		"vignette_intensity": current_vignette_intensity,
		"snap_turn_enabled": snap_turn_enabled,
		"snap_turn_angle": snap_turn_angle,
		"horizon_stabilization": horizon_stabilization,
		"reduced_motion": reduced_motion,
		"camera_shake_reduction": camera_shake_reduction
	}


## Get comfort level name
func get_comfort_level_name() -> String:
	match comfort_level:
		ComfortLevel.MINIMAL: return "Minimal"
		ComfortLevel.STANDARD: return "Standard"
		ComfortLevel.COMFORTABLE: return "Comfortable"
		ComfortLevel.MAXIMUM: return "Maximum"
	return "Unknown"

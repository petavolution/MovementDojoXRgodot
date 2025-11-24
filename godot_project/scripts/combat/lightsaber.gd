## Lightsaber - VR lightsaber with physics-based combat
## Attach to XRController3D
extends Node3D
class_name Lightsaber

signal activated()
signal deactivated()
signal blade_hit(target: Node3D, damage: float, position: Vector3, velocity: Vector3)
signal blade_clash(other_saber: Lightsaber, position: Vector3)

@export_group("Blade Properties")
@export var blade_length := 1.0
@export var blade_width := 0.025
@export var blade_color := Color(0.2, 0.5, 1.0)  # Blue default
@export var core_color := Color(1.0, 1.0, 1.0)

@export_group("Combat Settings")
@export var damage_multiplier := 1.0
@export var min_damage_velocity := 1.0  # m/s minimum for damage
@export var max_damage_velocity := 8.0  # m/s for max damage
@export var base_damage := 10.0
@export var max_damage := 100.0

@export_group("Audio")
@export var hum_volume_db := -10.0
@export var swing_threshold := 2.0  # m/s for swing sound

@export_group("Haptics")
@export var haptic_intensity := 0.5
@export var haptic_duration := 0.1

# Node references
var hilt_mesh: MeshInstance3D
var blade_mesh: MeshInstance3D
var blade_collider: Area3D
var blade_light: OmniLight3D
var hum_audio: AudioStreamPlayer3D
var swing_audio: AudioStreamPlayer3D
var clash_audio: AudioStreamPlayer3D

# State
var is_active := false
var is_activating := false
var blade_extend_progress := 0.0
var controller: XRController3D

# Velocity tracking
var previous_tip_position := Vector3.ZERO
var current_tip_velocity := Vector3.ZERO
var velocity_history: Array[float] = []
const VELOCITY_HISTORY_SIZE := 10

# Input tracking
var trigger_pressed := false
const TRIGGER_THRESHOLD := 0.7  # Trigger press threshold (0.0-1.0)

# Materials
var blade_material: ShaderMaterial
var hilt_material: StandardMaterial3D


func _ready() -> void:
	_setup_hilt()
	_setup_blade()
	_setup_collider()
	_setup_light()
	_setup_audio()

	# Find controller parent and connect input signals
	var parent := get_parent()
	if parent is XRController3D:
		controller = parent
		controller.button_pressed.connect(_on_button_pressed)
		controller.input_float_changed.connect(_on_input_float_changed)
		DebugLogger.debug("Lightsaber", "Controller connected: %s" % parent.name)
	else:
		DebugLogger.warn("Lightsaber", "Parent is not XRController3D - activation via input disabled")


func _physics_process(delta: float) -> void:
	if not is_active and not is_activating:
		return

	# Update blade extension animation
	if is_activating:
		blade_extend_progress += delta * 4.0  # 0.25s to fully extend
		if blade_extend_progress >= 1.0:
			blade_extend_progress = 1.0
			is_activating = false
		_update_blade_extension()

	# Calculate blade tip velocity
	var tip_position := _get_blade_tip_position()
	if previous_tip_position != Vector3.ZERO:
		current_tip_velocity = (tip_position - previous_tip_position) / delta
	previous_tip_position = tip_position

	# Track velocity history
	velocity_history.append(current_tip_velocity.length())
	if velocity_history.size() > VELOCITY_HISTORY_SIZE:
		velocity_history.remove_at(0)

	# Update audio based on movement
	_update_swing_audio()


func activate() -> void:
	if is_active or is_activating:
		return

	is_activating = true
	is_active = true
	blade_extend_progress = 0.0

	blade_mesh.visible = true
	blade_collider.monitoring = true
	blade_light.visible = true

	# Start hum audio
	if hum_audio and not hum_audio.playing:
		hum_audio.play()

	activated.emit()

	var hand := "right" if controller and controller.tracker == "right_hand" else "left"
	GameEvents.saber_activated.emit(hand)


func deactivate() -> void:
	if not is_active:
		return

	is_active = false
	is_activating = false
	blade_extend_progress = 0.0

	blade_mesh.visible = false
	blade_collider.monitoring = false
	blade_light.visible = false

	# Stop hum audio
	if hum_audio:
		hum_audio.stop()

	deactivated.emit()

	var hand := "right" if controller and controller.tracker == "right_hand" else "left"
	GameEvents.saber_deactivated.emit(hand)


func toggle() -> void:
	if is_active:
		deactivate()
	else:
		activate()


func set_blade_color(color: Color) -> void:
	blade_color = color
	if blade_material:
		blade_material.set_shader_parameter("blade_color", Vector3(color.r, color.g, color.b))
	if blade_light:
		blade_light.light_color = color


func _setup_hilt() -> void:
	hilt_mesh = MeshInstance3D.new()
	hilt_mesh.name = "HiltMesh"

	var hilt := CylinderMesh.new()
	hilt.top_radius = 0.018
	hilt.bottom_radius = 0.022
	hilt.height = 0.25

	hilt_material = StandardMaterial3D.new()
	hilt_material.albedo_color = Color(0.15, 0.15, 0.15)
	hilt_material.metallic = 0.9
	hilt_material.roughness = 0.3

	hilt.material = hilt_material
	hilt_mesh.mesh = hilt
	hilt_mesh.rotation_degrees.x = 90  # Point forward
	add_child(hilt_mesh)


func _setup_blade() -> void:
	blade_mesh = MeshInstance3D.new()
	blade_mesh.name = "BladeMesh"

	var blade := CylinderMesh.new()
	blade.top_radius = blade_width * 0.8
	blade.bottom_radius = blade_width
	blade.height = blade_length

	blade_mesh.mesh = blade
	blade_mesh.position = Vector3(0, 0, -blade_length / 2 - 0.12)  # Position in front of hilt
	blade_mesh.rotation_degrees.x = 90
	blade_mesh.visible = false

	# Apply blade shader
	blade_material = _create_blade_shader_material()
	blade_mesh.material_override = blade_material

	add_child(blade_mesh)


func _setup_collider() -> void:
	blade_collider = Area3D.new()
	blade_collider.name = "BladeCollider"
	blade_collider.monitoring = false
	blade_collider.monitorable = true
	blade_collider.collision_layer = 2  # Blade layer
	blade_collider.collision_mask = 4 | 8  # Enemies + other blades

	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = blade_width * 1.5
	capsule.height = blade_length
	shape.shape = capsule
	shape.rotation_degrees.x = 90
	shape.position = Vector3(0, 0, -blade_length / 2 - 0.12)

	blade_collider.add_child(shape)
	add_child(blade_collider)

	blade_collider.body_entered.connect(_on_blade_body_entered)
	blade_collider.area_entered.connect(_on_blade_area_entered)


func _setup_light() -> void:
	blade_light = OmniLight3D.new()
	blade_light.name = "BladeLight"
	blade_light.light_color = blade_color
	blade_light.light_energy = 2.0
	blade_light.omni_range = 2.0
	blade_light.omni_attenuation = 1.5
	blade_light.shadow_enabled = false
	blade_light.position = Vector3(0, 0, -blade_length / 2)
	blade_light.visible = false
	add_child(blade_light)


func _setup_audio() -> void:
	# Hum audio (looping)
	hum_audio = AudioStreamPlayer3D.new()
	hum_audio.name = "HumAudio"
	hum_audio.volume_db = hum_volume_db
	hum_audio.max_db = 0
	hum_audio.unit_size = 2.0
	# Audio stream would be loaded from resource
	add_child(hum_audio)

	# Swing audio (one-shot)
	swing_audio = AudioStreamPlayer3D.new()
	swing_audio.name = "SwingAudio"
	swing_audio.volume_db = -5.0
	add_child(swing_audio)

	# Clash audio (one-shot)
	clash_audio = AudioStreamPlayer3D.new()
	clash_audio.name = "ClashAudio"
	clash_audio.volume_db = 0.0
	add_child(clash_audio)


func _create_blade_shader_material() -> ShaderMaterial:
	var material := ShaderMaterial.new()

	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_always;

uniform vec3 blade_color : source_color = vec3(0.2, 0.5, 1.0);
uniform vec3 core_color : source_color = vec3(1.0, 1.0, 1.0);
uniform float core_intensity : hint_range(0, 10) = 3.0;
uniform float glow_intensity : hint_range(0, 5) = 1.5;
uniform float extension : hint_range(0, 1) = 1.0;

varying vec3 local_pos;

void vertex() {
	local_pos = VERTEX;
	// Scale blade based on extension
	VERTEX.y *= extension;
}

void fragment() {
	// Calculate core brightness based on distance from center
	float dist_from_center = length(local_pos.xz) / 0.025;  // Normalized to blade width
	float core = 1.0 - smoothstep(0.0, 0.6, dist_from_center);
	float outer = 1.0 - smoothstep(0.3, 1.0, dist_from_center);

	// Mix core and blade colors
	vec3 final_color = mix(blade_color, core_color, core * core_intensity * 0.3);
	final_color *= (1.0 + core * core_intensity);

	ALBEDO = final_color;
	EMISSION = final_color * glow_intensity;
	ALPHA = outer * extension;
}
"""
	material.shader = shader
	material.set_shader_parameter("blade_color", Vector3(blade_color.r, blade_color.g, blade_color.b))
	material.set_shader_parameter("core_color", Vector3(core_color.r, core_color.g, core_color.b))
	material.set_shader_parameter("extension", 0.0)

	return material


func _update_blade_extension() -> void:
	if blade_material:
		blade_material.set_shader_parameter("extension", blade_extend_progress)

	# Update light intensity
	if blade_light:
		blade_light.light_energy = blade_extend_progress * 2.0


func _get_blade_tip_position() -> Vector3:
	return global_position + global_transform.basis * Vector3(0, 0, -blade_length - 0.12)


func _update_swing_audio() -> void:
	var avg_velocity := 0.0
	for v in velocity_history:
		avg_velocity += v
	if velocity_history.size() > 0:
		avg_velocity /= velocity_history.size()

	# Modulate hum pitch based on movement
	if hum_audio:
		hum_audio.pitch_scale = 1.0 + (avg_velocity / 10.0) * 0.3

	# Trigger swing sound at high velocities
	if avg_velocity > swing_threshold and swing_audio and not swing_audio.playing:
		swing_audio.pitch_scale = 0.9 + randf() * 0.2
		# swing_audio.play()  # Would play swing sound


func _calculate_damage(velocity: float) -> float:
	if velocity < min_damage_velocity:
		return 0.0

	var velocity_factor := clamp(
		(velocity - min_damage_velocity) / (max_damage_velocity - min_damage_velocity),
		0.0,
		1.0
	)

	return lerp(base_damage, max_damage, velocity_factor) * damage_multiplier


func _trigger_haptic(intensity: float = -1.0) -> void:
	if controller == null:
		return

	var final_intensity := intensity if intensity >= 0 else haptic_intensity
	controller.trigger_haptic_pulse("haptic", 50.0, final_intensity, haptic_duration, 0.0)


func _on_button_pressed(button: String) -> void:
	# Toggle saber with A/X button
	if button == "ax_button":
		toggle()


func _on_input_float_changed(name: String, value: float) -> void:
	# Handle trigger as analog input (detect press/release)
	if name == "trigger":
		var was_pressed := trigger_pressed
		trigger_pressed = value > TRIGGER_THRESHOLD

		# Toggle on press (not release)
		if trigger_pressed and not was_pressed:
			toggle()


func _on_blade_body_entered(body: Node3D) -> void:
	if not is_active:
		return

	var velocity := current_tip_velocity.length()
	var damage := _calculate_damage(velocity)

	if damage > 0:
		var contact_point := _get_blade_tip_position()  # Simplified

		blade_hit.emit(body, damage, contact_point, current_tip_velocity)
		GameEvents.target_hit.emit(body, damage, contact_point)

		_trigger_haptic(clamp(damage / max_damage, 0.3, 1.0))

		# Play clash sound
		if clash_audio:
			clash_audio.pitch_scale = 0.8 + randf() * 0.4
			# clash_audio.play()


func _on_blade_area_entered(area: Area3D) -> void:
	if not is_active:
		return

	# Check for other lightsaber blades
	var parent := area.get_parent()
	if parent is Lightsaber and parent != self:
		var contact_point := _get_blade_tip_position()
		blade_clash.emit(parent, contact_point)
		GameEvents.saber_clash.emit(contact_point, current_tip_velocity.length())

		_trigger_haptic(1.0)

		if clash_audio:
			clash_audio.pitch_scale = 0.9 + randf() * 0.2
			# clash_audio.play()

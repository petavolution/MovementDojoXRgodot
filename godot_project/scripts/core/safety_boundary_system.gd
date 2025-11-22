## SafetyBoundarySystem - Guardian/Chaperone integration and safety features
## Prevents collisions with real-world obstacles and warns about play area limits
class_name SafetyBoundarySystem
extends Node3D

signal boundary_approaching(distance: float, direction: Vector3)
signal boundary_breached(position: Vector3)
signal boundary_safe
signal collision_warning(object_type: String, position: Vector3)
signal safety_mode_changed(mode: SafetyMode)

## Safety modes
enum SafetyMode {
	DISABLED,           # No boundary warnings (not recommended)
	VISUAL_ONLY,        # Visual indicators only
	VISUAL_HAPTIC,      # Visual + haptic feedback
	FULL                # Visual + haptic + audio + game pause
}

## Warning levels
enum WarningLevel {
	SAFE,               # Within safe zone
	CAUTION,            # Approaching boundary (yellow zone)
	WARNING,            # Very close to boundary (orange zone)
	DANGER              # At or beyond boundary (red zone)
}

## Configuration
@export var safety_mode: SafetyMode = SafetyMode.VISUAL_HAPTIC
@export var warning_distance_caution: float = 0.5  # meters
@export var warning_distance_warning: float = 0.3  # meters
@export var warning_distance_danger: float = 0.1   # meters
@export var check_interval: float = 0.05           # 20Hz checking
@export var enable_floor_warning: bool = true
@export var floor_warning_height: float = 0.3      # meters

## Visual settings
@export var boundary_color_safe: Color = Color(0.0, 0.5, 1.0, 0.0)
@export var boundary_color_caution: Color = Color(1.0, 1.0, 0.0, 0.3)
@export var boundary_color_warning: Color = Color(1.0, 0.5, 0.0, 0.5)
@export var boundary_color_danger: Color = Color(1.0, 0.0, 0.0, 0.8)

## State
var current_warning_level: WarningLevel = WarningLevel.SAFE
var is_active: bool = false
var check_timer: float = 0.0

## Boundary data
var boundary_points: PackedVector3Array = []
var boundary_center: Vector3 = Vector3.ZERO
var play_area_size: Vector2 = Vector2.ZERO

## References (set via setup_xr_nodes)
var xr_origin: XROrigin3D
var xr_camera: XRCamera3D
var left_controller: XRController3D
var right_controller: XRController3D

## Visual components
var boundary_mesh: MeshInstance3D
var floor_grid: MeshInstance3D
var warning_overlay: MeshInstance3D
var boundary_material: ShaderMaterial

## Tracked positions for velocity-based prediction
var head_velocity: Vector3 = Vector3.ZERO
var prev_head_pos: Vector3 = Vector3.ZERO


func _ready() -> void:
	_create_boundary_visuals()
	_create_floor_grid()
	_create_warning_overlay()


## Setup with XR origin to get boundary data directly from OpenXR
func setup(origin: XROrigin3D, camera: XRCamera3D, left: XRController3D, right: XRController3D) -> void:
	xr_origin = origin
	xr_camera = camera
	left_controller = left
	right_controller = right
	prev_head_pos = camera.global_position if camera else Vector3.ZERO

	# Get boundary data from XR interface
	_refresh_boundary_data()


## Legacy compatibility - use setup() instead
func setup_xr_nodes(camera: XRCamera3D, left: XRController3D, right: XRController3D) -> void:
	xr_camera = camera
	left_controller = left
	right_controller = right
	prev_head_pos = camera.global_position if camera else Vector3.ZERO


## Refresh boundary data from OpenXR runtime
func _refresh_boundary_data() -> void:
	var xr_interface := XRServer.primary_interface
	if xr_interface == null:
		return

	# OpenXR provides play area bounds via get_play_area()
	if xr_interface.has_method("get_play_area"):
		var play_area: PackedVector3Array = xr_interface.get_play_area()
		if play_area.size() > 0:
			boundary_points = play_area
			_calculate_center_and_size()
			_update_boundary_mesh()


func _calculate_center_and_size() -> void:
	if boundary_points.is_empty():
		return

	var min_pos := boundary_points[0]
	var max_pos := boundary_points[0]

	for point in boundary_points:
		min_pos.x = min(min_pos.x, point.x)
		min_pos.z = min(min_pos.z, point.z)
		max_pos.x = max(max_pos.x, point.x)
		max_pos.z = max(max_pos.z, point.z)

	boundary_center = (min_pos + max_pos) / 2.0
	play_area_size = Vector2(max_pos.x - min_pos.x, max_pos.z - min_pos.z)


func activate() -> void:
	is_active = true
	set_process(true)


func deactivate() -> void:
	is_active = false
	set_process(false)
	_set_warning_level(WarningLevel.SAFE)


func _process(delta: float) -> void:
	if not is_active or safety_mode == SafetyMode.DISABLED:
		return

	check_timer += delta
	if check_timer < check_interval:
		return
	check_timer = 0.0

	_check_boundaries()
	_update_head_velocity(delta)


func _check_boundaries() -> void:
	if boundary_points.size() < 3:
		return

	var min_distance := INF
	var closest_direction := Vector3.ZERO

	# Check head position
	if xr_camera:
		var head_pos := xr_camera.global_position
		var result := _get_boundary_distance(head_pos)
		if result.distance < min_distance:
			min_distance = result.distance
			closest_direction = result.direction

		# Predictive check based on velocity
		if head_velocity.length() > 0.5:
			var predicted_pos := head_pos + head_velocity * 0.5  # 500ms ahead
			var pred_result := _get_boundary_distance(predicted_pos)
			if pred_result.distance < min_distance:
				min_distance = pred_result.distance
				closest_direction = pred_result.direction

	# Check controller positions
	if left_controller:
		var result := _get_boundary_distance(left_controller.global_position)
		if result.distance < min_distance:
			min_distance = result.distance
			closest_direction = result.direction

	if right_controller:
		var result := _get_boundary_distance(right_controller.global_position)
		if result.distance < min_distance:
			min_distance = result.distance
			closest_direction = result.direction

	# Check floor proximity
	if enable_floor_warning and xr_camera:
		var head_height := xr_camera.global_position.y
		if head_height < floor_warning_height:
			min_distance = minf(min_distance, head_height)
			closest_direction = Vector3.DOWN

	# Determine warning level
	var new_level := _distance_to_warning_level(min_distance)

	if new_level != current_warning_level:
		_set_warning_level(new_level)

	# Emit approach signal if not safe
	if new_level != WarningLevel.SAFE:
		boundary_approaching.emit(min_distance, closest_direction)


func _get_boundary_distance(position: Vector3) -> Dictionary:
	var min_distance := INF
	var closest_dir := Vector3.ZERO

	var pos_2d := Vector2(position.x, position.z)

	for i in range(boundary_points.size()):
		var p1 := boundary_points[i]
		var p2 := boundary_points[(i + 1) % boundary_points.size()]

		var line_start := Vector2(p1.x, p1.z)
		var line_end := Vector2(p2.x, p2.z)

		var result := _point_to_line_segment(pos_2d, line_start, line_end)

		if result.distance < min_distance:
			min_distance = result.distance
			var closest_3d := Vector3(result.closest_point.x, position.y, result.closest_point.y)
			closest_dir = (closest_3d - position).normalized()

	return {
		"distance": min_distance,
		"direction": closest_dir
	}


func _point_to_line_segment(point: Vector2, line_start: Vector2, line_end: Vector2) -> Dictionary:
	var line := line_end - line_start
	var length_sq := line.length_squared()

	if length_sq < 0.0001:
		return {
			"distance": point.distance_to(line_start),
			"closest_point": line_start
		}

	var t := clampf(((point - line_start).dot(line)) / length_sq, 0.0, 1.0)
	var closest := line_start + line * t

	return {
		"distance": point.distance_to(closest),
		"closest_point": closest
	}


func _distance_to_warning_level(distance: float) -> WarningLevel:
	if distance <= warning_distance_danger:
		return WarningLevel.DANGER
	elif distance <= warning_distance_warning:
		return WarningLevel.WARNING
	elif distance <= warning_distance_caution:
		return WarningLevel.CAUTION
	return WarningLevel.SAFE


func _set_warning_level(level: WarningLevel) -> void:
	var old_level := current_warning_level
	current_warning_level = level

	# Update visuals
	_update_boundary_color()
	_update_warning_overlay()

	# Emit signals
	match level:
		WarningLevel.SAFE:
			boundary_safe.emit()
		WarningLevel.DANGER:
			if xr_camera:
				boundary_breached.emit(xr_camera.global_position)

	# Haptic feedback
	if safety_mode in [SafetyMode.VISUAL_HAPTIC, SafetyMode.FULL]:
		_trigger_haptic_warning(level)

	# Audio warning
	if safety_mode == SafetyMode.FULL:
		_play_audio_warning(level)


func _update_head_velocity(delta: float) -> void:
	if xr_camera == null or delta <= 0:
		return

	var current_pos := xr_camera.global_position
	head_velocity = (current_pos - prev_head_pos) / delta
	prev_head_pos = current_pos


func _trigger_haptic_warning(level: WarningLevel) -> void:
	var intensity := 0.0
	var duration := 0.0

	match level:
		WarningLevel.CAUTION:
			intensity = 0.2
			duration = 0.1
		WarningLevel.WARNING:
			intensity = 0.5
			duration = 0.15
		WarningLevel.DANGER:
			intensity = 1.0
			duration = 0.3

	if intensity > 0:
		# Use HapticPatterns if available
		if left_controller:
			left_controller.trigger_haptic_pulse("haptic", duration, intensity, 0, 0)
		if right_controller:
			right_controller.trigger_haptic_pulse("haptic", duration, intensity, 0, 0)


func _play_audio_warning(level: WarningLevel) -> void:
	match level:
		WarningLevel.WARNING:
			GameEvents.sfx_requested.emit("boundary_warning", Vector3.ZERO)
		WarningLevel.DANGER:
			GameEvents.sfx_requested.emit("boundary_danger", Vector3.ZERO)


func _create_boundary_visuals() -> void:
	# Boundary wall mesh
	boundary_mesh = MeshInstance3D.new()
	boundary_mesh.name = "BoundaryWalls"

	# Create shader for animated boundary effect
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;

uniform vec4 boundary_color : source_color = vec4(0.0, 0.5, 1.0, 0.3);
uniform float pulse_speed : hint_range(0.0, 5.0) = 1.0;
uniform float grid_scale : hint_range(1.0, 20.0) = 10.0;

void fragment() {
	vec2 grid_uv = UV * grid_scale;
	float grid = step(0.95, fract(grid_uv.x)) + step(0.95, fract(grid_uv.y));

	float pulse = 0.5 + 0.5 * sin(TIME * pulse_speed);
	float alpha = boundary_color.a * (0.5 + 0.5 * grid) * pulse;

	ALBEDO = boundary_color.rgb;
	ALPHA = alpha;
}
"""

	boundary_material = ShaderMaterial.new()
	boundary_material.shader = shader
	boundary_material.set_shader_parameter("boundary_color", boundary_color_safe)
	boundary_material.set_shader_parameter("pulse_speed", 1.0)

	boundary_mesh.material_override = boundary_material
	boundary_mesh.visible = false
	add_child(boundary_mesh)


func _create_floor_grid() -> void:
	floor_grid = MeshInstance3D.new()
	floor_grid.name = "FloorGrid"

	var plane := PlaneMesh.new()
	plane.size = Vector2(10, 10)

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.1, 0.3, 0.5, 0.2)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	plane.material = mat

	floor_grid.mesh = plane
	floor_grid.position.y = 0.01
	floor_grid.visible = false
	add_child(floor_grid)


func _create_warning_overlay() -> void:
	# Full-screen warning overlay for danger situations
	warning_overlay = MeshInstance3D.new()
	warning_overlay.name = "WarningOverlay"

	var sphere := SphereMesh.new()
	sphere.radius = 0.5
	sphere.height = 1.0
	sphere.radial_segments = 16
	sphere.rings = 8

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1, 0, 0, 0)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_FRONT  # Render inside
	sphere.material = mat

	warning_overlay.mesh = sphere
	warning_overlay.visible = false
	add_child(warning_overlay)


func _update_boundary_mesh() -> void:
	if boundary_points.size() < 3:
		boundary_mesh.visible = false
		return

	# Create wall mesh from boundary points
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var wall_height := 2.5

	for i in range(boundary_points.size()):
		var p1 := boundary_points[i]
		var p2 := boundary_points[(i + 1) % boundary_points.size()]

		# Create wall quad
		var bottom_left := p1
		var bottom_right := p2
		var top_left := p1 + Vector3(0, wall_height, 0)
		var top_right := p2 + Vector3(0, wall_height, 0)

		# Calculate normal (facing inward)
		var edge := (p2 - p1).normalized()
		var normal := Vector3(-edge.z, 0, edge.x)

		# Calculate UVs
		var width := p1.distance_to(p2)
		var u_scale := width / wall_height

		# Triangle 1
		st.set_normal(normal)
		st.set_uv(Vector2(0, 1))
		st.add_vertex(bottom_left)
		st.set_uv(Vector2(u_scale, 1))
		st.add_vertex(bottom_right)
		st.set_uv(Vector2(0, 0))
		st.add_vertex(top_left)

		# Triangle 2
		st.set_normal(normal)
		st.set_uv(Vector2(u_scale, 1))
		st.add_vertex(bottom_right)
		st.set_uv(Vector2(u_scale, 0))
		st.add_vertex(top_right)
		st.set_uv(Vector2(0, 0))
		st.add_vertex(top_left)

	var mesh := st.commit()
	boundary_mesh.mesh = mesh


func _update_boundary_color() -> void:
	if boundary_material == null:
		return

	var color: Color
	var pulse_speed: float

	match current_warning_level:
		WarningLevel.SAFE:
			color = boundary_color_safe
			pulse_speed = 0.5
			boundary_mesh.visible = false
		WarningLevel.CAUTION:
			color = boundary_color_caution
			pulse_speed = 1.5
			boundary_mesh.visible = true
		WarningLevel.WARNING:
			color = boundary_color_warning
			pulse_speed = 3.0
			boundary_mesh.visible = true
		WarningLevel.DANGER:
			color = boundary_color_danger
			pulse_speed = 5.0
			boundary_mesh.visible = true

	boundary_material.set_shader_parameter("boundary_color", color)
	boundary_material.set_shader_parameter("pulse_speed", pulse_speed)


func _update_warning_overlay() -> void:
	if warning_overlay == null:
		return

	# Position overlay around camera
	if xr_camera:
		warning_overlay.global_position = xr_camera.global_position

	match current_warning_level:
		WarningLevel.SAFE, WarningLevel.CAUTION:
			warning_overlay.visible = false
		WarningLevel.WARNING:
			warning_overlay.visible = true
			var mat := warning_overlay.mesh.material as StandardMaterial3D
			if mat:
				mat.albedo_color = Color(1, 0.5, 0, 0.1)
		WarningLevel.DANGER:
			warning_overlay.visible = true
			var mat := warning_overlay.mesh.material as StandardMaterial3D
			if mat:
				mat.albedo_color = Color(1, 0, 0, 0.2)


func _on_bounds_changed(bounds: PackedVector3Array) -> void:
	boundary_points = bounds
	_update_boundary_mesh()


## Set safety mode
func set_safety_mode(mode: SafetyMode) -> void:
	safety_mode = mode
	safety_mode_changed.emit(mode)

	if mode == SafetyMode.DISABLED:
		_set_warning_level(WarningLevel.SAFE)


## Manually define play area (for testing or custom setups)
func set_custom_bounds(bounds: PackedVector3Array) -> void:
	boundary_points = bounds
	_calculate_center_and_size()
	_update_boundary_mesh()


func _calculate_center_and_size() -> void:
	if boundary_points.size() < 3:
		return

	var min_x := INF
	var max_x := -INF
	var min_z := INF
	var max_z := -INF

	for point in boundary_points:
		min_x = minf(min_x, point.x)
		max_x = maxf(max_x, point.x)
		min_z = minf(min_z, point.z)
		max_z = maxf(max_z, point.z)

	play_area_size = Vector2(max_x - min_x, max_z - min_z)
	boundary_center = Vector3((min_x + max_x) / 2.0, 0, (min_z + max_z) / 2.0)


## Get current warning level name
func get_warning_level_name() -> String:
	match current_warning_level:
		WarningLevel.SAFE: return "Safe"
		WarningLevel.CAUTION: return "Caution"
		WarningLevel.WARNING: return "Warning"
		WarningLevel.DANGER: return "Danger"
	return "Unknown"


## Get safety status
func get_status() -> Dictionary:
	return {
		"is_active": is_active,
		"safety_mode": safety_mode,
		"warning_level": get_warning_level_name(),
		"has_bounds": boundary_points.size() >= 3,
		"play_area_size": play_area_size
	}

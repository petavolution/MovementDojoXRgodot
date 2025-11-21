## MovementHeatMap - 3D visualization of movement coverage
## Shows where hands have been in space using particle-like display
extends Node3D
class_name MovementHeatMap

@export var update_interval := 0.5  # Seconds between updates
@export var point_size := 0.03  # Size of each heat point
@export var max_display_points := 2000  # Performance limit

# Color gradient (blue = cold/rare -> red = hot/frequent)
@export var cold_color := Color(0.2, 0.4, 1.0, 0.4)
@export var warm_color := Color(1.0, 1.0, 0.2, 0.6)
@export var hot_color := Color(1.0, 0.2, 0.1, 0.8)

var multi_mesh_instance: MultiMeshInstance3D
var multi_mesh: MultiMesh
var sphere_mesh: SphereMesh

var _update_timer := 0.0
var _head_position := Vector3.ZERO


func _ready() -> void:
	_setup_multi_mesh()

	# Visibility based on settings
	visible = SessionManager.get_settings().get("heat_map_visible", false)

	# Track head position for relative display
	GameEvents.movement_frame_recorded.connect(_on_movement_frame)


func _process(delta: float) -> void:
	if not visible:
		return

	_update_timer += delta
	if _update_timer >= update_interval:
		_update_timer = 0.0
		_update_heat_map()


func _setup_multi_mesh() -> void:
	# Create sphere mesh for heat points
	sphere_mesh = SphereMesh.new()
	sphere_mesh.radius = point_size
	sphere_mesh.height = point_size * 2
	sphere_mesh.radial_segments = 8
	sphere_mesh.rings = 4

	# Create material
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo = true
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sphere_mesh.material = material

	# Create MultiMesh
	multi_mesh = MultiMesh.new()
	multi_mesh.transform_format = MultiMesh.TRANSFORM_3D
	multi_mesh.use_colors = true
	multi_mesh.mesh = sphere_mesh
	multi_mesh.instance_count = max_display_points

	# Create instance
	multi_mesh_instance = MultiMeshInstance3D.new()
	multi_mesh_instance.multimesh = multi_mesh
	add_child(multi_mesh_instance)


func _on_movement_frame(frame: MovementFrame) -> void:
	_head_position = frame.head_position


func _update_heat_map() -> void:
	var space_map := MovementTracker.get_space_map()
	if space_map == null:
		return

	var heat_data := space_map.get_heat_map_data()

	# Limit to max display points
	var display_count := mini(heat_data.size(), max_display_points)
	multi_mesh.visible_instance_count = display_count

	if display_count == 0:
		return

	# Sort by intensity (optional, show most active first)
	heat_data.sort_custom(func(a, b): return a["intensity"] > b["intensity"])

	# Update instances
	for i in range(display_count):
		var data: Dictionary = heat_data[i]
		var world_pos: Vector3 = data["position"] + _head_position  # Convert relative to world
		var intensity: float = data["intensity"]

		# Set transform
		var transform := Transform3D.IDENTITY
		transform.origin = world_pos

		# Scale by intensity
		var scale := 0.5 + intensity * 0.5
		transform = transform.scaled(Vector3(scale, scale, scale))

		multi_mesh.set_instance_transform(i, transform)

		# Set color based on intensity
		var color := _intensity_to_color(intensity)
		multi_mesh.set_instance_color(i, color)

	# Hide remaining instances
	for i in range(display_count, max_display_points):
		var transform := Transform3D.IDENTITY
		transform.origin = Vector3(0, -1000, 0)  # Move far away
		multi_mesh.set_instance_transform(i, transform)


func _intensity_to_color(intensity: float) -> Color:
	if intensity < 0.33:
		return cold_color.lerp(warm_color, intensity * 3.0)
	elif intensity < 0.66:
		return warm_color.lerp(hot_color, (intensity - 0.33) * 3.0)
	else:
		return hot_color


func set_visibility(visible_: bool) -> void:
	visible = visible_


func force_update() -> void:
	_update_heat_map()

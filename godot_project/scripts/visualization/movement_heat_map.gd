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
	# Create low-poly sphere mesh for heat points (optimized for many instances)
	sphere_mesh = SphereMesh.new()
	sphere_mesh.radius = point_size
	sphere_mesh.height = point_size * 2
	sphere_mesh.radial_segments = 6  # Reduced from 8
	sphere_mesh.rings = 3  # Reduced from 4

	# Create unshaded material (fast rendering)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo = true
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sphere_mesh.material = material

	# Create MultiMesh with visible_instance_count = 0 (no rendering until data)
	multi_mesh = MultiMesh.new()
	multi_mesh.transform_format = MultiMesh.TRANSFORM_3D
	multi_mesh.use_colors = true
	multi_mesh.mesh = sphere_mesh
	multi_mesh.instance_count = max_display_points
	multi_mesh.visible_instance_count = 0  # Start with nothing visible

	# Create instance
	multi_mesh_instance = MultiMeshInstance3D.new()
	multi_mesh_instance.multimesh = multi_mesh
	add_child(multi_mesh_instance)


func _on_movement_frame(frame: MovementFrame) -> void:
	_head_position = frame.head_position


func _update_heat_map() -> void:
	var space_map := MovementTracker.get_space_map()
	if space_map == null:
		multi_mesh.visible_instance_count = 0
		return

	var heat_data := space_map.get_heat_map_data()
	if heat_data.is_empty():
		multi_mesh.visible_instance_count = 0
		return

	# Limit to max display points
	var display_count := mini(heat_data.size(), max_display_points)

	# Sort by intensity (show most active first) - only if needed
	if heat_data.size() > max_display_points:
		heat_data.sort_custom(func(a, b): return a["intensity"] > b["intensity"])

	# Update visible instances only
	for i in range(display_count):
		var data: Dictionary = heat_data[i]
		var world_pos: Vector3 = data["position"] + _head_position
		var intensity: float = data["intensity"]

		# Set transform with intensity-based scale
		var scale := 0.5 + intensity * 0.5
		var transform := Transform3D.IDENTITY.scaled(Vector3(scale, scale, scale))
		transform.origin = world_pos

		multi_mesh.set_instance_transform(i, transform)
		multi_mesh.set_instance_color(i, _intensity_to_color(intensity))

	# visible_instance_count automatically hides instances beyond this count
	multi_mesh.visible_instance_count = display_count


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

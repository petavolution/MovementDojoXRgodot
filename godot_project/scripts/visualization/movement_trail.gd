## MovementTrail - Renders ghost trails for hand movement visualization
## Attach to XROrigin3D or scene root
extends Node3D
class_name MovementTrail

@export var trail_length := 60  # Number of points (about 0.66s at 90Hz)
@export var trail_width := 0.01  # Width in meters
@export var left_color := Color(0.2, 0.6, 1.0, 0.6)
@export var right_color := Color(1.0, 0.4, 0.2, 0.6)
@export var fade_oldest := true
@export var min_velocity := 0.2  # Only show trail when moving

# Trail data
var left_points: PackedVector3Array
var right_points: PackedVector3Array
var left_colors: PackedColorArray
var right_colors: PackedColorArray

# Mesh instances
@onready var left_mesh_instance: MeshInstance3D = $LeftTrailMesh
@onready var right_mesh_instance: MeshInstance3D = $RightTrailMesh

var left_mesh: ImmediateMesh
var right_mesh: ImmediateMesh

# Material
var trail_material: StandardMaterial3D


func _ready() -> void:
	_setup_materials()
	_setup_mesh_instances()

	left_points.resize(trail_length)
	right_points.resize(trail_length)
	left_colors.resize(trail_length)
	right_colors.resize(trail_length)

	# Initialize colors
	for i in range(trail_length):
		var alpha := float(i) / trail_length if fade_oldest else 1.0
		left_colors[i] = Color(left_color.r, left_color.g, left_color.b, left_color.a * alpha)
		right_colors[i] = Color(right_color.r, right_color.g, right_color.b, right_color.a * alpha)

	GameEvents.movement_frame_recorded.connect(_on_movement_frame)

	# Visibility based on settings
	visible = SessionManager.get_settings().get("trail_visible", true)


func _setup_materials() -> void:
	trail_material = StandardMaterial3D.new()
	trail_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	trail_material.vertex_color_use_as_albedo = true
	trail_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	trail_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	trail_material.no_depth_test = false
	trail_material.render_priority = 1


func _setup_mesh_instances() -> void:
	# Create mesh instances if not in scene
	if not has_node("LeftTrailMesh"):
		left_mesh_instance = MeshInstance3D.new()
		left_mesh_instance.name = "LeftTrailMesh"
		add_child(left_mesh_instance)

	if not has_node("RightTrailMesh"):
		right_mesh_instance = MeshInstance3D.new()
		right_mesh_instance.name = "RightTrailMesh"
		add_child(right_mesh_instance)

	left_mesh = ImmediateMesh.new()
	right_mesh = ImmediateMesh.new()

	left_mesh_instance.mesh = left_mesh
	right_mesh_instance.mesh = right_mesh

	left_mesh_instance.material_override = trail_material
	right_mesh_instance.material_override = trail_material


func _on_movement_frame(frame: MovementFrame) -> void:
	# Shift points
	for i in range(trail_length - 1, 0, -1):
		left_points[i] = left_points[i - 1]
		right_points[i] = right_points[i - 1]

	# Add new points
	left_points[0] = frame.left_position
	right_points[0] = frame.right_position

	# Update meshes
	_update_trail_mesh(left_mesh, left_points, left_colors, frame.left_velocity.length())
	_update_trail_mesh(right_mesh, right_points, right_colors, frame.right_velocity.length())


func _update_trail_mesh(mesh: ImmediateMesh, points: PackedVector3Array, colors: PackedColorArray, velocity: float) -> void:
	mesh.clear_surfaces()

	# Don't render if moving too slowly
	if velocity < min_velocity:
		return

	var valid_points := 0
	for i in range(points.size()):
		if points[i] != Vector3.ZERO:
			valid_points += 1

	if valid_points < 2:
		return

	mesh.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)

	for i in range(valid_points):
		if points[i] == Vector3.ZERO:
			continue
		mesh.surface_set_color(colors[i])
		mesh.surface_add_vertex(points[i])

	mesh.surface_end()


func set_visibility(visible_: bool) -> void:
	visible = visible_


func clear_trails() -> void:
	for i in range(trail_length):
		left_points[i] = Vector3.ZERO
		right_points[i] = Vector3.ZERO

	left_mesh.clear_surfaces()
	right_mesh.clear_surfaces()

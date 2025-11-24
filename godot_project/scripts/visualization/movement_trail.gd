## MovementTrail - Renders ghost trails for hand movement visualization
## Optimized with ring buffer and reduced update frequency
extends Node3D
class_name MovementTrail

@export var trail_length := 60  # Number of points (~0.66s at 90Hz)
@export var trail_width := 0.01  # Width in meters
@export var left_color := Color(0.2, 0.6, 1.0, 0.6)
@export var right_color := Color(1.0, 0.4, 0.2, 0.6)
@export var fade_oldest := true
@export var min_velocity := 0.2  # Only show trail when moving
@export var update_interval := 2  # Update mesh every N frames (reduces CPU at 90Hz)

# Ring buffer for trail points (avoids array shifting)
var left_points: PackedVector3Array
var right_points: PackedVector3Array
var write_index := 0
var points_filled := 0

# Pre-computed colors (no per-frame allocation)
var left_colors: PackedColorArray
var right_colors: PackedColorArray

# Mesh instances
var left_mesh_instance: MeshInstance3D
var right_mesh_instance: MeshInstance3D
var left_mesh: ImmediateMesh
var right_mesh: ImmediateMesh

# Material (shared between both trails)
var trail_material: StandardMaterial3D

# Frame counter for update throttling
var frame_count := 0
var needs_update := false


func _ready() -> void:
	_setup_materials()
	_setup_mesh_instances()

	# Pre-allocate arrays (no resizing during runtime)
	left_points = PackedVector3Array()
	right_points = PackedVector3Array()
	left_colors = PackedColorArray()
	right_colors = PackedColorArray()

	left_points.resize(trail_length)
	right_points.resize(trail_length)
	left_colors.resize(trail_length)
	right_colors.resize(trail_length)

	# Pre-compute colors (oldest to newest)
	for i in range(trail_length):
		var alpha := float(i) / trail_length if fade_oldest else 1.0
		left_colors[i] = Color(left_color.r, left_color.g, left_color.b, left_color.a * alpha)
		right_colors[i] = Color(right_color.r, right_color.g, right_color.b, right_color.a * alpha)

	GameEvents.movement_frame_recorded.connect(_on_movement_frame)

	# Initial visibility from settings
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
	# Get or create mesh instances
	left_mesh_instance = get_node_or_null("LeftTrailMesh")
	if left_mesh_instance == null:
		left_mesh_instance = MeshInstance3D.new()
		left_mesh_instance.name = "LeftTrailMesh"
		add_child(left_mesh_instance)

	right_mesh_instance = get_node_or_null("RightTrailMesh")
	if right_mesh_instance == null:
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
	# Skip if not visible (no point recording data we won't render)
	if not visible:
		return

	# Store new point in ring buffer (O(1) instead of O(n) shift)
	left_points[write_index] = frame.left_position
	right_points[write_index] = frame.right_position

	write_index = (write_index + 1) % trail_length
	points_filled = mini(points_filled + 1, trail_length)

	# Throttle mesh updates (every N frames)
	frame_count += 1
	if frame_count >= update_interval:
		frame_count = 0
		_update_meshes(frame.left_velocity.length(), frame.right_velocity.length())


func _update_meshes(left_velocity: float, right_velocity: float) -> void:
	_update_trail_mesh(left_mesh, left_points, left_colors, left_velocity)
	_update_trail_mesh(right_mesh, right_points, right_colors, right_velocity)


func _update_trail_mesh(mesh: ImmediateMesh, points: PackedVector3Array, colors: PackedColorArray, velocity: float) -> void:
	mesh.clear_surfaces()

	# Don't render if too slow or not enough points
	if velocity < min_velocity or points_filled < 2:
		return

	mesh.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)

	# Read ring buffer from oldest to newest
	var count := points_filled
	for i in range(count):
		# Calculate ring buffer index (oldest first)
		var buf_idx := (write_index - count + i + trail_length) % trail_length
		var point := points[buf_idx]

		if point == Vector3.ZERO:
			continue

		# Color index maps to age (0 = oldest, count-1 = newest)
		var color_idx := int(float(i) / count * (trail_length - 1))
		mesh.surface_set_color(colors[color_idx])
		mesh.surface_add_vertex(point)

	mesh.surface_end()


func set_visibility(visible_: bool) -> void:
	visible = visible_
	if not visible:
		# Clear meshes when hidden
		left_mesh.clear_surfaces()
		right_mesh.clear_surfaces()


func clear_trails() -> void:
	write_index = 0
	points_filled = 0

	for i in range(trail_length):
		left_points[i] = Vector3.ZERO
		right_points[i] = Vector3.ZERO

	left_mesh.clear_surfaces()
	right_mesh.clear_surfaces()

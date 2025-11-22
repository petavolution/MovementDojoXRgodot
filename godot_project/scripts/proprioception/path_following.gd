## PathFollowing - 3D path tracing exercises for proprioceptive training
## Users trace predefined paths with their saber, receiving real-time feedback
class_name PathFollowing
extends Node3D

signal path_started(path_name: String)
signal path_completed(path_name: String, score: float, time: float)
signal path_failed(path_name: String, reason: String)
signal checkpoint_reached(index: int, total: int)
signal deviation_warning(amount: float, direction: Vector3)
signal perfect_segment_completed

## Path definition
class TracePath:
	var name: String = ""
	var description: String = ""
	var points: Array[Vector3] = []
	var rotations: Array[Vector3] = []  # Optional rotation guidance at each point
	var speeds: Array[float] = []  # Recommended speed at each segment
	var tolerance: float = 0.1  # Max deviation in meters
	var time_limit: float = 0.0  # 0 = no limit
	var require_direction: bool = false  # Must trace in correct direction
	var loop: bool = false
	var difficulty: float = 0.5

	func get_segment_length(index: int) -> float:
		if index < 0 or index >= points.size() - 1:
			return 0.0
		return points[index].distance_to(points[index + 1])

	func get_total_length() -> float:
		var length := 0.0
		for i in range(points.size() - 1):
			length += get_segment_length(i)
		return length


## Active path state
var current_path: TracePath
var is_active: bool = false
var current_checkpoint: int = 0
var path_progress: float = 0.0  # 0-1
var elapsed_time: float = 0.0

## Tracking
var saber_tip_position: Vector3 = Vector3.ZERO
var tracking_target: Node3D  # Usually the saber blade tip

## Scoring
var total_deviation: float = 0.0
var deviation_samples: int = 0
var perfect_segments: int = 0
var current_segment_perfect: bool = true

## Visualization
var path_visual: Node3D
var progress_indicator: Node3D
var deviation_indicator: Node3D

## Settings
@export var sample_rate: float = 30.0  # Samples per second
@export var checkpoint_distance: float = 0.05  # Distance to checkpoint to count as reached
@export var perfect_threshold: float = 0.03  # Deviation under this is "perfect"

var sample_timer: float = 0.0
var sample_interval: float = 1.0 / 30.0

## Predefined paths
var path_library: Dictionary = {}


func _ready() -> void:
	sample_interval = 1.0 / sample_rate
	_setup_path_library()
	_create_visualization()


func setup(saber_tip: Node3D) -> void:
	tracking_target = saber_tip


func _process(delta: float) -> void:
	if not is_active or tracking_target == null:
		return

	elapsed_time += delta
	saber_tip_position = tracking_target.global_position

	# Sample deviation at fixed rate
	sample_timer += delta
	if sample_timer >= sample_interval:
		sample_timer -= sample_interval
		_sample_deviation()

	_check_checkpoint_progress()
	_update_visualization()

	# Check time limit
	if current_path.time_limit > 0 and elapsed_time >= current_path.time_limit:
		_fail_path("Time limit exceeded")


func _setup_path_library() -> void:
	# Horizontal Figure-8
	var figure8_h := TracePath.new()
	figure8_h.name = "Horizontal Figure-8"
	figure8_h.description = "Trace a horizontal infinity symbol"
	figure8_h.points = _generate_figure8_points(0.5, Vector3.UP, 32)
	figure8_h.tolerance = 0.12
	figure8_h.difficulty = 0.4
	path_library["figure8_horizontal"] = figure8_h

	# Vertical Figure-8
	var figure8_v := TracePath.new()
	figure8_v.name = "Vertical Figure-8"
	figure8_v.description = "Trace a vertical infinity symbol"
	figure8_v.points = _generate_figure8_points(0.5, Vector3.FORWARD, 32)
	figure8_v.tolerance = 0.12
	figure8_v.difficulty = 0.5
	path_library["figure8_vertical"] = figure8_v

	# Circle - Clockwise
	var circle_cw := TracePath.new()
	circle_cw.name = "Circle (Clockwise)"
	circle_cw.description = "Trace a circle clockwise"
	circle_cw.points = _generate_circle_points(0.4, Vector3.FORWARD, 24, true)
	circle_cw.tolerance = 0.1
	circle_cw.difficulty = 0.3
	circle_cw.loop = true
	path_library["circle_cw"] = circle_cw

	# Circle - Counter-clockwise
	var circle_ccw := TracePath.new()
	circle_ccw.name = "Circle (Counter-clockwise)"
	circle_ccw.description = "Trace a circle counter-clockwise"
	circle_ccw.points = _generate_circle_points(0.4, Vector3.FORWARD, 24, false)
	circle_ccw.tolerance = 0.1
	circle_ccw.difficulty = 0.3
	circle_ccw.loop = true
	path_library["circle_ccw"] = circle_ccw

	# Vertical Slash
	var v_slash := TracePath.new()
	v_slash.name = "Vertical Slash"
	v_slash.description = "Straight vertical downward slash"
	v_slash.points = [
		Vector3(0, 1.8, -0.5),
		Vector3(0, 0.5, -0.5)
	]
	v_slash.tolerance = 0.08
	v_slash.difficulty = 0.2
	v_slash.require_direction = true
	path_library["vertical_slash"] = v_slash

	# Horizontal Slash
	var h_slash := TracePath.new()
	h_slash.name = "Horizontal Slash"
	h_slash.description = "Straight horizontal slash"
	h_slash.points = [
		Vector3(-0.6, 1.2, -0.5),
		Vector3(0.6, 1.2, -0.5)
	]
	h_slash.tolerance = 0.08
	h_slash.difficulty = 0.2
	h_slash.require_direction = true
	path_library["horizontal_slash"] = h_slash

	# Diagonal Slash (Top-left to Bottom-right)
	var diag_slash := TracePath.new()
	diag_slash.name = "Diagonal Slash"
	diag_slash.description = "Diagonal slash from top-left to bottom-right"
	diag_slash.points = [
		Vector3(-0.5, 1.7, -0.5),
		Vector3(0.5, 0.6, -0.5)
	]
	diag_slash.tolerance = 0.1
	diag_slash.difficulty = 0.3
	diag_slash.require_direction = true
	path_library["diagonal_slash"] = diag_slash

	# Square pattern
	var square := TracePath.new()
	square.name = "Square"
	square.description = "Trace a square shape"
	square.points = [
		Vector3(-0.3, 1.4, -0.5),
		Vector3(0.3, 1.4, -0.5),
		Vector3(0.3, 0.8, -0.5),
		Vector3(-0.3, 0.8, -0.5),
		Vector3(-0.3, 1.4, -0.5)
	]
	square.tolerance = 0.1
	square.difficulty = 0.4
	path_library["square"] = square

	# Triangle pattern
	var triangle := TracePath.new()
	triangle.name = "Triangle"
	triangle.description = "Trace a triangle shape"
	triangle.points = [
		Vector3(0, 1.6, -0.5),
		Vector3(-0.4, 0.8, -0.5),
		Vector3(0.4, 0.8, -0.5),
		Vector3(0, 1.6, -0.5)
	]
	triangle.tolerance = 0.1
	triangle.difficulty = 0.35
	path_library["triangle"] = triangle

	# Spiral inward
	var spiral := TracePath.new()
	spiral.name = "Spiral Inward"
	spiral.description = "Trace an inward spiral"
	spiral.points = _generate_spiral_points(0.5, 0.1, 3, 36)
	spiral.tolerance = 0.12
	spiral.difficulty = 0.6
	path_library["spiral_inward"] = spiral

	# Wave pattern
	var wave := TracePath.new()
	wave.name = "Wave"
	wave.description = "Trace a sinusoidal wave"
	wave.points = _generate_wave_points(0.8, 0.2, 3, 24)
	wave.tolerance = 0.1
	wave.difficulty = 0.5
	path_library["wave"] = wave


func _generate_figure8_points(scale: float, normal: Vector3, segments: int) -> Array[Vector3]:
	var points: Array[Vector3] = []
	var center := Vector3(0, 1.2, -0.5)

	for i in range(segments + 1):
		var t := float(i) / segments * TAU
		# Lemniscate of Bernoulli
		var denom := 1.0 + sin(t) * sin(t)
		var x := scale * cos(t) / denom
		var y := scale * sin(t) * cos(t) / denom

		var point := center
		if normal == Vector3.UP:
			point += Vector3(x, 0, y)
		elif normal == Vector3.FORWARD:
			point += Vector3(x, y, 0)
		else:
			point += Vector3(0, y, x)

		points.append(point)

	return points


func _generate_circle_points(radius: float, normal: Vector3, segments: int, clockwise: bool) -> Array[Vector3]:
	var points: Array[Vector3] = []
	var center := Vector3(0, 1.2, -0.5)

	for i in range(segments + 1):
		var t := float(i) / segments * TAU
		if not clockwise:
			t = -t

		var x := cos(t) * radius
		var y := sin(t) * radius

		var point := center
		if normal == Vector3.FORWARD:
			point += Vector3(x, y, 0)
		elif normal == Vector3.UP:
			point += Vector3(x, 0, y)
		else:
			point += Vector3(0, x, y)

		points.append(point)

	return points


func _generate_spiral_points(start_radius: float, end_radius: float, turns: float, segments: int) -> Array[Vector3]:
	var points: Array[Vector3] = []
	var center := Vector3(0, 1.2, -0.5)

	for i in range(segments + 1):
		var t := float(i) / segments
		var angle := t * turns * TAU
		var radius := lerpf(start_radius, end_radius, t)

		points.append(center + Vector3(cos(angle) * radius, sin(angle) * radius, 0))

	return points


func _generate_wave_points(width: float, amplitude: float, waves: float, segments: int) -> Array[Vector3]:
	var points: Array[Vector3] = []
	var start := Vector3(-width / 2, 1.2, -0.5)

	for i in range(segments + 1):
		var t := float(i) / segments
		var x := t * width
		var y := sin(t * waves * TAU) * amplitude

		points.append(start + Vector3(x, y, 0))

	return points


func _create_visualization() -> void:
	path_visual = Node3D.new()
	path_visual.name = "PathVisualization"
	add_child(path_visual)

	progress_indicator = _create_progress_sphere()
	add_child(progress_indicator)
	progress_indicator.visible = false

	deviation_indicator = _create_deviation_indicator()
	add_child(deviation_indicator)
	deviation_indicator.visible = false


func _create_progress_sphere() -> Node3D:
	var node := Node3D.new()
	var mesh := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.03
	sphere.height = 0.06

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.2, 1.0, 0.4)
	mat.emission_enabled = true
	mat.emission = Color(0.2, 1.0, 0.4)
	mat.emission_energy_multiplier = 2.0
	sphere.material = mat

	mesh.mesh = sphere
	node.add_child(mesh)
	return node


func _create_deviation_indicator() -> Node3D:
	var node := Node3D.new()
	# Arrow mesh pointing toward correct path
	var mesh := MeshInstance3D.new()
	var arrow := CylinderMesh.new()
	arrow.top_radius = 0.0
	arrow.bottom_radius = 0.02
	arrow.height = 0.1

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.5, 0.0)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.5, 0.0)
	arrow.material = mat

	mesh.mesh = arrow
	node.add_child(mesh)
	return node


## Start a path exercise
func start_path(path_id: String) -> bool:
	if not path_library.has(path_id):
		push_error("Unknown path: " + path_id)
		return false

	current_path = path_library[path_id]
	return _begin_path()


func start_custom_path(path: TracePath) -> bool:
	current_path = path
	return _begin_path()


func _begin_path() -> bool:
	if current_path == null or current_path.points.size() < 2:
		return false

	is_active = true
	current_checkpoint = 0
	path_progress = 0.0
	elapsed_time = 0.0
	total_deviation = 0.0
	deviation_samples = 0
	perfect_segments = 0
	current_segment_perfect = true

	_visualize_path()
	progress_indicator.visible = true

	path_started.emit(current_path.name)
	return true


func stop_path() -> void:
	is_active = false
	progress_indicator.visible = false
	deviation_indicator.visible = false
	_clear_path_visual()


func _sample_deviation() -> void:
	if current_path == null or current_checkpoint >= current_path.points.size() - 1:
		return

	# Find closest point on current segment
	var seg_start := current_path.points[current_checkpoint]
	var seg_end := current_path.points[current_checkpoint + 1]
	var closest := _closest_point_on_segment(saber_tip_position, seg_start, seg_end)

	var deviation := saber_tip_position.distance_to(closest)
	total_deviation += deviation
	deviation_samples += 1

	# Check if deviation is too high
	if deviation > current_path.tolerance:
		deviation_warning.emit(deviation, (closest - saber_tip_position).normalized())
		current_segment_perfect = false

		# Update deviation indicator
		deviation_indicator.visible = true
		deviation_indicator.global_position = saber_tip_position
		deviation_indicator.look_at(closest, Vector3.UP)

	elif deviation > perfect_threshold:
		current_segment_perfect = false
		deviation_indicator.visible = false
	else:
		deviation_indicator.visible = false


func _check_checkpoint_progress() -> void:
	if current_path == null:
		return

	var target := current_path.points[current_checkpoint + 1] if current_checkpoint < current_path.points.size() - 1 else current_path.points[current_checkpoint]
	var distance := saber_tip_position.distance_to(target)

	if distance <= checkpoint_distance:
		# Reached checkpoint
		if current_segment_perfect:
			perfect_segments += 1
			perfect_segment_completed.emit()

		current_checkpoint += 1
		current_segment_perfect = true

		checkpoint_reached.emit(current_checkpoint, current_path.points.size() - 1)

		# Update progress indicator
		progress_indicator.global_position = target

		# Check for completion
		if current_checkpoint >= current_path.points.size() - 1:
			_complete_path()


func _complete_path() -> void:
	is_active = false

	var avg_deviation := total_deviation / deviation_samples if deviation_samples > 0 else 0.0
	var accuracy := 1.0 - clampf(avg_deviation / current_path.tolerance, 0.0, 1.0)
	var perfect_ratio := float(perfect_segments) / (current_path.points.size() - 1)

	# Final score combines accuracy and perfect segments
	var score := accuracy * 0.7 + perfect_ratio * 0.3

	path_completed.emit(current_path.name, score, elapsed_time)

	progress_indicator.visible = false
	deviation_indicator.visible = false


func _fail_path(reason: String) -> void:
	is_active = false
	path_failed.emit(current_path.name, reason)

	progress_indicator.visible = false
	deviation_indicator.visible = false


func _closest_point_on_segment(point: Vector3, seg_start: Vector3, seg_end: Vector3) -> Vector3:
	var seg := seg_end - seg_start
	var seg_length := seg.length()
	if seg_length < 0.001:
		return seg_start

	var seg_dir := seg / seg_length
	var to_point := point - seg_start
	var projection := to_point.dot(seg_dir)

	projection = clampf(projection, 0.0, seg_length)
	return seg_start + seg_dir * projection


func _visualize_path() -> void:
	_clear_path_visual()

	if current_path == null:
		return

	# Create line mesh for path
	var im := ImmediateMesh.new()
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.mesh = im

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.3, 0.7, 1.0, 0.7)
	mat.emission_enabled = true
	mat.emission = Color(0.3, 0.7, 1.0)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	im.surface_begin(Mesh.PRIMITIVE_LINE_STRIP, mat)

	for point in current_path.points:
		im.surface_add_vertex(point)

	im.surface_end()

	path_visual.add_child(mesh_instance)

	# Add checkpoint markers
	for i in range(current_path.points.size()):
		var marker := _create_checkpoint_marker(i == 0, i == current_path.points.size() - 1)
		marker.position = current_path.points[i]
		path_visual.add_child(marker)


func _create_checkpoint_marker(is_start: bool, is_end: bool) -> Node3D:
	var node := Node3D.new()
	var mesh := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.025 if not (is_start or is_end) else 0.04

	var mat := StandardMaterial3D.new()
	if is_start:
		mat.albedo_color = Color(0.2, 1.0, 0.2)  # Green for start
	elif is_end:
		mat.albedo_color = Color(1.0, 0.8, 0.2)  # Gold for end
	else:
		mat.albedo_color = Color(0.5, 0.7, 1.0)  # Blue for checkpoints

	mat.emission_enabled = true
	mat.emission = mat.albedo_color
	sphere.material = mat

	mesh.mesh = sphere
	node.add_child(mesh)
	return node


func _clear_path_visual() -> void:
	for child in path_visual.get_children():
		child.queue_free()


func _update_visualization() -> void:
	if not is_active:
		return

	# Update progress indicator along path
	if current_checkpoint < current_path.points.size() - 1:
		var next_point := current_path.points[current_checkpoint + 1]
		progress_indicator.global_position = progress_indicator.global_position.lerp(next_point, 0.1)


## Get available paths
func get_path_list() -> Array[String]:
	var list: Array[String] = []
	for key in path_library:
		list.append(key)
	return list


func get_path(path_id: String) -> TracePath:
	return path_library.get(path_id)


func get_progress() -> float:
	if current_path == null or current_path.points.size() < 2:
		return 0.0
	return float(current_checkpoint) / (current_path.points.size() - 1)

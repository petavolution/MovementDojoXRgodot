## GapIndicator - Visual indicators for unexplored movement zones
## Encourages users to explore new movement areas
extends Node3D
class_name GapIndicator

@export var max_indicators := 10
@export var indicator_size := 0.08
@export var pulse_speed := 2.0
@export var indicator_color := Color(0.8, 0.8, 0.2, 0.5)
@export var update_interval := 2.0  # Seconds between zone updates
@export var exploration_radius := 0.15  # How close to "discover" a zone

var active_indicators: Array[Node3D] = []
var target_positions: Array[Vector3] = []
var _update_timer := 0.0
var _head_position := Vector3.ZERO
var _pulse_phase := 0.0

# Indicator scene (simple sphere)
var indicator_mesh: SphereMesh
var indicator_material: StandardMaterial3D


func _ready() -> void:
	_setup_indicator_resources()

	visible = SessionManager.get_settings().get("gap_indicators_visible", true)

	GameEvents.movement_frame_recorded.connect(_on_movement_frame)
	GameEvents.movement_zone_explored.connect(_on_zone_explored)


func _process(delta: float) -> void:
	if not visible:
		return

	# Update pulse animation
	_pulse_phase += delta * pulse_speed
	var pulse_scale := 1.0 + sin(_pulse_phase) * 0.2

	# Update indicator positions and scale (relative to head)
	for i in range(active_indicators.size()):
		var indicator := active_indicators[i]
		if is_instance_valid(indicator):
			indicator.scale = Vector3.ONE * indicator_size * pulse_scale
			indicator.position = target_positions[i] + _head_position

	# Periodically update target zones
	_update_timer += delta
	if _update_timer >= update_interval:
		_update_timer = 0.0
		_update_target_zones()


func _setup_indicator_resources() -> void:
	# Low-poly sphere for indicators (max 10, so complexity matters less)
	indicator_mesh = SphereMesh.new()
	indicator_mesh.radius = 0.5
	indicator_mesh.height = 1.0
	indicator_mesh.radial_segments = 8  # Reduced from 16
	indicator_mesh.rings = 4  # Reduced from 8

	indicator_material = StandardMaterial3D.new()
	indicator_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	indicator_material.albedo_color = indicator_color
	indicator_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	indicator_material.emission_enabled = true
	indicator_material.emission = indicator_color
	indicator_material.emission_energy_multiplier = 0.5


func _on_movement_frame(frame: MovementFrame) -> void:
	_head_position = frame.head_position

	# Check if hands are near any indicator
	_check_exploration(frame.left_position, "left")
	_check_exploration(frame.right_position, "right")


func _on_zone_explored(zone_position: Vector3, _hand: String) -> void:
	# Remove indicator if it was near the explored zone
	_remove_indicator_near(zone_position)


func _check_exploration(hand_pos: Vector3, _hand: String) -> void:
	for i in range(target_positions.size() - 1, -1, -1):
		var target_world := target_positions[i] + _head_position
		if hand_pos.distance_to(target_world) < exploration_radius:
			_on_indicator_reached(i)


func _on_indicator_reached(index: int) -> void:
	if index < 0 or index >= active_indicators.size():
		return

	var indicator := active_indicators[index]
	var position := target_positions[index] + _head_position

	# Spawn celebration effect
	_spawn_discovery_effect(position)

	# Remove indicator
	if is_instance_valid(indicator):
		indicator.queue_free()

	active_indicators.remove_at(index)
	target_positions.remove_at(index)


func _spawn_discovery_effect(position: Vector3) -> void:
	# Simple flash effect
	var flash := MeshInstance3D.new()
	flash.mesh = indicator_mesh
	flash.material_override = indicator_material.duplicate()
	flash.material_override.albedo_color = Color(1.0, 1.0, 0.5, 0.8)
	flash.material_override.emission = Color(1.0, 1.0, 0.5)
	flash.position = position
	flash.scale = Vector3.ONE * indicator_size * 2

	add_child(flash)

	# Animate and remove
	var tween := create_tween()
	tween.tween_property(flash, "scale", Vector3.ONE * indicator_size * 4, 0.3)
	tween.parallel().tween_property(flash.material_override, "albedo_color:a", 0.0, 0.3)
	tween.tween_callback(flash.queue_free)


func _update_target_zones() -> void:
	var space_map := MovementTracker.get_space_map()
	if space_map == null:
		return

	# Get unexplored zones
	var unexplored := space_map.get_unexplored_zones(max_indicators * 3)

	if unexplored.is_empty():
		return

	# Filter to zones that don't already have indicators
	var new_zones: Array[Vector3] = []
	for zone in unexplored:
		var already_targeted := false
		for existing in target_positions:
			if zone.distance_to(existing) < 0.2:
				already_targeted = true
				break
		if not already_targeted:
			new_zones.append(zone)

	# Prioritize interesting zones (overhead, behind, etc.)
	new_zones.sort_custom(_zone_priority_sort)

	# Add indicators up to max
	var to_add := mini(max_indicators - active_indicators.size(), new_zones.size())

	for i in range(to_add):
		_create_indicator(new_zones[i])


func _zone_priority_sort(a: Vector3, b: Vector3) -> bool:
	# Prioritize overhead and behind reaches
	var a_priority := _get_zone_priority(a)
	var b_priority := _get_zone_priority(b)
	return a_priority > b_priority


func _get_zone_priority(zone: Vector3) -> float:
	var priority := 0.0

	# Overhead is high priority
	if zone.y > 0.3:
		priority += 2.0

	# Behind is high priority
	if zone.z < -0.2:
		priority += 1.5

	# Cross-body is interesting
	if abs(zone.x) > 0.4:
		priority += 1.0

	# Low reaches are valuable
	if zone.y < -0.4:
		priority += 1.0

	return priority


func _create_indicator(relative_position: Vector3) -> void:
	var indicator := MeshInstance3D.new()
	indicator.mesh = indicator_mesh
	indicator.material_override = indicator_material
	indicator.scale = Vector3.ONE * indicator_size

	add_child(indicator)

	active_indicators.append(indicator)
	target_positions.append(relative_position)

	# Update position (will be updated each frame relative to head)
	indicator.position = relative_position + _head_position


func _remove_indicator_near(world_position: Vector3) -> void:
	for i in range(active_indicators.size() - 1, -1, -1):
		var target_world := target_positions[i] + _head_position
		if world_position.distance_to(target_world) < 0.2:
			if is_instance_valid(active_indicators[i]):
				active_indicators[i].queue_free()
			active_indicators.remove_at(i)
			target_positions.remove_at(i)


func set_visibility(visible_: bool) -> void:
	visible = visible_
	for indicator in active_indicators:
		if is_instance_valid(indicator):
			indicator.visible = visible_

## DojoEnvironment - Training dojo scene setup
## Creates the visual environment for training
extends Node3D
class_name DojoEnvironment

@export_group("Dojo Settings")
@export var dojo_radius := 10.0
@export var dojo_height := 6.0
@export var ambient_color := Color(0.05, 0.05, 0.1)
@export var accent_color := Color(0.2, 0.4, 0.8)

@export_group("Lighting")
@export var main_light_intensity := 0.3
@export var accent_light_intensity := 1.0

# Generated nodes
var floor_mesh: MeshInstance3D
var walls: Node3D
var ceiling_mesh: MeshInstance3D
var main_light: DirectionalLight3D
var accent_lights: Array[OmniLight3D] = []


func _ready() -> void:
	_create_floor()
	_create_walls()
	_create_ceiling()
	_create_lighting()
	_create_decorations()


func _create_floor() -> void:
	floor_mesh = MeshInstance3D.new()
	floor_mesh.name = "Floor"

	var plane := PlaneMesh.new()
	plane.size = Vector2(dojo_radius * 2, dojo_radius * 2)

	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.08, 0.08, 0.1)
	material.metallic = 0.2
	material.roughness = 0.8

	# Grid pattern
	material.uv1_scale = Vector3(10, 10, 1)

	plane.material = material
	floor_mesh.mesh = plane

	add_child(floor_mesh)


func _create_walls() -> void:
	walls = Node3D.new()
	walls.name = "Walls"
	add_child(walls)

	# Create octagonal walls
	var segments := 8
	var angle_step := TAU / segments

	for i in range(segments):
		var wall := _create_wall_segment(i, angle_step)
		walls.add_child(wall)


func _create_wall_segment(index: int, angle_step: float) -> MeshInstance3D:
	var wall := MeshInstance3D.new()

	var mesh := BoxMesh.new()
	var segment_width := 2 * dojo_radius * sin(angle_step / 2)
	mesh.size = Vector3(segment_width, dojo_height, 0.2)

	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.06, 0.06, 0.08)
	material.metallic = 0.1
	material.roughness = 0.9

	mesh.material = material
	wall.mesh = mesh

	# Position wall segment
	var angle := index * angle_step
	var distance := dojo_radius - 0.1
	wall.position = Vector3(
		cos(angle) * distance,
		dojo_height / 2,
		sin(angle) * distance
	)
	wall.rotation.y = -angle + PI / 2

	return wall


func _create_ceiling() -> void:
	ceiling_mesh = MeshInstance3D.new()
	ceiling_mesh.name = "Ceiling"

	var plane := PlaneMesh.new()
	plane.size = Vector2(dojo_radius * 2, dojo_radius * 2)

	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.04, 0.04, 0.06)
	material.metallic = 0.0
	material.roughness = 1.0

	plane.material = material
	ceiling_mesh.mesh = plane
	ceiling_mesh.position.y = dojo_height
	ceiling_mesh.rotation.x = PI  # Flip to face down

	add_child(ceiling_mesh)


func _create_lighting() -> void:
	# Main directional light (dim ambient)
	main_light = DirectionalLight3D.new()
	main_light.name = "MainLight"
	main_light.light_color = Color(0.9, 0.9, 1.0)
	main_light.light_energy = main_light_intensity
	main_light.shadow_enabled = true
	main_light.rotation_degrees = Vector3(-45, 30, 0)
	add_child(main_light)

	# Accent lights around the room
	var light_count := 4
	for i in range(light_count):
		var light := OmniLight3D.new()
		light.name = "AccentLight" + str(i)
		light.light_color = accent_color
		light.light_energy = accent_light_intensity
		light.omni_range = 8.0
		light.omni_attenuation = 1.5
		light.shadow_enabled = false

		var angle := (float(i) / light_count) * TAU
		light.position = Vector3(
			cos(angle) * (dojo_radius - 2),
			dojo_height - 1,
			sin(angle) * (dojo_radius - 2)
		)

		accent_lights.append(light)
		add_child(light)


func _create_decorations() -> void:
	# Center training platform (slightly raised)
	var platform := MeshInstance3D.new()
	platform.name = "TrainingPlatform"

	var cylinder := CylinderMesh.new()
	cylinder.top_radius = 2.5
	cylinder.bottom_radius = 2.8
	cylinder.height = 0.1

	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.1, 0.1, 0.15)
	material.metallic = 0.4
	material.roughness = 0.6
	material.emission_enabled = true
	material.emission = accent_color * 0.1

	cylinder.material = material
	platform.mesh = cylinder
	platform.position.y = 0.05

	add_child(platform)

	# Edge lights on platform
	_create_platform_edge_lights(2.5)


func _create_platform_edge_lights(radius: float) -> void:
	var edge_lights := Node3D.new()
	edge_lights.name = "PlatformEdgeLights"
	add_child(edge_lights)

	var light_count := 12
	for i in range(light_count):
		var light := OmniLight3D.new()
		light.light_color = accent_color
		light.light_energy = 0.3
		light.omni_range = 1.0
		light.omni_attenuation = 2.0

		var angle := (float(i) / light_count) * TAU
		light.position = Vector3(
			cos(angle) * radius,
			0.15,
			sin(angle) * radius
		)

		edge_lights.add_child(light)


## Change accent color (can be called for different modes)
func set_accent_color(color: Color) -> void:
	accent_color = color

	for light in accent_lights:
		light.light_color = color

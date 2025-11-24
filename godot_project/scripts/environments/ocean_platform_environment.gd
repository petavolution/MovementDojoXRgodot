## OceanPlatformEnvironment - Raised platform surrounded by infinite ocean
## Player stands on a stone/metal platform with railings, looking out at the sea
##
## Layout:
##   - Central platform: 6m x 6m raised 0.5m above water
##   - Low railings around edges
##   - Large water plane extending to horizon
##   - Sky dome with gradient
##   - Directional sun light
extends BaseEnvironment
class_name OceanPlatformEnvironment

const ENV_SOURCE := "OceanPlatform"

# =============================================================================
# CONFIGURATION
# =============================================================================

## Platform dimensions
@export var platform_width := 6.0
@export var platform_depth := 6.0
@export var platform_height := 0.4
@export var platform_elevation := 0.5  # Height above water

## Railing configuration
@export var railing_height := 0.9
@export var railing_thickness := 0.05
@export var railing_post_width := 0.08

## Ocean configuration
@export var ocean_size := 500.0  # Large plane for "infinite" feel
@export var water_color := Color(0.05, 0.25, 0.4)
@export var water_alpha := 0.85

## Sky configuration
@export var sky_color := Color(0.4, 0.6, 0.9)
@export var horizon_color := Color(0.7, 0.8, 0.95)
@export var sun_direction := Vector3(-0.5, -0.8, -0.3)

# =============================================================================
# COLORS
# =============================================================================

const PLATFORM_COLOR := Color(0.35, 0.32, 0.28)  # Stone gray-brown
const PLATFORM_TOP_COLOR := Color(0.4, 0.38, 0.35)  # Slightly lighter top
const RAILING_COLOR := Color(0.25, 0.25, 0.28)  # Dark metal
const POST_COLOR := Color(0.3, 0.3, 0.32)

# =============================================================================
# IMPLEMENTATION
# =============================================================================

func get_environment_name() -> String:
	return "OceanPlatform"


func _build_environment() -> void:
	_build_sky_and_lighting()
	_build_ocean()
	_build_platform()
	_build_railings()

	DebugLogger.info(ENV_SOURCE, "Platform: %.1fm x %.1fm at height %.1fm" % [
		platform_width, platform_depth, platform_elevation
	])
	DebugLogger.info(ENV_SOURCE, "Ocean: %.0fm x %.0fm water plane" % [ocean_size, ocean_size])


func _build_sky_and_lighting() -> void:
	# Create world environment with sky gradient
	_create_world_environment(
		sky_color,
		horizon_color,
		0.6,
		true,  # fog enabled
		Color(0.7, 0.8, 0.9),  # fog color
		0.002  # light fog density
	)

	# Sun light
	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.light_color = Color(1.0, 0.95, 0.85)  # Warm sunlight
	sun.light_energy = 1.2
	sun.shadow_enabled = true
	sun.look_at_from_position(Vector3.ZERO, sun_direction.normalized(), Vector3.UP)
	_add_geometry(sun)

	# Ambient fill from sky
	var fill := DirectionalLight3D.new()
	fill.name = "SkyFill"
	fill.light_color = sky_color
	fill.light_energy = 0.3
	fill.shadow_enabled = false
	fill.look_at_from_position(Vector3.ZERO, Vector3(0.2, -1, 0.1), Vector3.UP)
	_add_geometry(fill)


func _build_ocean() -> void:
	# Create large water plane at y=0
	var water := ProceduralMeshes.create_plane(
		ocean_size,
		ocean_size,
		water_color,
		Vector3.ZERO,
		true
	)
	water.name = "Ocean"

	# Apply transparent water material
	var water_mat := ProceduralMeshes.create_transparent_material(
		water_color,
		water_alpha,
		0.15  # subtle emission for glow
	)
	water_mat.roughness = 0.1  # Shiny water
	water_mat.metallic = 0.05
	water.material_override = water_mat

	_add_geometry(water)

	DebugLogger.debug(ENV_SOURCE, "Created ocean plane")


func _build_platform() -> void:
	var platform_y := platform_elevation + platform_height / 2.0

	# Main platform body
	var platform := ProceduralMeshes.create_box(
		Vector3(platform_width, platform_height, platform_depth),
		PLATFORM_COLOR,
		Vector3(0, platform_y, 0)
	)
	platform.name = "Platform"

	# Apply slightly metallic material for stone look
	var platform_mat := ProceduralMeshes.create_simple_pbr_material(
		PLATFORM_COLOR,
		0.1,
		0.85
	)
	platform.material_override = platform_mat
	_add_geometry(platform)

	# Platform top surface (slightly different color for visual interest)
	var top_surface := ProceduralMeshes.create_box(
		Vector3(platform_width - 0.1, 0.05, platform_depth - 0.1),
		PLATFORM_TOP_COLOR,
		Vector3(0, platform_elevation + platform_height + 0.025, 0)
	)
	top_surface.name = "PlatformTop"
	_add_geometry(top_surface)

	# Edge trim (dark border around platform)
	var trim_height := 0.08
	var trim_width := 0.12
	_create_platform_trim(trim_height, trim_width)

	DebugLogger.debug(ENV_SOURCE, "Created platform")


func _create_platform_trim(trim_height: float, trim_width: float) -> void:
	var platform_top := platform_elevation + platform_height
	var trim_y := platform_top + trim_height / 2.0
	var half_w := platform_width / 2.0
	var half_d := platform_depth / 2.0

	var trim_color := Color(0.2, 0.2, 0.22)

	# Four edge trims
	var edges := [
		# Front
		{"pos": Vector3(0, trim_y, half_d - trim_width/2), "size": Vector3(platform_width, trim_height, trim_width)},
		# Back
		{"pos": Vector3(0, trim_y, -half_d + trim_width/2), "size": Vector3(platform_width, trim_height, trim_width)},
		# Left
		{"pos": Vector3(-half_w + trim_width/2, trim_y, 0), "size": Vector3(trim_width, trim_height, platform_depth - trim_width*2)},
		# Right
		{"pos": Vector3(half_w - trim_width/2, trim_y, 0), "size": Vector3(trim_width, trim_height, platform_depth - trim_width*2)},
	]

	for i in range(edges.size()):
		var edge: Dictionary = edges[i]
		var trim := ProceduralMeshes.create_box(edge.size, trim_color, edge.pos)
		trim.name = "Trim%d" % i
		_add_geometry(trim)


func _build_railings() -> void:
	var platform_top := platform_elevation + platform_height
	var half_w := platform_width / 2.0 - 0.15
	var half_d := platform_depth / 2.0 - 0.15

	# Create railings on all four sides
	_create_railing_side(Vector3(-half_w, platform_top, 0), Vector3.BACK, platform_depth - 0.3, "Left")
	_create_railing_side(Vector3(half_w, platform_top, 0), Vector3.FORWARD, platform_depth - 0.3, "Right")
	_create_railing_side(Vector3(0, platform_top, half_d), Vector3.LEFT, platform_width - 0.3, "Front")
	_create_railing_side(Vector3(0, platform_top, -half_d), Vector3.RIGHT, platform_width - 0.3, "Back")

	DebugLogger.debug(ENV_SOURCE, "Created railings")


func _create_railing_side(center: Vector3, direction: Vector3, length: float, side_name: String) -> void:
	var post_spacing := 1.5
	var num_posts := int(length / post_spacing) + 1
	var actual_spacing := length / (num_posts - 1) if num_posts > 1 else 0.0

	# Calculate perpendicular for posts placement
	var perp := direction.cross(Vector3.UP).normalized()

	# Top rail
	var rail_y := center.y + railing_height
	var rail := ProceduralMeshes.create_box(
		Vector3(railing_thickness, railing_thickness, length) if abs(direction.z) > 0.5 else Vector3(length, railing_thickness, railing_thickness),
		RAILING_COLOR,
		Vector3(center.x, rail_y, center.z)
	)
	rail.name = "Rail" + side_name
	var rail_mat := ProceduralMeshes.create_metallic_material(RAILING_COLOR, 0.8, 0.4)
	rail.material_override = rail_mat
	_add_geometry(rail)

	# Middle rail
	var mid_rail_y := center.y + railing_height * 0.5
	var mid_rail := ProceduralMeshes.create_box(
		Vector3(railing_thickness * 0.8, railing_thickness * 0.8, length) if abs(direction.z) > 0.5 else Vector3(length, railing_thickness * 0.8, railing_thickness * 0.8),
		RAILING_COLOR,
		Vector3(center.x, mid_rail_y, center.z)
	)
	mid_rail.name = "MidRail" + side_name
	mid_rail.material_override = rail_mat
	_add_geometry(mid_rail)

	# Posts
	for i in range(num_posts):
		var t := float(i) / (num_posts - 1) if num_posts > 1 else 0.5
		var post_offset := (t - 0.5) * length
		var post_pos := center + perp * post_offset
		post_pos.y = center.y + railing_height / 2.0

		var post := ProceduralMeshes.create_box(
			Vector3(railing_post_width, railing_height, railing_post_width),
			POST_COLOR,
			post_pos
		)
		post.name = "Post%s%d" % [side_name, i]
		post.material_override = ProceduralMeshes.create_metallic_material(POST_COLOR, 0.7, 0.5)
		_add_geometry(post)

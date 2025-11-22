## ProceduralMeshes - Utility class for creating procedural geometry
## Provides reusable building blocks for training environments
##
## Usage:
##   var floor = ProceduralMeshes.create_plane(10.0, 10.0, Color(0.2, 0.2, 0.2))
##   add_child(floor)
##
##   var wall = ProceduralMeshes.create_box(Vector3(5, 3, 0.2), Color(0.3, 0.3, 0.3))
##   wall.position = Vector3(0, 1.5, -5)
##   add_child(wall)
extends RefCounted
class_name ProceduralMeshes

const SOURCE := "ProceduralMesh"

# =============================================================================
# CONFIGURATION
# =============================================================================

## Minimum segments for curved geometry
const MIN_SEGMENTS := 3
## Maximum segments to prevent performance issues
const MAX_SEGMENTS := 128
## Default segments for cylinders/rings
const DEFAULT_SEGMENTS := 16

# =============================================================================
# PLANE MESH
# =============================================================================

## Create a horizontal plane (floor/ceiling)
## Returns MeshInstance3D ready to add to scene tree
##
## Parameters:
##   width: Size along X axis
##   depth: Size along Z axis
##   color: Albedo color for the material
##   position: Optional world position (default: origin)
##   facing_up: If true, normal points up (+Y); if false, points down (-Y)
static func create_plane(
	width: float,
	depth: float,
	color: Color = Color.WHITE,
	position: Vector3 = Vector3.ZERO,
	facing_up: bool = true
) -> MeshInstance3D:
	# Validate inputs
	if width <= 0.0 or depth <= 0.0:
		DebugLogger.warn(SOURCE, "Invalid plane dimensions (%.2f x %.2f), using 1x1" % [width, depth])
		width = maxf(width, 1.0)
		depth = maxf(depth, 1.0)

	var mesh := PlaneMesh.new()
	mesh.size = Vector2(width, depth)

	var material := create_simple_pbr_material(color)
	mesh.material = material

	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.position = position

	# Flip if facing down (for ceilings)
	if not facing_up:
		instance.rotation_degrees.x = 180.0

	DebugLogger.debug(SOURCE, "Created plane %.1fx%.1f at %s" % [width, depth, position])
	return instance


## Create a vertical plane (wall segment)
## Normal faces along +Z by default
static func create_wall_plane(
	width: float,
	height: float,
	color: Color = Color.WHITE,
	position: Vector3 = Vector3.ZERO
) -> MeshInstance3D:
	if width <= 0.0 or height <= 0.0:
		DebugLogger.warn(SOURCE, "Invalid wall dimensions (%.2f x %.2f), using 1x1" % [width, height])
		width = maxf(width, 1.0)
		height = maxf(height, 1.0)

	var mesh := PlaneMesh.new()
	mesh.size = Vector2(width, height)

	var material := create_simple_pbr_material(color)
	mesh.material = material

	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.position = position
	# Rotate to face +Z (vertical wall)
	instance.rotation_degrees.x = -90.0

	DebugLogger.debug(SOURCE, "Created wall plane %.1fx%.1f at %s" % [width, height, position])
	return instance


# =============================================================================
# BOX MESH
# =============================================================================

## Create a box/cube mesh
##
## Parameters:
##   size: Vector3 with width (X), height (Y), depth (Z)
##   color: Albedo color
##   position: Optional world position (default: origin, box centered)
static func create_box(
	size: Vector3,
	color: Color = Color.WHITE,
	position: Vector3 = Vector3.ZERO
) -> MeshInstance3D:
	# Validate inputs
	var valid_size := Vector3(
		maxf(size.x, 0.01),
		maxf(size.y, 0.01),
		maxf(size.z, 0.01)
	)
	if valid_size != size:
		DebugLogger.warn(SOURCE, "Invalid box size %s, clamped to %s" % [size, valid_size])

	var mesh := BoxMesh.new()
	mesh.size = valid_size

	var material := create_simple_pbr_material(color)
	mesh.material = material

	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.position = position

	DebugLogger.debug(SOURCE, "Created box %s at %s" % [valid_size, position])
	return instance


## Create a thin box suitable for platforms/floors with thickness
static func create_platform(
	width: float,
	depth: float,
	thickness: float = 0.2,
	color: Color = Color.WHITE,
	position: Vector3 = Vector3.ZERO
) -> MeshInstance3D:
	return create_box(Vector3(width, thickness, depth), color, position)


## Create a thin box suitable for walls
static func create_wall(
	width: float,
	height: float,
	thickness: float = 0.2,
	color: Color = Color.WHITE,
	position: Vector3 = Vector3.ZERO
) -> MeshInstance3D:
	return create_box(Vector3(width, height, thickness), color, position)


# =============================================================================
# CYLINDER MESH
# =============================================================================

## Axis enum for cylinder orientation
enum CylinderAxis { Y, X, Z }

## Create a cylinder mesh
##
## Parameters:
##   radius: Cylinder radius
##   height: Cylinder height
##   color: Albedo color
##   position: World position (cylinder centered at this point)
##   axis: Which axis the cylinder is aligned to (default: Y - vertical)
##   segments: Number of radial segments (default: 16)
static func create_cylinder(
	radius: float,
	height: float,
	color: Color = Color.WHITE,
	position: Vector3 = Vector3.ZERO,
	axis: CylinderAxis = CylinderAxis.Y,
	segments: int = DEFAULT_SEGMENTS
) -> MeshInstance3D:
	# Validate inputs
	radius = maxf(radius, 0.01)
	height = maxf(height, 0.01)
	segments = clampi(segments, MIN_SEGMENTS, MAX_SEGMENTS)

	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = segments
	mesh.rings = 1

	var material := create_simple_pbr_material(color)
	mesh.material = material

	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.position = position

	# Rotate based on axis
	match axis:
		CylinderAxis.X:
			instance.rotation_degrees.z = 90.0
		CylinderAxis.Z:
			instance.rotation_degrees.x = 90.0
		# CylinderAxis.Y is default, no rotation needed

	DebugLogger.debug(SOURCE, "Created cylinder r=%.2f h=%.2f at %s" % [radius, height, position])
	return instance


## Create a tapered cylinder (cone-like)
static func create_tapered_cylinder(
	bottom_radius: float,
	top_radius: float,
	height: float,
	color: Color = Color.WHITE,
	position: Vector3 = Vector3.ZERO,
	segments: int = DEFAULT_SEGMENTS
) -> MeshInstance3D:
	bottom_radius = maxf(bottom_radius, 0.0)
	top_radius = maxf(top_radius, 0.0)
	height = maxf(height, 0.01)
	segments = clampi(segments, MIN_SEGMENTS, MAX_SEGMENTS)

	var mesh := CylinderMesh.new()
	mesh.top_radius = top_radius
	mesh.bottom_radius = bottom_radius
	mesh.height = height
	mesh.radial_segments = segments
	mesh.rings = 1

	var material := create_simple_pbr_material(color)
	mesh.material = material

	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.position = position

	DebugLogger.debug(SOURCE, "Created tapered cylinder r=%.2f/%.2f h=%.2f at %s" % [
		bottom_radius, top_radius, height, position
	])
	return instance


## Create a pillar (vertical cylinder with optional cap styling)
static func create_pillar(
	radius: float,
	height: float,
	color: Color = Color.WHITE,
	position: Vector3 = Vector3.ZERO,
	segments: int = DEFAULT_SEGMENTS
) -> MeshInstance3D:
	return create_cylinder(radius, height, color, position, CylinderAxis.Y, segments)


# =============================================================================
# SPHERE MESH
# =============================================================================

## Create a sphere mesh
static func create_sphere(
	radius: float,
	color: Color = Color.WHITE,
	position: Vector3 = Vector3.ZERO,
	segments: int = DEFAULT_SEGMENTS
) -> MeshInstance3D:
	radius = maxf(radius, 0.01)
	segments = clampi(segments, MIN_SEGMENTS, MAX_SEGMENTS)

	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = segments
	mesh.rings = segments / 2

	var material := create_simple_pbr_material(color)
	mesh.material = material

	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.position = position

	DebugLogger.debug(SOURCE, "Created sphere r=%.2f at %s" % [radius, position])
	return instance


# =============================================================================
# RING / TORUS MESH (using ArrayMesh for custom geometry)
# =============================================================================

## Create a flat ring (annulus) - useful for platforms, halos, etc.
## This creates a flat disc with a hole in the center
static func create_ring(
	inner_radius: float,
	outer_radius: float,
	color: Color = Color.WHITE,
	position: Vector3 = Vector3.ZERO,
	segments: int = DEFAULT_SEGMENTS * 2
) -> MeshInstance3D:
	# Validate inputs
	inner_radius = maxf(inner_radius, 0.0)
	outer_radius = maxf(outer_radius, inner_radius + 0.01)
	segments = clampi(segments, MIN_SEGMENTS, MAX_SEGMENTS)

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)

	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()

	# Generate ring vertices (two circles)
	for i in range(segments + 1):
		var angle := float(i) / segments * TAU
		var cos_a := cos(angle)
		var sin_a := sin(angle)
		var u := float(i) / segments

		# Inner vertex
		vertices.append(Vector3(cos_a * inner_radius, 0, sin_a * inner_radius))
		normals.append(Vector3.UP)
		uvs.append(Vector2(u, 0))

		# Outer vertex
		vertices.append(Vector3(cos_a * outer_radius, 0, sin_a * outer_radius))
		normals.append(Vector3.UP)
		uvs.append(Vector2(u, 1))

	# Generate indices (triangle strip as individual triangles)
	for i in range(segments):
		var base := i * 2
		# First triangle
		indices.append(base)
		indices.append(base + 1)
		indices.append(base + 2)
		# Second triangle
		indices.append(base + 1)
		indices.append(base + 3)
		indices.append(base + 2)

	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices

	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

	var material := create_simple_pbr_material(color)
	mesh.surface_set_material(0, material)

	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.position = position

	DebugLogger.debug(SOURCE, "Created ring inner=%.2f outer=%.2f at %s" % [
		inner_radius, outer_radius, position
	])
	return instance


## Create a simple rail/beam (elongated box)
static func create_rail(
	length: float,
	width: float = 0.05,
	height: float = 0.05,
	color: Color = Color.WHITE,
	position: Vector3 = Vector3.ZERO,
	axis: CylinderAxis = CylinderAxis.X
) -> MeshInstance3D:
	var size: Vector3
	match axis:
		CylinderAxis.X:
			size = Vector3(length, height, width)
		CylinderAxis.Y:
			size = Vector3(width, length, height)
		CylinderAxis.Z:
			size = Vector3(width, height, length)
		_:
			size = Vector3(length, height, width)

	var instance := create_box(size, color, position)
	DebugLogger.debug(SOURCE, "Created rail len=%.2f at %s" % [length, position])
	return instance


# =============================================================================
# MATERIAL HELPERS
# =============================================================================

## Create a simple unlit/emissive color material
## Good for: UI elements, holograms, hyperspace streaks, indicators
static func create_unlit_material(
	color: Color,
	emission_energy: float = 1.0
) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color

	if emission_energy > 0.0:
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = emission_energy

	return material


## Create a simple PBR material with albedo, metallic, roughness
## Good for: Most solid surfaces (floors, walls, platforms)
static func create_simple_pbr_material(
	color: Color,
	metallic: float = 0.0,
	roughness: float = 0.8
) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = clampf(metallic, 0.0, 1.0)
	material.roughness = clampf(roughness, 0.0, 1.0)
	return material


## Create an emissive PBR material (glowing surfaces)
## Good for: Accent lighting, glowing panels, energy effects
static func create_emissive_material(
	color: Color,
	emission_color: Color = Color(-1, -1, -1),  # Use Color(-1,-1,-1) as sentinel for "same as albedo"
	emission_energy: float = 1.0,
	metallic: float = 0.0,
	roughness: float = 0.5
) -> StandardMaterial3D:
	var material := create_simple_pbr_material(color, metallic, roughness)
	material.emission_enabled = true

	# Use albedo color for emission if no emission color specified
	if emission_color.r < 0:
		material.emission = color
	else:
		material.emission = emission_color

	material.emission_energy_multiplier = maxf(emission_energy, 0.0)
	return material


## Create a transparent/translucent material
## Good for: Water, glass, holograms, force fields
static func create_transparent_material(
	color: Color,
	alpha: float = 0.5,
	emission_energy: float = 0.0
) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(color.r, color.g, color.b, clampf(alpha, 0.0, 1.0))
	material.metallic = 0.0
	material.roughness = 0.2

	if emission_energy > 0.0:
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = emission_energy

	return material


## Create a holographic panel material
## Good for: Floating UI, holographic screens, data displays
static func create_hologram_material(
	color: Color = Color(0.3, 0.7, 1.0),
	alpha: float = 0.7,
	emission_energy: float = 0.5
) -> StandardMaterial3D:
	var material := create_transparent_material(color, alpha, emission_energy)
	material.cull_mode = BaseMaterial3D.CULL_DISABLED  # Visible from both sides
	return material


## Create a metallic material
## Good for: Metal surfaces, railings, weapons
static func create_metallic_material(
	color: Color,
	metallic: float = 0.9,
	roughness: float = 0.3
) -> StandardMaterial3D:
	return create_simple_pbr_material(color, metallic, roughness)


# =============================================================================
# COMPOSITE HELPERS
# =============================================================================

## Apply material to an existing MeshInstance3D
static func apply_material(instance: MeshInstance3D, material: Material) -> void:
	if instance == null:
		DebugLogger.warn(SOURCE, "Cannot apply material to null instance")
		return
	instance.material_override = material


## Create a glowing sphere (useful for indicators, orbs)
static func create_glowing_sphere(
	radius: float,
	color: Color,
	emission_energy: float = 1.5,
	position: Vector3 = Vector3.ZERO
) -> MeshInstance3D:
	var instance := create_sphere(radius, color, position)
	var material := create_emissive_material(color, Color(-1,-1,-1), emission_energy)
	instance.material_override = material
	return instance


## Create a holographic panel (flat rectangle, visible from both sides)
static func create_holographic_panel(
	width: float,
	height: float,
	color: Color = Color(0.3, 0.7, 1.0),
	position: Vector3 = Vector3.ZERO,
	alpha: float = 0.7
) -> MeshInstance3D:
	var instance := create_wall_plane(width, height, color, position)
	var material := create_hologram_material(color, alpha)
	instance.material_override = material

	DebugLogger.debug(SOURCE, "Created holographic panel %.1fx%.1f at %s" % [width, height, position])
	return instance


## Create a water-like plane (for ocean environment)
## Note: For animated water, use a custom shader - this creates static water look
static func create_water_plane(
	width: float,
	depth: float,
	water_color: Color = Color(0.1, 0.3, 0.5),
	position: Vector3 = Vector3.ZERO,
	alpha: float = 0.8
) -> MeshInstance3D:
	var instance := create_plane(width, depth, water_color, position)
	var material := create_transparent_material(water_color, alpha, 0.2)
	material.roughness = 0.1  # Shiny water
	material.metallic = 0.1
	instance.material_override = material

	DebugLogger.debug(SOURCE, "Created water plane %.1fx%.1f at %s" % [width, depth, position])
	return instance


## Create a star streak line (for hyperspace effect)
## Returns an elongated, emissive thin box
static func create_star_streak(
	length: float,
	thickness: float = 0.02,
	color: Color = Color(0.8, 0.9, 1.0),
	position: Vector3 = Vector3.ZERO,
	emission_energy: float = 2.0
) -> MeshInstance3D:
	var instance := create_box(
		Vector3(thickness, thickness, length),
		color,
		position
	)
	var material := create_unlit_material(color, emission_energy)
	instance.material_override = material

	DebugLogger.debug(SOURCE, "Created star streak len=%.2f at %s" % [length, position])
	return instance


# =============================================================================
# UTILITY FUNCTIONS
# =============================================================================

## Set the name of a mesh instance (for scene tree organization)
static func set_name(instance: MeshInstance3D, mesh_name: String) -> MeshInstance3D:
	if instance != null:
		instance.name = mesh_name
	return instance


## Create and name a mesh in one call
static func create_named_box(
	mesh_name: String,
	size: Vector3,
	color: Color = Color.WHITE,
	position: Vector3 = Vector3.ZERO
) -> MeshInstance3D:
	var instance := create_box(size, color, position)
	instance.name = mesh_name
	return instance


## Create and name a plane in one call
static func create_named_plane(
	mesh_name: String,
	width: float,
	depth: float,
	color: Color = Color.WHITE,
	position: Vector3 = Vector3.ZERO
) -> MeshInstance3D:
	var instance := create_plane(width, depth, color, position)
	instance.name = mesh_name
	return instance


## Create and name a cylinder in one call
static func create_named_cylinder(
	mesh_name: String,
	radius: float,
	height: float,
	color: Color = Color.WHITE,
	position: Vector3 = Vector3.ZERO
) -> MeshInstance3D:
	var instance := create_cylinder(radius, height, color, position)
	instance.name = mesh_name
	return instance

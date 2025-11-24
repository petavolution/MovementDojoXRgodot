## KungFuDojoEnvironment - Traditional martial arts training hall
## Rectangular wooden room with tatami floor, pillars, weapon rack, and holoscreens
##
## Layout:
##   - Room: 10m x 8m x 4m (width x depth x height)
##   - Tatami-style floor with grid pattern
##   - Wooden walls and ceiling beams
##   - Four corner pillars
##   - Weapon rack on back wall
##   - Holographic screens on side walls
extends BaseEnvironment
class_name KungFuDojoEnvironment

const ENV_SOURCE := "KungFuDojo"

# =============================================================================
# CONFIGURATION
# =============================================================================

## Room dimensions
@export var room_width := 10.0
@export var room_depth := 8.0
@export var room_height := 4.0
@export var wall_thickness := 0.25

## Pillar configuration
@export var pillar_radius := 0.2
@export var pillar_inset := 0.8  # Distance from walls

## Tatami configuration
@export var tatami_tile_width := 1.0
@export var tatami_tile_depth := 2.0
@export var tatami_border := 0.02

## Weapon rack configuration
@export var rack_width := 2.5
@export var rack_height := 1.8
@export var num_weapons := 4

## Holoscreen configuration
@export var holoscreen_width := 1.5
@export var holoscreen_height := 1.0
@export var holoscreen_color := Color(0.2, 0.7, 0.9)

# =============================================================================
# COLORS
# =============================================================================

const FLOOR_COLOR := Color(0.6, 0.5, 0.35)  # Tatami beige
const FLOOR_BORDER_COLOR := Color(0.15, 0.12, 0.08)  # Dark border
const WALL_COLOR := Color(0.45, 0.35, 0.25)  # Wood brown
const WALL_ACCENT_COLOR := Color(0.35, 0.28, 0.2)  # Darker wood
const CEILING_COLOR := Color(0.4, 0.32, 0.22)  # Dark wood
const PILLAR_COLOR := Color(0.5, 0.38, 0.28)  # Polished wood
const BEAM_COLOR := Color(0.42, 0.32, 0.22)  # Ceiling beams
const RACK_COLOR := Color(0.3, 0.22, 0.15)  # Dark wood rack
const WEAPON_METAL_COLOR := Color(0.7, 0.7, 0.72)  # Steel
const WEAPON_WOOD_COLOR := Color(0.4, 0.28, 0.18)  # Staff wood

# =============================================================================
# IMPLEMENTATION
# =============================================================================

func get_environment_name() -> String:
	return "KungFuDojo"


func _build_environment() -> void:
	_build_lighting()
	_build_floor()
	_build_walls()
	_build_ceiling()
	_build_pillars()
	_build_ceiling_beams()
	_build_weapon_rack()
	_build_holoscreens()

	DebugLogger.info(ENV_SOURCE, "Room: %.1fm x %.1fm x %.1fm" % [room_width, room_depth, room_height])
	DebugLogger.info(ENV_SOURCE, "Features: 4 pillars, weapon rack (%d weapons), 2 holoscreens" % num_weapons)


func _build_lighting() -> void:
	# Warm ambient environment
	_create_world_environment(
		Color(0.1, 0.08, 0.05),  # Dark brown background
		Color(0.9, 0.8, 0.6),    # Warm ambient
		0.3
	)

	# Main overhead light
	var main_light := DirectionalLight3D.new()
	main_light.name = "MainLight"
	main_light.light_color = Color(1.0, 0.95, 0.85)
	main_light.light_energy = 0.8
	main_light.shadow_enabled = true
	main_light.look_at_from_position(Vector3(0, room_height, 0), Vector3(0, 0, 0), Vector3.FORWARD)
	_add_geometry(main_light)

	# Accent lights in corners
	var corner_positions := [
		Vector3(-room_width/2 + 1.5, room_height - 0.5, -room_depth/2 + 1.5),
		Vector3(room_width/2 - 1.5, room_height - 0.5, -room_depth/2 + 1.5),
		Vector3(-room_width/2 + 1.5, room_height - 0.5, room_depth/2 - 1.5),
		Vector3(room_width/2 - 1.5, room_height - 0.5, room_depth/2 - 1.5),
	]

	for i in range(corner_positions.size()):
		var light := OmniLight3D.new()
		light.name = "CornerLight%d" % i
		light.position = corner_positions[i]
		light.light_color = Color(1.0, 0.85, 0.6)  # Warm lantern
		light.light_energy = 0.4
		light.omni_range = 4.0
		light.omni_attenuation = 1.2
		_add_geometry(light)


func _build_floor() -> void:
	# Base floor
	var floor_base := ProceduralMeshes.create_plane(
		room_width,
		room_depth,
		FLOOR_BORDER_COLOR,
		Vector3.ZERO
	)
	floor_base.name = "FloorBase"
	_add_geometry(floor_base)

	# Tatami tiles grid
	var tiles_x := int(room_width / tatami_tile_width)
	var tiles_z := int(room_depth / tatami_tile_depth)
	var start_x := -room_width / 2.0 + tatami_tile_width / 2.0
	var start_z := -room_depth / 2.0 + tatami_tile_depth / 2.0

	var tile_count := 0
	for x in range(tiles_x):
		for z in range(tiles_z):
			var pos := Vector3(
				start_x + x * tatami_tile_width,
				0.005,  # Slightly above base
				start_z + z * tatami_tile_depth
			)

			# Alternate tatami colors slightly for visual interest
			var tile_color := FLOOR_COLOR
			if (x + z) % 2 == 0:
				tile_color = tile_color.darkened(0.05)

			var tile := ProceduralMeshes.create_plane(
				tatami_tile_width - tatami_border * 2,
				tatami_tile_depth - tatami_border * 2,
				tile_color,
				pos
			)
			tile.name = "Tatami%d" % tile_count
			_add_geometry(tile)
			tile_count += 1

	DebugLogger.debug(ENV_SOURCE, "Created %d tatami tiles" % tile_count)


func _build_walls() -> void:
	var half_w := room_width / 2.0
	var half_d := room_depth / 2.0
	var wall_y := room_height / 2.0

	# Back wall (weapon rack goes here)
	var back_wall := ProceduralMeshes.create_box(
		Vector3(room_width, room_height, wall_thickness),
		WALL_COLOR,
		Vector3(0, wall_y, -half_d - wall_thickness/2)
	)
	back_wall.name = "BackWall"
	_add_geometry(back_wall)

	# Front wall
	var front_wall := ProceduralMeshes.create_box(
		Vector3(room_width, room_height, wall_thickness),
		WALL_COLOR,
		Vector3(0, wall_y, half_d + wall_thickness/2)
	)
	front_wall.name = "FrontWall"
	_add_geometry(front_wall)

	# Left wall (holoscreen here)
	var left_wall := ProceduralMeshes.create_box(
		Vector3(wall_thickness, room_height, room_depth),
		WALL_COLOR,
		Vector3(-half_w - wall_thickness/2, wall_y, 0)
	)
	left_wall.name = "LeftWall"
	_add_geometry(left_wall)

	# Right wall (holoscreen here)
	var right_wall := ProceduralMeshes.create_box(
		Vector3(wall_thickness, room_height, room_depth),
		WALL_COLOR,
		Vector3(half_w + wall_thickness/2, wall_y, 0)
	)
	right_wall.name = "RightWall"
	_add_geometry(right_wall)

	# Decorative wall panels (wainscoting)
	_create_wall_panels()


func _create_wall_panels() -> void:
	var panel_height := 1.2
	var panel_y := panel_height / 2.0
	var half_w := room_width / 2.0
	var half_d := room_depth / 2.0

	# Back panel
	var back_panel := ProceduralMeshes.create_box(
		Vector3(room_width - 0.1, panel_height, 0.05),
		WALL_ACCENT_COLOR,
		Vector3(0, panel_y, -half_d + 0.03)
	)
	back_panel.name = "BackPanel"
	_add_geometry(back_panel)

	# Side panels
	var left_panel := ProceduralMeshes.create_box(
		Vector3(0.05, panel_height, room_depth - 0.1),
		WALL_ACCENT_COLOR,
		Vector3(-half_w + 0.03, panel_y, 0)
	)
	left_panel.name = "LeftPanel"
	_add_geometry(left_panel)

	var right_panel := ProceduralMeshes.create_box(
		Vector3(0.05, panel_height, room_depth - 0.1),
		WALL_ACCENT_COLOR,
		Vector3(half_w - 0.03, panel_y, 0)
	)
	right_panel.name = "RightPanel"
	_add_geometry(right_panel)


func _build_ceiling() -> void:
	var ceiling := ProceduralMeshes.create_plane(
		room_width,
		room_depth,
		CEILING_COLOR,
		Vector3(0, room_height, 0),
		false  # facing down
	)
	ceiling.name = "Ceiling"
	_add_geometry(ceiling)


func _build_pillars() -> void:
	var half_w := room_width / 2.0 - pillar_inset
	var half_d := room_depth / 2.0 - pillar_inset
	var pillar_y := room_height / 2.0

	var pillar_positions := [
		Vector3(-half_w, pillar_y, -half_d),
		Vector3(half_w, pillar_y, -half_d),
		Vector3(-half_w, pillar_y, half_d),
		Vector3(half_w, pillar_y, half_d),
	]

	var pillar_mat := ProceduralMeshes.create_simple_pbr_material(PILLAR_COLOR, 0.2, 0.6)

	for i in range(pillar_positions.size()):
		var pillar := ProceduralMeshes.create_cylinder(
			pillar_radius,
			room_height,
			PILLAR_COLOR,
			pillar_positions[i]
		)
		pillar.name = "Pillar%d" % i
		pillar.material_override = pillar_mat
		_add_geometry(pillar)

	DebugLogger.debug(ENV_SOURCE, "Created 4 pillars")


func _build_ceiling_beams() -> void:
	var beam_width := 0.15
	var beam_height := 0.2
	var beam_y := room_height - beam_height / 2.0

	# Cross beams
	var beam1 := ProceduralMeshes.create_box(
		Vector3(room_width, beam_height, beam_width),
		BEAM_COLOR,
		Vector3(0, beam_y, -room_depth / 4.0)
	)
	beam1.name = "Beam1"
	_add_geometry(beam1)

	var beam2 := ProceduralMeshes.create_box(
		Vector3(room_width, beam_height, beam_width),
		BEAM_COLOR,
		Vector3(0, beam_y, room_depth / 4.0)
	)
	beam2.name = "Beam2"
	_add_geometry(beam2)

	var beam3 := ProceduralMeshes.create_box(
		Vector3(beam_width, beam_height, room_depth),
		BEAM_COLOR,
		Vector3(-room_width / 4.0, beam_y, 0)
	)
	beam3.name = "Beam3"
	_add_geometry(beam3)

	var beam4 := ProceduralMeshes.create_box(
		Vector3(beam_width, beam_height, room_depth),
		BEAM_COLOR,
		Vector3(room_width / 4.0, beam_y, 0)
	)
	beam4.name = "Beam4"
	_add_geometry(beam4)


func _build_weapon_rack() -> void:
	var half_d := room_depth / 2.0
	var rack_z := -half_d + 0.3
	var rack_y := rack_height / 2.0 + 0.8

	# Rack frame - vertical posts
	var post_spacing := rack_width - 0.1
	for i in range(2):
		var x := -post_spacing/2 + i * post_spacing
		var post := ProceduralMeshes.create_box(
			Vector3(0.08, rack_height, 0.08),
			RACK_COLOR,
			Vector3(x, rack_y, rack_z)
		)
		post.name = "RackPost%d" % i
		_add_geometry(post)

	# Horizontal bars
	var bar_positions := [0.3, 0.6, 1.0, 1.4]
	for i in range(bar_positions.size()):
		var bar := ProceduralMeshes.create_box(
			Vector3(rack_width, 0.04, 0.06),
			RACK_COLOR,
			Vector3(0, bar_positions[i] + 0.8, rack_z + 0.03)
		)
		bar.name = "RackBar%d" % i
		_add_geometry(bar)

	# Weapons
	_create_weapons(rack_z)

	DebugLogger.debug(ENV_SOURCE, "Created weapon rack")


func _create_weapons(rack_z: float) -> void:
	var spacing := rack_width / (num_weapons + 1)

	for i in range(num_weapons):
		var x := -rack_width/2 + spacing * (i + 1)

		if i % 2 == 0:
			# Sword (blade + handle)
			_create_sword(Vector3(x, 1.3, rack_z + 0.15), i)
		else:
			# Staff
			_create_staff(Vector3(x, 1.3, rack_z + 0.15), i)


func _create_sword(pos: Vector3, index: int) -> void:
	# Blade
	var blade := ProceduralMeshes.create_box(
		Vector3(0.04, 0.8, 0.01),
		WEAPON_METAL_COLOR,
		pos
	)
	blade.name = "SwordBlade%d" % index
	blade.material_override = ProceduralMeshes.create_metallic_material(WEAPON_METAL_COLOR, 0.95, 0.2)
	_add_geometry(blade)

	# Handle
	var handle := ProceduralMeshes.create_box(
		Vector3(0.03, 0.2, 0.03),
		WEAPON_WOOD_COLOR,
		Vector3(pos.x, pos.y - 0.5, pos.z)
	)
	handle.name = "SwordHandle%d" % index
	_add_geometry(handle)


func _create_staff(pos: Vector3, index: int) -> void:
	var staff := ProceduralMeshes.create_cylinder(
		0.02,
		1.6,
		WEAPON_WOOD_COLOR,
		Vector3(pos.x, pos.y, pos.z),
		ProceduralMeshes.CylinderAxis.Y,
		8
	)
	staff.name = "Staff%d" % index
	_add_geometry(staff)


func _build_holoscreens() -> void:
	var half_w := room_width / 2.0
	var screen_y := 2.0

	# Left wall screen
	var left_screen := ProceduralMeshes.create_holographic_panel(
		holoscreen_height,  # Rotated, so swap
		holoscreen_width,
		holoscreen_color,
		Vector3(-half_w + 0.15, screen_y, 0),
		0.6
	)
	left_screen.name = "HoloScreenLeft"
	left_screen.rotation_degrees.y = 90
	_add_geometry(left_screen)

	# Right wall screen
	var right_screen := ProceduralMeshes.create_holographic_panel(
		holoscreen_height,
		holoscreen_width,
		holoscreen_color,
		Vector3(half_w - 0.15, screen_y, 0),
		0.6
	)
	right_screen.name = "HoloScreenRight"
	right_screen.rotation_degrees.y = -90
	_add_geometry(right_screen)

	DebugLogger.debug(ENV_SOURCE, "Created 2 holoscreens")

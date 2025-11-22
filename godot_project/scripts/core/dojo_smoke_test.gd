## DojoSmokeTest - Minimal VR scene to verify XR setup works
## Run with: godot --vr-smoke-test
## Tests: XR rendering, controller tracking, basic input bindings
## Spawns: floor, walls, debug saber (right), debug blaster (left), dummy drone
extends Node3D
class_name DojoSmokeTest

const SOURCE := "SmokeTest"

# XR Nodes
var xr_origin: XROrigin3D
var xr_camera: XRCamera3D
var left_controller: XRController3D
var right_controller: XRController3D

# XR State
var xr_interface: XRInterface
var xr_initialized := false

# Debug meshes (created procedurally)
var debug_saber: MeshInstance3D
var debug_blaster: MeshInstance3D
var dummy_drone: MeshInstance3D

# Status logging
var _status_log_timer: float = 0.0
const STATUS_LOG_INTERVAL := 1.0  # Log every second

# Saber activation state
var _saber_active := false


func _ready() -> void:
	DebugLogger.info(SOURCE, "=== ENTERING VR DOJO SMOKE TEST MODE ===")
	DebugLogger.info(SOURCE, "Testing: XR rendering, controller tracking, input bindings")
	DebugLogger.info(SOURCE, "")

	# Setup XR
	_setup_xr()

	if not xr_initialized:
		DebugLogger.error(SOURCE, "XR initialization failed - smoke test cannot continue")
		return

	# Build scene
	_build_dojo_environment()
	_setup_debug_weapons()
	_spawn_dummy_drone()

	# Connect input signals
	_connect_input_signals()

	DebugLogger.info(SOURCE, "")
	DebugLogger.info(SOURCE, "Smoke test scene ready. Move controllers to verify tracking.")
	DebugLogger.info(SOURCE, "Right trigger = activate saber, Left trigger = blaster fire (visual only)")


func _setup_xr() -> void:
	DebugLogger.info(SOURCE, "Setting up XR...")

	# Create XR scene structure
	xr_origin = XROrigin3D.new()
	xr_origin.name = "XROrigin3D"
	add_child(xr_origin)

	xr_camera = XRCamera3D.new()
	xr_camera.name = "XRCamera3D"
	xr_origin.add_child(xr_camera)

	left_controller = XRController3D.new()
	left_controller.name = "LeftController"
	left_controller.tracker = "left_hand"
	xr_origin.add_child(left_controller)

	right_controller = XRController3D.new()
	right_controller.name = "RightController"
	right_controller.tracker = "right_hand"
	xr_origin.add_child(right_controller)

	# Initialize OpenXR
	xr_interface = XRServer.find_interface("OpenXR")
	if xr_interface == null:
		DebugLogger.error(SOURCE, "OpenXR interface not found")
		return

	get_viewport().use_xr = true

	if not xr_interface.is_initialized():
		if not xr_interface.initialize():
			DebugLogger.error(SOURCE, "Failed to initialize OpenXR")
			return

	xr_initialized = true

	# Sync physics to display
	var refresh_rate := xr_interface.get_display_refresh_rate()
	if refresh_rate > 0:
		Engine.physics_ticks_per_second = int(refresh_rate)
	else:
		Engine.physics_ticks_per_second = 90

	DebugLogger.info(SOURCE, "XR initialized at %.0f Hz" % Engine.physics_ticks_per_second)


func _build_dojo_environment() -> void:
	DebugLogger.info(SOURCE, "Building dojo environment...")

	# Floor (dark gray)
	var floor_mesh := PlaneMesh.new()
	floor_mesh.size = Vector2(10.0, 10.0)

	var floor_mat := StandardMaterial3D.new()
	floor_mat.albedo_color = Color(0.15, 0.15, 0.18)
	floor_mat.roughness = 0.8

	var floor := MeshInstance3D.new()
	floor.name = "Floor"
	floor.mesh = floor_mesh
	floor.material_override = floor_mat
	add_child(floor)

	# Walls / pillars (4 corner pillars)
	var pillar_positions := [
		Vector3(-4.0, 1.5, -4.0),
		Vector3(4.0, 1.5, -4.0),
		Vector3(-4.0, 1.5, 4.0),
		Vector3(4.0, 1.5, 4.0),
	]

	var pillar_mesh := BoxMesh.new()
	pillar_mesh.size = Vector3(0.5, 3.0, 0.5)

	var pillar_mat := StandardMaterial3D.new()
	pillar_mat.albedo_color = Color(0.3, 0.25, 0.2)
	pillar_mat.roughness = 0.7

	for i in range(pillar_positions.size()):
		var pillar := MeshInstance3D.new()
		pillar.name = "Pillar%d" % i
		pillar.mesh = pillar_mesh
		pillar.material_override = pillar_mat
		pillar.position = pillar_positions[i]
		add_child(pillar)

	# Back wall (visual reference for depth)
	var wall_mesh := BoxMesh.new()
	wall_mesh.size = Vector3(10.0, 4.0, 0.2)

	var wall_mat := StandardMaterial3D.new()
	wall_mat.albedo_color = Color(0.2, 0.2, 0.25)
	wall_mat.roughness = 0.9

	var back_wall := MeshInstance3D.new()
	back_wall.name = "BackWall"
	back_wall.mesh = wall_mesh
	back_wall.material_override = wall_mat
	back_wall.position = Vector3(0, 2.0, -5.0)
	add_child(back_wall)

	# Ambient light
	var light := DirectionalLight3D.new()
	light.name = "MainLight"
	light.light_energy = 0.8
	light.shadow_enabled = true
	light.rotation_degrees = Vector3(-45, 30, 0)
	add_child(light)

	# Environment (simple sky color)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.05, 0.05, 0.1)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.2, 0.2, 0.3)
	env.ambient_light_energy = 0.5

	var world_env := WorldEnvironment.new()
	world_env.name = "WorldEnvironment"
	world_env.environment = env
	add_child(world_env)

	DebugLogger.debug(SOURCE, "Dojo environment built: floor, 4 pillars, back wall")


func _setup_debug_weapons() -> void:
	DebugLogger.info(SOURCE, "Setting up debug weapons...")

	# Right hand: Debug Saber (cyan cylinder)
	var saber_mesh := CylinderMesh.new()
	saber_mesh.top_radius = 0.015
	saber_mesh.bottom_radius = 0.02
	saber_mesh.height = 1.0

	var saber_mat := StandardMaterial3D.new()
	saber_mat.albedo_color = Color(0.2, 0.8, 1.0)  # Cyan
	saber_mat.emission_enabled = true
	saber_mat.emission = Color(0.2, 0.8, 1.0)
	saber_mat.emission_energy_multiplier = 0.5

	debug_saber = MeshInstance3D.new()
	debug_saber.name = "DebugSaber"
	debug_saber.mesh = saber_mesh
	debug_saber.material_override = saber_mat
	# Offset so base is at controller position, blade extends forward
	debug_saber.position = Vector3(0, 0, -0.5)
	debug_saber.rotation_degrees = Vector3(90, 0, 0)  # Point forward
	debug_saber.visible = false  # Start deactivated
	right_controller.add_child(debug_saber)

	# Saber hilt (always visible)
	var hilt_mesh := CylinderMesh.new()
	hilt_mesh.top_radius = 0.02
	hilt_mesh.bottom_radius = 0.025
	hilt_mesh.height = 0.15

	var hilt_mat := StandardMaterial3D.new()
	hilt_mat.albedo_color = Color(0.3, 0.3, 0.35)
	hilt_mat.metallic = 0.8
	hilt_mat.roughness = 0.3

	var hilt := MeshInstance3D.new()
	hilt.name = "SaberHilt"
	hilt.mesh = hilt_mesh
	hilt.material_override = hilt_mat
	hilt.rotation_degrees = Vector3(90, 0, 0)
	right_controller.add_child(hilt)

	DebugLogger.debug(SOURCE, "Right hand: saber hilt + blade (trigger to activate)")

	# Left hand: Debug Blaster (dark box)
	var blaster_body := BoxMesh.new()
	blaster_body.size = Vector3(0.05, 0.08, 0.15)

	var blaster_mat := StandardMaterial3D.new()
	blaster_mat.albedo_color = Color(0.2, 0.2, 0.2)
	blaster_mat.metallic = 0.6
	blaster_mat.roughness = 0.4

	debug_blaster = MeshInstance3D.new()
	debug_blaster.name = "DebugBlaster"
	debug_blaster.mesh = blaster_body
	debug_blaster.material_override = blaster_mat
	debug_blaster.position = Vector3(0, 0, -0.08)
	left_controller.add_child(debug_blaster)

	# Blaster barrel
	var barrel_mesh := CylinderMesh.new()
	barrel_mesh.top_radius = 0.01
	barrel_mesh.bottom_radius = 0.012
	barrel_mesh.height = 0.1

	var barrel_mat := StandardMaterial3D.new()
	barrel_mat.albedo_color = Color(0.15, 0.15, 0.15)
	barrel_mat.metallic = 0.9

	var barrel := MeshInstance3D.new()
	barrel.name = "BlasterBarrel"
	barrel.mesh = barrel_mesh
	barrel.material_override = barrel_mat
	barrel.position = Vector3(0, 0, -0.12)
	barrel.rotation_degrees = Vector3(90, 0, 0)
	debug_blaster.add_child(barrel)

	DebugLogger.debug(SOURCE, "Left hand: blaster body + barrel")


func _spawn_dummy_drone() -> void:
	DebugLogger.info(SOURCE, "Spawning dummy drone...")

	# Hovering sphere (red) as drone placeholder
	var drone_mesh := SphereMesh.new()
	drone_mesh.radius = 0.2
	drone_mesh.height = 0.4

	var drone_mat := StandardMaterial3D.new()
	drone_mat.albedo_color = Color(0.8, 0.2, 0.2)  # Red
	drone_mat.emission_enabled = true
	drone_mat.emission = Color(0.8, 0.2, 0.2)
	drone_mat.emission_energy_multiplier = 0.3

	dummy_drone = MeshInstance3D.new()
	dummy_drone.name = "DummyDrone"
	dummy_drone.mesh = drone_mesh
	dummy_drone.material_override = drone_mat
	dummy_drone.position = Vector3(0, 1.8, -2.5)  # In front, at head height
	add_child(dummy_drone)

	# Add "eye" indicator
	var eye_mesh := SphereMesh.new()
	eye_mesh.radius = 0.05
	eye_mesh.height = 0.1

	var eye_mat := StandardMaterial3D.new()
	eye_mat.albedo_color = Color(1.0, 0.5, 0.0)  # Orange
	eye_mat.emission_enabled = true
	eye_mat.emission = Color(1.0, 0.5, 0.0)
	eye_mat.emission_energy_multiplier = 1.0

	var eye := MeshInstance3D.new()
	eye.name = "DroneEye"
	eye.mesh = eye_mesh
	eye.material_override = eye_mat
	eye.position = Vector3(0, 0, -0.18)
	dummy_drone.add_child(eye)

	DebugLogger.debug(SOURCE, "Dummy drone spawned at (0, 1.8, -2.5)")


func _connect_input_signals() -> void:
	# Connect controller signals for input testing
	if right_controller:
		right_controller.input_float_changed.connect(_on_right_float_changed)
		right_controller.button_pressed.connect(_on_right_button_pressed)

	if left_controller:
		left_controller.input_float_changed.connect(_on_left_float_changed)
		left_controller.button_pressed.connect(_on_left_button_pressed)


func _process(delta: float) -> void:
	if not xr_initialized:
		return

	# Periodic status logging
	_status_log_timer += delta
	if _status_log_timer >= STATUS_LOG_INTERVAL:
		_status_log_timer = 0.0
		_log_tracking_status()

	# Gentle drone hover animation
	if dummy_drone:
		dummy_drone.position.y = 1.8 + sin(Time.get_ticks_msec() * 0.002) * 0.1


func _log_tracking_status() -> void:
	var hmd_valid := xr_camera != null and xr_interface.is_initialized()
	var left_valid := left_controller != null and left_controller.get_is_active() and left_controller.get_has_tracking_data()
	var right_valid := right_controller != null and right_controller.get_is_active() and right_controller.get_has_tracking_data()

	DebugLogger.debug(SOURCE, "Tracking: HMD=%s Left=%s Right=%s" % [
		"OK" if hmd_valid else "NO",
		"OK" if left_valid else "NO",
		"OK" if right_valid else "NO"
	])

	# Log controller positions if tracked
	if left_valid:
		var pos := left_controller.global_position
		DebugLogger.trace(SOURCE, "Left pos: (%.2f, %.2f, %.2f)" % [pos.x, pos.y, pos.z])
	if right_valid:
		var pos := right_controller.global_position
		DebugLogger.trace(SOURCE, "Right pos: (%.2f, %.2f, %.2f)" % [pos.x, pos.y, pos.z])


# =============================================================================
# INPUT HANDLERS
# =============================================================================

func _on_right_float_changed(action_name: String, value: float) -> void:
	if action_name == "trigger":
		if value >= 0.7 and not _saber_active:
			_saber_active = true
			debug_saber.visible = true
			DebugLogger.info(SOURCE, "SABER ACTIVATED")
		elif value < 0.3 and _saber_active:
			_saber_active = false
			debug_saber.visible = false
			DebugLogger.info(SOURCE, "Saber deactivated")


func _on_left_float_changed(action_name: String, value: float) -> void:
	if action_name == "trigger" and value >= 0.7:
		# Flash blaster barrel
		DebugLogger.debug(SOURCE, "BLASTER FIRE (visual only)")
		_flash_blaster()


func _on_right_button_pressed(button: String) -> void:
	DebugLogger.debug(SOURCE, "Right button: %s" % button)


func _on_left_button_pressed(button: String) -> void:
	DebugLogger.debug(SOURCE, "Left button: %s" % button)


func _flash_blaster() -> void:
	# Quick flash effect on blaster
	if debug_blaster:
		var mat := debug_blaster.material_override as StandardMaterial3D
		if mat:
			mat.emission_enabled = true
			mat.emission = Color(1.0, 0.5, 0.0)
			mat.emission_energy_multiplier = 2.0
			# Reset after short delay
			await get_tree().create_timer(0.1).timeout
			mat.emission_enabled = false


# =============================================================================
# STATIC HELPERS
# =============================================================================

## Check if --vr-smoke-test flag is present
static func has_smoke_test_flag() -> bool:
	var args := OS.get_cmdline_args()
	return "--vr-smoke-test" in args or "-vr-smoke-test" in args

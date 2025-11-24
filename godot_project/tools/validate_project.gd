## ProjectValidator - CLI tool for validating project structure and configuration
## Run with: godot --headless --script tools/validate_project.gd
extends SceneTree

const EXIT_SUCCESS := 0
const EXIT_FAILURE := 1

var errors: Array[String] = []
var warnings: Array[String] = []
var checks_passed := 0
var checks_total := 0


func _init() -> void:
	print("\n" + "=".repeat(60))
	print("Movement Dojo XR - Project Validator")
	print("=".repeat(60) + "\n")

	# Run all validation checks
	_validate_autoloads()
	_validate_core_scripts()
	_validate_scene_structure()
	_validate_resources()
	_validate_dependencies()

	# Print results
	_print_results()

	# Exit with appropriate code
	var exit_code := EXIT_SUCCESS if errors.is_empty() else EXIT_FAILURE
	quit(exit_code)


func _check(condition: bool, name: String, error_msg: String = "", is_warning: bool = false) -> bool:
	checks_total += 1
	if condition:
		checks_passed += 1
		print("  [OK] %s" % name)
		return true
	else:
		if is_warning:
			warnings.append(error_msg if error_msg else name)
			print("  [WARN] %s" % name)
		else:
			errors.append(error_msg if error_msg else name)
			print("  [FAIL] %s" % name)
		return false


func _validate_autoloads() -> void:
	print("[SECTION] Autoload Configuration")

	# Required autoloads in correct order
	var required_autoloads := [
		"DebugLogger",
		"GameEvents",
		"XRInputManager",
		"MovementTracker",
		"SessionManager"
	]

	for autoload_name in required_autoloads:
		var node := get_root().get_node_or_null("/root/%s" % autoload_name)
		_check(node != null, "Autoload: %s" % autoload_name,
			"Missing autoload: %s - check project.godot" % autoload_name)

	print("")


func _validate_core_scripts() -> void:
	print("[SECTION] Core Scripts")

	var core_scripts := [
		"res://scripts/core/debug_logger.gd",
		"res://scripts/core/game_events.gd",
		"res://scripts/core/xr_input_manager.gd",
		"res://scripts/core/movement_tracker.gd",
		"res://scripts/core/session_manager.gd",
		"res://scripts/core/systems_manager.gd",
		"res://scripts/core/movement_frame.gd",
		"res://scripts/core/movement_space_map.gd",
		"res://scripts/core/haptic_patterns.gd",
		"res://scripts/main_vr.gd"
	]

	for script_path in core_scripts:
		var exists := ResourceLoader.exists(script_path)
		var short_name := script_path.get_file()
		_check(exists, "Script: %s" % short_name,
			"Missing script: %s" % script_path)

	print("")


func _validate_scene_structure() -> void:
	print("[SECTION] Scene Structure")

	# Check main scene exists
	var main_scene_path := "res://scenes/main_vr.tscn"
	_check(ResourceLoader.exists(main_scene_path), "Main scene exists",
		"Missing main scene: %s" % main_scene_path)

	# Load and validate main scene structure
	if ResourceLoader.exists(main_scene_path):
		var scene := load(main_scene_path) as PackedScene
		if scene:
			var instance := scene.instantiate()
			if instance:
				# Check required nodes
				var required_nodes := [
					"XROrigin3D",
					"XROrigin3D/XRCamera3D",
					"XROrigin3D/LeftController",
					"XROrigin3D/RightController"
				]

				for node_path in required_nodes:
					var node := instance.get_node_or_null(node_path)
					var short_name := node_path.get_file()
					_check(node != null, "Node: %s" % short_name,
						"Missing scene node: %s" % node_path)

				# Check optional nodes (warnings only)
				var optional_nodes := [
					"DojoEnvironment",
					"TargetSpawner",
					"MovementTrail",
					"MovementHeatMap",
					"MovementHUD"
				]

				for node_path in optional_nodes:
					var node := instance.get_node_or_null(node_path)
					_check(node != null, "Optional: %s" % node_path,
						"Optional node missing: %s" % node_path, true)

				instance.queue_free()

	print("")


func _validate_resources() -> void:
	print("[SECTION] Resources")

	var required_resources := [
		"res://resources/openxr_action_map.tres"
	]

	for res_path in required_resources:
		var exists := ResourceLoader.exists(res_path)
		var short_name := res_path.get_file()
		_check(exists, "Resource: %s" % short_name,
			"Missing resource: %s" % res_path)

	print("")


func _validate_dependencies() -> void:
	print("[SECTION] Script Dependencies")

	# Test that core classes can be instantiated
	var frame := MovementFrame.new()
	_check(frame != null, "MovementFrame instantiation")

	var space_map := MovementSpaceMap.new()
	_check(space_map != null, "MovementSpaceMap instantiation")

	# Test SystemsManager script paths
	var systems_scripts := [
		"res://scripts/analytics/movement_analytics.gd",
		"res://scripts/core/audio_manager.gd",
		"res://scripts/core/score_manager.gd",
		"res://scripts/core/adaptive_difficulty.gd",
		"res://scripts/core/replay_system.gd",
		"res://scripts/core/calibration_system.gd",
		"res://scripts/core/achievement_system.gd"
	]

	for script_path in systems_scripts:
		var exists := ResourceLoader.exists(script_path)
		var short_name := script_path.get_file()
		_check(exists, "Lazy-load: %s" % short_name,
			"Missing lazy-load script: %s" % script_path, true)

	print("")


func _print_results() -> void:
	print("=".repeat(60))
	print("VALIDATION RESULTS")
	print("=".repeat(60))
	print("")
	print("Checks: %d/%d passed" % [checks_passed, checks_total])

	if not warnings.is_empty():
		print("\nWarnings (%d):" % warnings.size())
		for warning in warnings:
			print("  - %s" % warning)

	if not errors.is_empty():
		print("\nErrors (%d):" % errors.size())
		for error in errors:
			print("  - %s" % error)
		print("\nProject has errors that must be fixed!")
	else:
		print("\nProject validation PASSED!")

	print("")

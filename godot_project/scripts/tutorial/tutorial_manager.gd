## TutorialManager - Interactive VR onboarding and tutorial system
## Guides new players through controls and mechanics
class_name TutorialManager
extends Node

signal tutorial_started(tutorial_id: String)
signal tutorial_completed(tutorial_id: String)
signal tutorial_skipped(tutorial_id: String)
signal step_started(step: TutorialStep)
signal step_completed(step: TutorialStep)
signal hint_shown(hint: String)

## Tutorial step definition
class TutorialStep:
	var id: String = ""
	var title: String = ""
	var instruction: String = ""
	var hint: String = ""
	var completion_condition: String = ""  # Signal or method name
	var timeout: float = 0.0  # 0 = no timeout
	var highlight_target: String = ""  # Node path to highlight
	var demo_animation: String = ""  # Animation to play
	var required_action: String = ""  # Input action required
	var voice_clip: String = ""  # Audio narration

	func _init(step_id: String = "") -> void:
		id = step_id


## Complete tutorial definition
class Tutorial:
	var id: String = ""
	var name: String = ""
	var description: String = ""
	var steps: Array[TutorialStep] = []
	var prerequisite: String = ""  # Required tutorial to complete first
	var can_skip: bool = true
	var reward_achievement: String = ""


## Tutorial state
var tutorials: Dictionary = {}
var completed_tutorials: Array[String] = []
var current_tutorial: Tutorial
var current_step_index: int = 0
var is_active: bool = false

## UI
var tutorial_panel: Node3D
var highlight_effect: Node3D

## References
var xr_camera: XRCamera3D
var input_manager: XRInputManager

## Timing
var step_timer: float = 0.0
var hint_delay: float = 10.0
var hint_shown_for_step: bool = false


func _ready() -> void:
	_setup_tutorials()
	_create_ui()


func _process(delta: float) -> void:
	if not is_active:
		return

	step_timer += delta

	# Show hint after delay
	if not hint_shown_for_step and step_timer >= hint_delay:
		_show_hint()

	# Check timeout
	var current_step := _get_current_step()
	if current_step and current_step.timeout > 0 and step_timer >= current_step.timeout:
		_advance_step()


func setup(camera: XRCamera3D, input: XRInputManager) -> void:
	xr_camera = camera
	input_manager = input

	# Connect to input events for completion detection
	if input_manager:
		input_manager.trigger_pressed.connect(_on_trigger_pressed)
		input_manager.grip_pressed.connect(_on_grip_pressed)
		input_manager.gesture_detected.connect(_on_gesture_detected)


func _setup_tutorials() -> void:
	# First Time Setup tutorial
	var setup := Tutorial.new()
	setup.id = "first_time"
	setup.name = "Welcome to Movement Dojo"
	setup.description = "Learn the basics of VR and the Movement Dojo"
	setup.can_skip = false

	var step1 := TutorialStep.new("look_around")
	step1.title = "Look Around"
	step1.instruction = "Turn your head to look around the dojo.\nExplore your surroundings!"
	step1.hint = "Move your head slowly in all directions"
	step1.timeout = 15.0
	setup.steps.append(step1)

	var step2 := TutorialStep.new("raise_hands")
	step2.title = "Raise Your Hands"
	step2.instruction = "Lift both controllers in front of you.\nThese are your hands in VR!"
	step2.hint = "Bring your hands up to chest level"
	step2.completion_condition = "hands_raised"
	setup.steps.append(step2)

	var step3 := TutorialStep.new("grip_saber")
	step3.title = "Grip Your Lightsaber"
	step3.instruction = "Press and hold the GRIP button to\nactivate your lightsaber."
	step3.hint = "The grip button is on the side of the controller"
	step3.required_action = "grip"
	step3.completion_condition = "grip_pressed"
	setup.steps.append(step3)

	tutorials["first_time"] = setup

	# Combat Basics tutorial
	var combat := Tutorial.new()
	combat.id = "combat_basics"
	combat.name = "Combat Basics"
	combat.description = "Learn to strike targets with your lightsaber"
	combat.prerequisite = "first_time"

	var c_step1 := TutorialStep.new("swing_saber")
	c_step1.title = "Swing Your Saber"
	c_step1.instruction = "Swing your lightsaber through the air.\nFeel the power!"
	c_step1.hint = "Move your arm in a sweeping motion"
	c_step1.completion_condition = "saber_swung"
	combat.steps.append(c_step1)

	var c_step2 := TutorialStep.new("hit_target")
	c_step2.title = "Strike the Target"
	c_step2.instruction = "A target will appear.\nSwing your saber to destroy it!"
	c_step2.hint = "Hit the glowing target with your blade"
	c_step2.completion_condition = "target_destroyed"
	combat.steps.append(c_step2)

	var c_step3 := TutorialStep.new("combo_hits")
	c_step3.title = "Build a Combo"
	c_step3.instruction = "Hit multiple targets quickly\nto build a combo!"
	c_step3.hint = "Keep hitting targets without pausing"
	c_step3.completion_condition = "combo_reached_3"
	combat.steps.append(c_step3)

	tutorials["combat_basics"] = combat

	# Movement tutorial
	var movement := Tutorial.new()
	movement.id = "movement_basics"
	movement.name = "Movement Mastery"
	movement.description = "Learn about movement tracking and coverage"
	movement.prerequisite = "combat_basics"

	var m_step1 := TutorialStep.new("explore_space")
	m_step1.title = "Explore Your Space"
	m_step1.instruction = "Move around your play space.\nReach in different directions!"
	m_step1.hint = "Try reaching high, low, and to the sides"
	m_step1.completion_condition = "zones_discovered_5"
	movement.steps.append(m_step1)

	var m_step2 := TutorialStep.new("check_heatmap")
	m_step2.title = "View Heat Map"
	m_step2.instruction = "Notice the heat map visualization.\nBright areas show where you've moved!"
	m_step2.timeout = 10.0
	movement.steps.append(m_step2)

	var m_step3 := TutorialStep.new("find_gaps")
	m_step3.title = "Find Movement Gaps"
	m_step3.instruction = "Look for pulsing indicators.\nThese show unexplored zones!"
	m_step3.hint = "Move to the pulsing areas to discover them"
	m_step3.completion_condition = "gap_zone_reached"
	movement.steps.append(m_step3)

	tutorials["movement_basics"] = movement

	# Force Powers tutorial
	var force := Tutorial.new()
	force.id = "force_powers"
	force.name = "Force Powers"
	force.description = "Learn to use the Force"
	force.prerequisite = "movement_basics"

	var f_step1 := TutorialStep.new("force_push")
	f_step1.title = "Force Push"
	f_step1.instruction = "Extend your palm forward quickly\nto perform a Force Push!"
	f_step1.hint = "Open your hand and thrust forward"
	f_step1.completion_condition = "force_push_used"
	force.steps.append(f_step1)

	var f_step2 := TutorialStep.new("force_pull")
	f_step2.title = "Force Pull"
	f_step2.instruction = "Reach out and pull back\nto use Force Pull!"
	f_step2.hint = "Extend your arm, then pull toward you"
	f_step2.completion_condition = "force_pull_used"
	force.steps.append(f_step2)

	tutorials["force_powers"] = force

	# Deflection tutorial
	var deflect := Tutorial.new()
	deflect.id = "deflection"
	deflect.name = "Deflection Training"
	deflect.description = "Learn to deflect incoming projectiles"
	deflect.prerequisite = "combat_basics"

	var d_step1 := TutorialStep.new("watch_projectile")
	d_step1.title = "Watch the Projectile"
	d_step1.instruction = "Projectiles will come toward you.\nWatch their trajectory!"
	d_step1.timeout = 5.0
	deflect.steps.append(d_step1)

	var d_step2 := TutorialStep.new("deflect_projectile")
	d_step2.title = "Deflect!"
	d_step2.instruction = "Angle your blade to deflect\nthe incoming projectile!"
	d_step2.hint = "Time your swing to meet the projectile"
	d_step2.completion_condition = "projectile_deflected"
	deflect.steps.append(d_step2)

	tutorials["deflection"] = deflect


func _create_ui() -> void:
	# Create tutorial panel (world-space UI)
	tutorial_panel = Node3D.new()
	tutorial_panel.name = "TutorialPanel"
	add_child(tutorial_panel)

	# Create highlight effect for drawing attention
	highlight_effect = _create_highlight_sphere()
	highlight_effect.visible = false
	add_child(highlight_effect)


func _create_highlight_sphere() -> Node3D:
	var node := Node3D.new()

	var mesh := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.1
	sphere.height = 0.2

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.3, 0.8, 1.0, 0.3)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.emission_enabled = true
	mat.emission = Color(0.3, 0.8, 1.0)
	mat.emission_energy_multiplier = 2.0
	sphere.material = mat

	mesh.mesh = sphere
	node.add_child(mesh)

	return node


## Start a tutorial
func start_tutorial(tutorial_id: String) -> bool:
	if not tutorials.has(tutorial_id):
		push_error("Tutorial not found: " + tutorial_id)
		return false

	var tutorial: Tutorial = tutorials[tutorial_id]

	# Check prerequisite
	if tutorial.prerequisite != "" and tutorial.prerequisite not in completed_tutorials:
		push_warning("Prerequisite not met: " + tutorial.prerequisite)
		return false

	current_tutorial = tutorial
	current_step_index = 0
	is_active = true

	tutorial_started.emit(tutorial_id)
	_start_current_step()

	return true


func skip_tutorial() -> void:
	if current_tutorial == null or not current_tutorial.can_skip:
		return

	is_active = false
	tutorial_skipped.emit(current_tutorial.id)
	_cleanup()


func complete_tutorial() -> void:
	if current_tutorial == null:
		return

	completed_tutorials.append(current_tutorial.id)

	# Grant achievement if specified
	if current_tutorial.reward_achievement != "":
		GameEvents.achievement_unlocked.emit(current_tutorial.reward_achievement)

	tutorial_completed.emit(current_tutorial.id)
	is_active = false
	_cleanup()


func _start_current_step() -> void:
	var step := _get_current_step()
	if step == null:
		complete_tutorial()
		return

	step_timer = 0.0
	hint_shown_for_step = false

	step_started.emit(step)
	_update_ui(step)

	# Setup highlight if specified
	if step.highlight_target != "":
		_highlight_node(step.highlight_target)


func _advance_step() -> void:
	var step := _get_current_step()
	if step:
		step_completed.emit(step)

	current_step_index += 1
	highlight_effect.visible = false

	if current_step_index >= current_tutorial.steps.size():
		complete_tutorial()
	else:
		_start_current_step()


func _get_current_step() -> TutorialStep:
	if current_tutorial == null:
		return null
	if current_step_index >= current_tutorial.steps.size():
		return null
	return current_tutorial.steps[current_step_index]


func _show_hint() -> void:
	var step := _get_current_step()
	if step and step.hint != "":
		hint_shown.emit(step.hint)
		hint_shown_for_step = true


func _update_ui(step: TutorialStep) -> void:
	# Position panel in front of player
	if xr_camera and tutorial_panel:
		var forward := -xr_camera.global_transform.basis.z
		forward.y = 0
		forward = forward.normalized()

		tutorial_panel.global_position = xr_camera.global_position + forward * 2.0
		tutorial_panel.global_position.y = xr_camera.global_position.y
		tutorial_panel.look_at(xr_camera.global_position, Vector3.UP)
		tutorial_panel.rotate_y(PI)


func _highlight_node(node_path: String) -> void:
	var node := get_node_or_null(node_path)
	if node and node is Node3D:
		highlight_effect.global_position = node.global_position
		highlight_effect.visible = true


func _cleanup() -> void:
	current_tutorial = null
	current_step_index = 0
	highlight_effect.visible = false


## Completion condition handlers
func check_completion(condition: String) -> void:
	var step := _get_current_step()
	if step and step.completion_condition == condition:
		_advance_step()


func _on_trigger_pressed(hand: XRInputManager.Hand) -> void:
	check_completion("trigger_pressed")


func _on_grip_pressed(hand: XRInputManager.Hand) -> void:
	check_completion("grip_pressed")


func _on_gesture_detected(hand: XRInputManager.Hand, gesture: XRInputManager.Gesture) -> void:
	if gesture == XRInputManager.Gesture.OPEN_PALM:
		check_completion("open_palm_gesture")
	elif gesture == XRInputManager.Gesture.FIST:
		check_completion("fist_gesture")


## External completion triggers
func on_target_destroyed() -> void:
	check_completion("target_destroyed")


func on_combo_reached(combo: int) -> void:
	if combo >= 3:
		check_completion("combo_reached_3")
	if combo >= 5:
		check_completion("combo_reached_5")


func on_saber_swung(velocity: float) -> void:
	if velocity > 2.0:
		check_completion("saber_swung")


func on_zones_discovered(count: int) -> void:
	if count >= 5:
		check_completion("zones_discovered_5")


func on_force_push_used() -> void:
	check_completion("force_push_used")


func on_force_pull_used() -> void:
	check_completion("force_pull_used")


func on_projectile_deflected() -> void:
	check_completion("projectile_deflected")


func on_hands_raised(left_height: float, right_height: float) -> void:
	if left_height > 1.0 and right_height > 1.0:
		check_completion("hands_raised")


## Query functions
func is_tutorial_completed(tutorial_id: String) -> bool:
	return tutorial_id in completed_tutorials


func get_next_tutorial() -> String:
	for tutorial_id in ["first_time", "combat_basics", "movement_basics", "force_powers", "deflection"]:
		if tutorial_id not in completed_tutorials:
			var tutorial: Tutorial = tutorials.get(tutorial_id)
			if tutorial and (tutorial.prerequisite == "" or tutorial.prerequisite in completed_tutorials):
				return tutorial_id
	return ""


func should_show_tutorial() -> bool:
	return "first_time" not in completed_tutorials


## Save/Load
func save_progress() -> Dictionary:
	return {
		"completed": completed_tutorials
	}


func load_progress(data: Dictionary) -> void:
	completed_tutorials = []
	for t in data.get("completed", []):
		completed_tutorials.append(t)

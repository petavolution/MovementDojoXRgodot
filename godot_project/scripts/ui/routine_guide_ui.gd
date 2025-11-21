## RoutineGuideUI - VR guidance display for wellness routines
## Shows current step, timer, and visual cues
extends Node3D
class_name RoutineGuideUI

@export var panel_distance := 2.0
@export var panel_height := 0.5

var viewport: SubViewport
var panel_sprite: Sprite3D

# UI elements
var step_name_label: Label
var instruction_label: Label
var timer_label: Label
var progress_bar: ProgressBar
var step_counter_label: Label

# Visual guides
var target_indicator: MeshInstance3D
var breath_indicator: Node3D

var xr_camera: XRCamera3D
var routine_manager: RoutineManager


func _ready() -> void:
	_create_ui()
	_create_visual_guides()
	visible = false


func _process(_delta: float) -> void:
	if not visible:
		return

	_update_position()
	_update_breath_indicator()


func setup(camera: XRCamera3D, manager: RoutineManager) -> void:
	xr_camera = camera
	routine_manager = manager

	# Connect to routine manager signals
	manager.step_started.connect(_on_step_started)
	manager.step_progress.connect(_on_step_progress)
	manager.step_completed.connect(_on_step_completed)
	manager.routine_completed.connect(_on_routine_completed)
	manager.routine_cancelled.connect(_on_routine_cancelled)


func show_guide() -> void:
	visible = true
	_position_panel()


func hide_guide() -> void:
	visible = false
	target_indicator.visible = false


func _create_ui() -> void:
	viewport = SubViewport.new()
	viewport.size = Vector2i(600, 400)
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)

	var panel := Panel.new()
	panel.size = Vector2(600, 400)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.1, 0.15, 0.9)
	style.corner_radius_top_left = 15
	style.corner_radius_top_right = 15
	style.corner_radius_bottom_left = 15
	style.corner_radius_bottom_right = 15
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.2, 0.6, 0.8, 0.8)
	panel.add_theme_stylebox_override("panel", style)

	viewport.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.anchor_right = 1.0
	vbox.anchor_bottom = 1.0
	vbox.offset_left = 20
	vbox.offset_right = -20
	vbox.offset_top = 20
	vbox.offset_bottom = -20
	panel.add_child(vbox)

	# Step name
	step_name_label = Label.new()
	step_name_label.text = "Step Name"
	step_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	step_name_label.add_theme_font_size_override("font_size", 32)
	step_name_label.add_theme_color_override("font_color", Color(0.4, 0.8, 1.0))
	vbox.add_child(step_name_label)

	vbox.add_child(HSeparator.new())

	# Instruction
	instruction_label = Label.new()
	instruction_label.text = "Follow the movement instruction"
	instruction_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	instruction_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	instruction_label.add_theme_font_size_override("font_size", 24)
	instruction_label.custom_minimum_size = Vector2(0, 80)
	vbox.add_child(instruction_label)

	# Progress bar
	progress_bar = ProgressBar.new()
	progress_bar.min_value = 0.0
	progress_bar.max_value = 1.0
	progress_bar.value = 0.0
	progress_bar.custom_minimum_size = Vector2(0, 30)
	progress_bar.show_percentage = false
	vbox.add_child(progress_bar)

	# Timer
	timer_label = Label.new()
	timer_label.text = "0:00"
	timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	timer_label.add_theme_font_size_override("font_size", 48)
	timer_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
	vbox.add_child(timer_label)

	# Step counter
	step_counter_label = Label.new()
	step_counter_label.text = "Step 1 of 5"
	step_counter_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	step_counter_label.add_theme_font_size_override("font_size", 20)
	step_counter_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	vbox.add_child(step_counter_label)

	# Sprite3D to display viewport
	panel_sprite = Sprite3D.new()
	panel_sprite.texture = viewport.get_texture()
	panel_sprite.pixel_size = 0.001
	add_child(panel_sprite)


func _create_visual_guides() -> void:
	# Target position indicator (shows where to reach)
	target_indicator = MeshInstance3D.new()
	target_indicator.name = "TargetIndicator"

	var sphere := SphereMesh.new()
	sphere.radius = 0.08
	sphere.height = 0.16

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.2, 0.8, 0.4, 0.5)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.emission_enabled = true
	mat.emission = Color(0.2, 0.8, 0.4)
	mat.emission_energy_multiplier = 0.5
	sphere.material = mat

	target_indicator.mesh = sphere
	target_indicator.visible = false
	add_child(target_indicator)

	# Breath indicator (pulsing sphere for breathing exercises)
	breath_indicator = Node3D.new()
	breath_indicator.name = "BreathIndicator"

	var breath_mesh := MeshInstance3D.new()
	var breath_sphere := SphereMesh.new()
	breath_sphere.radius = 0.15
	breath_sphere.height = 0.3

	var breath_mat := StandardMaterial3D.new()
	breath_mat.albedo_color = Color(0.3, 0.5, 0.8, 0.3)
	breath_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	breath_mat.emission_enabled = true
	breath_mat.emission = Color(0.3, 0.5, 0.8)
	breath_sphere.material = breath_mat

	breath_mesh.mesh = breath_sphere
	breath_indicator.add_child(breath_mesh)
	breath_indicator.visible = false
	add_child(breath_indicator)


func _position_panel() -> void:
	if xr_camera == null:
		return

	var forward := -xr_camera.global_transform.basis.z
	forward.y = 0
	forward = forward.normalized()

	global_position = xr_camera.global_position + forward * panel_distance
	global_position.y = xr_camera.global_position.y + panel_height

	look_at(xr_camera.global_position, Vector3.UP)
	rotate_y(PI)


func _update_position() -> void:
	if xr_camera:
		look_at(xr_camera.global_position, Vector3.UP)
		rotate_y(PI)


func _update_breath_indicator() -> void:
	if not breath_indicator.visible:
		return

	# Pulsing animation for breathing rhythm
	var time := Time.get_ticks_msec() / 1000.0
	var breath_cycle := 4.0  # 4 seconds per breath
	var phase := fmod(time, breath_cycle) / breath_cycle

	# Inhale (0-0.5), exhale (0.5-1.0)
	var scale_factor: float
	if phase < 0.5:
		scale_factor = 0.8 + 0.4 * (phase * 2)  # Grow during inhale
	else:
		scale_factor = 1.2 - 0.4 * ((phase - 0.5) * 2)  # Shrink during exhale

	breath_indicator.scale = Vector3.ONE * scale_factor


func _on_step_started(step: WellnessRoutine.RoutineStep, index: int) -> void:
	step_name_label.text = step.name
	instruction_label.text = step.instruction
	progress_bar.value = 0.0

	if routine_manager and routine_manager.current_routine:
		var total := routine_manager.current_routine.steps.size()
		step_counter_label.text = "Step %d of %d" % [index + 1, total]

	# Show visual guides based on step type
	if step.target_zones.size() > 0:
		target_indicator.visible = true
		# Position at first target zone
		if xr_camera:
			target_indicator.global_position = xr_camera.global_position + step.target_zones[0]

	# Show breath indicator for stillness/meditation steps
	if step.name.contains("Breath") or step.name.contains("Centering") or step.name.contains("Meditation"):
		breath_indicator.visible = true
		if xr_camera:
			breath_indicator.global_position = xr_camera.global_position + Vector3(0, 0, -1)
	else:
		breath_indicator.visible = false


func _on_step_progress(progress: float, time_remaining: float) -> void:
	progress_bar.value = progress

	var minutes := int(time_remaining) / 60
	var seconds := int(time_remaining) % 60
	timer_label.text = "%d:%02d" % [minutes, seconds]

	# Pulse timer when low
	if time_remaining < 5.0:
		var pulse := 1.0 + sin(Time.get_ticks_msec() / 100.0) * 0.1
		timer_label.scale = Vector2(pulse, pulse)
	else:
		timer_label.scale = Vector2.ONE


func _on_step_completed(_step: WellnessRoutine.RoutineStep, _index: int) -> void:
	target_indicator.visible = false


func _on_routine_completed(_routine: WellnessRoutine, stats: Dictionary) -> void:
	step_name_label.text = "Routine Complete!"
	instruction_label.text = "Great work! You completed all steps."
	timer_label.text = ""
	progress_bar.value = 1.0
	step_counter_label.text = "Completion: %.0f%%" % stats.get("completion_rate", 100.0)

	target_indicator.visible = false
	breath_indicator.visible = false

	# Hide after delay
	var timer := get_tree().create_timer(5.0)
	timer.timeout.connect(hide_guide)


func _on_routine_cancelled() -> void:
	hide_guide()

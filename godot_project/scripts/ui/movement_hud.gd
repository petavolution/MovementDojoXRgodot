## MovementHUD - World-space HUD for real-time movement stats
## Attaches to wrist or floats near player
extends Node3D
class_name MovementHUD

@export var attach_to_wrist := true
@export var wrist_offset := Vector3(0.0, 0.05, -0.1)  # Offset from controller
@export var floating_offset := Vector3(-0.4, -0.2, 0.5)  # Offset from head

@export var hud_scale := Vector3(0.001, 0.001, 0.001)  # Scale for world-space
@export var update_interval := 0.1  # Seconds between updates

# UI Elements
var panel: Control
var coverage_label: Label
var symmetry_bar: ProgressBar
var symmetry_label: Label
var pose_label: Label
var movement_type_label: Label
var session_time_label: Label

# References
var xr_camera: XRCamera3D
var left_controller: XRController3D

var _update_timer := 0.0
var _current_pose := ""
var _pose_display_timer := 0.0


func _ready() -> void:
	_create_hud_ui()

	visible = SessionManager.get_settings().get("hud_visible", true)

	GameEvents.analytics_updated.connect(_on_analytics_updated)
	GameEvents.pose_detected.connect(_on_pose_detected)
	GameEvents.pose_lost.connect(_on_pose_lost)


func _process(delta: float) -> void:
	if not visible:
		return

	# Update position
	_update_position()

	# Update timer display
	_update_timer += delta
	if _update_timer >= update_interval:
		_update_timer = 0.0
		_update_session_time()

	# Fade out pose display
	if _pose_display_timer > 0:
		_pose_display_timer -= delta
		if _pose_display_timer <= 0:
			pose_label.text = ""


func setup_references(camera: XRCamera3D, left_ctrl: XRController3D) -> void:
	xr_camera = camera
	left_controller = left_ctrl


func _create_hud_ui() -> void:
	# Create SubViewport for 2D UI in 3D world space
	var viewport := SubViewport.new()
	viewport.size = Vector2i(400, 300)
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE  # More efficient than ALWAYS
	viewport.render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS  # Ensure clean transparency
	viewport.gui_disable_input = true  # No input needed for this HUD
	add_child(viewport)

	# Create panel
	panel = Panel.new()
	panel.custom_minimum_size = Vector2(400, 300)
	panel.size = Vector2(400, 300)

	# Style the panel
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.15, 0.85)
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_left = 10
	style.corner_radius_bottom_right = 10
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.3, 0.5, 0.8, 0.8)
	panel.add_theme_stylebox_override("panel", style)

	viewport.add_child(panel)

	# Create VBox for layout
	var vbox := VBoxContainer.new()
	vbox.anchor_right = 1.0
	vbox.anchor_bottom = 1.0
	vbox.offset_left = 15
	vbox.offset_right = -15
	vbox.offset_top = 10
	vbox.offset_bottom = -10
	panel.add_child(vbox)

	# Title
	var title := Label.new()
	title.text = "MOVEMENT DOJO"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color(0.4, 0.7, 1.0))
	vbox.add_child(title)

	vbox.add_child(HSeparator.new())

	# Session time
	session_time_label = Label.new()
	session_time_label.text = "Time: 00:00"
	session_time_label.add_theme_font_size_override("font_size", 18)
	vbox.add_child(session_time_label)

	# Coverage
	var coverage_container := HBoxContainer.new()
	var coverage_title := Label.new()
	coverage_title.text = "Coverage: "
	coverage_title.add_theme_font_size_override("font_size", 18)
	coverage_container.add_child(coverage_title)

	coverage_label = Label.new()
	coverage_label.text = "0.0%"
	coverage_label.add_theme_font_size_override("font_size", 18)
	coverage_label.add_theme_color_override("font_color", Color(0.2, 1.0, 0.4))
	coverage_container.add_child(coverage_label)
	vbox.add_child(coverage_container)

	# Symmetry
	var symmetry_container := VBoxContainer.new()
	symmetry_label = Label.new()
	symmetry_label.text = "Balance: 100%"
	symmetry_label.add_theme_font_size_override("font_size", 16)
	symmetry_container.add_child(symmetry_label)

	symmetry_bar = ProgressBar.new()
	symmetry_bar.custom_minimum_size = Vector2(0, 20)
	symmetry_bar.min_value = 0
	symmetry_bar.max_value = 100
	symmetry_bar.value = 100
	symmetry_bar.show_percentage = false
	symmetry_container.add_child(symmetry_bar)
	vbox.add_child(symmetry_container)

	# Current movement type
	movement_type_label = Label.new()
	movement_type_label.text = "Movement: Idle"
	movement_type_label.add_theme_font_size_override("font_size", 16)
	movement_type_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	vbox.add_child(movement_type_label)

	# Detected pose
	pose_label = Label.new()
	pose_label.text = ""
	pose_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pose_label.add_theme_font_size_override("font_size", 20)
	pose_label.add_theme_color_override("font_color", Color(1.0, 0.8, 0.2))
	vbox.add_child(pose_label)

	# Create Sprite3D to display the viewport in 3D world
	var sprite := Sprite3D.new()
	sprite.texture = viewport.get_texture()
	sprite.pixel_size = 0.001
	sprite.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED  # Use alpha blending
	sprite.shaded = false  # Unshaded for UI clarity
	sprite.double_sided = false  # Only visible from front
	sprite.render_priority = 10  # Render on top of other transparent objects
	add_child(sprite)


func _update_position() -> void:
	if attach_to_wrist and left_controller != null:
		global_transform = left_controller.global_transform
		position += left_controller.global_transform.basis * wrist_offset
		# Face the camera
		if xr_camera != null:
			look_at(xr_camera.global_position, Vector3.UP)
	elif xr_camera != null:
		global_transform = xr_camera.global_transform
		position += xr_camera.global_transform.basis * floating_offset
		look_at(xr_camera.global_position, Vector3.UP)


func _on_analytics_updated(stats: Dictionary) -> void:
	# Update coverage
	var coverage: float = stats.get("coverage", 0.0)
	coverage_label.text = "%.1f%%" % coverage

	# Color based on coverage
	if coverage < 25:
		coverage_label.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4))
	elif coverage < 50:
		coverage_label.add_theme_color_override("font_color", Color(1.0, 0.8, 0.2))
	elif coverage < 75:
		coverage_label.add_theme_color_override("font_color", Color(0.6, 1.0, 0.4))
	else:
		coverage_label.add_theme_color_override("font_color", Color(0.2, 1.0, 0.8))

	# Update symmetry
	var symmetry: float = stats.get("symmetry", 100.0)
	symmetry_label.text = "Balance: %.0f%%" % symmetry
	symmetry_bar.value = symmetry

	# Color symmetry bar
	var bar_style := StyleBoxFlat.new()
	if symmetry >= 90:
		bar_style.bg_color = Color(0.2, 0.8, 0.4)
	elif symmetry >= 70:
		bar_style.bg_color = Color(0.8, 0.8, 0.2)
	else:
		bar_style.bg_color = Color(0.8, 0.3, 0.2)
	symmetry_bar.add_theme_stylebox_override("fill", bar_style)


func _on_pose_detected(pose_name: String, _confidence: float) -> void:
	pose_label.text = pose_name
	_pose_display_timer = 3.0  # Show for 3 seconds


func _on_pose_lost(_pose_name: String) -> void:
	pass  # Keep showing until timer expires


func _update_session_time() -> void:
	var duration := MovementTracker.get_session_duration()
	var minutes := int(duration) / 60
	var seconds := int(duration) % 60
	session_time_label.text = "Time: %02d:%02d" % [minutes, seconds]


func set_visibility(visible_: bool) -> void:
	visible = visible_

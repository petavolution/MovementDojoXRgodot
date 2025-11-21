## VRMenu - 3D world-space menu system for VR
## Provides main menu, settings, and routine selection
extends Node3D
class_name VRMenu

signal menu_action(action: String, data: Variant)
signal menu_opened()
signal menu_closed()

@export var menu_distance := 1.5  # Distance from player
@export var menu_height_offset := 0.2  # Height relative to head
@export var panel_width := 0.8
@export var panel_height := 0.6

enum MenuState {
	HIDDEN,
	MAIN,
	TRAINING,
	WELLNESS,
	SETTINGS,
	STATS
}

var current_state := MenuState.HIDDEN
var menu_panels: Dictionary = {}
var active_panel: Control

# References
var xr_camera: XRCamera3D
var left_controller: XRController3D
var right_controller: XRController3D

# Interaction
var hovered_button: Button
var laser_pointer: MeshInstance3D
var laser_hit_point: MeshInstance3D

# SubViewport for 2D UI
var viewport: SubViewport
var viewport_sprite: Sprite3D


func _ready() -> void:
	_create_viewport()
	_create_menu_panels()
	_create_laser_pointer()

	visible = false


func _process(delta: float) -> void:
	if current_state == MenuState.HIDDEN:
		return

	_update_position()
	_update_laser_interaction()


func setup_references(camera: XRCamera3D, left: XRController3D, right: XRController3D) -> void:
	xr_camera = camera
	left_controller = left
	right_controller = right

	# Connect controller input
	if right_controller:
		right_controller.button_pressed.connect(_on_controller_button)


func show_menu(state: MenuState = MenuState.MAIN) -> void:
	if current_state != MenuState.HIDDEN:
		return

	visible = true
	_switch_to_state(state)
	_position_in_front_of_player()

	menu_opened.emit()


func hide_menu() -> void:
	visible = false
	current_state = MenuState.HIDDEN

	if active_panel:
		active_panel.visible = false

	menu_closed.emit()


func toggle_menu() -> void:
	if current_state == MenuState.HIDDEN:
		show_menu()
	else:
		hide_menu()


func _create_viewport() -> void:
	viewport = SubViewport.new()
	viewport.size = Vector2i(800, 600)
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.gui_disable_input = false
	add_child(viewport)

	viewport_sprite = Sprite3D.new()
	viewport_sprite.texture = viewport.get_texture()
	viewport_sprite.pixel_size = 0.001
	add_child(viewport_sprite)


func _create_menu_panels() -> void:
	_create_main_menu()
	_create_training_menu()
	_create_wellness_menu()
	_create_settings_menu()
	_create_stats_menu()


func _create_main_menu() -> void:
	var panel := _create_panel_base("MainMenu")

	var vbox := VBoxContainer.new()
	vbox.anchor_right = 1.0
	vbox.anchor_bottom = 1.0
	vbox.offset_left = 50
	vbox.offset_right = -50
	vbox.offset_top = 50
	vbox.offset_bottom = -50
	panel.add_child(vbox)

	# Title
	var title := Label.new()
	title.text = "MOVEMENT DOJO"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 48)
	title.add_theme_color_override("font_color", Color(0.4, 0.7, 1.0))
	vbox.add_child(title)

	vbox.add_child(HSeparator.new())
	vbox.add_child(_create_spacer(20))

	# Buttons
	var btn_training := _create_menu_button("Start Training", "start_training")
	vbox.add_child(btn_training)

	var btn_wellness := _create_menu_button("Wellness Routines", "show_wellness")
	vbox.add_child(btn_wellness)

	var btn_stats := _create_menu_button("Statistics", "show_stats")
	vbox.add_child(btn_stats)

	var btn_settings := _create_menu_button("Settings", "show_settings")
	vbox.add_child(btn_settings)

	vbox.add_child(_create_spacer(20))

	var btn_quit := _create_menu_button("Quit", "quit")
	btn_quit.add_theme_color_override("font_color", Color(0.8, 0.3, 0.3))
	vbox.add_child(btn_quit)

	menu_panels[MenuState.MAIN] = panel


func _create_training_menu() -> void:
	var panel := _create_panel_base("TrainingMenu")

	var vbox := VBoxContainer.new()
	vbox.anchor_right = 1.0
	vbox.anchor_bottom = 1.0
	vbox.offset_left = 50
	vbox.offset_right = -50
	vbox.offset_top = 30
	vbox.offset_bottom = -30
	panel.add_child(vbox)

	var title := Label.new()
	title.text = "TRAINING"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 36)
	vbox.add_child(title)

	vbox.add_child(HSeparator.new())

	var btn_targets := _create_menu_button("Target Practice", "training_targets")
	vbox.add_child(btn_targets)

	var btn_deflect := _create_menu_button("Deflection Training", "training_deflection")
	vbox.add_child(btn_deflect)

	var btn_combat := _create_menu_button("Combat Waves", "training_waves")
	vbox.add_child(btn_combat)

	var btn_free := _create_menu_button("Free Practice", "training_free")
	vbox.add_child(btn_free)

	vbox.add_child(_create_spacer(20))

	var btn_back := _create_menu_button("Back", "back_to_main")
	vbox.add_child(btn_back)

	menu_panels[MenuState.TRAINING] = panel


func _create_wellness_menu() -> void:
	var panel := _create_panel_base("WellnessMenu")

	var vbox := VBoxContainer.new()
	vbox.anchor_right = 1.0
	vbox.anchor_bottom = 1.0
	vbox.offset_left = 50
	vbox.offset_right = -50
	vbox.offset_top = 30
	vbox.offset_bottom = -30
	panel.add_child(vbox)

	var title := Label.new()
	title.text = "WELLNESS ROUTINES"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 36)
	vbox.add_child(title)

	vbox.add_child(HSeparator.new())

	# Routine buttons
	var routines := [
		["Morning Activation", "morning_activation"],
		["Saber Warmup", "saber_warmup"],
		["VR Sun Salutation", "vr_sun_salutation"],
		["Warrior Flow", "warrior_flow"],
		["Gathering Qi", "gathering_qi"],
		["Cloud Hands", "cloud_hands"],
		["Moving Meditation", "moving_meditation"]
	]

	for routine in routines:
		var btn := _create_menu_button(routine[0], "start_routine:" + routine[1])
		vbox.add_child(btn)

	vbox.add_child(_create_spacer(10))

	var btn_back := _create_menu_button("Back", "back_to_main")
	vbox.add_child(btn_back)

	menu_panels[MenuState.WELLNESS] = panel


func _create_settings_menu() -> void:
	var panel := _create_panel_base("SettingsMenu")

	var vbox := VBoxContainer.new()
	vbox.anchor_right = 1.0
	vbox.anchor_bottom = 1.0
	vbox.offset_left = 50
	vbox.offset_right = -50
	vbox.offset_top = 30
	vbox.offset_bottom = -30
	panel.add_child(vbox)

	var title := Label.new()
	title.text = "SETTINGS"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 36)
	vbox.add_child(title)

	vbox.add_child(HSeparator.new())

	# Volume sliders
	vbox.add_child(_create_slider_row("Master Volume", "master_volume", 1.0))
	vbox.add_child(_create_slider_row("Music", "music_volume", 0.7))
	vbox.add_child(_create_slider_row("Effects", "sfx_volume", 1.0))

	vbox.add_child(HSeparator.new())

	# Toggles
	vbox.add_child(_create_toggle_row("Show HUD", "hud_visible", true))
	vbox.add_child(_create_toggle_row("Show Trails", "trail_visible", true))
	vbox.add_child(_create_toggle_row("Show Heat Map", "heat_map_visible", false))
	vbox.add_child(_create_toggle_row("Gap Indicators", "gap_indicators_visible", true))

	vbox.add_child(_create_spacer(10))

	var btn_back := _create_menu_button("Back", "back_to_main")
	vbox.add_child(btn_back)

	menu_panels[MenuState.SETTINGS] = panel


func _create_stats_menu() -> void:
	var panel := _create_panel_base("StatsMenu")

	var vbox := VBoxContainer.new()
	vbox.anchor_right = 1.0
	vbox.anchor_bottom = 1.0
	vbox.offset_left = 50
	vbox.offset_right = -50
	vbox.offset_top = 30
	vbox.offset_bottom = -30
	panel.add_child(vbox)

	var title := Label.new()
	title.text = "STATISTICS"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 36)
	vbox.add_child(title)

	vbox.add_child(HSeparator.new())

	# Stats will be populated dynamically
	var stats_container := VBoxContainer.new()
	stats_container.name = "StatsContainer"
	vbox.add_child(stats_container)

	vbox.add_child(_create_spacer(20))

	var btn_back := _create_menu_button("Back", "back_to_main")
	vbox.add_child(btn_back)

	menu_panels[MenuState.STATS] = panel


func _create_panel_base(panel_name: String) -> Panel:
	var panel := Panel.new()
	panel.name = panel_name
	panel.custom_minimum_size = Vector2(800, 600)
	panel.size = Vector2(800, 600)
	panel.visible = false

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.08, 0.12, 0.95)
	style.corner_radius_top_left = 15
	style.corner_radius_top_right = 15
	style.corner_radius_bottom_left = 15
	style.corner_radius_bottom_right = 15
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.3, 0.5, 0.8, 0.8)
	panel.add_theme_stylebox_override("panel", style)

	viewport.add_child(panel)
	return panel


func _create_menu_button(text: String, action: String) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(0, 50)
	btn.add_theme_font_size_override("font_size", 24)
	btn.pressed.connect(func(): _on_button_action(action))
	return btn


func _create_slider_row(label_text: String, setting_key: String, default_value: float) -> HBoxContainer:
	var row := HBoxContainer.new()

	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size = Vector2(200, 0)
	row.add_child(label)

	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.value = SessionManager.get_settings().get(setting_key, default_value)
	slider.custom_minimum_size = Vector2(200, 30)
	slider.value_changed.connect(func(val): SessionManager.update_setting(setting_key, val))
	row.add_child(slider)

	return row


func _create_toggle_row(label_text: String, setting_key: String, default_value: bool) -> HBoxContainer:
	var row := HBoxContainer.new()

	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size = Vector2(250, 0)
	row.add_child(label)

	var toggle := CheckButton.new()
	toggle.button_pressed = SessionManager.get_settings().get(setting_key, default_value)
	toggle.toggled.connect(func(pressed): SessionManager.update_setting(setting_key, pressed))
	row.add_child(toggle)

	return row


func _create_spacer(height: float) -> Control:
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, height)
	return spacer


func _create_laser_pointer() -> void:
	laser_pointer = MeshInstance3D.new()
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = 0.002
	cylinder.bottom_radius = 0.002
	cylinder.height = 5.0

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.3, 0.6, 1.0, 0.5)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	cylinder.material = mat

	laser_pointer.mesh = cylinder
	laser_pointer.visible = false
	add_child(laser_pointer)

	laser_hit_point = MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.01
	sphere.height = 0.02
	sphere.material = mat.duplicate()
	laser_hit_point.mesh = sphere
	laser_hit_point.visible = false
	add_child(laser_hit_point)


func _switch_to_state(new_state: MenuState) -> void:
	if active_panel:
		active_panel.visible = false

	current_state = new_state

	if menu_panels.has(new_state):
		active_panel = menu_panels[new_state]
		active_panel.visible = true

		if new_state == MenuState.STATS:
			_update_stats_display()


func _position_in_front_of_player() -> void:
	if xr_camera == null:
		return

	var forward := -xr_camera.global_transform.basis.z
	forward.y = 0
	forward = forward.normalized()

	global_position = xr_camera.global_position + forward * menu_distance
	global_position.y += menu_height_offset

	look_at(xr_camera.global_position, Vector3.UP)
	rotate_y(PI)  # Face the player


func _update_position() -> void:
	if xr_camera:
		look_at(xr_camera.global_position, Vector3.UP)
		rotate_y(PI)


func _update_laser_interaction() -> void:
	if right_controller == null:
		laser_pointer.visible = false
		return

	laser_pointer.visible = true
	laser_pointer.global_position = right_controller.global_position
	laser_pointer.global_transform = right_controller.global_transform
	laser_pointer.rotate_object_local(Vector3.RIGHT, PI / 2)

	# Raycast to menu
	# Simplified - in production would do proper 3D to 2D coordinate mapping


func _update_stats_display() -> void:
	var stats_container := menu_panels[MenuState.STATS].get_node_or_null("StatsContainer")
	if stats_container == null:
		return

	# Clear existing
	for child in stats_container.get_children():
		child.queue_free()

	var lifetime := SessionManager.get_lifetime_stats()
	var score_stats := ScoreManager.get_session_stats()

	var stats := [
		["Total Sessions", str(lifetime.get("total_sessions", 0))],
		["Total Time", _format_time(lifetime.get("total_duration", 0.0))],
		["Best Coverage", "%.1f%%" % lifetime.get("best_coverage", 0.0)],
		["High Score", str(score_stats.get("high_score", 0))],
		["Best Combo", str(score_stats.get("best_combo", 0))],
		["Daily Streak", str(lifetime.get("daily_streak", 0)) + " days"],
		["Achievements", "%d/%d" % [Achievements.get_unlocked_count(), Achievements.get_total_count()]]
	]

	for stat in stats:
		var row := HBoxContainer.new()

		var label := Label.new()
		label.text = stat[0] + ":"
		label.custom_minimum_size = Vector2(200, 0)
		row.add_child(label)

		var value := Label.new()
		value.text = stat[1]
		value.add_theme_color_override("font_color", Color(0.4, 0.8, 1.0))
		row.add_child(value)

		stats_container.add_child(row)


func _format_time(seconds: float) -> String:
	var hours := int(seconds) / 3600
	var minutes := (int(seconds) % 3600) / 60
	if hours > 0:
		return "%dh %dm" % [hours, minutes]
	else:
		return "%dm" % minutes


func _on_button_action(action: String) -> void:
	match action:
		"start_training":
			hide_menu()
			menu_action.emit("start_training", null)
		"show_wellness":
			_switch_to_state(MenuState.WELLNESS)
		"show_stats":
			_switch_to_state(MenuState.STATS)
		"show_settings":
			_switch_to_state(MenuState.SETTINGS)
		"back_to_main":
			_switch_to_state(MenuState.MAIN)
		"quit":
			menu_action.emit("quit", null)
		_:
			if action.begins_with("start_routine:"):
				var routine_id := action.substr(14)
				hide_menu()
				menu_action.emit("start_routine", routine_id)
			elif action.begins_with("training_"):
				hide_menu()
				menu_action.emit(action, null)


func _on_controller_button(button: String) -> void:
	if button == "trigger_click" and current_state != MenuState.HIDDEN:
		# Would trigger hovered button
		pass
	elif button == "menu_button":
		toggle_menu()

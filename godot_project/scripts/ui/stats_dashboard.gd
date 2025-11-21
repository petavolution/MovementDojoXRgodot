## StatsDashboard - VR statistics visualization panel
## Displays comprehensive movement and performance analytics
class_name StatsDashboard
extends Node3D

signal dashboard_opened
signal dashboard_closed
signal tab_changed(tab_name: String)

enum Tab { OVERVIEW, MOVEMENT, COMBAT, WELLNESS, HISTORY }

@export var panel_width: float = 1.2
@export var panel_height: float = 0.8
@export var follow_head: bool = false

var viewport: SubViewport
var panel_mesh: MeshInstance3D
var current_tab: Tab = Tab.OVERVIEW

# UI containers
var tab_bar: HBoxContainer
var content_container: Control
var tab_contents: Dictionary = {}

# Data references
var session_manager: Node
var movement_tracker: Node

# Chart data
var movement_history: Array[float] = []
var accuracy_history: Array[float] = []
var score_history: Array[int] = []

const MAX_HISTORY_POINTS := 30


func _ready() -> void:
	_create_panel()
	_create_ui()
	visible = false


func setup(sess_manager: Node, mov_tracker: Node) -> void:
	session_manager = sess_manager
	movement_tracker = mov_tracker


func _create_panel() -> void:
	# Create SubViewport for UI rendering
	viewport = SubViewport.new()
	viewport.size = Vector2i(1200, 800)
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)

	# Create 3D mesh to display the viewport
	panel_mesh = MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(panel_width, panel_height)
	panel_mesh.mesh = quad

	var mat := StandardMaterial3D.new()
	mat.albedo_texture = viewport.get_texture()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	panel_mesh.material_override = mat

	add_child(panel_mesh)


func _create_ui() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	viewport.add_child(root)

	# Background panel
	var bg := Panel.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg_style := StyleBoxFlat.new()
	bg_style.bg_color = Color(0.08, 0.1, 0.15, 0.95)
	bg_style.corner_radius_top_left = 20
	bg_style.corner_radius_top_right = 20
	bg_style.corner_radius_bottom_left = 20
	bg_style.corner_radius_bottom_right = 20
	bg_style.border_width_left = 2
	bg_style.border_width_right = 2
	bg_style.border_width_top = 2
	bg_style.border_width_bottom = 2
	bg_style.border_color = Color(0.3, 0.5, 0.7, 0.8)
	bg.add_theme_stylebox_override("panel", bg_style)
	root.add_child(bg)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.offset_left = 20
	vbox.offset_right = -20
	vbox.offset_top = 20
	vbox.offset_bottom = -20
	root.add_child(vbox)

	# Title
	var title := Label.new()
	title.text = "MOVEMENT DOJO - STATISTICS"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 36)
	title.add_theme_color_override("font_color", Color(0.4, 0.8, 1.0))
	vbox.add_child(title)

	vbox.add_child(HSeparator.new())

	# Tab bar
	tab_bar = HBoxContainer.new()
	tab_bar.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(tab_bar)

	_create_tab_buttons()

	vbox.add_child(HSeparator.new())

	# Content area
	content_container = Control.new()
	content_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(content_container)

	_create_tab_contents()
	_show_tab(Tab.OVERVIEW)


func _create_tab_buttons() -> void:
	var tabs := ["Overview", "Movement", "Combat", "Wellness", "History"]
	var tab_enums := [Tab.OVERVIEW, Tab.MOVEMENT, Tab.COMBAT, Tab.WELLNESS, Tab.HISTORY]

	for i in range(tabs.size()):
		var btn := Button.new()
		btn.text = tabs[i]
		btn.custom_minimum_size = Vector2(150, 40)
		btn.pressed.connect(_on_tab_pressed.bind(tab_enums[i]))
		tab_bar.add_child(btn)


func _create_tab_contents() -> void:
	# Overview tab
	var overview := _create_overview_content()
	tab_contents[Tab.OVERVIEW] = overview
	content_container.add_child(overview)

	# Movement tab
	var movement := _create_movement_content()
	tab_contents[Tab.MOVEMENT] = movement
	content_container.add_child(movement)

	# Combat tab
	var combat := _create_combat_content()
	tab_contents[Tab.COMBAT] = combat
	content_container.add_child(combat)

	# Wellness tab
	var wellness := _create_wellness_content()
	tab_contents[Tab.WELLNESS] = wellness
	content_container.add_child(wellness)

	# History tab
	var history := _create_history_content()
	tab_contents[Tab.HISTORY] = history
	content_container.add_child(history)


func _create_overview_content() -> Control:
	var container := VBoxContainer.new()
	container.set_anchors_preset(Control.PRESET_FULL_RECT)

	var grid := GridContainer.new()
	grid.columns = 3
	container.add_child(grid)

	# Stat cards
	grid.add_child(_create_stat_card("Total Sessions", "0", "session_count"))
	grid.add_child(_create_stat_card("Total Time", "0:00", "total_time"))
	grid.add_child(_create_stat_card("Avg. Accuracy", "0%", "avg_accuracy"))
	grid.add_child(_create_stat_card("Best Combo", "0", "best_combo"))
	grid.add_child(_create_stat_card("Targets Hit", "0", "targets_hit"))
	grid.add_child(_create_stat_card("Est. Calories", "0", "calories"))

	return container


func _create_movement_content() -> Control:
	var container := VBoxContainer.new()
	container.set_anchors_preset(Control.PRESET_FULL_RECT)

	var grid := GridContainer.new()
	grid.columns = 2
	container.add_child(grid)

	grid.add_child(_create_stat_card("Space Coverage", "0%", "space_coverage"))
	grid.add_child(_create_stat_card("Zones Discovered", "0", "zones_discovered"))
	grid.add_child(_create_stat_card("Avg. Velocity", "0 m/s", "avg_velocity"))
	grid.add_child(_create_stat_card("Max Reach", "0m", "max_reach"))

	# Movement distribution label
	var dist_label := Label.new()
	dist_label.text = "Movement Distribution"
	dist_label.add_theme_font_size_override("font_size", 24)
	container.add_child(dist_label)

	# Visual representation of movement zones
	var zone_display := _create_zone_visualization()
	container.add_child(zone_display)

	return container


func _create_combat_content() -> Control:
	var container := VBoxContainer.new()
	container.set_anchors_preset(Control.PRESET_FULL_RECT)

	var grid := GridContainer.new()
	grid.columns = 3
	container.add_child(grid)

	grid.add_child(_create_stat_card("Total Score", "0", "total_score"))
	grid.add_child(_create_stat_card("Accuracy", "0%", "accuracy"))
	grid.add_child(_create_stat_card("Perfect Hits", "0", "perfect_hits"))
	grid.add_child(_create_stat_card("Deflections", "0", "deflections"))
	grid.add_child(_create_stat_card("Force Uses", "0", "force_uses"))
	grid.add_child(_create_stat_card("Reaction Time", "0ms", "reaction_time"))

	return container


func _create_wellness_content() -> Control:
	var container := VBoxContainer.new()
	container.set_anchors_preset(Control.PRESET_FULL_RECT)

	var grid := GridContainer.new()
	grid.columns = 2
	container.add_child(grid)

	grid.add_child(_create_stat_card("Routines Completed", "0", "routines_done"))
	grid.add_child(_create_stat_card("Active Minutes", "0", "active_minutes"))
	grid.add_child(_create_stat_card("Poses Held", "0", "poses_held"))
	grid.add_child(_create_stat_card("Streak Days", "0", "streak_days"))

	# Routine history
	var routine_label := Label.new()
	routine_label.text = "Recent Routines"
	routine_label.add_theme_font_size_override("font_size", 24)
	container.add_child(routine_label)

	var routine_list := ItemList.new()
	routine_list.custom_minimum_size = Vector2(0, 200)
	routine_list.set_meta("id", "routine_list")
	container.add_child(routine_list)

	return container


func _create_history_content() -> Control:
	var container := VBoxContainer.new()
	container.set_anchors_preset(Control.PRESET_FULL_RECT)

	var label := Label.new()
	label.text = "Session History (Last 30 Days)"
	label.add_theme_font_size_override("font_size", 24)
	container.add_child(label)

	# Simple chart placeholder (would use custom drawing in full implementation)
	var chart_bg := ColorRect.new()
	chart_bg.color = Color(0.1, 0.12, 0.18, 1.0)
	chart_bg.custom_minimum_size = Vector2(0, 300)
	chart_bg.set_meta("id", "history_chart")
	container.add_child(chart_bg)

	# Session list
	var session_list := ItemList.new()
	session_list.custom_minimum_size = Vector2(0, 200)
	session_list.set_meta("id", "session_list")
	container.add_child(session_list)

	return container


func _create_stat_card(title: String, value: String, stat_id: String) -> Control:
	var card := Panel.new()
	card.custom_minimum_size = Vector2(200, 100)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.15, 0.22, 1.0)
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_left = 10
	style.corner_radius_bottom_right = 10
	card.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.offset_left = 10
	vbox.offset_right = -10
	vbox.offset_top = 10
	vbox.offset_bottom = -10
	card.add_child(vbox)

	var title_label := Label.new()
	title_label.text = title
	title_label.add_theme_font_size_override("font_size", 16)
	title_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	vbox.add_child(title_label)

	var value_label := Label.new()
	value_label.text = value
	value_label.add_theme_font_size_override("font_size", 32)
	value_label.add_theme_color_override("font_color", Color(0.4, 0.8, 1.0))
	value_label.set_meta("stat_id", stat_id)
	vbox.add_child(value_label)

	return card


func _create_zone_visualization() -> Control:
	var container := ColorRect.new()
	container.color = Color(0.1, 0.12, 0.18, 1.0)
	container.custom_minimum_size = Vector2(0, 200)
	container.set_meta("id", "zone_viz")
	return container


func _on_tab_pressed(tab: Tab) -> void:
	_show_tab(tab)


func _show_tab(tab: Tab) -> void:
	current_tab = tab

	for t in tab_contents:
		tab_contents[t].visible = (t == tab)

	var tab_names := {
		Tab.OVERVIEW: "Overview",
		Tab.MOVEMENT: "Movement",
		Tab.COMBAT: "Combat",
		Tab.WELLNESS: "Wellness",
		Tab.HISTORY: "History"
	}

	tab_changed.emit(tab_names.get(tab, ""))
	_update_tab_data(tab)


func _update_tab_data(tab: Tab) -> void:
	if session_manager == null:
		return

	var stats: Dictionary = {}
	if session_manager.has_method("get_lifetime_stats"):
		stats = session_manager.get_lifetime_stats()

	match tab:
		Tab.OVERVIEW:
			_update_stat("session_count", str(stats.get("session_count", 0)))
			_update_stat("total_time", _format_time(stats.get("total_play_time", 0.0)))
			_update_stat("avg_accuracy", "%.1f%%" % stats.get("avg_accuracy", 0.0))
			_update_stat("best_combo", str(stats.get("best_combo", 0)))
			_update_stat("targets_hit", str(stats.get("total_targets_hit", 0)))
			_update_stat("calories", str(int(stats.get("total_calories", 0))))

		Tab.MOVEMENT:
			var current_stats: Dictionary = {}
			if movement_tracker and movement_tracker.has_method("get_session_stats"):
				current_stats = movement_tracker.get_session_stats()

			_update_stat("space_coverage", "%.1f%%" % (current_stats.get("space_coverage", 0.0) * 100))
			_update_stat("zones_discovered", str(current_stats.get("zones_discovered", 0)))
			_update_stat("avg_velocity", "%.2f m/s" % current_stats.get("avg_velocity", 0.0))
			_update_stat("max_reach", "%.2fm" % current_stats.get("max_reach", 0.0))

		Tab.COMBAT:
			_update_stat("total_score", str(stats.get("total_score", 0)))
			_update_stat("accuracy", "%.1f%%" % stats.get("avg_accuracy", 0.0))
			_update_stat("perfect_hits", str(stats.get("perfect_hits", 0)))
			_update_stat("deflections", str(stats.get("deflections", 0)))
			_update_stat("force_uses", str(stats.get("force_uses", 0)))
			_update_stat("reaction_time", "%dms" % int(stats.get("avg_reaction_time", 0) * 1000))


func _update_stat(stat_id: String, value: String) -> void:
	var labels := _find_stat_labels(content_container, stat_id)
	for label in labels:
		label.text = value


func _find_stat_labels(node: Node, stat_id: String) -> Array[Label]:
	var results: Array[Label] = []

	if node is Label and node.has_meta("stat_id") and node.get_meta("stat_id") == stat_id:
		results.append(node)

	for child in node.get_children():
		results.append_array(_find_stat_labels(child, stat_id))

	return results


func _format_time(seconds: float) -> String:
	var hours := int(seconds) / 3600
	var minutes := (int(seconds) % 3600) / 60
	if hours > 0:
		return "%d:%02d" % [hours, minutes]
	return "%d min" % minutes


func show_dashboard() -> void:
	visible = true
	_update_tab_data(current_tab)
	dashboard_opened.emit()


func hide_dashboard() -> void:
	visible = false
	dashboard_closed.emit()


func toggle_dashboard() -> void:
	if visible:
		hide_dashboard()
	else:
		show_dashboard()

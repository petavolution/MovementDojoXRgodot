## VRPerformanceMonitor - Real-time VR performance tracking
## Monitors frame timing, dropped frames, and system health
class_name VRPerformanceMonitor
extends Node

signal performance_warning(message: String, severity: int)
signal frame_drop_detected(dropped_count: int)
signal reprojection_started
signal reprojection_ended
signal thermal_warning(level: int)

## Performance thresholds (for 90Hz target)
const TARGET_FRAME_TIME_MS := 11.11  # 90 FPS
const WARNING_FRAME_TIME_MS := 13.0
const CRITICAL_FRAME_TIME_MS := 16.0

## State
var is_monitoring: bool = false
var show_overlay: bool = false

## Metrics
var current_fps: float = 90.0
var average_fps: float = 90.0
var frame_time_ms: float = 11.0
var gpu_time_ms: float = 0.0
var cpu_time_ms: float = 0.0

var dropped_frames_total: int = 0
var dropped_frames_session: int = 0
var reprojection_count: int = 0

var fps_history: Array[float] = []
const FPS_HISTORY_SIZE := 90

## Tracking quality
var tracking_quality: float = 1.0
var left_controller_tracked: bool = true
var right_controller_tracked: bool = true
var headset_tracked: bool = true

## System
var memory_used_mb: float = 0.0
var vram_used_mb: float = 0.0

## Performance level
enum PerformanceLevel { EXCELLENT, GOOD, ACCEPTABLE, POOR, CRITICAL }
var current_level: PerformanceLevel = PerformanceLevel.EXCELLENT

## UI
var overlay_label: Label3D


func _ready() -> void:
	fps_history.resize(FPS_HISTORY_SIZE)
	fps_history.fill(90.0)

	_create_overlay()


func _process(delta: float) -> void:
	if not is_monitoring:
		return

	_update_metrics(delta)
	_check_performance()
	_update_overlay()


func start_monitoring() -> void:
	is_monitoring = true
	dropped_frames_session = 0


func stop_monitoring() -> void:
	is_monitoring = false


func _update_metrics(delta: float) -> void:
	# FPS calculation
	current_fps = 1.0 / delta if delta > 0 else 0.0
	frame_time_ms = delta * 1000.0

	# Update FPS history
	fps_history.pop_front()
	fps_history.push_back(current_fps)

	# Calculate average
	var sum := 0.0
	for fps in fps_history:
		sum += fps
	average_fps = sum / fps_history.size()

	# Memory tracking
	memory_used_mb = OS.get_static_memory_usage() / 1048576.0

	# Check for dropped frames
	if frame_time_ms > TARGET_FRAME_TIME_MS * 1.5:
		dropped_frames_session += 1
		dropped_frames_total += 1
		frame_drop_detected.emit(1)

	# Update XR tracking quality
	_update_tracking_quality()


func _update_tracking_quality() -> void:
	var xr_interface := XRServer.primary_interface
	if xr_interface == null:
		tracking_quality = 0.0
		return

	# Check if interface is initialized
	if not xr_interface.is_initialized():
		tracking_quality = 0.0
		return

	# Tracking quality estimation based on available data
	var quality := 1.0

	# Would check actual tracking confidence from XR runtime
	# For now, use heuristics based on controller visibility
	headset_tracked = true  # Assume headset is always tracked if XR is active

	tracking_quality = quality


func _check_performance() -> void:
	var old_level := current_level

	if frame_time_ms <= TARGET_FRAME_TIME_MS:
		current_level = PerformanceLevel.EXCELLENT
	elif frame_time_ms <= WARNING_FRAME_TIME_MS:
		current_level = PerformanceLevel.GOOD
	elif frame_time_ms <= CRITICAL_FRAME_TIME_MS:
		current_level = PerformanceLevel.ACCEPTABLE
	elif frame_time_ms <= CRITICAL_FRAME_TIME_MS * 1.5:
		current_level = PerformanceLevel.POOR
	else:
		current_level = PerformanceLevel.CRITICAL

	# Emit warnings on level change
	if current_level != old_level:
		if current_level == PerformanceLevel.POOR:
			performance_warning.emit("Performance degraded - consider reducing quality", 1)
		elif current_level == PerformanceLevel.CRITICAL:
			performance_warning.emit("Critical performance issues - reduce quality immediately", 2)


func _create_overlay() -> void:
	overlay_label = Label3D.new()
	overlay_label.name = "PerformanceOverlay"
	overlay_label.pixel_size = 0.001
	overlay_label.font_size = 32
	overlay_label.outline_size = 4
	overlay_label.modulate = Color(0.0, 1.0, 0.0)
	overlay_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	overlay_label.no_depth_test = true
	overlay_label.visible = false
	add_child(overlay_label)


func _update_overlay() -> void:
	if not show_overlay or overlay_label == null:
		return

	var text := "FPS: %.0f (%.1f ms)\n" % [current_fps, frame_time_ms]
	text += "Avg: %.0f FPS\n" % average_fps
	text += "Dropped: %d\n" % dropped_frames_session
	text += "Memory: %.0f MB\n" % memory_used_mb
	text += "Level: %s" % _level_name(current_level)

	overlay_label.text = text

	# Color based on performance
	match current_level:
		PerformanceLevel.EXCELLENT:
			overlay_label.modulate = Color(0.0, 1.0, 0.0)
		PerformanceLevel.GOOD:
			overlay_label.modulate = Color(0.5, 1.0, 0.0)
		PerformanceLevel.ACCEPTABLE:
			overlay_label.modulate = Color(1.0, 1.0, 0.0)
		PerformanceLevel.POOR:
			overlay_label.modulate = Color(1.0, 0.5, 0.0)
		PerformanceLevel.CRITICAL:
			overlay_label.modulate = Color(1.0, 0.0, 0.0)


func toggle_overlay() -> void:
	show_overlay = not show_overlay
	overlay_label.visible = show_overlay


func position_overlay(camera: XRCamera3D) -> void:
	if overlay_label and camera:
		var forward := -camera.global_transform.basis.z
		overlay_label.global_position = camera.global_position + forward * 0.5
		overlay_label.global_position += Vector3(-0.15, 0.1, 0)


func _level_name(level: PerformanceLevel) -> String:
	match level:
		PerformanceLevel.EXCELLENT: return "Excellent"
		PerformanceLevel.GOOD: return "Good"
		PerformanceLevel.ACCEPTABLE: return "Acceptable"
		PerformanceLevel.POOR: return "Poor"
		PerformanceLevel.CRITICAL: return "Critical"
	return "Unknown"


## Get performance report
func get_report() -> Dictionary:
	return {
		"current_fps": current_fps,
		"average_fps": average_fps,
		"frame_time_ms": frame_time_ms,
		"dropped_frames_session": dropped_frames_session,
		"dropped_frames_total": dropped_frames_total,
		"reprojection_count": reprojection_count,
		"memory_used_mb": memory_used_mb,
		"performance_level": _level_name(current_level),
		"tracking_quality": tracking_quality,
		"headset_tracked": headset_tracked,
		"left_controller_tracked": left_controller_tracked,
		"right_controller_tracked": right_controller_tracked
	}


## Get FPS statistics
func get_fps_stats() -> Dictionary:
	var min_fps := 999.0
	var max_fps := 0.0

	for fps in fps_history:
		min_fps = minf(min_fps, fps)
		max_fps = maxf(max_fps, fps)

	return {
		"current": current_fps,
		"average": average_fps,
		"min": min_fps,
		"max": max_fps,
		"target": 90.0
	}


## Recommend quality settings based on performance
func get_quality_recommendation() -> Dictionary:
	var recommendations := {
		"action": "none",
		"settings": {}
	}

	match current_level:
		PerformanceLevel.EXCELLENT:
			recommendations.action = "can_increase"
			recommendations.settings = {
				"render_scale": 1.2,
				"msaa": 4,
				"particle_density": 1.5
			}
		PerformanceLevel.GOOD:
			recommendations.action = "none"
		PerformanceLevel.ACCEPTABLE:
			recommendations.action = "consider_reducing"
			recommendations.settings = {
				"particle_density": 0.8
			}
		PerformanceLevel.POOR:
			recommendations.action = "reduce"
			recommendations.settings = {
				"render_scale": 0.9,
				"msaa": 2,
				"particle_density": 0.5,
				"shadow_quality": 1
			}
		PerformanceLevel.CRITICAL:
			recommendations.action = "reduce_immediately"
			recommendations.settings = {
				"render_scale": 0.7,
				"msaa": 0,
				"particle_density": 0.3,
				"shadow_quality": 0,
				"glow_enabled": false
			}

	return recommendations


## Auto-adjust quality based on performance
func auto_adjust_quality() -> void:
	var recommendations := get_quality_recommendation()

	if recommendations.action == "none":
		return

	# Would apply settings through SettingsManager
	var settings_manager := get_node_or_null("/root/SettingsManager")
	if settings_manager == null:
		return

	for key in recommendations.settings:
		if settings_manager.has_method("set_graphics_setting"):
			settings_manager.set_graphics_setting(key, recommendations.settings[key])

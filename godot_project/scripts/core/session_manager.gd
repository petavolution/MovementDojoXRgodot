## SessionManager - Data persistence and session lifecycle
## Autoloaded as "SessionManager"
extends Node

const SAVE_DIR := "user://movement_dojo/"
const SESSIONS_DIR := "user://movement_dojo/sessions/"
const ANALYTICS_DIR := "user://movement_dojo/analytics/"
const SETTINGS_FILE := "user://movement_dojo/settings.json"

# Current session
var current_session_id := ""
var session_active := false
var session_start_time := 0.0

# Lifetime statistics
var lifetime_stats := {
	"total_sessions": 0,
	"total_duration": 0.0,
	"total_distance": 0.0,
	"best_coverage": 0.0,
	"achievements": [],
	"daily_streak": 0,
	"last_session_date": ""
}

# Settings
var settings := {
	"hud_visible": true,
	"trail_visible": true,
	"heat_map_visible": false,
	"gap_indicators_visible": true,
	"haptic_intensity": 1.0,
	"comfort_vignette": true,
	"snap_turn_angle": 45.0
}


func _ready() -> void:
	_ensure_directories()
	_load_lifetime_stats()
	_load_settings()


func start_session() -> String:
	if session_active:
		end_session()

	current_session_id = _generate_session_id()
	session_active = true
	session_start_time = Time.get_unix_time_from_system()

	MovementTracker.start_tracking()

	GameEvents.session_started.emit(current_session_id)
	print("[SessionManager] Session started: ", current_session_id)

	return current_session_id


func end_session() -> Dictionary:
	if not session_active:
		return {}

	MovementTracker.stop_tracking()

	var summary := _compile_session_summary()
	_save_session(summary)
	_update_lifetime_stats(summary)

	session_active = false
	GameEvents.session_ended.emit(current_session_id, summary)
	print("[SessionManager] Session ended: ", current_session_id)

	current_session_id = ""
	return summary


func pause_session() -> void:
	if session_active:
		MovementTracker.stop_tracking()
		GameEvents.session_paused.emit()


func resume_session() -> void:
	if session_active:
		MovementTracker.start_tracking()
		GameEvents.session_resumed.emit()


func get_session_summary() -> Dictionary:
	if not session_active:
		return {}
	return _compile_session_summary()


func get_lifetime_stats() -> Dictionary:
	return lifetime_stats.duplicate(true)


func get_settings() -> Dictionary:
	return settings.duplicate(true)


func update_setting(key: String, value: Variant) -> void:
	if settings.has(key):
		settings[key] = value
		_save_settings()


func unlock_achievement(achievement_id: String) -> bool:
	if achievement_id in lifetime_stats["achievements"]:
		return false  # Already unlocked

	lifetime_stats["achievements"].append(achievement_id)
	_save_lifetime_stats()

	GameEvents.achievement_unlocked.emit(achievement_id)
	return true


func get_recent_sessions(count: int = 10) -> Array[Dictionary]:
	var sessions: Array[Dictionary] = []
	var dir := DirAccess.open(SESSIONS_DIR)

	if dir == null:
		return sessions

	var files: Array[String] = []
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if file_name.ends_with(".json"):
			files.append(file_name)
		file_name = dir.get_next()
	dir.list_dir_end()

	# Sort by name (which includes timestamp)
	files.sort()
	files.reverse()  # Most recent first

	for i in range(mini(count, files.size())):
		var session_data := _load_session_file(SESSIONS_DIR + files[i])
		if not session_data.is_empty():
			sessions.append(session_data)

	return sessions


func _ensure_directories() -> void:
	DirAccess.make_dir_recursive_absolute(SAVE_DIR.replace("user://", OS.get_user_data_dir() + "/"))
	DirAccess.make_dir_recursive_absolute(SESSIONS_DIR.replace("user://", OS.get_user_data_dir() + "/"))
	DirAccess.make_dir_recursive_absolute(ANALYTICS_DIR.replace("user://", OS.get_user_data_dir() + "/"))


func _generate_session_id() -> String:
	var datetime := Time.get_datetime_dict_from_system()
	return "%04d%02d%02d_%02d%02d%02d_%s" % [
		datetime["year"],
		datetime["month"],
		datetime["day"],
		datetime["hour"],
		datetime["minute"],
		datetime["second"],
		_generate_short_uuid()
	]


func _generate_short_uuid() -> String:
	var chars := "abcdefghijklmnopqrstuvwxyz0123456789"
	var result := ""
	for i in range(6):
		result += chars[randi() % chars.length()]
	return result


func _compile_session_summary() -> Dictionary:
	var stats := MovementAnalytics.get_current_stats()
	var space_map := MovementTracker.get_space_map()
	var frames := MovementTracker.get_all_frames()

	var duration := Time.get_unix_time_from_system() - session_start_time

	return {
		"session_id": current_session_id,
		"start_time": session_start_time,
		"duration": duration,
		"frame_count": frames.size(),
		"stats": stats,
		"space_map_summary": {
			"coverage": space_map.get_coverage_percentage(),
			"symmetry": space_map.get_symmetry_score(),
			"directional": space_map.get_directional_coverage(),
			"unique_cells": space_map.unique_cells_visited
		},
		"hardware": {
			"hmd": XRServer.primary_interface.get_name() if XRServer.primary_interface else "Unknown",
			"tracking_hz": Engine.physics_ticks_per_second
		}
	}


func _save_session(summary: Dictionary) -> void:
	var file_path := SESSIONS_DIR + current_session_id + ".json"
	var file := FileAccess.open(file_path, FileAccess.WRITE)

	if file == null:
		push_error("[SessionManager] Failed to save session: ", FileAccess.get_open_error())
		return

	# Include frame data for detailed analysis (compressed)
	var full_data := summary.duplicate(true)

	# Sample frames to reduce file size (every 9th frame = ~10Hz)
	var frames := MovementTracker.get_all_frames()
	var sampled_frames: Array[Dictionary] = []
	for i in range(0, frames.size(), 9):
		sampled_frames.append(frames[i].to_dict())
	full_data["frames"] = sampled_frames

	# Include space map data
	full_data["space_map"] = MovementTracker.get_space_map().to_dict()

	file.store_string(JSON.stringify(full_data, "\t"))
	file.close()

	print("[SessionManager] Session saved: ", file_path)


func _load_session_file(file_path: String) -> Dictionary:
	var file := FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		return {}

	var json := JSON.new()
	var error := json.parse(file.get_as_text())
	file.close()

	if error != OK:
		push_error("[SessionManager] Failed to parse session file: ", file_path)
		return {}

	return json.data


func _update_lifetime_stats(summary: Dictionary) -> void:
	lifetime_stats["total_sessions"] += 1
	lifetime_stats["total_duration"] += summary.get("duration", 0.0)

	var stats: Dictionary = summary.get("stats", {})
	var distance: Dictionary = stats.get("distance", {})
	lifetime_stats["total_distance"] += distance.get("total", 0.0)

	var coverage: float = summary.get("space_map_summary", {}).get("coverage", 0.0)
	if coverage > lifetime_stats["best_coverage"]:
		lifetime_stats["best_coverage"] = coverage

	# Update streak
	var today := Time.get_date_string_from_system()
	var last_date: String = lifetime_stats["last_session_date"]

	if last_date.is_empty():
		lifetime_stats["daily_streak"] = 1
	elif last_date == today:
		pass  # Same day, streak unchanged
	elif _is_consecutive_day(last_date, today):
		lifetime_stats["daily_streak"] += 1
	else:
		lifetime_stats["daily_streak"] = 1

	lifetime_stats["last_session_date"] = today

	_save_lifetime_stats()
	_check_achievements(summary)


func _is_consecutive_day(date1: String, date2: String) -> bool:
	# Simple check - just compare if dates are one day apart
	var d1 := Time.get_unix_time_from_datetime_string(date1 + "T00:00:00")
	var d2 := Time.get_unix_time_from_datetime_string(date2 + "T00:00:00")
	var diff := abs(d2 - d1)
	return diff >= 86400 and diff < 172800  # Between 1 and 2 days


func _check_achievements(summary: Dictionary) -> void:
	var stats: Dictionary = summary.get("stats", {})
	var coverage: float = summary.get("space_map_summary", {}).get("coverage", 0.0)
	var directional: Dictionary = summary.get("space_map_summary", {}).get("directional", {})

	# Coverage achievements
	if coverage >= 25.0:
		unlock_achievement("coverage_25")
	if coverage >= 50.0:
		unlock_achievement("coverage_50")
	if coverage >= 75.0:
		unlock_achievement("coverage_75")
	if coverage >= 90.0:
		unlock_achievement("coverage_90")

	# Directional achievements
	if directional.get("overhead", 0.0) > 50.0:
		unlock_achievement("sky_reach")
	if directional.get("behind", 0.0) > 30.0:
		unlock_achievement("behind_back")
	if directional.get("below", 0.0) > 50.0:
		unlock_achievement("low_reach")

	# Symmetry achievement
	var symmetry: float = stats.get("symmetry", 0.0)
	if symmetry >= 95.0:
		unlock_achievement("perfect_symmetry")

	# Streak achievements
	if lifetime_stats["daily_streak"] >= 7:
		unlock_achievement("streak_7")
	if lifetime_stats["daily_streak"] >= 30:
		unlock_achievement("streak_30")

	# Pose achievements
	var poses: Array = stats.get("poses", [])
	if poses.size() > 0:
		unlock_achievement("first_pose")
	if "Meditation" in poses:
		unlock_achievement("meditation_master")


func _save_lifetime_stats() -> void:
	var file_path := ANALYTICS_DIR + "lifetime_stats.json"
	var file := FileAccess.open(file_path, FileAccess.WRITE)

	if file == null:
		push_error("[SessionManager] Failed to save lifetime stats")
		return

	file.store_string(JSON.stringify(lifetime_stats, "\t"))
	file.close()


func _load_lifetime_stats() -> void:
	var file_path := ANALYTICS_DIR + "lifetime_stats.json"
	var file := FileAccess.open(file_path, FileAccess.READ)

	if file == null:
		return  # No existing stats, use defaults

	var json := JSON.new()
	var error := json.parse(file.get_as_text())
	file.close()

	if error == OK and json.data is Dictionary:
		# Merge with defaults to handle new fields
		for key in json.data:
			lifetime_stats[key] = json.data[key]


func _save_settings() -> void:
	var file := FileAccess.open(SETTINGS_FILE, FileAccess.WRITE)

	if file == null:
		push_error("[SessionManager] Failed to save settings")
		return

	file.store_string(JSON.stringify(settings, "\t"))
	file.close()


func _load_settings() -> void:
	var file := FileAccess.open(SETTINGS_FILE, FileAccess.READ)

	if file == null:
		return  # No existing settings, use defaults

	var json := JSON.new()
	var error := json.parse(file.get_as_text())
	file.close()

	if error == OK and json.data is Dictionary:
		for key in json.data:
			if settings.has(key):
				settings[key] = json.data[key]

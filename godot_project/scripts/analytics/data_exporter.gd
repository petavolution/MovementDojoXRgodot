## DataExporter - Export movement and session data for external analysis
## Supports CSV, JSON, and custom formats for research/health apps
class_name DataExporter
extends Node

signal export_started(format: String)
signal export_progress(percent: float)
signal export_completed(file_path: String)
signal export_failed(error: String)

enum ExportFormat {
	JSON,
	CSV,
	CSV_DETAILED,
	SUMMARY_JSON,
	MOVEMENT_FRAMES,
	HEALTH_APP  # Format compatible with health tracking apps
}

const EXPORT_DIR := "user://exports/"

## Export options
class ExportOptions:
	var include_movement_frames: bool = true
	var include_analytics: bool = true
	var include_achievements: bool = true
	var include_challenges: bool = true
	var include_settings: bool = false
	var include_raw_positions: bool = false
	var anonymize: bool = false
	var date_range_start: int = 0  # Unix timestamp, 0 = all time
	var date_range_end: int = 0
	var compress: bool = false


## Reference to data sources
var session_manager: Node
var movement_tracker: Node
var challenge_system: Node


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(EXPORT_DIR)


func setup(sess_mgr: Node, mov_tracker: Node, chal_sys: Node = null) -> void:
	session_manager = sess_mgr
	movement_tracker = mov_tracker
	challenge_system = chal_sys


## Export session data
func export_sessions(format: ExportFormat, options: ExportOptions = null) -> String:
	if options == null:
		options = ExportOptions.new()

	export_started.emit(_format_name(format))

	var file_path := ""

	match format:
		ExportFormat.JSON:
			file_path = _export_json(options)
		ExportFormat.CSV:
			file_path = _export_csv(options)
		ExportFormat.CSV_DETAILED:
			file_path = _export_csv_detailed(options)
		ExportFormat.SUMMARY_JSON:
			file_path = _export_summary_json(options)
		ExportFormat.MOVEMENT_FRAMES:
			file_path = _export_movement_frames(options)
		ExportFormat.HEALTH_APP:
			file_path = _export_health_format(options)

	if file_path != "":
		export_completed.emit(file_path)
	else:
		export_failed.emit("Export failed")

	return file_path


func _export_json(options: ExportOptions) -> String:
	var data := _gather_all_data(options)

	var timestamp := Time.get_datetime_string_from_system().replace(":", "-")
	var filename := "movement_dojo_export_%s.json" % timestamp
	var path := EXPORT_DIR + filename

	var json_string := JSON.stringify(data, "\t")
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return ""

	file.store_string(json_string)
	file.close()

	return path


func _export_csv(options: ExportOptions) -> String:
	var timestamp := Time.get_datetime_string_from_system().replace(":", "-")
	var filename := "movement_dojo_sessions_%s.csv" % timestamp
	var path := EXPORT_DIR + filename

	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return ""

	# Header
	file.store_line("session_id,date,duration_minutes,targets_hit,accuracy,max_combo,score,calories,coverage_percent")

	# Get session data
	var sessions := _get_session_history(options)
	var total := sessions.size()

	for i in range(total):
		var session: Dictionary = sessions[i]
		var line := "%s,%s,%.1f,%d,%.1f,%d,%d,%.0f,%.1f" % [
			session.get("id", ""),
			session.get("date", ""),
			session.get("duration", 0.0) / 60.0,
			session.get("targets_hit", 0),
			session.get("accuracy", 0.0),
			session.get("max_combo", 0),
			session.get("score", 0),
			session.get("calories", 0.0),
			session.get("coverage", 0.0) * 100
		]
		file.store_line(line)
		export_progress.emit(float(i + 1) / total * 100)

	file.close()
	return path


func _export_csv_detailed(options: ExportOptions) -> String:
	var timestamp := Time.get_datetime_string_from_system().replace(":", "-")
	var filename := "movement_dojo_detailed_%s.csv" % timestamp
	var path := EXPORT_DIR + filename

	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return ""

	# Detailed header including movement data
	var headers := [
		"session_id", "timestamp_ms", "head_x", "head_y", "head_z",
		"left_hand_x", "left_hand_y", "left_hand_z",
		"right_hand_x", "right_hand_y", "right_hand_z",
		"left_velocity", "right_velocity", "symmetry_score"
	]
	file.store_line(",".join(headers))

	# Would iterate through recorded frames
	# This is a placeholder for the actual frame data export
	var frames := _get_movement_frames(options)
	var total := frames.size()

	for i in range(total):
		var frame: Dictionary = frames[i]
		var line := "%s,%d,%.4f,%.4f,%.4f,%.4f,%.4f,%.4f,%.4f,%.4f,%.4f,%.3f,%.3f,%.3f" % [
			frame.get("session_id", ""),
			frame.get("timestamp", 0),
			frame.get("head_pos", Vector3.ZERO).x,
			frame.get("head_pos", Vector3.ZERO).y,
			frame.get("head_pos", Vector3.ZERO).z,
			frame.get("left_pos", Vector3.ZERO).x,
			frame.get("left_pos", Vector3.ZERO).y,
			frame.get("left_pos", Vector3.ZERO).z,
			frame.get("right_pos", Vector3.ZERO).x,
			frame.get("right_pos", Vector3.ZERO).y,
			frame.get("right_pos", Vector3.ZERO).z,
			frame.get("left_vel", 0.0),
			frame.get("right_vel", 0.0),
			frame.get("symmetry", 0.0)
		]
		file.store_line(line)

		if i % 100 == 0:
			export_progress.emit(float(i + 1) / total * 100)

	file.close()
	return path


func _export_summary_json(options: ExportOptions) -> String:
	var data := {
		"export_date": Time.get_datetime_string_from_system(),
		"version": "1.0",
		"lifetime_stats": {},
		"recent_sessions": [],
		"achievements": [],
		"challenges": []
	}

	# Lifetime stats
	if session_manager and session_manager.has_method("get_lifetime_stats"):
		data.lifetime_stats = session_manager.get_lifetime_stats()

	# Recent sessions (last 30 days)
	var sessions := _get_session_history(options)
	var thirty_days_ago := Time.get_unix_time_from_system() - (30 * 86400)

	for session in sessions:
		if session.get("timestamp", 0) >= thirty_days_ago:
			data.recent_sessions.append(_summarize_session(session))

	# Achievements
	if options.include_achievements and session_manager:
		if session_manager.has_method("get_unlocked_achievements"):
			data.achievements = session_manager.get_unlocked_achievements()

	# Challenges
	if options.include_challenges and challenge_system:
		if challenge_system.has_method("get_completed_unclaimed"):
			var challenges := challenge_system.get_completed_unclaimed()
			for c in challenges:
				data.challenges.append(c.to_dict() if c.has_method("to_dict") else {})

	var timestamp := Time.get_datetime_string_from_system().replace(":", "-")
	var filename := "movement_dojo_summary_%s.json" % timestamp
	var path := EXPORT_DIR + filename

	var json_string := JSON.stringify(data, "\t")
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return ""

	file.store_string(json_string)
	file.close()

	return path


func _export_movement_frames(options: ExportOptions) -> String:
	var data := {
		"export_date": Time.get_datetime_string_from_system(),
		"format": "movement_frames",
		"sample_rate_hz": 90,
		"frames": []
	}

	var frames := _get_movement_frames(options)
	data.frames = frames

	var timestamp := Time.get_datetime_string_from_system().replace(":", "-")
	var filename := "movement_frames_%s.json" % timestamp
	var path := EXPORT_DIR + filename

	var json_string := JSON.stringify(data)
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return ""

	file.store_string(json_string)
	file.close()

	return path


func _export_health_format(options: ExportOptions) -> String:
	# Format compatible with health tracking apps
	var data := {
		"source": "Movement Dojo XR",
		"export_version": "1.0",
		"user_id": _get_anonymous_id() if options.anonymize else _get_user_id(),
		"activities": []
	}

	var sessions := _get_session_history(options)

	for session in sessions:
		var activity := {
			"type": "VR_FITNESS",
			"subtype": "MOVEMENT_TRAINING",
			"start_time": session.get("start_time", ""),
			"end_time": session.get("end_time", ""),
			"duration_seconds": session.get("duration", 0.0),
			"calories_burned": session.get("calories", 0.0),
			"metrics": {
				"movement_score": session.get("coverage", 0.0) * 100,
				"accuracy_percent": session.get("accuracy", 0.0),
				"active_minutes": session.get("duration", 0.0) / 60.0,
				"targets_hit": session.get("targets_hit", 0),
				"distance_meters": session.get("distance_moved", 0.0)
			}
		}
		data.activities.append(activity)

	var timestamp := Time.get_datetime_string_from_system().replace(":", "-")
	var filename := "health_export_%s.json" % timestamp
	var path := EXPORT_DIR + filename

	var json_string := JSON.stringify(data, "\t")
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return ""

	file.store_string(json_string)
	file.close()

	return path


func _gather_all_data(options: ExportOptions) -> Dictionary:
	var data := {
		"export_date": Time.get_datetime_string_from_system(),
		"version": "1.0"
	}

	if options.include_analytics:
		data["lifetime_stats"] = {}
		if session_manager and session_manager.has_method("get_lifetime_stats"):
			data["lifetime_stats"] = session_manager.get_lifetime_stats()

	data["sessions"] = _get_session_history(options)

	if options.include_achievements:
		data["achievements"] = []
		if session_manager and session_manager.has_method("get_unlocked_achievements"):
			data["achievements"] = session_manager.get_unlocked_achievements()

	if options.include_challenges and challenge_system:
		data["challenges"] = {
			"completed": [],
			"in_progress": []
		}

	if options.include_movement_frames:
		data["movement_frames"] = _get_movement_frames(options)

	return data


func _get_session_history(options: ExportOptions) -> Array:
	var sessions: Array = []

	if session_manager and session_manager.has_method("get_session_history"):
		sessions = session_manager.get_session_history()

	# Filter by date range
	if options.date_range_start > 0 or options.date_range_end > 0:
		var filtered: Array = []
		for session in sessions:
			var ts: int = session.get("timestamp", 0)
			if options.date_range_start > 0 and ts < options.date_range_start:
				continue
			if options.date_range_end > 0 and ts > options.date_range_end:
				continue
			filtered.append(session)
		sessions = filtered

	# Anonymize if requested
	if options.anonymize:
		for session in sessions:
			session.erase("user_id")
			session["id"] = _hash_id(session.get("id", ""))

	return sessions


func _get_movement_frames(options: ExportOptions) -> Array:
	# Would retrieve stored movement frame data
	# Placeholder implementation
	return []


func _summarize_session(session: Dictionary) -> Dictionary:
	return {
		"date": session.get("date", ""),
		"duration_minutes": session.get("duration", 0.0) / 60.0,
		"score": session.get("score", 0),
		"accuracy": session.get("accuracy", 0.0),
		"calories": session.get("calories", 0.0)
	}


func _get_user_id() -> String:
	# Return stored user ID or generate one
	return "user_" + str(hash(OS.get_unique_id()))


func _get_anonymous_id() -> String:
	return "anon_" + str(randi())


func _hash_id(original: String) -> String:
	return str(hash(original))


func _format_name(format: ExportFormat) -> String:
	match format:
		ExportFormat.JSON: return "JSON"
		ExportFormat.CSV: return "CSV"
		ExportFormat.CSV_DETAILED: return "CSV Detailed"
		ExportFormat.SUMMARY_JSON: return "Summary JSON"
		ExportFormat.MOVEMENT_FRAMES: return "Movement Frames"
		ExportFormat.HEALTH_APP: return "Health App Format"
	return "Unknown"


## Get list of existing exports
func get_export_files() -> Array[String]:
	var files: Array[String] = []
	var dir := DirAccess.open(EXPORT_DIR)
	if dir:
		dir.list_dir_begin()
		var filename := dir.get_next()
		while filename != "":
			if not dir.current_is_dir():
				files.append(filename)
			filename = dir.get_next()
		dir.list_dir_end()

	return files


## Delete an export file
func delete_export(filename: String) -> bool:
	var path := EXPORT_DIR + filename
	return DirAccess.remove_absolute(path) == OK


## Get full path for an export
func get_export_path(filename: String) -> String:
	return ProjectSettings.globalize_path(EXPORT_DIR + filename)

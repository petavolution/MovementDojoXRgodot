## DebugLogger - Centralized logging system for VR dojo combat debugging
## Writes all debug output to configurable log file with optional console mirror
## Autoloaded as first system for early error capture
##
## Features:
## - TRACE/DEBUG/INFO/WARN/ERROR/FATAL log levels
## - Configurable file path and log levels
## - Thread-safe writes with Mutex
## - XR-specific diagnostic helpers
## - Millisecond timestamps for combat debugging
## - Automatic log rotation
## - Startup diagnostic report
extends Node
class_name DebugLoggerClass

# =============================================================================
# LOG LEVELS
# =============================================================================

enum Level {
	TRACE = 0,  # Finest detail (frame-by-frame, pose data)
	DEBUG = 1,  # Development debugging
	INFO = 2,   # Normal operation events
	WARN = 3,   # Potential issues
	ERROR = 4,  # Recoverable errors
	FATAL = 5   # Unrecoverable errors
}

# =============================================================================
# CONFIGURATION
# =============================================================================

## Default configuration - can be overridden via set_config()
const DEFAULT_CONFIG := {
	"log_file_path": "user://logs/engine.log",
	"max_log_size_mb": 10,
	"file_log_level": Level.TRACE,
	"console_log_level": Level.DEBUG,
	"enable_console": true,
	"enable_file": true,
	"include_milliseconds": true,
	"flush_on_error": true,
	"max_early_buffer": 1000,
}

# Subsystem filters (empty = log all, otherwise only listed subsystems)
var _subsystem_filter: Array[String] = []
var _subsystem_mute: Array[String] = []  # Explicitly muted subsystems

# =============================================================================
# INTERNAL STATE
# =============================================================================

# Singleton instance (set in _init for earliest access)
static var instance: DebugLoggerClass

# Configuration
var _config: Dictionary = DEFAULT_CONFIG.duplicate()

# File handling
var _log_file: FileAccess
var _log_path: String
var _file_ready := false

# Thread safety
var _mutex: Mutex

# Session tracking
var _session_id: String
var _session_start_time: int
var _message_count: int = 0

# Buffer for early messages (before file is ready)
var _early_buffer: Array[String] = []

# XR diagnostic cache
var _xr_diagnostic_cache: Dictionary = {}

# =============================================================================
# LIFECYCLE
# =============================================================================

func _init() -> void:
	instance = self
	_mutex = Mutex.new()
	_session_start_time = Time.get_ticks_msec()


func _ready() -> void:
	_setup_log_file()
	_write_session_header()
	_flush_early_buffer()

	# Engine startup marker
	info("Engine", "=== STARTUP BEGIN ===")
	info("Engine", "Godot %s on %s" % [Engine.get_version_info().string, OS.get_name()])
	info("Engine", "Log file: %s" % _log_path)
	info("Engine", "File level: %s, Console level: %s" % [
		_level_to_string(_config.file_log_level),
		_level_to_string(_config.console_log_level)
	])

	# Deferred startup validation (after all autoloads)
	call_deferred("_run_startup_diagnostics")


func _exit_tree() -> void:
	info("Engine", "=== SHUTDOWN BEGIN ===")
	_write_shutdown_summary()
	info("Engine", "=== SHUTDOWN COMPLETE ===")
	_close_log_file()
	if instance == self:
		instance = null


func _notification(what: int) -> void:
	# Ensure flush on various exit conditions
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		warn("Engine", "Window close requested - flushing logs")
		flush()
	elif what == NOTIFICATION_CRASH:
		fatal("Engine", "CRASH DETECTED - attempting log flush")
		flush()


# =============================================================================
# PUBLIC API - LOGGING
# =============================================================================

## Log trace message (finest detail, for frame-by-frame debugging)
static func trace(source: String, message: String) -> void:
	if instance:
		instance._log(Level.TRACE, source, message)


## Log debug message
static func debug(source: String, message: String) -> void:
	if instance:
		instance._log(Level.DEBUG, source, message)
	else:
		print("[DEBUG] [%s] %s" % [source, message])


## Log info message
static func info(source: String, message: String) -> void:
	if instance:
		instance._log(Level.INFO, source, message)
	else:
		print("[INFO] [%s] %s" % [source, message])


## Log warning message
static func warn(source: String, message: String) -> void:
	if instance:
		instance._log(Level.WARN, source, message)
	else:
		push_warning("[%s] %s" % [source, message])


## Log error message
static func error(source: String, message: String) -> void:
	if instance:
		instance._log(Level.ERROR, source, message)
	else:
		push_error("[%s] %s" % [source, message])


## Log fatal error
static func fatal(source: String, message: String) -> void:
	if instance:
		instance._log(Level.FATAL, source, message)
	push_error("[FATAL] [%s] %s" % [source, message])


## Log with explicit level
static func log_level(level: Level, source: String, message: String) -> void:
	if instance:
		instance._log(level, source, message)


## Log exception with stack trace
static func exception(source: String, message: String, error_info: Variant = null) -> void:
	var full_message := message
	if error_info != null:
		full_message += "\n  Error: %s" % str(error_info)

	var stack := get_stack()
	if stack.size() > 1:
		full_message += "\n  Stack trace:"
		for i in range(1, mini(stack.size(), 10)):
			var frame: Dictionary = stack[i]
			full_message += "\n    %s:%d in %s()" % [
				frame.get("source", "unknown"),
				frame.get("line", 0),
				frame.get("function", "unknown")
			]

	error(source, full_message)


# =============================================================================
# PUBLIC API - XR DIAGNOSTICS
# =============================================================================

## Log XR runtime information
static func xr_runtime(runtime_name: String, version: String, is_active: bool) -> void:
	if instance:
		var status := "ACTIVE" if is_active else "available"
		instance._log(Level.INFO, "XR", "Runtime: %s v%s [%s]" % [runtime_name, version, status])
		instance._xr_diagnostic_cache["runtime"] = runtime_name
		instance._xr_diagnostic_cache["runtime_version"] = version


## Log XR interface status
static func xr_interface_status(interface_name: String, initialized: bool, error_msg: String = "") -> void:
	if instance:
		if initialized:
			instance._log(Level.INFO, "XR", "Interface '%s' initialized successfully" % interface_name)
		else:
			var msg := "Interface '%s' failed to initialize" % interface_name
			if error_msg:
				msg += ": %s" % error_msg
			instance._log(Level.ERROR, "XR", msg)


## Log HMD tracking status
static func xr_hmd_status(tracked: bool, pose_valid: bool, tracking_confidence: float = -1.0) -> void:
	if instance:
		var level := Level.INFO if tracked else Level.WARN
		var msg := "HMD: tracked=%s pose_valid=%s" % [tracked, pose_valid]
		if tracking_confidence >= 0:
			msg += " confidence=%.2f" % tracking_confidence
		instance._log(level, "XR", msg)
		instance._xr_diagnostic_cache["hmd_tracked"] = tracked


## Log controller status
static func xr_controller_status(hand: String, bound: bool, tracked: bool, tracking_confidence: float = -1.0) -> void:
	if instance:
		var level := Level.INFO if (bound and tracked) else Level.WARN
		var msg := "Controller %s: bound=%s tracked=%s" % [hand, bound, tracked]
		if tracking_confidence >= 0:
			msg += " confidence=%.2f" % tracking_confidence
		instance._log(level, "XR", msg)
		instance._xr_diagnostic_cache["%s_controller_bound" % hand] = bound
		instance._xr_diagnostic_cache["%s_controller_tracked" % hand] = tracked


## Log display/refresh rate info
static func xr_display_info(refresh_rate: float, resolution: Vector2i, foveation_level: int = -1) -> void:
	if instance:
		var msg := "Display: %.0fHz %dx%d" % [refresh_rate, resolution.x, resolution.y]
		if foveation_level >= 0:
			msg += " foveation=%d" % foveation_level
		instance._log(Level.INFO, "XR", msg)
		instance._xr_diagnostic_cache["refresh_rate"] = refresh_rate


## Log play area/boundary info
static func xr_play_area(size: Vector2, configured: bool) -> void:
	if instance:
		if configured:
			instance._log(Level.INFO, "XR", "Play area: %.1fm x %.1fm" % [size.x, size.y])
		else:
			instance._log(Level.WARN, "XR", "Play area: NOT CONFIGURED")
		instance._xr_diagnostic_cache["play_area_configured"] = configured


## Log full XR diagnostic report
static func xr_diagnostic_report() -> void:
	if instance:
		instance._log(Level.INFO, "XR", "=== XR DIAGNOSTIC REPORT ===")
		for key in instance._xr_diagnostic_cache:
			instance._log(Level.INFO, "XR", "  %s: %s" % [key, instance._xr_diagnostic_cache[key]])
		instance._log(Level.INFO, "XR", "=== END REPORT ===")


# =============================================================================
# PUBLIC API - COMBAT EVENT LOGGING (for future dojo systems)
# =============================================================================

## Log combat event (designed for high-frequency dojo combat)
static func combat_event(event_type: String, details: Dictionary = {}) -> void:
	if instance:
		var msg := event_type
		if not details.is_empty():
			var parts: Array[String] = []
			for key in details:
				parts.append("%s=%s" % [key, details[key]])
			msg += " {%s}" % ", ".join(parts)
		instance._log(Level.DEBUG, "Combat", msg)


## Log tracking pose (TRACE level for frame-by-frame debugging)
static func pose_trace(device: String, position: Vector3, rotation: Quaternion) -> void:
	if instance:
		instance._log(Level.TRACE, "Pose", "%s pos=(%.3f,%.3f,%.3f) rot=(%.3f,%.3f,%.3f,%.3f)" % [
			device, position.x, position.y, position.z,
			rotation.x, rotation.y, rotation.z, rotation.w
		])


# =============================================================================
# PUBLIC API - CONFIGURATION
# =============================================================================

## Update configuration
static func set_config(key: String, value: Variant) -> void:
	if instance and key in instance._config:
		instance._config[key] = value
		instance._log(Level.DEBUG, "Logger", "Config updated: %s = %s" % [key, value])


## Get configuration value
static func get_config(key: String) -> Variant:
	if instance and key in instance._config:
		return instance._config[key]
	return null


## Set minimum log level for file output
static func set_file_level(level: Level) -> void:
	if instance:
		instance._config.file_log_level = level


## Set minimum log level for console output
static func set_console_level(level: Level) -> void:
	if instance:
		instance._config.console_log_level = level


## Enable/disable console output
static func set_console_enabled(enabled: bool) -> void:
	if instance:
		instance._config.enable_console = enabled


## Filter to only log specific subsystems (empty = log all)
static func set_subsystem_filter(subsystems: Array[String]) -> void:
	if instance:
		instance._subsystem_filter = subsystems


## Mute specific subsystems
static func mute_subsystem(subsystem: String) -> void:
	if instance and subsystem not in instance._subsystem_mute:
		instance._subsystem_mute.append(subsystem)


## Unmute subsystem
static func unmute_subsystem(subsystem: String) -> void:
	if instance:
		instance._subsystem_mute.erase(subsystem)


## Get current log file path
static func get_log_path() -> String:
	if instance:
		return instance._log_path
	return ""


## Get session ID
static func get_session_id() -> String:
	if instance:
		return instance._session_id
	return ""


## Force flush to disk
static func flush() -> void:
	if instance:
		instance._flush()


# =============================================================================
# INTERNAL - CORE LOGGING
# =============================================================================

func _log(level: Level, source: String, message: String) -> void:
	# Subsystem filtering
	if source in _subsystem_mute:
		return
	if not _subsystem_filter.is_empty() and source not in _subsystem_filter:
		return

	# Thread-safe timestamp and formatting
	_mutex.lock()

	var timestamp := _get_timestamp()
	var level_str := _level_to_string(level)
	var formatted := "[%s] [%-5s] [%s] %s" % [timestamp, level_str, source, message]

	# Console output
	if _config.enable_console and level >= _config.console_log_level:
		match level:
			Level.TRACE, Level.DEBUG, Level.INFO:
				print(formatted)
			Level.WARN:
				push_warning(formatted)
			Level.ERROR, Level.FATAL:
				push_error(formatted)

	# File output
	if _config.enable_file and level >= _config.file_log_level:
		_write_to_file(formatted)

		# Flush on errors
		if _config.flush_on_error and level >= Level.ERROR:
			_flush_internal()

	_message_count += 1
	_mutex.unlock()


func _write_to_file(line: String) -> void:
	if not _file_ready:
		if _early_buffer.size() < _config.max_early_buffer:
			_early_buffer.append(line)
		return

	if _log_file:
		_log_file.store_line(line)


func _flush() -> void:
	_mutex.lock()
	_flush_internal()
	_mutex.unlock()


func _flush_internal() -> void:
	if _log_file:
		_log_file.flush()


# =============================================================================
# INTERNAL - FILE MANAGEMENT
# =============================================================================

func _setup_log_file() -> void:
	var log_path_setting: String = _config.log_file_path

	# Resolve user:// to actual path
	if log_path_setting.begins_with("user://"):
		_log_path = log_path_setting.replace("user://", OS.get_user_data_dir() + "/")
	else:
		_log_path = log_path_setting

	# Ensure directory exists
	var dir_path := _log_path.get_base_dir()
	var dir := DirAccess.open("res://")
	if dir:
		dir.make_dir_recursive(dir_path)
	else:
		DirAccess.make_dir_recursive_absolute(dir_path)

	# Rotate log if too large
	var max_size := _config.max_log_size_mb * 1024 * 1024
	if FileAccess.file_exists(_log_path):
		var file := FileAccess.open(_log_path, FileAccess.READ)
		if file:
			var size := file.get_length()
			file.close()
			if size > max_size:
				_rotate_log()

	# Open log file
	_log_file = FileAccess.open(_log_path, FileAccess.READ_WRITE)
	if _log_file == null:
		_log_file = FileAccess.open(_log_path, FileAccess.WRITE)

	if _log_file:
		_log_file.seek_end()
		_file_ready = true
	else:
		push_error("DebugLogger: Failed to open log file: %s (error: %d)" % [
			_log_path, FileAccess.get_open_error()
		])


func _rotate_log() -> void:
	# Keep last 3 rotations
	for i in range(2, 0, -1):
		var old_path := "%s.%d" % [_log_path, i]
		var new_path := "%s.%d" % [_log_path, i + 1]
		if FileAccess.file_exists(old_path):
			if FileAccess.file_exists(new_path):
				DirAccess.remove_absolute(new_path)
			DirAccess.rename_absolute(old_path, new_path)

	# Move current to .1
	var backup_path := "%s.1" % _log_path
	if FileAccess.file_exists(_log_path):
		DirAccess.rename_absolute(_log_path, backup_path)


func _write_session_header() -> void:
	if not _log_file:
		return

	_session_id = _generate_session_id()
	var datetime := Time.get_datetime_dict_from_system()

	var header := """

================================================================================
SESSION: %s
DATE: %04d-%02d-%02d %02d:%02d:%02d
ENGINE: Godot %s
PLATFORM: %s
================================================================================
""" % [
		_session_id,
		datetime.year, datetime.month, datetime.day,
		datetime.hour, datetime.minute, datetime.second,
		Engine.get_version_info().string,
		OS.get_name()
	]

	_log_file.store_string(header)
	_log_file.flush()


func _write_shutdown_summary() -> void:
	var uptime_ms := Time.get_ticks_msec() - _session_start_time
	var uptime_sec := uptime_ms / 1000.0

	info("Engine", "Session duration: %.1f seconds" % uptime_sec)
	info("Engine", "Total log messages: %d" % _message_count)


func _close_log_file() -> void:
	if _log_file:
		_log_file.store_line("")
		_log_file.store_line("[%s] [INFO ] [Engine] Log file closed" % _get_timestamp())
		_log_file.store_line("")
		_log_file.flush()
		_log_file.close()
		_log_file = null
	_file_ready = false


func _flush_early_buffer() -> void:
	for line in _early_buffer:
		_write_to_file(line)
	_early_buffer.clear()


# =============================================================================
# INTERNAL - UTILITIES
# =============================================================================

func _get_timestamp() -> String:
	var datetime := Time.get_datetime_dict_from_system()
	var msec := Time.get_ticks_msec() % 1000

	if _config.include_milliseconds:
		return "%04d-%02d-%02d %02d:%02d:%02d.%03d" % [
			datetime.year, datetime.month, datetime.day,
			datetime.hour, datetime.minute, datetime.second,
			msec
		]
	else:
		return "%04d-%02d-%02d %02d:%02d:%02d" % [
			datetime.year, datetime.month, datetime.day,
			datetime.hour, datetime.minute, datetime.second
		]


func _level_to_string(level: Level) -> String:
	match level:
		Level.TRACE: return "TRACE"
		Level.DEBUG: return "DEBUG"
		Level.INFO: return "INFO"
		Level.WARN: return "WARN"
		Level.ERROR: return "ERROR"
		Level.FATAL: return "FATAL"
	return "?????"


func _generate_session_id() -> String:
	var datetime := Time.get_datetime_dict_from_system()
	var random_suffix := randi() % 10000
	return "%04d%02d%02d_%02d%02d%02d_%04d" % [
		datetime.year, datetime.month, datetime.day,
		datetime.hour, datetime.minute, datetime.second,
		random_suffix
	]


# =============================================================================
# STARTUP DIAGNOSTICS
# =============================================================================

func _run_startup_diagnostics() -> void:
	info("Engine", "--- Startup Diagnostics ---")

	# Check autoloads
	var required_autoloads := ["GameEvents", "XRInputManager", "MovementTracker", "SessionManager"]
	var missing: Array[String] = []

	for autoload_name in required_autoloads:
		if get_node_or_null("/root/%s" % autoload_name):
			debug("Engine", "  Autoload OK: %s" % autoload_name)
		else:
			missing.append(autoload_name)
			error("Engine", "  Autoload MISSING: %s" % autoload_name)

	if missing.is_empty():
		info("Engine", "All %d autoloads loaded successfully" % required_autoloads.size())
	else:
		error("Engine", "STARTUP FAILED: Missing autoloads: %s" % ", ".join(missing))

	# XR Interface check
	_check_xr_availability()

	info("Engine", "--- End Diagnostics ---")


func _check_xr_availability() -> void:
	var xr_interface := XRServer.find_interface("OpenXR")

	if xr_interface == null:
		warn("XR", "OpenXR interface not found - desktop mode only")
		_xr_diagnostic_cache["openxr_available"] = false
		return

	_xr_diagnostic_cache["openxr_available"] = true
	info("XR", "OpenXR interface found")

	# Log available capabilities
	if xr_interface.is_initialized():
		info("XR", "OpenXR already initialized")

		var refresh_rate := xr_interface.get_display_refresh_rate()
		if refresh_rate > 0:
			xr_display_info(refresh_rate, DisplayServer.window_get_size())

		# Check play area
		if xr_interface.has_method("get_play_area"):
			var play_area: PackedVector3Array = xr_interface.get_play_area()
			if play_area.size() >= 3:
				var min_x := INF
				var max_x := -INF
				var min_z := INF
				var max_z := -INF
				for point in play_area:
					min_x = minf(min_x, point.x)
					max_x = maxf(max_x, point.x)
					min_z = minf(min_z, point.z)
					max_z = maxf(max_z, point.z)
				xr_play_area(Vector2(max_x - min_x, max_z - min_z), true)
			else:
				xr_play_area(Vector2.ZERO, false)
	else:
		info("XR", "OpenXR available but not yet initialized")

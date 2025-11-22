## DebugLogger - Centralized logging with file output
## Writes all debug output to both console and debug-log.txt
## Autoloaded as first system for early error capture
extends Node
class_name DebugLogger

enum Level { DEBUG, INFO, WARN, ERROR, FATAL }

const LOG_FILE := "user://debug-log.txt"
const MAX_LOG_SIZE := 5 * 1024 * 1024  # 5MB max log file size
const TIMESTAMP_FORMAT := "%04d-%02d-%02d %02d:%02d:%02d"

# Singleton instance
static var instance: DebugLogger

# File handle
var _log_file: FileAccess
var _log_path: String
var _session_id: String
var _log_level: Level = Level.DEBUG

# Buffer for early messages (before file is ready)
var _early_buffer: Array[String] = []
var _file_ready := false


func _init() -> void:
	# Set singleton early
	instance = self


func _ready() -> void:
	_setup_log_file()
	_write_session_header()
	_flush_early_buffer()

	# Log system info
	info("DebugLogger", "Logging initialized")
	info("DebugLogger", "Godot version: %s" % Engine.get_version_info().string)
	info("DebugLogger", "OS: %s" % OS.get_name())


func _exit_tree() -> void:
	info("DebugLogger", "Session ending")
	_close_log_file()
	if instance == self:
		instance = null


# =============================================================================
# PUBLIC API
# =============================================================================

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


## Log fatal error (will also push_error)
static func fatal(source: String, message: String) -> void:
	if instance:
		instance._log(Level.FATAL, source, message)
	push_error("[FATAL] [%s] %s" % [source, message])


## Log exception/error with stack trace
static func exception(source: String, message: String, error_info: Variant = null) -> void:
	var full_message := message
	if error_info != null:
		full_message += "\n  Error: %s" % str(error_info)

	# Get stack trace
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


## Set minimum log level
static func set_level(level: Level) -> void:
	if instance:
		instance._log_level = level


## Get current log file path
static func get_log_path() -> String:
	if instance:
		return instance._log_path
	return ""


## Force flush to disk
static func flush() -> void:
	if instance and instance._log_file:
		instance._log_file.flush()


# =============================================================================
# INTERNAL
# =============================================================================

func _log(level: Level, source: String, message: String) -> void:
	if level < _log_level:
		return

	var timestamp := _get_timestamp()
	var level_str := _level_to_string(level)
	var formatted := "[%s] [%s] [%s] %s" % [timestamp, level_str, source, message]

	# Console output
	match level:
		Level.DEBUG:
			print(formatted)
		Level.INFO:
			print(formatted)
		Level.WARN:
			push_warning(formatted)
		Level.ERROR, Level.FATAL:
			push_error(formatted)

	# File output
	_write_to_file(formatted)


func _write_to_file(line: String) -> void:
	if not _file_ready:
		_early_buffer.append(line)
		return

	if _log_file:
		_log_file.store_line(line)
		# Flush on errors for immediate visibility
		if "[ERROR]" in line or "[FATAL]" in line:
			_log_file.flush()


func _setup_log_file() -> void:
	_log_path = LOG_FILE.replace("user://", OS.get_user_data_dir() + "/")

	# Ensure directory exists
	var dir_path := _log_path.get_base_dir()
	DirAccess.make_dir_recursive_absolute(dir_path)

	# Rotate log if too large
	if FileAccess.file_exists(_log_path):
		var size := FileAccess.get_file_as_bytes(_log_path).size()
		if size > MAX_LOG_SIZE:
			_rotate_log()

	# Open log file (append mode)
	_log_file = FileAccess.open(_log_path, FileAccess.READ_WRITE)
	if _log_file == null:
		# Try creating new file
		_log_file = FileAccess.open(_log_path, FileAccess.WRITE)

	if _log_file:
		_log_file.seek_end()
		_file_ready = true
	else:
		push_error("DebugLogger: Failed to open log file: %s" % _log_path)


func _rotate_log() -> void:
	var backup_path := _log_path + ".old"

	# Remove old backup
	if FileAccess.file_exists(backup_path):
		DirAccess.remove_absolute(backup_path)

	# Rename current to backup
	DirAccess.rename_absolute(_log_path, backup_path)


func _write_session_header() -> void:
	if not _log_file:
		return

	_session_id = _generate_session_id()
	var datetime := Time.get_datetime_dict_from_system()

	_log_file.store_line("")
	_log_file.store_line("=" .repeat(80))
	_log_file.store_line("SESSION: %s" % _session_id)
	_log_file.store_line("DATE: %04d-%02d-%02d %02d:%02d:%02d" % [
		datetime.year, datetime.month, datetime.day,
		datetime.hour, datetime.minute, datetime.second
	])
	_log_file.store_line("=" .repeat(80))
	_log_file.store_line("")
	_log_file.flush()


func _flush_early_buffer() -> void:
	for line in _early_buffer:
		_write_to_file(line)
	_early_buffer.clear()


func _close_log_file() -> void:
	if _log_file:
		_log_file.store_line("")
		_log_file.store_line("[%s] [INFO] [DebugLogger] Session closed" % _get_timestamp())
		_log_file.store_line("")
		_log_file.flush()
		_log_file.close()
		_log_file = null
	_file_ready = false


func _get_timestamp() -> String:
	var datetime := Time.get_datetime_dict_from_system()
	return TIMESTAMP_FORMAT % [
		datetime.year, datetime.month, datetime.day,
		datetime.hour, datetime.minute, datetime.second
	]


func _level_to_string(level: Level) -> String:
	match level:
		Level.DEBUG: return "DEBUG"
		Level.INFO: return "INFO"
		Level.WARN: return "WARN"
		Level.ERROR: return "ERROR"
		Level.FATAL: return "FATAL"
	return "UNKNOWN"


func _generate_session_id() -> String:
	var datetime := Time.get_datetime_dict_from_system()
	return "%04d%02d%02d_%02d%02d%02d" % [
		datetime.year, datetime.month, datetime.day,
		datetime.hour, datetime.minute, datetime.second
	]

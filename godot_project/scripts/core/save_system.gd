## SaveSystem - Robust data persistence with backup and validation
## Handles all game data saving/loading with integrity checks
class_name SaveSystem
extends Node

signal save_started
signal save_completed(success: bool)
signal load_started
signal load_completed(success: bool)
signal backup_created(backup_path: String)
signal data_corrupted(file_path: String)
signal save_slot_changed(slot: int)

const SAVE_DIR := "user://saves/"
const BACKUP_DIR := "user://backups/"
const MAX_BACKUPS := 5
const SAVE_VERSION := 2

## Save slot management
var current_slot: int = 0
var auto_save_enabled: bool = true
var auto_save_interval: float = 300.0  # 5 minutes
var auto_save_timer: float = 0.0

## Data sections
var player_data: Dictionary = {}
var session_data: Dictionary = {}
var achievement_data: Dictionary = {}
var settings_data: Dictionary = {}
var progress_data: Dictionary = {}

## Checksums for integrity
var data_checksums: Dictionary = {}


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)
	DirAccess.make_dir_recursive_absolute(BACKUP_DIR)


func _process(delta: float) -> void:
	if auto_save_enabled:
		auto_save_timer += delta
		if auto_save_timer >= auto_save_interval:
			auto_save_timer = 0.0
			auto_save()


## Save all game data
func save_game(slot: int = -1) -> bool:
	if slot < 0:
		slot = current_slot

	save_started.emit()

	var save_data := _gather_all_data()

	# Add metadata
	save_data["meta"] = {
		"version": SAVE_VERSION,
		"timestamp": Time.get_unix_time_from_system(),
		"datetime": Time.get_datetime_string_from_system(),
		"playtime": progress_data.get("total_playtime", 0.0),
		"checksum": _calculate_checksum(save_data)
	}

	var file_path := _get_save_path(slot)
	var success := _write_save_file(file_path, save_data)

	if success:
		# Create backup periodically
		_maybe_create_backup(slot)

	save_completed.emit(success)
	return success


## Load game data
func load_game(slot: int = -1) -> bool:
	if slot < 0:
		slot = current_slot

	load_started.emit()

	var file_path := _get_save_path(slot)
	var save_data := _read_save_file(file_path)

	if save_data.is_empty():
		# Try loading from backup
		save_data = _load_from_backup(slot)
		if save_data.is_empty():
			load_completed.emit(false)
			return false

	# Validate checksum
	var stored_checksum: String = save_data.get("meta", {}).get("checksum", "")
	save_data.meta.erase("checksum")
	var calculated_checksum := _calculate_checksum(save_data)

	if stored_checksum != "" and stored_checksum != calculated_checksum:
		push_warning("Save data checksum mismatch - data may be corrupted")
		data_corrupted.emit(file_path)
		# Still try to load, but warn user

	# Version migration
	var version: int = save_data.get("meta", {}).get("version", 1)
	if version < SAVE_VERSION:
		save_data = _migrate_save_data(save_data, version)

	# Apply loaded data
	_apply_loaded_data(save_data)

	current_slot = slot
	load_completed.emit(true)
	return true


## Auto-save
func auto_save() -> void:
	save_game(current_slot)


## Quick save
func quick_save() -> void:
	save_game(99)  # Special quick save slot


## Quick load
func quick_load() -> bool:
	return load_game(99)


## Create new save slot
func create_new_game(slot: int) -> void:
	_reset_all_data()
	current_slot = slot
	save_slot_changed.emit(slot)
	save_game(slot)


## Delete save slot
func delete_save(slot: int) -> bool:
	var file_path := _get_save_path(slot)
	if FileAccess.file_exists(file_path):
		return DirAccess.remove_absolute(file_path) == OK
	return false


## Check if save exists
func save_exists(slot: int) -> bool:
	return FileAccess.file_exists(_get_save_path(slot))


## Get save info without loading
func get_save_info(slot: int) -> Dictionary:
	var file_path := _get_save_path(slot)

	if not FileAccess.file_exists(file_path):
		return {}

	var file := FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		return {}

	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		file.close()
		return {}
	file.close()

	var data: Dictionary = json.data
	var meta: Dictionary = data.get("meta", {})
	var progress: Dictionary = data.get("progress", {})

	return {
		"slot": slot,
		"datetime": meta.get("datetime", "Unknown"),
		"playtime": meta.get("playtime", 0.0),
		"level": progress.get("player_level", 1),
		"completion": progress.get("story_completion", 0.0),
		"version": meta.get("version", 1)
	}


## Get all save slot info
func get_all_saves() -> Array[Dictionary]:
	var saves: Array[Dictionary] = []

	for slot in range(10):  # Support 10 save slots
		if save_exists(slot):
			saves.append(get_save_info(slot))

	return saves


func _gather_all_data() -> Dictionary:
	return {
		"player": player_data.duplicate(true),
		"session": session_data.duplicate(true),
		"achievements": achievement_data.duplicate(true),
		"settings": settings_data.duplicate(true),
		"progress": progress_data.duplicate(true)
	}


func _apply_loaded_data(data: Dictionary) -> void:
	player_data = data.get("player", {})
	session_data = data.get("session", {})
	achievement_data = data.get("achievements", {})
	settings_data = data.get("settings", {})
	progress_data = data.get("progress", {})


func _reset_all_data() -> void:
	player_data = {
		"name": "Player",
		"created": Time.get_unix_time_from_system()
	}
	session_data = {}
	achievement_data = {"unlocked": []}
	settings_data = {}
	progress_data = {
		"total_playtime": 0.0,
		"sessions_completed": 0,
		"player_level": 1,
		"experience": 0,
		"story_completion": 0.0
	}


func _get_save_path(slot: int) -> String:
	return SAVE_DIR + "save_slot_%d.json" % slot


func _get_backup_path(slot: int, index: int) -> String:
	return BACKUP_DIR + "save_slot_%d_backup_%d.json" % [slot, index]


func _write_save_file(path: String, data: Dictionary) -> bool:
	var json_string := JSON.stringify(data, "\t")

	# Write to temp file first
	var temp_path := path + ".tmp"
	var file := FileAccess.open(temp_path, FileAccess.WRITE)
	if file == null:
		push_error("Failed to create save file: " + temp_path)
		return false

	file.store_string(json_string)
	file.close()

	# Verify temp file is valid
	var verify := FileAccess.open(temp_path, FileAccess.READ)
	if verify == null:
		push_error("Failed to verify save file")
		return false

	var verify_json := JSON.new()
	if verify_json.parse(verify.get_as_text()) != OK:
		push_error("Save file verification failed - JSON invalid")
		verify.close()
		DirAccess.remove_absolute(temp_path)
		return false
	verify.close()

	# Rename temp to actual save file (atomic on most systems)
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)

	var dir := DirAccess.open(SAVE_DIR)
	if dir:
		dir.rename(temp_path.get_file(), path.get_file())

	return true


func _read_save_file(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}

	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}

	var json_string := file.get_as_text()
	file.close()

	var json := JSON.new()
	if json.parse(json_string) != OK:
		push_error("Failed to parse save file: " + json.get_error_message())
		return {}

	return json.data


func _calculate_checksum(data: Dictionary) -> String:
	# Simple checksum based on JSON string hash
	var json_string := JSON.stringify(data)
	return str(hash(json_string))


func _migrate_save_data(data: Dictionary, from_version: int) -> Dictionary:
	# Handle save file migrations between versions
	if from_version < 2:
		# Migration from v1 to v2
		if not data.has("progress"):
			data["progress"] = {}
		if not data.progress.has("player_level"):
			data.progress["player_level"] = 1
		if not data.progress.has("experience"):
			data.progress["experience"] = 0

	return data


func _maybe_create_backup(slot: int) -> void:
	# Create backup every 5 saves
	var backup_counter := progress_data.get("backup_counter", 0)
	backup_counter += 1

	if backup_counter >= 5:
		backup_counter = 0
		_create_backup(slot)

	progress_data["backup_counter"] = backup_counter


func _create_backup(slot: int) -> void:
	var source_path := _get_save_path(slot)
	if not FileAccess.file_exists(source_path):
		return

	# Rotate backups (keep last MAX_BACKUPS)
	for i in range(MAX_BACKUPS - 1, 0, -1):
		var old_path := _get_backup_path(slot, i - 1)
		var new_path := _get_backup_path(slot, i)
		if FileAccess.file_exists(old_path):
			if FileAccess.file_exists(new_path):
				DirAccess.remove_absolute(new_path)
			var dir := DirAccess.open(BACKUP_DIR)
			if dir:
				dir.rename(old_path.get_file(), new_path.get_file())

	# Copy current save to backup 0
	var backup_path := _get_backup_path(slot, 0)
	var source := FileAccess.open(source_path, FileAccess.READ)
	var backup := FileAccess.open(backup_path, FileAccess.WRITE)

	if source and backup:
		backup.store_string(source.get_as_text())
		source.close()
		backup.close()
		backup_created.emit(backup_path)


func _load_from_backup(slot: int) -> Dictionary:
	# Try each backup in order
	for i in range(MAX_BACKUPS):
		var backup_path := _get_backup_path(slot, i)
		var data := _read_save_file(backup_path)
		if not data.is_empty():
			push_warning("Loaded from backup: " + backup_path)
			return data

	return {}


## Set data section
func set_player_data(key: String, value: Variant) -> void:
	player_data[key] = value


func set_progress_data(key: String, value: Variant) -> void:
	progress_data[key] = value


func add_achievement(achievement_id: String) -> void:
	if not achievement_data.has("unlocked"):
		achievement_data["unlocked"] = []
	if achievement_id not in achievement_data.unlocked:
		achievement_data.unlocked.append(achievement_id)


## Get data
func get_player_data(key: String, default: Variant = null) -> Variant:
	return player_data.get(key, default)


func get_progress_data(key: String, default: Variant = null) -> Variant:
	return progress_data.get(key, default)


func is_achievement_unlocked(achievement_id: String) -> bool:
	if not achievement_data.has("unlocked"):
		return false
	return achievement_id in achievement_data.unlocked


## Export/Import for cloud saves
func export_save_data() -> String:
	var data := _gather_all_data()
	data["meta"] = {
		"version": SAVE_VERSION,
		"timestamp": Time.get_unix_time_from_system(),
		"checksum": _calculate_checksum(data)
	}
	return Marshalls.utf8_to_base64(JSON.stringify(data))


func import_save_data(encoded: String) -> bool:
	var json_string := Marshalls.base64_to_utf8(encoded)
	var json := JSON.new()
	if json.parse(json_string) != OK:
		return false

	var data: Dictionary = json.data
	_apply_loaded_data(data)
	return true

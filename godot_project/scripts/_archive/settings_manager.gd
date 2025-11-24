## SettingsManager - Centralized game settings and user preferences
## Handles persistence, validation, and settings UI binding
class_name SettingsManager
extends Node

signal settings_changed(category: String, key: String, value: Variant)
signal settings_loaded
signal settings_saved
signal settings_reset

const SETTINGS_PATH := "user://settings.json"
const SETTINGS_VERSION := 1

## Settings categories
var gameplay: GameplaySettings
var graphics: GraphicsSettings
var audio: AudioSettings
var comfort: ComfortSettings
var controls: ControlSettings
var accessibility: AccessibilitySettings

## All settings as dictionary for easy serialization
var _settings: Dictionary = {}
var _defaults: Dictionary = {}


class GameplaySettings:
	var difficulty_mode: String = "adaptive"  # adaptive, easy, normal, hard, custom
	var custom_difficulty: float = 0.5
	var target_lifetime: float = 3.0
	var spawn_rate: float = 1.0
	var enable_projectiles: bool = true
	var enable_force_powers: bool = true
	var auto_activate_saber: bool = false
	var dominant_hand: String = "right"  # left, right
	var show_hit_direction: bool = true
	var require_direction_match: bool = false
	var tutorial_hints: bool = true
	var auto_pause_on_remove: bool = true


class GraphicsSettings:
	var render_scale: float = 1.0  # 0.5 - 1.5
	var msaa_level: int = 2  # 0, 2, 4, 8
	var shadow_quality: int = 2  # 0=off, 1=low, 2=medium, 3=high
	var glow_enabled: bool = true
	var glow_intensity: float = 0.5
	var particle_density: float = 1.0
	var trail_quality: int = 2  # 0=off, 1=low, 2=medium, 3=high
	var heat_map_resolution: int = 1  # 0=low, 1=medium, 2=high
	var environment_detail: int = 2  # 0=low, 1=medium, 2=high
	var blade_glow_intensity: float = 1.0


class AudioSettings:
	var master_volume: float = 1.0
	var music_volume: float = 0.7
	var sfx_volume: float = 1.0
	var voice_volume: float = 1.0
	var haptic_intensity: float = 1.0
	var spatial_audio: bool = true
	var music_enabled: bool = true
	var hit_sounds: bool = true
	var ambient_sounds: bool = true
	var voice_guidance: bool = true


class ComfortSettings:
	var seated_mode: bool = false
	var play_space_scale: float = 1.0
	var floor_height_offset: float = 0.0
	var vignette_on_motion: bool = false
	var vignette_intensity: float = 0.5
	var snap_turning: bool = false
	var snap_turn_angle: float = 45.0
	var smooth_turn_speed: float = 90.0
	var height_adjustment: float = 0.0
	var recenter_on_start: bool = true
	var boundary_warnings: bool = true
	var reduce_motion: bool = false


class ControlSettings:
	var left_trigger_action: String = "grip_saber"
	var right_trigger_action: String = "grip_saber"
	var left_grip_action: String = "force_power"
	var right_grip_action: String = "force_power"
	var menu_button: String = "left_menu"
	var thumbstick_deadzone: float = 0.15
	var trigger_threshold: float = 0.7
	var grip_threshold: float = 0.7
	var swap_hands: bool = false
	var gesture_sensitivity: float = 1.0


class AccessibilitySettings:
	var color_blind_mode: String = "none"  # none, protanopia, deuteranopia, tritanopia
	var high_contrast: bool = false
	var larger_ui: bool = false
	var ui_scale: float = 1.0
	var subtitle_size: float = 1.0
	var screen_reader: bool = false
	var one_handed_mode: bool = false
	var auto_aim_assist: float = 0.0  # 0-1
	var extended_timers: bool = false
	var timer_multiplier: float = 1.0
	var simplified_visuals: bool = false
	var flash_reduction: bool = false


func _ready() -> void:
	_initialize_defaults()
	load_settings()


func _initialize_defaults() -> void:
	gameplay = GameplaySettings.new()
	graphics = GraphicsSettings.new()
	audio = AudioSettings.new()
	comfort = ComfortSettings.new()
	controls = ControlSettings.new()
	accessibility = AccessibilitySettings.new()

	_defaults = _serialize_all()


func _serialize_all() -> Dictionary:
	return {
		"version": SETTINGS_VERSION,
		"gameplay": _serialize_object(gameplay),
		"graphics": _serialize_object(graphics),
		"audio": _serialize_object(audio),
		"comfort": _serialize_object(comfort),
		"controls": _serialize_object(controls),
		"accessibility": _serialize_object(accessibility)
	}


func _serialize_object(obj: Object) -> Dictionary:
	var data := {}
	for prop in obj.get_property_list():
		if prop.usage & PROPERTY_USAGE_SCRIPT_VARIABLE:
			data[prop.name] = obj.get(prop.name)
	return data


func _deserialize_object(obj: Object, data: Dictionary) -> void:
	for key in data:
		if key in obj:
			obj.set(key, data[key])


func load_settings() -> bool:
	var file := FileAccess.open(SETTINGS_PATH, FileAccess.READ)
	if file == null:
		push_warning("No settings file found, using defaults")
		_settings = _defaults.duplicate(true)
		return false

	var json_string := file.get_as_text()
	file.close()

	var json := JSON.new()
	var error := json.parse(json_string)
	if error != OK:
		push_error("Failed to parse settings: " + json.get_error_message())
		_settings = _defaults.duplicate(true)
		return false

	_settings = json.data

	# Version migration
	var version: int = _settings.get("version", 0)
	if version < SETTINGS_VERSION:
		_migrate_settings(version)

	# Apply loaded settings to objects
	_deserialize_object(gameplay, _settings.get("gameplay", {}))
	_deserialize_object(graphics, _settings.get("graphics", {}))
	_deserialize_object(audio, _settings.get("audio", {}))
	_deserialize_object(comfort, _settings.get("comfort", {}))
	_deserialize_object(controls, _settings.get("controls", {}))
	_deserialize_object(accessibility, _settings.get("accessibility", {}))

	_apply_settings()
	settings_loaded.emit()
	return true


func save_settings() -> bool:
	_settings = _serialize_all()

	var json_string := JSON.stringify(_settings, "\t")
	var file := FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	if file == null:
		push_error("Failed to save settings")
		return false

	file.store_string(json_string)
	file.close()

	settings_saved.emit()
	return true


func reset_to_defaults() -> void:
	_settings = _defaults.duplicate(true)
	_deserialize_object(gameplay, _settings.get("gameplay", {}))
	_deserialize_object(graphics, _settings.get("graphics", {}))
	_deserialize_object(audio, _settings.get("audio", {}))
	_deserialize_object(comfort, _settings.get("comfort", {}))
	_deserialize_object(controls, _settings.get("controls", {}))
	_deserialize_object(accessibility, _settings.get("accessibility", {}))

	_apply_settings()
	settings_reset.emit()


func reset_category(category: String) -> void:
	if _defaults.has(category):
		_settings[category] = _defaults[category].duplicate(true)
		match category:
			"gameplay": _deserialize_object(gameplay, _settings[category])
			"graphics": _deserialize_object(graphics, _settings[category])
			"audio": _deserialize_object(audio, _settings[category])
			"comfort": _deserialize_object(comfort, _settings[category])
			"controls": _deserialize_object(controls, _settings[category])
			"accessibility": _deserialize_object(accessibility, _settings[category])
		_apply_category(category)


func _migrate_settings(from_version: int) -> void:
	# Handle settings migration between versions
	if from_version < 1:
		# Migration from version 0 to 1
		pass


func _apply_settings() -> void:
	_apply_category("graphics")
	_apply_category("audio")
	_apply_category("comfort")
	_apply_category("accessibility")


func _apply_category(category: String) -> void:
	match category:
		"graphics":
			_apply_graphics_settings()
		"audio":
			_apply_audio_settings()
		"comfort":
			_apply_comfort_settings()
		"accessibility":
			_apply_accessibility_settings()


func _apply_graphics_settings() -> void:
	# Apply render scale
	var viewport := get_viewport()
	if viewport:
		viewport.scaling_3d_scale = graphics.render_scale

	# Apply MSAA
	if viewport:
		match graphics.msaa_level:
			0: viewport.msaa_3d = Viewport.MSAA_DISABLED
			2: viewport.msaa_3d = Viewport.MSAA_2X
			4: viewport.msaa_3d = Viewport.MSAA_4X
			8: viewport.msaa_3d = Viewport.MSAA_8X

	# Apply to environment if available
	var env_manager := get_node_or_null("/root/EnvironmentManager")
	if env_manager and env_manager.has_method("set_glow_enabled"):
		env_manager.set_glow_enabled(graphics.glow_enabled)
		env_manager.set_glow_intensity(graphics.glow_intensity)


func _apply_audio_settings() -> void:
	# Apply audio bus volumes
	var master_idx := AudioServer.get_bus_index("Master")
	if master_idx >= 0:
		AudioServer.set_bus_volume_db(master_idx, linear_to_db(audio.master_volume))

	var music_idx := AudioServer.get_bus_index("Music")
	if music_idx >= 0:
		AudioServer.set_bus_volume_db(music_idx, linear_to_db(audio.music_volume))

	var sfx_idx := AudioServer.get_bus_index("SFX")
	if sfx_idx >= 0:
		AudioServer.set_bus_volume_db(sfx_idx, linear_to_db(audio.sfx_volume))


func _apply_comfort_settings() -> void:
	# Apply comfort settings to XR origin if available
	var xr_origin := get_node_or_null("/root/Main/XROrigin3D")
	if xr_origin:
		xr_origin.position.y = comfort.floor_height_offset + comfort.height_adjustment


func _apply_accessibility_settings() -> void:
	# Apply color blind shader if needed
	if accessibility.color_blind_mode != "none":
		_apply_color_blind_filter(accessibility.color_blind_mode)


func _apply_color_blind_filter(mode: String) -> void:
	# Would apply post-processing shader for color blindness
	pass


## Setters with auto-save and events
func set_gameplay_setting(key: String, value: Variant) -> void:
	if key in gameplay:
		gameplay.set(key, value)
		settings_changed.emit("gameplay", key, value)


func set_graphics_setting(key: String, value: Variant) -> void:
	if key in graphics:
		graphics.set(key, value)
		_apply_graphics_settings()
		settings_changed.emit("graphics", key, value)


func set_audio_setting(key: String, value: Variant) -> void:
	if key in audio:
		audio.set(key, value)
		_apply_audio_settings()
		settings_changed.emit("audio", key, value)


func set_comfort_setting(key: String, value: Variant) -> void:
	if key in comfort:
		comfort.set(key, value)
		_apply_comfort_settings()
		settings_changed.emit("comfort", key, value)


func set_controls_setting(key: String, value: Variant) -> void:
	if key in controls:
		controls.set(key, value)
		settings_changed.emit("controls", key, value)


func set_accessibility_setting(key: String, value: Variant) -> void:
	if key in accessibility:
		accessibility.set(key, value)
		_apply_accessibility_settings()
		settings_changed.emit("accessibility", key, value)


## Getters
func get_setting(category: String, key: String) -> Variant:
	match category:
		"gameplay": return gameplay.get(key) if key in gameplay else null
		"graphics": return graphics.get(key) if key in graphics else null
		"audio": return audio.get(key) if key in audio else null
		"comfort": return comfort.get(key) if key in comfort else null
		"controls": return controls.get(key) if key in controls else null
		"accessibility": return accessibility.get(key) if key in accessibility else null
	return null


func get_all_settings() -> Dictionary:
	return _serialize_all()

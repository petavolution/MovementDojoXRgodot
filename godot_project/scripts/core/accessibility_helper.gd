## AccessibilityHelper - Accessibility features and adaptations
## Provides options for players with different needs
class_name AccessibilityHelper
extends Node

signal accessibility_setting_changed(setting: String, value: Variant)
signal color_scheme_changed(scheme: String)
signal one_handed_mode_toggled(enabled: bool)

## Color blind simulation matrices
const COLOR_BLIND_MATRICES := {
	"none": [
		1.0, 0.0, 0.0, 0.0,
		0.0, 1.0, 0.0, 0.0,
		0.0, 0.0, 1.0, 0.0,
		0.0, 0.0, 0.0, 1.0
	],
	"protanopia": [  # Red-blind
		0.567, 0.433, 0.0, 0.0,
		0.558, 0.442, 0.0, 0.0,
		0.0, 0.242, 0.758, 0.0,
		0.0, 0.0, 0.0, 1.0
	],
	"deuteranopia": [  # Green-blind
		0.625, 0.375, 0.0, 0.0,
		0.7, 0.3, 0.0, 0.0,
		0.0, 0.3, 0.7, 0.0,
		0.0, 0.0, 0.0, 1.0
	],
	"tritanopia": [  # Blue-blind
		0.95, 0.05, 0.0, 0.0,
		0.0, 0.433, 0.567, 0.0,
		0.0, 0.475, 0.525, 0.0,
		0.0, 0.0, 0.0, 1.0
	]
}

## High contrast color schemes
const HIGH_CONTRAST_COLORS := {
	"target_normal": Color(1.0, 1.0, 0.0),  # Bright yellow
	"target_hit": Color(0.0, 1.0, 0.0),     # Bright green
	"target_miss": Color(1.0, 0.0, 0.0),    # Bright red
	"blade_player": Color(0.0, 1.0, 1.0),   # Cyan
	"blade_enemy": Color(1.0, 0.0, 1.0),    # Magenta
	"ui_text": Color(1.0, 1.0, 1.0),        # White
	"ui_background": Color(0.0, 0.0, 0.0, 0.9)  # Near black
}

## Shape indicators (for color-blind players)
enum ShapeIndicator { CIRCLE, SQUARE, TRIANGLE, DIAMOND, STAR, HEXAGON }

## State
var is_one_handed_mode: bool = false
var active_hand: String = "right"
var color_blind_mode: String = "none"
var high_contrast: bool = false
var reduced_motion: bool = false
var larger_ui: bool = false
var ui_scale: float = 1.0
var audio_cues_enabled: bool = true
var haptic_feedback_enabled: bool = true
var subtitle_enabled: bool = true
var subtitle_size: float = 1.0
var auto_aim_strength: float = 0.0

## References
var settings_manager: Node
var color_blind_shader: ShaderMaterial


func _ready() -> void:
	_setup_color_blind_shader()


func setup(settings_mgr: Node) -> void:
	settings_manager = settings_mgr

	# Load initial settings
	if settings_manager:
		_load_from_settings()


func _load_from_settings() -> void:
	if settings_manager == null:
		return

	if settings_manager.has_method("get_setting"):
		color_blind_mode = settings_manager.get_setting("accessibility", "color_blind_mode")
		high_contrast = settings_manager.get_setting("accessibility", "high_contrast")
		larger_ui = settings_manager.get_setting("accessibility", "larger_ui")
		ui_scale = settings_manager.get_setting("accessibility", "ui_scale")
		is_one_handed_mode = settings_manager.get_setting("accessibility", "one_handed_mode")
		auto_aim_strength = settings_manager.get_setting("accessibility", "auto_aim_assist")
		reduced_motion = settings_manager.get_setting("accessibility", "flash_reduction")

	_apply_all_settings()


func _apply_all_settings() -> void:
	apply_color_blind_mode(color_blind_mode)
	apply_high_contrast(high_contrast)
	apply_ui_scale(ui_scale)
	apply_reduced_motion(reduced_motion)


func _setup_color_blind_shader() -> void:
	# Create shader for color blind simulation
	var shader := Shader.new()
	shader.code = """
shader_type canvas_item;

uniform mat4 color_matrix;

void fragment() {
	vec4 color = texture(TEXTURE, UV);
	COLOR = color_matrix * color;
}
"""
	color_blind_shader = ShaderMaterial.new()
	color_blind_shader.shader = shader


## Color blind mode
func apply_color_blind_mode(mode: String) -> void:
	color_blind_mode = mode

	if not COLOR_BLIND_MATRICES.has(mode):
		mode = "none"

	var matrix: Array = COLOR_BLIND_MATRICES[mode]

	# Apply to post-processing
	if color_blind_shader:
		# Would set as post-process effect
		pass

	accessibility_setting_changed.emit("color_blind_mode", mode)
	color_scheme_changed.emit(mode)


## Get color-adjusted color for color blind mode
func get_accessible_color(original: Color, use_case: String = "") -> Color:
	if color_blind_mode == "none" and not high_contrast:
		return original

	if high_contrast and HIGH_CONTRAST_COLORS.has(use_case):
		return HIGH_CONTRAST_COLORS[use_case]

	# Apply color blind transformation
	if color_blind_mode != "none":
		var matrix: Array = COLOR_BLIND_MATRICES[color_blind_mode]
		return Color(
			original.r * matrix[0] + original.g * matrix[1] + original.b * matrix[2],
			original.r * matrix[4] + original.g * matrix[5] + original.b * matrix[6],
			original.r * matrix[8] + original.g * matrix[9] + original.b * matrix[10],
			original.a
		)

	return original


## High contrast mode
func apply_high_contrast(enabled: bool) -> void:
	high_contrast = enabled
	accessibility_setting_changed.emit("high_contrast", enabled)


## UI scaling
func apply_ui_scale(scale: float) -> void:
	ui_scale = clampf(scale, 0.5, 2.0)

	# Scale would be applied to UI elements
	# For VR, this affects world-space UI size

	accessibility_setting_changed.emit("ui_scale", ui_scale)


## Reduced motion
func apply_reduced_motion(enabled: bool) -> void:
	reduced_motion = enabled

	# Disable or reduce:
	# - Screen shake
	# - Rapid particle effects
	# - Fast transitions
	# - Flashing effects

	accessibility_setting_changed.emit("reduced_motion", enabled)


## One-handed mode
func enable_one_handed_mode(hand: String = "right") -> void:
	is_one_handed_mode = true
	active_hand = hand

	# Remap controls for one-handed use
	# - Auto-grip for saber
	# - Simplified Force powers
	# - Head-directed aiming

	one_handed_mode_toggled.emit(true)
	accessibility_setting_changed.emit("one_handed_mode", true)


func disable_one_handed_mode() -> void:
	is_one_handed_mode = false
	one_handed_mode_toggled.emit(false)
	accessibility_setting_changed.emit("one_handed_mode", false)


## Auto-aim assist
func apply_auto_aim(target_position: Vector3, hand_position: Vector3, hand_direction: Vector3) -> Vector3:
	if auto_aim_strength <= 0:
		return hand_direction

	var to_target := (target_position - hand_position).normalized()
	var assisted_dir := hand_direction.lerp(to_target, auto_aim_strength * 0.5)

	return assisted_dir.normalized()


## Get shape indicator for color-coded elements
func get_shape_for_type(type: String) -> ShapeIndicator:
	# Use shapes in addition to colors for color-blind accessibility
	match type:
		"target_normal": return ShapeIndicator.CIRCLE
		"target_bonus": return ShapeIndicator.STAR
		"target_avoid": return ShapeIndicator.TRIANGLE
		"target_hold": return ShapeIndicator.SQUARE
		"powerup": return ShapeIndicator.DIAMOND
		"hazard": return ShapeIndicator.HEXAGON
	return ShapeIndicator.CIRCLE


## Audio cue for visual events
func play_audio_cue(event: String, position: Vector3 = Vector3.ZERO) -> void:
	if not audio_cues_enabled:
		return

	# Would play spatial audio cues for important events
	# Helps players who can't see visual indicators clearly
	match event:
		"target_spawn":
			GameEvents.sfx_requested.emit("target_spawn_cue", position)
		"target_approaching":
			GameEvents.sfx_requested.emit("target_approach_cue", position)
		"attack_incoming":
			GameEvents.sfx_requested.emit("attack_warning_cue", position)
		"combo_milestone":
			GameEvents.sfx_requested.emit("combo_cue", position)


## Subtitle/caption support
func show_subtitle(text: String, duration: float = 3.0, speaker: String = "") -> void:
	if not subtitle_enabled:
		return

	# Would display subtitle in world space
	# Positioned for easy reading in VR

	var display_text := text
	if speaker != "":
		display_text = "[%s] %s" % [speaker, text]

	# Emit for UI to handle
	GameEvents.tutorial_step_changed.emit("subtitle", display_text)


## Timer extension for extended timers mode
func get_adjusted_timer(base_duration: float) -> float:
	if settings_manager and settings_manager.has_method("get_setting"):
		var extended: bool = settings_manager.get_setting("accessibility", "extended_timers")
		var multiplier: float = settings_manager.get_setting("accessibility", "timer_multiplier")

		if extended:
			return base_duration * multiplier

	return base_duration


## Get current accessibility profile
func get_profile() -> Dictionary:
	return {
		"one_handed_mode": is_one_handed_mode,
		"active_hand": active_hand,
		"color_blind_mode": color_blind_mode,
		"high_contrast": high_contrast,
		"reduced_motion": reduced_motion,
		"larger_ui": larger_ui,
		"ui_scale": ui_scale,
		"audio_cues": audio_cues_enabled,
		"haptic_feedback": haptic_feedback_enabled,
		"subtitles": subtitle_enabled,
		"subtitle_size": subtitle_size,
		"auto_aim": auto_aim_strength
	}


## Apply a full accessibility profile
func apply_profile(profile: Dictionary) -> void:
	if profile.has("one_handed_mode"):
		if profile.one_handed_mode:
			enable_one_handed_mode(profile.get("active_hand", "right"))
		else:
			disable_one_handed_mode()

	if profile.has("color_blind_mode"):
		apply_color_blind_mode(profile.color_blind_mode)

	if profile.has("high_contrast"):
		apply_high_contrast(profile.high_contrast)

	if profile.has("reduced_motion"):
		apply_reduced_motion(profile.reduced_motion)

	if profile.has("ui_scale"):
		apply_ui_scale(profile.ui_scale)

	if profile.has("audio_cues"):
		audio_cues_enabled = profile.audio_cues

	if profile.has("haptic_feedback"):
		haptic_feedback_enabled = profile.haptic_feedback

	if profile.has("subtitles"):
		subtitle_enabled = profile.subtitles

	if profile.has("subtitle_size"):
		subtitle_size = profile.subtitle_size

	if profile.has("auto_aim"):
		auto_aim_strength = profile.auto_aim

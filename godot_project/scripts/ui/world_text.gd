## WorldText - Simple 3D world-space text display
## Uses Label3D for lightweight text rendering in VR
## Supports fade-in/out animations and auto-dismiss
extends Node3D
class_name WorldText

# =============================================================================
# SIGNALS
# =============================================================================

signal dismissed()

# =============================================================================
# CONFIGURATION
# =============================================================================

@export_group("Text")
@export var text := "" : set = set_text
@export var font_size := 32
@export var text_color := Color.WHITE
@export var outline_color := Color.BLACK
@export var outline_size := 4

@export_group("Layout")
@export var billboard := true  # Always face camera
@export var fixed_size := true  # Constant pixel size regardless of distance
@export var pixel_size := 0.002  # Size multiplier

@export_group("Animation")
@export var fade_in_duration := 0.3
@export var fade_out_duration := 0.3
@export var auto_dismiss_time := 0.0  # 0 = don't auto-dismiss

# =============================================================================
# NODES
# =============================================================================

var label: Label3D
var _dismiss_timer := 0.0
var _is_fading_out := false
var _is_visible := false

# =============================================================================
# LIFECYCLE
# =============================================================================

func _ready() -> void:
	_create_label()

	if text != "":
		show_text(text)


func _process(delta: float) -> void:
	if auto_dismiss_time > 0 and _is_visible and not _is_fading_out:
		_dismiss_timer += delta
		if _dismiss_timer >= auto_dismiss_time:
			dismiss()


func _create_label() -> void:
	label = Label3D.new()
	label.name = "Label"

	label.font_size = font_size
	label.modulate = text_color
	label.outline_modulate = outline_color
	label.outline_size = outline_size

	label.billboard = Label3D.BILLBOARD_ENABLED if billboard else Label3D.BILLBOARD_DISABLED
	label.fixed_size = fixed_size
	label.pixel_size = pixel_size

	label.no_depth_test = true  # Always visible
	label.shaded = false

	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	# Start invisible
	label.modulate.a = 0.0

	add_child(label)


# =============================================================================
# PUBLIC API
# =============================================================================

func set_text(value: String) -> void:
	text = value
	if label:
		label.text = text


func show_text(new_text: String, duration: float = 0.0) -> void:
	text = new_text
	if label:
		label.text = text

	auto_dismiss_time = duration
	_dismiss_timer = 0.0
	_is_fading_out = false
	_is_visible = true

	# Fade in
	if fade_in_duration > 0:
		var tween := create_tween()
		tween.tween_property(label, "modulate:a", 1.0, fade_in_duration)
	else:
		label.modulate.a = 1.0


func dismiss() -> void:
	if _is_fading_out:
		return

	_is_fading_out = true

	# Fade out
	if fade_out_duration > 0:
		var tween := create_tween()
		tween.tween_property(label, "modulate:a", 0.0, fade_out_duration)
		tween.tween_callback(_on_fade_complete)
	else:
		label.modulate.a = 0.0
		_on_fade_complete()


func _on_fade_complete() -> void:
	_is_visible = false
	dismissed.emit()


func set_color(color: Color) -> void:
	text_color = color
	if label:
		label.modulate = color


func set_font_size(size: int) -> void:
	font_size = size
	if label:
		label.font_size = size


# =============================================================================
# FACTORY
# =============================================================================

static func create(
	display_text: String,
	pos: Vector3,
	color: Color = Color.WHITE,
	size: int = 32,
	duration: float = 0.0
) -> WorldText:
	var wt := WorldText.new()
	wt.position = pos
	wt.text_color = color
	wt.font_size = size
	wt.auto_dismiss_time = duration
	wt.text = display_text
	return wt

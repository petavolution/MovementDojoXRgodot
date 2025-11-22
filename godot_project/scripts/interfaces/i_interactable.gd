## IInteractable - Interface for interactable objects
## Defines contract for objects that can be interacted with via lightsaber or hand
class_name IInteractable
extends RefCounted

## Interaction types
enum InteractionType {
	TOUCH,          # Simple contact
	HIT,            # Impact with velocity
	SLICE,          # Cut through
	GRAB,           # Hand grab
	POINT,          # Point/select
	FORCE_PUSH,     # Force push
	FORCE_PULL      # Force pull
}

## Interaction event data
class InteractionEvent:
	var type: InteractionType = InteractionType.TOUCH
	var position: Vector3 = Vector3.ZERO
	var normal: Vector3 = Vector3.ZERO
	var velocity: Vector3 = Vector3.ZERO
	var force: float = 0.0
	var hand: String = ""  # "left", "right", or ""
	var is_blade: bool = false
	var timestamp: float = 0.0

## Interface methods

## Check if this object can be interacted with
func can_interact(interaction_type: InteractionType) -> bool:
	push_error("IInteractable.can_interact() not implemented")
	return false

## Get supported interaction types
func get_supported_interactions() -> Array[InteractionType]:
	push_error("IInteractable.get_supported_interactions() not implemented")
	return []

## Handle interaction event
func on_interact(event: InteractionEvent) -> void:
	push_error("IInteractable.on_interact() not implemented")

## Called when interaction starts (e.g., hand enters grab range)
func on_interaction_start(interaction_type: InteractionType) -> void:
	pass  # Optional

## Called when interaction ends
func on_interaction_end(interaction_type: InteractionType) -> void:
	pass  # Optional

## Get highlight color when pointed at
func get_highlight_color() -> Color:
	return Color(1, 1, 1, 0.3)  # Default white highlight

## Check if currently highlighted
func is_highlighted() -> bool:
	return false  # Default

## Set highlight state
func set_highlighted(highlighted: bool) -> void:
	pass  # Default: no implementation

## Get interaction prompt text
func get_interaction_prompt() -> String:
	return ""  # Default: no prompt

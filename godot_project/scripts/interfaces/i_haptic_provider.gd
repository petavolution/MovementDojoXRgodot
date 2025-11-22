## IHapticProvider - Interface for haptic feedback providers
## Allows swapping haptic implementations (controller, vest, gloves, etc.)
class_name IHapticProvider
extends RefCounted

## Haptic channel/location
enum HapticChannel {
	LEFT_HAND,
	RIGHT_HAND,
	BOTH_HANDS,
	HEAD,           # For HMD haptics
	BODY_LEFT,      # Vest/suit left
	BODY_RIGHT,     # Vest/suit right
	BODY_BACK,
	BODY_FRONT
}

## Haptic pattern types
enum PatternType {
	PULSE,          # Single pulse
	RAMP_UP,        # Increasing intensity
	RAMP_DOWN,      # Decreasing intensity
	WAVE,           # Oscillating
	CONSTANT,       # Steady vibration
	CUSTOM          # Custom waveform
}

## Haptic feedback request
class HapticRequest:
	var channel: HapticChannel = HapticChannel.RIGHT_HAND
	var pattern: PatternType = PatternType.PULSE
	var intensity: float = 1.0
	var duration: float = 0.1
	var frequency: float = 0.0  # Hz, 0 = default
	var custom_waveform: PackedFloat32Array = PackedFloat32Array()
	var priority: int = 0

## Interface methods

## Check if haptic channel is available
func is_channel_available(channel: HapticChannel) -> bool:
	push_error("IHapticProvider.is_channel_available() not implemented")
	return false

## Get all available channels
func get_available_channels() -> Array[HapticChannel]:
	push_error("IHapticProvider.get_available_channels() not implemented")
	return []

## Trigger haptic feedback
func trigger_haptic(request: HapticRequest) -> void:
	push_error("IHapticProvider.trigger_haptic() not implemented")

## Simple pulse shorthand
func pulse(channel: HapticChannel, intensity: float, duration: float) -> void:
	var request := HapticRequest.new()
	request.channel = channel
	request.pattern = PatternType.PULSE
	request.intensity = intensity
	request.duration = duration
	trigger_haptic(request)

## Stop all haptic feedback
func stop_all() -> void:
	push_error("IHapticProvider.stop_all() not implemented")

## Stop haptic on specific channel
func stop_channel(channel: HapticChannel) -> void:
	push_error("IHapticProvider.stop_channel() not implemented")

## Get provider name
func get_provider_name() -> String:
	push_error("IHapticProvider.get_provider_name() not implemented")
	return ""

## Check if provider supports custom waveforms
func supports_custom_waveforms() -> bool:
	return false  # Default: not supported

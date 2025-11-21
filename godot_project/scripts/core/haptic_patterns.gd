## HapticPatterns - Pre-defined haptic feedback patterns for VR
## Provides various tactile feedback patterns for different events
class_name HapticPatterns
extends RefCounted

## Pattern definition
class Pattern:
	var pulses: Array[Dictionary] = []  # {delay, duration, frequency, amplitude}

	func add_pulse(delay_ms: float, duration_ms: float, frequency: float, amplitude: float) -> Pattern:
		pulses.append({
			"delay": delay_ms / 1000.0,
			"duration": duration_ms / 1000.0,
			"frequency": frequency,
			"amplitude": amplitude
		})
		return self


## Pre-defined patterns
static var LIGHT_TAP := Pattern.new().add_pulse(0, 50, 100, 0.3)

static var MEDIUM_TAP := Pattern.new().add_pulse(0, 80, 150, 0.5)

static var STRONG_TAP := Pattern.new().add_pulse(0, 100, 200, 0.8)

static var DOUBLE_TAP := Pattern.new()\
	.add_pulse(0, 50, 150, 0.5)\
	.add_pulse(100, 50, 150, 0.5)

static var TRIPLE_TAP := Pattern.new()\
	.add_pulse(0, 40, 150, 0.4)\
	.add_pulse(80, 40, 150, 0.5)\
	.add_pulse(160, 40, 150, 0.6)

static var SUCCESS := Pattern.new()\
	.add_pulse(0, 100, 100, 0.3)\
	.add_pulse(150, 150, 150, 0.6)

static var ERROR := Pattern.new()\
	.add_pulse(0, 200, 50, 0.8)\
	.add_pulse(250, 200, 50, 0.8)

static var BLADE_CLASH := Pattern.new()\
	.add_pulse(0, 150, 200, 1.0)

static var BLADE_HIT := Pattern.new()\
	.add_pulse(0, 80, 180, 0.7)

static var DEFLECTION := Pattern.new()\
	.add_pulse(0, 100, 220, 0.9)\
	.add_pulse(50, 50, 180, 0.4)

static var FORCE_PUSH := Pattern.new()\
	.add_pulse(0, 50, 100, 0.3)\
	.add_pulse(50, 100, 150, 0.6)\
	.add_pulse(150, 150, 200, 0.9)

static var FORCE_PULL := Pattern.new()\
	.add_pulse(0, 150, 200, 0.8)\
	.add_pulse(150, 100, 150, 0.5)\
	.add_pulse(250, 50, 100, 0.2)

static var ACHIEVEMENT := Pattern.new()\
	.add_pulse(0, 100, 100, 0.4)\
	.add_pulse(150, 100, 150, 0.6)\
	.add_pulse(300, 150, 200, 0.8)

static var HEARTBEAT := Pattern.new()\
	.add_pulse(0, 100, 100, 0.6)\
	.add_pulse(150, 80, 100, 0.4)

static var BREATHING_IN := Pattern.new()\
	.add_pulse(0, 50, 80, 0.2)\
	.add_pulse(200, 50, 100, 0.3)\
	.add_pulse(400, 50, 120, 0.4)\
	.add_pulse(600, 50, 140, 0.5)

static var BREATHING_OUT := Pattern.new()\
	.add_pulse(0, 50, 140, 0.5)\
	.add_pulse(200, 50, 120, 0.4)\
	.add_pulse(400, 50, 100, 0.3)\
	.add_pulse(600, 50, 80, 0.2)

static var ZONE_DISCOVERED := Pattern.new()\
	.add_pulse(0, 80, 180, 0.7)\
	.add_pulse(100, 120, 220, 0.5)

static var COMBO_MILESTONE := Pattern.new()\
	.add_pulse(0, 50, 150, 0.5)\
	.add_pulse(70, 50, 180, 0.6)\
	.add_pulse(140, 50, 210, 0.7)\
	.add_pulse(210, 100, 250, 0.9)


## Play a haptic pattern on a controller
static func play(controller: XRController3D, pattern: Pattern, intensity_scale: float = 1.0) -> void:
	if controller == null or pattern == null:
		return

	for pulse in pattern.pulses:
		var delay: float = pulse["delay"]
		var duration: float = pulse["duration"]
		var frequency: float = pulse["frequency"]
		var amplitude: float = pulse["amplitude"] * intensity_scale

		# Schedule the pulse
		if delay > 0:
			var timer := controller.get_tree().create_timer(delay)
			timer.timeout.connect(func():
				controller.trigger_haptic_pulse("haptic", frequency, amplitude, duration, 0.0)
			)
		else:
			controller.trigger_haptic_pulse("haptic", frequency, amplitude, duration, 0.0)


## Play pattern on both controllers
static func play_both(left: XRController3D, right: XRController3D, pattern: Pattern, intensity: float = 1.0) -> void:
	play(left, pattern, intensity)
	play(right, pattern, intensity)


## Create a custom ramp pattern
static func create_ramp(start_amp: float, end_amp: float, duration_ms: float, steps: int) -> Pattern:
	var pattern := Pattern.new()
	var step_duration := duration_ms / steps
	var amp_step := (end_amp - start_amp) / steps

	for i in range(steps):
		var amp := start_amp + amp_step * i
		pattern.add_pulse(i * step_duration, step_duration, 150, amp)

	return pattern


## Create a pattern from velocity (higher velocity = stronger feedback)
static func from_velocity(velocity: float, max_velocity: float = 10.0) -> Pattern:
	var normalized := clamp(velocity / max_velocity, 0.0, 1.0)
	var duration := 50.0 + normalized * 100.0
	var frequency := 100.0 + normalized * 150.0
	var amplitude := 0.3 + normalized * 0.7

	return Pattern.new().add_pulse(0, duration, frequency, amplitude)

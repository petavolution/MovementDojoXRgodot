## DualWieldManager - Manages dual lightsaber combat
## Handles two-saber coordination, sync attacks, and special moves
class_name DualWieldManager
extends Node

signal dual_wield_activated
signal dual_wield_deactivated
signal sync_attack_ready
signal sync_attack_executed(attack_type: String, power: float)
signal cross_slash_executed(position: Vector3)
signal scissor_attack_executed(position: Vector3)

## Saber references
var left_saber: Lightsaber
var right_saber: Lightsaber

## State
var is_dual_wielding: bool = false
var left_active: bool = false
var right_active: bool = false

## Sync attack detection
var sync_window: float = 0.15  # 150ms window for synchronized attacks
var last_left_swing_time: float = 0.0
var last_right_swing_time: float = 0.0
var last_left_swing_dir: Vector3 = Vector3.ZERO
var last_right_swing_dir: Vector3 = Vector3.ZERO

## Velocity tracking
var left_velocity: Vector3 = Vector3.ZERO
var right_velocity: Vector3 = Vector3.ZERO
var left_prev_pos: Vector3 = Vector3.ZERO
var right_prev_pos: Vector3 = Vector3.ZERO

## Special move detection
var cross_slash_angle_threshold: float = 120.0  # Degrees
var scissor_distance_threshold: float = 0.3  # Meters

## Scoring
var sync_bonus_multiplier: float = 1.5
var cross_slash_bonus: int = 200
var scissor_attack_bonus: int = 300

## Combo tracking for dual wield
var dual_combo: int = 0
var max_dual_combo: int = 0


func _ready() -> void:
	pass


func setup(left: Lightsaber, right: Lightsaber) -> void:
	left_saber = left
	right_saber = right

	# Connect to saber events
	if left_saber:
		left_saber.blade_activated.connect(_on_left_activated)
		left_saber.blade_deactivated.connect(_on_left_deactivated)

	if right_saber:
		right_saber.blade_activated.connect(_on_right_activated)
		right_saber.blade_deactivated.connect(_on_right_deactivated)


func _physics_process(delta: float) -> void:
	if not is_dual_wielding:
		return

	_update_velocities(delta)
	_check_sync_attacks()
	_check_special_moves()


func _update_velocities(delta: float) -> void:
	if left_saber and left_active:
		var current_pos := left_saber.global_position
		left_velocity = (current_pos - left_prev_pos) / delta if delta > 0 else Vector3.ZERO
		left_prev_pos = current_pos

	if right_saber and right_active:
		var current_pos := right_saber.global_position
		right_velocity = (current_pos - right_prev_pos) / delta if delta > 0 else Vector3.ZERO
		right_prev_pos = current_pos


func _on_left_activated() -> void:
	left_active = true
	_check_dual_wield_state()


func _on_left_deactivated() -> void:
	left_active = false
	_check_dual_wield_state()


func _on_right_activated() -> void:
	right_active = true
	_check_dual_wield_state()


func _on_right_deactivated() -> void:
	right_active = false
	_check_dual_wield_state()


func _check_dual_wield_state() -> void:
	var was_dual := is_dual_wielding
	is_dual_wielding = left_active and right_active

	if is_dual_wielding and not was_dual:
		dual_wield_activated.emit()
		dual_combo = 0
	elif not is_dual_wielding and was_dual:
		dual_wield_deactivated.emit()
		if dual_combo > max_dual_combo:
			max_dual_combo = dual_combo


## Register a swing from a saber
func register_swing(hand: String, direction: Vector3, velocity: float) -> void:
	var current_time := Time.get_ticks_msec() / 1000.0

	if hand == "left":
		last_left_swing_time = current_time
		last_left_swing_dir = direction.normalized()
	else:
		last_right_swing_time = current_time
		last_right_swing_dir = direction.normalized()


## Register a hit from a saber
func register_hit(hand: String, target: Node3D, position: Vector3) -> Dictionary:
	var result := {
		"is_sync": false,
		"bonus_multiplier": 1.0,
		"special_attack": ""
	}

	if not is_dual_wielding:
		return result

	# Check for synchronized hit
	var current_time := Time.get_ticks_msec() / 1000.0
	var other_time := last_right_swing_time if hand == "left" else last_left_swing_time
	var time_diff := abs(current_time - other_time)

	if time_diff <= sync_window:
		result.is_sync = true
		result.bonus_multiplier = sync_bonus_multiplier
		dual_combo += 1

		# Check for special attacks
		var special := _detect_special_attack(position)
		if special != "":
			result.special_attack = special
			result.bonus_multiplier *= 2.0

	return result


func _check_sync_attacks() -> void:
	if not is_dual_wielding:
		return

	# Check if both sabers are swinging simultaneously
	var left_speed := left_velocity.length()
	var right_speed := right_velocity.length()

	if left_speed > 2.0 and right_speed > 2.0:
		# Both sabers are in motion
		var time_diff := abs(last_left_swing_time - last_right_swing_time)
		if time_diff < 0.1:
			sync_attack_ready.emit()


func _check_special_moves() -> void:
	if not is_dual_wielding:
		return

	if left_saber == null or right_saber == null:
		return

	var left_pos := left_saber.global_position
	var right_pos := right_saber.global_position

	# Check for cross slash (X pattern)
	if _is_cross_slash():
		var center := (left_pos + right_pos) / 2.0
		cross_slash_executed.emit(center)
		sync_attack_executed.emit("cross_slash", left_velocity.length() + right_velocity.length())

	# Check for scissor attack (parallel closing)
	if _is_scissor_attack():
		var center := (left_pos + right_pos) / 2.0
		scissor_attack_executed.emit(center)
		sync_attack_executed.emit("scissor", left_velocity.length() + right_velocity.length())


func _is_cross_slash() -> bool:
	if left_velocity.length() < 2.0 or right_velocity.length() < 2.0:
		return false

	# Check if velocities are crossing (opposite diagonal directions)
	var left_dir := left_velocity.normalized()
	var right_dir := right_velocity.normalized()

	var angle := rad_to_deg(acos(left_dir.dot(right_dir)))

	# Should be moving in roughly opposite diagonal directions
	return angle > cross_slash_angle_threshold


func _is_scissor_attack() -> bool:
	if left_saber == null or right_saber == null:
		return false

	var left_pos := left_saber.global_position
	var right_pos := right_saber.global_position
	var distance := left_pos.distance_to(right_pos)

	# Check if sabers are close together and moving toward each other
	if distance > scissor_distance_threshold:
		return false

	var left_dir := left_velocity.normalized()
	var right_dir := right_velocity.normalized()
	var to_right := (right_pos - left_pos).normalized()
	var to_left := -to_right

	# Left saber moving toward right, right saber moving toward left
	var left_toward := left_dir.dot(to_right) > 0.5
	var right_toward := right_dir.dot(to_left) > 0.5

	return left_toward and right_toward and left_velocity.length() > 1.5 and right_velocity.length() > 1.5


func _detect_special_attack(hit_position: Vector3) -> String:
	# Check what kind of special attack was performed based on recent motion
	if _is_cross_slash():
		return "cross_slash"
	if _is_scissor_attack():
		return "scissor"
	return ""


## Get combined saber power for damage calculation
func get_combined_power() -> float:
	var left_power := left_velocity.length() if left_active else 0.0
	var right_power := right_velocity.length() if right_active else 0.0

	if is_dual_wielding:
		# Bonus for dual wielding
		return (left_power + right_power) * 1.2
	return max(left_power, right_power)


## Get dominant hand's saber
func get_dominant_saber() -> Lightsaber:
	# Could be based on settings
	return right_saber


## Get off-hand saber
func get_offhand_saber() -> Lightsaber:
	return left_saber


## Force deactivate both sabers
func deactivate_both() -> void:
	if left_saber and left_saber.has_method("deactivate"):
		left_saber.deactivate()
	if right_saber and right_saber.has_method("deactivate"):
		right_saber.deactivate()


## Get stats
func get_stats() -> Dictionary:
	return {
		"is_dual_wielding": is_dual_wielding,
		"dual_combo": dual_combo,
		"max_dual_combo": max_dual_combo,
		"left_velocity": left_velocity.length(),
		"right_velocity": right_velocity.length(),
		"combined_power": get_combined_power()
	}


## Set saber colors
func set_saber_colors(left_color: Color, right_color: Color) -> void:
	if left_saber and left_saber.has_method("set_blade_color"):
		left_saber.set_blade_color(left_color)
	if right_saber and right_saber.has_method("set_blade_color"):
		right_saber.set_blade_color(right_color)


## Match saber colors (same color for both)
func set_matched_colors(color: Color) -> void:
	set_saber_colors(color, color)


## Complementary colors (opposite on color wheel)
func set_complementary_colors(base_color: Color) -> void:
	var complement := Color(1.0 - base_color.r, 1.0 - base_color.g, 1.0 - base_color.b)
	set_saber_colors(base_color, complement)

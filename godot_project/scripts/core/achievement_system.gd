## AchievementSystem - Tracks and displays achievements
## Autoloaded as "Achievements"
extends Node

signal achievement_unlocked(achievement: Achievement)
signal achievement_progress(achievement_id: String, current: int, target: int)

# All available achievements
var achievements: Dictionary = {}
var unlocked_achievements: Array[String] = []

# Notification queue
var notification_queue: Array[Achievement] = []
var is_showing_notification := false

# VR notification display
var notification_display: AchievementNotification


class Achievement:
	var id: String
	var name: String
	var description: String
	var icon: String
	var category: String  # "movement", "combat", "wellness", "streak", "mastery"
	var is_hidden: bool = false
	var is_unlocked: bool = false
	var unlock_time: float = 0.0

	# For progressive achievements
	var is_progressive: bool = false
	var current_progress: int = 0
	var target_progress: int = 1

	# Reward
	var reward_xp: int = 0

	static func create(a_id: String, a_name: String, desc: String, cat: String, icon_name: String = "") -> Achievement:
		var ach := Achievement.new()
		ach.id = a_id
		ach.name = a_name
		ach.description = desc
		ach.category = cat
		ach.icon = icon_name if icon_name != "" else a_id
		return ach

	static func create_progressive(a_id: String, a_name: String, desc: String, cat: String, target: int) -> Achievement:
		var ach := create(a_id, a_name, desc, cat)
		ach.is_progressive = true
		ach.target_progress = target
		return ach


func _ready() -> void:
	_define_achievements()
	_load_unlocked()
	_setup_notification_display()

	# Listen for events that trigger achievements
	GameEvents.movement_zone_explored.connect(_on_zone_explored)
	GameEvents.target_hit.connect(_on_target_hit)
	GameEvents.pose_detected.connect(_on_pose_detected)
	GameEvents.session_ended.connect(_on_session_ended)


func _process(_delta: float) -> void:
	_process_notification_queue()


func unlock(achievement_id: String) -> bool:
	if achievement_id in unlocked_achievements:
		return false

	if not achievements.has(achievement_id):
		push_error("[Achievements] Unknown achievement: ", achievement_id)
		return false

	var achievement: Achievement = achievements[achievement_id]
	achievement.is_unlocked = true
	achievement.unlock_time = Time.get_unix_time_from_system()

	unlocked_achievements.append(achievement_id)
	_save_unlocked()

	# Queue notification
	notification_queue.append(achievement)
	achievement_unlocked.emit(achievement)

	print("[Achievements] Unlocked: ", achievement.name)
	return true


func add_progress(achievement_id: String, amount: int = 1) -> void:
	if achievement_id in unlocked_achievements:
		return

	if not achievements.has(achievement_id):
		return

	var achievement: Achievement = achievements[achievement_id]
	if not achievement.is_progressive:
		return

	achievement.current_progress = min(achievement.current_progress + amount, achievement.target_progress)
	achievement_progress.emit(achievement_id, achievement.current_progress, achievement.target_progress)

	# Check for completion
	if achievement.current_progress >= achievement.target_progress:
		unlock(achievement_id)


func get_achievement(achievement_id: String) -> Achievement:
	return achievements.get(achievement_id)


func get_all_achievements() -> Array[Achievement]:
	var result: Array[Achievement] = []
	for ach in achievements.values():
		result.append(ach)
	return result


func get_achievements_by_category(category: String) -> Array[Achievement]:
	var result: Array[Achievement] = []
	for ach in achievements.values():
		if ach.category == category:
			result.append(ach)
	return result


func get_unlocked_count() -> int:
	return unlocked_achievements.size()


func get_total_count() -> int:
	return achievements.size()


func get_completion_percentage() -> float:
	if achievements.size() == 0:
		return 0.0
	return float(unlocked_achievements.size()) / achievements.size() * 100.0


func _define_achievements() -> void:
	# Movement achievements
	_add(Achievement.create(
		"first_swing", "First Strike",
		"Swing your lightsaber for the first time",
		"combat"
	))
	_add(Achievement.create(
		"sky_reach", "Sky Reach",
		"Reach above your head",
		"movement"
	))
	_add(Achievement.create(
		"behind_back", "Hidden Blade",
		"Reach behind your back",
		"movement"
	))
	_add(Achievement.create(
		"low_reach", "Ground Touch",
		"Reach below waist level",
		"movement"
	))
	_add(Achievement.create(
		"cross_body", "Cross Strike",
		"Reach across your body's midline",
		"movement"
	))

	# Coverage achievements
	_add(Achievement.create(
		"coverage_25", "Quarter Explorer",
		"Use 25% of your reachable movement space",
		"movement"
	))
	_add(Achievement.create(
		"coverage_50", "Half Explorer",
		"Use 50% of your reachable movement space",
		"movement"
	))
	_add(Achievement.create(
		"coverage_75", "Explorer",
		"Use 75% of your reachable movement space",
		"movement"
	))
	_add(Achievement.create(
		"coverage_90", "Movement Master",
		"Use 90% of your reachable movement space",
		"mastery"
	))

	# Combat achievements
	_add(Achievement.create_progressive(
		"targets_10", "Target Practice",
		"Destroy 10 training targets",
		"combat", 10
	))
	_add(Achievement.create_progressive(
		"targets_100", "Target Destroyer",
		"Destroy 100 training targets",
		"combat", 100
	))
	_add(Achievement.create_progressive(
		"targets_1000", "Master Duelist",
		"Destroy 1000 training targets",
		"mastery", 1000
	))
	_add(Achievement.create(
		"deflect_first", "Deflection",
		"Deflect your first projectile",
		"combat"
	))
	_add(Achievement.create_progressive(
		"deflect_50", "Reflector",
		"Deflect 50 projectiles",
		"combat", 50
	))
	_add(Achievement.create(
		"combo_10", "Combo Striker",
		"Achieve a 10-hit combo",
		"combat"
	))
	_add(Achievement.create(
		"combo_25", "Combo Master",
		"Achieve a 25-hit combo",
		"mastery"
	))

	# Wellness achievements
	_add(Achievement.create(
		"first_pose", "First Form",
		"Hold a recognized pose",
		"wellness"
	))
	_add(Achievement.create(
		"first_routine_completed", "Routine Beginner",
		"Complete your first wellness routine",
		"wellness"
	))
	_add(Achievement.create(
		"yoga_complete", "Yoga Practitioner",
		"Complete a yoga routine",
		"wellness"
	))
	_add(Achievement.create(
		"qi_gong_complete", "Qi Cultivator",
		"Complete a qi gong routine",
		"wellness"
	))
	_add(Achievement.create(
		"meditation_complete", "Meditation Practice",
		"Complete a meditation routine",
		"wellness"
	))
	_add(Achievement.create_progressive(
		"routines_10", "Routine Regular",
		"Complete 10 wellness routines",
		"wellness", 10
	))

	# Balance achievements
	_add(Achievement.create(
		"perfect_symmetry", "Balanced Force",
		"Achieve 95%+ left/right movement symmetry",
		"movement"
	))

	# Streak achievements
	_add(Achievement.create(
		"streak_7", "Week Warrior",
		"Train for 7 days in a row",
		"streak"
	))
	_add(Achievement.create(
		"streak_30", "Monthly Master",
		"Train for 30 days in a row",
		"mastery"
	))

	# Session achievements
	_add(Achievement.create(
		"session_30min", "Dedicated Trainee",
		"Complete a 30-minute session",
		"streak"
	))
	_add(Achievement.create(
		"session_60min", "Hour of Power",
		"Complete a 60-minute session",
		"mastery"
	))


func _add(achievement: Achievement) -> void:
	achievements[achievement.id] = achievement


func _save_unlocked() -> void:
	# Saved via SessionManager lifetime stats
	pass


func _load_unlocked() -> void:
	var stats := SessionManager.get_lifetime_stats()
	unlocked_achievements = stats.get("achievements", [])

	# Mark loaded achievements as unlocked
	for ach_id in unlocked_achievements:
		if achievements.has(ach_id):
			achievements[ach_id].is_unlocked = true


func _setup_notification_display() -> void:
	notification_display = AchievementNotification.new()
	notification_display.name = "AchievementNotification"
	notification_display.notification_complete.connect(_on_notification_complete)
	add_child(notification_display)


func _process_notification_queue() -> void:
	if is_showing_notification or notification_queue.is_empty():
		return

	var achievement := notification_queue.pop_front()
	is_showing_notification = true
	notification_display.show_achievement(achievement)


func _on_notification_complete() -> void:
	is_showing_notification = false


# Event handlers
func _on_zone_explored(position: Vector3, _hand: String) -> void:
	# Check directional achievements
	if position.y > 0.3:
		unlock("sky_reach")
	if position.y < -0.4:
		unlock("low_reach")
	if position.z < -0.2:
		unlock("behind_back")


func _on_target_hit(_target: Node3D, _damage: float, _position: Vector3) -> void:
	add_progress("targets_10", 1)
	add_progress("targets_100", 1)
	add_progress("targets_1000", 1)


func _on_pose_detected(pose_name: String, _confidence: float) -> void:
	unlock("first_pose")


func _on_session_ended(_session_id: String, summary: Dictionary) -> void:
	var duration: float = summary.get("duration", 0.0)

	if duration >= 1800:  # 30 minutes
		unlock("session_30min")
	if duration >= 3600:  # 60 minutes
		unlock("session_60min")


## AchievementNotification - VR popup for achievement unlocks
class AchievementNotification extends Node3D:
	signal notification_complete()

	var panel: MeshInstance3D
	var title_label: Label3D
	var description_label: Label3D
	var icon_sprite: Sprite3D

	var is_showing := false
	var show_duration := 4.0
	var fade_duration := 0.5
	var _timer := 0.0

	func _ready() -> void:
		visible = false
		_create_display()

	func _process(delta: float) -> void:
		if not is_showing:
			return

		_timer += delta
		if _timer >= show_duration:
			_hide()

		# Face camera
		var camera := get_viewport().get_camera_3d()
		if camera:
			look_at(camera.global_position, Vector3.UP)

	func show_achievement(achievement: Achievement) -> void:
		title_label.text = achievement.name
		description_label.text = achievement.description

		# Position in front of player
		var camera := get_viewport().get_camera_3d()
		if camera:
			global_position = camera.global_position + camera.global_transform.basis * Vector3(0, 0.3, -1.5)

		visible = true
		is_showing = true
		_timer = 0.0

		# Animate in
		var tween := create_tween()
		scale = Vector3.ZERO
		tween.tween_property(self, "scale", Vector3.ONE * 0.5, 0.3).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)

	func _hide() -> void:
		var tween := create_tween()
		tween.tween_property(self, "scale", Vector3.ZERO, fade_duration)
		tween.tween_callback(_on_hidden)

	func _on_hidden() -> void:
		visible = false
		is_showing = false
		notification_complete.emit()

	func _create_display() -> void:
		# Background panel
		panel = MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.8, 0.3, 0.02)
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.1, 0.1, 0.2, 0.9)
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.emission_enabled = true
		mat.emission = Color(0.2, 0.4, 0.8)
		mat.emission_energy_multiplier = 0.3
		box.material = mat
		panel.mesh = box
		add_child(panel)

		# Title
		title_label = Label3D.new()
		title_label.text = "Achievement Unlocked!"
		title_label.font_size = 48
		title_label.position = Vector3(0, 0.08, 0.02)
		title_label.modulate = Color(1.0, 0.9, 0.3)
		add_child(title_label)

		# Description
		description_label = Label3D.new()
		description_label.text = ""
		description_label.font_size = 32
		description_label.position = Vector3(0, -0.05, 0.02)
		description_label.modulate = Color(0.9, 0.9, 0.9)
		add_child(description_label)

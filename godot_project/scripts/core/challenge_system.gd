## ChallengeSystem - Daily, weekly, and custom challenges
## Provides goals and rewards to encourage regular play
class_name ChallengeSystem
extends Node

signal challenge_unlocked(challenge: Challenge)
signal challenge_progress(challenge: Challenge, progress: float)
signal challenge_completed(challenge: Challenge)
signal daily_reset
signal weekly_reset

## Challenge types
enum ChallengeType {
	DAILY,
	WEEKLY,
	ACHIEVEMENT,
	MILESTONE,
	CUSTOM
}

## Challenge categories
enum ChallengeCategory {
	COMBAT,
	MOVEMENT,
	WELLNESS,
	ACCURACY,
	ENDURANCE,
	COMBO,
	EXPLORATION,
	MASTERY
}

## Challenge definition
class Challenge:
	var id: String = ""
	var name: String = ""
	var description: String = ""
	var type: ChallengeType = ChallengeType.DAILY
	var category: ChallengeCategory = ChallengeCategory.COMBAT
	var target_value: float = 0.0
	var current_value: float = 0.0
	var reward_xp: int = 100
	var reward_achievement: String = ""
	var is_completed: bool = false
	var is_claimed: bool = false
	var expires_at: int = 0  # Unix timestamp, 0 = no expiry
	var created_at: int = 0
	var difficulty: int = 1  # 1-5 stars

	func get_progress() -> float:
		if target_value <= 0:
			return 0.0
		return clampf(current_value / target_value, 0.0, 1.0)

	func is_expired() -> bool:
		if expires_at == 0:
			return false
		return Time.get_unix_time_from_system() > expires_at

	func to_dict() -> Dictionary:
		return {
			"id": id,
			"name": name,
			"description": description,
			"type": type,
			"category": category,
			"target": target_value,
			"current": current_value,
			"reward_xp": reward_xp,
			"reward_achievement": reward_achievement,
			"completed": is_completed,
			"claimed": is_claimed,
			"expires": expires_at,
			"created": created_at,
			"difficulty": difficulty
		}

	static func from_dict(data: Dictionary) -> Challenge:
		var c := Challenge.new()
		c.id = data.get("id", "")
		c.name = data.get("name", "")
		c.description = data.get("description", "")
		c.type = data.get("type", ChallengeType.DAILY)
		c.category = data.get("category", ChallengeCategory.COMBAT)
		c.target_value = data.get("target", 0.0)
		c.current_value = data.get("current", 0.0)
		c.reward_xp = data.get("reward_xp", 100)
		c.reward_achievement = data.get("reward_achievement", "")
		c.is_completed = data.get("completed", false)
		c.is_claimed = data.get("claimed", false)
		c.expires_at = data.get("expires", 0)
		c.created_at = data.get("created", 0)
		c.difficulty = data.get("difficulty", 1)
		return c


## Challenge templates
class ChallengeTemplate:
	var id_prefix: String
	var name_template: String
	var description_template: String
	var category: ChallengeCategory
	var target_range: Vector2  # Min, max for random generation
	var base_xp: int
	var difficulty_range: Vector2i


## Active challenges
var daily_challenges: Array[Challenge] = []
var weekly_challenges: Array[Challenge] = []
var milestone_challenges: Array[Challenge] = []

## Templates for challenge generation
var challenge_templates: Array[ChallengeTemplate] = []

## Timing
var last_daily_reset: int = 0
var last_weekly_reset: int = 0

## Save path
const CHALLENGES_PATH := "user://challenges.json"


func _ready() -> void:
	_setup_templates()
	_load_challenges()
	_check_resets()


func _setup_templates() -> void:
	# Combat challenges
	_add_template("hit_targets", "Target Practice", "Hit {target} targets",
		ChallengeCategory.COMBAT, Vector2(20, 100), 50, Vector2i(1, 3))

	_add_template("perfect_hits", "Perfect Form", "Get {target} perfect hits",
		ChallengeCategory.ACCURACY, Vector2(5, 30), 75, Vector2i(2, 4))

	_add_template("deflections", "Deflection Master", "Deflect {target} projectiles",
		ChallengeCategory.COMBAT, Vector2(10, 50), 60, Vector2i(2, 4))

	_add_template("force_uses", "Force Wielder", "Use Force powers {target} times",
		ChallengeCategory.COMBAT, Vector2(10, 40), 50, Vector2i(1, 3))

	# Combo challenges
	_add_template("max_combo", "Combo King", "Reach a combo of {target}",
		ChallengeCategory.COMBO, Vector2(10, 50), 80, Vector2i(2, 5))

	_add_template("combo_total", "Combo Accumulator", "Accumulate {target} total combo",
		ChallengeCategory.COMBO, Vector2(50, 200), 60, Vector2i(1, 3))

	# Movement challenges
	_add_template("zones_discovered", "Explorer", "Discover {target} new movement zones",
		ChallengeCategory.EXPLORATION, Vector2(10, 50), 70, Vector2i(2, 4))

	_add_template("coverage", "Space Master", "Achieve {target}% space coverage",
		ChallengeCategory.MOVEMENT, Vector2(30, 80), 100, Vector2i(2, 5))

	_add_template("distance_moved", "Marathon", "Move your hands {target} meters total",
		ChallengeCategory.MOVEMENT, Vector2(50, 300), 50, Vector2i(1, 3))

	# Wellness challenges
	_add_template("routines_completed", "Wellness Warrior", "Complete {target} wellness routines",
		ChallengeCategory.WELLNESS, Vector2(1, 5), 100, Vector2i(2, 4))

	_add_template("poses_held", "Pose Master", "Hold {target} poses successfully",
		ChallengeCategory.WELLNESS, Vector2(5, 20), 60, Vector2i(1, 3))

	_add_template("active_minutes", "Stay Active", "Be active for {target} minutes",
		ChallengeCategory.ENDURANCE, Vector2(10, 60), 50, Vector2i(1, 4))

	# Endurance challenges
	_add_template("session_time", "Endurance Test", "Complete a {target} minute session",
		ChallengeCategory.ENDURANCE, Vector2(5, 30), 80, Vector2i(2, 5))

	_add_template("consecutive_days", "Daily Dedication", "Play for {target} consecutive days",
		ChallengeCategory.MASTERY, Vector2(3, 14), 150, Vector2i(3, 5))


func _add_template(id: String, name: String, desc: String, cat: ChallengeCategory,
					target: Vector2, xp: int, diff: Vector2i) -> void:
	var template := ChallengeTemplate.new()
	template.id_prefix = id
	template.name_template = name
	template.description_template = desc
	template.category = cat
	template.target_range = target
	template.base_xp = xp
	template.difficulty_range = diff
	challenge_templates.append(template)


func _check_resets() -> void:
	var now := Time.get_unix_time_from_system()
	var today := _get_day_start(now)
	var week_start := _get_week_start(now)

	# Daily reset
	if last_daily_reset < today:
		_reset_daily_challenges()
		last_daily_reset = today
		daily_reset.emit()

	# Weekly reset
	if last_weekly_reset < week_start:
		_reset_weekly_challenges()
		last_weekly_reset = week_start
		weekly_reset.emit()


func _get_day_start(timestamp: int) -> int:
	var datetime := Time.get_datetime_dict_from_unix_time(timestamp)
	datetime.hour = 0
	datetime.minute = 0
	datetime.second = 0
	return Time.get_unix_time_from_datetime_dict(datetime)


func _get_week_start(timestamp: int) -> int:
	var datetime := Time.get_datetime_dict_from_unix_time(timestamp)
	var days_since_monday := (datetime.weekday + 6) % 7  # Monday = 0
	datetime.hour = 0
	datetime.minute = 0
	datetime.second = 0
	var day_start := Time.get_unix_time_from_datetime_dict(datetime)
	return day_start - (days_since_monday * 86400)


func _reset_daily_challenges() -> void:
	daily_challenges.clear()
	_generate_daily_challenges()


func _reset_weekly_challenges() -> void:
	weekly_challenges.clear()
	_generate_weekly_challenges()


func _generate_daily_challenges() -> void:
	var now := Time.get_unix_time_from_system()
	var tomorrow := _get_day_start(now) + 86400

	# Generate 3 daily challenges
	var used_categories: Array[ChallengeCategory] = []

	for i in range(3):
		var template := _pick_random_template(used_categories)
		if template == null:
			continue

		used_categories.append(template.category)

		var challenge := _create_from_template(template, ChallengeType.DAILY)
		challenge.expires_at = tomorrow
		challenge.difficulty = randi_range(1, 3)
		daily_challenges.append(challenge)
		challenge_unlocked.emit(challenge)


func _generate_weekly_challenges() -> void:
	var now := Time.get_unix_time_from_system()
	var next_week := _get_week_start(now) + (7 * 86400)

	# Generate 5 weekly challenges (harder)
	var used_categories: Array[ChallengeCategory] = []

	for i in range(5):
		var template := _pick_random_template(used_categories)
		if template == null:
			continue

		used_categories.append(template.category)

		var challenge := _create_from_template(template, ChallengeType.WEEKLY)
		challenge.expires_at = next_week
		challenge.difficulty = randi_range(2, 5)
		# Weekly challenges have higher targets
		challenge.target_value *= 3.0
		challenge.reward_xp *= 2
		weekly_challenges.append(challenge)
		challenge_unlocked.emit(challenge)


func _pick_random_template(exclude_categories: Array[ChallengeCategory]) -> ChallengeTemplate:
	var available: Array[ChallengeTemplate] = []
	for template in challenge_templates:
		if template.category not in exclude_categories:
			available.append(template)

	if available.is_empty():
		return challenge_templates[randi() % challenge_templates.size()]

	return available[randi() % available.size()]


func _create_from_template(template: ChallengeTemplate, type: ChallengeType) -> Challenge:
	var challenge := Challenge.new()
	var target := randi_range(int(template.target_range.x), int(template.target_range.y))

	challenge.id = "%s_%d" % [template.id_prefix, Time.get_unix_time_from_system()]
	challenge.name = template.name_template
	challenge.description = template.description_template.replace("{target}", str(target))
	challenge.type = type
	challenge.category = template.category
	challenge.target_value = float(target)
	challenge.reward_xp = template.base_xp
	challenge.created_at = Time.get_unix_time_from_system()
	challenge.difficulty = randi_range(template.difficulty_range.x, template.difficulty_range.y)

	return challenge


## Progress tracking
func add_progress(stat_name: String, amount: float) -> void:
	var all_challenges := daily_challenges + weekly_challenges + milestone_challenges

	for challenge in all_challenges:
		if challenge.is_completed or challenge.is_expired():
			continue

		if _matches_stat(challenge, stat_name):
			challenge.current_value += amount
			challenge_progress.emit(challenge, challenge.get_progress())

			if challenge.current_value >= challenge.target_value:
				_complete_challenge(challenge)


func _matches_stat(challenge: Challenge, stat_name: String) -> bool:
	# Map stat names to challenge id prefixes
	var mappings := {
		"targets_hit": "hit_targets",
		"perfect_hits": "perfect_hits",
		"deflections": "deflections",
		"force_uses": "force_uses",
		"max_combo": "max_combo",
		"combo_total": "combo_total",
		"zones_discovered": "zones_discovered",
		"coverage": "coverage",
		"distance_moved": "distance_moved",
		"routines_completed": "routines_completed",
		"poses_held": "poses_held",
		"active_minutes": "active_minutes",
		"session_time": "session_time"
	}

	var prefix: String = mappings.get(stat_name, "")
	return challenge.id.begins_with(prefix)


func _complete_challenge(challenge: Challenge) -> void:
	challenge.is_completed = true
	challenge_completed.emit(challenge)

	# Grant reward achievement if specified
	if challenge.reward_achievement != "":
		GameEvents.achievement_unlocked.emit(challenge.reward_achievement)


func claim_challenge(challenge_id: String) -> int:
	var challenge := _find_challenge(challenge_id)
	if challenge == null or not challenge.is_completed or challenge.is_claimed:
		return 0

	challenge.is_claimed = true
	_save_challenges()
	return challenge.reward_xp


func _find_challenge(challenge_id: String) -> Challenge:
	for c in daily_challenges + weekly_challenges + milestone_challenges:
		if c.id == challenge_id:
			return c
	return null


## Getters
func get_daily_challenges() -> Array[Challenge]:
	return daily_challenges


func get_weekly_challenges() -> Array[Challenge]:
	return weekly_challenges


func get_active_challenges() -> Array[Challenge]:
	var active: Array[Challenge] = []
	for c in daily_challenges + weekly_challenges:
		if not c.is_expired() and not c.is_claimed:
			active.append(c)
	return active


func get_completed_unclaimed() -> Array[Challenge]:
	var unclaimed: Array[Challenge] = []
	for c in daily_challenges + weekly_challenges + milestone_challenges:
		if c.is_completed and not c.is_claimed:
			unclaimed.append(c)
	return unclaimed


## Save/Load
func _save_challenges() -> void:
	var data := {
		"last_daily_reset": last_daily_reset,
		"last_weekly_reset": last_weekly_reset,
		"daily": [],
		"weekly": [],
		"milestones": []
	}

	for c in daily_challenges:
		data.daily.append(c.to_dict())
	for c in weekly_challenges:
		data.weekly.append(c.to_dict())
	for c in milestone_challenges:
		data.milestones.append(c.to_dict())

	var json_string := JSON.stringify(data, "\t")
	var file := FileAccess.open(CHALLENGES_PATH, FileAccess.WRITE)
	if file:
		file.store_string(json_string)
		file.close()


func _load_challenges() -> void:
	var file := FileAccess.open(CHALLENGES_PATH, FileAccess.READ)
	if file == null:
		_generate_daily_challenges()
		_generate_weekly_challenges()
		return

	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		file.close()
		return
	file.close()

	var data: Dictionary = json.data
	last_daily_reset = data.get("last_daily_reset", 0)
	last_weekly_reset = data.get("last_weekly_reset", 0)

	daily_challenges.clear()
	for c_data in data.get("daily", []):
		daily_challenges.append(Challenge.from_dict(c_data))

	weekly_challenges.clear()
	for c_data in data.get("weekly", []):
		weekly_challenges.append(Challenge.from_dict(c_data))

	milestone_challenges.clear()
	for c_data in data.get("milestones", []):
		milestone_challenges.append(Challenge.from_dict(c_data))

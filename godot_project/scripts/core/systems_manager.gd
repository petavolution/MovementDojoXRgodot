## SystemsManager - Lazy-loading manager for secondary systems
## Provides on-demand instantiation of non-essential systems
## This keeps startup fast and memory efficient
extends Node
class_name SystemsManager

const SOURCE := "SystemsManager"

# Singleton instance (set by main scene, not autoload)
static var instance: SystemsManager

# System references (lazy-loaded)
var _analytics: Node
var _audio_manager: Node
var _score_manager: Node
var _adaptive_difficulty: Node
var _replay_system: Node
var _calibration_system: Node
var _achievement_system: Node

# Loading state tracking
var _loading_errors: Array[String] = []

# System scripts
const SCRIPTS := {
	"analytics": "res://scripts/analytics/movement_analytics.gd",
	"audio": "res://scripts/core/audio_manager.gd",
	"score": "res://scripts/core/score_manager.gd",
	"difficulty": "res://scripts/core/adaptive_difficulty.gd",
	"replay": "res://scripts/core/replay_system.gd",
	"calibration": "res://scripts/core/calibration_system.gd",
	"achievement": "res://scripts/core/achievement_system.gd"
}


func _ready() -> void:
	instance = self
	name = "SystemsManager"
	DebugLogger.info(SOURCE, "SystemsManager initialized")


func _exit_tree() -> void:
	DebugLogger.info(SOURCE, "SystemsManager shutting down")
	if instance == self:
		instance = null


# =============================================================================
# LAZY ACCESSORS
# =============================================================================

## Get MovementAnalytics (creates if needed)
func get_analytics() -> Node:
	if _analytics == null:
		_analytics = _load_system("analytics", "MovementAnalytics")
	return _analytics


## Get AudioManager (creates if needed)
func get_audio() -> Node:
	if _audio_manager == null:
		_audio_manager = _load_system("audio", "AudioManager")
	return _audio_manager


## Get ScoreManager (creates if needed)
func get_score() -> Node:
	if _score_manager == null:
		_score_manager = _load_system("score", "ScoreManager")
	return _score_manager


## Get AdaptiveDifficulty (creates if needed)
func get_difficulty() -> Node:
	if _adaptive_difficulty == null:
		_adaptive_difficulty = _load_system("difficulty", "AdaptiveDifficulty")
	return _adaptive_difficulty


## Get ReplaySystem (creates if needed)
func get_replay() -> Node:
	if _replay_system == null:
		_replay_system = _load_system("replay", "ReplaySystem")
	return _replay_system


## Get CalibrationSystem (creates if needed)
func get_calibration() -> Node:
	if _calibration_system == null:
		_calibration_system = _load_system("calibration", "CalibrationSystem")
	return _calibration_system


## Get AchievementSystem (creates if needed)
func get_achievement() -> Node:
	if _achievement_system == null:
		_achievement_system = _load_system("achievement", "AchievementSystem")
	return _achievement_system


# =============================================================================
# STATIC ACCESSORS (for global access)
# =============================================================================

static func analytics() -> Node:
	return instance.get_analytics() if instance else null


static func audio() -> Node:
	return instance.get_audio() if instance else null


static func score() -> Node:
	return instance.get_score() if instance else null


static func difficulty() -> Node:
	return instance.get_difficulty() if instance else null


static func replay() -> Node:
	return instance.get_replay() if instance else null


static func calibration() -> Node:
	return instance.get_calibration() if instance else null


static func achievement() -> Node:
	return instance.get_achievement() if instance else null


# =============================================================================
# PRELOADING (for modes that need multiple systems)
# =============================================================================

## Preload systems needed for training mode
func preload_training_systems() -> void:
	DebugLogger.info(SOURCE, "Preloading training systems...")
	get_analytics()
	get_score()
	get_audio()
	get_difficulty()
	DebugLogger.info(SOURCE, "Training systems preloaded")


## Preload systems needed for wellness mode
func preload_wellness_systems() -> void:
	DebugLogger.info(SOURCE, "Preloading wellness systems...")
	get_analytics()
	get_audio()
	DebugLogger.info(SOURCE, "Wellness systems preloaded")


## Unload non-essential systems to free memory
func unload_optional_systems() -> void:
	if _replay_system:
		_replay_system.queue_free()
		_replay_system = null
		DebugLogger.info(SOURCE, "Unloaded ReplaySystem")

	if _adaptive_difficulty:
		_adaptive_difficulty.queue_free()
		_adaptive_difficulty = null
		DebugLogger.info(SOURCE, "Unloaded AdaptiveDifficulty")

	DebugLogger.info(SOURCE, "Optional systems unloaded")


# =============================================================================
# INTERNAL
# =============================================================================

func _load_system(key: String, node_name: String) -> Node:
	if not SCRIPTS.has(key):
		var err_msg := "Unknown system key: " + key
		DebugLogger.error(SOURCE, err_msg)
		_loading_errors.append(err_msg)
		return null

	var script_path: String = SCRIPTS[key]
	DebugLogger.debug(SOURCE, "Loading system: %s from %s" % [node_name, script_path])

	# Check if file exists
	if not ResourceLoader.exists(script_path):
		var err_msg := "Script file not found: " + script_path
		DebugLogger.error(SOURCE, err_msg)
		_loading_errors.append(err_msg)
		return null

	var script := load(script_path)
	if script == null:
		var err_msg := "Failed to load script: " + script_path
		DebugLogger.error(SOURCE, err_msg)
		_loading_errors.append(err_msg)
		return null

	var node := Node.new()
	node.set_script(script)
	node.name = node_name
	add_child(node)

	DebugLogger.info(SOURCE, "Loaded: " + node_name)
	return node


## Get any loading errors that occurred
func get_loading_errors() -> Array[String]:
	return _loading_errors.duplicate()


## Check if a system is loaded
func is_loaded(system_name: String) -> bool:
	match system_name:
		"analytics": return _analytics != null
		"audio": return _audio_manager != null
		"score": return _score_manager != null
		"difficulty": return _adaptive_difficulty != null
		"replay": return _replay_system != null
		"calibration": return _calibration_system != null
		"achievement": return _achievement_system != null
	return false


## Get list of loaded systems
func get_loaded_systems() -> Array[String]:
	var loaded: Array[String] = []
	if _analytics: loaded.append("analytics")
	if _audio_manager: loaded.append("audio")
	if _score_manager: loaded.append("score")
	if _adaptive_difficulty: loaded.append("difficulty")
	if _replay_system: loaded.append("replay")
	if _calibration_system: loaded.append("calibration")
	if _achievement_system: loaded.append("achievement")
	return loaded

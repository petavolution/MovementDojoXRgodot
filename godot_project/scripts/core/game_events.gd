## Game Events - Global signal bus for decoupled communication
## Autoloaded as "GameEvents"
extends Node

const SOURCE := "GameEvents"


func _ready() -> void:
	DebugLogger.info(SOURCE, "GameEvents signal bus initialized")


# Movement events
signal movement_frame_recorded(frame: MovementFrame)
signal movement_zone_explored(zone_position: Vector3, hand: String)
signal movement_coverage_updated(coverage_percent: float)
signal movement_gap_detected(gap_positions: Array[Vector3])

# Combat events
signal saber_activated(hand: String)
signal saber_deactivated(hand: String)
signal saber_clash(position: Vector3, velocity: float)
signal target_hit(target: Node3D, damage: float, position: Vector3)
signal projectile_deflected(projectile: Node3D, direction: Vector3)

# Wellness events
signal pose_detected(pose_name: String, confidence: float)
signal pose_lost(pose_name: String)
signal symmetry_updated(score: float)
signal routine_step_completed(routine_name: String, step_index: int)
signal achievement_unlocked(achievement_id: String)

# Session events
signal session_started(session_id: String)
signal session_ended(session_id: String, summary: Dictionary)
signal session_paused()
signal session_resumed()

# Analytics events
signal analytics_updated(stats: Dictionary)
signal heat_map_updated(heat_map_data: Array)

# UI events
signal hud_visibility_changed(visible: bool)
signal menu_opened(menu_name: String)
signal menu_closed(menu_name: String)

# Score and combo events
signal score_changed(new_score: int)
signal combo_changed(combo: int)
signal combo_lost()
signal multiplier_changed(multiplier: float)

# Target events
signal target_spawned(target: Node3D)
signal target_destroyed(target: Node3D, velocity: float)
signal target_missed(target: Node3D)

# Force power events
signal force_push_activated(position: Vector3, direction: Vector3)
signal force_pull_activated(position: Vector3)
signal force_power_ready(power_type: String)

# Training events
signal training_mode_started(mode_name: String)
signal training_mode_ended(mode_name: String, results: Dictionary)
signal wave_started(wave_number: int)
signal wave_completed(wave_number: int)

# Tutorial events
signal tutorial_started(tutorial_id: String)
signal tutorial_step_changed(step_name: String, instruction: String)
signal tutorial_completed(tutorial_id: String)

# Difficulty events
signal difficulty_changed(new_level: float)
signal difficulty_zone_entered(zone_name: String)

# Replay events
signal replay_recording_started()
signal replay_recording_stopped()
signal replay_playback_started()
signal replay_playback_stopped()

# Environment events
signal environment_changed(env_name: String)
signal theme_changed(theme_name: String)

# VFX and haptic requests
signal vfx_requested(effect_name: String, position: Vector3, direction: Vector3)
signal sfx_requested(sound_name: String, position: Vector3)
signal haptic_feedback(hand: int, pattern: Resource, intensity: float)

# Calibration events
signal calibration_started()
signal calibration_completed(data: Dictionary)

# Avatar events
signal avatar_pose_updated()
signal avatar_visibility_changed(visible: bool)

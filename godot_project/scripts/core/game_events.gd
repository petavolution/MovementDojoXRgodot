## Game Events - Global signal bus for decoupled communication
## Autoloaded as "GameEvents"
extends Node

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

## TargetPattern - Choreographed target sequences
## Defines timed spawn patterns for rhythm-based gameplay
class_name TargetPattern
extends Resource

signal pattern_started
signal beat_triggered(beat_index: int, spawn_data: BeatData)
signal pattern_completed

## Single beat in the pattern
class BeatData:
	var time_offset: float = 0.0  # Seconds from pattern start
	var positions: Array[Vector3] = []  # Target spawn positions
	var directions: Array[Vector3] = []  # Required hit directions (optional)
	var target_types: Array[int] = []  # 0=normal, 1=hold, 2=avoid
	var duration: float = 0.0  # For hold targets

	func add_target(pos: Vector3, dir: Vector3 = Vector3.ZERO, type: int = 0, dur: float = 0.0) -> BeatData:
		positions.append(pos)
		directions.append(dir)
		target_types.append(type)
		duration = dur
		return self


@export var pattern_name: String = "Unnamed Pattern"
@export var description: String = ""
@export var difficulty: float = 0.5  # 0.0-1.0
@export var bpm: float = 120.0
@export var duration_seconds: float = 30.0

var beats: Array[BeatData] = []
var is_playing: bool = false
var current_time: float = 0.0
var current_beat_index: int = 0


func add_beat(time: float) -> BeatData:
	var beat := BeatData.new()
	beat.time_offset = time
	beats.append(beat)
	# Keep sorted by time
	beats.sort_custom(func(a, b): return a.time_offset < b.time_offset)
	return beat


func clear_beats() -> void:
	beats.clear()


func get_beat_interval() -> float:
	return 60.0 / bpm


## Pre-built pattern generators
static func create_horizontal_sweep(bpm: float, measures: int) -> TargetPattern:
	var pattern := TargetPattern.new()
	pattern.pattern_name = "Horizontal Sweep"
	pattern.description = "Sweep targets from left to right"
	pattern.bpm = bpm
	pattern.difficulty = 0.3

	var interval := 60.0 / bpm
	var positions := [-1.0, -0.5, 0.0, 0.5, 1.0]
	var time := 0.0

	for measure in range(measures):
		for i in range(positions.size()):
			var beat := pattern.add_beat(time)
			var pos := Vector3(positions[i], 1.2, -1.5)
			beat.add_target(pos, Vector3.RIGHT)
			time += interval

	pattern.duration_seconds = time
	return pattern


static func create_vertical_ladder(bpm: float, measures: int) -> TargetPattern:
	var pattern := TargetPattern.new()
	pattern.pattern_name = "Vertical Ladder"
	pattern.description = "Climb up and down with alternating hands"
	pattern.bpm = bpm
	pattern.difficulty = 0.4

	var interval := 60.0 / bpm
	var heights := [0.5, 0.8, 1.1, 1.4, 1.7, 1.4, 1.1, 0.8]
	var time := 0.0

	for measure in range(measures):
		for i in range(heights.size()):
			var beat := pattern.add_beat(time)
			var side := -0.5 if i % 2 == 0 else 0.5
			var pos := Vector3(side, heights[i], -1.5)
			beat.add_target(pos, Vector3.UP if i < 4 else Vector3.DOWN)
			time += interval

	pattern.duration_seconds = time
	return pattern


static func create_cross_pattern(bpm: float, measures: int) -> TargetPattern:
	var pattern := TargetPattern.new()
	pattern.pattern_name = "Cross Pattern"
	pattern.description = "Diagonal crosses requiring both hands"
	pattern.bpm = bpm
	pattern.difficulty = 0.5

	var interval := 60.0 / bpm
	var time := 0.0

	for measure in range(measures):
		# Top-left to bottom-right
		var beat1 := pattern.add_beat(time)
		beat1.add_target(Vector3(-0.7, 1.6, -1.5), Vector3(1, -1, 0).normalized())
		time += interval

		beat1 = pattern.add_beat(time)
		beat1.add_target(Vector3(0.7, 0.6, -1.5), Vector3(1, -1, 0).normalized())
		time += interval

		# Top-right to bottom-left
		var beat2 := pattern.add_beat(time)
		beat2.add_target(Vector3(0.7, 1.6, -1.5), Vector3(-1, -1, 0).normalized())
		time += interval

		beat2 = pattern.add_beat(time)
		beat2.add_target(Vector3(-0.7, 0.6, -1.5), Vector3(-1, -1, 0).normalized())
		time += interval

	pattern.duration_seconds = time
	return pattern


static func create_double_strike(bpm: float, measures: int) -> TargetPattern:
	var pattern := TargetPattern.new()
	pattern.pattern_name = "Double Strike"
	pattern.description = "Hit two targets simultaneously"
	pattern.bpm = bpm
	pattern.difficulty = 0.6

	var interval := 60.0 / bpm * 2  # Half-notes
	var time := 0.0

	for measure in range(measures):
		var beat := pattern.add_beat(time)
		beat.add_target(Vector3(-0.6, 1.2, -1.5), Vector3.RIGHT)
		beat.add_target(Vector3(0.6, 1.2, -1.5), Vector3.LEFT)
		time += interval

		beat = pattern.add_beat(time)
		beat.add_target(Vector3(-0.4, 0.8, -1.5), Vector3.DOWN)
		beat.add_target(Vector3(0.4, 1.6, -1.5), Vector3.UP)
		time += interval

	pattern.duration_seconds = time
	return pattern


static func create_circle_pattern(bpm: float, repetitions: int) -> TargetPattern:
	var pattern := TargetPattern.new()
	pattern.pattern_name = "Circle"
	pattern.description = "Targets in a circular pattern"
	pattern.bpm = bpm
	pattern.difficulty = 0.4

	var interval := 60.0 / bpm
	var time := 0.0
	var points := 8

	for rep in range(repetitions):
		for i in range(points):
			var angle := (float(i) / points) * TAU
			var radius := 0.7
			var center_y := 1.2

			var beat := pattern.add_beat(time)
			var pos := Vector3(cos(angle) * radius, center_y + sin(angle) * radius, -1.5)

			# Direction tangent to circle
			var dir := Vector3(-sin(angle), cos(angle), 0)
			beat.add_target(pos, dir)
			time += interval

	pattern.duration_seconds = time
	return pattern


static func create_figure_eight(bpm: float, repetitions: int) -> TargetPattern:
	var pattern := TargetPattern.new()
	pattern.pattern_name = "Figure Eight"
	pattern.description = "Infinity pattern for flow training"
	pattern.bpm = bpm
	pattern.difficulty = 0.5

	var interval := 60.0 / bpm
	var time := 0.0
	var points := 16

	for rep in range(repetitions):
		for i in range(points):
			var t := float(i) / points * TAU
			# Lemniscate of Bernoulli (figure 8)
			var scale := 0.6
			var x := scale * cos(t) / (1 + sin(t) * sin(t))
			var y := scale * sin(t) * cos(t) / (1 + sin(t) * sin(t))

			var beat := pattern.add_beat(time)
			var pos := Vector3(x, 1.2 + y, -1.5)
			beat.add_target(pos)
			time += interval

	pattern.duration_seconds = time
	return pattern


static func create_burst_pattern(bpm: float, bursts: int) -> TargetPattern:
	var pattern := TargetPattern.new()
	pattern.pattern_name = "Burst"
	pattern.description = "Quick bursts of targets with rest periods"
	pattern.bpm = bpm
	pattern.difficulty = 0.7

	var quick_interval := 60.0 / bpm / 2  # Eighth notes
	var rest_interval := 60.0 / bpm * 2  # Half note rest
	var time := 0.0

	for burst in range(bursts):
		# 4 quick targets
		for i in range(4):
			var beat := pattern.add_beat(time)
			var x := randf_range(-0.8, 0.8)
			var y := randf_range(0.6, 1.6)
			beat.add_target(Vector3(x, y, -1.5))
			time += quick_interval

		# Rest
		time += rest_interval

	pattern.duration_seconds = time
	return pattern


static func create_warmup_pattern() -> TargetPattern:
	var pattern := TargetPattern.new()
	pattern.pattern_name = "Warmup"
	pattern.description = "Gentle warmup sequence"
	pattern.bpm = 80.0
	pattern.difficulty = 0.1

	var interval := 60.0 / 80.0 * 2  # Slow
	var time := 0.0

	# Simple left-right alternation at comfortable height
	for i in range(16):
		var beat := pattern.add_beat(time)
		var side := -0.5 if i % 2 == 0 else 0.5
		beat.add_target(Vector3(side, 1.2, -1.5))
		time += interval

	pattern.duration_seconds = time
	return pattern


static func create_full_body_pattern(bpm: float, measures: int) -> TargetPattern:
	var pattern := TargetPattern.new()
	pattern.pattern_name = "Full Body"
	pattern.description = "Targets across your entire movement space"
	pattern.bpm = bpm
	pattern.difficulty = 0.8

	var interval := 60.0 / bpm
	var time := 0.0

	# Zones: high-left, high-right, mid-left, mid-right, low-left, low-right
	var zones := [
		Vector3(-0.8, 1.8, -1.5),  # High left
		Vector3(0.8, 1.8, -1.5),   # High right
		Vector3(-0.9, 1.2, -1.3),  # Mid left (slightly forward)
		Vector3(0.9, 1.2, -1.3),   # Mid right
		Vector3(-0.6, 0.4, -1.2),  # Low left
		Vector3(0.6, 0.4, -1.2),   # Low right
	]

	for measure in range(measures):
		# Randomize zone order each measure
		var shuffled := zones.duplicate()
		shuffled.shuffle()

		for pos in shuffled:
			var beat := pattern.add_beat(time)
			beat.add_target(pos)
			time += interval

	pattern.duration_seconds = time
	return pattern

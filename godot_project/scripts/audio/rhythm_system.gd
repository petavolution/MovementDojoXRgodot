## RhythmSystem - Music-synchronized gameplay for beat-based training
## Handles beat detection, synchronization, and rhythm-based scoring
class_name RhythmSystem
extends Node

signal beat_occurred(beat_number: int, beat_time: float)
signal measure_started(measure_number: int)
signal rhythm_started(track_name: String)
signal rhythm_stopped
signal perfect_timing(offset_ms: float)
signal good_timing(offset_ms: float)
signal missed_timing

## Timing windows (in milliseconds)
const PERFECT_WINDOW := 50.0   # +/- 50ms
const GOOD_WINDOW := 100.0     # +/- 100ms
const OK_WINDOW := 150.0       # +/- 150ms

## Track data
class RhythmTrack:
	var name: String = ""
	var audio_stream: AudioStream
	var bpm: float = 120.0
	var time_signature_numerator: int = 4
	var time_signature_denominator: int = 4
	var offset_ms: float = 0.0  # Audio offset for sync
	var beats: Array[float] = []  # Pre-calculated beat times
	var intensity_curve: Curve  # Energy over time


## State
var current_track: RhythmTrack
var is_playing: bool = false
var playback_time: float = 0.0
var current_beat: int = 0
var current_measure: int = 0

## Audio
var music_player: AudioStreamPlayer
var beat_interval: float = 0.5  # Seconds per beat

## Beat tracking
var next_beat_time: float = 0.0
var beats_per_measure: int = 4

## Hit detection
var pending_hits: Array[Dictionary] = []  # {time, position, direction}
var hit_results: Array[Dictionary] = []

## Calibration
var audio_latency_offset: float = 0.0
var input_latency_offset: float = 0.0

## Pre-loaded tracks
var tracks: Dictionary = {}


func _ready() -> void:
	music_player = AudioStreamPlayer.new()
	music_player.bus = "Music"
	add_child(music_player)

	_setup_default_tracks()


func _process(delta: float) -> void:
	if not is_playing:
		return

	playback_time = music_player.get_playback_position()

	_check_beats()
	_process_pending_hits()


func _setup_default_tracks() -> void:
	# Training track - simple 4/4 beat
	var training := RhythmTrack.new()
	training.name = "Training Beat"
	training.bpm = 100.0
	training.time_signature_numerator = 4
	training.time_signature_denominator = 4
	tracks["training"] = training

	# Warmup track - slower tempo
	var warmup := RhythmTrack.new()
	warmup.name = "Warmup Flow"
	warmup.bpm = 80.0
	warmup.time_signature_numerator = 4
	warmup.time_signature_denominator = 4
	tracks["warmup"] = warmup

	# Intense track - faster tempo
	var intense := RhythmTrack.new()
	intense.name = "Intense Combat"
	intense.bpm = 140.0
	intense.time_signature_numerator = 4
	intense.time_signature_denominator = 4
	tracks["intense"] = intense

	# Meditation track - very slow
	var meditation := RhythmTrack.new()
	meditation.name = "Meditation"
	meditation.bpm = 60.0
	meditation.time_signature_numerator = 3
	meditation.time_signature_denominator = 4
	tracks["meditation"] = meditation


func load_track(track_id: String, audio: AudioStream = null) -> bool:
	if not tracks.has(track_id):
		return false

	current_track = tracks[track_id]

	if audio:
		current_track.audio_stream = audio

	# Calculate beat times
	_calculate_beat_times()

	return true


func _calculate_beat_times() -> void:
	if current_track == null:
		return

	current_track.beats.clear()
	beat_interval = 60.0 / current_track.bpm
	beats_per_measure = current_track.time_signature_numerator

	# Calculate beats for track duration (or reasonable default)
	var duration := 300.0  # 5 minutes default
	if current_track.audio_stream:
		duration = current_track.audio_stream.get_length()

	var time := current_track.offset_ms / 1000.0
	while time < duration:
		current_track.beats.append(time)
		time += beat_interval


func start_rhythm(track_id: String = "") -> void:
	if track_id != "" and tracks.has(track_id):
		load_track(track_id)

	if current_track == null:
		push_error("No track loaded")
		return

	playback_time = 0.0
	current_beat = 0
	current_measure = 0
	next_beat_time = current_track.offset_ms / 1000.0
	pending_hits.clear()
	hit_results.clear()

	if current_track.audio_stream:
		music_player.stream = current_track.audio_stream
		music_player.play()

	is_playing = true
	rhythm_started.emit(current_track.name)


func stop_rhythm() -> void:
	is_playing = false
	music_player.stop()
	rhythm_stopped.emit()


func pause_rhythm() -> void:
	is_playing = false
	music_player.stream_paused = true


func resume_rhythm() -> void:
	is_playing = true
	music_player.stream_paused = false


func _check_beats() -> void:
	if current_track == null:
		return

	var adjusted_time := playback_time + audio_latency_offset

	# Check if we've passed the next beat
	while current_beat < current_track.beats.size() and adjusted_time >= current_track.beats[current_beat]:
		beat_occurred.emit(current_beat, current_track.beats[current_beat])

		# Check for measure start
		if current_beat % beats_per_measure == 0:
			current_measure = current_beat / beats_per_measure
			measure_started.emit(current_measure)

		current_beat += 1

		# Update next beat time
		if current_beat < current_track.beats.size():
			next_beat_time = current_track.beats[current_beat]


## Schedule a target hit at a specific beat
func schedule_hit(beat_number: int, position: Vector3, direction: Vector3 = Vector3.ZERO) -> void:
	if current_track == null or beat_number >= current_track.beats.size():
		return

	pending_hits.append({
		"beat": beat_number,
		"time": current_track.beats[beat_number],
		"position": position,
		"direction": direction,
		"processed": false
	})


## Register a player hit and evaluate timing
func register_hit(hit_time: float) -> Dictionary:
	var adjusted_time := hit_time + input_latency_offset

	# Find closest beat
	var closest_beat := -1
	var closest_offset := INF

	for i in range(max(0, current_beat - 2), min(current_track.beats.size(), current_beat + 3)):
		var beat_time := current_track.beats[i]
		var offset := abs(adjusted_time - beat_time) * 1000.0  # Convert to ms

		if offset < closest_offset:
			closest_offset = offset
			closest_beat = i

	# Evaluate timing
	var result := {
		"beat": closest_beat,
		"offset_ms": closest_offset,
		"rating": "miss",
		"score_multiplier": 0.0
	}

	if closest_offset <= PERFECT_WINDOW:
		result.rating = "perfect"
		result.score_multiplier = 1.5
		perfect_timing.emit(closest_offset)
	elif closest_offset <= GOOD_WINDOW:
		result.rating = "good"
		result.score_multiplier = 1.0
		good_timing.emit(closest_offset)
	elif closest_offset <= OK_WINDOW:
		result.rating = "ok"
		result.score_multiplier = 0.5
	else:
		result.rating = "miss"
		result.score_multiplier = 0.0
		missed_timing.emit()

	hit_results.append(result)
	return result


func _process_pending_hits() -> void:
	var current_time := playback_time + audio_latency_offset
	var to_remove: Array[int] = []

	for i in range(pending_hits.size()):
		var hit: Dictionary = pending_hits[i]
		if hit.processed:
			continue

		var hit_time: float = hit.time
		var time_until := hit_time - current_time

		# If hit window has passed, mark as missed
		if time_until < -OK_WINDOW / 1000.0:
			hit.processed = true
			to_remove.append(i)
			missed_timing.emit()

	# Remove processed hits
	for i in range(to_remove.size() - 1, -1, -1):
		pending_hits.remove_at(to_remove[i])


## Get time until next beat (for UI sync)
func get_time_to_next_beat() -> float:
	if current_track == null or not is_playing:
		return 0.0

	return next_beat_time - playback_time


## Get beat progress (0-1, for animations)
func get_beat_progress() -> float:
	if current_track == null or not is_playing:
		return 0.0

	var prev_beat_time := 0.0
	if current_beat > 0 and current_beat <= current_track.beats.size():
		prev_beat_time = current_track.beats[current_beat - 1]

	var progress := (playback_time - prev_beat_time) / beat_interval
	return clampf(progress, 0.0, 1.0)


## Get current intensity (for adaptive difficulty/visuals)
func get_intensity() -> float:
	if current_track == null or current_track.intensity_curve == null:
		return 0.5

	var track_progress := playback_time / current_track.audio_stream.get_length() if current_track.audio_stream else 0.0
	return current_track.intensity_curve.sample(track_progress)


## Calibration
func set_audio_latency(ms: float) -> void:
	audio_latency_offset = ms / 1000.0


func set_input_latency(ms: float) -> void:
	input_latency_offset = ms / 1000.0


## Get BPM
func get_bpm() -> float:
	return current_track.bpm if current_track else 120.0


## Get current beat
func get_current_beat() -> int:
	return current_beat


## Get current measure
func get_current_measure() -> int:
	return current_measure


## Get beat interval in seconds
func get_beat_interval() -> float:
	return beat_interval


## Get accuracy statistics
func get_accuracy_stats() -> Dictionary:
	if hit_results.is_empty():
		return {"perfect": 0, "good": 0, "ok": 0, "miss": 0, "accuracy": 0.0}

	var stats := {"perfect": 0, "good": 0, "ok": 0, "miss": 0}

	for result in hit_results:
		stats[result.rating] += 1

	var total := hit_results.size()
	var weighted := stats.perfect * 1.0 + stats.good * 0.75 + stats.ok * 0.5
	stats.accuracy = (weighted / total) * 100.0 if total > 0 else 0.0

	return stats


## Create track from BPM (for procedural rhythm)
func create_procedural_track(name: String, bpm: float, time_sig_num: int = 4, time_sig_denom: int = 4) -> RhythmTrack:
	var track := RhythmTrack.new()
	track.name = name
	track.bpm = bpm
	track.time_signature_numerator = time_sig_num
	track.time_signature_denominator = time_sig_denom

	tracks[name.to_lower().replace(" ", "_")] = track
	return track

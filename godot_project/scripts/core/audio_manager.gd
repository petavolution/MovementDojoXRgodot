## AudioManager - Centralized audio management for VR
## Handles spatial audio, music, and sound effects
## Autoloaded as "AudioManager"
extends Node

# Audio buses
const BUS_MASTER := "Master"
const BUS_MUSIC := "Music"
const BUS_SFX := "SFX"
const BUS_VOICE := "Voice"
const BUS_AMBIENT := "Ambient"

# Volume settings (linear 0-1)
var master_volume := 1.0
var music_volume := 0.7
var sfx_volume := 1.0
var voice_volume := 1.0
var ambient_volume := 0.5

# Audio pools for frequently used sounds
var sfx_pool: Array[AudioStreamPlayer3D] = []
var sfx_2d_pool: Array[AudioStreamPlayer] = []
const POOL_SIZE := 16

# Music player
var music_player: AudioStreamPlayer
var music_crossfade_player: AudioStreamPlayer
var current_music: String = ""
var is_crossfading := false

# Ambient soundscape
var ambient_player: AudioStreamPlayer3D

# Cached sounds
var sound_cache: Dictionary = {}


func _ready() -> void:
	_setup_buses()
	_setup_pools()
	_setup_music()
	_load_settings()


func _setup_buses() -> void:
	# Create audio buses if they don't exist
	var bus_names := [BUS_MUSIC, BUS_SFX, BUS_VOICE, BUS_AMBIENT]
	for bus_name in bus_names:
		if AudioServer.get_bus_index(bus_name) == -1:
			var idx := AudioServer.bus_count
			AudioServer.add_bus(idx)
			AudioServer.set_bus_name(idx, bus_name)
			AudioServer.set_bus_send(idx, BUS_MASTER)


func _setup_pools() -> void:
	# 3D spatial sound effects pool
	for i in range(POOL_SIZE):
		var player := AudioStreamPlayer3D.new()
		player.name = "SFXPlayer3D_" + str(i)
		player.bus = BUS_SFX
		player.unit_size = 2.0
		player.max_db = 3.0
		player.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
		add_child(player)
		sfx_pool.append(player)

	# 2D sound effects pool (UI, etc.)
	for i in range(POOL_SIZE / 2):
		var player := AudioStreamPlayer.new()
		player.name = "SFXPlayer2D_" + str(i)
		player.bus = BUS_SFX
		add_child(player)
		sfx_2d_pool.append(player)


func _setup_music() -> void:
	music_player = AudioStreamPlayer.new()
	music_player.name = "MusicPlayer"
	music_player.bus = BUS_MUSIC
	add_child(music_player)

	music_crossfade_player = AudioStreamPlayer.new()
	music_crossfade_player.name = "MusicCrossfade"
	music_crossfade_player.bus = BUS_MUSIC
	add_child(music_crossfade_player)


func _load_settings() -> void:
	var settings := SessionManager.get_settings()
	master_volume = settings.get("master_volume", 1.0)
	music_volume = settings.get("music_volume", 0.7)
	sfx_volume = settings.get("sfx_volume", 1.0)

	_apply_volumes()


func _apply_volumes() -> void:
	_set_bus_volume(BUS_MASTER, master_volume)
	_set_bus_volume(BUS_MUSIC, music_volume)
	_set_bus_volume(BUS_SFX, sfx_volume)
	_set_bus_volume(BUS_VOICE, voice_volume)
	_set_bus_volume(BUS_AMBIENT, ambient_volume)


func _set_bus_volume(bus_name: String, volume: float) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx >= 0:
		AudioServer.set_bus_volume_db(idx, linear_to_db(volume))


# ============================================================================
# Public API
# ============================================================================

## Play a 3D spatial sound effect at a position
func play_sfx_3d(sound_path: String, position: Vector3, volume_db: float = 0.0, pitch: float = 1.0) -> AudioStreamPlayer3D:
	var stream := _get_cached_sound(sound_path)
	if stream == null:
		return null

	var player := _get_available_3d_player()
	if player == null:
		return null

	player.stream = stream
	player.global_position = position
	player.volume_db = volume_db
	player.pitch_scale = pitch
	player.play()

	return player


## Play a 3D sound attached to a node (follows the node)
func play_sfx_attached(sound_path: String, parent: Node3D, volume_db: float = 0.0, pitch: float = 1.0) -> AudioStreamPlayer3D:
	var stream := _get_cached_sound(sound_path)
	if stream == null:
		return null

	var player := AudioStreamPlayer3D.new()
	player.stream = stream
	player.volume_db = volume_db
	player.pitch_scale = pitch
	player.bus = BUS_SFX
	player.finished.connect(player.queue_free)

	parent.add_child(player)
	player.play()

	return player


## Play a 2D (non-spatial) sound effect
func play_sfx_2d(sound_path: String, volume_db: float = 0.0, pitch: float = 1.0) -> AudioStreamPlayer:
	var stream := _get_cached_sound(sound_path)
	if stream == null:
		return null

	var player := _get_available_2d_player()
	if player == null:
		return null

	player.stream = stream
	player.volume_db = volume_db
	player.pitch_scale = pitch
	player.play()

	return player


## Play music with optional crossfade
func play_music(music_path: String, crossfade_time: float = 1.0) -> void:
	if music_path == current_music:
		return

	var stream := _get_cached_sound(music_path)
	if stream == null:
		return

	if crossfade_time > 0 and music_player.playing:
		_crossfade_music(stream, crossfade_time)
	else:
		music_player.stream = stream
		music_player.play()

	current_music = music_path


## Stop music with fade out
func stop_music(fade_time: float = 1.0) -> void:
	if fade_time > 0:
		var tween := create_tween()
		tween.tween_property(music_player, "volume_db", -80.0, fade_time)
		tween.tween_callback(music_player.stop)
		tween.tween_callback(func(): music_player.volume_db = 0.0)
	else:
		music_player.stop()

	current_music = ""


## Set ambient soundscape
func set_ambient(sound_path: String, volume_db: float = -10.0) -> void:
	if ambient_player == null:
		ambient_player = AudioStreamPlayer3D.new()
		ambient_player.name = "AmbientPlayer"
		ambient_player.bus = BUS_AMBIENT
		ambient_player.unit_size = 100.0  # Wide range
		add_child(ambient_player)

	var stream := _get_cached_sound(sound_path)
	if stream:
		ambient_player.stream = stream
		ambient_player.volume_db = volume_db
		ambient_player.play()


## Play UI sound (click, hover, etc.)
func play_ui_sound(sound_type: String) -> void:
	var path := "res://audio/ui/" + sound_type + ".ogg"
	play_sfx_2d(path, -5.0)


## Play combat sound with variations
func play_combat_sound(sound_type: String, position: Vector3) -> void:
	var base_path := "res://audio/combat/" + sound_type
	# In production, would have multiple variations
	play_sfx_3d(base_path + ".ogg", position, 0.0, randf_range(0.9, 1.1))


# ============================================================================
# Volume Control
# ============================================================================

func set_master_volume(volume: float) -> void:
	master_volume = clamp(volume, 0.0, 1.0)
	_set_bus_volume(BUS_MASTER, master_volume)
	SessionManager.update_setting("master_volume", master_volume)


func set_music_volume(volume: float) -> void:
	music_volume = clamp(volume, 0.0, 1.0)
	_set_bus_volume(BUS_MUSIC, music_volume)
	SessionManager.update_setting("music_volume", music_volume)


func set_sfx_volume(volume: float) -> void:
	sfx_volume = clamp(volume, 0.0, 1.0)
	_set_bus_volume(BUS_SFX, sfx_volume)
	SessionManager.update_setting("sfx_volume", sfx_volume)


# ============================================================================
# Internal
# ============================================================================

func _get_cached_sound(path: String) -> AudioStream:
	if sound_cache.has(path):
		return sound_cache[path]

	if not ResourceLoader.exists(path):
		# Return null silently - sound files may not exist yet
		return null

	var stream := load(path) as AudioStream
	if stream:
		sound_cache[path] = stream

	return stream


func _get_available_3d_player() -> AudioStreamPlayer3D:
	for player in sfx_pool:
		if not player.playing:
			return player
	# All players busy, return first (will cut off oldest sound)
	return sfx_pool[0]


func _get_available_2d_player() -> AudioStreamPlayer:
	for player in sfx_2d_pool:
		if not player.playing:
			return player
	return sfx_2d_pool[0]


func _crossfade_music(new_stream: AudioStream, duration: float) -> void:
	is_crossfading = true

	# Move current music to crossfade player
	music_crossfade_player.stream = music_player.stream
	music_crossfade_player.volume_db = music_player.volume_db
	music_crossfade_player.play(music_player.get_playback_position())

	# Start new music quietly
	music_player.stream = new_stream
	music_player.volume_db = -80.0
	music_player.play()

	# Crossfade
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(music_player, "volume_db", 0.0, duration)
	tween.tween_property(music_crossfade_player, "volume_db", -80.0, duration)
	tween.set_parallel(false)
	tween.tween_callback(func():
		music_crossfade_player.stop()
		is_crossfading = false
	)

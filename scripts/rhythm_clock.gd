extends Node

signal beat_triggered(beat_index: int, beat_time_seconds: float)
signal beat_fraction_changed(beat_fraction: float)
signal bpm_changed(new_bpm: float)

@export_range(40.0, 240.0, 1.0) var bpm: float = 120.0
@export var auto_start: bool = true
@export var use_audio_latency_compensation: bool = true

@onready var _music_player: AudioStreamPlayer = $MusicPlayer

var _fallback_elapsed_seconds: float = 0.0
var _last_emitted_beat: int = -1
var _running: bool = false
var _paused: bool = false
var _pause_position: float = 0.0
var _last_bpm: float = -1.0

## Optional LevelData resource for dynamic BPM and trap data.
var level_data: Resource = null


func _ready() -> void:
	if auto_start:
		start()


## Assign a LevelData resource for dynamic BPM support.
func set_level_data(ld: Resource) -> void:
	level_data = ld


func start(reset_beat: bool = true) -> void:
	_running = true
	if reset_beat:
		_last_emitted_beat = -1
		_fallback_elapsed_seconds = 0.0
		_last_bpm = -1.0
	if _music_player.stream != null and not _music_player.playing:
		_music_player.play()


func stop() -> void:
	_running = false
	_paused = false
	if _music_player.playing:
		_music_player.stop()


func pause() -> void:
	if not _running or _paused:
		return
	_paused = true
	_running = false
	_pause_position = get_song_position_seconds()
	if _music_player.playing:
		_music_player.stop()


func resume() -> void:
	if not _paused:
		return
	_paused = false
	_running = true
	_fallback_elapsed_seconds = _pause_position
	if _music_player.stream != null:
		_music_player.play(_pause_position)


func is_paused() -> bool:
	return _paused


## Get current BPM — uses LevelData if available, else static export.
func get_current_bpm() -> float:
	if level_data != null and level_data.has_method("get_bpm_at_second"):
		return level_data.get_bpm_at_second(get_song_position_seconds())
	return bpm


func get_seconds_per_beat() -> float:
	return 60.0 / get_current_bpm()


func get_song_position_seconds() -> float:
	if _music_player.playing:
		var position: float = _music_player.get_playback_position()
		if use_audio_latency_compensation:
			position += AudioServer.get_time_since_last_mix()
			position -= AudioServer.get_output_latency()
		return max(position, 0.0)
	return max(_fallback_elapsed_seconds, 0.0)


## Get current beat position as fractional float.
## Uses LevelData auto-converter when available (handles variable BPM).
func get_beat_position() -> float:
	var sec: float = get_song_position_seconds()
	if level_data != null and level_data.has_method("seconds_to_beat"):
		return level_data.seconds_to_beat(sec)
	return sec / get_seconds_per_beat()


func _process(delta: float) -> void:
	if not _running:
		return

	if not _music_player.playing:
		_fallback_elapsed_seconds += delta

	# Emit bpm_changed when BPM shifts
	var current_bpm: float = get_current_bpm()
	if _last_bpm >= 0.0 and absf(current_bpm - _last_bpm) > 0.01:
		bpm_changed.emit(current_bpm)
	_last_bpm = current_bpm

	var beat_position: float = get_beat_position()
	var whole_beat: int = maxi(floori(beat_position), 0)

	for beat_index in range(_last_emitted_beat + 1, whole_beat + 1):
		var beat_sec: float = 0.0
		if level_data != null and level_data.has_method("beat_to_seconds"):
			beat_sec = level_data.beat_to_seconds(float(beat_index))
		else:
			beat_sec = float(beat_index) * get_seconds_per_beat()
		beat_triggered.emit(beat_index, beat_sec)

	_last_emitted_beat = whole_beat
	beat_fraction_changed.emit(beat_position - floor(beat_position))

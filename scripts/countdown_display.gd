## CountdownDisplay — Beat-synced countdown (6→1→GO!) at level start.
## Dark overlay + big centered number. Listens to RhythmClock beat_triggered.
## Beat 0→"6", Beat 1→"5", … Beat 5→"1", Beat 6→"GO!", then done.
## Emits `countdown_finished` on GO beat and self-destructs.
extends Control

signal countdown_finished

## How many beats to count down from (default 6 → shows 6,5,4,3,2,1,GO!).
@export var start_number: int = 6

## Overlay darkness (0 = transparent, 1 = fully black).
@export var overlay_opacity: float = 0.45

var _rhythm_clock: Node = null
var _finished: bool = false
var _overlay: ColorRect = null
var _label: Label = null


func _ready() -> void:
	# Fill entire screen
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Dark overlay
	_overlay = ColorRect.new()
	_overlay.color = Color(0, 0, 0, overlay_opacity)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_overlay)
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	# Countdown label
	_label = Label.new()
	_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_label)

	# Visual style — big, bold, with shadow
	_label.add_theme_font_size_override("font_size", 140)
	_label.add_theme_color_override("font_color", Color(0.85, 0.75, 1.0, 1.0))
	_label.add_theme_color_override("font_shadow_color", Color(0.3, 0.1, 0.5, 0.6))
	_label.add_theme_constant_override("shadow_offset_x", 3)
	_label.add_theme_constant_override("shadow_offset_y", 3)

	# Apply project font if available
	var theme_res: Resource = load("res://assets/ui_theme.tres") if ResourceLoader.exists("res://assets/ui_theme.tres") else null
	if theme_res != null and theme_res is Theme:
		var font = (theme_res as Theme).default_font
		if font != null:
			_label.add_theme_font_override("font", font)

	_label.text = str(start_number)


## Call this from BattleScene after adding to tree.
## Connects to the clock's beat_triggered signal.
func setup(rhythm_clock: Node) -> void:
	_rhythm_clock = rhythm_clock
	if _rhythm_clock.has_signal("beat_triggered"):
		_rhythm_clock.beat_triggered.connect(_on_beat)


func _on_beat(beat_index: int, _beat_time_seconds: float) -> void:
	if _finished:
		return

	# beat 0 → show "6", beat 1 → "5", … beat 5 → "1"
	var remaining: int = start_number - beat_index

	if remaining >= 1:
		# Number phase
		_label.text = str(remaining)
		_label.add_theme_font_size_override("font_size", 140)

		# Color: purple → cyan-white as count decreases
		var t: float = 1.0 - float(remaining - 1) / float(start_number)
		var col := Color(0.6 + 0.4 * t, 0.5 + 0.5 * t, 1.0, 1.0)
		_label.add_theme_color_override("font_color", col)

		_play_pop_animation()

	elif remaining == 0:
		# "GO!" beat
		_label.text = "GO!"
		_label.add_theme_font_size_override("font_size", 160)
		_label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.6, 1.0))

		_play_pop_animation(1.8)

		# Signal that countdown is done — player can move now
		_finished = true
		countdown_finished.emit()

		# Fade out everything and self-destruct
		_fade_and_die()


func _play_pop_animation(start_scale: float = 1.6) -> void:
	_label.pivot_offset = _label.size * 0.5
	_label.scale = Vector2(start_scale, start_scale)

	var tween := create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_BACK)
	tween.tween_property(_label, "scale", Vector2(1.0, 1.0), 0.25)


func _fade_and_die() -> void:
	await get_tree().create_timer(0.5).timeout
	var exit_tween := create_tween()
	exit_tween.tween_property(self, "modulate:a", 0.0, 0.3)
	await exit_tween.finished
	queue_free()

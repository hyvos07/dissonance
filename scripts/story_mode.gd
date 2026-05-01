## StoryMode — Main Visual Novel controller scene.
## Manages dialogue flow, backgrounds, characters, and transitions to boss fights.
extends Control

## Dialogue resource paths for each chapter
const CHAPTER_DIALOGUE: Dictionary = {
	"prolog": "res://dialogue/prolog.dialogue",
	"babak_pembuka": "res://dialogue/babak_pembuka.dialogue",
	"babak_1_lumen": "res://dialogue/babak_1_lumen.dialogue",
	"babak_2_aria": "res://dialogue/babak_2_aria.dialogue",
	"babak_3_tetra": "res://dialogue/babak_3_tetra.dialogue",
	"klimaks": "res://dialogue/klimaks.dialogue",
	"epilog": "res://dialogue/epilog.dialogue",
}

## Boss music mapping (for ambient preview)
const MENU_MUSIC_PATH: String = "res://assets/Empty Plaza Memory.mp3"

## Character name → color mapping
const CHARACTER_COLORS: Dictionary = {
	"NARASI": Color(0.75, 0.75, 0.85, 0.9),
	"Suis": Color(0.9, 0.85, 1.0),
	"Buna": Color(1.0, 0.88, 0.75),
	"LUMEN": Color(1.0, 0.92, 0.3),
	"ARIA": Color(0.55, 0.78, 1.0),
	"TETRA": Color(0.3, 1.0, 0.82),
	"Guru": Color(0.7, 0.7, 0.7),
}

## Background scenes
const BG_COLORS: Dictionary = {
	"hitam": Color(0.0, 0.0, 0.0),
	"kelas_12b": Color(0.08, 0.06, 0.12),
	"koridor": Color(0.06, 0.06, 0.1),
	"perpustakaan_siang": Color(0.07, 0.05, 0.1),
	"perpustakaan_malam": Color(0.03, 0.02, 0.06),
	"gudang_olahraga": Color(0.06, 0.04, 0.04),
	"toilet_wanita": Color(0.05, 0.06, 0.08),
}

const BG_LABELS: Dictionary = {
	"hitam": "",
	"kelas_12b": "Kelas 12-B",
	"koridor": "Koridor Sekolah",
	"perpustakaan_siang": "Perpustakaan — Siang",
	"perpustakaan_malam": "Perpustakaan — Malam",
	"gudang_olahraga": "Gudang Olahraga",
	"toilet_wanita": "Toilet Wanita",
}

## Nodes
@onready var _bg_rect: ColorRect = $BG
@onready var _bg_label: Label = $BGLabel
@onready var _fade_overlay: ColorRect = $FadeOverlay
@onready var _dialogue_box: PanelContainer = $DialogueBox
@onready var _name_label: Label = %NameLabel
@onready var _text_label: RichTextLabel = %TextLabel
@onready var _continue_indicator: Label = %ContinueIndicator
@onready var _suis_sprite: TextureRect = $CharacterLayer/SuisSprite
@onready var _buna_sprite: TextureRect = $CharacterLayer/BunaSprite
@onready var _music_player: AudioStreamPlayer = $MusicPlayer

signal boss_fight_requested()

## State
var _is_overlay: bool = false
var _dialogue_resource: Resource = null
var _dialogue_line = null  # DialogueLine
var _is_typing: bool = false
var _typing_tween: Tween = null
var _waiting_for_input: bool = false
var _pending_boss_fight: String = ""
var _chapter_ended: bool = false
var _current_text: String = ""
var _visible_chars: int = 0

## Character visibility state
var _suis_visible: bool = false
var _buna_visible: bool = false
var _suis_position: String = "center"  # "left", "center", "right"
var _buna_position: String = "right"


func _ready() -> void:
	GameManager.in_story_mode = true

	# Setup initial state
	_fade_overlay.color = Color(0, 0, 0, 1)
	_fade_overlay.visible = true
	_dialogue_box.visible = false
	_suis_sprite.visible = false
	_buna_sprite.visible = false
	_continue_indicator.visible = false

	# Load character textures
	_load_character_textures()

	# Setup music
	_setup_music()

	# Load and start current chapter
	_start_current_chapter()


func _load_character_textures() -> void:
	var suis_path: String = "res://assets/characters/suis/suis_default.png"
	var buna_path: String = "res://assets/characters/buna/buna_default.png"
	if ResourceLoader.exists(suis_path):
		_suis_sprite.texture = load(suis_path)
	if ResourceLoader.exists(buna_path):
		_buna_sprite.texture = load(buna_path)


func setup_as_overlay() -> void:
	_is_overlay = true
	_bg_rect.visible = false
	_bg_label.visible = false
	_fade_overlay.visible = false
	if _music_player:
		_music_player.stop()

func _setup_music() -> void:
	if _is_overlay:
		return
	var stream = load(MENU_MUSIC_PATH)
	if stream == null:
		return
	if stream is AudioStreamMP3:
		stream.loop = true
	_music_player.stream = stream
	_music_player.bus = "Music"
	_music_player.volume_db = -14.0
	_music_player.play()


func _start_current_chapter() -> void:
	var chapter_name: String = GameManager.get_current_chapter()
	if chapter_name.is_empty():
		_finish_story()
		return

	var dialogue_path: String = CHAPTER_DIALOGUE.get(chapter_name, "")
	if dialogue_path.is_empty() or not ResourceLoader.exists(dialogue_path):
		push_error("StoryMode: Cannot find dialogue for chapter '%s'" % chapter_name)
		_finish_story()
		return

	_dialogue_resource = load(dialogue_path)
	_chapter_ended = false

	# Determine start title
	var start_title: String = ""
	if not GameManager.story_resume_title.is_empty():
		start_title = GameManager.story_resume_title
		GameManager.story_resume_title = ""

	# Get first line
	_get_next_line(start_title)


func _get_next_line(from_id: String = "") -> void:
	var dm = Engine.get_singleton("DialogueManager")
	if dm == null:
		push_error("StoryMode: DialogueManager singleton not found!")
		return

	_dialogue_line = await dm.get_next_dialogue_line(_dialogue_resource, from_id, [self])

	if _dialogue_line == null:
		# End of dialogue
		if not _chapter_ended:
			_on_chapter_finished()
		return

	_show_dialogue_line()


func _show_dialogue_line() -> void:
	if _dialogue_line == null:
		return

	var character: String = _dialogue_line.character
	var text: String = _dialogue_line.text
	var is_narration: bool = _dialogue_line.has_tag("narasi") or character == "NARASI"

	# Show dialogue box
	_dialogue_box.visible = true
	_continue_indicator.visible = false
	_waiting_for_input = false

	# Handle character name display
	if is_narration or character.is_empty():
		_name_label.text = ""
		_name_label.visible = false
	else:
		_name_label.text = character
		_name_label.visible = true
		var color: Color = CHARACTER_COLORS.get(character, Color.WHITE)
		_name_label.add_theme_color_override("font_color", color)

	# Handle inner thoughts
	var is_inner: bool = _dialogue_line.has_tag("inner_thought")

	# Update character dimming based on who's speaking
	_update_character_focus(character)

	# Setup text with typewriter effect
	if is_narration:
		_text_label.text = "[i]%s[/i]" % text
	elif is_inner:
		_text_label.text = "[i](%s)[/i]" % text
	else:
		_text_label.text = text

	_text_label.visible_ratio = 0.0
	_is_typing = true

	# Start typewriter
	if _typing_tween and _typing_tween.is_valid():
		_typing_tween.kill()

	var char_count: int = _text_label.get_total_character_count()
	if char_count == 0:
		char_count = text.length()
	var type_duration: float = maxf(char_count * 0.03, 0.5)

	_typing_tween = create_tween()
	_typing_tween.tween_property(_text_label, "visible_ratio", 1.0, type_duration)
	_typing_tween.finished.connect(_on_typing_finished, CONNECT_ONE_SHOT)


func _on_typing_finished() -> void:
	_is_typing = false
	_waiting_for_input = true
	_continue_indicator.visible = true
	# Animate the continue indicator
	_animate_continue_indicator()


func _animate_continue_indicator() -> void:
	var tween := create_tween().set_loops()
	tween.tween_property(_continue_indicator, "modulate:a", 0.3, 0.6)
	tween.tween_property(_continue_indicator, "modulate:a", 1.0, 0.6)


func _update_character_focus(speaker: String) -> void:
	if _suis_visible:
		var is_speaking: bool = speaker == "Suis"
		var target_alpha: float = 1.0 if is_speaking else 0.5
		if not _buna_visible:
			target_alpha = 1.0
		var tw := create_tween()
		tw.tween_property(_suis_sprite, "modulate:a", target_alpha, 0.2)

	if _buna_visible:
		var is_speaking: bool = speaker == "Buna"
		var target_alpha: float = 1.0 if is_speaking else 0.5
		if not _suis_visible:
			target_alpha = 1.0
		var tw := create_tween()
		tw.tween_property(_buna_sprite, "modulate:a", target_alpha, 0.2)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE and not _is_overlay:
			_show_skip_prompt()
			return

	# Accept input (click, space, enter)
	var accepted: bool = false
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		accepted = true
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode in [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER]:
			accepted = true

	if not accepted:
		return

	if _is_typing:
		# Skip typewriter — show all text immediately
		if _typing_tween and _typing_tween.is_valid():
			_typing_tween.kill()
		_text_label.visible_ratio = 1.0
		_on_typing_finished()
		get_viewport().set_input_as_handled()
	elif _waiting_for_input:
		_waiting_for_input = false
		_continue_indicator.visible = false
		get_viewport().set_input_as_handled()
		_get_next_line(_dialogue_line.next_id)


func _show_skip_prompt() -> void:
	# Simple skip confirmation
	var overlay := ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.7)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(overlay)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 16)
	center.add_child(vbox)

	var lbl := Label.new()
	lbl.text = "Skip to Main Menu?"
	lbl.add_theme_font_size_override("font_size", 32)
	lbl.add_theme_color_override("font_color", Color(0.85, 0.75, 1.0))
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(lbl)

	var resume_btn := Button.new()
	resume_btn.text = "Resume"
	resume_btn.custom_minimum_size = Vector2(220, 48)
	resume_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	resume_btn.add_theme_font_size_override("font_size", 20)
	resume_btn.pressed.connect(func(): overlay.queue_free())
	vbox.add_child(resume_btn)

	var quit_btn := Button.new()
	quit_btn.text = "Back to Menu"
	quit_btn.custom_minimum_size = Vector2(220, 48)
	quit_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	quit_btn.add_theme_font_size_override("font_size", 20)
	quit_btn.pressed.connect(func():
		GameManager.in_story_mode = false
		get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
	)
	vbox.add_child(quit_btn)


func _on_chapter_finished() -> void:
	_chapter_ended = true
	_dialogue_box.visible = false

	# Check if there's a pending boss fight
	if not _pending_boss_fight.is_empty():
		_transition_to_boss(_pending_boss_fight)
		_pending_boss_fight = ""
		return

	# Try to advance to next chapter
	if GameManager.advance_chapter():
		_start_current_chapter()
	else:
		_finish_story()


func _transition_to_boss(boss_name: String) -> void:
	# Set up GameManager for battle
	var level_path: String = GameManager.get_boss_level_path(boss_name)
	GameManager.current_level_path = level_path
	GameManager.current_boss_name = boss_name
	GameManager.reset_hp()

	# Remember which chapter we're in and what title to resume from after the fight
	GameManager.story_resume_chapter = GameManager.get_current_chapter()

	# Fade out and transition to battle
	var tween := create_tween()
	tween.tween_property(_fade_overlay, "color:a", 1.0, 0.5)
	await tween.finished

	get_tree().change_scene_to_file("res://scenes/main.tscn")


func _finish_story() -> void:
	GameManager.story_completed = true
	GameManager.in_story_mode = false
	GameManager.save_progress()

	# Fade to black
	var tween := create_tween()
	tween.tween_property(_fade_overlay, "color:a", 1.0, 1.0)
	await tween.finished

	# Show completion message then go to menu
	await get_tree().create_timer(1.5).timeout
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")


## ---- Mutation Functions (called from .dialogue files) ----

func set_background(bg_name: String) -> void:
	var color: Color = BG_COLORS.get(bg_name, Color(0.05, 0.05, 0.08))
	_bg_rect.color = color

	var label_text: String = BG_LABELS.get(bg_name, "")
	if label_text.is_empty():
		_bg_label.visible = false
	else:
		_bg_label.text = label_text
		_bg_label.visible = true
		# Fade in/out location label
		_bg_label.modulate.a = 0.0
		var tw := create_tween()
		tw.tween_property(_bg_label, "modulate:a", 0.6, 0.5)
		tw.tween_interval(2.0)
		tw.tween_property(_bg_label, "modulate:a", 0.0, 1.0)


func show_character(char_name: String, position: String = "center") -> void:
	var sprite: TextureRect = _get_character_sprite(char_name)
	if sprite == null:
		return

	if char_name == "suis":
		_suis_visible = true
		_suis_position = position
	elif char_name == "buna":
		_buna_visible = true
		_buna_position = position

	_position_character(sprite, position)
	sprite.visible = true
	sprite.modulate.a = 0.0

	# Enter animation: slide up + fade in
	sprite.position.y += 40
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(sprite, "modulate:a", 1.0, 0.4)
	tw.tween_property(sprite, "position:y", sprite.position.y - 40, 0.4).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)


func hide_character(char_name: String) -> void:
	var sprite: TextureRect = _get_character_sprite(char_name)
	if sprite == null:
		return

	if char_name == "suis":
		_suis_visible = false
	elif char_name == "buna":
		_buna_visible = false

	# Exit animation: slide down + fade out
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(sprite, "modulate:a", 0.0, 0.3)
	tw.tween_property(sprite, "position:y", sprite.position.y + 40, 0.3)
	await tw.finished
	sprite.visible = false


func move_character(char_name: String, position: String) -> void:
	var sprite: TextureRect = _get_character_sprite(char_name)
	if sprite == null:
		return

	if char_name == "suis":
		_suis_position = position
	elif char_name == "buna":
		_buna_position = position

	var target_x: float = _get_position_x(position, sprite)
	var tw := create_tween()
	tw.tween_property(sprite, "position:x", target_x, 0.4).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CUBIC)


func fade_in() -> void:
	if _is_overlay: return
	_fade_overlay.visible = true
	var tw := create_tween()
	tw.tween_property(_fade_overlay, "color:a", 0.0, 0.8)
	await tw.finished


func fade_to_black() -> void:
	if _is_overlay: return
	_fade_overlay.visible = true
	var tw := create_tween()
	tw.tween_property(_fade_overlay, "color:a", 1.0, 0.8)
	await tw.finished


func dramatic_pause(duration: float) -> void:
	await get_tree().create_timer(duration).timeout


func screen_shake() -> void:
	var original_pos: Vector2 = position
	for i in range(8):
		position = original_pos + Vector2(randf_range(-6, 6), randf_range(-6, 6))
		await get_tree().create_timer(0.04).timeout
	position = original_pos


func play_sfx(_sfx_name: String) -> void:
	# Placeholder — SFX system can be expanded later
	pass


func play_music_preview() -> void:
	# Placeholder — could play a specific music clip here
	pass


func start_boss_fight(boss_name: String) -> void:
	if _is_overlay:
		boss_fight_requested.emit()
		queue_free()
		return

	# Mark boss fight to happen after the current dialogue section ends
	_pending_boss_fight = boss_name

	# Also set resume title for after the fight
	# The fight will end and BattleScene will return to StoryMode
	var chapter: String = GameManager.get_current_chapter()
	match boss_name:
		"LUMEN":
			GameManager.story_resume_title = "pertarungan_lumen"
		"ARIA":
			GameManager.story_resume_title = "pertarungan_aria"
		"TETRA":
			GameManager.story_resume_title = "pertarungan_tetra"

	GameManager.story_resume_chapter = chapter
	GameManager.save_progress()

	# Hide dialogue box and prepare for transition
	_dialogue_box.visible = false
	_hide_all_characters()

	# Stop dialogue processing — the chapter_ended handler will pick up the boss fight
	_chapter_ended = true
	_transition_to_boss(boss_name)


func end_chapter(_chapter_name: String) -> void:
	# Called from dialogue to mark chapter end — handled by dialogue ending naturally
	pass


func _get_character_sprite(char_name: String) -> TextureRect:
	match char_name.to_lower():
		"suis":
			return _suis_sprite
		"buna":
			return _buna_sprite
	return null


func _position_character(sprite: TextureRect, pos: String) -> void:
	var x: float = _get_position_x(pos, sprite)
	sprite.position.x = x
	sprite.position.y = 80  # Base Y position


func _get_position_x(pos: String, sprite: TextureRect) -> float:
	var screen_w: float = get_viewport_rect().size.x
	var sprite_w: float = sprite.size.x if sprite.size.x > 0 else 300
	match pos:
		"left":
			return screen_w * 0.15 - sprite_w * 0.5
		"center":
			return screen_w * 0.5 - sprite_w * 0.5
		"right":
			return screen_w * 0.85 - sprite_w * 0.5
	return screen_w * 0.5 - sprite_w * 0.5


func _hide_all_characters() -> void:
	_suis_sprite.visible = false
	_buna_sprite.visible = false
	_suis_visible = false
	_buna_visible = false

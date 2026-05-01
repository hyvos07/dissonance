## MainMenu — Title screen. Story Mode → VN. Free Play (after story). Options. Exit.
extends Control

## Drag your background video (.ogv) here in the Inspector.
@export var bg_video: VideoStream

@onready var _story_btn: Button = %StoryButton
@onready var _continue_btn: Button = %ContinueButton
@onready var _freeplay_btn: Button = %FreePlayButton
@onready var _options_btn: Button = %OptionsButton
@onready var _exit_btn: Button = %ExitButton
@onready var _options_panel: PanelContainer = $OptionsPanel
@onready var _master_slider: HSlider = %MasterVolSlider
@onready var _music_slider: HSlider = %MusicVolSlider
@onready var _back_btn: Button = %BackButton
@onready var _vbox: VBoxContainer = $VBoxContainer

const MENU_MUSIC_PATH: String = "res://assets/mainmenu.mp3"


func _ready() -> void:
	_setup_bg(0.5)
	_setup_menu_music()

	_story_btn.pressed.connect(_on_new_story)
	_continue_btn.pressed.connect(_on_continue_story)
	_freeplay_btn.pressed.connect(_on_freeplay)
	_options_btn.pressed.connect(_on_options)
	_exit_btn.pressed.connect(_on_exit)
	_back_btn.pressed.connect(_on_back)
	_master_slider.value_changed.connect(_on_master_vol_changed)
	_music_slider.value_changed.connect(_on_music_vol_changed)

	# Init slider positions from current bus volumes
	_master_slider.value = db_to_linear(AudioServer.get_bus_volume_db(0)) * 100.0
	var music_idx: int = AudioServer.get_bus_index("Music")
	if music_idx >= 0:
		_music_slider.value = db_to_linear(AudioServer.get_bus_volume_db(music_idx)) * 100.0
	else:
		_music_slider.value = 80.0

	# Configure button availability
	_update_menu_state()


func _update_menu_state() -> void:
	# Continue button: only if save exists and story not completed
	var has_save: bool = GameManager.has_save()
	var story_done: bool = GameManager.story_completed
	var in_progress: bool = has_save and not story_done and GameManager.story_chapter_index > 0

	_continue_btn.visible = in_progress
	_continue_btn.disabled = not in_progress

	# Free Play: only if story completed
	_freeplay_btn.disabled = not story_done
	_freeplay_btn.modulate.a = 1.0
	if not story_done:
		_freeplay_btn.tooltip_text = "Complete Story Mode to unlock"
	else:
		_freeplay_btn.tooltip_text = ""


## Background setup: uses video if assigned, else animated shader gradient.
func _setup_bg(dim_amount: float) -> void:
	if bg_video != null:
		var video := VideoStreamPlayer.new()
		video.name = "BGVideo"
		video.stream = bg_video
		video.autoplay = true
		video.expand = true
		video.loop = true
		video.volume_db = -80.0
		video.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		video.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(video)
		move_child(video, 0)
		# Dim overlay
		var dim := ColorRect.new()
		dim.color = Color(0, 0, 0, dim_amount)
		dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(dim)
		move_child(dim, 1)
		return

	# Fallback: animated shader gradient
	var bg := ColorRect.new()
	bg.name = "AnimatedBG"
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var shader_code := """
shader_type canvas_item;
uniform float dim : hint_range(0.0, 1.0) = 0.5;
void fragment() {
	vec2 uv = UV;
	float t = TIME * 0.15;
	float wave1 = sin(uv.x * 3.0 + t) * 0.5 + 0.5;
	float wave2 = sin(uv.y * 2.5 - t * 1.3) * 0.5 + 0.5;
	float wave3 = sin((uv.x + uv.y) * 2.0 + t * 0.7) * 0.5 + 0.5;
	vec3 col1 = vec3(0.02, 0.06, 0.18);  // deep navy
	vec3 col2 = vec3(0.04, 0.10, 0.24);  // dark blue
	vec3 col3 = vec3(0.06, 0.12, 0.28);  // steel blue
	vec3 color = mix(col1, col2, wave1);
	color = mix(color, col3, wave2 * 0.5);
	color += wave3 * 0.02;
	color *= (1.0 - dim);
	COLOR = vec4(color, 1.0);
}
"""
	var shader := Shader.new()
	shader.code = shader_code
	var mat := ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter("dim", dim_amount)
	bg.material = mat

	add_child(bg)
	move_child(bg, 0)


## Play looping menu background music on the Music bus.
func _setup_menu_music() -> void:
	var stream = load(MENU_MUSIC_PATH)
	if stream == null:
		return
	if stream is AudioStreamMP3:
		stream.loop = true
	var player := AudioStreamPlayer.new()
	player.name = "MenuMusic"
	player.stream = stream
	player.bus = "Music"
	player.volume_db = -12.0
	player.autoplay = true
	add_child(player)


func _on_new_story() -> void:
	GameManager.delete_save()
	GameManager.story_chapter_index = 0
	GameManager.story_completed = false
	GameManager.in_story_mode = true
	GameManager.story_resume_title = ""
	GameManager.story_resume_chapter = ""
	GameManager.save_progress()
	get_tree().change_scene_to_file("res://scenes/story/story_mode.tscn")


func _on_continue_story() -> void:
	GameManager.in_story_mode = true
	get_tree().change_scene_to_file("res://scenes/story/story_mode.tscn")


func _on_freeplay() -> void:
	GameManager.in_story_mode = false
	get_tree().change_scene_to_file("res://scenes/level_select.tscn")


func _on_options() -> void:
	_vbox.visible = false
	_options_panel.visible = true


func _on_back() -> void:
	_options_panel.visible = false
	_vbox.visible = true


func _on_exit() -> void:
	get_tree().quit()


func _on_master_vol_changed(value: float) -> void:
	var vol_linear: float = value / 100.0
	var vol_db: float = linear_to_db(max(vol_linear, 0.001))
	AudioServer.set_bus_volume_db(0, vol_db)
	AudioServer.set_bus_mute(0, value < 1.0)


func _on_music_vol_changed(value: float) -> void:
	var music_idx: int = AudioServer.get_bus_index("Music")
	if music_idx < 0:
		return
	var vol_linear: float = value / 100.0
	var vol_db: float = linear_to_db(max(vol_linear, 0.001))
	AudioServer.set_bus_volume_db(music_idx, vol_db)
	AudioServer.set_bus_mute(music_idx, value < 1.0)

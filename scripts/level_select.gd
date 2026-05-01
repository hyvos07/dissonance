## LevelSelect — Boss chooser screen. Pick a shard to fight.
extends Control

## Maps boss name -> expected JSON path in res://levels/
const BOSS_LEVELS: Dictionary = {
	"LUMEN": "res://levels/Lumen.json",
	"ARIA": "res://levels/Aria.json",
	"TETRA": "res://levels/Tetra.json",
}

## Drag your background video (.ogv) here in the Inspector.
@export var bg_video: VideoStream

@onready var _lumen_btn: Button = $VBoxContainer/LumenButton
@onready var _aria_btn: Button = $VBoxContainer/AriaButton
@onready var _tetra_btn: Button = $VBoxContainer/TetraButton
@onready var _back_btn: Button = $VBoxContainer/BackButton

const MENU_MUSIC_PATH: String = "res://assets/Empty Plaza Memory.mp3"


func _ready() -> void:
	_setup_bg(0.7)
	_setup_menu_music()

	_setup_button(_lumen_btn, "LUMEN")
	_setup_button(_aria_btn, "ARIA")
	_setup_button(_tetra_btn, "TETRA")
	_back_btn.pressed.connect(_on_back)


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
	vec3 col1 = vec3(0.02, 0.06, 0.18);
	vec3 col2 = vec3(0.04, 0.10, 0.24);
	vec3 col3 = vec3(0.06, 0.12, 0.28);
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


func _setup_button(btn: Button, boss_name: String) -> void:
	var path: String = BOSS_LEVELS[boss_name]
	var exists: bool = FileAccess.file_exists(path)
	btn.disabled = not exists
	btn.modulate.a = 1.0 if exists else 0.35
	btn.pressed.connect(_on_boss_selected.bind(boss_name, path))
	if not exists:
		btn.tooltip_text = "Level data not found"


func _on_boss_selected(boss_name: String, path: String) -> void:
	GameManager.current_level_path = path
	GameManager.current_boss_name = boss_name
	GameManager.reset_hp()
	get_tree().change_scene_to_file("res://scenes/main.tscn")


func _on_back() -> void:
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")

extends Control

## Maps boss name → expected JSON path in res://levels/
const BOSS_LEVELS: Dictionary = {
	"LUMEN": "res://levels/Lumen.json",
	"ARIA": "res://levels/Aria.json",
	"TETRA": "res://levels/Tetra.json",
}

@onready var _lumen_btn: Button = $VBoxContainer/LumenButton
@onready var _aria_btn: Button = $VBoxContainer/AriaButton
@onready var _tetra_btn: Button = $VBoxContainer/TetraButton


func _ready() -> void:
	_setup_button(_lumen_btn, "LUMEN")
	_setup_button(_aria_btn, "ARIA")
	_setup_button(_tetra_btn, "TETRA")


func _setup_button(btn: Button, boss_name: String) -> void:
	var path: String = BOSS_LEVELS[boss_name]
	var exists: bool = FileAccess.file_exists(path)
	btn.disabled = not exists
	btn.modulate.a = 1.0 if exists else 0.35
	btn.pressed.connect(_on_boss_selected.bind(boss_name, path))
	# Tooltip shows availability
	if not exists:
		btn.tooltip_text = "Level data not found"


func _on_boss_selected(boss_name: String, path: String) -> void:
	GameManager.current_level_path = path
	GameManager.current_boss_name = boss_name
	GameManager.reset_hp()
	get_tree().change_scene_to_file("res://scenes/main.tscn")

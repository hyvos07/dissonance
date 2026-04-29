## GameManager — Autoload singleton. Carries data between scenes.
extends Node

## Path to the level JSON the player chose from the menu.
var current_level_path: String = ""

## Player health defaults.
var max_hp: int = 3
var player_hp: int = 3

## Boss display name (for HUD, etc.)
var current_boss_name: String = ""


func reset_hp() -> void:
	player_hp = max_hp

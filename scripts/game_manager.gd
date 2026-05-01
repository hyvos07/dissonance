## GameManager — Autoload singleton. Carries data between scenes.
## Now includes persistent save/load and story progress tracking.
extends Node

## Path to the level JSON the player chose from the menu.
var current_level_path: String = ""

## Player health defaults.
var max_hp: int = 5
var player_hp: int = 5

## Boss display name (for HUD, etc.)
var current_boss_name: String = ""

## ---- Story Mode State ----

## Ordered list of all story chapters
const STORY_CHAPTERS: Array[String] = [
	"prolog",
	"babak_pembuka",
	"babak_1_lumen",
	"babak_2_aria",
	"babak_3_tetra",
	"klimaks",
	"epilog",
]

## Current story chapter index (0-based)
var story_chapter_index: int = 0

## Whether story mode has been completed at least once
var story_completed: bool = false

## Whether we are currently in story mode (vs free play)
var in_story_mode: bool = false

## After a boss fight in story mode, which chapter title to resume from
var story_resume_title: String = ""

## Which dialogue file to resume from after boss fight
var story_resume_chapter: String = ""

## Save file path
const SAVE_PATH: String = "user://dissonance_save.cfg"


func reset_hp() -> void:
	player_hp = max_hp


## Get current chapter name
func get_current_chapter() -> String:
	if story_chapter_index >= 0 and story_chapter_index < STORY_CHAPTERS.size():
		return STORY_CHAPTERS[story_chapter_index]
	return ""


## Advance to next story chapter, returns true if there are more chapters
func advance_chapter() -> bool:
	story_chapter_index += 1
	if story_chapter_index >= STORY_CHAPTERS.size():
		story_completed = true
		save_progress()
		return false
	save_progress()
	return true


## Maps boss name to level JSON path
func get_boss_level_path(boss_name: String) -> String:
	var paths: Dictionary = {
		"LUMEN": "res://levels/Lumen.json",
		"ARIA": "res://levels/Aria.json",
		"TETRA": "res://levels/Tetra.json",
	}
	return paths.get(boss_name, "")


## ---- Save / Load System ----

func save_progress() -> void:
	var config := ConfigFile.new()
	config.set_value("story", "chapter_index", story_chapter_index)
	config.set_value("story", "completed", story_completed)
	config.set_value("story", "resume_title", story_resume_title)
	config.set_value("story", "resume_chapter", story_resume_chapter)
	config.save(SAVE_PATH)


func load_progress() -> bool:
	var config := ConfigFile.new()
	var err := config.load(SAVE_PATH)
	if err != OK:
		return false
	story_chapter_index = config.get_value("story", "chapter_index", 0)
	story_completed = config.get_value("story", "completed", false)
	story_resume_title = config.get_value("story", "resume_title", "")
	story_resume_chapter = config.get_value("story", "resume_chapter", "")
	return true


func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func delete_save() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)
	story_chapter_index = 0
	story_completed = false


func _ready() -> void:
	load_progress()

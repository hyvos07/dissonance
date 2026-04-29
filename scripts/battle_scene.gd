extends Node2D

@onready var _arena: Node2D = $Arena
@onready var _player: Node2D = $Player
@onready var _rhythm_clock: Node = $RhythmClock
@onready var _beat_label: Label = $CanvasLayer/HUD/BeatLabel
@onready var _timing_label: Label = $CanvasLayer/HUD/TimingLabel
@onready var _hp_display: HBoxContainer = $CanvasLayer/HpDisplay

## Internal systems (created at runtime)
var _arena_state: ArenaState = null
var _telegraph: Node = null
var _trap_viz: Node2D = null
var _level_data: LevelData = null
var _game_over: bool = false
var _game_won: bool = false

## Music mapping: boss name → audio file path
const MUSIC_MAP: Dictionary = {
	"LUMEN": "res://assets/boss song/Lumen - Neon Curtain Call.mp3",
}


func _ready() -> void:
	# 1. Load level data from GameManager
	_load_level()

	# 2. Setup ArenaState
	var cols: int = 6
	var rows: int = 6
	if _level_data != null:
		cols = _level_data.grid_size.x
		rows = _level_data.grid_size.y
	_arena_state = ArenaState.new(cols, rows)

	# 3. Configure player
	_player.configure(_arena, _arena_state)
	_player.setup_hp(GameManager.max_hp, GameManager.player_hp)
	_player.move_resolved.connect(_on_player_move_resolved)
	_player.player_hit.connect(_on_player_hit)
	_player.player_died.connect(_on_player_died)

	# 4. Setup TelegraphSystem
	_telegraph = Node.new()
	_telegraph.name = "TelegraphSystem"
	_telegraph.set_script(load("res://scripts/telegraph_system.gd"))
	add_child(_telegraph)
	_telegraph.setup(_rhythm_clock, _arena_state, _level_data)
	_telegraph.player_should_take_damage.connect(_on_damage_check)

	# 5. Setup TrapVisualizer
	_trap_viz = Node2D.new()
	_trap_viz.name = "TrapVisualizer"
	_trap_viz.set_script(load("res://scripts/trap_visualizer.gd"))
	_arena.add_child(_trap_viz)
	_trap_viz.setup(_arena, _arena_state, _telegraph)

	# 6. Setup HP display
	_hp_display.setup(GameManager.max_hp, GameManager.player_hp)
	_hp_display.hp_depleted.connect(_on_player_died)

	# 7. Wire beat for HUD updates
	_rhythm_clock.beat_triggered.connect(_on_beat_triggered)

	# 8. Calculate max beat from trap data and tell the visualizer
	if _level_data != null:
		var beat_viz: Control = $CanvasLayer/BeatVisualizer
		var last_beat: int = 0
		for trap in _level_data.traps:
			var trap_end: int = int(trap["beat"]) + int(trap["duration_beats"])
			if trap_end > last_beat:
				last_beat = trap_end
		beat_viz.max_beat = last_beat

	# 9. Load music
	_load_music()

	_update_hud("READY", Vector2i.ZERO, Vector2i.ZERO)

	# 10. Start clock + music immediately (beat visualizer needs this)
	_rhythm_clock.set_level_data(_level_data)
	_rhythm_clock.start()

	# 11. Freeze player and show beat-synced countdown
	_player.frozen = true
	_start_countdown()


func _start_countdown() -> void:
	var countdown := Control.new()
	countdown.name = "CountdownDisplay"
	countdown.set_script(load("res://scripts/countdown_display.gd"))
	$CanvasLayer.add_child(countdown)
	countdown.setup(_rhythm_clock)
	countdown.countdown_finished.connect(_on_countdown_finished)


func _on_countdown_finished() -> void:
	_player.frozen = false


func _load_level() -> void:
	var path: String = GameManager.current_level_path
	if path.is_empty():
		push_warning("BattleScene: No level path set. Using fallback.")
		path = "res://levels/Lumen.json"
		GameManager.current_level_path = path
		GameManager.current_boss_name = "LUMEN"

	_level_data = LevelData.new()
	if not _level_data.load_from_json(path):
		push_error("BattleScene: Failed to load level from %s" % path)
		_level_data = null


func _load_music() -> void:
	var boss: String = GameManager.current_boss_name
	if MUSIC_MAP.has(boss):
		var music_path: String = MUSIC_MAP[boss]
		if ResourceLoader.exists(music_path):
			var stream = load(music_path)
			var music_player: AudioStreamPlayer = _rhythm_clock.get_node("MusicPlayer")
			music_player.stream = stream
			# Detect end of song for win condition
			music_player.finished.connect(_on_song_finished)


func _on_beat_triggered(beat_index: int, _beat_time_seconds: float) -> void:
	_beat_label.text = "Beat: %d" % beat_index


func _on_damage_check(positions: Array) -> void:
	if _game_over or _game_won:
		return
	var player_pos: Vector2i = _player.get_grid_position()
	for pos in positions:
		if pos == player_pos:
			_player.take_damage()
			_hp_display.take_damage()
			break


func _on_player_move_resolved(result: String, from_cell: Vector2i, to_cell: Vector2i) -> void:
	_update_hud(result, from_cell, to_cell)


func _on_player_hit(remaining_hp: int) -> void:
	GameManager.player_hp = remaining_hp


func _on_player_died() -> void:
	if _game_over:
		return
	_game_over = true
	_rhythm_clock.stop()
	# Hide beat visualizer
	$CanvasLayer/BeatVisualizer.visible = false
	# Keep trap visuals visible so player sees what hit them
	# Show game over after a short delay
	await get_tree().create_timer(1.0).timeout
	_show_end_screen("GAME OVER", Color(0.9, 0.2, 0.2))


func _on_song_finished() -> void:
	if _game_over or _game_won:
		return
	_game_won = true
	_rhythm_clock.stop()
	# Hide beat visualizer
	$CanvasLayer/BeatVisualizer.visible = false
	# Clear all trap visuals so no leftover tiles
	_arena_state.clear_all()
	if _trap_viz:
		_trap_viz.queue_redraw()
	# 2 second pause after song ends
	await get_tree().create_timer(2.0).timeout
	_show_end_screen("VICTORY!", Color(0.3, 1.0, 0.5))


func _show_end_screen(text: String, color: Color) -> void:
	var overlay := ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.6)
	$CanvasLayer.add_child(overlay)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var center_container := CenterContainer.new()
	overlay.add_child(center_container)
	center_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.custom_minimum_size = Vector2(400, 0)
	center_container.add_child(vbox)

	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 48)
	label.add_theme_color_override("font_color", color)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(label)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 20)
	vbox.add_child(spacer)

	var retry_btn := Button.new()
	retry_btn.text = "Try Again"
	retry_btn.custom_minimum_size = Vector2(200, 44)
	retry_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	retry_btn.add_theme_font_size_override("font_size", 20)
	retry_btn.pressed.connect(_retry)
	vbox.add_child(retry_btn)

	var menu_btn := Button.new()
	menu_btn.text = "Main Menu"
	menu_btn.custom_minimum_size = Vector2(200, 44)
	menu_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	menu_btn.add_theme_font_size_override("font_size", 20)
	menu_btn.pressed.connect(_back_to_menu)
	vbox.add_child(menu_btn)


func _retry() -> void:
	GameManager.reset_hp()
	get_tree().reload_current_scene()


func _back_to_menu() -> void:
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")


func _update_hud(result: String, from_cell: Vector2i, to_cell: Vector2i) -> void:
	_timing_label.text = "Move: %s | From: (%d,%d) -> (%d,%d)\nUse Arrow Keys or WASD. You can move anytime." % [
		result,
		from_cell.x,
		from_cell.y,
		to_cell.x,
		to_cell.y
	]

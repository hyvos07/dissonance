## TelegraphSystem — Reads LevelData traps each beat, updates ArenaState.
## Attach as child of Battle scene. Needs rhythm_clock + arena_state + level_data.
extends Node

signal player_should_take_damage(positions: Array)

var _rhythm_clock: Node = null
var _arena_state: ArenaState = null
var _level_data: Resource = null

## Per-tile countdown: Vector2i → int (beats remaining until activation)
var _tile_countdown: Dictionary = {}


func setup(clock: Node, state: ArenaState, ld: Resource) -> void:
	_rhythm_clock = clock
	_arena_state = state
	_level_data = ld

	if _rhythm_clock.has_signal("beat_triggered"):
		_rhythm_clock.beat_triggered.connect(_on_beat_triggered)


## Get the countdown for a specific tile (0 if not in warning)
func get_countdown(pos: Vector2i) -> int:
	if _tile_countdown.has(pos):
		return _tile_countdown[pos]
	return 0


func _on_beat_triggered(beat_index: int, _beat_time_seconds: float) -> void:
	if _level_data == null or _arena_state == null:
		return

	_arena_state.clear_all()
	_tile_countdown.clear()

	# Gather all traps whose warning or active window covers this beat
	var all_traps: Array = _level_data.traps
	var damage_positions: Array[Vector2i] = []

	for t in all_traps:
		var trap_beat: float = float(t["beat"])
		var warn_beats: int = int(t["warn_beats"])
		var duration: int = int(t["duration_beats"])
		var trap_type: String = String(t["type"])
		var positions: Array = t["positions"]

		var warn_start: float = trap_beat - float(warn_beats)
		var active_end: float = trap_beat + float(duration)

		# Skip traps that are fully past or not yet relevant
		if float(beat_index) < warn_start or float(beat_index) >= active_end:
			continue

		# Determine phase
		var in_warning: bool = float(beat_index) >= warn_start and float(beat_index) < trap_beat
		var in_active: bool = float(beat_index) >= trap_beat and float(beat_index) < active_end

		for pos in positions:
			var cell: Vector2i = pos as Vector2i
			if not _is_in_grid(cell):
				continue

			if in_active:
				if trap_type == "lock":
					_arena_state.set_tile_state(cell, ArenaState.TileState.LOCKED)
				else:
					_arena_state.set_tile_state(cell, ArenaState.TileState.DANGER)
					damage_positions.append(cell)
			elif in_warning:
				# Only set warning if not already in a higher-priority state
				var current: int = _arena_state.get_tile_state(cell)
				if current == ArenaState.TileState.EMPTY:
					_arena_state.set_tile_state(cell, ArenaState.TileState.WARNING)

				# Store countdown: beats remaining until this trap activates
				var beats_remaining: int = int(trap_beat) - beat_index
				# Keep the smallest countdown if multiple traps warn the same tile
				if not _tile_countdown.has(cell) or beats_remaining < _tile_countdown[cell]:
					_tile_countdown[cell] = beats_remaining

	if damage_positions.size() > 0:
		player_should_take_damage.emit(damage_positions)


func _is_in_grid(pos: Vector2i) -> bool:
	if _level_data == null:
		return pos.x >= 0 and pos.y >= 0 and pos.x < 6 and pos.y < 6
	return pos.x >= 0 and pos.y >= 0 and pos.x < _level_data.grid_size.x and pos.y < _level_data.grid_size.y

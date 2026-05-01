## TelegraphSystem — Reads LevelData traps each beat, updates ArenaState.
## Attach as child of Battle scene. Needs rhythm_clock + arena_state + level_data.
extends Node

signal player_should_take_damage(positions: Array)
signal player_trapped_in_lock(safe_cell: Vector2i)

var _rhythm_clock: Node = null
var _arena_state: ArenaState = null
var _level_data: Resource = null
var _player: Node2D = null

## Per-tile countdown: Vector2i → int (beats remaining until activation)
var _tile_countdown: Dictionary = {}

## Per-tile trap type for warnings: Vector2i → String ("pulse", "lock", "chord")
var _tile_warn_type: Dictionary = {}

## Per-tile chord direction (for chord warning/active visuals): Vector2i → Vector2i
var _tile_chord_dir: Dictionary = {}


func setup(clock: Node, state: ArenaState, ld: Resource, player: Node2D = null) -> void:
	_rhythm_clock = clock
	_arena_state = state
	_level_data = ld
	_player = player

	if _rhythm_clock.has_signal("beat_triggered"):
		_rhythm_clock.beat_triggered.connect(_on_beat_triggered)


## Get the countdown for a specific tile (0 if not in warning)
func get_countdown(pos: Vector2i) -> int:
	if _tile_countdown.has(pos):
		return _tile_countdown[pos]
	return 0


## Get the trap type for a warning tile ("pulse", "lock", "chord")
func get_warn_type(pos: Vector2i) -> String:
	if _tile_warn_type.has(pos):
		return _tile_warn_type[pos]
	return ""


## Get chord direction for a tile (used by visualizer for arrow drawing)
func get_chord_direction(pos: Vector2i) -> Vector2i:
	if _tile_chord_dir.has(pos):
		return _tile_chord_dir[pos]
	return Vector2i.ZERO


func _on_beat_triggered(beat_index: int, _beat_time_seconds: float) -> void:
	if _level_data == null or _arena_state == null:
		return

	_arena_state.clear_all()
	_tile_countdown.clear()
	_tile_warn_type.clear()
	_tile_chord_dir.clear()

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

		# === CHORD TRAP: moving entity ===
		if trap_type == "chord":
			var direction: Vector2i = t.get("direction", Vector2i.ZERO) as Vector2i

			if in_warning:
				# Warning phase: show warning at the original positions
				for pos in positions:
					var cell: Vector2i = pos as Vector2i
					if not _is_in_grid(cell):
						continue
					var current: int = _arena_state.get_tile_state(cell)
					if current == ArenaState.TileState.EMPTY:
						_arena_state.set_tile_state(cell, ArenaState.TileState.WARNING_CHORD)
					# Store countdown
					var beats_remaining: int = int(trap_beat) - beat_index
					if not _tile_countdown.has(cell) or beats_remaining < _tile_countdown[cell]:
						_tile_countdown[cell] = beats_remaining
					_tile_warn_type[cell] = "chord"
					_tile_chord_dir[cell] = direction

			elif in_active:
				# Active phase: compute moved position
				# beat offset from activation: 0, 1, 2, ... (duration-1)
				var beat_offset: int = beat_index - int(trap_beat)
				for pos in positions:
					var origin: Vector2i = pos as Vector2i
					var moved: Vector2i = origin + direction * beat_offset
					if not _is_in_grid(moved):
						continue  # Off-grid = disappeared
					_arena_state.set_tile_state(moved, ArenaState.TileState.CHORD_DANGER)
					_tile_chord_dir[moved] = direction
					damage_positions.append(moved)

		# === LOCK TRAP ===
		elif trap_type == "lock":
			for pos in positions:
				var cell: Vector2i = pos as Vector2i
				if not _is_in_grid(cell):
					continue

				if in_active:
					_arena_state.set_tile_state(cell, ArenaState.TileState.LOCKED)
				elif in_warning:
					var current: int = _arena_state.get_tile_state(cell)
					if current == ArenaState.TileState.EMPTY:
						_arena_state.set_tile_state(cell, ArenaState.TileState.WARNING_LOCK)
					var beats_remaining: int = int(trap_beat) - beat_index
					if not _tile_countdown.has(cell) or beats_remaining < _tile_countdown[cell]:
						_tile_countdown[cell] = beats_remaining
					_tile_warn_type[cell] = "lock"

		# === PULSE TRAP (default) ===
		else:
			for pos in positions:
				var cell: Vector2i = pos as Vector2i
				if not _is_in_grid(cell):
					continue

				if in_active:
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
					_tile_warn_type[cell] = "pulse"

	if damage_positions.size() > 0:
		player_should_take_damage.emit(damage_positions)

	# Check if player is trapped inside a locked tile and displace them
	_check_player_locked()


func _check_player_locked() -> void:
	if _player == null or _arena_state == null:
		return
	if not _player.has_method("get_grid_position"):
		return

	var player_pos: Vector2i = _player.get_grid_position()
	if not _arena_state.is_locked(player_pos):
		return

	# Player is on a locked tile — find nearest EMPTY tile (Manhattan BFS)
	var cols: int = _arena_state._columns
	var rows: int = _arena_state._rows
	var best_cell: Vector2i = Vector2i(-1, -1)
	var best_dist: int = 999

	for x in range(cols):
		for y in range(rows):
			var cell := Vector2i(x, y)
			var state: int = _arena_state.get_tile_state(cell)
			if state == ArenaState.TileState.EMPTY or state == ArenaState.TileState.WARNING or state == ArenaState.TileState.WARNING_LOCK or state == ArenaState.TileState.WARNING_CHORD:
				var dist: int = abs(cell.x - player_pos.x) + abs(cell.y - player_pos.y)
				if dist < best_dist:
					best_dist = dist
					best_cell = cell

	if best_cell != Vector2i(-1, -1):
		player_trapped_in_lock.emit(best_cell)


func _is_in_grid(pos: Vector2i) -> bool:
	if _level_data == null:
		return pos.x >= 0 and pos.y >= 0 and pos.x < 6 and pos.y < 6
	return pos.x >= 0 and pos.y >= 0 and pos.x < _level_data.grid_size.x and pos.y < _level_data.grid_size.y

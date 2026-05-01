## ArenaState — Tracks the state of every tile in the arena grid.
## Each cell can be EMPTY, WARNING, DANGER, or LOCKED.
class_name ArenaState
extends RefCounted

enum TileState { EMPTY, WARNING, DANGER, LOCKED, CHORD_DANGER, WARNING_LOCK, WARNING_CHORD }

signal tile_state_changed(pos: Vector2i, old_state: int, new_state: int)

var _columns: int = 6
var _rows: int = 6
var _grid: Array = []  # 2D array of TileState


func _init(cols: int = 6, rows_count: int = 6) -> void:
	_columns = cols
	_rows = rows_count
	clear_all()


func clear_all() -> void:
	_grid.clear()
	for x in range(_columns):
		var col: Array = []
		col.resize(_rows)
		col.fill(TileState.EMPTY)
		_grid.append(col)


func set_tile_state(pos: Vector2i, state: int) -> void:
	if not _is_valid(pos):
		return
	var old: int = _grid[pos.x][pos.y]
	if old == state:
		return
	_grid[pos.x][pos.y] = state
	tile_state_changed.emit(pos, old, state)


func get_tile_state(pos: Vector2i) -> int:
	if not _is_valid(pos):
		return TileState.EMPTY
	return _grid[pos.x][pos.y]


func is_dangerous(pos: Vector2i) -> bool:
	var s: int = get_tile_state(pos)
	return s == TileState.DANGER or s == TileState.CHORD_DANGER


func is_locked(pos: Vector2i) -> bool:
	return get_tile_state(pos) == TileState.LOCKED


func _is_valid(pos: Vector2i) -> bool:
	return pos.x >= 0 and pos.y >= 0 and pos.x < _columns and pos.y < _rows

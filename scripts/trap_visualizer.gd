## TrapVisualizer — Draws colored overlays on arena tiles based on ArenaState.
## Add as child of Arena node. Needs arena_grid reference for coordinate mapping.
extends Node2D

var _arena_grid: Node2D = null
var _arena_state: ArenaState = null
var _telegraph_system: Node = null
var _tile_size: Vector2 = Vector2(64, 64)

## Visual config
var warning_color: Color = Color(0.914, 0.835, 0.008, 0.55)
var danger_pulse_color: Color = Color(0.6, 0.15, 0.85, 0.55)
var danger_flash_color: Color = Color(0.8, 0.3, 1.0, 0.7)
var locked_color: Color = Color(0.85, 0.15, 0.15, 0.45)

var _flash_timer: float = 0.0
var _flash_active: bool = false


func setup(arena: Node2D, state: ArenaState, telegraph: Node = null) -> void:
	_arena_grid = arena
	_arena_state = state
	_telegraph_system = telegraph

	# Derive tile size from TileMap
	if arena.has_node("TileMap"):
		var tm: TileMap = arena.get_node("TileMap")
		_tile_size = Vector2(tm.tile_set.tile_size)
	_arena_state.tile_state_changed.connect(_on_tile_changed)


func _on_tile_changed(_pos: Vector2i, _old: int, _new: int) -> void:
	if _new == ArenaState.TileState.DANGER:
		_flash_active = true
		_flash_timer = 0.15
	queue_redraw()


func _process(delta: float) -> void:
	if _flash_timer > 0.0:
		_flash_timer -= delta
		if _flash_timer <= 0.0:
			_flash_active = false
		queue_redraw()


func _draw() -> void:
	if _arena_grid == null or _arena_state == null:
		return

	var cols: int = _arena_state._columns
	var rows: int = _arena_state._rows

	for x in range(cols):
		for y in range(rows):
			var cell := Vector2i(x, y)
			var state: int = _arena_state.get_tile_state(cell)
			if state == ArenaState.TileState.EMPTY:
				continue

			var world_pos: Vector2 = _arena_grid.grid_to_world(cell)
			# Convert to local coordinates of this node
			var local_pos: Vector2 = to_local(world_pos)
			# _draw() is in local space of Arena child — no need to multiply by parent scale
			var rect_size: Vector2 = _tile_size
			var rect_origin: Vector2 = local_pos - rect_size * 0.5

			var color: Color = Color.TRANSPARENT
			match state:
				ArenaState.TileState.WARNING:
					color = warning_color
				ArenaState.TileState.DANGER:
					color = danger_flash_color if _flash_active else danger_pulse_color
				ArenaState.TileState.LOCKED:
					color = locked_color

			draw_rect(Rect2(rect_origin, rect_size), color, true)

			# Draw warning countdown or lock icon text
			if state == ArenaState.TileState.WARNING:
				var countdown: int = 0
				if _telegraph_system != null and _telegraph_system.has_method("get_countdown"):
					countdown = _telegraph_system.get_countdown(cell)
				_draw_warning_countdown(local_pos, rect_size, countdown)
			elif state == ArenaState.TileState.LOCKED:
				_draw_lock_label(local_pos, rect_size)


func _draw_warning_countdown(center: Vector2, _rect_size: Vector2, beats_remaining: int) -> void:
	var font: Font = ThemeDB.fallback_font
	var font_size: int = 24
	var text: String = str(beats_remaining) if beats_remaining > 0 else "!"
	var text_width: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size).x
	var ascent: float = font.get_ascent(font_size)
	var descent: float = font.get_descent(font_size)
	var text_pos: Vector2 = Vector2(center.x - text_width * 0.5, center.y + (ascent - descent) * 0.5)

	# Consistent warm yellow
	var col: Color = Color(1.0, 0.95, 0.3, 0.95)
	draw_string(font, text_pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, col)


func _draw_lock_label(center: Vector2, _rect_size: Vector2) -> void:
	var font: Font = ThemeDB.fallback_font
	var font_size: int = 28
	var text: String = "X"
	var text_width: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size).x
	var ascent: float = font.get_ascent(font_size)
	var descent: float = font.get_descent(font_size)
	var text_pos: Vector2 = Vector2(center.x - text_width * 0.5, center.y + (ascent - descent) * 0.5)
	draw_string(font, text_pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(1.0, 0.3, 0.3, 0.85))

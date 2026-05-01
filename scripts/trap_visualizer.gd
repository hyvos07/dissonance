## TrapVisualizer — Draws colored overlays on arena tiles based on ArenaState.
## Add as child of Arena node. Needs arena_grid reference for coordinate mapping.
## Each trap type has unique warning + active visuals.
extends Node2D

var _arena_grid: Node2D = null
var _arena_state: ArenaState = null
var _telegraph_system: Node = null
var _tile_size: Vector2 = Vector2(64, 64)

## Visual config — Pulse (purple)
var danger_pulse_color: Color = Color(0.6, 0.15, 0.85, 0.55)
var danger_flash_color: Color = Color(0.8, 0.3, 1.0, 0.7)

## Visual config — Chord (blue)
var chord_danger_color: Color = Color(0.15, 0.45, 0.95, 0.55)
var chord_flash_color: Color = Color(0.25, 0.6, 1.0, 0.7)

## Visual config — Lock (red)
var locked_color: Color = Color(0.85, 0.15, 0.15, 0.45)

## Visual config — Warnings (each type gets unique color)
var warning_pulse_color: Color = Color(0.914, 0.835, 0.008, 0.55)   # Warm yellow
var warning_lock_color: Color = Color(0.85, 0.25, 0.15, 0.35)       # Soft red
var warning_chord_color: Color = Color(0.15, 0.55, 0.85, 0.35)      # Soft blue

var _flash_timer: float = 0.0
var _flash_active: bool = false
var _chord_flash_timer: float = 0.0
var _chord_flash_active: bool = false


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
	elif _new == ArenaState.TileState.CHORD_DANGER:
		_chord_flash_active = true
		_chord_flash_timer = 0.15
	queue_redraw()


func _process(delta: float) -> void:
	if _flash_timer > 0.0:
		_flash_timer -= delta
		if _flash_timer <= 0.0:
			_flash_active = false
		queue_redraw()
	if _chord_flash_timer > 0.0:
		_chord_flash_timer -= delta
		if _chord_flash_timer <= 0.0:
			_chord_flash_active = false
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

			match state:
				ArenaState.TileState.WARNING:
					# Pulse warning: yellow + countdown number
					draw_rect(Rect2(rect_origin, rect_size), warning_pulse_color, true)
					_draw_pulse_warning(local_pos, rect_size, cell)

				ArenaState.TileState.WARNING_LOCK:
					# Lock warning: soft red + lock icon
					draw_rect(Rect2(rect_origin, rect_size), warning_lock_color, true)
					_draw_lock_warning(local_pos, rect_size, cell)

				ArenaState.TileState.WARNING_CHORD:
					# Chord warning: soft blue + direction arrow
					draw_rect(Rect2(rect_origin, rect_size), warning_chord_color, true)
					_draw_chord_warning(local_pos, rect_size, cell)

				ArenaState.TileState.DANGER:
					# Pulse active: purple flash
					var color: Color = danger_flash_color if _flash_active else danger_pulse_color
					draw_rect(Rect2(rect_origin, rect_size), color, true)

				ArenaState.TileState.CHORD_DANGER:
					# Chord active: blue + direction arrow
					var color: Color = chord_flash_color if _chord_flash_active else chord_danger_color
					draw_rect(Rect2(rect_origin, rect_size), color, true)
					_draw_chord_arrow(local_pos, rect_size, cell)

				ArenaState.TileState.LOCKED:
					# Lock active: red + X
					draw_rect(Rect2(rect_origin, rect_size), locked_color, true)
					_draw_lock_label(local_pos, rect_size)


# ─── PULSE WARNING: yellow countdown number ───

func _draw_pulse_warning(center: Vector2, _rect_size: Vector2, cell: Vector2i) -> void:
	var countdown: int = 0
	if _telegraph_system != null and _telegraph_system.has_method("get_countdown"):
		countdown = _telegraph_system.get_countdown(cell)

	var font: Font = ThemeDB.fallback_font
	var font_size: int = 24
	var text: String = str(countdown) if countdown > 0 else "!"
	var text_width: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size).x
	var ascent: float = font.get_ascent(font_size)
	var descent: float = font.get_descent(font_size)
	var text_pos: Vector2 = Vector2(center.x - text_width * 0.5, center.y + (ascent - descent) * 0.5)

	# Warm yellow text
	var col: Color = Color(1.0, 0.95, 0.3, 0.95)
	draw_string(font, text_pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, col)


# ─── LOCK WARNING: red-ish with lock icon ───

func _draw_lock_warning(center: Vector2, rect_size: Vector2, cell: Vector2i) -> void:
	var countdown: int = 0
	if _telegraph_system != null and _telegraph_system.has_method("get_countdown"):
		countdown = _telegraph_system.get_countdown(cell)

	# Draw a padlock shape (simplified: rectangle body + arc top)
	var icon_size: float = min(rect_size.x, rect_size.y) * 0.35
	var body_w: float = icon_size * 0.7
	var body_h: float = icon_size * 0.5
	var body_origin := Vector2(center.x - body_w * 0.5, center.y - body_h * 0.3)

	# Lock body
	var lock_col: Color = Color(1.0, 0.4, 0.3, 0.9)
	draw_rect(Rect2(body_origin, Vector2(body_w, body_h)), lock_col, true)

	# Lock shackle (arc approximation with lines)
	var arc_cx: float = center.x
	var arc_bottom: float = body_origin.y
	var arc_radius: float = body_w * 0.35
	var arc_top: float = arc_bottom - arc_radius * 1.3
	# Left line
	draw_line(Vector2(arc_cx - arc_radius, arc_bottom), Vector2(arc_cx - arc_radius, arc_top), lock_col, 2.5)
	# Top arc (simple horizontal)
	draw_line(Vector2(arc_cx - arc_radius, arc_top), Vector2(arc_cx + arc_radius, arc_top), lock_col, 2.5)
	# Right line
	draw_line(Vector2(arc_cx + arc_radius, arc_bottom), Vector2(arc_cx + arc_radius, arc_top), lock_col, 2.5)

	# Countdown below icon
	if countdown > 0:
		var font: Font = ThemeDB.fallback_font
		var font_size: int = 14
		var text: String = str(countdown)
		var text_width: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size).x
		var text_pos := Vector2(center.x - text_width * 0.5, body_origin.y + body_h + font.get_ascent(font_size) + 2.0)
		draw_string(font, text_pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(1.0, 0.5, 0.4, 0.95))


# ─── CHORD WARNING: blue with direction triangle ───

func _draw_chord_warning(center: Vector2, rect_size: Vector2, cell: Vector2i) -> void:
	var countdown: int = 0
	if _telegraph_system != null and _telegraph_system.has_method("get_countdown"):
		countdown = _telegraph_system.get_countdown(cell)

	# Direction arrow
	var dir: Vector2i = Vector2i.ZERO
	if _telegraph_system != null and _telegraph_system.has_method("get_chord_direction"):
		dir = _telegraph_system.get_chord_direction(cell)

	# Draw triangle arrow pointing in direction
	_draw_direction_triangle(center, rect_size, dir, Color(0.3, 0.7, 1.0, 0.9))

	# Countdown text
	if countdown > 0:
		var font: Font = ThemeDB.fallback_font
		var font_size: int = 14
		var text: String = str(countdown)
		var text_width: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size).x
		var ascent: float = font.get_ascent(font_size)
		var descent: float = font.get_descent(font_size)
		var text_pos := Vector2(center.x - text_width * 0.5, center.y + (ascent - descent) * 0.5 + rect_size.y * 0.25)
		draw_string(font, text_pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(0.4, 0.8, 1.0, 0.95))


# ─── CHORD ACTIVE: blue with direction triangle ───

func _draw_chord_arrow(center: Vector2, rect_size: Vector2, cell: Vector2i) -> void:
	var dir: Vector2i = Vector2i.ZERO
	if _telegraph_system != null and _telegraph_system.has_method("get_chord_direction"):
		dir = _telegraph_system.get_chord_direction(cell)
	_draw_direction_triangle(center, rect_size, dir, Color(0.9, 0.95, 1.0, 0.95))


# ─── Shared: draw filled triangle arrow pointing in a direction ───

func _draw_direction_triangle(center: Vector2, rect_size: Vector2, dir: Vector2i, color: Color) -> void:
	var half: float = min(rect_size.x, rect_size.y) * 0.28
	var points: PackedVector2Array = PackedVector2Array()

	if dir == Vector2i(1, 0):  # Right
		points.append(Vector2(center.x + half, center.y))
		points.append(Vector2(center.x - half * 0.6, center.y - half * 0.7))
		points.append(Vector2(center.x - half * 0.6, center.y + half * 0.7))
	elif dir == Vector2i(-1, 0):  # Left
		points.append(Vector2(center.x - half, center.y))
		points.append(Vector2(center.x + half * 0.6, center.y - half * 0.7))
		points.append(Vector2(center.x + half * 0.6, center.y + half * 0.7))
	elif dir == Vector2i(0, 1):  # Down
		points.append(Vector2(center.x, center.y + half))
		points.append(Vector2(center.x - half * 0.7, center.y - half * 0.6))
		points.append(Vector2(center.x + half * 0.7, center.y - half * 0.6))
	elif dir == Vector2i(0, -1):  # Up
		points.append(Vector2(center.x, center.y - half))
		points.append(Vector2(center.x - half * 0.7, center.y + half * 0.6))
		points.append(Vector2(center.x + half * 0.7, center.y + half * 0.6))
	else:
		# Diagonal or unknown — draw a diamond
		points.append(Vector2(center.x, center.y - half))
		points.append(Vector2(center.x + half, center.y))
		points.append(Vector2(center.x, center.y + half))
		points.append(Vector2(center.x - half, center.y))

	if points.size() >= 3:
		draw_colored_polygon(points, color)


# ─── LOCK ACTIVE: red X ───

func _draw_lock_label(center: Vector2, _rect_size: Vector2) -> void:
	var font: Font = ThemeDB.fallback_font
	var font_size: int = 28
	var text: String = "X"
	var text_width: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size).x
	var ascent: float = font.get_ascent(font_size)
	var descent: float = font.get_descent(font_size)
	var text_pos: Vector2 = Vector2(center.x - text_width * 0.5, center.y + (ascent - descent) * 0.5)
	draw_string(font, text_pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(1.0, 0.3, 0.3, 0.85))

extends Control

@export var rhythm_clock_path: NodePath
@export_range(2.0, 24.0, 1.0) var center_line_width: float = 2.0
@export_range(1.0, 16.0, 1.0) var bar_width: float = 4.0
@export_range(16.0, 220.0, 1.0) var bar_height: float = 88.0
@export_range(1, 16, 1) var bars_ahead: int = 8
@export_range(16.0, 220.0, 1.0) var pixels_per_beat: float = 96.0
@export var draw_left_side: bool = true
@export var draw_right_side: bool = true
@export var center_line_color: Color = Color(0.85, 0.95, 1.0, 0.9)
@export var beat_bar_color: Color = Color(0.2, 0.95, 0.95, 0.95)
@export var lane_color: Color = Color(0.06, 0.06, 0.08, 0.85)
@export var border_color: Color = Color(0.25, 0.25, 0.35, 0.6)

var _rhythm_clock: Node
var _beat_fraction: float = 0.0
var _beat_flash: float = 0.0
var _last_seen_beat: int = -1
var _impact_latched: bool = false

## Maximum beat — beats beyond this won't appear in the visualizer.
## Set to -1 to show beats indefinitely.
var max_beat: int = -1

## Track the current whole beat for clamping
var _current_beat: float = 0.0


func _ready() -> void:
	set_process(true)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_resolve_rhythm_clock()
	_connect_rhythm_clock()
	queue_redraw()


func _process(delta: float) -> void:
	if _rhythm_clock != null and _rhythm_clock.has_method("get_song_position_seconds") and _rhythm_clock.has_method("get_seconds_per_beat"):
		var seconds_per_beat: float = max(float(_rhythm_clock.call("get_seconds_per_beat")), 0.001)
		var beat_position: float = float(_rhythm_clock.call("get_song_position_seconds")) / seconds_per_beat
		_current_beat = beat_position
		_beat_fraction = beat_position - floor(beat_position)

		var nearest_distance: float = (1.0 - _beat_fraction) * pixels_per_beat
		var hit_window: float = max((bar_width + center_line_width) * 0.8, 1.0)
		if nearest_distance <= hit_window and not _impact_latched:
			_trigger_center_hit_glow()
			_impact_latched = true
		elif nearest_distance > hit_window * 2.0:
			_impact_latched = false

	_beat_flash = max(_beat_flash - (delta * 4.0), 0.0)
	queue_redraw()


func _draw() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return

	var center: Vector2 = size * 0.5
	var half_bar_height: float = bar_height * 0.5
	var lane_top: float = center.y - half_bar_height - 10.0
	var lane_height: float = bar_height + 20.0

	# Draw background panel with rounded corners feel
	var lane_rect := Rect2(Vector2(0.0, lane_top), Vector2(size.x, lane_height))
	draw_rect(lane_rect, lane_color, true)

	# Draw border (top + bottom lines)
	var border_top := Rect2(Vector2(0.0, lane_top), Vector2(size.x, 1.0))
	var border_bottom := Rect2(Vector2(0.0, lane_top + lane_height - 1.0), Vector2(size.x, 1.0))
	var border_left := Rect2(Vector2(0.0, lane_top), Vector2(1.0, lane_height))
	var border_right := Rect2(Vector2(size.x - 1.0, lane_top), Vector2(1.0, lane_height))
	draw_rect(border_top, border_color, true)
	draw_rect(border_bottom, border_color, true)
	draw_rect(border_left, border_color, true)
	draw_rect(border_right, border_color, true)

	# Center glow flash
	var flash_strength: float = 0.35 * _beat_flash
	if _beat_flash > 0.0:
		var glow_rect := Rect2(
			Vector2(center.x - ((center_line_width + 24.0 * _beat_flash) * 0.5), center.y - half_bar_height - 8.0),
			Vector2(center_line_width + 24.0 * _beat_flash, bar_height + 16.0)
		)
		var glow_color := Color(center_line_color.r, center_line_color.g, center_line_color.b, 0.28 * _beat_flash)
		draw_rect(glow_rect, glow_color, true)

	# Center line
	var center_color: Color = center_line_color.lerp(Color(1.0, 1.0, 1.0, 1.0), flash_strength)
	var center_rect := Rect2(
		Vector2(center.x - (center_line_width * 0.5), center.y - half_bar_height - 4.0),
		Vector2(center_line_width, bar_height + 8.0)
	)
	draw_rect(center_rect, center_color, true)

	# Beat bars
	var current_whole_beat: int = floori(_current_beat)
	for i in range(1, bars_ahead + 1):
		# The beat index this bar represents
		var upcoming_beat: int = current_whole_beat + i

		# Skip beats past the max (song's last effective beat)
		if max_beat > 0 and upcoming_beat > max_beat:
			continue

		var distance: float = (float(i) - _beat_fraction) * pixels_per_beat
		if distance <= (bar_width + center_line_width):
			continue

		var fade: float = 1.0 - (float(i - 1) / max(float(bars_ahead), 1.0))
		var bar_color: Color = beat_bar_color
		bar_color.a *= clamp(fade, 0.15, 1.0)

		if draw_left_side:
			_draw_bar(center.x - distance, center.y, bar_color)
		if draw_right_side:
			_draw_bar(center.x + distance, center.y, bar_color)


func _draw_bar(x: float, center_y: float, color: Color) -> void:
	var bar_rect := Rect2(
		Vector2(x - (bar_width * 0.5), center_y - (bar_height * 0.5)),
		Vector2(bar_width, bar_height)
	)
	draw_rect(bar_rect, color, true)


func _resolve_rhythm_clock() -> void:
	if rhythm_clock_path != NodePath("") and has_node(rhythm_clock_path):
		_rhythm_clock = get_node(rhythm_clock_path)
		return

	var cursor: Node = self
	while cursor != null:
		if cursor.has_node("RhythmClock"):
			_rhythm_clock = cursor.get_node("RhythmClock")
			return
		cursor = cursor.get_parent()

	push_warning("BeatVisualizer could not find a RhythmClock node. Set rhythm_clock_path in the inspector.")


func _connect_rhythm_clock() -> void:
	if _rhythm_clock == null:
		return

	if _rhythm_clock.has_signal("beat_triggered"):
		var callback := Callable(self, "_on_beat_triggered")
		if not _rhythm_clock.is_connected("beat_triggered", callback):
			_rhythm_clock.connect("beat_triggered", callback)


func _on_beat_triggered(beat_index: int, _beat_time_seconds: float) -> void:
	if beat_index == _last_seen_beat:
		return

	_last_seen_beat = beat_index
	_trigger_center_hit_glow()


func _trigger_center_hit_glow() -> void:
	_beat_flash = max(_beat_flash, 1.0)

extends Node2D

signal move_resolved(result: String, from_cell: Vector2i, to_cell: Vector2i)
signal player_hit(remaining_hp: int)
signal player_died

@export var start_grid_position: Vector2i = Vector2i(2, 2)
@export var use_wasd: bool = true
@export_range(0.0, 0.5, 0.01) var move_input_buffer_seconds: float = 0.08

@onready var _visual: Node2D = $Visual

var _arena: Node = null
var _arena_state: ArenaState = null
var _grid_position: Vector2i = Vector2i.ZERO
var _facing: Vector2i = Vector2i.DOWN
var _next_move_allowed_time_ms: int = 0

## HP
var max_hp: int = 3
var hp: int = 3
var _invincible: bool = false
var _invincible_timer: float = 0.0
const INVINCIBLE_DURATION: float = 1.0

## When true, player cannot move (used by countdown).
var frozen: bool = false


func _ready() -> void:
	_grid_position = start_grid_position


func configure(arena: Node, arena_state: ArenaState = null) -> void:
	_arena = arena
	_arena_state = arena_state
	_sync_world_position()
	if _visual.has_method("set_facing"):
		_visual.set_facing(_facing)


func setup_hp(max_health: int, current_health: int) -> void:
	max_hp = max_health
	hp = current_health


func _process(delta: float) -> void:
	if _invincible:
		_invincible_timer -= delta
		if _invincible_timer <= 0.0:
			_invincible = false
			if _visual:
				_visual.modulate.a = 1.0


func _unhandled_input(event: InputEvent) -> void:
	if frozen or _arena == null or hp <= 0:
		return
	if event is InputEventKey and event.echo:
		return
	if Time.get_ticks_msec() < _next_move_allowed_time_ms:
		return

	var direction: Vector2i = _extract_direction(event)
	if direction == Vector2i.ZERO:
		return

	if move_input_buffer_seconds > 0.0:
		_next_move_allowed_time_ms = Time.get_ticks_msec() + int(round(move_input_buffer_seconds * 1000.0))

	_attempt_move(direction)


func check_damage_at_current_tile() -> void:
	if _arena_state == null or _invincible or hp <= 0:
		return
	if _arena_state.is_dangerous(_grid_position):
		take_damage()


func take_damage(amount: int = 1) -> void:
	if _invincible or hp <= 0:
		return
	hp = max(hp - amount, 0)
	_invincible = true
	_invincible_timer = INVINCIBLE_DURATION

	# Visual feedback: flash + blink
	if _visual:
		_visual.modulate = Color(1.0, 0.3, 0.3, 1.0)
		var tween := create_tween()
		tween.tween_property(_visual, "modulate", Color(1.0, 1.0, 1.0, 0.5), 0.15)
		tween.tween_property(_visual, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.15)
		tween.set_loops(3)

	player_hit.emit(hp)
	if hp <= 0:
		player_died.emit()


func get_grid_position() -> Vector2i:
	return _grid_position


func _extract_direction(event: InputEvent) -> Vector2i:
	if event.is_action_pressed("ui_up"):
		return Vector2i.UP
	if event.is_action_pressed("ui_down"):
		return Vector2i.DOWN
	if event.is_action_pressed("ui_left"):
		return Vector2i.LEFT
	if event.is_action_pressed("ui_right"):
		return Vector2i.RIGHT

	if use_wasd and event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_W:
				return Vector2i.UP
			KEY_S:
				return Vector2i.DOWN
			KEY_A:
				return Vector2i.LEFT
			KEY_D:
				return Vector2i.RIGHT

	return Vector2i.ZERO


func _attempt_move(direction: Vector2i) -> void:
	var from_cell: Vector2i = _grid_position
	_facing = direction
	if _visual.has_method("set_facing"):
		_visual.set_facing(direction)

	var target: Vector2i = _grid_position + direction

	# Check arena bounds
	if not _arena.is_inside(target):
		if _visual.has_method("play_step"):
			_visual.play_step(direction)
		move_resolved.emit("BLOCKED", from_cell, from_cell)
		return

	# Check locked tiles
	if _arena_state != null and _arena_state.is_locked(target):
		if _visual.has_method("play_step"):
			_visual.play_step(direction)
		move_resolved.emit("BLOCKED", from_cell, from_cell)
		return

	_grid_position = target
	_sync_world_position()

	if _visual.has_method("play_step"):
		_visual.play_step(direction)
	if _visual.has_method("show_timing_feedback"):
		_visual.show_timing_feedback("MOVED")
	move_resolved.emit("MOVED", from_cell, _grid_position)


func _sync_world_position() -> void:
	if _arena == null:
		return
	global_position = _arena.grid_to_world(_grid_position)

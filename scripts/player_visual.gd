extends Node2D

@onready var _sprite: AnimatedSprite2D = $Sprite
@export var step_lunge_distance: float = 6.0
@export var step_bob_height: float = 3.0
@export var step_out_duration: float = 0.06
@export var step_return_duration: float = 0.1

var _step_toggle: int = 0
var _step_tween: Tween = null
var _base_position: Vector2 = Vector2.ZERO


func _ready() -> void:
	_base_position = position


func set_facing(direction: Vector2i) -> void:
	_sprite.frame = _frame_for_direction(direction, false)


func play_step(direction: Vector2i) -> void:
	_step_toggle = (_step_toggle + 1) % 2
	_sprite.frame = _frame_for_direction(direction, true)
	if _step_tween != null and _step_tween.is_valid():
		_step_tween.kill()

	position = _base_position
	var lunge_target: Vector2 = _base_position + (Vector2(direction) * step_lunge_distance)
	lunge_target.y -= step_bob_height

	_step_tween = create_tween()
	_step_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_step_tween.tween_property(self, "position", lunge_target, step_out_duration)
	_step_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	_step_tween.tween_property(self, "position", _base_position, step_return_duration)


func show_timing_feedback(judgement: String) -> void:
	var flash_color := Color(1.0, 1.0, 1.0, 1.0)
	match judgement:
		"MOVED":
			flash_color = Color(1.0, 1.12, 1.0, 1.0)
		"PERFECT":
			flash_color = Color(1.2, 1.2, 1.2, 1.0)
		"GOOD":
			flash_color = Color(1.0, 1.1, 1.25, 1.0)
		"MISS":
			flash_color = Color(1.2, 0.7, 0.7, 1.0)
		"BLOCKED":
			flash_color = Color(1.0, 0.8, 0.6, 1.0)

	_sprite.modulate = flash_color
	var tween := create_tween()
	tween.tween_property(_sprite, "modulate", Color.WHITE, 0.12)


func _frame_for_direction(direction: Vector2i, stepping: bool) -> int:
	var row: int = 0
	if direction == Vector2i.UP:
		row = 12
	elif direction == Vector2i.LEFT:
		row = 8
	elif direction == Vector2i.RIGHT:
		row = 4
	else:
		row = 0

	var column: int = 0
	if stepping:
		column = 1 if _step_toggle == 0 else 2

	return row * 8 + column

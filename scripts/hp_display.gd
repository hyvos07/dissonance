## HpDisplay — Simple heart-based HP display for the HUD.
extends HBoxContainer

signal hp_depleted

var _max_hp: int = 3
var _current_hp: int = 3
var _heart_labels: Array[Label] = []

## Colors
var full_color: Color = Color(1.0, 0.3, 0.35, 1.0)
var empty_color: Color = Color(0.25, 0.15, 0.15, 0.4)
var flash_color: Color = Color(1.0, 1.0, 1.0, 1.0)


func setup(max_hp: int, current_hp: int) -> void:
	_max_hp = max_hp
	_current_hp = current_hp
	_rebuild_hearts()


func take_damage(amount: int = 1) -> void:
	_current_hp = max(_current_hp - amount, 0)
	_update_display()
	_flash_damage()
	if _current_hp <= 0:
		hp_depleted.emit()


func _rebuild_hearts() -> void:
	for child in get_children():
		child.queue_free()
	_heart_labels.clear()

	for i in range(_max_hp):
		var lbl := Label.new()
		lbl.text = "♥"
		lbl.add_theme_font_size_override("font_size", 32)
		lbl.add_theme_color_override("font_color", full_color)
		add_child(lbl)
		_heart_labels.append(lbl)


func _update_display() -> void:
	for i in range(_heart_labels.size()):
		if i < _current_hp:
			_heart_labels[i].add_theme_color_override("font_color", full_color)
			_heart_labels[i].text = "♥"
		else:
			_heart_labels[i].add_theme_color_override("font_color", empty_color)
			_heart_labels[i].text = "♡"


func _flash_damage() -> void:
	# Flash the last lost heart white briefly
	var lost_index: int = _current_hp  # The heart that just emptied
	if lost_index >= 0 and lost_index < _heart_labels.size():
		var lbl: Label = _heart_labels[lost_index]
		lbl.add_theme_color_override("font_color", flash_color)
		var tween := create_tween()
		tween.tween_property(lbl, "theme_override_colors/font_color", empty_color, 0.3)

extends Control

signal value_changed(value: Vector2)

var _touch_index := -1
var _mouse_active := false
var _value := Vector2.ZERO
var _knob_position := Vector2.ZERO

const KNOB_RADIUS := 30.0


func _ready() -> void:
	custom_minimum_size = Vector2(164, 164)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_knob_position = size * 0.5


func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed and _touch_index == -1:
			_touch_index = event.index
			_update_value(make_canvas_position_local(event.position))
		elif not event.pressed and event.index == _touch_index:
			_touch_index = -1
			_reset_value()
	elif event is InputEventScreenDrag and event.index == _touch_index:
		_update_value(make_canvas_position_local(event.position))
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_mouse_active = event.pressed
		if _mouse_active:
			_update_value(make_canvas_position_local(event.position))
		else:
			_reset_value()
	elif event is InputEventMouseMotion and _mouse_active:
		_update_value(make_canvas_position_local(event.position))


func _update_value(pointer: Vector2) -> void:
	var center := size * 0.5
	var offset := pointer - center
	var radius := minf(size.x, size.y) * 0.38
	if offset.length() > radius:
		offset = offset.normalized() * radius
	_value = Vector2(offset.x / radius, offset.y / radius)
	_knob_position = center + offset
	value_changed.emit(_value)
	queue_redraw()


func _reset_value() -> void:
	_value = Vector2.ZERO
	_knob_position = size * 0.5
	value_changed.emit(_value)
	queue_redraw()


func _draw() -> void:
	var center := size * 0.5
	draw_circle(center, minf(size.x, size.y) * 0.46, Color(0.04, 0.10, 0.12, 0.52))
	draw_arc(center, minf(size.x, size.y) * 0.46, 0.0, TAU, 48, Color(0.72, 0.88, 0.79, 0.65), 2.0)
	draw_circle(_knob_position, KNOB_RADIUS, Color(0.75, 0.89, 0.79, 0.8))

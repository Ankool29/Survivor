class_name VirtualJoystick
extends Control
## Joystick tactile : apparaît là où le pouce se pose, dans la moitié gauche.

signal changed(vector: Vector2)

const RADIUS := 70.0
var vector := Vector2.ZERO
var _touch := -1
var _origin := Vector2.ZERO
var _knob := Vector2.ZERO


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	get_viewport().size_changed.connect(queue_redraw)
	resized.connect(queue_redraw)


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var e := event as InputEventScreenTouch
		var area := size
		if e.pressed and _touch == -1 and e.position.x < area.x * 0.45 and e.position.y > area.y * 0.2:
			_touch = e.index
			_origin = e.position
			_knob = e.position
			_update()
			get_viewport().set_input_as_handled()
		elif not e.pressed and e.index == _touch:
			_touch = -1
			_knob = _origin
			_update()
	elif event is InputEventScreenDrag:
		var d := event as InputEventScreenDrag
		if d.index == _touch:
			_knob = d.position
			_update()
			get_viewport().set_input_as_handled()


func is_touch(index: int) -> bool:
	return index == _touch


func _update() -> void:
	var off := _knob - _origin
	if off.length() > RADIUS:
		off = off.normalized() * RADIUS
		_knob = _origin + off
	vector = off / RADIUS if _touch != -1 else Vector2.ZERO
	changed.emit(vector)
	queue_redraw()


func _draw() -> void:
	if _touch == -1:
		var area := size
		var hint := Vector2(area.x * 0.12, area.y * 0.75)
		draw_circle(hint, RADIUS, Color(1, 1, 1, 0.06))
		draw_arc(hint, RADIUS, 0, TAU, 48, Color(1, 1, 1, 0.18), 2.0)
		return
	draw_circle(_origin, RADIUS, Color(0, 0, 0, 0.18))
	draw_arc(_origin, RADIUS, 0, TAU, 48, Color(1, 1, 1, 0.35), 2.0)
	draw_circle(_knob, 28, Color(1, 1, 1, 0.45))

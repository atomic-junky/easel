class_name PaintCanvas
extends Control

## Per-image freehand overlay.
##
## Strokes are stored in image-normalised coordinates and re-projected whenever
## the picture is laid out again, so a window resize or a device rotation keeps
## the drawing on the part of the image it was drawn on.

## Points closer than this (in pixels) are dropped: fewer, better-spaced points
## give a smoother curve than every raw motion sample.
const MIN_POINT_DISTANCE: float = 2.5
const UNDO_STEPS: int = 64

var brush_size: int = 8
var brush_color: Color = Color.BLACK
var can_draw: bool = false

var _canvases: Dictionary = {}  # id -> { "root": Node2D, "undo": UndoRedo }
var _current_id: String = ""
var _image_rect: Rect2 = Rect2()

var _line: Line2D = null
var _points: PackedVector2Array = []
var _pressures: PackedFloat32Array = []


func create_canvas(id: String) -> void:
	if _canvases.has(id):
		return

	var root := Node2D.new()
	root.name = "Canvas_%s" % id
	root.visible = false
	add_child(root)

	var undo := UndoRedo.new()
	undo.max_steps = UNDO_STEPS

	_canvases[id] = {"root": root, "undo": undo}


func switch_canvas(id: String) -> void:
	if not _canvases.has(id):
		push_error("Canvas '%s' does not exist" % id)
		return

	_end_stroke(false)
	for key: String in _canvases:
		_canvases[key]["root"].visible = false
	_canvases[id]["root"].visible = true
	_current_id = id


func clear_canvas() -> void:
	_end_stroke(false)
	# The old version dropped the dictionary and left every Node2D in the tree,
	# so each session leaked all of its previous drawings.
	for key: String in _canvases:
		_canvases[key]["root"].queue_free()

	_canvases.clear()
	_current_id = ""


## Called by the session with the rect the picture actually occupies.
func set_image_rect(rect: Rect2) -> void:
	if rect.size.x <= 0.0 or rect.size.y <= 0.0 or rect.is_equal_approx(_image_rect):
		return

	_image_rect = rect
	for key: String in _canvases:
		for line: Node in _canvases[key]["root"].get_children():
			if line is Line2D:
				_reproject(line)


func undo() -> void:
	if _canvases.has(_current_id):
		_canvases[_current_id]["undo"].undo()


func redo() -> void:
	if _canvases.has(_current_id):
		_canvases[_current_id]["undo"].redo()


func _input(_event: InputEvent) -> void:
	if not can_draw or not _canvases.has(_current_id):
		return

	if Input.is_action_just_pressed("app_do"):
		redo()
	elif Input.is_action_just_pressed("app_undo"):
		undo()


func _gui_input(event: InputEvent) -> void:
	if not visible or not can_draw or not _canvases.has(_current_id):
		return

	if event is InputEventMouseButton:
		if event.button_index != MOUSE_BUTTON_LEFT:
			return
		if event.pressed:
			_begin_stroke(event.position, 1.0)
		else:
			_end_stroke(true)

	elif event is InputEventScreenTouch:
		# Only the first finger draws; further fingers are gestures, not ink.
		if event.index != 0:
			_end_stroke(false)
			return
		if event.pressed:
			_begin_stroke(event.position, _pressure_of(event))
		else:
			_end_stroke(true)

	elif event is InputEventMouseMotion:
		_extend_stroke(event.position, _pressure_of(event))

	elif event is InputEventScreenDrag and event.index == 0:
		_extend_stroke(event.position, _pressure_of(event))


func _pressure_of(event: InputEvent) -> float:
	if "pressure" in event and event.pressure > 0.0:
		return clampf(event.pressure, 0.05, 1.0)
	return 1.0


func _begin_stroke(position_in_canvas: Vector2, pressure: float) -> void:
	_end_stroke(false)

	_line = Line2D.new()
	_line.antialiased = true
	_line.default_color = brush_color
	_line.width = brush_size
	_line.joint_mode = Line2D.LINE_JOINT_ROUND
	_line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	_line.end_cap_mode = Line2D.LINE_CAP_ROUND

	_points = PackedVector2Array([position_in_canvas])
	_pressures = PackedFloat32Array([pressure])

	_canvases[_current_id]["root"].add_child(_line)
	_apply_stroke()


func _extend_stroke(position_in_canvas: Vector2, pressure: float) -> void:
	if _line == null:
		return
	if _points.size() > 0 and _points[-1].distance_to(position_in_canvas) < MIN_POINT_DISTANCE:
		return

	_points.append(position_in_canvas)
	_pressures.append(pressure)
	_apply_stroke()


func _end_stroke(commit: bool) -> void:
	if _line == null:
		return

	var line: Line2D = _line
	_line = null

	# A tap is not a stroke.
	if not commit or line.get_point_count() < 2:
		line.queue_free()
		return

	line.set_meta("normalised", _to_normalised(_points))

	var root: Node2D = _canvases[_current_id]["root"]
	var undo: UndoRedo = _canvases[_current_id]["undo"]
	undo.create_action("Stroke")
	undo.add_do_method(root.add_child.bind(line))
	undo.add_do_reference(line)
	undo.add_undo_method(root.remove_child.bind(line))
	# The line is already on screen, so the "do" half must not run now.
	undo.commit_action(false)


## Rebuilds the visible geometry from the pixel points of the stroke in progress.
func _apply_stroke() -> void:
	_line.points = _points
	_line.width_curve = _build_width_curve(_pressures)


## Pressure lives in the width curve as a 0..1 multiplier of `width`. The old
## code stored `brush_size * pressure` there and always at offset 1.0, which
## both squared the thickness and flattened every stroke to a single value.
func _build_width_curve(pressures: PackedFloat32Array) -> Curve:
	var curve := Curve.new()
	curve.min_value = 0.0
	curve.max_value = 1.0

	var last: int = pressures.size() - 1
	if last <= 0:
		curve.add_point(Vector2(0.0, pressures[0] if last == 0 else 1.0))
		return curve

	for i in pressures.size():
		curve.add_point(Vector2(float(i) / float(last), pressures[i]))
	return curve


func _to_normalised(points: PackedVector2Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	if _image_rect.size.x <= 0.0 or _image_rect.size.y <= 0.0:
		return points

	for point: Vector2 in points:
		out.append((point - _image_rect.position) / _image_rect.size)
	return out


func _reproject(line: Line2D) -> void:
	var normalised: PackedVector2Array = line.get_meta("normalised", PackedVector2Array())
	if normalised.is_empty():
		return

	var out := PackedVector2Array()
	for point: Vector2 in normalised:
		out.append(_image_rect.position + point * _image_rect.size)
	line.points = out

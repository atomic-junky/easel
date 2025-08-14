class_name PaintCanvas
extends Control

enum BrushMode { PENCIL, ERASER, CIRCLE_SHAPE, RECTANGLE_SHAPE }
enum BrushShape { RECTANGLE, CIRCLE }

var brush_mode := BrushMode.PENCIL
var brush_size := 2
var brush_color := Color.BLACK
var brush_shape := BrushShape.CIRCLE
var bg_color := Color.TRANSPARENT

var _pressed := false
var _current_line: Line2D = null

# canvases: { canvas_id: { "lines": Node2D, "undo_redo": UndoRedo } }
var canvases := {}
var current_canvas_id := ""
var touch_count := 0
var can_draw: bool = false

@onready var gesture_timer: Timer = %GestureTimer


func create_canvas(id: String) -> void:
	if id in canvases:
		return
	var container := Node2D.new()
	container.name = "Canvas_%s" % id
	add_child(container)
	container.visible = false
	var ur := UndoRedo.new()
	ur.max_steps = 50
	canvases[id] = {
		"lines": container,
		"undo_redo": ur
	}


func switch_canvas(id: String) -> void:
	if not id in canvases:
		push_error("Canvas '%s' n'existe pas" % id)
		return
	for k in canvases.keys():
		canvases[k]["lines"].visible = false
	canvases[id]["lines"].visible = true
	current_canvas_id = id


func clear_canvas() -> void:
	canvases = {}
	current_canvas_id = ""
	_pressed = false
	_current_line = null


func _input(_event: InputEvent) -> void:
	if not can_draw:
		return
	
	if not current_canvas_id in canvases:
		return
	var ur: UndoRedo = canvases[current_canvas_id]["undo_redo"]
	if Input.is_action_just_pressed("app_do"):
		ur.redo()
	elif Input.is_action_just_pressed("app_undo"):
		ur.undo()


func _handle_screen_touch() -> void:
	if not gesture_timer.is_stopped():
		await gesture_timer.timeout
	
	var ur: UndoRedo = canvases[current_canvas_id]["undo_redo"]
	
	if touch_count == 2:
		ur.redo()
	elif touch_count == 1:
		ur.undo()
	else:
		return
	
	touch_count = 0



func _gui_input(event: InputEvent) -> void:
	if not visible or not can_draw:
		return
	
	if not current_canvas_id in canvases:
		return
	var canvas_lines: Node = canvases[current_canvas_id]["lines"]
	var ur: UndoRedo = canvases[current_canvas_id]["undo_redo"]

	# souris / tactile
	if event is InputEventMouseButton or event is InputEventScreenTouch:
		if event is InputEventScreenTouch:
			touch_count = max(touch_count, event.index)
			gesture_timer.start()
			_handle_screen_touch()
		
		# seulement clic gauche
		if event is InputEventMouseButton and event.button_index != MOUSE_BUTTON_LEFT:
			return

		_pressed = event.pressed
		if event.pressed:
			var new_line := Line2D.new()
			new_line.antialiased = true
			new_line.default_color = brush_color
			new_line.width = brush_size
			new_line.width_curve = Curve.new()
			new_line.begin_cap_mode = Line2D.LINE_CAP_ROUND
			new_line.end_cap_mode = Line2D.LINE_CAP_ROUND

			# Premier point
			new_line.add_point(event.position - position)

			# Pression initiale
			var pressure := 1.0
			if "pressure" in event:
				pressure = clamp(event.pressure, 0.0, 1.0)
			new_line.width_curve.add_point(Vector2(0, brush_size * pressure))

			_current_line = new_line
			canvases[current_canvas_id]["lines"].add_child(_current_line) # affichage temporaire
		elif _current_line != null:
			if _current_line.get_point_count() <= 1:
				_current_line.queue_free()
				return
			
			ur.create_action("Draw line %s" % _current_line)
			ur.add_do_method(canvases[current_canvas_id]["lines"].add_child.bind(_current_line))
			ur.add_do_reference(_current_line)
			ur.add_undo_method(canvases[current_canvas_id]["lines"].remove_child.bind(_current_line))
			ur.commit_action(false)

			_current_line = null

	# Mouvement / drag : mise à jour points et courbe de largeur
	elif _pressed and (event is InputEventMouseMotion or event is InputEventScreenDrag):
		if event is InputEventScreenDrag and event.index != 0:
			return
		
		if _current_line:
			_current_line.add_point(event.position - position)

			# Ajout du point de courbe correspondant à cette position
			var pressure := 1.0
			if "pressure" in event:
				pressure = clamp(event.pressure, 0.0, 1.0)

			var offset: float = float(_current_line.get_point_count() - 1) / max(1, _current_line.get_point_count() - 1)
			_current_line.width_curve.add_point(Vector2(offset, brush_size * pressure))


func undo() -> void:
	var ur: UndoRedo = canvases[current_canvas_id]["undo_redo"]
	ur.undo()

func redo() -> void:
	var ur: UndoRedo = canvases[current_canvas_id]["undo_redo"]
	ur.redo()

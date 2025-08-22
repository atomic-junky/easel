class_name Session extends Control

signal done(session_context: SessionContext)

@export var invisible_element: Array[Node] = []

@onready var icon_play: Texture2D = preload("res://assets/icons/play.svg")
@onready var icon_pause: Texture2D = preload("res://assets/icons/pause.svg")

@onready var pause_button: Button = %PauseButton
@onready var paint_canvas: PaintCanvas = %PaintCanvas
@onready var paint_toolbar: DrawingToolBar = %DrawingToolBar
@onready var timer: Timer = %Timer
@onready var mouse_move_timer: Timer = %MouseMovetimer
@onready var navigation_container := %NavigationContainer
@onready var file_location_button := %FileLocationButton
@onready var texture_container := %TextureContainer
@onready var spiner_container := %SpinerContainer

var _context: SessionContext
var queue: SessionQueue

var _swipe_start := Vector2.ZERO
var _swipe_min_distance := 50

var is_drawing: bool = false
var no_timer: bool = false


func load_args(args: SessionContext) -> void:
	setup()
	if not is_node_ready():
		await ready
	
	start_session(args)


func setup() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	set_process(false)
	set_process_input(false)
	
	queue = SessionQueue.new()
	add_child(queue)
	_context = null


func start_session(context: SessionContext) -> void:
	_on_paint_button_toggled(false)
	paint_canvas.clear_canvas()
	navigation_container.show()
	if OS.get_name() in ["Android", "iOS"]:
		navigation_container.hide()
		file_location_button.hide()
	
	if context.session_type == SessionContext.Type.RELAXED:
		no_timer = true
		pause_button.hide()
	
	_context = context
	var _queue: Array = context.get_images_path()
	queue.load_queue(_queue)
	mouse_move_timer.start()
	
	set_process(true)
	set_process_input(true)
	current_image()


func _process(_delta: float) -> void:
	var time_left: int = ceil(timer.time_left)
	var minutes: int = floor(time_left/60)
	var seconds: int = time_left-(minutes*60)
	pause_button.text = "%s:%02d" % [minutes, seconds]
	
	%ButtonPrevious.disabled = not queue.has_previous()
	%ButtonNext.disabled = not queue.has_next()
	
	if texture_container.get_texture():
		var texture_size = texture_container.get_texture().get_size()
		%GridContainer.set_ratio(texture_size.x / texture_size.y)
		%Grid.material.set_shader_parameter("rect_size", %Grid.size)


func _input(event: InputEvent) -> void:
	if (event is InputEventMouseMotion and abs(event.velocity) >= Vector2.ONE) or event is InputEventScreenTouch:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		var tween: Tween = create_tween()
		tween.set_parallel()
		for element in invisible_element:
			tween.tween_property(element, "modulate:a", 1.0, 0.25)
	
	if event is InputEventMouse or event is InputEventScreenTouch:
		mouse_move_timer.start()
	
	if Input.is_action_just_pressed("ui_right"):
		next_image()
	elif Input.is_action_just_pressed("ui_left"):
		previous_image()
	
	if is_drawing:
		return
	
	var swipe_dir: String = ""
	
	if event is InputEventScreenTouch:
		if event.pressed:
			_swipe_start = event.position
		else:
			var swipe_end = event.position
			var delta = swipe_end - _swipe_start
			
			if delta.length() >= _swipe_min_distance:
				swipe_dir = _get_swipe_direction(delta)
	
	if swipe_dir == "right":
		previous_image()
	elif swipe_dir == "left":
		next_image()


func current_image() -> void:
	change_image(queue.current)
	_update()


func next_image() -> void:
	if not queue.has_next():
		print("Reach the end")
		return
	
	change_image(queue.next)
	_update()


func previous_image() -> void:
	if not queue.has_previous():
		print("At the start")
		return
	
	change_image(queue.previous)
	_update()


func change_image(image_callable: Callable) -> void:
	texture_container.texture = null
	spiner_container.show()
	var data: Dictionary = image_callable.call(_image_loaded_callback)
	_on_image_loaded(data)


func _image_loaded_callback(data: Dictionary) -> void:
	_on_image_loaded.call_deferred(data)


func _on_image_loaded(data: Dictionary) -> void:
	spiner_container.hide()
	match data.get("status"):
		"fail":
			printerr(data.get("message"))
		"loading":
			spiner_container.show()
		"success":
			texture_container.texture = data.get("texture")
		_:
			printerr("Unknown status %s" % data.get("status"))


func _update() -> void:
	var file_name: String = queue.get_current_location().get_file()
	file_location_button.text = file_name
	
	if not no_timer:
		timer.wait_time = _context.get_image_duration(queue._queue_idx)
		timer.start()
	
	var canvas_idx: String = _get_canvas_index(queue._queue_idx)
	paint_canvas.create_canvas(canvas_idx)
	paint_canvas.switch_canvas(canvas_idx)
	
	%CountLabel.text = "%s/%s" % [queue._queue_idx+1, queue.size()]


func _on_timer_timeout() -> void:
	if not no_timer:
		next_image()


func _on_button_next_pressed() -> void:
	next_image()


func _on_button_previous_pressed() -> void:
	previous_image()


func _get_canvas_index(image_index: int) -> String:
	return "im_%s" % image_index


func _on_mouse_movetimer_timeout() -> void:
	if is_drawing:
		return
	
	Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)
	var tween: Tween = create_tween()
	tween.set_parallel()
	for element in invisible_element:
		tween.tween_property(element, "modulate:a", 0, 1.0)


func _on_grid_button_pressed() -> void:
	%GridContainer.visible = %GridButton.button_pressed
	
	
func _get_swipe_direction(delta: Vector2) -> String:
	if abs(delta.x) > abs(delta.y):
		return "right" if delta.x > 0 else "left"
	else:
		return "down" if delta.y > 0 else "up"


func _on_paint_button_toggled(toggled_on: bool) -> void:
	is_drawing = toggled_on
	paint_canvas.can_draw = toggled_on
	paint_toolbar.visible = toggled_on
	navigation_container.visible = !toggled_on
	if OS.get_name() in ["Android", "iOS"]:
		navigation_container.hide()
	if visible:
		mouse_move_timer.start()


func _on_file_location_button_pressed() -> void:
	var image_path: String = queue.get_current_location()
	OS.shell_show_in_file_manager(image_path, false)


func _on_brush_size_slider_value_changed(value: float) -> void:
	paint_canvas.brush_size = value


func get_current_image() -> Image:
	var texture: Texture2D = texture_container.texture
	if not texture:
		return
	var im: Image = texture.get_image()
	if im.is_empty():
		return
	return im

func _on_rotate_left_button_pressed() -> void:
	var im: Image = get_current_image()
	if im:
		im.rotate_90(COUNTERCLOCKWISE)
		queue._cache[queue._queue_idx]["texture"] = ImageTexture.create_from_image(im)
	current_image()


func _on_rotate_right_button_pressed() -> void:
	var im: Image = get_current_image()
	if im:
		im.rotate_90(CLOCKWISE)
		queue._cache[queue._queue_idx]["texture"] = ImageTexture.create_from_image(im)
	current_image()


func _on_pause_button_toggled(toggled_on: bool) -> void:
	if no_timer:
		return
	
	timer.paused = toggled_on
	if toggled_on:
		pause_button.icon = icon_pause
	else:
		pause_button.icon = icon_play


func _on_exit_button_pressed() -> void:
	done.emit(_context)


func _on_greyscale_button_toggled(toggled_on: bool) -> void:
	%Greyscale.visible = toggled_on

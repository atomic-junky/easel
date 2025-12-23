class_name Session extends Control

signal done(session_context: SessionResource)

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
@onready var spiner := %Spiner
@onready var message_label := %MessageLabel
@onready var count_label := %CountLabel
@onready var paint_button := %PaintButton

var is_drawing: bool = false
var is_pause: bool = false
var _context: SessionResource
var queue: SessionQueue
var no_timer: bool = false
var _swipe_start := Vector2.ZERO
var _swipe_min_distance := 50


func _ready() -> void:
	if OS.get_name() in ["Android", "iOS"]:
		DisplayServer.screen_set_orientation(DisplayServer.SCREEN_SENSOR)


func load_args(args: SessionResource) -> void:
	setup()
	if not is_node_ready():
		await ready
	
	start_session(args)


func get_args() -> SessionResource:
	return _context


func setup() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	set_process(false)
	set_process_input(false)
	
	queue = SessionQueue.new()
	add_child(queue)
	_context = null


func start_session(context: SessionResource) -> void:
	_on_paint_button_toggled(false)
	paint_canvas.clear_canvas()
	navigation_container.show()
	if OS.get_name() in ["Android", "iOS"]:
		navigation_container.hide()
		file_location_button.hide()
	
	if context.session_type == SessionResource.Type.RELAXED:
		no_timer = true
		pause_button.hide()
	
	# Génère la séquence finale avec les chemins d'images avant de charger la queue
	var session_type_script: Script = null
	match context.session_type:
		SessionResource.Type.STANDARD:
			session_type_script = load("res://scenes/menu/standard.gd")
		SessionResource.Type.CLASS:
			session_type_script = load("res://scenes/menu/class.gd")
		SessionResource.Type.RELAXED:
			session_type_script = load("res://scenes/menu/relaxed.gd")
		SessionResource.Type.CUSTOM:
			session_type_script = load("res://scenes/menu/custom.gd")
		_:
			session_type_script = null
	if session_type_script:
		var generator = session_type_script.new()
		var generated_sequence = generator.generate_sequence(context)
		context.sequence = generated_sequence
	_context = context
	queue.load_queue(context)
	# If the generated queue is empty, avoid starting the session flow
	if queue.size() == 0:
		message_label.show()
		message_label.text = "No images available for this session."
		spiner.hide()
		# Keep navigation hidden and don't start timers/process
		navigation_container.hide()
		set_process(false)
		set_process_input(false)
		return
	mouse_move_timer.start()
	
	set_process(true)
	set_process_input(true)
	current_image()


func _process(_delta: float) -> void:
	pause_button.set_time(timer.time_left, timer.wait_time)
	
	%ButtonPrevious.disabled = not queue.has_previous()
	%ButtonNext.disabled = not queue.has_next()
	
	if texture_container.get_texture():
		var texture_size = texture_container.get_texture().get_size()
		%GridContainer.set_ratio(texture_size.x / texture_size.y)
		%Grid.material.set_shader_parameter("rect_size", %Grid.size)


func _input(event: InputEvent) -> void:
	var is_mouse_motion = event is InputEventMouseMotion and abs(event.velocity) >= Vector2.ONE
	var is_screen_touch = event is InputEventScreenTouch
	if is_mouse_motion or is_screen_touch:
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
	change_image(queue.current.bind(_on_item_loaded))


func next_image() -> void:
	if not queue.has_next():
		print("Reach the end")
		return
	
	change_image(queue.next.bind(_on_item_loaded))


func previous_image() -> void:
	if not queue.has_previous():
		return
	
	change_image(queue.previous.bind(_on_item_loaded))


func change_image(image_callable: Callable) -> void:
	texture_container.texture = null
	spiner.show()
	var item: Dictionary = image_callable.call()
	_on_item_loaded(item)





func _on_item_loaded(item: Dictionary) -> void:
	spiner.hide()
	message_label.hide()
	is_pause = false
	var status = item.get("status", "unknown")
	var item_duration = item.get("duration", 60)
	match status:
		"break":
			message_label.show()
			message_label.text = "Break"
			is_pause = true
			texture_container.texture = null
		"fail":
			message_label.show()
			message_label.text = item.get("message", "Image not found")
			texture_container.texture = null
		"loading":
			spiner.show()
		"success":
			if item.has("texture") and item["texture"]:
				texture_container.texture = item["texture"]
			else:
				message_label.show()
				message_label.text = "Image not found"
				texture_container.texture = null
		_:
			message_label.show()
			message_label.text = "Unknown status: %s" % status
			texture_container.texture = null
	_update(item_duration)


func _update(item_duration := 60) -> void:
	if queue.size() == 0:
		file_location_button.text = ""
		count_label.text = "0/0"
		return

	var file_name: String = queue.get_current_filename()
	if file_name.length() > 48:
		file_name = file_name.left(45)
		file_name += "..."
	elif file_name.length() <= 0:
		file_name = queue.get_current_location()
		if file_name.length() > 48:
			file_name = file_name.right(45)
			file_name = "..." + file_name
	file_location_button.text = file_name

	# Timer logic
	if not no_timer and not is_pause:
		if item_duration > 0:
			timer.wait_time = item_duration
			timer.paused = false
			timer.start()
		# No need for else after return above
	else:
		timer.stop()
		timer.paused = true

	var canvas_idx: String = _get_canvas_index(queue.get_current_index())
	paint_canvas.create_canvas(canvas_idx)
	paint_canvas.switch_canvas(canvas_idx)

	count_label.text = "%s/%s" % [queue.get_current_index()+1, queue.size()]


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
	count_label.visible = !toggled_on
	file_location_button.visible = !toggled_on
	if OS.get_name() in ["Android", "iOS"]:
		navigation_container.hide()
	if visible:
		mouse_move_timer.start()


func _on_file_location_button_pressed() -> void:
	var image_path: String = queue.get_current_location()
	OS.shell_show_in_file_manager(image_path, false)


func _on_brush_size_slider_value_changed(value: float) -> void:
	paint_canvas.brush_size = int(value)


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
		queue.set_cached_texture(queue.get_current_index(), ImageTexture.create_from_image(im))
	current_image()


func _on_rotate_right_button_pressed() -> void:
	var im: Image = get_current_image()
	if im:
		im.rotate_90(CLOCKWISE)
		queue.set_cached_texture(queue.get_current_index(), ImageTexture.create_from_image(im))
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

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
@onready var flb_container: HBoxContainer = %FLBContainer

var is_drawing: bool = false
var is_pause: bool = false
var _context: SessionResource
var queue: SessionQueue
var no_timer: bool = false
var _swipe_start := Vector2.ZERO
var _swipe_min_distance := 50
var _last_mouse_position: Vector2 = Vector2.ZERO


func _ready() -> void:
	if OS.get_name() in ["Android", "iOS"]:
		DisplayServer.screen_set_orientation(DisplayServer.SCREEN_SENSOR)
	
	resized.connect(_on_resized)


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
	queue.item_loaded.connect(_on_queue_item_loaded)
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
	if queue.size() == 0:
		message_label.show()
		message_label.text = "No images available for this session."
		spiner.hide()
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
		var texture_size: Vector2 = texture_container.get_texture().get_size()
		%GridContainer.set_ratio(texture_size.x / texture_size.y)
		%Grid.material.set_shader_parameter("rect_size", %Grid.size)
		paint_canvas.set_image_rect(_displayed_image_rect(texture_size))


## Where the picture actually sits once letterboxed, in PaintCanvas coordinates.
## The drawing follows this rect, so resizing or rotating keeps strokes on the
## part of the image they were drawn on.
func _displayed_image_rect(texture_size: Vector2) -> Rect2:
	var area: Vector2 = texture_container.size
	if texture_size.x <= 0.0 or texture_size.y <= 0.0:
		return Rect2(Vector2.ZERO, area)

	var factor: float = minf(area.x / texture_size.x, area.y / texture_size.y)
	var drawn: Vector2 = texture_size * factor
	var offset: Vector2 = texture_container.global_position - paint_canvas.global_position
	return Rect2(offset + (area - drawn) * 0.5, drawn)


func _input(event: InputEvent) -> void:
	var is_mouse_motion = event is InputEventMouseMotion and abs(event.velocity) >= Vector2.ONE
	var is_screen_touch = event is InputEventScreenTouch
	if is_mouse_motion or is_screen_touch:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		var tween: Tween = create_tween()
		tween.set_parallel()
		for element in invisible_element:
			tween.tween_property(element, "modulate:a", 1.0, 0.25)
	
	if (event is InputEventMouse or event is InputEventScreenTouch) \
	and event.position != _last_mouse_position:
		_last_mouse_position = event.position
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
	_goto(queue.current())


func next_image() -> void:
	if not queue.has_next():
		return
	_goto(queue.next())


func previous_image() -> void:
	if not queue.has_previous():
		return
	_goto(queue.previous())


func _goto(entry: Dictionary) -> void:
	_present(entry)
	_update(entry)


## A load that finishes after we moved on must not steal the screen; one that
## finishes on the image still being shown must update it.
func _on_queue_item_loaded(index: int, entry: Dictionary) -> void:
	if index != queue.get_current_index():
		return

	_present(entry)
	# The wait was dead time, so the clock only starts once the image is up.
	_update(entry)



## Puts an entry on screen. Never touches the timer, so it is safe to call again
## when a slow image finally arrives.
func _present(entry: Dictionary) -> void:
	spiner.hide()
	message_label.hide()
	is_pause = false

	var status: String = str(entry.get("status", "unknown"))
	match status:
		"break":
			message_label.show()
			message_label.text = "Break"
			is_pause = true
			texture_container.texture = null
		"loading":
			spiner.show()
			texture_container.texture = null
		"success":
			var texture: Texture2D = entry.get("texture")
			if texture:
				texture_container.texture = texture
			else:
				message_label.show()
				message_label.text = "Image not found"
				texture_container.texture = null
		"fail":
			message_label.show()
			message_label.text = str(entry.get("message", "Image not found"))
			texture_container.texture = null
		_:
			message_label.show()
			message_label.text = "Unknown status: %s" % status
			texture_container.texture = null


func _update(entry: Dictionary = {}) -> void:
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

	# The clock must not run while the image is still decoding, otherwise a slow
	# load eats the drawing time.
	var still_loading: bool = entry.get("status", "") == "loading"
	var item_duration: int = int(entry.get("duration", 60))

	if not no_timer and not is_pause and not still_loading and item_duration > 0:
		timer.wait_time = item_duration
		timer.paused = false
		timer.start()
	else:
		timer.stop()
		timer.paused = true

	var canvas_idx: String = _get_canvas_index(queue.get_current_index())
	paint_canvas.create_canvas(canvas_idx)
	paint_canvas.switch_canvas(canvas_idx)

	count_label.text = "%s/%s" % [queue.get_current_index()+1, queue.size()]


func _on_timer_timeout() -> void:
	if no_timer:
		return

	if queue.has_next():
		next_image()
	else:
		_finish_session()


## The run is over: offer the ways out instead of freezing on the last image.
func _finish_session() -> void:
	timer.stop()
	timer.paused = true

	var spare: int = _unused_images().size()
	var summary: String = "%d image%s drawn." % [queue.size(), "" if queue.size() == 1 else "s"]
	if spare > 0:
		summary += "\n%d more available in your packs." % spare

	%EndSummary.text = summary
	%MoreImagesButton.visible = spare > 0
	%EndModal.open()


## Pack images that this session did not use.
func _unused_images() -> Array:
	if _context == null:
		return []

	var used: Dictionary = {}
	for item: Dictionary in _context.sequence:
		used[str(item.get("path", ""))] = true

	var spare: Array = []
	for image: Dictionary in _context.get_images_path_raw():
		if not used.has(str(image.get("path", ""))):
			spare.append(image)
	return spare


func _on_end_menu_pressed() -> void:
	%EndModal.close()
	done.emit(_context)


func _on_end_replay_pressed() -> void:
	%EndModal.close()
	paint_canvas.clear_canvas()
	queue.load_queue(_context.sequence)
	current_image()


## Extends the run with images the session had left over, keeping the pacing of
## the last item.
func _on_end_more_images_pressed() -> void:
	var spare: Array = _unused_images()
	if spare.is_empty():
		return

	var duration: int = queue.get_item_duration(queue.size() - 1)
	if duration <= 0:
		duration = maxi(1, _context.duration)

	var resume_at: int = _context.sequence.size()
	for image: Dictionary in spare:
		_context.sequence.append({
			"type": "pose",
			"duration": duration,
			"path": image.get("path", ""),
			"name": image.get("name", "Unknown"),
		})

	%EndModal.close()
	queue.load_queue(_context.sequence)
	for _step in resume_at:
		queue.next()
	current_image()


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
		return null
	var im: Image = texture.get_image()
	if not im or im.is_empty():
		return null
	return im


func _on_rotate_left_button_pressed() -> void:
	_rotate_current(COUNTERCLOCKWISE)


func _on_rotate_right_button_pressed() -> void:
	_rotate_current(CLOCKWISE)


## Rotating only swaps the picture: the timer and the drawing keep running.
func _rotate_current(direction: int) -> void:
	var im: Image = get_current_image()
	if not im:
		return

	im.rotate_90(direction)
	queue.set_cached_texture(queue.get_current_index(), ImageTexture.create_from_image(im))
	_present(queue.current())


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

func _on_resized() -> void:
	pass

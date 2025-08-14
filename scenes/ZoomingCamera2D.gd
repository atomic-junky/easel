class_name ZoomingCamera2D
extends Camera2D

# Lower cap for the `_zoom_level`.
@export var min_zoom := 0.5
# Upper cap for the `_zoom_level`.
@export var max_zoom := 3.0
# Controls how much we increase or decrease the `_zoom_level` on every turn of the scroll wheel.
@export var zoom_factor := 0.1
# Duration of the zoom's tween animation.
@export var zoom_duration := 0.2

# The camera's target zoom level.
var _zoom_level := 1.0: set = _set_zoom_level

# We store a reference to the scene's tween node.
	
func _set_zoom_level(value: float) -> void:
	# We limit the value between `min_zoom` and `max_zoom`
	_zoom_level = clamp(value, min_zoom, max_zoom)
	# Then, we ask the tween node to animate the camera's `zoom` property from its current value
	# to the target zoom level.
	var tween: Tween = create_tween()
	tween.tween_property(
		self,
		"zoom",
		Vector2(_zoom_level, _zoom_level),
		zoom_duration
	).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
	
func _input(event):
	if event.is_action_pressed("zoom_in"):
		# Inside a given class, we need to either write `self._zoom_level = ...` or explicitly
		# call the setter function to use it.
		_set_zoom_level(_zoom_level - zoom_factor)
		print("zin")
	if event.is_action_pressed("zoom_out"):
		_set_zoom_level(_zoom_level + zoom_factor)
		print("zout")


func _on_App_resized():
	return
	position = get_window().size/2
	

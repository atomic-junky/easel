class_name SafeMarginContainer extends MarginContainer

@onready var viewport: Viewport = get_viewport()

var _default_top: int = get_theme_constant("margin_top")
var _default_left: int = get_theme_constant("margin_left")
var _default_bottom: int = get_theme_constant("margin_bottom")
var _default_right: int = get_theme_constant("margin_right")


func _ready() -> void:
	viewport.size_changed.connect(_set_safe_area_margins)
	_set_safe_area_margins()


func set_margin_all(margin: int) -> void:
	var _default_top: int = margin
	var _default_left: int = margin
	var _default_bottom: int = margin
	var _default_right: int = margin
	
	_set_safe_area_margins()


func _set_safe_area_margins() -> void:
	if not (OS.has_feature("ios") or OS.has_feature("android")):
		return
	
	var rect = DisplayServer.get_display_safe_area() # Safe area in screen/physical pixels
	var screen_size = DisplayServer.screen_get_size() # Entire screen area in screen/physical pixels

	# Calculate how many "logical pixels" correspond to a single physical pixel
	var aspect_x = size.x / screen_size.x
	var aspect_y = size.y / screen_size.y

	# Convert the safe-area rect to logical pixel margins
	var margin_left = max(rect.position.x * aspect_x, _default_left)
	var margin_top = max(rect.position.y * aspect_y, _default_top)
	var margin_right = max((screen_size.x - (rect.position.x + rect.size.x)) * aspect_x, _default_right)
	var margin_bottom = max((screen_size.y - (rect.position.y + rect.size.y)) * aspect_y, _default_bottom)

	add_theme_constant_override("margin_left", margin_left)
	add_theme_constant_override("margin_top", margin_top)
	add_theme_constant_override("margin_right", margin_right)
	add_theme_constant_override("margin_bottom", margin_bottom)

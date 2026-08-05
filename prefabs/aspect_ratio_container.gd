extends AspectRatioContainer

@onready var margin_container: MarginContainer = %MainSafeMargin


func _ready() -> void:
	item_rect_changed.connect(_on_size_changed)
	_update_ui()


func _update_ui() -> void:
	ratio = _get_ratio()
	
	var _is_mobile: bool = OS.get_name() in ["iOS", "Android"]
	var _compact_ui: bool = size.x <= 550 or _is_mobile
	
	#if _compact_ui:
		#margin_container.add_theme_constant_override("margin_bottom", 0)
		#margin_container.add_theme_constant_override("margin_left", 0)
		#margin_container.add_theme_constant_override("margin_right", 0)
		#margin_container.add_theme_constant_override("margin_top", 0)
		#
		#return
	
	# Default
	
	margin_container.add_theme_constant_override("margin_bottom", 10)
	margin_container.add_theme_constant_override("margin_left", 10)
	margin_container.add_theme_constant_override("margin_right", 10)
	margin_container.add_theme_constant_override("margin_top", 10)


func _get_ratio() -> float:
	var vp_size: Vector2 = get_viewport_rect().size
	var x: float = vp_size.x
	var y: float = vp_size.y
	
	return x/y


func _on_size_changed() -> void:
	_update_ui()

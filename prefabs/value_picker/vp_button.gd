class_name VPButton extends Button

var value: Variant

func _ready() -> void:
	toggle_mode = true
	custom_minimum_size.x = 78
	theme_type_variation = "ButtonMenuToggle"
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND


func deselect() -> void:
	button_pressed = false

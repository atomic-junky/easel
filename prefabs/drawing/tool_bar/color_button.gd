class_name ColorButton extends Button


@onready var color_icons: Array = [
	preload("res://assets/icons/colors/color_0.svg"),
	preload("res://assets/icons/colors/color_1.svg"),
	preload("res://assets/icons/colors/color_2.svg"),
	preload("res://assets/icons/colors/color_3.svg"),
	preload("res://assets/icons/colors/color_4.svg"),
	preload("res://assets/icons/colors/color_5.svg")
]

@export var color_idx: int = 0


func _init(idx: int) -> void:
	color_idx = idx


func _ready() -> void:
	icon = color_icons[color_idx]
	theme_type_variation = "ButtonColor"
	toggle_mode = true


func get_brush_color() -> Color:
	var icon_image: Image = icon.get_image()
	return icon_image.get_pixel(icon_image.get_width()/2, icon_image.get_height()/2)

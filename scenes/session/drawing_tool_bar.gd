class_name DrawingToolBar extends Control


@onready var paint_canvas := %PaintCanvas
@onready var color_button_container := %HBoxColors


func _ready() -> void:
	for color_idx in range(5):
		var color_button: ColorButton = ColorButton.new(color_idx)
		color_button.pressed.connect(_on_color_button_pressed.bind(color_button))
		color_button_container.add_child(color_button)
		
		if color_idx == 0:
			color_button.pressed.emit()


func _on_color_button_pressed(button: ColorButton) -> void:
	paint_canvas.brush_color = button.get_brush_color()
	button.button_pressed = true
	
	for color_button: ColorButton in color_button_container.get_children():
		if color_button == button:
			continue
		
		color_button.button_pressed = false

class_name ImageOrder extends Control

signal value_changed

var shuffle: bool = false
var reverse: bool = false

@onready var _order_container: Control = %OrderContainer
@onready var _shuffle_button: Button = get_node("ShuffleContainer/ShuffleButton")
@onready var _reverse_button: Button = get_node("OrderContainer/OrderButton")


func _on_shuffle_button_toggled(toggled_on: bool) -> void:
	_order_container.visible = !toggled_on
	shuffle = toggled_on
	value_changed.emit()


func _on_order_button_toggled(toggled_on: bool) -> void:
	reverse = toggled_on
	value_changed.emit()


func set_shuffle_state(toggled_on: bool) -> void:
	if not is_node_ready():
		await ready
	_shuffle_button.button_pressed = toggled_on
	_shuffle_button.skip_animation()
	_order_container.visible = not toggled_on
	shuffle = toggled_on


func set_reverse_state(toggled_on: bool) -> void:
	if not is_node_ready():
		await ready
	_reverse_button.button_pressed = toggled_on
	_reverse_button.skip_animation()
	reverse = toggled_on

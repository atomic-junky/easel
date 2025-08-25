class_name ImageOrder extends Control

signal value_changed

@onready var _order_container: Control = %OrderContainer

var shuffle: bool = false
var reverse: bool = false


func _ready() -> void:
	pass


func _on_shuffle_button_toggled(toggled_on: bool) -> void:
	_order_container.visible = !toggled_on
	shuffle = toggled_on
	value_changed.emit()


func _on_order_button_toggled(toggled_on: bool) -> void:
	reverse = toggled_on
	value_changed.emit()

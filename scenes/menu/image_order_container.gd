class_name ImageOrder extends Control

signal value_changed

var shuffle: bool = false
var reverse: bool = false

@onready var _reverse_container: HBoxContainer = %ReverseContainer
@onready var _shuffle_button: Button = %ShuffleButton
@onready var _reverse_button: Button = %ReverseButton

func _ready() -> void:
	_on_shuffle_button_toggled(_reverse_button.button_pressed)
	_on_order_button_toggled(_shuffle_button.button_pressed)

func _on_shuffle_button_toggled(toggled_on: bool) -> void:
	_reverse_button.disabled = toggled_on
	_reverse_container.modulate.a = 0.5 if toggled_on else 1.0
	shuffle = toggled_on
	value_changed.emit()


func _on_order_button_toggled(toggled_on: bool) -> void:
	reverse = toggled_on
	value_changed.emit()


func set_shuffle_state(toggled_on: bool) -> void:
	if not is_node_ready():
		await ready
	_shuffle_button.button_pressed = toggled_on
	_reverse_container.modulate.a = 0.5 if toggled_on else 1.0
	_reverse_button.disabled = toggled_on
	shuffle = toggled_on


func set_reverse_state(toggled_on: bool) -> void:
	if not is_node_ready():
		await ready
	_reverse_button.button_pressed = toggled_on
	reverse = toggled_on

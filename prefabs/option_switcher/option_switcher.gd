@tool
class_name OptionSwitcher extends VBoxContainer

signal value_changed(value: int)

@export var use_custom_button: bool = false :
	set(value):
		use_custom_button = value
		_update()
@export var title: String = "" :
	set(value):
		title = value
		_update()
@export var custom_suffix: String = ""
@export var custom_step: int = 1
@export_subgroup("First option", "first_")
@export var first_label: String = ""
@export var first_value: int = 1
@export_subgroup("Second option", "second_")
@export var second_label: String = ""
@export var second_value: int = 2
@export_subgroup("Third option", "third_")
@export var third_label: String = ""
@export var third_value: int = 3
@export_subgroup("Fourth option", "fourth_")
@export var fourth_label: String = ""
@export var fourth_value: int = 4

@onready var buttons_container: Control = %ButtonsContainer
@onready var custom_value_container: Control = %CustomValueContainer
@onready var custom_value: SpinBox = %CustomValue
@onready var custom_value_container_bg: Control = %CustomValueContainerBG
@onready var label: Label = %Label
@onready var custom_button: Button = %CustomButton
@onready var _buttons: Array = [%FirstButton, %SecondButton, %ThirdButton, %FourthButton]

var _button_labels: Array :
	get():
		return [first_label, second_label, third_label, fourth_label]
var _button_values: Array :
	get():
		return [first_value, second_value, third_value, fourth_value]
var _last_toggled_button: Button

var value: int : get = _get_value


func _ready() -> void:
	_last_toggled_button = _buttons[0]
	custom_value.value = _get_value()
	custom_value.get_line_edit().text_changed.connect(_on_custom_value_value_changed)
	custom_value.get_line_edit().theme_type_variation = "LineEditSwitcher"
	_update()


func _update() -> void:
	if Engine.is_editor_hint():
		_update_editor()
		return
	
	if not is_node_ready():
		return
	
	for idx: int in _buttons.size():
		var button: Button = _buttons[idx]
		var label: String = _button_labels[idx]

		button.text = label
		button.pressed.connect(_update_buttons.bind(button))
	
	custom_button.pressed.connect(_update_buttons.bind(custom_button))
	custom_button.visible = use_custom_button
	custom_value.suffix = custom_suffix
	label.text = title
	
	_update_button_size.call_deferred()


func _get_value() -> int:
	if custom_button.button_pressed:
		return custom_value.value
	
	for idx: int in _buttons.size():
		var button: Button = _buttons[idx]
		if button.button_pressed:
			return _button_values[idx]
	
	return -1

func _update_button_size() -> void:
	var max_button_size: float = 0.0
	for button: Button in _buttons:
		max_button_size = max(max_button_size, button.size.x)
	
	for button: Button in _buttons:
		button.custom_minimum_size.x = max_button_size


func _update_editor() -> void:
	%CustomButton.visible = use_custom_button
	%Label.text = title


func _update_buttons(toggled_button: Button) -> void:
	for button: Button in _buttons:
		button.button_pressed = button == toggled_button
		if button == toggled_button:
			_last_toggled_button = button
	
	if custom_button == toggled_button:
		if not custom_button.button_pressed and _last_toggled_button:
			_last_toggled_button.button_pressed = true
	else:
		custom_value.value = _get_value()
		
	custom_value_container.visible = custom_button.button_pressed
	custom_value_container_bg.visible = custom_button.button_pressed
	
	value_changed.emit(value)


func _on_add_button_pressed() -> void:
	custom_value.value += custom_step


func _on_minus_button_pressed() -> void:
	custom_value.value -= custom_step


func _on_custom_value_value_changed(_value: float) -> void:
	value_changed.emit(value)

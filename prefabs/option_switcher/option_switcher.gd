@tool
class_name OptionSwitcher extends VBoxContainer

signal value_changed(value: int)

## If true, uses data-driven options array.
## If false, falls back to legacy hardcoded properties.
@export var use_dynamic_options: bool = false :
	set(value):
		use_dynamic_options = value
		_update()

## Array of OptionData for data-driven configuration (only used when use_dynamic_options = true)
@export var options: Array[OptionData] = [] :
	set(value):
		options = value
		_update()

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

## Legacy hardcoded option properties (deprecated).
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
@export_subgroup("Fifth option", "fifth_")
@export var fifth_label: String = ""
@export var fifth_value: int = 5
@export_subgroup("Sixth option", "sixth_")
@export var sixth_label: String = ""
@export var sixth_value: int = 6

@onready var buttons_container: Control = %ButtonsContainer
@onready var custom_value_container: Control = %CustomValueContainer
@onready var custom_value: SpinBox = %CustomValue
@onready var custom_value_container_bg: Control = %CustomValueContainerBG
@onready var label: Label = %Label
@onready var custom_button: Button = %CustomButton
@onready var _buttons: Array = [
	%FirstButton, %SecondButton, %ThirdButton,
	%FourthButton, %FifthButton, %SixthButton
]

## Computed labels for logical buttons
var _button_labels: Array :
	get():
		if use_dynamic_options and not options.is_empty():
			return options.map(func(opt: OptionData): return opt.label)
		return [first_label, second_label, third_label, fourth_label, fifth_label, sixth_label]

## Computed values for logical buttons
var _button_values: Array :
	get():
		if use_dynamic_options and not options.is_empty():
			return options.map(func(opt: OptionData): return opt.value)
		return [first_value, second_value, third_value, fourth_value, fifth_value, sixth_value]

## Enabled flags for logical buttons
var _buttons_enabled: Array :
	get():
		if use_dynamic_options and not options.is_empty():
			var enabled_array: Array = options.map(func(opt: OptionData): return opt.enabled)
			while enabled_array.size() < 6:
				enabled_array.append(false)
			return enabled_array
			
		var enabled: Array = []
		for blabel: String in _button_labels:
			enabled.append(not blabel.is_empty())
		return enabled
		

var _last_toggled_button: Button
var value: int : get = _get_value
var _programmatic_change: bool = false # Flag to prevent animation during programmatic changes


func _ready() -> void:
	_last_toggled_button = _buttons[0]
	custom_value.value = _get_value()
	custom_value.get_line_edit().text_changed.connect(_on_custom_value_value_changed)
	custom_value.get_line_edit().theme_type_variation = "LineEditValue"
	custom_button.pressed.connect(_update_buttons.bind(custom_button))
	_update()
	value_changed.emit(value)


func _update() -> void:
	if Engine.is_editor_hint():
		_update_editor()
		return
	
	if not is_node_ready():
		return

	# Determine how many logical options we have (dynamic or legacy set)
	var logical_count: int = _button_labels.size()
	var enabled_count: int = _buttons_enabled.size()

	# Safety: Cap iteration to number of physical buttons
	var physical_count: int = _buttons.size()
	var loop_count: int = min(logical_count, physical_count)

	for i in loop_count:
		var button: Button = _buttons[i]
		var button_label: String = _button_labels[i] if i < logical_count else ""
		var enabled: bool = _buttons_enabled[i] if i < enabled_count else false

		button.text = button_label
		button.visible = enabled and button_label != ""
		if not button.pressed.is_connected(_update_buttons):
			button.pressed.connect(_update_buttons.bind(button))

	# Hide any extra physical buttons if we have fewer logical options
	for j in range(loop_count, physical_count):
		var extra_button: Button = _buttons[j]
		extra_button.visible = false
	
	custom_button.visible = use_custom_button
	custom_value.suffix = custom_suffix
	label.visible = not title.is_empty()
	label.text = title
	
	_update_button_size()


func _get_value() -> int:
	if custom_button.button_pressed:
		return roundi(custom_value.value)

	var logical_count: int = _button_values.size()
	var physical_count: int = _buttons.size()
	var loop_count: int = min(logical_count, physical_count)

	for i in loop_count:
		var button: Button = _buttons[i]
		if button.button_pressed:
			return _button_values[i]
	
	return -1


func set_value(idx: int) -> void:
	if idx < 0:
		_update_buttons(custom_button, false)
	else:
		_update_buttons(_buttons[idx], false)
	


## Gives every visible option the width of the widest one, as in the design.
func _update_button_size() -> void:
	if not is_inside_tree():
		return

	for button: Button in _buttons:
		button.custom_minimum_size.x = 0.0

	await get_tree().process_frame

	var widest: float = 0.0
	for button: Button in _buttons:
		if button.visible:
			widest = maxf(widest, button.size.x)

	for button: Button in _buttons:
		button.custom_minimum_size.x = widest


func _update_editor() -> void:
	%CustomButton.visible = use_custom_button
	%Label.text = title


func _update_buttons(toggled_button: Button, animate: bool = true) -> void:
	# If called programmatically (not from user click), disable animation
	var should_animate := animate and not _programmatic_change
	
	# Only process visible logical buttons
	for button: Button in _buttons:
		if not button.visible:
			continue
		var should_be_pressed := button == toggled_button
		if should_animate:
			button.button_pressed = should_be_pressed
		else:
			button.set_pressed_no_signal(should_be_pressed)
		if button == toggled_button:
			_last_toggled_button = button
	
	if custom_button == toggled_button:
		if not custom_button.button_pressed and _last_toggled_button:
			if should_animate:
				_last_toggled_button.button_pressed = true
			else:
				_last_toggled_button.set_pressed_no_signal(true)
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


## Programmatically set options
func set_options_array(new_options: Array[OptionData]) -> void:
	use_dynamic_options = true
	options = new_options
	if is_node_ready():
		_update()


## Helper to create options from simple arrays
func set_options_from_arrays(labels: Array, values: Array, enabled: Array = []) -> void:
	var new_options: Array[OptionData] = []
	for i in labels.size():
		var opt := OptionData.new()
		opt.label = labels[i]
		opt.value = values[i] if i < values.size() else i + 1
		opt.enabled = enabled[i] if i < enabled.size() else true
		new_options.append(opt)
	set_options_array(new_options)

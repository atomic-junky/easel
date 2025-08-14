class_name ValuePicker extends VBoxContainer

signal value_changed

@export var label: String = "Time per image" : set = _set_label
@export var values: Array[VPValue] = [] : set = _set_values

@onready var display_label: Label = %Label
@onready var value_container: HFlowContainer = %Values
@onready var custom_container: Control = %CustomContainer
@onready var custom_value: SpinBox = %SpinBox

var custom_button: VPButton


func _set_label(value: Variant) -> void:
	label = value
	
	if is_node_ready():
		display_label.text = label


func _set_values(value: Variant) -> void:
	values = value
	reload_values()


func _ready() -> void:
	display_label.text = label
	reload_values()
	
	var line_edit = custom_value.get_line_edit()
	line_edit.context_menu_enabled = false


func reload_values() -> void:
	if not is_node_ready():
		return
	
	for child in value_container.get_children():
		child.queue_free()
	
	for v in values:
		if not v:
			return
		
		var new_vpbutton: VPButton = VPButton.new()
		new_vpbutton.text = v.label
		new_vpbutton.value = v.value
		new_vpbutton.pressed.connect(_on_vpbutton_pressed.bind(new_vpbutton))
		
		value_container.add_child(new_vpbutton)
		
	var custom_vpbutton: VPButton = VPButton.new()
	custom_vpbutton.text = "custom"
	custom_vpbutton.value = get_value()
	custom_vpbutton.pressed.connect(_on_vpbutton_pressed.bind(custom_vpbutton))
	custom_vpbutton.pressed.connect(_on_custom_button_pressed.bind(custom_vpbutton))
	
	value_container.add_child(custom_vpbutton)
	custom_button = custom_vpbutton
	custom_value.value = get_value()


func get_value() -> int:
	for child: VPButton in value_container.get_children():
		if not child is VPButton:
			continue
		
		if child.button_pressed:
			return child.value
	
	return -1


func _on_vpbutton_pressed(button: VPButton) -> void:
	custom_container.hide()
	for child in value_container.get_children():
		if not child is VPButton or child == button:
			continue
		
		child.deselect()
	
	value_changed.emit()


func _on_custom_button_pressed(button: VPButton) -> void:
	if button.button_pressed:
		custom_container.show()


func _on_spin_box_value_changed(value: float) -> void:
	custom_button.value = value
	value_changed.emit()

## Builder for creating session configuration forms dynamically
## Reduces hardcoding and makes forms extensible
class_name SessionFormBuilder extends RefCounted

var _fields: Array[FormFieldConfig] = []
var _container: Control = null


func _init(container: Control = null) -> void:
	_container = container


## Add a field to the form
func add_field(field: FormFieldConfig) -> SessionFormBuilder:
	_fields.append(field)
	return self


## Add multiple fields
func add_fields(fields: Array[FormFieldConfig]) -> SessionFormBuilder:
	_fields.append_array(fields)
	return self


## Build the form in the specified container
func build() -> Dictionary:
	if not _container:
		push_error("No container set for SessionFormBuilder")
		return {}
	
	var field_nodes: Dictionary = {}
	
	for field in _fields:
		if not field.enabled:
			continue
		
		var field_node: Control = _create_field_node(field)
		if field_node:
			_container.add_child(field_node)
			field_nodes[field.field_name] = field_node
	
	return field_nodes


## Create a node for a field based on its type
func _create_field_node(field: FormFieldConfig) -> Control:
	match field.field_type:
		FormFieldConfig.FieldType.INTEGER:
			return _create_integer_field(field)
		FormFieldConfig.FieldType.TOGGLE:
			return _create_toggle_field(field)
		FormFieldConfig.FieldType.IMAGE_ORDER:
			return _create_image_order_field(field)
		_:
			push_warning("Unsupported field type: %s" % field.field_type)
			return null


## Create an integer field (OptionSwitcher)
func _create_integer_field(field: FormFieldConfig) -> Control:
	var switcher := OptionSwitcher.new()
	switcher.title = field.label
	
	if field.properties.get("use_options", false):
		var options: Array = field.properties.get("options", [])
		if not options.is_empty():
			switcher.set_options_array(options)
	else:
		# Create range-based options if needed
		var min_val: int = field.properties.get("min", 0)
		var max_val: int = field.properties.get("max", 100)
		var step: int = field.properties.get("step", 1)
		# This would need more implementation for range-based switchers
	
	return switcher


## Create a toggle field (CheckBox)
func _create_toggle_field(field: FormFieldConfig) -> Control:
	var checkbox := CheckBox.new()
	checkbox.text = field.label
	checkbox.button_pressed = field.default_value if field.default_value != null else false
	return checkbox


## Create an image order field
func _create_image_order_field(_field: FormFieldConfig) -> Control:
	# This would load the ImageOrder scene
	# For now, return null as it needs the actual scene
	push_warning("Image order field creation not yet implemented in builder")
	return null


## Helper to extract values from built form
static func extract_values(field_nodes: Dictionary) -> Dictionary:
	var values: Dictionary = {}
	
	for field_name in field_nodes.keys():
		var node: Control = field_nodes[field_name]
		
		if node is OptionSwitcher:
			values[field_name] = node.value
		elif node is CheckBox:
			values[field_name] = node.button_pressed
		elif node is ImageOrder:
			values[field_name] = {
				"shuffle": node.shuffle,
				"reverse": node.reverse
			}
	
	return values

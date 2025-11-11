## Base class for form field definitions
## Allows creating configurable form fields without hardcoding them
class_name FormFieldConfig extends Resource

enum FieldType {
	INTEGER,      ## Integer input (spinbox/switcher)
	TIME,         ## Time duration input
	TOGGLE,       ## Boolean checkbox
	IMAGE_ORDER,  ## Image ordering controls (shuffle/reverse)
	CUSTOM        ## Custom field type
}

@export var field_type: FieldType = FieldType.INTEGER
@export var field_name: String = ""
@export var label: String = ""
@export var default_value: Variant = null
@export var enabled: bool = true
@export var required: bool = false

## Custom properties for specific field types
@export var properties: Dictionary = {}


func _init(
	p_type: FieldType = FieldType.INTEGER,
	p_name: String = "",
	p_label: String = "",
	p_default: Variant = null
) -> void:
	field_type = p_type
	field_name = p_name
	label = p_label if not p_label.is_empty() else p_name
	default_value = p_default


## Create an integer field with options
static func create_integer_options(
	name: String,
	label_text: String,
	options: Array[OptionData],
	default_val: int = 0
) -> FormFieldConfig:
	var field := FormFieldConfig.new(FieldType.INTEGER, name, label_text, default_val)
	field.properties["options"] = options
	field.properties["use_options"] = true
	return field


## Create a simple integer field
static func create_integer(
	name: String,
	label_text: String,
	min_val: int = 0,
	max_val: int = 100,
	default_val: int = 0
) -> FormFieldConfig:
	var field := FormFieldConfig.new(FieldType.INTEGER, name, label_text, default_val)
	field.properties["min"] = min_val
	field.properties["max"] = max_val
	return field


## Create a toggle field
static func create_toggle(
	name: String,
	label_text: String,
	default_val: bool = false
) -> FormFieldConfig:
	var field := FormFieldConfig.new(FieldType.TOGGLE, name, label_text, default_val)
	return field


## Create an image order field
static func create_image_order(name: String = "image_order") -> FormFieldConfig:
	var field := FormFieldConfig.new(FieldType.IMAGE_ORDER, name, "Image Order")
	field.properties["shuffle"] = true
	field.properties["reverse"] = false
	return field

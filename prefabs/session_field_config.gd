## Configuration for a UI field in a SessionType panel
class_name SessionFieldConfig extends Resource

enum FieldType {
	IMAGE_ORDER,      ## Shuffle/reverse controls
	OPTION_SWITCHER,  ## Multiple choice buttons
	CUSTOM            ## Custom control (subclass handles)
}

@export var field_type: FieldType = FieldType.OPTION_SWITCHER
@export var property_name: String = ""  ## Property to bind to (in _state)
@export var title: String = ""          ## Display title for the field

## For OptionSwitcher fields
@export var options: Array[int] = []    ## Available values
@export var default_value: int = 0      ## Default selection
@export var suffix: String = ""         ## Unit suffix (e.g., " s", " imgs")

## For ImageOrder fields
@export var shuffle_property: String = "shuffle"
@export var reverse_property: String = "reverse"

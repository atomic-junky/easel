# Lightweight field config for a session section.
# Keep this minimal: label, type, binding key, options/default.
class_name SectionFieldConfig extends Resource

enum Kind { INT_SWITCHER, TOGGLE, IMAGE_ORDER, TEMPLATE_SELECT }

@export var key: String = ""            # Identifier used to apply into SessionResource
@export var kind: Kind = Kind.INT_SWITCHER
@export var label: String = ""          # Display label
@export var default_value: Variant       # Starting value
@export var options: Array = []          # For switchers (array of {label:String, value:int})
@export var required: bool = false       # Simple validation flag

func get_value_or_default(current: Variant) -> Variant:
	return current if current != null else default_value

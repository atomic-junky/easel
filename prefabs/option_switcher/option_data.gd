## Represents a single option in an OptionSwitcher
## This allows for data-driven configuration of options
class_name OptionData extends Resource

@export var label: String = ""
@export var value: int = 0
@export var enabled: bool = true


func _init(p_label: String = "", p_value: int = 0, p_enabled: bool = true) -> void:
	label = p_label
	value = p_value
	enabled = p_enabled

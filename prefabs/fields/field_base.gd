@abstract
class_name SessionField extends VBoxContainer

var field_name: String
var title: String
var suffix: String
var default_value: Variant
var extra: Dictionary = {}

func _init(data: Dictionary) -> void:
	field_name = data.get("name", "")
	title = data.get("title", "")
	suffix = data.get("suffix", "")
	default_value = data.get("default", null)
	extra = data.get("extra", {})
	_build()

@abstract func _build() -> void
@abstract func get_value_dict() -> Dictionary

@abstract
class_name SessionField extends VBoxContainer

## Base of every settings field. Configuration arrives as a typed [FieldSpec]
## rather than a Dictionary, so renderers read named properties.

var spec: FieldSpec

## Shorthands for the two things every renderer needs.
var field_name: String
var title: String


func _init(field_spec: FieldSpec) -> void:
	spec = field_spec
	field_name = spec.name
	title = spec.title
	_build()


@abstract func _build() -> void
@abstract func get_value_dict() -> Dictionary

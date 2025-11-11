@abstract
class_name SessionField extends VBoxContainer

signal _field_update
signal value_changed(new_value: Dictionary, old_value: Dictionary)

var _value: Dictionary
	
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

func _ready() -> void:
	_value = get_value_dict()
	_field_update.connect(_on_field_update)

func _on_field_update() -> void:
	var old_value: Dictionary = _value
	var new_value: Dictionary = get_value_dict()
	
	_value = new_value
	value_changed.emit(new_value, old_value)

@abstract func _build() -> void
@abstract func get_value_dict() -> Dictionary

class_name SessionFieldInt
extends SessionField

var _spin: SpinBox

func _build() -> void:
	var hb := HBoxContainer.new()
	var lbl := Label.new()
	lbl.text = title
	_spin = SpinBox.new()
	_spin.min_value = extra.get("min", 0)
	_spin.max_value = extra.get("max", 9999)
	_spin.step = extra.get("step", 1)
	_spin.suffix = suffix
	_spin.value = int(default_value) if default_value != null else 0
	hb.add_child(lbl)
	hb.add_child(_spin)
	add_child(hb)
	_spin.value_changed.connect(func(_v: float):
		_field_update.emit()
	)

func get_value_dict() -> Dictionary:
	return {field_name: int(_spin.value)}

func set_from_context(context: Object) -> void:
	if context and context.has_property(field_name):
		_spin.value = int(context.get(field_name))

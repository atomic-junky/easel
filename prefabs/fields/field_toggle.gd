class_name SessionFieldToggle extends SessionField

var _cb: CheckBox

func _build() -> void:
	var hb := HBoxContainer.new()
	var lbl := Label.new()
	lbl.text = title
	_cb = CheckBox.new()
	_cb.button_pressed = bool(default_value) if default_value != null else false
	hb.add_child(lbl)
	hb.add_child(_cb)
	add_child(hb)
	_cb.toggled.connect(func(_pressed: bool):
		_field_update.emit()
	)

func get_value_dict() -> Dictionary:
	return {field_name: _cb.button_pressed}

func set_from_context(context: Object) -> void:
	if context and context.has_property(field_name):
		_cb.button_pressed = bool(context.get(field_name))

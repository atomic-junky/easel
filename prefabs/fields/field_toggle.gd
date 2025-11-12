class_name SessionFieldToggle extends SessionField

var _cb: CheckBox

func _has_prop(object: Object, property_name: String) -> bool:
	for p in object.get_property_list():
		if p.get("name") == property_name:
			return true
	return false

func _build() -> void:
	var hb := HBoxContainer.new()
	var lbl := Label.new()
	lbl.text = title
	_cb = CheckBox.new()
	_cb.button_pressed = bool(default_value) if default_value != null else false
	hb.add_child(lbl)
	hb.add_child(_cb)
	add_child(hb)

func get_value_dict() -> Dictionary:
	return {field_name: _cb.button_pressed}

func set_from_context(context: Object) -> void:
	if not context:
		return
	
	# If property exists in context, use it
	if _has_prop(context, field_name):
		var value = context.get(field_name)
		if value != null:
			_cb.button_pressed = bool(value)
			return
	
	# Otherwise, apply default value
	_cb.button_pressed = bool(default_value) if default_value != null else false

class_name SessionFieldInt
extends SessionField

var _spin: SpinBox

func _has_prop(object: Object, property_name: String) -> bool:
	for p in object.get_property_list():
		if p.get("name") == property_name:
			return true
	return false

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

func get_value_dict() -> Dictionary:
	return {field_name: int(_spin.value)}

func set_from_context(context: Object) -> void:
	if not context:
		return
	
	# If property exists in context, use it
	if _has_prop(context, field_name):
		var value = context.get(field_name)
		if value != null:
			_spin.value = int(value)
			return
	
	# Otherwise, apply default value
	_spin.value = int(default_value) if default_value != null else 0

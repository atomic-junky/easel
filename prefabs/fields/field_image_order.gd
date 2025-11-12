class_name SessionFieldImageOrder extends SessionField

var _image_order: ImageOrder

func _has_prop(object: Object, property_name: String) -> bool:
	for p in object.get_property_list():
		if p.get("name") == property_name:
			return true
	return false

func _build() -> void:
	_image_order = preload("res://scenes/menu/image_order_container.tscn").instantiate()
	add_child(_image_order)

func _ready() -> void:
	# Don't set defaults here - let them come from context or define_field default
	pass

func get_value_dict() -> Dictionary:
	var shuffle_key: String = extra.get("shuffle_property", "shuffle")
	var reverse_key: String = extra.get("reverse_property", "reverse")
	return {shuffle_key: _image_order.shuffle, reverse_key: _image_order.reverse}

func set_from_context(context: Object) -> void:
	if not context:
		return
	
	var shuffle_key: String = extra.get("shuffle_property", "shuffle")
	var reverse_key: String = extra.get("reverse_property", "reverse")
	
	# Apply shuffle value from context or use context default (true)
	if _has_prop(context, shuffle_key):
		var shuffle_val = context.get(shuffle_key)
		_image_order.set_shuffle_state(bool(shuffle_val) if shuffle_val != null else true)
	else:
		_image_order.set_shuffle_state(true)  # SessionContext default
	
	# Apply reverse value from context or use context default (false)
	if _has_prop(context, reverse_key):
		var reverse_val = context.get(reverse_key)
		_image_order.set_reverse_state(bool(reverse_val) if reverse_val != null else false)
	else:
		_image_order.set_reverse_state(false)  # SessionContext default

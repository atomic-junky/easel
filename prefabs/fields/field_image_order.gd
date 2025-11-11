class_name SessionFieldImageOrder extends SessionField

var _image_order: ImageOrder

func _build() -> void:
	_image_order = preload("res://scenes/menu/image_order_container.tscn").instantiate()
	add_child(_image_order)

func _ready() -> void:
	super._ready()
	_image_order.shuffle = false
	_image_order.reverse = false
	_image_order.value_changed.connect(func():
		_field_update.emit()
	)

func get_value_dict() -> Dictionary:
	var shuffle_key: String = extra.get("shuffle_property", "shuffle")
	var reverse_key: String = extra.get("reverse_property", "reverse")
	return {shuffle_key: _image_order.shuffle, reverse_key: _image_order.reverse}

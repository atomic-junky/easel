class_name SessionFieldImageOrder extends SessionField

## Shuffle / reverse pair. It always writes SessionResource.shuffle and
## .reverse, so those names are no longer passed in by every caller.

const SHUFFLE_KEY: String = "shuffle"
const REVERSE_KEY: String = "reverse"

var _image_order: ImageOrder


func _build() -> void:
	_image_order = preload("res://scenes/menu/image_order_container.tscn").instantiate()
	add_child(_image_order)


func get_value_dict() -> Dictionary:
	return {SHUFFLE_KEY: _image_order.shuffle, REVERSE_KEY: _image_order.reverse}


func set_from_context(context: Object) -> void:
	if not context:
		return

	_image_order.set_shuffle_state(bool(context.get(SHUFFLE_KEY)))
	_image_order.set_reverse_state(bool(context.get(REVERSE_KEY)))

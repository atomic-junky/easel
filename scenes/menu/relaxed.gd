extends SessionType

@onready var image_order_container: ImageOrder = $ImageOrderContainer

var shuffle: bool = false
var reverse: bool = false


func apply_context(context: SessionContext) -> void:
	context.number_of_images = context.get_image_count()
	context.time_per_image = -1
	context.shuffle = shuffle
	context.reverse = reverse
	context.session_type = SessionContext.Type.STANDARD


func is_valid() -> bool:
	return true


func _on_image_order_value_changed() -> void:
	shuffle = image_order_container.shuffle
	reverse = image_order_container.reverse

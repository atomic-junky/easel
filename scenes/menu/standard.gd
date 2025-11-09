extends SessionType

@onready var image_order_container: ImageOrder = $ImageOrderContainer

var number_of_images: int = 0
var time_per_images: int = 0
var shuffle: bool = false
var reverse: bool = false


func apply_context(context: SessionContext) -> void:
	context.number_of_images = number_of_images
	context.time_per_image = time_per_images
	context.shuffle = shuffle
	context.reverse = reverse
	context.session_type = SessionContext.Type.STANDARD


func is_valid() -> bool:
	return true


func _on_noi_switcher_value_changed(value: int) -> void:
	number_of_images = value


func _on_tpi_switcher_value_changed(value: int) -> void:
	time_per_images = value


func _on_image_order_value_changed() -> void:
	shuffle = image_order_container.shuffle
	reverse = image_order_container.reverse

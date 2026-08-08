extends SessionType

func setup() -> void:
	define_choice("number_of_images", [10, 20, 30, 50, 100], "Images") \
		.with_all() \
		.with_default(-1) \
		.with_range(1, 999)

	define_choice("duration", [30, 60, 300, 600, 1800], "Time per image") \
		.with_labels(PackedStringArray(["30 s", "1 min", "5 min", "10 min", "30 min"])) \
		.with_unit("s") \
		.with_range(5, 3600, 5) \
		.with_default(300)
	
	define_image_order()

func get_context_type() -> SessionResource.Type:
	return SessionResource.Type.STANDARD

func get_mode_name() -> String:
	return "Standard"

func generate_sequence(context: SessionResource) -> Array:
	var all_images: Array = context.get_images_path_raw()
	var image_count: int = all_images.size()
	if context.shuffle:
		all_images.shuffle()
	elif context.reverse:
		all_images.reverse()

	var result: Array = []
	var actual_count: int = context.number_of_images
	if actual_count < 0:
		actual_count = image_count
	if actual_count > image_count:
		actual_count = image_count

	for _i in range(actual_count):
		if all_images.is_empty():
			break
		var next_image = all_images.pop_front()
		result.append({
			"type": "pose",
			"duration": context.duration if context.duration > 0 else 60,
			"path": next_image.get("path", ""),
			"name": next_image.get("name", "Unknown"),
		})
	return result

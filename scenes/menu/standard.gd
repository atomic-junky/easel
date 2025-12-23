extends SessionType

func setup() -> void:
	define_field(
		"number_of_images", "switcher", [5, 10, 20, 50],
		"Images", ""
	)
	define_field(
		"time_per_image", "switcher", [30, 60, 120, 300],
		"Time per images", " s"
	)
	define_field(
		"image_order", "image_order", [], "", "", {
			"shuffle_property": "shuffle",
			"reverse_property": "reverse"
		}
	)

func get_context_type() -> SessionResource.Type:
	return SessionResource.Type.STANDARD

func get_mode_name() -> String:
	return "Standard"

# Génère la séquence pour le mode Standard
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

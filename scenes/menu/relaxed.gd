extends SessionType

func setup() -> void:
	define_image_order()

func get_context_type() -> SessionResource.Type:
	return SessionResource.Type.RELAXED

func get_mode_name() -> String:
	return "Relaxed"

# Génère la séquence pour le mode Relaxed
func generate_sequence(context: SessionResource) -> Array:
	var all_images: Array = context.get_images_path_raw()
	if context.shuffle:
		all_images.shuffle()
	elif context.reverse:
		all_images.reverse()
	var result: Array = []
	for next_image in all_images:
		result.append({
			"type": "pose",
			"duration": -1,
			"path": next_image.get("path", ""),
			"name": next_image.get("name", "Unknown"),
		})
	return result

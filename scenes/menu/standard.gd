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

func get_context_type() -> SessionContext.Type:
	return SessionContext.Type.STANDARD

func get_mode_name() -> String:
	return "Standard"

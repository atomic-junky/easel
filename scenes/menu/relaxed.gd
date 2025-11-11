extends SessionType

func setup() -> void:
	define_field(
		"image_order", "image_order", null, [], "", "", {
			"shuffle_property": "shuffle",
			"reverse_property": "reverse"
		}
	)

func get_context_type() -> SessionContext.Type:
	return SessionContext.Type.RELAXED

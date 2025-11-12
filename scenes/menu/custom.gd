extends SessionType

var _custom_sequence: Array[Dictionary] = []

func setup() -> void:
	# Default sequence with one pose
	var default_sequence: Array[Dictionary] = [
		{"type": "pose", "duration": 60, "amount": 1}
	]
	
	define_field(
		"class_data", "custom_sequence", default_sequence, [],
		"Session sequence", ""
	)
	define_field(
		"image_order", "image_order", null, [], "", "", {
			"shuffle_property": "shuffle",
			"reverse_property": "reverse"
		}
	)
	
	# Connect to fields_built signal to setup change listeners
	fields_built.connect(_on_fields_built)

func _on_fields_built() -> void:
	# Get initial sequence
	var values := collect_field_values()
	if values.has("class_data"):
		_custom_sequence = values["class_data"].duplicate(true)
	
	# Connect to sequence field changes
	for field in get_field_nodes():
		if field.field_name == "class_data":
			field.value_changed.connect(func(new_value: Dictionary, _old_value: Dictionary):
				if new_value.has("class_data"):
					_custom_sequence = new_value["class_data"].duplicate(true)
			)
			break

func apply_context(context: SessionContext) -> void:
	# Calculate total number of images from sequence
	var number_of_images: int = 0
	for item in _custom_sequence:
		if item.get("type") == "pose":
			number_of_images += item.get("amount", 1)
	
	context.session_type = SessionContext.Type.CUSTOM
	context.class_data = _custom_sequence.duplicate(true)
	context.number_of_images = number_of_images
	
	# Apply image_order toggles generically
	apply_fields_to_context(context)

func is_valid() -> bool:
	# Check if there's at least one pose
	for item in _custom_sequence:
		if item.get("type") == "pose" and item.get("amount", 0) > 0:
			return true
	return false

func get_context_type() -> SessionContext.Type:
	return SessionContext.Type.CUSTOM

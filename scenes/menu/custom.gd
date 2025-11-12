extends SessionType

var _custom_sequence: Array[Dictionary] = []

func setup() -> void:
	# Default sequence with one pose
	var default_sequence: Array[Dictionary] = [
		{"type": "pose", "duration": 60, "amount": 1}
	]
	
	define_field(
		"class_data", "custom_sequence", [],
		"Session sequence", ""
	)
	define_field(
		"image_order", "image_order", [], "", "", {
			"shuffle_property": "shuffle",
			"reverse_property": "reverse"
		}
	)
	
	# Set initial sequence
	_custom_sequence = default_sequence.duplicate(true)

func load_from_context(context: SessionContext) -> void:
	super.load_from_context(context)
	# After loading fields, get the sequence
	var values := collect_field_values()
	if values.has("class_data"):
		var data = values["class_data"]
		if typeof(data) == TYPE_ARRAY:
			_custom_sequence.clear()
			for item in data:
				if typeof(item) == TYPE_DICTIONARY:
					_custom_sequence.append(item.duplicate(true))

func save_to_context(context: SessionContext) -> void:
	# Get current sequence before saving
	var values := collect_field_values()
	if values.has("class_data"):
		var data = values["class_data"]
		if typeof(data) == TYPE_ARRAY:
			_custom_sequence.clear()
			for item in data:
				if typeof(item) == TYPE_DICTIONARY:
					_custom_sequence.append(item.duplicate(true))
	
	# Apply all fields generically
	apply_fields_to_context(context)
	
	# Set custom-specific data
	var number_of_images: int = 0
	for item in _custom_sequence:
		if item.get("type") == "pose":
			number_of_images += item.get("amount", 1)
	
	context.class_data = _custom_sequence.duplicate(true)
	context.number_of_images = number_of_images

func is_valid() -> bool:
	# Check if there's at least one pose
	for item in _custom_sequence:
		if item.get("type") == "pose" and item.get("amount", 0) > 0:
			return true
	return false

func get_context_type() -> SessionContext.Type:
	return SessionContext.Type.CUSTOM

func get_mode_name() -> String:
	return "Custom"

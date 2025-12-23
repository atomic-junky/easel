extends SessionType

var _custom_sequence: Array[Dictionary] = []

func setup() -> void:
	# Default sequence with one pose
	_custom_sequence = [
		{"type": "pose", "duration": 60, "amount": 1}
	]
	
	define_field(
		"sequence", "custom_sequence", [],
		"Session sequence", ""
	)
	define_field(
		"image_order", "image_order", [], "", "", {
			"shuffle_property": "shuffle",
			"reverse_property": "reverse"
		}
	)

func _update_sequence_from_values() -> void:
	"""Extract sequence from field values"""
	var values := collect_field_values()
	if values.has("sequence"):
		var data = values["sequence"]
		if typeof(data) == TYPE_ARRAY:
			_custom_sequence.clear()
			for item in data:
				if typeof(item) == TYPE_DICTIONARY:
					_custom_sequence.append(item.duplicate(true))

func load_from_context(context: SessionResource) -> void:
	super.load_from_context(context)
	_update_sequence_from_values()

func save_to_context(context: SessionResource) -> void:
	_update_sequence_from_values()
	apply_fields_to_context(context)
	
	# Set custom-specific data
	var number_of_images: int = 0
	for item in _custom_sequence:
		if item.get("type") == "pose":
			number_of_images += item.get("amount", 1)
	
	context.sequence = _custom_sequence.duplicate(true)
	context.number_of_images = number_of_images

func is_valid() -> bool:
	# Check if there's at least one pose
	for item in _custom_sequence:
		if item.get("type") == "pose" and item.get("amount", 0) > 0:
			return true
	return false

func get_context_type() -> SessionResource.Type:
	return SessionResource.Type.CUSTOM

func get_mode_name() -> String:
	return "Custom"

# Génère la séquence pour le mode Custom
func generate_sequence(context: SessionResource) -> Array:
	var all_images: Array = context.get_images_path_raw()
	if context.shuffle:
		all_images.shuffle()
	elif context.reverse:
		all_images.reverse()
	var result: Array = []
	var seq: Array = context.sequence
	for i in range(seq.size()):
		var item: Dictionary = seq[i]
		var pose_type: String = String(item.get("type", "pose"))
		var pose_duration: int = int(item.get("duration", 60))
		var pose_data: Dictionary = {"type": pose_type, "duration": pose_duration}
		if pose_type == "pose":
			if all_images.is_empty():
				break
			var next_image = all_images.pop_front()
			pose_data["path"] = next_image.get("path", "")
			pose_data["name"] = next_image.get("name", "Unknown")
		result.append(pose_data)
	return result

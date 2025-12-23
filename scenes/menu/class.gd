extends SessionType

var _class_session: Array = []

func setup() -> void:
	ClassSessionTemplateRegistry.initialize()
	var durations := ClassSessionTemplateRegistry.get_available_durations()
	define_field(
		"session_duration", "switcher", durations,
		"Session duration", " min"
	)
	define_field(
		"image_order", "image_order", [], "", "", {
			"shuffle_property": "shuffle",
			"reverse_property": "reverse"
		}
	)
	# Set initial template based on default duration
	if durations.size() > 0:
		_apply_template_for_duration(durations[0])

func _apply_template_for_duration(duration: int) -> void:
	var template := ClassSessionTemplateRegistry.get_template(duration)
	if template:
		_class_session = template.session_sequence.duplicate(true)

func load_from_context(context: SessionResource) -> void:
	# Apply the template based on saved duration before loading UI
	if context and context.duration > 0:
		_apply_template_for_duration(context.duration)
	super.load_from_context(context)

func save_to_context(context: SessionResource) -> void:
	# Read current duration from field and apply template
	var values := collect_field_values()
	if values.has("duration"):
		var dur := int(values["duration"])
		context.duration = dur
		_apply_template_for_duration(dur)
	
	# Now apply all fields generically
	apply_fields_to_context(context)
	
	# Set class-specific data
	var number_of_images: int = 0
	for pose in _class_session:
		number_of_images += pose.get("amount", 1)
	context.sequence = _class_session
	context.number_of_images = number_of_images

func is_valid() -> bool:
	return not _class_session.is_empty()

func get_context_type() -> SessionResource.Type:
	return SessionResource.Type.CLASS

func get_mode_name() -> String:
	return "Class Mode"

# Génère la séquence pour le mode Class
func generate_sequence(context: SessionResource) -> Array:
	var all_images: Array = context.get_images_path_raw()
	if context.shuffle:
		all_images.shuffle()
	elif context.reverse:
		all_images.reverse()
	var result: Array = []
	var seq: Array = context.sequence
	if seq.size() == 0 and all_images.size() > 0:
		for next_image in all_images:
			result.append({
				"type": "pose",
				"duration": 60,
				"path": next_image.get("path", ""),
				"name": next_image.get("name", "Unknown"),
			})
		return result
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

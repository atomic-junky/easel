extends SessionType

var _class_session: Array = []

func setup() -> void:
	ClassSessionTemplateRegistry.initialize()
	var durations := ClassSessionTemplateRegistry.get_available_durations()
	define_field(
		"duration", "choice", durations,
		"Session duration", " min", {
			"custom_min": 5, "custom_max": 240, "custom_step": 5
		}
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

func is_valid() -> bool:
	return not _class_session.is_empty()

func get_context_type() -> SessionResource.Type:
	return SessionResource.Type.CLASS

func get_mode_name() -> String:
	return "Class Mode"

func generate_sequence(context: SessionResource) -> Array:
	var all_images: Array = context.get_images_path_raw()
	if context.shuffle:
		all_images.shuffle()
	elif context.reverse:
		all_images.reverse()
	# The template is picked from the chosen duration, not read back out of
	# context.sequence — that field is where the result goes, not the source.
	_apply_template_for_duration(int(context.duration))

	var result: Array = []
	for item: Dictionary in _class_session:
		var pose_type: String = str(item.get("type", "pose"))
		var pose_duration: int = int(item.get("duration", 60))

		# Templates group identical poses with "amount" instead of repeating them.
		for _repeat in maxi(1, int(item.get("amount", 1))):
			if pose_type != "pose":
				result.append({"type": pose_type, "duration": pose_duration})
				continue

			if all_images.is_empty():
				return result

			var next_image: Dictionary = all_images.pop_front()
			result.append({
				"type": "pose",
				"duration": pose_duration,
				"path": next_image.get("path", ""),
				"name": next_image.get("name", "Unknown"),
			})
	return result

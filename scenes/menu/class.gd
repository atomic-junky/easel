extends SessionType

var _class_session: Array = []

func setup() -> void:
	ClassSessionTemplateRegistry.initialize()
	var durations := ClassSessionTemplateRegistry.get_available_durations()
	define_field(
		"duration", "switcher", durations,
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
	context.class_data = _class_session
	context.number_of_images = number_of_images

func is_valid() -> bool:
	return not _class_session.is_empty()

func get_context_type() -> SessionResource.Type:
	return SessionResource.Type.CLASS

func get_mode_name() -> String:
	return "Class Mode"

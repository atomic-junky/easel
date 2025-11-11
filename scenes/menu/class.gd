extends SessionType

var _class_session: Array = []

func setup() -> void:
	ClassSessionTemplateRegistry.initialize()
	var durations := ClassSessionTemplateRegistry.get_available_durations()
	define_field(
		"duration", "switcher", durations[0] if durations.size() > 0 else 30, durations,
		"Session duration", " min"
	)
	define_field(
		"image_order", "image_order", null, [], "", "", {
			"shuffle_property": "shuffle",
			"reverse_property": "reverse"
		}
	)
	# After fields are built, select initial template and hookup change listener
	fields_built.connect(_on_fields_built)

func _on_fields_built() -> void:
	# Set initial template based on default duration
	var values := collect_field_values()
	if values.has("duration"):
		_apply_template_for_duration(int(values["duration"]))
	# Connect to duration field changes
	for field in get_field_nodes():
		if field is SessionFieldSwitcher and field.field_name == "duration":
			field.value_changed.connect(func(new_value: Dictionary, _old_value: Dictionary):
				if new_value.has("duration"):
					_apply_template_for_duration(int(new_value["duration"]))
			)
			break

func _apply_template_for_duration(duration: int) -> void:
	var template := ClassSessionTemplateRegistry.get_template(duration)
	if template:
		_class_session = template.session_sequence.duplicate(true)

func apply_context(context: SessionContext) -> void:
	var number_of_images: int = 0
	for pose in _class_session:
		number_of_images += pose.get("amount", 1)
	context.session_type = SessionContext.Type.CLASS
	context.class_data = _class_session
	context.number_of_images = number_of_images
	# Apply image_order toggles generically
	apply_fields_to_context(context)

func is_valid() -> bool:
	return not _class_session.is_empty()

func get_context_type() -> SessionContext.Type:
	return SessionContext.Type.CLASS

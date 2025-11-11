# Dynamic session type descriptors (simple, no heavy config)
# Provides build and apply functions for each type.
class_name DynamicSessionTypes

const TYPE_STANDARD := 1
const TYPE_CLASS := 2
const TYPE_RELAXED := 3
const TYPE_CUSTOM := 4

static var _image_order_scene := preload("res://scenes/menu/image_order_container.tscn")

static func get_session_type_names() -> Array:
	return ["Standard", "Class", "Relaxed", "Custom"]

static func build(panel: Control, session_type: int, _context: SessionContext) -> Dictionary:
	# Clear previous content
	for child in panel.get_children():
		child.queue_free()
	var state := {
		"type": session_type,
		"image_order": null,
		"number_switcher": null,
		"time_switcher": null,
		"duration_switcher": null
	}
	match session_type:
		TYPE_STANDARD:
			state.image_order = _add_image_order(panel)
			state.number_switcher = _add_switcher(panel, "Images", [5,10,20,50], 10, " imgs")
			state.time_switcher = _add_switcher(panel, "Time", [30,60,120,300], 60, " s")
			panel.add_child(_spacer())
			panel.add_child(_label("Standard session"))
		TYPE_RELAXED:
			state.image_order = _add_image_order(panel)
			panel.add_child(_label("Relaxed session (full pack, no timer)"))
		TYPE_CLASS:
			state.image_order = _add_image_order(panel)
			var durations := ClassSessionTemplateRegistry.get_available_durations()
			state.duration_switcher = _add_switcher(panel, "Duration", durations, durations[0], " min")
			panel.add_child(_label("Class session (preset templates)"))
		TYPE_CUSTOM:
			state.image_order = _add_image_order(panel)
			panel.add_child(_label("Custom session (WIP)"))
	return state

static func apply(context: SessionContext, state: Dictionary) -> void:
	var t = state.type
	var order = state.image_order
	if order:
		context.shuffle = order.shuffle
		context.reverse = order.reverse
	match t:
		TYPE_STANDARD:
			context.session_type = SessionContext.Type.STANDARD
			if state.number_switcher:
				context.number_of_images = state.number_switcher.value
			if state.time_switcher:
				context.time_per_image = state.time_switcher.value
			if context.number_of_images <= 0:
				context.number_of_images = context.get_image_count()
		TYPE_RELAXED:
			context.session_type = SessionContext.Type.RELAXED
			context.number_of_images = context.get_image_count()
			context.time_per_image = -1
		TYPE_CLASS:
			context.session_type = SessionContext.Type.CLASS
			var duration: int = state.duration_switcher.value if state.duration_switcher else 30
			var template: ClassSessionTemplate = ClassSessionTemplateRegistry.get_template(duration)
			if template:
				context.class_data = template.session_sequence
				context.number_of_images = _count_template_images(template)
				context.time_per_image = -1
		TYPE_CUSTOM:
			context.session_type = SessionContext.Type.CUSTOM
			# Placeholder - custom pose list not implemented yet
			context.number_of_images = context.get_image_count()
			context.time_per_image = -1

static func is_valid(state: Dictionary, context: SessionContext) -> bool:
	match state.type:
		TYPE_STANDARD:
			return context.get_image_count(false) > 0
		TYPE_RELAXED:
			return context.get_image_count(false) > 0
		TYPE_CLASS:
			return not context.class_data.is_empty() and context.get_image_count(false) > 0
		TYPE_CUSTOM:
			return false
	return false

# Helpers
static func _add_image_order(panel: Control) -> ImageOrder:
	var inst: ImageOrder = _image_order_scene.instantiate()
	panel.add_child(inst)
	return inst

static func _add_switcher(
	panel: Control,
	title: String,
	values: Array,
	default_value: int,
	_suffix: String
) -> OptionSwitcher:
	var sw := OptionSwitcher.new()
	sw.title = title
	sw.use_dynamic_options = true
	var opts: Array[OptionData] = []
	for v in values:
		var od := OptionData.new()
		od.label = str(v)
		od.value = v
		opts.append(od)
	sw.set_options_array(opts)
	# Set default by pressing matching button
	for b in sw.get_children():
		if b is Button and b.text == str(default_value):
			b.button_pressed = true
	panel.add_child(sw)
	return sw

static func _spacer() -> Control:
	var c := Control.new()
	c.custom_minimum_size.y = 8
	return c

static func _label(text: String) -> Label:
	var l := Label.new()
	l.text = text
	return l

static func _count_template_images(template: ClassSessionTemplate) -> int:
	var total := 0
	for item in template.session_sequence:
		if item.get("type") == "pose":
			total += item.get("amount", 1)
	return total

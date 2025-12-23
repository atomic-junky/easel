"""
DynamicSessionTypes

This file provides a small, clear API for building and applying session-type UIs and
for validating the resulting state. It is intentionally thin — the SessionResource is
the source of truth for session configuration (see `prefabs/session_resource.gd`).

API (static functions):
- build(panel: Control, session_type, context) -> Dictionary
	Build UI controls for the requested session_type and attach them to `panel`.
	`session_type` can be either a `SessionResource.Type` value or the legacy
	1..4 integer values (legacy callers).

- apply(context: SessionResource, state: Dictionary) -> void
	Apply the state produced by `build` to the given `SessionResource`.

- is_valid(state: Dictionary, context: SessionResource) -> bool
	Quick validation of the built state before saving/starting a session.

Helpers are provided to create simple controls used by the UI.
"""

class_name DynamicSessionTypes

static var _image_order_scene := preload("res://scenes/menu/image_order_container.tscn")


static func _normalize_type(t) -> int:
	# Accept either SessionResource.Type enum values or legacy 1..4 constants
	if typeof(t) == TYPE_INT:
		# Legacy mapping: 1->STANDARD(0), 2->CLASS(1), 3->RELAXED(2), 4->CUSTOM(3)
		if t >= 1 and t <= 4:
			return t - 1
		return t
	return t


static func get_session_type_names() -> Array:
	return ["Standard", "Class", "Relaxed", "Custom"]


static func build(panel: Control, session_type, context: SessionResource) -> Dictionary:
	# Normalize and clear previous UI
	var stype := _normalize_type(session_type)
	for child in panel.get_children():
		child.queue_free()

	var state := {
		"type": stype,
		"image_order": null,
		"number_switcher": null,
		"time_switcher": null,
		"duration_switcher": null,
		"sequence_editor": null
	}

	# Common image ordering control
	state.image_order = _add_image_order(panel)

	match stype:
		SessionResource.Type.STANDARD:
			var default_number := int(context.settings.get("last_number_of_images", 10))
			var default_time := int(context.settings.get("last_time_per_image", 60))
			state.number_switcher = _add_switcher(panel, "Images", [5, 10, 20, 50], default_number, " imgs")
			state.time_switcher = _add_switcher(panel, "Time", [30, 60, 120, 300], default_time, " s")
			panel.add_child(_label("Standard session"))

		SessionResource.Type.RELAXED:
			panel.add_child(_label("Relaxed session — full pack, no timer"))

		SessionResource.Type.CLASS:
			var durations := ClassSessionTemplateRegistry.get_available_durations()
			if durations.size() == 0:
				panel.add_child(_label("No class templates available"))
			else:
				var last_dur := int(context.settings.get("last_class_duration", durations[0]))
				state.duration_switcher = _add_switcher(panel, "Duration (min)", durations, last_dur, " min")
			panel.add_child(_label("Class session — pick a template"))

		SessionResource.Type.CUSTOM:
			# Provide a simple sequence editor: use context.sequence as source
			var editor := _create_sequence_editor(context)
			panel.add_child(editor)
			state.sequence_editor = editor
			panel.add_child(_label("Custom session — build a sequence of poses/breaks"))

	return state


static func apply(context: SessionResource, state: Dictionary) -> void:
	var stype: int = int(state.get("type", SessionResource.Type.STANDARD))
	var order = state.get("image_order")
	if order:
		context.shuffle = order.shuffle
		context.reverse = order.reverse

	match stype:
		SessionResource.Type.STANDARD:
			context.session_type = SessionResource.Type.STANDARD
			if state.number_switcher:
				context.number_of_images = int(state.number_switcher.value)
			if state.time_switcher:
				context.time_per_image = int(state.time_switcher.value)
			if context.number_of_images <= 0:
				context.number_of_images = context.get_image_count()
			# Persist standard settings
			context.settings["last_number_of_images"] = int(context.number_of_images)
			context.settings["last_time_per_image"] = int(context.time_per_image)

		SessionResource.Type.RELAXED:
			context.session_type = SessionResource.Type.RELAXED
			context.number_of_images = context.get_image_count()
			context.time_per_image = -1

		SessionResource.Type.CLASS:
			context.session_type = SessionResource.Type.CLASS
			var duration := int(state.duration_switcher.value) if state.duration_switcher else 30
			var template := ClassSessionTemplateRegistry.get_template(duration)
			if template:
				context.sequence = template.session_sequence.duplicate(true)
				context.number_of_images = int(_count_template_images(template))
				context.time_per_image = -1
			# Persist last chosen class duration
			context.settings["last_class_duration"] = int(duration)

		SessionResource.Type.CUSTOM:
			context.session_type = SessionResource.Type.CUSTOM
			# If a sequence editor exists, read its content; otherwise respect context.sequence
			if state.sequence_editor:
				context.sequence = _read_sequence_editor(state.sequence_editor)
			context.number_of_images = context.get_image_count()
			context.time_per_image = -1
			# Persist custom sequence for next time
			context.settings["last_custom_sequence"] = context.sequence.duplicate(true)


static func is_valid(state: Dictionary, context: SessionResource) -> bool:
	var stype := int(state.get("type", SessionResource.Type.STANDARD))
	match stype:
		SessionResource.Type.STANDARD:
			return context.get_image_count(false) > 0
		SessionResource.Type.RELAXED:
			return context.get_image_count(false) > 0
		SessionResource.Type.CLASS:
			return context.sequence.size() > 0 and context.get_image_count(false) > 0
		SessionResource.Type.CUSTOM:
			# Custom is valid when sequence editor contains at least one pose
			if state.sequence_editor:
				var seq := _read_sequence_editor(state.sequence_editor)
				return seq.size() > 0 and context.get_image_count(false) > 0
			return context.sequence.size() > 0 and context.get_image_count(false) > 0
	return false


# ------------------ Helpers for building UI controls ------------------
static func _add_image_order(panel: Control) -> Node:
	var inst := _image_order_scene.instantiate()
	panel.add_child(inst)
	return inst


static func _add_switcher(
	panel: Control,
	title: String,
	values: Array,
	default_value,
	_suffix: String
) -> Node:
	var sw := OptionSwitcher.new()
	sw.title = title
	sw.use_dynamic_options = true
	var opts: Array = []
	for v in values:
		var od := OptionData.new()
		od.label = str(v)
		od.value = v
		opts.append(od)
	sw.set_options_array(opts)
	# Try to set default
	for b in sw.get_children():
		if b is Button and b.text == str(default_value):
			b.button_pressed = true
	panel.add_child(sw)
	return sw


static func _label(text: String) -> Label:
	var l := Label.new()
	l.text = text
	return l


static func _create_sequence_editor(context: SessionResource) -> Control:
	# Minimal sequence editor: a VBox with a List and add/remove buttons.
	var vbox := VBoxContainer.new()
	var list := ItemList.new()
	list.allow_reselect = true
	list.select_mode = ItemList.SELECT_SINGLE
	vbox.add_child(list)

	# Populate from existing sequence
	for item in context.sequence:
		list.add_item(str(item))

	var h := HBoxContainer.new()
	var btn_add_pose := Button.new(); btn_add_pose.text = "Add Pose"
	var btn_add_break := Button.new(); btn_add_break.text = "Add Break"
	var btn_remove := Button.new(); btn_remove.text = "Remove"
	h.add_child(btn_add_pose); h.add_child(btn_add_break); h.add_child(btn_remove)
	vbox.add_child(h)

	btn_add_pose.pressed.connect(func():
		var dur = context.time_per_image if context.time_per_image > 0 else 60
		var d := {"type": "pose", "duration": dur, "amount": 1}
		list.add_item(str(d))
	)
	btn_add_break.pressed.connect(func():
		var d := {"type": "break", "duration": 10}
		list.add_item(str(d))
	)
	btn_remove.pressed.connect(func():
		var idx := list.get_selected_items()
		if idx.size() > 0:
			list.remove_item(idx[0])
	)

	# Store references for later reading
	vbox.set_meta("_seq_list", list)
	return vbox


static func _read_sequence_editor(editor: Control) -> Array:
	var list: ItemList = editor.get_meta("_seq_list")
	var out: Array = []
	if not list:
		return out
	for i in range(list.get_item_count()):
		var text := list.get_item_text(i)
		# Stored as str(dict) — try to parse minimally. Preferably, real UI stores structured data.
		var parsed := _try_parse_dict_string(text)
		if parsed:
			out.append(parsed)
	return out


static func _try_parse_dict_string(s: String) -> Dictionary:
	# Best-effort parser for strings produced by the minimal sequence editor.
	var out: Dictionary = {}
	var rx := RegEx.new()
	var pattern_type := "(?:'|\")?type(?:'|\")?\\s*[:=]\\s*(?:'|\")?([a-zA-Z_]+)(?:'|\")?"
	if rx.compile(pattern_type) == OK:
		var m := rx.search(s)
		if m:
			out["type"] = m.get_string(1)

	var pattern_duration := "duration\\s*[:=]\\s*([0-9]+)"
	if rx.compile(pattern_duration) == OK:
		var m2 := rx.search(s)
		if m2:
			out["duration"] = int(m2.get_string(1))

	var pattern_amount := "amount\\s*[:=]\\s*([0-9]+)"
	if rx.compile(pattern_amount) == OK:
		var m3 := rx.search(s)
		if m3:
			out["amount"] = int(m3.get_string(1))

	return out


static func _count_template_images(template: ClassSessionTemplate) -> int:
	var total := 0
	for item in template.session_sequence:
		if item.get("type") == "pose":
			total += int(item.get("amount", 1))
	return total


# ------------------ Sequence generation per session type ------------------

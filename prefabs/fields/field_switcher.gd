class_name SessionFieldSwitcher extends SessionField

var _switcher: OptionSwitcher
var _options: Array = []

func _init(fdata: Dictionary) -> void:
	_options = fdata.get("options", [])
	super._init(fdata)

func _build() -> void:
	_switcher = preload("res://prefabs/option_switcher/option_switcher.tscn").instantiate()
	_switcher.title = title
	_switcher.use_dynamic_options = true
	var opts: Array[OptionData] = []
	for value in _options:
		var opt := OptionData.new()
		opt.label = str(value) + suffix
		opt.value = value
		opts.append(opt)
	_switcher.set_options_array(opts)
	add_child(_switcher)

func _ready() -> void:
	await _switcher.ready
	await get_tree().process_frame
	_apply_default_if_needed()

func _apply_default_if_needed() -> void:
	# Only apply default if no button is currently selected
	var has_selection := false
	for button in _switcher._buttons:
		if button.button_pressed:
			has_selection = true
			break
	
	if not has_selection:
		var dflt = default_value if default_value != null else (
			_options[0] if _options.size() > 0 else null
		)
		if dflt != null:
			_switcher._programmatic_change = true
			var label_text: String = str(dflt) + suffix
			var btn := _find_button_by_text(_switcher, label_text)
			if btn:
				_switcher._update_buttons(btn, false)
			_switcher._programmatic_change = false

func get_value_dict() -> Dictionary:
	return {field_name: _switcher.value}

func set_from_context(context: Object) -> void:
	if not context:
		return
	
	# Wait until we're fully ready before processing
	if not _switcher or not _switcher.is_node_ready() or not is_inside_tree():
		call_deferred("set_from_context", context)
		return
	
	if not _has_prop(context, field_name):
		# Property doesn't exist, apply default
		_apply_default_if_needed()
		return
	
	var target_value: Variant = context.get(field_name)
	if target_value == null:
		# Null value, apply default
		_apply_default_if_needed()
		return
	
	# Check if value is valid (>= 0 for number fields, or exists in options)
	if typeof(target_value) == TYPE_INT and int(target_value) < 0:
		# Invalid negative value, apply default
		_apply_default_if_needed()
		return
	
	_apply_context_value(target_value)

func _apply_context_value(target_value: Variant) -> void:
	if not _switcher:
		return
	
	# Set flag to prevent animation during programmatic change
	_switcher._programmatic_change = true
	
	var button_found := false
	
	# Try to find button with matching underlying value
	var values: Array = []
	if _switcher._button_values:
		values = _switcher._button_values
	
	for i in values.size():
		if int(values[i]) == int(target_value) and i < _switcher._buttons.size():
			var button: Button = _switcher._buttons[i]
			_switcher._update_buttons(button, false)
			button_found = true
			_switcher._programmatic_change = false
			return
	
	# Fallback: attempt matching label text (value + suffix)
	if not button_found:
		var label_text := str(target_value) + suffix
		var btn := _find_button_by_text(_switcher, label_text)
		if btn:
			_switcher._update_buttons(btn, false)
			button_found = true
	
	_switcher._programmatic_change = false
	
	# If context value wasn't found/valid, apply default
	if not button_found:
		_apply_default_if_needed()

func _find_button_by_text(root: Node, text: String) -> Button:
	for child in root.get_children():
		if child is Button and child.text == text:
			return child
		var found := _find_button_by_text(child, text)
		if found:
			return found
	return null

func _has_prop(object: Object, property_name: String) -> bool:
	for p in object.get_property_list():
		if p.get("name") == property_name:
			return true
	return false

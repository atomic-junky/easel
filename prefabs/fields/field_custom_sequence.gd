class_name SessionFieldCustomSequence
extends SessionField

var _sequence: Array[Dictionary] = []
var _list_container: VBoxContainer
var _scroll_container: ScrollContainer

func _build() -> void:
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	
	var main_vbox: VBoxContainer= VBoxContainer.new()
	main_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	
	# Title label
	if title:
		var title_label: Label = Label.new()
		title_label.text = title
		main_vbox.add_child(title_label)
	
	# Scroll container for the list
	_scroll_container = ScrollContainer.new()
	_scroll_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll_container.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	main_vbox.add_child(_scroll_container)
	
	_list_container = VBoxContainer.new()
	_list_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll_container.add_child(_list_container)
	
	# Button container
	var button_hbox: HBoxContainer = HBoxContainer.new()
	
	var add_pose_btn: Button = Button.new()
	add_pose_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_pose_btn.text = "+ Pose"
	add_pose_btn.pressed.connect(_on_add_pose)
	button_hbox.add_child(add_pose_btn)
	
	var add_break_btn: Button = Button.new()
	add_break_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_break_btn.text = "+ Break"
	add_break_btn.pressed.connect(_on_add_break)
	button_hbox.add_child(add_break_btn)
	
	main_vbox.add_child(button_hbox)
	add_child(main_vbox)
	
	# Initialize with default if provided
	if spec.default_value and typeof(spec.default_value) == TYPE_ARRAY:
		_sequence = spec.default_value.duplicate(true)
		_rebuild_list()

func _on_add_pose() -> void:
	_sequence.append({
		"type": "pose",
		"duration": 60,
		"amount": 1
	})
	_rebuild_list()

func _on_add_break() -> void:
	_sequence.append({
		"type": "break",
		"duration": 60,
		"amount": 1
	})
	_rebuild_list()

func _rebuild_list() -> void:
	# Clear existing items
	for child in _list_container.get_children():
		child.queue_free()
	
	# Build list items
	for i in _sequence.size():
		var item := _create_list_item(i)
		_list_container.add_child(item)

func _create_list_item(idx: int) -> Control:
	var item_data: Dictionary = _sequence[idx]
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	var hbox := HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_END
	hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_theme_constant_override("separation", 8)
	panel.add_child(hbox)
	
	# Type label
	var type_label := Label.new()
	type_label.text = "  %s.  %s" % [idx+1, item_data.get("type", "pose").capitalize()]
	type_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(type_label)
	
	# Amount control (for poses)
	if item_data.get("type") == "pose":
		var amount_label := Label.new()
		amount_label.text = "Count:"
		hbox.add_child(amount_label)
		
		var amount_spin := SpinBox.new()
		amount_spin.min_value = 1
		amount_spin.max_value = 100
		amount_spin.value = item_data.get("amount", 1)
		amount_spin.custom_minimum_size = Vector2(60, 0)
		amount_spin.value_changed.connect(func(val: float):
			_sequence[idx]["amount"] = int(val)
		)
		hbox.add_child(amount_spin)
	
	# Duration control
	var duration_label := Label.new()
	duration_label.text = "Duration:"
	hbox.add_child(duration_label)
	
	var duration_spin := SpinBox.new()
	duration_spin.min_value = 5
	duration_spin.max_value = 600
	duration_spin.step = 5
	duration_spin.suffix = "s"
	duration_spin.value = item_data.get("duration", 60)
	duration_spin.custom_minimum_size = Vector2(60, 0)
	duration_spin.value_changed.connect(func(val: float):
		_sequence[idx]["duration"] = int(val)
	)
	hbox.add_child(duration_spin)
	
	# Delete button
	var delete_btn := Button.new()
	delete_btn.text = "✕"
	delete_btn.pressed.connect(func():
		_on_delete_item(idx)
	)
	hbox.add_child(delete_btn)
	
	return panel

func _on_delete_item(idx: int) -> void:
	if idx >= 0 and idx < _sequence.size():
		_sequence.remove_at(idx)
		_rebuild_list()

func get_value_dict() -> Dictionary:
	return {field_name: _sequence.duplicate(true)}

func set_from_context(context: Object) -> void:
	if context and _has_prop(context, field_name):
		var val = context.get(field_name)
		if typeof(val) == TYPE_ARRAY:
			# Ensure proper type conversion for typed array
			_sequence.clear()
			for item in val:
				if typeof(item) == TYPE_DICTIONARY:
					_sequence.append(item.duplicate(true))
			if is_node_ready():
				_rebuild_list()

func _has_prop(object: Object, property_name: String) -> bool:
	for p in object.get_property_list():
		if p.get("name") == property_name:
			return true
	return false

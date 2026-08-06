class_name SessionFieldChoice extends SessionField

## A row of chips plus an optional custom value.
##
## Chips wrap on their own, so the field works at any width without measuring.
## "Custom" reveals a stepper: big -/+ targets for touch, a typable field for
## keyboard. `extra.labels` overrides the chip text; otherwise value + suffix.

const GAP: int = 10
const STEP_SIZE: Vector2 = Vector2(52, 52)

var _chips: Array[Button] = []
var _custom_chip: Button
var _stepper: HBoxContainer
var _value_edit: LineEdit
var _options: Array = []
var _value: int = 0
var _min: int = 1
var _max: int = 9999
var _step: int = 1


func _init(fdata: Dictionary) -> void:
	_options = fdata.get("options", [])
	super._init(fdata)


func _build() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", GAP)

	_min = int(extra.get("custom_min", 1))
	_max = int(extra.get("custom_max", 9999))
	_step = int(extra.get("custom_step", 1))

	if not title.is_empty():
		var label: Label = Label.new()
		label.text = title
		label.theme_type_variation = &"LabelFieldTitle"
		add_child(label)

	var flow: HFlowContainer = HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", GAP)
	flow.add_theme_constant_override("v_separation", GAP)
	add_child(flow)

	var group: ButtonGroup = ButtonGroup.new()
	var labels: Array = extra.get("labels", [])

	for i in _options.size():
		var text: String = str(labels[i]) if i < labels.size() else str(_options[i]) + suffix
		var chip: Button = _make_chip(text, group)
		chip.pressed.connect(_on_option_pressed.bind(i))
		flow.add_child(chip)
		_chips.append(chip)

	_custom_chip = _make_chip("Custom", group)
	_custom_chip.pressed.connect(_on_custom_pressed)
	flow.add_child(_custom_chip)

	_build_stepper()

	var initial: Variant = default_value
	if initial == null:
		initial = _options[0] if not _options.is_empty() else _min
	_select_value(int(initial))


func _make_chip(text: String, group: ButtonGroup) -> Button:
	var chip: Button = Button.new()
	chip.text = text
	chip.theme_type_variation = &"ButtonChip"
	chip.toggle_mode = true
	chip.button_group = group
	chip.pressed.connect(_pop.bind(chip))
	return chip


func _build_stepper() -> void:
	_stepper = HBoxContainer.new()
	_stepper.alignment = BoxContainer.ALIGNMENT_CENTER
	_stepper.add_theme_constant_override("separation", GAP)
	_stepper.visible = false
	add_child(_stepper)

	_stepper.add_child(_make_step_button("-", -1))

	var field: PanelContainer = PanelContainer.new()
	field.theme_type_variation = &"FieldPanel"
	field.custom_minimum_size.x = 120
	_stepper.add_child(field)

	_value_edit = LineEdit.new()
	_value_edit.theme_type_variation = &"LineEditValue"
	_value_edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_value_edit.text_submitted.connect(_on_value_submitted)
	_value_edit.focus_exited.connect(func() -> void: _on_value_submitted(_value_edit.text))
	field.add_child(_value_edit)

	_stepper.add_child(_make_step_button("+", 1))


func _make_step_button(text: String, direction: int) -> Button:
	var button: Button = Button.new()
	button.text = text
	button.theme_type_variation = &"ButtonStepper"
	button.custom_minimum_size = STEP_SIZE
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	button.pressed.connect(func() -> void:
		_pop(button)
		_set_custom_value(_value + _step * direction)
	)
	return button


func _pop(control: Control) -> void:
	control.pivot_offset = control.size / 2.0
	var tween: Tween = create_tween()
	tween.tween_property(control, "scale", Vector2(1.08, 1.08), 0.07) \
		.set_trans(Tween.TRANS_QUAD)
	tween.tween_property(control, "scale", Vector2.ONE, 0.16) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _select_value(value: int) -> void:
	_value = value
	var index: int = _options.find(value)
	for i in _chips.size():
		_chips[i].set_pressed_no_signal(i == index)

	# A value that is not one of the presets is shown as a custom entry.
	var is_custom: bool = index < 0
	_custom_chip.set_pressed_no_signal(is_custom)
	_stepper.visible = is_custom
	_value_edit.text = str(value)


func _set_custom_value(value: int) -> void:
	_value = clampi(value, _min, _max)
	_value_edit.text = str(_value)


func _on_option_pressed(index: int) -> void:
	_value = int(_options[index])
	_stepper.visible = false


func _on_custom_pressed() -> void:
	_stepper.visible = true
	_set_custom_value(_value)
	_value_edit.grab_focus()
	_value_edit.select_all()


func _on_value_submitted(text: String) -> void:
	_set_custom_value(int(text) if text.is_valid_int() else _value)


func get_value_dict() -> Dictionary:
	return {field_name: _value}


func set_from_context(context: Object) -> void:
	if not context:
		return
	var value: Variant = context.get(field_name)
	if typeof(value) == TYPE_INT and int(value) >= 0:
		_select_value(int(value))

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
	_switcher.value_changed.connect(func(_v: int):
		_field_update.emit()
	)

func _ready() -> void:
	super._ready()
	await _switcher.ready
	await get_tree().process_frame
	var dflt = default_value if default_value != null else (
		_options[0] if _options.size() > 0 else null
	)
	if dflt != null:
		var label_text: String = str(dflt) + suffix
		var btn := _find_button_by_text(_switcher, label_text)
		if btn:
			btn.emit_signal("pressed")

func get_value_dict() -> Dictionary:
	return {field_name: _switcher.value}

func _find_button_by_text(root: Node, text: String) -> Button:
	for child in root.get_children():
		if child is Button and child.text == text:
			return child
		var found := _find_button_by_text(child, text)
		if found:
			return found
	return null

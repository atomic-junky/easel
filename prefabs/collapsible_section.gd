@tool
class_name CollapsibleSection
extends VBoxContainer

signal toggled(is_expanded: bool)

@export var section_title: String = "Section" :
	set(value):
		section_title = value
		if _header_button:
			_update_header_text()

@export var is_expanded: bool = true :
	set(value):
		if is_expanded != value:
			is_expanded = value
			if is_node_ready():
				set_expanded(value, true)

@export var animation_duration: float = 0.2

var _header_button: Button
var _content_container: Control
var _arrow_label: Label
var _title_label: Label
var _tween: Tween


func _ready() -> void:
	if not _header_button:
		_setup_ui()
	set_expanded(is_expanded, false)


func _setup_ui() -> void:
	# Create header button
	_header_button = Button.new()
	_header_button.custom_minimum_size.y = 48
	_header_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	_header_button.pressed.connect(_on_header_pressed)
	add_child(_header_button)
	move_child(_header_button, 0)
	
	# Create HBox for arrow and title
	var hbox := HBoxContainer.new()
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_header_button.add_child(hbox)
	
	# Create arrow label
	_arrow_label = Label.new()
	_arrow_label.text = "▼"
	_arrow_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(_arrow_label)
	
	# Create title label
	_title_label = Label.new()
	_title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(_title_label)
	
	_update_header_text()
	
	# Find or create content container
	if get_child_count() > 1:
		_content_container = get_child(1)
	else:
		_content_container = VBoxContainer.new()
		_content_container.name = "Content"
		add_child(_content_container)


func _update_header_text() -> void:
	if _title_label:
		_title_label.text = section_title


func _on_header_pressed() -> void:
	set_expanded(not is_expanded, true)
	toggled.emit(is_expanded)


func set_expanded(expanded: bool, animate: bool = true) -> void:
	is_expanded = expanded
	
	if not _content_container:
		return
	
	# Kill existing tween
	if _tween:
		_tween.kill()
	
	# Update arrow
	if _arrow_label:
		_arrow_label.text = "▼" if expanded else "▶"
	
	if not animate or not is_inside_tree():
		_content_container.visible = expanded
		return
	
	# Animate expansion/collapse
	if expanded:
		_content_container.visible = true
		_content_container.modulate.a = 0.0
		_tween = create_tween()
		_tween.set_parallel(true)
		_tween.tween_property(_content_container, "modulate:a", 1.0, animation_duration)
	else:
		_tween = create_tween()
		_tween.tween_property(_content_container, "modulate:a", 0.0, animation_duration)
		_tween.tween_callback(func(): _content_container.visible = false)


func get_content_container() -> Control:
	return _content_container

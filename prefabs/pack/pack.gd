class_name PackContainer extends PanelContainer

signal delete_request
signal toggled

@onready var check_box: CheckBox = %CheckBox
@onready var icon_rect: TextureRect = %IconRect
@onready var title_label: Label = %Title
@onready var decsc_label: Label = %Description

var _context: PackContext


func _from_context(context: PackContext) -> void:
	_context = context
	check_box.button_pressed = context.enabled
	title_label.text = context.pack_name
	decsc_label.text = "%s images found." % context.image_count


func _on_button_pressed() -> void:
	delete_request.emit()


func _on_check_box_toggled(toggled_on: bool) -> void:
	_context.enabled = toggled_on
	toggled.emit()

class_name Pack extends PanelContainer

signal delete_request
signal toggled

@onready var check_box: CheckBox = %CheckBox
@onready var icon_rect: TextureRect = %IconRect
@onready var title_label: Label = %Title
@onready var decsc_label: Label = %Description

@onready var folder_icon: Texture2D = preload("res://assets/icons/folder.svg")
@onready var image_icon: Texture2D = preload("res://assets/icons/image.svg")
@onready var pinterest_icon: Texture2D = preload("res://assets/icons/pinterest.svg")
@onready var add_icon: Texture2D = preload("res://assets/icons/bookmark-add.svg")
@onready var check_icon: Texture2D = preload("res://assets/icons/bookmark-check.svg")

var _context: PackContext


func _from_context(context: PackContext) -> void:
	_context = context
	check_box.button_pressed = context.enabled
	title_label.text = context.pack_name
	
	var desc_label: String = "%s images found."
	match context.source:
		Constants.Source.FOLDER:
			icon_rect.texture = folder_icon
		Constants.Source.IMAGES:
			icon_rect.texture = image_icon
		Constants.Source.PINTEREST:
			icon_rect.texture = pinterest_icon
			desc_label = "%s pins found."
		Constants.Source.LIBRARY:
			pass
	
	decsc_label.text = desc_label % context.image_count


func _on_button_pressed() -> void:
	delete_request.emit()


func _on_check_box_toggled(toggled_on: bool) -> void:
	_context.enabled = toggled_on
	toggled.emit()


func _on_save_button_pressed() -> void:
	pass # Replace with function body.

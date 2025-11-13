class_name Pack extends PanelContainer

signal delete_request
signal refresh_request
signal toggled

@onready var check_box: CheckBox = %CheckBox
@onready var icon_rect: TextureRect = %IconRect
@onready var title_label: Label = %Title
@onready var decsc_label: Label = %Description
@onready var delete_button: Button = %DeleteButton
@onready var refresh_button: Button = %RefreshButton

@onready var folder_icon: Texture2D = preload("res://assets/icons/folder.svg")
@onready var image_icon: Texture2D = preload("res://assets/icons/image.svg")
@onready var pinterest_icon: Texture2D = preload("res://assets/icons/pinterest.svg")
@onready var add_icon: Texture2D = preload("res://assets/icons/bookmark-add.svg")
@onready var check_icon: Texture2D = preload("res://assets/icons/bookmark-check.svg")

var _resource: PackResource


func _from_context(
	pack: PackResource,
	show_delete: bool = true,
	show_refresh: bool = false
) -> void:
	_resource = pack
	check_box.button_pressed = pack.enabled
	title_label.text = pack.pack_name
	
	# Control button visibility
	delete_button.visible = show_delete
	refresh_button.visible = show_refresh
	
	var desc_label: String = "%s images found."
	match pack.source:
		Constants.Source.FOLDER:
			icon_rect.texture = folder_icon
		Constants.Source.IMAGES:
			icon_rect.texture = image_icon
		Constants.Source.PINTEREST:
			icon_rect.texture = pinterest_icon
			desc_label = "%s pins found."
		Constants.Source.LIBRARY:
			pass
	
	decsc_label.text = desc_label % pack.image_count


func _on_button_pressed() -> void:
	delete_request.emit()


func _on_refresh_button_pressed() -> void:
	refresh_request.emit()


func _on_check_box_toggled(toggled_on: bool) -> void:
	_resource.enabled = toggled_on
	toggled.emit()


func _on_save_button_pressed() -> void:
	pass # Replace with function body.

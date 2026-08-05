extends VBoxContainer

const PACK_OBJECT: PackedScene = preload("res://prefabs/pack/pack.tscn")
const ADD_ICON: Texture2D = preload("res://assets/icons/plus.svg")
const CLOSE_ICON: Texture2D = preload("res://assets/icons/exit.svg")

@onready var menu: Menu = $"../../../../../.."

@onready var add_pack_button: Button = %AddPackButton

@onready var add_pack_container := %AddPackContainer
@onready var source_button_container := %SourceButtonContainer
@onready var pinterest_url_container := %PinterestUrlContainer

@onready var pinterest_url_input_container := %UrlInputContainer
@onready var pinterest_url_spinner_container := %UrlInputSpinerContainer
@onready var pinterest_url_input := %UrlInput
@onready var pinterest_url_done_button := %UrlDoneButton
@onready var pinterest_url_section_checkbox := %PinterestSectionCheckBox
@onready var pinterest_url_message_label := %PinterestUrlMessageLabel

@onready var folder_dialog: FileDialog = %FolderDialog
@onready var images_dialog: FileDialog = %ImageDialog


func _on_add_pack_button_toggled(toggled_on: bool) -> void:
	add_pack_container.visible = toggled_on
	source_button_container.show()
	pinterest_url_container.hide()
	add_pack_button.icon = CLOSE_ICON if toggled_on else ADD_ICON

func _on_folder_button_pressed() -> void: folder_dialog.popup_centered()
func _on_images_button_pressed() -> void: images_dialog.popup_centered()

func _on_folder_dialog_dir_selected(dir: String) -> void:
	menu._add_packs(PackResource.create_from_path(dir))
	add_pack_button.button_pressed = false

func _on_image_dialog_files_selected(paths: PackedStringArray) -> void:
	menu._add_packs(PackResource.create_from_paths(paths))
	add_pack_button.button_pressed = false

func _on_pinterest_button_pressed() -> void:
	source_button_container.hide()
	pinterest_url_container.show()
	pinterest_url_input_container.show()
	pinterest_url_spinner_container.hide()
	
	pinterest_url_input.text = ""


func _on_url_done_button_pressed() -> void:
	pinterest_url_input_container.hide()
	pinterest_url_spinner_container.show()
	
	pinterest_url_input_container.hide()
	pinterest_url_spinner_container.show()
	pinterest_url_message_label.show()
	pinterest_url_section_checkbox.hide()

	var use_sections: bool = pinterest_url_section_checkbox.button_pressed
	
	# Create a new instance for this fetch
	var _pinterest_fetcher = PinterestFetcher.new()
	add_child(_pinterest_fetcher)
	
	var results: Array = await _pinterest_fetcher.fetch(
		pinterest_url_input.text,
		use_sections,
		_on_url_fetcher_progress_callback
	)
	
	# Clean up the fetcher
	_pinterest_fetcher.queue_free()
	_pinterest_fetcher = null

	pinterest_url_spinner_container.hide()
	pinterest_url_input_container.show()
	pinterest_url_section_checkbox.show()
	pinterest_url_message_label.hide()
	
	add_pack_button.button_pressed = false

	for pack in results:
		if pack.is_empty() or pack.get("status") != "success":
			printerr(pack.get("data", "Fetching failure (no data)"))
			return
		
		var pack_resource: PackResource = PackResource.create_from_urls(
			pack.get("data", {}),
			use_sections
		)
		menu._add_packs([pack_resource])
	menu._update()


func _on_url_fetcher_progress_callback(message: String) -> void:
	pinterest_url_message_label.text = message

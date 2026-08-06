extends VBoxContainer

## Contents of the "Add a new Pack" modal.

const SOURCE_LOCAL: int = 1
const SOURCE_PINTEREST: int = 2

@onready var menu: Menu = owner
@onready var modal: Modal = %AddPackModal

@onready var local_container: Control = %LocalContainer
@onready var pinterest_container: Control = %PinterestContainer
@onready var url_input: LineEdit = %UrlInput
@onready var url_spinner: Control = %UrlInputSpinerContainer
@onready var section_row: Control = %SectionRow
@onready var section_checkbox: Button = %PinterestSectionCheckBox
@onready var message_label: Label = %PinterestUrlMessageLabel
@onready var done_button: Button = %AddPackDoneButton

@onready var folder_dialog: FileDialog = %FolderDialog
@onready var images_dialog: FileDialog = %ImageDialog

var _source: int = SOURCE_LOCAL


func _ready() -> void:
	url_input.text_changed.connect(_on_url_text_changed)
	_apply_source(_source)


## The switcher emits on its own _ready, which runs before ours.
func _on_source_switcher_value_changed(value: int) -> void:
	if not is_node_ready():
		await ready
	_apply_source(value)


func _apply_source(value: int) -> void:
	_source = value
	local_container.visible = value == SOURCE_LOCAL
	pinterest_container.visible = value == SOURCE_PINTEREST
	_update_done_button()


func _on_url_text_changed(_text: String) -> void:
	_update_done_button()


func _update_done_button() -> void:
	done_button.disabled = _source != SOURCE_PINTEREST or url_input.text.strip_edges().is_empty()


func _on_folder_button_pressed() -> void: folder_dialog.popup_centered()
func _on_images_button_pressed() -> void: images_dialog.popup_centered()


func _on_folder_dialog_dir_selected(dir: String) -> void:
	menu._add_packs(PackResource.create_from_path(dir))
	modal.close()


func _on_image_dialog_files_selected(paths: PackedStringArray) -> void:
	menu._add_packs(PackResource.create_from_paths(paths))
	modal.close()


func _on_done_button_pressed() -> void:
	_set_fetching(true)

	var use_sections: bool = section_checkbox.button_pressed
	var fetcher: PinterestFetcher = PinterestFetcher.new()
	add_child(fetcher)

	var results: Array = await fetcher.fetch(
		url_input.text,
		use_sections,
		_on_url_fetcher_progress_callback
	)

	fetcher.queue_free()
	_set_fetching(false)

	for pack in results:
		if pack.is_empty() or pack.get("status") != "success":
			printerr(pack.get("data", "Fetching failure (no data)"))
			return

		menu._add_packs([PackResource.create_from_urls(pack.get("data", {}), use_sections)])

	url_input.text = ""
	_update_done_button()
	modal.close()


func _set_fetching(active: bool) -> void:
	url_input.visible = not active
	section_row.visible = not active
	url_spinner.visible = active
	message_label.visible = active
	done_button.disabled = active


func _on_url_fetcher_progress_callback(message: String) -> void:
	message_label.text = message

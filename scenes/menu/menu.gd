class_name Menu extends Control

signal done(context: SessionContext)

const SUPPORTED_EXTENSIONS := ["png", "jpeg", "jpg", "tiff"]

@onready var folder_dialog: FileDialog = %FolderDialog
@onready var images_dialog: FileDialog = %ImageDialog

@onready var info_label: Label = %InfoLabel
@onready var standard: Control = %Standard
@onready var comming_soon: Control = %CommingSoon
@onready var relaxed: Control = %Relaxed
@onready var session_type_switcher: OptionSwitcher = %SessionTypeSwitcher
@onready var _session_panel: Array = [standard, comming_soon, relaxed, comming_soon]
@onready var done_button: Button = %DoneButton

@onready var pack_selector: Control = %PackSelectorContainer
@onready var pack_container: Control = %PackContainer
@onready var dimer: ColorRect = %Dimer
@onready var url_container: Control = %UrlContainer
@onready var url_label: Label = %UrlLabel
@onready var url_input_container: Control = %UrlInputContainer
@onready var url_input: LineEdit = %UrlInput
@onready var url_input_spiner_container: Control = %UrlInputSpinerContainer

@onready var pack_object: PackedScene = preload("res://prefabs/pack/pack.tscn")

var _context: SessionContext


func _ready() -> void:
	_on_session_type_switcher_value_changed(1)
	_update()
	visibility_changed.connect(_update)


func _on_session_type_switcher_value_changed(value: int) -> void:
	for panel in _session_panel:
		panel.hide()
	
	_session_panel[value-1].show()
	_update()


func _on_select_pack_button_pressed() -> void:
	pack_selector.show()


func get_session_panel() -> SessionType:
	return _session_panel[session_type_switcher.value-1]


func _update() -> void:
	if not _context:
		_context = SessionContext.new()
	
	for pack in pack_container.get_children():
		pack.queue_free()
	
	for pack: PackContext in _context.packs:
		var new_pack: Pack = pack_object.instantiate()
		pack_container.add_child(new_pack)
		new_pack._from_context(pack)
		new_pack.delete_request.connect(_on_pack_delete_request.bind(pack))
		new_pack.toggled.connect(_on_pack_toggled.bind(pack))
	
	get_session_panel().apply_context(_context)
	
	done_button.disabled = not get_session_panel().is_valid()
	if _context.get_image_count() <= 0:
		done_button.disabled = true
	
	_update_labels()


func _update_labels() -> void:
	var pack_count: int = _context.get_packs().size()
	var image_count: int = _context.get_image_count(false)
	var more_than_one_pack: bool = pack_count >= 1
	var more_than_one_image: bool = image_count >= 1
	
	if pack_count <= 0:
		info_label.text = "No pack selected"
		return
	var info_text: String = ""
	info_text += "%s images" if more_than_one_image else "%s image"
	info_text += " in %s packs" if more_than_one_pack else " in %s packs"
	
	info_label.text = info_text % [image_count, pack_count]

func _add_packs(packs: Array[PackContext]) -> void:
	for new_pack: PackContext in packs:
		if new_pack.image_count <= 0:
			packs.erase(new_pack)

	_context.packs.append_array(packs)
	_update()


func _on_pack_delete_request(pack: PackContext) -> void:
	_context.packs.erase(pack)
	_update()


func _on_pack_toggled(pack: PackContext) -> void:
	_update_labels()


func get_args() -> SessionContext:
	return _context

# Pack source buttons

func _on_folder_button_pressed() -> void: folder_dialog.popup_centered()
func _on_images_button_pressed() -> void: images_dialog.popup_centered()


func _on_pinterest_button_pressed() -> void:
	dimer.show()
	url_container.show()
	url_input_container.show()
	url_input_spiner_container.hide()
	url_input.clear()
	url_input.grab_click_focus()
	url_label.text = "Enter url"


func _on_library_button_pressed() -> void:
	pass # Replace with function body.


func _on_folder_dialog_dir_selected(dir: String) -> void:
	_add_packs(PackContext.create_from_path(dir))


func _on_image_dialog_files_selected(paths: PackedStringArray) -> void:
	_add_packs(PackContext.create_from_paths(paths))


func _on_clear_button_pressed() -> void:
	_context.packs.clear()
	_update()


func _on_url_done_button_pressed() -> void:
	url_input_container.hide()
	url_input_spiner_container.show()
	
	var board: Dictionary = await PinterestFetcher.fetch(url_input.text, _on_url_fetcher_progress_callback)
	
	url_input_spiner_container.hide()
	url_input_container.show()
	dimer.hide()
	url_container.hide()
	
	if board.is_empty() or board.get("status") != "success":
		printerr(board.get("data", "Fetching failure (no data)"))
		return
	
	_context.packs.append(PackContext.create_from_urls(board.get("data", {})))
	_update()


func _on_url_fetcher_progress_callback(message: String) -> void:
	url_label.text = message


func _on_pack_done_button_pressed() -> void:
	pack_selector.hide()


func _on_done_button_pressed() -> void:
	done.emit(_context)

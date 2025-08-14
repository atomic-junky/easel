class_name Menu
extends Control

var SUPPORTED_EXTENSIONS := ["png", "jpeg", "jpg", "tiff"]

signal done(context: SessionContext)

# Références aux nœuds
@onready var number_value_picker: ValuePicker = %NumberValuePicker
@onready var time_value_picker: ValuePicker = %TimeValuePicker
@onready var file_dialog: FileDialog = %FileDialog
@onready var start_session_button: Button = %StartSessionButton
@onready var spinner: TextureRect = %Spiner
@onready var folder_tooltip: Label = %FolderTooltip
@onready var done_button: Button = %DoneButton
@onready var packs_container: Control = %PacksContainer
@onready var dimer: ColorRect = %Dimer
@onready var pack_selector: Control = %PackSelector
@onready var pack_selector_ratio: Control = %PackSelectorRatio
@onready var url_container: Control = %UrlContainer
@onready var url_edit: LineEdit = %UrlEdit
@onready var spinner_container: Control = %SpinerContainer

# Préchargements
@onready var pack_obj := preload("res://prefabs/pack/pack.tscn")

# Données
var packs: Array[PackContext] = []


func _ready() -> void:
	setup()
	_on_resized()


func setup() -> void:
	start_session_button.show()
	spinner.hide()
	update()


func _on_start_session_button_pressed() -> void:
	start_session_button.hide()
	spinner.show()
	done.emit(create_context())


func create_context() -> SessionContext:
	var new_context: SessionContext = SessionContext.new()
	new_context.number_of_images = number_value_picker.get_value()
	new_context.time_per_image = time_value_picker.get_value()
	new_context.packs = packs
	return new_context


func _on_set_folder_button_pressed() -> void:
	var android_permission := "android.permission.READ_MEDIA_IMAGES"
	
	if OS.get_name() == "Android":
		var has_permission := OS.request_permission(android_permission)
		if not has_permission:
			await get_tree().on_request_permissions_result
			if not android_permission in OS.get_granted_permissions():
				return
	
	file_dialog.popup_centered()


func _on_file_dialog_dir_selected(dir: String) -> void:
	packs.append_array(PackContext.create_from_path(dir))
	update()


func _update_display() -> void:
	var image_count := get_pack_images_count()
	
	if packs.size() <= 0:
		folder_tooltip.text = "Please select a folder that contains images."
	else:
		folder_tooltip.text = "%s images found (in %s packs)!" % [image_count, get_enabled_pack_count()]
	
	done_button.text = "Done (%s images)" % [image_count]


func update() -> void:
	_update_display()
	
	for pack in packs_container.get_children():
		pack.queue_free()
	
	for pack: PackContext in packs:
		var new_pack: PackContainer = pack_obj.instantiate()
		new_pack.delete_request.connect(_on_pack_delete_request.bind(pack))
		new_pack.toggled.connect(_update_display)
		packs_container.add_child(new_pack)
		new_pack._from_context(pack)
	
	var is_form_valid := true
	if time_value_picker.get_value() <= 0: is_form_valid = false
	if packs.is_empty(): is_form_valid = false
	
	start_session_button.disabled = not is_form_valid


func _on_pack_delete_request(pack: PackContext) -> void:
	packs.erase(pack)
	update()


func get_pack_images_count() -> int:
	var count := 0
	for pack in packs:
		if pack.enabled:
			count += pack.image_count
	return count


func get_enabled_pack_count() -> int:
	var count := 0
	for pack in packs:
		if pack.enabled:
			count += 1
	return count


func get_args() -> SessionContext:
	return create_context()


func _on_select_pack_folder_pressed() -> void:
	dimer.show()
	pack_selector.show()


func _on_done_button_pressed() -> void:
	dimer.hide()
	pack_selector.hide()


func _on_clear_button_pressed() -> void:
	packs.clear()
	update()


func _on_folder_button_pressed() -> void:
	file_dialog.popup_centered()
	url_container.hide()
	spinner_container.hide()


func _on_pinterest_button_pressed() -> void:
	url_container.show()
	url_edit.text = ""
	url_edit.grab_focus()


func _on_button_url_done_pressed() -> void:
	url_container.hide()
	spinner_container.show()
	var board: Dictionary = await PinterestFetcher.fetch(url_edit.text)
	spinner_container.hide()
	
	if board.is_empty() or board.get("status") != "success":
		printerr(board.get("data", "no data"))
		return
	
	packs.append(PackContext.create_from_urls(board.get("data", {})))
	update()


func _on_resized() -> void:
	if not is_node_ready():
		return
	
	var vp_size := pack_selector_ratio.size
	var ratio := vp_size.x / vp_size.y
	pack_selector_ratio.ratio = 0.6
	if ratio < 1.0:
		pack_selector_ratio.ratio = ratio

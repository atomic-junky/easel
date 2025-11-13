extends VBoxContainer

## Tab 2: Pack Selection
## Handles image pack selection and management

signal packs_changed

const PACK_OBJECT: PackedScene = preload("res://prefabs/pack/pack.tscn")

var _context: SessionResource
var _pinterest_fetcher: PinterestFetcher

@onready var pack_container: VBoxContainer = %PackContainer
@onready var pack_history_container: VBoxContainer = %PackHistoryContainer
@onready var folder_button: Button = %FolderButton
@onready var images_button: Button = %ImagesButton
@onready var pinterest_button: Button = %PinterestButton
@onready var info_label: Label = %InfoLabel
@onready var folder_dialog: FileDialog = %FolderDialog
@onready var images_dialog: FileDialog = %ImagesDialog
@onready var url_container: Control = null  # Created dynamically
@onready var dimer: ColorRect = null  # Reference from parent


func _ready() -> void:
	folder_button.pressed.connect(_on_folder_button_pressed)
	images_button.pressed.connect(_on_images_button_pressed)
	pinterest_button.pressed.connect(_on_pinterest_button_pressed)
	
	folder_dialog.dir_selected.connect(_on_folder_dialog_dir_selected)
	images_dialog.files_selected.connect(_on_image_dialog_files_selected)
	
	_populate_pack_history()


func set_context(context: SessionResource) -> void:
	_context = context
	_update_packs_display()


func _populate_pack_history() -> void:
	# Clear existing items
	for child in pack_history_container.get_children():
		child.queue_free()
	
	var history: Array[PackResource] = PackHistory.get_history()
	
	if history.is_empty():
		var empty_label := Label.new()
		empty_label.text = "No packs in history"
		empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		pack_history_container.add_child(empty_label)
		return
	
	# Create Pack instances for recent packs (limit to 5)
	var max_display := 5
	for i in mini(history.size(), max_display):
		var pack := history[i]
		var pack_node: Pack = PACK_OBJECT.instantiate()
		pack_history_container.add_child(pack_node)
		pack_node._from_context(pack, false, true)
		# Make it smaller for history display
		pack_node.custom_minimum_size = Vector2(0, 60)
		# Connect to add this pack when clicked
		pack_node.refresh_request.connect(_on_pack_history_add_request.bind(pack))


func _on_pack_history_add_request(pack: PackResource) -> void:
	_add_packs([pack])


func _add_packs(packs: Array[PackResource]) -> void:
	if not _context:
		_context = SessionResource.new()
	
	for new_pack: PackResource in packs:
		if new_pack.image_count <= 0:
			continue
		_context.packs.append(new_pack)
	
	# Add to history
	PackHistory.add_packs(packs)
	
	_update_packs_display()
	packs_changed.emit()


func _update_packs_display() -> void:
	# Clear existing pack displays
	for child in pack_container.get_children():
		child.queue_free()
	
	if not _context:
		return
	
	for pack: PackResource in _context.packs:
		var new_pack: Pack = PACK_OBJECT.instantiate()
		pack_container.add_child(new_pack)
		new_pack._from_context(pack)
		new_pack.delete_request.connect(_on_pack_delete_request.bind(pack))
		new_pack.toggled.connect(_on_pack_toggled.bind(pack))
	
	_update_info_label()


func _update_info_label() -> void:
	if not _context:
		info_label.text = "No pack selected"
		return
	
	var pack_count: int = _context.get_packs().size()
	var image_count: int = _context.get_image_count(false)
	
	if pack_count <= 0:
		info_label.text = "No pack selected"
		return
	
	var more_than_one_pack: bool = pack_count > 1
	var more_than_one_image: bool = image_count > 1
	
	var info_text: String = ""
	info_text += "%s images" if more_than_one_image else "%s image"
	info_text += " in %s packs" if more_than_one_pack else " in %s pack"
	
	info_label.text = info_text % [image_count, pack_count]


func _on_pack_delete_request(pack: PackResource) -> void:
	if _context:
		_context.packs.erase(pack)
	_update_packs_display()
	packs_changed.emit()


func _on_pack_toggled(_pack: PackResource) -> void:
	_update_info_label()
	packs_changed.emit()


func _on_folder_button_pressed() -> void:
	folder_dialog.popup_centered()


func _on_images_button_pressed() -> void:
	images_dialog.popup_centered()


func _on_pinterest_button_pressed() -> void:
	# TODO: Implement Pinterest dialog
	pass


func _on_folder_dialog_dir_selected(dir: String) -> void:
	_add_packs(PackResource.create_from_path(dir))


func _on_image_dialog_files_selected(paths: PackedStringArray) -> void:
	_add_packs(PackResource.create_from_paths(paths))


func is_valid() -> bool:
	# Valid if at least one pack with images is selected
	if not _context:
		return false
	return _context.get_image_count() > 0


func clear_packs() -> void:
	if _context:
		_context.packs.clear()
	_update_packs_display()
	packs_changed.emit()

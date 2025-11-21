class_name Pack extends PanelContainer

signal delete_request
signal refresh_request
signal add_pack_request
signal toggled
signal refresh_done

@onready var check_box: CheckBox = %CheckBox
@onready var icon_rect: TextureRect = %IconRect
@onready var title_label: Label = %Title
@onready var decsc_label: Label = %Description
@onready var refresh_spiner: Control = %RefreshSpiner
@onready var menu_button: MenuButton = %MenuButton
@onready var holo_overlay: Panel = %HoloOL
@onready var add_pack_container: HBoxContainer = %AddPackContainer
@onready var add_pack_button: Button = %AddPackButton

@onready var folder_icon: Texture2D = preload("res://assets/icons/folder.svg")
@onready var image_icon: Texture2D = preload("res://assets/icons/image.svg")
@onready var pinterest_icon: Texture2D = preload("res://assets/icons/pinterest.svg")
@onready var add_icon: Texture2D = preload("res://assets/icons/bookmark-add.svg")
@onready var check_icon: Texture2D = preload("res://assets/icons/bookmark-check.svg")

var _resource: PackResource
var _pinterest_fetcher: PinterestFetcher
var _is_holo: bool = false


func _ready() -> void:
	var mb_popup: PopupMenu = menu_button.get_popup()
	mb_popup.id_pressed.connect(_on_mb_popup_id_pressed)


func _from_context(
	pack: PackResource,
	is_holo: bool = false
) -> void:
	_resource = pack
	_is_holo = is_holo
	check_box.button_pressed = pack.enabled
	title_label.text = pack.pack_name
	
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
	
	holo_overlay.visible = is_holo
	add_pack_container.visible = is_holo
	menu_button.visible = not is_holo
	
	if is_holo:
		check_box.button_pressed = false
		pack.enabled = true
		check_box.disabled = true
		theme_type_variation += "Holo"


func _on_refresh_button_pressed() -> void:
	# Show spinner
	refresh_spiner.visible = true
	
	await _refresh_pack()
	
	# Hide spinner
	refresh_spiner.visible = false
	refresh_request.emit()


func _refresh_pack() -> void:
	if not _resource:
		refresh_done.emit()
		return
	
	match _resource.source:
		Constants.Source.FOLDER:
			if DirAccess.dir_exists_absolute(_resource.path):
				_resource.images = PackResource._recursive_load_dir(_resource.path)
			
		Constants.Source.IMAGES:
			# For image packs, filter out deleted files
			var valid_images: Array[Dictionary] = []
			for img in _resource.images:
				if FileAccess.file_exists(img.get("path", "")):
					valid_images.append(img)
			_resource.images = valid_images
			
		Constants.Source.PINTEREST:
			# Refresh Pinterest pack by fetching from URL
			if _resource.path.is_empty():
				push_error("PackResource path is empty!")
				refresh_done.emit()
			
			# Create a new instance for this fetch
			_pinterest_fetcher = PinterestFetcher.new()
			add_child(_pinterest_fetcher)
			
			var results: Array = await _pinterest_fetcher.fetch(
				_resource.path,
				_resource.use_pinterest_sections,
				_on_pinterest_refresh_progress
			)
			
			# Clean up the fetcher
			_pinterest_fetcher.queue_free()
			_pinterest_fetcher = null
			
			if results.is_empty():
				push_error("PinterestFetcher return is empty!")
				refresh_done.emit()
				return
			
			var pack_data = results[0]
			if pack_data.is_empty() or pack_data.get("status") != "success":
				refresh_done.emit()
				return 
			
			var data: Dictionary = pack_data.get("data", {})
			var pack_images: Array = data.get("images", [])
			
			# Convert Array to Array[Dictionary]
			var typed_images: Array[Dictionary] = []
			for img in pack_images:
				if img is Dictionary:
					typed_images.append(img)
			
			_resource.images = typed_images
	refresh_done.emit()
	
	_from_context(_resource)


func _on_pinterest_refresh_progress(message: String) -> void:
	# Update description with progress message
	decsc_label.text = message


func _on_check_box_toggled(toggled_on: bool) -> void:
	_resource.enabled = toggled_on if not _is_holo else true
	toggled.emit()


func _on_save_button_pressed() -> void:
	pass # Replace with function body.


func _on_mb_popup_id_pressed(id: int) -> void:
	match id:
		-1: return
		0: return
		1: # Refresh
			_refresh_pack()
		2: # Export
			pass
		3: # Delete
			delete_request.emit()


func _on_add_pack_button_pressed() -> void:
	add_pack_request.emit()

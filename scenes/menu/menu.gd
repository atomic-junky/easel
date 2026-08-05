class_name Menu extends Control

## Menu interface for session management, pack selection, and mode configuration.
##
## This menu supports:
## - Session creation and import (.gsession files)
## - Image pack selection from folders, images, or Pinterest
## - Session type/mode selection
## - Session export functionality

signal done(context: SessionResource)

const PACK_OBJECT: PackedScene = preload("res://prefabs/pack/pack.tscn")

var _context: SessionResource
var _context_by_type: Dictionary = {}
var _current_panel: SessionType = null

@onready var settings: Control = %Settings
@onready var import_session_dialog: FileDialog = null
@onready var save_session_dialog: FileDialog = null
@onready var main_vbox: VBoxContainer = %MainVBox
@onready var pack_container: Control = %PackContainer
@onready var tabbar: CustomTabBar = %TabBar
@onready var next_button: Button = %NextButton

## end variables


func _ready() -> void:
	if OS.get_name() in ["Android", "iOS"]:
		DisplayServer.screen_set_orientation(DisplayServer.SCREEN_PORTRAIT)
		main_vbox.add_theme_constant_override("separation",
			60
		)
	
	visibility_changed.connect(_update)
	_on_resized()
	_update()


func _on_next_button_pressed() -> void:
	tabbar.get_child(1).button_pressed = true


func _can_proceed_from_packs() -> bool:
	# Check if at least one pack is selected
	return _context and _context.packs and not _context.packs.is_empty()


func _save_current_context() -> void:
	if _current_panel and _context:
		_current_panel.save_to_context(_context)
		_context_by_type[_context.session_type] = _context


func _get_context_for(session_type: SessionResource.Type) -> SessionResource:
	if _context_by_type.has(session_type):
		return _context_by_type[session_type]
	var ctx := SessionResource.new()
	ctx.session_type = session_type
	if _context and _context.packs:
		ctx.packs = _context.packs
	_context_by_type[session_type] = ctx
	return ctx


func load_args(args: SessionResource) -> void:
	_context = args
	
	# Ensure node is ready before updating UI
	if not is_node_ready():
		await ready

	# Switch to the correct panel for this context's session type
	if _context:
		settings.load_from_context(_context)
		_update()
	else:
		_update()


func _update() -> void:
	if not is_node_ready():
		return
	if not _context:
		_context = SessionResource.new()

	if pack_container:
		for pack in pack_container.get_children():
			pack.queue_free()

	for pack: PackResource in _context.packs:
		var new_pack: Pack = PACK_OBJECT.instantiate()
		if pack_container:
			pack_container.add_child(new_pack)
		new_pack._from_context(pack)
		new_pack.delete_request.connect(_on_pack_delete_request.bind(pack))
		new_pack.toggled.connect(_update)
	
	var image_count: int = _context.get_image_count(true)
	var more_than_one_image: bool = image_count >= 1
	tabbar.disable_tab(1, not more_than_one_image)
	next_button.disabled = not more_than_one_image
	
	if _context.packs.size() <= 0:
		var margin: MarginContainer = MarginContainer.new()
		var label: Label = Label.new()
		label.text = "No pack selected"
		label.theme_type_variation = "LabelSecondary"
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		margin.add_child(label)
		pack_container.add_child(margin)

	_load_history()


func _load_history() -> void:
	var packs: Array[PackResource] = PackHistory.get_history()
	
	var packs_path: Array = _context.packs.map(func(p: PackResource): return p.path)
	var history_pack_count: int = 0
	for pack: PackResource in packs:
		if history_pack_count >= 3:
			return
		
		if pack.path in packs_path:
			continue
		
		if history_pack_count <= 0:
			var hbox: HBoxContainer = HBoxContainer.new()
			var label: Label = Label.new()
			var separator: HSeparator = HSeparator.new()
			label.text = "History"
			separator.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			hbox.add_child(separator)
			hbox.add_child(label)
			hbox.add_child(separator.duplicate())
			pack_container.add_child(hbox)
		
		var new_pack: Pack = PACK_OBJECT.instantiate()
		if pack_container:
			pack_container.add_child(new_pack)
		new_pack._from_context(pack, true)
		new_pack.add_pack_request.connect(_on_holo_add_pack.bind(pack))
		history_pack_count+=1


func _add_packs(packs: Array[PackResource]) -> void:
	for new_pack: PackResource in packs:
		if new_pack.image_count <= 0:
			packs.erase(new_pack)

	_context.packs.append_array(packs)
	
	# Add to history
	PackHistory.add_packs(packs)
	
	_update()


func _on_pack_delete_request(pack: PackResource) -> void:
	_context.packs.erase(pack)
	_update()


func _on_holo_add_pack(pack: PackResource) -> void:
	_add_packs([pack])
	_update()


func get_args() -> SessionResource:
	if _context == null:
		_context = SessionResource.new()
	settings.apply_context(_context)
	return _context


func _on_done_button_pressed() -> void:
	settings.apply_context(_context)
	_context_by_type[_context.session_type] = _context
	done.emit(_context)


func _on_resized() -> void:
	if not is_node_ready():
		return

	if size.x <= 490 + 80:
		main_vbox.custom_minimum_size.x = 0.0
		main_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		return
	
	main_vbox.custom_minimum_size.x = 490
	main_vbox.size_flags_horizontal = Control.SIZE_SHRINK_CENTER


## Session Import/Export Functions

func open_import_session_dialog() -> void:
	if import_session_dialog:
		import_session_dialog.popup_centered()


func open_save_session_dialog() -> void:
	if save_session_dialog:
		save_session_dialog.popup_centered()


#func _on_import_session_file_selected(path: String) -> void:
	#var loaded_session := SessionResource.load_from_file(path)
	#if loaded_session:
		#_context = loaded_session
		#_context_by_type[_context.session_type] = _context
		#
		## Update UI with loaded session
		#_update()
		#
		## Switch to the correct session type
		#var target_panel_index := _get_panel_index_for_type(_context.session_type)
		#if target_panel_index != _active_session_panel_index:
			#_set_switcher_index(target_panel_index)
		#else:
			## Already on correct panel, just bind and update
			#var panel := get_session_panel()
			#if panel:
				#panel.load_from_context(_context)
	#else:
		#printerr("Failed to load session from: ", path)


#func _on_save_session_file_selected(path: String) -> void:
	## Ensure we have the latest context
	#var panel := get_session_panel()
	#if panel and _context:
		#panel.save_to_context(_context)
	#
	#if _context:
		#var result := _context.save_to_file(path)
		#if result == OK:
			## Extract session name from path
			#var session_name := path.get_file().get_basename()
			#SessionHistory.add_session(session_name, path)
			#print("Session saved successfully to: ", path)


#func _on_session_history_item_pressed(path: String) -> void:
	## Load a session from history
	#_on_import_session_file_selected(path)

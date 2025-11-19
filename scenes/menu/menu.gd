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
var _active_session_panel_index: int = 0
var _session_panels: Array[SessionType] = []
var _session_type_index: Dictionary = {}
var _context_by_type: Dictionary = {}
var _current_panel: SessionType = null
var _suppress_switcher_signal: bool = false

@onready var folder_dialog: FileDialog = %FolderDialog
@onready var images_dialog: FileDialog = %ImageDialog
@onready var import_session_dialog: FileDialog = null
@onready var save_session_dialog: FileDialog = null
@onready var packs_step: Control = null
@onready var mode_step: Control = null
@onready var main_vbox: VBoxContainer = %MainVBox
@onready var session_type_switcher: OptionSwitcher = %SessionTypeSwitcher
@onready var pack_container: Control = %PackContainer
@onready var tabbar: CustomTabBar = %TabBar
@onready var done_button: Button = %DoneButton

## end variables


func _ready() -> void:
	if OS.get_name() in ["Android", "iOS"]:
		DisplayServer.screen_set_orientation(DisplayServer.SCREEN_PORTRAIT)
		main_vbox.add_theme_constant_override("separation",
			60
		)

	_create_session_dialogs()
	
	visibility_changed.connect(_update)
	_on_resized()
	_update()

	_set_switcher_index(0)


func _create_session_dialogs() -> void:
	if not import_session_dialog:
		import_session_dialog = FileDialog.new()
		import_session_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
		import_session_dialog.access = FileDialog.ACCESS_FILESYSTEM
		import_session_dialog.add_filter("*.gsession", "GestureApp Session")
		import_session_dialog.file_selected.connect(_on_import_session_file_selected)
		add_child(import_session_dialog)
	
	if not save_session_dialog:
		save_session_dialog = FileDialog.new()
		save_session_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
		save_session_dialog.access = FileDialog.ACCESS_FILESYSTEM
		save_session_dialog.add_filter("*.gsession", "GestureApp Session")
		save_session_dialog.file_selected.connect(_on_save_session_file_selected)
		add_child(save_session_dialog)


func _on_done_pressed() -> void:
	# Save current panel state to context
	var panel := get_session_panel()
	if panel and _context:
		panel.save_to_context(_context)
	
	# Emit done signal to launch session
	if _context:
		done.emit(_context)


func _can_proceed_from_packs() -> bool:
	# Check if at least one pack is selected
	return _context and _context.packs and not _context.packs.is_empty()


func _set_switcher_index(index: int) -> void:
	_switch_to_panel(index, true)


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


func _switch_to_panel(index: int, sync_switcher: bool) -> void:
	if _session_panels.is_empty():
		return

	var clamped_index: int = clampi(index, 0, _session_panels.size() - 1)
	var can_sync_switcher := (
		sync_switcher
		and session_type_switcher.is_node_ready()
		and session_type_switcher.has_method("_update_buttons")
	)
	if can_sync_switcher:
		var buttons: Array = session_type_switcher._buttons
		if clamped_index < buttons.size():
			var button: Button = buttons[clamped_index]
			if button:
				_suppress_switcher_signal = true
				session_type_switcher._programmatic_change = true
				session_type_switcher._update_buttons(button, false)
				session_type_switcher._programmatic_change = false

	_save_current_context()

	for panel in _session_panels:
		panel.hide()

	_active_session_panel_index = clamped_index
	var new_panel: SessionType = _session_panels[clamped_index]
	_context = _get_context_for(new_panel.get_context_type())

	new_panel.show()
	new_panel.load_from_context(_context)
	if new_panel.has_method("on_activated"):
		new_panel.on_activated()

	_current_panel = new_panel
	_suppress_switcher_signal = false
	_update()


func load_args(args: SessionResource) -> void:
	# Restore context when coming back from a session
	_context = args
	var previous_session_type := _context.session_type if args else SessionResource.Type.STANDARD
	if args:
		_context_by_type[args.session_type] = args

	# Ensure node is ready before updating UI
	if not is_node_ready():
		await ready

	# Switch to the correct panel for this context's session type
	if _context:
		var target_panel_index := _get_panel_index_for_type(previous_session_type)
		if target_panel_index != _active_session_panel_index:
			_set_switcher_index(target_panel_index)
		else:
			# Already on correct panel, just bind and update
			var panel := get_session_panel()
			if panel:
				panel.load_from_context(_context)
			_update()
	else:
		_update()


func _on_session_type_switcher_value_changed(value: int) -> void:
	if not is_node_ready():
		return
	if _session_panels.is_empty():
		return
	if _suppress_switcher_signal:
		_suppress_switcher_signal = false
		return

	# Save current context for its session type before switching
	if _context:
		var current := get_session_panel()
		if current:
			current.save_to_context(_context)
		_context_by_type[_context.session_type] = _context

	var index: int = clampi(value - 1, 0, _session_panels.size() - 1)
	_switch_to_panel(index, false)


func get_session_panel() -> SessionType:
	if _session_panels.is_empty():
		return null
	if _active_session_panel_index < 0 or _active_session_panel_index >= _session_panels.size():
		_active_session_panel_index = 0
	return _session_panels[_active_session_panel_index]


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
	done_button.disabled = not more_than_one_image
	
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
	var panel := get_session_panel()
	if panel:
		panel.save_to_context(_context)
	return _context


func _on_done_button_pressed() -> void:
	# Sync the context with the active panel before caching it
	var panel := get_session_panel()
	if panel:
		panel.save_to_context(_context)
	_context_by_type[_context.session_type] = _context
	done.emit(_context)


## Map SessionResource.Type to panel index
func _get_panel_index_for_type(session_type: SessionResource.Type) -> int:
	if _session_type_index.has(session_type):
		return int(_session_type_index[session_type])
	return 0


func _on_resized() -> void:
	if not is_node_ready():
		return

	if size.x <= 490 + 80:
		main_vbox.custom_minimum_size.x = 0.0
		main_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		return
	main_vbox.custom_minimum_size.x = 474.0
	main_vbox.size_flags_horizontal = Control.SIZE_SHRINK_CENTER


## Session Import/Export Functions

func open_import_session_dialog() -> void:
	if import_session_dialog:
		import_session_dialog.popup_centered()


func open_save_session_dialog() -> void:
	if save_session_dialog:
		save_session_dialog.popup_centered()


func _on_import_session_file_selected(path: String) -> void:
	var loaded_session := SessionResource.load_from_file(path)
	if loaded_session:
		_context = loaded_session
		_context_by_type[_context.session_type] = _context
		
		# Update UI with loaded session
		_update()
		
		# Switch to the correct session type
		var target_panel_index := _get_panel_index_for_type(_context.session_type)
		if target_panel_index != _active_session_panel_index:
			_set_switcher_index(target_panel_index)
		else:
			# Already on correct panel, just bind and update
			var panel := get_session_panel()
			if panel:
				panel.load_from_context(_context)
	else:
		printerr("Failed to load session from: ", path)


func _on_save_session_file_selected(path: String) -> void:
	# Ensure we have the latest context
	var panel := get_session_panel()
	if panel and _context:
		panel.save_to_context(_context)
	
	if _context:
		var result := _context.save_to_file(path)
		if result == OK:
			# Extract session name from path
			var session_name := path.get_file().get_basename()
			SessionHistory.add_session(session_name, path)
			print("Session saved successfully to: ", path)


func _on_session_history_item_pressed(path: String) -> void:
	# Load a session from history
	_on_import_session_file_selected(path)

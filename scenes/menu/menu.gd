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
var _pinterest_fetcher: PinterestFetcher
var _stepper: MenuStepper = null
var _current_step_container: Control = null

@onready var folder_dialog: FileDialog = %FolderDialog
@onready var images_dialog: FileDialog = %ImageDialog
@onready var import_session_dialog: FileDialog = null
@onready var save_session_dialog: FileDialog = null
@onready var session_step: Control = null
@onready var packs_step: Control = null
@onready var mode_step: Control = null
@onready var main_vbox: VBoxContainer = %MainVBox
@onready var info_label: Label = %InfoLabel
@onready var session_type_switcher: OptionSwitcher = %SessionTypeSwitcher
@onready var session_panel_container: VBoxContainer = (
	session_type_switcher.get_parent().get_node("Panel/VBox")
)
@onready var pack_selector: Control = %PackSelectorContainer
@onready var pack_container: Control = %PackContainer
@onready var dimer: ColorRect = %Dimer
@onready var url_container: Control = %UrlContainer
@onready var url_vbox: VBoxContainer = %UrlVBox
@onready var url_label: Label = %UrlLabel
@onready var url_input_container: Control = %UrlInputContainer
@onready var url_input: LineEdit = %UrlInput
@onready var url_input_spiner_container: Control = %UrlInputSpinerContainer
@onready var pinterest_section_chech_box: CheckBox = %PinterestSectionCheckBox
@onready var history_container: Control = %HistoryContainer
@onready var history_scroll: ScrollContainer = %HistoryScroll
@onready var history_pack_list: VBoxContainer = %HistoryPackList

## end variables


func _ready() -> void:
	if OS.get_name() in ["Android", "iOS"]:
		DisplayServer.screen_set_orientation(DisplayServer.SCREEN_PORTRAIT)
		main_vbox.add_theme_constant_override("separation",
			60
		)

	_initialize_session_panels()
	_create_session_dialogs()
	
	_setup_stepper()
	
	visibility_changed.connect(_update)
	_on_resized()
	
	# Connect dimer click to close overlays
	dimer.gui_input.connect(_on_dimer_input)

	if _session_panels.is_empty():
		_update()
		return

	_set_switcher_index(0)


func _on_dimer_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			# Close any open overlay
			if url_container.visible:
				dimer.hide()
				url_container.hide()
			elif history_container.visible:
				_on_history_cancel_pressed()


func _initialize_session_panels() -> void:
	_session_panels.clear()
	_session_type_index.clear()
	if session_panel_container == null:
		return

	for child in session_panel_container.get_children():
		if child is SessionType:
			var panel: SessionType = child
			panel.hide()
			_session_panels.append(panel)
			_session_type_index[panel.get_context_type()] = _session_panels.size() - 1

	if _session_panels.is_empty():
		return

	var options: Array[OptionData] = []
	for i in _session_panels.size():
		var mode_name := _session_panels[i].get_mode_name()
		var option: OptionData = OptionData.new(mode_name, i + 1, true)
		options.append(option)

	session_type_switcher.use_dynamic_options = true
	session_type_switcher.set_options_array(options)


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


func _setup_stepper() -> void:
	# Get the stepper and step containers
	_stepper = %MenuStepper
	if not _stepper:
		push_warning("MenuStepper not found in scene")
		return
	
	_current_step_container = %StepContainer
	session_step = %SessionStep
	packs_step = %PacksStep
	mode_step = %ModeStep
	
	# Connect stepper signals
	_stepper.step_changed.connect(_on_step_changed)
	_stepper.step_completed.connect(_on_step_completed)
	
	# Connect Session step buttons
	var new_session_btn = session_step.get_node_or_null("ButtonsGrid/NewSessionButton")
	if new_session_btn:
		new_session_btn.pressed.connect(_on_new_session_pressed)
	
	var import_session_btn = session_step.get_node_or_null("ButtonsGrid/ImportSessionButton")
	if import_session_btn:
		import_session_btn.pressed.connect(open_import_session_dialog)
	
	# Connect Packs step source buttons (integrated directly in the step)
	var folder_btn = packs_step.get_node_or_null("ContentHBox/SourcesPanel/FolderButton")
	if folder_btn:
		folder_btn.pressed.connect(_on_folder_button_pressed)
	
	var images_btn = packs_step.get_node_or_null("ContentHBox/SourcesPanel/ImagesButton")
	if images_btn:
		images_btn.pressed.connect(_on_images_button_pressed)
	
	var pinterest_btn = packs_step.get_node_or_null("ContentHBox/SourcesPanel/PinterestButton")
	if pinterest_btn:
		pinterest_btn.pressed.connect(_on_pinterest_button_pressed)
	
	var history_btn = packs_step.get_node_or_null("ContentHBox/SourcesPanel/HistoryButton")
	if history_btn:
		history_btn.pressed.connect(_on_history_button_pressed)
	
	var clear_btn = packs_step.get_node_or_null("ContentHBox/PacksPanel/HBoxContainer/ClearButton")
	if clear_btn:
		clear_btn.pressed.connect(_on_clear_button_pressed)
	
	var packs_prev_btn = packs_step.get_node_or_null("NavigationButtons/PreviousButton")
	if packs_prev_btn:
		packs_prev_btn.pressed.connect(_on_packs_previous_pressed)
	
	var packs_next_btn = packs_step.get_node_or_null("NavigationButtons/NextButton")
	if packs_next_btn:
		packs_next_btn.pressed.connect(_on_packs_next_pressed)
	
	# Connect Mode step navigation
	var mode_prev_btn = mode_step.get_node_or_null("PreviousButton")
	if mode_prev_btn:
		mode_prev_btn.pressed.connect(_on_mode_previous_pressed)
	
	var done_btn = mode_step.get_node_or_null("Panel/VBox/DoneButtonContiainer/DoneButton")
	if done_btn:
		done_btn.pressed.connect(_on_done_pressed)
	
	# Show initial step
	_show_step(0)


func _show_step(step_index: int) -> void:
	# Hide all steps
	if session_step:
		session_step.hide()
	if packs_step:
		packs_step.hide()
	if mode_step:
		mode_step.hide()
	
	# Show current step
	match step_index:
		0:
			if session_step:
				session_step.show()
		1:
			if packs_step:
				packs_step.show()
		2:
			if mode_step:
				mode_step.show()


func _on_step_changed(step_index: int) -> void:
	_show_step(step_index)
	_update()


func _on_step_completed(_step_index: int) -> void:
	# Handle step completion if needed
	pass


func _on_packs_previous_pressed() -> void:
	if _stepper:
		_stepper.go_to_previous_step()


func _on_packs_next_pressed() -> void:
	if not _can_proceed_from_packs():
		push_warning("Cannot proceed: No packs selected")
		return
	
	if _stepper:
		_stepper.go_to_next_step()


func _on_mode_previous_pressed() -> void:
	if _stepper:
		_stepper.go_to_previous_step()


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


func _on_new_session_pressed() -> void:
	# Reset to a new session
	_context = SessionResource.new()
	_context_by_type.clear()
	
	# Clear packs
	if pack_container:
		for pack_node in pack_container.get_children():
			pack_node.queue_free()
	
	# Unlock and go to packs step
	if _stepper:
		_stepper.unlock_next_step()
		_stepper.go_to_next_step()
	
	_update()


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
	if _session_panels.is_empty():
		_initialize_session_panels()

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

	# Guard: pack_container might not be ready if called too early
	if pack_container:
		for pack in pack_container.get_children():
			pack.queue_free()

	for pack: PackResource in _context.packs:
		var new_pack: Pack = PACK_OBJECT.instantiate()
		if pack_container:
			pack_container.add_child(new_pack)
		new_pack._from_context(pack)
		new_pack.delete_request.connect(_on_pack_delete_request.bind(pack))
		new_pack.toggled.connect(_on_pack_toggled.bind(pack))

	var panel := get_session_panel()
	var valid := false
	if panel and panel.has_method("is_valid"):
		valid = panel.is_valid()
	
	# Update done button state in ModeStep if we're on that step
	if _stepper and _stepper.current_step == 2 and mode_step:
		var done_btn = mode_step.get_node_or_null("Panel/VBox/DoneButtonContiainer/DoneButton")
		if done_btn:
			done_btn.disabled = not valid or _context.get_image_count() <= 0

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


func _add_packs(packs: Array[PackResource]) -> void:
	for new_pack: PackResource in packs:
		if new_pack.image_count <= 0:
			packs.erase(new_pack)

	_context.packs.append_array(packs)
	
	# Add to history
	PackHistory.add_packs(packs)
	
	# Unlock next step if we're on packs step and have packs
	if _stepper and _stepper.current_step == 1 and _can_proceed_from_packs():
		_stepper.unlock_next_step()
	
	_update()


func _on_pack_delete_request(pack: PackResource) -> void:
	_context.packs.erase(pack)
	_update()


func _on_pack_toggled(_pack: PackResource) -> void:
	_update_labels()


func get_args() -> SessionResource:
	if _context == null:
		_context = SessionResource.new()
	var panel := get_session_panel()
	if panel:
		panel.save_to_context(_context)
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


func _on_history_button_pressed() -> void:
	dimer.show()
	history_container.show()
	_populate_history_list()


func _populate_history_list() -> void:
	# Clear existing items
	for child in history_pack_list.get_children():
		child.queue_free()
	
	var history: Array[PackResource] = PackHistory.get_history()
	
	if history.is_empty():
		var empty_label := Label.new()
		empty_label.text = "No packs in history"
		empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		history_pack_list.add_child(empty_label)
		return
	
	# Create Pack instances for each pack in history
	for pack in history:
		var pack_node: Pack = PACK_OBJECT.instantiate()
		history_pack_list.add_child(pack_node)
		# Show refresh button, hide delete button in history view
		pack_node._from_context(pack, false, true)
		# Pack handles refresh internally, no need to connect the signal


func _on_history_add_selected_pressed() -> void:
	var selected_packs: Array[PackResource] = []
	
	for pack_node in history_pack_list.get_children():
		if pack_node is Pack and pack_node.check_box.button_pressed:
			var index := pack_node.get_index()
			var history := PackHistory.get_history()
			if index < history.size():
				selected_packs.append(history[index])
	
	if not selected_packs.is_empty():
		_add_packs(selected_packs)
	
	_on_history_cancel_pressed()


func _on_history_cancel_pressed() -> void:
	dimer.hide()
	history_container.hide()


func _on_history_select_all_pressed() -> void:
	for pack_node in history_pack_list.get_children():
		if pack_node is Pack:
			pack_node.check_box.button_pressed = true


func _on_history_select_none_pressed() -> void:
	for pack_node in history_pack_list.get_children():
		if pack_node is Pack:
			pack_node.check_box.button_pressed = false


func _on_folder_dialog_dir_selected(dir: String) -> void:
	_add_packs(PackResource.create_from_path(dir))


func _on_image_dialog_files_selected(paths: PackedStringArray) -> void:
	_add_packs(PackResource.create_from_paths(paths))


func _on_clear_button_pressed() -> void:
	_context.packs.clear()
	_update()


func _on_url_done_button_pressed() -> void:
	url_input_container.hide()
	url_input_spiner_container.show()
	pinterest_section_chech_box.disabled = true

	var use_sections := pinterest_section_chech_box.button_pressed
	
	# Create a new instance for this fetch
	_pinterest_fetcher = PinterestFetcher.new()
	add_child(_pinterest_fetcher)
	
	var results: Array = await _pinterest_fetcher.fetch(
		url_input.text,
		use_sections,
		_on_url_fetcher_progress_callback
	)
	
	# Clean up the fetcher
	_pinterest_fetcher.queue_free()
	_pinterest_fetcher = null

	url_input_spiner_container.hide()
	url_input_container.show()
	dimer.hide()
	url_container.hide()
	pinterest_section_chech_box.disabled = false

	for pack in results:
		if pack.is_empty() or pack.get("status") != "success":
			printerr(pack.get("data", "Fetching failure (no data)"))
			return
		
		var pack_resource: PackResource = PackResource.create_from_urls(
			pack.get("data", {}),
			use_sections
		)
		_add_packs([pack_resource])
	_update()


func _on_url_fetcher_progress_callback(message: String) -> void:
	url_label.text = message

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
		url_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		url_vbox.custom_minimum_size.x = 0.0
		return
	main_vbox.custom_minimum_size.x = 474.0
	main_vbox.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	url_container.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	url_vbox.custom_minimum_size.x = 400.0


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
		
		# Unlock next step and advance if on session step
		if _stepper and _stepper.current_step == 0:
			_stepper.unlock_next_step()
			_stepper.go_to_next_step()
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

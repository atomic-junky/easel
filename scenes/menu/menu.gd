class_name Menu extends Control

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
var _use_tabs: bool = true  # Enable tab-based interface
var _tab_container: TabContainer = null
var _original_property_container: Control = null

@onready var folder_dialog: FileDialog = %FolderDialog
@onready var images_dialog: FileDialog = %ImageDialog
@onready var import_session_dialog: FileDialog = null  # Will be created dynamically
@onready var save_session_dialog: FileDialog = null  # Will be created dynamically
@onready var main_vbox: VBoxContainer = %MainVBox
@onready var info_label: Label = %InfoLabel
@onready var session_type_switcher: OptionSwitcher = %SessionTypeSwitcher
@onready var done_button: Button = %DoneButton
@onready var session_panel_container: VBoxContainer = (
	session_type_switcher.get_parent().get_node("Panel/VBox")
)
@onready var pack_selector: Control = %PackSelectorContainer
@onready var pack_selector_panel: PanelContainer = %PackSelectorPanel
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
	
	# Restructure UI into tabs if enabled
	if _use_tabs:
		_create_tabbed_interface()
	
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
	# Create Import Session Dialog
	import_session_dialog = FileDialog.new()
	import_session_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	import_session_dialog.access = FileDialog.ACCESS_FILESYSTEM
	import_session_dialog.add_filter("*.gsession", "GestureApp Session")
	import_session_dialog.file_selected.connect(_on_import_session_file_selected)
	add_child(import_session_dialog)
	
	# Create Save Session Dialog
	save_session_dialog = FileDialog.new()
	save_session_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	save_session_dialog.access = FileDialog.ACCESS_FILESYSTEM
	save_session_dialog.add_filter("*.gsession", "GestureApp Session")
	save_session_dialog.file_selected.connect(_on_save_session_file_selected)
	add_child(save_session_dialog)


func _create_tabbed_interface() -> void:
	# Find the PropertyContainer (the main content area)
	var property_container := main_vbox.get_node_or_null("PropertyContainer")
	if not property_container:
		printerr("Could not find PropertyContainer for tabbed interface")
		return
	
	_original_property_container = property_container
	var parent := property_container.get_parent()
	var index := property_container.get_index()
	
	# Create TabContainer
	_tab_container = TabContainer.new()
	_tab_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	
	# Remove PropertyContainer from parent
	parent.remove_child(property_container)
	
	# Add TabContainer in its place
	parent.add_child(_tab_container)
	parent.move_child(_tab_container, index)
	
	# Create Tab 1: Session Management
	_create_session_tab()
	
	# Create Tab 2: Pack Selection (contains the pack selector UI)
	_create_pack_selection_tab(property_container)
	
	# Create Tab 3: Mode Selection (contains session type switcher)
	_create_mode_selection_tab(property_container)


func _create_session_tab() -> void:
	var tab := VBoxContainer.new()
	tab.name = "Session"
	tab.add_theme_constant_override("separation", 15)
	_tab_container.add_child(tab)
	
	# Title
	var title_label := Label.new()
	title_label.text = "Session Management"
	title_label.add_theme_font_size_override("font_size", 20)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tab.add_child(title_label)
	
	# Buttons HBox
	var button_hbox := HBoxContainer.new()
	button_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	button_hbox.add_theme_constant_override("separation", 10)
	tab.add_child(button_hbox)
	
	# New Session Button
	var new_session_btn := Button.new()
	new_session_btn.text = "New Session"
	new_session_btn.pressed.connect(_on_new_session_pressed)
	button_hbox.add_child(new_session_btn)
	
	# Import Session Button
	var import_session_btn := Button.new()
	import_session_btn.text = "Import Session"
	import_session_btn.pressed.connect(open_import_session_dialog)
	button_hbox.add_child(import_session_btn)
	
	# Session History Label
	var history_label := Label.new()
	history_label.text = "Previous Sessions"
	history_label.add_theme_font_size_override("font_size", 16)
	tab.add_child(history_label)
	
	# Scroll container for session history
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tab.add_child(scroll)
	
	var history_list := VBoxContainer.new()
	history_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	history_list.add_theme_constant_override("separation", 5)
	scroll.add_child(history_list)
	
	# Populate session history
	_populate_session_history_in_tab(history_list)
	
	# Next Button
	var next_btn := Button.new()
	next_btn.text = "Next: Select Packs →"
	next_btn.pressed.connect(_on_session_tab_next_pressed)
	tab.add_child(next_btn)


func _create_pack_selection_tab(original_container: Control) -> void:
	var tab := VBoxContainer.new()
	tab.name = "Packs"
	tab.add_theme_constant_override("separation", 15)
	_tab_container.add_child(tab)
	
	# Title
	var title_label := Label.new()
	title_label.text = "Select Image Packs"
	title_label.add_theme_font_size_override("font_size", 20)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tab.add_child(title_label)
	
	# Move the pack selection UI (VBox with SelectPackButton) here
	var vbox := original_container.get_node_or_null("VBox")
	if vbox:
		original_container.remove_child(vbox)
		tab.add_child(vbox)
	
	# Add a section for pack history
	var history_label := Label.new()
	history_label.text = "Recent Packs (click to add)"
	tab.add_child(history_label)
	
	var pack_history_scroll := ScrollContainer.new()
	pack_history_scroll.custom_minimum_size = Vector2(0, 150)
	tab.add_child(pack_history_scroll)
	
	var pack_history_list := VBoxContainer.new()
	pack_history_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pack_history_list.add_theme_constant_override("separation", 5)
	pack_history_scroll.add_child(pack_history_list)
	
	# Populate pack history
	_populate_pack_history_in_tab(pack_history_list)
	
	# Navigation buttons
	var nav_hbox := HBoxContainer.new()
	nav_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	nav_hbox.add_theme_constant_override("separation", 10)
	tab.add_child(nav_hbox)
	
	var prev_btn := Button.new()
	prev_btn.text = "← Previous"
	prev_btn.pressed.connect(_on_pack_tab_prev_pressed)
	nav_hbox.add_child(prev_btn)
	
	var next_btn := Button.new()
	next_btn.text = "Next: Select Mode →"
	next_btn.pressed.connect(_on_pack_tab_next_pressed)
	nav_hbox.add_child(next_btn)


func _create_mode_selection_tab(original_container: Control) -> void:
	var tab := VBoxContainer.new()
	tab.name = "Mode"
	tab.add_theme_constant_override("separation", 15)
	_tab_container.add_child(tab)
	
	# Title
	var title_label := Label.new()
	title_label.text = "Select Session Mode"
	title_label.add_theme_font_size_override("font_size", 20)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tab.add_child(title_label)
	
	# Move SessionTypeSwitcher and Panel to this tab
	var switcher := original_container.get_node_or_null("SessionTypeSwitcher")
	var panel := original_container.get_node_or_null("Panel")
	
	if switcher:
		original_container.remove_child(switcher)
		tab.add_child(switcher)
	
	if panel:
		original_container.remove_child(panel)
		tab.add_child(panel)
	
	# Add Save Session button
	var save_btn := Button.new()
	save_btn.text = "💾 Save Session"
	save_btn.pressed.connect(open_save_session_dialog)
	tab.add_child(save_btn)
	
	# Navigation buttons
	var nav_hbox := HBoxContainer.new()
	nav_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	nav_hbox.add_theme_constant_override("separation", 10)
	tab.add_child(nav_hbox)
	
	var prev_btn := Button.new()
	prev_btn.text = "← Previous"
	prev_btn.pressed.connect(_on_mode_tab_prev_pressed)
	nav_hbox.add_child(prev_btn)


func _populate_session_history_in_tab(container: VBoxContainer) -> void:
	# Clear existing items
	for child in container.get_children():
		child.queue_free()
	
	var history := SessionHistory.get_history()
	
	if history.is_empty():
		var empty_label := Label.new()
		empty_label.text = "No previous sessions"
		empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		container.add_child(empty_label)
		return
	
	# Create buttons for each session in history
	for entry in history:
		var btn := Button.new()
		btn.text = entry.get("name", "Unknown")
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.pressed.connect(_on_session_history_item_pressed.bind(entry.get("path", "")))
		container.add_child(btn)


func _populate_pack_history_in_tab(container: VBoxContainer) -> void:
	# Clear existing items
	for child in container.get_children():
		child.queue_free()
	
	var history: Array[PackResource] = PackHistory.get_history()
	
	if history.is_empty():
		var empty_label := Label.new()
		empty_label.text = "No packs in history"
		empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		container.add_child(empty_label)
		return
	
	# Create buttons for recent packs (limit to 5)
	var max_display := 5
	for i in mini(history.size(), max_display):
		var pack := history[i]
		var btn := Button.new()
		btn.text = "%s (%d images)" % [pack.pack_name, pack.image_count]
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.pressed.connect(_on_pack_history_add_pressed.bind(pack))
		container.add_child(btn)


# Tab navigation handlers
func _on_session_tab_next_pressed() -> void:
	if _tab_container:
		_tab_container.current_tab = 1  # Go to Packs tab


func _on_pack_tab_prev_pressed() -> void:
	if _tab_container:
		_tab_container.current_tab = 0  # Go to Session tab


func _on_pack_tab_next_pressed() -> void:
	if _tab_container:
		_tab_container.current_tab = 2  # Go to Mode tab


func _on_mode_tab_prev_pressed() -> void:
	if _tab_container:
		_tab_container.current_tab = 1  # Go to Packs tab


func _on_new_session_pressed() -> void:
	# Reset to a new session
	_context = SessionResource.new()
	_context_by_type.clear()
	
	# Clear packs
	if pack_container:
		for pack_node in pack_container.get_children():
			pack_node.queue_free()
	
	# Go to packs tab
	if _tab_container:
		_tab_container.current_tab = 1
	
	_update()


func _on_pack_history_add_pressed(pack: PackResource) -> void:
	# Add pack from history to current session
	_add_packs([pack])


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


func _on_select_pack_button_pressed() -> void:
	pack_selector.show()


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
	done_button.disabled = not valid
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


func _on_pack_done_button_pressed() -> void:
	pack_selector.hide()


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
		pack_selector_panel.custom_minimum_size.x = 0.0
		pack_selector_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		url_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		url_vbox.custom_minimum_size.x = 0.0
		return
	main_vbox.custom_minimum_size.x = 474.0
	main_vbox.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	pack_selector_panel.custom_minimum_size.x = 650.0
	pack_selector_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
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
	# Switch to packs tab after loading
	if _tab_container:
		_tab_container.current_tab = 1

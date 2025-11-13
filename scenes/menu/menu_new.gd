extends Control

## Main menu controller with tabbed navigation
## Manages session, pack, and mode selection with validation

signal done(context: SessionResource)

var _context: SessionResource

@onready var tab_container: TabContainer = %TabContainer
@onready var tab_session: Control = %TabSession
@onready var tab_packs: Control = %TabPacks
@onready var tab_mode: Control = %TabMode
@onready var next_button: Button = %NextButton
@onready var prev_button: Button = %PrevButton
@onready var done_button: Button = %DoneButton
@onready var save_session_button: Button = %SaveSessionButton
@onready var save_session_dialog: FileDialog = null


func _ready() -> void:
	if OS.get_name() in ["Android", "iOS"]:
		DisplayServer.screen_set_orientation(DisplayServer.SCREEN_PORTRAIT)
	
	_context = SessionResource.new()
	
	# Create save session dialog
	save_session_dialog = FileDialog.new()
	save_session_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	save_session_dialog.access = FileDialog.ACCESS_FILESYSTEM
	save_session_dialog.add_filter("*.gsession", "GestureApp Session")
	save_session_dialog.file_selected.connect(_on_save_session_file_selected)
	add_child(save_session_dialog)
	
	# Connect tab signals
	tab_session.session_selected.connect(_on_session_selected)
	tab_session.new_session_requested.connect(_on_new_session_requested)
	tab_packs.packs_changed.connect(_on_packs_changed)
	tab_mode.mode_changed.connect(_on_mode_changed)
	
	# Connect navigation buttons
	next_button.pressed.connect(_on_next_pressed)
	prev_button.pressed.connect(_on_prev_pressed)
	done_button.pressed.connect(_on_done_pressed)
	save_session_button.pressed.connect(_on_save_session_pressed)
	
	# Connect tab change
	tab_container.tab_changed.connect(_on_tab_changed)
	
	# Initialize context in tabs
	tab_packs.set_context(_context)
	tab_mode.set_context(_context)
	
	# Initial UI update
	_update_navigation_buttons()


func _on_tab_changed(_tab: int) -> void:
	_update_navigation_buttons()


func _update_navigation_buttons() -> void:
	var current_tab := tab_container.current_tab
	
	# Update button visibility
	prev_button.visible = current_tab > 0
	
	# Show/hide next/done based on tab
	if current_tab < 2:
		next_button.visible = true
		done_button.visible = false
		save_session_button.visible = false
	else:
		next_button.visible = false
		done_button.visible = true
		save_session_button.visible = true
	
	# Enable/disable next button based on validation
	match current_tab:
		0:  # Session tab
			next_button.disabled = not tab_session.is_valid()
		1:  # Packs tab
			next_button.disabled = not tab_packs.is_valid()
		2:  # Mode tab
			done_button.disabled = not tab_mode.is_valid() or not tab_packs.is_valid()


func _on_next_pressed() -> void:
	var current_tab := tab_container.current_tab
	
	# Validate current tab before proceeding
	var is_valid := false
	match current_tab:
		0:
			is_valid = tab_session.is_valid()
		1:
			is_valid = tab_packs.is_valid()
	
	if is_valid and current_tab < 2:
		tab_container.current_tab = current_tab + 1


func _on_prev_pressed() -> void:
	var current_tab := tab_container.current_tab
	if current_tab > 0:
		tab_container.current_tab = current_tab - 1


func _on_session_selected(path: String) -> void:
	var loaded_session := SessionResource.load_from_file(path)
	if loaded_session:
		_context = loaded_session
		tab_packs.set_context(_context)
		tab_mode.set_context(_context)
		# Move to packs tab
		tab_container.current_tab = 1


func _on_new_session_requested() -> void:
	_context = SessionResource.new()
	tab_packs.clear_packs()
	tab_packs.set_context(_context)
	tab_mode.set_context(_context)
	# Move to packs tab
	tab_container.current_tab = 1


func _on_packs_changed() -> void:
	_update_navigation_buttons()


func _on_mode_changed() -> void:
	_update_navigation_buttons()


func _on_save_session_pressed() -> void:
	save_session_dialog.popup_centered()


func _on_save_session_file_selected(path: String) -> void:
	# Ensure we have the latest context
	_context = tab_mode.get_context()
	
	if _context:
		var result := _context.save_to_file(path)
		if result == OK:
			var session_name := path.get_file().get_basename()
			SessionHistory.add_session(session_name, path)
			tab_session.refresh_history()
			print("Session saved successfully to: ", path)


func _on_done_pressed() -> void:
	# Get final context from mode tab
	_context = tab_mode.get_context()
	done.emit(_context)


func load_args(args: SessionResource) -> void:
	# Restore context when coming back from a session
	if args:
		_context = args
		tab_packs.set_context(_context)
		tab_mode.set_context(_context)


func get_args() -> SessionResource:
	return tab_mode.get_context()

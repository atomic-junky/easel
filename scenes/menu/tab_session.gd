extends VBoxContainer

## Tab 1: Session Management
## Handles new session creation, session import, and session history

signal session_selected(session_path: String)
signal new_session_requested

var _history_list: VBoxContainer

@onready var new_session_btn: Button = %NewSessionButton
@onready var import_session_btn: Button = %ImportSessionButton
@onready var session_history_container: VBoxContainer = %SessionHistoryContainer


func _ready() -> void:
	new_session_btn.pressed.connect(_on_new_session_pressed)
	import_session_btn.pressed.connect(_on_import_session_pressed)
	_populate_session_history()


func _populate_session_history() -> void:
	# Clear existing items
	for child in session_history_container.get_children():
		child.queue_free()
	
	var history := SessionHistory.get_history()
	
	if history.is_empty():
		var empty_label := Label.new()
		empty_label.text = "No previous sessions"
		empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		session_history_container.add_child(empty_label)
		return
	
	# Create buttons for each session in history
	for entry in history:
		var btn := Button.new()
		btn.text = entry.get("name", "Unknown")
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.pressed.connect(_on_session_history_item_pressed.bind(entry.get("path", "")))
		session_history_container.add_child(btn)


func _on_new_session_pressed() -> void:
	new_session_requested.emit()


func _on_import_session_pressed() -> void:
	# Create and show file dialog
	var dialog := FileDialog.new()
	dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	dialog.access = FileDialog.ACCESS_FILESYSTEM
	dialog.add_filter("*.gsession", "GestureApp Session")
	dialog.file_selected.connect(_on_import_file_selected)
	add_child(dialog)
	dialog.popup_centered()


func _on_import_file_selected(path: String) -> void:
	session_selected.emit(path)


func _on_session_history_item_pressed(path: String) -> void:
	session_selected.emit(path)


func is_valid() -> bool:
	# Session tab is always valid - user can proceed to pack selection
	return true


func refresh_history() -> void:
	_populate_session_history()

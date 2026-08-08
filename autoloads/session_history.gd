extends Node

## Autoload singleton that manages session history.
##
## Tracks the last 10 saved sessions (.gsession files) for quick access.
## History is stored as JSON in user://session_history/sessions.json
##
## Usage:
##   SessionHistory.add_session("My Session", "user://sessions/my_session.gsession")
##   var history := SessionHistory.get_history()  # Returns Array[Dictionary]
##   for entry in history:
##       print(entry["name"], " at ", entry["path"])

const MAX_HISTORY_SIZE := 10
const HISTORY_DIR := "user://session_history/"

var _history: Array[Dictionary] = []  # Array of {name: String, path: String, timestamp: int}


func _ready() -> void:
	# Create history directory if it doesn't exist
	if not DirAccess.dir_exists_absolute(HISTORY_DIR):
		DirAccess.make_dir_recursive_absolute(HISTORY_DIR)
	_load_history()


## Add a session to history (most recent first)
func add_session(session_name: String, session_path: String) -> void:
	print("[SessionHistory] add_session called for: ", session_name)
	
	if session_name.is_empty() or session_path.is_empty():
		print("[SessionHistory] Session rejected: empty name or path")
		return
	
	# Remove duplicate if already exists (compare by path)
	_history = _history.filter(func(item: Dictionary) -> bool:
		return item.get("path", "") != session_path
	)
	
	# Add to front
	var entry := {
		"name": session_name,
		"path": session_path,
		"timestamp": Time.get_unix_time_from_system()
	}
	_history.push_front(entry)
	
	if _history.size() > MAX_HISTORY_SIZE:
		_history.resize(MAX_HISTORY_SIZE)
	
	_save_history()


## Get history as array of dictionaries
func get_history() -> Array[Dictionary]:
	# Filter out sessions that no longer exist
	var result: Array[Dictionary] = []
	for entry in _history:
		var path: String = entry.get("path", "")
		if FileAccess.file_exists(path):
			result.append(entry)
	return result


## Get number of items in history
func get_history_count() -> int:
	return _history.size()


## Clear all history
func clear_history() -> void:
	_history.clear()
	_save_history()


## Load history from JSON file
func _load_history() -> void:
	_history.clear()
	
	var history_file_path := HISTORY_DIR + "sessions.json"
	if not FileAccess.file_exists(history_file_path):
		print("[SessionHistory] No history file found")
		return
	
	var file := FileAccess.open(history_file_path, FileAccess.READ)
	if not file:
		printerr("[SessionHistory] Failed to open history file")
		return
	
	var json_text := file.get_as_text()
	file.close()
	
	var json := JSON.new()
	var parse_result := json.parse(json_text)
	if parse_result != OK:
		printerr("[SessionHistory] Failed to parse history JSON")
		return
	
	var data = json.get_data()
	if data is Array:
		for item in data:
			if item is Dictionary:
				_history.append(item)
	
	print("[SessionHistory] Loaded ", _history.size(), " sessions from history")


## Save history to JSON file
func _save_history() -> void:
	print("[SessionHistory] Saving ", _history.size(), " sessions to history")
	
	var history_file_path := HISTORY_DIR + "sessions.json"
	var file := FileAccess.open(history_file_path, FileAccess.WRITE)
	if not file:
		printerr("[SessionHistory] Failed to create history file")
		return
	
	var json_text := JSON.stringify(_history, "\t")
	file.store_string(json_text)
	file.close()
	
	print("[SessionHistory] History saved successfully")

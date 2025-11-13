extends Node

## Manages pack history - stores the last 10 packs used by the user

const MAX_HISTORY_SIZE := 10
const HISTORY_DIR := "user://pack_history/"

var _history: Array[PackResource] = []


func _ready() -> void:
	# Create history directory if it doesn't exist
	if not DirAccess.dir_exists_absolute(HISTORY_DIR):
		DirAccess.make_dir_recursive_absolute(HISTORY_DIR)
	_load_history()


## Add a pack to history (most recent first)
func add_pack(pack: PackResource, save_immediately: bool = true) -> void:
	print("[PackHistory] add_pack called for: ", pack.pack_name,
		" save_immediately=", save_immediately)
	
	if not pack or pack.image_count <= 0:
		print("[PackHistory] Pack rejected: no images")
		return
	
	# Create a new resource copy to avoid reference issues
	var pack_copy := PackResource.new()
	pack_copy.enabled = pack.enabled
	pack_copy.source = pack.source
	pack_copy.pack_name = pack.pack_name
	pack_copy.path = pack.path
	pack_copy.images = pack.images.duplicate(true)
	pack_copy.use_pinterest_sections = pack.use_pinterest_sections
	
	print("[PackHistory] Current history size before filter: ", _history.size())
	
	# Remove duplicate if already exists (compare by path and source)
	_history = _history.filter(func(item: PackResource) -> bool:
		return not (item.path == pack_copy.path and item.source == pack_copy.source)
	)
	
	print("[PackHistory] History size after filter: ", _history.size())
	
	# Add to front
	_history.push_front(pack_copy)
	print("[PackHistory] History size after push_front: ", _history.size())
	
	if _history.size() > MAX_HISTORY_SIZE:
		_history.resize(MAX_HISTORY_SIZE)
	
	if save_immediately:
		_save_history()


## Add multiple packs to history
func add_packs(packs: Array[PackResource]) -> void:
	for pack in packs:
		add_pack(pack, false)  # Don't save after each pack
	_save_history()  # Save once at the end


## Get history as array of PackResource
func get_history() -> Array[PackResource]:
	# Filter out packs that no longer exist
	var result: Array[PackResource] = []
	for pack in _history:
		if _validate_pack_exists(pack):
			result.append(pack)
	return result


## Get number of items in history
func get_history_count() -> int:
	return _history.size()


## Clear all history
func clear_history() -> void:
	_history.clear()
	_clear_history_files()


## Check if a pack's source still exists
func _validate_pack_exists(pack: PackResource) -> bool:
	if pack.source == Constants.Source.FOLDER:
		return DirAccess.dir_exists_absolute(pack.path)
	if pack.source == Constants.Source.IMAGES:
		return FileAccess.file_exists(pack.path)
	if pack.source == Constants.Source.PINTEREST:
		# Pinterest packs can't be validated, assume they exist
		return true
	return false


## Load history from saved resource files
func _load_history() -> void:
	_history.clear()
	
	# Load the index file
	var index_path := HISTORY_DIR + "index.tres"
	if not FileAccess.file_exists(index_path):
		print("[PackHistory] No index file found at: ", index_path)
		return
	
	var index := ResourceLoader.load(index_path, "", ResourceLoader.CACHE_MODE_IGNORE) as HistoryIndex
	if not index:
		print("[PackHistory] Failed to load index file - file may be corrupted")
		print("[PackHistory] Attempting to clear corrupted history files...")
		_clear_history_files()
		print("[PackHistory] History cleared. New history will be created on next pack addition.")
		return
	
	if index.pack_files == null or index.pack_files.is_empty():
		print("[PackHistory] Index file is empty")
		return
	
	print("[PackHistory] Loading ", index.pack_files.size(), " packs from history")
	
	for pack_file in index.pack_files:
		var pack_path: String = HISTORY_DIR.path_join(pack_file)
		if FileAccess.file_exists(pack_path):
			var pack := ResourceLoader.load(pack_path, "", ResourceLoader.CACHE_MODE_IGNORE) as PackResource
			if pack:
				# Refresh folder-based packs to get current file list
				if pack.source == Constants.Source.FOLDER:
					if DirAccess.dir_exists_absolute(pack.path):
						pack.images = PackResource._recursive_load_dir(pack.path)
				
				print("[PackHistory] Loaded pack: ", pack.pack_name, " with ", pack.image_count, " images")
				_history.append(pack)
			else:
				print("[PackHistory] Failed to load pack from: ", pack_path)
		else:
			print("[PackHistory] Pack file not found: ", pack_path)
	
	print("[PackHistory] Total packs loaded: ", _history.size())


## Save history as resource files
func _save_history() -> void:
	print("[PackHistory] Saving ", _history.size(), " packs to history")
	
	# Clear old files
	_clear_history_files()
	
	# Save each pack as a separate resource file
	var pack_files: Array[String] = []
	
	for i in _history.size():
		var pack := _history[i]
		if not pack:
			continue
		
		var filename := "pack_%d.tres" % i
		var filepath := HISTORY_DIR + filename
		
		var save_result := ResourceSaver.save(pack, filepath)
		if save_result == OK:
			pack_files.append(filename)
			print("[PackHistory] Saved pack: ", pack.pack_name)
		else:
			print("[PackHistory] Failed to save pack: ", pack.pack_name, " error: ", save_result)
	
	# Save index file with list of pack files
	var index := HistoryIndex.new()
	index.pack_files = pack_files
	var index_result := ResourceSaver.save(index, HISTORY_DIR + "index.tres")
	if index_result == OK:
		print("[PackHistory] Index saved successfully with ", pack_files.size(), " entries")
	else:
		print("[PackHistory] Failed to save index, error: ", index_result)


## Clear all history files
func _clear_history_files() -> void:
	var dir := DirAccess.open(HISTORY_DIR)
	if dir:
		dir.list_dir_begin()
		var file_name := dir.get_next()
		while file_name != "":
			if not dir.current_is_dir():
				dir.remove(file_name)
			file_name = dir.get_next()
		dir.list_dir_end()

extends Node

## Manages pack history, stores the last 32 packs used by the user

const MAX_HISTORY_SIZE: int = 32
const HISTORY_DIR := "user://pack_history/"

var _history: Array[PackResource] = []


func _ready() -> void:
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
	

	var pack_copy: PackResource = pack.duplicate_deep(Resource.DEEP_DUPLICATE_INTERNAL)
	
	print("[PackHistory] Current history size before filter: ", _history.size())
	
	# Remove duplicate if already exists (compare by path and source)
	_history = _history.filter(func(item: PackResource) -> bool:
		return not (item.path == pack_copy.path)
	)
	
	print("[PackHistory] History size after filter: ", _history.size())
	
	_history.push_front(pack_copy)
	print("[PackHistory] History size after push_front: ", _history.size())
	_clean_history()
	
	if _history.size() > MAX_HISTORY_SIZE:
		_history.resize(MAX_HISTORY_SIZE)
	
	if save_immediately:
		_save_history()
	

## Removes a pack from history. Matched by path rather than by identity, because
## _clean_history replaces the stored resources with deep copies on every save.
func erase_pack(pack: PackResource) -> void:
	var kept: Array[PackResource] = []
	for item: PackResource in _history:
		if item.path != pack.path:
			kept.append(item)

	if kept.size() == _history.size():
		return

	_history = kept
	_save_history()


func add_packs(packs: Array[PackResource]) -> void:
	for pack in packs:
		add_pack(pack, false)
	_save_history()


func get_history() -> Array[PackResource]:
	var result: Array[PackResource] = []
	for pack in _history:
		if _validate_pack_exists(pack):
			result.append(pack)
	return result


func get_history_count() -> int:
	return _history.size()


func clear_history() -> void:
	_history.clear()
	_clear_history_files()


func _validate_pack_exists(pack: PackResource) -> bool:
	if pack.source == Constants.Source.FOLDER:
		return DirAccess.dir_exists_absolute(pack.path)
	if pack.source == Constants.Source.IMAGES:
		return FileAccess.file_exists(pack.path)
	return not pack.fetch_plugin_id().is_empty()


func _load_history() -> void:
	_history.clear()
	
	var index_path := HISTORY_DIR.path_join("index.tres")
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
	
	_clean_history()
	_save_history()


func _clean_history() -> void:
	var old_history: Array[PackResource] = _history.duplicate(true)
	clear_history()
	
	var pack_paths: Array = []
	for pack in old_history:
		if pack.path in pack_paths:
			continue
		pack_paths.append(pack.path)
		_history.append(pack)


func _save_history() -> void:
	_clean_history()
	print("[PackHistory] Saving ", _history.size(), " packs to history")
	
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
	var index_result := ResourceSaver.save(index, HISTORY_DIR.path_join("index.tres"))
	if index_result == OK:
		print("[PackHistory] Index saved successfully with ", pack_files.size(), " entries")
	else:
		print("[PackHistory] Failed to save index, error: ", index_result)


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

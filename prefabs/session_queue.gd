class_name SessionQueue extends Node

const URL_REGEX: String = '^(ftp|http|https)://[^ "]+$'
const PRELOAD_RANGE := 10
const UNLOAD_RANGE := 20

var _queue: Array = []
var _queue_idx: int = 0
var _cache: Dictionary = {} # { <idx>: { "texture": <Texture2D>, "size": <int> } }

var _url_regex: RegEx = RegEx.new()
var _thread: Thread
var _load_queue: Array = []
var _thread_loop: bool = true


func _init() -> void:
	_url_regex.compile(URL_REGEX)


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		if _thread != null and _thread.is_alive():
			_thread_loop = false
			await _thread.wait_to_finish()


func load_queue(queue_or_context) -> void:
	# Accept either a pre-built queue Array or a SessionResource and build it here
	_queue_idx = 0
	if queue_or_context is SessionResource:
		_queue = queue_or_context.sequence
	elif typeof(queue_or_context) == TYPE_ARRAY:
		_queue = queue_or_context
	else:
		_queue = []

	if _thread == null:
		_thread = Thread.new()
		_thread.start(_background_loader)


func current(callback: Callable) -> Dictionary:
	if _queue.size() == 0:
		return {"status": "fail", "message": "Empty queue"}
	return get_from_cache(_queue_idx, callback)


func next(callback: Callable) -> Dictionary:
	if _queue.size() == 0:
		return {"status": "fail", "message": "Empty queue"}
	if _queue_idx < _queue.size() - 1:
		_queue_idx += 1
		return get_from_cache(_queue_idx, callback)
	return {}


func previous(callback: Callable) -> Dictionary:
	if _queue.size() == 0:
		return {"status": "fail", "message": "Empty queue"}
	if _queue_idx > 0:
		_queue_idx -= 1
		return get_from_cache(_queue_idx, callback)
	return {}


func has_next() -> bool: return _queue_idx < _queue.size()-1
func has_previous() -> bool: return _queue_idx > 0
func size() -> int: return _queue.size()


func get_current_location() -> String:
	return _queue[_queue_idx].get("path", "") if _queue_idx < _queue.size() else ""


func get_current_filename() -> String:
	return _queue[_queue_idx].get("name", "Unknown") if _queue_idx < _queue.size() else "Unknown"


func get_from_cache(idx: int, callback: Callable) -> Dictionary:
	# Validate index
	if idx < 0 or idx >= _queue.size():
		return {"status": "fail", "message": "Index out of range"}

	var item: Dictionary = _queue[idx]
	if item.get("type") == "break":
		return {"status": "break", "duration": item.get("duration")}

	if _cache.has(idx):
		return _cache[idx]

	_enqueue_load(idx, callback)
	_cache[idx] = {"status": "loading"}
	return _cache[idx]


func _enqueue_load(idx: int, callback: Callable) -> void:
	if idx < 0 or idx >= _queue.size():
		return
	if _load_queue.has(idx) or (_cache.has(idx) and _cache[idx]["status"] != "loading"):
		return
	_load_queue.append({"index": idx, "callback": callback})


func _background_loader() -> void:
	while _thread_loop:
		for offset in range(-PRELOAD_RANGE, PRELOAD_RANGE + 1):
			var preload_idx = _queue_idx + offset
			var in_range := preload_idx >= 0 and preload_idx < _queue.size()
			var is_pose: bool = in_range and _queue[preload_idx].get("type") == "pose"
			if not is_pose:
				continue
			if not _cache.has(preload_idx) and not _is_in_load_queue(preload_idx):
				_load_queue.append({"index": preload_idx})

		_clean_cache()
		if _load_queue.is_empty():
			await get_tree().create_timer(0.2).timeout
			continue
		
		var queue_obj: Dictionary = _load_queue.pop_front()
		var idx: int = queue_obj["index"]
		var callback: Callable = queue_obj.get("callback", func(_x): return)
		var path: String = _queue[idx].get("path")
		
		_cache[idx] = { "status": "loading", "path": path }

		var texture: Texture2D = await _load_image(path)
		if texture:
			_cache[idx] = {
				"status": "success",
				"index": idx,
				"texture": texture,
				"path": path
			}
		else:
			_cache[idx] = {
				"status": "fail",
				"path": path,
				"message": "The image cannot be loaded."
			}

		callback.call(_cache[idx])


func _load_image(path: String) -> Texture2D:
	var is_url: bool = _url_regex.search(path) != null
	if is_url:
		return await UrlImageLoader.get_image(path)
	
	for _i in range(4):
		var im: Image = Image.load_from_file(path)
		if im and not im.is_empty():
			return ImageTexture.create_from_image(im)
	return null


func _is_in_load_queue(idx: int) -> bool:
	for q in _load_queue:
		if typeof(q) == TYPE_DICTIONARY and q.get("index", -1) == idx:
			return true
	return false


func _get_cache_count() -> int:
	var count: int = 0
	for idx in _cache.keys():
		var el: Dictionary = _cache[idx]
		if el and el["status"] == "success":
			count += 1
	return count


func _clean_cache() -> void:
	var unload_range: Array = range(_queue_idx - UNLOAD_RANGE, _queue_idx + UNLOAD_RANGE + 1)
	for idx: int in _cache.keys():
		if not idx in unload_range:
			_cache.erase(idx)
	
	for el: Dictionary in _load_queue:
		var idx: int = el.get("index")
		if not idx in unload_range:
			_load_queue.erase(idx)


# Public accessors to avoid exposing internals directly
func get_current_index() -> int:
	return _queue_idx

func get_current_item() -> Dictionary:
	return get_item(_queue_idx)

func get_item(idx: int) -> Dictionary:
	if idx >= 0 and idx < _queue.size():
		return _queue[idx]
	return {}

func get_item_duration(idx: int) -> int:
	var it := get_item(idx)
	if it.size() == 0:
		return -1
	return int(it.get("duration", -1))

func get_item_path(idx: int) -> String:
	return str(get_item(idx).get("path", ""))

func get_item_name(idx: int) -> String:
	return str(get_item(idx).get("name", "Unknown"))

func get_cached(idx: int) -> Dictionary:
	return _cache.get(idx, {})

func set_cached_texture(idx: int, texture: Texture2D) -> void:
	var path = get_item_path(idx)
	_cache[idx] = {
		"status": "success",
		"index": idx,
		"texture": texture,
		"path": path
	}

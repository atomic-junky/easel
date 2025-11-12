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


func load_queue(queue: Array) -> void:
	_queue_idx = 0
	_queue = queue
	if _thread == null:
		_thread = Thread.new()
		_thread.start(_background_loader)


func current(callback: Callable) -> Dictionary:
	var result = get_from_cache(_queue_idx, callback)
	return result


func next(callback: Callable) -> Dictionary:
	if _queue_idx < _queue.size() - 1:
		_queue_idx += 1
		var result = get_from_cache(_queue_idx, callback)
		return result
	return {}


func previous(callback: Callable) -> Dictionary:
	if _queue_idx > 0:
		_queue_idx -= 1
		var result = get_from_cache(_queue_idx, callback)
		return result
	return {}


func has_next() -> bool: return _queue_idx < _queue.size()-1
func has_previous() -> bool: return _queue_idx > 0
func size() -> int: return _queue.size()


func get_current_location() -> String:
	return _queue[_queue_idx].get("path", "") if _queue.size() >= _queue_idx else ""


func get_current_filename() -> String:
	return _queue[_queue_idx].get("name", "Unknown") if _queue.size() >= _queue_idx else "Unknown"


func get_from_cache(idx: int, callback: Callable) -> Dictionary:
	if _queue[idx].get("type") == "break":
		return {
			"status": "break",
			"duration": _queue[idx].get("duration")
		}
	
	if _cache.has(idx):
		return _cache[idx]

	_enqueue_load(idx, callback)
	_cache[idx] = {
		"status": "loading"
	}
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

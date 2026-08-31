class_name SessionQueue extends Node

## Loads session images around the current index and reports every completion.
##
## Files are decoded on WorkerThreadPool; URLs stay on the main thread because
## HTTPRequest needs the scene tree. Results are published from _process so
## textures are always created on the main thread.
##
## Consumers listen to [signal item_loaded] rather than passing a callback: a
## load that is already in flight has no callback slot to fill, which is why the
## previous version could leave an image stuck on its spinner forever.

signal item_loaded(index: int, entry: Dictionary)

const URL_REGEX: String = '^(ftp|http|https)://[^ "]+$'
const PRELOAD_RANGE: int = 6
const UNLOAD_RANGE: int = 20
const MAX_CONCURRENT: int = 4
const MAX_ATTEMPTS: int = 3

var _queue: Array = []
var _queue_idx: int = 0
var _cache: Dictionary = {}
var _pending: Dictionary = {}

var _url_regex: RegEx = RegEx.new()
var _mutex: Mutex = Mutex.new()
var _decoded: Array = []
var _tasks: Array = []


func _init() -> void:
	_url_regex.compile(URL_REGEX)


func _ready() -> void:
	set_process(true)


func _exit_tree() -> void:
	# Joining here is what the old NOTIFICATION_PREDELETE hook meant to do; it
	# could not, because its "thread" function was a coroutine that had already
	# returned at its first await.
	for task_id in _tasks:
		WorkerThreadPool.wait_for_task_completion(task_id)
	_tasks.clear()


func _process(_delta: float) -> void:
	_publish_decoded()
	_queue_preloads()


func load_queue(queue_or_context) -> void:
	_queue_idx = 0
	_cache.clear()
	_pending.clear()

	if queue_or_context is SessionResource:
		_queue = queue_or_context.sequence
	elif typeof(queue_or_context) == TYPE_ARRAY:
		_queue = queue_or_context
	else:
		_queue = []


## Navigation. Each returns the entry to display right now, which may still be
## "loading" — item_loaded fires later with the real thing.

func current() -> Dictionary:
	return _entry_for(_queue_idx)


func next() -> Dictionary:
	if has_next():
		_queue_idx += 1
	return _entry_for(_queue_idx)


func previous() -> Dictionary:
	if has_previous():
		_queue_idx -= 1
	return _entry_for(_queue_idx)


func has_next() -> bool: return _queue_idx < _queue.size() - 1
func has_previous() -> bool: return _queue_idx > 0
func size() -> int: return _queue.size()


func _entry_for(idx: int) -> Dictionary:
	if idx < 0 or idx >= _queue.size():
		return {"status": "fail", "message": "Empty queue"}

	var item: Dictionary = _queue[idx]
	if item.get("type") == "break":
		return {"status": "break", "duration": item.get("duration", 0)}

	if _cache.has(idx):
		return _cache[idx]

	_start_load(idx)
	return {"status": "loading", "index": idx}


## Loading

func _queue_preloads() -> void:
	if _queue.is_empty():
		return

	_clean_cache()

	# Nearest first: the image you are about to see matters more than the one
	# six steps away.
	for offset in range(0, PRELOAD_RANGE + 1):
		if _pending.size() >= MAX_CONCURRENT:
			return
		for idx: int in ([_queue_idx] if offset == 0 else [_queue_idx + offset, _queue_idx - offset]):
			if _needs_load(idx):
				_start_load(idx)


func _needs_load(idx: int) -> bool:
	if idx < 0 or idx >= _queue.size():
		return false
	if _cache.has(idx) or _pending.has(idx):
		return false
	return _queue[idx].get("type") == "pose"


func _start_load(idx: int) -> void:
	if idx < 0 or idx >= _queue.size() or _pending.has(idx) or _cache.has(idx):
		return

	var path: String = str(_queue[idx].get("path", ""))
	if path.is_empty():
		_fail(idx, "Image not found")
		return

	_pending[idx] = true

	if _url_regex.search(path) != null:
		_load_url(idx, path)
	else:
		_tasks.append(WorkerThreadPool.add_task(_decode_file.bind(idx, path)))


## Runs on a pool thread: decoding only, no engine objects touched.
func _decode_file(idx: int, path: String) -> void:
	var image: Image = null
	for _attempt in MAX_ATTEMPTS:
		var loaded: Image = ImageDecoder.load_file(path)
		if loaded and not loaded.is_empty():
			image = loaded
			break

	_mutex.lock()
	_decoded.append({"index": idx, "image": image})
	_mutex.unlock()


func _load_url(idx: int, path: String) -> void:
	var texture: Texture2D = await UrlImageLoader.get_image(path)
	if not is_inside_tree():
		return

	_pending.erase(idx)
	if texture:
		_store(idx, texture)
	else:
		_fail(idx, "The image cannot be downloaded.")


func _publish_decoded() -> void:
	_mutex.lock()
	var batch: Array = _decoded
	_decoded = []
	_mutex.unlock()

	for result: Dictionary in batch:
		var idx: int = result["index"]
		_pending.erase(idx)

		var image: Image = result["image"]
		if image:
			_store(idx, ImageTexture.create_from_image(image))
		else:
			_fail(idx, "The image cannot be loaded.")


func _store(idx: int, texture: Texture2D) -> void:
	_cache[idx] = {
		"status": "success",
		"index": idx,
		"texture": texture,
		"path": get_item_path(idx),
		"duration": get_item_duration(idx),
	}
	item_loaded.emit(idx, _cache[idx])


func _fail(idx: int, message: String) -> void:
	_pending.erase(idx)
	_cache[idx] = {
		"status": "fail",
		"index": idx,
		"path": get_item_path(idx),
		"message": message,
		"duration": get_item_duration(idx),
	}
	item_loaded.emit(idx, _cache[idx])


func _clean_cache() -> void:
	var low: int = _queue_idx - UNLOAD_RANGE
	var high: int = _queue_idx + UNLOAD_RANGE

	for idx: int in _cache.keys():
		if idx < low or idx > high:
			_cache.erase(idx)


## Accessors

func get_current_index() -> int:
	return _queue_idx


func get_current_location() -> String:
	return get_item_path(_queue_idx)


func get_current_filename() -> String:
	return get_item_name(_queue_idx)


func get_item(idx: int) -> Dictionary:
	return _queue[idx] if idx >= 0 and idx < _queue.size() else {}


func get_current_item() -> Dictionary:
	return get_item(_queue_idx)


func get_item_duration(idx: int) -> int:
	var item: Dictionary = get_item(idx)
	return int(item.get("duration", -1)) if not item.is_empty() else -1


func get_item_path(idx: int) -> String:
	return str(get_item(idx).get("path", ""))


func get_item_name(idx: int) -> String:
	return str(get_item(idx).get("name", "Unknown"))


func get_cached(idx: int) -> Dictionary:
	return _cache.get(idx, {})


## Replaces a cached texture without announcing it, so callers that already know
## (rotation, for one) stay in control of what happens on screen.
func set_cached_texture(idx: int, texture: Texture2D) -> void:
	_cache[idx] = {
		"status": "success",
		"index": idx,
		"texture": texture,
		"path": get_item_path(idx),
		"duration": get_item_duration(idx),
	}

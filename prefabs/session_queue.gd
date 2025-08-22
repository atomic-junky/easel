class_name SessionQueue extends Node

signal _frame(delta: float)
signal image_loaded(idx: int)
signal cache_loaded

const URL_REGEX: String = '^(ftp|http|https)://[^ "]+$'
const PRELOAD_RANGE := 10
const MAX_CACHE_MEMORY_MB: int = 256 # Mo

var _queue: Array = []
var _queue_idx: int = 0
var _cache: Dictionary = {} # { idx: { "texture": Texture2D, "size": int } }
var _cache_memory: int = 0 # octets

var _url_regex: RegEx = RegEx.new()
var _thread: Thread
var _loading: bool = false
var _load_queue: Array = []


func _init() -> void:
	_url_regex.compile(URL_REGEX)


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
	return _queue[_queue_idx]


func get_from_cache(idx: int, callback: Callable) -> Dictionary:
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
	while true:
		# Construire la liste des indices à charger
		for offset in range(-PRELOAD_RANGE, PRELOAD_RANGE + 1):
			var idx = _queue_idx + offset
			if idx >= 0 and idx < _queue.size():
				if not _cache.has(idx) and not _is_in_load_queue(idx):
					# Vérifie qu'on a (ou aura) la place dans le cache
					if _would_fit_in_cache(idx):
						_load_queue.append({"index": idx})

		# Rien à charger → on attend un peu
		if _load_queue.is_empty():
			await get_tree().create_timer(0.2).timeout
			continue
		
		var queue_obj: Dictionary = _load_queue.pop_front()
		var idx: int = queue_obj["index"]
		var callback: Callable = queue_obj.get("callback", func(_x): return)
		var path: String = _queue[idx]

		_cache[idx] = { "status": "loading", "path": path }

		var texture: Texture2D = await _load_image(path)
		if texture:
			var size_bytes = _estimate_texture_size(texture)
			_cache[idx] = {
				"status": "success",
				"texture": texture,
				"path": path,
				"size": size_bytes
			}
			_cache_memory += size_bytes
			_clean_cache()
		else:
			_cache[idx] = { "status": "fail", "path": path }

		call_deferred("emit_signal", "image_loaded", idx)
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


func _would_fit_in_cache(idx: int) -> bool:
	# Estimer la taille avant chargement
	var fake_size = 512 * 512 * 4 # estimation par défaut si on ne sait pas
	# Ici tu pourrais faire un quick metadata check si tu veux
	return (_cache_memory + fake_size) <= (MAX_CACHE_MEMORY_MB * 1024 * 1024)


func _estimate_texture_size(tex: Texture2D) -> int:
	if tex == null:
		return 0
	var size = tex.get_width() * tex.get_height() * 4 # RGBA8 → 4 bytes par pixel
	return size


func _get_cache_count() -> int:
	var count: int = 0
	for idx in _cache.keys():
		var el: Dictionary = _cache[idx]
		if el and el["status"] == "succcess":
			count += 1
	return count


func _clean_cache() -> void:
	while _cache_memory > MAX_CACHE_MEMORY_MB * 1024 * 1024:
		var farthest_idx = -1
		var farthest_dist = -1
		for key in _cache.keys():
			var dist = abs(key - _queue_idx)
			if dist > farthest_dist:
				farthest_dist = dist
				farthest_idx = key

		if farthest_idx != -1:
			_cache_memory -= _cache[farthest_idx].get("size", 0)
			_cache.erase(farthest_idx)

class_name SessionQueue extends RefCounted

signal image_loaded
signal cache_loaded

const MIN_CACHE_RANGE: int = 10
const MAX_CACHE_RANGE: int = 40
const URL_REGEX: String = '^(ftp|http|https)://[^ "]+$'

var _queue: Array = []
var _cache: Dictionary = {}
var _queue_idx: int = 0
var _url_regex: RegEx = RegEx.new()


func _init() -> void:
	image_loaded.connect(_on_image_loaded)
	_url_regex.compile(URL_REGEX)


func load_queue(queue: Array) -> void:
	_queue_idx = 0
	_queue = queue
	_update_cache()
	if not is_cache_loaded():
		await cache_loaded


func current() -> Dictionary:
	return _cache.get(_queue_idx)


func next() -> Dictionary:
	var result: Dictionary
	
	_queue_idx += 1
	result = _cache.get(_queue_idx, {})
	_update_cache()
	return result

func previous() -> Dictionary:
	var result: Dictionary
	
	_queue_idx -= 1
	result = _cache.get(_queue_idx, {})
	_update_cache()
	return result


func has_next() -> bool: return _queue_idx < _queue.size()-1
func has_previous() -> bool: return _queue_idx > 0


func _update_cache() -> void:
	var min_cache_range: Array = range(
		clamp(0, _queue_idx-MIN_CACHE_RANGE, _queue.size()),
		clamp(0, _queue_idx+MIN_CACHE_RANGE, _queue.size()),
	)
	
	var max_cache_range: Array = range(
		clamp(0, _queue_idx-MAX_CACHE_RANGE, _queue.size()),
		clamp(0, _queue_idx+MAX_CACHE_RANGE, _queue.size()),
	)
	
	# Load images
	for idx in min_cache_range:
		if _cache.has(idx):
			continue
		
		var im_path: String = _queue[idx]
		_load_image(im_path, idx)
	
	# Unload images
	for key in _cache.keys():
		if max_cache_range.has(key):
			continue
		
		_cache.erase(key)


func _load_image(path: String, idx: int) -> void:
	_cache[idx] = {
		"status": "loading"
	}
	var is_url: bool = _url_regex.search(path) != null
	
	var texture: Texture2D
	if is_url:
		texture = await UrlImageLoader.get_image(path)
	else:
		for _i in range(4):
			var im: Image = Image.load_from_file(path)
			if im and not im.is_empty():
				texture = ImageTexture.create_from_image(im)
				break
	
	if not texture:
		_cache[idx] = {
			"status": "fail",
			"message": "Can't load image at %s." % path
		}
	else:
		_cache[idx] = {
			"status": "success",
			"texture": texture,
			"path": path
		}
	
	image_loaded.emit()


func is_cache_loaded() -> bool:
	var result: bool = true
	var min_cache_range: Array = range(
		clamp(0, _queue_idx-MIN_CACHE_RANGE, _queue.size()),
		clamp(0, _queue_idx+MIN_CACHE_RANGE, _queue.size()),
	)
	
	for idx in min_cache_range:
		if not _cache.has(idx):
			result = false
	
	return result

func _on_image_loaded() -> void:
	if is_cache_loaded(): cache_loaded.emit()


func get_current_location() -> String:
	return _queue[_queue_idx]


func size() -> int:
	return _queue.size()

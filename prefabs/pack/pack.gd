class_name Pack extends Button

const URL_REGEX: String = '^(ftp|http|https)://[^ " ]+$'

signal delete_request
signal refresh_request
signal add_pack_request
signal selection_changed
signal refresh_done
signal refresh_progress(message: String)

const TINT_COUNT: int = 5

static var _preview_queue: Array = []
static var _preview_worker_thread: Thread = null
static var _preview_worker_running: bool = false
static var _preview_queue_mutex: Mutex = Mutex.new()
static var _preview_cache: Dictionary = {}

@onready var mosaic: PanelContainer = %Mosaic
@onready var icon_rect: TextureRect = %IconRect
@onready var badge: PanelContainer = %Badge
@onready var badge_label: Label = %BadgeLabel
@onready var title_label: Label = %Title
@onready var decsc_label: Label = %Description
@onready var actions: HBoxContainer = %Actions

@onready var folder_icon: Texture2D = preload("res://assets/icons/folder.svg")
@onready var image_icon: Texture2D = preload("res://assets/icons/image.svg")
@onready var pinterest_icon: Texture2D = preload("res://assets/icons/pinterest.svg")
@onready var add_icon: Texture2D = preload("res://assets/icons/bookmark-add.svg")
@onready var check_icon: Texture2D = preload("res://assets/icons/bookmark-check.svg")

@onready var preview_rects: Array[TextureRect] = [
	%PreviewRect01,
	%PreviewRect02,
	%PreviewRect03,
]

var _resource: PackResource
var _pinterest_fetcher: PinterestFetcher
var _is_holo: bool = false
var _url_regex: RegEx = RegEx.new()


func _ready() -> void:
	pressed.connect(_on_pressed)

	_url_regex.compile(URL_REGEX)


func _from_context(
	pack: PackResource,
	is_holo: bool = false
) -> void:
	_resource = pack
	_is_holo = is_holo
	button_pressed = pack.enabled
	title_label.text = pack.pack_name

	var desc_label: String = "%s images"
	match pack.source:
		Constants.Source.FOLDER:
			icon_rect.texture = folder_icon
		Constants.Source.IMAGES:
			icon_rect.texture = image_icon
		Constants.Source.PINTEREST:
			icon_rect.texture = pinterest_icon
			desc_label = "%s pins"
		Constants.Source.LIBRARY:
			pass

	decsc_label.text = desc_label % pack.image_count

	# Stable per-pack pastel so a grid of cards is not one flat block.
	mosaic.theme_type_variation = "PackCardClip%d" % (absi(pack.path.hash()) % TINT_COUNT)

	if is_holo:
		button_pressed = false
		toggle_mode = false
		pack.enabled = true

	_queue_preview_images()


## Shows the selection rank, or hides the badge when rank <= 0.
func set_badge(rank: int) -> void:
	badge.visible = rank > 0
	badge_label.text = str(rank)

func _queue_preview_images() -> void:
	for idx in preview_rects.size():
		var rect: TextureRect = preview_rects[idx]
		if not rect or idx >= _resource.image_count:
			break
		var im_data: Dictionary = _resource.images[idx]
		var path: String = str(im_data.get("path", ""))
		if path == "":
			continue
		var is_url: bool = _url_regex.search(path) != null
		if _apply_cached_preview(path, rect):
			continue
		_enqueue_preview(path, rect, is_url, self)


static func _enqueue_preview(path: String, rect: TextureRect, is_url: bool, pack: Pack) -> void:
	if path == "" or not is_instance_valid(pack) or not is_instance_valid(rect):
		return
	_preview_queue_mutex.lock()
	_preview_queue.append({
		"path": path,
		"rect_ref": weakref(rect),
		"is_url": is_url,
		"pack_ref": weakref(pack),
	})
	var should_start: bool = not _preview_worker_running
	if should_start:
		_preview_worker_running = true
	_preview_queue_mutex.unlock()
	if should_start:
		var thread: Thread = Thread.new()
		_preview_worker_thread = thread
		thread.start(_preview_worker_loop)



static func _preview_worker_loop() -> void:
	while true:
		_preview_queue_mutex.lock()
		if _preview_queue.is_empty():
			_preview_worker_running = false
			_preview_worker_thread = null
			_preview_queue_mutex.unlock()
			return
		var task: Dictionary = _preview_queue.pop_front()
		_preview_queue_mutex.unlock()
		var pack_ref: WeakRef = task.get("pack_ref") as WeakRef
		var rect_ref: WeakRef = task.get("rect_ref") as WeakRef
		var pack: Pack = pack_ref.get_ref() as Pack if pack_ref != null else null
		var rect: TextureRect = rect_ref.get_ref() as TextureRect if rect_ref != null else null
		if not is_instance_valid(pack) or not is_instance_valid(rect):
			continue
		var path: String = str(task.get("path", ""))
		if path == "":
			continue
		if task.get("is_url"):
			pack.call_thread_safe("_fetch_url_texture", path, rect)
			continue
		for _i in range(4):
			var im: Image = Image.load_from_file(path)
			if im and not im.is_empty():
				if is_instance_valid(pack):
					pack.call_thread_safe("_post_thread_load_image", im, rect, path)
				break

static func _apply_cached_preview(path: String, rect: TextureRect) -> bool:
	if path == "":
		return false
	var cached_texture: Texture2D = _preview_cache.get(path)
	if cached_texture and cached_texture is Texture2D:
		rect.texture = cached_texture
		return true
	return false


func _post_thread_load_image(source: Variant, rect: TextureRect, path: String) -> void:
	if not is_instance_valid(rect):
		return
	var texture: Texture2D
	if source is Texture2D:
		texture = source
	elif source is Image:
		texture = ImageTexture.create_from_image(source)
	else:
		return
	rect.texture = texture
	if path != "" and texture:
		_preview_cache[path] = texture


func _fetch_url_texture(path: String, rect: TextureRect) -> void:
	var texture: Texture2D = await UrlImageLoader.get_image(path)
	if texture and is_instance_valid(rect):
		_post_thread_load_image(texture, rect, path)


## Refreshes this pack, showing the spinner while it runs.
func refresh() -> void:
	await _refresh_pack()
	refresh_request.emit()


func _refresh_pack() -> void:
	if not _resource:
		refresh_done.emit()
		return
	
	match _resource.source:
		Constants.Source.FOLDER:
			if DirAccess.dir_exists_absolute(_resource.path):
				_resource.images = PackResource._recursive_load_dir(_resource.path)
			
		Constants.Source.IMAGES:
			# For image packs, filter out deleted files
			var valid_images: Array[Dictionary] = []
			for img in _resource.images:
				if FileAccess.file_exists(img.get("path", "")):
					valid_images.append(img)
			_resource.images = valid_images
			
		Constants.Source.PINTEREST:
			# Refresh Pinterest pack by fetching from URL
			if _resource.path.is_empty():
				push_error("PackResource path is empty!")
				refresh_done.emit()
			
			# Create a new instance for this fetch
			_pinterest_fetcher = PinterestFetcher.new()
			add_child(_pinterest_fetcher)
			
			var results: Array = await _pinterest_fetcher.fetch(
				_resource.path,
				_resource.use_pinterest_sections,
				_on_pinterest_refresh_progress
			)
			
			# Clean up the fetcher
			_pinterest_fetcher.queue_free()
			_pinterest_fetcher = null
			
			if results.is_empty():
				push_error("PinterestFetcher return is empty!")
				refresh_done.emit()
				return
			
			var pack_data = results[0]
			if pack_data.is_empty() or pack_data.get("status") != "success":
				refresh_done.emit()
				return
			
			var data: Dictionary = pack_data.get("data", {})
			var pack_images: Array = data.get("images", [])
			
			# Convert Array to Array[Dictionary]
			var typed_images: Array[Dictionary] = []
			for img in pack_images:
				if img is Dictionary:
					typed_images.append(img)
			
			_resource.images = typed_images
	refresh_done.emit()
	
	_from_context(_resource)


func _on_pinterest_refresh_progress(message: String) -> void:
	refresh_progress.emit(message)


func _on_toggled(toggled_on: bool) -> void:
	_resource.enabled = toggled_on if not _is_holo else true
	_pop()
	selection_changed.emit()
	actions.visible = !toggled_on


## Short squash so picking a pack feels physical.
func _pop() -> void:
	pivot_offset = size / 2.0
	var tween: Tween = create_tween()
	tween.tween_property(self, "scale", Vector2(1.05, 1.05), 0.08) \
		.set_trans(Tween.TRANS_QUAD)
	tween.tween_property(self, "scale", Vector2.ONE, 0.18) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _on_pressed() -> void:
	if _is_holo:
		add_pack_request.emit()


func _on_delete_button_pressed() -> void:
	delete_request.emit()

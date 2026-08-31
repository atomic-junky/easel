@abstract class_name EaselFetcherPlugin extends AwaitableHTTPRequest


var progress_callback: Callable = _empty_progress_callback


## Metadata. Subclasses must override the first three.

static func plugin_id() -> StringName:
	return &""


static func display_name() -> String:
	return ""


## True when this plugin knows how to fetch the given URL.
static func can_handle(_url: String) -> bool:
	return false


static func icon_path() -> String:
	return ""


## Settings the UI should offer for this plugin, as controls it builds itself.
static func options() -> Array[PluginOption]:
	return []


func fetch(url: String, params: Dictionary = {}, progress: Callable = _empty_progress_callback) -> Array[PackFetchResult]:
	progress_callback = progress
	if get_url_segments(url).is_empty():
		return [PackFetchResult.failure("Invalid url.")]

	@warning_ignore("redundant_await")
	return await on_fetch(url, params)


@abstract func on_fetch(url: String, params: Dictionary) -> Array[PackFetchResult]


func report(message: String) -> void:
	progress_callback.call(message)


func _empty_progress_callback(_message: String) -> void: return


# Helpers

static func get_url_segments(url: String) -> PackedStringArray:
	var clean_url = url.split("?")[0].split("#")[0]
	clean_url = clean_url.replace("https://", "").replace("http://", "")
	clean_url = clean_url.rstrip("/")
	clean_url = clean_url.trim_prefix("www.")
	return clean_url.split("/")


static func host_of(url: String) -> String:
	var segments: PackedStringArray = get_url_segments(url)
	return segments[0] if not segments.is_empty() else ""


func sync_request(url: String, custom_headers: PackedStringArray = PackedStringArray(), method: HTTPClient.Method = HTTPClient.METHOD_GET, request_data: String = "") -> HTTPResult:
	var err: Error = request(url, custom_headers, method, request_data)
	var result := await request_completed as Array

	if err != OK:
		return HTTPResult._from_error(err)

	return HTTPResult._from_array(result)

extends Node

var http_request: AwaitableHTTPRequest = AwaitableHTTPRequest.new()
var _progress_callback: Callable

# Constants for better maintainability
const MAX_REQUESTS = 64
const PAGE_SIZE = 50
const DEFAULT_DOMAIN = "pinterest.com"
const USER_AGENT = "Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:141.0) Gecko/20100101 Firefox/141.0"

# Resource types and their corresponding handlers
enum ResourceType { BOARD, SECTION }
const RESOURCE_CONFIGS = {
	ResourceType.BOARD: {
		"resource_request": "BoardFeedResource",
		"url_handler": "www/[username]/[slug].js",
		"type_key": "board_id"
	},
	ResourceType.SECTION: {
		"resource_request": "BoardSectionPinsResource", 
		"url_handler": "www/[username]/[slug]/[section_slug].js",
		"type_key": "section_id"
	}
}


func _ready():
	add_child(http_request)


func get_board_options(url: String, res_id: String, bookmarks: Array, resource_type: ResourceType) -> Dictionary:
	var type_key = "board" if resource_type == ResourceType.BOARD else "section"
	var options = {
		"%s_id" % type_key: res_id,
		"currentFilter": -1,
		"field_set_key": "react_grid_pin",
		"filter_section_pins": true,
		"sort": "default",
		"layout": "default",
		"page_size": PAGE_SIZE,
		"redux_normalize_feed": true,
	}
	
	if resource_type == ResourceType.BOARD:
		options["type_url"] = url
	if bookmarks.size() > 0:
		options["bookmarks"] = bookmarks
		
	return options


func build_request_params(url: String, board_id: String, resource_type: ResourceType, bookmarks: Array = []) -> Array:
	var options = get_board_options(url, board_id, bookmarks, resource_type)
	var data = JSON.stringify({
		"options": options,
		"context": {}
	})
	
	return [
		{"source_url": "/%s/" % url},
		{"data": data},
		{"_": str(int(Time.get_unix_time_from_system() * 1000))}
	]


func get_request_headers(url: String, url_handler: String) -> PackedStringArray:
	return [
		"User-Agent: %s" % USER_AGENT,
		"Accept: application/json, text/javascript, */*, q=0.01",
		"X-Requested-With: XMLHttpRequest",
		"X-Pinterest-Source-Url: %s" % url,
		"X-Pinterest-PWS-Handler: %s" % url_handler
	] as PackedStringArray


func get_board_info(board_url: String) -> Dictionary:
	var result: HTTPResult = await http_request.async_request(board_url)
	var body = result.body_as_string()
	
	var board_data = _extract_board_data_from_html(body)
	if board_data.is_empty():
		_log_debug_info(body, board_data)
	
	return board_data


func _extract_board_data_from_html(body: String) -> Dictionary:
	var regex = RegEx.new()
	regex.compile("(?is)<script\\b[^>]*>([\\s\\S]*?)<\\/script>")
	var scripts = regex.search_all(body)
	
	for script_match: RegExMatch in scripts:
		var board_data = _parse_script_for_board_data(script_match.get_string(1))
		if not board_data.is_empty():
			return board_data
	
	return {}


func _parse_script_for_board_data(content: String) -> Dictionary:
	var json = JSON.new()
	if json.parse(content) != OK or json.data is not Dictionary:
		return {}
	
	var data: Dictionary = json.data
	if not data.has("initialReduxState"):
		return {}
	
	var resources: Dictionary = data["initialReduxState"].get("resources", {})
	if not resources.has("BoardResource"):
		return {}
	
	var board_key: String = resources["BoardResource"].keys()[0]
	var board_res: Dictionary = resources["BoardResource"][board_key]["data"]
	
	return {
		"board_id": board_res.get("id", ""),
		"board_name": board_res.get("name", ""),
		"url": board_res.get("url", ""),
		"domain": board_res.get("seo_canonical_domain", DEFAULT_DOMAIN)
	}


func _log_debug_info(body: String, board_data: Dictionary):
	print("Board ID not found")
	if board_data.has("initialReduxState"):
		print("initialReduxState found but no BoardResource")
	else:
		print("initialReduxState not found")
		print("Page body preview: ", body.substr(0, 500))


func fetch_board_sections(url: String, board_id: String, domain: String) -> Array:
	var section_ids: Array = []
	var bookmarks: Array = []
	
	_progress_callback.call("Searching for board sections...")
	
	for i in range(MAX_REQUESTS):
		if bookmarks.find("-end-") != -1:
			break

		var response_data = await _make_sections_request(url, board_id, domain, bookmarks)
		if response_data.is_empty():
			break
			
		var sections = response_data.get("data", [])
		bookmarks = response_data.get("bookmarks", [])

		for section in sections:
			if section.has("id") and section.has("slug"):
				section_ids.append({
					"id": section.get("id"),
					"slug": section.get("slug"),
					"title": section.get("title", "Empty section title")
				})
				
		_progress_callback.call("Collecting board sections (%s found)..." % [section_ids.size()])
	
	return section_ids


func _make_sections_request(url: String, board_id: String, domain: String, bookmarks: Array) -> Dictionary:
	var params_array = build_request_params(url, board_id, ResourceType.BOARD, bookmarks)
	var final_url = "https://%s/resource/BoardSectionsResource/get/?%s" % [domain, _build_query_string(params_array)]
	var headers = get_request_headers(url, "www/[username]/[slug].js")
	
	var result: HTTPResult = await http_request.async_request(final_url, headers, HTTPClient.METHOD_GET)
	return _parse_api_response(result)


func fetch_redirect_url(url: String) -> String:
	var response: HTTPResult = await http_request.async_request(url)
	var page_content: String = response.body_as_string()
	
	if not page_content.contains("api.pinterest.com/url_shortener"):
		return url
	
	var href_regex = RegEx.new()
	href_regex.compile('<a href="(.*)">')
	
	# Follow redirect chain
	var redirect_url = _extract_href(page_content, href_regex)
	response = await http_request.async_request(redirect_url)
	page_content = response.body_as_string()
	redirect_url = _extract_href(page_content, href_regex)
	
	# Clean URL parameters
	var clean_url_regex = RegEx.new()
	clean_url_regex.compile('(.+)\\?')
	var clean_match = clean_url_regex.search(redirect_url)
	if clean_match:
		redirect_url = clean_match.get_string(1)
	
	return redirect_url


func _extract_href(content: String, regex: RegEx) -> String:
	var match = regex.search(content)
	return match.get_string(1) if match else ""


func fetch_board(board_url: String, include_sections: bool) -> Array:
	_progress_callback.call("Searching...")
	var board_info = await get_board_info(board_url)
	
	if not _validate_board_info(board_info):
		return [_build_result("fail", "Board information not found")]
	
	var results: Array = []
	var url = board_info["url"]
	var board_id = board_info["board_id"]
	var board_name = board_info["board_name"]
	var domain = board_info["domain"]
	
	# Collect main board pins
	results.append(await collect_pins(url, board_id, board_name, domain, ResourceType.BOARD))
	
	# Collect section pins if requested
	if include_sections:
		var sections = await fetch_board_sections(url, board_id, domain)
		for section: Dictionary in sections:
			var section_url = url + section.get("slug") + "/"
			results.append(await collect_pins(section_url, section.get("id"), section.get("title"), domain, ResourceType.SECTION))
	
	return results


func fetch_section(board_url: String, section_slug: String) -> Array:
	_progress_callback.call("Searching...")
	var board_info = await get_board_info(board_url)
	
	if not _validate_board_info(board_info):
		return [_build_result("fail", "Board information not found")]
	
	var sections = await fetch_board_sections(board_info["url"], board_info["board_id"], board_info["domain"])
	
	for section: Dictionary in sections:
		if section.get("slug") == section_slug:
			var section_url = board_info["url"] + section.get("slug") + "/"
			return [await collect_pins(section_url, section.get("id"), section.get("title"), board_info["domain"], ResourceType.SECTION)]
	
	return [_build_result("fail", "Section not found")]


func _validate_board_info(board_info: Dictionary) -> bool:
	if board_info.get("board_id", "").is_empty():
		_progress_callback.call("Board not found...")
		printerr("Empty board_id!")
		return false
	if board_info.get("url", "").is_empty():
		_progress_callback.call("Board not found...")
		printerr("Empty url!")
		return false
	return true


func collect_pins(url: String, board_id: String, board_name: String, domain: String, resource_type: ResourceType) -> Dictionary:
	var bookmarks: Array = []
	var images: Array = []
	
	_progress_callback.call("Collecting pins...")
	
	for i in range(MAX_REQUESTS):
		if bookmarks.find("-end-") != -1:
			break

		var response_data: Dictionary = await _make_pins_request(url, board_id, domain, resource_type, bookmarks)
		if response_data.is_empty():
			break
			
		var pins: Array = response_data.get("data", [])
		bookmarks = response_data.get("bookmarks", [])

		for pin in pins:
			var pin_result: Dictionary = _extract_pins(pin)
			if not pin_result.is_empty():
				images.append(pin_result)
				
		_progress_callback.call("Collecting pins (%s found)..." % [images.size()])
	
	# Construct full URL if url is relative
	var full_url = url
	if not url.begins_with("http"):
		full_url = "https://" + domain + url
	
	return _build_result("success", {
		"images": images,
		"board_name": board_name,
		"url": full_url
	})


func _make_pins_request(url: String, board_id: String, domain: String, resource_type: ResourceType, bookmarks: Array) -> Dictionary:
	var config = RESOURCE_CONFIGS[resource_type]
	var params_array = build_request_params(url, board_id, resource_type, bookmarks)
	var final_url = "https://%s/resource/%s/get/?%s" % [domain, config["resource_request"], _build_query_string(params_array)]
	var headers = get_request_headers(url, config["url_handler"])
	
	var result: HTTPResult = await http_request.async_request(final_url, headers, HTTPClient.METHOD_GET)
	return _parse_api_response(result)


func _parse_api_response(result: HTTPResult) -> Dictionary:
	if not result.success():
		printerr("HTTP request failed: ", result.body_as_string())
		return {}

	var json = JSON.new()
	if json.parse(result.body_as_string()) != OK:
		printerr("JSON parse error: ", result.body_as_string())
		return {}
	
	var raw_data: Variant = json.data
	if raw_data is not Dictionary:
		printerr("Invalid response type")
		return {}

	var resource: Dictionary = raw_data.get("resource_response", {})
	
	# Handle error responses
	if resource.get("data", []) is String:
		printerr("API error: ", resource.get("data"))
		return {}
	if resource.has("error"):
		printerr("API error: ", resource.get("error"))
		return {}
	
	# Extract data and bookmarks
	var options: Dictionary = raw_data.get("resource", {}).get("options", {})
	return {
		"data": resource.get("data", []),
		"bookmarks": options.get("bookmarks", [])
	}


func _extract_pins(pin: Dictionary) -> Dictionary:
	var url: String = pin.get("images", {}).get("orig", {}).get("url", "")
	var pname = pin.get("seo_alt_text", "No name")
	var extension: String = url.get_extension()
	if not extension in Constants.SUPPORTED_EXTENSIONS:
		return {}
	return {
		"path": url,
		"name": pname
	}


func fetch(url: String, include_sections: bool, progress_callback: Callable = _empty_progress_callback) -> Array:
	_progress_callback = progress_callback
	
	if url.is_empty() or url.get_slice_count("/") <= 0:
		return []
	
	# Handle short URLs
	if url.contains("pin.it"):
		url = await fetch_redirect_url(url)
	
	var parsed_url = _parse_pinterest_url(url)
	if parsed_url.is_empty():
		return []
	
	# Determine if it's a section or board URL
	if parsed_url.has("section_slug"):
		return await fetch_section(parsed_url["board_url"], parsed_url["section_slug"])
	else:
		return await fetch_board(url, include_sections)


func _parse_pinterest_url(url: String) -> Dictionary:
	var base_url = url.trim_prefix("https://www.").trim_prefix("https://").trim_prefix("www.").trim_suffix("/")
	var url_parts = base_url.split("/")
	
	if url_parts.size() <= 2:
		return {}
	elif url_parts.size() == 4:
		return {
			"board_url": url.trim_suffix(url_parts[3] + "/"),
			"section_slug": url_parts[3]
		}
	else:
		return {"board_url": url}


func _build_query_string(params: Array) -> String:
	var query_parts: Array = []
	
	for param_dict: Dictionary in params:
		for key: String in param_dict.keys():
			var encoded_key = key.uri_encode()
			var value = param_dict[key]
			
			match typeof(value):
				TYPE_ARRAY:
					for v in value:
						query_parts.append("%s=%s" % [encoded_key, str(v).uri_encode()])
				TYPE_NIL:
					query_parts.append(encoded_key)
				_:
					query_parts.append("%s=%s" % [encoded_key, str(value).uri_encode()])
	
	return "&".join(query_parts)


func _empty_progress_callback(_message: String) -> void:
	return


func _build_result(status: String, data: Variant) -> Dictionary:
	return {"status": status, "data": data}

extends Node

var http_request: AwaitableHTTPRequest = AwaitableHTTPRequest.new()
var _progress_callback: Callable

func _ready():
	add_child(http_request)


func get_board_options(url: String, res_id: String, bookmarks: Array, type: String = "board") -> Dictionary:
	var options = {
		"%s_id" % type: res_id,
		"currentFilter": -1,
		"field_set_key": "react_grid_pin",
		"filter_section_pins": true,
		"sort": "default",
		"layout": "default",
		"page_size": 25,
		"redux_normalize_feed": true,
	}
	if type == "board": options["type_url"] = url
	if bookmarks.size() > 0: options["bookmarks"] = bookmarks
	return options


func get_board_params(url: String, board_id: String, type: String, bookmarks: Array = []) -> Array:
	return build_params(get_board_options(url, board_id, bookmarks, type), url)


func build_params(options: Dictionary, url: String) -> Array:
	var params: Array = []
	var data: String = JSON.stringify({
		"options": options,
		"context": {}
	})
	
	params.append({"source_url": "/%s/" % url})
	params.append({"data": data})
	params.append({"_": str(int(Time.get_unix_time_from_system() * 1000))})
	return params


func get_header(url: String, url_handler: String) -> PackedStringArray:
	if url.count("/") <= 2:
		return [
			"User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:141.0) Gecko/20100101 Firefox/141.0",
			"Accept: application/json, text/javascript, */*, q=0.01",
			"X-Requested-With: XMLHttpRequest",
			"X-Pinterest-Source-Url: %s" % url,
			"X-Pinterest-PWS-Handler: %s" % url_handler
		] as PackedStringArray
	
	return [
		"User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:141.0) Gecko/20100101 Firefox/141.0",
		"Accept: application/json, text/javascript, */*, q=0.01",
		"X-Requested-With: XMLHttpRequest",
		"X-Pinterest-Source-Url: %s" % url,
		"X-Pinterest-PWS-Handler: %s" % url_handler
	] as PackedStringArray


func get_board_info(board_url: String) -> Dictionary:
	var board_id: String = ""
	var board_name: String = ""
	var url: String = ""
	var domain: String = ""
	
	var _debug_initialReduxState_found: bool = false
	var _debug_resources: Dictionary = {}
	
	var result: HTTPResult = await http_request.async_request(board_url)
	var body = result.body_as_string()
	#var page_file: FileAccess = FileAccess.open("C:\\Users\\holyt\\Desktop\\log\\page.html", FileAccess.WRITE)
	#page_file.store_string(body)
	var regex = RegEx.new()
	regex.compile("(?is)<script\\b[^>]*>([\\s\\S]*?)<\\/script>")
	var scripts = regex.search_all(body)
	
	for m: RegExMatch in scripts:
		var content: String = m.get_string(1)
		var json: JSON = JSON.new()
		var err: Error = json.parse(content)
		if not err == OK:
			continue
		
		var data: Variant = json.data
		if data is not Dictionary:
			continue
		
		if data.has("initialReduxState"):
			_debug_initialReduxState_found = true
			# print(data)
			var resources: Dictionary = data["initialReduxState"].get("resources", {})
			if not resources.has("BoardResource"):
				continue
			var board_key: String = resources["BoardResource"].keys()[0]
			var board_res: Dictionary = resources["BoardResource"][board_key]
			
			board_id = board_res["data"]["id"]
			board_name = board_res["data"]["name"]
			url = board_res["data"]["url"]
			domain = board_res["data"]["seo_canonical_domain"]
			
			if board_id.is_empty():
				_debug_resources = resources
	
	if board_id.is_empty():
		print("board id not found")
		if _debug_initialReduxState_found:
			print("initialReduxState found")
			print("Resources:")
			print(_debug_resources)
		else:
			print("initialReduxState not found")
			print("Page body:")
			print(body)
	
	return { "board_id": board_id, "board_name": board_name, "url": url, "domain": domain }


func fetch_board_sections(url: String, board_id: String, board_name: String, domain: String) -> Array:
	var section_ids: Array = []
	
	var bookmarks: Array = []
	_progress_callback.call("Searching for board sections...")
	for i in range(64):
		if bookmarks.find("-end-") != -1:
			break

		var params_array: Array = get_board_params(url, board_id, "board", bookmarks)
		var final_url: String = "https://%s/resource/BoardSectionsResource/get/?%s" % [domain, _query_string(params_array)]
		var result: HTTPResult = await http_request.async_request(final_url, get_header(url, "www/[username]/[slug].js"), HTTPClient.METHOD_GET)
		var response: String = result.body_as_string()
		if not result.success():
			printerr(response)
			return section_ids

		var json: JSON = JSON.new()
		var err: Error = json.parse(response)
		if err != OK:
			printerr(response)
			return section_ids
		
		var raw_data: Variant = JSON.parse_string(response)
		if raw_data is not Dictionary:
			printerr("Invalid response type")
			return section_ids

		var resource: Dictionary = raw_data.get("resource_response", {})
		
		var data: Array = resource.get("data", [])
		var options: Dictionary = raw_data.get("resource", {}).get("options", {})
		bookmarks = options.get("bookmarks", [])

		for section in data:
			if section.has("id") and section.has("slug"):
				section_ids.append({
					"id": section.get("id"),
					"slug": section.get("slug"),
					"title": section.get("title", "Empty section title")
				})
			_progress_callback.call("Collecting board sections (%s found)..." % [section_ids.size()])
	
	return section_ids


func fetch_redirect_url(url: String) -> String:
	var response: HTTPResult = await http_request.async_request(url)
	var page_content: String = response.body_as_string()
	if not page_content.contains("https://api.pinterest.com/url_shortener"):
		return url
	
	var href_regex: RegEx = RegEx.new()
	href_regex.compile('<a href="(.*)">')
	var href_match: RegExMatch = href_regex.search(page_content)
	var redirect_url: String = href_match.get_string(1)
	
	response = await http_request.async_request(redirect_url)
	page_content = response.body_as_string()
	href_match = href_regex.search(page_content)
	redirect_url = href_match.get_string(1)
	
	var clean_url_regex: RegEx = RegEx.new()
	clean_url_regex.compile('(.+)\\?')
	var clean_url_match: RegExMatch = clean_url_regex.search(redirect_url)
	redirect_url = href_match.get_string(1)
	
	return redirect_url


func fetch_board(board_url: String, include_sections: bool) -> Array:
	_progress_callback.call("Searching...")
	var infos: Dictionary = await get_board_info(board_url)
	var url: String = infos.get("url", "")
	var board_id: String = infos.get("board_id", "")
	var board_name: String = infos.get("board_name", "")
	var domain: String = infos.get("domain", "pinterest.com")
	var results: Array = []
	
	if board_id.is_empty():
		_progress_callback.call("Board not found...")
		printerr("Empty board_id!")
		return [_build_result("fail", "Can't find board_id")]
	if url.is_empty():
		_progress_callback.call("Board not found...")
		printerr("Empty url!")
		return [_build_result("fail", "Can't find username")]
	
	results.append(await collect_pins(url, board_id, board_name, domain, "board"))
	if include_sections:
		var sections: Array = await fetch_board_sections(url, board_id, board_name, domain)
		for section: Dictionary in sections:
			var section_url: String = url + section.get("slug") + "/"
			results.append(await collect_pins(section_url, section.get("id"), section.get("title"), domain, "section"))
	return results


func fetch_section(board_url: String, section_slug: String) -> Array:
	_progress_callback.call("Searching...")
	var infos: Dictionary = await get_board_info(board_url)
	var url: String = infos.get("url", "")
	var board_id: String = infos.get("board_id", "")
	var board_name: String = infos.get("board_name", "")
	var domain: String = infos.get("domain", "pinterest.com")
	var results: Array = []
	
	if board_id.is_empty():
		_progress_callback.call("Board not found...")
		printerr("Empty board_id!")
		return [_build_result("fail", "Can't find board_id")]
	if url.is_empty():
		_progress_callback.call("Board not found...")
		printerr("Empty url!")
		return [_build_result("fail", "Can't find username")]
	
	var sections: Array = await fetch_board_sections(url, board_id, board_name, domain)
	for section: Dictionary in sections:
		if section.get("slug") != section_slug:
			continue
		var section_url: String = url + section.get("slug") + "/"
		results.append(await collect_pins(section_url, section.get("id"), section.get("title"), domain, "section"))
	return results

func collect_pins(url: String, board_id: String, board_name: String, domain: String, resource_type: String = "board") -> Dictionary:
	var resource_request: String = "BoardFeedResource"
	var url_handler: String = "www/[username]/[slug].js"
	if resource_type == "section":
		resource_request = "BoardSectionPinsResource"
		url_handler = "www/[username]/[slug]/[section_slug].js"
	
	var bookmarks: Array = []
	var image_urls: Array = []
	_progress_callback.call("Collecting pins...")
	for i in range(64):
		if bookmarks.find("-end-") != -1:
			break

		var params_array: Array = get_board_params(url, board_id, resource_type, bookmarks)
		var final_url: String = "https://%s/resource/%s/get/?%s" % [domain, resource_request, _query_string(params_array)]
		var result: HTTPResult = await http_request.async_request(final_url, get_header(url, url_handler), HTTPClient.METHOD_GET)
		var response: String = result.body_as_string()
		if not result.success():
			printerr(response)
			break

		var json: JSON = JSON.new()
		var err: Error = json.parse(response)
		if err != OK:
			printerr(response)
			break
		
		var raw_data: Variant = JSON.parse_string(response)
		if raw_data is not Dictionary:
			printerr("Invalid response type")
			break

		var resource: Dictionary = raw_data.get("resource_response", {})
		
		if resource.get("data", []) is String:
			printerr(resource.get("data"))
			break
			
		if resource.has("error"):
			printerr(resource.get("error"))
			break
		
		var data: Array = resource.get("data", [])
		var options: Dictionary = raw_data.get("resource", {}).get("options", {})
		bookmarks = options.get("bookmarks", [])

		for image in data:
			if image.has("images"):
				var url_image = image.get("images", {}).get("orig", {}).get("url", "")
				if url_image != "":
					image_urls.append(url_image)
			_progress_callback.call("Collecting pins (%s found)..." % [image_urls.size()])
	
	return _build_result("success", {"urls": image_urls, "board_name": board_name})


func fetch(url: String, include_sections: bool, progress_callback: Callable = _empty_progress_callback) -> Array:
	_progress_callback = progress_callback
	
	if url.is_empty() or url.get_slice_count("/") <= 0:
		return []
	
	if url.contains("pin.it"):
		url = await fetch_redirect_url(url)
	
	var result: Array = []
	
	var base_url: String = url
	base_url = base_url.trim_prefix("https://www.")
	base_url = base_url.trim_prefix("https://")
	base_url = base_url.trim_prefix("www.")
	base_url = base_url.trim_suffix("/")
	var splitted_url: Array = base_url.split("/")
	
	print(splitted_url)
	
	if splitted_url.size() <= 2:
		return []
	if splitted_url.size() == 4:
		var section_slug: String = splitted_url[3]
		var board_url: String = url.trim_suffix(section_slug + "/")
		result = await fetch_section(board_url, section_slug)
	else:
		result = await fetch_board(url, include_sections)
	
	http_request.cancel_request()
	return result


func _query_string(arr: Array) -> String:
	var query: String = ""
	for dict: Dictionary in arr:
		for key: String in dict.keys():
			var encoded_key: String = key.uri_encode()
			var value = dict[key]
			match typeof(value):
				TYPE_ARRAY:
					var values: Array = value
					for v: String in values:
						query += "&" + encoded_key + "=" +  str(v).uri_encode()
					break
				TYPE_NIL:
					query += "&" + encoded_key
					break
				_:
					query += "&" + encoded_key + "=" + str(value).uri_encode()
		
	return query.substr(1)


func _empty_progress_callback(_message: String) -> void:
	return


func _build_result(status: String, data: Variant) -> Dictionary:
	return {"status": status, "data": data}

extends Node


func get_image(url: String) -> ImageTexture:
	var im: Image = Image.new()
	for _i in range(4): # retry 4 times if it fail
		var http_request: AwaitableHTTPRequest = AwaitableHTTPRequest.new()
		
		call_deferred("add_child", http_request)
		if not http_request.is_node_ready():
			await http_request.ready
			
		var response: HTTPResult = await http_request.async_request(url)
		http_request.queue_free()
		
		if response.bytes.size() <= 0:
			continue
		
		var im_extension: String = url.get_extension()
		match im_extension.to_lower():
			"png":
				im.load_png_from_buffer(response.bytes)
			"jpg", "jpeg":
				im.load_jpg_from_buffer(response.bytes)
			"ktx":
				im.load_ktx_from_buffer(response.bytes)
			"bmp":
				im.load_bmp_from_buffer(response.bytes)
			_:
				printerr("Unsupported image extension \"%s\"." % im_extension)
		break
	return ImageTexture.create_from_image(im)

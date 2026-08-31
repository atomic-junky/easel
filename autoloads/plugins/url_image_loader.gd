extends Node

## Downloads remote images. ImageDecoder works out what they are.

const RETRIES: int = 4


func get_image(url: String) -> ImageTexture:
	for _i in RETRIES:
		var http_request: AwaitableHTTPRequest = AwaitableHTTPRequest.new()

		call_deferred("add_child", http_request)
		if not http_request.is_node_ready():
			await http_request.ready

		var response: HTTPResult = await http_request.async_request(url)
		http_request.queue_free()

		if response.bytes.size() <= 0:
			continue

		var image: Image = ImageDecoder.decode(
			response.bytes, response.headers.get("content-type", ""), url
		)
		if image == null:
			printerr("Unrecognised image data at \"%s\"." % url)
			return null

		return ImageTexture.create_from_image(image)
	return null

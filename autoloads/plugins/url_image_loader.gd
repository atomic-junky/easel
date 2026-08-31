extends Node

## Downloads remote images.
##
## The format is read from the response, not from the url: plenty of CDNs
## (Cosmos among them) serve images from extension-less urls.

const RETRIES: int = 4

const SIGNATURES: Array[Dictionary] = [
	{"format": &"png", "offset": 0, "magic": [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]},
	{"format": &"jpg", "offset": 0, "magic": [0xFF, 0xD8, 0xFF]},
	{"format": &"bmp", "offset": 0, "magic": [0x42, 0x4D]},
	{"format": &"webp", "offset": 8, "magic": [0x57, 0x45, 0x42, 0x50]},
]

const MIME_FORMATS: Dictionary = {
	"image/png": &"png",
	"image/jpeg": &"jpg",
	"image/jpg": &"jpg",
	"image/webp": &"webp",
	"image/bmp": &"bmp",
	"image/x-ms-bmp": &"bmp",
	"image/svg+xml": &"svg",
}


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

		var image: Image = decode(response.bytes, response.headers.get("content-type", ""), url)
		if image == null:
			printerr("Unrecognised image data at \"%s\"." % url)
			return null

		return ImageTexture.create_from_image(image)
	return null


## Decodes image bytes, trusting what the bytes say first, then the server's
## content type, then the url as a last resort.
static func decode(bytes: PackedByteArray, mime: String = "", url: String = "") -> Image:
	for format: StringName in [
		_format_from_bytes(bytes),
		MIME_FORMATS.get(mime.get_slice(";", 0).strip_edges().to_lower(), &""),
		StringName(url.get_basename().get_extension().to_lower()),
	]:
		if format.is_empty():
			continue

		var image := Image.new()
		if _load_buffer(image, format, bytes) == OK and not image.is_empty():
			return image

	return null


static func _format_from_bytes(bytes: PackedByteArray) -> StringName:
	for signature: Dictionary in SIGNATURES:
		var magic: Array = signature["magic"]
		var offset: int = signature["offset"]
		if bytes.size() < offset + magic.size():
			continue
		if bytes.slice(offset, offset + magic.size()) == PackedByteArray(magic):
			return signature["format"]

	if not bytes.is_empty() and bytes[0] == 0x3C: # '<', so xml or svg
		return &"svg"

	return &""


static func _load_buffer(image: Image, format: StringName, bytes: PackedByteArray) -> Error:
	match format:
		&"png": return image.load_png_from_buffer(bytes)
		&"jpg", &"jpeg": return image.load_jpg_from_buffer(bytes)
		&"webp": return image.load_webp_from_buffer(bytes)
		&"bmp": return image.load_bmp_from_buffer(bytes)
		&"tga": return image.load_tga_from_buffer(bytes)
		&"svg": return image.load_svg_from_buffer(bytes)
	return FAILED

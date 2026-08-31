class_name ImageDecoder

## Turns image bytes into an Image, whatever the source claims they are.

## Magic numbers, checked in order.
const SIGNATURES: Array[Dictionary] = [
	{"format": &"png", "offset": 0, "magic": [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]},
	{"format": &"jpg", "offset": 0, "magic": [0xFF, 0xD8, 0xFF]},
	{"format": &"gif", "offset": 0, "magic": [0x47, 0x49, 0x46, 0x38]},
	{"format": &"bmp", "offset": 0, "magic": [0x42, 0x4D]},
	{"format": &"webp", "offset": 8, "magic": [0x57, 0x45, 0x42, 0x50]},
]

const MIME_FORMATS: Dictionary = {
	"image/png": &"png",
	"image/jpeg": &"jpg",
	"image/jpg": &"jpg",
	"image/gif": &"gif",
	"image/webp": &"webp",
	"image/bmp": &"bmp",
	"image/x-ms-bmp": &"bmp",
	"image/svg+xml": &"svg",
}

const EXTENSIONS: PackedStringArray = [
	"png", "jpg", "jpeg", "gif", "webp", "bmp", "tga", "svg"
]


static func decode(bytes: PackedByteArray, mime: String = "", url: String = "") -> Image:
	for format: StringName in [
		format_from_bytes(bytes),
		MIME_FORMATS.get(mime.get_slice(";", 0).strip_edges().to_lower(), &""),
		StringName(url.get_basename().get_extension().to_lower()),
	]:
		if format.is_empty():
			continue

		var image: Image = _decode_as(format, bytes)
		if image != null and not image.is_empty():
			return image

	return null


static func load_file(path: String) -> Image:
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(path)
	return decode(bytes, "", path) if not bytes.is_empty() else null


static func handles(path: String) -> bool:
	return path.get_basename().get_extension().to_lower() in EXTENSIONS


static func format_from_bytes(bytes: PackedByteArray) -> StringName:
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


static func _decode_as(format: StringName, bytes: PackedByteArray) -> Image:
	if format == &"gif":
		return GifDecoder.decode(bytes)

	var image := Image.new()
	var error: Error = FAILED
	match format:
		&"png": error = image.load_png_from_buffer(bytes)
		&"jpg", &"jpeg": error = image.load_jpg_from_buffer(bytes)
		&"webp": error = image.load_webp_from_buffer(bytes)
		&"bmp": error = image.load_bmp_from_buffer(bytes)
		&"tga": error = image.load_tga_from_buffer(bytes)
		&"svg": error = image.load_svg_from_buffer(bytes)

	return image if error == OK else null

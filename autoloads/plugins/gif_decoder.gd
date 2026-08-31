class_name GifDecoder

## Only the first frame is decoded.

const HEADER: Array = [0x47, 0x49, 0x46] # "GIF"

const EXTENSION_BLOCK: int = 0x21
const IMAGE_BLOCK: int = 0x2C
const TRAILER_BLOCK: int = 0x3B
const GRAPHIC_CONTROL_LABEL: int = 0xF9

const MAX_CODE_SIZE: int = 12

## Row start and step of each interlacing pass.
const INTERLACE_PASSES: Array[Vector2i] = [
	Vector2i(0, 8), Vector2i(4, 8), Vector2i(2, 4), Vector2i(1, 2)
]


static func decode(bytes: PackedByteArray) -> Image:
	if bytes.size() < 13 or bytes.slice(0, 3) != PackedByteArray(HEADER):
		return null

	var canvas_width: int = bytes.decode_u16(6)
	var canvas_height: int = bytes.decode_u16(8)
	if canvas_width <= 0 or canvas_height <= 0:
		return null

	var packed: int = bytes[10]
	var pos: int = 13
	var global_palette := PackedByteArray()
	if packed & 0x80:
		var size: int = 3 * (1 << ((packed & 0x07) + 1))
		global_palette = bytes.slice(pos, pos + size)
		pos += size

	var transparent_index: int = -1

	while pos < bytes.size():
		var block: int = bytes[pos]
		pos += 1

		if block == TRAILER_BLOCK:
			break

		if block == EXTENSION_BLOCK:
			if pos >= bytes.size():
				break
			var label: int = bytes[pos]
			pos += 1
			if label == GRAPHIC_CONTROL_LABEL and pos + 5 <= bytes.size():
				if bytes[pos + 1] & 0x01:
					transparent_index = bytes[pos + 4]
			pos = _skip_sub_blocks(bytes, pos)
			continue

		if block != IMAGE_BLOCK or pos + 9 > bytes.size():
			break

		return _decode_frame(
			bytes, pos, canvas_width, canvas_height, global_palette, transparent_index
		)

	return null


static func _decode_frame(
	bytes: PackedByteArray,
	pos: int,
	canvas_width: int,
	canvas_height: int,
	global_palette: PackedByteArray,
	transparent_index: int
) -> Image:
	var left: int = bytes.decode_u16(pos)
	var top: int = bytes.decode_u16(pos + 2)
	var width: int = bytes.decode_u16(pos + 4)
	var height: int = bytes.decode_u16(pos + 6)
	var packed: int = bytes[pos + 8]
	pos += 9

	var palette: PackedByteArray = global_palette
	if packed & 0x80:
		var size: int = 3 * (1 << ((packed & 0x07) + 1))
		palette = bytes.slice(pos, pos + size)
		pos += size

	if width <= 0 or height <= 0 or palette.is_empty() or pos >= bytes.size():
		return null

	var minimum_code_size: int = bytes[pos]
	pos += 1
	if minimum_code_size < 2 or minimum_code_size > 11:
		return null

	var compressed := PackedByteArray()
	while pos < bytes.size() and bytes[pos] != 0:
		var length: int = bytes[pos]
		compressed.append_array(bytes.slice(pos + 1, pos + 1 + length))
		pos += 1 + length

	var indices: PackedByteArray = _lzw_decode(compressed, minimum_code_size, width * height)
	if indices.is_empty():
		return null

	var pixels := PackedByteArray()
	pixels.resize(canvas_width * canvas_height * 4)
	pixels.fill(0)

	var interlaced: bool = bool(packed & 0x40)
	for row in height:
		var target_row: int = _interlaced_row(row, height) if interlaced else row
		if top + target_row >= canvas_height:
			continue

		for column in width:
			if left + column >= canvas_width:
				continue

			var index: int = row * width + column
			if index >= indices.size():
				break

			var color: int = indices[index]
			if color == transparent_index or color * 3 + 2 >= palette.size():
				continue

			var offset: int = ((top + target_row) * canvas_width + left + column) * 4
			pixels[offset] = palette[color * 3]
			pixels[offset + 1] = palette[color * 3 + 1]
			pixels[offset + 2] = palette[color * 3 + 2]
			pixels[offset + 3] = 255

	return Image.create_from_data(
		canvas_width, canvas_height, false, Image.FORMAT_RGBA8, pixels
	)


## Interlaced gifs store rows in four passes instead of top to bottom.
static func _interlaced_row(row: int, height: int) -> int:
	var seen: int = 0
	for pass_info: Vector2i in INTERLACE_PASSES:
		var rows_in_pass: int = ceili(float(height - pass_info.x) / pass_info.y)
		if row < seen + rows_in_pass:
			return pass_info.x + (row - seen) * pass_info.y
		seen += rows_in_pass
	return row


static func _skip_sub_blocks(bytes: PackedByteArray, pos: int) -> int:
	while pos < bytes.size() and bytes[pos] != 0:
		pos += 1 + bytes[pos]
	return pos + 1


static func _lzw_decode(
	data: PackedByteArray, minimum_code_size: int, pixel_count: int
) -> PackedByteArray:
	var clear_code: int = 1 << minimum_code_size
	var end_code: int = clear_code + 1

	var dictionary: Array[PackedByteArray] = []
	var code_size: int = minimum_code_size + 1
	var previous := PackedByteArray()
	var output := PackedByteArray()

	var bit: int = 0
	var total_bits: int = data.size() * 8
	_reset_dictionary(dictionary, clear_code)

	while bit + code_size <= total_bits and output.size() < pixel_count:
		var code: int = _read_bits(data, bit, code_size)
		bit += code_size

		if code == clear_code:
			_reset_dictionary(dictionary, clear_code)
			code_size = minimum_code_size + 1
			previous = PackedByteArray()
			continue

		if code == end_code:
			break

		var entry: PackedByteArray
		if code < dictionary.size():
			entry = dictionary[code]
		elif code == dictionary.size() and not previous.is_empty():
			entry = previous + PackedByteArray([previous[0]])
		else:
			break

		output.append_array(entry)

		if not previous.is_empty():
			dictionary.append(previous + PackedByteArray([entry[0]]))
			if dictionary.size() == 1 << code_size and code_size < MAX_CODE_SIZE:
				code_size += 1

		previous = entry

	return output


static func _reset_dictionary(dictionary: Array[PackedByteArray], clear_code: int) -> void:
	dictionary.clear()
	for i in clear_code:
		dictionary.append(PackedByteArray([i]))
	dictionary.append(PackedByteArray()) # clear
	dictionary.append(PackedByteArray()) # end


## Gif codes are packed least significant bit first and straddle byte edges.
static func _read_bits(data: PackedByteArray, bit: int, count: int) -> int:
	var value: int = 0
	for i in count:
		var index: int = bit + i
		value |= ((data[index >> 3] >> (index & 7)) & 1) << i
	return value

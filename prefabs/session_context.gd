class_name SessionContext

enum Type {
	STANDARD,
	CLASS,
	RELAXED,
	CUSTOM
}


var session_type: Type = Type.STANDARD
var number_of_images: int = -1
var time_per_image: int = 60 # in seconds
var class_data: Array = []
var shuffle: bool = true
var reverse: bool = false
var packs: Array[PackContext] = []


func get_images_path() -> Array:
	var all_paths: Array = get_images_path_raw()
	var image_count = all_paths.size()
	
	if shuffle:
		all_paths.shuffle()
	elif reverse:
		all_paths.reverse()
		
	if image_count <= number_of_images or number_of_images < 0:
		return all_paths

	var result: Array = []
	for i in number_of_images:
		result.append(all_paths.pop_front())
	return result


func get_images_path_raw() -> Array:
	var all_paths: Array[String] = []
	for pack: PackContext in get_packs():
		all_paths.append_array(pack.image_paths)
	
	return all_paths


func get_image_count(only_enabled: bool = true) -> int:
	var count: int = 0
	for pack: PackContext in packs:
		if pack.enabled or not only_enabled:
			count += pack.image_count
	return count


func get_packs() -> Array[PackContext]:
	return packs.filter(func(p: PackContext): return p.enabled)


func get_image_duration(idx: int) -> int:
	if session_type == Type.CLASS:
		return class_data[idx]
	return time_per_image

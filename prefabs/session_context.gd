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
	var all_images: Array = get_images_path_raw()
	var image_count: int = all_images.size()

	if shuffle:
		all_images.shuffle()
	elif reverse:
		all_images.reverse()

	var result: Array = []

	# For CLASS and CUSTOM sessions, follow the sequence exactly as defined
	if session_type in [Type.CLASS, Type.CUSTOM]:
		var seq: Array = _get_all_poses()
		for idx in seq.size():
			var item: Dictionary = seq[idx]
			var pose_type: String = String(item.get("type", "pose"))
			var pose_duration: int = int(item.get("duration", time_per_image))
			var pose_data: Dictionary = {
				"type": pose_type,
				"duration": pose_duration
			}
			if pose_type == "pose":
				# Guard against empty image pool
				if all_images.is_empty():
					break
				var next_image: Dictionary = all_images.pop_front()
				pose_data["path"] = next_image.get("path", "")
				pose_data["name"] = next_image.get("name", "Unknown")
			result.append(pose_data)
		return result

	# STANDARD and other types: use number_of_images and time_per_image
	if number_of_images < 0:
		number_of_images = image_count
	if number_of_images > image_count:
		number_of_images = image_count

	for _i in number_of_images:
		if all_images.is_empty():
			break
		var next_image: Dictionary = all_images.pop_front()
		result.append({
			"type": "pose",
			"duration": time_per_image,
			"path": next_image.get("path", ""),
			"name": next_image.get("name", "Unknown")
		})
	return result


func get_images_path_raw() -> Array:
	var all_paths: Array = []
	for pack: PackContext in get_packs():
		all_paths.append_array(pack.images)
	
	return all_paths


func get_image_count(only_enabled: bool = true) -> int:
	var count: int = 0
	for pack: PackContext in packs:
		if pack.enabled or not only_enabled:
			count += pack.image_count
	return count


func get_packs() -> Array[PackContext]:
	return packs.filter(func(p: PackContext): return p.enabled)


func get_pose_type(idx: int) -> String:
	if session_type in [Type.CLASS, Type.CUSTOM]:
		return _get_all_poses()[idx]["type"]
	return "pose"


func get_pose_duration(idx: int) -> int:
	if session_type in [Type.CLASS, Type.CUSTOM]:
		return _get_all_poses()[idx]["duration"]
	return time_per_image


func _get_all_poses() -> Array:
	var poses: Array = []
	for pose: Dictionary in class_data:
		for _i in pose.get("amount", 1):
			poses.append({
				"type": pose.get("type"),
				"duration": pose.get("duration")
			})
	return poses

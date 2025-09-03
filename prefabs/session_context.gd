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
	var image_count = all_images.size()
	
	if shuffle:
		all_images.shuffle()
	elif reverse:
		all_images.reverse()
		
	if number_of_images < 0:
		number_of_images = image_count
	
	if number_of_images > image_count:
		number_of_images = image_count

	var result: Array = []
	for idx in number_of_images:
		var pose_type: String = get_pose_type(idx)
		var pose_duration: int = get_pose_duration(idx)
		var pose_data: Dictionary = {
			"type": pose_type,
			"duration": pose_duration
		}
		
		if pose_type == "pose":
			pose_data["path"] = all_images.pop_front()["path"]
			pose_data["name"] = all_images.pop_front()["name"]
			
		result.append(pose_data)
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

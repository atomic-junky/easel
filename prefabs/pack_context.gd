class_name PackContext extends RefCounted

const SUPPORTED_EXTENSIONS := ["png", "jpeg", "jpg", "tiff", "PNG", "JPG", "JPEG"]

var enabled: bool = true
var source: Constants.Source = Constants.Source.FOLDER
var pack_name: String = "Invalid"
var path: String = ""
var image_paths: Array = []
var image_count: int : 
	get():
		return image_paths.size()


static func create_from_path(path: String) -> Array[PackContext]:
	var pack := PackContext.new()
	var dir_name: String = path.replace("\\", "/").split("/")[-1]
	
	pack.path = path
	pack.enabled = true
	pack.source = Constants.Source.FOLDER
	pack.pack_name = dir_name
	pack.image_paths = PackContext._recursive_load_dir(path)
	return [pack]


static func create_from_paths(paths: Array) -> Array[PackContext]:
	var pack := PackContext.new()
	
	for path in paths:
		if path.get_extension() not in SUPPORTED_EXTENSIONS:
			paths.erase(path)
	
	pack.path = paths[0]
	pack.enabled = true
	pack.source = Constants.Source.IMAGES
	pack.pack_name = "Image pack"
	pack.image_paths = paths
	return [pack]


static func create_from_urls(data: Dictionary) -> PackContext:
	var urls: Array = data.get("urls", [])
	var board_name: String = data.get("board_name", "Unknown")
	
	var pack: PackContext = PackContext.new()
	pack.source = Constants.Source.PINTEREST
	pack.pack_name = board_name
	pack.image_paths = urls
	return pack


static func _recursive_load_dir(base_dir_path: String, max_depth: int = 32) -> Array:
	var result: Array = []
	
	if max_depth <= 0:
		push_warning("Max depth reach!")
		return []
	
	for file_name: String in DirAccess.get_files_at(base_dir_path):
		var file_path: String = base_dir_path.path_join(file_name)
		if file_path.get_extension() in SUPPORTED_EXTENSIONS:
			result.append(file_path)
	
	for dir_name: String in DirAccess.get_directories_at(base_dir_path):
		var dir_path: String = base_dir_path.path_join(dir_name)
		result.append_array(PackContext._recursive_load_dir(dir_path, max_depth-1))
	
	return result

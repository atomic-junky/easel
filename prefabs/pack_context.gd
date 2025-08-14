class_name PackContext extends RefCounted

const SUPPORTED_EXTENSIONS := ["png", "jpeg", "jpg", "tiff", "PNG", "JPG", "JPEG"]

var enabled: bool = true
var source: Constants.Source = Constants.Source.FOLDER
var pack_name: String = "Invalid"
var path: String = ""
var image_paths: Array = []
var image_count: int = 0


static func create_from_path(path: String) -> Array[PackContext]:
	var packs: Array[PackContext] = []
	
	var base_path: String = path
	var directories: Array = []
	if DirAccess.get_files_at(path).size() > 0:
		var dir_name: String = path.replace("\\", "/").get_slice("/", -1)
		directories.append(dir_name)
		base_path = path.trim_suffix(dir_name)
	else:
		var dir_access: DirAccess = DirAccess.open(path)
		directories.append_array(dir_access.get_directories())
	
	for dir_name: String in directories:
		var pack := PackContext.new()
		var dir_path: String = base_path.path_join(dir_name)
		
		pack.path = path
		pack.enabled = true
		pack.source = Constants.Source.FOLDER
		pack.pack_name = dir_name
		pack.image_paths = PackContext._recursive_load_dir(dir_path)
		pack.image_count = pack.image_paths.size()
		
		if pack.image_paths.size() > 0:
			packs.append(pack)
	
	return packs


static func create_from_urls(data: Dictionary) -> PackContext:
	var urls: Array = data.get("urls", [])
	var board_name: String = data.get("board_name", "Unknown")
	
	var pack: PackContext = PackContext.new()
	pack.source = Constants.Source.PINTEREST
	pack.pack_name = board_name
	pack.image_paths = urls
	pack.image_count = pack.image_paths.size()
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

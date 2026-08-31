class_name PackResource extends Resource

@export var enabled: bool = true
@export var source: Constants.Source = Constants.Source.FOLDER
@export var pack_name: String = "Invalid"
@export var path: String = ""
@export var images: Array[Dictionary] = []

@export var plugin_params: Dictionary = {}
@export var plugin_id: StringName = &""

var image_count: int :
	get():
		return images.size()


static func create_from_path(pack_path: String) -> Array[PackResource]:
	var pack := PackResource.new()
	var dir_name: String = pack_path.replace("\\", "/").split("/")[-1]
	
	pack.path = pack_path
	pack.enabled = true
	pack.source = Constants.Source.FOLDER
	pack.pack_name = dir_name
	pack.images = PackResource._recursive_load_dir(pack_path)
	return [pack]


static func create_from_paths(paths: Array) -> Array[PackResource]:
	var pack := PackResource.new()
	
	for pack_path: String in paths:
		if not ImageDecoder.handles(pack_path):
			paths.erase(pack_path)
			continue
		pack.images.append({ "path": pack_path, "name": pack_path.get_file() })
	
	pack.path = paths[0]
	pack.enabled = true
	pack.source = Constants.Source.IMAGES
	pack.pack_name = "Image pack"
	return [pack]


static func create_from_fetch(
	result: PackFetchResult,
	from_plugin: StringName,
	params: Dictionary = {}
) -> PackResource:
	var pack: PackResource = PackResource.new()
	pack.source = Constants.Source.PLUGIN
	pack.plugin_id = from_plugin
	pack.plugin_params = params.duplicate()
	pack.pack_name = result.pack_name
	pack.path = result.url
	pack.images = result.images.duplicate()
	return pack


## Packs saved before plugins had ids still carry the old PINTEREST source.
func fetch_plugin_id() -> StringName:
	if not plugin_id.is_empty():
		return plugin_id
	return &"pinterest" if source == Constants.Source.PINTEREST else &""


static func _recursive_load_dir(base_dir_path: String, max_depth: int = 32) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	
	if max_depth <= 0:
		push_warning("Max depth reach!")
		return []
	
	for file_name: String in DirAccess.get_files_at(base_dir_path):
		var file_path: String = base_dir_path.path_join(file_name)
		if ImageDecoder.handles(file_path):
			result.append({ "path": file_path, "name": file_name })
	
	for dir_name: String in DirAccess.get_directories_at(base_dir_path):
		var dir_path: String = base_dir_path.path_join(dir_name)
		result.append_array(PackResource._recursive_load_dir(dir_path, max_depth-1))
	
	return result

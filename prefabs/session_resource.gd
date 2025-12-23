class_name SessionResource extends Resource

## A saveable/loadable session configuration for GestureApp.
##
## SessionResource (formerly SessionContext) represents a complete session configuration
## including session type, image packs, timing settings, and session-specific data.
##
## Can be saved to and loaded from .gsession files using:
## - save_to_file(path: String) -> int
## - load_from_file(path: String) -> SessionResource (static)
##
## Usage:
##   var session := SessionResource.new()
##   session.session_type = SessionResource.Type.STANDARD
##   session.packs = [pack1, pack2]
##   session.save_to_file("user://my_session.gsession")
##
##   var loaded := SessionResource.load_from_file("user://my_session.gsession")

enum Type {
	STANDARD,
	CLASS,
	RELAXED,
	CUSTOM
}

@export var session_type: Type = Type.STANDARD
@export var number_of_images: int = -1  # -1 means unset, will use field default
## time_per_image supprimé, la durée est toujours lue depuis le champ 'duration' du dictionnaire de la séquence
@export var duration: int = -1  # -1 means unset, will use field default (for CLASS mode)
@export var sequence: Array = []
@export var shuffle: bool = true  # Default value for image ordering
@export var reverse: bool = false  # Default value for image ordering
@export var packs: Array[PackResource] = []
@export var settings: Dictionary = {}


func get_images_path() -> Array:
	# Retourne la séquence telle qu'elle est
	return sequence
		
		


func get_images_path_raw() -> Array:
	var all_paths: Array = []
	for pack: PackResource in get_packs():
		all_paths.append_array(pack.images)
	
	return all_paths


func get_image_count(only_enabled: bool = true) -> int:
	var count: int = 0
	for pack: PackResource in packs:
		if pack.enabled or not only_enabled:
			count += pack.image_count
	return count


func get_packs() -> Array[PackResource]:
	return packs.filter(func(p: PackResource): return p.enabled)


func get_pose_type(idx: int) -> String:
	return sequence[idx]["type"]


func get_pose_duration(idx: int) -> int:
	return sequence[idx]["duration"]


## La séquence est déjà une liste de dictionnaires, pas besoin de transformer


## Save this session resource to a .gsession file
func save_to_file(file_path: String) -> int:
	# Ensure .gsession extension
	if not file_path.ends_with(".gsession"):
		file_path += ".gsession"
	
	var result := ResourceSaver.save(self, file_path)
	if result == OK:
		print("[SessionResource] Saved session to: ", file_path)
	else:
		printerr("[SessionResource] Failed to save session to: ", file_path, " error: ", result)
	return result


## Load a session resource from a .gsession file
static func load_from_file(file_path: String) -> SessionResource:
	if not FileAccess.file_exists(file_path):
		printerr("[SessionResource] File does not exist: ", file_path)
		return null
	
	var resource := ResourceLoader.load(file_path, "", ResourceLoader.CACHE_MODE_IGNORE)
	if resource is SessionResource:
		print("[SessionResource] Loaded session from: ", file_path)
		return resource
	else:
		printerr("[SessionResource] Failed to load valid session from: ", file_path)
		return null

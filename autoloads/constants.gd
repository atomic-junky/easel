extends Node

enum Source {
	FOLDER,
	IMAGES,
	LIBRARY,
	PINTEREST,
	PLUGIN
}

const PREFERENCES_PATH = "user://preferences.cfg"
const SUPPORTED_EXTENSIONS := ["png", "jpeg", "jpg", "tiff"]

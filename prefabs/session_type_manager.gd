## Manages available session types and their configurations
## Allows for easy addition of new session types without hardcoding
class_name SessionTypeManager extends RefCounted

static var _session_type_configs: Dictionary = {}
static var _initialized: bool = false


## Initialize default session types
static func initialize() -> void:
	if _initialized:
		return
	
	_initialized = true
	_register_default_types()


## Register a session type configuration
static func register_type(config: SessionTypeConfig) -> void:
	if not config.enabled:
		return
	_session_type_configs[config.session_type] = config


## Get configuration for a session type
static func get_config(session_type: SessionContext.Type) -> SessionTypeConfig:
	if not _initialized:
		initialize()
	return _session_type_configs.get(session_type)


## Get all enabled session types
static func get_enabled_types() -> Array[SessionContext.Type]:
	if not _initialized:
		initialize()
	var types: Array[SessionContext.Type] = []
	for type_key in _session_type_configs.keys():
		types.append(type_key)
	return types


## Register default session type configurations
static func _register_default_types() -> void:
	# Standard session
	var standard_config := SessionTypeConfig.new()
	standard_config.session_type = SessionContext.Type.STANDARD
	standard_config.display_name = "Standard"
	standard_config.enabled = true
	standard_config.requires_validation = false
	standard_config.default_number_of_images = 0
	standard_config.default_time_per_image = 60
	standard_config.default_shuffle = true
	register_type(standard_config)
	
	# Class session
	var class_config := SessionTypeConfig.new()
	class_config.session_type = SessionContext.Type.CLASS
	class_config.display_name = "Class"
	class_config.enabled = true
	class_config.requires_validation = true
	register_type(class_config)
	
	# Relaxed session
	var relaxed_config := SessionTypeConfig.new()
	relaxed_config.session_type = SessionContext.Type.RELAXED
	relaxed_config.display_name = "Relaxed"
	relaxed_config.enabled = true
	relaxed_config.requires_validation = false
	relaxed_config.default_number_of_images = -1
	relaxed_config.default_time_per_image = -1
	relaxed_config.default_shuffle = true
	register_type(relaxed_config)
	
	# Custom session
	var custom_config := SessionTypeConfig.new()
	custom_config.session_type = SessionContext.Type.CUSTOM
	custom_config.display_name = "Custom"
	custom_config.enabled = true
	custom_config.requires_validation = true
	register_type(custom_config)

## Configuration resource for session types
## Allows defining session behavior through data instead of code
class_name SessionTypeConfig extends Resource

## The type of session this config represents
@export var session_type: SessionContext.Type = SessionContext.Type.STANDARD

## Human-readable name
@export var display_name: String = ""

## Whether this session type is enabled
@export var enabled: bool = true

## Whether this session type requires validation
@export var requires_validation: bool = false

## Default values for the session
@export_group("Default Values")
@export var default_number_of_images: int = -1
@export var default_time_per_image: int = 60
@export var default_shuffle: bool = true
@export var default_reverse: bool = false

## Custom session data (for class mode, etc.)
@export var custom_data: Dictionary = {}


func apply_to_context(context: SessionContext) -> void:
	"""Apply this configuration to a session context"""
	context.session_type = session_type
	context.shuffle = default_shuffle
	context.reverse = default_reverse
	
	if default_number_of_images >= 0:
		context.number_of_images = default_number_of_images
	
	if default_time_per_image >= 0:
		context.time_per_image = default_time_per_image

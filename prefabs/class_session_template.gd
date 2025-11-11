## Represents a template for class-based drawing sessions
## Defines the structure of poses and breaks with durations
class_name ClassSessionTemplate extends Resource

## Duration in minutes
@export var duration_minutes: int = 30

## Human-readable name
@export var template_name: String = ""

## The sequence of poses and breaks
@export var session_sequence: Array[Dictionary] = []


func _init(p_duration: int = 30, p_name: String = "") -> void:
	duration_minutes = p_duration
	template_name = p_name if not p_name.is_empty() else "%d min" % p_duration


## Create a session template with the given sequence
static func create(
	duration: int,
	name: String,
	sequence: Array[Dictionary]
) -> ClassSessionTemplate:
	var template := ClassSessionTemplate.new(duration, name)
	template.session_sequence = sequence
	return template


## Get the total number of poses in this template
func get_pose_count() -> int:
	var count: int = 0
	for item in session_sequence:
		if item.get("type") == "pose":
			count += item.get("amount", 1)
	return count


## Get the total duration in seconds
func get_total_duration() -> int:
	var total: int = 0
	for item in session_sequence:
		total += item.get("duration", 0) * item.get("amount", 1)
	return total


## Validate that the template is correctly configured
func validate() -> bool:
	if session_sequence.is_empty():
		push_warning("Empty session sequence in template '%s'" % template_name)
		return false
	
	var calculated_duration := get_total_duration()
	var expected_duration := duration_minutes * 60
	
	if calculated_duration != expected_duration:
		push_error(
			"Template '%s' duration mismatch: calculated %d seconds, expected %d seconds" %
			[template_name, calculated_duration, expected_duration]
		)
		return false
	
	return true

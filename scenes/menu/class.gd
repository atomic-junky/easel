extends SessionType

@onready var image_order_container: ImageOrder = $ImageOrderContainer

var class_session: Array = []
var shuffle: bool = false
var reverse: bool = false



func apply_context(context: SessionContext):
	var total_duration: int = 0
	var number_of_images: int = 0
	for pose in class_session:
		total_duration += pose.get("duration") * pose.get("amount", 1)
		if pose.get("type") == "poses":
			number_of_images += pose.get("ammout")
	
	context.session_type = SessionContext.Type.CLASS
	context.class_data = class_session
	context.number_of_images = number_of_images
	context.shuffle = shuffle
	context.reverse = reverse
	context.session_type = SessionContext.Type.STANDARD


func is_valid() -> bool:
	return !class_session.is_empty()


func _on_class_duration_switcher_value_changed(value: int) -> void:
	var session: Array = []
	
	match value:
		30:
			session = [
				{"type": "poses", "duration": 30, "amount": 10}, # 5min
				{"type": "poses", "duration": 60, "amount": 5}, # 10min (5min)
				{"type": "poses", "duration": 5*60, "amount": 2}, # 20min (10min)
				{"type": "poses", "duration": 10*60, "amount": 1}, # 30min (10min)
			]
		60:
			session = [
				{"type": "poses", "duration": 30, "amount": 10}, # 5min
				{"type": "poses", "duration": 60, "amount": 5}, # 10min (5min)
				{"type": "poses", "duration": 5*60, "amount": 2}, # 20min (10min)
				{"type": "poses", "duration": 10*60, "amount": 1}, # 30min (10min)
				{"type": "pose", "duration": 5*60}, # 35min (5min)
				{"type": "break", "duration": 25*60, "amount": 1}, # 60min (25min)
			]
		90:
			session = [
				{"type": "poses", "duration": 30, "amount": 10}, # 5min
				{"type": "poses", "duration": 60, "amount": 5}, # 10min (5min)
				{"type": "poses", "duration": 5*60, "amount": 3}, # 25min (15min)
				{"type": "break", "duration": 5*60}, # 40min (5min)
				{"type": "poses", "duration": 10*60, "amount": 2}, # 60min (20min)
				{"type": "poses", "duration": 30*60, "amount": 1}, # 90min (30min)
			]
		120:
			session = [
				{"type": "poses", "duration": 60, "amount": 5}, # 5min
				{"type": "poses", "duration": 5*60, "amount": 3}, # 20min (15min)
				{"type": "break", "duration": 5*60}, # 25min (5min)
				{"type": "poses", "duration": 10*60, "amount": 2}, # 45min (20min)
				{"type": "poses", "duration": 20*60, "amount": 1}, # 65min  (20min)
				{"type": "break", "duration": 5*60}, # 70min (5min)
				{"type": "poses", "duration": 50*60, "amount": 1}, # 120min (50min)
			]
		180:
			session = [
				{"type": "poses", "duration": 60, "amount": 5}, # 5min
				{"type": "poses", "duration": 5*60, "amount": 3}, # 20min (15min)
				{"type": "poses", "duration": 10*60, "amount": 2}, # 40min (20min)
				{"type": "break", "duration": 5*60}, # 45min (5min)
				{"type": "poses", "duration": 20*60, "amount": 2}, # 85min  (40min)
				{"type": "break", "duration": 5*60}, # 90min (5min)
				{"type": "poses", "duration": 30*60, "amount": 1}, # 120min (30min)
				{"type": "poses", "duration": 60*60, "amount": 1}, # 180min (60min)
			]
	
	assert(!session.is_empty(), "Invalid session time %s" % value)
	
	var total_duration: int = 0
	for pose in session:
		total_duration += pose.get("duration") * pose.get("amount", 1)
	
	if total_duration != total_duration:
		push_error("Session duration do not correspond to button value. (%s and %s)" % [total_duration, value])
	
	class_session = session


func _on_image_order_container_value_changed() -> void:
	shuffle = image_order_container.shuffle
	reverse = image_order_container.reverse

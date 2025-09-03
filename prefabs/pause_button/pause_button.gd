class_name PauseButton extends Button


@onready var panel: Panel = %Panel


func set_time(new_time: float, max_time: float) -> void:
	var time_left: int = round(new_time)
	var minutes: int = floor(time_left/60)
	var seconds: int = time_left-(minutes*60)
	text = "%s:%02d" % [minutes, seconds]
	
	var panel_size_x: int = remap(new_time, 0, max_time, -4, size.x) + 2
	panel.size.x = panel_size_x

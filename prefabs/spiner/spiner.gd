class_name LoadingSpiner extends TextureRect


func _ready() -> void:
	pivot_offset = size/2
	
	spin()

func spin() -> void:
	var tween: Tween = create_tween()
	tween.tween_property(self, "rotation_degrees", 0, 0)
	tween.tween_property(self, "rotation_degrees", 360, 0.5)
	await tween.finished
	spin()

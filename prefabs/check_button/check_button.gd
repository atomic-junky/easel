extends Button

@onready var animation_player: AnimationPlayer = %AnimationPlayer


func _ready() -> void:
	pass


func _on_toggled(toggled_on: bool) -> void:
	if not is_node_ready():
		return
	
	if toggled_on:
		animation_player.play("switch")
	else:
		animation_player.play_backwards("switch")
	
	if not has_focus():
		animation_player.seek(animation_player.current_animation_length, true)

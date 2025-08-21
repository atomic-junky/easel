extends Button

@onready var animation_player: AnimationPlayer = %AnimationPlayer


func _ready() -> void:
	pass


func _on_toggled(toggled_on: bool) -> void:
	if not is_node_ready():
		return
	
	if toggled_on:
		animation_player.play("switch")
		return
	animation_player.play_backwards("switch")

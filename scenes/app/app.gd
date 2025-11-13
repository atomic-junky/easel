extends Control

@onready var aspect_ration: AspectRatioContainer = %AspectRatioContainer

var menu_scene: String = "res://scenes/menu/menu.tscn"
var session_scene: String = "res://scenes/session/session.tscn"
var current_view: Control : get = _get_view

var context: SessionResource

func _ready():
	_on_resized()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		get_tree().quit_on_go_back = current_view is Menu


func _get_view() -> Control:
	return aspect_ration.get_child(0)


func _on_view_done(new_context: SessionResource = SessionResource.new()) -> void:
	context = new_context
	var scene_path: String
	if current_view is Menu:
		scene_path = session_scene
	else:
		scene_path = menu_scene
		
	await SceneLoader.switch_scene(aspect_ration, current_view, scene_path)


func _on_resized() -> void:
	if not is_node_ready():
		return
	
	var vp_size: Vector2 = get_viewport_rect().size
	aspect_ration.ratio = vp_size.x/vp_size.y


func _on_aspect_ratio_container_child_entered_tree(node: Node) -> void:
	node.connect("done", _on_view_done)

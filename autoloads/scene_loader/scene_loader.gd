extends CanvasLayer

signal finish

const PRELOAD_ANIM := "Preload"
const POSTLOAD_ANIM := "Postload"

var _is_loading := false
var _use_transition := false
var _progress := [0.0] # Toujours initialisé
var _scene_path := ""
var _base_node: Node = null
var _replace_node: Node = null

@onready var _animator: AnimationPlayer = %animator
@onready var _progress_bar: ProgressBar = %progress_bar
@onready var _background: ColorRect = %background

func _ready() -> void:
	_background.visible = false
	_background.modulate = Color(1, 1, 1, 0)

func switch_scene(base_node: Node, replace_node: Node, new_scene_path: String, use_transition: bool = false) -> void:
	if _is_loading:
		push_error("SceneLoader: A scene load is already in progress.")
		return
	
	_is_loading = true
	_use_transition = use_transition
	_base_node = base_node
	_replace_node = replace_node
	_scene_path = new_scene_path
	
	# Lancement en différé pour ne pas bloquer le frame courant
	call_deferred("_start_loading")
	await finish

func _start_loading() -> void:
	if _use_transition:
		_play_animation(PRELOAD_ANIM)
	
	var error := ResourceLoader.load_threaded_request(_scene_path)
	if error != OK:
		push_error("SceneLoader: Failed to request load for %s (error %s)" % [_scene_path, error])
		_is_loading = false

func _process(_delta: float) -> void:
	if not _is_loading:
		return
	
	var status := ResourceLoader.load_threaded_get_status(_scene_path, _progress)
	_progress_bar.value = clamp(_progress[0] * 100, 0, 100)
	
	match status:
		ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			pass
		ResourceLoader.THREAD_LOAD_LOADED:
			_finalize_scene_switch()
		ResourceLoader.THREAD_LOAD_FAILED:
			push_error("SceneLoader: Failed to load scene: %s" % _scene_path)
			_is_loading = false


func _finalize_scene_switch() -> void:
	var packed_scene: PackedScene = ResourceLoader.load_threaded_get(_scene_path)
	if packed_scene == null:
		push_error("SceneLoader: PackedScene is null after loading.")
		_is_loading = false
		return
	
	var args: Variant
	
	# Suppression de l'ancienne scène
	if _replace_node and is_instance_valid(_replace_node):
		if _replace_node.has_method("get_args"):
			args = _replace_node.get_args()
		_replace_node.queue_free()
	
	# Ajout de la nouvelle
	var new_instance := packed_scene.instantiate()
	if new_instance.has_method("load_args"):
		new_instance.load_args(args)
	_base_node.add_child(new_instance)
	
	if _use_transition:
		_play_animation(POSTLOAD_ANIM)
	
	# Reset
	_is_loading = false
	_progress[0] = 0.0
	finish.emit()

func _play_animation(anim_name: String) -> void:
	if _animator and _animator.has_animation(anim_name):
		_animator.play(anim_name)

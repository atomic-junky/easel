class_name Modal extends Control

## Centered dialog over a blurred backdrop.
##
## Content is authored as direct children of the Modal node in the parent scene;
## on ready they are moved into the panel. Children in the "modal_footer" group
## are pinned to the bottom, everything else is centered.

signal closed

const MAX_SIZE: Vector2 = Vector2(550, 400)
const SCREEN_MARGIN: float = 50.0

@export var title: String = "":
	set(value):
		title = value
		if is_node_ready():
			%ModalTitle.text = value


func _ready() -> void:
	for child in get_children():
		if child.name in ["Dimmer", "Center"]:
			continue
		child.reparent(%ModalFooter if child.is_in_group(&"modal_footer") else %ModalContent)

	%ModalTitle.text = title
	resized.connect(_on_resized)
	_on_resized()
	hide()


func open() -> void:
	show()
	_animate(0.92, 1.0, 0.0, 1.0)


func close() -> void:
	await _animate(1.0, 0.96, 1.0, 0.0)
	hide()
	closed.emit()


func _animate(from_scale: float, to_scale: float, from_alpha: float, to_alpha: float) -> void:
	var panel: Control = %ModalPanel
	panel.pivot_offset = panel.size / 2.0
	panel.scale = Vector2(from_scale, from_scale)
	modulate.a = from_alpha

	var tween: Tween = create_tween().set_parallel()
	tween.tween_property(panel, "scale", Vector2(to_scale, to_scale), 0.18) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "modulate:a", to_alpha, 0.14)
	await tween.finished


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		close()
		accept_event()


func _shortcut_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed(&"ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


func _on_resized() -> void:
	%ModalPanel.custom_minimum_size = Vector2(
		minf(MAX_SIZE.x, size.x - SCREEN_MARGIN),
		minf(MAX_SIZE.y, size.y - SCREEN_MARGIN)
	)

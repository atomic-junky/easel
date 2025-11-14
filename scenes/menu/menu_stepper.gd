class_name MenuStepper
extends VBoxContainer

## Custom stepper/breadcrumb navigation for menu with step validation

signal step_changed(step_index: int)
signal step_completed(step_index: int)

enum StepStatus {
	LOCKED,     # Cannot access yet
	CURRENT,    # Currently active
	COMPLETED,  # Can go back to this step
	AVAILABLE   # Can proceed to this step
}

@export var steps: Array[String] = ["Session", "Packs", "Mode"]
@export var current_step: int = 0

var _step_buttons: Array[Button] = []
var _step_status: Array[StepStatus] = []

@onready var breadcrumb_container: HBoxContainer = null


func _ready() -> void:
	_build_breadcrumbs()
	_update_breadcrumbs()


func _build_breadcrumbs() -> void:
	# Create breadcrumb container
	breadcrumb_container = HBoxContainer.new()
	breadcrumb_container.alignment = BoxContainer.ALIGNMENT_CENTER
	breadcrumb_container.add_theme_constant_override("separation", 10)
	add_child(breadcrumb_container)
	
	# Initialize step status
	_step_status.resize(steps.size())
	for i in steps.size():
		_step_status[i] = StepStatus.LOCKED
	
	_step_status[0] = StepStatus.CURRENT
	
	# Create step buttons as large clickable panels
	for i in steps.size():
		if i > 0:
			# Add arrow separator
			var arrow := Label.new()
			arrow.text = "→"
			arrow.add_theme_font_size_override("font_size", 28)
			arrow.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5, 0.6))
			arrow.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			breadcrumb_container.add_child(arrow)
		
		# Create step button (large button style)
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(140, 70)
		
		# Create label with step number and name
		btn.text = str(i + 1) + "\n" + steps[i]
		btn.add_theme_font_size_override("font_size", 16)
		
		btn.disabled = true
		btn.pressed.connect(_on_step_button_pressed.bind(i))
		breadcrumb_container.add_child(btn)
		_step_buttons.append(btn)


func _update_breadcrumbs() -> void:
	for i in steps.size():
		var btn := _step_buttons[i]
		var status := _step_status[i]
		
		# Update button state and appearance
		match status:
			StepStatus.LOCKED:
				btn.disabled = true
				btn.modulate = Color(0.4, 0.4, 0.4, 0.6)
			StepStatus.CURRENT:
				btn.disabled = false
				btn.modulate = Color(0.4, 0.8, 1.0)
			StepStatus.COMPLETED:
				btn.disabled = false
				btn.modulate = Color(0.5, 1.0, 0.5)
			StepStatus.AVAILABLE:
				btn.disabled = false
				btn.modulate = Color(0.8, 0.8, 0.8)


func _on_step_button_pressed(step_index: int) -> void:
	if _can_navigate_to(step_index):
		_navigate_to(step_index)


func _can_navigate_to(step_index: int) -> bool:
	var status := _step_status[step_index]
	return status in [StepStatus.CURRENT, StepStatus.COMPLETED, StepStatus.AVAILABLE]


func _navigate_to(step_index: int) -> void:
	if step_index == current_step:
		return
	
	current_step = step_index
	step_changed.emit(step_index)
	_update_breadcrumbs()


func unlock_next_step() -> void:
	# Mark current step as completed
	if current_step < steps.size():
		_step_status[current_step] = StepStatus.COMPLETED
		step_completed.emit(current_step)
	
	# Unlock next step
	if current_step + 1 < steps.size():
		_step_status[current_step + 1] = StepStatus.AVAILABLE
		_update_breadcrumbs()


func go_to_next_step() -> void:
	if current_step + 1 < steps.size():
		unlock_next_step()
		_navigate_to(current_step + 1)


func go_to_previous_step() -> void:
	if current_step > 0:
		_navigate_to(current_step - 1)


func can_proceed() -> bool:
	return current_step + 1 < steps.size() and _step_status[current_step + 1] != StepStatus.LOCKED


func reset_steps() -> void:
	for i in steps.size():
		_step_status[i] = StepStatus.LOCKED
	_step_status[0] = StepStatus.CURRENT
	current_step = 0
	_update_breadcrumbs()

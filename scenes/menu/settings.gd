extends VBoxContainer

@onready var session_type_switcher: OptionSwitcher = %SessionTypeSwitcher
@onready var session_types_containers: Array[SessionType] = [
	%Standard,
	%Relaxed,
	%Class,
]

var _current_session_container: SessionType


func _on_session_type_switcher_value_changed(value: int) -> void:
	var temp_context: SessionResource
	if _current_session_container:
		temp_context = _current_session_container.get_context()
	
	if not is_node_ready():
		await ready
	
	for session: SessionType in session_types_containers:
		session.hide()
	
	_current_session_container = session_types_containers[value-1]
	_current_session_container.show()
	if temp_context:
		_current_session_container.load_from_context(temp_context)


func switch_session_from_type(session_type: SessionResource.Type) -> void:
	for session: SessionType in session_types_containers:
		session.hide()
		
	_current_session_container = session_types_containers[0]
	for session: SessionType in session_types_containers:
		if session.get_context_type() != session_type:
			continue
		
		_current_session_container = session
		break
		
	_current_session_container.show()
	session_type_switcher.set_value(_current_session_container.get_index())


func apply_context(context: SessionResource) -> void:
	_current_session_container.apply_context(context)


func load_from_context(context: SessionResource) -> void:
	switch_session_from_type(context.session_type)
	_current_session_container.load_from_context(context)


func get_current_session_container() -> SessionType:
	return _current_session_container

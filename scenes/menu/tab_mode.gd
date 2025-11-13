extends VBoxContainer

## Tab 3: Mode Selection
## Handles session type selection and configuration

signal mode_changed

var _context: SessionResource
var _session_panels: Array[SessionType] = []
var _session_type_index: Dictionary = {}
var _current_panel: SessionType = null
var _suppress_switcher_signal: bool = false

@onready var session_type_switcher: OptionSwitcher = %SessionTypeSwitcher
@onready var session_panel_container: VBoxContainer = %SessionPanelContainer


func _ready() -> void:
	_initialize_session_panels()
	session_type_switcher.value_changed.connect(_on_session_type_changed)


func _initialize_session_panels() -> void:
	_session_panels.clear()
	_session_type_index.clear()
	
	if session_panel_container == null:
		return
	
	for child in session_panel_container.get_children():
		if child is SessionType:
			var panel: SessionType = child
			panel.hide()
			_session_panels.append(panel)
			_session_type_index[panel.get_context_type()] = _session_panels.size() - 1
	
	if _session_panels.is_empty():
		return
	
	var options: Array[OptionData] = []
	for i in _session_panels.size():
		var mode_name := _session_panels[i].get_mode_name()
		var option: OptionData = OptionData.new(mode_name, i + 1, true)
		options.append(option)
	
	session_type_switcher.use_dynamic_options = true
	session_type_switcher.set_options_array(options)
	
	# Show first panel by default
	if _session_panels.size() > 0:
		_switch_to_panel(0)


func set_context(context: SessionResource) -> void:
	_context = context
	
	if _context:
		# Switch to the correct panel for this context's session type
		var target_panel_index := _get_panel_index_for_type(_context.session_type)
		_switch_to_panel(target_panel_index)


func _switch_to_panel(index: int) -> void:
	if _session_panels.is_empty():
		return
	
	var clamped_index: int = clampi(index, 0, _session_panels.size() - 1)
	
	# Save current panel state
	if _current_panel and _context:
		_current_panel.save_to_context(_context)
	
	# Hide all panels
	for panel in _session_panels:
		panel.hide()
	
	# Show and load new panel
	var new_panel: SessionType = _session_panels[clamped_index]
	
	if not _context:
		_context = SessionResource.new()
	
	_context.session_type = new_panel.get_context_type()
	
	new_panel.show()
	new_panel.load_from_context(_context)
	
	if new_panel.has_method("on_activated"):
		new_panel.on_activated()
	
	_current_panel = new_panel
	mode_changed.emit()


func _on_session_type_changed(value: int) -> void:
	if _suppress_switcher_signal:
		_suppress_switcher_signal = false
		return
	
	var index: int = clampi(value - 1, 0, _session_panels.size() - 1)
	_switch_to_panel(index)


func _get_panel_index_for_type(session_type: SessionResource.Type) -> int:
	if _session_type_index.has(session_type):
		return int(_session_type_index[session_type])
	return 0


func is_valid() -> bool:
	if not _current_panel:
		return false
	
	if _current_panel.has_method("is_valid"):
		return _current_panel.is_valid()
	
	return true


func save_to_context() -> void:
	if _current_panel and _context:
		_current_panel.save_to_context(_context)


func get_context() -> SessionResource:
	save_to_context()
	return _context

class_name CustomTabBar extends HBoxContainer

@export var tabs: Array[Control] = []
var _disabled_tabs: Array[Control] = []


func _ready() -> void:
	_update()
	get_child(0).button_pressed = true


func _update() -> void:
	var active_tab: Control = _get_active_tab()
	
	for tab in get_children():
		tab.free()
	
	var button_group: ButtonGroup = ButtonGroup.new()
	for tab: Control in tabs:
		var new_button: Button = Button.new()
		new_button.text = tab.name
		new_button.toggle_mode = true
		new_button.disabled = tab in _disabled_tabs
		new_button.theme_type_variation = "TabBarButton"
		new_button.button_group = button_group
		new_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		new_button.toggled.connect(_on_button_toggled.bind(tab))
		
		if tab in _disabled_tabs:
			new_button.mouse_default_cursor_shape = Control.CURSOR_FORBIDDEN
		add_child(new_button)
	
	#if not active_tab or (active_tab.visible and active_tab in _disabled_tabs):
		#for tab in tabs:
			#if tab in _disabled_tabs:
				#tab.hide()
				#continue
			#
			#await get_tree().process_frame
			#get_child(tab.get_index()).button_pressed = true
			#return
	#elif active_tab:
	await get_tree().process_frame
	var tab_button: Button = get_child(active_tab.get_index())
	tab_button.button_pressed = true


func _on_button_toggled(toggled_on: bool, node: Control) -> void:
	node.visible = toggled_on


func _get_active_tab() -> Control:
	for tab in tabs:
		if tab.visible:
			return tab
	return null


func disable_tab(tab_idx: int, disable: bool) -> void:
	var tab_control: Control = tabs.get(tab_idx)
	
	if disable:
		if tab_control in _disabled_tabs:
			return
		_disabled_tabs.append(tabs.get(tab_idx))
	else:
		if not tab_control in _disabled_tabs:
			return
		_disabled_tabs.erase(tabs.get(tab_idx))
	_update()

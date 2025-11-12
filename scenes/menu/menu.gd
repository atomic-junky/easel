class_name Menu extends Control

signal done(context: SessionContext)

const PACK_OBJECT: PackedScene = preload("res://prefabs/pack/pack.tscn")

var _context: SessionContext
var _active_session_panel_index: int = 0
var _session_panels: Array[SessionType] = []
var _session_type_index: Dictionary = {}
var _context_by_type: Dictionary = {}
var _current_panel: SessionType = null
var _suppress_switcher_signal: bool = false

@onready var folder_dialog: FileDialog = %FolderDialog
@onready var images_dialog: FileDialog = %ImageDialog
@onready var main_vbox: VBoxContainer = %MainVBox
@onready var info_label: Label = %InfoLabel
@onready var session_type_switcher: OptionSwitcher = %SessionTypeSwitcher
@onready var done_button: Button = %DoneButton
@onready var session_panel_container: VBoxContainer = (
	session_type_switcher.get_parent().get_node("Panel/VBox")
)
@onready var pack_selector: Control = %PackSelectorContainer
@onready var pack_selector_panel: PanelContainer = %PackSelectorPanel
@onready var pack_container: Control = %PackContainer
@onready var dimer: ColorRect = %Dimer
@onready var url_container: Control = %UrlContainer
@onready var url_vbox: VBoxContainer = %UrlVBox
@onready var url_label: Label = %UrlLabel
@onready var url_input_container: Control = %UrlInputContainer
@onready var url_input: LineEdit = %UrlInput
@onready var url_input_spiner_container: Control = %UrlInputSpinerContainer
@onready var pinterest_section_chech_box: CheckBox = %PinterestSectionCheckBox

## end variables


func _ready() -> void:
	if OS.get_name() in ["Android", "iOS"]:
		DisplayServer.screen_set_orientation(DisplayServer.SCREEN_PORTRAIT)
		main_vbox.add_theme_constant_override("separation",
			60
		)

	_initialize_session_panels()
	visibility_changed.connect(_update)
	_on_resized()

	if _session_panels.is_empty():
		_update()
		return

	_set_switcher_index(0)


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


func _set_switcher_index(index: int) -> void:
	_switch_to_panel(index, true)


func _save_current_context() -> void:
	if _current_panel and _context:
		_current_panel.save_to_context(_context)
		_context_by_type[_context.session_type] = _context


func _get_context_for(session_type: SessionContext.Type) -> SessionContext:
	if _context_by_type.has(session_type):
		return _context_by_type[session_type]
	var ctx := SessionContext.new()
	ctx.session_type = session_type
	if _context and _context.packs:
		ctx.packs = _context.packs
	_context_by_type[session_type] = ctx
	return ctx


func _switch_to_panel(index: int, sync_switcher: bool) -> void:
	if _session_panels.is_empty():
		return

	var clamped_index: int = clampi(index, 0, _session_panels.size() - 1)
	var can_sync_switcher := (
		sync_switcher
		and session_type_switcher.is_node_ready()
		and session_type_switcher.has_method("_update_buttons")
	)
	if can_sync_switcher:
		var buttons: Array = session_type_switcher._buttons
		if clamped_index < buttons.size():
			var button: Button = buttons[clamped_index]
			if button:
				_suppress_switcher_signal = true
				session_type_switcher._programmatic_change = true
				session_type_switcher._update_buttons(button, false)
				session_type_switcher._programmatic_change = false

	_save_current_context()

	for panel in _session_panels:
		panel.hide()

	_active_session_panel_index = clamped_index
	var new_panel: SessionType = _session_panels[clamped_index]
	_context = _get_context_for(new_panel.get_context_type())

	new_panel.show()
	new_panel.load_from_context(_context)
	if new_panel.has_method("on_activated"):
		new_panel.on_activated()

	_current_panel = new_panel
	_suppress_switcher_signal = false
	_update()


func load_args(args: SessionContext) -> void:
	# Restore context when coming back from a session
	_context = args
	var previous_session_type := _context.session_type if args else SessionContext.Type.STANDARD
	if args:
		_context_by_type[args.session_type] = args

	# Ensure node is ready before updating UI
	if not is_node_ready():
		await ready
	if _session_panels.is_empty():
		_initialize_session_panels()

	# Switch to the correct panel for this context's session type
	if _context:
		var target_panel_index := _get_panel_index_for_type(previous_session_type)
		if target_panel_index != _active_session_panel_index:
			_set_switcher_index(target_panel_index)
		else:
			# Already on correct panel, just bind and update
			var panel := get_session_panel()
			if panel:
				panel.load_from_context(_context)
			_update()
	else:
		_update()


func _on_session_type_switcher_value_changed(value: int) -> void:
	if not is_node_ready():
		return
	if _session_panels.is_empty():
		return
	if _suppress_switcher_signal:
		_suppress_switcher_signal = false
		return

	# Save current context for its session type before switching
	if _context:
		var current := get_session_panel()
		if current:
			current.save_to_context(_context)
		_context_by_type[_context.session_type] = _context

	var index: int = clampi(value - 1, 0, _session_panels.size() - 1)
	_switch_to_panel(index, false)


func _on_select_pack_button_pressed() -> void:
	pack_selector.show()


func get_session_panel() -> SessionType:
	if _session_panels.is_empty():
		return null
	if _active_session_panel_index < 0 or _active_session_panel_index >= _session_panels.size():
		_active_session_panel_index = 0
	return _session_panels[_active_session_panel_index]


func _update() -> void:
	if not is_node_ready():
		return
	if not _context:
		_context = SessionContext.new()

	# Guard: pack_container might not be ready if called too early
	if pack_container:
		for pack in pack_container.get_children():
			pack.queue_free()

	for pack: PackContext in _context.packs:
		var new_pack: Pack = PACK_OBJECT.instantiate()
		if pack_container:
			pack_container.add_child(new_pack)
		new_pack._from_context(pack)
		new_pack.delete_request.connect(_on_pack_delete_request.bind(pack))
		new_pack.toggled.connect(_on_pack_toggled.bind(pack))

	var panel := get_session_panel()
	var valid := false
	if panel and panel.has_method("is_valid"):
		valid = panel.is_valid()
	done_button.disabled = not valid
	if _context.get_image_count() <= 0:
		done_button.disabled = true

	_update_labels()


func _update_labels() -> void:
	var pack_count: int = _context.get_packs().size()
	var image_count: int = _context.get_image_count(false)
	var more_than_one_pack: bool = pack_count >= 1
	var more_than_one_image: bool = image_count >= 1

	if pack_count <= 0:
		info_label.text = "No pack selected"
		return
	var info_text: String = ""
	info_text += "%s images" if more_than_one_image else "%s image"
	info_text += " in %s packs" if more_than_one_pack else " in %s packs"

	info_label.text = info_text % [image_count, pack_count]


func _add_packs(packs: Array[PackContext]) -> void:
	for new_pack: PackContext in packs:
		if new_pack.image_count <= 0:
			packs.erase(new_pack)

	_context.packs.append_array(packs)
	_update()


func _on_pack_delete_request(pack: PackContext) -> void:
	_context.packs.erase(pack)
	_update()


func _on_pack_toggled(_pack: PackContext) -> void:
	_update_labels()


func get_args() -> SessionContext:
	if _context == null:
		_context = SessionContext.new()
	var panel := get_session_panel()
	if panel:
		panel.save_to_context(_context)
	return _context

# Pack source buttons

func _on_folder_button_pressed() -> void: folder_dialog.popup_centered()
func _on_images_button_pressed() -> void: images_dialog.popup_centered()


func _on_pinterest_button_pressed() -> void:
	dimer.show()
	url_container.show()
	url_input_container.show()
	url_input_spiner_container.hide()
	url_input.clear()
	url_input.grab_click_focus()
	url_label.text = "Enter url"


func _on_library_button_pressed() -> void:
	pass # Replace with function body.


func _on_history_button_pressed() -> void:
	pass # Replace with function body.


func _on_folder_dialog_dir_selected(dir: String) -> void:
	_add_packs(PackContext.create_from_path(dir))


func _on_image_dialog_files_selected(paths: PackedStringArray) -> void:
	_add_packs(PackContext.create_from_paths(paths))


func _on_clear_button_pressed() -> void:
	_context.packs.clear()
	_update()


func _on_url_done_button_pressed() -> void:
	url_input_container.hide()
	url_input_spiner_container.show()
	pinterest_section_chech_box.disabled = true

	var use_sections := pinterest_section_chech_box.button_pressed
	var results: Array = await PinterestFetcher.fetch(
		url_input.text,
		use_sections,
		_on_url_fetcher_progress_callback
	)

	url_input_spiner_container.hide()
	url_input_container.show()
	dimer.hide()
	url_container.hide()
	pinterest_section_chech_box.disabled = false

	for pack in results:
		if pack.is_empty() or pack.get("status") != "success":
			printerr(pack.get("data", "Fetching failure (no data)"))
			return

		_context.packs.append(PackContext.create_from_urls(pack.get("data", {})))
	_update()


func _on_url_fetcher_progress_callback(message: String) -> void:
	url_label.text = message


func _on_pack_done_button_pressed() -> void:
	pack_selector.hide()


func _on_done_button_pressed() -> void:
	# Sync the context with the active panel before caching it
	var panel := get_session_panel()
	if panel:
		panel.save_to_context(_context)
	_context_by_type[_context.session_type] = _context
	done.emit(_context)


## Map SessionContext.Type to panel index
func _get_panel_index_for_type(session_type: SessionContext.Type) -> int:
	if _session_type_index.has(session_type):
		return int(_session_type_index[session_type])
	return 0


func _on_resized() -> void:
	if not is_node_ready():
		return

	if size.x <= 490 + 80:
		main_vbox.custom_minimum_size.x = 0.0
		main_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		pack_selector_panel.custom_minimum_size.x = 0.0
		pack_selector_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		url_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		url_vbox.custom_minimum_size.x = 0.0
		return
	main_vbox.custom_minimum_size.x = 474.0
	main_vbox.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	pack_selector_panel.custom_minimum_size.x = 650.0
	pack_selector_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	url_container.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	url_vbox.custom_minimum_size.x = 400.0

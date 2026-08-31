extends VBoxContainer

## Contents of the "Add a new Pack" modal.

const LOCAL_TAB: int = 1
const FIRST_PLUGIN_TAB: int = 2

@onready var menu: Menu = owner
@onready var modal: Modal = %AddPackModal

@onready var source_switcher: OptionSwitcher = %SourceSwitcher
@onready var local_container: Control = %LocalContainer
@onready var url_container: Control = %UrlContainer
@onready var url_input: LineEdit = %UrlInput
@onready var url_spinner: Control = %UrlInputSpinerContainer
@onready var options_container: Control = %OptionsContainer
@onready var message_label: Label = %UrlMessageLabel
@onready var done_button: Button = %AddPackDoneButton

@onready var folder_dialog: FileDialog = %FolderDialog
@onready var images_dialog: FileDialog = %ImageDialog

var _plugin: GDScript = null
var _option_controls: Dictionary = {}


func _ready() -> void:
	url_input.text_changed.connect(_on_url_text_changed)
	_build_tabs()
	_apply_source(source_switcher.value)


func _build_tabs() -> void:
	var labels: Array = ["Local"]
	var values: Array = [LOCAL_TAB]

	for plugin: GDScript in Plugins.scripts():
		labels.append(plugin.display_name())
		values.append(values.size() + 1)

	if labels.size() > source_switcher.MAX_OPTIONS:
		push_warning("Only %d tabs fit in the switcher." % source_switcher.MAX_OPTIONS)

	source_switcher.set_options_from_arrays(labels, values)


## The switcher emits on its own _ready, which runs before ours.
func _on_source_switcher_value_changed(value: int) -> void:
	if not is_node_ready():
		await ready
	_apply_source(value)


func _apply_source(value: int) -> void:
	var scripts: Array[GDScript] = Plugins.scripts()
	var index: int = value - FIRST_PLUGIN_TAB
	_plugin = scripts[index] if index >= 0 and index < scripts.size() else null

	local_container.visible = _plugin == null
	url_container.visible = _plugin != null
	message_label.visible = false

	if _plugin != null:
		url_input.placeholder_text = "%s url" % _plugin.display_name()
		_build_options()

	_update_done_button()


## Rebuilds the tab's option rows from what the plugin declares.
func _build_options() -> void:
	_option_controls.clear()
	for child in options_container.get_children():
		child.queue_free()

	for option: PluginOption in _plugin.options():
		options_container.add_child(_build_option_row(option))


func _build_option_row(option: PluginOption) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)

	var toggle := Button.new()
	toggle.custom_minimum_size = Vector2(24, 24)
	toggle.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	toggle.theme_type_variation = &"CheckSquare"
	toggle.toggle_mode = true
	toggle.button_pressed = bool(option.default_value)
	row.add_child(toggle)

	var label := Label.new()
	label.text = option.label
	row.add_child(label)

	_option_controls[option.id] = toggle
	return row


func _collect_params() -> Dictionary:
	var params: Dictionary = Plugins.default_params(_plugin)
	for id: StringName in _option_controls:
		params[id] = _option_controls[id].button_pressed
	return params


func _on_url_text_changed(_text: String) -> void:
	_update_done_button()


func _update_done_button() -> void:
	done_button.disabled = _plugin == null or not _plugin.can_handle(url_input.text.strip_edges())


func _on_folder_button_pressed() -> void: folder_dialog.popup_centered()
func _on_images_button_pressed() -> void: images_dialog.popup_centered()


func _on_folder_dialog_dir_selected(dir: String) -> void:
	menu._add_packs(PackResource.create_from_path(dir))
	modal.close()


func _on_image_dialog_files_selected(paths: PackedStringArray) -> void:
	menu._add_packs(PackResource.create_from_paths(paths))
	modal.close()


func _on_done_button_pressed() -> void:
	var url: String = url_input.text.strip_edges()
	var params: Dictionary = _collect_params()
	var fetcher: EaselFetcherPlugin = _plugin.new()

	_set_fetching(true)
	add_child(fetcher)

	var results: Array[PackFetchResult] = await fetcher.fetch(
		url, params, _on_url_fetcher_progress_callback
	)

	fetcher.queue_free()
	_set_fetching(false)

	var packs: Array[PackResource] = []
	for result: PackFetchResult in results:
		if not result.ok():
			message_label.visible = true
			message_label.text = result.error + " (skipping)"
			continue
		packs.append(PackResource.create_from_fetch(result, _plugin.plugin_id(), params))

	menu._add_packs(packs)

	url_input.text = ""
	_update_done_button()
	modal.close()


func _set_fetching(active: bool) -> void:
	url_input.visible = not active
	options_container.visible = not active
	url_spinner.visible = active
	message_label.visible = active
	done_button.disabled = active


func _on_url_fetcher_progress_callback(message: String) -> void:
	message_label.text = message

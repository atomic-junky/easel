extends VBoxContainer

## Contents of the "Add a new Pack" modal.

const SOURCE_LOCAL: int = 1
const SOURCE_URL: int = 2

@onready var menu: Menu = owner
@onready var modal: Modal = %AddPackModal

@onready var local_container: Control = %LocalContainer
@onready var url_container: Control = %UrlContainer
@onready var url_input: LineEdit = %UrlInput
@onready var url_spinner: Control = %UrlInputSpinerContainer
@onready var options_container: Control = %OptionsContainer
@onready var message_label: Label = %UrlMessageLabel
@onready var done_button: Button = %AddPackDoneButton

@onready var folder_dialog: FileDialog = %FolderDialog
@onready var images_dialog: FileDialog = %ImageDialog

var _source: int = SOURCE_LOCAL
var _plugin: GDScript = null
var _option_controls: Dictionary = {}


func _ready() -> void:
	url_input.text_changed.connect(_on_url_text_changed)
	_apply_source(_source)


## The switcher emits on its own _ready, which runs before ours.
func _on_source_switcher_value_changed(value: int) -> void:
	if not is_node_ready():
		await ready
	_apply_source(value)


func _apply_source(value: int) -> void:
	_source = value
	local_container.visible = value == SOURCE_LOCAL
	url_container.visible = value == SOURCE_URL
	_update_done_button()


func _on_url_text_changed(text: String) -> void:
	_set_plugin(Plugins.script_for_url(text.strip_edges()))
	_update_done_button()


## Swaps the option rows whenever the typed url resolves to another plugin.
func _set_plugin(plugin: GDScript) -> void:
	if plugin == _plugin:
		return
	_plugin = plugin

	_option_controls.clear()
	for child in options_container.get_children():
		child.queue_free()

	if _plugin == null:
		return

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
	var params: Dictionary = Plugins.default_params(_plugin) if _plugin else {}
	for id: StringName in _option_controls:
		params[id] = _option_controls[id].button_pressed
	return params


func _update_done_button() -> void:
	done_button.disabled = _source != SOURCE_URL or _plugin == null


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
	var fetcher: EaselFetcherPlugin = Plugins.create_for_url(url)
	if fetcher == null:
		return

	var params: Dictionary = _collect_params()
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
			message_label.text = result.error
			return
		packs.append(PackResource.create_from_fetch(result, _plugin.plugin_id(), params))

	menu._add_packs(packs)

	url_input.text = ""
	_on_url_text_changed("")
	modal.close()


func _set_fetching(active: bool) -> void:
	url_input.visible = not active
	options_container.visible = not active
	url_spinner.visible = active
	message_label.visible = active
	done_button.disabled = active


func _on_url_fetcher_progress_callback(message: String) -> void:
	message_label.text = message

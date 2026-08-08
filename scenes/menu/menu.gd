class_name Menu extends Control

## Pack selection and session configuration.
##
## Packs live in two grids: the ones in the session, and the rest. Picking a
## pack moves it between them; the badge shows its rank in the session.

signal done(context: SessionResource)

const PACK_OBJECT: PackedScene = preload("res://prefabs/pack/pack.tscn")
const COLUMN_WIDTH: float = 635.0

## Below this width the layout goes edge-to-edge and the primary action fills.
const COMPACT_WIDTH: float = 550.0
const PAD: float = 25.0
const PAD_COMPACT: float = 12.0
const BAR_HEIGHT: float = 52.0

const CARD_MIN_WIDTH: float = 165.0
const CARD_RATIO: float = 198.0 / 140.0
const GRID_GAP: float = 20.0

var _context: SessionResource
var _selection_order: Array[PackResource] = []
var _cards: Dictionary = {}

@onready var settings: Control = %Settings
@onready var column: Control = %CenterColumn
@onready var main_margin: MarginContainer = %MainSafeMargin
@onready var selected_section: Control = %SelectedSection
@onready var selected_container: Control = %SelectedContainer
@onready var library_section: Control = %LibrarySection
@onready var library_container: Control = %LibraryContainer
@onready var bottom_bar: Control = %BottomBar
@onready var count_label: Label = %CountLabel
@onready var start_button: Button = %StartSessionButton
@onready var refresh_button: Button = %RefreshButton
@onready var settings_modal: Modal = %SettingsModal
@onready var add_pack_modal: Modal = %AddPackModal
@onready var progress_modal: Modal = %ProgressModal
@onready var progress_label: Label = %ProgressLabel


func _ready() -> void:
	if OS.get_name() in ["Android", "iOS"]:
		DisplayServer.screen_set_orientation(DisplayServer.SCREEN_PORTRAIT)

	visibility_changed.connect(_update)
	selected_container.resized.connect(_layout_grid)
	library_container.resized.connect(_layout_grid)
	_on_resized()
	_update()


func load_args(args: SessionResource) -> void:
	_context = args

	if not is_node_ready():
		await ready

	if _context:
		settings.load_from_context(_context)
	_update()


func get_args() -> SessionResource:
	if _context == null:
		_context = SessionResource.new()
	settings.apply_context(_context)
	return _context


func _update() -> void:
	if not is_node_ready():
		return
	if not _context:
		_context = SessionResource.new()

	for container: Control in [selected_container, library_container]:
		for child in container.get_children():
			child.queue_free()
	_cards.clear()

	# Drop entries that were removed or deselected elsewhere.
	var kept: Array[PackResource] = []
	for pack: PackResource in _selection_order:
		if pack in _context.packs and pack.enabled:
			kept.append(pack)
	_selection_order = kept

	for pack: PackResource in _context.packs:
		if pack.enabled and not _selection_order.has(pack):
			_selection_order.append(pack)

		var parent: Control = selected_container if pack.enabled else library_container
		var card: Pack = _add_card(parent, pack, false)
		_cards[pack] = card

	_load_history()
	_refresh_selection()
	_layout_grid()


func _load_history() -> void:
	var packs_path: Array = _context.packs.map(func(p: PackResource) -> String: return p.path)

	for pack: PackResource in PackHistory.get_history():
		if pack.path in packs_path:
			continue
		_add_card(library_container, pack, true)


func _add_card(parent: Control, pack: PackResource, is_holo: bool = false) -> Pack:
	var card: Pack = PACK_OBJECT.instantiate()
	parent.add_child(card)
	card._from_context(pack, is_holo)

	# A history card adds its pack to the session; a session card selects it.
	card.delete_request.connect(_on_pack_delete_request.bind(pack))
	if is_holo:
		card.add_pack_request.connect(_on_holo_add_pack.bind(pack))
	else:
		card.selection_changed.connect(_on_pack_selection_changed.bind(pack))

	return card



func _refresh_selection() -> void:
	for pack: PackResource in _cards:
		_cards[pack].set_badge(_selection_order.find(pack) + 1)

	_apply_order()

	var image_count: int = _context.get_image_count(true)
	var pack_count: int = _selection_order.size()
	if pack_count <= 0:
		count_label.text = "No pack selected"
	else:
		count_label.text = "%d pack%s selected (%d images)" % [
			pack_count, "" if pack_count == 1 else "s", image_count
		]

	start_button.disabled = image_count < 1
	refresh_button.disabled = _selection_order.is_empty()


## Selected packs sit in their own grid, in the order they were picked. The rest
## keep their original position, so deselecting puts a pack back where it was.
func _apply_order() -> void:
	var index: int = 0
	for pack: PackResource in _selection_order:
		index = _place(_cards.get(pack), selected_container, index)

	index = 0
	for pack: PackResource in _context.packs:
		if _selection_order.has(pack):
			continue
		index = _place(_cards.get(pack), library_container, index)

	selected_section.visible = selected_container.get_child_count() > 0
	library_section.visible = library_container.get_child_count() > 0


func _place(card: Variant, container: Control, index: int) -> int:
	if not is_instance_valid(card):
		return index
	if card.get_parent() != container:
		card.reparent(container, false)
	container.move_child(card, index)
	return index + 1


## Sizes the cards so a whole number of them fills the row, at any width.
func _layout_grid() -> void:
	for container: Control in [selected_container, library_container]:
		var width: float = container.size.x
		if width <= 0.0:
			continue

		var columns: int = maxi(1, floori((width + GRID_GAP) / (CARD_MIN_WIDTH + GRID_GAP)))
		var card_width: float = floorf((width - (columns - 1) * GRID_GAP) / columns)
		var card_size: Vector2 = Vector2(card_width, floorf(card_width / CARD_RATIO))

		for card: Node in container.get_children():
			if card is Pack and card.custom_minimum_size != card_size:
				card.custom_minimum_size = card_size


func _add_packs(packs: Array[PackResource]) -> void:
	var added: Array[PackResource] = []
	for new_pack: PackResource in packs:
		if new_pack.image_count > 0:
			added.append(new_pack)

	if added.is_empty():
		return

	_context.packs.append_array(added)
	PackHistory.add_packs(added)

	# A pack you just added is the one you want to draw: select it right away.
	for new_pack: PackResource in added:
		new_pack.enabled = true

		if not _selection_order.has(new_pack):
			_selection_order.append(new_pack)

	_update()


func _on_pack_selection_changed(pack: PackResource) -> void:
	if pack.enabled:
		if not _selection_order.has(pack):
			_selection_order.append(pack)
	else:
		_selection_order.erase(pack)
	_refresh_selection()


## Works for both grids: a session pack is dropped from the session and from
## history, a history pack only exists in history.
func _on_pack_delete_request(pack: PackResource) -> void:
	_context.packs.erase(pack)
	_selection_order.erase(pack)
	PackHistory.erase_pack(pack)
	_update()


func _on_holo_add_pack(pack: PackResource) -> void:
	_add_packs([pack])


func _on_add_pack_button_pressed() -> void:
	add_pack_modal.open()


func _on_refresh_button_pressed() -> void:
	if _selection_order.is_empty():
		return

	refresh_button.disabled = true
	progress_modal.open()

	var packs: Array[PackResource] = _selection_order.duplicate()
	for i in packs.size():
		var pack: PackResource = packs[i]
		var card: Variant = _cards.get(pack)
		if not is_instance_valid(card):
			continue

		progress_label.text = "%s\n%d of %d" % [pack.pack_name, i + 1, packs.size()]
		var on_progress: Callable = func(message: String) -> void:
			progress_label.text = "%s\n%s" % [pack.pack_name, message]

		card.refresh_progress.connect(on_progress)
		await card.refresh()
		if is_instance_valid(card):
			card.refresh_progress.disconnect(on_progress)

	progress_modal.close()
	_refresh_selection()


func _on_settings_button_pressed() -> void:
	settings_modal.open()


func _on_settings_done_button_pressed() -> void:
	settings.apply_context(_context)
	settings_modal.close()


func _on_start_session_button_pressed() -> void:
	settings.apply_context(_context)
	done.emit(_context)


func _on_resized() -> void:
	if not is_node_ready():
		return

	var compact: bool = size.x <= COMPACT_WIDTH or OS.get_name() in ["Android", "iOS"]
	var pad: float = PAD_COMPACT if compact else PAD

	main_margin.add_theme_constant_override("margin_left", int(pad))
	main_margin.add_theme_constant_override("margin_right", int(pad))
	main_margin.add_theme_constant_override("margin_top", int(pad))
	main_margin.add_theme_constant_override("margin_bottom", int(pad * 2.0 + BAR_HEIGHT))

	# Floating and centered when there is room, edge-to-edge when there is not.
	bottom_bar.offset_top = -(pad + BAR_HEIGHT)
	bottom_bar.offset_bottom = -pad
	bottom_bar.anchor_left = 0.0 if compact else 0.5
	bottom_bar.anchor_right = 1.0 if compact else 0.5
	bottom_bar.offset_left = pad if compact else 0.0
	bottom_bar.offset_right = -pad if compact else 0.0
	start_button.size_flags_horizontal = (
		Control.SIZE_EXPAND_FILL if compact else Control.SIZE_FILL
	)

	var available: float = size.x - pad * 2.0
	column.custom_minimum_size.x = minf(COLUMN_WIDTH, available)
	column.size_flags_horizontal = (
		Control.SIZE_SHRINK_CENTER if available > COLUMN_WIDTH else Control.SIZE_EXPAND_FILL
	)

	_layout_grid()

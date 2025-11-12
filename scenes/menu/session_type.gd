@abstract
class_name SessionType extends VBoxContainer

signal fields_built

var _field_bucket: Dictionary = {
	"switcher": preload("res://prefabs/fields/field_switcher.gd"),
	"toggle": preload("res://prefabs/fields/field_toggle.gd"),
	"number": preload("res://prefabs/fields/field_int.gd"),
	"image_order": preload("res://prefabs/fields/field_image_order.gd"),
	"custom_sequence": preload("res://prefabs/fields/field_custom_sequence.gd"),
}

var _field_container: VBoxContainer = null
var _field_datas: Dictionary = {}
var _fields: Array = []
var _fields_ready: bool = false

## API: Call in _ready or setup to declare a field
func define_field(
	fname: String,
	field_type: String,
	options: Array = [],
	title: String = "",
	suffix: String = "",
	extra: Dictionary = {}
) -> void:
	var fdata = {
		"name": fname,
		"type": field_type,
		"options": options,
		"title": title,
		"suffix": suffix,
		"extra": extra
	}
	_field_datas[fname] = fdata

## Called automatically when added to tree
func _ready() -> void:
	setup()
	_build_fields()
	fields_built.emit()


## Initialize UI from field definitions
func _build_fields() -> void:
	for child in get_children():
		child.queue_free()
		
	_field_container = VBoxContainer.new()
	_field_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_field_container.add_theme_constant_override("separation", 6)
	add_child(_field_container)
	
	for fname: String in _field_datas.keys():
		var fdata: Dictionary = _field_datas[fname]
		_build_field(fdata)

	_fields_ready = true

## Build a single field from definition
func _build_field(fdata: Dictionary) -> void:
	var script: GDScript = _field_bucket.get(fdata.get("type"))
	var node: Node
	if not script:
		node = Label.new()
		node.text = "Missing field type: " + fdata.get("type")
	else:
		var field: SessionField = script.new(fdata)
		_fields.append(field)
		node = field
	if node:
		_field_container.add_child(node)


func update_context(_context: SessionContext) -> void:
	push_error("update_context is deprecated. Use save_to_context instead.")

## Load UI from context values
func load_from_context(context: SessionContext) -> void:
	if not context:
		return
	
	# Wait for all fields to be ready before loading context
	if not _fields_ready:
		await fields_built
	
	# Ensure all field nodes are fully initialized
	for field: SessionField in get_field_nodes():
		if not field.is_node_ready():
			await field.ready
	
	for field: SessionField in get_field_nodes():
		if field.has_method("set_from_context"):
			field.set_from_context(context)

## Save UI values to context
func save_to_context(context: SessionContext) -> void:
	if not context:
		return
	apply_context(context)

## Base generic application; subclasses can override for specialized logic
func apply_context(context: SessionContext) -> void:
	if not context:
		return
	context.session_type = get_context_type()
	# Use the generic helper to apply all fields
	apply_fields_to_context(context)


func have_property(object: Object, property_name: String) -> bool:
	for property: Dictionary in object.get_property_list():
		if property.get("name") == property_name:
			return true
	return false


func bind_context(_context: SessionContext) -> void:
	push_error("bind_context is deprecated. Use load_from_context instead.")


func get_field_nodes() -> Array[SessionField]:
	var arr: Array[SessionField] = []
	if not _field_container:
		return arr
	for child in _field_container.get_children():
		if child is SessionField:
			arr.append(child)
	return arr


func collect_field_values() -> Dictionary:
	var result: Dictionary = {}
	for field: SessionField in get_field_nodes():
		var vd := field.get_value_dict()
		for k in vd.keys():
			result[k] = vd[k]
	return result


func apply_fields_to_context(context: Object) -> void:
	if context == null:
		return
	var values := collect_field_values()
	# Build property whitelist for context
	var props: Dictionary = {}
	for p in context.get_property_list():
		if typeof(p) == TYPE_DICTIONARY and p.has("name"):
			props[p.name] = true
	for k in values.keys():
		if props.has(k):
			context.set(k, values[k])


func is_valid() -> bool:
	return true

@abstract func setup() -> void

@abstract
func get_context_type() -> SessionContext.Type

@abstract
func get_mode_name() -> String

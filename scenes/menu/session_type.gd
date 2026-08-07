@abstract
class_name SessionType extends VBoxContainer

signal fields_built

const CHOICE_FIELD: GDScript = preload("res://prefabs/fields/field_choice.gd")
const IMAGE_ORDER_FIELD: GDScript = preload("res://prefabs/fields/field_image_order.gd")
const SEQUENCE_FIELD: GDScript = preload("res://prefabs/fields/field_custom_sequence.gd")

var _field_container: VBoxContainer = null
var _specs: Array[FieldSpec] = []
var _fields_ready: bool = false


## Field definitions. Subclasses call these from setup(); each returns its spec
## so optional settings can be chained, e.g.
##     define_choice("duration", [30, 60], "Time").with_unit("s").with_range(5, 3600, 5)

## A row of preset chips plus a custom value entry.
func define_choice(field_name: String, options: Array, title: String = "") -> FieldSpec:
	return _define(CHOICE_FIELD, field_name, title, options)


## The shuffle / reverse pair. It always writes the same two properties.
func define_image_order() -> FieldSpec:
	return _define(IMAGE_ORDER_FIELD, "image_order", "")


## The editable list of poses and breaks used by Custom mode.
func define_sequence(field_name: String, title: String = "") -> FieldSpec:
	return _define(SEQUENCE_FIELD, field_name, title)


func _define(renderer: GDScript, field_name: String, title: String, options: Array = []) -> FieldSpec:
	var spec := FieldSpec.new()
	spec.renderer = renderer
	spec.name = field_name
	spec.title = title
	spec.options = options
	# The old API only ever inferred a default for "switcher" fields, which no
	# mode used, so every field started with a null default.
	if not options.is_empty():
		spec.default_value = options[0]

	_specs.append(spec)
	return spec

## Called automatically when added to tree
func _ready() -> void:
	_build_fields()
	fields_built.emit()


## Initialize UI from field definitions
func _build_fields() -> void:
	for child in get_children():
		child.queue_free()
		
	_specs.clear()
	setup()

	_field_container = VBoxContainer.new()
	_field_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_field_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_field_container.add_theme_constant_override("separation", 15)
	add_child(_field_container)

	for spec: FieldSpec in _specs:
		_field_container.add_child(spec.renderer.new(spec))

	_fields_ready = true

## Load UI from context values
func load_from_context(context: SessionResource) -> void:
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


## Base generic application; subclasses can override for specialized logic
func apply_context(context: SessionResource) -> void:
	if not context:
		return
	context.session_type = get_context_type()
	# Use the generic helper to apply all fields
	apply_fields_to_context(context)

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


func get_context() -> SessionResource:
	var context: SessionResource = SessionResource.new()
	context.session_type = get_context_type()
	apply_fields_to_context(context)
	return context


func is_valid() -> bool:
	return true

@abstract 
func setup() -> void

@abstract
func get_context_type() -> SessionResource.Type

@abstract
func get_mode_name() -> String

@abstract
func generate_sequence(context: SessionResource) -> Array

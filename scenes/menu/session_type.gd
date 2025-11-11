@abstract
class_name SessionType extends VBoxContainer

signal fields_built

var _field_bucket: Dictionary = {
	"switcher": preload("res://prefabs/fields/field_switcher.gd"),
	"toggle": preload("res://prefabs/fields/field_toggle.gd"),
	"number": preload("res://prefabs/fields/field_int.gd"),
	"image_order": preload("res://prefabs/fields/field_image_order.gd"),
	"custom": PackedScene.new()
}

var _binded_context: SessionContext = null
var _field_container: VBoxContainer = null
var _field_datas: Dictionary = {}
var _fields: Array = []

## API: Call in _ready or setup to declare a field
func define_field(
	fname: String,
	field_type: String,
	default: Variant,
	options: Array = [],
	title: String = "",
	suffix: String = "",
	extra: Dictionary = {}
) -> void:
	var fdata = {
		"name": fname,
		"type": field_type,
		"options": options,
		"default": default,
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
	_field_container.add_theme_constant_override("separation", 6)
	add_child(_field_container)
	
	for fname: String in _field_datas.keys():
		var fdata: Dictionary = _field_datas[fname]
		_build_field(fdata)

## Build a single field from definition
func _build_field(fdata: Dictionary) -> void:
	var script: GDScript = _field_bucket.get(fdata.get("type"))
	var node: Node
	if not script:
		node = Label.new()
		node.text = "Missing field type: " + fdata.get("type")
	else:
		var field: SessionField = script.new(fdata)
		field.value_changed.connect(_on_field_value_changed)
		_fields.append(field)
		node = field
	if node:
		_field_container.add_child(node)


func _on_field_value_changed(_new_value: Dictionary, _old_value: Dictionary) -> void:
	update_context(_binded_context)


func update_context(context: SessionContext) -> void:
	if not context:
		push_error("SessionContext is null")
		return
	
	context.session_type = get_context_type()
	for field: SessionField in _fields:
		var fvalues: Dictionary = field.get_value_dict()
		for fname: String in fvalues.keys():
			var fvalue: Variant = fvalues[fname]
			if not have_property(context, fname):
				push_error("SessionContext do not have property %s" % fname)
				continue
			context.set(fname, fvalue)


func have_property(object: Object, property_name: String) -> bool:
	for property: Dictionary in object.get_property_list():
		if property.get("name") == property_name:
			return true
	return false


func bind_context(context: SessionContext) -> void:
	_binded_context = context


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

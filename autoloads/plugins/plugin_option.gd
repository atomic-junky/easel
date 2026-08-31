class_name PluginOption extends RefCounted

var id: StringName
var label: String
var default_value: bool = false


static func toggle(option_id: StringName, text: String, enabled: bool = false) -> PluginOption:
	var option := PluginOption.new()
	option.id = option_id
	option.label = text
	option.default_value = enabled
	return option

extends Node

const PLUGIN_SCRIPTS: Array[GDScript] = [
	preload("res://autoloads/plugins/pinterest_fetcher.gd"),
	preload("res://autoloads/plugins/cosmos_fetcher.gd"),
]


func scripts() -> Array[GDScript]:
	return PLUGIN_SCRIPTS


func script_for_id(id: StringName) -> GDScript:
	for plugin: GDScript in PLUGIN_SCRIPTS:
		if plugin.plugin_id() == id:
			return plugin
	return null


func script_for_url(url: String) -> GDScript:
	for plugin: GDScript in PLUGIN_SCRIPTS:
		if plugin.can_handle(url):
			return plugin
	return null


func default_params(plugin: GDScript) -> Dictionary:
	var params: Dictionary = {}
	for option: PluginOption in plugin.options():
		params[option.id] = option.default_value
	return params


func create(id: StringName) -> EaselFetcherPlugin:
	var plugin: GDScript = script_for_id(id)
	return plugin.new() if plugin else null


func create_for_url(url: String) -> EaselFetcherPlugin:
	var plugin: GDScript = script_for_url(url)
	return plugin.new() if plugin else null

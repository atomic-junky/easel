extends Control

@onready var progress_popup: PanelContainer = %ProgressPopup
@onready var progress_rtl: RichTextLabel = %ProgressRTL


func _ready() -> void:
	progress_popup.hide()


func _on_fetch_pinterest_button_pressed() -> void:
	pass # Replace with function body.


func _on_fetch_cosmos_button_pressed() -> void:
	var cosmos: CosmosFetcher = CosmosFetcher.new()
	add_child(cosmos)
	await cosmos.fetch("https://www.cosmos.so/mncb0z/references", {}, _progress_callback)
	cosmos.queue_free()


func _progress_callback(message: String) -> void:
	progress_rtl.text = message
	progress_popup.show()


func _on_close_button_pressed() -> void:
	progress_popup.hide()

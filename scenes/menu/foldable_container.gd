extends FoldableContainer


func _ready() -> void:
	folding_changed.connect(_on_folding_changed)
	_on_folding_changed(folded)


func _on_folding_changed(_is_folded: bool) -> void:
	size_flags_vertical = SIZE_EXPAND if folded else SIZE_EXPAND_FILL

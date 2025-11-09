class_name SessionType extends Control


func apply_context(_context: SessionContext):
	push_warning("Function apply_context must be override.")


func is_valid() -> bool:
	return false

@tool
class_name AccordionManager
extends Node

## Manages CollapsibleSection nodes to ensure only one is expanded at a time

var _sections: Array[CollapsibleSection] = []


func _ready() -> void:
	# Auto-discover child CollapsibleSections
	_discover_sections()


func _discover_sections() -> void:
	"""Automatically find and register all CollapsibleSection children"""
	for child in get_parent().get_children():
		if child is CollapsibleSection:
			register_section(child)


func register_section(section: CollapsibleSection) -> void:
	"""Register a CollapsibleSection to be managed by this accordion"""
	if section in _sections:
		return
	
	_sections.append(section)
	section.toggled.connect(_on_section_toggled.bind(section))


func unregister_section(section: CollapsibleSection) -> void:
	"""Remove a CollapsibleSection from management"""
	if section in _sections:
		_sections.erase(section)
		if section.toggled.is_connected(_on_section_toggled):
			section.toggled.disconnect(_on_section_toggled)


func _on_section_toggled(is_expanded: bool, source_section: CollapsibleSection) -> void:
	"""When a section is expanded, collapse all others"""
	if not is_expanded:
		return  # Don't do anything if a section was collapsed
	
	# Collapse all other sections
	for section in _sections:
		if section != source_section and section.is_expanded:
			section.set_expanded(false, true)


func expand_section(section: CollapsibleSection, animate: bool = true) -> void:
	"""Programmatically expand a specific section"""
	if section in _sections:
		section.set_expanded(true, animate)


func collapse_all(animate: bool = true) -> void:
	"""Collapse all managed sections"""
	for section in _sections:
		section.set_expanded(false, animate)

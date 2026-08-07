class_name FieldSpec extends RefCounted

## Typed description of one settings field.
##
## Built by the define_* helpers on [SessionType] and read directly by the
## renderers, so nothing passes a type string or an untyped "extra" dictionary
## around any more.

## Script that renders this field. Set by the define_* helper.
var renderer: GDScript

## Property of [SessionResource] this field writes.
var name: String
var title: String = ""

var options: Array = []
var labels: PackedStringArray = PackedStringArray()
var unit: String = ""
var default_value: Variant = null

var minimum: int = 1
var maximum: int = 9999
var step: int = 1

var has_all: bool = false
var all_value: int = -1


## Chip text, when the values alone do not read well ("1 min" for 60).
func with_labels(value: PackedStringArray) -> FieldSpec:
	labels = value
	return self


## Shown next to the custom value, and appended to unlabelled chips.
func with_unit(value: String) -> FieldSpec:
	unit = value
	return self


## Bounds of the custom value entry.
func with_range(low: int, high: int, increment: int = 1) -> FieldSpec:
	minimum = low
	maximum = high
	step = increment
	return self


func with_default(value: Variant) -> FieldSpec:
	default_value = value
	return self


## Adds an "All" chip. SessionResource already reads a negative count as "every
## image" (standard.gd), so that is the value it carries.
func with_all(value: int = -1) -> FieldSpec:
	has_all = true
	all_value = value
	return self

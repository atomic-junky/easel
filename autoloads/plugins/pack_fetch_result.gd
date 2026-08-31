class_name PackFetchResult extends RefCounted

## What a fetcher plugin hands back to the UI.

var pack_name: String = "Unknown"
var url: String = ""
var images: Array[Dictionary] = []
var error: String = ""


static func success(name: String, source_url: String, found: Array) -> PackFetchResult:
	var result := PackFetchResult.new()
	result.pack_name = name
	result.url = source_url
	for image in found:
		if image is Dictionary and not image.is_empty():
			result.images.append(image)
	return result


static func failure(message: String) -> PackFetchResult:
	var result := PackFetchResult.new()
	result.error = message
	return result


func ok() -> bool:
	return error.is_empty() and not images.is_empty()

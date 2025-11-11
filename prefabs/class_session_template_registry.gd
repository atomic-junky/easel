## Registry for class session templates
## Centralizes all predefined templates and allows easy extension
class_name ClassSessionTemplateRegistry extends RefCounted

static var _templates: Dictionary = {}
static var _initialized: bool = false


## Initialize the default templates
static func initialize() -> void:
	if _initialized:
		return
	
	_initialized = true
	_register_default_templates()


## Register a template
static func register_template(template: ClassSessionTemplate) -> void:
	if not template.validate():
		push_warning("Failed to register invalid template: %s" % template.template_name)
		return
	_templates[template.duration_minutes] = template


## Get a template by duration (in minutes)
static func get_template(duration_minutes: int) -> ClassSessionTemplate:
	if not _initialized:
		initialize()
	return _templates.get(duration_minutes)


## Get all available template durations
static func get_available_durations() -> Array[int]:
	if not _initialized:
		initialize()
	var durations: Array[int] = []
	for key in _templates.keys():
		durations.append(key)
	durations.sort()
	return durations


## Get all templates
static func get_all_templates() -> Array[ClassSessionTemplate]:
	if not _initialized:
		initialize()
	var templates: Array[ClassSessionTemplate] = []
	for template in _templates.values():
		templates.append(template)
	return templates


## Register all the default hardcoded templates
static func _register_default_templates() -> void:
	# 30 minute session
	register_template(ClassSessionTemplate.create(30, "30 min", [
		{"type": "pose", "duration": 30, "amount": 10},   # 5min
		{"type": "pose", "duration": 60, "amount": 5},    # 10min (5min)
		{"type": "pose", "duration": 5*60, "amount": 2},  # 20min (10min)
		{"type": "pose", "duration": 10*60, "amount": 1}, # 30min (10min)
	]))
	
	# 60 minute session
	register_template(ClassSessionTemplate.create(60, "60 min", [
		{"type": "pose", "duration": 30, "amount": 10},   # 5min
		{"type": "pose", "duration": 60, "amount": 5},    # 10min (5min)
		{"type": "pose", "duration": 5*60, "amount": 2},  # 20min (10min)
		{"type": "pose", "duration": 10*60, "amount": 1}, # 30min (10min)
		{"type": "break", "duration": 5*60, "amount": 1}, # 35min (5min)
		{"type": "pose", "duration": 25*60, "amount": 1}, # 60min (25min)
	]))
	
	# 90 minute session
	register_template(ClassSessionTemplate.create(90, "90 min", [
		{"type": "pose", "duration": 30, "amount": 10},   # 5min
		{"type": "pose", "duration": 60, "amount": 5},    # 10min (5min)
		{"type": "pose", "duration": 5*60, "amount": 3},  # 25min (15min)
		{"type": "break", "duration": 5*60, "amount": 1}, # 30min (5min)
		{"type": "pose", "duration": 10*60, "amount": 2}, # 50min (20min)
		{"type": "pose", "duration": 30*60, "amount": 1}, # 80min (30min)
		{"type": "break", "duration": 10*60, "amount": 1}, # 90min (10min)
	]))
	
	# 120 minute session
	register_template(ClassSessionTemplate.create(120, "120 min", [
		{"type": "pose", "duration": 60, "amount": 5},     # 5min
		{"type": "pose", "duration": 5*60, "amount": 3},   # 20min (15min)
		{"type": "break", "duration": 5*60, "amount": 1},  # 25min (5min)
		{"type": "pose", "duration": 10*60, "amount": 2},  # 45min (20min)
		{"type": "pose", "duration": 20*60, "amount": 1},  # 65min (20min)
		{"type": "break", "duration": 5*60, "amount": 1},  # 70min (5min)
		{"type": "pose", "duration": 50*60, "amount": 1},  # 120min (50min)
	]))
	
	# 180 minute session
	register_template(ClassSessionTemplate.create(180, "180 min", [
		{"type": "pose", "duration": 60, "amount": 5},     # 5min
		{"type": "pose", "duration": 5*60, "amount": 3},   # 20min (15min)
		{"type": "pose", "duration": 10*60, "amount": 2},  # 40min (20min)
		{"type": "break", "duration": 5*60, "amount": 1},  # 45min (5min)
		{"type": "pose", "duration": 20*60, "amount": 2},  # 85min (40min)
		{"type": "break", "duration": 5*60, "amount": 1},  # 90min (5min)
		{"type": "pose", "duration": 30*60, "amount": 1},  # 120min (30min)
		{"type": "pose", "duration": 60*60, "amount": 1},  # 180min (60min)
	]))

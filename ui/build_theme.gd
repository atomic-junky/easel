class_name EaselTheme extends Theme

const OUT: String = "res://ui/default_theme.tres"

const ACCENT: Color = Color("49BDB8")
const ACCENT_SOFT: Color = Color("41252a")
const BLUE: Color = Color("4f9bf4")
const GREEN: Color = Color("3fc98a")
const YELLOW: Color = Color("ffc940")
const PURPLE: Color = Color("a77bf3")

const BACKGROUND: Color = Color("131315")
const SURFACE: Color = Color("1e1e21")
const NEUTRAL: Color = Color("2b2b30")
const NEUTRAL_DARK: Color = Color("3d3d44")
const TEXT: Color = Color("f2efea")
const TEXT_DIM: Color = Color(0.949, 0.937, 0.918, 0.5)
const DISABLED: Color = Color(0.949, 0.937, 0.918, 0.14)
const ON_ACCENT: Color = Color(1, 1, 1)
const OVERLAY: Color = Color(0.043, 0.043, 0.05, 0.62)

## Muted hues used to tint pack cards so a grid never reads as one flat block.
const CARD_TINTS: Array[Color] = [
	Color("3a2529"), Color("1f2c3d"), Color("1e332b"), Color("3a3122"), Color("2c2440")
]

const R: int = 18
const R_SM: int = 10
const R_PILL: int = 100
const R_MODAL: int = 28
const BORDER: int = 3

# Button padding, by role. Sized so every control clears a ~44px touch target
# once the DPI scale factor is applied.
const PAD_TEXT: Vector2 = Vector2(26, 14)
const PAD_ICON: Vector2 = Vector2(13, 13)
const PAD_CHIP: Vector2 = Vector2(22, 13)

const FONT_BOLD: String = "res://assets/fonts/InterDisplay/InterDisplay-Bold.ttf"
const FONT_SEMI: String = "res://assets/fonts/InterDisplay/InterDisplay-SemiBold.ttf"
const FONT_MED: String = "res://assets/fonts/InterDisplay/InterDisplay-Medium.ttf"

var _bold: Font
var _semi: Font
var _med: Font


func _init() -> void:
	_bold = load(FONT_BOLD)
	_semi = load(FONT_SEMI)
	_med = load(FONT_MED)

	var t := Theme.new()
	t.default_font = _semi
	t.default_font_size = 15

	_build_button(t)
	_build_labels(t)
	_build_inputs(t)
	_build_panels(t)
	_build_pack(t)
	_build_switcher(t)
	_build_popup(t)
	_build_misc(t)

	var err: int = ResourceSaver.save(t, OUT)
	if err != OK:
		printerr("build_theme: save failed (%d)" % err)
	else:
		print("build_theme: wrote ", OUT)


## Style helpers

func _flat(
	bg: Color,
	radius: int = R,
	pad_x: float = 10.0,
	pad_y: float = 5.0,
	border: int = 0,
	border_color: Color = Color(0, 0, 0, 0)
) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(radius)
	s.corner_detail = 12
	s.content_margin_left = pad_x
	s.content_margin_right = pad_x
	s.content_margin_top = pad_y
	s.content_margin_bottom = pad_y
	if border > 0:
		s.set_border_width_all(border)
		s.border_color = border_color
	return s


func _empty(pad_x: float = 0.0, pad_y: float = 0.0) -> StyleBoxEmpty:
	var s := StyleBoxEmpty.new()
	s.content_margin_left = pad_x
	s.content_margin_right = pad_x
	s.content_margin_top = pad_y
	s.content_margin_bottom = pad_y
	return s


## Fills the six Button styleboxes from a single background colour.
func _button_styles(t: Theme, type: String, bg: Color, radius: int, pad_x: float, pad_y: float) -> void:
	t.set_stylebox("normal", type, _flat(bg, radius, pad_x, pad_y))
	t.set_stylebox("hover", type, _flat(bg.lightened(0.1), radius, pad_x, pad_y))
	t.set_stylebox("pressed", type, _flat(bg.darkened(0.14), radius, pad_x, pad_y))
	t.set_stylebox("hover_pressed", type, _flat(bg.darkened(0.07), radius, pad_x, pad_y))
	t.set_stylebox("disabled", type, _flat(DISABLED, radius, pad_x, pad_y))
	t.set_stylebox("focus", type, _empty(pad_x, pad_y))


func _button_font(t: Theme, type: String, color: Color, size: int = 15) -> void:
	t.set_font("font", type, _bold)
	t.set_font_size("font_size", type, size)
	for state: String in ["font_color", "font_hover_color", "font_pressed_color",
			"font_hover_pressed_color", "font_focus_color"]:
		t.set_color(state, type, color)
	t.set_color("font_disabled_color", type, ON_ACCENT)
	for state: String in ["icon_normal_color", "icon_hover_color", "icon_pressed_color",
			"icon_hover_pressed_color", "icon_focus_color"]:
		t.set_color(state, type, color)
	t.set_color("icon_disabled_color", type, ON_ACCENT)


## Types

func _build_button(t: Theme) -> void:
	_button_styles(t, "Button", NEUTRAL, R_PILL, PAD_TEXT.x, PAD_TEXT.y)
	_button_font(t, "Button", TEXT)
	t.set_constant("h_separation", "Button", 10)
	t.set_constant("icon_max_width", "Button", 20)

	t.set_type_variation("ButtonAccent", "Button")
	_button_styles(t, "ButtonAccent", ACCENT, R_PILL, PAD_TEXT.x, PAD_TEXT.y)
	_button_font(t, "ButtonAccent", ON_ACCENT, 16)
	t.set_constant("icon_max_width", "ButtonAccent", 22)

	# Square icon buttons: text padding would push a 22px icon past its box.
	t.set_type_variation("ButtonIcon", "Button")
	_button_styles(t, "ButtonIcon", ACCENT, R_PILL, PAD_ICON.x, PAD_ICON.y)
	_button_font(t, "ButtonIcon", ON_ACCENT)
	t.set_constant("icon_max_width", "ButtonIcon", 22)

	t.set_type_variation("ButtonSoft", "Button")
	_button_styles(t, "ButtonSoft", NEUTRAL, R_PILL, PAD_ICON.x, PAD_ICON.y)
	_button_font(t, "ButtonSoft", TEXT)
	t.set_constant("icon_max_width", "ButtonSoft", 22)

	# Option chips. Unselected reads as a soft outline so the selected one pops.
	t.set_type_variation("ButtonChip", "Button")
	t.set_stylebox("normal", "ButtonChip",
		_flat(SURFACE, R_PILL, PAD_CHIP.x, PAD_CHIP.y, 2, NEUTRAL_DARK))
	t.set_stylebox("hover", "ButtonChip",
		_flat(NEUTRAL, R_PILL, PAD_CHIP.x, PAD_CHIP.y, 2, NEUTRAL_DARK))
	t.set_stylebox("pressed", "ButtonChip",
		_flat(ACCENT, R_PILL, PAD_CHIP.x, PAD_CHIP.y, 2, ACCENT))
	t.set_stylebox("hover_pressed", "ButtonChip",
		_flat(ACCENT.lightened(0.08), R_PILL, PAD_CHIP.x, PAD_CHIP.y, 2, ACCENT))
	t.set_stylebox("disabled", "ButtonChip", _flat(DISABLED, R_PILL, PAD_CHIP.x, PAD_CHIP.y))
	t.set_stylebox("focus", "ButtonChip", _empty(PAD_CHIP.x, PAD_CHIP.y))
	t.set_font("font", "ButtonChip", _bold)
	t.set_font_size("font_size", "ButtonChip", 16)
	t.set_color("font_color", "ButtonChip", TEXT)
	t.set_color("font_hover_color", "ButtonChip", TEXT)
	t.set_color("font_pressed_color", "ButtonChip", ON_ACCENT)
	t.set_color("font_hover_pressed_color", "ButtonChip", ON_ACCENT)
	t.set_color("font_focus_color", "ButtonChip", TEXT)

	# Round +/- of the custom value stepper.
	t.set_type_variation("ButtonStepper", "Button")
	_button_styles(t, "ButtonStepper", ACCENT_SOFT, R_PILL, 0, 0)
	_button_font(t, "ButtonStepper", ACCENT, 22)

	t.set_type_variation("CheckSquare", "Button")
	t.set_stylebox("normal", "CheckSquare", _flat(SURFACE, R_SM, 0, 0, 2, NEUTRAL_DARK))
	t.set_stylebox("hover", "CheckSquare", _flat(NEUTRAL, R_SM, 0, 0, 2, NEUTRAL_DARK))
	t.set_stylebox("pressed", "CheckSquare", _flat(ACCENT, R_SM, 0, 0, 2, ACCENT))
	t.set_stylebox("hover_pressed", "CheckSquare",
		_flat(ACCENT.lightened(0.08), R_SM, 0, 0, 2, ACCENT))
	t.set_stylebox("disabled", "CheckSquare", _flat(DISABLED, R_SM, 0, 0))
	t.set_stylebox("focus", "CheckSquare", _empty())

	# Session drawing toolbar swatches.
	t.set_type_variation("ButtonColor", "Button")
	t.set_stylebox("normal", "ButtonColor", _flat(Color(0, 0, 0, 0), R_PILL, 0, 0))
	t.set_stylebox("hover", "ButtonColor", _flat(NEUTRAL, R_PILL, 0, 0))
	t.set_stylebox("pressed", "ButtonColor", _flat(ACCENT, R_PILL, 0, 0))
	t.set_stylebox("hover_pressed", "ButtonColor", _flat(ACCENT, R_PILL, 0, 0))
	t.set_stylebox("focus", "ButtonColor", _empty())
	t.set_constant("icon_max_width", "ButtonColor", 24)
	t.set_constant("h_separation", "ButtonColor", 0)


func _build_labels(t: Theme) -> void:
	t.set_font("font", "Label", _semi)
	t.set_font_size("font_size", "Label", 15)
	t.set_color("font_color", "Label", TEXT)

	_label_variation(t, "LabelTitle", _bold, 52, TEXT)
	_label_variation(t, "LabelSection", _bold, 26, TEXT)
	_label_variation(t, "LabelGroup", _bold, 18, TEXT)
	_label_variation(t, "LabelMeta", _med, 13, TEXT_DIM)
	_label_variation(t, "LabelSecondary", _med, 15, TEXT_DIM)
	_label_variation(t, "LabelFieldTitle", _bold, 16, TEXT)
	_label_variation(t, "LabelPackTitle", _bold, 15, TEXT)
	_label_variation(t, "LabelPackInfos", _med, 11, TEXT)
	_label_variation(t, "LabelBadge", _bold, 15, ON_ACCENT)
	_label_variation(t, "LabelValue", _bold, 24, TEXT)
	_label_variation(t, "HeaderSmall", _semi, 17, TEXT)


func _label_variation(t: Theme, name: String, font: Font, size: int, color: Color) -> void:
	t.set_type_variation(name, "Label")
	t.set_font("font", name, font)
	t.set_font_size("font_size", name, size)
	t.set_color("font_color", name, color)


func _build_inputs(t: Theme) -> void:
	t.set_stylebox("normal", "LineEdit", _flat(NEUTRAL, R_PILL, 18, 12))
	t.set_stylebox("focus", "LineEdit", _flat(NEUTRAL, R_PILL, 18, 12, 2, ACCENT))
	t.set_font("font", "LineEdit", _bold)
	t.set_font_size("font_size", "LineEdit", 16)
	t.set_color("font_color", "LineEdit", TEXT)
	t.set_color("font_placeholder_color", "LineEdit", TEXT_DIM)
	t.set_color("caret_color", "LineEdit", ACCENT)

	# Centred, borderless field used inside the stepper.
	t.set_type_variation("LineEditValue", "LineEdit")
	t.set_stylebox("normal", "LineEditValue", _empty(6, 6))
	t.set_stylebox("focus", "LineEditValue", _empty(6, 6))
	t.set_font("font", "LineEditValue", _bold)
	t.set_font_size("font_size", "LineEditValue", 24)

	t.set_font("font", "CheckBox", _semi)
	t.set_font_size("font_size", "CheckBox", 15)
	t.set_color("font_color", "CheckBox", TEXT)
	for state: String in ["icon_normal_color", "icon_hover_color", "icon_pressed_color",
			"icon_hover_pressed_color"]:
		t.set_color(state, "CheckBox", TEXT)


func _build_panels(t: Theme) -> void:
	t.set_stylebox("panel", "PanelContainer", _flat(SURFACE, R, 0, 0))

	t.set_type_variation("ModalPanel", "PanelContainer")
	t.set_stylebox("panel", "ModalPanel", _flat(SURFACE, R_MODAL, 30, 30))

	# Soft grouping block behind a section of the page.
	t.set_type_variation("SectionPanel", "PanelContainer")
	t.set_stylebox("panel", "SectionPanel", _flat(SURFACE, R, 18, 18))

	t.set_type_variation("FieldPanel", "PanelContainer")
	t.set_stylebox("panel", "FieldPanel", _flat(BACKGROUND, R, 16, 16))

	for side: String in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		t.set_constant(side, "MarginContainer", 0)


func _build_pack(t: Theme) -> void:
	# The card is a toggle Button: "pressed" is the selected state, so the accent
	# border comes for free. Only the border is drawn here — the Mosaic child,
	# inset by BORDER, paints the background and clips the previews.
	var clear: Color = Color(0, 0, 0, 0)
	t.set_type_variation("PackCard", "Button")
	t.set_stylebox("normal", "PackCard", _flat(clear, R, 0, 0, BORDER, NEUTRAL_DARK))
	t.set_stylebox("hover", "PackCard", _flat(clear, R, 0, 0, BORDER, ACCENT.lightened(0.5)))
	t.set_stylebox("pressed", "PackCard", _flat(clear, R, 0, 0, BORDER, ACCENT))
	t.set_stylebox("hover_pressed", "PackCard", _flat(clear, R, 0, 0, BORDER, ACCENT))
	t.set_stylebox("disabled", "PackCard", _flat(clear, R, 0, 0, BORDER, NEUTRAL_DARK))
	t.set_stylebox("focus", "PackCard", _empty())

	# One clip variation per tint; pack.gd picks by index.
	for i in CARD_TINTS.size():
		var name: String = "PackCardClip%d" % i
		t.set_type_variation(name, "PanelContainer")
		t.set_stylebox("panel", name, _flat(CARD_TINTS[i], R - BORDER, 0, 0))

	t.set_type_variation("PackCardLabel", "PanelContainer")
	t.set_stylebox("panel", "PackCardLabel", _flat(OVERLAY, R_SM, 8, 4))

	t.set_type_variation("PackBadge", "PanelContainer")
	t.set_stylebox("panel", "PackBadge", _flat(ACCENT, R_PILL, 0, 0))

	# Round action buttons sitting on top of the card artwork.
	t.set_type_variation("PackAction", "Button")
	t.set_stylebox("normal", "PackAction", _flat(OVERLAY, R_PILL, 6, 6))
	t.set_stylebox("hover", "PackAction", _flat(NEUTRAL_DARK, R_PILL, 6, 6))
	t.set_stylebox("pressed", "PackAction", _flat(ACCENT, R_PILL, 6, 6))
	t.set_stylebox("hover_pressed", "PackAction", _flat(ACCENT, R_PILL, 6, 6))
	t.set_stylebox("disabled", "PackAction", _flat(DISABLED, R_PILL, 6, 6))
	t.set_stylebox("focus", "PackAction", _empty(6, 6))
	_button_font(t, "PackAction", TEXT)
	t.set_constant("icon_max_width", "PackAction", 18)

	t.set_type_variation("PackActionDanger", "Button")
	t.set_stylebox("normal", "PackActionDanger", _flat(OVERLAY, R_PILL, 6, 6))
	t.set_stylebox("hover", "PackActionDanger", _flat(ACCENT, R_PILL, 6, 6))
	t.set_stylebox("pressed", "PackActionDanger", _flat(ACCENT.darkened(0.2), R_PILL, 6, 6))
	t.set_stylebox("hover_pressed", "PackActionDanger", _flat(ACCENT, R_PILL, 6, 6))
	t.set_stylebox("focus", "PackActionDanger", _empty(6, 6))
	_button_font(t, "PackActionDanger", TEXT)
	t.set_constant("icon_max_width", "PackActionDanger", 18)


func _build_switcher(t: Theme) -> void:
	t.set_type_variation("SwitcherPanel", "PanelContainer")
	t.set_stylebox("panel", "SwitcherPanel", _flat(NEUTRAL, R_PILL, 6, 6))

	t.set_type_variation("SwitcherBG", "Panel")
	t.set_stylebox("panel", "SwitcherBG", _flat(NEUTRAL, 0, 0, 0))

	var px: float = PAD_CHIP.x
	var py: float = PAD_CHIP.y
	t.set_type_variation("ButtonSwitcher", "Button")
	t.set_stylebox("normal", "ButtonSwitcher", _empty(px, py))
	t.set_stylebox("hover", "ButtonSwitcher", _flat(Color(1, 1, 1, 0.08), R_PILL, px, py))
	t.set_stylebox("pressed", "ButtonSwitcher", _flat(ACCENT, R_PILL, px, py))
	t.set_stylebox("hover_pressed", "ButtonSwitcher",
		_flat(ACCENT.lightened(0.08), R_PILL, px, py))
	t.set_stylebox("disabled", "ButtonSwitcher", _empty(px, py))
	t.set_stylebox("focus", "ButtonSwitcher", _empty(px, py))
	t.set_font("font", "ButtonSwitcher", _bold)
	t.set_font_size("font_size", "ButtonSwitcher", 16)
	t.set_color("font_color", "ButtonSwitcher", TEXT_DIM)
	t.set_color("font_hover_color", "ButtonSwitcher", TEXT)
	t.set_color("font_pressed_color", "ButtonSwitcher", ON_ACCENT)
	t.set_color("font_hover_pressed_color", "ButtonSwitcher", ON_ACCENT)
	t.set_color("font_focus_color", "ButtonSwitcher", TEXT_DIM)
	t.set_color("font_disabled_color", "ButtonSwitcher", DISABLED)


func _build_popup(t: Theme) -> void:
	t.set_stylebox("panel", "PopupMenu", _flat(SURFACE, R, 0, 8, 2, NEUTRAL))
	t.set_stylebox("hover", "PopupMenu", _flat(ACCENT_SOFT, R_SM, 0, 0))
	t.set_font("font", "PopupMenu", _semi)
	t.set_font_size("font_size", "PopupMenu", 15)
	t.set_color("font_color", "PopupMenu", TEXT)
	t.set_color("font_hover_color", "PopupMenu", TEXT)
	t.set_constant("item_start_padding", "PopupMenu", 14)
	t.set_constant("item_end_padding", "PopupMenu", 14)
	t.set_constant("v_separation", "PopupMenu", 8)

	for state: String in ["normal", "hover", "pressed", "focus"]:
		t.set_stylebox(state, "MenuButton", _empty())
	for state: String in ["icon_normal_color", "icon_hover_color", "icon_pressed_color"]:
		t.set_color(state, "MenuButton", TEXT)


func _build_misc(t: Theme) -> void:
	var line := StyleBoxLine.new()
	line.color = NEUTRAL
	line.thickness = 2
	t.set_stylebox("separator", "HSeparator", line)

	var vline := StyleBoxLine.new()
	vline.color = NEUTRAL
	vline.thickness = 2
	vline.vertical = true
	t.set_stylebox("separator", "VSeparator", vline)

	t.set_icon("grabber", "HSlider", load("res://assets/icons/grabber.svg"))
	t.set_icon("grabber_highlight", "HSlider", load("res://assets/icons/grabber.svg"))
	t.set_stylebox("slider", "HSlider", _flat(NEUTRAL, R_PILL, 0, 0))
	t.set_constant("center_grabber", "HSlider", 1)

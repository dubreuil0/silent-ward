class_name UiKit
extends RefCounted
## Ortak yazı tipleri ve tema.

static var _theme: Theme
static var _fonts: Dictionary = {}


static func font(kind: String) -> Font:
	if _fonts.has(kind):
		return _fonts[kind]
	var f := SystemFont.new()
	match kind:
		"title":
			f.font_names = PackedStringArray(["Georgia", "Times New Roman", "Serif"])
			f.font_weight = 700
		"type":
			f.font_names = PackedStringArray(["Courier New", "Consolas", "Monospace"])
		_:
			f.font_names = PackedStringArray(["Segoe UI", "Arial", "Sans-Serif"])
	f.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
	_fonts[kind] = f
	return f


static func theme() -> Theme:
	if _theme:
		return _theme
	var t := Theme.new()
	t.default_font = font("ui")
	t.default_font_size = 18

	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.05, 0.05, 0.06, 0.6)
	normal.border_color = Color(0.35, 0.33, 0.3, 0.5)
	normal.border_width_left = 2
	normal.content_margin_left = 22
	normal.content_margin_right = 22
	normal.content_margin_top = 10
	normal.content_margin_bottom = 10
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.22, 0.03, 0.03, 0.75)
	hover.border_color = Color(0.75, 0.1, 0.08)
	hover.border_width_left = 5
	var pressed := hover.duplicate() as StyleBoxFlat
	pressed.bg_color = Color(0.35, 0.04, 0.04, 0.85)
	t.set_stylebox("normal", "Button", normal)
	t.set_stylebox("hover", "Button", hover)
	t.set_stylebox("pressed", "Button", pressed)
	t.set_stylebox("focus", "Button", hover)
	t.set_color("font_color", "Button", Color(0.8, 0.78, 0.74))
	t.set_color("font_hover_color", "Button", Color(1.0, 0.85, 0.8))
	t.set_color("font_focus_color", "Button", Color(1.0, 0.85, 0.8))
	t.set_color("font_pressed_color", "Button", Color(1.0, 0.7, 0.65))
	t.set_font("font", "Button", font("title"))
	t.set_font_size("font_size", "Button", 22)

	var panel := StyleBoxFlat.new()
	panel.bg_color = Color(0.03, 0.03, 0.035, 0.92)
	panel.border_color = Color(0.3, 0.06, 0.05)
	panel.set_border_width_all(1)
	panel.set_content_margin_all(28)
	t.set_stylebox("panel", "PanelContainer", panel)

	var track := StyleBoxFlat.new()
	track.bg_color = Color(0.2, 0.2, 0.2)
	track.content_margin_top = 3
	track.content_margin_bottom = 3
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(0.6, 0.08, 0.06)
	fill.content_margin_top = 3
	fill.content_margin_bottom = 3
	t.set_stylebox("slider", "HSlider", track)
	t.set_stylebox("grabber_area", "HSlider", fill)
	t.set_stylebox("grabber_area_highlight", "HSlider", fill)
	t.set_color("font_color", "Label", Color(0.82, 0.8, 0.76))
	t.set_color("font_color", "CheckBox", Color(0.82, 0.8, 0.76))
	_theme = t
	return t


static func label(text: String, size := 18, kind := "ui", color := Color(0.82, 0.8, 0.76)) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", font(kind))
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	l.add_theme_constant_override("outline_size", 6)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


static func button(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.custom_minimum_size = Vector2(320, 0)
	b.pressed.connect(func() -> void:
		Sfx.play("flash_click", -8.0, 0.8, "UI")
		cb.call())
	b.mouse_entered.connect(func() -> void:
		Sfx.play("flash_click", -18.0, 1.6, "UI"))
	return b

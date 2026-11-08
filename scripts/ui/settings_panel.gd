class_name SettingsPanel
extends PanelContainer
## Ayarlar: fare hassasiyeti, ses, parlaklık, tam ekran.

signal closed


func _ready() -> void:
	theme = UiKit.theme()
	custom_minimum_size = Vector2(520, 0)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	add_child(v)
	v.add_child(UiKit.label("AYARLAR", 30, "title", Color(0.85, 0.15, 0.1)))
	var lang_row := HBoxContainer.new()
	lang_row.add_theme_constant_override("separation", 16)
	var lang_label := UiKit.label("Dil / Language", 18)
	lang_label.custom_minimum_size = Vector2(190, 0)
	lang_row.add_child(lang_label)
	var lang := OptionButton.new()
	lang.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	lang.add_item("Türkçe")
	lang.add_item("English")
	lang.selected = 0 if Game.language == "tr" else 1
	lang.item_selected.connect(func(i: int) -> void:
		Game.language = "tr" if i == 0 else "en"
		Game.apply_settings())
	lang_row.add_child(lang)
	v.add_child(lang_row)
	_slider(v, "Fare hassasiyeti", 0.05, 1.0, Game.sensitivity, func(x: float) -> void: Game.sensitivity = x)
	_slider(v, "Ana ses", 0.0, 1.0, Game.master_volume, func(x: float) -> void: Game.master_volume = x)
	_slider(v, "Parlaklık", 0.6, 1.8, Game.brightness, func(x: float) -> void: Game.brightness = x)
	var fs := CheckBox.new()
	fs.text = "Tam ekran (F11)"
	fs.button_pressed = Game.fullscreen
	visibility_changed.connect(func() -> void: fs.set_pressed_no_signal(Game.fullscreen))
	fs.toggled.connect(func(on: bool) -> void:
		Game.fullscreen = on
		Game.apply_settings())
	v.add_child(fs)
	v.add_child(UiKit.label("İpucu: Oyun karanlık olmak üzere tasarlandı. Parlaklığı,\nekranın en karanlık köşesi zar zor seçilene kadar ayarla.", 14, "ui", Color(0.55, 0.53, 0.5)))
	v.add_child(UiKit.button("Geri", func() -> void:
		Game.save_settings()
		hide()
		closed.emit()))


func _slider(parent: Control, text: String, lo: float, hi: float, value: float, setter: Callable) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	var l := UiKit.label(text, 18)
	l.custom_minimum_size = Vector2(190, 0)
	row.add_child(l)
	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = 0.01
	s.value = value
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.custom_minimum_size = Vector2(240, 24)
	s.value_changed.connect(func(x: float) -> void:
		setter.call(x)
		Game.apply_settings())
	row.add_child(s)
	parent.add_child(row)

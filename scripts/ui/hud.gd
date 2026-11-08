class_name HUD
extends CanvasLayer
## Oyun içi arayüz: hedef, envanter, fener/stamina, notlar, dolap görünümü,
## duraklatma menüsü, ölüm / kaçış ekranları ve post-process.

const POST_SHADER := preload("res://assets/shaders/post_process.gdshader")
const SLIT_SHADER := """
shader_type canvas_item;
uniform float open = 1.0;
void fragment() {
	vec2 uv = UV;
	float region = smoothstep(0.30, 0.34, uv.y) * smoothstep(0.66, 0.62, uv.y)
		* smoothstep(0.12, 0.18, uv.x) * smoothstep(0.88, 0.82, uv.x);
	float slit = smoothstep(0.25, 0.42, fract(uv.y * 13.0)) * smoothstep(0.98, 0.82, fract(uv.y * 13.0));
	float a = 1.0 - region * slit * open;
	COLOR = vec4(0.0, 0.0, 0.0, clamp(a, 0.0, 0.985));
}
"""

var _post: ShaderMaterial
var _root: Control
var _cross: ColorRect
var _prompt: Label
var _message: Label
var _msg_tween: Tween
var _objective: Label
var _obj_header: Label
var _fuses: Label
var _keys: Label
var _battery_fill: ColorRect
var _battery_label: Label
var _stamina_bg: ColorRect
var _stamina_fill: ColorRect
var _locker_view: ColorRect
var _breath_box: VBoxContainer
var _breath_fill: ColorRect
var _breath_hint: Label
var _note_layer: Control
var _note_title: Label
var _note_body: Label
var _pause_layer: Control
var _pause_menu: VBoxContainer
var _pause_notes: Label
var _settings: SettingsPanel
var _end_layer: Control
var _fade: ColorRect
var _damage := 0.0
var _blackout := 0.0
var _glitch := 0.0
var _paused := false


func _ready() -> void:
	Game.hud = self
	layer = 5
	process_mode = Node.PROCESS_MODE_ALWAYS

	var post_layer := CanvasLayer.new()
	post_layer.layer = 1
	add_child(post_layer)
	var pr := ColorRect.new()
	pr.set_anchors_preset(Control.PRESET_FULL_RECT)
	pr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_post = ShaderMaterial.new()
	_post.shader = POST_SHADER
	pr.material = _post
	post_layer.add_child(pr)

	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.theme = UiKit.theme()
	add_child(_root)

	_build_locker_view()
	_build_gameplay()
	if Game.touch:
		_root.add_child(TouchControls.new())
	# Android geri tuşu oyundan çıkmasın, duraklatsın
	get_tree().quit_on_go_back = false
	_build_note()
	_build_pause()
	_build_end()

	_fade = ColorRect.new()
	_fade.color = Color.BLACK
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_fade)
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", 0.0, 2.5).set_delay(0.3)

	Game.message.connect(show_message)
	Game.objective_changed.connect(_on_objective)
	Game.inventory_changed.connect(_refresh_inventory)
	_refresh_inventory()


func _build_gameplay() -> void:
	_cross = ColorRect.new()
	_cross.color = Color(1, 1, 1, 0.25)
	_cross.size = Vector2(4, 4)
	_cross.set_anchors_preset(Control.PRESET_CENTER)
	_cross.position = Vector2(-2, -2)
	_cross.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_cross)

	_prompt = UiKit.label("", 20)
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.set_anchors_preset(Control.PRESET_CENTER)
	_prompt.position = Vector2(-300, 34)
	_prompt.size = Vector2(600, 30)
	_root.add_child(_prompt)

	_message = UiKit.label("", 22, "title", Color(0.9, 0.86, 0.8))
	_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_message.position = Vector2(-450, -330 if Game.touch else -170)
	_message.size = Vector2(900, 40)
	_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_message.modulate.a = 0.0
	_root.add_child(_message)

	var obj := VBoxContainer.new()
	obj.position = Vector2(36, 30)
	obj.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(obj)
	_obj_header = UiKit.label("HEDEF", 13, "ui", Color(0.7, 0.15, 0.1))
	obj.add_child(_obj_header)
	_objective = UiKit.label("", 19, "title")
	_objective.custom_minimum_size = Vector2(520, 0)
	_objective.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	obj.add_child(_objective)

	var inv := VBoxContainer.new()
	inv.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	inv.position = Vector2(-300, 30)
	inv.size = Vector2(264, 100)
	inv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(inv)
	_fuses = UiKit.label("", 19, "title")
	_fuses.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	inv.add_child(_fuses)
	_keys = UiKit.label("", 15, "ui", Color(0.7, 0.68, 0.6))
	_keys.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	inv.add_child(_keys)

	var bat := Control.new()
	bat.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	bat.position = Vector2(36, -64)
	bat.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(bat)
	_battery_label = UiKit.label("FENER", 13, "ui", Color(0.65, 0.63, 0.58))
	bat.add_child(_battery_label)
	var bg := ColorRect.new()
	bg.color = Color(0.1, 0.1, 0.1, 0.7)
	bg.position = Vector2(0, 24)
	bg.size = Vector2(170, 7)
	bat.add_child(bg)
	_battery_fill = ColorRect.new()
	_battery_fill.color = Color(0.85, 0.78, 0.55, 0.85)
	_battery_fill.position = Vector2(0, 24)
	_battery_fill.size = Vector2(170, 7)
	bat.add_child(_battery_fill)

	_stamina_bg = ColorRect.new()
	_stamina_bg.color = Color(0.1, 0.1, 0.1, 0.5)
	_stamina_bg.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_stamina_bg.position = Vector2(-120, -46)
	_stamina_bg.size = Vector2(240, 4)
	_stamina_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_stamina_bg)
	_stamina_fill = ColorRect.new()
	_stamina_fill.color = Color(0.8, 0.8, 0.8, 0.8)
	_stamina_fill.size = Vector2(240, 4)
	_stamina_bg.add_child(_stamina_fill)

	_breath_box = VBoxContainer.new()
	_breath_box.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_breath_box.position = Vector2(-200, -150)
	_breath_box.size = Vector2(400, 60)
	_breath_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_breath_box.visible = false
	_root.add_child(_breath_box)
	_breath_hint = UiKit.label("", 17)
	_breath_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_breath_box.add_child(_breath_hint)
	var bb := ColorRect.new()
	bb.color = Color(0.1, 0.1, 0.1, 0.7)
	bb.custom_minimum_size = Vector2(400, 6)
	_breath_box.add_child(bb)
	_breath_fill = ColorRect.new()
	_breath_fill.color = Color(0.55, 0.7, 0.85, 0.9)
	_breath_fill.size = Vector2(400, 6)
	bb.add_child(_breath_fill)


func _build_locker_view() -> void:
	_locker_view = ColorRect.new()
	_locker_view.set_anchors_preset(Control.PRESET_FULL_RECT)
	_locker_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh := Shader.new()
	sh.code = SLIT_SHADER
	var m := ShaderMaterial.new()
	m.shader = sh
	_locker_view.material = m
	_locker_view.visible = false
	_root.add_child(_locker_view)


func _build_note() -> void:
	_note_layer = Control.new()
	_note_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_note_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_note_layer.visible = false
	_root.add_child(_note_layer)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_note_layer.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_note_layer.add_child(center)
	var paper := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.78, 0.74, 0.62)
	sb.border_color = Color(0.45, 0.38, 0.28)
	sb.set_border_width_all(2)
	sb.set_content_margin_all(26 if Game.mobile else 42)
	sb.shadow_color = Color(0, 0, 0, 0.6)
	sb.shadow_size = 18
	paper.add_theme_stylebox_override("panel", sb)
	paper.custom_minimum_size = Vector2(640, 0)
	paper.rotation_degrees = -0.8
	center.add_child(paper)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10 if Game.mobile else 18)
	paper.add_child(v)
	_note_title = Label.new()
	_note_title.add_theme_font_override("font", UiKit.font("title"))
	_note_title.add_theme_font_size_override("font_size", 26)
	_note_title.add_theme_color_override("font_color", Color(0.18, 0.1, 0.08))
	v.add_child(_note_title)
	_note_body = Label.new()
	_note_body.add_theme_font_override("font", UiKit.font("type"))
	_note_body.add_theme_font_size_override("font_size", 16 if Game.mobile else 18)
	_note_body.add_theme_color_override("font_color", Color(0.12, 0.1, 0.1))
	_note_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_note_body.custom_minimum_size = Vector2(556, 0)
	v.add_child(_note_body)
	var foot := Label.new()
	foot.text = "Kapatmak için dokun" if Game.touch else "[E] / [ESC]  Kapat"
	foot.add_theme_font_size_override("font_size", 14)
	foot.add_theme_color_override("font_color", Color(0.35, 0.3, 0.25))
	foot.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	v.add_child(foot)


func _build_pause() -> void:
	_pause_layer = Control.new()
	_pause_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_pause_layer.visible = false
	_root.add_child(_pause_layer)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.75)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_pause_layer.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_pause_layer.add_child(center)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	center.add_child(v)
	_pause_menu = v
	v.add_child(UiKit.label("DURAKLATILDI", 40, "title", Color(0.8, 0.12, 0.08)))
	_pause_notes = UiKit.label("", 15, "ui", Color(0.5, 0.5, 0.5))
	v.add_child(_pause_notes)
	v.add_child(UiKit.button("Devam et", func() -> void: set_paused(false)))
	v.add_child(UiKit.button("Ayarlar", func() -> void:
		v.hide()
		_settings.show()))
	v.add_child(UiKit.button("Yeniden başla", func() -> void: Game.start_game()))
	v.add_child(UiKit.button("Ana menü", func() -> void: Game.go_menu()))
	if not Game.mobile:
		v.add_child(UiKit.button("Masaüstüne çık", func() -> void: get_tree().quit()))
	v.add_child(UiKit.label("hud.controls.touch" if Game.touch else "hud.controls", 14, "ui", Color(0.5, 0.5, 0.5)))
	_settings = SettingsPanel.new()
	_settings.hide()
	_settings.closed.connect(func() -> void: v.show())
	center.add_child(_settings)


func _build_end() -> void:
	_end_layer = Control.new()
	_end_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_end_layer.visible = false
	_root.add_child(_end_layer)


# ---------------------------------------------------------------- güncelleme

func _process(delta: float) -> void:
	var p := Game.player as Player
	if p:
		_battery_fill.size.x = 170.0 * p.battery / 100.0
		_battery_fill.color = Color(0.85, 0.78, 0.55, 0.85) if p.battery > 25.0 else Color(0.85, 0.25, 0.15, 0.6 + 0.3 * sin(Time.get_ticks_msec() * 0.01))
		_battery_label.text = tr("FENER  %d%%") % int(p.battery) + ("" if p.flashlight_on else tr("  (kapalı)"))
		_stamina_fill.size.x = 240.0 * p.stamina / 100.0
		_stamina_fill.color = Color(0.85, 0.3, 0.2, 0.8) if p.exhausted else Color(0.8, 0.8, 0.8, 0.8)
		var want_a := 0.0 if p.stamina >= 99.5 else 1.0
		_stamina_bg.modulate.a = move_toward(_stamina_bg.modulate.a, want_a, delta * 3.0)
	_damage = move_toward(_damage, 0.0, delta * 0.35)
	_glitch = move_toward(_glitch, 0.0, delta * 1.5)
	_post.set_shader_parameter("damage", _damage)
	_post.set_shader_parameter("blackout", _blackout)
	_post.set_shader_parameter("glitch", _glitch)


func _unhandled_input(event: InputEvent) -> void:
	# pencere odağı kaybolunca fare serbest kalır; tıklayınca tekrar yakala
	if not Game.touch and event is InputEventMouseButton and event.pressed and not _paused and not _end_layer.visible \
			and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		get_viewport().set_input_as_handled()
		return
	if not event.is_action_pressed("pause"):
		return
	if _end_layer.visible:
		return
	if _note_layer.visible:
		close_note()
	elif _settings.visible:
		_settings.hide()
		_pause_menu.show()
	else:
		var p := Game.player as Player
		if p and p.dead:
			return
		set_paused(not _paused)
	get_viewport().set_input_as_handled()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and is_node_ready() and not _paused and not _end_layer.visible:
		var p := Game.player as Player
		if p and not p.dead:
			set_paused(true)
	elif what == NOTIFICATION_WM_GO_BACK_REQUEST and is_node_ready() and not _end_layer.visible:
		var ev := InputEventAction.new()
		ev.action = "pause"
		ev.pressed = true
		_unhandled_input(ev)


func set_paused(on: bool) -> void:
	_paused = on
	get_tree().paused = on
	_pause_layer.visible = on
	_settings.hide()
	if on:
		_pause_menu.show()
		_pause_notes.text = tr("Okunan notlar: %d/%d    ·    Süre: %s") % [Game.notes_read.size(), Game.NOTES_TOTAL, Game.elapsed_text()]
	if not Game.touch:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if on else Input.MOUSE_MODE_CAPTURED


func is_overlay_open() -> bool:
	return _note_layer.visible or _pause_layer.visible or _end_layer.visible


func has_prompt() -> bool:
	return _prompt.text != ""


func set_prompt(text: String) -> void:
	if text == "":
		_prompt.text = ""
		_cross.color.a = 0.25
		_cross.size = Vector2(4, 4)
		_cross.position = Vector2(-2, -2)
	else:
		_prompt.text = text if Game.touch else "[E]  " + text
		_cross.color.a = 0.9
		_cross.size = Vector2(6, 6)
		_cross.position = Vector2(-3, -3)


func show_message(text: String, duration := 3.5) -> void:
	_message.text = text
	if _msg_tween:
		_msg_tween.kill()
	_msg_tween = create_tween()
	_msg_tween.tween_property(_message, "modulate:a", 1.0, 0.25)
	_msg_tween.tween_interval(duration)
	_msg_tween.tween_property(_message, "modulate:a", 0.0, 1.0)


func _on_objective(text: String) -> void:
	_objective.text = text
	var tw := create_tween()
	_objective.modulate = Color(1.0, 0.4, 0.3)
	tw.tween_property(_objective, "modulate", Color.WHITE, 2.0)


func _refresh_inventory() -> void:
	_fuses.text = tr("SİGORTA  %d / %d") % [Game.fuses, Game.FUSES_NEEDED]
	var names: Array[String] = []
	for k in Game.keys:
		names.append("• " + tr(str(Game.keys[k])))
	_keys.text = "\n".join(names)


func set_fear(f: float) -> void:
	_post.set_shader_parameter("fear", f)


func set_locker_view(on: bool) -> void:
	_locker_view.visible = on
	_breath_box.visible = on


func set_breath(value: float, holding: bool, enemy_near: bool) -> void:
	_breath_fill.size.x = 400.0 * value
	_breath_fill.color = Color(0.55, 0.7, 0.85, 0.9) if value > 0.3 else Color(0.85, 0.3, 0.2, 0.9)
	if holding:
		_breath_hint.text = tr("Nefesini tutuyorsun...")
	elif enemy_near:
		_breath_hint.text = tr("Yakında! NEFESİNİ TUT  [NEFES]" if Game.touch else "Yakında! NEFESİNİ TUT  [Sağ Tık / Boşluk]")
		_breath_hint.add_theme_color_override("font_color", Color(0.95, 0.3, 0.25))
		return
	else:
		_breath_hint.text = tr("Saklanıyorsun   [ETKİLEŞ] Çık   [NEFES] Nefesini tut" if Game.touch else "Saklanıyorsun   [E] Çık   [Sağ Tık] Nefesini tut")
	_breath_hint.add_theme_color_override("font_color", Color(0.82, 0.8, 0.76))


func show_note(title: String, body: String) -> void:
	_note_title.text = title
	_note_body.text = body
	_note_layer.visible = true
	var p := Game.player as Player
	if p:
		p.reading = true


func close_note() -> void:
	_note_layer.visible = false
	Sfx.play("paper", -10.0, 1.2)
	var p := Game.player as Player
	if p:
		p.reading = false


func death_flash() -> void:
	_damage = 1.0
	_glitch = 1.0
	var tw := create_tween()
	tw.tween_interval(1.4)
	tw.tween_property(self, "_blackout", 1.0, 0.9)


func pulse_glitch(amount := 0.8) -> void:
	_glitch = maxf(_glitch, amount)


func fade_out(duration: float) -> void:
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", 1.0, duration)


func fade_in(duration: float) -> void:
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", 0.0, duration)


func show_end(win: bool) -> void:
	set_prompt("")
	_locker_view.visible = false
	_breath_box.visible = false
	_end_layer.visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	for c in _end_layer.get_children():
		c.queue_free()
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 1)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_end_layer.add_child(bg)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_end_layer.add_child(center)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(v)
	var title := UiKit.label("KAÇTIN" if win else "SENİ BULDU", 76, "title", Color(0.85, 0.82, 0.75) if win else Color(0.75, 0.06, 0.04))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(title)
	var sub_text := "end.win.sub" if win else "end.lose.sub"
	var sub := UiKit.label(sub_text, 20, "title", Color(0.6, 0.58, 0.55))
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(sub)
	var stats := UiKit.label(tr("Süre: %s    ·    Sigorta: %d/%d    ·    Okunan notlar: %d/%d") % [Game.elapsed_text(), Game.fuses, Game.FUSES_NEEDED, Game.notes_read.size(), Game.NOTES_TOTAL], 16, "ui", Color(0.5, 0.5, 0.5))
	stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(stats)
	v.add_child(Control.new())
	var buttons := VBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 10)
	var bc := CenterContainer.new()
	bc.add_child(buttons)
	v.add_child(bc)
	buttons.add_child(UiKit.button("Tekrar oyna" if win else "Tekrar dene", func() -> void: Game.start_game()))
	buttons.add_child(UiKit.button("Ana menü", func() -> void: Game.go_menu()))
	if not Game.mobile:
		buttons.add_child(UiKit.button("Masaüstüne çık", func() -> void: get_tree().quit()))
	_end_layer.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(_end_layer, "modulate:a", 1.0, 1.5)

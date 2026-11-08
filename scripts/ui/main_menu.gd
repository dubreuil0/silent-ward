extends Node3D
## Ana menü: arka planda titreyen ışıklı bir koridor ve uçta beliren Hemşire.

const MAP := [
	"#####",
	"#...#",
	"#...#",
	"##.##",
	"##.##",
	"##D##",
	"##.##",
	"##.##",
	"##.##",
	"##.##",
	"#####",
]

var _cam: Camera3D
var _far: FlickerLight
var _near: FlickerLight
var _nurse: NurseBody
var _t := 0.0
var _menu: VBoxContainer
var _settings: SettingsPanel
var _controls: PanelContainer
var _fade: ColorRect


func _ready() -> void:
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var b := LevelBuilder.new(PackedStringArray(MAP))
	b.build(self)
	for info in b.doors:
		var d := Door.new()
		d.cell = info["cell"]
		d.along_x = info["along_x"]
		d.position = info["center"]
		add_child(d)
		d.force_open_wide(-80.0)

	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color.BLACK
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.05, 0.06, 0.08)
	env.ambient_light_energy = 0.3
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.tonemap_exposure = 1.1 * Game.brightness
	env.ssao_enabled = true
	env.ssao_intensity = 2.5
	env.glow_enabled = true
	env.glow_intensity = 0.7
	env.volumetric_fog_enabled = true
	env.volumetric_fog_density = 0.05
	env.volumetric_fog_anisotropy = 0.6
	env.adjustment_enabled = true
	env.adjustment_saturation = 0.75
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	_near = _make_light(LevelBuilder.cell_center(2, 7), FlickerLight.Mode.FLICKER, 1.0)
	_far = _make_light(LevelBuilder.cell_center(2, 2), FlickerLight.Mode.BROKEN, 1.3)

	_nurse = NurseBody.new()
	_nurse.position = LevelBuilder.cell_center(2, 1) + Vector3(0, 0, 0.4)
	_nurse.rotation.y = 0.0
	add_child(_nurse)

	var chair := (load("res://assets/models/wheelchair_01/wheelchair_01.gltf") as PackedScene).instantiate() as Node3D
	chair.position = LevelBuilder.cell_center(2, 6) + Vector3(0.55, 0, 0.3)
	chair.rotation_degrees.y = 200.0
	add_child(chair)
	var blood := Label3D.new()
	blood.text = tr("KAÇ")
	blood.font = UiKit.font("title")
	blood.font_size = 140
	blood.pixel_size = 0.004
	blood.modulate = Color(0.35, 0.02, 0.01)
	blood.shaded = true
	blood.position = Vector3(LevelBuilder.cell_center(2, 6).x - 0.98, 1.7, LevelBuilder.cell_center(2, 6).z)
	blood.rotation_degrees = Vector3(0, 90, -6)
	add_child(blood)

	_cam = Camera3D.new()
	_cam.fov = 62.0
	_cam.position = LevelBuilder.cell_center(2, 9) + Vector3(0.3, 1.55, 0.6)
	add_child(_cam)
	_cam.current = true

	_build_ui()

	var music := AudioStreamPlayer.new()
	music.stream = Sfx.stream("music_box")
	music.bus = "Music"
	music.volume_db = -8.0
	add_child(music)
	music.play()
	var amb := AudioStreamPlayer.new()
	amb.stream = Sfx.stream("ambient_drone")
	amb.bus = "Ambient"
	amb.volume_db = -8.0
	add_child(amb)
	amb.play()

	for a in OS.get_cmdline_user_args():
		if a == "--autostart":
			Game.start_game.call_deferred()
			return
		if a.begins_with("--shots="):
			await get_tree().create_timer(4.0).timeout
			get_viewport().get_texture().get_image().save_png(a.substr(8).path_join("00_menu.png"))
			get_tree().quit()


func _make_light(pos: Vector3, mode: FlickerLight.Mode, energy: float) -> FlickerLight:
	var emissive := Mats.plain(Color(0.9, 0.9, 0.85), 0.4, 0.0, Color(0.85, 0.92, 1.0), 3.0)
	var tube := MeshInstance3D.new()
	var tm := CapsuleMesh.new()
	tm.radius = 0.022
	tm.height = 0.95
	tube.mesh = tm
	tube.rotation = Vector3(PI * 0.5, 0, 0)
	tube.position = Vector3(pos.x, LevelBuilder.HEIGHT - 0.05, pos.z)
	tube.material_override = emissive
	add_child(tube)
	var l := FlickerLight.new()
	l.position = Vector3(pos.x, LevelBuilder.HEIGHT - 0.3, pos.z)
	l.light_color = Color(0.78, 0.88, 1.0)
	l.base_energy = energy
	l.omni_range = 8.0
	l.shadow_enabled = true
	l.light_volumetric_fog_energy = 1.5
	l.mode = mode
	l.emissive = emissive
	add_child(l)
	l.buzz = Sfx.attach_loop("buzz", l, -22.0, 1.5, 10.0, false)
	return l


func _process(delta: float) -> void:
	_t += delta
	_cam.position = LevelBuilder.cell_center(2, 9) + Vector3(0.3 + sin(_t * 0.21) * 0.15, 1.55 + sin(_t * 0.37) * 0.04, 0.6 - sin(_t * 0.11) * 0.6)
	_cam.rotation = Vector3(-0.03 + sin(_t * 0.27) * 0.015, 0.05 + sin(_t * 0.17) * 0.04, sin(_t * 0.23) * 0.01)
	# Hemşire yalnızca uzaktaki lamba yandığında görünür ve her seferinde biraz yaklaşır.
	_nurse.visible = _far.light_energy > 0.2
	_nurse.animate(delta, 0.0, NurseBody.Pose.IDLE)


func _build_ui() -> void:
	var post_layer := CanvasLayer.new()
	post_layer.layer = 1
	add_child(post_layer)
	var pr := ColorRect.new()
	pr.set_anchors_preset(Control.PRESET_FULL_RECT)
	pr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var pm := ShaderMaterial.new()
	pm.shader = preload("res://assets/shaders/post_process.gdshader")
	pm.set_shader_parameter("fear", 0.15)
	pr.material = pm
	post_layer.add_child(pr)

	var ui := CanvasLayer.new()
	ui.layer = 2
	add_child(ui)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.theme = UiKit.theme()
	ui.add_child(root)

	var grad := GradientTexture2D.new()
	var g := Gradient.new()
	g.colors = PackedColorArray([Color(0, 0, 0, 0.85), Color(0, 0, 0, 0.0)])
	grad.gradient = g
	grad.fill_to = Vector2(1, 0)
	var tr := TextureRect.new()
	tr.texture = grad
	tr.stretch_mode = TextureRect.STRETCH_SCALE
	tr.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	tr.offset_right = 760
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(tr)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 90)
	margin.add_theme_constant_override("margin_top", 120)
	margin.add_theme_constant_override("margin_bottom", 60)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(margin)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	col.add_theme_constant_override("separation", 12)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(col)

	var title := UiKit.label("SESSİZ KOĞUŞ", 84, "title", Color(0.78, 0.07, 0.04))
	col.add_child(title)
	var tw := create_tween().set_loops()
	tw.tween_property(title, "modulate:a", 0.55, 0.06).set_delay(3.5)
	tw.tween_property(title, "modulate:a", 1.0, 0.05)
	tw.tween_property(title, "modulate:a", 0.7, 0.04).set_delay(0.1)
	tw.tween_property(title, "modulate:a", 1.0, 0.08)
	col.add_child(UiKit.label("Saint Halvard Akıl Hastanesi  ·  1987", 22, "title", Color(0.6, 0.58, 0.54)))
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 50)
	col.add_child(spacer)

	_menu = VBoxContainer.new()
	_menu.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_menu.add_theme_constant_override("separation", 10)
	col.add_child(_menu)
	_menu.add_child(UiKit.button("Yeni Oyun", _start))
	_menu.add_child(UiKit.button("Ayarlar", func() -> void:
		_menu.hide()
		_controls.hide()
		_settings.show()))
	_menu.add_child(UiKit.button("Nasıl Oynanır", func() -> void: _controls.visible = not _controls.visible))
	_menu.add_child(UiKit.button("Çıkış", func() -> void: get_tree().quit()))

	_settings = SettingsPanel.new()
	_settings.hide()
	_settings.closed.connect(func() -> void: _menu.show())
	col.add_child(_settings)

	_controls = PanelContainer.new()
	_controls.hide()
	_controls.custom_minimum_size = Vector2(560, 0)
	var cv := VBoxContainer.new()
	cv.add_theme_constant_override("separation", 6)
	_controls.add_child(cv)
	cv.add_child(UiKit.label("NASIL OYNANIR", 24, "title", Color(0.85, 0.15, 0.1)))
	var help := UiKit.label("menu.help", 16)
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	cv.add_child(help)
	col.add_child(_controls)

	var credit := UiKit.label("Texture ve modeller: Poly Haven (CC0)  ·  Sesler prosedürel üretildi", 13, "ui", Color(0.4, 0.4, 0.4))
	credit.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	credit.position = Vector2(-560, -40)
	root.add_child(credit)

	_fade = ColorRect.new()
	_fade.color = Color.BLACK
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_fade)
	create_tween().tween_property(_fade, "color:a", 0.0, 2.0)


func _start() -> void:
	_fade.mouse_filter = Control.MOUSE_FILTER_STOP
	Sfx.play("sting", -8.0)
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", 1.0, 1.2)
	tw.tween_callback(Game.start_game)

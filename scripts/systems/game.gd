extends Node
## Global oyun durumu, ayarlar, envanter ve olay yolu (autoload: Game).

signal noise_made(pos: Vector3, radius: float)
signal inventory_changed
signal objective_changed(text: String)
signal message(text: String, duration: float)
signal settings_changed

const SETTINGS_PATH := "user://settings.cfg"
const GAME_SCENE := "res://scenes/game.tscn"
const MENU_SCENE := "res://scenes/main_menu.tscn"
const FUSES_NEEDED := 5
const NOTES_TOTAL := 8

var sensitivity := 0.3
var master_volume := 0.8
var brightness := 1.0
var fullscreen := true
var language := "tr" if OS.get_locale_language() == "tr" else "en"
var touch_opacity := 0.55

## Telefon/tablet: düşük maliyetli görüntü profili, büyük arayüz. Masaüstünde --mobile ile denenir.
var mobile := OS.has_feature("mobile")
## Ekran dokunmatik kontrolleri. Masaüstünde --touch (veya --mobile) ile denenir.
var touch := mobile

var level: Node = null
var player: Node = null
var hud: Node = null

var keys: Dictionary = {}
var fuses := 0
var power_on := false
var notes_read: Array[String] = []
var objective := ""
var game_over := false
var run_start_ms := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	I18n.setup()
	for a in OS.get_cmdline_user_args():
		if a == "--mobile":
			mobile = true
			touch = true
		elif a == "--touch":
			touch = true
	_setup_input()
	load_settings()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--lang="):
			language = a.substr(7)
		elif a == "--windowed":
			fullscreen = false
	if mobile:
		_setup_mobile()
	apply_settings()


func _setup_mobile() -> void:
	# telefonda 900 piksellik tasarım çok küçük kalır: arayüzü 640 yüksekliğe göre ölçekle
	get_tree().root.content_scale_size = Vector2i(1138, 640)
	# 3D sahneyi daha düşük çözünürlükte çiz (Mobile renderer'da FSR yok, bilinear büyütülür)
	var vp := get_tree().root
	vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
	vp.scaling_3d_scale = 0.75
	vp.msaa_3d = Viewport.MSAA_DISABLED
	vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA
	vp.positional_shadow_atlas_size = 2048
	RenderingServer.directional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_SOFT_LOW)
	RenderingServer.positional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_SOFT_LOW)
	DisplayServer.screen_set_keep_on(true)


## Mobil profilde ortam efektlerini Mobile renderer'ın desteklediklerine indirger.
## Hacimli sisin yerini, ayrıntıyı uzakta yutan düz derinlik sisi alır.
func adapt_environment(env: Environment, fog_density: float) -> void:
	if not mobile:
		return
	env.volumetric_fog_enabled = false
	env.ssil_enabled = false
	env.ssao_enabled = false
	env.sdfgi_enabled = false
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_EXPONENTIAL
	env.fog_light_color = Color(0.035, 0.04, 0.05)
	env.fog_density = fog_density
	env.fog_sky_affect = 0.0


func _setup_input() -> void:
	var keymap := {
		"move_forward": [KEY_W, KEY_UP],
		"move_back": [KEY_S, KEY_DOWN],
		"move_left": [KEY_A, KEY_LEFT],
		"move_right": [KEY_D, KEY_RIGHT],
		"sprint": [KEY_SHIFT],
		"crouch": [KEY_CTRL, KEY_C],
		"interact": [KEY_E],
		"flashlight": [KEY_F],
		"hold_breath": [KEY_SPACE],
		"pause": [KEY_ESCAPE, KEY_P],
		"toggle_fullscreen": [KEY_F11],
	}
	for action in keymap:
		if InputMap.has_action(action):
			InputMap.action_erase_events(action)
		else:
			InputMap.add_action(action)
		for k in keymap[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = k
			InputMap.action_add_event(action, ev)
	# dokunmatikte her dokunuş sahte bir sol tık da üretir; o yüzden fare tuşları bağlanmaz
	if not touch:
		_add_mouse("interact", MOUSE_BUTTON_LEFT)
		_add_mouse("hold_breath", MOUSE_BUTTON_RIGHT)


func _add_mouse(action: String, button: MouseButton) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = button
	InputMap.action_add_event(action, ev)


# ---------------------------------------------------------------- akış

func new_run() -> void:
	keys.clear()
	fuses = 0
	power_on = false
	notes_read.clear()
	objective = ""
	game_over = false
	run_start_ms = Time.get_ticks_msec()


func start_game() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(GAME_SCENE)


func go_menu() -> void:
	get_tree().paused = false
	level = null
	player = null
	hud = null
	get_tree().change_scene_to_file(MENU_SCENE)


func elapsed_text() -> String:
	var s := (Time.get_ticks_msec() - run_start_ms) / 1000
	return "%02d:%02d" % [s / 60, s % 60]


# ---------------------------------------------------------------- envanter

func add_key(id: String, display: String) -> void:
	keys[id] = display
	inventory_changed.emit()


func has_key(id: String) -> bool:
	return keys.has(id)


func add_fuse() -> void:
	fuses += 1
	inventory_changed.emit()


func read_note(id: String) -> void:
	if not notes_read.has(id):
		notes_read.append(id)


func set_objective(text: String) -> void:
	objective = text
	objective_changed.emit(text)


func show_message(text: String, duration := 3.5) -> void:
	message.emit(text, duration)


func make_noise(pos: Vector3, radius: float) -> void:
	noise_made.emit(pos, radius)


# ---------------------------------------------------------------- ayarlar

func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) != OK:
		return
	sensitivity = cfg.get_value("game", "sensitivity", sensitivity)
	master_volume = cfg.get_value("game", "master_volume", master_volume)
	brightness = cfg.get_value("game", "brightness", brightness)
	fullscreen = cfg.get_value("game", "fullscreen", fullscreen)
	language = cfg.get_value("game", "language", language)
	touch_opacity = cfg.get_value("game", "touch_opacity", touch_opacity)


func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("game", "touch_opacity", touch_opacity)
	cfg.set_value("game", "language", language)
	cfg.set_value("game", "sensitivity", sensitivity)
	cfg.set_value("game", "master_volume", master_volume)
	cfg.set_value("game", "brightness", brightness)
	cfg.set_value("game", "fullscreen", fullscreen)
	cfg.save(SETTINGS_PATH)


func apply_settings() -> void:
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(master_volume, 0.0001)))
	TranslationServer.set_locale(language)
	get_window().title = "Sessiz Koğuş" if language == "tr" else "Silent Ward"
	if OS.has_feature("mobile"):
		settings_changed.emit()
		return
	var cur := DisplayServer.window_get_mode()
	var is_full := cur == DisplayServer.WINDOW_MODE_FULLSCREEN or cur == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN
	if fullscreen and not is_full:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	elif not fullscreen and is_full:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	settings_changed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_fullscreen"):
		fullscreen = not fullscreen
		apply_settings()
		save_settings()
		get_viewport().set_input_as_handled()

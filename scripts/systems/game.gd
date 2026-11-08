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
	_setup_input()
	load_settings()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--lang="):
			language = a.substr(7)
		elif a == "--windowed":
			fullscreen = false
	apply_settings()


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


func save_settings() -> void:
	var cfg := ConfigFile.new()
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

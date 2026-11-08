class_name TouchControls
extends Control
## Dokunmatik ekran kontrolleri: ekranın sol tarafında serbest joystick (sonuna kadar
## itince koşar), sağ tarafında parmak kaydırarak bakış, sağ altta eylem butonları.
## Butonlar oyunun normal girdi eylemlerini tetikler; oyuncu kodu klavyeyle aynı yolu kullanır.

const STICK_R := 78.0
const STICK_ZONE := 0.42  # ekran genişliğinin joystick'e ayrılan sol kısmı
const SPRINT_AT := 0.93

var _stick_id := -1
var _stick_origin := Vector2.ZERO
var _stick_pos := Vector2.ZERO
var _look_id := -1
var _crouch_on := false
var _font: Font

## id, merkez ofseti (sağ alt köşeden; pause için üst ortadan), yarıçap, etiket
var _buttons: Array[Dictionary] = [
	{"id": "interact", "off": Vector2(-118, -150), "r": 60.0, "label": "ETKİLEŞ", "touch": -1},
	{"id": "flashlight", "off": Vector2(-262, -96), "r": 44.0, "label": "FENER", "touch": -1},
	{"id": "crouch", "off": Vector2(-96, -300), "r": 44.0, "label": "EĞİL", "touch": -1},
	{"id": "breath", "off": Vector2(-280, -236), "r": 58.0, "label": "NEFES", "touch": -1},
	{"id": "pause", "off": Vector2(0, 44), "r": 30.0, "label": "II", "touch": -1},
]


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_font = UiKit.font("title")
	Input.action_release("crouch")


func _exit_tree() -> void:
	_release_all()
	Input.action_release("crouch")


func _process(_delta: float) -> void:
	var on := _active()
	if visible != on:
		visible = on
		if not on:
			_release_all()
	if on:
		queue_redraw()


func _active() -> bool:
	var p := Game.player as Player
	if p == null or p.dead or Game.game_over or get_tree().paused:
		return false
	return Game.hud == null or not Game.hud.is_overlay_open()


# ---------------------------------------------------------------- girdi

func _input(event: InputEvent) -> void:
	var p := Game.player as Player
	if p == null:
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			# not okunurken ekrana dokunmak notu kapatır
			if p.reading:
				if Game.hud:
					Game.hud.close_note()
				get_viewport().set_input_as_handled()
				return
			if visible:
				_on_press(event.index, event.position)
		else:
			_on_release(event.index)
	elif event is InputEventScreenDrag and visible:
		_on_drag(event.index, event.position, event.relative)


func _on_press(id: int, pos: Vector2) -> void:
	for b in _buttons:
		if _button_shown(b) and pos.distance_to(_button_pos(b)) <= b.r * 1.3:
			_press_button(b, id)
			get_viewport().set_input_as_handled()
			return
	if pos.x < size.x * STICK_ZONE and _stick_id == -1:
		_stick_id = id
		_stick_origin = pos
		_stick_pos = pos
	elif _look_id == -1:
		_look_id = id
	get_viewport().set_input_as_handled()


func _on_drag(id: int, pos: Vector2, rel: Vector2) -> void:
	if id == _stick_id:
		var d := pos - _stick_origin
		if d.length() > STICK_R:
			# parmak halkanın dışına çıkınca joystick onu takip eder
			_stick_origin = pos - d.normalized() * STICK_R
			d = pos - _stick_origin
		_stick_pos = pos
		_apply_stick(d / STICK_R)
	elif id == _look_id:
		var p := Game.player as Player
		if p and not p.reading:
			p.look(rel, Game.sensitivity * 0.009)
	get_viewport().set_input_as_handled()


func _on_release(id: int) -> void:
	if id == _stick_id:
		_stick_id = -1
		_apply_stick(Vector2.ZERO)
	if id == _look_id:
		_look_id = -1
	for b in _buttons:
		if b.touch == id:
			b.touch = -1
			if b.id == "breath":
				Input.action_release("hold_breath")


func _apply_stick(v: Vector2) -> void:
	_set_axis("move_right", v.x)
	_set_axis("move_left", -v.x)
	_set_axis("move_back", v.y)
	_set_axis("move_forward", -v.y)
	if v.length() >= SPRINT_AT and v.y < -0.5:
		Input.action_press("sprint")
	else:
		Input.action_release("sprint")


func _set_axis(action: String, value: float) -> void:
	if value > 0.05:
		Input.action_press(action, minf(value, 1.0))
	else:
		Input.action_release(action)


func _press_button(b: Dictionary, id: int) -> void:
	b.touch = id
	match b.id:
		"interact":
			_send_action("interact")
		"flashlight":
			_send_action("flashlight")
		"pause":
			_send_action("pause")
		"crouch":
			_crouch_on = not _crouch_on
			if _crouch_on:
				Input.action_press("crouch")
			else:
				Input.action_release("crouch")
		"breath":
			Input.action_press("hold_breath")


## Oyuncu ve HUD bu eylemleri olay olarak dinler; tek seferlik bir basma olayı gönder.
func _send_action(action: String) -> void:
	for pressed in [true, false]:
		var ev := InputEventAction.new()
		ev.action = action
		ev.pressed = pressed
		Input.parse_input_event(ev)


func _release_all() -> void:
	_stick_id = -1
	_look_id = -1
	_apply_stick(Vector2.ZERO)
	Input.action_release("hold_breath")
	for b in _buttons:
		b.touch = -1


# ---------------------------------------------------------------- çizim

func _button_shown(b: Dictionary) -> bool:
	var p := Game.player as Player
	var hidden := p != null and p.hidden_in != null
	match b.id:
		"breath":
			return hidden
		"flashlight", "crouch":
			return not hidden
	return true


func _button_pos(b: Dictionary) -> Vector2:
	if b.id == "pause":
		return Vector2(size.x * 0.5, b.off.y)
	return size + b.off


func _draw() -> void:
	var op := Game.touch_opacity
	var ink := Color(0.86, 0.82, 0.76, op)
	var shade := Color(0.0, 0.0, 0.0, 0.35 * op)

	# joystick: dokunulmuyorsa varsayılan yerinde soluk bir ipucu
	var base := _stick_origin if _stick_id != -1 else Vector2(size.x * 0.13, size.y - 190.0)
	var knob := _stick_pos if _stick_id != -1 else base
	var idle_mul := 1.0 if _stick_id != -1 else 0.5
	draw_circle(base, STICK_R, Color(shade, shade.a * idle_mul))
	draw_arc(base, STICK_R, 0.0, TAU, 48, Color(ink, ink.a * 0.6 * idle_mul), 2.0, true)
	draw_circle(knob, 30.0, Color(ink, ink.a * 0.45 * idle_mul))
	var sprinting := Input.is_action_pressed("sprint")
	if sprinting:
		draw_arc(base, STICK_R + 6.0, -PI * 0.75, -PI * 0.25, 16, Color(0.85, 0.2, 0.15, op), 4.0, true)

	var p := Game.player as Player
	for b in _buttons:
		if not _button_shown(b):
			continue
		var c := _button_pos(b)
		var r: float = b.r
		var lit: bool = b.touch != -1
		var ring := ink
		if b.id == "interact":
			var has_target: bool = Game.hud != null and Game.hud.has_prompt()
			ring = Color(0.9, 0.2, 0.14, op + 0.25) if has_target else Color(ink, ink.a * 0.45)
		elif b.id == "flashlight" and p and p.flashlight_on:
			ring = Color(1.0, 0.85, 0.5, op + 0.2)
		elif b.id == "crouch" and _crouch_on:
			ring = Color(0.55, 0.75, 0.95, op + 0.2)
		elif b.id == "breath" and p and p.holding_breath:
			ring = Color(0.55, 0.75, 0.95, op + 0.25)
		draw_circle(c, r, Color(shade, shade.a * (2.0 if lit else 1.0)))
		draw_arc(c, r, 0.0, TAU, 48, ring, 3.0, true)
		var text := tr(b.label)
		var fs := 15 if r < 50.0 else 17
		var w := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_string(_font, c + Vector2(-w * 0.5, fs * 0.35), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(ring, minf(1.0, ring.a + 0.2)))

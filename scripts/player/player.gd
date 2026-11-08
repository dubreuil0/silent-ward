class_name Player
extends CharacterBody3D
## Birinci şahıs oyuncu: hareket, fener, stamina, etkileşim, dolapta saklanma.

const WALK := 2.5
const RUN := 4.9
const CROUCH := 1.3
const STAND_EYE := 1.62
const CROUCH_EYE := 0.98
const GRAVITY := 18.0

var head: Node3D
var camera: Camera3D
var flash: SpotLight3D
var ray: RayCast3D

var stamina := 100.0
var exhausted := false
var battery := 100.0
var flashlight_on := false
var crouching := false
var sprinting := false
var hidden_in: Locker = null
var breath := 100.0
var holding_breath := false
var exposure := 0.0
var dead := false
var frozen := false
var reading := false
var fear := 0.0
var adrenaline := 0.0

var _flash_pivot: Node3D
var _fill: OmniLight3D
var _night: OmniLight3D
var _bob_t := 0.0
var _bob_amp := 0.0
var _step_acc := 0.0
var _shake := 0.0
var _stamina_delay := 0.0
var _breath_lock := false
var _flicker_t := 0.0
var _flicker_mul := 1.0
var _locker_yaw := 0.0
var _death_look := Vector3.ZERO
var _death_t := 0.0
var _heart: AudioStreamPlayer
var _pant: AudioStreamPlayer


func _ready() -> void:
	Game.player = self
	collision_layer = 2
	collision_mask = 1 | 16
	floor_snap_length = 0.3

	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.3
	cap.height = 1.75
	cs.shape = cap
	cs.position = Vector3(0, 0.875, 0)
	add_child(cs)

	head = Node3D.new()
	head.position = Vector3(0, STAND_EYE, 0)
	add_child(head)
	camera = Camera3D.new()
	camera.fov = 72.0
	camera.near = 0.04
	camera.far = 120.0
	camera.current = true
	head.add_child(camera)

	ray = RayCast3D.new()
	ray.target_position = Vector3(0, 0, -2.3)
	ray.collision_mask = 1 | 8 | 16
	ray.add_exception(self)
	camera.add_child(ray)

	_flash_pivot = Node3D.new()
	_flash_pivot.top_level = true
	add_child(_flash_pivot)
	flash = SpotLight3D.new()
	flash.spot_range = 26.0
	flash.spot_angle = 31.0
	flash.spot_angle_attenuation = 1.0
	flash.spot_attenuation = 0.85
	flash.light_energy = 0.0
	flash.light_color = Color(1.0, 0.94, 0.82)
	flash.shadow_enabled = true
	flash.shadow_bias = 0.04
	flash.shadow_blur = 1.5
	flash.light_volumetric_fog_energy = 0.7
	flash.light_projector = _make_projector()
	flash.light_specular = 0.6
	_flash_pivot.add_child(flash)
	# feneri açıkken çevreye yansıyan zayıf dolgu ışığı
	_fill = OmniLight3D.new()
	_fill.omni_range = 3.5
	_fill.light_energy = 0.0
	_fill.light_color = Color(1.0, 0.92, 0.8)
	_fill.light_volumetric_fog_energy = 0.0
	_fill.position = Vector3(0, 0, -0.4)
	_flash_pivot.add_child(_fill)
	# feneri kapalıyken siluetleri seçebilmek için çok hafif "göz uyumu" ışığı
	_night = OmniLight3D.new()
	_night.omni_range = 7.0
	_night.light_energy = 0.12
	_night.light_color = Color(0.55, 0.65, 0.9)
	_night.light_volumetric_fog_energy = 0.0
	_night.light_specular = 0.0
	head.add_child(_night)

	_heart = _loop_player("heartbeat")
	_pant = _loop_player("breath")
	_snap_flash_pivot()


func _loop_player(sound: String) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.stream = Sfx.stream(sound)
	p.bus = "SFX"
	p.volume_db = -80.0
	add_child(p)
	p.play()
	return p


func _make_projector() -> Texture2D:
	var n := 128
	var img := Image.create(n, n, false, Image.FORMAT_RGB8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for y in n:
		for x in n:
			var p := Vector2(x - n * 0.5, y - n * 0.5) / (n * 0.5)
			var r := p.length()
			var v := clampf(1.0 - r, 0.0, 1.0)
			v = pow(v, 0.5) * 0.8
			v += exp(-pow((r - 0.7) / 0.08, 2.0)) * 0.12
			v += exp(-pow(r / 0.3, 2.0)) * 0.3
			v *= 0.97 + rng.randf() * 0.03
			img.set_pixel(x, y, Color(v, v * 0.97, v * 0.9))
	return ImageTexture.create_from_image(img)


# ---------------------------------------------------------------- girdi

func _unhandled_input(event: InputEvent) -> void:
	if dead or frozen:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and not reading:
		var s := Game.sensitivity * 0.006
		var rel: Vector2 = event.relative
		if hidden_in:
			_locker_yaw = clampf(_locker_yaw - rel.x * s, -0.7, 0.7)
			head.rotation.y = _locker_yaw
		else:
			rotate_y(-rel.x * s)
		head.rotation.x = clampf(head.rotation.x - rel.y * s, -1.45, 1.45)
	elif event.is_action_pressed("flashlight") and not reading:
		set_flashlight(not flashlight_on)
	elif event.is_action_pressed("interact"):
		if reading:
			if Game.hud:
				Game.hud.close_note()
		else:
			_interact()


func set_flashlight(on: bool) -> void:
	if on and battery <= 0.0:
		Sfx.play("flash_click", -6.0, 0.8)
		Game.show_message(tr("Pil bitti."), 2.0)
		return
	if hidden_in and on:
		return
	flashlight_on = on
	Sfx.play("flash_click", -6.0, randf_range(0.95, 1.05))


func add_battery(amount: float) -> void:
	battery = minf(100.0, battery + amount)


func add_shake(amount: float) -> void:
	_shake = maxf(_shake, amount)


func eye_position() -> Vector3:
	return camera.global_position


func look_dir() -> Vector3:
	return -camera.global_transform.basis.z


# ---------------------------------------------------------------- döngü

func _physics_process(delta: float) -> void:
	_update_flashlight(delta)
	_update_fear(delta)
	_update_camera_fx(delta)
	if dead:
		_update_death(delta)
		return
	if hidden_in:
		_update_hidden(delta)
		_update_prompt()
		return

	var input := Vector2.ZERO
	if not reading and not frozen:
		input = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
		crouching = Input.is_action_pressed("crouch")
	var moving := input.length() > 0.1
	var want_sprint := Input.is_action_pressed("sprint") and input.y < -0.1 and not crouching and not reading and not frozen
	adrenaline = maxf(0.0, adrenaline - delta)
	sprinting = want_sprint and not exhausted and stamina > 0.0

	if sprinting and moving:
		if adrenaline <= 0.0:
			stamina -= 17.0 * delta
		_stamina_delay = 1.0
		if stamina <= 0.0:
			stamina = 0.0
			exhausted = true
			sprinting = false
			Sfx.play("gasp", -4.0)
	else:
		_stamina_delay -= delta
		if _stamina_delay <= 0.0:
			stamina = minf(100.0, stamina + (9.0 if exhausted else 15.0) * delta)
		if exhausted and stamina > 35.0:
			exhausted = false

	var speed := WALK
	if crouching:
		speed = CROUCH
	elif sprinting:
		speed = RUN
	if exhausted:
		speed *= 0.82
	var dir := global_transform.basis * Vector3(input.x, 0, input.y)
	dir.y = 0.0
	dir = dir.normalized() * minf(input.length(), 1.0)
	var k := 1.0 - exp(-(10.0 if moving else 12.0) * delta)
	velocity.x = lerpf(velocity.x, dir.x * speed, k)
	velocity.z = lerpf(velocity.z, dir.z * speed, k)
	if is_on_floor():
		velocity.y = -0.5
	else:
		velocity.y -= GRAVITY * delta
	move_and_slide()

	var eye := CROUCH_EYE if crouching else STAND_EYE
	head.position.y = lerpf(head.position.y, eye, 1.0 - exp(-10.0 * delta))
	_bob_and_steps(delta)
	_update_prompt()

	var pant_target := 0.0
	if exhausted:
		pant_target = 0.9
	elif stamina < 60.0:
		pant_target = (60.0 - stamina) / 60.0 * 0.6
	_pant.volume_db = lerpf(_pant.volume_db, linear_to_db(maxf(pant_target, 0.0001)) - 4.0, delta * 3.0)


func _bob_and_steps(delta: float) -> void:
	var hs := Vector2(velocity.x, velocity.z).length()
	var stride := 0.75 if crouching else (1.4 if sprinting else 1.0)
	var target_amp := 0.0
	if is_on_floor() and hs > 0.3:
		target_amp = 0.022 if crouching else (0.06 if sprinting else 0.035)
		_bob_t += hs * delta / stride * PI
		_step_acc += hs * delta
		if _step_acc >= stride:
			_step_acc = 0.0
			_footstep()
	_bob_amp = lerpf(_bob_amp, target_amp, 1.0 - exp(-8.0 * delta))
	camera.position = Vector3(cos(_bob_t) * _bob_amp * 0.5, absf(sin(_bob_t)) * _bob_amp - _bob_amp * 0.5, 0)


func _footstep() -> void:
	var surface := "tile"
	if Game.level:
		surface = Game.level.surface_at(global_position)
	var vol := -16.0 if crouching else (-3.0 if sprinting else -8.0)
	Sfx.play("step_%s_%d" % [surface, randi() % 3], vol, randf_range(0.9, 1.1))
	if sprinting:
		Game.make_noise(global_position, 14.0)
	elif not crouching:
		Game.make_noise(global_position, 4.5)


func _update_camera_fx(delta: float) -> void:
	_shake = maxf(0.0, _shake - delta * 1.5)
	camera.h_offset = randf_range(-1.0, 1.0) * _shake * 0.15
	camera.v_offset = randf_range(-1.0, 1.0) * _shake * 0.15


func _snap_flash_pivot() -> void:
	_flash_pivot.global_transform = camera.global_transform


func _update_flashlight(delta: float) -> void:
	# fener kameranın biraz gerisinden gelir: elde tutulan ağırlık hissi
	var cam_t := camera.global_transform
	var b := _flash_pivot.global_transform.basis.orthonormalized().slerp(cam_t.basis.orthonormalized(), 1.0 - exp(-16.0 * delta))
	_flash_pivot.global_transform = Transform3D(b, cam_t.origin + cam_t.basis * Vector3(0.16, -0.16, -0.05))

	var energy := 0.0
	if flashlight_on and not hidden_in:
		battery = maxf(0.0, battery - 0.3 * delta)
		if battery <= 0.0:
			flashlight_on = false
			Sfx.play("flash_click", -6.0, 0.8)
			Game.show_message(tr("Fenerin pili bitti. Pil bul."), 3.0)
		energy = 7.0
		if battery < 25.0:
			_flicker_t -= delta
			if _flicker_t <= 0.0:
				_flicker_t = randf_range(0.04, 0.5) if randf() < 0.3 else randf_range(0.5, 2.5)
				_flicker_mul = randf_range(0.0, 0.5) if _flicker_t < 0.5 else 1.0
			energy *= lerpf(0.45, 1.0, battery / 25.0) * _flicker_mul
	flash.light_energy = lerpf(flash.light_energy, energy, 1.0 - exp(-30.0 * delta))
	flash.visible = flash.light_energy > 0.01
	_fill.light_energy = flash.light_energy * 0.035


func _update_fear(delta: float) -> void:
	var target := 0.0
	var enemy: Nurse = Game.level.enemy if Game.level else null
	if enemy and enemy.is_active():
		var d := global_position.distance_to(enemy.global_position)
		target = clampf(1.0 - (d - 2.0) / 14.0, 0.0, 1.0) * 0.65
		if enemy.is_hunting():
			target = maxf(target, 0.5) + 0.25 * clampf(1.0 - d / 12.0, 0.0, 1.0)
	if hidden_in and enemy and enemy.global_position.distance_to(global_position) < 5.0:
		target = maxf(target, 0.8)
	if dead:
		target = 1.0
	fear = lerpf(fear, clampf(target, 0.0, 1.0), 1.0 - exp(-2.0 * delta))
	_heart.volume_db = linear_to_db(maxf(fear * 1.1, 0.0001)) - 2.0
	_heart.pitch_scale = 0.9 + fear * 0.75
	if Game.hud:
		Game.hud.set_fear(fear)


# ---------------------------------------------------------------- etkileşim

func _get_target() -> Object:
	if hidden_in:
		return hidden_in
	if not ray.is_colliding():
		return null
	var c: Object = ray.get_collider()
	if c and c.has_meta("interact_owner"):
		c = c.get_meta("interact_owner")
	if c and c.has_method("interact"):
		return c
	return null


func _update_prompt() -> void:
	if not Game.hud:
		return
	var t: Object = null
	if not (reading or frozen or dead):
		t = _get_target()
	Game.hud.set_prompt(t.call("get_prompt") if t else "")


func _interact() -> void:
	if frozen:
		return
	var t := _get_target()
	if t:
		t.call("interact", self)


# ---------------------------------------------------------------- saklanma

func enter_locker(l: Locker) -> void:
	if hidden_in or dead:
		return
	hidden_in = l
	velocity = Vector3.ZERO
	l.swing(true, crouching)
	var t := l.hide_transform()
	var tw := create_tween()
	tw.tween_property(self, "global_position", t.origin, 0.3)
	rotation.y = l.global_rotation.y + PI
	head.rotation = Vector3.ZERO
	_locker_yaw = 0.0
	camera.cull_mask &= ~Locker.DOOR_LAYER
	if flashlight_on:
		flashlight_on = false
		Sfx.play("flash_click", -6.0)
	breath = 100.0
	exposure = 0.0
	Game.make_noise(global_position, 3.0 if crouching else 5.0)
	if Game.hud:
		Game.hud.set_locker_view(true)
	if Game.level and Game.level.enemy:
		Game.level.enemy.on_player_hid(l)


func exit_locker() -> void:
	if not hidden_in:
		return
	var l := hidden_in
	l.swing(true)
	hidden_in = null
	global_position = l.exit_position()
	head.rotation.y = 0.0
	camera.cull_mask |= Locker.DOOR_LAYER
	holding_breath = false
	if Game.hud:
		Game.hud.set_locker_view(false)


func _update_hidden(delta: float) -> void:
	velocity = Vector3.ZERO
	var want := Input.is_action_pressed("hold_breath") and not _breath_lock
	holding_breath = want and breath > 0.0
	if holding_breath:
		breath -= 15.0 * delta
		if breath <= 0.0:
			breath = 0.0
			_breath_lock = true
			holding_breath = false
			Sfx.play("gasp", 0.0)
			Game.make_noise(global_position, 7.0)
			exposure += 0.6
	else:
		breath = minf(100.0, breath + 18.0 * delta)
		if _breath_lock and breath > 40.0:
			_breath_lock = false

	var enemy: Nurse = Game.level.enemy if Game.level else null
	var near := false
	if enemy and enemy.is_active() and enemy.state != Nurse.State.KILL:
		var d := enemy.global_position.distance_to(global_position)
		near = d < 3.6
		if near and not holding_breath:
			exposure += delta * (1.1 if d < 2.2 else 0.55)
		else:
			exposure = maxf(0.0, exposure - delta * 0.5)
		if exposure >= 1.0:
			exposure = 0.0
			enemy.found_hidden(hidden_in)
	if Game.hud:
		Game.hud.set_breath(breath / 100.0, holding_breath, near)
	_pant.volume_db = -80.0 if holding_breath else lerpf(_pant.volume_db, -20.0, delta)


# ---------------------------------------------------------------- ölüm

func die(enemy: Node3D) -> void:
	if dead:
		return
	dead = true
	velocity = Vector3.ZERO
	_death_look = enemy.global_position + Vector3.UP * 2.0
	_death_t = 0.0
	_shake = 1.0
	Sfx.play("scream", 0.0, randf_range(0.95, 1.05))
	Sfx.play("sting", -4.0)
	if Game.hud:
		Game.hud.set_prompt("")
		Game.hud.death_flash()
	get_tree().create_timer(2.4).timeout.connect(func() -> void:
		if Game.level:
			Game.level.on_player_dead())


func _update_death(delta: float) -> void:
	_death_t += delta
	_shake = maxf(_shake, 0.35)
	var ct := camera.global_transform
	if ct.origin.distance_to(_death_look) > 0.05:
		var want := ct.looking_at(_death_look, Vector3.UP)
		camera.global_transform = Transform3D(ct.basis.orthonormalized().slerp(want.basis.orthonormalized(), 1.0 - exp(-14.0 * delta)), ct.origin)
	if _death_t > 1.3:
		head.position.y = lerpf(head.position.y, 0.4, delta * 3.0)

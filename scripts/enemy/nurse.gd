class_name Nurse
extends CharacterBody3D
## Hemşire yapay zekâsı: ızgara üzerinde A* ile hareket eder; ışık ve sese tepki verir.

enum State { DORMANT, PATROL, INVESTIGATE, CHASE, SEARCH, CHECK_LOCKER, KILL, FINAL }

const EYE_H := 1.95
const KILL_DIST := 1.25

var state := State.DORMANT
var body: NurseBody

var _path := PackedVector3Array()
var _path_i := 0
var _goal := Vector3.ZERO
var _last_known := Vector3.ZERO
var _search_center := Vector3.ZERO
var _state_t := 0.0
var _wait_t := 0.0
var _lost_t := 0.0
var _repath_t := 0.0
var _sight_t := 0.0
var _suspicion := 0.0
var _last_seen_ms := -100000
var _can_see := false
var _step_acc := 0.0
var _stuck_t := 0.0
var _stuck_pos := Vector3.ZERO
var _door_pause := 0.0
var _locker: Locker
var _speed := 0.0
var _breath: AudioStreamPlayer3D
var _music: AudioStreamPlayer
var _music_vol := 0.0
var _shape: CollisionShape3D


func _ready() -> void:
	collision_layer = 4
	collision_mask = 1
	_shape = CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.3
	cap.height = 2.0
	_shape.shape = cap
	_shape.position = Vector3(0, 1.0, 0)
	add_child(_shape)

	body = NurseBody.new()
	add_child(body)

	_breath = Sfx.attach_loop("nurse_breath", self, 0.0, 2.5, 20.0, false)
	_breath.position = Vector3(0, 1.9, 0)

	_music = AudioStreamPlayer.new()
	_music.stream = Sfx.stream("chase_music")
	_music.bus = "Music"
	_music.volume_db = -80.0
	add_child(_music)

	Game.noise_made.connect(_on_noise)
	_set_active(false)


func _set_active(on: bool) -> void:
	visible = on
	_shape.disabled = not on
	set_physics_process(on)
	if on:
		_breath.play()
	else:
		_breath.stop()


func activate(pos: Vector3) -> void:
	global_position = pos
	_set_active(true)
	_enter(State.PATROL)
	_music.play()


func is_active() -> bool:
	return state != State.DORMANT


func is_hunting() -> bool:
	return state == State.CHASE or state == State.FINAL or state == State.CHECK_LOCKER


func final_hunt(spawn: Vector3) -> void:
	global_position = spawn
	_set_active(true)
	if not _music.playing:
		_music.play()
	Sfx.play_at("nurse_alert", global_position + Vector3.UP * 2.0, 6.0, 0.9, 60.0)
	_enter(State.FINAL)


# ---------------------------------------------------------------- ana döngü

func _physics_process(delta: float) -> void:
	var player := Game.player as Player
	if player == null or state == State.KILL:
		return
	_state_t += delta
	_update_sight(delta, player)

	var spd := 0.0
	match state:
		State.PATROL:
			spd = 1.3
			if _path_done():
				_wait_t -= delta
				if _wait_t <= 0.0:
					_pick_patrol(player)
		State.INVESTIGATE:
			spd = 2.3
			if _path_done():
				_wait_t -= delta
				_look_around(delta)
				if _wait_t <= 0.0:
					_search_center = global_position
					_enter(State.SEARCH)
		State.SEARCH:
			spd = 1.7
			if _path_done():
				_wait_t -= delta
				_look_around(delta)
				if _wait_t <= 0.0:
					_go_to(_random_point_near(_search_center, 4))
					_wait_t = randf_range(1.0, 2.5)
			if _state_t > 16.0:
				_enter(State.PATROL)
		State.CHASE:
			spd = 3.5 + 0.1 * Game.fuses
			_chase(delta, player, false)
		State.FINAL:
			spd = 3.85
			_chase(delta, player, true)
		State.CHECK_LOCKER:
			spd = 3.0
			if player.hidden_in != _locker:
				_enter(State.FINAL if Game.power_on else State.CHASE)
				return
			var ld := global_position.distance_to(_locker.exit_position()) if _locker else 99.0
			if _path_done() and ld > 2.6:
				_go_to(_locker.exit_position())
			if ld < 0.9 or (_path_done() and ld < 2.6):
				_face(_locker.global_position, 5.0)
				_locker.rip_open()
				_kill(player)
				return
		State.KILL:
			spd = 0.0

	if _door_pause > 0.0:
		_door_pause -= delta
		spd *= 0.25
	_follow_path(delta, spd)
	_open_doors()
	_check_stuck(delta)

	var hs := Vector2(velocity.x, velocity.z).length()
	var pose := NurseBody.Pose.WALK
	if state == State.CHASE or state == State.FINAL:
		pose = NurseBody.Pose.CHASE
	elif state == State.KILL:
		pose = NurseBody.Pose.KILL
	elif hs < 0.1:
		pose = NurseBody.Pose.IDLE
	body.animate(delta, hs, pose)
	body.set_glitch(0.6 if is_hunting() else 0.0)
	_footsteps(delta, hs, player)
	_update_music(delta)


func _process(delta: float) -> void:
	if state == State.KILL:
		body.animate(delta, 0.0, NurseBody.Pose.KILL)
		body.set_glitch(1.0)


func _chase(delta: float, player: Player, omniscient: bool) -> void:
	if player.dead:
		return
	if player.hidden_in:
		if omniscient:
			_check_locker(player.hidden_in)
		else:
			_lost_t += delta
			if _path_done() or _lost_t > 4.0:
				_search_center = _last_known
				_enter(State.SEARCH)
		return
	if _can_see or omniscient:
		_last_known = player.global_position
		_lost_t = 0.0
	else:
		_lost_t += delta
	_repath_t -= delta
	if _repath_t <= 0.0:
		_repath_t = 0.3
		_go_to(_last_known)
	var d := global_position.distance_to(player.global_position)
	if d < KILL_DIST and (_can_see or omniscient or d < 0.9):
		_kill(player)
		return
	if not omniscient and _lost_t > 5.0:
		_search_center = _last_known
		_enter(State.SEARCH)


func _enter(s: State) -> void:
	state = s
	_state_t = 0.0
	_lost_t = 0.0
	match s:
		State.PATROL:
			_wait_t = 0.0
			_path = PackedVector3Array()
		State.INVESTIGATE:
			_wait_t = randf_range(2.5, 4.0)
		State.SEARCH:
			_wait_t = 0.5
			_path = PackedVector3Array()
		State.CHASE, State.FINAL:
			_repath_t = 0.0
			_last_known = Game.player.global_position


# ---------------------------------------------------------------- algılama

func _update_sight(delta: float, player: Player) -> void:
	_sight_t -= delta
	if _sight_t > 0.0:
		return
	var dt := 0.12 - _sight_t
	_sight_t = 0.12
	_can_see = false
	if player.dead or player.hidden_in or state == State.KILL:
		_suspicion = maxf(0.0, _suspicion - dt)
		return
	var eye := global_position + Vector3.UP * EYE_H
	var target := player.eye_position()
	var to := target - eye
	var dist := to.length()
	var hunting := is_hunting()

	var view_range := 12.0
	if player.flashlight_on:
		view_range += 8.0
	if player.crouching:
		view_range *= 0.6
	if player.sprinting:
		view_range += 3.0
	if hunting:
		view_range = 30.0

	var visible_now := false
	if dist < view_range:
		var fwd := -global_transform.basis.z
		var flat := Vector3(to.x, 0, to.z).normalized()
		var ang := rad_to_deg(acos(clampf(fwd.dot(flat), -1.0, 1.0)))
		var fov := 120.0 if hunting else 65.0
		# Işığa doğrudan tutulursa her açıdan fark eder.
		var lit := player.flashlight_on and dist < 18.0 and player.look_dir().dot(-to.normalized()) > 0.93
		if dist < 2.2 or ang < fov or lit:
			visible_now = _ray_clear(eye, target)
	if visible_now:
		_can_see = true
		_last_seen_ms = Time.get_ticks_msec()
		_last_known = player.global_position
		if not hunting and state != State.CHECK_LOCKER:
			var rate := 3.0 if dist < 5.0 else (1.1 if player.flashlight_on else 0.7)
			_suspicion += dt * rate
			if state == State.PATROL or state == State.SEARCH:
				_face(player.global_position, 1.0)
			if _suspicion >= 1.0:
				_start_chase()
	else:
		_suspicion = maxf(0.0, _suspicion - dt * 0.4)


func _ray_clear(from: Vector3, to: Vector3) -> bool:
	var q := PhysicsRayQueryParameters3D.create(from, to, 1 | 16, [get_rid()])
	return get_world_3d().direct_space_state.intersect_ray(q).is_empty()


func _start_chase() -> void:
	_suspicion = 0.0
	Sfx.play_at("nurse_alert", global_position + Vector3.UP * 2.0, 4.0, randf_range(0.9, 1.05), 50.0)
	Sfx.play("sting", -8.0)
	_enter(State.CHASE)
	if Game.level:
		Game.level.on_chase_started()


func _on_noise(pos: Vector3, radius: float) -> void:
	if state == State.DORMANT or state == State.KILL or state == State.CHECK_LOCKER:
		return
	if global_position.distance_to(pos) > radius:
		return
	if state == State.CHASE or state == State.FINAL:
		_last_known = pos
		return
	_enter(State.INVESTIGATE)
	_go_to(pos)


## Oyuncu dolaba girdiğinde çağrılır.
func on_player_hid(locker: Locker) -> void:
	if state == State.FINAL:
		_check_locker(locker)
		return
	var seen_recently := Time.get_ticks_msec() - _last_seen_ms < 900
	if state == State.CHASE and seen_recently and global_position.distance_to(locker.global_position) < 16.0:
		_check_locker(locker)


## Saklanan oyuncu nefes sesiyle kendini ele verdi.
func found_hidden(locker: Locker) -> void:
	if state != State.KILL and state != State.DORMANT:
		Sfx.play_at("nurse_alert", global_position + Vector3.UP * 2.0, 2.0, 1.1)
		_check_locker(locker)


func _check_locker(locker: Locker) -> void:
	if state == State.CHECK_LOCKER:
		return
	_locker = locker
	state = State.CHECK_LOCKER
	_state_t = 0.0
	_go_to(locker.exit_position())


func _kill(player: Player) -> void:
	state = State.KILL
	velocity = Vector3.ZERO
	_music.volume_db = -6.0
	var dir := global_position - player.global_position
	dir.y = 0.0
	if dir.length() < 0.1:
		dir = -player.global_transform.basis.z
	dir = dir.normalized()
	global_position = player.global_position + dir * 1.05
	global_position.y = player.global_position.y
	var look := player.global_position
	look.y = global_position.y
	look_at(look, Vector3.UP)
	# yüzü görünür kılan soluk, hastalıklı ışık
	var face := OmniLight3D.new()
	face.light_color = Color(0.75, 0.85, 0.7)
	face.light_energy = 1.6
	face.omni_range = 2.2
	face.position = Vector3(0, 1.7, -0.7)
	add_child(face)
	player.die(self)


# ---------------------------------------------------------------- hareket

func _go_to(pos: Vector3) -> void:
	_goal = pos
	_path = Game.level.find_path(global_position, pos)
	_path_i = 0


func _path_done() -> bool:
	return _path_i >= _path.size()


func _follow_path(delta: float, spd: float) -> void:
	var want := Vector3.ZERO
	while _path_i < _path.size():
		var p := _path[_path_i]
		var to := p - global_position
		to.y = 0.0
		if to.length() < 0.35:
			_path_i += 1
			continue
		want = to.normalized() * spd
		break
	var k := 1.0 - exp(-10.0 * delta)
	velocity.x = lerpf(velocity.x, want.x, k)
	velocity.z = lerpf(velocity.z, want.z, k)
	velocity.y = 0.0 if is_on_floor() else velocity.y - 18.0 * delta
	move_and_slide()
	var hv := Vector3(velocity.x, 0, velocity.z)
	if hv.length() > 0.2:
		var yaw := atan2(-hv.x, -hv.z)
		rotation.y = lerp_angle(rotation.y, yaw, 1.0 - exp(-7.0 * delta))


func _face(pos: Vector3, rate: float) -> void:
	var to := pos - global_position
	var yaw := atan2(-to.x, -to.z)
	rotation.y = lerp_angle(rotation.y, yaw, clampf(rate * 0.2, 0.0, 1.0))


func _look_around(delta: float) -> void:
	rotation.y += sin(_state_t * 1.3) * delta * 1.2


func _open_doors() -> void:
	for door: Door in Game.level.doors:
		if door.is_open or door.locked:
			continue
		var d := door.global_position.distance_to(global_position)
		if d < 1.9:
			door.open_from(global_position, true)
			_door_pause = 0.4


func _check_stuck(delta: float) -> void:
	if _path_done():
		_stuck_t = 0.0
		return
	_stuck_t += delta
	if _stuck_t > 1.2:
		if global_position.distance_to(_stuck_pos) < 0.25:
			_go_to(_goal)
			global_position += Vector3(randf_range(-0.2, 0.2), 0, randf_range(-0.2, 0.2))
		_stuck_pos = global_position
		_stuck_t = 0.0


func _pick_patrol(player: Player) -> void:
	var pts: Array[Vector3] = Game.level.patrol_points
	var chosen := pts[randi() % pts.size()]
	# "yönetmen": çoğu zaman oyuncunun bölgesine doğru dolaşır
	if randf() < 0.5:
		var near := pts.duplicate()
		near.sort_custom(func(a: Vector3, b: Vector3) -> bool:
			return a.distance_to(player.global_position) < b.distance_to(player.global_position))
		var options := near.slice(0, 5).filter(func(p: Vector3) -> bool:
			return p.distance_to(global_position) > 4.0)
		if not options.is_empty():
			chosen = options[randi() % options.size()]
	_go_to(chosen)
	_wait_t = randf_range(1.0, 3.5)


func _random_point_near(center: Vector3, radius_cells: int) -> Vector3:
	var lvl := Game.level
	var c := LevelBuilder.world_to_cell(center)
	for i in 12:
		var cand := c + Vector2i(randi_range(-radius_cells, radius_cells), randi_range(-radius_cells, radius_cells))
		if lvl.is_cell_open(cand):
			return LevelBuilder.cell_center(cand.x, cand.y)
	return center


func _footsteps(delta: float, hs: float, player: Player) -> void:
	if hs < 0.2:
		return
	_step_acc += hs * delta
	var stride := 1.2 if state != State.CHASE and state != State.FINAL else 1.5
	if _step_acc >= stride:
		_step_acc = 0.0
		var loud := 2.0 if is_hunting() else -2.0
		Sfx.play_at(Sfx.random_variant("enemy_step", 2), global_position, loud, randf_range(0.85, 1.1), 30.0, 3.0)
		var d := global_position.distance_to(player.global_position)
		if d < 9.0:
			player.add_shake(0.06 * (1.0 - d / 9.0))


func _update_music(delta: float) -> void:
	var target := 1.0 if is_hunting() else 0.0
	_music_vol = move_toward(_music_vol, target, delta * (1.5 if target > 0.5 else 0.25))
	_music.volume_db = linear_to_db(maxf(_music_vol, 0.0001))

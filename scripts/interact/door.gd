class_name Door
extends Node3D
## Menteşeli kapı. Kilitli olabilir (anahtar ya da elektrik gerektirir).

const W := LevelBuilder.DOOR_W - 0.14
const H := LevelBuilder.DOOR_H - 0.03
const OPEN_ANGLE := 92.0

var cell := Vector2i.ZERO
var along_x := false
var key_id := ""
var key_name := ""
var is_exit := false
var locked := false
var is_open := false

var _hinge: Node3D
var _body: AnimatableBody3D
var _tween: Tween


func _ready() -> void:
	locked = key_id != "" or is_exit
	rotation_degrees.y = 90.0 if along_x else 0.0

	_hinge = Node3D.new()
	_hinge.position = Vector3(-W * 0.5, 0, 0)
	add_child(_hinge)
	_body = AnimatableBody3D.new()
	_body.collision_layer = 8 | 16
	_body.collision_mask = 0
	_body.sync_to_physics = false
	_body.set_meta("interact_owner", self)
	_hinge.add_child(_body)

	var panel := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(W, H, 0.07)
	panel.mesh = bm
	panel.material_override = Mats.triplanar("metal_rust" if is_exit else "door_wood", 0.8)
	panel.position = Vector3(W * 0.5, H * 0.5, 0)
	_body.add_child(panel)

	# gözetleme penceresi çerçevesi (koğuş kapısı hissi)
	if not is_exit:
		var win := MeshInstance3D.new()
		var wm := BoxMesh.new()
		wm.size = Vector3(0.32, 0.22, 0.09)
		win.mesh = wm
		win.material_override = Mats.plain(Color(0.015, 0.015, 0.018), 0.75, 0.0)
		win.position = Vector3(W * 0.5, 1.65, 0)
		_body.add_child(win)

	var knob_mat := Mats.plain(Color(0.45, 0.4, 0.32), 0.35, 1.0)
	for zs in [-1.0, 1.0]:
		var knob := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.035
		sm.height = 0.07
		knob.mesh = sm
		knob.material_override = knob_mat
		knob.position = Vector3(W - 0.11, 1.0, 0.06 * zs)
		_body.add_child(knob)

	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(W, H, 0.08)
	cs.shape = shape
	cs.position = Vector3(W * 0.5, H * 0.5, 0)
	_body.add_child(cs)

	# kasa
	var frame_mat := Mats.triplanar("door_wood", 1.5)
	for fx in [-LevelBuilder.DOOR_W * 0.5 + 0.03, LevelBuilder.DOOR_W * 0.5 - 0.03]:
		_frame_piece(Vector3(fx, LevelBuilder.DOOR_H * 0.5, 0), Vector3(0.06, LevelBuilder.DOOR_H, 0.16), frame_mat)
	_frame_piece(Vector3(0, LevelBuilder.DOOR_H - 0.03, 0), Vector3(LevelBuilder.DOOR_W, 0.06, 0.16), frame_mat)


func _frame_piece(pos: Vector3, size: Vector3, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	mi.position = pos
	add_child(mi)


func get_prompt() -> String:
	if locked:
		if is_exit:
			return tr("Ana Kapı") if Game.power_on else tr("Ana Kapı (elektrik yok)")
		if Game.has_key(key_id):
			return tr("Kilidi aç: %s") % tr(key_name)
		return tr("Kilitli")
	return tr("Kapıyı kapat") if is_open else tr("Kapıyı aç")


func interact(player: Node3D) -> void:
	if locked:
		if is_exit:
			if Game.power_on:
				Game.level.on_exit_opened()
			else:
				Sfx.play_at("door_locked", global_position + Vector3.UP, 0.0)
				Game.level.on_exit_tried()
			return
		if Game.has_key(key_id):
			unlock()
			Game.show_message(tr("%s kullanıldı.") % tr(key_name))
		else:
			Sfx.play_at("door_locked", global_position + Vector3.UP, 0.0)
			Game.make_noise(global_position, 6.0)
			Game.show_message(tr("Kilitli. Bir anahtar gerekiyor."), 2.5)
		return
	if is_open:
		close()
	else:
		open_from(player.global_position, false)
		var crouched: bool = player.get("crouching")
		Game.make_noise(global_position, 3.5 if crouched else 7.0)


func unlock() -> void:
	locked = false
	Sfx.play_at("unlock", global_position + Vector3.UP, 0.0)
	if Game.level:
		Game.level.on_door_unlocked(self)


func open_from(from: Vector3, by_enemy: bool) -> void:
	if locked or is_open:
		return
	is_open = true
	var lp := to_local(from)
	var target := OPEN_ANGLE if lp.z > 0.0 else -OPEN_ANGLE
	_animate(target, 0.45 if by_enemy else 0.9, Tween.TRANS_SINE)
	Sfx.play_at("door_open", global_position + Vector3.UP * 1.2, 2.0 if by_enemy else 0.0, randf_range(0.9, 1.1))


func close() -> void:
	if not is_open:
		return
	is_open = false
	_animate(0.0, 0.7, Tween.TRANS_SINE)
	get_tree().create_timer(0.6).timeout.connect(func() -> void:
		if is_inside_tree() and not is_open:
			Sfx.play_at("door_close", global_position + Vector3.UP, 0.0))


## Korku olayı: kapı aniden çarpar.
func slam() -> void:
	is_open = false
	_animate(0.0, 0.22, Tween.TRANS_EXPO, Tween.EASE_IN)
	get_tree().create_timer(0.2).timeout.connect(func() -> void:
		Sfx.play_at("door_slam", global_position + Vector3.UP, 6.0, 1.0, 45.0))


## Korku olayı: kapı kendiliğinden yavaşça açılır.
func creep_open(angle := 40.0) -> void:
	is_open = true
	_animate(angle, 3.0, Tween.TRANS_SINE)
	Sfx.play_at("door_open", global_position + Vector3.UP * 1.2, 0.0, 0.7)


func force_open_wide(angle: float) -> void:
	is_open = true
	_hinge.rotation_degrees.y = angle


func _animate(target_deg: float, dur: float, trans: Tween.TransitionType, ease_type := Tween.EASE_IN_OUT) -> void:
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(_hinge, "rotation_degrees:y", target_deg, dur).set_trans(trans).set_ease(ease_type)

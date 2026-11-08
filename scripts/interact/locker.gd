class_name Locker
extends StaticBody3D
## Saklanılabilen metal dolap. Önü yerel +Z yönüne bakar.

const W := 0.78
const H := 2.0
const D := 0.6
## Oyuncu içerideyken kapı mesh'i bu görsel katmanda olur ve kameradan gizlenir.
const DOOR_LAYER := 2

var _door_pivot: Node3D
var _tween: Tween


func _ready() -> void:
	collision_layer = 1 | 8
	collision_mask = 0
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(W, H, D)
	cs.shape = sh
	cs.position = Vector3(0, H * 0.5, 0)
	add_child(cs)

	var mat := Mats.triplanar("metal_green", 1.2)
	var t := 0.025
	_panel(Vector3(0, H * 0.5, -D * 0.5 + t * 0.5), Vector3(W, H, t), mat)
	_panel(Vector3(-W * 0.5 + t * 0.5, H * 0.5, 0), Vector3(t, H, D), mat)
	_panel(Vector3(W * 0.5 - t * 0.5, H * 0.5, 0), Vector3(t, H, D), mat)
	_panel(Vector3(0, H - t * 0.5, 0), Vector3(W, t, D), mat)
	_panel(Vector3(0, t * 0.5, 0), Vector3(W, t, D), mat)
	# iç karanlık
	var inner := Mats.plain(Color(0.03, 0.03, 0.03), 0.9)
	_panel(Vector3(0, H * 0.5, -D * 0.5 + t + 0.005), Vector3(W - 2 * t, H - 2 * t, 0.01), inner)

	_door_pivot = Node3D.new()
	_door_pivot.position = Vector3(-W * 0.5, 0, D * 0.5)
	add_child(_door_pivot)
	var door := _panel(Vector3(W * 0.5, H * 0.5, -0.012), Vector3(W - 0.01, H - 0.01, 0.022), mat, _door_pivot)
	door.layers = DOOR_LAYER
	# havalandırma yarıkları
	var slit_mat := Mats.plain(Color(0.0, 0.0, 0.0), 1.0)
	for i in 6:
		var s := _panel(Vector3(W * 0.5, 1.45 + i * 0.045, 0.002), Vector3(W * 0.55, 0.014, 0.01), slit_mat, _door_pivot)
		s.layers = DOOR_LAYER
	var handle := _panel(Vector3(W - 0.08, 1.05, 0.015), Vector3(0.025, 0.14, 0.03), Mats.plain(Color(0.3, 0.3, 0.3), 0.4, 1.0), _door_pivot)
	handle.layers = DOOR_LAYER


func _panel(pos: Vector3, size: Vector3, mat: Material, parent: Node3D = null) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	mi.position = pos
	(parent if parent else self).add_child(mi)
	return mi


func get_prompt() -> String:
	var p := Game.player
	if p and p.get("hidden_in") == self:
		return tr("Dolaptan çık")
	return tr("Dolaba saklan")


func interact(player: Node3D) -> void:
	if player.get("hidden_in") == self:
		player.call("exit_locker")
	else:
		player.call("enter_locker", self)


## Oyuncunun içeride duracağı ayak noktası ve bakış yönü (yaw).
func hide_transform() -> Transform3D:
	var t := Transform3D(Basis(Vector3.UP, global_rotation.y + PI), to_global(Vector3(0, 0, 0.02)))
	return t


func exit_position() -> Vector3:
	return to_global(Vector3(0, 0, D * 0.5 + 0.55))


func swing(open: bool, quiet := false) -> void:
	if _tween:
		_tween.kill()
	_tween = create_tween()
	if open:
		_tween.tween_property(_door_pivot, "rotation_degrees:y", -100.0, 0.25)
		_tween.tween_property(_door_pivot, "rotation_degrees:y", 0.0, 0.35).set_delay(0.35)
		Sfx.play_at("locker_open", global_position + Vector3.UP, -6.0 if quiet else 0.0)
		get_tree().create_timer(0.65).timeout.connect(func() -> void:
			Sfx.play_at("locker_close", global_position + Vector3.UP, -8.0 if quiet else -2.0))
	else:
		_tween.tween_property(_door_pivot, "rotation_degrees:y", -110.0, 0.15)


## Düşman dolabı zorla açar.
func rip_open() -> void:
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(_door_pivot, "rotation_degrees:y", -120.0, 0.12).set_trans(Tween.TRANS_EXPO)
	Sfx.play_at("metal_bang", global_position + Vector3.UP, 4.0)

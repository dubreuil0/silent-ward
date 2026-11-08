class_name Generator
extends StaticBody3D
## Bodrumdaki jeneratör. Beş sigorta takılınca elektriği geri getirir.

var _slots: Array[MeshInstance3D] = []
var _slot_on: StandardMaterial3D
var _slot_off: StandardMaterial3D
var _loop: AudioStreamPlayer3D
var _shake_t := 0.0
var _model: Node3D
var _starting := false


func _ready() -> void:
	collision_layer = 1 | 8
	collision_mask = 0
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(1.4, 1.0, 1.0)
	cs.shape = sh
	cs.position = Vector3(0, 0.5, 0)
	add_child(cs)

	_model = (load("res://assets/models/portable_generator/portable_generator.gltf") as PackedScene).instantiate()
	_model.scale = Vector3.ONE * 1.6
	add_child(_model)

	# sigorta paneli: jeneratörün üstünde beş yuva
	var panel := MeshInstance3D.new()
	var pm := BoxMesh.new()
	pm.size = Vector3(0.7, 0.32, 0.06)
	panel.mesh = pm
	panel.material_override = Mats.triplanar("metal_rust", 2.0)
	panel.position = Vector3(0, 1.15, -0.15)
	add_child(panel)
	_slot_off = Mats.plain(Color(0.08, 0.02, 0.02), 0.5, 0.0, Color(0.6, 0.05, 0.02), 0.6)
	_slot_on = Mats.plain(Color(0.9, 0.6, 0.2), 0.2, 0.0, Color(1.0, 0.6, 0.2), 3.0)
	for i in Game.FUSES_NEEDED:
		var s := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.035
		cm.bottom_radius = 0.035
		cm.height = 0.05
		s.mesh = cm
		s.rotation.x = PI * 0.5
		s.position = Vector3(-0.24 + i * 0.12, 1.15, -0.11)
		s.material_override = _slot_off
		add_child(s)
		_slots.append(s)


func _process(delta: float) -> void:
	if Game.power_on and _model:
		_shake_t += delta
		_model.position = Vector3(sin(_shake_t * 70.0), 0, cos(_shake_t * 53.0)) * 0.006


func get_prompt() -> String:
	if Game.power_on:
		return tr("Jeneratör çalışıyor")
	if Game.fuses >= Game.FUSES_NEEDED:
		return tr("Sigortaları tak ve jeneratörü çalıştır")
	return tr("Jeneratör (%d/%d sigorta)") % [Game.fuses, Game.FUSES_NEEDED]


func interact(_player: Node3D) -> void:
	if Game.power_on or _starting:
		return
	if Game.fuses < Game.FUSES_NEEDED:
		Game.show_message(tr("Sigorta yuvaları boş. %d sigorta daha lazım.") % (Game.FUSES_NEEDED - Game.fuses))
		Sfx.play_at("door_locked", global_position + Vector3.UP, -4.0, 1.4)
		return
	_starting = true
	for i in _slots.size():
		get_tree().create_timer(0.25 * i).timeout.connect(func() -> void:
			_slots[i].material_override = _slot_on
			Sfx.play_at("unlock", global_position + Vector3.UP, -4.0, 1.2 + i * 0.05))
	get_tree().create_timer(1.5).timeout.connect(func() -> void:
		Sfx.play_at("generator_start", global_position + Vector3.UP * 0.5, 6.0, 1.0, 60.0)
		get_tree().create_timer(2.2).timeout.connect(func() -> void:
			_loop = Sfx.attach_loop("generator_loop", self, 0.0, 4.0, 40.0)
			if Game.level:
				Game.level.restore_power()))

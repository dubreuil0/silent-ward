class_name Pickup
extends StaticBody3D
## Toplanabilir eşya: sigorta, anahtar veya pil.

var kind := "fuse"
var item_id := ""
var display := ""

var _glow: OmniLight3D
var _glint_mat: StandardMaterial3D
var _t := 0.0


func _ready() -> void:
	collision_layer = 8
	collision_mask = 0
	_t = randf() * 10.0
	var cs := CollisionShape3D.new()
	var sh := SphereShape3D.new()
	sh.radius = 0.2
	cs.shape = sh
	cs.position = Vector3(0, 0.08, 0)
	add_child(cs)
	match kind:
		"fuse":
			_build_fuse()
		"key":
			_build_key()
		"battery":
			_build_battery()


func _process(delta: float) -> void:
	_t += delta
	var pulse := 0.5 + 0.5 * sin(_t * 2.2)
	if _glow:
		_glow.light_energy = 0.12 + 0.18 * pulse
	if _glint_mat:
		_glint_mat.emission_energy_multiplier = 0.4 + 1.2 * pulse


func get_prompt() -> String:
	return tr("Al: %s") % tr(display)


func interact(player: Node3D) -> void:
	match kind:
		"fuse":
			Game.add_fuse()
			Sfx.play("fuse_pickup", -4.0)
			Game.show_message(tr("Sigorta bulundu (%d/%d)") % [Game.fuses, Game.FUSES_NEEDED])
		"key":
			Game.add_key(item_id, display)
			Sfx.play("key_pickup", -4.0)
			Game.show_message(tr("%s alındı.") % tr(display))
		"battery":
			player.call("add_battery", 45.0)
			Sfx.play("battery", -2.0)
			Game.show_message(tr("Fener pili (+%45)"), 2.0)
	if Game.level:
		Game.level.on_item_picked(self)
	queue_free()


func _mesh(mesh: Mesh, mat: Material, pos: Vector3, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.rotation = rot
	add_child(mi)
	return mi


func _add_glow(color: Color) -> void:
	_glow = OmniLight3D.new()
	_glow.light_color = color
	_glow.omni_range = 0.9
	_glow.light_energy = 0.2
	_glow.position = Vector3(0, 0.15, 0)
	_glow.light_volumetric_fog_energy = 0.0
	add_child(_glow)


func _build_fuse() -> void:
	# cam gövdeli eski tip sigorta
	_glint_mat = Mats.plain(Color(0.9, 0.55, 0.2, 0.6), 0.05, 0.0, Color(1.0, 0.55, 0.15), 1.0)
	_glint_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var glass := CylinderMesh.new()
	glass.top_radius = 0.028
	glass.bottom_radius = 0.028
	glass.height = 0.11
	var lying := Vector3(0, 0, PI * 0.5)
	_mesh(glass, _glint_mat, Vector3(0, 0.03, 0), lying)
	var cap := CylinderMesh.new()
	cap.top_radius = 0.032
	cap.bottom_radius = 0.032
	cap.height = 0.035
	var metal := Mats.plain(Color(0.7, 0.62, 0.45), 0.3, 1.0)
	_mesh(cap, metal, Vector3(-0.07, 0.032, 0), lying)
	_mesh(cap, metal, Vector3(0.07, 0.032, 0), lying)
	_add_glow(Color(1.0, 0.6, 0.25))


func _build_key() -> void:
	var brass := Mats.plain(Color(0.62, 0.5, 0.28), 0.3, 1.0, Color(0.9, 0.8, 0.5), 0.0)
	brass.emission_enabled = true
	brass.emission = Color(0.6, 0.5, 0.3)
	_glint_mat = brass
	var ring := TorusMesh.new()
	ring.inner_radius = 0.02
	ring.outer_radius = 0.035
	_mesh(ring, brass, Vector3(-0.06, 0.006, 0))
	var shaft := BoxMesh.new()
	shaft.size = Vector3(0.1, 0.008, 0.012)
	_mesh(shaft, brass, Vector3(0.02, 0.006, 0))
	var bit := BoxMesh.new()
	bit.size = Vector3(0.025, 0.008, 0.03)
	_mesh(bit, brass, Vector3(0.06, 0.006, 0.018))
	# kırmızı etiket
	var tag := BoxMesh.new()
	tag.size = Vector3(0.04, 0.004, 0.06)
	_mesh(tag, Mats.plain(Color(0.4, 0.05, 0.04), 0.9), Vector3(-0.11, 0.003, 0.02), Vector3(0, 0.4, 0))
	_add_glow(Color(0.8, 0.85, 1.0))


func _build_battery() -> void:
	var body := CylinderMesh.new()
	body.top_radius = 0.017
	body.bottom_radius = 0.017
	body.height = 0.065
	var lying := Vector3(0, 0, PI * 0.5)
	_glint_mat = Mats.plain(Color(0.12, 0.3, 0.12), 0.4, 0.3, Color(0.2, 0.5, 0.2), 0.3)
	for i in 2:
		_mesh(body, _glint_mat, Vector3(0, 0.017, -0.02 + 0.04 * i), lying)
		var tip := CylinderMesh.new()
		tip.top_radius = 0.006
		tip.bottom_radius = 0.006
		tip.height = 0.01
		_mesh(tip, Mats.plain(Color(0.7, 0.7, 0.7), 0.3, 1.0), Vector3(0.037, 0.017, -0.02 + 0.04 * i), lying)
	_add_glow(Color(0.5, 1.0, 0.5))

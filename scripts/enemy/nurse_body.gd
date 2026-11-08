class_name NurseBody
extends Node3D
## "Hemşire": gözleri bağlı, uzun uzuvlu, ~2.2 m boyunda prosedürel yaratık.
## Model -Z yönüne bakar. animate() ile kodla canlandırılır.

enum Pose { IDLE, WALK, CHASE, KILL }

const SHADER := preload("res://assets/shaders/nurse.gdshader")

var skin_mat: ShaderMaterial
var cloth_mat: ShaderMaterial
var band_mat: ShaderMaterial

var _hip_root: Node3D
var _torso: Node3D
var _neck: Node3D
var _head: Node3D
var _hips: Array[Node3D] = []
var _knees: Array[Node3D] = []
var _shoulders: Array[Node3D] = []
var _elbows: Array[Node3D] = []
var _fingers: Array[Node3D] = []
var _phase := 0.0
var _twitch_t := 0.0
var _twitch := Vector3.ZERO
var _twitch_target := Vector3.ZERO
var _reach := 0.0


func _ready() -> void:
	skin_mat = _make_mat(false)
	skin_mat.set_shader_parameter("base_a", Color(0.33, 0.33, 0.3))
	skin_mat.set_shader_parameter("base_b", Color(0.12, 0.13, 0.14))
	skin_mat.set_shader_parameter("blood_amount", 0.3)
	cloth_mat = _make_mat(true)
	band_mat = _make_mat(true)
	band_mat.set_shader_parameter("base_a", Color(0.3, 0.26, 0.2))
	band_mat.set_shader_parameter("blood_amount", 0.65)
	_build()


func _make_mat(cloth: bool) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = SHADER
	m.set_shader_parameter("is_cloth", 1.0 if cloth else 0.0)
	if cloth:
		m.set_shader_parameter("base_a", Color(0.4, 0.38, 0.32))
		m.set_shader_parameter("base_b", Color(0.2, 0.18, 0.14))
		m.set_shader_parameter("blood_amount", 0.48)
		m.set_shader_parameter("bottom_blood", 0.7)
	return m


func _part(parent: Node3D, mesh: Mesh, mat: Material, pos: Vector3, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.rotation = rot
	parent.add_child(mi)
	return mi


func _pivot(parent: Node3D, pos: Vector3) -> Node3D:
	var n := Node3D.new()
	n.position = pos
	parent.add_child(n)
	return n


func _limb(length: float, r_top: float, r_bot: float) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.height = length
	c.top_radius = r_top
	c.bottom_radius = r_bot
	c.radial_segments = 10
	c.rings = 2
	return c


func _build() -> void:
	_hip_root = _pivot(self, Vector3(0, 0.92, 0))

	# bacaklar: önlüğün altından görünen sıska bacaklar
	for side in [-1.0, 1.0]:
		var hip := _pivot(_hip_root, Vector3(0.1 * side, 0, 0))
		_part(hip, _limb(0.48, 0.055, 0.04), skin_mat, Vector3(0, -0.24, 0))
		var knee := _pivot(hip, Vector3(0, -0.48, 0))
		_part(knee, _limb(0.44, 0.04, 0.03), skin_mat, Vector3(0, -0.22, 0))
		var foot := BoxMesh.new()
		foot.size = Vector3(0.07, 0.04, 0.22)
		_part(knee, foot, skin_mat, Vector3(0, -0.43, -0.06))
		_hips.append(hip)
		_knees.append(knee)

	# önlük (etek)
	var gown := _limb(0.95, 0.19, 0.4)
	gown.radial_segments = 16
	gown.rings = 4
	_part(_hip_root, gown, cloth_mat, Vector3(0, -0.02, 0))

	_torso = _pivot(_hip_root, Vector3(0, 0.45, 0))
	var chest := CapsuleMesh.new()
	chest.radius = 0.16
	chest.height = 0.62
	_part(_torso, chest, cloth_mat, Vector3(0, 0.15, 0), Vector3(0.12, 0, 0))
	# omurga çıkıntıları
	var bump := SphereMesh.new()
	bump.radius = 0.03
	bump.height = 0.05
	for i in 4:
		_part(_torso, bump, skin_mat, Vector3(0, 0.0 + i * 0.1, 0.14 - i * 0.012))

	_neck = _pivot(_torso, Vector3(0, 0.42, -0.04))
	_part(_neck, _limb(0.22, 0.035, 0.045), skin_mat, Vector3(0, 0.1, 0))
	_head = _pivot(_neck, Vector3(0, 0.22, 0))
	var skull := SphereMesh.new()
	skull.radius = 0.12
	skull.height = 0.31
	_part(_head, skull, skin_mat, Vector3(0, 0.1, 0))
	# göz bağı
	var band := TorusMesh.new()
	band.inner_radius = 0.105
	band.outer_radius = 0.135
	band.rings = 16
	_part(_head, band, band_mat, Vector3(0, 0.13, 0), Vector3(0.1, 0, 0))
	# yırtık, dikey ağız
	var mouth := BoxMesh.new()
	mouth.size = Vector3(0.035, 0.09, 0.02)
	var mouth_mat := Mats.plain(Color(0.03, 0.0, 0.0), 0.3, 0.0, Color(0.25, 0.0, 0.0), 0.4)
	_part(_head, mouth, mouth_mat, Vector3(0, 0.0, -0.105), Vector3(0.15, 0, 0))
	var tooth := BoxMesh.new()
	tooth.size = Vector3(0.008, 0.016, 0.01)
	var tooth_mat := Mats.plain(Color(0.6, 0.55, 0.42), 0.4)
	for i in 5:
		_part(_head, tooth, tooth_mat, Vector3(-0.012 + (i % 2) * 0.024, 0.035 - i * 0.017, -0.112))
	# hemşire bonesi
	var cap := BoxMesh.new()
	cap.size = Vector3(0.2, 0.07, 0.13)
	_part(_head, cap, cloth_mat, Vector3(0, 0.25, 0.02), Vector3(-0.25, 0, 0))
	var cross := BoxMesh.new()
	cross.size = Vector3(0.05, 0.015, 0.005)
	var red := Mats.plain(Color(0.35, 0.02, 0.02), 0.6)
	_part(_head, cross, red, Vector3(0, 0.27, -0.045), Vector3(-0.25, 0, 0))
	_part(_head, cross, red, Vector3(0, 0.27, -0.045), Vector3(-0.25, 0, PI * 0.5))

	# uzun kollar ve parmaklar
	for side in [-1.0, 1.0]:
		var sh := _pivot(_torso, Vector3(0.21 * side, 0.36, 0))
		sh.rotation.z = 0.08 * side
		_part(sh, _limb(0.5, 0.045, 0.035), skin_mat, Vector3(0, -0.25, 0))
		var el := _pivot(sh, Vector3(0, -0.5, 0))
		_part(el, _limb(0.52, 0.035, 0.025), skin_mat, Vector3(0, -0.26, 0))
		var hand := _pivot(el, Vector3(0, -0.53, 0))
		var palm := BoxMesh.new()
		palm.size = Vector3(0.06, 0.09, 0.025)
		_part(hand, palm, skin_mat, Vector3(0, -0.04, 0))
		for f in 4:
			var fp := _pivot(hand, Vector3(-0.024 + f * 0.016, -0.085, 0))
			_part(fp, _limb(0.2 - absf(f - 1.5) * 0.02, 0.008, 0.004), skin_mat, Vector3(0, -0.1, 0))
			_fingers.append(fp)
		_shoulders.append(sh)
		_elbows.append(el)


func set_glitch(v: float) -> void:
	for m in [skin_mat, cloth_mat, band_mat]:
		m.set_shader_parameter("glitch", v)


## speed: m/s, pose: Pose
func animate(delta: float, speed: float, pose: int) -> void:
	var swing := clampf(speed / 2.2, 0.0, 1.3)
	_phase += delta * (1.5 + speed * 2.4)
	var s := sin(_phase)

	for i in 2:
		var sgn := 1.0 if i == 0 else -1.0
		_hips[i].rotation.x = s * 0.5 * swing * sgn
		_knees[i].rotation.x = -maxf(0.0, -s * sgn) * 0.8 * swing

	# kambur, sallanan gövde
	var hunch := 0.25 + (0.25 if pose == Pose.CHASE else 0.0)
	_torso.rotation.x = lerpf(_torso.rotation.x, -hunch + absf(s) * 0.05 * swing, delta * 5.0)
	_torso.rotation.z = sin(_phase * 0.5) * 0.06 * swing
	_hip_root.position.y = 0.92 + absf(s) * 0.035 * swing

	# kollar: yürürken sarkar, kovalarken öne uzanır
	var want_reach := 1.0 if pose == Pose.CHASE or pose == Pose.KILL else 0.0
	_reach = lerpf(_reach, want_reach, delta * 4.0)
	for i in 2:
		var sgn := 1.0 if i == 0 else -1.0
		var hang := -s * 0.18 * swing * sgn
		var reach_angle := 1.25 + sin(_phase * 2.0 + i) * 0.15
		if pose == Pose.KILL:
			reach_angle = 2.2 + sin(Time.get_ticks_msec() * 0.05 + i) * 0.1
		_shoulders[i].rotation.x = lerpf(hang, reach_angle, _reach)
		_elbows[i].rotation.x = lerpf(-0.1, -0.25, _reach)
	var curl := 0.3 + 0.3 * sin(_phase * 3.0)
	for f in _fingers:
		f.rotation.x = lerpf(f.rotation.x, curl * (1.0 - _reach * 0.6), delta * 6.0)

	# kafa: yana eğik, ani seğirmeler
	_twitch_t -= delta
	if _twitch_t <= 0.0:
		var agitated := pose == Pose.CHASE or pose == Pose.KILL
		_twitch_t = randf_range(0.05, 0.25) if agitated else randf_range(0.6, 2.5)
		var amp := 0.7 if agitated else 0.35
		_twitch_target = Vector3(randf_range(-amp, amp) * 0.5, randf_range(-amp, amp), randf_range(-amp, amp))
	_twitch = _twitch.lerp(_twitch_target, minf(1.0, delta * 25.0))
	_head.rotation = Vector3(0.15, 0, 0.45) + _twitch
	_neck.rotation.x = -0.35 + (0.3 if pose == Pose.CHASE else 0.0)

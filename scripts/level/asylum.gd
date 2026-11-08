extends Node3D
## Saint Halvard Akıl Hastanesi: seviye kurulumu, korku olayları ve oyun akışı.

const MAP := [
	"########################################",
	"#######........................#########",
	"#######.######################.#########",
	"#wwwww#.#wwwww#ooooooooo######.#########",
	"#wwwwwD.Dwwwww#ooooooooo######.#########",
	"#wwwww#.#wwwww#ooooooooo######.#########",
	"#######.#######ooooooooo######.#########",
	"#wwwww#.#wwwww#####O##########.#########",
	"#wwwwwD.Dwwwww#####.##########.#########",
	"#wwwww#.#wwwww#kkk#.###ssssss#.#mmmmmm##",
	"#######.#######kkk#.###ssssss#.#mmmmmm##",
	"#wwwww#.#wwwww#kkkD.###ssssssD.Mmmmmmm##",
	"#wwwwwD.Dwwwww#kkk#.###ssssss#.#mmmmmm##",
	"#wwwww#.#wwwww#kkk#.###ssssss#.#mmmmmm##",
	"#######.###########.##########.#########",
	"#wwwww#.Dwwwww#####.##########.#########",
	"#wwwwwD.#wwwww#####.##########.Bbbbbbbb#",
	"#wwwww#.###########.##########.#bbbbbbb#",
	"#######........................#bbbbbbb#",
	"###########.#######lll##########bb#b#bb#",
	"###########D###lllllllllll######bbbbbbb#",
	"#########nnnnn#lllllllllll######bbbbbbb#",
	"#########nnnnn#lllllllllll######bb#b#bb#",
	"#########nnnnn#lllllllllll######bbbbbbb#",
	"#########nnnnn#lllllllllll######bbbbbbb#",
	"###############lllllllllll######bbbbbbb#",
	"####################E###################",
	"########################################",
]

const KEYS := {
	"M": ["morgue", "Morg Anahtarı"],
	"O": ["office", "Ofis Anahtarı"],
	"B": ["basement", "Bodrum Anahtarı"],
}

const DIRS := {"N": Vector3(0, 0, -1), "S": Vector3(0, 0, 1), "E": Vector3(1, 0, 0), "W": Vector3(-1, 0, 0)}

var builder: LevelBuilder
var astar: AStarGrid2D
var doors: Array[Door] = []
var patrol_points: Array[Vector3] = []
var enemy: Nurse
var player: Player
var hud: HUD

var _door_at: Dictionary = {}
var _lights: Array[FlickerLight] = []
var _emergency: Array[FlickerLight] = []
var _locked_patrol: Dictionary = {}
var _scenes: Dictionary = {}
var _env: Environment
var _ambient_t := 12.0
var _drip_t := 3.0
var _apparition: NurseBody
var _wheelchair: Node3D
var _exit_sign: Label3D
var _blood_tex: Texture2D
var _music_box: AudioStreamPlayer3D


func _ready() -> void:
	Game.new_run()
	Game.level = self
	builder = LevelBuilder.new(PackedStringArray(MAP))
	builder.build(self)
	astar = builder.make_astar()

	_setup_environment()
	_spawn_doors()
	_setup_patrol()

	player = Player.new()
	player.position = _c(20, 24)
	add_child(player)
	_add_dust()

	enemy = Nurse.new()
	enemy.position = Vector3(0, -50, 0)
	add_child(enemy)

	_build_lobby()
	_build_corridors()
	_build_wards()
	_build_nurse_station()
	_build_storage()
	_build_surgery()
	_build_morgue()
	_build_office()
	_build_basement()
	_build_emergency_lights()
	_build_decals()

	hud = HUD.new()
	add_child(hud)

	var amb := AudioStreamPlayer.new()
	amb.stream = Sfx.stream("ambient_drone")
	amb.bus = "Ambient"
	amb.volume_db = -6.0
	add_child(amb)
	amb.play()

	Game.settings_changed.connect(_apply_brightness)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	Game.set_objective(tr("Saint Halvard'dan çıkmanın bir yolunu bul."))
	_intro_messages()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots="):
			add_child((load("res://tools/screenshot_tour.gd") as GDScript).new())
		elif a.begins_with("--autotest="):
			add_child((load("res://tools/autotest.gd") as GDScript).new())


func _intro_messages() -> void:
	var lines := [
		[2.5, "Kardeşin bu hastanede kayboldu. Kapı arkandan kilitlendi.", 4.0],
		[7.5, "[F] Fener   ·   [Shift] Koş   ·   [Ctrl] Eğil   ·   [E] Etkileşim", 5.0],
	]
	for l in lines:
		get_tree().create_timer(l[0]).timeout.connect(func() -> void: Game.show_message(tr(l[1]), l[2]))


# ---------------------------------------------------------------- yardımcılar

func _c(x: int, z: int, ox := 0.0, oz := 0.0, y := 0.0) -> Vector3:
	return LevelBuilder.cell_center(x, z) + Vector3(ox, y, oz)


func surface_at(pos: Vector3) -> String:
	return builder.surface_at(pos)


func is_cell_open(c: Vector2i) -> bool:
	return astar.is_in_boundsv(c) and not astar.is_point_solid(c)


func find_path(from: Vector3, to: Vector3) -> PackedVector3Array:
	var a := LevelBuilder.world_to_cell(from)
	var b := LevelBuilder.world_to_cell(to)
	var pts := PackedVector3Array()
	if not astar.is_in_boundsv(a) or not astar.is_in_boundsv(b):
		return pts
	var exact := true
	if astar.is_point_solid(b):
		exact = false
		b = _nearest_open(b)
	if astar.is_point_solid(a):
		a = _nearest_open(a)
	if a == b:
		pts.append(Vector3(to.x, 0, to.z) if exact else LevelBuilder.cell_center(b.x, b.y))
		return pts
	var ids := astar.get_id_path(a, b, true)
	for i in range(1, ids.size()):
		pts.append(LevelBuilder.cell_center(ids[i].x, ids[i].y))
	if exact and not ids.is_empty() and ids[ids.size() - 1] == b:
		pts[pts.size() - 1] = Vector3(to.x, 0, to.z)
	return pts


func _nearest_open(c: Vector2i) -> Vector2i:
	for r in range(1, 4):
		for dz in range(-r, r + 1):
			for dx in range(-r, r + 1):
				var n := c + Vector2i(dx, dz)
				if is_cell_open(n):
					return n
	return c


func _block(cells: Array) -> void:
	for cell in cells:
		astar.set_point_solid(cell, true)


func _scene(id: String) -> PackedScene:
	if not _scenes.has(id):
		_scenes[id] = load("res://assets/models/%s/%s.gltf" % [id, id])
	return _scenes[id]


## Poly Haven modelini yerleştirir; collide ise AABB'sinden kutu çarpışması üretir.
func prop(id: String, pos: Vector3, rot_deg := 0.0, scl := 1.0, collide := true, y_fix := 0.0) -> Node3D:
	var inst := _scene(id).instantiate() as Node3D
	inst.position = pos + Vector3.UP * y_fix * scl
	inst.rotation_degrees.y = rot_deg
	inst.scale = Vector3.ONE * scl
	add_child(inst)
	if collide:
		var box := AABB()
		var first := true
		var inv := inst.global_transform.affine_inverse()
		for n in inst.find_children("*", "MeshInstance3D", true, false):
			var mi := n as MeshInstance3D
			var b: AABB = (inv * mi.global_transform) * mi.get_aabb()
			box = b if first else box.merge(b)
			first = false
		if not first:
			var body := StaticBody3D.new()
			body.collision_layer = 1
			body.collision_mask = 0
			var cs := CollisionShape3D.new()
			var sh := BoxShape3D.new()
			sh.size = box.size
			cs.shape = sh
			cs.position = box.get_center()
			body.add_child(cs)
			inst.add_child(body)
	return inst


func box(pos: Vector3, size: Vector3, mat: Material, collide := true) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	mi.position = pos
	add_child(mi)
	if collide:
		var body := StaticBody3D.new()
		body.collision_layer = 1
		body.collision_mask = 0
		var cs := CollisionShape3D.new()
		var sh := BoxShape3D.new()
		sh.size = size
		cs.shape = sh
		body.add_child(cs)
		mi.add_child(body)
	return mi


## Metal masa (ameliyat / otopsi) — üst yüzey 0.9 m.
func metal_table(pos: Vector3, rot_deg := 0.0, length := 2.0) -> void:
	var root := Node3D.new()
	root.position = pos
	root.rotation_degrees.y = rot_deg
	add_child(root)
	var steel := Mats.triplanar("metal_rust", 1.5)
	var top := MeshInstance3D.new()
	var tm := BoxMesh.new()
	tm.size = Vector3(length, 0.06, 0.8)
	top.mesh = tm
	top.material_override = steel
	top.position = Vector3(0, 0.87, 0)
	root.add_child(top)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			var leg := MeshInstance3D.new()
			var lm := CylinderMesh.new()
			lm.top_radius = 0.03
			lm.bottom_radius = 0.03
			lm.height = 0.85
			leg.mesh = lm
			leg.material_override = steel
			leg.position = Vector3(sx * (length * 0.5 - 0.08), 0.425, sz * 0.32)
			root.add_child(leg)
	var body := StaticBody3D.new()
	body.collision_layer = 1
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(length, 0.9, 0.8)
	cs.shape = sh
	cs.position = Vector3(0, 0.45, 0)
	body.add_child(cs)
	root.add_child(body)


func locker(x: int, z: int, facing: String) -> Locker:
	var d: Vector3 = DIRS[facing]
	var behind := Vector2i(x - int(d.x), z - int(d.z))
	if builder.is_walk(behind.x, behind.y):
		push_warning("Dolabın arkası duvar değil: %s" % [Vector2i(x, z)])
	var l := Locker.new()
	l.position = _c(x, z) - d * (LevelBuilder.CELL * 0.5 - Locker.D * 0.5 - 0.03)
	l.rotation.y = atan2(d.x, d.z)
	add_child(l)
	_block([Vector2i(x, z)])
	return l


func pickup(kind: String, pos: Vector3, id := "", display := "") -> Pickup:
	var p := Pickup.new()
	p.kind = kind
	p.item_id = id
	p.display = display
	if display == "":
		p.display = {"fuse": "Sigorta", "battery": "Pil"}.get(kind, kind)
	p.position = pos
	p.rotation.y = randf() * TAU
	add_child(p)
	return p


func note(id: String, pos: Vector3) -> void:
	var n := Note.new()
	n.note_id = id
	n.title = "note.%s.title" % id
	n.body = "note.%s.body" % id
	n.position = pos
	add_child(n)


## Tavana monte lamba. kind: fluo / cage / desk
func lamp(pos: Vector3, kind: String, mode: FlickerLight.Mode, energy := 1.0, rot_deg := 0.0, color := Color.WHITE) -> FlickerLight:
	var fixture_y := LevelBuilder.HEIGHT
	var emissive := Mats.plain(Color(0.9, 0.9, 0.85), 0.4, 0.0, Color(0.85, 0.92, 1.0), 3.0)
	var light_pos := pos
	match kind:
		"fluo":
			var f := prop("mounted_fluorescent_lights", Vector3(pos.x, fixture_y, pos.z), rot_deg, 1.2, false)
			f.name = "Fluo"
			var tube := MeshInstance3D.new()
			var tm := CapsuleMesh.new()
			tm.radius = 0.022
			tm.height = 0.95
			tube.mesh = tm
			tube.rotation = Vector3(0, deg_to_rad(rot_deg), PI * 0.5)
			tube.position = Vector3(pos.x, fixture_y - 0.06, pos.z)
			tube.material_override = emissive
			tube.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(tube)
			light_pos = Vector3(pos.x, fixture_y - 0.3, pos.z)
			if color == Color.WHITE:
				color = Color(0.78, 0.88, 1.0)
		"cage":
			prop("caged_hanging_light", Vector3(pos.x, fixture_y, pos.z), rot_deg, 1.0, false)
			emissive.emission = Color(1.0, 0.7, 0.4)
			var bulb := MeshInstance3D.new()
			var sm := SphereMesh.new()
			sm.radius = 0.05
			sm.height = 0.1
			bulb.mesh = sm
			bulb.material_override = emissive
			bulb.position = Vector3(pos.x, fixture_y - 0.62, pos.z)
			bulb.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(bulb)
			light_pos = Vector3(pos.x, fixture_y - 0.75, pos.z)
			if color == Color.WHITE:
				color = Color(1.0, 0.72, 0.45)
		"desk":
			emissive.emission = Color(1.0, 0.75, 0.45)
			var shade := MeshInstance3D.new()
			var cm := CylinderMesh.new()
			cm.top_radius = 0.05
			cm.bottom_radius = 0.13
			cm.height = 0.14
			shade.mesh = cm
			shade.material_override = Mats.plain(Color(0.12, 0.25, 0.15), 0.4, 0.6)
			shade.position = pos + Vector3(0, 0.38, 0)
			add_child(shade)
			var stem := MeshInstance3D.new()
			var st := CylinderMesh.new()
			st.top_radius = 0.012
			st.bottom_radius = 0.06
			st.height = 0.36
			stem.mesh = st
			stem.material_override = Mats.plain(Color(0.4, 0.33, 0.2), 0.3, 1.0)
			stem.position = pos + Vector3(0, 0.18, 0)
			add_child(stem)
			var bulb2 := MeshInstance3D.new()
			var sm2 := SphereMesh.new()
			sm2.radius = 0.035
			sm2.height = 0.07
			bulb2.mesh = sm2
			bulb2.material_override = emissive
			bulb2.position = pos + Vector3(0, 0.32, 0)
			add_child(bulb2)
			light_pos = pos + Vector3(0, 0.28, 0)
			if color == Color.WHITE:
				color = Color(1.0, 0.7, 0.4)
	var l := FlickerLight.new()
	l.position = light_pos
	l.light_color = color
	l.base_energy = energy * 1.8
	l.omni_range = 5.0 if kind == "desk" else 8.5
	l.omni_attenuation = 1.4
	l.shadow_enabled = true
	l.shadow_bias = 0.05
	l.light_volumetric_fog_energy = 1.4
	l.mode = mode
	l.emissive = emissive
	l.emissive_base = 3.0
	add_child(l)
	if kind == "fluo" and mode != FlickerLight.Mode.OFF:
		l.buzz = Sfx.attach_loop("buzz", l, -24.0, 1.2, 9.0, false)
	_lights.append(l)
	return l


func wall_text(text: String, pos: Vector3, yaw_deg: float, size := 110) -> Label3D:
	var l := Label3D.new()
	l.text = tr(text)
	l.font = UiKit.font("title")
	l.font_size = size
	l.pixel_size = 0.004
	l.modulate = Color(0.32, 0.015, 0.01)
	l.outline_size = 0
	l.shaded = true
	l.double_sided = false
	l.position = pos
	l.rotation_degrees = Vector3(0, yaw_deg, randf_range(-4.0, 4.0))
	add_child(l)
	return l


func trigger(x0: int, z0: int, x1: int, z1: int, act: Callable, cond: Callable = Callable()) -> void:
	var t := ScareTrigger.new()
	var a := _c(x0, z0)
	var b := _c(x1, z1)
	var size := Vector3(absf(b.x - a.x) + LevelBuilder.CELL, 2.5, absf(b.z - a.z) + LevelBuilder.CELL)
	add_child(t)
	t.setup((a + b) * 0.5, size, act, cond)


# ---------------------------------------------------------------- ortam

func _setup_environment() -> void:
	_env = Environment.new()
	_env.background_mode = Environment.BG_COLOR
	_env.background_color = Color.BLACK
	_env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_env.ambient_light_color = Color(0.07, 0.08, 0.1)
	_env.ambient_light_energy = 0.55
	_env.tonemap_mode = Environment.TONE_MAPPER_AGX
	_env.tonemap_white = 6.0
	_env.ssao_enabled = true
	_env.ssao_radius = 1.4
	_env.ssao_intensity = 2.6
	_env.ssao_power = 1.6
	_env.ssil_enabled = true
	_env.ssil_radius = 4.0
	_env.ssil_intensity = 1.2
	_env.glow_enabled = true
	_env.glow_intensity = 0.7
	_env.glow_bloom = 0.04
	_env.glow_hdr_threshold = 0.9
	_env.volumetric_fog_enabled = true
	_env.volumetric_fog_density = 0.04
	_env.volumetric_fog_albedo = Color(0.72, 0.75, 0.78)
	_env.volumetric_fog_anisotropy = 0.6
	_env.volumetric_fog_length = 48.0
	_env.volumetric_fog_ambient_inject = 0.08
	_env.adjustment_enabled = true
	_env.adjustment_contrast = 1.1
	_env.adjustment_saturation = 0.8
	var we := WorldEnvironment.new()
	we.environment = _env
	add_child(we)
	_apply_brightness()


func _apply_brightness() -> void:
	if _env:
		_env.tonemap_exposure = 1.4 * Game.brightness


func _add_dust() -> void:
	var p := GPUParticles3D.new()
	p.amount = 400
	p.lifetime = 10.0
	p.preprocess = 10.0
	p.local_coords = false
	p.visibility_aabb = AABB(Vector3(-10, -3, -10), Vector3(20, 6, 20))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(6, 1.4, 6)
	pm.direction = Vector3(0, 1, 0)
	pm.spread = 180.0
	pm.initial_velocity_min = 0.01
	pm.initial_velocity_max = 0.06
	pm.gravity = Vector3(0, -0.008, 0)
	pm.turbulence_enabled = true
	pm.turbulence_noise_strength = 0.3
	pm.turbulence_noise_speed_random = 0.2
	p.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(0.012, 0.012)
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.85, 0.82, 0.75)
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.roughness = 1.0
	q.material = m
	p.draw_pass_1 = q
	p.position = Vector3(0, 1.3, 0)
	player.add_child(p)


func _process(delta: float) -> void:
	if Game.game_over or player == null or player.dead:
		return
	_ambient_t -= delta
	if _ambient_t <= 0.0:
		_ambient_t = randf_range(16.0, 38.0)
		_random_ambient_event()
	if surface_at(player.global_position) == "concrete":
		_drip_t -= delta
		if _drip_t <= 0.0:
			_drip_t = randf_range(1.5, 5.0)
			var off := Vector3(randf_range(-6, 6), 2.5, randf_range(-6, 6))
			Sfx.play_at("drip", player.global_position + off, -10.0, randf_range(0.8, 1.3), 15.0, 2.0)


func _random_ambient_event() -> void:
	var events := ["metal_bang", "thump", "thump", "door_slam", "static", "whisper", "drip"]
	var ev: String = events[randi() % events.size()]
	var ang := randf() * TAU
	var dist := randf_range(9.0, 16.0)
	var vol := -8.0
	if ev == "whisper":
		dist = randf_range(1.5, 3.0)
		vol = -14.0
	var pos := player.global_position + Vector3(cos(ang) * dist, 2.0, sin(ang) * dist)
	Sfx.play_at(ev, pos, vol, randf_range(0.7, 1.0), 40.0)


# ---------------------------------------------------------------- kapılar ve devriye

func _spawn_doors() -> void:
	for info in builder.doors:
		var d := Door.new()
		d.cell = info["cell"]
		d.along_x = info["along_x"]
		var ch: String = info["char"]
		if KEYS.has(ch):
			d.key_id = KEYS[ch][0]
			d.key_name = KEYS[ch][1]
		d.is_exit = ch == "E"
		d.position = info["center"]
		add_child(d)
		doors.append(d)
		_door_at[d.cell] = d


func _setup_patrol() -> void:
	var cells := [
		Vector2i(7, 2), Vector2i(7, 8), Vector2i(7, 14), Vector2i(10, 18), Vector2i(16, 18),
		Vector2i(19, 13), Vector2i(24, 18), Vector2i(30, 4), Vector2i(30, 10), Vector2i(30, 16),
		Vector2i(13, 1), Vector2i(24, 1), Vector2i(3, 4), Vector2i(3, 8), Vector2i(3, 12),
		Vector2i(3, 16), Vector2i(11, 4), Vector2i(11, 8), Vector2i(11, 12), Vector2i(11, 16),
		Vector2i(11, 23), Vector2i(16, 11), Vector2i(26, 12), Vector2i(21, 22), Vector2i(17, 24),
	]
	for c in cells:
		patrol_points.append(LevelBuilder.cell_center(c.x, c.y))
	_locked_patrol = {
		"morgue": [Vector2i(34, 11), Vector2i(36, 10)],
		"office": [Vector2i(17, 5), Vector2i(21, 4)],
		"basement": [Vector2i(33, 18), Vector2i(35, 24)],
	}


func door(x: int, z: int) -> Door:
	return _door_at.get(Vector2i(x, z))


# ---------------------------------------------------------------- bölümler

func _build_lobby() -> void:
	prop("metal_office_desk", _c(17, 21), 0.0)
	_block([Vector2i(17, 21)])
	note("n1", _c(17, 21, -0.45, 0.15, 0.79))
	pickup("battery", _c(17, 21, 0.55, 0.1, 0.79))
	prop("Television_01", _c(17, 21, 0.1, -0.2, 0.79), 10.0, 1.0, false)
	prop("clipboard", _c(17, 21, -0.75, 0.1, 0.79), 40.0, 1.0, false)
	lamp(_c(17, 21, 0.8, -0.25, 0.79), "desk", FlickerLight.Mode.FLICKER, 0.7)
	prop("SchoolChair_01", _c(17, 22, 0.0, -0.1), 170.0)
	prop("wheelchair_01", _c(23, 24), 30.0)
	prop("WetFloorSign_01", _c(20, 21, 0.6, 0.0), 20.0, 1.0, false)
	prop("metal_trash_can", _c(25, 20, 0.4, -0.4), 0.0)
	prop("vintage_day_bed", _c(23, 25, 0.0, 0.5), 180.0)
	prop("cardboard_box_01", _c(15, 21, -0.4, -0.3), 25.0, 1.0, true, 0.18)
	prop("cardboard_box_01", _c(15, 21, -0.35, 0.2), -10.0, 1.0, true, 0.18)
	prop("wall_clock", Vector3(_c(23, 20).x, 2.35, 40.0), 0.0, 1.2, false)
	locker(15, 25, "E")
	lamp(_c(20, 22), "fluo", FlickerLight.Mode.FLICKER, 1.0)
	lamp(_c(23, 23), "fluo", FlickerLight.Mode.OFF, 1.0, 90.0)
	wall_text("GERİ DÖN", Vector3(_c(16, 20).x + 0.5, 1.75, 40.03), 0.0, 140)
	_exit_sign = Label3D.new()
	_exit_sign.text = tr("ÇIKIŞ")
	_exit_sign.font = UiKit.font("ui")
	_exit_sign.font_size = 64
	_exit_sign.pixel_size = 0.004
	_exit_sign.modulate = Color(0.9, 0.12, 0.08)
	_exit_sign.outline_modulate = Color(0.1, 0.0, 0.0)
	_exit_sign.position = Vector3(_c(20, 26).x, 2.7, 51.97)
	_exit_sign.rotation_degrees.y = 180.0
	add_child(_exit_sign)


func _build_corridors() -> void:
	# ana koridor
	lamp(_c(9, 18), "fluo", FlickerLight.Mode.BROKEN, 1.0, 0.0)
	lamp(_c(14, 18), "fluo", FlickerLight.Mode.FLICKER, 1.1, 0.0)
	lamp(_c(20, 18), "fluo", FlickerLight.Mode.STEADY, 0.8, 0.0)
	lamp(_c(25, 18), "fluo", FlickerLight.Mode.OFF, 1.0, 0.0)
	var far := lamp(_c(29, 18), "fluo", FlickerLight.Mode.BROKEN, 1.2, 0.0)
	prop("cardboard_box_01", _c(16, 18, 0.0, -0.65), 10.0, 1.0, false, 0.18)
	prop("cardboard_box_01", _c(16, 18, 0.45, -0.7), 70.0, 1.0, false, 0.18)
	prop("metal_trash_can", _c(22, 18, 0.0, 0.62), 0.0, 1.0, false)
	_wheelchair = prop("wheelchair_01", _c(8, 18, 0.0, -0.45), 90.0, 1.0, false)

	# batı koridoru
	var west := lamp(_c(7, 9), "fluo", FlickerLight.Mode.STEADY, 1.0, 90.0)
	lamp(_c(7, 3), "fluo", FlickerLight.Mode.OFF, 1.0, 90.0)
	lamp(_c(7, 15), "fluo", FlickerLight.Mode.BROKEN, 1.0, 90.0)
	prop("SchoolChair_01", _c(7, 6, 0.6, 0.0), 75.0, 1.0, false)
	prop("vintage_crutches_01", _c(7, 13, -0.85, 0.0), 0.0, 1.0, false)

	# kuzey koridoru
	lamp(_c(12, 1), "fluo", FlickerLight.Mode.BROKEN, 1.0)
	lamp(_c(19, 1), "fluo", FlickerLight.Mode.OFF, 1.0)
	lamp(_c(26, 1), "fluo", FlickerLight.Mode.FLICKER, 0.9)
	pickup("battery", _c(29, 1, 0.5, -0.5))

	# doğu koridoru
	lamp(_c(30, 5), "fluo", FlickerLight.Mode.FLICKER, 1.0, 90.0)
	lamp(_c(30, 13), "fluo", FlickerLight.Mode.STEADY, 0.7, 90.0)
	prop("WetFloorSign_01", _c(30, 8, -0.6, 0.0), 60.0, 1.0, false)

	# ofis koridoru
	lamp(_c(19, 12), "fluo", FlickerLight.Mode.FLICKER, 0.9, 90.0)
	prop("wheelchair_01", _c(19, 15, 0.55, 0.0), 170.0, 1.0, false)

	# --- korku olayları
	# 1) koridorun ucunda bir siluet
	_apparition = NurseBody.new()
	_apparition.position = _c(29, 18, 0.0, 0.0)
	_apparition.rotation.y = PI * 0.5
	_apparition.visible = false
	add_child(_apparition)
	trigger(18, 18, 22, 18, func() -> void:
		if enemy.is_active():
			return
		_apparition.visible = true
		far.set_mode(FlickerLight.Mode.FLICKER)
		Sfx.play_at("static", _apparition.global_position + Vector3.UP * 1.5, -4.0, 0.8)
		get_tree().create_timer(1.7).timeout.connect(func() -> void:
			far.blow_out()
			_apparition.visible = false
			Sfx.play("sting", -10.0)
			Game.show_message("...?", 2.0)))

	# 2) tekerlekli sandalye kendiliğinden yuvarlanır
	trigger(12, 18, 13, 18, func() -> void:
		Sfx.play_at("wheelchair", _wheelchair.global_position, 2.0, 1.0, 25.0)
		var tw := create_tween().set_parallel(true)
		tw.tween_property(_wheelchair, "position", _c(11, 18, 0.0, -0.45), 3.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tw.tween_property(_wheelchair, "rotation_degrees:y", 120.0, 3.0))

	# 3) batı koridorunda lamba patlar
	trigger(7, 11, 7, 12, func() -> void:
		west.blow_out()
		Sfx.play("sting", -14.0))

	# 4) hemşire odasının kapısı kendiliğinden aralanır
	trigger(10, 18, 12, 18, func() -> void:
		var d := door(11, 20)
		if d and not d.is_open:
			d.creep_open(-45.0))


func _ward(x0: int, z0: int, z1: int, beds: Array) -> void:
	for bx in beds:
		prop("old_bed_frame", Vector3(_c(bx, z0).x, 0, z0 * LevelBuilder.CELL + 1.02), 0.0)
		_block([Vector2i(bx, z0)])


func _build_wards() -> void:
	_ward(1, 3, 5, [2, 4])
	_ward(1, 7, 9, [2, 4])
	_ward(1, 11, 13, [2, 4])
	_ward(1, 15, 17, [2, 4])
	_ward(9, 3, 5, [10, 12])
	_ward(9, 7, 9, [10, 12])
	_ward(9, 11, 13, [10, 12])
	_ward(9, 15, 16, [12])

	# Koğuş 1: ilk sigorta
	pickup("fuse", _c(5, 5, -0.2, 0.3))
	prop("wheelchair_01", _c(2, 5), 200.0)
	prop("metal_trash_can", _c(1, 5, -0.4, 0.4), 0.0, 1.0, false)
	# Koğuş 2
	locker(1, 9, "E")
	lamp(_c(3, 8), "fluo", FlickerLight.Mode.BROKEN, 0.9)
	prop("drawer_cabinet", _c(5, 9, 0.7, 0.0), -90.0)
	_block([Vector2i(5, 9)])
	# Koğuş 3: hasta günlüğü
	note("n2", _c(3, 12, 0.3, 0.2))
	pickup("battery", _c(5, 13, -0.2, 0.4))
	prop("SchoolChair_01", _c(3, 13, 0.0, 0.2), 200.0)
	# Koğuş 4
	locker(5, 17, "W")
	lamp(_c(3, 16), "fluo", FlickerLight.Mode.FLICKER, 0.8)
	wall_text("O DUYUYOR", Vector3(2.03, 1.6, _c(1, 16).z), 90.0, 120)
	prop("vintage_crutches_01", _c(1, 17, -0.8, 0.5), 30.0, 1.0, false)
	# Koğuş 5
	locker(9, 3, "E")
	pickup("battery", _c(12, 5, 0.0, 0.3))
	prop("cardboard_box_01", _c(13, 5, 0.3, 0.4), 30.0, 1.0, true, 0.18)
	# Koğuş 6: morg anahtarı
	pickup("key", _c(13, 9, -0.2, 0.3), "morgue", "Morg Anahtarı")
	lamp(_c(11, 8), "fluo", FlickerLight.Mode.STEADY, 0.55, 0.0, Color(0.6, 0.7, 1.0))
	prop("SchoolChair_01", _c(11, 9, 0.0, 0.2), 140.0)
	prop("old_gas_mask", Vector3(_c(9, 8).x - 0.97, 1.8, _c(9, 8).z), 90.0, 1.0, false)
	# Koğuş 7
	locker(13, 13, "W")
	prop("wheelchair_01", _c(10, 13), -30.0)
	# Koğuş 8
	lamp(_c(11, 16), "fluo", FlickerLight.Mode.BROKEN, 0.8)
	prop("wooden_crate_01", _c(9, 16, 0.0, 0.3), 10.0)
	prop("wooden_crate_01", _c(9, 16, 0.05, 0.3, 0.35), -15.0, 1.0, false)


func _build_nurse_station() -> void:
	prop("metal_office_desk", _c(11, 22), 180.0)
	_block([Vector2i(11, 22)])
	pickup("fuse", _c(11, 22, 0.45, 0.0, 0.79))
	note("n3", _c(11, 22, -0.4, 0.1, 0.79))
	lamp(_c(11, 22, -0.8, -0.2, 0.79), "desk", FlickerLight.Mode.STEADY, 0.6)
	prop("SchoolChair_01", _c(11, 23, 0.0, -0.2), 0.0)
	locker(13, 24, "W")
	prop("worn_metal_rack", _c(9, 21, -0.68, 0.0), 90.0)
	_block([Vector2i(9, 21)])
	prop("medical_box", _c(9, 21, -0.68, 0.0, 1.0), 80.0, 1.0, false, 0.04)
	prop("medical_box", _c(10, 24, 0.0, 0.3), 20.0, 1.0, false, 0.04)
	prop("cassette_player", _c(11, 22, 0.1, -0.3, 0.79), 160.0, 1.0, false)


func _build_storage() -> void:
	locker(15, 9, "E")
	prop("worn_metal_rack", _c(17, 9, 0.0, -0.68), 0.0)
	_block([Vector2i(17, 9)])
	prop("cardboard_box_01", _c(17, 9, 0.0, -0.68, 1.2), 20.0, 1.0, false, 0.18)
	prop("wooden_crate_01", _c(15, 13, 0.0, 0.4), 0.0)
	prop("wooden_crate_01", _c(15, 13, 0.0, 0.4, 0.35), 15.0, 1.0, false)
	pickup("battery", _c(15, 13, 0.0, 0.4, 0.7))
	prop("cardboard_box_01", _c(17, 13, 0.2, 0.4), -20.0, 1.0, true, 0.18)
	prop("metal_tool_chest", _c(17, 12, 0.6, 0.0), -90.0, 1.0, true, 0.19)
	note("n4", _c(16, 12, 0.0, 0.0))
	lamp(_c(16, 11), "cage", FlickerLight.Mode.FLICKER, 0.8)
	var rat := prop("street_rat", _c(16, 10, 0.0, 0.0), 0.0, 1.6, false)
	rat.visible = false
	trigger(17, 11, 17, 11, func() -> void:
		rat.visible = true
		Sfx.play_at("rat", rat.global_position, 0.0)
		rat.look_at(_c(15, 13), Vector3.UP)
		rat.rotate_y(PI)
		var tw := create_tween()
		tw.tween_property(rat, "position", _c(15, 12, -0.3, 0.3), 0.7)
		tw.tween_callback(func() -> void: rat.visible = false))


func _build_surgery() -> void:
	metal_table(_c(25, 11), 0.0)
	_block([Vector2i(25, 11)])
	pickup("fuse", _c(25, 11, 0.4, 0.1, 0.9))
	var blood := Mats.plain(Color(0.2, 0.01, 0.01), 0.15)
	box(_c(25, 11, -0.3, 0.0, 0.905), Vector3(0.9, 0.01, 0.6), blood, false)
	prop("caged_hanging_light", Vector3(_c(25, 11).x, LevelBuilder.HEIGHT, _c(25, 11).z), 0.0, 1.3, false)
	var spot := SpotLight3D.new()
	spot.position = Vector3(_c(25, 11).x, LevelBuilder.HEIGHT - 1.0, _c(25, 11).z)
	spot.rotation_degrees.x = -90.0
	spot.spot_angle = 35.0
	spot.spot_range = 4.0
	spot.light_energy = 2.5
	spot.light_color = Color(0.9, 0.95, 1.0)
	spot.shadow_enabled = true
	add_child(spot)
	# yan masa: ofis anahtarı ve rapor
	metal_table(_c(27, 9, 0.0, -0.35), 0.0, 1.3)
	_block([Vector2i(27, 9)])
	pickup("key", _c(27, 9, 0.35, -0.35, 0.9), "office", "Ofis Anahtarı")
	note("n5", _c(27, 9, -0.25, -0.3, 0.9))
	prop("chemistry_set", _c(27, 9, -0.5, -0.45, 0.9), 0.0, 1.0, false)
	prop("industrial_microscope", _c(24, 9, 0.0, -0.45, 0.0), 0.0, 1.0, false)
	prop("medical_box", _c(24, 13, 0.4, 0.3), 30.0, 1.0, false, 0.04)
	prop("metal_tool_chest", _c(26, 12, 0.0, 0.0), 20.0, 1.0, true, 0.19)
	locker(23, 13, "E")
	lamp(_c(27, 12), "fluo", FlickerLight.Mode.OFF, 1.0)
	# televizyon: içeri girince karıncalanır
	var tv := prop("Television_01", _c(28, 13, 0.25, 0.35), -135.0, 1.0)
	var tv_light := OmniLight3D.new()
	tv_light.light_color = Color(0.6, 0.75, 0.9)
	tv_light.omni_range = 4.0
	tv_light.light_energy = 0.0
	tv_light.shadow_enabled = true
	tv.add_child(tv_light)
	tv_light.position = Vector3(0, 0.3, 0.5)
	trigger(27, 10, 28, 12, func() -> void:
		var snd := Sfx.play_at("static", tv.global_position + Vector3.UP * 0.3, 0.0)
		var tw := create_tween()
		for i in 22:
			tw.tween_callback(func() -> void: tv_light.light_energy = randf_range(0.2, 1.6))
			tw.tween_interval(0.09)
		tw.tween_callback(func() -> void:
			tv_light.light_energy = 0.0
			if is_instance_valid(snd):
				snd.stop()))
	wall_text("SESSİZLİK", Vector3(_c(23, 11).x - 0.97, 1.7, _c(23, 11).z), 90.0, 120)


func _build_morgue() -> void:
	# soğutma çekmeceleri
	var steel := Mats.triplanar("metal_rust", 1.0)
	var bank_center := Vector3(70.0, 1.2, 18.45)
	box(bank_center, Vector3(6.0, 2.4, 0.9), steel)
	_block([Vector2i(33, 9), Vector2i(34, 9), Vector2i(35, 9), Vector2i(36, 9)])
	var handle := Mats.plain(Color(0.5, 0.5, 0.48), 0.3, 1.0)
	var seam := Mats.plain(Color(0.02, 0.02, 0.02), 0.9)
	for row in 3:
		for col in 5:
			var p := Vector3(67.6 + col * 1.2, 0.45 + row * 0.75, 18.91)
			if row == 1 and col == 2:
				box(p + Vector3(0, 0, -0.005), Vector3(1.1, 0.68, 0.01), seam, false)
				continue
			box(p, Vector3(1.08, 0.66, 0.02), steel, false)
			box(p + Vector3(0.38, 0, 0.03), Vector3(0.05, 0.16, 0.04), handle, false)
	# kayan çekmece + örtülü ceset
	var drawer := Node3D.new()
	drawer.position = Vector3(67.6 + 2 * 1.2, 1.2, 18.45)
	add_child(drawer)
	var tray := MeshInstance3D.new()
	var tm := BoxMesh.new()
	tm.size = Vector3(1.0, 0.1, 0.9)
	tray.mesh = tm
	tray.material_override = steel
	drawer.add_child(tray)
	var sheet := MeshInstance3D.new()
	var cm := CapsuleMesh.new()
	cm.radius = 0.2
	cm.height = 0.85
	sheet.mesh = cm
	sheet.rotation.x = PI * 0.5
	sheet.position = Vector3(0, 0.15, 0.0)
	sheet.scale = Vector3(1.0, 1.0, 0.55)
	sheet.material_override = Mats.plain(Color(0.62, 0.6, 0.55), 0.95)
	drawer.add_child(sheet)
	trigger(32, 10, 33, 12, func() -> void:
		Sfx.play_at("whisper", drawer.global_position, 0.0, 0.9)
		get_tree().create_timer(1.2).timeout.connect(func() -> void:
			Sfx.play_at("locker_open", drawer.global_position, 2.0, 0.6)
			var tw := create_tween()
			tw.tween_property(drawer, "position:z", 19.4, 0.35).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)))

	metal_table(_c(35, 12), 0.0)
	_block([Vector2i(35, 12)])
	pickup("fuse", _c(35, 12, 0.5, 0.1, 0.9))
	note("n6", _c(35, 12, -0.5, 0.0, 0.9))
	metal_table(_c(33, 12), 0.0)
	_block([Vector2i(33, 12)])
	var body := MeshInstance3D.new()
	var bm := CapsuleMesh.new()
	bm.radius = 0.24
	bm.height = 1.8
	body.mesh = bm
	body.rotation.z = PI * 0.5
	body.scale = Vector3(1.0, 1.0, 0.6)
	body.position = _c(33, 12, 0.0, 0.0, 1.05)
	body.material_override = Mats.plain(Color(0.58, 0.56, 0.5), 0.95)
	add_child(body)
	var hand := MeshInstance3D.new()
	var hm := CylinderMesh.new()
	hm.top_radius = 0.03
	hm.bottom_radius = 0.025
	hm.height = 0.45
	hand.mesh = hm
	hand.position = _c(33, 12, 0.5, 0.42, 0.75)
	hand.rotation.x = 0.15
	hand.material_override = Mats.plain(Color(0.42, 0.42, 0.38), 0.5)
	add_child(hand)
	pickup("battery", _c(32, 13, -0.3, 0.4))
	locker(37, 13, "W")
	lamp(_c(34, 11), "fluo", FlickerLight.Mode.FLICKER, 0.9, 0.0, Color(0.7, 0.85, 1.0))
	lamp(_c(36, 11), "fluo", FlickerLight.Mode.OFF, 1.0)


func _build_office() -> void:
	prop("metal_office_desk", _c(19, 4), 180.0)
	_block([Vector2i(19, 4)])
	pickup("fuse", _c(19, 4, 0.55, 0.05, 0.79))
	note("n7", _c(19, 4, -0.35, 0.1, 0.79))
	lamp(_c(19, 4, -0.8, -0.2, 0.79), "desk", FlickerLight.Mode.STEADY, 0.7)
	var player_box := prop("cassette_player", _c(19, 4, 0.1, -0.25, 0.79), 200.0, 1.0, false)
	prop("SchoolChair_01", _c(19, 3, 0.0, 0.1), 180.0)
	prop("drawer_cabinet", _c(15, 3, -0.72, 0.3), 90.0)
	_block([Vector2i(15, 3)])
	prop("vintage_cabinet_01", _c(16, 3, 1.0, -0.62), 0.0, 1.0, true, 0.34)
	_block([Vector2i(16, 3), Vector2i(17, 3)])
	prop("wall_clock", Vector3(_c(21, 3).x, 2.3, 6.03), 0.0, 1.0, false)
	locker(23, 3, "W")
	box(_c(21, 6, 0.0, 0.45, 0.375), Vector3(0.9, 0.75, 0.6), Mats.triplanar("door_wood", 1.0))
	_block([Vector2i(21, 6)])
	pickup("key", _c(21, 6, 0.1, 0.45, 0.76), "basement", "Bodrum Anahtarı")
	prop("Television_01", _c(23, 6, 0.0, 0.3), -160.0)
	lamp(_c(16, 5), "fluo", FlickerLight.Mode.OFF, 1.0)
	wall_text("HASTALARIM BENİM", Vector3(_c(19, 3).x, 2.2, 6.03), 0.0, 90)
	trigger(18, 6, 20, 6, func() -> void:
		_music_box = Sfx.attach_loop("music_box", player_box, -2.0, 3.0, 25.0, false)
		_music_box.play()
		get_tree().create_timer(26.0).timeout.connect(func() -> void:
			if is_instance_valid(_music_box):
				_music_box.stop()))


func _build_basement() -> void:
	var gen := Generator.new()
	gen.position = _c(37, 24, 0.1, 0.3)
	gen.rotation_degrees.y = -90.0
	add_child(gen)
	_block([Vector2i(37, 24)])
	prop("power_box_01", Vector3(77.95, 1.5, _c(38, 23).z), -90.0, 1.4, false)
	locker(38, 17, "W")
	note("n8", _c(33, 25, 0.0, 0.3))
	pickup("battery", _c(33, 17, -0.3, -0.2))
	prop("metal_tool_chest", _c(32, 21, -0.5, 0.0), 90.0, 1.0, true, 0.19)
	prop("wooden_crate_01", _c(38, 20, 0.3, 0.0), 90.0)
	prop("wooden_crate_01", _c(38, 20, 0.3, 0.0, 0.35), 75.0, 1.0, false)
	prop("cardboard_box_01", _c(38, 21, 0.4, 0.2), 10.0, 1.0, true, 0.18)
	prop("worn_metal_rack", _c(32, 24, -0.68, 0.0), 90.0)
	_block([Vector2i(32, 24)])
	prop("signal_flashlight", _c(33, 25, 0.5, 0.4), 70.0, 1.0, false, 0.04)
	# tavan boruları
	var rust := Mats.triplanar("metal_rust", 1.0)
	for pz in [34.6, 41.4, 47.4]:
		var pipe := MeshInstance3D.new()
		var pm := CylinderMesh.new()
		pm.top_radius = 0.09
		pm.bottom_radius = 0.09
		pm.height = 14.0
		pipe.mesh = pm
		pipe.rotation.z = PI * 0.5
		pipe.position = Vector3(71.0, 2.9, pz)
		pipe.material_override = rust
		add_child(pipe)
	lamp(_c(33, 17), "cage", FlickerLight.Mode.STEADY, 0.7)
	var b2 := lamp(_c(37, 20), "cage", FlickerLight.Mode.FLICKER, 0.9)
	lamp(_c(33, 23), "cage", FlickerLight.Mode.BROKEN, 0.8)
	lamp(_c(36, 24), "cage", FlickerLight.Mode.STEADY, 0.6)
	wall_text("IŞIĞI KAPAT", Vector3(64.03, 1.7, _c(32, 20).z), 90.0, 120)
	trigger(32, 16, 33, 17, func() -> void:
		Sfx.play_at("metal_bang", _c(37, 23, 0, 0, 2.0), 4.0, 0.8, 40.0)
		b2.set_mode(FlickerLight.Mode.BROKEN))


func _build_emergency_lights() -> void:
	var cells := [Vector2i(30, 4), Vector2i(30, 11), Vector2i(30, 17), Vector2i(26, 18), Vector2i(20, 18),
		Vector2i(13, 18), Vector2i(20, 23), Vector2i(34, 20), Vector2i(36, 23), Vector2i(7, 10),
		Vector2i(19, 12), Vector2i(16, 1), Vector2i(7, 2)]
	for c in cells:
		var l := FlickerLight.new()
		l.position = _c(c.x, c.y, 0, 0, LevelBuilder.HEIGHT - 0.25)
		l.light_color = Color(1.0, 0.08, 0.04)
		l.base_energy = 1.6
		l.omni_range = 7.0
		l.shadow_enabled = false
		l.light_volumetric_fog_energy = 2.0
		l.mode = FlickerLight.Mode.OFF
		var lens := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.08
		sm.height = 0.1
		lens.mesh = sm
		var em := Mats.plain(Color(0.3, 0.0, 0.0), 0.3, 0.0, Color(1.0, 0.05, 0.02), 0.0)
		lens.material_override = em
		lens.position = Vector3(0, 0.18, 0)
		l.add_child(lens)
		l.emissive = em
		l.emissive_base = 6.0
		add_child(l)
		_emergency.append(l)


func _build_decals() -> void:
	_blood_tex = _make_blood_texture()
	var spots := [
		[_c(20, 21, -0.3, 0.6), 1.6], [_c(16, 18, 0.0, 0.2), 2.4], [_c(7, 11), 1.8],
		[_c(25, 12), 2.2], [_c(34, 11), 2.6], [_c(3, 4, 0.5), 1.4], [_c(11, 12), 1.6],
		[_c(30, 15), 2.0], [_c(35, 23), 2.2], [_c(19, 5), 1.5], [_c(12, 22), 1.6],
	]
	for s in spots:
		var d := Decal.new()
		d.texture_albedo = _blood_tex
		var sz: float = s[1]
		d.size = Vector3(sz, 0.6, sz * randf_range(0.6, 1.4))
		d.position = s[0]
		d.rotation.y = randf() * TAU
		d.modulate = Color(0.55, 0.05, 0.03, 0.9)
		d.albedo_mix = 1.0
		d.upper_fade = 0.1
		d.lower_fade = 0.1
		add_child(d)


func _make_blood_texture() -> Texture2D:
	var n := 128
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	var noise := FastNoiseLite.new()
	noise.seed = 9
	noise.frequency = 0.06
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var blobs: Array[Vector3] = []
	for i in 9:
		blobs.append(Vector3(rng.randf_range(0.25, 0.75), rng.randf_range(0.25, 0.75), rng.randf_range(0.05, 0.22)))
	for y in n:
		for x in n:
			var u := Vector2(float(x) / n, float(y) / n)
			var v := 0.0
			for b in blobs:
				var d := u.distance_to(Vector2(b.x, b.y))
				v = maxf(v, 1.0 - d / b.z)
			v += noise.get_noise_2d(x, y) * 0.5
			var a := clampf((v - 0.3) * 3.0, 0.0, 1.0)
			var edge := clampf(1.0 - absf(v - 0.4) * 6.0, 0.0, 1.0) * 0.3
			img.set_pixel(x, y, Color(0.6 - edge, 0.04, 0.03, a))
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


# ---------------------------------------------------------------- oyun akışı

func on_item_picked(item: Pickup) -> void:
	if item.kind != "fuse":
		return
	if Game.fuses == 1:
		_wake_enemy(item.global_position)
	if Game.fuses == 3:
		_mid_scare()
	if Game.fuses >= Game.FUSES_NEEDED:
		Game.set_objective(tr("Tüm sigortalar sende. Bodrumdaki jeneratörü çalıştır."))
	else:
		Game.set_objective(tr("Sigortaları bul (%d/%d) ve bodrumdaki jeneratörü çalıştır.") % [Game.fuses, Game.FUSES_NEEDED])


func _wake_enemy(at: Vector3) -> void:
	var d := door(6, 4)
	if d and LevelBuilder.world_to_cell(at).x <= 5:
		get_tree().create_timer(0.4).timeout.connect(func() -> void:
			if not d.is_open:
				d.force_open_wide(-60.0)
			d.slam())
	get_tree().create_timer(2.0).timeout.connect(func() -> void:
		enemy.activate(_c(19, 10))
		Sfx.play_at("nurse_alert", player.global_position + Vector3(8, 2, -6), -2.0, 0.75, 60.0)
		Sfx.play("sting", -6.0)
		for l in _lights:
			if l.mode == FlickerLight.Mode.STEADY:
				l.set_mode(FlickerLight.Mode.FLICKER)
		if hud:
			hud.pulse_glitch(1.0)
		Game.show_message(tr("Bir şey uyandı. Sessiz ol."), 4.0))


func _mid_scare() -> void:
	Sfx.play("whisper", -6.0, 0.8)
	for l in _lights:
		if l.mode != FlickerLight.Mode.OFF:
			l.set_mode(FlickerLight.Mode.BROKEN)
	get_tree().create_timer(6.0).timeout.connect(func() -> void:
		for l in _lights:
			if l.mode == FlickerLight.Mode.BROKEN:
				l.set_mode(FlickerLight.Mode.FLICKER))


func on_note_read(id: String) -> void:
	if id == "n1" and Game.fuses == 0:
		Game.set_objective(tr("Ana kapı elektrikle kilitli. Elektriği geri getirmenin bir yolunu bul."))


func on_exit_tried() -> void:
	Game.show_message(tr("Kapı elektronik kilitli. Elektrik olmadan açılmıyor."), 3.0)
	if Game.fuses == 0:
		Game.set_objective(tr("Ana kapı elektrikle kilitli. Elektriği geri getirmenin bir yolunu bul."))


func on_door_unlocked(d: Door) -> void:
	astar.set_point_solid(d.cell, false)
	if _locked_patrol.has(d.key_id):
		for c in _locked_patrol[d.key_id]:
			patrol_points.append(LevelBuilder.cell_center(c.x, c.y))


func on_chase_started() -> void:
	if hud:
		hud.pulse_glitch(0.7)


func restore_power() -> void:
	Game.power_on = true
	for l in _emergency:
		l.set_mode(FlickerLight.Mode.STEADY)
	for l in _lights:
		l.set_mode(FlickerLight.Mode.FLICKER)
	for p in [_c(20, 22, 0, 0, 2.8), _c(19, 18, 0, 0, 2.8), _c(30, 10, 0, 0, 2.8), _c(35, 20, 0, 0, 2.8)]:
		var host := Node3D.new()
		host.position = p
		add_child(host)
		Sfx.attach_loop("alarm", host, -4.0, 5.0, 45.0)
	_exit_sign.modulate = Color(0.15, 1.0, 0.3)
	_exit_sign.shaded = false
	var green := OmniLight3D.new()
	green.position = _exit_sign.position + Vector3(0, 0, -0.5)
	green.light_color = Color(0.2, 1.0, 0.35)
	green.light_energy = 1.2
	green.omni_range = 5.0
	add_child(green)
	if is_instance_valid(_music_box):
		_music_box.stop()
	player.adrenaline = 12.0
	player.stamina = 100.0
	player.exhausted = false
	Game.set_objective(tr("KOŞ! Lobideki ana kapıya git!"))
	Game.show_message(tr("Elektrik geldi... ve alarmlar O'nu uyandırdı. KOŞ!"), 4.0)
	hud.pulse_glitch(1.0)
	get_tree().create_timer(1.0).timeout.connect(func() -> void:
		enemy.final_hunt(_c(35, 11)))


func on_exit_opened() -> void:
	if Game.game_over:
		return
	Game.game_over = true
	player.frozen = true
	var d := door(20, 26)
	if d:
		d.locked = false
		d.open_from(player.global_position, false)
	Sfx.play("door_slam", -2.0, 0.7)
	enemy.set_physics_process(false)
	hud.fade_out(2.0)
	get_tree().create_timer(2.3).timeout.connect(func() -> void:
		enemy.visible = false
		hud.show_end(true))


func on_player_dead() -> void:
	Game.game_over = true
	hud.show_end(false)

class_name Note
extends StaticBody3D
## Okunabilir kâğıt not. Hikâyeyi anlatır.

static var _paper_tex: Texture2D

var note_id := ""
var title := ""
var body := ""


func _ready() -> void:
	collision_layer = 8
	collision_mask = 0
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(0.3, 0.1, 0.36)
	cs.shape = sh
	add_child(cs)

	var mi := MeshInstance3D.new()
	var q := PlaneMesh.new()
	q.size = Vector2(0.21, 0.297)
	mi.mesh = q
	var m := StandardMaterial3D.new()
	m.albedo_texture = _get_paper_texture()
	m.roughness = 0.95
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.emission_enabled = true
	m.emission = Color(0.25, 0.23, 0.18)
	m.emission_energy_multiplier = 0.15
	mi.material_override = m
	mi.position = Vector3(0, 0.004, 0)
	mi.rotation.y = randf_range(-0.5, 0.5)
	add_child(mi)


func get_prompt() -> String:
	return tr("Oku: %s") % tr(title)


func interact(_player: Node3D) -> void:
	Sfx.play("paper", -4.0)
	Game.read_note(note_id)
	if Game.hud:
		Game.hud.show_note(tr(title), tr(body))
	if Game.level:
		Game.level.on_note_read(note_id)


## Üzerinde el yazısı satırları ve lekeler olan prosedürel kâğıt dokusu.
static func _get_paper_texture() -> Texture2D:
	if _paper_tex:
		return _paper_tex
	var w := 128
	var h := 180
	var img := Image.create(w, h, false, Image.FORMAT_RGB8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	for y in h:
		for x in w:
			var n := rng.randf() * 0.06
			img.set_pixel(x, y, Color(0.78 - n, 0.74 - n, 0.62 - n))
	var y0 := 16
	while y0 < h - 14:
		var line_len := rng.randi_range(60, 104)
		var x := 12
		while x < 12 + line_len:
			var word := rng.randi_range(4, 14)
			for i in word:
				var yy := y0 + int(sin((x + i) * 0.9) * 1.2)
				img.set_pixel(clampi(x + i, 0, w - 1), clampi(yy, 0, h - 1), Color(0.12, 0.1, 0.12))
			x += word + rng.randi_range(3, 5)
		y0 += 8
	# kahverengi leke
	var cx := rng.randi_range(30, 100)
	var cy := rng.randi_range(40, 150)
	for y in h:
		for x in w:
			var d := Vector2(x - cx, (y - cy) * 0.8).length()
			if d < 22.0:
				var c := img.get_pixel(x, y)
				img.set_pixel(x, y, c.lerp(Color(0.45, 0.3, 0.18), 0.35 * (1.0 - d / 22.0)))
	img.generate_mipmaps()
	_paper_tex = ImageTexture.create_from_image(img)
	return _paper_tex

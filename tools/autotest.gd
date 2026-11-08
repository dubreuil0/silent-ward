extends Node
## Geliştirme aracı: `-- --autotest=A|B|C` ile oyun akışını otomatik doğrular.
## A: eşyalar, kilitler, jeneratör, çıkış. B: düşman görür ve yakalar. C: dolapta saklanma + yol bulma.

var mode := "A"
var fails := 0


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--autotest="):
			mode = a.substr(11)
	await get_tree().create_timer(1.0).timeout
	match mode:
		"A":
			await _test_progression()
		"B":
			await _test_chase()
		"C":
			await _test_hide_and_paths()
		"D":
			await _test_patrol_soak()
	print("AUTOTEST %s: %s (%d hata)" % [mode, "BAŞARILI" if fails == 0 else "BAŞARISIZ", fails])
	get_tree().quit()


func check(cond: bool, what: String) -> void:
	print(("  [OK]   " if cond else "  [FAIL] ") + what)
	if not cond:
		fails += 1


func _test_progression() -> void:
	var lvl := Game.level
	var p := Game.player as Player
	check(p.is_on_floor() and absf(p.global_position.y) < 0.2, "oyuncu zeminde (y=%.2f)" % p.global_position.y)

	Input.action_press("move_forward")
	var z0 := p.global_position.z
	await get_tree().create_timer(1.0).timeout
	Input.action_release("move_forward")
	check(z0 - p.global_position.z > 1.5, "ileri yürüme (%.2f m)" % (z0 - p.global_position.z))

	var notes := lvl.find_children("*", "Note", true, false)
	check(notes.size() == Game.NOTES_TOTAL, "not sayısı %d" % notes.size())
	for n in notes:
		n.interact(p)
		Game.hud.close_note()
	check(Game.notes_read.size() == Game.NOTES_TOTAL, "tüm notlar okundu")

	var pickups := lvl.find_children("*", "Pickup", true, false)
	var counts := {}
	for it in pickups:
		counts[it.kind] = counts.get(it.kind, 0) + 1
	print("  eşyalar: ", counts)
	for it in pickups:
		if it.kind == "fuse" and Game.fuses == 0:
			p.global_position = it.global_position + Vector3(0.6, 0, 0)
		it.interact(p)
	await get_tree().create_timer(3.0).timeout
	check(Game.fuses == 5, "5 sigorta toplandı (%d)" % Game.fuses)
	check(Game.keys.size() == 3, "3 anahtar toplandı (%d)" % Game.keys.size())
	check(lvl.enemy.is_active(), "ilk sigortadan sonra Hemşire uyandı")

	for d: Door in lvl.doors:
		if d.key_id != "":
			d.interact(p)
			check(not d.locked and not lvl.astar.is_point_solid(d.cell), "kapı açıldı: %s" % d.key_name)

	var gen := lvl.find_children("*", "Generator", true, false)[0] as Generator
	gen.interact(p)
	await get_tree().create_timer(5.5).timeout
	check(Game.power_on, "jeneratör elektriği verdi")
	check(lvl.enemy.state == Nurse.State.FINAL, "final kovalaması başladı (durum %d)" % lvl.enemy.state)

	p.global_position = LevelBuilder.cell_center(20, 25)
	var exit_door: Door = lvl.door(20, 26)
	exit_door.interact(p)
	await get_tree().create_timer(3.0).timeout
	check(Game.game_over and not p.dead, "çıkış kapısından kaçıldı")


func _test_chase() -> void:
	var lvl := Game.level
	var p := Game.player as Player
	p.global_position = LevelBuilder.cell_center(14, 18)
	p.rotation.y = -PI * 0.5
	p.flashlight_on = true
	lvl.enemy.activate(LevelBuilder.cell_center(24, 18))
	var saw_chase := false
	for i in 200:
		await get_tree().create_timer(0.1).timeout
		if lvl.enemy.state == Nurse.State.CHASE:
			saw_chase = true
		if p.dead:
			break
	check(saw_chase, "Hemşire oyuncuyu fark edip kovaladı")
	check(p.dead, "Hemşire oyuncuyu yakaladı")
	await get_tree().create_timer(3.0).timeout
	check(Game.game_over, "ölüm ekranı gösterildi")


## Hemşire uzun süre devriye gezer; takılma ve hata olmamalı.
func _test_patrol_soak() -> void:
	var lvl := Game.level
	var p := Game.player as Player
	p.global_position = LevelBuilder.cell_center(17, 24)
	p.frozen = true
	Engine.time_scale = 4.0
	lvl.enemy.activate(LevelBuilder.cell_center(7, 2))
	var travelled := 0.0
	var last: Vector3 = lvl.enemy.global_position
	var visited := {}
	var states := {}
	for i in 300:
		await get_tree().create_timer(0.4).timeout
		var e: Nurse = lvl.enemy
		travelled += e.global_position.distance_to(last)
		last = e.global_position
		visited[LevelBuilder.world_to_cell(e.global_position)] = true
		states[e.state] = true
		if p.dead:
			break
	Engine.time_scale = 1.0
	print("  yol: %.0f m, ziyaret edilen hücre: %d, durumlar: %s, oyuncu öldü: %s" % [travelled, visited.size(), states.keys(), p.dead])
	check(travelled > 150.0, "Hemşire devriyede hareket etti")
	check(visited.size() > 40, "Hemşire haritanın farklı yerlerini dolaştı")


func _test_hide_and_paths() -> void:
	var lvl := Game.level
	var p := Game.player as Player
	var empty := 0
	for a in lvl.patrol_points:
		for b in lvl.patrol_points:
			if a != b and lvl.find_path(a, b).is_empty():
				empty += 1
	check(empty == 0, "tüm devriye noktaları arası yol var (boş: %d)" % empty)

	# Hemşire uzaktayken dolaba girip nefes tutmadan beklemek: yakına gelirse bulur.
	var locker: Locker = null
	for l in lvl.find_children("*", "Locker", true, false):
		if LevelBuilder.world_to_cell(l.global_position) == Vector2i(15, 25):
			locker = l
	check(locker != null, "lobi dolabı bulundu")
	p.global_position = locker.exit_position()
	locker.interact(p)
	await get_tree().create_timer(0.5).timeout
	check(p.hidden_in == locker, "oyuncu dolaba girdi")
	lvl.enemy.activate(LevelBuilder.cell_center(17, 25))
	lvl.enemy._go_to(locker.exit_position() + Vector3(0.6, 0, 0))
	for i in 80:
		await get_tree().create_timer(0.1).timeout
		if p.dead:
			break
	check(p.dead, "nefes tutmayan saklı oyuncu bulundu")

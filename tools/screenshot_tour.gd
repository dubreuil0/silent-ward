extends Node
## Geliştirme aracı: oyunu `-- --shots=KLASÖR` ile başlatınca belirli noktalardan
## ekran görüntüsü alır ve çıkar. Normal oyunda hiç yüklenmez.

var out_dir := ""
var shots := [
	# [hücre x, z, yaw (derece, 0 = kuzey), pitch, fener, ad]
	[20, 24, 0.0, 0.0, true, "01_lobby"],
	[18, 23, 30.0, -15.0, true, "02_reception"],
	[7, 4, 90.0, -5.0, true, "03_ward_door"],
	[3, 13, 0.0, -10.0, true, "04_ward"],
	[4, 5, -60.0, -45.0, true, "05_fuse"],
	[17, 24, 120.0, -5.0, true, "06_locker"],
	[19, 6, 0.0, -15.0, true, "07_office"],
	[33, 17, -150.0, 0.0, true, "08_basement"],
	[20, 21, 0.0, 0.0, false, "09_lobby_dark"],
	[12, 18, 90.0, 8.0, true, "10_nurse"],
]


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots="):
			out_dir = a.substr(8)
	DirAccess.make_dir_recursive_absolute(out_dir)
	await get_tree().create_timer(3.5).timeout
	var lvl := Game.level
	var p := Game.player as Player
	for s in shots:
		if s[5] == "10_nurse":
			lvl.enemy.activate(LevelBuilder.cell_center(10, 18) + Vector3(0.6, 0, 0))
			lvl.enemy.set_physics_process(false)
			lvl.enemy.rotation.y = -PI * 0.5
		p.global_position = LevelBuilder.cell_center(s[0], s[1])
		p.rotation.y = deg_to_rad(s[2])
		p.head.rotation.x = deg_to_rad(s[3])
		p.flashlight_on = s[4]
		p.battery = 100.0
		await get_tree().create_timer(1.2).timeout
		_save(s[5])
	# arayüz ekranları
	lvl.enemy.global_position = LevelBuilder.cell_center(2, 20) + Vector3(0, -40, 0)
	p.global_position = LevelBuilder.cell_center(18, 24)
	p.rotation.y = 0.0
	p.head.rotation.x = 0.0
	Game.hud.show_note(tr("note.n2.title"), tr("note.n2.body"))
	await get_tree().create_timer(0.6).timeout
	_save("11_note")
	Game.hud.close_note()
	var locker: Locker = null
	for l in lvl.find_children("*", "Locker", true, false):
		if LevelBuilder.world_to_cell(l.global_position) == Vector2i(15, 25):
			locker = l
	p.global_position = locker.exit_position()
	locker.interact(p)
	lvl.enemy.global_position = LevelBuilder.cell_center(18, 25)
	lvl.enemy.rotation.y = PI * 0.5
	await get_tree().create_timer(1.2).timeout
	_save("12_locker")
	p.exit_locker()
	lvl.enemy.set_physics_process(true)
	lvl.enemy._kill(p)
	await get_tree().create_timer(0.7).timeout
	_save("13_jumpscare")
	await get_tree().create_timer(4.5).timeout
	_save("14_death")
	get_tree().quit()


func _save(shot_name: String) -> void:
	var img := get_viewport().get_texture().get_image()
	img.save_png(out_dir.path_join(shot_name + ".png"))

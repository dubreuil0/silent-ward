extends Node
## Ses yöneticisi (autoload: Sfx). Bus düzenini kurar, üretilmiş sesleri çalar.

const AUDIO_DIR := "res://assets/audio/"

var _cache: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_buses()


func _setup_buses() -> void:
	if AudioServer.get_bus_index("SFX") != -1:
		return
	for bus_name in ["SFX", "Ambient", "Music", "UI"]:
		AudioServer.add_bus()
		var i := AudioServer.bus_count - 1
		AudioServer.set_bus_name(i, bus_name)
		AudioServer.set_bus_send(i, "Master")
	var rev := AudioEffectReverb.new()
	rev.room_size = 0.78
	rev.damping = 0.35
	rev.spread = 0.9
	rev.wet = 0.24
	rev.dry = 1.0
	AudioServer.add_bus_effect(AudioServer.get_bus_index("SFX"), rev)
	var rev2 := AudioEffectReverb.new()
	rev2.room_size = 0.9
	rev2.wet = 0.35
	rev2.dry = 0.8
	AudioServer.add_bus_effect(AudioServer.get_bus_index("Ambient"), rev2)
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Music"), -4.0)
	AudioServer.add_bus_effect(0, AudioEffectHardLimiter.new())


func stream(sound: String) -> AudioStream:
	if not _cache.has(sound):
		_cache[sound] = load(AUDIO_DIR + sound + ".res")
	return _cache[sound]


## Konumsuz (2D) ses çalar.
func play(sound: String, volume_db := 0.0, pitch := 1.0, bus := "SFX") -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.stream = stream(sound)
	p.volume_db = volume_db
	p.pitch_scale = pitch
	p.bus = bus
	add_child(p)
	p.play()
	p.finished.connect(p.queue_free)
	return p


## Dünyada bir konumda 3D ses çalar.
func play_at(sound: String, pos: Vector3, volume_db := 0.0, pitch := 1.0, max_distance := 35.0, unit_size := 4.0) -> AudioStreamPlayer3D:
	var host := get_tree().current_scene
	if host == null:
		return null
	var p := AudioStreamPlayer3D.new()
	p.stream = stream(sound)
	p.volume_db = volume_db
	p.pitch_scale = pitch
	p.max_distance = max_distance
	p.unit_size = unit_size
	p.bus = "SFX"
	p.attenuation_filter_cutoff_hz = 6000.0
	host.add_child(p)
	p.global_position = pos
	p.play()
	p.finished.connect(p.queue_free)
	return p


## Bir düğüme bağlı sürekli (döngü) 3D ses oluşturur.
func attach_loop(sound: String, parent: Node3D, volume_db := 0.0, unit_size := 3.0, max_distance := 25.0, autoplay := true) -> AudioStreamPlayer3D:
	var p := AudioStreamPlayer3D.new()
	p.stream = stream(sound)
	p.volume_db = volume_db
	p.unit_size = unit_size
	p.max_distance = max_distance
	p.bus = "SFX"
	p.attenuation_filter_cutoff_hz = 5000.0
	parent.add_child(p)
	if autoplay:
		p.play(randf() * 1.5)
	return p


func random_variant(prefix: String, count: int) -> String:
	return "%s_%d" % [prefix, randi() % count]

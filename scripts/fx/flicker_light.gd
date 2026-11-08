class_name FlickerLight
extends OmniLight3D
## Bozuk floresan / lamba davranışı. İsteğe bağlı emisyonlu materyal ve vızıltı sesini senkronlar.

enum Mode { STEADY, FLICKER, BROKEN, OFF }

var mode := Mode.STEADY
var base_energy := 1.0
var emissive: StandardMaterial3D
var emissive_base := 3.0
var buzz: AudioStreamPlayer3D

var _timer := 0.0
var _level := 1.0
var _target := 1.0
var _override := -1.0


func _ready() -> void:
	_timer = randf() * 2.0


func _process(delta: float) -> void:
	if _override >= 0.0:
		_apply(_override)
		return
	_timer -= delta
	match mode:
		Mode.STEADY:
			_target = 1.0 - randf() * 0.04
		Mode.FLICKER:
			if _timer <= 0.0:
				if randf() < 0.08:
					_timer = randf_range(0.4, 1.4)
					_target = 0.0
				else:
					_timer = randf_range(0.03, 0.22)
					_target = 1.0 if randf() > 0.35 else randf_range(0.05, 0.4)
		Mode.BROKEN:
			if _timer <= 0.0:
				if _target > 0.0:
					_target = 0.0
					_timer = randf_range(1.5, 6.0)
				else:
					_target = randf_range(0.5, 1.0)
					_timer = randf_range(0.03, 0.12)
		Mode.OFF:
			_target = 0.0
	_level = _target
	_apply(_level)


func _apply(v: float) -> void:
	light_energy = base_energy * v
	visible = v > 0.001
	if emissive:
		emissive.emission_energy_multiplier = emissive_base * v
	if buzz:
		var want := v > 0.05
		if want and not buzz.playing:
			buzz.play()
		elif not want and buzz.playing:
			buzz.stop()


## Lamba patlar: kısa parlama, kıvılcım ve karanlık.
func blow_out() -> void:
	Sfx.play_at("spark", global_position, 4.0)
	_override = 3.0
	get_tree().create_timer(0.08).timeout.connect(func() -> void:
		_override = 0.0
		mode = Mode.OFF)


func set_mode(m: Mode) -> void:
	mode = m
	_override = -1.0

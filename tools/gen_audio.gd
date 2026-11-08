extends SceneTree
## Geliştirme aracı: oyundaki tüm sesleri prosedürel olarak üretir ve
## res://assets/audio/*.res olarak kaydeder.
## godot --headless --path . --script res://tools/gen_audio.gd

const SR := 32000
const OUT := "res://assets/audio/"

var rng := RandomNumberGenerator.new()


class SVF:
	## Durum değişkenli filtre (low / band / high çıkışlı).
	var low := 0.0
	var band := 0.0
	var high := 0.0
	var f := 0.1
	var q := 1.0

	func _init(fc: float, res_q: float) -> void:
		set_freq(fc)
		q = 1.0 / maxf(res_q, 0.05)

	func set_freq(fc: float) -> void:
		f = 2.0 * sin(PI * clampf(fc, 10.0, SR * 0.22) / SR)

	func process(x: float) -> float:
		low += f * band
		high = x - low - q * band
		band += f * high
		return band


func _init() -> void:
	rng.seed = 1987
	DirAccess.make_dir_recursive_absolute(OUT)
	var t0 := Time.get_ticks_msec()
	_generate_all()
	print("Ses üretimi tamamlandı: %d ms" % (Time.get_ticks_msec() - t0))
	quit()


# ---------------------------------------------------------------- yardımcılar

func ns(sec: float) -> int:
	return int(sec * SR)


func make(sec: float) -> PackedFloat32Array:
	var b := PackedFloat32Array()
	b.resize(ns(sec))
	return b


func nz() -> float:
	return rng.randf_range(-1.0, 1.0)


func lp_k(fc: float) -> float:
	return 1.0 - exp(-TAU * fc / SR)


func save(name: String, b: PackedFloat32Array, loop := false, gain := 0.9) -> void:
	var peak := 0.0001
	for v in b:
		peak = maxf(peak, absf(v))
	var k := gain / peak
	var data := PackedByteArray()
	data.resize(b.size() * 2)
	for i in b.size():
		data.encode_s16(i * 2, int(clampf(b[i] * k, -1.0, 1.0) * 32767.0))
	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = SR
	s.stereo = false
	s.data = data
	if loop:
		s.loop_mode = AudioStreamWAV.LOOP_FORWARD
		s.loop_begin = 0
		s.loop_end = b.size()
	var err := ResourceSaver.save(s, OUT + name + ".res")
	if err != OK:
		push_error("Kaydedilemedi: " + name)


## Uzun üretilmiş tamponun sonunu başına çapraz geçişle karıştırıp kusursuz döngü yapar.
func crossfade_loop(b: PackedFloat32Array, length_sec: float, fade_sec: float) -> PackedFloat32Array:
	var n := ns(length_sec)
	var f := ns(fade_sec)
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		out[i] = b[i]
	for i in f:
		var a := float(i) / f
		out[i] = b[i] * a + b[n + i] * (1.0 - a)
	return out


## Döngü sınırını taşan kuyrukları başa ekler (olay tabanlı müzik için).
func wrap_loop(b: PackedFloat32Array, length_sec: float) -> PackedFloat32Array:
	var n := ns(length_sec)
	var out := PackedFloat32Array()
	out.resize(n)
	for i in b.size():
		out[i % n] += b[i]
	return out


func add_burst(b: PackedFloat32Array, start: float, decay: float, fc: float, q: float, amp: float) -> void:
	var f := SVF.new(fc, q)
	var s := ns(start)
	var cnt := mini(ns(decay * 8.0), b.size() - s)
	for i in cnt:
		var t := float(i) / SR
		var env := exp(-t / decay) * minf(1.0, t / 0.0015)
		b[s + i] += f.process(nz() * env) * amp


func add_tone(b: PackedFloat32Array, start: float, freq: float, decay: float, amp: float, drop := 0.0) -> void:
	var s := ns(start)
	var cnt := mini(ns(decay * 8.0), b.size() - s)
	var ph := 0.0
	for i in cnt:
		var t := float(i) / SR
		var fr := freq * (1.0 + drop * exp(-t / 0.03))
		ph += TAU * fr / SR
		b[s + i] += sin(ph) * exp(-t / decay) * minf(1.0, t / 0.002) * amp


func add_partials(b: PackedFloat32Array, start: float, partials: Array, amp: float) -> void:
	# partials: [[freq, decay, gain], ...]
	for p in partials:
		add_tone(b, start, p[0], p[1], amp * p[2])


# ---------------------------------------------------------------- sesler

func _generate_all() -> void:
	for i in 3:
		gen_step("step_tile_%d" % i, 2600.0, 1.3, 0.022, 110.0, 0.45)
		gen_step("step_wood_%d" % i, 650.0, 2.2, 0.045, 85.0, 0.9)
		gen_step("step_concrete_%d" % i, 1300.0, 0.8, 0.03, 80.0, 0.6)
		gen_step("step_soft_%d" % i, 850.0, 0.7, 0.035, 70.0, 0.5)
	for i in 2:
		gen_enemy_step("enemy_step_%d" % i)
	gen_door_open()
	gen_door_close()
	gen_door_slam()
	gen_door_locked()
	gen_unlock()
	gen_pickup()
	gen_key_pickup()
	gen_fuse_pickup()
	gen_paper()
	gen_click()
	gen_battery()
	gen_heartbeat()
	gen_breath()
	gen_gasp()
	gen_ambient()
	gen_chase()
	gen_scream("scream", 2.2, 520.0, 1.0)
	gen_scream("nurse_alert", 1.6, 300.0, 0.7)
	gen_sting()
	gen_whisper()
	gen_nurse_breath()
	gen_buzz()
	gen_spark()
	gen_generator_start()
	gen_generator_loop()
	gen_alarm()
	gen_static()
	gen_rat()
	gen_wheelchair()
	gen_metal_bang()
	gen_drip()
	gen_thump()
	gen_locker_open()
	gen_locker_close()
	gen_music_box()


func gen_step(name: String, fc: float, q: float, decay: float, thump_f: float, thump_amt: float) -> void:
	var b := make(0.32)
	var j := rng.randf_range(0.85, 1.15)
	add_burst(b, 0.0, decay * j, fc * j, q, 1.0)
	add_burst(b, rng.randf_range(0.045, 0.07), decay * 0.8, fc * 1.15 * j, q, 0.45)
	add_tone(b, 0.0, thump_f * j, 0.035, thump_amt, 1.5)
	# ince kum / kir hışırtısı
	var hp := 0.0
	for i in ns(0.12):
		var x := nz() * (1.0 if rng.randf() < 0.04 else 0.0)
		hp += lp_k(3000.0) * (x - hp)
		b[i] += (x - hp) * 0.35 * exp(-float(i) / SR / 0.05)
	save(name, b, false, 0.8)


func gen_enemy_step(name: String) -> void:
	var b := make(0.7)
	add_tone(b, 0.0, 52.0, 0.14, 1.0, 2.0)
	var lp := 0.0
	for i in b.size():
		var t := float(i) / SR
		lp += lp_k(380.0) * (nz() - lp)
		b[i] += lp * exp(-t / 0.09) * 1.6
	# kemik çıtırtısı
	add_burst(b, rng.randf_range(0.02, 0.05), 0.004, 3200.0, 2.0, 0.7)
	add_burst(b, rng.randf_range(0.08, 0.12), 0.003, 4200.0, 3.0, 0.35)
	# ıslak sürtünme
	add_burst(b, 0.05, 0.06, 700.0, 1.5, 0.25)
	save(name, b)


func creak(b: PackedFloat32Array, start: float, dur: float, f0: float, f1: float, amp: float, res: Array) -> void:
	var filters: Array[SVF] = []
	for r in res:
		filters.append(SVF.new(r, 9.0))
	var ph := 0.0
	var s := ns(start)
	var n := mini(ns(dur), b.size() - s)
	var jitter := 0.0
	for i in n:
		var u := float(i) / n
		jitter += (rng.randf_range(-1.0, 1.0) * 30.0 - jitter) * 0.002
		var fr := lerpf(f0, f1, u) + sin(u * PI * 3.0) * 40.0 + jitter
		ph += fr / SR
		var x := 0.0
		if ph >= 1.0:
			ph -= 1.0
			x = rng.randf_range(0.6, 1.0)
		var env := sin(u * PI) * (0.7 + 0.3 * sin(u * 23.0))
		var y := 0.0
		for flt in filters:
			y += flt.process(x)
		b[s + i] += y * env * amp


func gen_door_open() -> void:
	var b := make(1.7)
	add_burst(b, 0.0, 0.006, 2800.0, 2.0, 0.6)
	add_partials(b, 0.0, [[1900.0, 0.03, 0.3], [3100.0, 0.02, 0.2]], 1.0)
	creak(b, 0.12, 1.35, 120.0, 260.0, 0.35, [650.0, 1150.0, 2300.0])
	save(name_of("door_open"), b)


func name_of(s: String) -> String:
	return s


func gen_door_close() -> void:
	var b := make(0.8)
	add_tone(b, 0.0, 90.0, 0.08, 0.9, 1.0)
	add_burst(b, 0.0, 0.03, 700.0, 0.8, 0.8)
	add_burst(b, 0.05, 0.005, 3000.0, 2.0, 0.5)
	add_partials(b, 0.05, [[2100.0, 0.03, 0.2], [3500.0, 0.02, 0.15]], 1.0)
	save("door_close", b)


func gen_door_slam() -> void:
	var b := make(1.6)
	add_tone(b, 0.0, 62.0, 0.25, 1.0, 1.5)
	add_burst(b, 0.0, 0.1, 900.0, 0.6, 1.2)
	add_burst(b, 0.0, 0.02, 3500.0, 1.0, 0.5)
	for i in 6:
		add_burst(b, rng.randf_range(0.08, 0.45), 0.012, rng.randf_range(1500.0, 2600.0), 4.0, 0.25)
	save("door_slam", b)


func gen_door_locked() -> void:
	var b := make(0.7)
	for t in [0.0, 0.14, 0.27]:
		add_burst(b, t, 0.018, 2400.0, 3.0, 0.8)
		add_tone(b, t, 130.0, 0.03, 0.5)
		add_partials(b, t, [[1700.0, 0.04, 0.15], [2900.0, 0.03, 0.1]], 1.0)
	save("door_locked", b)


func gen_unlock() -> void:
	var b := make(0.6)
	for t in [0.0, 0.2]:
		add_burst(b, t, 0.004, 4000.0, 2.0, 0.7)
		add_partials(b, t, [[2300.0, 0.04, 0.4], [3700.0, 0.03, 0.3], [5100.0, 0.02, 0.2]], 1.0)
	save("unlock", b)


func gen_pickup() -> void:
	var b := make(1.4)
	var ph := [0.0, 0.0, 0.0]
	var fr := [440.0, 659.3, 987.8]
	var dc := [0.7, 0.5, 0.35]
	for i in b.size():
		var t := float(i) / SR
		var v := 0.0
		for k in 3:
			ph[k] += TAU * fr[k] * (1.0 + 0.004 * sin(t * 30.0)) / SR
			v += sin(ph[k]) * exp(-t / dc[k]) / (k + 1)
		b[i] = v * minf(1.0, t / 0.01)
	save("pickup", b, false, 0.6)


func gen_key_pickup() -> void:
	var b := make(0.7)
	for i in 9:
		var t := rng.randf_range(0.0, 0.25)
		add_partials(b, t, [[rng.randf_range(3000, 4500), 0.05, 0.4], [rng.randf_range(5000, 7000), 0.03, 0.3]], 0.6)
		add_burst(b, t, 0.003, 5000.0, 2.0, 0.3)
	save("key_pickup", b, false, 0.7)


func gen_fuse_pickup() -> void:
	var b := make(1.0)
	add_partials(b, 0.0, [[523.3, 0.5, 0.5], [784.0, 0.4, 0.3]], 1.0)
	var ph := 0.0
	for i in ns(0.35):
		var t := float(i) / SR
		ph += 120.0 / SR
		var saw := 2.0 * fposmod(ph, 1.0) - 1.0
		b[i] += (saw * 0.4 + nz() * 0.2) * exp(-t / 0.09)
	save("fuse_pickup", b, false, 0.75)


func gen_paper() -> void:
	var b := make(0.7)
	var lp := 0.0
	var env := 0.0
	var target := 0.0
	for i in b.size():
		var t := float(i) / SR
		if i % 600 == 0:
			target = rng.randf() * rng.randf()
		env += (target - env) * 0.004
		var x := nz()
		lp += lp_k(1800.0) * (x - lp)
		b[i] = (x - lp) * env * sin(PI * t / 0.7)
	save("paper", b, false, 0.6)


func gen_click() -> void:
	var b := make(0.12)
	add_burst(b, 0.0, 0.002, 3500.0, 4.0, 1.0)
	add_burst(b, 0.035, 0.0015, 2600.0, 4.0, 0.5)
	save("flash_click", b, false, 0.6)


func gen_battery() -> void:
	var b := make(0.45)
	add_burst(b, 0.0, 0.003, 3000.0, 3.0, 1.0)
	add_burst(b, 0.05, 0.08, 1500.0, 0.7, 0.2)
	add_burst(b, 0.22, 0.003, 3800.0, 3.0, 0.8)
	save("battery", b, false, 0.6)


func gen_heartbeat() -> void:
	var b := make(1.0)
	add_tone(b, 0.0, 44.0, 0.08, 1.0, 1.0)
	add_tone(b, 0.27, 40.0, 0.07, 0.7, 1.0)
	var lp := 0.0
	for i in b.size():
		lp += lp_k(120.0) * (b[i] - lp)
		b[i] = lp * 3.0
	save("heartbeat", b, true, 0.9)


func gen_breath() -> void:
	var b := make(3.0)
	var f1 := SVF.new(1100.0, 0.9)
	var f2 := SVF.new(500.0, 1.2)
	for i in b.size():
		var t := float(i) / SR
		var env := 0.0
		if t < 1.1:
			env = pow(sin(PI * t / 1.1), 2.0) * 0.6
		elif t > 1.35 and t < 2.75:
			env = pow(sin(PI * (t - 1.35) / 1.4), 2.0)
		var x := nz() * env
		b[i] = f1.process(x) * 0.7 + f2.process(x) * 0.5
	save("breath", b, true, 0.7)


func gen_gasp() -> void:
	var b := make(0.8)
	var f := SVF.new(1200.0, 1.5)
	for i in b.size():
		var t := float(i) / SR
		f.set_freq(1000.0 + t * 2500.0)
		var env := minf(1.0, t / 0.05) * exp(-maxf(0.0, t - 0.15) / 0.12)
		b[i] = f.process(nz()) * env
	save("gasp", b, false, 0.7)


func gen_ambient() -> void:
	var L := 16.0
	var b := make(L + 2.0)
	var tones := [[36.75, 0.5], [55.0, 0.6], [55.25, 0.5], [82.5, 0.25], [110.125, 0.12], [164.75, 0.05]]
	var phases := []
	phases.resize(tones.size())
	phases.fill(0.0)
	var wind := SVF.new(400.0, 1.5)
	var rumble := 0.0
	for i in b.size():
		var t := float(i) / SR
		var v := 0.0
		for k in tones.size():
			phases[k] += TAU * tones[k][0] / SR
			v += sin(phases[k]) * tones[k][1] * (0.75 + 0.25 * sin(TAU * t * (k + 1) / L))
		rumble += lp_k(90.0) * (nz() - rumble)
		wind.set_freq(420.0 + 260.0 * sin(TAU * t / L) + 120.0 * sin(TAU * 3.0 * t / L))
		var w := wind.process(nz()) * (0.5 + 0.5 * sin(TAU * 2.0 * t / L + 1.0))
		b[i] = v * 0.5 + rumble * 2.5 + w * 0.35
	# uzak metal inlemeleri
	for st in [4.0, 11.0]:
		var f := SVF.new(300.0, 6.0)
		var ph := 0.0
		for i in ns(2.5):
			var t := float(i) / SR
			ph += (95.0 - t * 12.0) / SR
			var saw := 2.0 * fposmod(ph, 1.0) - 1.0
			f.set_freq(260.0 + 120.0 * sin(t * 2.0))
			b[ns(st) + i] += f.process(saw) * sin(PI * t / 2.5) * 0.25
	save("ambient_drone", crossfade_loop(b, L, 1.5), true, 0.7)


func saw_h(ph: float, harmonics: int) -> float:
	var v := 0.0
	for h in range(1, harmonics + 1):
		v += sin(ph * h) / h
	return v


func gen_chase() -> void:
	var L := 8.0
	var beat := 0.5
	var b := make(L + 1.5)
	# bas darbeleri (sekizlik)
	for n in 32:
		var st := n * beat * 0.5
		var s := ns(st)
		var ph := 0.0
		var fr := 41.2 if (n % 8) < 6 else 43.65
		for i in ns(0.3):
			var t := float(i) / SR
			ph += TAU * fr / SR
			b[s + i] += saw_h(ph, 7) * exp(-t / 0.12) * 0.55
	# davul vuruşları
	for n in 16:
		if n % 4 == 0 or n % 4 == 3 or n == 6:
			add_tone(b, n * beat, 48.0, 0.25, 1.2, 2.5)
			add_burst(b, n * beat, 0.05, 600.0, 0.8, 0.6)
	# metal tıkırtılar (on altılık)
	for n in 64:
		add_burst(b, n * beat * 0.25, 0.008 if n % 2 == 0 else 0.004, 7000.0, 1.0, 0.18 if n % 4 == 2 else 0.08)
	# uyumsuz yaylı küme (tremolo)
	var cl := [311.1, 329.6, 349.2, 622.3]
	var phs := [0.0, 0.0, 0.0, 0.0]
	for i in ns(L):
		var t := float(i) / SR
		var trem := 0.6 + 0.4 * sin(TAU * 12.0 * t)
		var swell := 0.5 + 0.5 * sin(TAU * t / L - PI * 0.5)
		var v := 0.0
		for k in cl.size():
			phs[k] += TAU * cl[k] * (1.0 + 0.003 * sin(TAU * 5.0 * t + k)) / SR
			v += saw_h(phs[k], 5) * (0.25 if k < 3 else 0.12 * swell)
		b[i] += v * trem * (0.35 + 0.25 * swell)
	save("chase_music", wrap_loop(b, L), true, 0.8)


func gen_scream(name: String, dur: float, base: float, harsh: float) -> void:
	var b := make(dur)
	var phs := []
	for k in 6:
		phs.append(rng.randf())
	var nf := SVF.new(3000.0, 1.0)
	var sub := 0.0
	for i in b.size():
		var t := float(i) / SR
		var u := t / dur
		var v := 0.0
		for k in 6:
			var fr: float = base * (1.0 + 0.071 * k) * (1.0 + 1.6 * (1.0 - exp(-t / 0.12)) - 0.6 * u) + 35.0 * sin(TAU * (6.0 + k) * t) * (k + 1)
			phs[k] = fposmod(phs[k] + fr / SR, 1.0)
			v += (2.0 * phs[k] - 1.0) * (1.0 / (k + 1.5))
		v *= 1.0 + 0.6 * nz() * harsh
		v += nf.process(nz()) * 0.8 * harsh
		sub += TAU * (70.0 + 30.0 * sin(TAU * 9.0 * t)) / SR
		v += sin(sub) * 0.6
		var env := minf(1.0, t / 0.012) * (1.0 if u < 0.65 else pow(1.0 - (u - 0.65) / 0.35, 2.0))
		b[i] = tanh(v * 2.5) * env
	save(name, b, false, 0.95)


func gen_sting() -> void:
	var b := make(3.8)
	var cluster := [185.0, 196.0, 207.65, 392.0, 415.3, 830.6, 880.0]
	for fr in cluster:
		var ph := 0.0
		var dec := rng.randf_range(0.9, 1.6)
		for i in b.size():
			var t := float(i) / SR
			ph += TAU * fr * (1.0 + 0.004 * sin(t * 31.0)) / SR
			b[i] += saw_h(ph, 4) * exp(-t / dec) * minf(1.0, t / 0.004) * 0.22
	add_tone(b, 0.0, 38.0, 1.0, 1.4, 1.5)
	add_burst(b, 0.0, 0.25, 500.0, 0.5, 1.0)
	add_burst(b, 0.0, 0.05, 4000.0, 0.7, 0.4)
	save("sting", b, false, 0.95)


func gen_whisper() -> void:
	var b := make(3.2)
	var f1 := SVF.new(1500.0, 5.0)
	var f2 := SVF.new(2600.0, 6.0)
	var hp := 0.0
	var t_next := 0.0
	var env_target := 0.0
	var env := 0.0
	var form := 0.0
	for i in b.size():
		var t := float(i) / SR
		if t >= t_next:
			t_next = t + rng.randf_range(0.07, 0.22)
			env_target = 0.0 if rng.randf() < 0.3 else rng.randf_range(0.4, 1.0)
			form = rng.randf()
		env += (env_target - env) * 0.003
		f1.set_freq(lerpf(900.0, 2000.0, form))
		f2.set_freq(lerpf(2200.0, 3200.0, 1.0 - form))
		var x := nz()
		hp += lp_k(5000.0) * (x - hp)
		var sib := (x - hp) * (0.6 if form > 0.8 else 0.1)
		b[i] = (f1.process(x) * 0.6 + f2.process(x) * 0.4 + sib) * env * sin(PI * t / 3.2)
	save("whisper", b, false, 0.7)


func gen_nurse_breath() -> void:
	var L := 4.0
	var b := make(L)
	var fa := SVF.new(500.0, 4.0)
	var fb := SVF.new(1100.0, 5.0)
	var fn := SVF.new(900.0, 2.0)
	var ph := 0.0
	for i in b.size():
		var t := float(i) / SR
		var inhale := 0.0
		var exhale := 0.0
		if t < 1.5:
			inhale = pow(sin(PI * t / 1.5), 2.0)
		elif t > 1.8 and t < 3.7:
			exhale = pow(sin(PI * (t - 1.8) / 1.9), 2.0)
		var fr := lerpf(38.0, 58.0, exhale) + rng.randf_range(-6.0, 6.0)
		ph += fr / SR
		var pulse := 0.0
		if ph >= 1.0:
			ph -= 1.0
			pulse = 1.0
		var growl := fa.process(pulse) + fb.process(pulse) * 0.6
		var air := fn.process(nz())
		b[i] = growl * (inhale * 0.4 + exhale) * 1.2 + air * (inhale * 0.7 + exhale * 0.3)
	save("nurse_breath", b, true, 0.8)


func gen_buzz() -> void:
	var b := make(2.0)
	for i in b.size():
		var t := float(i) / SR
		var v := 0.0
		for k in range(1, 13):
			v += sin(TAU * 100.0 * k * t + k) / pow(k, 1.1)
		b[i] = v * (0.8 + 0.2 * sin(TAU * 0.5 * t)) + nz() * 0.03
	save("buzz", b, true, 0.6)


func gen_spark() -> void:
	var b := make(0.9)
	add_burst(b, 0.0, 0.02, 1500.0, 0.6, 1.0)
	add_tone(b, 0.0, 80.0, 0.05, 0.8, 2.0)
	for i in 50:
		var t := pow(rng.randf(), 2.0) * 0.8
		add_burst(b, t, 0.002, rng.randf_range(2500.0, 6000.0), 2.0, rng.randf_range(0.2, 0.7) * (1.0 - t))
	save("spark", b, false, 0.8)


func gen_generator_start() -> void:
	var b := make(4.0)
	var t := 0.05
	var rate := 4.0
	while t < 2.2:
		add_tone(b, t, 55.0, 0.06, 0.8, 1.5)
		add_burst(b, t, 0.03, 500.0, 0.8, 0.5)
		rate = minf(rate * 1.12, 26.0)
		t += 1.0 / rate
	var lp := 0.0
	var ph := 0.0
	for i in range(ns(2.0), b.size()):
		var tt := float(i) / SR - 2.0
		ph += TAU * 50.0 / SR
		lp += lp_k(250.0) * (nz() - lp)
		b[i] += (sin(ph) * 0.5 + sin(ph * 2.0) * 0.25 + lp * 2.0) * minf(1.0, tt / 0.6)
	save("generator_start", b, false, 0.85)


func gen_generator_loop() -> void:
	var b := make(3.0)
	var lp := 0.0
	var ph := 0.0
	for i in b.size():
		var t := float(i) / SR
		ph += TAU * 25.0 / SR
		lp += lp_k(300.0) * (nz() - lp)
		var pulse := pow(0.5 + 0.5 * sin(ph), 6.0)
		b[i] = pulse * 0.6 + sin(ph * 2.0) * 0.3 + sin(ph * 4.0) * 0.15 + lp * 1.5 * (0.6 + pulse)
	save("generator_loop", crossfade_loop(b, 2.0, 0.5), true, 0.7)


func gen_alarm() -> void:
	var b := make(2.0)
	var ph := 0.0
	for i in b.size():
		var t := float(i) / SR
		var fr := 760.0 if t < 1.0 else 570.0
		ph += TAU * fr / SR
		var local := fmod(t, 1.0)
		var env := minf(1.0, local / 0.01) * minf(1.0, (1.0 - local) / 0.01)
		b[i] = (sin(ph) + 0.35 * sin(ph * 3.0) + 0.15 * sin(ph * 5.0)) * env
	save("alarm", b, true, 0.6)


func gen_static() -> void:
	var b := make(2.0)
	var f := SVF.new(2200.0, 0.6)
	var amp := 1.0
	for i in b.size():
		if i % 400 == 0:
			amp = rng.randf_range(0.3, 1.0)
		var x := nz()
		if rng.randf() < 0.002:
			x *= 6.0
		b[i] = f.process(x) * amp
	save("static", b, false, 0.6)


func gen_rat() -> void:
	var b := make(0.9)
	for st in [0.05, 0.22, 0.5]:
		var ph := 0.0
		var s := ns(st)
		for i in ns(0.07):
			var t := float(i) / SR
			ph += TAU * (3800.0 + 900.0 * sin(PI * t / 0.07)) / SR
			b[s + i] += sin(ph) * sin(PI * t / 0.07) * 0.6
	for i in 25:
		add_burst(b, rng.randf_range(0.0, 0.8), 0.003, 4000.0, 1.5, 0.25)
	save("rat", b, false, 0.6)


func gen_wheelchair() -> void:
	var b := make(3.2)
	var lp := 0.0
	for i in b.size():
		var t := float(i) / SR
		lp += lp_k(120.0) * (nz() - lp)
		b[i] = lp * 2.0 * sin(PI * t / 3.2)
	for i in 100:
		var t := rng.randf_range(0.0, 3.1)
		add_burst(b, t, 0.004, rng.randf_range(1800.0, 3200.0), 3.0, 0.3 * sin(PI * t / 3.2))
	var t2 := 0.2
	while t2 < 3.0:
		add_partials(b, t2, [[1750.0, 0.05, 0.25], [2650.0, 0.03, 0.12]], 1.0)
		t2 += 0.55
	save("wheelchair", b, false, 0.7)


func gen_metal_bang() -> void:
	var b := make(3.0)
	add_partials(b, 0.0, [[220.0, 1.1, 0.8], [563.0, 0.8, 0.6], [1011.0, 0.6, 0.45], [1783.0, 0.4, 0.3], [2410.0, 0.3, 0.2]], 1.0)
	add_burst(b, 0.0, 0.03, 1200.0, 0.6, 0.8)
	add_tone(b, 0.0, 70.0, 0.15, 0.6, 1.0)
	save("metal_bang", b, false, 0.85)


func gen_drip() -> void:
	var b := make(0.4)
	var ph := 0.0
	for i in b.size():
		var t := float(i) / SR
		ph += TAU * (900.0 + 1600.0 * minf(1.0, t / 0.025)) / SR
		b[i] = sin(ph) * exp(-t / 0.03) * minf(1.0, t / 0.001)
	save("drip", b, false, 0.6)


func gen_thump() -> void:
	var b := make(1.3)
	for st in [0.0, 0.38]:
		add_tone(b, st, 50.0, 0.18, 1.0, 1.2)
		add_burst(b, st, 0.05, 220.0, 0.7, 1.2)
	save("thump", b, false, 0.85)


func gen_locker_open() -> void:
	var b := make(0.8)
	creak(b, 0.0, 0.45, 260.0, 420.0, 0.25, [1500.0, 2900.0])
	add_partials(b, 0.42, [[480.0, 0.15, 0.4], [1230.0, 0.1, 0.3], [2100.0, 0.06, 0.2]], 1.0)
	add_burst(b, 0.42, 0.01, 2000.0, 1.0, 0.4)
	save("locker_open", b, false, 0.7)


func gen_locker_close() -> void:
	var b := make(0.6)
	add_partials(b, 0.0, [[430.0, 0.2, 0.6], [1150.0, 0.12, 0.35], [2250.0, 0.08, 0.2]], 1.0)
	add_burst(b, 0.0, 0.015, 1400.0, 0.8, 0.8)
	add_tone(b, 0.0, 90.0, 0.06, 0.6)
	save("locker_close", b, false, 0.75)


func gen_music_box() -> void:
	# La minör, hafif akortsuz bir müzik kutusu ninnisi.
	var L := 12.0
	var b := make(L + 3.0)
	var melody := [81, 84, 88, 81, 83, 80, 76, -1, 81, 84, 86, 88, 89, 88, 86, 83]
	var bass := [57, -1, 64, -1, 56, -1, 64, -1, 57, -1, 62, -1, 65, -1, 59, -1]
	var step := L / 16.0
	for n in 16:
		for track in [[melody, 1.0], [bass, 0.5]]:
			var note: int = track[0][n]
			if note < 0:
				continue
			var fr := 440.0 * pow(2.0, (note - 69) / 12.0)
			var s := ns(n * step)
			var ph := 0.0
			for i in ns(2.5):
				var t := float(i) / SR
				var wob := 1.0 + 0.006 * sin(TAU * 0.35 * (n * step + t))
				ph += TAU * fr * wob / SR
				var v := sin(ph) * exp(-t / 0.9) + 0.35 * sin(ph * 3.0) * exp(-t / 0.25) + 0.15 * sin(ph * 5.4) * exp(-t / 0.08)
				b[s + i] += v * minf(1.0, t / 0.002) * track[1]
	save("music_box", wrap_loop(b, L), true, 0.6)

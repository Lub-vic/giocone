class_name Sfx
extends Node
## Suoni sintetizzati da codice (nessun file audio): effetti e droni ambientali per regione.

const RATE := 16000

var cache := {}
var players: Array = []
var amb: AudioStreamPlayer
var cur_amb := ""
var rr := 0
var sfx_lin := 1.0
var amb_lin := 1.0


func _ready() -> void:
	for i in 8:
		var p := AudioStreamPlayer.new()
		p.volume_db = -7.0
		add_child(p)
		players.append(p)
	amb = AudioStreamPlayer.new()
	amb.volume_db = -19.0
	add_child(amb)
	_build()


func _wav(samples: PackedFloat32Array, loop := false) -> AudioStreamWAV:
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	var d := PackedByteArray()
	d.resize(samples.size() * 2)
	for i in samples.size():
		d.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 30000.0))
	w.data = d
	if loop:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = samples.size()
	return w


# wave: 0 seno, 1 dente di sega, 2 quadra
func _tone(f0: float, f1: float, dur: float, wave: int, noise: float, vol: float, attack := 0.004) -> PackedFloat32Array:
	var n := int(dur * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var phase := 0.0
	var lp := 0.0
	for i in n:
		var t := float(i) / n
		phase += lerpf(f0, f1, t) / RATE
		var s := 0.0
		if wave == 0:
			s = sin(TAU * phase)
		elif wave == 1:
			s = 2.0 * fposmod(phase, 1.0) - 1.0
		else:
			s = 1.0 if fposmod(phase, 1.0) < 0.5 else -1.0
		lp = lerpf(lp, randf() * 2.0 - 1.0, 0.35)
		s = s * (1.0 - noise) + lp * noise * 1.6
		var env := minf(i / (attack * RATE), 1.0) * pow(1.0 - t, 2.0)
		out[i] = s * env * vol
	return out


func _cat(parts: Array) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	for p in parts:
		out.append_array(p)
	return out


## somma due suoni (la durata e' quella del piu' lungo)
func _mix2(a: PackedFloat32Array, b: PackedFloat32Array) -> PackedFloat32Array:
	var out := a.duplicate() if a.size() >= b.size() else b.duplicate()
	var other := b if a.size() >= b.size() else a
	for i in other.size():
		out[i] += other[i]
	return out


## tuono: schiocco secco, poi un brontolio che rotola e si spegne
func _thunder(dur: float, crack: float) -> PackedFloat32Array:
	var n := int(dur * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var lp := 0.0
	var lp2 := 0.0
	var roll := 1.0
	for i in n:
		var t := float(i) / RATE
		var w := randf() * 2.0 - 1.0
		lp = lerpf(lp, w, 0.05)
		lp2 = lerpf(lp2, lp, 0.12)
		if i % 900 == 0:
			roll = randf_range(0.45, 1.0)
		var s := w * exp(-t * 28.0) * crack + lp2 * 4.2 * roll * exp(-t * 1.9) * minf(t * 30.0, 1.0)
		out[i] = s * 0.75 * minf((dur - t) * 4.0, 1.0)
	return out


## scarica elettrica: scoppiettii irregolari
func _crackle(dur: float, vol: float) -> PackedFloat32Array:
	var n := int(dur * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var gate := 0.0
	for i in n:
		if i % 90 == 0:
			gate = 1.0 if randf() < 0.55 else 0.05
		var t := float(i) / n
		out[i] = (randf() * 2.0 - 1.0) * gate * pow(1.0 - t, 1.5) * vol
	return out


## risucchio: un suono che cresce e si interrompe di colpo
func _swell(dur: float) -> PackedFloat32Array:
	var n := int(dur * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var phase := 0.0
	var lp := 0.0
	for i in n:
		var t := float(i) / n
		phase += lerpf(55.0, 620.0, t * t) / RATE
		lp = lerpf(lp, randf() * 2.0 - 1.0, 0.04 + 0.4 * t)
		var s := sin(TAU * phase) * 0.45 + sin(TAU * phase * 2.01) * 0.2 + lp * 0.7
		out[i] = s * pow(t, 2.2) * 0.8 * clampf((1.0 - t) * 60.0, 0.0, 1.0)
	return out


## nastro riavvolto: ticchettii di orologio sempre piu' fitti e un lamento che sale
func _rewind(dur: float) -> PackedFloat32Array:
	var n := int(dur * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var phase := 0.0
	var beat := 0.0
	for i in n:
		var t := float(i) / n
		phase += lerpf(210.0, 900.0, t * t) * (1.0 + 0.25 * sin(t * 90.0)) / RATE
		beat += lerpf(7.0, 34.0, t) / RATE
		var tick := (randf() * 2.0 - 1.0) * exp(-fposmod(beat, 1.0) * 22.0)
		out[i] = (sin(TAU * phase) * 0.18 + tick * 0.5) * minf(t * 12.0, 1.0) * minf((1.0 - t) * 14.0, 1.0)
	return out


func _drone(f: float, dur: float, noise: float) -> PackedFloat32Array:
	var n := int(dur * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var lp := 0.0
	for i in n:
		var t := float(i) / RATE
		lp = lerpf(lp, randf() * 2.0 - 1.0, 0.04)
		var s := sin(TAU * f * t) * 0.5 + sin(TAU * f * 1.5 * t) * 0.22 + sin(TAU * f * 2.0 * t) * 0.1 + lp * noise
		out[i] = s * (0.75 + 0.25 * sin(TAU * t / dur)) * 0.55
	return out


func _build() -> void:
	cache["swing"] = _wav(_tone(0, 0, 0.13, 0, 1.0, 0.45, 0.02))
	cache["shot"] = _wav(_mix2(_crackle(0.09, 0.8), _tone(240, 60, 0.18, 0, 0.55, 0.7, 0.001)))
	cache["cock"] = _wav(_cat([_tone(0, 0, 0.03, 0, 1.0, 0.45, 0.001), _tone(0, 0, 0.05, 0, 0.0, 0.0), _tone(1500, 900, 0.04, 2, 0.5, 0.25, 0.001)]))
	# cutscene dell'ufo
	cache["thunder"] = _wav(_thunder(2.2, 1.0))
	cache["boom_big"] = _wav(_mix2(_thunder(2.6, 0.55), _tone(95, 24, 1.8, 0, 0.12, 0.9, 0.003)))
	cache["zap"] = _wav(_crackle(0.22, 0.5))
	cache["rumble"] = _wav(_mix2(_tone(38, 62, 2.6, 1, 0.3, 0.38, 0.9), _tone(57, 45, 2.6, 0, 0.2, 0.4, 1.1)))
	cache["time_open"] = _wav(_mix2(_tone(90, 780, 1.3, 0, 0.06, 0.45, 0.02), _tone(135, 1170, 1.3, 0, 0.0, 0.25, 0.05)))
	cache["time_suck"] = _wav(_swell(1.35))
	cache["rewind"] = _wav(_rewind(2.5))
	cache["searchlight"] = _wav(_mix2(_tone(300, 300, 1.2, 2, 0.05, 0.12, 0.03), _tone(1210, 1190, 1.2, 0, 0.0, 0.16, 0.2)))
	cache["alarm"] = _wav(_cat([_tone(880, 620, 0.22, 2, 0.05, 0.2), _tone(880, 620, 0.22, 2, 0.05, 0.2), _tone(880, 620, 0.22, 2, 0.05, 0.2), _tone(880, 560, 0.3, 2, 0.1, 0.2)]))
	cache["hit"] = _wav(_tone(180, 60, 0.13, 2, 0.35, 0.6))
	cache["slam"] = _wav(_tone(110, 35, 0.35, 1, 0.5, 0.8))
	cache["roll"] = _wav(_tone(0, 0, 0.22, 0, 1.0, 0.35, 0.05))
	cache["hurt"] = _wav(_tone(220, 80, 0.28, 1, 0.3, 0.7))
	cache["kill"] = _wav(_tone(140, 45, 0.4, 1, 0.55, 0.7))
	cache["soul"] = _wav(_tone(700, 1300, 0.09, 0, 0.0, 0.25))
	cache["level"] = _wav(_cat([_tone(400, 400, 0.1, 0, 0.0, 0.4), _tone(500, 500, 0.1, 0, 0.0, 0.4), _tone(650, 650, 0.1, 0, 0.0, 0.4), _tone(820, 820, 0.3, 0, 0.0, 0.45)]))
	cache["bonfire"] = _wav(_cat([_tone(220, 220, 0.5, 0, 0.1, 0.35, 0.1), _tone(330, 330, 0.5, 0, 0.1, 0.3, 0.1)]))
	cache["death"] = _wav(_tone(190, 32, 1.4, 1, 0.25, 0.7, 0.03))
	cache["drink"] = _wav(_cat([_tone(200, 320, 0.12, 0, 0.2, 0.4), _tone(200, 320, 0.12, 0, 0.2, 0.4), _tone(200, 360, 0.15, 0, 0.2, 0.4)]))
	cache["roar"] = _wav(_tone(75, 45, 0.7, 1, 0.45, 0.8, 0.05))
	cache["laser_charge"] = _wav(_tone(180, 980, 0.75, 0, 0.08, 0.35, 0.03))
	cache["laser"] = _wav(_tone(820, 420, 2.5, 0, 0.10, 0.32, 0.04))
	cache["page"] = _wav(_tone(0, 0, 0.18, 0, 1.0, 0.25, 0.03))
	cache["buy"] = _wav(_cat([_tone(500, 500, 0.08, 2, 0.0, 0.3), _tone(750, 750, 0.18, 2, 0.0, 0.3)]))
	var f := [55.0, 48.0, 44.0, 52.0, 60.0, 70.0, 40.0]
	var nz := [0.25, 0.3, 0.35, 0.3, 0.2, 0.55, 0.4]
	for i in f.size():
		cache["amb_%d" % i] = _wav(_drone(f[i], 3.0, nz[i]), true)
	cache["amb_dun"] = _wav(_drone(46.0, 3.0, 0.3), true)


func play(name: String, vol := 0.0) -> void:
	if not cache.has(name):
		return
	for k in players.size():
		rr = (rr + 1) % players.size()
		var p: AudioStreamPlayer = players[rr]
		if not p.playing:
			p.stream = cache[name]
			p.volume_db = -7.0 + vol + linear_to_db(maxf(sfx_lin, 0.0001))
			p.pitch_scale = randf_range(0.92, 1.08)
			p.play()
			return


func set_levels(sfx_v: float, amb_v: float) -> void:
	sfx_lin = sfx_v
	amb_lin = amb_v
	if amb != null:
		amb.volume_db = -19.0 + linear_to_db(maxf(amb_lin, 0.0001))


func ambient(name: String) -> void:
	if name == cur_amb or not cache.has("amb_" + name):
		return
	cur_amb = name
	amb.stream = cache["amb_" + name]
	amb.play()

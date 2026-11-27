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

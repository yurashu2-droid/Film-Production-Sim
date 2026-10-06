extends Node
## 全サウンドをコードで合成するSEとBGMのシングルトン (autoload "Sfx")

signal played(sound: String, position: Variant)
signal music_changed(track: String)

const RATE: int = 22050
const MAX_ONESHOTS: int = 40
const MUSIC_DB: float = 0.0
const SILENT_DB: float = -60.0

var muted: bool = false
var synth_ms: int = 0

var _streams: Dictionary = {}
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _warned: Dictionary = {}
var _oneshots: Array[Node] = []
var _music_players: Array[AudioStreamPlayer] = []
var _music_cur: int = 0
var _music_name: String = ""
var _music_tween: Tween = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in 2:
		var mp: AudioStreamPlayer = AudioStreamPlayer.new()
		mp.volume_db = SILENT_DB
		add_child(mp)
		_music_players.append(mp)
	resynthesize()


func resynthesize() -> void:
	var t0: int = Time.get_ticks_msec()
	_rng.seed = 20240607
	_streams.clear()
	_synth_sfx()
	_synth_music()
	synth_ms = Time.get_ticks_msec() - t0


# ---------------------------------------------------------------- public API

func has_sound(sound: String) -> bool:
	return _streams.has(sound)


func get_stream(sound: String) -> AudioStreamWAV:
	return _streams.get(sound) as AudioStreamWAV


func current_music() -> String:
	return _music_name


func play(sound: String, position: Variant = null, volume_db: float = 0.0) -> void:
	if not _streams.has(sound):
		if not _warned.has(sound):
			_warned[sound] = true
			push_warning("Sfx: unknown sound '%s'" % sound)
		return
	played.emit(sound, position)
	if muted or not is_inside_tree():
		return
	if _oneshots.size() >= MAX_ONESHOTS:
		var oldest: Node = _oneshots.pop_front()
		if is_instance_valid(oldest):
			oldest.queue_free()
	var stream: AudioStreamWAV = _streams[sound]
	if position is Vector3:
		var p3: AudioStreamPlayer3D = AudioStreamPlayer3D.new()
		p3.stream = stream
		p3.volume_db = volume_db
		p3.unit_size = 8.0
		p3.max_distance = 60.0
		add_child(p3)
		p3.global_position = position as Vector3
		p3.finished.connect(_on_oneshot_finished.bind(p3))
		_oneshots.append(p3)
		p3.play()
	else:
		var p: AudioStreamPlayer = AudioStreamPlayer.new()
		p.stream = stream
		p.volume_db = volume_db
		add_child(p)
		p.finished.connect(_on_oneshot_finished.bind(p))
		_oneshots.append(p)
		p.play()


func play_music(track: String, fade_sec: float = 0.4) -> void:
	if not _streams.has(track):
		if not _warned.has(track):
			_warned[track] = true
			push_warning("Sfx: unknown music '%s'" % track)
		return
	var same: bool = track == _music_name
	_music_name = track
	music_changed.emit(track)
	if muted or not is_inside_tree():
		return
	if same and _music_players[_music_cur].playing:
		return
	_kill_music_tween()
	var old: AudioStreamPlayer = _music_players[_music_cur]
	_music_cur = 1 - _music_cur
	var nw: AudioStreamPlayer = _music_players[_music_cur]
	nw.stop()
	nw.stream = _streams[track]
	nw.volume_db = SILENT_DB if fade_sec > 0.0 else MUSIC_DB
	nw.play()
	if fade_sec <= 0.0:
		old.stop()
		return
	_music_tween = create_tween()
	_music_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_music_tween.set_parallel(true)
	_music_tween.tween_property(nw, "volume_db", MUSIC_DB, fade_sec)
	if old.playing:
		_music_tween.tween_property(old, "volume_db", SILENT_DB, fade_sec)
		_music_tween.chain().tween_callback(old.stop)


func stop_music(fade_sec: float = 0.6) -> void:
	_music_name = ""
	music_changed.emit("")
	_kill_music_tween()
	if not is_inside_tree():
		return
	var cur: AudioStreamPlayer = _music_players[_music_cur]
	var other: AudioStreamPlayer = _music_players[1 - _music_cur]
	other.stop()
	if fade_sec <= 0.0 or not cur.playing:
		cur.stop()
		return
	_music_tween = create_tween()
	_music_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_music_tween.tween_property(cur, "volume_db", SILENT_DB, fade_sec)
	_music_tween.tween_callback(cur.stop)


func silence_all() -> void:
	_kill_music_tween()
	_music_name = ""
	for mp in _music_players:
		mp.stop()
	for n in _oneshots:
		if is_instance_valid(n):
			n.queue_free()
	_oneshots.clear()


# ---------------------------------------------------------------- internals

func _kill_music_tween() -> void:
	if _music_tween != null and _music_tween.is_valid():
		_music_tween.kill()
	_music_tween = null


func _on_oneshot_finished(p: Node) -> void:
	_oneshots.erase(p)
	if is_instance_valid(p):
		p.queue_free()


func _buf(sec: float) -> PackedFloat32Array:
	var b: PackedFloat32Array = PackedFloat32Array()
	b.resize(int(sec * RATE))
	return b


func _midi(m: float) -> float:
	return 440.0 * pow(2.0, (m - 69.0) / 12.0)


## 正弦+倍音。tau>0で指数減衰、f1<0で周波数固定、wrapでループ末尾を先頭へ回り込ませる
func _tone(buf: PackedFloat32Array, t0: float, dur: float, f0: float, amp: float,
		atk: float = 0.01, rel: float = 0.05, tau: float = 0.0, f1: float = -1.0,
		h2: float = 0.0, h3: float = 0.0, wrap: bool = false) -> void:
	var n: int = buf.size()
	var i0: int = int(t0 * RATE)
	var cnt: int = int(dur * RATE)
	var ph: float = 0.0
	var fe: float = f0 if f1 < 0.0 else f1
	var inv_sr: float = 1.0 / RATE
	for i in cnt:
		var t: float = i * inv_sr
		var f: float = f0 + (fe - f0) * (float(i) / cnt)
		ph += TAU * f * inv_sr
		var env: float = 1.0
		if atk > 0.0 and t < atk:
			env = t / atk
		if rel > 0.0 and dur - t < rel:
			env *= maxf(0.0, (dur - t) / rel)
		if tau > 0.0:
			env *= exp(-t / tau)
		var v: float = sin(ph)
		if h2 != 0.0:
			v += h2 * sin(2.0 * ph)
		if h3 != 0.0:
			v += h3 * sin(3.0 * ph)
		var idx: int = i0 + i
		if wrap:
			idx = idx % n
		elif idx >= n:
			break
		buf[idx] += v * env * amp


## ローパスノイズ。lp: 0..1 (小さいほど低域)
func _noise(buf: PackedFloat32Array, t0: float, dur: float, amp: float, lp: float,
		atk: float = 0.002, tau: float = 0.1) -> void:
	var n: int = buf.size()
	var i0: int = int(t0 * RATE)
	var cnt: int = int(dur * RATE)
	var y: float = 0.0
	var inv_sr: float = 1.0 / RATE
	var tail: float = minf(0.01, dur * 0.5)
	for i in cnt:
		var idx: int = i0 + i
		if idx >= n:
			break
		var t: float = i * inv_sr
		y += lp * (_rng.randf_range(-1.0, 1.0) - y)
		var env: float = exp(-t / tau)
		if atk > 0.0 and t < atk:
			env *= t / atk
		if dur - t < tail:
			env *= (dur - t) / tail
		buf[idx] += y * env * amp


func _finish(buf: PackedFloat32Array, peak: float, loop: bool = false) -> AudioStreamWAV:
	var n: int = buf.size()
	var mx: float = 0.0001
	for i in n:
		var a: float = absf(buf[i])
		if a > mx:
			mx = a
	var k: float = peak / mx
	var fade: int = 0 if loop else mini(110, n / 4)
	var bytes: PackedByteArray = PackedByteArray()
	bytes.resize(n * 2)
	for i in n:
		var v: float = buf[i] * k
		if i >= n - fade:
			v *= float(n - 1 - i) / fade
		bytes.encode_s16(i * 2, clampi(int(v * 32767.0), -32767, 32767))
	var s: AudioStreamWAV = AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = RATE
	s.stereo = false
	s.data = bytes
	if loop:
		s.loop_mode = AudioStreamWAV.LOOP_FORWARD
		s.loop_begin = 0
		s.loop_end = n
	return s


func _synth_sfx() -> void:
	var b: PackedFloat32Array

	# explosion
	b = _buf(2.2)
	_tone(b, 0.0, 2.2, 90.0, 1.0, 0.004, 0.4, 0.6, 35.0, 0.3, 0.0)
	_tone(b, 0.0, 1.2, 55.0, 0.5, 0.01, 0.3, 0.3, 30.0)
	_noise(b, 0.0, 2.2, 1.4, 0.07, 0.006, 0.55)
	_noise(b, 0.0, 0.8, 0.5, 0.25, 0.003, 0.15)
	_noise(b, 0.0, 0.07, 0.6, 0.9, 0.0, 0.015)
	_streams["explosion"] = _finish(b, 0.85)

	# explosion_fizzle
	b = _buf(0.6)
	_noise(b, 0.0, 0.55, 0.8, 0.45, 0.02, 0.2)
	_tone(b, 0.0, 0.5, 1400.0, 0.25, 0.02, 0.15, 0.25, 350.0)
	_streams["explosion_fizzle"] = _finish(b, 0.5)

	# clap
	b = _buf(0.12)
	_noise(b, 0.0, 0.03, 1.0, 0.85, 0.0, 0.006)
	_noise(b, 0.045, 0.06, 0.9, 0.6, 0.0, 0.015)
	_tone(b, 0.045, 0.05, 900.0, 0.2, 0.0, 0.02, 0.015)
	_streams["clap"] = _finish(b, 0.8)

	# pickup
	b = _buf(0.08)
	_tone(b, 0.0, 0.08, 600.0, 1.0, 0.008, 0.03, 0.0, 900.0, 0.1)
	_streams["pickup"] = _finish(b, 0.5)

	# drop
	b = _buf(0.12)
	_tone(b, 0.0, 0.12, 140.0, 1.0, 0.003, 0.02, 0.035, 70.0)
	_noise(b, 0.0, 0.03, 0.2, 0.2, 0.0, 0.01)
	_streams["drop"] = _finish(b, 0.6)

	# fix / unfix
	b = _buf(0.25)
	for j in 4:
		var t: float = j * 0.065
		_noise(b, t, 0.03, 0.9, 0.55, 0.0, 0.006)
		_tone(b, t, 0.03, 1800.0 + j * 120.0, 0.25, 0.0, 0.01, 0.008)
	_streams["fix"] = _finish(b, 0.6)
	b = _buf(0.25)
	for j in 4:
		var t: float = j * 0.065
		_noise(b, t, 0.035, 0.9, 0.25, 0.0, 0.008)
		_tone(b, t, 0.035, 900.0 - j * 80.0, 0.3, 0.0, 0.012, 0.01)
	_streams["unfix"] = _finish(b, 0.6)

	# ui_ok
	b = _buf(0.35)
	_tone(b, 0.0, 0.2, _midi(76.0), 0.8, 0.005, 0.08, 0.1, -1.0, 0.2, 0.05)
	_tone(b, 0.1, 0.25, _midi(83.0), 0.8, 0.005, 0.1, 0.12, -1.0, 0.2, 0.05)
	_streams["ui_ok"] = _finish(b, 0.5)

	# ui_fail
	b = _buf(0.4)
	_tone(b, 0.0, 0.2, _midi(62.0), 0.8, 0.01, 0.06, 0.0, -1.0, 0.4, 0.25)
	_tone(b, 0.18, 0.22, _midi(55.0), 0.8, 0.01, 0.1, 0.0, -1.0, 0.4, 0.25)
	_streams["ui_fail"] = _finish(b, 0.45)

	# cue
	b = _buf(0.3)
	_tone(b, 0.0, 0.3, 1320.0, 0.8, 0.003, 0.05, 0.07, -1.0, 0.25, 0.0)
	_tone(b, 0.0, 0.3, 1320.0 * 2.76, 0.2, 0.003, 0.05, 0.03)
	_streams["cue"] = _finish(b, 0.5)

	# countdown
	b = _buf(0.12)
	_tone(b, 0.0, 0.12, 880.0, 1.0, 0.004, 0.02)
	_streams["countdown"] = _finish(b, 0.5)
	b = _buf(0.4)
	_tone(b, 0.0, 0.4, 1320.0, 1.0, 0.004, 0.06)
	_streams["countdown_go"] = _finish(b, 0.55)

	# success_fanfare
	b = _buf(1.8)
	var melody: Array = [[0.0, 0.2, 72.0], [0.2, 0.2, 76.0], [0.4, 0.2, 79.0], [0.6, 0.2, 76.0], [0.85, 0.95, 84.0]]
	for nt in melody:
		var ts: float = nt[0]
		var d: float = nt[1]
		var m: float = nt[2]
		_tone(b, ts, d + 0.05, _midi(m), 0.7, 0.01, 0.05, 0.0, -1.0, 0.3, 0.12)
		_tone(b, ts, d + 0.05, _midi(m - 4.0), 0.35, 0.01, 0.05, 0.0, -1.0, 0.2, 0.0)
	_tone(b, 0.85, 0.95, _midi(79.0), 0.4, 0.01, 0.5, 0.0, -1.0, 0.2, 0.0)
	_tone(b, 0.85, 0.95, _midi(60.0), 0.4, 0.01, 0.5, 0.0, -1.0, 0.3, 0.0)
	_streams["success_fanfare"] = _finish(b, 0.7)

	# thump
	b = _buf(0.2)
	_tone(b, 0.0, 0.2, 100.0, 0.7, 0.002, 0.03, 0.05, 55.0)
	_noise(b, 0.0, 0.2, 1.0, 0.12, 0.002, 0.05)
	_streams["thump"] = _finish(b, 0.7)


func _synth_music() -> void:
	var b: PackedFloat32Array

	# --- confession: 3/4 waltz arpeggio, 4 bars of 2 s
	b = _buf(8.0)
	var beat: float = 2.0 / 3.0
	var chords: Array = [[48, 52, 55, 60], [45, 52, 57, 60], [41, 48, 53, 57], [43, 50, 55, 59]]
	var pat: Array = [0, 1, 2, 3, 2, 1]
	for bar in 4:
		var ch: Array = chords[bar]
		for j in 6:
			var m: float = ch[pat[j]]
			_tone(b, bar * 2.0 + j * beat * 0.5, 0.55, _midi(m), 0.5, 0.02, 0.3, 0.0, -1.0, 0.25, 0.08, true)
		_tone(b, bar * 2.0, 2.0, _midi(float(ch[0]) - 12.0), 0.3, 0.05, 0.5, 0.0, -1.0, 0.15, 0.0, true)
	var mel: Array = [[0, 2, 76], [2, 1, 74], [3, 2, 72], [5, 1, 69], [6, 2, 72], [8, 1, 69], [9, 2, 71], [11, 1, 74]]
	for nt in mel:
		var ts: float = float(nt[0]) * beat
		var d: float = float(nt[1]) * beat
		_tone(b, ts, d, _midi(float(nt[2])), 0.6, 0.06, 0.25, 0.0, -1.0, 0.2, 0.05, true)
	_streams["music_confession"] = _finish(b, 0.25, true)

	# --- reunion: 4/4, 0.5 s beat
	b = _buf(8.0)
	var pads: Array = [[53, 57, 60], [55, 59, 62], [52, 55, 59], [57, 60, 64]]
	for bar in 4:
		var ch: Array = pads[bar]
		for m in ch:
			_tone(b, bar * 2.0, 2.3, _midi(float(m)), 0.35, 0.35, 0.5, 0.0, -1.0, 0.25, 0.1, true)
		_tone(b, bar * 2.0, 2.0, _midi(float(ch[0]) - 24.0), 0.5, 0.05, 0.4, 0.0, -1.0, 0.2, 0.0, true)
		for j in 8:
			var m2: float = ch[j % 3] + 12.0
			_tone(b, bar * 2.0 + j * 0.25, 0.3, _midi(m2), 0.18, 0.01, 0.15, 0.0, -1.0, 0.2, 0.0, true)
	var mel2: Array = [[0, 1, 69], [1, 1, 72], [2, 1, 74], [3, 1, 77], [4, 1, 71], [5, 1, 74], [6, 1, 76], [7, 1, 79],
		[8, 1, 76], [9, 1, 79], [10, 1, 83], [11, 1, 79], [12, 1, 72], [13, 1, 76], [14, 2, 81]]
	for nt in mel2:
		_tone(b, float(nt[0]) * 0.5, float(nt[1]) * 0.5 + 0.1, _midi(float(nt[2])), 0.55, 0.03, 0.2, 0.0, -1.0, 0.25, 0.08, true)
	for bt in [0.0, 1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0]:
		var tt: float = bt  # 1秒間隔のティンパニ
		_tone(b, tt, 0.6, 110.0, 0.7, 0.003, 0.1, 0.18, 65.0, 0.0, 0.0, true)
	_streams["music_reunion"] = _finish(b, 0.25, true)

	# --- tension: 周期が8秒に収まる周波数のドローン + 遅いトレモロ
	b = _buf(8.0)
	_tone(b, 0.0, 8.0, 55.0, 0.8, 0.0, 0.0, 0.0, -1.0, 0.4, 0.2, true)
	_tone(b, 0.0, 8.0, 55.125, 0.6, 0.0, 0.0, 0.0, -1.0, 0.3, 0.0, true)
	_tone(b, 0.0, 8.0, 82.5, 0.3, 0.0, 0.0, 0.0, -1.0, 0.2, 0.0, true)
	_tone(b, 0.0, 8.0, 116.5, 0.12, 0.0, 0.0, 0.0, -1.0, 0.0, 0.0, true)
	var nb: int = b.size()
	for i in nb:
		b[i] *= 0.7 + 0.3 * sin(TAU * 4.0 * i / nb)
	_streams["music_tension"] = _finish(b, 0.22, true)

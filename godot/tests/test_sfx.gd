extends SceneTree

const ONESHOTS: Array[String] = ["explosion", "explosion_fizzle", "clap", "pickup", "drop", "fix", "unfix",
	"ui_ok", "ui_fail", "cue", "countdown", "countdown_go", "success_fanfare", "thump"]
const MUSIC: Array[String] = ["music_confession", "music_reunion", "music_tension"]

var _played_count: int = 0
var _music_events: Array[String] = []


func _initialize() -> void:
	_run()


func _fail(reason: String) -> void:
	print("SFX_TEST_FAIL: ", reason)
	quit(1)


func _run() -> void:
	await process_frame
	var sfx: Node = root.get_node_or_null("Sfx")
	if sfx == null:
		_fail("Sfx autoload missing")
		return
	for name in ONESHOTS + MUSIC:
		var is_music: bool = name.begins_with("music_")
		if not sfx.has_sound(name):
			_fail("missing sound " + name)
			return
		var s: AudioStreamWAV = sfx.get_stream(name)
		if s == null or s.data.size() == 0:
			_fail("empty stream " + name)
			return
		var n: int = s.data.size() / 2
		var dur: float = float(n) / s.mix_rate
		var peak: int = 0
		for i in n:
			peak = maxi(peak, absi(s.data.decode_s16(i * 2)))
		print("%-18s dur=%.3fs peak=%d" % [name, dur, peak])
		if peak == 0:
			_fail("all-zero " + name)
			return
		if peak >= 32767 or peak <= 2000:
			_fail("peak out of range " + name)
			return
		if is_music:
			if dur < 7.5 or dur > 8.5:
				_fail("music duration " + name)
				return
			if s.loop_mode != AudioStreamWAV.LOOP_FORWARD or s.loop_end != n:
				_fail("loop setup " + name)
				return
			var d0: int = s.data.decode_s16(0)
			var d1: int = s.data.decode_s16((n - 1) * 2)
			if absi(d0 - d1) > peak / 4:
				_fail("loop discontinuity " + name)
				return
		elif dur < 0.05 or dur > 3.0:
			_fail("duration " + name)
			return
	sfx.played.connect(func(_s: String, _p: Variant) -> void: _played_count += 1)
	sfx.music_changed.connect(func(t: String) -> void: _music_events.append(t))
	sfx.play("clap")
	sfx.play("explosion", Vector3(1, 2, 3))
	sfx.play("no_such_sound")
	for i in 100:
		sfx.play("pickup")
	if _played_count != 102:
		_fail("played signal count %d" % _played_count)
		return
	sfx.play_music("music_confession")
	await process_frame
	sfx.play_music("music_reunion", 0.2)
	await process_frame
	if sfx.current_music() != "music_reunion":
		_fail("current_music")
		return
	sfx.stop_music()
	sfx.muted = true
	sfx.play("ui_ok")
	sfx.play_music("music_tension")
	sfx.muted = false
	sfx.silence_all()
	if _music_events != ["music_confession", "music_reunion", "", "music_tension"]:
		_fail("music events " + str(_music_events))
		return
	await process_frame
	var t0: int = Time.get_ticks_msec()
	sfx.resynthesize()
	print("synth_ms (initial)=", sfx.synth_ms, " resynth_ms=", Time.get_ticks_msec() - t0)
	print("SFX_TEST_OK")
	quit()

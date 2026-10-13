extends SceneTree
# 無料素材のSEを加工して、ゲーム用の音を書き出す。
#   godot --headless --path godot --script res://tools/build_sfx.gd
# 素材：tools/diagnostics/ の下に展開した配布物（リポジトリには入れない）。出どころと利用条件は
#       godot/assets/audio/README.md に音ごとに書く。
# 出力：res://assets/audio/sfx/<名前>_<番号>.res（Godot用）と、試聴用の .wav（tools/diagnostics/sfx_preview/）
# 同じ音でも毎回少し違って聞こえるよう、素材の別テイクから数種類ずつ作る。
const RATE := 44100
const OUT := "res://assets/audio/sfx/"
# 再配布できない素材から作った音はこちらへ（.gitignore で公開リポジトリから外す）
const OUT_LOCAL := "res://assets/audio/sfx_local/"
const IMPACT := "res://../tools/diagnostics/kenney_impact/Audio/"
const LAB := "res://../tools/diagnostics/soundeffect_lab/"
const INTERFACE := "res://../tools/diagnostics/kenney_interface-sounds/Audio/"

var _report: Array[String] = []
var _out := OUT
var _only := ""          # 「-- --only=<名前>」で、その音だけを書き出す（ほかの音のファイルは触らない）


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://../tools/diagnostics/sfx_preview"))
	if " ".join(OS.get_cmdline_user_args()).contains("--probe"):
		_probe()
		quit()
		return
	for flag: String in OS.get_cmdline_user_args():
		if flag.begins_with("--only="):
			_only = flag.get_slice("=", 1)
	_out = OUT
	_impacts()
	if DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(INTERFACE)):
		_interface()
	if DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(LAB)):
		_out = OUT_LOCAL
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_LOCAL))
		_lab()
	for line in _report:
		print(line)
	print("BUILD_SFX_OK ", _report.size())
	quit()


# ---- レシピ：衝突音（Kenney Impact Sounds, CC0） ----

func _impacts() -> void:
	for i in 5:
		var n := "%03d" % i
		# 掴む：軽い当たりを少し高く、短く
		var b := pitch(src(IMPACT + "impactGeneric_light_" + n + ".ogg"), 1.18)
		b = highpass(b, 180.0)
		fade_out(b, 0.05, 0.12)
		save("pickup", i, b, 0.5)
		# 置く：木の当たりに、柔らかい低い当たりを重ねる
		b = buf(0.5)
		mix(b, pitch(src(IMPACT + "impactWood_medium_" + n + ".ogg"), 0.95), 0.0, 0.9)
		mix(b, lowpass(pitch(src(IMPACT + "impactSoft_medium_" + n + ".ogg"), 0.8), 900.0), 0.006, 0.7)
		fade_out(b, 0.16, 0.25)
		save("drop", i, b, 0.6)
		# どすん：重い柔らかい当たり＋重い木。低く、こもらせる
		b = buf(0.8)
		mix(b, lowpass(pitch(src(IMPACT + "impactSoft_heavy_" + n + ".ogg"), 0.78), 1400.0), 0.0, 1.0)
		mix(b, lowpass(pitch(src(IMPACT + "impactWood_heavy_" + n + ".ogg"), 0.7), 2200.0), 0.012, 0.6)
		mix(b, lowpass(pitch(src(IMPACT + "impactPunch_heavy_" + n + ".ogg"), 0.6), 500.0), 0.0, 0.5)
		fade_out(b, 0.3, 0.45)
		save("thump", i, b, 0.75)
		# 荷台に積む：板の当たり＋薄い鉄板の響き
		b = buf(0.6)
		mix(b, pitch(src(IMPACT + "impactPlank_medium_" + n + ".ogg"), 0.9), 0.0, 0.9)
		mix(b, lowpass(pitch(src(IMPACT + "impactPlate_light_" + n + ".ogg"), 0.75), 3000.0), 0.01, 0.35)
		fade_out(b, 0.2, 0.35)
		save("load", i, b, 0.62)
		# 固定：金具を2回かける（カチ、カチッ）
		b = buf(0.4)
		mix(b, pitch(src(IMPACT + "impactMetal_light_" + n + ".ogg"), 1.5), 0.0, 0.6)
		mix(b, pitch(src(IMPACT + "impactMetal_light_" + "%03d" % ((i + 2) % 5) + ".ogg"), 1.85), 0.085, 0.9)
		b = highpass(b, 400.0)
		fade_out(b, 0.16, 0.2)
		save("fix", i, b, 0.5)
		# 固定を外す：ブリキを低く1回
		b = pitch(src(IMPACT + "impactTin_medium_" + n + ".ogg"), 1.1)
		b = highpass(b, 300.0)
		fade_out(b, 0.08, 0.18)
		save("unfix", i, b, 0.42)
	for i in 3:
		var n := "%03d" % i
		var m := "%03d" % (i + 2)
		# 門：重い鉄の当たりを低くして、金網の震えを後ろに付ける
		var b := buf(1.3)
		mix(b, lowpass(pitch(src(IMPACT + "impactMetal_heavy_" + n + ".ogg"), 0.62), 3800.0), 0.0, 1.0)
		mix(b, pitch(src(IMPACT + "impactPlate_heavy_" + m + ".ogg"), 0.7), 0.03, 0.45)
		mix(b, highpass(pitch(src(IMPACT + "impactTin_medium_" + n + ".ogg"), 0.9), 900.0), 0.11, 0.3)
		mix(b, highpass(pitch(src(IMPACT + "impactTin_medium_" + m + ".ogg"), 1.05), 900.0), 0.2, 0.18)
		fade_out(b, 0.6, 0.65)
		save("gate", i, b, 0.7)
		# 段差：車体の底を打つ低い音＋荷台のがたつき
		b = buf(1.0)
		mix(b, lowpass(pitch(src(IMPACT + "impactPunch_heavy_" + n + ".ogg"), 0.55), 420.0), 0.0, 1.0)
		mix(b, lowpass(pitch(src(IMPACT + "impactPlate_medium_" + n + ".ogg"), 0.66), 2600.0), 0.02, 0.55)
		mix(b, pitch(src(IMPACT + "impactPlank_medium_" + m + ".ogg"), 0.85), 0.09, 0.4)
		mix(b, pitch(src(IMPACT + "impactTin_medium_" + m + ".ogg"), 0.8), 0.15, 0.3)
		mix(b, pitch(src(IMPACT + "impactWood_light_" + n + ".ogg"), 1.0), 0.24, 0.25)
		fade_out(b, 0.45, 0.5)
		save("bump", i, b, 0.78)


# ---- レシピ：画面の音（Kenney Interface Sounds, CC0） ----
# 画面の音は「短い・角が立たない・同じ楽器の仲間」でそろえる。選ぶ＜開く＜決定 の順に長く、
# 戻る・失敗は低めにする。物音より小さく鳴らす

func _interface() -> void:
	# 選ぶ：ごく短い中くらいの高さの音（2種）
	for i in 2:
		var b := lowpass(src(INTERFACE + ["select_002.ogg", "select_007.ogg"][i]), 7000.0)
		fade_out(b, 0.03, 0.03)
		save("ui_select", i, b, 0.32)
	# 開く：少し低く、余韻のある音
	var b := src(INTERFACE + "select_005.ogg")
	fade_out(b, 0.1, 0.12)
	save("ui_open", 0, b, 0.34)
	# 戻る・閉じる：短く低い音
	b = pitch(src(INTERFACE + "back_003.ogg"), 0.9)
	fade_out(b, 0.05, 0.05)
	save("ui_back", 0, b, 0.3)
	# 決定：2音の上がる音
	b = src(INTERFACE + "confirmation_001.ogg")
	fade_out(b, 0.2, 0.12)
	save("ui_ok", 0, b, 0.4)
	# 失敗・足りない：下がる音
	b = pitch(src(INTERFACE + "error_003.ogg"), 0.85)
	fade_out(b, 0.24, 0.12)
	save("ui_fail", 0, b, 0.38)


# ---- レシピ：効果音ラボの素材（再配布不可。出力は公開リポジトリに入れない） ----
# もともと完成された音なので、加工は「切る・重ねる・高さを少し変える・余韻を整える」にとどめる

func _lab() -> void:
	# 爆発：ドカーンを主音に、長い大爆発の低い余韻を足す
	var tail := lowpass(cut(src(LAB + "big-explosion1.mp3"), 0.0, 4.0), 900.0)
	for i in 2:
		var b := buf(4.2)
		mix(b, src(LAB + ["bomb4.mp3", "bomb3.mp3"][i]), 0.0, 1.0)
		mix(b, tail, 0.03, 0.45)
		fade_out(b, 2.2, 1.6)
		save("explosion", i, b, 0.9)
	# 不発：しけったマッチ＋気の抜けたラッパ
	var b := buf(0.8)
	mix(b, src(LAB + "matchstick-failure1.mp3"), 0.0, 1.0)
	mix(b, pitch(src(LAB + "pafu1.mp3"), 0.84), 0.12, 0.7)
	fade_out(b, 0.4, 0.3)
	save("explosion_fizzle", 0, b, 0.6)
	# 導火線：しけったマッチの「シュッ」を高さ違いで3つ。燃えている間、細かく鳴らしてパチパチに聞かせる
	for i in 3:
		var hiss := pitch(cut(src(LAB + "matchstick-failure1.mp3"), 0.0, 0.16), [1.0, 1.22, 0.86][i])
		fade_out(hiss, 0.07, 0.06)
		save("fuse", i, hiss, 0.5)
	# 怪獣の鳴き声：2種類。足元の地響きをうっすら足す
	var rumble := lowpass(src(LAB + "monster-footstep1.mp3"), 300.0)
	b = buf(3.2)
	mix(b, src(LAB + "dragon-cry1.mp3"), 0.0, 1.0)
	mix(b, rumble, 0.05, 0.35)
	fade_out(b, 2.4, 0.75)
	save("roar", 0, b, 0.85)
	b = buf(1.9)
	mix(b, pitch(src(LAB + "dragon-cry2.mp3"), 0.92), 0.0, 1.0)
	mix(b, rumble, 0.03, 0.35)
	fade_out(b, 1.2, 0.6)
	save("roar", 1, b, 0.85)
	# どすん（倒れる・落ちる）
	b = cut(src(LAB + "real-down1.mp3"), 0.0, 0.7)
	fade_out(b, 0.4, 0.3)
	save("thump", 0, b, 0.75)
	b = buf(0.8)
	mix(b, pitch(src(LAB + "real-down1.mp3"), 0.88), 0.0, 1.0)
	mix(b, src(LAB + "stick-fall1.mp3"), 0.05, 0.4)
	fade_out(b, 0.45, 0.3)
	save("thump", 1, b, 0.75)
	b = pitch(src(LAB + "firewood-put1.mp3"), 0.8)
	fade_out(b, 0.45, 0.3)
	save("thump", 2, b, 0.75)
	# 置く
	var puts := ["brick1.mp3", "bucket-put1.mp3", "firewood-put2.mp3"]
	for i in 3:
		b = src(LAB + puts[i])
		fade_out(b, 0.3, 0.25)
		save("drop", i, b, 0.6)
	# 掴む：布ごと掴む音を、高さ違いで3つ
	var grab := src(LAB + "grap1.mp3")
	for i in 3:
		b = pitch(grab, [1.0, 1.12, 0.92][i])
		fade_out(b, 0.22, 0.14)
		save("pickup", i, b, 0.5)
	# 荷台に積む：薪を置く音＋薄い鉄板の響き
	var plate := lowpass(cut(src(LAB + "iron-plate2.mp3"), 0.0, 0.7), 2600.0)
	for i in 2:
		b = buf(0.9)
		mix(b, src(LAB + ["firewood-put1.mp3", "firewood-put2.mp3"][i]), 0.0, 1.0)
		mix(b, pitch(plate, 0.8), 0.01, 0.22)
		fade_out(b, 0.4, 0.4)
		save("load", i, b, 0.65)
	# 固定・固定を外す：カチッ／カコッ／コカッ
	for i in 2:
		b = cut(src(LAB + ["decision31.mp3", "decision50.mp3"][i]), 0.0, 0.3)
		fade_out(b, 0.12, 0.15)
		save("fix", i, b, 0.5)
	b = cut(src(LAB + "decision44.mp3"), 0.0, 0.3)
	fade_out(b, 0.1, 0.15)
	save("unfix", 0, b, 0.45)
	# 門：ギギギ…と開いて、ガシャンと止まる
	b = buf(2.9)
	mix(b, src(LAB + "gate-open1.mp3"), 0.0, 1.0)
	mix(b, src(LAB + "iron-door-close1.mp3"), 1.5, 0.7)
	fade_out(b, 2.2, 0.6)
	save("gate", 0, b, 0.7)
	# 段差：荷台の扉の「ドン」＋工具ががちゃつく音
	var tools := src(LAB + "tool-box1.mp3")
	for i in 2:
		b = buf(1.4)
		mix(b, pitch(src(LAB + "truck-carrier-door1.mp3"), 0.85), 0.0, 1.0)
		mix(b, cut(tools, [0.03, 2.02][i], [0.82, 2.81][i]), 0.07, 0.5)
		fade_out(b, 0.8, 0.5)
		save("bump", i, b, 0.8)
	# 出発：エンジンをかける
	b = cut(src(LAB + "car-engine1.mp3"), 0.0, 3.4)
	fade_out(b, 2.4, 1.0)
	save("engine", 0, b, 0.6)
	# カウントダウン：プッ（1回ぶん）と、最後のピー
	var count := src(LAB + "electronic-countdown1.mp3")
	b = cut(count, 0.0, 0.62)
	fade_out(b, 0.5, 0.1)
	save("countdown", 0, b, 0.5)
	b = cut(count, 2.97, 4.6)
	fade_out(b, 1.3, 0.3)
	save("countdown_go", 0, b, 0.55)
	# 成功：ラッパのファンファーレ＋歓声と拍手
	b = buf(4.6)
	mix(b, src(LAB + "trumpet1.mp3"), 0.0, 1.0)
	mix(b, src(LAB + "people-performance-cheer1.mp3"), 0.55, 0.5)
	fade_out(b, 3.4, 1.1)
	save("success_fanfare", 0, b, 0.75)
	# 画面の音：撮影所にある物の音でそろえる（スイッチ・木の小さな当たり）。ごく短く、小さく
	for i in 2:
		b = cut(src(LAB + ["decision44.mp3", "decision50.mp3"][i]), 0.0, 0.12)
		b = lowpass(b, 6000.0)
		fade_out(b, 0.05, 0.06)
		save("ui_select", i, b, 0.26)
	b = cut(src(LAB + "switch1.mp3"), 0.0, 0.17)
	fade_out(b, 0.09, 0.08)
	save("ui_open", 0, b, 0.3)
	b = pitch(cut(src(LAB + "decision44.mp3"), 0.0, 0.12), 0.72)
	fade_out(b, 0.06, 0.08)
	save("ui_back", 0, b, 0.26)
	b = buf(0.4)
	mix(b, cut(src(LAB + "electricity-switch1.mp3"), 0.0, 0.1), 0.0, 0.8)
	mix(b, cut(src(LAB + "decision7.mp3"), 0.0, 0.2), 0.035, 1.0)
	fade_out(b, 0.16, 0.14)
	save("ui_ok", 0, b, 0.36)
	b = cut(src(LAB + "cancel9.mp3"), 0.0, 0.3)
	fade_out(b, 0.16, 0.12)
	save("ui_fail", 0, b, 0.36)
	# 突風：野外の空き地で、ときどき吹く
	b = cut(src(LAB + "wind1.mp3"), 0.3, 4.3)
	for i in int(0.5 * RATE):
		b[i] *= float(i) / (0.5 * RATE)
	fade_out(b, 2.6, 1.3)
	save("wind", 0, b, 0.6)
	# 合図
	b = cut(src(LAB + "decision38.mp3"), 0.0, 0.3)
	fade_out(b, 0.12, 0.15)
	save("cue", 0, b, 0.55)


# 素材の長さと、音が鳴っている区間を表示する（耳で聞けない代わりの下調べ）
func _probe() -> void:
	# 「-- --probe=<フォルダ>」で、別の素材フォルダも調べられる
	var from := LAB
	for flag: String in OS.get_cmdline_user_args():
		if flag.begins_with("--probe="):
			from = flag.get_slice("=", 1)
	var dir := ProjectSettings.globalize_path(from)
	for name in DirAccess.get_files_at(dir):
		if not (name.ends_with(".mp3") or name.ends_with(".ogg")):
			continue
		var b := src(from + name)
		var parts: Array[String] = []
		for r: Vector2 in regions(b, 0.02, 0.06):
			parts.append("%.2f-%.2f" % [r.x, r.y])
		var loud := 0.0
		var cross := 0
		for i in range(1, b.size()):
			loud += b[i] * b[i]
			if (b[i] >= 0.0) != (b[i - 1] >= 0.0):
				cross += 1
		# 高さの目安＝ゼロをまたぐ回数から出した周波数
		print("PROBE %-34s %.2f秒  高さ%5dHz  %s" % [name, b.size() / float(RATE), int(cross * 0.5 / maxf(b.size() / float(RATE), 0.01)), " ".join(parts)])


# 音が鳴っている区間（秒）を返す。level より大きい所を、gap 秒以内の切れ目はつないで1区間にする
func regions(b: PackedFloat32Array, level: float, gap: float) -> Array:
	var out: Array = []
	var win := int(0.005 * RATE)
	var start := -1.0
	var last := -1.0
	var i := 0
	while i < b.size():
		var top := 0.0
		for k in range(i, mini(i + win, b.size())):
			top = maxf(top, absf(b[k]))
		var t := i / float(RATE)
		if top > level:
			if start < 0.0:
				start = t
			last = t + 0.005
		elif start >= 0.0 and t - last > gap:
			out.append(Vector2(start, last))
			start = -1.0
		i += win
	if start >= 0.0:
		out.append(Vector2(start, last))
	return out


# from 秒から to 秒までを切り出す
func cut(b: PackedFloat32Array, from: float, to: float) -> PackedFloat32Array:
	return b.slice(clampi(int(from * RATE), 0, b.size()), clampi(int(to * RATE), 0, b.size()))


# ---- 部品 ----

func buf(sec: float) -> PackedFloat32Array:
	var b := PackedFloat32Array()
	b.resize(int(sec * RATE))
	return b


# 素材を読み、モノラルの波形にする
func src(path: String) -> PackedFloat32Array:
	var full := ProjectSettings.globalize_path(path)
	var stream: AudioStream = AudioStreamMP3.load_from_file(full) if full.ends_with(".mp3") else AudioStreamOggVorbis.load_from_file(full)
	if stream == null:
		push_error("素材が読めない：" + full)
		return buf(0.1)
	var pb := stream.instantiate_playback()
	pb.start(0.0)
	var want := int(stream.get_length() * AudioServer.get_mix_rate())
	var out := PackedFloat32Array()
	while out.size() < want:
		var frames := pb.mix_audio(1.0, mini(4096, want - out.size()))
		if frames.is_empty():
			break
		for v: Vector2 in frames:
			out.append((v.x + v.y) * 0.5)
	if not is_equal_approx(AudioServer.get_mix_rate(), float(RATE)):
		out = pitch(out, AudioServer.get_mix_rate() / float(RATE))
	return out


# 高さを変える（1より大きいと高く短く）
func pitch(b: PackedFloat32Array, ratio: float) -> PackedFloat32Array:
	var n := int(b.size() / ratio)
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		var p := i * ratio
		var k := int(p)
		var f := p - k
		var a: float = b[k]
		var c: float = b[mini(k + 1, b.size() - 1)]
		out[i] = lerpf(a, c, f)
	return out


func lowpass(b: PackedFloat32Array, cutoff: float) -> PackedFloat32Array:
	var out := b.duplicate()
	var a := 1.0 - exp(-TAU * cutoff / RATE)
	# 2回かけて、切れ味を上げる
	for pass_n in 2:
		var y := 0.0
		for i in out.size():
			y += a * (out[i] - y)
			out[i] = y
	return out


func highpass(b: PackedFloat32Array, cutoff: float) -> PackedFloat32Array:
	var low := lowpass(b, cutoff)
	var out := b.duplicate()
	for i in out.size():
		out[i] -= low[i]
	return out


func mix(dst: PackedFloat32Array, s: PackedFloat32Array, at_sec: float, gain: float) -> void:
	var o := int(at_sec * RATE)
	for i in s.size():
		if o + i >= dst.size():
			break
		dst[o + i] += s[i] * gain


# start 秒から dur 秒かけて消し、その先は切る
func fade_out(b: PackedFloat32Array, start: float, dur: float) -> void:
	var s := int(start * RATE)
	var e := mini(int((start + dur) * RATE), b.size())
	for i in range(s, e):
		var u := float(i - s) / float(maxi(e - s, 1))
		b[i] *= (1.0 - u) * (1.0 - u)
	b.resize(e)


# つなぎ目が分からないよう、終わりの1秒を頭へ重ねてから、くり返し再生の音として書き出す
func save_loop(name: String, b: PackedFloat32Array, level: float) -> void:
	if _only != "" and name != _only:
		return
	var blend := RATE
	var n := b.size() - blend
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		out[i] = b[i]
	for i in blend:
		var u := float(i) / float(blend)
		out[i] = b[i] * u + b[n + i] * (1.0 - u)
	var power := 0.0
	for v in out:
		power += v * v
	var gain := level / maxf(sqrt(power / float(n)), 0.00001)
	var bytes := PackedByteArray()
	bytes.resize(n * 2)
	for i in n:
		bytes.encode_s16(i * 2, int(clampf(out[i] * gain, -1.0, 1.0) * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.stereo = false
	wav.data = bytes
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wav.loop_begin = 0
	wav.loop_end = n
	ResourceSaver.save(wav, "%s%s_0.res" % [_out, name])
	wav.save_to_wav(ProjectSettings.globalize_path("res://../tools/diagnostics/sfx_preview/%s%s_0.wav" % ["local_" if _out == OUT_LOCAL else "", name]))
	_report.append("SFX %s_0  %.2f秒（くり返し）" % [name, n / float(RATE)])


func save(name: String, index: int, b: PackedFloat32Array, peak: float) -> void:
	if _only != "" and name != _only:
		return
	# 頭の無音を詰め、音量をそろえ、出だしのプチ音を消す
	var first := 0
	while first < b.size() - 1 and absf(b[first]) < 0.004:
		first += 1
	b = b.slice(maxi(first - 8, 0))
	var top := 0.0001
	for v in b:
		top = maxf(top, absf(v))
	var bytes := PackedByteArray()
	bytes.resize(b.size() * 2)
	for i in b.size():
		var v: float = b[i] / top * peak * minf(i / 24.0, 1.0)
		bytes.encode_s16(i * 2, int(clampf(v, -1.0, 1.0) * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.stereo = false
	wav.data = bytes
	ResourceSaver.save(wav, "%s%s_%d.res" % [_out, name, index])
	var tag := "local_" if _out == OUT_LOCAL else ""
	wav.save_to_wav(ProjectSettings.globalize_path("res://../tools/diagnostics/sfx_preview/%s%s_%d.wav" % [tag, name, index]))
	_report.append("SFX %s_%d  %.2f秒" % [name, index, b.size() / float(RATE)])

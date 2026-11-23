extends RefCounted
## 編集の台本（リール）を組む。計算だけ（どこからでも呼べる）。使うのは features/editors.gd の、名匠（pro）とド派手（hype）。
## 考え方と、元にした 2 本の動画は docs/production/editing-craft.md。
##   ・台本は「出来上がりの秒」で並べる（曲が先。絵は、曲の拍に合わせて切る）。出来上がりは、どちらも 28 秒ほど
##   ・1 行：[出来上がりの始め, 終わり, 素材の始め, 速さ, 寄り, 静かに]
##       寄り：[] 寄らない ／ ["actor", 役者の番号, 始めの倍率, 終わりの倍率] ／ ["at", [x, y, z], …] 世界の中の点 ／ ["prop", 物の番号, …, 上へずらす割合] 役の物 ／ ["uv", [u, v], …] 画面の中の点
##       静かに：true なら、その間の効果音と爆発の合図は出さない（刻み・止め・NG）
##   ・効果と字も、出来上がりの秒で：[始め, 終わり, 種類, 文, おまけ]
##   ・手は、素材から決める：役者ごとの一番大きく映った時刻（faces）・場面が撮れた時刻（passes）・爆発（bursts）・映り込み・間。
##     無い物の分は、名匠は長さを詰め直してまとめる。ド派手は、何も無い絵に効果だけが乗る（精算で引かれる）
const PRO_OUT := 28.0
const PRO_MUSIC := "edit_pro"
const HYPE_BPM := 128.0
const HYPE_MUSIC := "edit_hype"
const ZOOM_MAX := 1.8            # 撮影カメラの絵は 1280×720。これより寄ると、ぼける


# d から、使いやすい形に（時刻の順）
static func _read(d: Dictionary) -> Dictionary:
	var dur := maxf(float(d.get("dur", 0.0)), 1.0)
	var passes: Array = []
	for i in (d.get("passes", []) as Array).size():
		var p := float(d["passes"][i])
		if p >= 0.0:
			passes.append([p, i])
	passes.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
	var faces: Array = (d.get("faces", []) as Array).duplicate(true)
	faces.sort_custom(func(a: Array, b: Array) -> bool: return float(a[1]) < float(b[1]))
	var bursts: Array = d.get("bursts", [])
	var info: Array = d.get("burst_info", [])
	var has_burst := not bursts.is_empty()
	var peak := dur * 0.6
	if has_burst:
		peak = float(bursts[0])
	elif passes.size() >= 2:
		peak = float(passes[-2][0])
	elif passes.size() == 1:
		peak = float(passes[0][0])
	var final := -1.0
	var final_i := -1
	if not passes.is_empty() and float(passes[-1][0]) > peak + 0.5:
		final = float(passes[-1][0])
		final_i = int(passes[-1][1])
	var at: Array = []
	var burst_kind := ""
	if has_burst and not info.is_empty():
		at = info[0][0]
		burst_kind = str(info[0][1])
	return {"dur": dur, "top": dur - 0.05, "passes": passes, "faces": faces, "has_burst": has_burst, "peak": peak, "final": final, "final_i": final_i,
		"burst_at": at, "burst_kind": burst_kind, "titles": d.get("titles", []), "net": bool(d.get("net", false)),
		"things": d.get("things", {}), "scene_roles": d.get("scene_roles", []),
		"cameo": d.get("cameo", []), "dead": d.get("dead", []), "job": str(d.get("job", "")), "company": str(d.get("company", ""))}


static func _title(r: Dictionary, i: int) -> String:
	var titles: Array = r["titles"]
	return str(titles[i]).split("（")[0] if i >= 0 and i < titles.size() else ""


# 1 行足す。素材の時刻は、テイクの中に収める（終わりに届くと、見返しが終わってしまう）
static func _seg(reel: Array, top: float, o0: float, o1: float, s0: float, speed: float, crop: Array = [], quiet: bool = false) -> float:
	if o1 - o0 < 0.001:
		return s0
	s0 = clampf(s0, 0.0, top)
	if s0 + (o1 - o0) * speed > top:
		speed = maxf((top - s0) / (o1 - o0), 0.0)
	reel.append([o0, o1, s0, speed, crop, quiet])
	return s0 + (o1 - o0) * speed


# from〜end の間に、切りたい所（誰も映っていない間・映り込み）が挟まっていたら、その後ろから始める
static func _clean_from(r: Dictionary, from: float, end: float) -> float:
	for s: Array in (r["dead"] as Array) + (r["cameo"] as Array):
		if float(s[1]) > from and float(s[0]) < end - 0.4:
			from = maxf(from, minf(float(s[1]) + 0.1, end - 0.4))
	return from


# その場面の、役の物（城・月 など）への寄り。隠れずに映った物が無ければ、決まった所（other）へ
static func _thing(r: Dictionary, scene_i: int, z0: float, z1: float, up: float, other: Array) -> Array:
	var roles: Array = r["scene_roles"]
	var role := str(roles[scene_i]) if scene_i >= 0 and scene_i < roles.size() else ""
	var things: Dictionary = r["things"]
	if role == "" or not things.has(role):
		return other
	return ["prop", int(things[role]), z0, z1, up]


static func _zoom(crop: Array) -> Array:
	if crop.size() >= 4:
		crop[2] = minf(float(crop[2]), ZOOM_MAX)
		crop[3] = minf(float(crop[3]), ZOOM_MAX)
	return crop


# ---- 名匠（上手くて安定）：大作の予告の顔で始めて、一打のあとに無音。明るい曲で締めて、切った所は NG のおまけに ----
# 曲（edit_pro、120 BPM）の目印：0 持続音 ／ 2・3.5・5・6.5 ティンパニ ／ 8 金管 ／ 12〜14 連打 ／ 14.0 一打 ／ 15.4〜17.6 無音 ／ 17.6 明るい曲 ／ 24.0 薄く
static func pro(d: Dictionary) -> Dictionary:
	var r := _read(d)
	var reel: Array = []
	var fx: Array = []
	var top: float = r["top"]
	var peak: float = r["peak"]
	var build_from := maxf(peak - 0.8, 0.0)
	var faces: Array = (r["faces"] as Array).filter(func(f: Array) -> bool: return float(f[1]) < build_from - 0.5).slice(0, 4)
	var shown := 0
	fx.append([0.0, 18.1, "bars", "", 0.5])
	fx.append([0.0, 17.6, "look", "", 7])
	fx.append([17.6, PRO_OUT, "look", "", 8])
	# 0〜2：一番はじめの顔を、ゆっくり。題は明朝で
	var open_at := maxf((float(faces[0][1]) if not faces.is_empty() else 0.0) - 1.0, 0.0)
	var open_crop: Array = ["actor", int(faces[0][0]), 1.2, 1.3] if not faces.is_empty() else []
	var cursor := _seg(reel, top, 0.0, 2.0, open_at, 0.6, open_crop)
	if str(r["job"]) != "":
		fx.append([0.35, 1.9, "t_title", str(r["job"]).split("（")[0], 0])
	# 2〜8：一人ずつ。ティンパニの拍で切る（4 人なら 1.5 秒ずつ。少なければ、長く）
	var lens: Array = {0: [], 1: [6.0], 2: [3.0, 3.0], 3: [1.5, 1.5, 3.0], 4: [1.5, 1.5, 1.5, 1.5]}[faces.size()]
	var o := 2.0
	for k in faces.size():
		var f: Array = faces[k]
		var length: float = lens[k]
		var speed := 1.0 if length <= 1.5 else 0.75
		var from := clampf(float(f[1]) - 0.5, 0.0, maxf(build_from - length * speed, 0.0))
		cursor = _seg(reel, top, o, o + length, from, speed, ["actor", int(f[0]), 1.3, 1.42])
		var name := str(f[3]) if f.size() >= 4 else ""
		if name != "":
			var why := str(f[4]) if f.size() >= 5 else ("" if bool(f[2]) else "cut")
			fx.append([o + 0.15, o + length - 0.1, "t_name", name + str({"cut": "　（頭は入りませんでした）", "hidden": "　（物に隠れていました）"}.get(why, "")), 0])
		o += length
		shown += 1
	if faces.is_empty():
		var until := maxf(minf(cursor + 6.0, build_from - 4.0), cursor)
		cursor = _seg(reel, top, 2.0, 8.0, cursor, (until - cursor) / 6.0)
	# 8〜12：寄りから引いて、全部見せる（山場より前に撮れた、いちばん後ろの場面）
	var reveal: Array = []
	for p: Array in r["passes"]:
		if float(p[0]) < build_from - 0.3 and int(p[1]) != int(r["final_i"]):
			reveal = p
	if not reveal.is_empty():
		var end := minf(float(reveal[0]) + 1.0, build_from)
		var from := _clean_from(r, maxf(end - 4.0, 0.0), end)
		var speed := (end - from) / 4.0
		cursor = _seg(reel, top, 8.0, 10.4, from, speed, _thing(r, int(reveal[1]), 1.7, 1.0, 0.6, ["uv", [0.5, 0.36], 1.7, 1.0]))
		cursor = _seg(reel, top, 10.4, 12.0, cursor, speed)
		fx.append([8.7, 11.7, "t_lower", _title(r, int(reveal[1])), 0])
		shown += 1
	else:
		var from := maxf(build_from - 4.0, minf(cursor, build_from))
		cursor = _seg(reel, top, 8.0, 12.0, from, (build_from - from) / 4.0)
	# 12〜14：山場の前の溜め。時間は飛ばさずにゆっくり流して、寄る倍率だけを、拍 → 半拍 → 4 分の 1 拍で替える
	var aim: Array = ["at", r["burst_at"]] if not (r["burst_at"] as Array).is_empty() else ["uv", [0.5, 0.42]]
	var steps := [12.0, 12.5, 13.0, 13.25, 13.5, 13.75, 14.0]
	var slow := (peak - 0.02 - build_from) / 2.0
	cursor = build_from
	for k in steps.size() - 1:
		var z := 1.1 + 0.11 * float(k)
		cursor = _seg(reel, top, steps[k], steps[k + 1], cursor, slow, _zoom(aim + [z, z + 0.03]), true)
	var words := _title(r, _peak_title(r)).split("、")
	if words.size() >= 2:
		fx.append([12.1, 14.0, "t_build", words[0] + "、", 0])
	# 14〜15.4：一打。ここだけ全部のせ（スロー・揺れ・白い光・大きな字）
	cursor = _seg(reel, top, 14.0, 15.4, peak - 0.02, 0.36, ["uv", [0.5, 0.45], 1.05, 1.0])
	fx.append([14.0, 14.4, "flash", "", 0])
	fx.append([14.0, 14.8, "shake", "", 0])
	var big := words[-1] if not words.is_empty() else ""
	if big != "":
		fx.append([14.04, 15.4, "t_big", big.trim_suffix("！").trim_suffix("。") + "。", 0])
	if bool(r["has_burst"]) or not (r["passes"] as Array).is_empty():
		shown += 1
	# 15.4〜17.6：無音。爆発が書割だったら、その板に寄って、正直に書く
	if str(r["burst_kind"]) == "flat":
		cursor = _seg(reel, top, 15.4, 17.6, cursor, 0.5, _zoom(["at", r["burst_at"], 1.0, 1.55]))
		fx.append([15.9, 17.45, "t_note", "※ 爆発は、板に描いた絵です", 0])
	else:
		cursor = _seg(reel, top, 15.4, 17.6, cursor, 0.5, ["uv", [0.5, 0.45], 1.0, 1.05])
	# 17.6〜24：黒い帯が開いて、明るい色に。最後の場面を、そのままの速さで
	var final: float = r["final"]
	var end := minf((final + 2.0) if final >= 0.0 else cursor + 6.4, top)
	var from := _clean_from(r, clampf(end - 6.4, minf(cursor, end), end), end)
	var speed := maxf((end - from) / 6.4, 0.05)
	cursor = _seg(reel, top, 17.6, 24.0, from, speed)
	var end_at := clampf(17.6 + (final - from) / speed, 18.2, 22.0) if final >= 0.0 else 19.0
	var ng: Array = _ng_spans(r)
	var end_until := 24.0 if not ng.is_empty() else 27.6
	var last := _title(r, int(r["final_i"]))
	if last != "":
		fx.append([end_at, end_until, "t_end", last, 0])
		shown += 1
	if str(r["company"]) != "":
		fx.append([end_at + 1.2, end_until, "t_sub", str(r["company"]), 0])
	# 24〜27.5：切った所（映り込み・誰も映っていない間）を、小さな窓の NG に
	if ng.is_empty():
		cursor = _seg(reel, top, 24.0, PRO_OUT, cursor, 0.3)
	else:
		var each := 3.5 / float(ng.size())
		for k in ng.size():
			var o0 := 24.0 + each * float(k)
			cursor = _seg(reel, top, o0, o0 + each, float(ng[k][0]), 1.0, [], true)
			fx.append([o0, o0 + each, "t_ng", str(ng[k][2]), 0])
		fx.append([24.0, PRO_OUT, "window", "", 0])
		_seg(reel, top, 27.5, PRO_OUT, cursor, 0.0, [], true)
	var who := "名匠フェイブル"
	var lines: Array = [["編集代（%s）" % who, -250]]
	if shown == 0:
		lines.append(["編集：素材が少ないが、まとめた", 60])
	else:
		lines.append(["編集：28 秒の予告編に仕立てた", 120])
		lines.append(["編集：見せ場を、曲の拍に合わせた ×%d" % shown, mini(shown * 40, 200)])
	if not ng.is_empty():
		lines.append(["編集：切った所を、NG のおまけにした", 30])
	var net: bool = r["net"]
	var cues: Array = [[minf(peak + 0.3, top), "編集うますぎん？" if net else "……編集が、上手い", "happy"]]
	if shown >= 3:
		cues.append([maxf(top - 0.4, 0.5), "これ本当に同じ会社？" if net else "同じ素材とは思えない……！", "wow"])
	return {"reel": reel, "fx": fx, "out": PRO_OUT, "music": PRO_MUSIC, "bpm": 120.0, "lines": lines, "cues": cues}


# 山場の場面の番号（爆発にいちばん近い時刻に撮れた場面。無ければ、山場の時刻より前の最後）
static func _peak_title(r: Dictionary) -> int:
	var best := -1
	var gap := 99.0
	for p: Array in r["passes"]:
		var g := absf(float(p[0]) - float(r["peak"]))
		if int(p[1]) != int(r["final_i"]) and g < gap:
			gap = g
			best = int(p[1])
	return best


# NG に回す所（映り込みを先に、次に誰も映っていない間。2 つまで。それぞれ 1.2 秒より長い所）
static func _ng_spans(r: Dictionary) -> Array:
	var out: Array = []
	for s: Array in r["cameo"]:
		if float(s[1]) - float(s[0]) >= 0.6 and out.is_empty():
			out.append([float(s[0]), float(s[1]), "※ 撮影中、スタッフが映りました"])
	for s: Array in r["dead"]:
		if float(s[1]) - float(s[0]) >= 1.2 and out.size() < 2:
			out.append([float(s[0]) + 0.3, float(s[1]), "※ カメラが、よそを向いていました"])
	return out


# ---- ド派手（上手くて不安定）：28 秒ずっとサビ。全部の切り替えが拍の上 ----
# 曲（edit_hype、128 BPM、1 小節 1.875 秒）：0〜2 小節 導入 ／ 2〜6 平歌 ／ 6〜14 サビ（10 小節目の頭が、山場）／ 14 小節目の頭で一打
# 枠は 8 つ：顔 4 人・見せ場 2 つ・爆発・締め。素材があれば「拍に乗った」、無ければ、何も無い絵に効果だけが乗る
static func hype(d: Dictionary) -> Dictionary:
	var r := _read(d)
	var reel: Array = []
	var fx: Array = []
	var top: float = r["top"]
	var dur: float = r["dur"]
	var peak: float = r["peak"]
	var beat := 60.0 / HYPE_BPM
	var bar := beat * 4.0
	var out := bar * 14.0 + 1.6
	var faces: Array = (r["faces"] as Array).slice(0, 4)
	var hits := 0
	var misses := 0
	fx.append([0.0, out, "look", "", 9])
	fx.append([bar * 2.0, bar * 14.0, "pulse", "", beat])
	# 導入 2 小節：題を 2 つに割って、字の形の窓にする（字の中だけ、絵が見える）
	var job := str(r["job"]).split("（")[0]
	var half := int(ceil(job.length() / 2.0))
	var first_at := maxf((float(faces[0][1]) if not faces.is_empty() else 0.0) - 0.8, 0.0)
	var first_crop: Array = ["actor", int(faces[0][0]), 1.35, 1.45] if not faces.is_empty() else ["uv", [0.5, 0.42], 1.2, 1.3]
	var cursor := _seg(reel, top, 0.0, bar, first_at, 1.0, first_crop)
	cursor = _seg(reel, top, bar, bar * 2.0, cursor, 1.0, first_crop)
	if job.length() >= 2:
		fx.append([0.0, bar, "k_mask", job.substr(0, half), 0])
		fx.append([bar, bar * 2.0, "k_mask", job.substr(half), 0])
	# 平歌 4 小節：1 人 1 小節。3 拍は寄りながら流し、4 拍目で止めて 2 色刷り、名前を絵に焼き込む
	for k in 4:
		var o := bar * float(2 + k)
		fx.append([o, o + 0.2, "rgb", "", 0])
		if k < faces.size():
			var f: Array = faces[k]
			var from := maxf(float(f[1]) - beat * 2.4, 0.0)
			cursor = _seg(reel, top, o, o + beat * 3.0, from, 1.0, ["actor", int(f[0]), 1.3, 1.55])
			_seg(reel, top, o + beat * 3.0, o + bar, cursor, 0.0, ["actor", int(f[0]), 1.55, 1.6], true)
			fx.append([o + beat * 3.0, o + bar, "duo", "", k])
			fx.append([o + beat * 3.0, o + bar, "k_burn", str(f[3]) if f.size() >= 4 else "", 0])
			hits += 1
		else:
			cursor = _seg(reel, top, o, o + beat * 3.0, dur * float(k + 1) / 6.0, 1.0, ["uv", [0.5, 0.45], 1.2, 1.45])
			_seg(reel, top, o + beat * 3.0, o + bar, cursor, 0.0, ["uv", [0.5, 0.45], 1.45, 1.5], true)
			fx.append([o + beat * 3.0, o + bar, "duo", "", k])
			fx.append([o + beat * 3.0, o + bar, "k_burn", "？", 0])
			misses += 1
	# サビ 1・2 小節目：見せ場（山場と締め以外に撮れた場面）。同じ言葉の壁が流れて、最後の半拍で絵の中へ突っ込む
	var build_from := maxf(peak - 1.5, 0.0)
	var peak_i := _peak_title(r) if bool(r["has_burst"]) else -1
	var highs: Array = (r["passes"] as Array).filter(func(p: Array) -> bool: return int(p[1]) != int(r["final_i"]) and float(p[0]) < peak and int(p[1]) != peak_i)
	highs = highs.slice(maxi(highs.size() - 2, 0))
	for k in 2:
		var o := bar * float(6 + k)
		fx.append([o, o + 0.2, "rgb", "", 0])
		var from := dur * float(k + 2) / 5.0
		var words := "……"
		var wide: Array = ["uv", [0.5, 0.42], 1.0, 1.15]
		var dive: Array = ["uv", [0.5, 0.42], 1.15, ZOOM_MAX]
		if k < highs.size():
			wide = _thing(r, int(highs[k][1]), 1.0, 1.15, 0.0, wide)
			dive = _thing(r, int(highs[k][1]), 1.15, ZOOM_MAX, 0.0, dive)
			from = _clean_from(r, clampf(float(highs[k][0]) - 1.3, 0.0, maxf(build_from - bar, 0.0)), float(highs[k][0]) + 0.5)
			words = _title(r, int(highs[k][1]))
			hits += 1
		else:
			misses += 1
		cursor = _seg(reel, top, o, o + beat * 3.5, from, 1.0, wide)
		_seg(reel, top, o + beat * 3.5, o + bar, cursor, 1.0, dive, true)
		fx.append([o + beat * 3.5, o + bar + 0.08, "flash", "", 0])
		fx.append([o, o + bar, "k_wall", words, k])
	# サビ 3・4 小節目：山場の前を、8 分 → 16 分で刻む。最後の 2 拍は、白黒反転の点滅
	var aim: Array = ["at", r["burst_at"]] if not (r["burst_at"] as Array).is_empty() else ["uv", [0.5, 0.42]]
	var o8 := bar * 8.0
	for j in 4:
		var piece := maxf(peak - 1.4 + 0.3 * float(j), 0.0)
		var z := 1.08 + 0.1 * float(j)
		for n in 2:
			var at := o8 + beat * (float(j) + 0.5 * float(n))
			_seg(reel, top, at, at + beat * 0.5, piece, 1.0, _zoom(aim + [z, z + 0.04]), true)
	var o9 := bar * 9.0
	for j in 8:
		var at := o9 + beat * 0.25 * float(j)
		var z := 1.4 + 0.05 * float(j)
		_seg(reel, top, at, at + beat * 0.25, maxf(peak - 0.2, 0.0), 1.0, _zoom(aim + [z, z]), true)
	_seg(reel, top, o9 + beat * 2.0, bar * 10.0, maxf(peak - 0.02 - beat, 0.0), 0.5, _zoom(aim + [1.2, 1.5]), true)
	fx.append([o9 + beat * 2.0, bar * 10.0, "strobe", "", beat * 0.25])
	var words := _title(r, _peak_title(r)).split("、")
	if words.size() >= 2:
		fx.append([o8, bar * 10.0 - 0.05, "k_slam", words[0], 0])
	# サビ 5 小節目：山場。同じ 1 拍を 3 回、拍ごとに少しずつ寄る。4 拍目で先へ
	var o10 := bar * 10.0
	for j in 3:
		cursor = _seg(reel, top, o10 + beat * float(j), o10 + beat * float(j + 1), peak - 0.02, 1.0, ["uv", [0.5, 0.45], 1.0 + 0.12 * float(j), 1.04 + 0.12 * float(j)])
		fx.append([o10 + beat * float(j), o10 + beat * float(j) + 0.22, "rgb", "", 0])
	cursor = _seg(reel, top, o10 + beat * 3.0, o10 + bar, cursor, 1.0)
	fx.append([o10, o10 + 0.3, "flash", "", 0])
	fx.append([o10, o10 + bar, "shake", "", 0])
	var shout := (words[-1] if not words.is_empty() else "").trim_suffix("！").trim_suffix("。")
	if shout != "":
		fx.append([o10 + 0.02, o10 + bar, "k_slam", shout + "！！", 1])
	if bool(r["has_burst"]):
		hits += 1
	else:
		misses += 1
	# サビ 6 小節目：爆発そのものではなく、見ている顔を、拍ごとに 1 人ずつ
	var o11 := bar * 11.0
	for j in 4:
		var crop: Array = ["actor", int(faces[j % faces.size()][0]), 1.6, 1.68] if not faces.is_empty() else ["uv", [0.25 + 0.17 * float(j), 0.45], 1.6, 1.68]
		cursor = _seg(reel, top, o11 + beat * float(j), o11 + beat * float(j + 1), cursor, 0.5, crop)
		fx.append([o11 + beat * float(j), o11 + beat * float(j) + 0.16, "rgb", "", 0])
	# サビ 7・8 小節目：締めの場面。決まる瞬間の 1 拍を 3 回くり返してから、流す
	var o12 := bar * 12.0
	var final: float = r["final"]
	var last := _title(r, int(r["final_i"]))
	if final >= 0.0:
		hits += 1
	else:
		misses += 1
		final = minf(cursor + 2.0, top - 1.0)
	for j in 3:
		_seg(reel, top, o12 + beat * float(j), o12 + beat * float(j + 1), maxf(final - beat, 0.0), 1.0, ["uv", [0.5, 0.45], 1.0 + 0.1 * float(j), 1.03 + 0.1 * float(j)], true)
		fx.append([o12 + beat * float(j), o12 + beat * float(j) + 0.2, "rgb", "", 0])
	cursor = _seg(reel, top, o12 + beat * 3.0, bar * 14.0, final, 1.0)
	fx.append([o12 + beat * 3.0, bar * 14.0 - 0.05, "k_slam", last if last != "" else "……", 0])
	# 一打：止めて暗くして、会社の名前
	_seg(reel, top, bar * 14.0, out, cursor, 0.0, [], true)
	fx.append([bar * 14.0, bar * 14.0 + 0.25, "flash", "", 0])
	fx.append([bar * 14.0, out, "dim", "", 0.62])
	if str(r["company"]) != "":
		fx.append([bar * 14.0 + 0.04, out, "k_slam", str(r["company"]), 2])
	var lines: Array = [["編集代（ド派手のバンバ）", -150]]
	if hits > 0:
		lines.append(["編集：拍に乗った ×%d" % hits, hits * 50])
	if misses > 0:
		lines.append(["編集：効果だけが浮いた ×%d" % misses, -misses * 45])
	var net: bool = r["net"]
	var cues: Array = []
	if hits >= 6:
		cues.append([minf(peak + 0.2, top), "情報量えぐいw" if net else "め、目が追いつかない……でも、いい！", "wow"])
	if misses >= 3:
		cues.append([clampf(dur * 0.4, 0.5, top), "何を見せられてる？" if net else "……何が映っているんです？", "sad"])
	return {"reel": reel, "fx": fx, "out": out, "music": HYPE_MUSIC, "bpm": HYPE_BPM, "lines": lines, "cues": cues, "hits": hits, "misses": misses}


# 出来上がりの秒 → その行の番号（無ければ -1）
static func seg_at(reel: Array, t: float, from: int = 0) -> int:
	var i := clampi(from, 0, maxi(reel.size() - 1, 0))
	if reel.is_empty():
		return -1
	if t < float(reel[i][0]):
		i = 0
	while i < reel.size() - 1 and t >= float(reel[i][1]):
		i += 1
	return i


# その行の、出来上がりの秒 t での素材の時刻
static func src_at(seg: Array, t: float) -> float:
	return float(seg[2]) + clampf(t - float(seg[0]), 0.0, float(seg[1]) - float(seg[0])) * float(seg[3])

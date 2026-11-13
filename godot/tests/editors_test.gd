extends SceneTree
# 編集者（features/editors.gd）の、編集の組み方（計算だけ。ゲームは立ち上げない）。
#   ・頼まない＝何も変えない
#   ・堅実：誰も映っていない間と、映り込みを切る。見せ場（場面が撮れた瞬間・爆発）は切らない
#   ・CM向き：場面ごとにテロップ。CMなら加点、ほかは減点
#   ・雰囲気もの向き：黒い帯とスロー。映り込みは切らない
#   ・前衛：同じ種なら同じ編集。見せ場に重なればハマる
#   ・名匠・ド派手：編集の台本（edit/reel_build.gd）。出来上がりの秒で並べる。曲の拍に、素材の見せ場が来る
#   godot --headless --path godot --script res://tests/editors_test.gd
var Editors: GDScript
var failed := false


func check(ok: bool, label: String) -> void:
	print("EDIT_CHECK ", label, " ", "OK" if ok else "FAIL")
	failed = failed or not ok


func coins(e: Dictionary) -> int:
	var sum := 0
	for l: Array in e["lines"]:
		sum += int(l[1])
	return sum


func in_cut(e: Dictionary, t: float) -> bool:
	for c: Array in e["cuts"]:
		if t >= float(c[0]) and t < float(c[1]):
			return true
	return false


# 台本の行が、出来上がりの秒ですき間なく並び、素材の時刻が 0〜dur に収まっているか
func reel_ok(e: Dictionary, dur: float) -> bool:
	var reel: Array = e.get("reel", [])
	if reel.is_empty() or absf(float(reel[0][0])) > 0.001 or absf(float(reel[-1][1]) - float(e["out"])) > 0.001:
		return false
	for i in reel.size():
		var s: Array = reel[i]
		var end := float(s[2]) + (float(s[1]) - float(s[0])) * float(s[3])
		if float(s[1]) <= float(s[0]) or float(s[2]) < 0.0 or end > dur - 0.04 or float(s[3]) < 0.0:
			print("  行 ", i, " ", s)
			return false
		if i > 0 and absf(float(s[0]) - float(reel[i - 1][1])) > 0.001:
			print("  すき間 ", i, " ", s)
			return false
	return true


# 出来上がりの秒 t に流れる、素材の時刻
func src_of(e: Dictionary, t: float) -> float:
	for s: Array in e["reel"]:
		if t >= float(s[0]) - 0.0001 and t < float(s[1]):
			return float(s[2]) + (t - float(s[0])) * float(s[3])
	return -1.0


func quiet_at(e: Dictionary, t: float) -> bool:
	for s: Array in e["reel"]:
		if t >= float(s[0]) and t < float(s[1]):
			return bool(s[5])
	return false


func starts(e: Dictionary, t: float) -> bool:
	return (e["reel"] as Array).any(func(s: Array) -> bool: return absf(float(s[0]) - t) < 0.001)


func texts(e: Dictionary, kind: String) -> Array:
	return (e["fx"] as Array).filter(func(f: Array) -> bool: return str(f[2]) == kind).map(func(f: Array) -> String: return str(f[3]))


func _initialize() -> void:
	run.call_deferred()


func run() -> void:
	await process_frame
	Editors = load("res://scripts/features/editors.gd")
	# 30秒のテイク：場面が撮れたのは 6・14・22・29 秒。爆発は 21 秒。誰も映っていない間が 2 つ、映り込みが 1 つ
	var d := {"dur": 30.0, "passes": [6.0, 14.0, 22.0, 29.0], "dead": [[0.0, 3.5], [7.0, 13.5], [20.4, 21.2]], "cameo": [[16.0, 17.2]],
		"bursts": [21.0], "genre": "cm", "titles": ["社員紹介（一人ずつ寄り）", "お城も建てます", "爆発も、します", "ぜんぶ、格安で！"], "net": true}
	var none: Dictionary = Editors.build_edit("none", d, 1)
	check(none["id"] == "none" and (none["cuts"] as Array).is_empty() and (none["fx"] as Array).is_empty() and (none["lines"] as Array).is_empty(), "頼まない：何も変えない・お金も動かない")
	var steady: Dictionary = Editors.build_edit("steady", d, 1)
	check((steady["cuts"] as Array).size() == 3 and in_cut(steady, 2.0) and in_cut(steady, 10.0) and in_cut(steady, 16.5), "堅実：間 2 つと映り込み 1 つを切る（%s）" % str(steady["cuts"]))
	check(not [6.0, 14.0, 22.0, 29.0, 21.0].any(func(t: float) -> bool: return in_cut(steady, t) or in_cut(steady, t - 0.9) or in_cut(steady, t + 0.5)), "堅実：見せ場の前後は切らない")
	check((steady["fx"] as Array).is_empty() and (steady["slows"] as Array).is_empty() and (steady["reps"] as Array).is_empty(), "堅実：変なことはしない")
	check(coins(steady) == -60 + 60 + 40, "堅実：編集代 60、間 2 か所 +60、映り込み 1 か所 +40（%d）" % coins(steady))
	check(Editors.cut_seconds(steady) > 8.0, "堅実：%.1f 秒ぶん短くなる" % Editors.cut_seconds(steady))
	var cm: Dictionary = Editors.build_edit("cm", d, 1)
	var telops: Array = (cm["fx"] as Array).filter(func(f: Array) -> bool: return str(f[2]) == "telop")
	check(telops.size() == 4 and str(telops[1][3]) == "お城も建てます！" and str(telops[0][3]) == "社員紹介！", "CM向き：撮れた場面ごとにテロップ（%s）" % str(telops.map(func(f: Array) -> String: return str(f[3]))))
	check((cm["fx"] as Array).any(func(f: Array) -> bool: return str(f[2]) == "sticker" and str(f[3]) == "格安！"), "CM向き：最後に「格安！」の札")
	check((cm["lines"] as Array).any(func(l: Array) -> bool: return "CM向き" in str(l[0]) and int(l[1]) > 0), "CM向き：CMの依頼なら加点")
	var drama := d.duplicate(true)
	drama["genre"] = "mood"
	drama["net"] = false
	var cm_off: Dictionary = Editors.build_edit("cm", drama, 1)
	check((cm_off["lines"] as Array).any(func(l: Array) -> bool: return "浮いている" in str(l[0]) and int(l[1]) < 0), "CM向き：CMでない依頼だと、テロップが浮いて減点")
	check(not (cm_off["cues"] as Array).is_empty() and str(cm_off["cues"][0][2]) == "sad", "CM向き：依頼主が、文字は要るかと言う（%s）" % str(cm_off["cues"]))
	var mv: Dictionary = Editors.build_edit("mv", drama, 1)
	check(float(mv["bars"]) > 0.0 and int(mv["grade"]) == 2 and not (mv["slows"] as Array).is_empty(), "雰囲気もの向き：上下の黒い帯・色・スロー")
	check(not in_cut(mv, 16.5) and in_cut(mv, 10.0), "雰囲気もの向き：長い間は切るが、映り込みは気にしない")
	check((mv["slows"] as Array).any(func(s: Array) -> bool: return float(s[0]) <= 21.0 and float(s[1]) > 21.0), "雰囲気もの向き：爆発の瞬間をスローに")
	check((mv["lines"] as Array).any(func(l: Array) -> bool: return "雰囲気もの向き" in str(l[0]) and int(l[1]) > 0), "雰囲気もの向き：月・夕日・結婚式の依頼なら加点")
	var mv_cm: Dictionary = Editors.build_edit("mv", d, 1)
	check((mv_cm["lines"] as Array).any(func(l: Array) -> bool: return "何の宣伝" in str(l[0]) and int(l[1]) < 0), "雰囲気もの向き：CMだと「何の宣伝か分からない」で減点")
	var wild_a: Dictionary = Editors.build_edit("wild", d, 77)
	var wild_b: Dictionary = Editors.build_edit("wild", d, 77)
	var wild_c: Dictionary = Editors.build_edit("wild", d, 78)
	check(str(wild_a) == str(wild_b), "前衛：同じ種なら、同じ編集（どの画面でも同じ）")
	check(str(wild_a["fx"]) != str(wild_c["fx"]), "前衛：種が変われば、違う編集")
	check((wild_a["reps"] as Array).size() == 1 and int(wild_a["reps"][0][2]) == 3 and absf(float(wild_a["reps"][0][0]) - 22.1) < 0.01, "前衛：爆発があれば、3回くり返す（%s）" % str(wild_a["reps"]))
	check((wild_a["cuts"] as Array).is_empty(), "前衛：素材は切らない")
	check((wild_a["lines"] as Array).any(func(l: Array) -> bool: return "ハマった" in str(l[0]) and int(l[1]) >= 70), "前衛：爆発のくり返しは、ハマった扱い（%s）" % str(wild_a["lines"]))
	var flat := d.duplicate(true)
	flat["bursts"] = []
	flat["passes"] = [-1.0, -1.0, -1.0, -1.0]
	var wild_flat: Dictionary = Editors.build_edit("wild", flat, 77)
	check((wild_flat["reps"] as Array).is_empty() and (wild_flat["lines"] as Array).any(func(l: Array) -> bool: return "滑った" in str(l[0]) and int(l[1]) < 0) and not (wild_flat["lines"] as Array).any(func(l: Array) -> bool: return "ハマった" in str(l[0])),
		"前衛：見せ場が1つも無いテイクだと、滑るだけ（%s）" % str(wild_flat["lines"]))
	# ---- 編集の台本（名匠・ド派手）：出来上がりの秒で並べる。切る・遅くするの表は使わない ----
	var rich := d.duplicate(true)
	rich["faces"] = [[0, 1.2, true, "社長"], [1, 2.6, true, "社員B"], [2, 4.0, true, "社員C"], [3, 5.2, false, "社員D"]]
	rich["burst_info"] = [[[1.0, 1.2, -3.0], "flat"]]
	rich["job"] = "わが社の紹介動画（ネット用・30秒）"
	rich["company"] = "アマノ映画"
	var pro: Dictionary = Editors.build_edit("pro", rich, 1)
	check(reel_ok(pro, 30.0), "名匠：台本の行は、出来上がりの秒ですき間なく並び、素材の時刻はテイクの中に収まる")
	check(absf(float(pro["out"]) - 28.0) < 0.01 and str(pro["music"]) == "edit_pro" and (pro["cuts"] as Array).is_empty(), "名匠：28 秒・書き下ろしの曲")
	check(absf(src_of(pro, 14.0) - 20.98) < 0.03 and not quiet_at(pro, 14.2), "名匠：曲の一打（14.0 秒）に、爆発の瞬間が来る（素材 %.2f 秒）" % src_of(pro, 14.0))
	check(texts(pro, "t_name") == ["社長", "社員B", "社員C", "社員D　（頭は入りませんでした）"], "名匠：一人ずつ名前。頭が入らなかった人は、そう書く（%s）" % str(texts(pro, "t_name")))
	check([2.0, 3.5, 5.0, 6.5, 8.0].all(func(t: float) -> bool: return starts(pro, t)), "名匠：一人ずつの切り替えは、ティンパニの拍（2・3.5・5・6.5・8 秒）")
	check(texts(pro, "t_build") == ["爆発も、"] and texts(pro, "t_big") == ["します。"], "名匠：山場の場面の名前を、溜めと一打に分ける（%s %s）" % [str(texts(pro, "t_build")), str(texts(pro, "t_big"))])
	check(texts(pro, "t_note") == ["※ 爆発は、板に描いた絵です"], "名匠：書割の爆発なら、無音の間に、正直に書く")
	check(texts(pro, "t_end") == ["ぜんぶ、格安で！"] and texts(pro, "t_sub") == ["アマノ映画"], "名匠：締めは最後の場面の名前と、会社の名前")
	check(texts(pro, "t_ng").size() == 2 and quiet_at(pro, 25.0) and absf(src_of(pro, 24.0) - 16.0) < 0.01, "名匠：切った所（映り込み・間）は、最後に NG のおまけ（%s）" % str(texts(pro, "t_ng")))
	check(coins(pro) == -250 + 120 + 200 + 30 and coins(pro) > coins(steady), "名匠：代金 250 でも黒字（%d）" % coins(pro))
	var real := rich.duplicate(true)
	real["burst_info"] = [[[1.0, 1.2, -3.0], "real"]]
	check(texts(Editors.build_edit("pro", real, 1), "t_note").is_empty(), "名匠：本物の爆発なら、「板に描いた絵」とは書かない")
	var thin: Dictionary = Editors.build_edit("pro", flat, 1)
	check(reel_ok(thin, 30.0) and coins(thin) < 0 and texts(thin, "t_name").is_empty() and texts(thin, "t_end").is_empty(), "名匠：見せ場が無いテイクでも、破綻しない。代金の元は取れない（%d）" % coins(thin))
	var hype: Dictionary = Editors.build_edit("hype", rich, 1)
	var beat := 60.0 / 128.0
	check(reel_ok(hype, 30.0) and str(hype["music"]) == "edit_hype", "ド派手：台本の行は、すき間なく並び、素材の時刻はテイクの中")
	check((hype["reel"] as Array).all(func(s: Array) -> bool: return absf(float(s[0]) / (beat * 0.25) - roundf(float(s[0]) / (beat * 0.25))) < 0.001), "ド派手：全部の切り替えが、拍（16 分）の上")
	check(absf(src_of(hype, beat * 40.0) - 20.98) < 0.03 and absf(src_of(hype, beat * 41.0) - 20.98) < 0.03 and absf(src_of(hype, beat * 42.0) - 20.98) < 0.03, "ド派手：サビの 5 小節目の頭から、爆発の 1 拍を 3 回")
	check(texts(hype, "k_mask") == ["わが社の", "紹介動画"] and texts(hype, "k_burn") == ["社長", "社員B", "社員C", "社員D"], "ド派手：題は字の形の窓、名前は絵に焼き込む（%s）" % str(texts(hype, "k_mask")))
	check(coins(hype) == -150 + 8 * 50 and coins(hype) > coins(pro), "ド派手：素材がそろえば、名匠より稼ぐ（%d）" % coins(hype))
	var hype_thin: Dictionary = Editors.build_edit("hype", flat, 1)
	check(reel_ok(hype_thin, 30.0) and coins(hype_thin) == -150 - 8 * 45 and coins(hype_thin) < coins(thin), "ド派手：見せ場が無いと、効果だけが浮く。名匠より大きく損をする（%d）" % coins(hype_thin))
	check((hype_thin["cues"] as Array).any(func(c: Array) -> bool: return str(c[2]) == "sad"), "ド派手：外した時は、見た人が首をかしげる")
	var short := rich.duplicate(true)
	short["dur"] = 9.0
	short["passes"] = [3.0, -1.0, -1.0, 8.0]
	short["bursts"] = []
	short["burst_info"] = []
	short["dead"] = []
	short["cameo"] = []
	check(reel_ok(Editors.build_edit("pro", short, 1), 9.0) and reel_ok(Editors.build_edit("hype", short, 1), 9.0), "短いテイク（9 秒）でも、素材の時刻がはみ出さない")
	check(Editors.genre_of({"title": "カップ麺の3分（CM）"}) == "cm" and Editors.genre_of({"title": "月夜の自転車"}) == "mood" and Editors.genre_of({"title": "怪獣ドラマ 第1話"}) == "action", "依頼の種類：CM・雰囲気もの・そのほか")
	print("EDIT_TEST_FAIL" if failed else "EDIT_TEST_OK")
	quit(1 if failed else 0)

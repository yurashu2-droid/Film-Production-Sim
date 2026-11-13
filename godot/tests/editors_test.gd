extends SceneTree
# 編集者（features/editors.gd）の、編集の組み方（計算だけ。ゲームは立ち上げない）。
#   ・頼まない＝何も変えない
#   ・堅実：誰も映っていない間と、映り込みを切る。見せ場（場面が撮れた瞬間・爆発）は切らない
#   ・CM向き：場面ごとにテロップ。CMなら加点、ほかは減点
#   ・雰囲気もの向き：黒い帯とスロー。映り込みは切らない
#   ・前衛：同じ種なら同じ編集。見せ場に重なればハマる
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
	check(Editors.genre_of({"title": "カップ麺の3分（CM）"}) == "cm" and Editors.genre_of({"title": "月夜の自転車"}) == "mood" and Editors.genre_of({"title": "怪獣ドラマ 第1話"}) == "action", "依頼の種類：CM・雰囲気もの・そのほか")
	print("EDIT_TEST_FAIL" if failed else "EDIT_TEST_OK")
	quit(1 if failed else 0)

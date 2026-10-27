extends SceneTree
## 依頼と台本の目録の確認（ゲームは起動しない。表だけを突き合わせる）。
##   production_flow.gd の JOBS・production_script.gd の SCRIPTS・production_briefs.gd の BRIEFS / BOARDS・
##   production_cast.gd の役・ui/storyboard.gd の絵コンテ・production_scrap.gd の廃材が、依頼ごとにそろっているか
##   godot --headless --path godot --script res://tests/scripts_catalog_test.gd
const Scripts := preload("res://scripts/production_script.gd")
const Briefs := preload("res://scripts/production_briefs.gd")
const Cast := preload("res://scripts/production_cast.gd")
const Storyboard := preload("res://scripts/ui/storyboard.gd")
const Scrap := preload("res://scripts/production_scrap.gd")
const Slides := preload("res://scripts/production_slides.gd")

# production_beats.gd の judge_tick が受ける決まり
const RULES := ["stroll", "appear", "attack", "topple", "cheer", "show", "blast", "track", "drop", "chase", "pit",
	"ring", "cross", "hit", "scorch", "high", "wind", "orbit", "climb", "pass", "sign", "roll"]
# 怪獣と街の映り方（judge.gd の _look_kaiju）は、台本 "kaiju" のときだけ数える
const KAIJU_RULES := ["stroll", "appear", "attack", "topple", "cheer"]
const POSES := ["idle", "freeze", "cheer", "bow", "hips", "wave", "point", "duck"]
const FACES := ["neutral", "happy", "sad", "angry", "surprised", "shock"]
const LOOKS := ["", "monster", "camera", "partner"]
# storyboard.gd の svg が、PARODY を通らずに描く組 → 枚数
const FIXED_BOARDS := {"pr": 4, "kaiju5": 5, "travel": 4, "trap": 4, "kaiju": 3, "castle": 3}

var failed := false
var checks := 0


func check(ok: bool, what: String) -> void:
	checks += 1
	if not ok:
		failed = true
		print("SCRIPTS_CATALOG_CHECK %s FAIL" % what)


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	# production_flow.gd は自動読み込み（Net）を使うので、起動してから読む
	var jobs: Array = load("res://scripts/production_flow.gd").JOBS
	check(Scripts.SCRIPTS.size() == jobs.size(), "SCRIPTS (%d) and JOBS (%d) are the same length" % [Scripts.SCRIPTS.size(), jobs.size()])
	check(Briefs.BRIEFS.size() == jobs.size(), "BRIEFS (%d) and JOBS (%d) are the same length" % [Briefs.BRIEFS.size(), jobs.size()])
	var dress_src := FileAccess.get_file_as_string("res://scripts/cast_dress.gd")
	var pair_svg: String = Storyboard._pair()
	# WORDS の役は、どれも ROLES にある
	for word: String in Scripts.WORDS:
		check(Cast.ROLES.has(str(Scripts.WORDS[word][0])), "WORDS {%s} names a known role" % word)
	var finales := 0
	for i in jobs.size():
		var job: Dictionary = jobs[i]
		var title := "%d %s" % [i, str(job.get("title", "?"))]
		var story := str(job.get("script", ""))
		var scenes: Array = job.get("scenes", [])
		finales += 1 if bool(job.get("finale", false)) else 0
		check(int(job.get("rank", 0)) >= 1 and int(job.get("rank", 0)) <= 5, "%s: rank 1-5" % title)
		check(not scenes.is_empty(), "%s: has scenes" % title)
		check(str(job.get("bonus_title", "")) != "" and str(job.get("bonus", "")) in ["first_take", "no_crew", "moon"], "%s: has a bonus" % title)
		# 役
		var roles: Array = Cast.roles_for(story)
		check(Cast.SCRIPT_ROLES.has(story) and not roles.is_empty(), "%s: script '%s' has roles" % [title, story])
		for role: String in roles:
			check(Cast.ROLES.has(role), "%s: role '%s' is in ROLES" % [title, role])
			check(dress_src.contains('"%s":' % role), "%s: role '%s' has a dress in cast_dress.gd" % [title, role])
		if str(job.get("bonus", "")) == "moon":
			check("moon" in roles, "%s: the moon bonus needs a moon role" % title)
		# 台本
		if i >= Scripts.SCRIPTS.size():
			continue
		var book: Dictionary = Scripts.SCRIPTS[i]
		var pages: Array = book.get("scenes", [])
		check(pages.size() == scenes.size(), "%s: script scenes %d == job scenes %d" % [title, pages.size(), scenes.size()])
		for page: Dictionary in pages:
			check(str(page.get("dir", "")) != "" and str(page.get("memo", "")) != "" and not (page.get("lines", []) as Array).is_empty(), "%s: every page has dir, lines and memo" % title)
			for line: Array in page.get("lines", []):
				for part: String in line:
					for token: String in _tokens(part):
						check(Scripts.WORDS.has(token), "%s: {%s} is in WORDS" % [title, token])
						if Scripts.WORDS.has(token):
							check(str(Scripts.WORDS[token][0]) in roles, "%s: {%s} is a role of '%s'" % [title, token, story])
		var cast: Array = Scripts.cast(i)
		check(cast.size() >= 1 and cast.size() <= 4, "%s: cast of 1-4" % title)
		var beats: Array = book.get("beats", [])
		if bool(job.get("finale", false)) or str(job.get("board", "")) == "kaiju5":
			check(not beats.is_empty(), "%s: the five-scene kaiju job has beats" % title)
		if not beats.is_empty():
			check(beats.size() == scenes.size(), "%s: beats %d == scenes %d" % [title, beats.size(), scenes.size()])
			for b: Dictionary in beats:
				var rule := str(b.get("rule", ""))
				check(rule in RULES, "%s: rule '%s' is known" % [title, rule])
				if rule in KAIJU_RULES:
					check(story == "kaiju", "%s: rule '%s' needs the kaiju script" % [title, rule])
				if rule == "blast" or b.get("boom", false):
					check("boom" in roles, "%s: '%s' needs a boom role" % [title, rule])
				if rule == "cross":
					check("moon" in roles, "%s: cross needs a moon role" % title)
				if rule == "pit":
					check("pit" in roles, "%s: pit needs a pit role" % title)
				if rule == "roll":
					check(book.has("cast"), "%s: roll needs a cast list" % title)
				if rule == "show" and str(b.get("role", "")) != "":
					check(str(b["role"]) in roles, "%s: show role '%s' is a role of '%s'" % [title, b["role"], story])
				if str(b.get("hide", "")) != "":
					check(str(b["hide"]) == "castle", "%s: hide only knows castle" % title)
				check(int(b.get("from", 0)) in [0, 1, 2] and int(b.get("to", 0)) in [0, 1, 2], "%s: marks are 0-2" % title)
				check(str(b.get("gait", "walk")) in ["walk", "run"], "%s: gait" % title)
				check(str(b.get("pose", "idle")) in POSES, "%s: pose '%s'" % [title, b.get("pose")])
				for p: Variant in (b.get("pose_by", {}) as Dictionary).values():
					check(str(p) in POSES, "%s: pose_by '%s'" % [title, p])
				check(str(b.get("look", "")) in LOOKS, "%s: look '%s'" % [title, b.get("look")])
				var faces: Array = b.get("face", ["neutral", "neutral"])
				check(faces.size() == 2 and faces.all(func(f: Variant) -> bool: return str(f) in FACES), "%s: faces %s" % [title, faces])
				for who: Variant in b.get("who", []):
					check(int(who) >= 0 and int(who) < cast.size(), "%s: who %s is in the cast" % [title, who])
		var cast_at: Array = job.get("cast_at", [0, 1])
		check(cast_at.size() == 2 and int(cast_at[0]) < scenes.size() and int(cast_at[1]) < scenes.size(), "%s: cast_at inside the scenes" % title)
		# 打ち合わせ・絵コンテ
		var brief: Dictionary = Briefs.BRIEFS[i] if i < Briefs.BRIEFS.size() else {}
		check((brief.get("lines", []) as Array).size() >= 3 and str(brief.get("name", "")) != "" and str(brief.get("purse", "")) != "", "%s: brief has name, purse and 3 lines" % title)
		check(ResourceLoader.exists("res://assets/ui/clients/%s.png" % str(brief.get("cast", ""))), "%s: client face '%s' exists" % [title, brief.get("cast", "")])
		for like: String in brief.get("likes", []):
			check(_attr_known(like), "%s: liked attr '%s' is used by some prop" % [title, like])
		check(not str(brief.get("taste", "")).ends_with("。"), "%s: taste has no trailing 。 (briefing.gd adds it)" % title)
		var board := str(job.get("board", story))
		check(Briefs.BOARDS.has(board) and (Briefs.BOARDS[board] as Array).size() == scenes.size(), "%s: BOARDS '%s' has %d lines" % [title, board, scenes.size()])
		if Storyboard.PARODY.has(board):
			var frames: Array = Storyboard.PARODY[board]
			check(frames.size() == scenes.size(), "%s: storyboard '%s' has %d panels" % [title, board, scenes.size()])
			for f: String in frames:
				check(f == "_pair" or Storyboard._parody(f) != pair_svg, "%s: panel %s is drawn (not the fallback)" % [title, f])
		else:
			check(FIXED_BOARDS.has(board) and int(FIXED_BOARDS[board]) == scenes.size(), "%s: storyboard '%s' draws %d panels" % [title, board, scenes.size()])
		for k in scenes.size():
			var img := Image.new()
			check(img.load_svg_from_string(Storyboard.svg(board, k), 0.5) == OK, "%s: storyboard panel %d renders" % [title, k + 1])
		# 監督の机の参考写真（production_slides.gd）：役ごとに、写真が並ぶ
		for n in 3:
			var stock: Array = Cast.PROPS.keys() if n == 0 else ([] if n == 1 else ["carton", "riser", "fx", "rock", "scrap_fan"])
			var deck: Dictionary = Slides.build(i, story, brief.get("likes", []), stock, 1000 + n)
			check(deck.has("rows") and (deck["rows"] as Array).size() > 0, "%s: slides are built (stock %d)" % [title, n])
		# 依頼主が用意する物
		for kind: String in job.get("props", []):
			check(Scrap.has_kind(kind), "%s: prop '%s' is in the scrap catalog" % [title, kind])
	check(finales == 1, "exactly one finale")
	for r in range(1, 5):
		var n := 0
		for job: Dictionary in jobs:
			n += 1 if int(job.get("rank", 0)) == r and not bool(job.get("debut", false)) else 0
		check(n >= 2, "rank %d has at least 2 jobs (%d)" % [r, n])
	print("SCRIPTS_CATALOG_TEST_FAIL" if failed else "SCRIPTS_CATALOG_TEST_OK checks=%d" % checks)
	quit(1 if failed else 0)


# せりふの中の {役} の言葉
func _tokens(text: String) -> Array:
	var out: Array = []
	var at := text.find("{")
	while at >= 0:
		var end := text.find("}", at)
		if end < 0:
			break
		out.append(text.substr(at + 1, end - at - 1))
		at = text.find("{", end)
	return out


func _attr_known(attr: String) -> bool:
	for kind: String in Cast.PROPS:
		if attr in (Cast.PROPS[kind].get("attrs", []) as Array):
			return true
	return false

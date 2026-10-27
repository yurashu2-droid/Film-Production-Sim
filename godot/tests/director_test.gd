extends SceneTree
# 監督の机の確認：台本に挟まった参考写真（参考スライド）・みんなの画面から外した情報・自分にだけ開く発注。
#   参考写真：台本を持って開き、もう一度 F で見る / 見ている間は世界が隠れる / 台本を持たない人は見られない / やめると台本は手に残る
#             移動中は見られない / 現場でも本番の前なら見られる（2026-10-24 から。机の上の物は発注の電話だけ）
#   スライド：役ごとにシルエットが並ぶ / 名前や属性の文字が無い / 役ごとに今日手に入る物が混ざる / 「＋」の組は本当にコンボ
#   画面　　：台本を持たない人には、場面の一覧と配役表が無い / 台本を持つと見られる / 発注画面に今日の廃材の一覧が無い
#   発注　　：開いている間も、ほかの人は動ける・物を持てる・時計が進む / 決めると物が届く / ほかの人の手や接着には触らない
#   godot --headless --path godot --fixed-fps 60 --script res://tests/director_test.gd
const Slides := preload("res://scripts/production_slides.gd")
const Cast := preload("res://scripts/production_cast.gd")
const Briefs := preload("res://scripts/production_briefs.gd")
const Catalog := preload("res://scripts/ui/order_catalog.gd")
var game: Node
var flow: Node
var desk: Node
var me: Node
var failed := false
var checks := 0


func _initialize() -> void:
	run.call_deferred()


func check(ok: bool, label: String) -> void:
	checks += 1
	print("DIRECTOR_CHECK ", label, " ", "OK" if ok else "FAIL")
	failed = failed or not ok


func frames(count: int) -> void:
	for i in count:
		await physics_frame


func first(kind: String) -> Node:
	var found: Node = null
	for pid: int in game.props:
		var prop: Node = game.props[pid]
		if prop.kind == kind and (found == null or prop.pid < found.pid):
			found = prop
	return found


func job_of(story: String) -> int:
	for i in flow.JOBS.size():
		if flow.JOBS[i]["script"] == story:
			return i
	return -1


func press(code: int) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = true
	game._input(event)


func mouse(button: int) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = button
	event.pressed = true
	game._input(event)


# 自分の視点を、その場所へ向ける（照準を合わせる）
func face(at: Vector3) -> void:
	var from: Vector3 = me.global_position + Vector3(0, 2.35, 0)
	var d: Vector3 = at - from
	me.aim_yaw = atan2(-d.x, -d.z)
	me.aim_pitch = atan2(d.y, Vector2(d.x, d.z).length())
	me.vis.rotation.y = me.aim_yaw + PI
	await frames(6)


# 机の前に立って、机の上の物（電話）を見る。
# すぐ前（1.4 m）に立つ：2 m 離れると、三人称のカメラが社屋の書割の外に出て、照準の線が書割の当たり判定に止められる
# （ゲームの不具合として報告済み。test_order の最初で、その場合だけを別に確かめる）
func stand_at_desk(thing_at: Vector3, z: float = 1.7) -> void:
	me.global_position = Vector3(thing_at.x, 0.1, z)
	me.velocity = Vector3.ZERO
	await frames(2)
	await face(thing_at + Vector3(0, 0.25, 0.05))


# 2人目の制作班を、その場に立たせる（通信はしない。ホストの判断だけを確かめる）
func add_crew(id: int, at: Vector3) -> Node:
	game._roster.append([id, 1])
	game._apply_roster()
	var other: Node = game.players[id]
	other.global_position = at
	return other


func remove_crew(id: int) -> void:
	game._roster = game._roster.filter(func(row: Array) -> bool: return row[0] != id)
	game._apply_roster()
	await frames(2)


# スライドの決まりを確かめる。満たしていない点の説明を返す（""＝全部満たしている）
func deck_problem(deck: Dictionary, story: String, likes: Array, available: Array) -> String:
	var rows: Array = deck.get("rows", [])
	var roles: Array = Cast.roles_for(story)
	if rows.size() != roles.size():
		return "rows %d" % rows.size()
	var seen_roles: Array = []
	for row: Array in rows:
		var role: String = row[0]
		var kinds: Array = (row[1] as Array).filter(func(kind: String) -> bool: return kind != "")
		seen_roles.append(role)
		if role not in roles or kinds.size() != Slides.PER_ROW:
			return "row %s has %d" % [role, kinds.size()]
		for kind: String in kinds:
			if not Cast.castable(kind) or Cast.is_joker(kind) or kinds.count(kind) != 1:
				return "odd kind %s in %s" % [kind, role]
		# 今日手に入る、らしい物（fit 1 以上）がある役には、今日手に入る物が1つは並ぶ
		var could := false
		for kind: String in available:
			if Cast.castable(kind) and not Cast.is_joker(kind) and Cast.fit(kind, role) >= 1:
				could = true
		if could and not kinds.any(func(kind: String) -> bool: return kind in available):
			return "nothing obtainable in %s" % role
	for role: String in roles:
		if role not in seen_roles:
			return "missing role %s" % role
	# 同じ形が、2つの役に並ばない
	var all_shown: Array = []
	for row: Array in rows:
		for kind: String in row[1]:
			if kind != "" and kind in all_shown:
				return "%s is shown for two roles" % kind
			all_shown.append(kind)
	var plus: Array = deck.get("plus", [])
	if plus.size() > Slides.MAX_PLUS:
		return "too many pairs"
	var used := {}
	for pair: Array in Slides.plus_pairs(deck):
		if not Slides.is_combo(story, pair[0], pair[1], pair[2], pair[3]):
			return "%s + %s is not a combo" % [pair[1], pair[3]]
		for part: String in ["%s/%s" % [pair[0], pair[1]], "%s/%s" % [pair[2], pair[3]]]:
			if used.has(part):
				return "%s is in two pairs" % part
			used[part] = true
	if plus.size() != Slides.plus_pairs(deck).size():
		return "a pair points outside the rows"
	var groups: Array = deck.get("likes", [])
	if groups.size() != likes.size():
		return "likes %d" % groups.size()
	for i in groups.size():
		var group: Array = groups[i]
		if group.is_empty() or group.size() > Slides.PER_LIKE:
			return "like group size %d" % group.size()
		for kind: String in group:
			if likes[i] not in Cast.attrs(kind) or group.count(kind) != 1:
				return "%s does not show the taste %s" % [kind, likes[i]]
		if Slides.kinds_with_attr(likes[i]).any(func(kind: String) -> bool: return kind in available) and not group.any(func(kind: String) -> bool: return kind in available):
			return "nothing obtainable for the taste %s" % likes[i]
	return ""


func run() -> void:
	game = load("res://production_game.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	while not game.startup_complete:
		await process_frame
	await frames(10)
	flow = game.production
	desk = game.director
	me = game.local_player()
	await test_slides()
	await test_company_screens()
	await test_peep_box()
	await test_set_screens()
	await test_order()
	print("DIRECTOR_TEST_FAIL" if failed else "DIRECTOR_TEST_OK", " checks=", checks)
	# 鳴っている音を止めてから終わる（鳴っている最中に終わると、終了時に「resources still in use」が出る）
	var sfx: Node = root.get_node_or_null("Sfx")
	if sfx != null:
		sfx.silence_all()
	game.queue_free()
	for i in 8:
		await process_frame
	quit(1 if failed else 0)


# 画面の文字を、いまの状態で作り直す（コマを待たずに確かめる。照準は数コマで取り直されるので）
func refresh_hud() -> void:
	game.hud._process(0.0)
	game.production_hud._refresh()


# その画面に書いてある文字を全部
func words_in(node: Node) -> Array:
	var out: Array = []
	for label: Label in node.find_children("*", "Label", true, false):
		if label.is_visible_in_tree() and label.text != "":
			out.append(label.text)
	return out


# ---- みんなの画面（会社）：配役表・今日の廃材の一覧・場面の並びが無い ----

func test_company_screens() -> void:
	var scenes: Array = flow.job()["scenes"]
	# 会社にいつも在る昇降台を、怪獣役に見立てておく（配役表に行ができる）
	var cart: Node = first("lift_cart")
	me.global_position = flow.HOME_TRUCK + Vector3(-3, 0.1, 0)
	me.aim_yaw = 0.0
	cart.restore([flow.HOME_TRUCK + Vector3(-3, 0.1, -2.6), Quaternion.IDENTITY, false])
	await frames(6)
	game.h_cast(cart.pid, "monster")
	check(flow.role_of(cart) == "monster" and int(flow.cast_sheet()["rows"][0]["grade"]) >= 0, "a prop is cast, so the casting sheet has something to show")
	# 現物を見る人には、今までどおり名前・属性・役が出る
	await face(cart.center_global())
	me.target = cart
	refresh_hud()
	check("〔" in game.hud.target_label.text and "怪獣役" in game.hud.target_label.text and "Y 役を決める" in game.hud.keys.text, "whoever looks at the real prop still reads its name, attributes and role (%s)" % game.hud.target_label.text)
	# 積み込み確認：荷台と機材だけ。配役表は無い
	game.open_menu("packing")
	await frames(4)
	var packing: Array = words_in(game.production_hud._packing)
	check(game.production_hud._packing.visible and not packing.any(func(text: String) -> bool: return "配役" in text or "怪獣役" in text or "役を決める" in text or "コンボ" in text), "the packing screen has no casting sheet")
	check(not flow.loadout().has("checks") and not flow.loadout().has("combos") and "怪獣役" not in flow.loadout_status(), "and the packing data carries none")
	game.close_menu()
	await frames(2)
	# 発注の画面：品物の写真と注文票だけ。今日の廃材の一覧・配役表・場面の並びは無い
	game.h_open_order()
	await frames(4)
	var catalog: Control = game.hud.catalog
	var order_words: Array = words_in(catalog)
	# 写真の数で見る（カードの欄を流すスクロールが内部に持つ絵は、数えない）
	var photos: Array = catalog.find_children("*", "TextureRect", true, false).filter(func(r: Node) -> bool: return not (r.get_parent() is ScrollContainer))
	check(catalog.visible and photos.size() == game.OPTIONS.size(), "the order screen shows photos of the rental items only, not of today's scrap")
	check(not order_words.any(func(text: String) -> bool: return "今日の廃材" in text or "配役" in text or "怪獣役" in text or str(scenes[0]) in text or str(scenes[2]) in text), "it has no scrap list, no casting sheet and no scene list")
	check(order_words.has("注文票") and "注文する" in str(catalog.confirm.text) and (catalog.rows as Array).all(func(row: Dictionary) -> bool: return (row["pic"] as TextureRect).texture != null), "the order slip, the prices and the item photos stay")
	game.h_order_confirm()
	await frames(6)
	check(not catalog.visible and flow.phase == 2, "the order screen closes again")
	# あそびかた（Tab）にも、場面の並びは書かない
	var sheet: Control = game.hud.help_sheet
	sheet.set_context(game.hud.cue_list(), game.hud.scene_titles())
	check("{scenes}" not in str(sheet.text) and str(scenes[0]) not in str(sheet._rendered()) and "挟まっている" in str(sheet.text) and "のぞき箱" not in str(sheet.text), "the help sheet no longer lists the scenes, and explains the photos in the script")
	# 台本を持っていない人は、台本のページも見られない
	check(not game.reads_script() and not game.production_hud.script_page.visible, "without the script, the casting sheet is nowhere on screen")


# ---- みんなの画面（現場）：場面の一覧は、台本を読める人にだけ ----

func test_set_screens() -> void:
	var hud: Node = game.hud
	var scenes: Array = flow.job()["scenes"]
	await frames(4)
	await process_frame
	var panel: Control = hud.order_panel
	check(flow.phase == 4 and panel.is_visible_in_tree() and hud.order_state.is_visible_in_tree(), "on the set, the job panel still shows the take count")
	check(not game.reads_script() and hud.order_lines.all(func(line: Label) -> bool: return not line.is_visible_in_tree()), "but without the script it has no scene list")
	check(not words_in(panel).any(func(text: String) -> bool: return str(scenes[0]).get_slice("（", 0) in text), "and no scene name is written on it")
	# 台本を持つと、場面の一覧が出る。F で開けば、配役も読める
	var book: Node = flow.script_prop
	book.restore([me.global_position + me.flat_forward() * 1.2 + Vector3(0, 0.4, 0), Quaternion.IDENTITY, false])
	await frames(4)
	game.h_grab(book.pid)
	await frames(4)
	await process_frame
	check(game.holding_script() and game.reads_script() and hud.order_lines.all(func(line: Label) -> bool: return line.is_visible_in_tree()), "holding the script brings the scene list back")
	check(str(scenes[0]).get_slice("（", 0) in (hud.order_lines[0] as Label).text, "with the scene names (%s)" % (hud.order_lines[0] as Label).text)
	press(KEY_F)
	await frames(3)
	await process_frame
	var page: Control = game.production_hud.script_page
	var lines: Array = words_in(page)
	check(game.script_open and page.visible and lines.any(func(text: String) -> bool: return text.begins_with("配役")) and lines.any(func(text: String) -> bool: return "怪獣役" in text) and lines.any(func(text: String) -> bool: return "第1場" in text), "the open script shows the casting sheet and the scenes")
	check(page.find_children("*", "TextureRect", true, false).is_empty() and not desk.view.visible, "the script is words only: the slide pictures stay in the peep box")
	game.h_release()
	await frames(4)
	await process_frame
	check(not game.reads_script() and not page.visible and hud.order_lines.all(func(line: Label) -> bool: return not line.is_visible_in_tree()), "letting go of the script hides both again")
	# 手帳の人の「台本の写し」は、今までどおり文字の台本を読める（スライドの絵は写せない）
	game.h_select_cast(game.PLAYER_CASTS.find("03"))
	await frames(12)
	me = game.local_player()
	game.talent.host_note(me.peer_id, true)
	await frames(4)
	await process_frame
	check(game.talent.note_open(me.peer_id) and game.reads_script() and page.visible and hud.order_lines.all(func(line: Label) -> bool: return line.is_visible_in_tree()), "the notebook talent still reads the written script")
	check(page.find_children("*", "TextureRect", true, false).is_empty() and not desk.view.visible and flow.peeper == 0, "but it copies no slide pictures")
	game.talent.host_note(me.peer_id, false)
	await frames(4)


# ---- スライドの中身（ホストが決める） ----

func test_slides() -> void:
	check(desk != null and flow.slides.is_empty() and flow.peeper == 0, "before a job there are no slides and nobody at the peep box")
	# 選び方の決まり：台本2つ × 乱数の種 × 今日の在庫のいろいろ
	var everything: Array = Cast.PROPS.keys()
	var rentals: Array = ["balcony", "window", "fx", "dolly", "sandbag", "rose", "carton", "spot"]
	var problems: Array = []
	var some_missing := 0
	var decks := 0
	var with_pair := 0
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261013
	for story: String in ["castle", "kaiju"]:
		var likes: Array = Briefs.brief(job_of(story))["likes"]
		for n in 120:
			# 今日の在庫：全部 / 借りられる物だけ / ばらばらに 18 種 / 何も無い
			var stock: Array = everything
			if n % 4 == 1:
				stock = rentals
			elif n % 4 == 2:
				stock = rentals.duplicate()
				for i in 18:
					stock.append(everything[rng.randi() % everything.size()])
			elif n % 4 == 3:
				stock = []
			var deck: Dictionary = Slides.build(job_of(story), story, likes, stock, rng.randi())
			var problem := deck_problem(deck, story, likes, stock)
			if problem != "":
				problems.append("%s #%d: %s" % [story, n, problem])
			decks += 1
			if not (deck["plus"] as Array).is_empty():
				with_pair += 1
			if n % 4 == 2 and Slides.kinds_of(deck).any(func(kind: String) -> bool: return kind not in stock):
				some_missing += 1
	check(problems.is_empty(), "every deck follows the rules (%d decks) %s" % [decks, str(problems.slice(0, 3))])
	check(some_missing > 40, "on an ordinary day, some of the shown shapes are not obtainable (%d of 60 decks)" % some_missing)
	check(with_pair > decks * 3 / 4, "most decks join a pair with a plus (%d of %d)" % [with_pair, decks])
	# 同じ種なら、同じ中身
	var once: Dictionary = Slides.build(3, "kaiju", ["街角", "乗り物"], rentals, 77)
	check(once == Slides.build(3, "kaiju", ["街角", "乗り物"], rentals, 77) and once != Slides.build(3, "kaiju", ["街角", "乗り物"], rentals, 78), "the same seed gives the same deck, another seed another one")
	# 名前つきのコンボ（トイレとうんこ など）が、らしさの低い物でも、組で並ぶことがある
	var odd := 0
	for n in 60:
		var deck: Dictionary = Slides.build(3, "kaiju", [], everything, n)
		for pair: Array in Slides.plus_pairs(deck):
			if Cast.fit(pair[1], pair[0]) == 0 or Cast.fit(pair[3], pair[2]) == 0:
				odd += 1
	check(odd > 5, "named combos bring in shapes that do not fit by themselves (%d pairs in 60 decks)" % odd)
	# 写真（シルエットの元）が、役に使える物ぜんぶにある
	var no_photo: Array = everything.filter(func(kind: String) -> bool: return not Cast.is_joker(kind) and Catalog.thumb(kind) == null)
	check(no_photo.is_empty(), "every castable prop has a photo to cut a silhouette from %s" % str(no_photo))

	# 依頼を受けると、ホストがスライドを決める。今日の在庫（日替わり）に合わせる
	flow.daily = true
	seed(5)
	flow.restock()
	var today: Array = flow.obtainable_kinds()
	check(today.size() < everything.size() - 10 and "fx" in today and "carton" in today and "balcony" in today, "on a daily-stock day only part of the props are obtainable (%d of %d), rentals included" % [today.size(), everything.size()])
	check(not flow.stash.is_empty() and flow.stash.all(func(pid: int) -> bool: return game.props[pid].kind == "carton" or game.props[pid].kind not in today or game.props.values().any(func(other: Node) -> bool: return other.kind == game.props[pid].kind and other.pid not in flow.stash)), "what is put away today is not counted as obtainable")
	game.h_accept_job(job_of("kaiju"))
	await frames(6)
	var deck: Dictionary = flow.slides
	check(flow.phase == 2 and not deck.is_empty() and int(deck["job"]) == job_of("kaiju"), "accepting a job decides the slides")
	check(deck_problem(deck, "kaiju", flow.likes(), today) == "", "the job's slides follow the rules for today's stock (%s)" % deck_problem(deck, "kaiju", flow.likes(), today))
	check((deck["rows"] as Array).any(func(row: Array) -> bool: return (row[1] as Array).any(func(kind: String) -> bool: return kind in today)), "at least one role has something obtainable today")
	check((flow.snapshot()["slides"] as Dictionary) == deck, "the slides travel in the snapshot")


# ---- 台本に挟まった参考写真（中の名前は、前の「のぞき箱」のまま peep） ----
# 2026-10-24 から、机の上の写真の台は無い。台本を持って開き、もう一度 F で写真を見る（production_director.gd の冒頭）

# 台本を、自分の前に出して持つ
func hold_script() -> Node:
	var book: Node = flow.script_prop
	if me.held == book.pid:
		return book
	if me.held != 0:
		game.h_release()
		await frames(3)
	book.restore([me.global_position + me.flat_forward() * 0.9 + Vector3(0, 0.6, 0), Quaternion.IDENTITY, false])
	await frames(3)
	game.h_grab(book.pid)
	await frames(3)
	return book


func test_peep_box() -> void:
	var view: CanvasLayer = desk.view
	var box: Vector3 = desk.BOX_AT
	check(desk.open_hours() and not desk.peeping() and not view.visible, "the photos can be seen once a job is taken, and nobody is looking")
	# 机の上には、もう写真の台は無い（机の物は発注の電話だけ）。手ぶらでは写真は見られない
	await stand_at_desk(box)
	check(desk.aimed() != "peep" and desk._root.get_node_or_null("PeepBox") == null, "the desk has no peep box any more (%s)" % desk.aimed())
	game.h_peep(true)
	await frames(2)
	check(flow.peeper == 0 and not desk.peeping(), "without the script, the photos cannot be seen")

	# 台本を持つ → F で開く → もう一度 F で、挟まった写真を見る
	var book: Node = await hold_script()
	me.aim_yaw = PI
	me.aim_pitch = 0.0
	await frames(4)
	refresh_hud()
	check(me.held == book.pid and "F 台本を開く" in game.hud.keys.text, "holding the script, F opens it (%s)" % game.hud.keys.text.get_slice("\n", 0))
	press(KEY_F)
	await frames(3)
	refresh_hud()
	check(game.script_open and "F 挟まっている写真を見る" in game.hud.keys.text, "with the script open, F looks at the tucked-in photos (%s)" % game.hud.keys.text.get_slice("\n", 0))
	var clock_before: float = flow.prep_left
	var stood_at: Vector3 = me.global_position
	press(KEY_F)
	await frames(4)
	check(flow.peeper == me.peer_id and desk.peeping() and not game.script_open, "F again starts looking at the photos")
	var screen := Rect2(Vector2.ZERO, root.get_visible_rect().size)
	check(view.visible and is_equal_approx(view.cover.color.a, 1.0) and view.cover.get_global_rect().encloses(screen), "while looking, an opaque cover hides the whole world")
	check(view.layer > game.hud.layer and view.layer > game.production_hud.layer, "the photo sits above every other screen")
	check(game.ui_blocking() and desk.aimed() == "", "the one looking cannot act on the world")
	check(me.held == book.pid and me.global_position.distance_to(stood_at) < 0.2, "the looker keeps the script in hand and stays where they were")
	check(me.vis.skel.get_node_or_null("DeskPose") == null, "no fixed pose is put on the looker (they just look down at the script)")

	# 写真：役ごとのシルエット・好み・絵コンテ
	var deck: Dictionary = flow.slides
	var scenes: Array = flow.job()["scenes"]
	check(view.count() == 2 + scenes.size() and view.page == 0, "there are photos for the roles, the client's taste and each scene (%d)" % view.count())
	var row_kinds: Array = []
	var captions: Array = []
	for row: Array in deck["rows"]:
		row_kinds.append_array(row[1])
		captions.append(Cast.role_name(str(row[0]), "kaiju") + ("に" if row[0] == "boom" else "の役に"))
	check(view.shown_kinds(0) == row_kinds, "the first photo lines up the silhouettes role by role")
	check(view.texts(0) == captions, "the only words on it are the short role captions %s" % str(view.texts(0)))
	var words: Array = view.texts(0) + view.texts(1)
	var leaks: Array = []
	for kind: String in Slides.kinds_of(deck):
		var prop: Node = first(kind)
		var name_of: String = str(prop.label).get_slice("（", 0) if prop != null else ""
		for word: String in words:
			if name_of != "" and name_of in word:
				leaks.append(name_of)
		for attr: String in Cast.attrs(kind):
			for word: String in words:
				if attr in word:
					leaks.append(attr)
	check(leaks.is_empty(), "no prop name and no attribute is written on the photos %s" % str(leaks))
	if view.pages.size() >= 3:
		var pictures: Array = (view.pages[0] as Control).find_children("*", "TextureRect", true, false).filter(func(pic: TextureRect) -> bool: return pic.has_meta("kind"))
		check(pictures.size() == row_kinds.size() and pictures.all(func(pic: TextureRect) -> bool: return pic.texture != null and pic.material is ShaderMaterial), "every shape is drawn through the silhouette shader, not as a colour photo")
		var like_kinds: Array = []
		for group: Array in deck["likes"]:
			like_kinds.append_array(group)
		check(view.shown_kinds(1) == like_kinds and view.texts(1) == ["依頼主の好み"], "the second photo shows the client's taste as shapes, without naming the attribute")
		check((view.pages[2] as Control).find_children("*", "TextureRect", true, false).size() == 1 and str(scenes[0]).get_slice("（", 0) in view.texts(2), "then one storyboard per scene")
	else:
		check(false, "the photo pages exist (%d)" % view.pages.size())

	# 送る：A/D・クリック・ホイール。端まで行くと回る
	press(KEY_D)
	check(view.page == 1 and (view.pages[1] as Control).visible and not (view.pages[0] as Control).visible, "D shows the next photo")
	press(KEY_A)
	check(view.page == 0, "A goes back")
	mouse(MOUSE_BUTTON_LEFT)
	mouse(MOUSE_BUTTON_WHEEL_DOWN)
	check(view.page == 2, "a click and the wheel also advance")
	mouse(MOUSE_BUTTON_WHEEL_UP)
	mouse(MOUSE_BUTTON_RIGHT)
	press(KEY_A)
	check(view.page == view.count() - 1, "going back past the first photo wraps to the last")
	check(flow.peeper == me.peer_id and flow.prep_left < clock_before, "the looker stays put, and the prep clock keeps running")

	# 写真を見ている人は、目印（ここ！）を出せない
	game.h_ping(me.global_position + Vector3(0, 2, 0), Vector3.DOWN)
	await frames(2)
	check(game.production_ping.snapshot().is_empty(), "the looker cannot point at things")

	# 一度に見られるのは、台本を持っている1人（台本は1冊）
	var other: Node = add_crew(2, me.global_position + Vector3(0.9, 0, 0))
	await frames(2)
	check(not flow.peep(2, true) and flow.peeper == me.peer_id, "another crew member without the script cannot look")

	# やめる：F / Esc / 歩こうとする。台本は手に残り、閉じる
	press(KEY_F)
	await frames(3)
	check(flow.peeper == 0 and not desk.peeping() and not view.visible and not game.ui_blocking() and not game.script_open and me.held == book.pid, "F stops looking, the world is back, the script is closed in hand")
	for code: int in [KEY_ESCAPE, KEY_W]:
		game.h_peep(true)
		await frames(3)
		var was: bool = desk.peeping()
		press(code)
		await frames(3)
		check(was and flow.peeper == 0 and not view.visible and game.menu_open == "", "%s stops looking too" % ("Esc" if code == KEY_ESCAPE else "trying to walk"))
	game.h_peep(true)
	await frames(3)
	check(flow.peeper == me.peer_id, "the script holder can look again")
	flow.crew_left(me.peer_id)
	await frames(3)
	check(flow.peeper == 0 and not view.visible, "a looker who leaves the game frees the photos")

	# 台本以外の物を持っていると、断られる
	game.h_release()
	await frames(3)
	var crown: Node = first("crown")
	# 王冠は、日替わりで廃材置き場に出ていない日がある。確かめる間だけ、出しておく（終わったら元へ戻す）
	var stash_before: Array = flow.stash.duplicate()
	var crown_home: Array = crown.get_state()
	if crown.pid in flow.stash:
		game.host_ev("stash", [flow.stash.filter(func(pid: int) -> bool: return pid != crown.pid)])
		await frames(2)
	crown.restore([me.global_position + me.flat_forward() * 0.9 + Vector3(0, 0.3, 0), Quaternion.IDENTITY, false])
	await frames(4)
	game.h_grab(crown.pid)
	await frames(3)
	game.h_peep(true)
	await frames(2)
	check(me.held == crown.pid and flow.peeper == 0, "with something other than the script in hand, looking is refused")
	game.h_release()
	await frames(3)

	# 一人称（F2）でも同じ：電話を見ると名前が出る。台本を開いて F で写真を見られる・やめられる
	me.set_first_person(true)
	me.global_position = Vector3(desk.PHONE_AT.x, 0.1, 2.3)
	me.velocity = Vector3.ZERO
	await frames(3)
	var to_phone: Vector3 = desk.PHONE_AT + Vector3(0, 0.12, 0) - me.cam.global_position
	me.aim_yaw = atan2(-to_phone.x, -to_phone.z)
	me.aim_pitch = atan2(to_phone.y, Vector2(to_phone.x, to_phone.z).length())
	await frames(6)
	var seen_fp: String = desk.aimed()
	me.aim_yaw = PI
	me.aim_pitch = 0.0
	await frames(3)
	await hold_script()
	press(KEY_F)
	await frames(3)
	press(KEY_F)
	await frames(4)
	var peeped_fp: bool = desk.peeping() and view.visible and flow.peeper == me.peer_id
	press(KEY_F)
	await frames(4)
	check(me.first_person and seen_fp == "phone" and peeped_fp and not desk.peeping() and not view.visible, "in first person, the phone is aimed at and the script's photos open the same way (%s)" % seen_fp)
	me.set_first_person(false)
	game.h_release()
	await frames(3)

	# 物を手に持ったまま電話を見る：名前の欄は電話の名前だけ（手に持った物の属性・役・特技の案内を、足さない）。
	# 段ボール頭で確かめる（持った物に「K：頭にしまう」も付くキャラ）。操作の案内は、今までどおり下の行に出る
	var my_cast: int = game._roster[0][1]
	game.h_select_cast(game.PLAYER_CASTS.find("09"))
	await frames(4)
	crown.restore([Vector3(desk.PHONE_AT.x + 0.7, 0.3, 2.0), Quaternion.IDENTITY, false])
	await frames(4)
	game.h_grab(crown.pid)
	await frames(3)
	await stand_at_desk(desk.PHONE_AT)
	refresh_hud()
	var in_hand: String = game.hud.target_label.text
	var hand_keys: String = game.hud.keys.text
	check(me.held == crown.pid and desk.aimed() == "phone" and in_hand == "発注の電話", "with a prop in hand, the phone still shows only its own name (%s)" % in_hand)
	check("手ぶらで F" in hand_keys and "K 頭にしまう" in hand_keys and "Y 役を決める" in hand_keys, "and the hints for the prop in hand stay on the key line (%s)" % hand_keys.get_slice("\n", 0))
	# 電話から目を離せば、手に持った物の属性と特技の案内が、今までどおり名前の欄に出る
	me.aim_yaw = PI
	me.aim_pitch = 0.0
	await frames(6)
	refresh_hud()
	check(desk.aimed() == "" and "〔お宝〕" in game.hud.target_label.text and "K：頭にしまう" in game.hud.target_label.text, "looking away, the prop in hand shows its attributes as before (%s)" % game.hud.target_label.text)
	game.h_release()
	game.h_select_cast(my_cast)
	await frames(4)

	# 段ボール頭の仲間が電話の前に立っている：頭に物をしまっていれば、その頭の道具箱が先（F は「頭から取り出す」）。
	# 何もしまっていなければ、仲間ごしに電話を見られる
	for row: Array in game._roster:
		if row[0] == 2:
			row[1] = game.PLAYER_CASTS.find("09")
	game._apply_roster()
	other.global_position = Vector3(desk.PHONE_AT.x, 0.05, 1.2)
	crown.restore([other.global_position + Vector3(1.2, 0.3, 0.8), Quaternion.IDENTITY, false])
	await frames(4)
	# 仲間の1.6 m 後ろから、頭ごしに電話を見る（頭の道具箱は、自分より先にいる相手のだけ狙える）。
	# 一人称で見る（三人称だと、カメラが社屋の書割の外に出て、照準が書割に止まる。報告済みの不具合）
	me.set_first_person(true)
	me.global_position = Vector3(desk.PHONE_AT.x, 0.1, other.global_position.z + 1.6)
	me.velocity = Vector3.ZERO
	await frames(3)
	var to_phone2: Vector3 = desk.PHONE_AT + Vector3(0, 0.12, 0) - me.cam.global_position
	me.aim_yaw = atan2(-to_phone2.x, -to_phone2.z)
	me.aim_pitch = atan2(to_phone2.y, Vector2(to_phone2.x, to_phone2.z).length())
	await frames(6)
	var through: String = desk.aimed()
	game.host_ev("stow", [2, crown.pid, true])
	await frames(6)
	refresh_hud()
	var head_first: bool = game.talent.crew_aimed(me) == 2 and desk.aimed() == "" and "頭の道具箱" in game.hud.target_label.text and "発注する" not in game.hud.keys.text
	check(through == "phone" and head_first, "a crew member's head box in front of the phone comes first (%s / %s)" % [through, game.hud.target_label.text])
	# F は机が受け取らず、次の「頭から取り出す」へ回る（取り出すところまでは、ここでは押さない。相手が本物の参加者でないため）
	check(not desk.handle_f(me) and flow.orderer == 0, "and the desk leaves F to the head box")
	game.host_ev("stow", [2, crown.pid, false])
	await frames(6)
	check(game.talent.crew_aimed(me) == 0 and desk.aimed() == "phone", "once that head is empty, the phone can be aimed at again")
	me.set_first_person(false)
	crown.restore(crown_home)
	game.host_ev("stash", [stash_before])
	await frames(2)

	# 出発すると、見ていた人も外れる。移動中は見られない
	me.global_position = flow.HOME_TRUCK + Vector3(-3, 0.1, 0)
	other.global_position = flow.HOME_TRUCK + Vector3(-3, 0.1, 1.2)
	flow.peeper = 2
	await frames(3)
	game.h_depart()
	await frames(3)
	check(flow.phase == 3 and flow.peeper == 0 and not desk.peeping() and not desk.open_hours(), "leaving for the set closes the photos")
	game.h_peep(true)
	check(flow.peeper == 0, "nobody can look on the road")
	for i in 900:
		if flow.phase == 4:
			break
		await physics_frame
	await frames(4)
	# 現場でも、本番の前なら、台本を持てば写真を見られる（会社でも現場でも）
	game.h_peep(true)
	await frames(2)
	var empty_handed: bool = flow.peeper == 0
	await hold_script()
	game.h_peep(true)
	await frames(3)
	check(flow.phase == 4 and empty_handed and flow.peeper == me.peer_id and view.visible, "on the set, before the take, the script holder can still look at the photos")
	game.h_peep(false)
	await frames(3)
	game.h_release()
	await frames(3)
	check(flow.peeper == 0 and not view.visible and not game.reads_script(), "and stops again")


# ---- 発注：自分の画面にだけ開く。ほかの人は止まらない ----

# 会社の庭（借りた物が届く所）に在るか
func at_home(prop: Node) -> bool:
	return not prop.absent and prop.global_position.y > -1.0 and prop.global_position.distance_to(flow.HOME_TRUCK) < 14.0


# 前へ歩く。進んだ距離を返す
func walk(count: int) -> float:
	var from: Vector3 = me.global_position
	Input.action_press("move_forward")
	await frames(count)
	Input.action_release("move_forward")
	await frames(2)
	return me.global_position.distance_to(from)


func test_order() -> void:
	# 事務所へ戻って、次の依頼を受ける（城の依頼。制作費 500）。
	# 姿だけの2人目は、精算の間は外しておく（精算には、1人ずつに送る知らせがある）
	await remove_crew(2)
	flow.expire()
	await frames(6)
	game.h_deliver(0)
	await frames(6)
	game.h_return_office()
	await frames(8)
	flow.daily = false
	flow.restock()
	game.h_accept_job(0)
	await frames(8)
	me = game.local_player()
	var other: Node = add_crew(2, flow.Office.SPAWN_POINT + Vector3(1.5, 0, 0))
	var catalog: Control = game.hud.catalog
	var dolly: Node = first("dolly")
	var rose: Node = first("rose")
	var bomb: Node = game.fx
	var sandbag: Node = first("sandbag")
	var cart: Node = first("lift_cart")
	var book: Node = flow.script_prop
	check(flow.phase == 2 and flow.orderer == 0 and flow.ordered.is_empty() and not game.ordering() and dolly.absent and rose.absent, "a new job starts with nothing ordered and nobody ordering")

	# 三人称で、机から 2 m 離れて電話を狙う：書割は自分の視点から消えている（office_facade.gd）ので、照準も通ってほしい
	await stand_at_desk(desk.PHONE_AT, 2.3)
	check(desk.aimed() == "phone", "in third person, the phone 2 m away can be aimed at past the office facade (%s)" % desk.aimed())
	# 机の電話を見て F：自分の画面にだけ、発注の画面が開く。全体は止まらない
	await stand_at_desk(desk.PHONE_AT)
	refresh_hud()
	check(desk.aimed() == "phone" and "発注の電話" in game.hud.target_label.text and "F 発注する" in game.hud.keys.text, "the phone on the desk shows its name and the F hint (%s)" % game.hud.target_label.text)
	var clock: float = flow.prep_left
	press(KEY_F)
	await frames(4)
	await process_frame
	check(flow.orderer == me.peer_id and game.ordering() and catalog.visible, "F at the phone opens the order screen for the one who pressed")
	check(flow.phase == 2 and game.state == game.S.PREP, "the game itself stays in the packing phase")
	check(game.ui_blocking() and game.wants_cursor() and desk.aimed() == "", "the one who orders is busy with that screen")
	var pose: Node = me.vis.skel.get_node_or_null("DeskPose")
	check(pose != null and pose.mode == "phone" and (desk._handset as Array).all(func(part: Node3D) -> bool: return not part.visible), "that person is seen holding the phone (pose and lifted handset)")
	await frames(40)
	check(flow.prep_left < clock - 0.5, "the prep clock keeps running while the order screen is open")

	# 選ぶ：台車とバラ。決めるまでは、何も届かない
	game.h_order_set("dolly", 1)
	game.h_order_set("rose", 1)
	await frames(4)
	check(int(game.order.get("dolly", 0)) == 1 and dolly.absent and rose.absent and flow.expenses == 0, "choosing fills the slip, but nothing arrives before the order is confirmed")
	var enter := InputEventKey.new()
	enter.physical_keycode = KEY_ENTER
	enter.pressed = true
	game._unhandled_input(enter)
	await frames(8)
	check(flow.orderer == 0 and not game.ordering() and not catalog.visible and not game.ui_blocking(), "Enter confirms the order and closes the screen")
	check(at_home(dolly) and not rose.absent and rose.rider_of == game.truck.pid, "the ordered things arrive: the dolly by the truck, the rose on the deck")
	check(flow.expenses == 100 and int(flow.ordered.get("dolly", 0)) == 1 and int(flow.ordered.get("rose", 0)) == 1, "and they are paid from the client's budget (%d)" % flow.expenses)
	check(me.vis.skel.get_node_or_null("DeskPose") == null and (desk._handset as Array).all(func(part: Node3D) -> bool: return part.visible), "the phone is back on the hook")

	# ほかの人が発注している間：自分は歩ける・物を持てる・時計は進む。自分は発注できない
	dolly.restore([flow.HOME_TRUCK + Vector3(-6.0, 0.1, 5.0), Quaternion.IDENTITY, false])
	game.adhesive.pairs = [{"a": cart.pid, "b": game.truck.pid, "pa": Vector3.ZERO, "pb": game.truck.to_local(cart.global_position), "joined": true}]
	game.adhesive.rebuild()
	me.global_position = Vector3(77.5, 0.1, 9.5)
	me.aim_yaw = PI * 0.5
	# 電話の人は、少し横に立つ（あとで自分が電話のすぐ前に立つので、重ならないように）
	other.global_position = Vector3(desk.PHONE_AT.x + 0.9, 0.1, 1.4)
	await frames(20)
	var moved_dolly: Vector3 = dolly.global_position
	game.h_grab(rose.pid)
	await frames(3)
	flow.open_order(2)
	await frames(4)
	await process_frame
	check(flow.orderer == 2 and not game.ordering() and not catalog.visible and not game.ui_blocking(), "when another crew member orders, my screen stays as it is")
	check(other.vis.skel.get_node_or_null("DeskPose") != null and other.vis.skel.get_node("DeskPose").mode == "phone", "and I can see who is on the phone")
	game._order_change(2, "fix", 1, false)
	clock = flow.prep_left
	var walked: float = await walk(40)
	check(walked > 1.0 and me.held == rose.pid and flow.prep_left < clock, "meanwhile I can walk and carry things, and the clock runs (%.1f m)" % walked)
	check(int(game.order.get("fix", 0)) == 1 and sandbag.absent, "what the other one is choosing has not arrived yet")
	game.h_open_order()
	game.h_order_set("fx", 1)
	game.h_order_confirm()
	await frames(3)
	check(flow.orderer == 2 and int(game.order.get("fx", 0)) == 0 and sandbag.absent, "only one person orders at a time: my requests are refused")
	await stand_at_desk(desk.PHONE_AT + Vector3(-0.3, 0, 0))
	refresh_hud()
	check(desk.aimed() == "phone" and me.held == rose.pid and game.hud.target_label.text == "発注の電話（使用中）", "the phone says it is in use, and nothing about the rose in my hand (%s)" % game.hud.target_label.text)

	# 相手が注文を決めた：届くのは、新しく頼んだ重りだけ。私の手の物・接着・動かした台車は、そのまま
	game.host_confirm_order(2)
	await frames(8)
	check(flow.orderer == 0 and at_home(sandbag) and flow.expenses == 160, "the other one's order is confirmed and the weights arrive (%d)" % flow.expenses)
	check(me.held == rose.pid and rose.holder == me.peer_id, "confirming an order does not take things out of other people's hands")
	check(game.adhesive.pairs.size() == 1 and dolly.global_position.distance_to(moved_dolly) < 0.6, "nor does it undo glue, or move what was delivered before")

	# やめた物だけが片づく：台車を返す。載せてあった物は残り、台車に付いていた接着だけが外れる
	game.h_release()
	await frames(3)
	game.host_load(book, dolly)
	game.adhesive.pairs.append({"a": dolly.pid, "b": cart.pid, "pa": Vector3.ZERO, "pb": cart.to_local(dolly.global_position), "joined": true})
	game.adhesive.rebuild()
	await frames(3)
	check(book.rider_of == dolly.pid and game.adhesive.pairs.size() == 2, "the script rides on the dolly, and the dolly is glued to the lift")
	game.h_open_order()
	game.h_order_set("dolly", 0)
	game.h_order_confirm()
	await frames(8)
	check(dolly.absent and flow.expenses == 80, "returning the dolly takes it away (%d)" % flow.expenses)
	check(book.rider_of == 0 and not book.absent and book.global_position.y > -1.0, "what was riding on it stays behind")
	check(game.adhesive.pairs.size() == 1 and int(game.adhesive.pairs[0]["a"]) == cart.pid, "and only the glue on the returned dolly is removed")

	# 決めずに閉じる（Esc・右クリック・閉じるボタン）：選びかけの注文は、前に決めた注文へ戻る
	game.h_open_order()
	game.h_order_set("fx", 1)
	await frames(3)
	check(game.ordering() and int(game.order.get("fx", 0)) == 1 and bomb.absent, "a bomb is chosen but not confirmed")
	press(KEY_ESCAPE)
	await frames(4)
	await process_frame
	check(flow.orderer == 0 and not catalog.visible and game.menu_open == "" and int(game.order.get("fx", 0)) == 0 and bomb.absent and flow.expenses == 80, "Esc closes the screen and drops the unconfirmed choice")
	game.h_open_order()
	game.h_order_set("fx", 1)
	mouse(MOUSE_BUTTON_RIGHT)
	await frames(4)
	check(flow.orderer == 0 and int(game.order.get("fx", 0)) == 0 and bomb.absent, "a right click does the same")
	game.h_open_order()
	game.h_order_set("fx", 1)
	(catalog._skip as Button).pressed.emit()
	await frames(4)
	check(flow.orderer == 0 and int(game.order.get("fx", 0)) == 0, "and so does the close button")
	# 発注中に抜けた人：席が空き、選びかけは消える
	game.h_open_order()
	game.h_order_set("fx", 1)
	flow.crew_left(me.peer_id)
	await frames(3)
	check(flow.orderer == 0 and int(game.order.get("fx", 0)) == 0 and not game.ordering(), "an orderer who leaves the game frees the desk")

	# 台本の写真を見ることと発注は、同時にはできない（台本を持って試す）
	me.global_position = Vector3(desk.PHONE_AT.x, 0.1, 2.0)
	await frames(2)
	await hold_script()
	game.h_open_order()
	await frames(2)
	game.h_peep(true)
	check(flow.orderer == me.peer_id and flow.peeper == 0, "while ordering, the script's photos are refused")
	game.h_order_close()
	await frames(2)
	game.h_peep(true)
	await frames(3)
	game.h_open_order()
	check(flow.peeper == me.peer_id and flow.orderer == 0, "while looking at the photos, ordering is refused")
	game.h_peep(false)
	await frames(3)
	game.h_release()
	await frames(3)

	# 荷台の決まった場所に先客がいたら、届いた爆弾は荷台の空いた所へ（重ねない・押しのけない）
	var slot := Transform3D(Basis.IDENTITY, Vector3(0.34, game.truck.deck_top + 0.02, -0.8))
	var world: Transform3D = game.truck.global_transform * slot
	sandbag.restore([world.origin, Quaternion.IDENTITY, false])
	game._set_rider(sandbag, game.truck, slot)
	await frames(30)
	game.h_open_order()
	game.h_order_set("fx", 1)
	game.h_order_confirm()
	await frames(20)
	var to_deck: Transform3D = game.truck.global_transform.affine_inverse()
	var bomb_box: AABB = (to_deck * bomb.global_transform) * (game.body_bounds(bomb) as AABB)
	var bag_box: AABB = (to_deck * sandbag.global_transform) * (game.body_bounds(sandbag) as AABB)
	check(not bomb.absent and flow.expenses == 440 and sandbag.rider_of == game.truck.pid, "the bomb is ordered while the deck is in use (%d)" % flow.expenses)
	check(bomb.rider_of == game.truck.pid and not bomb_box.grow(-0.03).intersects(bag_box) and bomb_box.position.y < game.truck.deck_top + 0.25, "it is set down on a free part of the deck, not on top of the cargo (%s / %s)" % [str(bomb_box), str(bag_box)])

	# 外のレンタルのカウンターでも、同じ画面が自分にだけ開く
	me.global_position = flow.Rental.POINT + Vector3(0, 0.1, 0)
	me.aim_pitch = 0.6
	await frames(4)
	check(game.station() == "order", "the rental counter by the truck is still an order point")
	press(KEY_F)
	await frames(4)
	check(flow.orderer == me.peer_id and game.ordering() and me.vis.skel.get_node_or_null("DeskPose") == null, "F there opens the same screen for me only")
	game.h_order_close()
	await frames(3)

	# 出発：発注の途中だった人の、選びかけの注文は消える
	flow.open_order(2)
	game._order_change(2, "rose", 0, false)
	me.global_position = flow.HOME_TRUCK + Vector3(-3, 0.1, 0)
	other.global_position = flow.HOME_TRUCK + Vector3(-3, 0.1, 1.2)
	await frames(3)
	check(flow.orderer == 2 and int(game.order.get("rose", 0)) == 0 and not rose.absent, "someone is still choosing when the crew gathers at the truck")
	game.h_depart()
	await frames(3)
	check(flow.phase == 3 and flow.orderer == 0 and int(game.order.get("rose", 0)) == 1 and not rose.absent, "leaving for the set drops the unconfirmed choice")

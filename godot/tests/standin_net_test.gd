extends "res://tests/pair_net_base.gd"
# 等身大パネルのペイントの二人通信：
#   参加者が描いた線・下塗り・見本の貼り付けが、ホストと参加者の両方の絵（panel.ink）に出る / 白紙に戻すと両方で白紙 /
#   あとから同期（sync_to）しても、入り直した人にも絵が届く。絵は見分けられるように、画素の並びごと見比べる。
#   遠い人・箱にない色・知らない見本・カンペへの見本は、ホストが断る。パネルの絵は見立て（ジョーカー）の点にも使われる。
# 会社での準備中（phase 2）のまま確かめる。出発も到着も使わない。
#   godot --headless --path godot res://tests/standin_net_test.tscn -- --standin-net-test-host      （参加者は -client）

# 絵の中の見る場所（パネルは 512×1200、カンペは 1024×724 なので、はみ出す分は端に寄せる）
const SAMPLES := [Vector2i(5, 5), Vector2i(250, 300), Vector2i(250, 600), Vector2i(250, 1100)]


func configure() -> void:
	prefix = "STANDIN_NET"
	port = 24852
	flag = "standin-net-test"
	budget = 60.0


func after_game() -> void:
	# 役の同期を、定期の送り直しに頼らず確かめる
	game.production.set_physics_process(false)


# 絵そのもの：画素の並びの要約と、見る場所の色
func picture(board: Node) -> Dictionary:
	var ink: Image = board.ink
	var spots: Array = []
	for point: Vector2i in SAMPLES:
		spots.append(ink.get_pixel(mini(point.x, ink.get_width() - 1), mini(point.y, ink.get_height() - 1)).to_html(false))
	return {"hash": hash(ink.get_data()), "size": ink.get_size(), "spots": spots}


func view() -> Dictionary:
	var cards: Node = game.cue_cards
	var flow: Node = game.production
	var panel: Node = cards.panel
	return {"boards": cards.boards.keys(), "panel": picture(panel), "card": picture(cards.card), "revision": panel.revision, "blank": panel.blank(),
		"casting": flow.casting.duplicate(), "fit": flow.cast_fit(panel, "monster"), "sheet": flow.cast_sheet()}


func host_action(action: String, arg: Variant, who: int) -> Dictionary:
	var cards: Node = game.cue_cards
	var panel: Node = cards.panel
	var front: Vector3 = panel.global_basis.z
	var side: Vector3 = front.cross(Vector3.UP)
	# パネルの正面に立つ（描ける近さ。ホストの制作班は反対側）
	var stand: Vector3 = panel.global_position + front * 2.2 + side * 0.9 + Vector3(0, 0.1, 0)
	match action:
		"stage":
			crew_to(who, stand)
			crew_to(1, panel.global_position + front * 2.2 - side * 0.9 + Vector3(0, 0.1, 0))
		"near":
			crew_to(who, stand)
		"far":
			crew_to(who, stand + Vector3(14, 0, 0))
		"fill":
			# ホストの制作班が塗る
			cards.h_fill(panel.pid, arg)
		"resend":
			cards.sync_to(who)
		"restore_home":
			# 事務所へ戻ったとき（production_flow.gd の return_office）と同じに、会社の物を元の状態へ戻す
			panel.restore(game.production._home_layout[panel.pid])
	return {}


func client_run() -> void:
	var cards: Node = game.cue_cards
	var flow: Node = game.production
	var panel: Node = cards.panel
	var green: Color = cards.PANEL_COLORS[9][1]
	var red: Color = cards.PANEL_COLORS[5][1]
	var blue: Color = cards.PANEL_COLORS[11][1]
	var paint := ["panel", "revision", "blank"]

	# ---- はじめは白紙。カンペとパネルの二つがある ----
	var reply: Dictionary = await request("hello")
	var blank_card: Dictionary = reply["view"]["card"]
	# 描ける物：カンペと等身大パネル（と、看板づくりの段ボール板。features/spray_sign.gd）
	var board_ids: Array = reply["view"]["boards"]
	check(cards.card.pid in board_ids and panel.pid in board_ids and (view()["boards"] as Array) == board_ids and panel.kind == "standin", "both peers have the cue card and the life-size panel")
	check(reply["view"]["blank"] and view()["blank"] and reply["view"]["panel"]["size"] == Vector2i(panel.res), "the panel starts blank on both peers")
	await sees(reply["view"], ["panel", "card", "revision"], "the blank sheets are identical pixel for pixel")

	# 依頼を受けて（見立てに使うため）、パネルの正面へ
	game.h_accept_job.rpc_id(1, job_of("kaiju"))
	check(await until(func() -> bool: return flow.phase == 2 and flow.story() == "kaiju"), "the job starts on both peers")
	reply = await request("stage")

	# ---- 下塗り・線 ----
	cards.h_fill.rpc_id(1, panel.pid, green)
	reply = await request("snapshot")
	check(reply["view"]["panel"]["spots"][0] == green.to_html(false) and not reply["view"]["blank"], "a base coat from the participant covers the host's sheet")
	await sees(reply["view"], paint, "the base coat also covers the participant's sheet")
	cards.h_draw.rpc_id(1, panel.pid, PackedVector2Array([Vector2(60, 300), Vector2(450, 300)]), red, 40.0)
	reply = await request("snapshot")
	check(reply["view"]["panel"]["spots"][1] == red.to_html(false) and reply["view"]["panel"]["spots"][2] == green.to_html(false), "a stroke from the participant lands in its colour on the host and keeps the coat around it")
	await sees(reply["view"], paint, "the stroke is on the participant's sheet too")
	var stroked: Dictionary = reply["view"]["panel"]
	cards.h_draw.rpc_id(1, panel.pid, PackedVector2Array([Vector2(60, 700), Vector2(450, 700)]), Color(0.3, 0.9, 0.1), 40.0)
	reply = await request("snapshot")
	check(reply["view"]["panel"] == stroked, "a colour that is not in the paint box is refused")
	await sees(reply["view"], paint, "a refused stroke changes nothing on the participant either")

	# ---- 見本 ----
	cards.h_preset.rpc_id(1, panel.pid, "actor_a")
	reply = await request("snapshot")
	var pasted: Dictionary = reply["view"]["panel"]
	check(pasted["hash"] != stroked["hash"] and pasted["size"] == Vector2i(panel.res) and not reply["view"]["blank"], "a sample picture pasted by the participant replaces the sheet on the host")
	await sees(reply["view"], paint, "the sample picture is pixel for pixel the same on the participant")
	cards.h_preset.rpc_id(1, panel.pid, "no_such_picture")
	cards.h_preset.rpc_id(1, cards.card.pid, "actor_b")
	reply = await request("snapshot")
	check(reply["view"]["panel"] == pasted and reply["view"]["card"] == blank_card, "an unknown sample and a sample for the cue card are refused")
	await sees(reply["view"], paint + ["card"], "the participant's sheets are untouched by the refused samples")

	# ---- 白紙に戻す ----
	cards.h_clear.rpc_id(1, panel.pid)
	reply = await request("snapshot")
	check(reply["view"]["blank"] and reply["view"]["panel"]["spots"][1] == "ffffff", "wiping the sheet makes it blank on the host")
	await sees(reply["view"], paint, "wiping the sheet makes it blank on the participant")

	# ---- 見立て（ジョーカー）：絵があれば「それっぽい」、白紙なら「むりやり」。配役表も両方で同じ ----
	game.h_cast.rpc_id(1, panel.pid, "monster")
	reply = await request("snapshot")
	check(reply["view"]["casting"].get(panel.pid, "") == "monster" and reply["view"]["fit"] == 0, "a blank panel cast as the monster is a forced choice")
	await sees(reply["view"], ["casting", "fit", "sheet"], "the casting sheet agrees while the panel is blank")
	cards.h_fill.rpc_id(1, panel.pid, green)
	reply = await request("snapshot")
	check(reply["view"]["fit"] == 1 and not reply["view"]["blank"], "a painted panel passes for the monster on the host")
	await sees(reply["view"], ["panel", "blank", "fit", "sheet"], "the participant's casting sheet follows the paint")
	cards.h_clear.rpc_id(1, panel.pid)
	reply = await request("snapshot")
	check(reply["view"]["fit"] == 0 and reply["view"]["blank"], "wiping the panel makes the casting forced again on the host")
	await sees(reply["view"], ["panel", "blank", "fit", "sheet"], "the participant's casting sheet follows the wiping")

	# ---- 遠くの人は描けない ----
	reply = await request("far")
	var before: Dictionary = reply["view"]
	cards.h_fill.rpc_id(1, panel.pid, red)
	cards.h_draw.rpc_id(1, panel.pid, PackedVector2Array([Vector2(60, 300), Vector2(450, 300)]), red, 40.0)
	reply = await request("snapshot")
	check(reply["view"]["panel"] == before["panel"] and reply["view"]["revision"] == before["revision"], "a participant far from the panel cannot paint it")
	await sees(reply["view"], paint, "a refused painter sees no change on the participant either")
	reply = await request("near")

	# ---- ホストが塗った絵も、参加者に出る ----
	reply = await request("fill", blue)
	check(reply["view"]["panel"]["spots"][0] == blue.to_html(false) and not reply["view"]["blank"], "the host paints the sheet")
	await sees(reply["view"], paint, "what the host painted shows on the participant's sheet")

	# ---- あとから同期（sync_to）：取りこぼした参加者の絵が、送り直しで戻る ----
	panel.fill_ink(Color.WHITE)
	check(panel.blank() and view()["panel"] != reply["view"]["panel"], "the participant's copy goes stale (as if the picture had been missed)")
	reply = await request("resend")
	await sees(reply["view"], paint, "sync_to brings the picture back to the participant")

	# ---- 会社の物を元の状態へ戻す（事務所へ戻るときと同じ）：パネルも、全員で白紙に戻る ----
	reply = await request("restore_home")
	check(reply["view"]["blank"] and reply["view"]["revision"] == 0, "restoring the company's props wipes the panel on the host")
	await sees(reply["view"], paint, "and the pushed snapshot wipes the participant's panel too")

	# ---- 途中参加：見本の上に線を重ねた絵が、入り直した人に届く ----
	cards.h_preset.rpc_id(1, panel.pid, "actor_b")
	cards.h_draw.rpc_id(1, panel.pid, PackedVector2Array([Vector2(60, 300), Vector2(450, 300)]), red, 40.0)
	reply = await request("snapshot")
	var expected: Dictionary = reply["view"]
	check(expected["panel"]["spots"][1] == red.to_html(false) and not expected["blank"], "the picture before the rejoin: a sample with a stroke over it")
	await sees(expected, paint, "the participant has the picture before the rejoin")
	await rejoin()
	cards = game.cue_cards
	panel = cards.panel
	reply = await request("hello")
	await sees(expected, paint + ["card", "boards", "casting", "fit", "sheet"], "a late joiner receives the picture, the cue card and the casting", LATE)

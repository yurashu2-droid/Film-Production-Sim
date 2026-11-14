extends "res://tests/pair_net_base.gd"
# カット割りと試写会の二人通信（会社の紹介動画）：
#   社員紹介：一人ずつ寄り。ホストの監督が、止めずにカメラの首を振って4人を撮る。参加者の画面でも、撮れた人が同じにそろう
#   場転　：ホストの監督が撮った場面でフィルムが止まると、参加者の画面でも「場転中」になり、フィルムの時計も止まって見える。
#           回し直すと、参加者の画面でも本番に戻る
#   試写会：参加者が「このテイクを納品」を頼むと、ホストが試写会を始め、参加者の画面にも題名の札・場面の見出し・依頼主が出る。
#           とばすと納品になり、参加者の画面でも「終」の札のあと、ギャラの読み上げが出る
#   godot --headless --path godot res://tests/cuts_net_test.tscn -- --cuts-net-test-host   （参加者は -client）

const CompanyLogo := preload("res://scripts/ui/company_logo.gd")
const CAM_AT := Vector3(0.0, 0.0, 5.0)
const AIM_WIDE := Vector3(0.0, 1.0, -1.6)
const AIM_CLOSE := Vector3(0.0, 0.8, 1.8)
# 会社の紹介動画（4カット・役者4人）の置き方は tests/pr_test.gd と同じ。城と書割は、事務所の壁より手前
const MARKS := [[Vector3(-0.6, 0.05, -1.2), Vector3(-1.0, 0.05, -0.6), Vector3(-0.5, 0.05, 1.8)],
	[Vector3(0.6, 0.05, -1.2), Vector3(-1.9, 0.05, -0.3), Vector3(0.5, 0.05, 1.8)],
	[Vector3(-1.8, 0.05, -1.2), Vector3(1.3, 0.05, -0.3), Vector3(-1.5, 0.05, 1.8)],
	[Vector3(1.8, 0.05, -1.2), Vector3(2.2, 0.05, -0.1), Vector3(1.5, 0.05, 1.8)]]
const CASTLE_AT := Vector3(0.0, 0.0, -2.2)
const FLAT_AT := Vector3(1.9, 0.0, -2.3)
const CARD_AT := Vector3(0.0, 2.05, 0.8)
const PAN_AT := Vector3(0.0, 0.0, 0.5)         # 社員紹介：四人の前の真ん中から、首を振って一人ずつ寄る
const SPOT_AT := [Vector3(-2.6, 0.0, 2.6), Vector3(2.6, 0.0, 2.6)]
const HOST_AT := Vector3(3.0, 0.1, 6.0)        # 監督（ホスト）：カメラの後ろ、台本のそば
const CLIENT_AT := Vector3(-3.0, 0.1, 6.5)     # 参加者：カメラの後ろ（画面の外）
var O := Vector3.ZERO                          # 撮影現場の真ん中（会社のCMは、会社の前）


func configure() -> void:
	prefix = "CUTS_NET"
	port = 24893
	flag = "cuts-net-test"
	budget = 150.0


func view() -> Dictionary:
	var beats: Node = game.beats
	var premiere: Node = game.hooks.feature("premiere")
	return {"phase": game.production.phase, "state": game.state, "hold": beats.holding, "next": beats.next_scene,
		"scene": beats.scene, "lit": beats.lit.duplicate(), "screening": premiere.screening if premiere != null else -2,
		"payment": game.production.last_payment, "flubs": game.production.last_flubs.size(), "roll": beats.roll_done.duplicate(), "holds": beats.roll_holds}


# 場面が撮れて、フィルムが止まるまで（ホスト）
func roll_until_hold(i: int) -> void:
	var beats: Node = game.beats
	await until(func() -> bool: return i < beats.lit.size() and bool(beats.lit[i]), 10.0)
	await until(func() -> bool: return beats.holding or game.state != game.S.TAKE, 4.0)


func host_action(action: String, _arg: Variant, who: int) -> Dictionary:
	var flow: Node = game.production
	var beats: Node = game.beats
	match action:
		"setup":
			# 会社のCMを受けて、現場へ。アーチを城に、書割を奥に、ライトを二人へ
			game.h_accept_job(flow.debut_job())
			await frames(10)
			crew_to(1, flow.HOME_TRUCK + Vector3(-3, 0.1, 0))
			crew_to(who, flow.HOME_TRUCK + Vector3(-3, 0.1, 1.5))
			await wait(0.3)
			game.h_depart()
			await until(func() -> bool: return flow.phase == 4, 20.0)
			await wait(0.5)
			O = flow.site_center()
			place(game.film, O + CAM_AT)
			place(first("scrap_arch"), O + CASTLE_AT, PI)
			place(first("boomflat"), O + FLAT_AT)
			for aid in 4:
				for step in 3:
					beats.place_spot(aid, step, O + MARKS[aid][step])
			# 看板：カンペに会社の名前を描いて、片づけておく（最後のカットの場転で出す）
			var card: RigidBody3D = game.cue_cards.card
			for i in 12:
				card.draw_line(Vector2(80, 80 + i * 50), Vector2(940, 100 + i * 50), Color.BLACK, 22.0)
			place(card, O + Vector3(4.0, 0.0, -6.0))
			for i in 2:
				place(game.spots[i], O + SPOT_AT[i], PI)
			crew_to(1, O + HOST_AT)
			crew_to(who, O + CLIENT_AT)
			var book: Node = flow.script_prop
			var state: Array = book.get_state()
			state[0] = O + HOST_AT + Vector3(0.6, 0.0, 0.0)
			state[2] = false
			book.restore(state)
			await wait(0.5)
			flow.cast_set(first("scrap_arch").pid, "castle")
			for i in 2:
				game._aim_spot(game.spots[i], O + Vector3(0.0, 1.3, -1.0))
				game.spots[i].level = 3
			game._aim_camera(O + AIM_WIDE, 56.0)
			game.h_standby()
			await wait(0.5)
		"roll":
			# カチンコで回す → 社員紹介：止めずに、カメラの首を振って一人ずつ寄る → そろって、止まるまで
			place(game.film, O + PAN_AT)
			game._aim_camera(O + MARKS[0][0] + Vector3(0.0, 1.0, 0.0), 40.0)
			await wait(0.3)
			game.h_take()
			await until(func() -> bool: return game.state == game.S.TAKE, 8.0)
			# 返事を待つのは10秒まで（pair_net_base.gd）なので、前半の二人と後半の二人（roll2）に分ける
			for aid in 2:
				await until(func() -> bool: return bool(beats.roll_done[aid]), 4.5)
				game._aim_camera(O + MARKS[aid + 1][0] + Vector3(0.0, 1.0, 0.0), 40.0)
		"roll2":
			for aid in [2, 3]:
				await until(func() -> bool: return bool(beats.roll_done[aid]), 4.0)
				if aid < 3:
					game._aim_camera(O + MARKS[aid + 1][0] + Vector3(0.0, 1.0, 0.0), 40.0)
			await roll_until_hold(0)
		"action":
			# 場転：カメラを引いて、城の前の社長を撮る所へ → 監督が 1 で回し直す（2カット目）→ 撮れて、止まるまで
			place(game.film, O + CAM_AT)
			game._aim_camera(O + AIM_WIDE, 56.0)
			await wait(1.0)
			game.h_beat(1)
			await wait(0.2)
			await roll_until_hold(1)
		"boom":
			# 監督が 1 で回し直す（3カット目：社長の背後で爆発）→ 撮れて、止まるまで
			await wait(1.5)
			game.h_beat(1)
			await wait(0.2)
			await roll_until_hold(2)
		"close":
			# 場転：看板を出し、カメラを寄せて、ライトを手前へ → 1 で回して、4カット目が撮れてテイクが終わるまで
			place(game.cue_cards.card, O + CARD_AT)
			game._aim_camera(O + AIM_CLOSE + Vector3(0, 0.2, 0), 46.0)
			for i in 2:
				game._aim_spot(game.spots[i], O + Vector3(0.0, 1.0, 1.8))
			await wait(2.5)
			game.h_beat(1)
			await until(func() -> bool: return game.state == game.S.RESULT, 15.0)
		"skip":
			game.h_stop_replay()
			await until(func() -> bool: return flow.phase == 5, 5.0)
	await frames(4)
	return {}


func client_run() -> void:
	var beats: Node = game.beats
	var premiere: Node = game.hooks.feature("premiere")
	var reply: Dictionary = await request("setup")
	check(int(reply["view"]["phase"]) == 4, "the host takes the commercial to the set")
	check(await until(func() -> bool: return game.production.phase == 4, 10.0), "the participant arrives too")
	# ---- 場転：止まると、参加者の画面でも止まって見える ----
	reply = await request("roll")
	check((reply["view"]["roll"] as Array).slice(0, 2) == [true, true] and not bool(reply["view"]["hold"]), "the host films the boss and the first staff in close-up, panning without stopping")
	reply = await request("roll2")
	check(bool(reply["view"]["hold"]) and int(reply["view"]["next"]) == 1, "the first cut is captured and the host's film stops")
	check(not false in (reply["view"]["roll"] as Array) and int(reply["view"]["holds"]) == 0, "the host panned through all four close-ups without stopping")
	await sees(reply["view"], ["hold", "next", "state", "roll"], "the participant's film stops too, with the same four close-ups done")
	check(game.take_held(), "the participant's take is held")
	await wait(0.6)          # 止まる直前の時計（0.2秒ごとの知らせ）が届き終わるのを待つ
	var held_clock: float = game.take_t
	await wait(1.0)
	check(is_equal_approx(float(game.take_t), held_clock), "the participant's film clock stands still during the set change")
	check(str(game.hud.order_state.text).begins_with("場転中"), "the participant's panel says the set is being changed")
	reply = await request("action")
	check(bool(reply["view"]["hold"]) and int(reply["view"]["next"]) == 2 and bool((reply["view"]["lit"] as Array)[1]), "the host rolls again, and the second cut is captured")
	await sees(reply["view"], ["hold", "next", "lit"], "the participant follows the second cut")
	reply = await request("boom")
	check(bool(reply["view"]["hold"]) and int(reply["view"]["next"]) == 3 and bool((reply["view"]["lit"] as Array)[2]), "the host rolls again, and the third cut (the explosion) is captured")
	await sees(reply["view"], ["hold", "next", "lit"], "the participant follows the third cut")
	reply = await request("close")
	check(int(reply["view"]["state"]) == game.S.RESULT and not false in (reply["view"]["lit"] as Array), "the fourth cut (the sign) ends the take with every cut captured")
	check(await until(func() -> bool: return game.state == game.S.RESULT, WAIT), "the participant sees the result")
	# ---- 試写会：参加者が納品を頼む ----
	game.request_deliver(game.selected)
	check(await until(func() -> bool: return premiere.screening == 0 and premiere._layer.visible, WAIT), "the participant's delivery request starts the screening on the participant's screen")
	# 会社の紹介動画の題は「{会社} 紹介動画」（2026-10-24 から、会社の名前は看板の絵。premiere.gd の _film_name）。
	# 看板の絵があれば絵入りの字（CompanyLogo の TWIN）で、無ければ「名無しの会社」の字で出る
	var card_text: String = premiere._card_big.text
	var twin: Node = premiere._card_big.get_node_or_null(CompanyLogo.TWIN)
	var named: bool = (twin != null and twin.visible) if CompanyLogo.has_logo() else card_text.contains(CompanyLogo.NAMELESS)
	check(premiere._card_box.visible and card_text.contains("紹介動画") and named, "the participant sees the title card (%s)" % card_text)
	check(await until(func() -> bool: return premiere._chapter.text.begins_with("第") and premiere._chapter.modulate.a > 0.1, 10.0), "the participant sees a scene heading during the screening (%s)" % premiere._chapter.text)
	reply = await request("skip")
	check(int(reply["view"]["phase"]) == 5 and int(reply["view"]["payment"]) > 0, "skipping delivers the take on the host")
	check(await until(func() -> bool: return premiere._card_big.text == "終" or premiere._sheet.visible, WAIT), "the participant sees the end card")
	check(await until(func() -> bool: return premiere._sheet.visible and not premiere.tally.is_empty(), 10.0), "then the client's readout")
	premiere.finish_tally()
	check(premiere._total.text.contains("+%d" % int(reply["view"]["payment"])), "the readout ends on the same fee as the host (%s)" % premiere._total.text)

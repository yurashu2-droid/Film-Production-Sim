extends Node
## 1日目（会社の紹介動画。production_flow.gd の JOBS の "debut"）の段取り。docs/production/tutorial-cm.md
##   ・廃材置き場の門は開けない（production_flow.gd の _process）。1日目は、廃材置き場へ行かずに撮る
##   ・依頼を受けると、紹介動画に使いそうな物を、事務所の前（撮影の舞台の手前の左。カメラを置く所のそば）に雑に置いておく：
##     城に見立てる書割・爆炎の書割・等身大パネル・看板にする段ボール板2枚とスプレー缶と接着剤・カメラの台にする段ボール箱2つ
##     （段ボール箱は、ふたを閉じて出す。2つ積むと 1.5m で、三脚とほぼ同じ高さ。箱馬は、1日目には出さない）
##     その日、廃材置き場にしまってある物でも出す（日替わりの廃材から外す）
##   ・ふつうに遊ぶ 1 日目は、その日に使わない会社の備品（滑車・押しボタン・点火トーチ・時計・ハーネス・背景の缶・
##     夜用フィルター・スロー光線・吊りクレーン・台車類・ロープとはさみ・清掃カート）をしまっておく。デバッグ用の物が並んで見えて、
##     始まりの邪魔だった（2026-11-11 ユーザー）。2 日目の朝（production_flow.gd の restock）で、元の場所に戻る。
##     確認では、tidy_force を立てたときだけしまう（ほかの確認は、備品がある前提で書いてある）
## 決めるのはホスト。置き場所は、ほかの物と同じに全員へ配られる
const PILE := [
	["flat", Vector3(65.9, 0.05, 16.8), 0.4],
	["boomflat", Vector3(67.2, 0.05, 18.0), -0.3],
	["standin", Vector3(68.3, 0.05, 16.9), 0.8],
	["cardboard", Vector3(67.0, 0.05, 15.6), -0.4],
	["cardboard", Vector3(68.4, 0.08, 15.4), 0.3],
	["spray_paint", Vector3(66.6, 0.05, 16.5), 0.0],
	["glue", Vector3(66.9, 0.05, 16.8), 0.6],
	["carton", Vector3(65.3, 0.05, 18.1), 0.2],
	["carton", Vector3(66.5, 0.05, 18.9), -0.5],
]

# 1 日目にしまう、会社の備品の種類
const SPARE := ["lift_cart", "dolly", "pulley", "buzzer", "igniter", "timer", "harness", "rope", "scissors",
	"bgcan_castle", "bgcan_space", "bgcan_sea", "nightgel", "slowray", "crane", "cleaning_cart"]

var game: Node
var tidy_force := false              # 自動確認でも、備品をしまう


func hook_new_job() -> void:
	var flow: Node = game.production
	if not Net.is_host() or flow == null or not bool(flow.job().get("debut", false)):
		return
	var hidden: Array = (flow.stash as Array).duplicate()
	var placed: Array = []
	var used := {}
	for row: Array in PILE:
		var p: RigidBody3D = _pick(str(row[0]), used)
		if p == null:
			continue
		used[p.pid] = true
		hidden.erase(p.pid)
		placed.append([p, row[1], float(row[2])])
	if bool(flow.daily) or tidy_force:
		for p: RigidBody3D in game.props.values():
			if str(p.kind) in SPARE and not p.absent and p.holder == 0 and p.rider_of == 0 and not hidden.has(p.pid):
				hidden.append(p.pid)
	game.host_ev("stash", [hidden])
	for item: Array in placed:
		var turn := Quaternion(Vector3.UP, float(item[2]))
		if (item[0] as Node).kind == "cardboard":
			turn = turn * Quaternion(Vector3.RIGHT, -PI * 0.5)      # 段ボール板は、表を上にして寝かせる
		(item[0] as RigidBody3D).restore([item[1], turn, false])
		if (item[0] as Node).kind == "carton":
			# 台にする箱：置き場の奥から出して、ふたを閉じておく（開いたままだと、上にカメラが載らない）
			(item[0] as RigidBody3D).set_fixed(false)
			game.host_ev("carton", [(item[0] as Node).pid, false])


# その種類の物を1つ（出ている物か、今日しまってある物。人が持っている物・荷台の物は使わない）
func _pick(kind: String, used: Dictionary) -> RigidBody3D:
	var flow: Node = game.production
	var sign: Node = game.hooks.feature("company_sign")
	for p: RigidBody3D in game.props.values():
		if p.kind != kind or used.has(p.pid) or p.holder != 0 or p.rider_of != 0:
			continue
		if sign != null and sign.in_use(p):
			continue          # 事務所の前に掛けてある看板の板
		if p.absent and not (p.pid in flow.stash):
			continue          # 借りていない物・しまい込んである物
		return p
	return null

extends Node
## 1日目（会社の紹介動画。production_flow.gd の JOBS の "debut"）の段取り。docs/production/tutorial-cm.md
##   ・廃材置き場の門は開けない（production_flow.gd の _process）。1日目は、廃材置き場へ行かずに撮る
##   ・依頼を受けると、紹介動画に使いそうな物を、事務所の前（撮影の舞台の手前の左。カメラを置く所のそば）に雑に置いておく：
##     城に見立てる書割・爆炎の書割・等身大パネル・看板に描くカンペ・カメラを載せる箱馬
##     その日、廃材置き場にしまってある物でも出す（日替わりの廃材から外す）
## 決めるのはホスト。置き場所は、ほかの物と同じに全員へ配られる
const PILE := [
	["flat", Vector3(65.9, 0.05, 16.8), 0.4],
	["boomflat", Vector3(67.2, 0.05, 18.0), -0.3],
	["standin", Vector3(68.3, 0.05, 16.9), 0.8],
	["cue_card", Vector3(67.1, 0.05, 16.4), -0.5],
	["applebox", Vector3(65.6, 0.05, 18.0), 0.2],
	["applebox", Vector3(66.2, 0.05, 18.4), -0.6],
	["applebox", Vector3(65.5, 0.05, 18.8), 1.1],
]

var game: Node


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
	game.host_ev("stash", [hidden])
	for item: Array in placed:
		(item[0] as RigidBody3D).restore([item[1], Quaternion(Vector3.UP, float(item[2])), false])


# その種類の物を1つ（出ている物か、今日しまってある物。人が持っている物・荷台の物は使わない）
func _pick(kind: String, used: Dictionary) -> RigidBody3D:
	var flow: Node = game.production
	for p: RigidBody3D in game.props.values():
		if p.kind != kind or used.has(p.pid) or p.holder != 0 or p.rider_of != 0:
			continue
		if p.absent and not (p.pid in flow.stash):
			continue          # 借りていない物・しまい込んである物
		return p
	return null

extends Node
## 書割の社屋（production_office.gd の _facade）の切り欠き：自分の視点のカメラと自分の体のあいだに書割が挟まって、
## 自分が隠れてしまうときだけ、自分の視点から書割を映さない（事務所には屋根が無く、三人称のカメラが外から入るため）。
## 事務所の中から裏を向けば、ベニヤ板と支えが見える。撮影カメラ・ほかの人の画面には、いつでも映る（CMの背景になる）。
const Office := preload("res://scripts/production_office.gd")
const PLANE_Z := 4.0                       # 書割の面（事務所の正面の壁と同じ）
const SPAN_X := Vector2(64.6, 79.4)        # 書割の左右の端
const SPAN_Y := Vector2(2.3, 8.0)          # 書割の下の端（1階の壁の上）から、てっぺんの飾りまで

var game: Node
var hidden := false           # いま、自分の視点から消しているか（確認用）
var excluded_arm: SpringArm3D
var solid_rid := RID()        # 書割の当たり判定（Solid）。見つけるまでは空


# 自分の照準の線（机の物・小道具を狙う線）から外す書割の当たり判定。
# 書割を自分の視点から消しているとき（事務所の中にいて、三人称のカメラが外にある）だけ返し、
# それ以外（外から社屋を狙うとき）は空の RID を返す
func aim_skip() -> RID:
	return solid_rid if hidden else RID()


func _process(_delta: float) -> void:
	var me: Node3D = game.local_player() if game != null else null
	if me == null or me.get("cam") == null:
		return
	# 書割には体・小道具が当たるが、切り欠き用の三人称カメラは通す。
	# ここで縮めるとカメラが板を越せず、入口で切り欠きが働かなくなる。
	if me.get("arm") != null and me.arm != excluded_arm:
		var facade := game.find_child("OfficeFacade", true, false)
		var solid := facade.get_node_or_null("Solid") as StaticBody3D if facade != null else null
		if solid != null:
			solid_rid = solid.get_rid()
			excluded_arm = me.arm
			excluded_arm.add_excluded_object(solid.get_rid())
	var cam: Camera3D = me.cam
	# 体と、頭の少し上（体のまわりの部屋の様子）のどちらかが隠れるなら、消す
	var hide := blocks(cam.global_position, me.global_position + Vector3(0, 1.0, 0)) or blocks(cam.global_position, me.global_position + Vector3(0, 2.6, 0))
	if hide == hidden:
		return
	hidden = hide
	cam.cull_mask = (cam.cull_mask & ~Office.FACADE_LAYER) if hide else (cam.cull_mask | Office.FACADE_LAYER)


# カメラから体までの線が、書割の板を通るか
static func blocks(from: Vector3, to: Vector3) -> bool:
	if (from.z - PLANE_Z) * (to.z - PLANE_Z) >= 0.0:
		return false          # 同じ側にいる
	var t := (PLANE_Z - from.z) / (to.z - from.z)
	var hit := from.lerp(to, t)
	return hit.x >= SPAN_X.x and hit.x <= SPAN_X.y and hit.y >= SPAN_Y.x and hit.y <= SPAN_Y.y

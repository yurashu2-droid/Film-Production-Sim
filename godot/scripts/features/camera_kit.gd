extends Node
## カメラの形：会社の「カメラ」のアップグレード（production_flow.gd の TRACKS の "camera"）。
##   0＝三脚なし（カメラ本体だけ。段ボールなどを積んで、その上に載せて撮る）/ 1＝三脚
##   買うと、次の場面から、撮影カメラ（どの台も）が三脚に載る。
## 自動確認の中（flow.daily が false）は、三脚あり（今までの確認が、三脚に載ったカメラを前提にしているため。役者が無料で付くのと同じ）。
## 会社の段階は全員の画面に配られる（production_flow.gd の snapshot）。届いたら、それぞれの画面でカメラの形をそろえる
var game: Node


func setup() -> void:
	apply()


func hook_production_applied() -> void:
	apply()


# 会社の段階に合わせて、撮影カメラを三脚に載せる・外す（全員の画面）
func apply() -> void:
	var flow: Node = game.production
	if flow == null:
		return
	var on := has_tripod()
	for p: Node in game.props.values():
		if p.kind == "camera" and p.has_method("set_tripod"):
			p.set_tripod(on)


func has_tripod() -> bool:
	var flow: Node = game.production
	return flow != null and (int(flow.levels.get("camera", 0)) >= 1 or not bool(flow.daily))

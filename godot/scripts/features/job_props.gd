extends Node
## 依頼主が用意する物（production_flow.gd の JOBS の "props"）：依頼を受けたとき、その日の廃材置き場にしまってあれば、出しておく。
## 名場面のパロディで、無いと撮れない物（送風機・バスの正面など）だけに使う。何に使うか・どう置くかは、制作班が決める。
var game: Node


func hook_new_job() -> void:
	if not Net.is_host() or game.production == null:
		return
	var flow: Node = game.production
	var need: Array = flow.job().get("props", [])
	if need.is_empty():
		return
	var hidden: Array = (flow.stash as Array).duplicate()
	var names: Array = []
	var done := {}
	for pid: int in flow.stash:
		var p: Node = game.props.get(pid)
		if p == null or not (p.kind in need) or done.has(p.kind):
			continue
		hidden.erase(pid)
		done[p.kind] = true
		names.append(str(p.label))
	if names.is_empty():
		return
	game.host_ev("stash", [hidden])
	game.host_ev("toast", ["依頼主の頼みで、%s を廃材置き場に出しておいた" % "・".join(PackedStringArray(names)), 0])

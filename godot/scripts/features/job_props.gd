extends Node
## 依頼主が用意する物（production_flow.gd の JOBS の "props"）：依頼を受けたとき、その日の廃材置き場にしまってあれば、出しておく。
## 名場面のパロディで、無いと撮れない物（送風機・バスの正面など）だけに使う。何に使うか・どう置くかは、制作班が決める。
## ゴミ袋・包みの中にしまってある物（production_scrap.gd の "bag"）も、ここから出せる（廃材置き場の空いている所に置く）。
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
	var out: Array = (flow.stash as Array).filter(func(pid: int) -> bool: return pid not in hidden)
	game.host_ev("stash", [hidden])
	# しまってあった物は、地面の下の待機場所にいる。日替わりの廃材は、その置き場所へ戻す。
	# ゴミ袋・包みの中の物は、廃材置き場の空いている所へ置く（features/junk_bags.gd）
	var junk: Node = game.hooks.feature("junk_bags")
	for pid: int in out:
		var p: Node = game.props.get(pid)
		if p == null:
			continue
		if flow.in_bag(p.kind) and junk != null:
			junk.deliver(p)
		elif flow._home_layout.has(pid):
			p.restore(flow._home_layout[pid])
	game.host_ev("toast", ["依頼主の頼みで、%s を廃材置き場に出しておいた" % "・".join(PackedStringArray(names)), 0])

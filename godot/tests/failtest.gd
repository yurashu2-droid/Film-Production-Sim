extends Node
# 失敗側の確認：告白の前に爆発 → 未達の理由 → 撮り直しで置き場所が戻る。
#   godot --headless --path godot -- --failtest

var game: Node


func _ready() -> void:
	_run.call_deferred()


func _wait(sec: float) -> void:
	await get_tree().create_timer(sec).timeout


func _run() -> void:
	var S: Dictionary = game.S
	await _wait(0.5)
	game.h_sample()
	await _wait(1.5)
	var flat: Node3D
	for p in game.props.values():
		if p.kind == "plywood":
			flat = p
			break
	var before: Vector3 = flat.global_position
	game.h_take()
	await _wait(3.6)
	game.h_cue(2)
	await _wait(2.5)
	var blown: float = flat.global_position.distance_to(before)
	game.h_take()      # カット
	await _wait(0.3)
	var res: Array = game.takes[0]["results"]
	for r: Dictionary in res:
		print("  ", "OK " if r["ok"] else "NG ", r["title"], " / ", r["detail"])
	var ok: bool = game.state == S.RESULT and not res[0]["ok"] and not res[1]["ok"] and "順序" in res[1]["detail"]
	print("blown=%.2f" % blown)
	ok = ok and blown > 0.3
	game.h_retake()
	await _wait(0.5)
	var back: float = flat.global_position.distance_to(before)
	print("retake state=", game.state, " takes=", game.takes.size(), " back=%.2f" % back, " actorA_y=%.2f" % game.actors[0].global_position.y)
	ok = ok and game.state == S.PREP and back < 0.1 and game.actors[0].global_position.y > 0.7
	# 何も映さず2回撮って、テイクを使い切る
	for i in 2:
		game.h_take()
		await _wait(3.6)
		game.h_take()
		await _wait(0.3)
		game.h_retake()
		await _wait(0.3)
	print("takes=", game.takes.size(), " state=", game.state, " detail=", game.takes[2]["results"][0]["detail"])
	ok = ok and game.takes.size() == 3 and game.state == S.RESULT
	game.h_deliver(2)
	await _wait(0.3)
	ok = ok and game.state == S.DELIVERED and not game.delivered_ok
	game.h_next()
	await _wait(0.3)
	ok = ok and game.state == S.PREP and game.takes.is_empty()
	print("FAILTEST_OK" if ok else "FAILTEST_FAIL")
	get_tree().quit(0 if ok else 1)

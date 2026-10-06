extends Node
# 2つ同時起動して、ホスト方式の同期を確かめる。
#   ホスト:   godot --headless --path godot -- --host --nettest
#   参加者:   godot --headless --path godot -- --join=127.0.0.1 --nettest
# 参加者側が「持つ → 見本 → 本番 → 合図」を出し、両方の画面で同じ結果になるかを見る。

var game: Node


func _ready() -> void:
	_run.call_deferred()


func _wait(sec: float) -> void:
	await get_tree().create_timer(sec).timeout


func _run() -> void:
	var who := "HOST" if Net.mode == "host" else "CLIENT"
	var S: Dictionary = game.S
	var t := 0.0
	while game.players.size() < 2 and t < 20.0:
		await _wait(0.2)
		t += 0.2
	print(who, " players=", game.players.size(), " my_id=", Net.my_id())
	if game.players.size() < 2:
		print(who, " NETTEST_FAIL no peer")
		get_tree().quit(1)
		return
	if Net.mode == "host":
		while game.state != S.RESULT and t < 70.0:
			await _wait(0.5)
			t += 0.5
		_report(who)
		await _wait(2.0)
		get_tree().quit(0)
		return

	var me: Node = game.local_player()
	var fx: Node3D = game.fx
	await _wait(0.5)
	var p0: Vector3 = fx.global_position
	me.aim_yaw = -1.0
	game.act_grab(fx.pid)
	await _wait(1.5)
	var moved: float = fx.global_position.distance_to(p0)
	print(who, " grab held=", me.held == fx.pid, " prop moved on my screen=%.2f" % moved)
	var ok: bool = me.held == fx.pid and moved > 0.5
	game.act_release()
	await _wait(0.5)
	ok = ok and me.held == 0
	game.h_sample.rpc_id(1)
	await _wait(2.0)
	var balcony: Node3D
	for p in game.props.values():
		if p.kind == "balcony":
			balcony = p
	print(who, " sample balcony=", balcony.global_position, " actorA=", game.actors[0].global_position, " hints=", game.live["hints"])
	ok = ok and balcony.global_position.distance_to(Vector3(0, 0, -3)) < 0.2 and game.actors[0].global_position.y > 0.7
	game.h_take.rpc_id(1)
	await _wait(4.0)
	ok = ok and game.state == S.TAKE
	game.h_cue.rpc_id(1, 1)
	await _wait(4.5)
	game.h_cue.rpc_id(1, 2)
	await _wait(2.5)
	game.h_cue.rpc_id(1, 3)
	t = 0.0
	while game.state != S.RESULT and t < 30.0:
		await _wait(0.5)
		t += 0.5
	_report(who)
	ok = ok and game.state == S.RESULT and not game.takes.is_empty() and not false in game.takes[0]["passed"]
	print(who, " NETTEST_OK" if ok else " NETTEST_FAIL")
	get_tree().quit(0 if ok else 1)


func _report(who: String) -> void:
	print(who, " state=", game.state, " takes=", game.takes.size())
	if not game.takes.is_empty():
		for r: Dictionary in game.takes[0]["results"]:
			print(who, "   ", "OK " if r["ok"] else "NG ", r["title"], " / ", r["detail"])
	for a in game.actors:
		print(who, "   ", a.label, " pos=", a.global_position)

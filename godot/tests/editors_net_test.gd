extends "res://tests/cuts_net_test.gd"
# 編集の台本（features/editors.gd の名匠・ド派手）の二人通信：
#   ホストが紹介動画を 1 テイク撮り、ド派手の編集者に頼む。参加者が納品を頼むと、参加者の画面にも同じ台本が届き、
#   台本の時計（出来上がりの秒）がホストとそろって進み、字と色が重なる。試写会が終わると、編集は外れる
#   godot --headless --path godot res://tests/editors_net_test.tscn -- --editors-net-test-host   （参加者は -client）


func configure() -> void:
	prefix = "EDIT_NET"
	port = 24897
	flag = "editors-net-test"
	budget = 170.0


func view() -> Dictionary:
	var out := super.view()
	var editors: Node = game.hooks.feature("editors")
	out["out_t"] = float(editors.out_t)
	out["reel"] = (editors.edit.get("reel", []) as Array).size()
	out["pick"] = str(editors.pick)
	return out


func host_action(action: String, arg: Variant, who: int) -> Dictionary:
	if action == "pick":
		game.hooks.feature("editors").host_pick(str(arg))
		await frames(4)
		return {}
	if action == "watch":
		await wait(float(arg))
		return {}
	return await super.host_action(action, arg, who)


func client_run() -> void:
	var premiere: Node = game.hooks.feature("premiere")
	var editors: Node = game.hooks.feature("editors")
	var reply: Dictionary = await request("setup")
	check(int(reply["view"]["phase"]) == 4, "the host takes the commercial to the set")
	for step: String in ["roll", "roll2", "action", "boom", "close"]:
		reply = await request(step)
	check(int(reply["view"]["state"]) == game.S.RESULT, "the host shoots one take of the company video")
	check(await until(func() -> bool: return game.state == game.S.RESULT, WAIT), "the participant sees the result")
	reply = await request("pick", "hype")
	check(str(reply["view"]["pick"]) == "hype" and await until(func() -> bool: return str(editors.pick) == "hype", WAIT), "the host hires the flashy editor, and the participant knows")
	game.request_deliver(game.selected)
	check(await until(func() -> bool: return premiere.screening == 0 and game.state == game.S.REPLAY, WAIT), "the participant's delivery request starts the screening")
	check(await until(func() -> bool: return (editors.edit.get("reel", []) as Array).size() > 20 and editors._over != null and editors._over.visible, WAIT), "the edit script reaches the participant (%d rows) and dresses the screen" % (editors.edit.get("reel", []) as Array).size())
	reply = await request("watch", 5.0)
	var host_out := float(reply["view"]["out_t"])
	check(int(reply["view"]["reel"]) == (editors.edit["reel"] as Array).size(), "both screens hold the same edit script")
	check(host_out > 4.0 and absf(float(editors.out_t) - host_out) < 0.5, "the edit clock runs together (host %.2f, participant %.2f)" % [host_out, float(editors.out_t)])
	check(await until(func() -> bool: return not (editors._type.items as Array).is_empty() or not (editors._type_diff.items as Array).is_empty() or editors._type_mask.visible, 4.0), "the participant's screen shows the editor's type (at %.1f s)" % float(editors.out_t))
	reply = await request("watch", 4.0)
	check(absf(float(editors.out_t) - float(reply["view"]["out_t"])) < 0.5 and float(editors.out_t) > 8.0, "and stays together (host %.2f, participant %.2f)" % [float(reply["view"]["out_t"]), float(editors.out_t)])
	reply = await request("skip")
	check(int(reply["view"]["phase"]) == 5 and int(reply["view"]["payment"]) != 0, "skipping delivers the take on the host")
	check(await until(func() -> bool: return editors.edit.is_empty() and (editors._over == null or not editors._over.visible), WAIT), "after the screening, the edit comes off the participant's screen")

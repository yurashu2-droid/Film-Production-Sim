extends SceneTree
# 小物の手持ち（prop.gd の hand_held・main.gd の hold_target）：
#   ・小物（いちばん長い辺が35cm以下で、2.5kg以下）を持って G を押すと、視点から見て右下・少し前に、立てたまま持つ
#   ・視点を動かしても、画面の中の同じ所（右下）に付いてくる
#   ・ホイール・右ドラッグ（回す）・N（力を抜く）で動かした途端に、その場の位置から、いつもの持ち方へ戻る（跳ばない）
#   ・大きな物の G は、今までどおり（起こして手元へ）
#   godot --headless --path godot --fixed-fps 60 --script res://tests/hand_hold_test.gd
var game: Node
var failed := false


func _initialize() -> void:
	create_timer(90).timeout.connect(func(): quit(2))
	run.call_deferred()


func check(ok: bool, label: String) -> void:
	print("HAND_CHECK ", label, " ", "OK" if ok else "FAIL")
	failed = failed or not ok


func frames(count: int) -> void:
	for i in count:
		await physics_frame


# 頭（視点）から見た、物の中心の場所
func seen_at(me: Node, prop: Node3D) -> Vector3:
	var anchor: Transform3D = game.hand_anchor(me)
	return anchor.affine_inverse() * (prop.global_transform * prop.center)


func run() -> void:
	game = load("res://production_game.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	while not game.startup_complete:
		await process_frame
	await frames(20)
	var me: Node3D = game.local_player()
	var spot := Vector3(66.0, 0.1, 12.0)
	me.global_position = spot
	me.aim_yaw = 0.0
	me.aim_pitch = -0.2
	var can: RigidBody3D = game.hooks.feature("spray_sign").cans[0]
	check(can.small_item(), "スプレー缶は小物")
	can.restore([spot + Vector3(0.3, -0.05, -0.6), Quaternion.IDENTITY, false])
	await frames(10)
	game.h_grab(can.pid)
	await frames(10)
	check(can.holder == me.peer_id and not can.hand_held, "つかんだだけでは、手持ちにならない")
	game.h_hold_command("pull")
	await frames(40)
	var local := seen_at(me, can)
	check(can.hand_held and local.x > 0.1 and local.y < -0.15 and local.z < -0.3, "G で手持ち：視点から見て右下・前にある（%s）" % str(local))
	check(absf(can.global_basis.y.dot(Vector3.UP)) > 0.95, "手持ちの缶は、立っている")
	me.aim_yaw = 0.8
	me.aim_pitch = 0.1
	await frames(40)
	var turned := seen_at(me, can)
	check(turned.distance_to(local) < 0.08, "視点を動かしても、画面の右下に付いてくる（%s）" % str(turned))
	# ホイール（奥行き）を動かすと、いつもの持ち方へ戻る。その場から跳ばない
	var before: Vector3 = can.global_position
	me.hold_dist = 1.8
	await frames(2)
	check(not can.hand_held and can.hold_reference_valid, "ホイールで動かした途端に、いつもの持ち方へ戻る")
	check(can.global_position.distance_to(before) < 0.3, "戻るときに、その場から跳ばない（%.2fm）" % can.global_position.distance_to(before))
	# もう一度 G → 右ドラッグ（回す）で戻る
	game.h_hold_command("pull")
	await frames(20)
	check(can.hand_held, "もう一度 G で、また手持ち")
	me.hold_yaw = 0.4
	await frames(2)
	check(not can.hand_held, "右ドラッグで回すと、いつもの持ち方へ戻る")
	game.h_hold_command("pull")
	await frames(20)
	me.hold_turning = false          # N：力を抜いた
	await frames(2)
	check(not can.hand_held, "N で力を抜くと、いつもの持ち方へ戻る")
	me.hold_turning = true
	# 放すと、手持ちは解ける
	game.h_hold_command("pull")
	await frames(10)
	game.host_release(can)
	await frames(3)
	check(not can.hand_held and can.holder == 0, "放すと、手持ちは解ける")
	# 元から手に小道具を持っているキャラ（01：バラ）は、物を持っている間だけ、その小道具が外れる
	me.set_cast("01")
	await frames(5)
	var skel: Skeleton3D = me.vis.skel
	var bone := skel.find_bone("PROP")
	check(bone >= 0 and not me.vis._hand_props.hidden, "手ぶらのときは、元から持っている小道具（バラ）が見えている")
	can.restore([me.global_position + Vector3(0.3, -0.05, -0.6), Quaternion.IDENTITY, false])
	await frames(5)
	game.h_grab(can.pid)
	await frames(5)
	check(can.holder == me.peer_id and me.vis._hand_props.hidden, "物を持っている間は、元から持っている小道具が外れる")
	game.host_release(can)
	await frames(5)
	check(not me.vis._hand_props.hidden, "放すと、元から持っている小道具が戻る")
	# 手持ちかどうかは、持ち方の知らせ（hold_adjust）に載って全員の画面へ届く
	game.h_grab(can.pid)
	await frames(3)
	game.h_hold_command("pull")
	await frames(3)
	var snap: Dictionary = game._hold_snapshot(me, can)
	check(bool(snap.get("hand", false)), "手持ちかどうかが、持ち方の知らせに載る")
	game.host_release(can)
	await frames(3)
	# 大きな物の G は、今までどおり
	var big: RigidBody3D = null
	for p: Node in game.props.values():
		if not p.absent and not p.small_item() and not p.immovable and not p.fixed and not p.rolls and p.kind in ["flat", "boomflat", "standin"]:
			big = p
			break
	if big != null:
		big.restore([spot + Vector3(0, 0, -1.2), Quaternion.IDENTITY, false])
		await frames(10)
		game.h_grab(big.pid)
		await frames(5)
		game.h_hold_command("pull")
		await frames(5)
		check(not big.hand_held, "大きな物（%s）の G は、今までどおり（手持ちにならない）" % big.label)
		game.host_release(big)
	print("HAND_TEST_FAIL" if failed else "HAND_TEST_OK")
	await frames(2)
	quit(1 if failed else 0)

extends SceneTree
# グリーンバックの合成（scripts/features/backdrop.gd）：背景フィルム缶を持って撮影カメラを見て F で入れると、
# そのカメラにだけ合成の板が付き、缶の背景が渡る。別の缶で入れ替え、同じ缶でもう一度 F で外す。
# 本番の記録に残り、撮ったあとで外しても、見返しでは撮った時の背景で映る。
#   godot --headless --path godot --fixed-fps 60 --script res://tests/backdrop_test.gd
var game: Node
var failed := false


func _initialize() -> void:
	create_timer(90).timeout.connect(func(): quit(2))
	run.call_deferred()


func check(ok: bool, label: String) -> void:
	print("BACKDROP_CHECK ", label, " ", "OK" if ok else "FAIL")
	failed = failed or not ok


func frames(count: int) -> void:
	for i in count:
		await physics_frame


func can(bd: Node, theme: String) -> RigidBody3D:
	for c: RigidBody3D in bd.cans:
		if c.kind == "bgcan_" + theme:
			return c
	return null


func quad_of(cam: Node) -> Node:
	return cam.view_cam.get_node_or_null("BackdropKey")


func run() -> void:
	game = load("res://production_game.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	while not game.startup_complete:
		await process_frame
	await frames(20)
	var bd: Node = game.hooks.feature("backdrop")
	check(bd != null and bd.cans.size() == 3 and can(bd, "castle") != null and can(bd, "space") != null and can(bd, "sea") != null,
		"背景フィルム缶（城・宇宙・海）が、会社の備品にある")
	var flow: Node = game.production
	var me: Node3D = game.local_player()
	game.h_accept_job(int(flow.debut_job()))
	await frames(20)
	me.global_position = flow.HOME_TRUCK + Vector3(-3, 0.1, 0)
	await frames(3)
	game.h_depart()
	await frames(30)
	var film: Node3D = game.film
	me.global_position = film.global_position + Vector3(1.2, 0.1, 0.8)
	var space := can(bd, "space")
	space.restore([me.global_position + Vector3(0.4, 0.1, 0.0), Quaternion.IDENTITY, false])
	await frames(5)
	game.h_grab.rpc_id(1, space.pid)
	await frames(3)
	check(space.holder == me.peer_id, "宇宙の缶を持った")
	me.target = film
	check(str(bd.hook_hud(me, "", "").get("keys_all", "")).contains("入れる"), "カメラを見ると、案内は「入れる」")
	check(game.hooks.first("hook_f", [me]), "F は、背景フィルムの仕組みが受ける")
	await frames(3)
	var q := quad_of(film)
	check(str(bd.backdrop.get(film.pid, "")) == "space" and q != null, "入れたカメラに、合成の板が付く")
	check(q != null and (q.material_override as ShaderMaterial).get_shader_parameter("backdrop") == bd._texture("space"), "板には、宇宙の背景が渡る")
	var others := 0
	for p: Node in game.props.values():
		if p.kind == "camera" and p != film and quad_of(p) != null:
			others += 1
	check(others == 0, "ほかのカメラには、板が付かない")
	# 入れ替え：海の缶に持ち替えて F
	game.h_release.rpc_id(1)
	await frames(3)
	var sea := can(bd, "sea")
	sea.restore([me.global_position + Vector3(0.4, 0.1, 0.0), Quaternion.IDENTITY, false])
	await frames(5)
	game.h_grab.rpc_id(1, sea.pid)
	await frames(3)
	me.target = film
	game.hooks.first("hook_f", [me])
	await frames(3)
	q = quad_of(film)
	check(str(bd.backdrop.get(film.pid, "")) == "sea" and q != null and (q.material_override as ShaderMaterial).get_shader_parameter("backdrop") == bd._texture("sea"),
		"別の缶で F すると、背景が海に入れ替わる")
	# 本番：海のまま撮る → 撮ったあとで外す → 見返しでは海に映り、終わると外した今に戻る
	game.h_take()
	for i in 400:
		if game.state == game.S.TAKE:
			break
		await physics_frame
	check(game.state == game.S.TAKE, "本番が始まる")
	var rec: Array = game._rec_events.filter(func(e: Array) -> bool: return e[1] == "backdrop")
	check(rec.size() >= 1 and str((rec[0][2][0] as Dictionary).get(film.pid, "")) == "sea", "本番の始まりの記録に、どのカメラにどの背景かが残る")
	await frames(40)
	game._cut()
	await frames(5)
	game.host_ev("backdrop", [{}])
	await frames(3)
	check(quad_of(film) == null, "撮ったあとで外すと、板は消える")
	game.h_replay(0)
	for i in 120:
		if quad_of(film) != null:
			break
		await physics_frame
	check(str(bd.backdrop.get(film.pid, "")) == "sea" and quad_of(film) != null, "見返しでは、撮った時の海の背景で映る")
	game.h_stop_replay()
	await frames(5)
	check(not bd.backdrop.has(film.pid) and quad_of(film) == null, "見返しが終わると、外した今に戻る")
	# もう一度入れてから、同じ缶で外す
	sea.restore([me.global_position + Vector3(0.4, 0.1, 0.0), Quaternion.IDENTITY, false])
	await frames(5)
	game.h_grab.rpc_id(1, sea.pid)
	await frames(3)
	me.target = film
	game.hooks.first("hook_f", [me])
	await frames(3)
	check(str(bd.backdrop.get(film.pid, "")) == "sea", "もう一度 F で、海を入れ直す")
	# 同じ缶で F：外れる
	me.target = film
	game.hooks.first("hook_f", [me])
	await frames(3)
	check(not bd.backdrop.has(film.pid) and quad_of(film) == null, "同じ缶でもう一度 F で外すと、板も消える")
	# 緑の見分け方（板の色の式を、CPU で同じに計算して確かめる）
	check(key(Color(0.023, 0.41, 0.028)) > 0.99, "緑の布の色は、抜ける")
	check(key(Color(0.15, 0.25, 0.08)) < 0.01, "草くらいの緑は、抜けない")
	check(key(Color(0.6, 0.5, 0.4)) < 0.01 and key(Color(0.02, 0.02, 0.02)) < 0.01, "肌の色・暗い所は、抜けない")
	print("BACKDROP_TEST_FAIL" if failed else "BACKDROP_TEST_OK")
	await frames(2)
	quit(1 if failed else 0)


func key(c: Color) -> float:
	var ratio := (c.g - maxf(c.r, c.b)) / maxf(c.g, 0.001)
	return smoothstep(0.6, 0.75, ratio) * smoothstep(0.004, 0.02, c.g)

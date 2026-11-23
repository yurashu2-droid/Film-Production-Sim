extends SceneTree
# スロー光線（features/slow_ray.gd）：
#   ・会社の備品として、懐中電灯の形の道具が1つある。持って F で、出す・止める
#   ・光線の中に落ちてきた物は、ゆっくり落ちる。うすい光の玉が付く。光線の外の物は、いつもの速さ
#   ・止めると、元の速さ・元の重さに戻る。誰かが持った物・固定した物には効かない
#   ・光線の中の人は、動いた分が 0.3 倍になり、体の動きもゆっくりになる。持っている人自身には効かない
#   godot --headless --path godot --fixed-fps 60 --script res://tests/slow_ray_test.gd
var game: Node
var failed := false


func _initialize() -> void:
	create_timer(120).timeout.connect(func(): quit(2))
	run.call_deferred()


func check(ok: bool, label: String) -> void:
	print("SLOW_CHECK ", label, " ", "OK" if ok else "FAIL")
	failed = failed or not ok


func frames(count: int) -> void:
	for i in count:
		await physics_frame


func drop(prop: Node, pos: Vector3) -> void:
	if prop.holder != 0:
		game.host_release(prop)
	prop.restore([pos, Quaternion.IDENTITY, false])
	prop.linear_velocity = Vector3.ZERO
	prop.angular_velocity = Vector3.ZERO
	prop.sleeping = false


func run() -> void:
	game = load("res://production_game.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	while not game.startup_complete:
		await process_frame
	await frames(20)
	var f: Node = game.hooks.feature("slow_ray")
	var me: Node3D = game.local_player()
	check(f != null and f.ray != null and str(f.ray.kind) == "slowray" and game.props.has(f.ray.pid), "懐中電灯の形の道具が、会社の備品として1つある")
	check(not f.on and (f.props_in as Array).is_empty() and not f._lens.visible, "はじめは、光線は出ていない")
	var size: Vector3 = f.ray.half * 2.0
	check(maxf(size.x, maxf(size.y, size.z)) > 0.3 and maxf(size.x, maxf(size.y, size.z)) < 0.6, "道具の長さは、手に持てる大きさ（%.2f m）" % maxf(size.x, maxf(size.y, size.z)))
	# ---- 持って F で、出す・止める ----
	me.global_position = f.ray.global_position + Vector3(0.0, 0.1, 1.2)
	me.held = int(f.ray.pid)
	check(f.hook_f(me), "持って F で、光線を出す")
	await frames(5)
	check(f.on and f._lens.visible and str(f.hook_hud(me, "", "").get("keys_all", "")).contains("止める"), "出している間は、頭が光り、案内は「止める」になる")
	me.held = 0
	# ---- 物：光線の中は、ゆっくり落ちる ----
	var boxes: Array = game.props.values().filter(func(p: Node) -> bool: return p.kind == "applebox" and not p.absent)
	var a: RigidBody3D = boxes[0]
	var b: RigidBody3D = boxes[1]
	var base: Vector3 = Vector3(40.0, 0.0, 40.0)             # 何も無い所の空中
	f.beam_override = [base + Vector3(-5.0, 12.0, 0.0), Vector3(1.0, 0.0, 0.0)]      # x の向きへ水平に
	me.global_position = base + Vector3(0.0, 0.1, 20.0)       # 自分は、光線の外
	drop(a, base + Vector3(0.0, 12.0, 0.0))                   # 光線の中
	drop(b, base + Vector3(0.0, 12.0, 6.0))                   # 光線の外
	await frames(45)
	var fell_a: float = 12.0 - a.global_position.y
	var fell_b: float = 12.0 - b.global_position.y
	check(int(a.pid) in f.props_in and int(b.pid) not in f.props_in, "光線の中の物だけが、浴びている")
	check(fell_b > 1.5 and fell_a < fell_b * 0.25, "光線の中の物は、ゆっくり落ちる（中 %.2f m・外 %.2f m）" % [fell_a, fell_b])
	check(a.get_node_or_null("SlowAura") != null and b.get_node_or_null("SlowAura") == null, "浴びている物にだけ、うすい光の玉が付く")
	check(absf(a.gravity_scale - f.SLOW * f.SLOW) < 0.001, "浴びている間は、落ち方もゆっくり")
	# 止めると、元に戻る
	var slow_speed: float = a.linear_velocity.length()
	f.h_switch()
	await frames(3)
	check(not f.on and (f.props_in as Array).is_empty() and a.get_node_or_null("SlowAura") == null, "止めると、誰も浴びていない。光の玉も消える")
	check(absf(a.gravity_scale - 1.0) < 0.001 and a.linear_velocity.length() > slow_speed * 2.0, "止めると、元の重さ・元の速さに戻る（%.2f → %.2f m/秒）" % [slow_speed, a.linear_velocity.length()])
	# 固定した物・誰かが持っている物には効かない
	f.h_switch()
	await frames(3)
	a.restore([base + Vector3(0.0, 12.0, 0.0), Quaternion.IDENTITY, true])
	await frames(10)
	check(int(a.pid) not in f.props_in, "固定した物には、効かない")
	# ---- 人：動いた分が 0.3 倍になる。体の動きもゆっくり ----
	var ground: Vector3 = game.production.HOME_SET + Vector3(0.0, 0.0, 3.0)      # 床のある所（事務所の前）
	f.beam_override = [ground + Vector3(-5.0, 0.9, 0.0), Vector3(1.0, 0.0, 0.0)]
	me.velocity = Vector3.ZERO
	me.global_position = ground + Vector3(0.0, 0.1, 0.0)
	await frames(10)
	check(int(me.peer_id) in f.players_in and me.get_node_or_null("SlowAura") != null, "光線の中の人は、浴びている（光の玉が付く）")
	check(absf(me.vis.anim.speed_scale - f.SLOW) < 0.001, "体の動きも、ゆっくりになる")
	var from: Vector3 = me.global_position
	me.global_position = from + Vector3(0.0, 0.0, 1.0)        # 1コマで 1m 動いたことにする
	f._slow_people()
	var moved: float = me.global_position.distance_to(from)
	check(moved > 0.2 and moved < 0.4, "動いた分は、0.3 倍になる（%.2f m）" % moved)
	# 自分が浴びている間：画面のふちの手がかりが出る。光線の中で鳴る音は低い
	await frames(30)
	check(f._cue.visible and f._cue_k > 0.9, "自分が浴びている間は、自分の画面に手がかりが出る（%.2f）" % f._cue_k)
	check(absf(f._pitch_at(ground + Vector3(0.0, 0.9, 0.0)) - f.SOUND_PITCH) < 0.001 and absf(f._pitch_at(ground + Vector3(0.0, 0.9, 6.0)) - 1.0) < 0.001,
		"光線の中で鳴る音は低く、外で鳴る音はそのまま")
	check((root.get_node("Sfx").pitch_zone as Callable).is_valid(), "音の高さを決める関数が、効果音の仕組みに入っている")
	# スローの中の着地：土ぼこりが、ゆっくり舞う（0.68秒の煙が、2秒たっても残っている）
	var puffs_before: int = f._fx._dusts.size()
	game.host_ev("slow_dust", [ground + Vector3(2.0, 0.0, 0.0), 1.0])
	await frames(120)
	check(f._fx._dusts.size() > puffs_before, "着地の土ぼこりは、2秒たっても舞っている（%d 個）" % (f._fx._dusts.size() - puffs_before))
	await frames(60)
	check(f._fx._dusts.size() == puffs_before, "土ぼこりは、ゆっくり消え切る")
	# 持っている人自身には効かない
	f.ray.holder = int(me.peer_id)
	await frames(5)
	check(int(me.peer_id) not in f.players_in, "持っている人自身には、効かない")
	f.ray.holder = 0
	f.h_switch()
	await frames(5)
	check(not f.on and (f.players_in as Array).is_empty() and absf(me.vis.anim.speed_scale - 1.0) < 0.001, "止めると、人も元に戻る")
	print("SLOW_TEST_FAIL" if failed else "SLOW_TEST_OK")
	root.get_node("Sfx").silence_all()
	await frames(4)
	quit(1 if failed else 0)

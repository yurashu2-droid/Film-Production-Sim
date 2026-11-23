extends SceneTree
# 等身大パネルを台車に載せて、仕掛けで引くと、役者として「歩いて」印に着く（ユーザーの案。features/stand_ins.gd × contraptions.gd）。
#   画面ありで撮る版：godot --path godot --position -32000,-32000 --audio-driver Dummy --fixed-fps 60 --script res://tests/panel_dolly_shot.gd
# 1人で遊ぶとき：自分が役者 A、パネルが役者 B。B の歩きは、台車を引く重り（滑車越し）に任せる。
var game: Node
var failed := false


var eye: Camera3D


func _initialize() -> void:
	root.unfocusable = true
	create_timer(300).timeout.connect(func(): quit(2))
	run.call_deferred()


func snap(tag: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://tests/shots/contraptions/%s.png" % tag)
	print("PANELSHOT ", tag)


func check(ok: bool, label: String) -> void:
	print("PANEL_DOLLY_CHECK ", label, " ", "OK" if ok else "FAIL")
	failed = failed or not ok


func frames(count: int) -> void:
	for i in count:
		await physics_frame


func top_of(p: RigidBody3D) -> Vector3:
	return p.center_global() + Vector3(0, p.half.y * 0.9, 0)


func run() -> void:
	game = load("res://production_game.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	while not game.startup_complete:
		await process_frame
	await frames(20)
	var flow: Node = game.production
	var roles: Node = game.hooks.feature("stand_ins")
	var rig: Node = game.hooks.feature("contraptions")
	var me: Node3D = game.local_player()
	game.h_accept_job(int(flow.debut_job()))
	await frames(20)
	me.global_position = flow.HOME_TRUCK + Vector3(-3, 0.1, 0)
	await frames(3)
	game.h_depart()
	await frames(30)
	var P: Vector3 = me.global_position
	P.y = 0.0
	var lane := P + Vector3(0, 0, 3.5)
	# 台車にパネルを載せて、接着する（一直線でない3点で固く）
	var dolly: RigidBody3D = game.stage.spawn("dolly", lane + Vector3(1.0, 0.05, 0), PI * 0.5)
	var panel: RigidBody3D = null
	for p: Node in game.props.values():
		if p.kind == "standin" and not p.absent:
			panel = p
	check(panel != null, "等身大パネルがある")
	await frames(30)
	panel.restore([dolly.global_position + Vector3(0, dolly.deck_top + 0.02, 0), Quaternion(Vector3.UP, PI * 0.5), false])
	await frames(20)
	var deck_y: float = dolly.global_position.y + dolly.deck_top
	var pairs: Array = []
	for off: Vector3 in [Vector3(0.2, 0, 0.0), Vector3(-0.2, 0, 0.15), Vector3(-0.2, 0, -0.15)]:
		var w: Vector3 = Vector3(panel.global_position.x, deck_y, panel.global_position.z) + off
		pairs.append({"a": panel.pid, "b": dolly.pid, "pa": panel.to_local(w), "pb": dolly.to_local(w), "joined": true})
	game.adhesive.restore({"first": {}, "pairs": pairs})
	await frames(20)
	# パネルを役者 B に（パネルのそばで）
	me.global_position = panel.global_position + Vector3(0, 0.1, -1.4)
	await frames(3)
	roles.h_cast_actor.rpc_id(1, "prop", int(panel.pid), 1)
	await frames(4)
	var b: Node = game.actors[1]
	check(b.stand_in == panel, "パネルが役者 B になった")
	me.global_position = P + Vector3(0, 0.1, -2.0)
	# 引く仕掛け：台車 → 滑車 → 重り。重りは支えのロープで吊っておく
	var pulley: RigidBody3D = null
	for p: RigidBody3D in rig.parts:
		if p.kind == "pulley" and pulley == null:
			pulley = p
	rig.host_mount(pulley, lane + Vector3(5.0, 2.8, 0), Vector3(-1, 0, 0), null)
	await frames(5)
	var wheel: Vector3 = rig._wheel(pulley.pid)
	var bag: RigidBody3D = game.stage.spawn("sandbag", Vector3(wheel.x, 1.75, wheel.z), 0.0)
	await frames(1)
	var hold: int = rig.host_add_row([0, top_of(bag) + Vector3(0, 0.6, 0.5)], [bag.pid, bag.to_local(top_of(bag) + Vector3(0, 0, 0.12))], [])
	var front: Vector3 = dolly.center_global() + Vector3(dolly.half.z + 0.05, 0.0, 0)
	var pull: int = rig.host_add_row([dolly.pid, dolly.to_local(front)], [bag.pid, bag.to_local(top_of(bag))], [pulley.pid])
	rig.rows[pull]["len"] = float(rig.rows[pull]["len"]) + 0.05
	await frames(90)
	# 場面の動き：B は、いまの所から 1.2m 先の印へ歩く
	var start: Vector3 = panel.global_position
	var mark: Vector3 = start + Vector3(1.2, 0, 0)
	b.play_beat({"to": mark, "gait": "walk", "pose": "idle", "look": "", "face_go": "neutral", "face_hold": "neutral"})
	eye = Camera3D.new()
	eye.fov = 50.0
	game.add_child(eye)
	var look: Vector3 = (start + wheel) * 0.5 + Vector3(0, -0.6, 0)
	eye.global_position = look + Vector3(-0.5, 1.0, 6.5)
	eye.look_at(look, Vector3.UP)
	eye.make_current()
	me.global_position = eye.global_position + Vector3(0, 0, 3.0)
	for layer: Node in [game.get("hud"), game.get("production_hud")]:
		if layer is CanvasLayer:
			(layer as CanvasLayer).visible = false
	await frames(3)
	await snap("panel_1_before")
	check(not b.beat_arrived() and not b.beat_walking(), "パネルが止まっている間は、歩いていない・着いていない")
	rig.host_ignite(hold, 0.1)
	var walked := false
	for i in 300:
		await physics_frame
		walked = walked or b.beat_walking()
		if b.beat_arrived():
			break
	await frames(20)
	await snap("panel_2_after")
	var moved: float = Vector2(panel.global_position.x - start.x, panel.global_position.z - start.z).length()
	check(walked, "重りが落ちて台車が走ると、パネル（役者 B）は「歩いている」")
	check(b.beat_arrived(), "印のそばまで運ばれると、役者 B は「着いた」（%.2f m 動いた）" % moved)
	check(panel.global_basis.y.y > 0.8, "パネルは、台車の上で立ったまま")
	print("PANELSHOT_FAIL" if failed else "PANELSHOT_OK")
	await frames(2)
	quit(1 if failed else 0)

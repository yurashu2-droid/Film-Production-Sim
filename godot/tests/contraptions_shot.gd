extends SceneTree
# 仕掛けの連鎖を撮る（scripts/features/contraptions.gd）：
#   ロープに火 → 焼き切れて重りがボタンに落ちる → チンでトーチから炎 → 炎で支えのロープが焼き切れる →
#   重りが落ちて、滑車を通したロープが、カメラを載せた台車を引く（自動の移動撮影）。
#   godot --path godot --position -32000,-32000 --audio-driver Dummy --fixed-fps 60 --script res://tests/contraptions_shot.gd
const OUT := "res://tests/shots/contraptions/"
var game: Node
var rig: Node
var eye: Camera3D
var failed := false


func _initialize() -> void:
	root.unfocusable = true
	create_timer(240).timeout.connect(func(): quit(2))
	run.call_deferred()


func frames(count: int) -> void:
	for i in count:
		await physics_frame


func snap(name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT + name + ".png")
	print("RIGSHOT ", name)


func top_of(p: RigidBody3D) -> Vector3:
	return p.center_global() + Vector3(0, p.half.y * 0.9, 0)


func part(kind: String, n: int = 0) -> RigidBody3D:
	for p: RigidBody3D in rig.parts:
		if p.kind == kind:
			if n == 0:
				return p
			n -= 1
	return null


func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	game = load("res://production_game.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	while not game.startup_complete:
		await process_frame
	await frames(20)
	var flow: Node = game.production
	rig = game.hooks.feature("contraptions")
	var me: Node3D = game.local_player()
	game.h_accept_job(int(flow.debut_job()))
	await frames(20)
	me.global_position = flow.HOME_TRUCK + Vector3(-3, 0.1, 0)
	await frames(3)
	game.h_depart()
	await frames(40)
	var P: Vector3 = me.global_position
	P.y = 0.0
	# 近くの壁を探す（ここに滑車を留め、ロープを結ぶ）
	var space: PhysicsDirectSpaceState3D = (game as Node3D).get_world_3d().direct_space_state
	var wall := {}
	var dir := Vector3.ZERO
	for d: Vector3 in [Vector3.RIGHT, Vector3.LEFT, Vector3.FORWARD, Vector3.BACK]:
		var q := PhysicsRayQueryParameters3D.create(P + Vector3(0, 2.3, 0), P + Vector3(0, 2.3, 0) + d * 25.0, 1)
		var hit: Dictionary = space.intersect_ray(q)
		print("RIGSHOT probe ", d, " ", hit.get("position"), " ", hit.get("collider"))
		if not hit.is_empty() and P.distance_to(hit["position"]) > 5.0 and (wall.is_empty() or P.distance_to(hit["position"]) < P.distance_to(wall["position"])):
			wall = hit
			dir = d
	print("RIGSHOT wall ", wall.get("position"), " dir ", dir)
	if wall.is_empty():
		quit(1)
		return
	var side := dir.cross(Vector3.UP)
	var W: Vector3 = wall["position"]
	var n: Vector3 = wall["normal"]
	# 台車（カメラを載せる）
	var dolly: RigidBody3D = game.stage.spawn("dolly", Vector3(W.x, 0.05, W.z) - dir * 4.6, atan2(dir.x, dir.z))
	await frames(30)
	var film: RigidBody3D = game.film
	film.restore([dolly.global_position + Vector3(0, dolly.deck_top + 0.02, 0) + dir * 0.1, Quaternion(Vector3.UP, atan2(-side.x, -side.z)), false])
	await frames(20)
	# 滑車を壁に留める
	var pulley := part("pulley")
	rig.host_mount(pulley, W, n, null)
	await frames(5)
	var wheel: Vector3 = rig._wheel(pulley.pid)
	# 重り2：滑車1の下にぶら下がる。台車 → 滑車1 → 重り2 のロープと、
	# 重り2 → 滑車2 → 壁の下の方 の支えのロープ（下の方の横に、点火トーチ）
	var bag2: RigidBody3D = game.stage.spawn("sandbag", Vector3(wheel.x, 1.75, wheel.z) - dir * 0.15, 0.0)
	var pulley2 := part("pulley", 1)
	rig.host_mount(pulley2, W + side * 0.9, n, null)
	await frames(1)
	var low_at: Vector3 = W + side * 2.0 - Vector3(0, W.y - 0.45, 0)
	var hold_id: int = rig.host_add_row([bag2.pid, bag2.to_local(top_of(bag2) + side * 0.1)], [0, low_at], [pulley2.pid])
	var front: Vector3 = dolly.global_position + dir * 0.55 + Vector3(0, 0.3, 0)
	rig.host_add_row([dolly.pid, dolly.to_local(front)], [bag2.pid, bag2.to_local(top_of(bag2))], [pulley.pid])
	var torch := part("igniter")
	await frames(60)
	torch.restore([Vector3(low_at.x, 0.05, low_at.z) - dir * 0.28 + side * 0.05, Quaternion.IDENTITY, false])
	await frames(10)
	# 重り1：ボタンの上で、ロープでぶら下がる（このロープに火を付けると、連鎖が始まる）
	var bell := part("buzzer")
	var drop_at: Vector3 = Vector3(W.x, 0.05, W.z) + side * 3.1 - dir * 0.3
	bell.restore([drop_at, Quaternion.IDENTITY, false])
	await frames(20)
	var bag1: RigidBody3D = game.stage.spawn("sandbag", drop_at + Vector3(0, 0.9, 0), 0.0)
	await frames(1)
	var start_id: int = rig.host_add_row([0, top_of(bag1) + Vector3(0, 0.7, 0)], [bag1.pid, bag1.to_local(top_of(bag1))], [])
	rig.wires[bell.pid] = [torch.pid]
	rig._changed()
	await frames(90)
	# 撮る位置：横から、少し高く
	eye = Camera3D.new()
	eye.fov = 55.0
	game.add_child(eye)
	var look: Vector3 = (W + dolly.global_position) * 0.5 + side * 1.5 + Vector3(0, -0.5, 0)
	eye.global_position = look + side * 3.2 + Vector3(0, 1.9, 0) - dir * 5.2
	eye.look_at(look, Vector3.UP)
	eye.make_current()
	me.global_position = eye.global_position + side * 3.0
	for layer: Node in [game.get("hud"), game.get("production_hud")]:
		if layer is CanvasLayer:
			(layer as CanvasLayer).visible = false
	await frames(10)
	await snap("01_ready")
	var x0: Vector3 = dolly.global_position
	rig.host_ignite(start_id, float(rig.rows[start_id]["len"]) * 0.4)
	await frames(30)
	await snap("02_lit")
	var shot_flame := false
	var shot_move := false
	for i in 420:
		await physics_frame
		if not shot_flame and rig.flames.has(torch.pid) and i % 2 == 0:
			await frames(18)
			await snap("03_bell_flame")
			shot_flame = true
		if not shot_move and bool(rig.rows[hold_id]["cut"]):
			await frames(16)
			await snap("04_pull")
			shot_move = true
	await frames(30)
	await snap("05_after")
	print("RIGSHOT bell at ", bell.global_position, " bag1 at ", bag1.global_position, " rows ", rig.rows.size())
	print("RIGSHOT dolly moved %.2f m" % (dolly.global_position - x0).dot(dir))
	quit(0)

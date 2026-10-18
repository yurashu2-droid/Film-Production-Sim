extends SceneTree
## 紹介動画（映画のティザー風）の撮影。1回の起動で1カットを、1コマずつ JPG に書き出す（tools/trailer/README.md）。
##   godot --path godot --fixed-fps 30 --resolution 1920x1080 --script res://trailer/trailer_shots.gd -- --shot=<名前> --out=<書き出し先>
## 人の操作は録らない。場面を台本どおりに組んで、カメラの動きも決めて撮る（何度でも同じ画が撮れる）。
## 画面の操作案内・お金の表示（CanvasLayer）と、制作班にだけ見える物（CREW_LAYER）は映さない。

const FPS := 30
const CREW_LAYER := 1 << 11
const SELF_LAYER := 1 << 12
const CastVisual := preload("res://scripts/cast_visual.gd")

var game: Node
var flow: Node
var cam: Camera3D
var out_dir := ""
var frame := 0
var shot := ""
var rock: RigidBody3D
var rig: Node
var _shake := 0.0
var _keep_ui := false            # 後半（ゲームの流れ）のカットは、画面の表示もそのまま映す
var K := {}                     # カットの途中の状態（ラムダの中で書き換えるので、辞書に置く）


func _initialize() -> void:
	create_timer(400).timeout.connect(func(): quit(2))
	run.call_deferred()


func arg(name: String, fallback: String) -> String:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--%s=" % name):
			return a.get_slice("=", 1)
	return fallback


func frames(count: int) -> void:
	for i in count:
		await physics_frame


func of_kind(kind: String, skip: Array = []) -> RigidBody3D:
	for p: Node in game.props.values():
		if p.kind == kind and not p.absent and p.holder == 0 and not (p in skip):
			return p
	return null


func place(p: RigidBody3D, at: Vector3, yaw: float = 0.0, frozen := false) -> void:
	p.restore([at, Quaternion(Vector3.UP, yaw), frozen])


# ---- 準備 ----

func run() -> void:
	shot = arg("shot", "probe")
	out_dir = arg("out", ProjectSettings.globalize_path("user://trailer/") + shot)
	DirAccess.make_dir_recursive_absolute(out_dir)
	game = load("res://production_game.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	game.input_locked = true
	while not game.startup_complete:
		await process_frame
	await frames(10)
	flow = game.production
	rig = game.hooks.feature("contraptions")
	rock = game.hooks.feature("boulder").rock
	if shot in ["scam_box", "premiere_online"]:
		_keep_ui = true
	elif shot == "cast_pop":
		_keep_ui = true
		flow.day = 2
		for i in flow.JOBS.size():
			if str(flow.JOBS[i].get("script", "")) == "kaiju":
				game.h_accept_job(i)
				break
		await frames(20)
	else:
		flow.day = 2
		for i in flow.JOBS.size():
			if str(flow.JOBS[i]["title"]) == "転がる大岩・予告編":
				game.h_accept_job(i)
				break
		await frames(20)
		game.h_open_order()
		game.h_order_set("boulder", 1)
		game.h_order_confirm()
		await frames(10)
	# 自分の体は、画の外へ
	var me: Node3D = game.local_player()
	me.global_position = Vector3(60, 0.1, 30)
	me.visible = false
	me.collision_layer = 0
	me.process_mode = Node.PROCESS_MODE_DISABLED
	_clear_set()
	cam = Camera3D.new()
	cam.cull_mask = 0xFFFFF & ~CREW_LAYER & ~SELF_LAYER
	cam.fov = 40
	root.add_child(cam)
	cam.make_current()
	_hide_ui()
	print("TRAILER shot=", shot, " out=", out_dir)
	await call(shot)
	print("TRAILER_DONE ", shot, " frames=", frame)
	quit(0)


# 撮る場所（会社の前の広場と車道）から、背の高い板や立て札をどける
func _clear_set() -> void:
	var n := 0
	for p: Node in game.props.values():
		var at: Vector3 = (p as Node3D).global_position
		if p.kind in ["standin", "partition", "greenscreen", "cue_card", "plywood", "window"] and at.x > 69.0 and at.x < 88.0 and at.z > 6.0 and at.z < 34.0:
			p.restore([Vector3(150.0 + float(n) * 4.0, 0.5, 150.0), Quaternion.IDENTITY, true])
			n += 1


func _hide_ui() -> void:
	if _keep_ui:
		return
	for layer: Node in root.find_children("*", "CanvasLayer", true, false):
		(layer as CanvasLayer).visible = false


# 1コマ書き出す（カメラの揺れを足して）
func grab() -> void:
	_hide_ui()
	var base := cam.global_transform
	if _shake > 0.001:
		cam.global_transform = base.translated(Vector3(randf_range(-1, 1), randf_range(-1, 1), 0) * _shake * 0.04)
		_shake *= 0.82
	cam.make_current()
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_jpg("%s/%05d.jpg" % [out_dir, frame], 0.93)
	frame += 1
	cam.global_transform = base


# seconds 秒を撮る。each(t) は毎コマ、写す前に呼ぶ（t は 0..1）
func rec(seconds: float, each: Callable) -> void:
	var n := int(round(seconds * FPS))
	for i in n:
		each.call(float(i) / maxf(n - 1, 1))
		await grab()


func look(from: Vector3, at: Vector3) -> void:
	cam.global_position = from
	cam.look_at(at)


static func ease_io(t: float) -> float:
	return t * t * (3.0 - 2.0 * t)


# 人形（班員）：体の物理を持たない見た目だけのキャラ。道すじは毎コマ、撮影の側で動かす
func puppet(tag: String, at: Vector3, yaw: float) -> Node3D:
	var v: Node3D = CastVisual.new()
	game.add_child(v)
	v.setup(tag)
	v.global_position = at
	v.rotation.y = yaw
	return v


# ---- 試し撮り：場所と構図の候補を静止画で ----

func probe() -> void:
	var t: Vector3 = flow.HOME_TRUCK
	var spots := [
		[t + Vector3(-3, 0.35, 6), t + Vector3(-6, 1.0, 0)],
		[t + Vector3(-9, 1.6, 8), t + Vector3(-4, 0.8, 0)],
		[t + Vector3(2, 0.3, 2), t + Vector3(-6, 1.2, -1)],
		[t + Vector3(-12, 1.2, -4), t + Vector3(-4, 1.0, 2)],
	]
	for s: Array in spots:
		look(s[0], s[1])
		await frames(2)
		await grab()



# ---- 共通の小道具 ----

const ROAD_X := 78.6                 # 追われる場面の道（会社の前の車道。軽トラはよける）
const ROAD_FAR := 11.0               # 走り出す所（奥。会社の側）
const ROAD_NEAR := 26.0              # 手前


func dof(far_from: float, amount := 0.08) -> void:
	var at := CameraAttributesPractical.new()
	at.dof_blur_far_enabled = true
	at.dof_blur_far_distance = far_from
	at.dof_blur_far_transition = far_from * 0.8
	at.dof_blur_amount = amount
	cam.attributes = at


func truck_away() -> void:
	var truck: RigidBody3D = game.get("truck")
	if truck != null:
		truck.restore([Vector3(88, 0.3, 4), Quaternion(Vector3.UP, PI * 0.5), true])


func actor(i: int) -> CharacterBody3D:
	return game.actors[i]


# 役者を、その場に立たせる（印に付いて回る待機をやめる）
func stand(a: CharacterBody3D, at: Vector3, yaw: float) -> void:
	a.global_position = at
	a.rotation.y = yaw
	a.velocity = Vector3.ZERO
	a.set_state(a.St.IDLE)


func run_to(a: CharacterBody3D, to: Vector3, pose := "idle", dive := false, face_go := "shock", face_hold := "shock", look_at := "") -> void:
	a.play_beat({"to": to, "gait": "run", "pose": pose, "look": look_at, "face_go": face_go, "face_hold": face_hold, "dive": dive})
	a.vis.set_face(face_go)


func crew_tags() -> Array:
	var used := [str(actor(0).vis.tag), str(actor(1).vis.tag)]
	var out: Array = []
	for t: String in ["01", "03", "06", "09", "04", "02", "M02"]:
		if not (t in used) and out.size() < 4:
			out.append(t)
	return out


# 物の見た目だけの写し（人形に持たせる）
func copy_of(kind: String) -> Node3D:
	var p := of_kind(kind)
	if p == null or p.visual == null:
		return Node3D.new()
	var v: Node3D = p.visual.duplicate()
	v.transform = Transform3D.IDENTITY
	return v


# ---- S01 大岩が届く（フック）：会社の看板の前に、空から大岩がドスン ----

func boulder_drop() -> void:
	truck_away()
	var at := Vector3(75.2, 0.0, 17.6)
	look(Vector3(77.6, 0.32, 25.4), at + Vector3(-0.4, 2.2, 0))
	cam.fov = 38
	rock.restore([at + Vector3(0, 11.0, 0), Quaternion(Vector3(1, 0.3, 0).normalized(), 0.6), false])
	rock.freeze = true
	await frames(10)
	var from := cam.global_position
	K["started"] = false
	K["landed"] = false
	await rec(3.8, func(t: float) -> void:
		cam.global_position = from + Vector3(-0.15, 0.04, -0.7) * ease_io(t)
		if not K["started"] and t > 0.08:
			K["started"] = true
			rock.freeze = false
			rock.linear_velocity = Vector3(0, -14.0, 0)
			rock.angular_velocity = Vector3(2.0, 0.0, 1.0)
		if K["started"] and not K["landed"] and rock.global_position.y < rock.half.y + 0.4:
			K["landed"] = true
			_shake = 1.0
			print("TRAILER_MARK land frame=", frame))


# ---- S02 選ばれし四人：ガラクタを抱えて走る班員 ----

func crew_run() -> void:
	truck_away()
	rock.restore([Vector3(60, 0.9, 40), Quaternion.IDENTITY, true])
	var tags := crew_tags()
	var loads := ["scrap_chicken", "scrap_poop", "scrap_lamp", "scrap_duck"]
	var lanes := [-2.2, -0.7, 0.8, 2.3]
	var team: Array = []
	for i in 4:
		var who := puppet(str(tags[i]), Vector3(74.5 + lanes[i], 0, 7.0 - float(i) * 1.3), 0.0)
		var held := copy_of(loads[i])
		who.add_child(held)
		held.position = Vector3(0, 1.0, 0.42)
		held.scale = Vector3.ONE * (0.9 if loads[i] != "scrap_lamp" else 0.7)
		who.play("carry_run")
		who.set_face(["happy", "shock", "angry", "happy"][i])
		team.append(who)
	cam.fov = 34
	var eye := Vector3(76.4, 0.28, 24.0)
	look(eye, Vector3(74.8, 1.2, 14.0))
	dof(14.0, 0.05)
	await frames(5)
	await rec(3.6, func(t: float) -> void:
		for i in 4:
			var who: Node3D = team[i]
			who.global_position.z += 4.6 / FPS
			who.position.y = absf(sin(float(frame + i * 7) * 0.45)) * 0.05
		cam.global_position = eye + Vector3(0.0, 0.0, 0.25 * ease_io(t)))


# ---- S03 主演 バスタブ：空からバスタブが落ちてきて、ドスン（大岩の届き方と同じ） ----

func tub_cast() -> void:
	truck_away()
	var tub := of_kind("scrap_tub")
	rock.restore([Vector3(60, 0.9, 40), Quaternion.IDENTITY, true])
	var at := Vector3(ROAD_X, 0.0, 21.0)
	tub.restore([at + Vector3(0, 6.5, 0), Quaternion(Vector3.UP, 0.45) * Quaternion(Vector3.RIGHT, 0.08), true])
	await frames(10)
	cam.fov = 30
	var eye := at + Vector3(1.0, 0.75, 2.5)
	look(eye, at + Vector3(0, 0.45, 0))
	dof(5.0, 0.05)
	K["dropped"] = false
	K["landed"] = false
	await rec(2.8, func(t: float) -> void:
		cam.global_position = eye + Vector3(-0.15, -0.05, -0.3) * ease_io(t)
		cam.look_at(at + Vector3(0, 0.45, 0))
		if not K["dropped"] and t > 0.05:
			K["dropped"] = true
			tub.restore([tub.global_position, tub.quaternion, false])
			tub.linear_velocity = Vector3(0, -9.0, 0)
			tub.angular_velocity = Vector3.ZERO
		if K["dropped"] and not K["landed"] and tub.global_position.y < 0.5:
			K["landed"] = true
			_shake = 0.5
			print("TRAILER_MARK land frame=", frame))


# ---- S04 美術 段ボール：スプレーで、黒い穴を描く ----

func spray_hole() -> void:
	var kit: Node = game.hooks.feature("spray_sign")
	var sheet: RigidBody3D = kit.sheets[0]
	var at := Vector3(73.0, 0.0, 22.0)
	sheet.restore([at, Quaternion.IDENTITY, true])
	var can: RigidBody3D = kit.cans[0]
	await frames(10)
	var face_n: Vector3 = sheet.global_basis.z
	cam.fov = 36
	var eye: Vector3 = sheet.global_position + Vector3(0.9, 0.75, 1.5)
	look(eye, sheet.global_position + Vector3(0, 0.37, 0))
	dof(3.0, 0.05)
	var res: Vector2i = sheet.RESOLUTION
	var c := Vector2(res.x * 0.5, res.y * 0.52)
	K["angle"] = 0.0
	K["rad"] = 6.0
	await rec(3.2, func(t: float) -> void:
		var pts := PackedVector2Array()
		var spreads := PackedFloat32Array()
		var px := c
		for k in 7:
			K["angle"] = float(K["angle"]) + 0.42
			K["rad"] = minf(float(K["rad"]) + 0.95, 150.0)
			px = c + Vector2(cos(float(K["angle"])), sin(float(K["angle"])) * 0.92) * float(K["rad"])
			pts.append(px)
			spreads.append(9.0)
		sheet.spray(pts, spreads, Color(0.06, 0.06, 0.07), frame)
		var hit: Vector3 = sheet.world_at(px)
		var nozzle_at: Vector3 = hit + face_n * 0.42 + Vector3(0.05, 0.03, 0)
		can.restore([nozzle_at - Vector3(0, 0.17, 0), Quaternion(Vector3.UP, sheet.global_rotation.y + PI), true])
		kit._mist_at(can, hit, Time.get_ticks_msec() / 1000.0 + 0.3)
		cam.global_position = eye + Vector3(-0.2, 0.0, -0.25) * ease_io(t))


# ---- S05〜S07 ピタゴラ装置：時計が鳴る → トーチの炎 → ロープが焼き切れる ----

var _clock: RigidBody3D
var _torch: RigidBody3D
var _rope := 0
var _rope_dir := Vector3.RIGHT
var _rope_head := Vector3.ZERO


# 装置を組む：木箱の上に時計とトーチ。トーチの炎の先を、大岩へ張ったロープが通る
func build_rig(ring_in: float) -> void:
	truck_away()
	_clock = of_kind("timer")
	_torch = of_kind("igniter")
	var base := Vector3(72.6, 0.0, 22.0)
	var box := of_kind("applebox")
	place(box, base + Vector3(0, 0.12, 0), 0.0, true)
	await frames(5)
	var top: float = box.global_position.y + box.center.y + box.half.y
	place(_clock, base + Vector3(-0.12, top + 0.02, 0.05), 0.25, true)
	place(_torch, base + Vector3(0.28, top + 0.02, 0.0), 0.0, true)
	await frames(5)
	_rope_head = _torch.global_transform * rig.TORCH_HEAD
	_rope_dir = Vector3(1, 0, -0.15).normalized()
	var anchor := _rope_head - _rope_dir * 1.1 + Vector3(0, 0.06, 0)
	var r: float = rock.half.y
	var attach := _rope_head + _rope_dir * 1.9 + Vector3(0, 0.06, 0)
	# 大岩の原点は底（中心は原点の r 上）。地面に置く
	rock.restore([Vector3(attach.x, 0.02, attach.z) + _rope_dir * r * 0.9, Quaternion.IDENTITY, true])
	await frames(5)
	_rope = rig.host_add_row([0, anchor], [rock.pid, rock.to_local(attach)], [])
	rig.wires[_clock.pid] = [_torch.pid]
	rig.timers[_clock.pid] = ring_in
	rig._changed()
	await frames(2)
	print("TRAILER rig rope=", _rope, " head=", _rope_head)


func rig_clock() -> void:
	await build_rig(1.4)
	cam.fov = 30
	var c: Vector3 = _clock.center_global() + Vector3(0.18, 0.02, 0)
	var eye := c + Vector3(0.35, 0.16, 1.35)
	look(eye, c)
	dof(2.4, 0.08)
	await rec(2.2, func(t: float) -> void:
		cam.global_position = eye + Vector3(-0.06, 0.0, -0.18) * ease_io(t)
		cam.look_at(c)
		# 鳴っている間は、時計がガタガタ震える
		if not rig.timers.has(_clock.pid) or float(rig.timers.get(_clock.pid, 0.0)) <= 0.0:
			_clock.visual.rotation = Vector3(0, randf_range(-0.1, 0.1), randf_range(-0.22, 0.22))
			_clock.visual.position = Vector3(randf_range(-0.015, 0.015), absf(randf_range(0, 0.035)), 0)
			_shake = maxf(_shake, 0.15))


func rig_torch() -> void:
	await build_rig(0.6)
	cam.fov = 30
	var h := _rope_head
	var eye := h + Vector3(-0.35, 0.18, 1.05)
	look(eye, h + Vector3(0.1, 0.05, 0))
	dof(2.0, 0.08)
	await rec(2.4, func(t: float) -> void:
		cam.global_position = eye + Vector3(0.1, 0.0, -0.15) * ease_io(t)
		cam.look_at(h + Vector3(0.1, 0.05, 0)))


func rig_snap() -> void:
	await build_rig(0.3)
	cam.fov = 36
	var mid := _rope_head + _rope_dir * 1.2
	var eye := mid + Vector3(-0.4, 0.5, 4.4)
	look(eye, mid + Vector3(0.3, 0.2, 0))
	dof(4.0, 0.05)
	K["gone"] = false
	await rec(3.2, func(t: float) -> void:
		cam.global_position = eye + Vector3(0.35, 0.0, 0.0) * ease_io(t)
		var row: Dictionary = rig.rows.get(_rope, {})
		if not K["gone"] and not row.is_empty() and bool(row["cut"]):
			K["gone"] = true
			rock.restore([rock.global_position, rock.quaternion, false])
			rock.launch(rock.global_position + Vector3(0, 0.05, 0), _rope_dir * 3.2, _rope_dir.cross(Vector3.DOWN) * 4.0)
			print("TRAILER_MARK snap frame=", frame))


# ---- S08 大岩が転がり出す：地面すれすれのカメラへ、大岩が迫る ----

func boulder_roll() -> void:
	truck_away()
	var eye := Vector3(ROAD_X, 0.22, ROAD_NEAR + 2.0)
	cam.fov = 44
	look(eye, Vector3(ROAD_X, 1.2, ROAD_FAR))
	rock.restore([Vector3(ROAD_X - 0.3, rock.half.y + 0.05, ROAD_FAR + 2.0), Quaternion.IDENTITY, false])
	await frames(10)
	rock.launch(rock.global_position, Vector3(0, 0, 6.5), Vector3(6.0, 0, 0))
	await rec(2.6, func(t: float) -> void:
		cam.global_position = eye + Vector3(0, 0.02 * sin(t * 30.0), -0.3 * t))


# 大岩を、同じ速さで転がし続ける（転がりの減り方を打ち消す。向きは +z）
func _keep_rolling(speed: float) -> void:
	var v := rock.linear_velocity
	if v.z < speed:
		rock.linear_velocity = Vector3(v.x, v.y, lerpf(v.z, speed, 0.3))
	rock.angular_velocity = Vector3(speed / rock.half.y, 0, 0)


# ---- カチンコ（テイク1・テイク2） ----

func _clap(take: int) -> void:
	var clap: RigidBody3D = game.clapper
	var at := Vector3(ROAD_X, 1.25, ROAD_NEAR + 1.0)
	clap.restore([at, Quaternion(Vector3.UP, PI) * Quaternion(Vector3.RIGHT, 0.12), true])
	clap.set_take(take)
	cam.fov = 34
	look(at + Vector3(0.05, 0.12, -1.2), at + Vector3(0, 0.08, 0))
	dof(1.8, 0.12)
	await frames(10)
	K["done"] = false
	await rec(1.6, func(t: float) -> void:
		if not K["done"] and t > 0.38:
			K["done"] = true
			clap.clap()
			print("TRAILER_MARK clap frame=", frame))


func clap1() -> void:
	truck_away()
	await _clap(1)


func clap2() -> void:
	truck_away()
	await _clap(2)


# ---- S10 テイク1：大岩が早すぎて、逃げ遅れた一人がぺちゃんこ ----

func take1() -> void:
	truck_away()
	var a := actor(0)
	var b := actor(1)
	stand(a, Vector3(ROAD_X - 0.75, 0.05, ROAD_FAR + 3.0), 0.0)
	stand(b, Vector3(ROAD_X + 0.75, 0.05, ROAD_FAR + 2.4), 0.0)
	rock.restore([Vector3(ROAD_X + 0.9, rock.half.y + 0.05, ROAD_FAR - 3.5), Quaternion.IDENTITY, false])
	await frames(20)
	cam.fov = 36
	look(Vector3(ROAD_X - 6.0, 1.1, ROAD_FAR + 3.0), Vector3(ROAD_X, 0.8, ROAD_FAR + 2.0))
	dof(9.0, 0.03)
	run_to(a, Vector3(ROAD_X - 0.75, 0.05, ROAD_NEAR + 0.5))
	run_to(b, Vector3(ROAD_X + 0.75, 0.05, ROAD_NEAR + 0.5))
	K["launched"] = false
	await rec(4.6, func(t: float) -> void:
		if not K["launched"] and t > 0.04:
			K["launched"] = true
			rock.launch(rock.global_position, Vector3(0, 0, 6.2), Vector3(7.0, 0, 0))
		elif K["launched"]:
			_keep_rolling(6.2)
		if b.is_flat() and not K.has("hit"):
			K["hit"] = true
			_shake = 0.6
			print("TRAILER_MARK flat frame=", frame)
		# 横から、二人と一緒に進むカメラ（後ろから迫る大岩も入る）。ぺちゃんこの後は止まる
		var m: Vector3 = a.global_position if b.is_flat() else (a.global_position + b.global_position) * 0.5
		if not K.has("stop") and b.is_flat():
			K["stop"] = cam.global_position.z
		var z: float = K.get("stop", m.z - 0.6)
		cam.global_position = cam.global_position.lerp(Vector3(ROAD_X - 6.0, 1.1, z), 0.25)
		cam.look_at(Vector3(ROAD_X, 0.75, cam.global_position.z - 1.2)))


# ---- S12 テイク2：時計を巻き直して、間一髪で穴へ（スローモーション） ----

var _tub: RigidBody3D


func _setup_pit() -> void:
	truck_away()
	_tub = of_kind("scrap_tub")
	place(_tub, Vector3(ROAD_X - 0.2, 0.4, ROAD_NEAR - 4.0), 0.0)
	await frames(30)
	flow.cast_set(_tub.pid, "pit", 0)
	await frames(3)


func take2() -> void:
	await _setup_pit()
	var a := actor(0)
	var b := actor(1)
	stand(a, Vector3(ROAD_X - 0.6, 0.05, ROAD_FAR + 2.0), 0.0)
	stand(b, Vector3(ROAD_X + 0.4, 0.05, ROAD_FAR + 1.4), 0.0)
	rock.restore([Vector3(ROAD_X - 1.95, rock.half.y + 0.05, ROAD_FAR - 4.5), Quaternion.IDENTITY, false])
	await frames(20)
	var c: Vector3 = _tub.center_global()
	var eye := Vector3(ROAD_X + 6.2, 0.6, c.z + 2.6)
	cam.fov = 34
	look(eye, Vector3(ROAD_X, 0.8, c.z - 2.0))
	dof(12.0, 0.03)
	run_to(a, c + Vector3(-0.3, 0, 0), "duck", true, "shock", "shock")
	run_to(b, c + Vector3(0.3, 0, 0), "duck", true, "shock", "shock")
	K["launched"] = false
	K["slow"] = false
	await rec(6.0, func(t: float) -> void:
		if not K["launched"] and t > 0.12:
			K["launched"] = true
			rock.launch(rock.global_position, Vector3(0, 0, 6.0), Vector3(7.0, 0, 0))
		elif K["launched"]:
			_keep_rolling(6.0)
		var gap: float = c.z - rock.global_position.z
		if not K["slow"] and gap < 3.6:
			K["slow"] = true
			Engine.time_scale = 0.3
			print("TRAILER_MARK slow frame=", frame)
		if K["slow"] and gap < -2.4 and Engine.time_scale < 1.0:
			Engine.time_scale = 1.0
			print("TRAILER_MARK fast frame=", frame)
		var focus := Vector3(ROAD_X, 0.8, c.z - 1.0).lerp(c, clampf(t * 1.4, 0.0, 1.0))
		cam.look_at(focus))
	Engine.time_scale = 1.0


# ---- S13 穴から顔を出して「今冬、公開未定！」 ----

func heads() -> void:
	await _setup_pit()
	var a := actor(0)
	var b := actor(1)
	var c: Vector3 = _tub.center_global()
	# 撮影カメラ（役者が顔を向ける先）を、こちらのカメラの後ろへ
	var eye := c + Vector3(0.2, 0.62, 2.3)
	game.film.restore([eye + Vector3(0, -0.5, 1.2), Quaternion(Vector3.UP, 0.0), true])
	stand(a, c + Vector3(-0.3, -0.3, 0), 0.0)
	stand(b, c + Vector3(0.3, -0.3, 0), 0.0)
	a.add_collision_exception_with(_tub)
	b.add_collision_exception_with(_tub)
	a.play_beat({"to": c + Vector3(-0.3, 0, 0), "gait": "walk", "pose": "duck", "look": "camera", "face_go": "happy", "face_hold": "happy"})
	b.play_beat({"to": c + Vector3(0.3, 0, 0), "gait": "walk", "pose": "duck", "look": "camera", "face_go": "happy", "face_hold": "happy"})
	await frames(90)
	cam.fov = 30
	look(eye, c + Vector3(0, 0.55, 0))
	dof(3.4, 0.08)
	await rec(3.2, func(t: float) -> void:
		cam.global_position = eye + Vector3(0, -0.04, -0.3) * ease_io(t)
		a.vis.set_face("happy")
		b.vis.set_face("happy"))


# ---- S14 タイトル：段ボールにスプレーで書いた題の看板と、喜ぶ班員 ----

func title_sign() -> void:
	truck_away()
	var kit: Node = game.hooks.feature("spray_sign")
	var sheet: RigidBody3D = kit.sheets[0]
	var at := Vector3(75.0, 0.0, 18.5)
	sheet.restore([at, Quaternion.IDENTITY, true])
	sheet.visual.scale = Vector3(2.3, 2.3, 1.0)
	var pic := Image.load_from_file(arg("sign", ""))
	if pic != null and not pic.is_empty():
		(sheet.surface.material_override as StandardMaterial3D).albedo_texture = ImageTexture.create_from_image(pic)
	var tags := crew_tags()
	var team: Array = []
	var spots := [Vector3(-2.45, 0, -0.1), Vector3(-1.65, 0, 0.35), Vector3(1.65, 0, 0.35), Vector3(2.45, 0, -0.1)]
	for other: RigidBody3D in kit.sheets:
		if other != sheet:
			other.restore([Vector3(150, 0.5, 160 + float(kit.sheets.find(other)) * 3.0), Quaternion.IDENTITY, true])
	for i in 4:
		var who := puppet(str(tags[i]), at + spots[i], [0.35, 0.15, -0.15, -0.35][i])
		who.set_face("happy")
		team.append(who)
	await frames(10)
	var c: Vector3 = at + Vector3(0, 0.85, 0)
	var eye := c + Vector3(0.0, 0.3, 6.4)
	cam.fov = 36
	look(eye, c)
	dof(9.0, 0.04)
	await rec(4.2, func(t: float) -> void:
		cam.global_position = eye + Vector3(0, -0.05, -1.4) * ease_io(t)
		cam.look_at(c)
		for i in 4:
			var who: Node3D = team[i]
			if (frame + i * 9) % 26 == 0:
				who.play("jump", 0.1, true))



# ---- 後半：ゲームの流れ（画面の表示もそのまま） ----

# 怪しい教材の箱：開けると、ホログラムのバズ山が出てきて、貯金が 100万 減る
func scam_box() -> void:
	var kit: Node = game.hooks.feature("delivery_box")
	kit.start()
	await frames(10)
	var b: Node3D = kit.box
	var me: Node3D = game.local_player()
	me.process_mode = Node.PROCESS_MODE_INHERIT
	me.global_position = b.global_position + Vector3(0, 0.1, 1.6)
	me.visible = false
	await frames(5)
	var c: Vector3 = b.global_position
	cam.cull_mask = 0xFFFFF & ~SELF_LAYER          # ホログラムの講師は、制作班にだけ見える層
	cam.fov = 40
	var eye := c + Vector3(-1.6, 1.25, 3.2)
	look(eye, c + Vector3(0, 0.9, 0))
	dof(6.0, 0.04)
	K["opened"] = false
	await rec(7.5, func(t: float) -> void:
		cam.global_position = eye + Vector3(0.3, 0.1, -0.6) * ease_io(t)
		cam.look_at(c + Vector3(0, 0.95 + 0.25 * t, 0))
		if not K["opened"] and t > 0.06:
			K["opened"] = true
			kit.hook_f(me)
			print("TRAILER_MARK open frame=", frame))


# 見立て：便器に役を付けると、目玉と角がポン（準備中は役の名前も出る）
func cast_pop() -> void:
	var toilet := of_kind("scrap_toilet")
	var at := Vector3(ROAD_X - 2.0, 0.0, 21.0)
	place(toilet, at + Vector3(0, 0.5, 0), 0.0)
	await frames(40)
	cam.cull_mask = 0xFFFFF & ~SELF_LAYER
	cam.fov = 34
	var c: Vector3 = toilet.center_global()
	var eye := c + Vector3(0.5, 0.55, 2.6)
	look(eye, c + Vector3(0, 0.2, 0))
	dof(4.5, 0.05)
	var side: int = game.cast_face_side(toilet, eye)
	K["cast"] = false
	await rec(2.6, func(t: float) -> void:
		cam.global_position = eye + Vector3(-0.1, -0.05, -0.35) * ease_io(t)
		cam.look_at(c + Vector3(0, 0.2, 0))
		if not K["cast"] and t > 0.3:
			K["cast"] = true
			flow.cast_set(toilet.pid, "monster", side)
			game.host_ev("cast_toast", ["撮影用トイレ → 怪獣役", "撮影用トイレ → 怪獣役（それらしい）"])
			print("TRAILER_MARK pop frame=", frame)
		var dress: Node3D = game._cast_dress.get(toilet.pid)
		if dress != null:
			if not K.has("pop0"):
				K["pop0"] = t
			var k: float = clampf((t - float(K["pop0"])) / 0.12, 0.0, 1.0)
			var pop := 1.0 + sin(k * PI) * 0.35
			for d: Node in dress.get_children():
				(d as Node3D).scale = Vector3.ONE * maxf(0.01, k * pop))


# 試写会（最初の一本はネットに上げる）：再生数が増えて、コメントが流れる
func premiere_online() -> void:
	var premiere: Node = game.hooks.feature("premiere")
	game.h_accept_job(flow.debut_job())
	await frames(20)
	var me: Node3D = game.local_player()
	me.process_mode = Node.PROCESS_MODE_INHERIT
	me.global_position = flow.HOME_TRUCK + Vector3(-3, 0.1, 0)
	look(flow.HOME_TRUCK + Vector3(-6, 2, 6), flow.HOME_TRUCK)
	await frames(3)
	game.h_depart()
	for i in 600:
		if flow.phase == 4:
			break
		await physics_frame
	await frames(30)
	game.h_take()
	for i in 400:
		if game.state == game.S.TAKE:
			break
		await physics_frame
	print("TRAILER take state=", game.state, " phase=", flow.phase)
	await frames(200)
	game._cut()
	await frames(5)
	print("TRAILER after cut state=", game.state, " takes=", (game._take_data as Array).size(), " frames=", (game._take_data[0]["frames"] as Array).size() if (game._take_data as Array).size() > 0 else -1)
	premiere._times[0] = [0.5, 1.2, 2.0, 2.8]
	game.request_deliver(0)
	await frames(10)
	print("TRAILER premiere state=", game.state, " screening=", premiere.screening, " replay=", game.get("replaying"))
	await rec(12.0, func(_t: float) -> void:
		if frame % 30 == 0:
			print("TRAILER t=", frame / 30, " screening=", premiere.screening, " replay_t=", game.get("replay_t")))


# ---- 後半のドタバタ：機能をテンポよく ----

# 爆破：段ボールの山の真ん中で、爆弾がドカン。箱が飛ぶ
func boom_fx() -> void:
	truck_away()
	rock.restore([Vector3(60, 0.9, 40), Quaternion.IDENTITY, true])
	var at := Vector3(ROAD_X, 0.0, 19.0)
	var bomb: RigidBody3D = game.fx
	bomb.restore([at + Vector3(0, 0.05, 0), Quaternion.IDENTITY, true])
	var junk: Array = []
	for p: Node in game.props.values():
		if p.kind == "carton" and not p.absent and junk.size() < 6:
			junk.append(p)
	for i in junk.size():
		var a := TAU * float(i) / float(junk.size())
		(junk[i] as RigidBody3D).restore([at + Vector3(cos(a) * 1.3, 0.45, sin(a) * 1.3), Quaternion(Vector3.UP, a), false])
	await frames(30)
	cam.fov = 40
	var eye := at + Vector3(0.8, 0.9, 6.0)
	look(eye, at + Vector3(0, 0.8, 0))
	dof(9.0, 0.03)
	K["boom"] = false
	await rec(2.2, func(t: float) -> void:
		if not K["boom"] and t > 0.18:
			K["boom"] = true
			game.host_ev("burst", [at + Vector3(0, 0.4, 0), 1.0])
			for p: RigidBody3D in junk:
				var d: Vector3 = (p.global_position - at).normalized()
				p.apply_central_impulse((d * 7.0 + Vector3(0, 8.0, 0)) * p.mass)
				p.apply_torque_impulse(Vector3(randf_range(-2, 2), randf_range(-2, 2), randf_range(-2, 2)) * p.mass)
			_shake = 1.2
			print("TRAILER_MARK boom frame=", frame))


# 送風機：風で、軽い物が吹き飛ぶ
func fan_wind() -> void:
	truck_away()
	var fan := of_kind("scrap_fan")
	var at := Vector3(ROAD_X - 1.5, 0.0, 20.0)
	place(fan, at + Vector3(0, 0.6, 0), PI * 0.5, true)
	await frames(20)
	var light: Array = []
	for kind: String in ["letter", "crown", "fish", "scrap_chicken", "rose", "script"]:
		var p := of_kind(kind)
		if p != null:
			light.append(p)
	var dir: Vector3 = fan.global_basis.z.normalized()
	for i in light.size():
		(light[i] as RigidBody3D).restore([at + dir * (1.2 + 0.35 * float(i)) + Vector3(0, 0.6 + 0.1 * float(i % 2), randf_range(-0.4, 0.4)), Quaternion.IDENTITY, false])
	await frames(30)
	cam.fov = 40
	var eye := at + dir * 2.2 + Vector3(0, 1.1, 5.4)
	look(eye, at + dir * 2.4 + Vector3(0, 0.9, 0))
	dof(8.0, 0.03)
	K["on"] = false
	await rec(2.0, func(t: float) -> void:
		if not K["on"] and t > 0.22:
			K["on"] = true
			rig.host_fan(fan, 3.0)
		if K["on"]:
			for p: RigidBody3D in light:
				p.apply_central_force((dir * 8.5 + Vector3(0, 3.2, 0)) * p.mass))


# 軽トラに積む：荷台へ、次々と物が放り込まれる
func truck_load() -> void:
	var truck: RigidBody3D = game.get("truck")
	var at := Vector3(ROAD_X, 0.3, 21.0)
	truck.restore([at, Quaternion(Vector3.UP, PI * 0.5), true])
	rock.restore([Vector3(60, 0.9, 40), Quaternion.IDENTITY, true])
	await frames(20)
	var items: Array = []
	for kind: String in ["scrap_tub", "scrap_toilet", "scrap_duck", "scrap_lamp", "carton"]:
		var p := of_kind(kind)
		if p != null:
			items.append(p)
	var bed: Vector3 = truck.global_transform * Vector3(truck.deck_c.x, truck.deck_top, truck.deck_c.y)
	cam.fov = 42
	var eye := bed + Vector3(-3.6, 2.3, 3.0)
	look(eye, bed + Vector3(0, -0.3, 0))
	dof(9.0, 0.03)
	for p: RigidBody3D in items:
		p.restore([Vector3(150, 0.5, 120 + float(items.find(p)) * 3.0), Quaternion.IDENTITY, true])
	await frames(3)
	await rec(2.4, func(t: float) -> void:
		var k := int(t * 4.6)
		for i in items.size():
			var p: RigidBody3D = items[i]
			if i == k and not K.has("thrown%d" % i):
				K["thrown%d" % i] = true
				p.restore([bed + Vector3(randf_range(-0.35, 0.35), 2.4, randf_range(-0.5, 0.5)), Quaternion(Vector3(randf(), randf(), randf()).normalized(), randf() * 2.0), false])
				p.linear_velocity = Vector3(0, -2.0, 0)
				p.angular_velocity = Vector3(randf_range(-4, 4), randf_range(-4, 4), randf_range(-4, 4)))


# 台車に載せたカメラ：押して走りながら、役者を追う
func dolly_track() -> void:
	truck_away()
	rock.restore([Vector3(60, 0.9, 40), Quaternion.IDENTITY, true])
	var dolly := of_kind("dolly")
	if dolly == null:
		dolly = game.stage.spawn("dolly", Vector3(ROAD_X - 2.6, 0.05, ROAD_FAR), 0.0)
	var film: RigidBody3D = game.film
	var a := actor(0)
	var b := actor(1)
	var z0 := ROAD_FAR + 2.0
	stand(a, Vector3(ROAD_X - 0.6, 0.05, z0 + 1.5), 0.0)
	stand(b, Vector3(ROAD_X + 0.6, 0.05, z0 + 1.0), 0.0)
	var tags := crew_tags()
	var pusher := puppet(str(tags[1]), Vector3(ROAD_X - 2.6, 0, z0 - 1.6), 0.0)
	pusher.play("carry_run")
	pusher.set_face("happy")
	await frames(20)
	run_to(a, Vector3(ROAD_X - 0.6, 0.05, ROAD_NEAR + 2.0), "idle", false, "happy", "happy")
	run_to(b, Vector3(ROAD_X + 0.6, 0.05, ROAD_NEAR + 2.0), "idle", false, "happy", "happy")
	cam.fov = 38
	dof(10.0, 0.03)
	K["z"] = z0
	await rec(2.6, func(t: float) -> void:
		K["z"] = float(K["z"]) + 3.3 / FPS
		var z: float = K["z"]
		var d := Vector3(ROAD_X - 2.6, 0.02, z)
		dolly.restore([d, Quaternion(Vector3.UP, 0.0), true])
		film.restore([d + Vector3(0, 0.25, 0.1), Quaternion(Vector3.UP, -PI * 0.5), true])
		pusher.global_position = d + Vector3(0, 0, -1.2)
		cam.global_position = Vector3(ROAD_X - 5.6, 1.7, z + 1.5)
		cam.look_at(Vector3(ROAD_X - 1.0, 0.8, z + 1.2)))

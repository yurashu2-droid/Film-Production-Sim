extends SceneTree
# 段ボール置き場・箱詰め・ロープ（フックに掛ける・たるみ・切る・道中で落ちる）を撮る（画像は tests/shots/carton へ）。
#   godot --path godot --position -32000,-32000 --audio-driver Dummy --script res://tests/cartonshot.gd
#   （画面つきで動かす。窓は画面の外に出し、音は鳴らさない。マウスも捕まえない）
var game: Node
var flow: Node
var kit: Node
var me: Node
var truck: Node
var cam: Camera3D
var ride := []                # 走っている軽トラを追うカメラ：[軽トラから見たカメラの位置, 見る点, 画角]（空なら追わない）


func _initialize() -> void:
	create_timer(240).timeout.connect(func(): quit(2))
	process_frame.connect(func() -> void:
		if Input.mouse_mode != Input.MOUSE_MODE_VISIBLE:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		# 移動中は、ゲームが毎コマ自分のカメラに切り替える。撮る間だけ、こちらのカメラに戻し続ける
		if not ride.is_empty() and truck != null and cam != null:
			view(truck.global_transform * (ride[0] as Vector3), truck.global_transform * (ride[1] as Vector3), float(ride[2])))
	run.call_deferred()


func frames(count: int) -> void:
	for i in count:
		await physics_frame


func snap(tag: String) -> void:
	for i in 14:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://tests/shots/carton/%s.png" % tag)
	print("CARTONSHOT ", tag)


# 自分で置いたカメラで撮る（from から at を見る）。画面の文字は消す
func view(from: Vector3, at: Vector3, fov: float = 55.0) -> void:
	cam.fov = fov
	cam.global_position = from
	cam.look_at(at)
	cam.make_current()
	game.hud.visible = false
	game.production_hud.visible = false


# 遊ぶ人の画面に戻す
func play_view() -> void:
	cam.current = false
	me.cam.make_current()
	game.hud.visible = true
	game.production_hud.visible = true


func of_kind(kind: String) -> Array:
	var out: Array = []
	for pid: int in game.props:
		if game.props[pid].kind == kind and not game.props[pid].absent:
			out.append(game.props[pid])
	return out


func put(prop: Node, pos: Vector3, yaw: float = 0.0) -> void:
	if prop.rider_of != 0:
		game.host_unload(prop)
	var state: Array = prop.get_state()
	state[0] = pos
	state[1] = Quaternion(Vector3.UP, yaw)
	state[2] = false
	prop.restore(state)


# 目の前に置いて、手に持つ
func take(prop: Node) -> void:
	if me.held != 0:
		game.h_release()
		await frames(2)
	put(prop, me.global_position + Vector3(0, 1.0, 0) + me.flat_forward() * 1.4)
	await frames(2)
	game.h_grab(prop.pid)
	await frames(3)


func pack(prop: Node, box: Node) -> bool:
	await take(prop)
	kit.h_pack(prop.pid, box.pid)
	await frames(3)
	if prop.stored_in != box.pid:
		print("CARTONSHOT could not pack ", prop.kind, " why=", kit.pack_problem(prop, box), " holder=", prop.holder, " held=", me.held, " dist=", me.global_position.distance_to(box.center_global()), " half=", prop.half)
		game.h_release()
		await frames(2)
		put(prop, me.global_position + Vector3(-5.0 - 0.9 * float(prop.pid % 6), 0.4, -2.0 - 1.1 * float(prop.pid % 4)))
		return false
	return true


# 箱の中を、ななめ上からのぞいて撮る
func close_up(box: Node3D, tag: String) -> void:
	view(box.global_position + Vector3(-0.55, 2.25, 1.05), box.global_position + Vector3(0.0, 0.3, 0.0), 44.0)
	await snap(tag)
	# 真横の少し上から：口のふちと、中身の高さの関係
	view(box.global_position + Vector3(0.0, 1.05, 2.6), box.global_position + Vector3(0.0, 0.5, 0.0), 40.0)
	await snap(tag + "_side")


# その物に照準が合う立ち位置と視線にする（カメラはキャラの真後ろ。合わなければ、少し横へずれて試す）。
# facing＝立つ向き（進む向きの yaw）、back＝物からの距離
func aim_at(prop: Node3D, yaw: float, back: float) -> void:
	me.aim_yaw = yaw
	var forward: Vector3 = me.flat_forward()
	var right := Vector3(-forward.z, 0.0, forward.x)
	for side: float in [0.0, 0.25, -0.25, 0.9]:
		if await _aim_from(prop, forward, right, back, side):
			return
	print("CARTONSHOT could not aim at ", prop.kind)


func _aim_from(prop: Node3D, forward: Vector3, right: Vector3, back: float, side: float) -> bool:
	var spot: Vector3 = prop.center_global() - forward * back - right * side
	me.global_position = Vector3(spot.x, 0.1, spot.z)
	for step in 16:
		me.aim_pitch = -0.1 - 0.05 * float(step)
		await frames(3)
		if me.target == prop:
			# 少し深く狙って、ふちではなく面をとらえる
			me.aim_pitch -= 0.04
			await frames(3)
			if me.target != prop:
				me.aim_pitch += 0.04
				await frames(3)
			return true
	return false


# 束を持って、フック from に結び、フック to に結ぶ。near＝2つ目のフックのそばまで歩いて結ぶ（false＝1つ目のそばから投げる）
func lash(from: int, to: int, near: bool = true) -> int:
	var before: Array = kit.lashes.keys()
	await stand_at(from)
	await take(kit.rope)
	kit.h_hook(from)
	await frames(20)
	if near:
		game.h_release()
		await frames(2)
		await stand_at(to)
		await take(kit.rope)
		await frames(10)
	kit.h_hook(to)
	await frames(20)
	game.h_release()
	await frames(2)
	for id: int in kit.lashes:
		if id not in before:
			return id
	print("CARTONSHOT could not lash ", from, " -> ", to)
	return 0


# そのフックの外側に立って、軽トラのほうを向く（手に持った物が、フックのそばに来る）
func stand_at(hook: int) -> void:
	if me.held != 0:
		game.h_release()
		await frames(2)
	var local: Vector3 = truck.hooks[hook]
	var spot: Vector3 = truck.global_transform * Vector3(local.x + signf(local.x) * 1.45, 0.0, local.z)
	var to: Vector3 = kit.hook_at(hook) - spot
	me.global_position = Vector3(spot.x, truck.global_position.y + 0.1, spot.z)
	me.aim_yaw = atan2(-to.x, -to.z)
	me.aim_pitch = -0.1
	await frames(3)


func load_by_hand(prop: Node, along: float) -> void:
	if me.held != 0:
		game.h_release()
		await frames(2)
	var box: AABB = game.body_bounds(prop)
	var reach: float = box.size.x * 0.5
	me.global_position = truck.global_transform * Vector3(-2.9, 0.1, along + box.size.z * 0.5 + 1.6)
	me.aim_yaw = -PI * 0.5
	me.aim_pitch = -0.1
	prop.restore([truck.global_transform * Vector3(-(1.5 + reach) - box.get_center().x, 0.5 - box.position.y, along - box.get_center().z), Quaternion.IDENTITY, false])
	await frames(2)
	game.h_grab(prop.pid)
	await frames(10)
	game.h_load_truck(prop.pid)
	await frames(20)
	if prop.rider_of != truck.pid:
		print("CARTONSHOT could not load ", prop.kind)
		game.h_release()


func run() -> void:
	game = load("res://production_game.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	while not game.startup_complete:
		await process_frame
	await frames(60)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://tests/shots/carton"))
	flow = game.production
	kit = game.cargo_kit
	me = game.local_player()
	truck = game.truck
	cam = Camera3D.new()
	game.add_child(cam)
	var yard: Rect2 = kit.YARD
	var mid := Vector3(yard.get_center().x, 0.0, yard.get_center().y)
	game.h_accept_job(3)
	await frames(40)

	# 1) 段ボール置き場：北東（軽トラ・通り道の側）の上から
	me.global_position = flow.HOME_TRUCK + Vector3(-3.0, 0.1, 5.5)
	view(mid + Vector3(4.6, 3.3, -5.0), mid + Vector3(-0.4, 0.6, 0.2), 52.0)
	await snap("1_carton_yard")
	# 2) 遊ぶ人の画面：軽トラの横から置き場を見る（遠くからの目印と、足元の文字）
	play_view()
	me.global_position = flow.HOME_TRUCK + Vector3(-3.2, 0.1, -2.6)
	var to_yard: Vector3 = mid - me.global_position
	me.aim_yaw = atan2(-to_yard.x, -to_yard.z)
	me.aim_pitch = -0.16
	await frames(30)
	await snap("2_yard_from_truck")
	# 3) 山を狙う：残りの数と「F：1箱もらう」
	await aim_at(kit.pile, PI, 2.7)       # 北の通り道の側から（置き場の箱の中には立たない）
	await frames(10)
	await snap("3_aim_pile")

	# ---- 箱詰め：軽トラの南西の空いた所に箱を並べて詰める（となりの箱が写り込まないよう、間をあける） ----
	var boxes: Array = of_kind("carton")
	var bench: Vector3 = flow.HOME_TRUCK + Vector3(-7.5, 0.1, 9.5)
	for i in 4:
		put(boxes[i], bench + Vector3(-3.6 + 2.4 * float(i), 0.1, -1.9))
	me.global_position = bench
	me.aim_yaw = 0.0
	me.aim_pitch = -0.3
	await frames(40)
	# 小さい物（いちばん長い辺が 50cm まで）を、ある分だけ1つの箱へ。中くらいの物は別の箱へ。トイレは、また別の箱へ
	var small: Array = []
	var slim: Array = []
	for prop: Node in game.props.values():
		# あとの場面で手に持つ物（ニワトリ・テープ）と、手で落とす物（王冠）は、取っておく
		if prop.absent or prop.holder != 0 or kit.pack_ban(prop) != "" or prop.kind in ["scrap_chicken", "tape", "crown"]:
			continue
		var longest: float = maxf(prop.half.x, maxf(prop.half.y, prop.half.z)) * 2.0
		if longest <= 0.5:
			small.append(prop)
		elif longest <= 0.82 and prop.kind not in ["dragon_skull", "scrap_duck", "scrap_idol", "scrap_chest"]:
			slim.append(prop)
	# かさのある物から先に入れる（詰めるのが上手な人の順。入れる順で、入る量も並びも変わる）
	var bulk := func(a: Node, b: Node) -> bool: return a.half.x * a.half.y * a.half.z > b.half.x * b.half.y * b.half.z if not is_equal_approx(a.half.x * a.half.y * a.half.z, b.half.x * b.half.y * b.half.z) else a.pid < b.pid
	small.sort_custom(bulk)
	slim.sort_custom(bulk)
	var count := 0
	for prop: Node in small:
		if await pack(prop, boxes[0]):
			count += 1
	print("CARTONSHOT small props in one carton: %d of %d, top %.2f m from the mouth" % [count, small.size(), kit.box_over(boxes[0])])
	await pack(of_kind("scrap_toilet")[0], boxes[2])
	for kind: String in ["dragon_skull", "scrap_duck", "scrap_idol"]:
		await pack(of_kind(kind)[0], boxes[3])
	print("CARTONSHOT medium carton: %s, top %.2f m from the mouth" % [kit.box_note(boxes[3]), kit.box_over(boxes[3])])
	await frames(20)
	# 4) 物の入った箱：北の上から、箱の中をのぞく
	view(bench + Vector3(0.0, 3.4, 2.6), bench + Vector3(0.0, 0.3, -1.9), 60.0)
	await snap("4_packed_cartons")
	await close_up(boxes[0], "5_packed_close")
	await close_up(boxes[3], "5b_medium_close")
	await close_up(boxes[2], "5c_toilet_sticks_out")
	# いっぱいの箱（中くらいの物の箱）を、かさのある物（お宝の箱）を持って狙う：「もう入らない」
	var chest: Node = of_kind("scrap_chest")[0]
	play_view()
	await take(chest)
	await aim_at(boxes[3], 0.0, 2.2)
	await frames(10)
	await snap("7b_aim_full_carton")
	# 満杯ではみ出した箱：お宝の箱を先に入れ、細長い物を足し、最後に王冠を手で上から落とす
	me.global_position = bench
	me.aim_yaw = 0.0
	await frames(3)
	count = 1 if await pack(chest, boxes[1]) else 0
	for prop: Node in slim:
		if await pack(prop, boxes[1]):
			count += 1
	var drop: Node = of_kind("crown")[0]
	put(drop, boxes[1].global_transform * Vector3(-0.1, 1.1, 0.0) - drop.center)
	await frames(150)
	print("CARTONSHOT overflowing carton: %d props by F, crown dropped by hand stored=%s, top %.2f m from the mouth, lid blocked=%s" % [count, str(drop.stored_in == boxes[1].pid), kit.box_over(boxes[1]), str(kit.lid_blocked(boxes[1]))])
	me.global_position = boxes[1].global_position + Vector3(0, 0.1, 1.6)
	await frames(3)
	game.h_toggle_carton(boxes[1].pid)
	await frames(40)
	print("CARTONSHOT after trying to close it: opened=", boxes[1].opened)
	me.global_position = bench
	await frames(3)
	await close_up(boxes[1], "5d_full_overflow")
	# 5) 手ぶらで、中身のある箱を狙う：名前の横に中身、下に操作
	play_view()
	await aim_at(boxes[0], 0.0, 2.0)
	await frames(10)
	print("CARTONSHOT aim filled: ", kit.f_action(me).get("do", ""), " note=", kit._note.text if kit._note.visible else "(hidden)")
	await snap("6_aim_filled_carton")
	await aim_at(boxes[3], 0.0, 2.0)
	await frames(10)
	await snap("6b_aim_medium_carton")
	# 6) 物を持って、開いた箱を狙う：「箱に入れる」
	await aim_at(boxes[1], 0.0, 2.2)
	var tape: Node = of_kind("tape")[0]
	await take(of_kind("scrap_chicken")[0])
	await aim_at(boxes[1], 0.0, 2.2)
	await frames(10)
	await snap("7_aim_with_prop")
	# 入らない物（岩）を持ったとき
	await take(of_kind("rock")[0])
	await aim_at(boxes[1], 0.0, 2.2)
	await frames(10)
	await snap("8_aim_too_big")
	game.h_release()
	await frames(5)
	put(of_kind("rock")[0], Vector3(yard.position.x - 2.5, 0.3, yard.position.y - 2.0))
	put(tape, Vector3(yard.position.x - 1.5, 0.3, yard.position.y - 2.0))

	# ---- 荷台：箱ごと積む → フックにロープを掛ける ----
	var partition: Node = of_kind("partition")[0]
	await load_by_hand(boxes[0], -0.57)
	await load_by_hand(boxes[3], -1.5)
	await frames(60)
	var behind := Vector3(-2.7, 4.3, -5.3)
	var deck := Vector3(0, 1.3, -1.2)
	# 9) 箱を積んだ荷台（後ろの上から）。荷台の左右のふちと、鳥居の柱に、黄色いフックが付いている
	me.global_position = flow.HOME_TRUCK + Vector3(-4.6, 0.1, 3.0)
	view(truck.global_transform * behind, truck.global_transform * deck, 55.0)
	await snap("9_cartons_on_deck")
	view(truck.global_transform * Vector3(-3.0, 1.7, -2.6), truck.global_transform * Vector3(-1.1, 1.0, -1.2), 42.0)
	await snap("10_hooks_side")
	# 10) 束を持って、フックを狙う：全部のフックに小さな輪、狙ったフックに大きな輪。案内は「F フックに結ぶ」
	play_view()
	await stand_at(3)
	me.global_position += truck.global_basis.x * -1.2
	await take(kit.rope)
	for step in 30:
		me.aim_pitch = -0.02 - 0.012 * float(step)
		await frames(3)
		if str(kit.f_action(me).get("do", "")) == "hook":
			break
	await frames(10)
	await snap("11_aim_hook")
	game.h_release()
	await frames(4)
	# 11) きちんと掛けた所：2つ目のフックのそばまで歩いて結ぶ → 箱の上を通って、張っている
	kit.rng.seed = 5
	var tight: int = await lash(3, 8, true)
	await frames(180)
	print("CARTONSHOT tight slack=%.3f grip=%.2f asleep=%s" % [float(kit.lashes[tight]["slack"]), kit.grip_of(boxes[0].pid), str(kit.lashes[tight]["cord"].asleep)])
	view(truck.global_transform * behind, truck.global_transform * deck, 55.0)
	await snap("12_lashed_tight")
	view(truck.global_transform * Vector3(-3.3, 2.5, -0.2), truck.global_transform * Vector3(0.1, 1.5, -1.0), 50.0)
	await snap("13_lashed_tight_side")
	view(truck.global_transform * Vector3(0.0, 5.2, -1.2), truck.global_transform * Vector3(0.0, 1.0, -1.25), 40.0)
	await snap("13b_lashed_tight_top")
	view(truck.global_transform * Vector3(0.0, 2.0, -4.6), truck.global_transform * Vector3(0.0, 1.55, -0.6), 40.0)
	await snap("13c_lashed_tight_rear")
	# 12) たるんだ所：1つ目のフックのそばから投げて結ぶ（さらに、確認用の入口でゆるめる）→ 箱の横で垂れている
	var loose: int = await lash(1, 7, false)
	kit.host_loosen(loose, 0.3)
	await frames(240)
	print("CARTONSHOT loose slack=%.3f grip=%.2f" % [float(kit.lashes[loose]["slack"]), kit.grip_of(boxes[3].pid)])
	view(truck.global_transform * behind, truck.global_transform * deck, 55.0)
	await snap("14_lashed_loose")
	view(truck.global_transform * Vector3(0.0, 2.6, -5.2), truck.global_transform * Vector3(0.0, 1.5, -1.4), 46.0)
	await snap("15_tight_and_loose_rear")
	# 13) 手ぶらで、掛けたロープを狙う：「F ほどく」
	play_view()
	await stand_at(3)
	me.global_position += truck.global_basis.x * -1.0
	for step in 40:
		me.aim_pitch = 0.1 - 0.012 * float(step)
		await frames(3)
		if str(kit.f_action(me).get("do", "")) == "untie":
			break
	await frames(10)
	await snap("16_aim_rope")
	# 14) 積み込み確認の画面：ロープのことは、何も書いていない
	me.global_position = flow.HOME_TRUCK + Vector3(-3, 0.1, 0)
	me.aim_yaw = -PI * 0.5
	me.aim_pitch = -0.2
	await frames(20)
	game.open_menu("packing")
	await snap("17_packing_sheet")
	game.close_menu()
	# 15) 切った所：はさみで、たるんだロープを切る → 2つに分かれて、それぞれのフックから垂れる
	await stand_at(1)
	await take(game.bomb_kit.scissors)
	var cord: Node3D = kit.lashes[loose]["cord"]
	kit.h_cut_lash(loose, cord.length * 0.5)
	await frames(180)
	game.h_release()
	view(truck.global_transform * behind, truck.global_transform * deck, 55.0)
	await snap("18_cut")
	# 16) 背の高いパーテーションを、後ろに積む（側板に渡して立つ）。ロープは、たるませて掛ける。
	#     背の高い物に掛けると、ロープをたくさん使う（束が細くなる）。箱に掛けていたロープは、ほどいて束に戻す
	for id: int in kit.lashes.keys():
		kit._undo(id)
	put(boxes[3], flow.HOME_TRUCK + Vector3(-6.0, 0.2, 4.0))
	await load_by_hand(partition, -1.88)
	await frames(60)
	var slack_one: int = await lash(1, 6, false)
	if slack_one != 0:
		kit.host_loosen(slack_one, 0.45)
	await frames(260)
	print("CARTONSHOT partition slack=%.3f grip=%.2f stock=%.2f asleep=%s" % [float(kit.lashes[slack_one]["slack"]), kit.grip_of(partition.pid), kit.stock(), str(kit.lashes[slack_one]["cord"].asleep)])
	view(truck.global_transform * behind, truck.global_transform * deck, 55.0)
	await snap("19_before_trip")
	# 17) 道中：張ったロープの箱は動かない。たるんだロープのパーテーションは、ずれて落ちる
	me.global_position = flow.HOME_TRUCK + Vector3(-3, 0.1, 0)
	await frames(3)
	game.h_depart()
	ride = [behind + Vector3(-1.0, 0.0, -1.5), deck, 62.0]
	await frames(14)
	await snap("20_trip_start")
	await frames(10)
	await snap("21_trip_falling")
	await frames(60)
	ride = [behind, deck, 55.0]
	await frames(140)
	await snap("22_trip_later")
	ride = [Vector3(-3.5, 3.0, -9.0), Vector3(0, 1.0, -4.0), 60.0]
	await frames(20)
	await snap("23_trip_behind")
	ride = []
	while flow.phase == 3:
		await physics_frame
	await frames(90)
	# 18) 現場：ロープは掛かったまま（自分でほどく）
	print("CARTONSHOT lost=", flow.lost, " lashes=", kit.lashes.size())
	view(truck.global_transform * behind, truck.global_transform * deck, 55.0)
	await snap("24_on_site")
	print("CARTONSHOT_OK")
	quit(0)

extends SceneTree
# 実際のシーン・移動・撮影を固定60Hzで確認する。配置と合図は自動。
var game: Node
var caption: Label
var counter := 0
var frame_id := 0
var capturing := false
var output := "res://tests/shots/production_preview/frames"
func _initialize():
	run.call_deferred()
func frames(n: int):
	for i in n:
		await physics_frame
		counter += 1
		if capturing and counter % 2 == 0:
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_jpg(output + "/%05d.jpg" % frame_id,0.88)
			frame_id += 1
func title(text: String):
	caption.text = text
	print("PREVIEW_SCENE ",frame_id," ",text)
func place(prop: Node, pos: Vector3, yaw: float = 0.0):
	if prop.rider_of != 0: game.host_unload(prop)
	var state: Array = prop.get_state()
	state[0] = pos
	state[1] = Quaternion(Vector3.UP,yaw)
	state[2] = true
	prop.restore(state)
func run():
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	var menu: Node = load("res://start_menu.tscn").instantiate()
	root.add_child(menu)
	current_scene = menu
	await frames(6)
	var overlay := CanvasLayer.new()
	overlay.layer = 100
	root.add_child(overlay)
	var bar := ColorRect.new()
	bar.color = Color(0.08,0.06,0.04,0.96)
	bar.position = Vector2(0,822)
	bar.size = Vector2(1600,78)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(bar)
	caption = Label.new()
	caption.position = Vector2(26,6)
	var preview_font := SystemFont.new()
	preview_font.font_names = PackedStringArray(["Yu Gothic UI","Meiryo","sans-serif"])
	caption.add_theme_font_override("font",preview_font)
	caption.add_theme_font_size_override("font_size",24)
	bar.add_child(caption)
	var badge := Label.new()
	badge.text = "動作確認用の自動プレイ / 通常速度 / 音声なし"
	badge.position = Vector2(26,47)
	badge.add_theme_font_override("font",caption.get_theme_font("font"))
	badge.add_theme_font_size_override("font_size",14)
	bar.add_child(badge)
	capturing = true
	title("友達と、予算600コインの映画制作会社を始める")
	await frames(120)
	menu.solo_button.pressed.emit()
	await frames(12)
	game = menu.game_node
	game._headless = true
	game.h_select_cast(1)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	title("事務所で依頼を選ぶ。今日は野外で『夜の城』を撮る")
	await frames(150)
	game.h_accept_job(2)
	for option in ["fx","refill","dolly","fix"]: game.h_order_set(option,1)
	title("借りる道具を予算内で選ぶ。足りないセットは無料の廃材で")
	await frames(180)
	game.h_order_confirm()
	var wanted := {"plywood":2,"riser":1,"moon":1,"dolly":1,"dragon_skull":1,"witch_cauldron":1}
	var props: Dictionary = {}
	for prop in game.props.values():
		if prop.absent or not wanted.has(prop.kind): continue
		var list: Array = props.get(prop.kind,[])
		if list.size() >= wanted[prop.kind]: continue
		list.append(prop)
		props[prop.kind] = list
		game.host_load(prop,game.truck)
	game.local_player().aim_yaw = atan2(-8.0,-13.0)
	title("道具も廃材も軽トラへ。走り出しと土煙もゲーム内の動作")
	Input.action_press("move_forward")
	Input.action_press("run")
	await frames(160)
	Input.action_release("move_forward")
	Input.action_release("run")
	await frames(60)
	game.local_player().position = game.production.HOME_TRUCK + Vector3(-3,0.1,0)
	game.h_depart()
	title("全員がそろったら出発。積んだ物だけが現場に届く")
	await frames(490)
	title("現場の借り時間は10分。設営も撮り直しも、この時間の中で")
	await frames(180)
	await physics_frame
	game.input_locked = true
	var dolly: Node = props["dolly"][0]
	place(dolly,Vector3(0,0,6.2),PI)
	place(game.film,Vector3(0,dolly.deck_top,6.2))
	game._set_rider(game.film,dolly,dolly.global_transform.affine_inverse()*game.film.global_transform)
	place(game.spots[0],Vector3(-3.6,0,2.6),PI)
	place(game.spots[1],Vector3(3.6,0,2.6),PI)
	place(game.fx,Vector3(-2.7,0,-6.4))
	place(props["riser"][0],Vector3(0,0,-3))
	place(props["plywood"][0],Vector3(-0.8,0,-3.75))
	place(props["plywood"][1],Vector3(0.8,0,-3.75))
	place(props["moon"][0],Vector3(3.6,0,-5.8))
	place(props["dragon_skull"][0],Vector3(2.8,0,-2.8))
	place(props["witch_cauldron"][0],Vector3(-2.5,0,-3.6))
	place(game.actors[0].mark,Vector3(0,0.97,-3))
	place(game.actors[1].mark,Vector3(1.5,0.05,-1))
	game._aim_camera(Vector3(0.5,1.55,-2.6),50.0)
	game._aim_spot(game.spots[0],Vector3(0,2.25,-3))
	game._aim_spot(game.spots[1],Vector3(1.5,1.2,-1))
	game.local_player().position = Vector3(8,0.1,6.5)
	game.local_player().aim_yaw = 0.0
	game.local_player().aim_pitch = -0.18
	for actor in game.actors: actor.set_state(actor.St.STANDBY)
	title("カメラに映る所だけ城を作る。配置はこの動画の確認用に自動化")
	await frames(180)
	print("PREVIEW_SETUP ",game.film.global_position," ",game.actors[0].mark.global_position," ",game.judge.look())
	game.h_grab(game.clapper.pid)
	game.h_use()
	title("カチンコを持って本番！ 告白 → 背後の爆発 → 再会")
	await frames(200)
	game.h_release()
	game.h_cue(1)
	await frames(230)
	game.h_cue(2)
	title("爆発の合図も制作班の仕事。タイミングと置き場所で映画になる")
	await frames(160)
	game.h_cue(3)
	while game.state == game.S.TAKE: await frames(15)
	print("PREVIEW_RESULT ",game.takes)
	assert(not false in game.takes[0].passed)
	title("三場面成立！ 撮れた映画をその場で見返す")
	await frames(180)
	game.h_replay(0)
	while game.state == game.S.REPLAY: await frames(15)
	game.h_deliver(0)
	title("納品して報酬を受け取る。追加注文『月を2秒映す』も達成")
	await frames(240)
	assert(game.production.last_payment == 1350)
	game.h_return_office()
	title("会社へ戻り、次の一本へ。失敗したテイクでも納品して続けられる")
	await frames(180)
	capturing = false
	print("PREVIEW_OK frames=",frame_id," duration=",float(frame_id)/30.0)
	menu.return_to_menu()
	await frames(8)
	quit()

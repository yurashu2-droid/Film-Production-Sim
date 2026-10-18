extends SceneTree
# スプレーの見え方を、時刻ごとに撮る（docs/production/spray-paint-study.md の設計の確かめ）。
#   吹き始め → 吹いている最中（横に払う）→ 止めたあと霧が沈んで消える → 板の跡の寄り
#   godot --path godot --fixed-fps 60 --script res://tests/spray_shot.gd   （画面ありで流す。tests/shots/spray/ に保存）
var game: Node
const OUT := "res://tests/shots/spray/"


func _initialize() -> void:
	create_timer(90).timeout.connect(func(): quit(2))
	run.call_deferred()


func frames(count: int) -> void:
	for i in count:
		await physics_frame


func snap(cam: Camera3D, name: String) -> void:
	cam.make_current()
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT + name + ".png")


func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	game = load("res://production_game.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	while not game.startup_complete:
		await process_frame
	await frames(20)
	var kit: Node = game.hooks.feature("spray_sign")
	var flow: Node = game.production
	flow.company = "ドタバタ映像社"
	var me: Node3D = game.local_player()
	var sheet: RigidBody3D = kit.sheets[0]
	var at := Vector3(70.0, 0.05, 11.0)
	sheet.restore([at + Vector3(0, 0.45, 0), Quaternion.IDENTITY, true])      # 箱馬の上に貼ったくらいの高さ
	var can: RigidBody3D = kit.cans[1]          # 赤
	me.global_position = at + Vector3(0.0, 0.1, 1.2)
	can.restore([me.global_position + Vector3(0.3, 0, 0), Quaternion.IDENTITY, false])
	await frames(10)
	# 缶の寄り（置いてある所）
	var close := Camera3D.new()
	close.fov = 40
	root.add_child(close)
	var stand: Vector3 = me.global_position
	me.global_position = at + Vector3(3.0, 0.1, 3.0)          # 缶の寄りを撮る間は、体をよける
	can.restore([at + Vector3(0.6, 0.05, 0.6), Quaternion.IDENTITY, true])
	await frames(5)
	var c0: Vector3 = can.global_position
	close.global_position = c0 + Vector3(0.18, 0.16, 0.24)
	close.look_at(c0 + Vector3(0, 0.1, 0))
	await snap(close, "can")
	me.global_position = stand
	can.restore([stand + Vector3(0.3, -0.05, 0), Quaternion.IDENTITY, false])
	await frames(5)
	me.vis.rotation.y = PI          # 体も板の方へ向ける（視点の向きだけでなく。缶を持つ手が板の側に来る）
	game.h_grab(can.pid)
	await frames(3)
	game.h_hold_command("pull")      # G：起こして手元へ（地面からつかんだ物は、つかんだ高さのままなので）
	await frames(20)
	me.set_first_person(true)          # 一人称（缶が手元の前に来る。ふつうに遊ぶときの吹き方）
	await frames(10)
	me.aim_yaw = 0.0
	for k in 50:
		me.aim_pitch = -0.2 - float(k) * 0.02
		await process_frame
		if not kit._aim(me).is_empty():
			break
	var pitch0: float = me.aim_pitch - 0.12      # 最初に当たるのは板の上の縁なので、少し下（真ん中寄り）を狙う
	me.aim_pitch = pitch0
	await process_frame
	# 横から見るカメラ（缶の口から板までの霧が見える）
	var side := Camera3D.new()
	side.fov = 50
	root.add_child(side)
	# 缶の口と板の間を、真横（左）から写す
	var aim: Dictionary = kit._aim(me)
	var mid: Vector3 = (can.nozzle_global() + (aim["at"] if not aim.is_empty() else at + Vector3(0, 0.4, 0))) * 0.5
	side.global_position = at + Vector3(-0.75, 0.85, 0.15)
	side.look_at(mid)
	var eye := Camera3D.new()
	eye.fov = 70
	root.add_child(eye)
	var t := 0.0
	var shots := [0.1, 0.35, 0.8]
	Input.action_press("operate")
	while t < 1.1:
		me.aim_yaw = sin(t * 5.0) * 0.16
		me.vis.rotation.y = me.aim_yaw + PI
		me.aim_pitch = pitch0 + sin(t * 2.3) * 0.04
		await process_frame
		t += 1.0 / 60.0
		if not shots.is_empty() and t >= float(shots[0]):
			var when := int(float(shots.pop_front()) * 100)
			await snap(side, "mist_%02d" % when)
			# 一人称の絵：頭の位置・向きのカメラで、自分の体と一人称の腕を隠して撮る（缶と霧が見える）
			eye.global_transform = game.hold_view_anchor(me)
			me.vis.visible = false
			await snap(eye, "fp_%02d" % when)
			me.vis.visible = true
	Input.action_release("operate")
	for after: float in [0.15, 0.45, 0.9, 1.4]:
		while t < 1.1 + after:
			await process_frame
			t += 1.0 / 60.0
		await snap(side, "mist_end_%03d" % int(after * 100))
	var front := Camera3D.new()
	front.fov = 45
	root.add_child(front)
	front.global_position = at + Vector3(0.0, 0.9, 1.25)
	front.look_at(at + Vector3(0, 0.83, 0))
	me.global_position = at + Vector3(2.5, 0.1, 2.5)
	await frames(3)
	await snap(front, "marks")
	print("SPRAY_SHOT_OK")
	quit(0)

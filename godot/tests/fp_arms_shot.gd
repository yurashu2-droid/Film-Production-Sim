extends SceneTree
# 一人称の腕が、画面をどれだけ覆うか（キャラごと・場面ごと）を測って、絵を残す。
#   場面：手ぶら / 小物を手持ち（スプレー缶を G）/ 大きな物を持つ（箱馬）
#   腕だけを写した絵で、腕の画素の割合を数える。ふつうの絵も一緒に残す（tests/shots/fp_arms/）
#   godot --path godot --fixed-fps 60 --script res://tests/fp_arms_shot.gd   （画面ありで流す）
#   FP_ARMS_MAX=0.2 を付けると、どれかが超えたら失敗にする
var game: Node
const OUT := "res://tests/shots/fp_arms/"
var worst := 0.0


func _initialize() -> void:
	create_timer(240).timeout.connect(func(): quit(2))
	run.call_deferred()


func frames(count: int) -> void:
	for i in count:
		await physics_frame


func shoot(me: Node, name: String) -> float:
	var cam: Camera3D = me.cam
	cam.make_current()
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT + name + ".png")
	# 腕だけ：映す層を腕の層にし、背景を黒にして数える
	var mask := cam.cull_mask
	var env := cam.environment
	var black := Environment.new()
	black.background_mode = Environment.BG_COLOR
	black.background_color = Color.BLACK
	black.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	black.ambient_light_color = Color.WHITE
	cam.environment = black
	cam.cull_mask = me.FirstPersonArms.LAYER
	game.hud.root.visible = false
	var hud2: Node = game.get("production_hud")
	var hud2_visible := true
	if hud2 != null:
		hud2_visible = hud2.root.visible
		hud2.root.visible = false
	await process_frame
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	cam.cull_mask = mask
	cam.environment = env
	game.hud.root.visible = true
	if hud2 != null:
		hud2.root.visible = hud2_visible
	var hit := 0
	var total := 0
	for y in range(0, img.get_height(), 6):
		for x in range(0, img.get_width(), 6):
			total += 1
			if img.get_pixel(x, y).v > 0.04:
				hit += 1
	var share := float(hit) / float(total)
	worst = maxf(worst, share)
	print("FP_ARMS %s 腕が画面を覆う割合 %.1f%%" % [name, share * 100.0])
	return share


func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	game = load("res://production_game.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	while not game.startup_complete:
		await process_frame
	await frames(20)
	var me: Node3D = game.local_player()
	var spot := Vector3(66.0, 0.1, 12.0)
	var can: RigidBody3D = game.hooks.feature("spray_sign").cans[0]
	var box: RigidBody3D = null
	for p: Node in game.props.values():
		if p.kind == "applebox" and not p.absent:
			box = p
			break
	for tag: String in game.PLAYER_CASTS:
		me.set_cast(tag)
		await frames(5)
		me.set_first_person(false)
		me.set_first_person(true)
		me.global_position = spot
		me.vis.rotation.y = PI
		me.aim_yaw = 0.0
		me.aim_pitch = -0.1
		await frames(30)
		await shoot(me, "%s_bare" % tag)
		can.restore([spot + Vector3(0.2, -0.05, -0.5), Quaternion.IDENTITY, false])
		await frames(5)
		game.h_grab(can.pid)
		await frames(3)
		game.h_hold_command("pull")
		await frames(40)
		await shoot(me, "%s_hand" % tag)
		game.host_release(can)
		can.restore([spot + Vector3(3, 0, 3), Quaternion.IDENTITY, false])
		await frames(5)
		if box != null:
			box.restore([spot + Vector3(0.0, -0.05, -0.9), Quaternion.IDENTITY, false])
			await frames(5)
			game.h_grab(box.pid)
			await frames(3)
			game.h_hold_command("pull")
			await frames(40)
			await shoot(me, "%s_box" % tag)
			game.host_release(box)
			box.restore([spot + Vector3(-3, 0, 3), Quaternion.IDENTITY, false])
			await frames(5)
	var limit := float(OS.get_environment("FP_ARMS_MAX")) if OS.get_environment("FP_ARMS_MAX") != "" else 1.0
	print("FP_ARMS いちばん覆った割合 %.1f%%" % (worst * 100.0))
	print("FP_ARMS_FAIL" if worst > limit else "FP_ARMS_OK")
	quit(1 if worst > limit else 0)

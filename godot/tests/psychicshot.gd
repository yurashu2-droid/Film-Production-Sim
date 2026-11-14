extends SceneTree
# 念力（vfx/vfx_psychic.gd）の見た目の型を、同じ構図・同じ時刻で撮って並べる。画面つきで実行する。
#   -- --styles=nenpa,giza   撮る型（省くと全部）
#   -- --times=0.5,1.5,2.6,4.5    撮る時刻（秒）
#   -- --view=close|wide|back     close＝物に寄る ／ wide＝手から物まで ／ back＝持ち手の後ろ（ゲームの三人称に近い）
#   -- --model=box|basket|fish|flat   -- --tag=名前（保存名 psychic_<名前>.png）
const Demo := preload("res://vfx/vfx_psychic_demo.gd")
const HAND := Vector3(-4.15, 1.05, 0.5)
const CELL := Vector2i(800, 450)

func _initialize() -> void:
	run.call_deferred()
	create_timer(170.0, true, false, true).timeout.connect(func(): quit(2))

func run() -> void:
	var styles: Array = Demo.Psychic.STYLES.keys()
	var times: Array = [0.5, 1.5, 2.6, 4.5]
	var view := "close"
	var model := "box"
	var tag := "styles"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--styles="):
			styles = Array(arg.trim_prefix("--styles=").split(","))
		elif arg.begins_with("--times="):
			times = []
			for part in arg.trim_prefix("--times=").split(","):
				times.append(part.to_float())
		elif arg.begins_with("--view="):
			view = arg.trim_prefix("--view=")
		elif arg.begins_with("--model="):
			model = arg.trim_prefix("--model=")
		elif arg.begins_with("--tag="):
			tag = arg.trim_prefix("--tag=")
	var lab: Node = load("res://vfx_lab.tscn").instantiate()
	root.add_child(lab)
	current_scene = lab
	await process_frame
	lab.loop_enabled = false
	lab._hud.visible = false
	lab.set_process_unhandled_input(false)
	# ラボが最初に出す演出（爆発）が出切るのを待って、片付ける
	for i in 70:
		await process_frame
	var camera: Camera3D = lab._camera
	var sheet := Image.create(CELL.x * times.size(), CELL.y * styles.size(), false, Image.FORMAT_RGB8)
	for s in styles.size():
		for old in get_nodes_in_group("vfx"):
			old.queue_free()
		await process_frame
		var demo: Node3D = Demo.spawn(lab, HAND, model, Demo.Psychic.TINT, styles[s])
		for i in times.size():
			while is_instance_valid(demo) and demo.age < float(times[i]):
				await process_frame
			var at: Vector3 = demo._prop.global_position if is_instance_valid(demo) else Vector3(0, 1, 0)
			match view:
				"wide":
					camera.global_position = Vector3(-1.2, 2.3, 7.2)
					camera.look_at(Vector3(-1.2, 1.3, 0.3))
				"back":
					var ahead := (at - HAND)
					ahead.y = 0.0
					ahead = ahead.normalized()
					camera.global_position = HAND - ahead * 3.6 + Vector3(0, 1.5, 0)
					camera.look_at(HAND + ahead * 3.0 + Vector3(0, 0.3, 0))
				_:
					camera.global_position = at + Vector3(0.4, 0.4, 1.9)
					camera.look_at(at + Vector3(0, 0.05, 0))
			await RenderingServer.frame_post_draw
			var frame := root.get_texture().get_image()
			frame.convert(Image.FORMAT_RGB8)
			frame.resize(CELL.x, CELL.y, Image.INTERPOLATE_BILINEAR)
			sheet.blit_rect(frame, Rect2i(Vector2i.ZERO, CELL), Vector2i(i * CELL.x, s * CELL.y))
		print("PSYCHIC_SHOT ", styles[s])
	var dir := ProjectSettings.globalize_path("res://tests/shots/vfx_review")
	DirAccess.make_dir_recursive_absolute(dir)
	sheet.save_png(dir.path_join("psychic_" + tag + ".png"))
	# 片付けてから終わる：共通部品の置き場（vfx_lib.gd）を空にしないと、終了時に「解放されていない」という警告が出る
	lab.queue_free()
	await process_frame
	await process_frame
	Demo.Psychic.Lib._cache.clear()
	quit(0)

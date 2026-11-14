extends SceneTree
# お金まわりの画面を撮る：帯の家賃・依頼カードの制作費・打ち合わせ・借りる画面・精算（通常／家賃／倒産）・アップグレード画面。
#   godot --path godot --script res://tests/moneyshot.gd      （接尾辞は環境変数 UISHOT_SUFFIX、解像度は --resolution）
var game: Node


func _initialize() -> void:
	run.call_deferred()


func snap(tag: String) -> void:
	for i in 14:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://tests/shots/money/%s%s.png" % [tag, OS.get_environment("UISHOT_SUFFIX")])


func run() -> void:
	game = load("res://production_game.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	while not game.startup_complete:
		await process_frame
	for i in 60:
		await physics_frame
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://tests/shots/money"))
	var flow: Node = game.production
	var me: Node = game.local_player()
	# 本番と同じ決まり（日替わりの廃材・家賃あり）で撮る
	flow.daily = true
	flow.hazards = true
	flow.day = 2
	flow.restock()
	game.production_sync.rpc(flow.snapshot())
	await snap("1_office_strip")
	game.open_menu("board")
	await snap("2_board")
	game.open_brief(4)
	for i in 240:
		await process_frame
	await snap("3_brief")
	game.close_menu()
	game.h_accept_job(0)
	game.h_open_order()
	game.h_order_set("fx", 1)
	game.h_order_set("dolly", 1)
	await snap("4_catalog")
	game.h_order_set("balcony", 1)      # 制作費を超えるので断られる
	await snap("4b_catalog_over")
	game.h_order_confirm()
	me.global_position = flow.HOME_TRUCK + Vector3(-3, 0.1, 0)
	for i in 30:
		await physics_frame
	game.open_menu("packing")
	await snap("4c_packing")
	game.close_menu()
	game.h_depart()
	for i in 900:
		if flow.phase == 4:
			break
		await physics_frame
	print("MONEYSHOT phase=", flow.phase)
	flow.expire()
	for i in 10:
		await physics_frame
	game.h_deliver(0)
	for i in 60:
		await process_frame
	await snap("5_settle")
	flow.day = 3
	flow.wallet = 1500
	flow.settle(0)
	await snap("6_settle_rent")
	flow.day = 6
	flow.wallet = 0
	flow.settle(0)
	await snap("7_bankrupt")
	game.h_return_office()
	for i in 30:
		await physics_frame
	await snap("8_new_company")
	flow.wallet = 900
	flow.day = 3
	game.production_sync.rpc(flow.snapshot())
	me.global_position = Vector3(69.6, 0.1, -3.2)
	me.aim_yaw = 0.0
	me.aim_pitch = 0.1
	for i in 40:
		await physics_frame
	await snap("9_display")
	print("MONEYSHOT_OK wallet=", flow.wallet, " day=", flow.day)
	quit()

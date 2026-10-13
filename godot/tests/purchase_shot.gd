extends SceneTree
# 発注画面の「借りる／買う／持っている」を撮る。出力は tests/shots/purchase/
#   godot --path godot --position -32000,-32000 --audio-driver Dummy --script res://tests/purchase_shot.gd
var game: Node


func _initialize() -> void:
	run.call_deferred()


func snap(tag: String) -> void:
	for i in 12:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://tests/shots/purchase/%s.png" % tag)


func run() -> void:
	game = load("res://production_game.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	while not game.startup_complete:
		await process_frame
	for i in 40:
		await physics_frame
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://tests/shots/purchase"))
	var flow: Node = game.production
	seed(7)
	flow.daily = true
	flow.restock()
	game.h_accept_job(0)
	game.h_open_order()
	# 1：何も選んでいない（貯金600。バルコニーと爆弾は、買うには貯金が足りない）
	await snap("1_choose")
	# 2：爆弾を借りる・台車を買う・火薬の袋を2つ
	game.h_order_set("fx", 1)
	game.h_order_buy("dolly", true)
	game.h_order_set("refill", 2)
	await snap("2_rent_and_buy")
	# 3：注文を決めたあとで、もう一度開く（台車は「持っている」）
	game.h_order_confirm()
	game.h_open_order()
	game.h_order_set("fx", 1)
	await snap("3_owned")
	# 4：貯金がほとんど無いとき（買うは、どれも押せない）
	flow.wallet = 60
	game.h_order_set("fx", 0)
	await snap("4_poor")
	# 5：会社の庭。買った台車が、軽トラの横に置いてある
	flow.wallet = 280
	game.h_order_confirm()
	var me: Node = game.local_player()
	me.position = flow.HOME_TRUCK + Vector3(-7.5, 0.1, -1.5)
	for i in 30:
		await physics_frame
	var dolly: Node = null
	for prop: Node in game.props.values():
		if prop.kind == "dolly":
			dolly = prop
	print("PURCHASE_SHOT dolly at ", dolly.global_position, " absent=", dolly.absent)
	var cam := Camera3D.new()
	root.add_child(cam)
	cam.global_position = dolly.global_position + Vector3(-3.2, 2.2, 3.6)
	cam.look_at(dolly.global_position + Vector3(0, 0.4, 0))
	cam.make_current()
	await snap("5_owned_in_yard")
	# 6：精算。買った物の出費（貯金から）が、内訳に1行出る
	flow.expire()
	for i in 6:
		await physics_frame
	flow.settle(0)
	await snap("6_settled")
	print("PURCHASE_SHOT_OK")
	quit()

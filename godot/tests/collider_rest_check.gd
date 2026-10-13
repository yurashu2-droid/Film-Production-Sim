extends SceneTree
# 並んでいる物が、起動してから勝手に動かない・倒れない・震えないことを数で確かめる。
# 当たり判定を直したあと、置き場所で隣の物とめり込んでいないかを見るのに使う。
#   会社（事務所・廃材置き場・軽トラのまわり）：
#     godot --headless --path godot --fixed-fps 60 --script res://tests/collider_rest_check.gd
#   撮影だけモードの倉庫：
#     godot --headless --path godot --fixed-fps 60 --script res://tests/collider_rest_check.gd -- --legacy
# 行は "COLLIDER_REST <場面> <種類> ... OK/NG"、最後に COLLIDER_REST_CHECK_OK / COLLIDER_REST_CHECK_FAIL。
const MOVE_LIMIT := 0.10        # 置いた場所からの横のずれ（m）
const DROP_LIMIT := 0.12        # 置いた高さからのずれ（m）。少し浮かせて置いた物が落ち着くぶんは許す
const TILT_LIMIT := 5.0         # 傾き・向きの変化（度）
const SPEED_LIMIT := 0.05       # 落ち着いたあとの速さ（m/秒）
const SPIN_LIMIT := 0.2         # 落ち着いたあとの回転（ラジアン/秒）

var game: Node
var bad := 0


func _initialize() -> void:
	run.call_deferred()


func frames(count: int) -> void:
	for i in count:
		await physics_frame


func run() -> void:
	var legacy := "--legacy" in OS.get_cmdline_user_args()
	game = (load("res://main.tscn" if legacy else "res://production_game.tscn") as PackedScene).instantiate()
	root.add_child(game)
	current_scene = game
	if not legacy:
		# 会社の場面は、何コマかに分けて組み立てる。組み上がるまで待つ
		while not game.startup_complete:
			await process_frame
	await frames(4)
	await watch("倉庫" if legacy else "事務所")
	if not legacy:
		# 依頼を受けると、廃材置き場の門が開き、物が置き場所へ並び直す
		game.h_accept_job(0)
		await frames(4)
		await watch("受注後")
	print("COLLIDER_REST_CHECK_OK" if bad == 0 else "COLLIDER_REST_CHECK_FAIL 動いた物=%d" % bad)
	quit(0 if bad == 0 else 1)


# いまの置き方を覚えて、6秒待ち、ずれと最後の2秒の動きを見る
func watch(scene: String) -> void:
	var start := {}
	for pid: int in game.props:
		var prop: RigidBody3D = game.props[pid]
		if prop.absent or prop.kind == "mark" or prop.immovable:
			continue
		start[pid] = prop.global_transform
	await frames(240)
	var fastest := {}
	var spin := {}
	for pid: int in start:
		fastest[pid] = 0.0
		spin[pid] = 0.0
	for i in 120:
		await physics_frame
		for pid: int in start:
			var prop: RigidBody3D = game.props[pid]
			fastest[pid] = maxf(fastest[pid], prop.linear_velocity.length())
			spin[pid] = maxf(spin[pid], prop.angular_velocity.length())
	var moved_count := 0
	for pid: int in start:
		var prop: RigidBody3D = game.props[pid]
		if prop.absent:
			continue
		var from: Transform3D = start[pid]
		var slide := Vector2(prop.global_position.x - from.origin.x, prop.global_position.z - from.origin.z).length()
		var drop := prop.global_position.y - from.origin.y
		var tilt := rad_to_deg(from.basis.y.normalized().angle_to(prop.global_basis.y.normalized()))
		var turn := rad_to_deg(from.basis.z.normalized().angle_to(prop.global_basis.z.normalized()))
		var ok: bool = slide < MOVE_LIMIT and absf(drop) < DROP_LIMIT and tilt < TILT_LIMIT and turn < TILT_LIMIT and fastest[pid] < SPEED_LIMIT and spin[pid] < SPIN_LIMIT
		if not ok:
			bad += 1
			moved_count += 1
		# 動いた物は必ず、動かなかった物は少しでもずれていれば書く
		if not ok or slide > 0.02 or absf(drop) > 0.06 or tilt > 1.0:
			print("COLLIDER_REST %s %-16s 横=%.3fm 高さ=%+.3fm 傾き=%.1f度 向き=%.1f度 速さ=%.3f 回転=%.3f 場所=(%.1f, %.2f, %.1f) %s" % [
				scene, prop.kind, slide, drop, tilt, turn, fastest[pid], spin[pid], prop.global_position.x, prop.global_position.y, prop.global_position.z, "OK" if ok else "NG"])
	print("COLLIDER_REST_SUMMARY %s 見た物=%d 動いた物=%d" % [scene, start.size(), moved_count])

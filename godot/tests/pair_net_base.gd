extends Node
# 二人通信の確認の共通部分。ホスト1＋参加者1を、本番と同じ ENet・RPC で繋いで確かめる。
#   派生側が決めること：configure()（prefix・port・flag・budget）/ after_game() / host_action() / view() / client_run()
#   起動：ホストは --<flag>-host、参加者は --<flag>-client（flag に test を入れておく。廃材の日替わりと育成データの保存が止まる）
#   成功の合図は <prefix>_TEST_OK、チェックの行は <prefix>_CHECK <説明> OK/FAIL
# 待ち合わせは固定の待ち時間にせず、届くまで待つ（until）。
# 「何も起きなかった」ことは、ホストの返事を受け取ってから確かめる：
#   参加者→ホストの通信は順序どおりなので、先に送った命令は、返事より前にホストが処理し終えている。
#   ホスト→参加者の確実な通信（ev・production_sync・rx_draw など）も、その返事より前に届き終えている。
#   物の位置や爆弾の火薬などは、順序の保証がない世界の同期で届くので、until で待つ。

# 待つ秒数。届けばすぐ終わるので、長めにしておく（世界の同期は、全部の物を送り直す約1.3秒ごとの周期にも頼る）
const WAIT := 8.0
const LATE := 30.0           # 入り直した直後：接続の立ち上がりで、順序の保証がない通信が間引かれ、物の状態が数秒遅れて届くことがある

var prefix := "PAIR_NET"
var port := 24850
var flag := "pair-net-test"
var budget := 60.0            # この秒数を超えたら、失敗として終わる

var game: Node
var host := false
var failed := false
var done := false
var checks := 0

var _started := 0
var _serial := 0
var _replies := {}
var _queue: Array = []
var _busy := false
var _finishing := false


# ---- 派生側で書き換える所 ----

func configure() -> void:
	pass


# ゲームができた直後（ホストも参加者も、再接続のたびに呼ばれる）
func after_game() -> void:
	pass


# ホストだけ：参加者の依頼（request）に応える。返事には、そのあとの view() が自動で付く
func host_action(_action: String, _arg: Variant, _who: int) -> Dictionary:
	return {}


# その人の画面に見える状態。ホストの返事と、参加者の手元を見比べるのに使う
func view() -> Dictionary:
	return {}


# 参加者だけ：確かめる手順
func client_run() -> void:
	pass


# ---- 進行 ----

func _ready() -> void:
	configure()
	host = ("--%s-host" % flag) in OS.get_cmdline_user_args()
	_started = Time.get_ticks_msec()
	run.call_deferred()


func _process(_delta: float) -> void:
	# ホストは先に起動していて、参加者の終わりを待つので、少しだけ長く待つ
	var limit: float = budget + (5.0 if host else 0.0)
	if not _finishing and Time.get_ticks_msec() - _started > int(limit * 1000.0):
		_finishing = true
		print(prefix, "_TEST_FAIL timeout (", limit, " s)")
		get_tree().quit(2)
		return
	if not host or _busy or _queue.is_empty():
		return
	_busy = true
	var item: Array = _queue.pop_front()
	var who: int = item[0]
	if item[2] == "done":
		failed = failed or not bool(item[3])
		done = true
		_busy = false
		return
	var data: Dictionary = await host_action(str(item[2]), item[3], who)
	data["view"] = view()
	answer.rpc_id(who, int(item[1]), data)
	_busy = false


func run() -> void:
	var err: int = Net.host(port) if host else Net.join("127.0.0.1", port)
	check(err == OK, "the socket opens on port %d" % port)
	if err != OK:
		get_tree().quit(1)
		return
	# 接続が終わる前にゲームを置いておく。参加者の hello は、ゲーム自身が接続の合図で送る（本番と同じ道）
	await create_game()
	if host:
		print(prefix, "_HOST_READY")
		while not done:
			await wait(0.05)
		await wait(0.3)
	else:
		await wait_joined()
		await client_run()
		ask.rpc_id(1, 0, "done", not failed)
		await wait(0.2)
	await finish()


func create_game() -> void:
	game = load("res://production_game.tscn").instantiate()
	game.name = "Game"
	get_tree().root.add_child(game)
	while not game.startup_complete:
		await get_tree().process_frame
	await after_game()


# 参加者：ホストに繋がり、名簿（roster）が届くまで
func wait_joined() -> void:
	var connected: bool = await until(func() -> bool: return multiplayer.multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED, 15.0)
	check(connected, "the participant connects to the host")
	var listed: bool = await until(func() -> bool: return game.local_player() != null and game.players.size() >= 2, 10.0)
	check(listed, "the crew list reaches the participant")


# 参加者：いったん抜けて、新しく入り直す（途中参加）。ゲームも作り直す
func rejoin() -> void:
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	hush()
	game.queue_free()
	game = null
	await frames(4)
	check(Net.join("127.0.0.1", port) == OK, "the late joiner's socket opens")
	await create_game()
	await wait_joined()


func finish() -> void:
	_finishing = true
	print(prefix, "_TEST_FAIL" if failed else "_TEST_OK", " checks=", checks)
	hush()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	if game != null:
		game.queue_free()
		game = null
	await frames(8)
	get_tree().quit(1 if failed else 0)


# 鳴っている効果音を止める。鳴っている最中に終わると、終了時に「resources still in use」が出る
func hush() -> void:
	var sfx: Node = get_tree().root.get_node_or_null("Sfx")
	if sfx != null:
		sfx.silence_all()


# ---- 通信 ----

@rpc("any_peer", "call_remote", "reliable")
func ask(sequence: int, action: String, arg: Variant = null) -> void:
	if host:
		_queue.append([multiplayer.get_remote_sender_id(), sequence, action, arg])


@rpc("authority", "call_remote", "reliable")
func answer(sequence: int, data: Dictionary) -> void:
	_replies[sequence] = data


# 参加者：ホストに頼んで、返事を待つ。返事の "view" は、頼みを済ませたあとのホストの画面
func request(action: String, arg: Variant = null) -> Dictionary:
	_serial += 1
	var sequence := _serial
	ask.rpc_id(1, sequence, action, arg)
	var started := Time.get_ticks_msec()
	while not _replies.has(sequence):
		if Time.get_ticks_msec() - started > 10000:
			check(false, "the host answers '%s'" % action)
			return {"view": {}}
		await wait(0.02)
	var data: Dictionary = _replies[sequence]
	_replies.erase(sequence)
	return data


# 参加者：ホストの返事の view と同じ物が、自分の画面にも出るまで待って、チェックにする（keys＝見比べる項目）
# 順序の保証がない世界の同期（物の位置・爆弾の火薬など）は、入り直した直後だと数秒かかることがある（LATE を使う）
func sees(theirs: Dictionary, keys: Array, label: String, timeout := WAIT) -> bool:
	var ok: bool = await until(func() -> bool: return agree(view(), theirs, keys), timeout)
	if not ok:
		var mine: Dictionary = view()
		for key: String in keys:
			if not mine.has(key) or not theirs.has(key) or mine[key] != theirs[key]:
				print(prefix, "_DIFF ", label, " [", key, "] host=", var_to_str(theirs.get(key)), " participant=", var_to_str(mine.get(key)))
	check(ok, label)
	return ok


func agree(mine: Dictionary, theirs: Dictionary, keys: Array) -> bool:
	for key: String in keys:
		if not mine.has(key) or not theirs.has(key) or mine[key] != theirs[key]:
			return false
	return true


# ---- 道具 ----

func wait(seconds := 0.05) -> void:
	await get_tree().create_timer(seconds).timeout


func frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame


# 条件が本当になるまで待つ。timeout 秒たってもならなければ false
func until(condition: Callable, timeout := WAIT) -> bool:
	var started := Time.get_ticks_msec()
	while not condition.call():
		if Time.get_ticks_msec() - started > int(timeout * 1000.0):
			return false
		await wait(0.02)
	return true


func check(ok: bool, label: String) -> void:
	checks += 1
	failed = failed or not ok
	print(prefix, "_CHECK ", label, " ", "OK" if ok else "FAIL")


# 種類で探す。物のIDの小さいほうから。ホストと参加者で同じ物になる（生成順が同じ）
func of_kind(kind: String) -> Array:
	var out: Array = []
	for pid: int in game.props:
		if game.props[pid].kind == kind:
			out.append(game.props[pid])
	out.sort_custom(func(a: Node, b: Node) -> bool: return a.pid < b.pid)
	return out


func first(kind: String) -> Node:
	var list: Array = of_kind(kind)
	return list[0] if not list.is_empty() else null


# 依頼の番号（production_flow.gd の JOBS）を、脚本の種類から探す
func job_of(script_name: String) -> int:
	var jobs: Array = game.production.JOBS
	for i in jobs.size():
		if jobs[i]["script"] == script_name:
			return i
	return -1


# ホストだけ：その場所へ置き直して、動かないようにする（見立ての札や距離の確認が、揺れで変わらないように）
func place(prop: Node, pos: Vector3, yaw: float = 0.0) -> void:
	if prop.rider_of != 0:
		game.host_unload(prop)
	var state: Array = prop.get_state()
	state[0] = pos
	state[1] = Quaternion(Vector3.UP, yaw)
	state[2] = true
	prop.restore(state)


# ホストだけ：制作班の誰かを、その場所へ移す（参加者の画面にも同じ移動が届く）
func crew_to(who: int, point: Vector3, yaw: float = 0.0) -> void:
	game.move_crew(point, yaw, who)

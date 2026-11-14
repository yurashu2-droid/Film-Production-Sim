extends Node
# An isolated localhost port keeps this test separate from a running game.
const PORT := 24783
var game: Node
var role := ""
var failed := false
var report: Dictionary = {}
var recorded := false

func _ready() -> void:
	run.call_deferred()
	get_tree().create_timer(25.0).timeout.connect(func(): get_tree().quit(2))

func check(ok: bool, label: String) -> void:
	print("PERFORMANCE_NET_CHECK ",role," ",label," ","OK" if ok else "FAIL")
	failed = failed or not ok

func wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout

@rpc("any_peer","call_remote","reliable")
func client_report(data: Dictionary) -> void:
	report = data

@rpc("authority","call_remote","reliable")
func record_cue() -> void:
	await wait(1.6)
	game.h_perform.rpc_id(1,"slate")
	game.performance.selected_effect = "petals"
	game.performance.request_fx()
	await wait(0.4)
	cue_done.rpc_id(1)

@rpc("any_peer","call_remote","reliable")
func cue_done() -> void:
	recorded = true

@rpc("authority","call_remote","reliable")
func finish(ok: bool) -> void:
	check(ok,"host accepted both effects and replayed recorded effect")
	print("PERFORMANCE_NET_TEST_CLIENT_FAIL" if failed else "PERFORMANCE_NET_TEST_CLIENT_OK")
	get_tree().quit(1 if failed else 0)

func run() -> void:
	if role == "host":
		check(Net.host(PORT) == OK,"host starts on test port")
		game.performance.set_open(true)
		var elapsed := 0.0
		while report.is_empty() and elapsed < 12.0:
			await wait(0.1)
			elapsed += 0.1
		if report.is_empty():
			check(false,"client reports controls")
			get_tree().quit(1)
			return
		var who: int = report["who"]
		check(game.performance.opened and game.performance._last_act.has(who) and game.performance._last_fx.has(who),"host selection panel does not block another crew member")
		check(report["acting"] and report["effect"] and game.players[who].vis.current == "slate", "acting and VFX are visible on both peers")
		game.performance.set_open(false)
		game._begin_take()
		record_cue.rpc_id(who)
		elapsed = 0.0
		while not recorded and elapsed < 6.0:
			await wait(0.1)
			elapsed += 0.1
		check(recorded and game._rec_events.any(func(e: Array): return e[1] == "stage_fx"),"client VFX is stored in host recording")
		game._cut()
		await wait(0.2)
		game.h_replay(0)
		await wait(1.8)
		check(game.performance.fx_root.get_child_count() == 1 and game.performance.fx_root.get_child(0).get_meta("performer") == who,"replay reconstructs client effect")
		finish.rpc_id(who,not failed)
		await wait(0.3)
		print("PERFORMANCE_NET_TEST_HOST_FAIL" if failed else "PERFORMANCE_NET_TEST_HOST_OK")
		get_tree().quit(1 if failed else 0)
	else:
		check(Net.join("127.0.0.1",PORT) == OK,"client starts connection")
		var elapsed := 0.0
		while (game.players.size() < 2 or not game.local_player()) and elapsed < 10.0:
			await wait(0.1)
			elapsed += 0.1
		await wait(0.6)
		check(game.players.size() == 2 and game.local_player().is_local,"client has its own crew member")
		game.h_perform.rpc_id(1,"slate")
		game.performance.selected_effect = "petals"
		game.performance.request_fx()
		# 決まった時間ではなく、演技と効果が自分の画面に出るまで待つ（起動直後は相手の処理が詰まることがある）
		var own: Node = game.local_player()
		var waited := 0.0
		while (own.vis.current != "slate" or game.performance.fx_root.get_child_count() != 1) and waited < 3.0:
			await wait(0.05)
			waited += 0.05
		client_report.rpc_id(1,{"who":Net.my_id(),"acting":own.vis.current == "slate","effect":game.performance.fx_root.get_child_count() == 1})

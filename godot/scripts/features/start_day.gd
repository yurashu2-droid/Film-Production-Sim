extends Node
## 遊んで確かめる用の起動（付けなければ、何もしない。ふつうの遊びには出ない）
##   「-- --day2」：1日目（会社のCM）を飛ばして、2日目から始まる。掲示板に、会社のCM以外の依頼（名場面のパロディなど）が全部出る
##     （ふだんは、評判の格に合わせて毎日3枚）。リポジトリ直下の play_new_jobs.bat から起動する。
##   「-- --debug」：デバッグ用のモード（2026-11-11 ユーザーの指示。play_debug.bat から起動する）
##     ・全部の物が出ている（日替わりで廃材をしまわない。1日目でも会社の備品をしまわない）
##     ・どこへでも行ける（廃材置き場の門が、いつも開いている）・貯金は DEBUG_COINS（「--coins=N」で替える）
##     ・好きな日から：「--day=N」（付けなければ 2日目。1 なら宅配の箱から）。掲示板には依頼が全部出る
##     ・好きな依頼から：「--job=K」（依頼の番号。production_flow.gd の JOBS の並び）。起動したら、その依頼を受けた所から始まる
##     自動確認と動画の撮影からも、apply(["--debug", "--job=3"]) のように呼べる
## 決めるのはホスト（日にち・貯金は、参加者へは会社の状態と一緒に届く）
const DEBUG_COINS := 99999

var game: Node
var debug := false


func setup() -> void:
	apply(OS.get_cmdline_user_args())


func apply(args: Array) -> void:
	if Net.mode == "client" or game.production == null:
		return
	var flow: Node = game.production
	if "--day2" in args and int(flow.day) <= 1:
		flow.day = 2
		flow.all_jobs = true
		flow.park_truck_for_day()
	if not "--debug" in args:
		return
	debug = true
	flow.debug = true
	flow.all_jobs = true
	flow.daily = false
	flow.day = maxi(1, int(_value(args, "--day", "2")))
	flow.wallet = int(_value(args, "--coins", str(DEBUG_COINS)))
	flow.park_truck_for_day()
	flow.restock()                    # 日替わりでしまわないので、廃材は全部出る
	var job := int(_value(args, "--job", "-1"))
	if job >= 0 and job < (flow.JOBS as Array).size():
		_accept_later(job)
	_announce()


# 起動の準備が済んでから、デバッグ用のモードだと知らせる（ふつうの遊びと見分けるため）
func _announce() -> void:
	if not is_inside_tree():
		return
	while not bool(game.get("startup_complete")):
		await get_tree().process_frame
	if game.get("hud") != null and game.hud.has_method("show_toast"):
		game.hud.show_toast("デバッグ用のモード：%d日目・物は全部出ている・門は開いている" % int(game.production.day), game.hud.YELLOW, 5.0)


# 「--name=値」の値（無ければ fallback）
func _value(args: Array, name: String, fallback: String) -> String:
	for arg: Variant in args:
		var s := str(arg)
		if s.begins_with(name + "="):
			return s.get_slice("=", 1)
	return fallback


# 起動の準備が済んでから、その依頼を受ける
func _accept_later(job: int) -> void:
	if not is_inside_tree():
		return
	while not bool(game.get("startup_complete")):
		await get_tree().process_frame
	await get_tree().process_frame
	game.h_accept_job(job)


# 1日目の段取り（features/tutorial_day.gd）が、デバッグ用のモードでは備品をしまわないように見る
func keeps_everything() -> bool:
	return debug

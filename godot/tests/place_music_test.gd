extends SceneTree
# 場所の曲（features/place_music.gd）：
#   ・事務所では事務所の曲、準備（集める・運ぶ・現場）では準備の曲
#   ・カウントダウン・本番・見返しでは、場所の曲を鳴らさない（劇中曲の邪魔をしない）。カットしたら準備の曲へ戻る
#   ・曲のファイル（music_local。公開リポジトリには無い）がある時だけ、実際に鳴っている曲も確かめる
#   godot --headless --path godot --fixed-fps 60 --script res://tests/place_music_test.gd
var game: Node
var failed := false
var Sfx: Node


func _initialize() -> void:
	create_timer(90).timeout.connect(func(): quit(2))
	run.call_deferred()


func check(ok: bool, label: String) -> void:
	print("MUSIC_CHECK ", label, " ", "OK" if ok else "FAIL")
	failed = failed or not ok


func frames(count: int) -> void:
	for i in count:
		await process_frame


func run() -> void:
	Sfx = root.get_node("Sfx")
	game = load("res://production_game.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	while not game.startup_complete:
		await process_frame
	await frames(20)
	var flow: Node = game.production
	var kit: Node = game.hooks.feature("place_music")
	var files: bool = Sfx.has_sound(kit.OFFICE) and Sfx.has_sound(kit.PREP)
	print("MUSIC_FILES ", files)
	check(kit != null, "場所の曲の仕組みがある")
	check(flow.phase == 0 and kit.wanted() == kit.OFFICE, "事務所では、事務所の曲")
	if files:
		check(Sfx.current_music() == kit.OFFICE, "事務所の曲が鳴っている（%s）" % Sfx.current_music())
	flow.phase = 2
	await frames(3)
	check(kit.wanted() == kit.PREP, "依頼を受けて準備に入ると、準備の曲")
	flow.phase = 3
	await frames(3)
	check(kit.wanted() == kit.PREP, "軽トラで運ぶ間も、準備の曲のまま")
	flow.phase = 4
	await frames(3)
	if files:
		check(Sfx.current_music() == kit.PREP, "準備の曲が鳴っている（%s）" % Sfx.current_music())
	# カウントダウン・本番：main.gd が劇中曲を鳴らす（state を変えると main.gd がすぐ本番へ進めるので、待たずに見る）
	game.state = game.S.COUNTDOWN
	check(kit.wanted() == "", "カウントダウンでは、場所の曲を鳴らさない")
	game.state = game.S.TAKE
	check(kit.wanted() == "", "本番中も、場所の曲を鳴らさない")
	# 劇中曲が鳴り続けている間は、場所の曲で上書きしない
	game.state = game.S.RESULT
	if Sfx.has_sound("music_tension"):
		Sfx.play_music("music_tension", 0.0)
		await frames(5)
		check(Sfx.current_music() == "music_tension", "劇中曲が鳴っている間は、上書きしない（%s）" % Sfx.current_music())
		Sfx.stop_music(0.0)
	game.state = game.S.RESULT
	await frames(3)
	check(kit.wanted() == kit.PREP, "カットしたら、準備の曲へ戻る")
	if files:
		check(Sfx.current_music() == kit.PREP, "準備の曲が戻っている（%s）" % Sfx.current_music())
	game.replaying = true          # 見返し（state を REPLAY にすると main.gd が録画を再生しようとするので、印だけ立てる）
	await frames(3)
	check(kit.wanted() == "" and Sfx.current_music() != kit.PREP, "見返しの間は、場所の曲を止める")
	game.replaying = false
	game.state = game.S.PREP
	flow.phase = 0
	await frames(3)
	check(kit.wanted() == kit.OFFICE, "帰社したら、事務所の曲")
	print("MUSIC_TEST_FAIL" if failed else "MUSIC_TEST_OK")
	await frames(2)
	quit(1 if failed else 0)

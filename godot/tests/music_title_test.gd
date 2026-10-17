extends SceneTree
## タイトル画面の曲（UVI で作った曲、music_local/title.res）の確認：
## 曲のファイルがあれば、music_title として読めて、ループの位置が付いていて、流して止められること。
## ファイルが無い環境（公開リポジトリ）では、music_title が無く、タイトル画面は曲を鳴らそうとしないこと。
## タイトル画面のスクリプト（start_menu.gd）が読めること。
## 音の流れ（Music・SFX）ができていて、曲は Music、効果音は SFX へ流れること。タイトルの曲は MUSIC_TRIM の分だけ小さく鳴ること。
var _failed := false


func _fail(msg: String) -> void:
	_failed = true
	print("MUSIC_TITLE_FAIL: ", msg)


func _init() -> void:
	var sfx: Node = load("res://scripts/sfx.gd").new()
	root.add_child(sfx)
	await process_frame
	for bus: String in ["Music", "SFX"]:
		if AudioServer.get_bus_index(bus) == -1:
			_fail("音の流れ %s が無い" % bus)
	for mp: AudioStreamPlayer in sfx._music_players:
		if mp.bus != "Music":
			_fail("曲が Music に流れていない")
	sfx.play("ui_ok")
	var last: Node = sfx._oneshots.back() if not sfx._oneshots.is_empty() else null
	if last == null or last.bus != "SFX":
		_fail("効果音が SFX に流れていない")
	var has_file := ResourceLoader.exists("res://assets/audio/music_local/title.res")
	if has_file != sfx.has_sound("music_title"):
		_fail("music_title の有無が、ファイルの有無と合わない")
	if has_file:
		var st: AudioStreamWAV = sfx.get_stream("music_title")
		if st.loop_mode != AudioStreamWAV.LOOP_FORWARD or st.loop_begin <= 0 or st.loop_end <= st.loop_begin:
			_fail("ループの位置が付いていない")
		print("music_title: %.1f秒 ループ %d〜%d" % [st.get_length(), st.loop_begin, st.loop_end])
		sfx.play_music("music_title", 0.0)
		await process_frame
		if sfx.current_music() != "music_title":
			_fail("流せない")
		var want: float = sfx.MUSIC_DB + float(sfx.MUSIC_TRIM.get("music_title", 0.0))
		if absf(sfx._music_players[sfx._music_cur].volume_db - want) > 0.01:
			_fail("タイトルの曲の音量が補正どおりでない")
		sfx.stop_music(0.0)
		if sfx.current_music() != "":
			_fail("止められない")
	var menu_script: GDScript = load("res://scripts/start_menu.gd")
	if menu_script == null or not menu_script.can_instantiate():
		_fail("start_menu.gd が読めない")
	sfx.silence_all()
	sfx.queue_free()
	await process_frame
	print("MUSIC_TITLE_FAIL" if _failed else "MUSIC_TITLE_OK")
	quit(1 if _failed else 0)

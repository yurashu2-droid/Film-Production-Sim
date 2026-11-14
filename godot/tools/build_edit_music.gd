extends SceneTree
## 編集者の曲（features/editors.gd の名匠・ド派手）を、ゲームで読める形（.res）にする。
## tools/trailer/pr_edit/game_music.py が書き出した tools/trailer/pr_edit/game/edit_*.wav を、QOA で圧縮して res://assets/audio/music_local/ へ（ループなし）。
## UVI の音色から作った曲なので、公開リポジトリには入れない（music_local は .gitignore 済み）。無ければ、編集は無音で流れる。
## 実行：Godot --headless --path godot --script res://tools/build_edit_music.gd
const OUT := "res://assets/audio/music_local/"


func _init() -> void:
	var src := ProjectSettings.globalize_path("res://").path_join("../tools/trailer/pr_edit/game").simplify_path()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	for f: String in DirAccess.get_files_at(src):
		if not f.ends_with(".wav"):
			continue
		var wav := AudioStreamWAV.load_from_file(src.path_join(f), {"compress/mode": 2})
		if wav == null:
			push_warning("build_edit_music: %s を読めない" % f)
			continue
		wav.loop_mode = AudioStreamWAV.LOOP_DISABLED
		var err := ResourceSaver.save(wav, OUT + f.get_basename() + ".res")
		print("build_edit_music: %s  %.2f秒  形式 %d  %s" % [f, wav.get_length(), wav.format, "保存" if err == OK else "保存できない %d" % err])
	quit()

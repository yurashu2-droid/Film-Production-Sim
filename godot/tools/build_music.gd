extends SceneTree
## BGM を、ゲームで読める形（.res）にする：tools/bgm/bgm.py が書き出した tools/bgm/out/game/<名前>.wav と .json（ループの位置）を読み、
## ループの位置を付けて、QOA で圧縮して res://assets/audio/music_local/<名前>.res に保存する（インポートの有無に依存しない。sfx と同じ）。
## wav を Godot のフォルダに置かないのは、Godot が自動で読み込み直して同じ曲を二重に抱えるため。
## music_local は UVI の音色から作った曲なので、公開リポジトリには入れない（.gitignore 済み）。無ければ scripts/sfx.gd は曲を鳴らさない。
## 実行：Godot --headless --path godot --script res://tools/build_music.gd
const OUT := "res://assets/audio/music_local/"


func _init() -> void:
	var src := ProjectSettings.globalize_path("res://").path_join("../tools/bgm/out/game").simplify_path()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var made := 0
	for f: String in DirAccess.get_files_at(src):
		if not f.ends_with(".json"):
			continue
		var name := f.get_basename()
		var info: Variant = JSON.parse_string(FileAccess.get_file_as_string(src.path_join(f)))
		var wav_path := src.path_join(name + ".wav")
		if not info is Dictionary or not FileAccess.file_exists(wav_path):
			push_warning("build_music: %s の wav か json が読めない" % name)
			continue
		var opts := {"compress/mode": 2, "edit/loop_mode": 2,
			"edit/loop_begin": int(info["loop_begin"]), "edit/loop_end": int(info["loop_end"])}
		var wav := AudioStreamWAV.load_from_file(wav_path, opts)
		if wav == null:
			push_warning("build_music: %s を読めない" % name)
			continue
		# 読み込みの設定が効かない版でも、ループの位置は必ず付ける
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = int(info["loop_begin"])
		wav.loop_end = int(info["loop_end"])
		var err := ResourceSaver.save(wav, OUT + name + ".res")
		print("build_music: %s  %.1f秒  ループ %d〜%d  形式 %d  %s" % [name, wav.get_length(), wav.loop_begin, wav.loop_end,
			wav.format, "保存" if err == OK else "保存できない %d" % err])
		made += 1
	print("build_music: %d 曲" % made)
	quit()

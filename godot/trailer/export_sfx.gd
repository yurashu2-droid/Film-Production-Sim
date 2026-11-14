extends SceneTree
## 紹介動画の音づくり用：ゲームの効果音（.res の AudioStreamWAV）を WAV に書き出す。
##   godot --headless --path godot --script res://trailer/export_sfx.gd -- --out=<書き出し先>
func _initialize() -> void:
	var out := ""
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.get_slice("=", 1)
	DirAccess.make_dir_recursive_absolute(out)
	var n := 0
	for dir: String in ["res://assets/audio/sfx/", "res://assets/audio/sfx_local/"]:
		var tag := "local_" if dir.ends_with("local/") else ""
		for f: String in DirAccess.get_files_at(dir):
			if not f.ends_with(".res"):
				continue
			var s: Variant = load(dir + f)
			if s is AudioStreamWAV:
				(s as AudioStreamWAV).save_to_wav("%s/%s%s.wav" % [out, tag, f.get_basename()])
				n += 1
	print("EXPORTED ", n)
	quit(0)

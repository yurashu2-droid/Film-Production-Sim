extends SceneTree
## 紹介動画用：「転がる大岩・予告編」の絵コンテ（scripts/ui/storyboard.gd）を1枚ずつ PNG に書き出す。
##   godot --headless --path godot --script res://trailer/export_board.gd -- --out=<書き出し先>
func _initialize() -> void:
	var out := ""
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.get_slice("=", 1)
	DirAccess.make_dir_recursive_absolute(out)
	var SB = load("res://scripts/ui/storyboard.gd")
	for i in 4:
		var img := Image.new()
		img.load_svg_from_string(SB.svg("trap", i), 3.0)
		img.save_png("%s/trap_%d.png" % [out, i])
	print("BOARD_DONE")
	quit(0)

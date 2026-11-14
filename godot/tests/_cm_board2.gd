extends SceneTree
# 「わが社の紹介動画」の手直し案2の絵コンテ（下書き）：カメラが動く。一人ずつ寄りで決めポーズ → 引きで城と爆発 → 全員集合
#   godot --headless --path godot --script res://tests/_cm_board2.gd
const SB := preload("res://scripts/ui/storyboard.gd")
const W := 480
const H := 270
const PAPER := "#f6f2e6"
const PENCIL := "#2f2f35"
const SOFT := "#8d897e"
const SHADE := "#dcd6c6"
const RED := "#c8503c"
const BLUE := "#3c78c8"


func _initialize() -> void:
	var frames := [_close("hips", "社長", false), _close("wave", "B", false), _close("point", "C", false), _close("", "D", true), _castle_blast(), _all_up()]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://tests/shots/boards/"))
	for i in frames.size():
		var svg := '<svg xmlns="http://www.w3.org/2000/svg" width="%d" height="%d" viewBox="0 0 %d %d"><rect width="%d" height="%d" fill="%s"/>%s<rect x="3" y="3" width="%d" height="%d" fill="none" stroke="%s" stroke-width="3"/></svg>' % [W, H, W, H, W, H, PAPER, frames[i], W - 6, H - 6, PENCIL]
		var img := Image.new()
		img.load_svg_from_string(svg, 1.0)
		img.save_png("res://tests/shots/boards/cm2_%d.png" % (i + 1))
	print("CM_BOARD2 OK")
	quit()


# 棒人間（storyboard.gd の _fig ＋ 指さし）
func _fig(at: Vector2, s: float, pose: String, flip: bool = false) -> String:
	if pose != "point":
		return SB._fig(at, s, pose, flip)
	var out := SB._fig(at, s, "hips", flip)
	# 片手で、カメラ（見ている人）を指さす：手前へ突き出した腕
	out += SB._line([at + Vector2(0, -58) * s, at + Vector2(-12, -60) * s, at + Vector2(-22, -66) * s], PENCIL, 4.5 * s)
	out += '<circle cx="%.1f" cy="%.1f" r="%.1f" fill="%s" stroke="%s" stroke-width="%.1f"/>' % [at.x - 23 * s, at.y - 66.5 * s, 3.2 * s, PAPER, PENCIL, 2.5 * s]
	return out


# 等身大パネル（物で代用した社員）
func _panel(at: Vector2, s: float) -> String:
	var out := '<g transform="translate(%.1f %.1f) scale(%.2f)">' % [at.x, at.y, s]
	out += '<path d="M -16,0 L -14,-54 L -22,-60 L -12,-66 C -16,-90 16,-90 12,-66 L 22,-60 L 14,-54 L 16,0 Z" fill="%s" stroke="%s" stroke-width="3" stroke-dasharray="7 5"/>' % [SHADE, SOFT]
	out += '</g>'
	return out


# 名前のテロップ（画面の下。字は線で）
func _telop(x: float, w: float, red: bool) -> String:
	var out := '<rect x="%.1f" y="206" width="%.1f" height="40" fill="%s" stroke="%s" stroke-width="3"/>' % [x, w, PAPER, PENCIL]
	out += '<rect x="%.1f" y="206" width="12" height="40" fill="%s"/>' % [x, RED if red else BLUE]
	for k in int((w - 40) / 22.0):
		out += SB._line([Vector2(x + 26 + k * 22, 226), Vector2(x + 40 + k * 22, 226)], PENCIL, 4.0)
	return out


# 撮影カメラの印（右上）：寄り・引き
func _cam_mark(close: bool) -> String:
	var out := '<rect x="404" y="18" width="40" height="26" rx="3" fill="%s" stroke="%s" stroke-width="3"/>' % [PAPER, PENCIL]
	out += '<path d="M 444,24 L 458,18 L 458,44 L 444,38 Z" fill="%s" stroke="%s" stroke-width="3"/>' % [PAPER, PENCIL]
	if close:
		out += SB._arrow(Vector2(400, 58), Vector2(370, 80))
	else:
		out += SB._arrow(Vector2(370, 80), Vector2(400, 58))
	return out


# 1〜4 一人ずつ、寄りで決めポーズ（胸から上が大きく映る。名前のテロップ）。いない社員は、パネルの寄り
func _close(pose: String, who: String, panel: bool) -> String:
	var out := ""
	if panel:
		out += _panel(Vector2(240, 440), 4.0)
		out += SB._question(Vector2(240, 60), 1.4, SOFT)
	else:
		out += _fig(Vector2(240, 430), 4.0, pose)
		# ドヤ顔の目と口
		out += SB._line([Vector2(222, 112), Vector2(234, 108)], PENCIL, 4.0) + SB._line([Vector2(246, 108), Vector2(258, 112)], PENCIL, 4.0) + SB._line([Vector2(228, 128), Vector2(240, 133), Vector2(252, 126)], PENCIL, 4.0)
	out += _telop(24, 190 if who == "社長" else 150, who == "社長")
	out += _cam_mark(true)
	return out


# 5 引き：城の前で、社長の背後で爆発。社長は動じない（社員は、びくっ）
func _castle_blast() -> String:
	var out := SB._ground(238)
	out += SB._ghost("M 40,238 L 40,98 L 58,98 L 58,82 L 76,82 L 76,98 L 100,98 L 100,82 L 118,82 L 118,98 L 140,98 L 140,82 L 158,82 L 158,98 L 176,98 L 176,238 Z")
	out += '<path d="%s" fill="%s" stroke="%s" stroke-width="3" stroke-dasharray="9 7"/>' % [SB._burst_path(Vector2(300, 118), 84, 44, 11), SHADE, SOFT]
	out += _fig(Vector2(250, 244), 0.95, "hips")
	out += _fig(Vector2(380, 242), 0.75, "scared", true)
	out += SB._startle(Vector2(380, 172), 0.6)
	out += _cam_mark(false)
	return out


# 6 全員集合：看板の前に駆け寄って、両手を上げる「ぜんぶ、格安で！」
func _all_up() -> String:
	var out := SB._ground(238)
	var c := Vector2(240, 82)
	var w := 300.0
	var h := 96.0
	out += SB._line([Vector2(c.x - w * 0.35, c.y + h * 0.5), Vector2(c.x - w * 0.35, c.y + h * 0.5 + 70)], PENCIL, 4.0)
	out += SB._line([Vector2(c.x + w * 0.35, c.y + h * 0.5), Vector2(c.x + w * 0.35, c.y + h * 0.5 + 70)], PENCIL, 4.0)
	out += '<rect x="%.1f" y="%.1f" width="%.1f" height="%.1f" fill="%s" stroke="%s" stroke-width="3.5"/>' % [c.x - w * 0.5, c.y - h * 0.5, w, h, PAPER, PENCIL]
	var d := "M %.1f,%.1f " % [c.x - w * 0.4, c.y - 6]
	for k in 10:
		d += "q %.1f,%.1f %.1f,0 " % [w * 0.04, -10.0 if k % 2 == 0 else 10.0, w * 0.08]
	out += '<path d="%s" fill="none" stroke="%s" stroke-width="5" stroke-linecap="round"/>' % [d, RED]
	out += _fig(Vector2(120, 244), 0.95, "cheer")
	out += _fig(Vector2(200, 248), 1.05, "cheer")
	out += _fig(Vector2(282, 248), 1.0, "cheer")
	out += _panel(Vector2(362, 244), 1.05)
	out += SB._arrow(Vector2(60, 250), Vector2(96, 250))
	out += _cam_mark(false)
	return out

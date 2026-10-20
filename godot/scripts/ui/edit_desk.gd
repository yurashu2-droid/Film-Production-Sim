extends RefCounted
## テイク確認の部品（hud.gd の _build_result が使う）。
## 撮影カメラの本物の映像から撮ったコマを、フィルムに並べる。場面ごとに、コマの角へ赤いペンで小さく ○ か ×。
## 景色の上にじかに置く（枠・紙・台で包まない）。

const RED := Color("e8392d")


# 景色の上にじかに書く字：黒い縁取りで読めるように
static func outlined_theme() -> Theme:
	var th := Theme.new()
	th.set_constant("outline_size", "Label", 6)
	th.set_color("font_outline_color", "Label", Color(0, 0, 0, 0.85))
	return th


# 撮影中に控えたコマから、場面ごとの1コマを選ぶ。
# 成立した場面は成立した瞬間のコマ、そうでない場面はテイクの尺を場面の数で割った真ん中あたりのコマ
static func pick_stills(frames: Array, passed_at: Dictionary, scenes: int, dur: float) -> Array:
	var out: Array = []
	for i in scenes:
		if passed_at.has(i):
			out.append(passed_at[i])
			continue
		var want := dur * (float(i) + 0.5) / float(maxi(scenes, 1))
		var best: Texture2D = null
		var gap := INF
		for f: Array in frames:
			var d: float = absf(float(f[0]) - want)
			if d < gap:
				gap = d
				best = f[1]
		out.append(best)
	return out


# フィルムの1コマ分（上下の送り穴つき）。隣どうしを並べると、1本のフィルムになる
class Cell extends Control:
	const RED := Color("e8392d")
	var still: Texture2D
	var ok := false
	var number := 1

	func setup(tex: Texture2D, is_ok: bool, n: int, w: float) -> Control:
		still = tex
		ok = is_ok
		number = n
		custom_minimum_size = Vector2(w, w * 9.0 / 16.0 + 34.0)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		return self

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		draw_rect(r, Color("231a12"))
		var hole := Vector2(10, 7)
		var x := 6.0
		while x < size.x - hole.x:
			for y: float in [5.0, size.y - 5.0 - hole.y]:
				draw_rect(Rect2(Vector2(x, y), hole), Color(0.92, 0.88, 0.8, 0.9))
			x += 20.0
		var pic := Rect2(Vector2(6, 17), Vector2(size.x - 12, size.y - 34))
		if still != null:
			draw_texture_rect(still, pic, false)
		else:
			draw_rect(pic, Color("3a3d42"))
			var f := FilmSet.font("mono")
			draw_string(f, pic.position + Vector2(0, pic.size.y * 0.5 + 8), "S%d" % number, HORIZONTAL_ALIGNMENT_CENTER, pic.size.x, 22, Color(1, 1, 1, 0.35))
		# 赤いペンの印（右下に小さく。少し揺れた手描きの線）
		var c := pic.end - Vector2(22, 22)
		if ok:
			var pts := PackedVector2Array()
			for k in 30:
				var a := -1.1 + TAU * 1.1 * float(k) / 29.0
				var rad := 13.0 + sin(float(k) * 1.9 + float(number)) * 1.0
				pts.append(c + Vector2(cos(a), sin(a)) * rad)
			draw_polyline(pts, Color(1, 1, 1, 0.6), 6.0, true)
			draw_polyline(pts, RED, 3.5, true)
		else:
			for seg: Array in [[Vector2(-11, -10), Vector2(10, 11)], [Vector2(10, -11), Vector2(-10, 10)]]:
				draw_line(c + seg[0], c + seg[1], Color(1, 1, 1, 0.6), 6.0, true)
				draw_line(c + seg[0], c + seg[1], RED, 3.5, true)

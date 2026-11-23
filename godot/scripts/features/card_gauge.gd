extends Node
## カードの残り（録画できる残り）を、画面の上の欄（STBY ／ REC の枠。production_hud.gd の _strip）に出す。
## 2026-11-14 ユーザー：「容量バーは上の UI 欄に乗せていい。カメラのそんな所に、バーはふつう無い」。
##   ・STBY ／ REC の字の右に、小さなカードの絵と、横長のバー。撮るほど短くなって、緑 → 黄 → 赤（色は ui/monitor_marks.gd の bar_color）
##   ・残りわずかで、点滅する。数字は出さない
##   ・出すのは、残りを数えている間だけ（場面の列を持つ依頼の、現場。film_camera.gd の film_shown）
## 上の欄のファイルには手を入れず、ここから欄の並びへ差し込む（各自の画面）。
const Marks := preload("res://scripts/ui/monitor_marks.gd")
const UI := preload("res://scripts/ui/ui_theme.gd")

var game: Node
var _box: Control
var _bar: Control


class Bar extends Control:
	var frac := 1.0
	var low := false

	func _ready() -> void:
		custom_minimum_size = Vector2(112, 22)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(_delta: float) -> void:
		if is_visible_in_tree():
			queue_redraw()

	func _draw() -> void:
		var mid := size.y * 0.5
		# カードの絵（角を落とした札と、端子）
		var o := Vector2(0, mid - 8.0)
		var white := Color(UI.CLAP_WHITE, 0.92)
		draw_colored_polygon(PackedVector2Array([o, o + Vector2(8, 0), o + Vector2(12, 4), o + Vector2(12, 16), o + Vector2(0, 16)]), white)
		for i in 3:
			draw_rect(Rect2(o + Vector2(1.5 + 2.6 * float(i), 1.5), Vector2(1.4, 4.0)), Color(0, 0, 0, 0.55))
		# バー：暗い溝と、残りの分
		var track := Rect2(20.0, mid - 4.0, size.x - 20.0, 8.0)
		draw_rect(track, Color(0, 0, 0, 0.5))
		var blink := not low or int(Time.get_ticks_msec() / 130) % 2 == 0
		var color := Marks.bar_color(frac)
		draw_rect(Rect2(track.position, Vector2(track.size.x * clampf(frac, 0.0, 1.0), track.size.y)), Color(color, 1.0 if blink else 0.25))
		draw_rect(track, Color(UI.CLAP_WHITE, 0.55), false, 1.0)


func _process(_delta: float) -> void:
	if game == null:
		return
	if _box == null and not _attach():
		return
	var film: Node = game.get("film")
	var on: bool = film != null and bool(film.film_shown)
	_box.visible = on
	if on:
		_bar.frac = float(film.film_frac)
		_bar.low = bool(film._film_low)


# 上の欄の並び（STBY の字のすぐ右）へ、区切りとバーを差し込む。欄がまだ無ければ false
func _attach() -> bool:
	var hud: Node = game.get("production_hud")
	if hud == null or not hud.get("_strip") is Control or (hud._strip as Control).get_child_count() == 0:
		return false
	var row: Node = (hud._strip as Control).get_child(0)
	if not row is HBoxContainer:
		return false
	_box = HBoxContainer.new()
	_box.name = "CardGauge"
	_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box.add_theme_constant_override("separation", 0)
	_box.add_child(UI.gap(1))
	var pad := Control.new()
	pad.custom_minimum_size = Vector2(12, 0)
	_box.add_child(pad)
	_bar = Bar.new()
	_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_box.add_child(_bar)
	row.add_child(_box)
	row.move_child(_box, mini(2, row.get_child_count() - 1))
	_box.visible = false
	return true

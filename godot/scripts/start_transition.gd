extends CanvasLayer
# 画面の切り替えに使うカチンコ。画面いっぱいの黒板が下からせり上がり、拍子木が「カチン」と閉じて
# 画面を覆う。その裏で次の画面を用意し、用意ができたら拍子木が開いて下へ抜ける。
#   begin()  … せり上がって閉じる。閉じ切ると occluded
#   reveal() … 開いて抜ける。抜け切ると finished
#   cancel() … 途中でやめる
# 小さな3Dモデルを引き伸ばさず、画面の大きさに合わせて2Dで描く（どの解像度でも形が崩れない）。
signal occluded
signal finished

const UI := preload("res://scripts/ui/ui_theme.gd")

const ENTER_TIME := 0.38        # せり上がり
const CLAP_TIME := 0.07         # 拍子木が閉じる
const EXIT_TIME := 0.52         # 開いて抜ける
const OPEN := 0.40              # 拍子木の開き（ラジアン）
const SHUT := 0.0

var active := false
var covered := false
var angle := OPEN               # いまの拍子木の開き
var rise := 1.0                 # 1=画面の下に隠れている、0=定位置
var scene_text := "事務所"      # 黒板の「現場」欄
var take_text := "1"
var note_text := "準備中"

var _board: Control
var _phase := ""
var _time := 0.0
var _sounded := false
var _since_clap := 10.0


func _ready() -> void:
	layer = 100
	_board = _Board.new()
	_board.owner_layer = self
	_board.set_anchors_preset(Control.PRESET_FULL_RECT)
	_board.mouse_filter = Control.MOUSE_FILTER_STOP      # 切り替え中は下の画面を押せない
	add_child(_board)
	visible = false
	set_process(false)


func begin(scene: String = "", take: String = "") -> void:
	cancel()
	if scene != "":
		scene_text = scene
	if take != "":
		take_text = take
	active = true
	covered = false
	_sounded = false
	_phase = "enter"
	_time = 0.0
	_since_clap = 10.0
	angle = OPEN
	rise = 1.0
	visible = true
	set_process(true)
	_board.queue_redraw()


func reveal() -> void:
	if not active or not covered:
		return
	_phase = "exit"
	_time = 0.0
	await finished


func cancel() -> void:
	var was_active := active
	active = false
	covered = false
	_phase = ""
	visible = false
	set_process(false)
	if was_active:
		occluded.emit()
		finished.emit()


# 画面がすき間なく覆われているか（閉じ切って定位置にある）
func is_fully_covering() -> bool:
	return covered and is_zero_approx(rise) and is_equal_approx(angle, SHUT)


# 縞の入った下あごが、画面の中に収まっているか
func bars_in_frame() -> bool:
	var size := _board.size
	var bar := bar_height(size)
	var top := rise * (size.y + bar * 2.0) + bar
	return top >= -1.0 and top + bar <= size.y + 1.0


func bar_height(size: Vector2) -> float:
	return clampf(size.y * 0.105, 56.0, 124.0)


func _process(delta: float) -> void:
	_time += delta
	_since_clap += delta
	match _phase:
		"enter":
			var t := minf(_time / ENTER_TIME, 1.0)
			rise = pow(1.0 - t, 3.0)
			# 閉じる直前に、ほんの少しだけ振りかぶる
			angle = OPEN + 0.07 * smoothstep(0.55, 1.0, t)
			if _time >= ENTER_TIME:
				rise = 0.0
				_phase = "clap"
				_time = 0.0
		"clap":
			var t := minf(_time / CLAP_TIME, 1.0)
			angle = lerpf(OPEN + 0.07, SHUT, t * t)
			if _time >= CLAP_TIME:
				angle = SHUT
				_sounded = true
				_since_clap = 0.0
				Sfx.play("clap", null, -4.0)
				covered = true
				_phase = "hold"
				_time = 0.0
				# 閉じた直後に次の画面を用意し、板の裏で描く
				occluded.emit()
		"hold":
			pass
		"exit":
			var t := minf(_time / EXIT_TIME, 1.0)
			# 先に拍子木がぱっと開き、少し遅れて板ごと下へ抜ける
			angle = OPEN * (1.0 - pow(1.0 - minf(t / 0.3, 1.0), 3.0))
			var drop := clampf((t - 0.16) / 0.84, 0.0, 1.0)
			rise = drop * drop * drop
			if _time >= EXIT_TIME:
				active = false
				covered = false
				visible = false
				set_process(false)
				finished.emit()
				return
	_board.queue_redraw()


# 閉じた瞬間の小さな揺れ（下へ数px沈んで戻る）
func _impact() -> float:
	if _since_clap > 0.3:
		return 0.0
	return 9.0 * exp(-_since_clap * 16.0) * cos(_since_clap * 46.0)


class _Board extends Control:
	var owner_layer: CanvasLayer

	func _draw() -> void:
		var o := owner_layer
		if o == null or not o.active:
			return
		var ui: GDScript = load("res://scripts/ui/ui_theme.gd")
		var w := size.x
		var h := size.y
		var bar: float = o.bar_height(size)
		var ink: Color = ui.INK
		var white: Color = ui.CLAP_WHITE
		var y0: float = o.rise * (h + bar * 2.0) + o._impact()
		var period := bar * 1.7

		# 黒板（下あごの下から画面の下まで。揺れても下が見えないよう少し余分に）
		draw_rect(Rect2(-8, y0 + bar * 2.0 - 1.0, w + 16, h + 80.0), ink)
		_fields(ui, Rect2(0, y0 + bar * 2.0, w, h - bar * 2.0), bar)

		# 下あご（動かない縞）
		ui.draw_stripes(self, Rect2(-8, y0 + bar, w + 16, bar), ink, white, period, 0.0)
		draw_rect(Rect2(-8, y0 + bar * 2.0 - 3.0, w + 16, 3.0), white)

		# 拍子木（左端の蝶番で開く。縞は下あごと逆向き）
		var hinge := Vector2(bar * 0.62, y0 + bar)
		draw_set_transform(hinge, -o.angle, Vector2(1, -1))
		ui.draw_stripes(self, Rect2(-hinge.x - 60.0, 0.0, w + 220.0, bar + 60.0), ink, white, period, period * 0.25)
		draw_rect(Rect2(-hinge.x - 60.0, 0.0, w + 220.0, 3.0), white)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

		# 蝶番の金具
		var plate := Rect2(hinge.x - bar * 0.5, y0 + bar - bar * 0.34, bar, bar * 0.68)
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color("2a2c32")
		sb.border_color = Color("5b5e66")
		sb.set_border_width_all(2)
		sb.set_corner_radius_all(6)
		sb.anti_aliasing = true
		sb.draw(get_canvas_item(), plate)
		draw_circle(hinge, bar * 0.16, Color("8b8e96"))
		draw_circle(hinge, bar * 0.07, Color("2a2c32"))

	# 黒板の記入欄：上に3つの欄、下に題名
	func _fields(ui: GDScript, r: Rect2, bar: float) -> void:
		var o := owner_layer
		var white: Color = ui.CLAP_WHITE
		var muted: Color = ui.MUTED
		var line := Color(white, 0.85)
		var k := clampf(size.y / 900.0, 0.6, 1.6)
		var pad := 56.0 * k
		var row_h := 132.0 * k
		var top := r.position.y + 34.0 * k
		var left := pad
		var right := size.x - pad
		var cell_w := (right - left) / 3.0
		var body: Font = ui.fnt("bold")
		var display: Font = ui.fnt("display")
		var date := Time.get_date_dict_from_system()
		var cells := [["現場　SCENE", o.scene_text], ["テイク　TAKE", o.take_text], ["日付　DATE", "%d.%02d.%02d" % [date["year"], date["month"], date["day"]]]]
		draw_line(Vector2(left, top), Vector2(right, top), line, 2.0)
		draw_line(Vector2(left, top + row_h), Vector2(right, top + row_h), line, 2.0)
		for i in 3:
			var x := left + cell_w * i
			if i > 0:
				draw_line(Vector2(x, top), Vector2(x, top + row_h), line, 2.0)
			draw_string(body, Vector2(x + 22.0 * k, top + 36.0 * k), cells[i][0], HORIZONTAL_ALIGNMENT_LEFT, cell_w - 30.0 * k, int(17 * k), muted)
			draw_string(display, Vector2(x + 22.0 * k, top + 104.0 * k), cells[i][1], HORIZONTAL_ALIGNMENT_LEFT, cell_w - 30.0 * k, int(56 * k), white)
		var mid := top + row_h + (r.end.y - top - row_h) * 0.5
		draw_string(display, Vector2(0, mid + 8.0 * k), "格安アクション映画制作班", HORIZONTAL_ALIGNMENT_CENTER, size.x, int(84 * k), white)
		# 待っている間だけ、点が増えていく
		var dots := ".".repeat(1 + int(o._time * 2.5) % 3) if o._phase == "hold" else ""
		draw_string(body, Vector2(0, mid + 72.0 * k), o.note_text + dots, HORIZONTAL_ALIGNMENT_CENTER, size.x, int(22 * k), muted)

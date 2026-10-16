extends Node
## 場面の列を持つ台本（production_script.gd の "beats"）の、進め方と採点。
## 今までの3場面の依頼は、ここを通らない（judge.gd の3条件と、合図 1・2・3 のまま）。
##
## ・進め方：監督がページをめくる。台本を読める人（持っている・手帳で開いている・置いた台本のすぐそばにいる）だけが、
##   1＝次の場面へ / 2＝今の場面をもう一度、を出せる。決めるのはホスト（host_step）。
##   役者は、場面ごとに決まった印（①②③）へ、決まった動きでまっすぐ進み、着いたら、その姿のまま次の合図を待つ（actor.gd の play_beat）。
##   準備中に進めると、通し稽古になる（フィルムは減らない。採点もしない。爆弾は、今までどおり準備中は鳴らない）。
## ・時計は物：テイクは、フィルム1本（FILM_SEC）で終わる。残りは、撮影カメラの上のリール（film_camera.gd）と、
##   確認用モニターの枠の目盛り（production_monitor_prop.gd）で見せる。残り秒数の数字は、どこにも出さない。
## ・採点：カメラに映った出来事の、順番と関係だけを見る（映り方は judge.gd の look() の見方をそのまま使う）。
##   解き方（怪獣の隠し方・火薬の量・点火の間合い・寄りの撮り方）は決めない。
##   班の誰か（プレイヤー）が撮影カメラに映っている間は、その場面は「撮れている時間」に数えない（production_notes.gd の数え方）。
##   撮れた場面は、確認用モニターの枠のランプが点く。撮れなかった理由（why）は、テイクのあとの確認に、場面ごとに出す。
## ・通信：ホストが決めて、"beat" の合図で配る（いまの場面・ランプ・稽古かどうか）。本番中の合図は、見返しにも残る。
##   役者の動きと印の場所は、今までどおり、世界の同期で届く。フィルムの残りは、テイクの時計（main.gd の take_t）から出す。
const Scripts := preload("res://scripts/production_script.gd")
const Marks := preload("res://scripts/ui/monitor_marks.gd")

const CREW_LAYER := 1 << 11       # 制作班にだけ見える表示（film_camera.gd と同じ番号）
const FILM_SEC := 90.0            # フィルム1本ぶんの秒数（この依頼のテイクの長さ）
const LOW_SEC := 15.0             # 残りがこれより少ないと、リールがカタカタ鳴る
const DIRECT_REACH := 2.5         # 置いた台本から、この距離までなら場面を進められる
const STEP_GAP := 0.35            # 続けて押したときに、場面を飛ばさないための間（秒）
const BOOM_DELAY := 0.9           # 場面に入ってから、爆発役の物（爆弾を除く）に合図が出るまで
const MEET_GAP := 1.0             # 「近づく」場面で、二人が向かい合って立つ間隔
const CUT_TAIL := 1.2             # カット割りの依頼：場面が撮れてから、フィルムを止める（カット）までの間
# ---- 採点の数字 ----
const NEED_STROLL := 1.5          # 街を歩く：歩いている二人と街が、映っている秒数
const NEED_APPEAR := 2.0          # 怪獣あらわる：怪獣・街・固まった二人が、映っている秒数
const NEED_BOOM := 0.5            # 怪獣の技：爆発と二人が、一緒に映っている秒数（爆発から judge.BOOM_WINDOW 秒のうちに）
const FALL_WINDOW := 3.0          # 爆発のあと、この秒数のうちに街が倒れること（そのあいだ、怪獣は立っていること）
const MIN_FALL := 2               # 倒れる・吹き飛ぶ街役の物の数
const BLOWN_M := 0.8              # 爆発の瞬間から、これだけ動いていれば「吹き飛んだ」
const TILT := 0.64                # 爆発の瞬間の向きから、これより傾いていれば「倒れた」（上向きどうしの内積。約50度）
const UPRIGHT := 0.6              # 怪獣が「立っている」とみなす傾き（judge.gd と同じ）
const SEEN_GRACE := 1.0           # 爆発の直前、この秒数のうちに映っていた街役の物を数える
const NEED_UP := 0.5              # 怪獣が倒れる：倒れる前に、立っている怪獣が映っている秒数
const NEED_DOWN := 1.0            # 倒れたあと、倒れた怪獣が映っている秒数
const CREW_GRACE := 0.5           # 怪獣が倒れる前後、この秒数のうちに班の誰かが映っていたら「倒す人が映っていた」
const NEED_CHEER := 1.5           # 勝利：万歳する二人と倒れた怪獣が、寄りで映っている秒数
const CLOSE_MIN := 0.30           # 寄り：画面の高さに対する、二人の大きさの下限（ふつうの場面は judge.MIN_SIZE＝0.10）
const CLOSE_TIMES := 1.3          # 寄り：「怪獣あらわる」で映っていた大きさの、この倍より大きく
const NEED_SHOW := 1.5            # 見せる（show）：着いた二人（と、決めた役の物）が映っている秒数
const NEED_TRACK := 0.8           # 動くカメラ（track）：歩く二人を映したまま、カメラが動いた距離（m）
const TRACK_SPEED := 0.2          # これより遅いカメラは、動いていないとみる（m/秒）
const TRACK_JUMP := 0.12          # 1コマにこれより大きく動いたら、カメラの切り替え（数えない）
const DROP_M := 1.0               # 上から落ちる（drop）：場面の間に、物がこれだけ下がったら「落ちた」
const NEED_CHASE := 0.6           # 大岩に追われる（chase）：逃げる二人と、後ろから転がって迫る物が映っている秒数（印の間が短いと、走るのは1秒ほど）
const CHASE_SPEED := 0.9          # これより速く動いている物を「迫っている」とみる（m/秒）
const CHASE_SPIN := 1.2           # これより速く回っていれば「転がっている」（滑っているだけではない。rad/秒）
const CHASE_NEAR := 4.5           # 二人のうち近いほうから、この距離までに迫っていること（m）
# 役者ごとの印 ①②③ の、最初の置き場所（現場の座標）。班が、好きな所へ置き直す
# （室内スタジオの左右の壁は x＝±4.1。どの現場でも、壁の内側に並ぶようにしてある）
const MARK_HOME := [[Vector3(-3.4, 0.05, -1.5), Vector3(-0.6, 0.05, -1.5), Vector3(2.6, 0.05, -1.5)],
	[Vector3(-3.4, 0.05, -0.3), Vector3(-0.6, 0.05, -0.3), Vector3(2.6, 0.05, -0.3)]]
const ACTORS := ["A", "B"]
const STEPS := ["①", "②", "③"]
# 場面ごとの、理由が1つも控えられなかったときの文
const NO_REASON := {
	"stroll": "歩いている二人が映る時間が足りなかった",
	"appear": "怪獣と二人が一緒に映る時間が足りなかった",
	"attack": "爆発が起きなかった",
	"topple": "怪獣が倒れなかった",
	"cheer": "万歳する二人が映る時間が足りなかった",
	"show": "二人が映る時間が足りなかった",
	"blast": "爆発が起きなかった",
	"track": "カメラが動きながら、歩く二人を映す時間が足りなかった",
	"drop": "二人のそばに、上から物が落ちてこなかった",
	"chase": "逃げる二人と、後ろから転がって迫る物が、一緒に映る時間が足りなかった",
}

var game: Node
var flow: Node
var marks: Array = [[], []]       # 役者ごとの印 [①, ②, ③]
var _mark_start: Array = []       # 印の最初の置き場所（setup のとき）
var scene := -1                   # いまの場面（-1＝まだ始めていない）。全員の画面で同じ
var lit: Array = []               # 場面ごとに、撮れたか（確認用モニターのランプ）
var rehearsal := false            # 通し稽古の最中か（準備中に場面を進めた）
var why: Array = []               # 場面ごとの「足りなかった理由」と秒数（ホスト）
var met_at: Array = []            # 場面が撮れた時刻（-1＝撮れていない。ホスト）
# カット割りの依頼（production_script.gd の cuts）：本番中に、フィルムを止めている（場転）。全員の画面で同じ。
# 止めている間は、テイクの時計・記録・採点・映り込みの数えが進まない（main.gd の take_held）
var holding := false
var next_scene := -1              # 場転のあと、1 で回し直したときに撮る場面
var _hold_in := -1.0              # 場面が撮れてから、カットするまでの残り（ホスト）

var _acc: Array = []              # 場面ごとの、撮れている時間
var _entered: Array = []          # 本番で、その場面へ進んだか
var _clock := 0.0                 # ホストの物理コマで数えた時計（続けて押した合図の間をはかる）
var _step_at := -10.0
var _boom_in := -1.0
var _crew_t := -100.0             # 班の誰かが、最後に映っていた時刻
var _city_seen := {}              # 街役の物が、最後に映っていた時刻（物のID → 時刻）
var _lead := 0                    # 「怪獣あらわる」で映った怪獣（物のID）
var _wide_sum := 0.0
var _wide := 0.0                  # 「怪獣あらわる」で映っていた、二人の大きさ（寄りの比べ先）
var _boom_before := false         # 怪獣の技の場面より前に、爆発が起きた
# 怪獣の技
var _boom_t := -1.0
var _boom_acc := 0.0
var _boom_ok := false
var _boom_done := false
var _boom_snap := {}              # 爆発の瞬間の街役の物（物のID → [場所, 上向き]）
var _fallen := {}
var _mon_watch := {}        # 爆発の瞬間に立っていた怪獣（物のID）
var _mon_fell := false
# 怪獣が倒れる
var _up_acc := 0.0
var _up_seen_t := -100.0
var _fell_t := -1.0
var _down_acc := 0.0
var _taint := false
var _topple_pid := 0
var _track_m := 0.0               # 動くカメラ：数えた距離
var _track_last := Vector3.INF    # 動くカメラ：前のコマのカメラの場所
var _drop_top := {}               # 上から落ちる：場面の間の、物の一番高い所（物のID → 高さ）
# 画面
var _playback := false
var _before_replay := {}
var _rattle := 0.0


# 印②③ を作る。全員の画面で同じ順に呼ぶ（物のIDがそろう）。ふだんは片づけてあり、この依頼のときだけ出る
func setup() -> void:
	flow = game.production
	for aid in 2:
		marks[aid] = [game.actors[aid].mark]
	for aid in 2:
		for _more in 2:
			var disc: RigidBody3D = game.stage.spawn_mark(aid, Vector3(float(game.props.size() + 1) * 3.0, -60.0, 40.0))
			(marks[aid] as Array).append(disc)
	for aid in 2:
		for step in 3:
			_dress(marks[aid][step], aid, step)
	# 最初の置き場所（会社の前で撮ったあと、ここへ戻す）
	for aid in 2:
		_mark_start.append([])
		for step in 3:
			(_mark_start[aid] as Array).append((marks[aid][step] as RigidBody3D).get_state())
	refresh()


# 印に、番号を付ける：円盤の上の数字（床の印として、映画にも映る）と、遠くからでも分かる札（制作班にだけ見える）
func _dress(disc: RigidBody3D, aid: int, step: int) -> void:
	var numeral := Label3D.new()
	numeral.name = "Numeral"
	numeral.text = str(step + 1)
	numeral.font = game.font
	numeral.font_size = 200
	numeral.pixel_size = 0.0019
	numeral.modulate = Color("1b1c20")
	numeral.outline_size = 14
	numeral.outline_modulate = Color("1b1c20")
	numeral.position = Vector3(0, 0.046, 0.02)
	numeral.rotation.x = -PI * 0.5
	numeral.visible = false
	disc.add_child(numeral)
	var tag := Label3D.new()
	tag.name = "Tag"
	tag.text = str(ACTORS[aid]) + str(STEPS[step])
	tag.font = game.font
	tag.font_size = 30
	tag.fixed_size = true
	tag.pixel_size = 0.0011
	tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	tag.no_depth_test = true
	tag.modulate = Color("f4f1ea")
	tag.outline_modulate = Color(0, 0, 0, 0.8)
	tag.outline_size = 10
	tag.layers = CREW_LAYER
	tag.position = Vector3(0, 0.42, 0)
	tag.visible = false
	disc.add_child(tag)


func mark(aid: int, step: int) -> RigidBody3D:
	return marks[aid][clampi(step, 0, 2)]


# 印を、その場に留める・戻す（ホスト。爆風を計算する間だけ留める。production_main.gd の host_burst）
func pin_marks(on: bool) -> void:
	for aid in 2:
		for step in 3:
			(marks[aid][step] as RigidBody3D).immovable = on


# いまの依頼の、場面の列（無ければ空）
func list() -> Array:
	return Scripts.beats(flow.chosen_job) if flow != null else []


# いまの依頼が、場面の列で進む依頼か（依頼を受けてから、事務所へ戻るまで）
func active() -> bool:
	return flow != null and flow.phase >= 1 and not list().is_empty()


# いまの依頼が、場面ごとにカットを割って撮る依頼か（そうでなければ長回し）
func cut_mode() -> bool:
	return active() and Scripts.cuts(flow.chosen_job)


func _falses(count: int) -> Array:
	var out: Array = []
	out.resize(count)
	out.fill(false)
	return out


# 依頼が変わった・物の出し入れがあった（全員の画面）：この依頼のときだけ、印②③と番号を出し、採点をこちらへ回す
func refresh() -> void:
	if flow == null:
		return
	var on := active()
	game.judge.beats = self if on else null
	for aid in 2:
		for step in 3:
			var item: RigidBody3D = marks[aid][step]
			if step > 0:
				item.set_absent(not on)
			item.label = "立ち位置の印 %s%s" % [ACTORS[aid], STEPS[step] if on else ""]
			(item.get_node("Numeral") as Node3D).visible = on
			(item.get_node("Tag") as Node3D).visible = on
	var count := list().size() if on else 0
	if lit.size() != count:
		lit = _falses(count)
		scene = -1
		rehearsal = false


# 依頼を受けた（ホスト）：印を最初の置き場所へ並べ、場面を最初へ戻す
func host_new_job() -> void:
	if not multiplayer.is_server():
		return
	scene = -1
	rehearsal = false
	_boom_in = -1.0
	lit = _falses(list().size() if active() else 0)
	if active():
		for aid in 2:
			for step in 3:
				(marks[aid][step] as RigidBody3D).restore([MARK_HOME[aid][step] + flow.site_center(), Quaternion.IDENTITY, false])
		for a: CharacterBody3D in game.actors:
			a.set_state(a.St.STANDBY)
	_broadcast()


# 帰社（ホスト）：会社の前で撮ったあとは、印を、軽トラで行く現場の最初の置き場所へ戻す（役者もそこへ戻る）
func hook_return_office() -> void:
	if not multiplayer.is_server() or not flow.shoots_home():
		return
	for aid in 2:
		for step in 3:
			(marks[aid][step] as RigidBody3D).restore(_mark_start[aid][step])
	for a: CharacterBody3D in game.actors:
		a.set_state(a.St.STANDBY)


# ---- 画面に出す物（全員） ----

# 使ったフィルム（秒）。本番中はテイクの時計、見返し中は見返しの時計、確認中は選んだテイクの長さ
func film_used() -> float:
	var S: Dictionary = game.S
	if game.state == S.TAKE:
		return float(game.take_t)
	if game.state == S.REPLAY:
		return float(game.replay_t)
	if game.state in [S.RESULT, S.DELIVERED] and not (game.takes as Array).is_empty():
		return float(game.takes[clampi(game.selected, 0, game.takes.size() - 1)].get("dur", 0.0))
	return 0.0


# フィルムの残り（1＝まるごと / 0＝切れた）
func film_frac() -> float:
	return clampf(1.0 - film_used() / FILM_SEC, 0.0, 1.0)


# モニターのランプ：本番と見返しでは、撮れた場面。確認中は、選んだテイクの成否。それ以外は消えている
func lamps() -> Array:
	var S: Dictionary = game.S
	var count := list().size()
	if game.state in [S.TAKE, S.REPLAY] and lit.size() == count:
		return lit
	if game.state in [S.RESULT, S.DELIVERED] and not (game.takes as Array).is_empty():
		var passed: Array = game.takes[clampi(game.selected, 0, game.takes.size() - 1)]["passed"]
		if passed.size() == count:
			return passed
	return _falses(count)


func _process(delta: float) -> void:
	if flow == null or game.camera_switcher == null:
		return
	var on := active()
	var S: Dictionary = game.S
	var used := film_used() if on else 0.0
	var frac := clampf(1.0 - used / FILM_SEC, 0.0, 1.0)
	var rolling: bool = on and game.state in [S.TAKE, S.REPLAY] and not holding     # 場転の間は、リールが止まる
	var low: bool = rolling and FILM_SEC - used < LOW_SEC
	for cam: Node in game.camera_switcher.cameras:
		cam.set_film(on and flow.phase in [2, 4, 5], frac, rolling, low)
	game.camera_switcher.monitor.set_marks(lamps() if on else [], frac)
	_sync_hold_sign(on and holding and game.state == S.TAKE)
	# 残りわずか：リールがカタカタ鳴る。切れる間際ほど、せわしなく
	if not low:
		_rattle = 0.0
		return
	_rattle -= delta
	if _rattle <= 0.0:
		_rattle = lerpf(0.14, 0.42, clampf((FILM_SEC - used) / LOW_SEC, 0.0, 1.0))
		var sfx: Node = get_node_or_null("/root/Sfx")
		if sfx != null and sfx.has_sound("ui_select"):
			sfx.play("ui_select", (game.program_camera() as Node3D).global_position + Vector3(0, 1.4, 0), -3.0)


# 場転の札：フィルムを止めている間、撮影カメラの上に浮かぶ（制作班にだけ見える。映画には映らない）。
# 画面の隅の文字ではなく、現場の物で「いまは止まっている・次は何の場面か」が分かるように
var _hold_sign: Label3D


func _sync_hold_sign(show: bool) -> void:
	if _hold_sign == null:
		if not show:
			return
		_hold_sign = Label3D.new()
		_hold_sign.name = "HoldSign"
		_hold_sign.font = game.font
		_hold_sign.font_size = 30
		_hold_sign.pixel_size = 0.0012
		_hold_sign.fixed_size = true
		_hold_sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		_hold_sign.no_depth_test = true
		_hold_sign.modulate = Color("ffcc00")
		_hold_sign.outline_modulate = Color(0, 0, 0, 0.85)
		_hold_sign.outline_size = 14
		_hold_sign.layers = CREW_LAYER
		add_child(_hold_sign)
	_hold_sign.visible = show
	if not show:
		return
	var cam: Node3D = game.program_camera()
	if cam != null:
		_hold_sign.global_position = cam.global_position + Vector3(0, 2.25, 0)
	var titles: Array = flow.job()["scenes"]
	var title: String = str(titles[next_scene]).get_slice("（", 0) if next_scene >= 0 and next_scene < titles.size() else ""
	_hold_sign.text = "場転中（フィルム停止）\n次：%s　／　1 で回す" % title


# ---- 場面を進める ----

# 台本を持っている人（いなければ 0）。物を持つ・置くの知らせ（"hold"）は全員に届くので、どの画面でも分かる
func _book_holder() -> int:
	var book: Node = flow.script_prop
	if book == null:
		return 0
	for id: int in game.players:
		if int(game.players[id].held) == book.pid:
			return id
	return 0


# その人が、場面を進められるか：台本を持っている・手帳で台本の写しを開いている・置いてある台本のすぐそばにいる
func may_direct(who: int) -> bool:
	if flow == null:
		return false
	var pl: Node3D = game.players.get(who)
	if pl == null:
		return false
	if game.talent != null and game.talent.note_open(who):
		return true
	var book: Node3D = flow.script_prop
	if book == null or book.absent:
		return false
	var holder := _book_holder()
	if holder != 0:
		return holder == who
	return pl.global_position.distance_to(book.global_position) <= DIRECT_REACH


# 場面を進める頼み（ホスト）。n：1＝次の場面へ / 2＝今の場面をもう一度
func host_step(who: int, n: int) -> void:
	var S: Dictionary = game.S
	if not multiplayer.is_server() or not active() or flow.phase != 4 or game.replaying or game.state not in [S.PREP, S.TAKE] or n not in [1, 2]:
		return
	if not may_direct(who):
		_tell(who, "場面を進められるのは、台本を読める人だけ（台本を持つか、すぐそばに置く）", true)
		return
	if _clock - _step_at < STEP_GAP:
		return
	var count := list().size()
	# カット割りの依頼の本番：場転の間は、1 でも 2 でも「回し直す」（用意した場面から）。
	# 回している間の 1 は「カット」（撮れていれば次の場面へ、撮れていなければ同じ場面を、場転のあとに撮り直す）
	if cut_mode() and game.state == S.TAKE:
		if holding:
			_action()
		elif n == 1 and scene >= 0:
			var ahead: bool = scene < lit.size() and bool(lit[scene]) and scene < count - 1
			_start_hold(scene + 1 if ahead else scene)
		elif n == 2 and scene >= 0:
			_enter(scene, true)
		_step_at = _clock
		return
	if n == 1:
		if scene >= count - 1:
			_tell(who, "最後の場面まで来ている（2 で、もう一度）", false)
			return
		_enter(scene + 1, false)
	elif scene >= 0:
		_enter(scene, true)
	_step_at = _clock


# 頼んだ本人にだけ、知らせを返す（もう抜けた人には送らない）
func _tell(who: int, text: String, bad: bool) -> void:
	if who != multiplayer.get_unique_id() and who not in multiplayer.get_peers():
		return
	game.ev.rpc_id(who, "toast", [text, 1 if bad else 0])
	if bad:
		game.ev.rpc_id(who, "sfx", ["ui_fail", null])


# 役者の行き先（その場面の最後の印）。二人が近づく場面では、二人の印のあいだで向かい合う
func _targets(b: Dictionary) -> Array:
	var to := int(b.get("to", 0))
	var a: Vector3 = mark(0, to).global_position
	var c: Vector3 = mark(1, to).global_position
	if b.get("meet", false):
		var apart := Vector3(a.x - c.x, 0.0, a.z - c.z)
		if apart.length() > MEET_GAP:
			var mid := (a + c) * 0.5
			var half := apart.normalized() * MEET_GAP * 0.5
			a = Vector3(mid.x + half.x, a.y, mid.z + half.z)
			c = Vector3(mid.x - half.x, c.y, mid.z - half.z)
	return [a, c]


# その場面を始める（again＝やり直し。役者は、その場面の最初の印まで走って戻ってから、もう一度演じる）
func _enter(i: int, again: bool) -> void:
	var b: Dictionary = list()[i]
	scene = i
	rehearsal = game.state == game.S.PREP
	var targets := _targets(b)
	var faces: Array = b.get("face", ["neutral", "neutral"])
	for a: CharacterBody3D in game.actors:
		var spec := {"to": targets[a.aid], "gait": str(b.get("gait", "walk")), "pose": str(b.get("pose", "idle")),
			"look": str(b.get("look", "")), "face_go": str(faces[0]), "face_hold": str(faces[1])}
		if again:
			spec["back"] = mark(a.aid, int(b.get("from", 0))).global_position
		a.play_beat(spec)
	if game.state == game.S.TAKE and i < _entered.size():
		_entered[i] = true
		if not lit[i]:
			_restart_rule(i)
	game.host_ev("sfx", ["cue", null])
	if b.has("music"):
		game.host_ev("music", [str(b["music"])])
	if b.get("roar", false):
		game.host_ev("sfx", ["roar", game.actors[0]._monster_pos()])
	_boom_in = BOOM_DELAY if b.get("boom", false) else -1.0
	_broadcast()


# カット（ホスト。カット割りの依頼の本番）：フィルムを止めて、場転に入る。
# 役者は、次に撮る場面の最初の印へ歩いて行き、そこで待つ。テイクは続いている（時計と記録が止まるだけ）
func _start_hold(next: int) -> void:
	_hold_in = -1.0
	_boom_in = -1.0
	next_scene = clampi(next, 0, list().size() - 1)
	var b: Dictionary = list()[next_scene]
	for a: CharacterBody3D in game.actors:
		a.play_beat({"to": mark(a.aid, int(b.get("from", 0))).global_position, "gait": "walk", "pose": "idle",
			"look": "", "face_go": "neutral", "face_hold": "neutral"})
	game.host_ev("music", [""])
	game.host_ev("sfx", ["clap", null])
	var titles: Array = flow.job()["scenes"]
	var title: String = str(titles[next_scene]) if next_scene < titles.size() else ""
	game.host_ev("toast", ["カット！ フィルムを止めた。場転：『%s』の用意ができたら、台本を読める人が 1 で回す" % title, 0])
	holding = true          # 止めてから配る（止めた知らせは、見返しの記録に入らない）
	_broadcast()


# 回し直す（ホスト）：場転で用意した場面から、フィルムを回す
func _action() -> void:
	holding = false
	game.host_ev("sfx", ["clap", null])
	_enter(next_scene, false)
	next_scene = -1


# 場面を閉じる（ホスト。テイクが終わった・準備へ戻った・役者を印へ戻した）
func host_reset() -> void:
	if not multiplayer.is_server():
		return
	_boom_in = -1.0
	_hold_in = -1.0
	if scene == -1 and not rehearsal and not holding:
		return
	scene = -1
	rehearsal = false
	holding = false
	next_scene = -1
	_broadcast()


# 爆発役の物への合図（ホスト）。爆弾は合図では鳴らない（導火線に火を付ける）。
# 爆炎の書割・爆発役に見立てた物（怪獣の技）は、この場面に入ると鳴る・飛ぶ
func _cue_boom() -> void:
	var S: Dictionary = game.S
	if not active() or scene < 0 or game.state not in [S.PREP, S.TAKE]:
		return
	if game.bomb_armed() or game.fx.fuse >= 0.0:
		return
	var flat: RigidBody3D = game._pick_boom()
	if flat == null:
		return
	if game.host_cast_boom(flat):
		return
	var pos: Vector3 = flat.burst_point()
	if game.state == S.TAKE:
		game.judge.on_burst(pos, flat.pid)
	game.host_ev("pop", [flat.pid])
	game.host_ev("burst", [pos, 0.0])
	game.host_ev("sfx", ["explosion", pos])
	if game.state == S.TAKE:
		for a: CharacterBody3D in game.actors:
			if a.global_position.distance_to(pos) < 9.0:
				a.knock(Vector3(0, 3.2, 0))


func _physics_process(delta: float) -> void:
	if flow == null or not multiplayer.is_server():
		return
	_clock += delta
	# カット割りの依頼：場面が撮れたら、少し回してからカット（最後の場面は、テイクの終わり＝main.gd の自動カット）
	if _hold_in > 0.0 and game.state == game.S.TAKE and not holding:
		_hold_in -= delta
		if _hold_in <= 0.0:
			_start_hold(scene + 1)
	if _boom_in > 0.0:
		_boom_in -= delta
		if _boom_in <= 0.0:
			_boom_in = -1.0
			_cue_boom()
	# 本番でも準備中でもなくなった（確認・納品・移動）：場面を閉じる
	var S: Dictionary = game.S
	if (scene >= 0 or rehearsal) and not _playback and (not active() or flow.phase != 4 or game.state not in [S.PREP, S.TAKE]):
		host_reset()


# ---- 通信 ----

func view() -> Dictionary:
	return {"scene": scene, "lit": lit.duplicate(), "rehearsal": rehearsal, "hold": holding, "next": next_scene}


# 全員へ配る（ホスト）。本番中の合図は、見返しのために記録にも残る（production_main.gd の host_ev）
func _broadcast() -> void:
	if multiplayer.is_server():
		game.host_ev("beat", [view()])


# あとから入った人へ、いまの様子を送る
func sync_to(who: int) -> void:
	if multiplayer.is_server() and who != multiplayer.get_unique_id():
		game.ev.rpc_id(who, "beat", [view()])


# 合図を受け取った（全員）。ホストは自分で決めた物なので、見返しの間だけ受け取る
func receive(data: Dictionary) -> void:
	if multiplayer.is_server() and not _playback:
		return
	_apply(data)


func _apply(data: Dictionary) -> void:
	scene = int(data.get("scene", -1))
	lit = (data.get("lit", []) as Array).duplicate()
	rehearsal = bool(data.get("rehearsal", false))
	holding = bool(data.get("hold", false))
	next_scene = int(data.get("next", -1))


# 見返しの始まりと終わり（ホスト）。見返しの間は記録どおりに見せ、終わったら今の様子へ戻す
func playback_changed(on: bool) -> void:
	if not multiplayer.is_server():
		return
	if on:
		_before_replay = view()
		_playback = true
	elif _playback:
		_playback = false
		_apply(_before_replay)
		_before_replay = {}
		game.ev.rpc("beat", [view()])


# ---- 採点（ホスト。judge.gd から呼ばれる） ----

func judge_reset() -> void:
	var count := list().size()
	lit = _falses(count)
	met_at = []
	why = []
	_acc = []
	_entered = []
	for i in count:
		met_at.append(-1.0)
		why.append({})
		_acc.append(0.0)
		_entered.append(false)
	_crew_t = -100.0
	_city_seen = {}
	_lead = 0
	_wide_sum = 0.0
	_wide = 0.0
	_boom_before = false
	_reset_attack()
	_reset_topple()


func passed() -> Array:
	var count := list().size()
	return lit.duplicate() if lit.size() == count else _falses(count)


func _rule_index(rule: String) -> int:
	var beats := list()
	for i in beats.size():
		if str(beats[i].get("rule", "")) == rule:
			return i
	return -1


func _note(i: int, reasons: Array, dt: float) -> void:
	for reason: String in reasons:
		why[i][reason] = float(why[i].get(reason, 0.0)) + dt


func _top_reason(i: int) -> String:
	var best := ""
	var best_t := 0.0
	for reason: String in why[i]:
		if float(why[i][reason]) > best_t:
			best_t = why[i][reason]
			best = reason
	return best


func _met(i: int) -> void:
	lit[i] = true
	met_at[i] = float(game.judge.t)
	game.host_condition_met(i)
	if cut_mode() and i == scene and i < list().size() - 1:
		_hold_in = CUT_TAIL
	_broadcast()


# その場面の数えを、最初からやり直す（場面に入った・「もう一度」）。理由も、やり直した回のものだけを残す
func _restart_rule(i: int) -> void:
	_acc[i] = 0.0
	why[i] = {}
	match str(list()[i].get("rule", "")):
		"attack", "blast":
			_reset_attack()
		"topple":
			_reset_topple()
		"appear":
			_wide_sum = 0.0
		"track":
			_track_m = 0.0
			_track_last = Vector3.INF
		"drop":
			_drop_top = {}


func _reset_attack() -> void:
	_boom_t = -1.0
	_boom_acc = 0.0
	_boom_ok = false
	_boom_done = false
	_boom_snap = {}
	_fallen = {}
	_mon_watch = {}
	_mon_fell = false


func _reset_topple() -> void:
	_up_acc = 0.0
	_up_seen_t = -100.0
	_fell_t = -1.0
	_down_acc = 0.0
	_taint = false
	_topple_pid = 0


# 傾いているか（上向きが、まっすぐ上から大きく外れた）
func _tipped(prop: Node3D) -> bool:
	return prop.global_basis.y.normalized().y < UPRIGHT


# 本番中、毎コマ。f＝いまの画面の見え方（judge.look()）
func judge_tick(dt: float, f: Dictionary) -> void:
	var t: float = game.judge.t
	for pid: int in f.get("city_pids", []):
		_city_seen[pid] = t
	var crew: bool = not (flow.notes.crew_in_frame() as Array).is_empty()
	if crew:
		_crew_t = t
	var beats := list()
	if scene < 0 or scene >= beats.size() or scene >= lit.size() or lit[scene]:
		return
	match str(beats[scene].get("rule", "")):
		"stroll":
			_rule_stroll(scene, f, dt, crew)
		"appear":
			_rule_appear(scene, f, dt, crew)
		"attack":
			_rule_attack(scene, f, dt, crew, t)
		"topple":
			_rule_topple(scene, f, dt, crew, t)
		"cheer":
			_rule_cheer(scene, f, dt, crew)
		"show":
			_rule_show(scene, f, dt, crew)
		"blast":
			_rule_blast(scene, f, dt, crew, t)
		"track":
			_rule_track(scene, f, dt, crew)
		"drop":
			_rule_drop(scene, f, dt, crew)
		"chase":
			_rule_chase(scene, f, dt, crew)


func _stuck() -> bool:
	return game.actors[0].beat_stuck() or game.actors[1].beat_stuck()


# 数える・理由を控える、の共通の終わり方
func _count(i: int, reasons: Array, dt: float, need: float) -> void:
	if reasons.is_empty():
		_acc[i] = float(_acc[i]) + dt
		if float(_acc[i]) >= need:
			_met(i)
	else:
		_note(i, reasons, dt)


# 1：街を歩いてくる。歩いている二人と、街役の物が2つ以上。怪獣役の物は、まだ映ってはいけない
func _rule_stroll(i: int, f: Dictionary, dt: float, crew: bool) -> void:
	if _stuck():
		_note(i, ["役者が物にぶつかって、立ち止まった"], dt)
		return
	if not (game.actors[0].beat_walking() and game.actors[1].beat_walking()):
		return          # 歩いていない間（戻っている・着いたあと）は、数えない
	var r: Array = game.judge.problems(f)
	if int(f["city_n"]) < game.judge.MIN_CITY:
		r.append("街役の物が%dつ以上映っていなかった" % game.judge.MIN_CITY)
	if f.get("monster_peek", false):
		r.append("怪獣が先に映っていた")
	if crew:
		r.append("スタッフが映っていた")
	_count(i, r, dt, NEED_STROLL)


# 2：怪獣あらわる。怪獣が、立っていて、街より大きく映る。二人は印②で見上げて固まる
func _rule_appear(i: int, f: Dictionary, dt: float, crew: bool) -> void:
	if _stuck():
		_note(i, ["役者が物にぶつかって、立ち止まった"], dt)
		return
	if not (game.actors[0].beat_arrived() and game.actors[1].beat_arrived()):
		return
	var r: Array = game.judge.problems(f)
	r.append_array(game.judge.kaiju_problems(f))
	if crew:
		r.append("スタッフが映っていた")
	if r.is_empty():
		var acts: Array = f["actors"]
		_wide_sum += minf(float(acts[0]["h"]), float(acts[1]["h"])) * dt
		_lead = int(f["monster"]["pid"])
	_count(i, r, dt, NEED_APPEAR)
	if lit[i]:
		_wide = _wide_sum / maxf(float(_acc[i]), 0.001)


# 爆発が起きた（judge.on_burst から）。怪獣の技の場面の間に起きた、最初の爆発を数える
func on_burst(pos: Vector3, src: int) -> bool:
	if holding:
		return true          # フィルムを止めている間の爆発は、映画に映らない（使い損）
	var jd: RefCounted = game.judge
	# 背後で爆発（blast）の場面の間に起きた爆発：そこから BOOM_WINDOW 秒の映り方を数える
	var beats_now := list()
	if scene >= 0 and scene < beats_now.size() and str(beats_now[scene].get("rule", "")) == "blast" and scene < lit.size() and not lit[scene]:
		if _boom_t >= 0.0 and jd.t - _boom_t < jd.BOOM_WINDOW:
			return true          # 数えている最中の爆発に、もう1つ重なった
		_reset_attack()
		_boom_t = jd.t
		jd.boom_t0 = jd.t
		jd.boom_pos = pos
		jd.boom_src = src
		jd.boom_power = 0
		return true
	var at := _rule_index("attack")
	if at < 0 or scene != at or at >= lit.size() or lit[at]:
		if at >= 0 and scene < at:
			_boom_before = true
			var shown := _rule_index("appear")
			if shown < 0 or shown >= lit.size() or not lit[shown]:
				jd.boom_early = true
		return true
	if _boom_t >= 0.0 and jd.t - _boom_t < FALL_WINDOW:
		return true          # 数えている最中の爆発に、もう1つ重なった
	_reset_attack()
	why[at] = {}
	_boom_t = jd.t
	jd.boom_t0 = jd.t
	jd.boom_pos = pos
	jd.boom_src = src
	jd.boom_power = 0
	# 直前まで映っていた街役の物と、立っている怪獣を控える
	for pid: int in _city_seen:
		var prop: Node3D = game.props.get(pid)
		if prop != null and not prop.absent and jd.t - float(_city_seen[pid]) <= SEEN_GRACE:
			_boom_snap[pid] = [prop.global_position, prop.global_basis.y.normalized()]
	for prop: Node3D in game.props.values():
		if prop.absent or jd.role_of(prop) != "monster" or _tipped(prop):
			continue
		if _lead == 0 or prop.pid == _lead:
			_mon_watch[prop.pid] = prop.global_position
	return true


# 3：怪獣の技。爆発が二人の背後に映る。そのあと FALL_WINDOW 秒のうちに、街役の物が2つ以上倒れる・吹き飛ぶ。怪獣は立ったまま
func _rule_attack(i: int, f: Dictionary, dt: float, crew: bool, t: float) -> void:
	if _boom_t < 0.0 or _boom_done:
		return
	var jd: RefCounted = game.judge
	var since := t - _boom_t
	if since <= jd.BOOM_WINDOW and not _boom_ok:
		var r: Array = jd.problems(f, false)
		if not f["fx_in"]:
			r.append("爆発が画面に入っていなかった")
		elif not f["fx_behind"]:
			r.append("爆発が二人より手前だった")
		if crew:
			r.append("スタッフが映っていた")
		if r.is_empty():
			_boom_acc += dt
			_boom_ok = _boom_acc >= NEED_BOOM
		else:
			_note(i, r, dt)
	for pid: int in _boom_snap:
		var prop: Node3D = game.props.get(pid)
		if prop == null or _fallen.has(pid):
			continue
		var was: Array = _boom_snap[pid]
		if prop.global_basis.y.normalized().dot(was[1] as Vector3) < TILT or prop.global_position.distance_to(was[0] as Vector3) > BLOWN_M:
			_fallen[pid] = true
	for pid: int in _mon_watch:
		var monster: Node3D = game.props.get(pid)
		if monster != null and (_tipped(monster) or monster.global_position.distance_to(_mon_watch[pid] as Vector3) > BLOWN_M):
			_mon_fell = true
	if since < FALL_WINDOW:
		return
	# 判定：ここで決まる。だめなら、次の爆発（「もう一度」）を待つ
	_boom_done = true
	# 判定の理由は、途中の映り方の理由より前に出す（重みを足す。大きいほど先）
	var bad := {}
	if not _boom_ok and _top_reason(i) == "":
		bad["爆発と二人が一緒に映る時間が足りなかった"] = 10.0
	if _fallen.size() < MIN_FALL:
		bad["街が倒れなかった（爆発のすぐあとに、街役の物が%dつ以上倒れること）" % MIN_FALL] = 11.0
	if _mon_watch.is_empty():
		bad["爆発のとき、怪獣が立っていなかった"] = 12.0
	elif _mon_fell:
		bad["怪獣まで倒れた"] = 13.0
	if bad.is_empty() and _boom_ok:
		_met(i)
		return
	for reason: String in bad:
		_note(i, [reason], float(bad[reason]))


# 4：怪獣が倒れる。この場面の間に、怪獣が「立っている → 倒れた」になる。倒す人は映ってはいけない
func _rule_topple(i: int, f: Dictionary, dt: float, crew: bool, t: float) -> void:
	var m: Dictionary = f["monster"]
	var standing: bool = m["exists"] and m["up"] and m["in"] and m["seen"]
	var prop: Node3D = game.props.get(_topple_pid) if _topple_pid != 0 else null
	if _fell_t < 0.0:
		if standing:
			_topple_pid = int(m["pid"])
			_up_seen_t = t
			if crew:
				_note(i, ["スタッフが映っていた"], dt)
			else:
				_up_acc += dt
			return
		if prop != null and _tipped(prop):
			if _up_acc >= NEED_UP and t - _up_seen_t <= 0.4:
				_fell_t = t
				_down_acc = 0.0
				_taint = t - _crew_t <= CREW_GRACE
			else:
				_note(i, ["怪獣が倒れるところが映っていなかった"], 1.0)
				_reset_topple()
			return
		if f["monster_down"]:
			_note(i, ["怪獣が、この場面の前に倒れていた（起こしてから倒す）"], dt)
		else:
			_note(i, ["立っている怪獣が映っていなかった"], dt)
		return
	if prop == null or not _tipped(prop):
		_reset_topple()          # 起こし直した：もう一度、立っている所から
		return
	if crew and t - _fell_t <= CREW_GRACE:
		_taint = true
	if _taint:
		_note(i, ["倒す人が映っていた"], dt)
		return
	var r: Array = []
	if not f["monster_down"]:
		r.append("倒れた怪獣が映っていなかった")
	if crew:
		r.append("スタッフが映っていた")
	if r.is_empty():
		_down_acc += dt
		if _down_acc >= NEED_DOWN:
			_met(i)
	else:
		_note(i, r, dt)


# 寄りに要る、二人の大きさ
func close_need() -> float:
	return maxf(CLOSE_MIN, _wide * CLOSE_TIMES)


# 5：勝利。倒れた怪獣の前で、二人が近づいて万歳。寄りで撮る
func _rule_cheer(i: int, f: Dictionary, dt: float, crew: bool) -> void:
	if _stuck():
		_note(i, ["役者が物にぶつかって、立ち止まった"], dt)
		return
	if not (game.actors[0].beat_arrived() and game.actors[1].beat_arrived()):
		return
	var r: Array = game.judge.problems(f)
	var acts: Array = f["actors"]
	if not f["close"]:
		r.append("二人が近づいていなかった")
	if not f["monster_down"]:
		r.append("倒れた怪獣が映っていなかった")
	if r.is_empty() and minf(float(acts[0]["h"]), float(acts[1]["h"])) < close_need():
		r.append("寄りが足りない（二人を、今までより大きく映す）")
	if crew:
		r.append("スタッフが映っていた")
	_count(i, r, dt, NEED_CHEER)


# 見せる（どの台本でも使える）：着いた二人が、明るく映っている。
#   role＝その役の物も一緒に映る（"castle"：城役が、倒れず・裏を見せずに映る / "moon"：月役が画面に入る）
#   hide＝その役の物が映っていてはいけない（場所が変わった場面。"castle"）/ close＝寄りで大きく、二人が近づいている
# 動くカメラ：歩いている二人を映したまま、撮影カメラが動く（台車に載せる・押す・引かせる）。押す人が映ってはいけない
func _rule_track(i: int, f: Dictionary, dt: float, crew: bool) -> void:
	var cam: Vector3 = game.program_camera().global_position
	var step := 0.0 if _track_last == Vector3.INF else Vector2(cam.x - _track_last.x, cam.z - _track_last.z).length()
	_track_last = cam
	if step > TRACK_JUMP:
		return          # カメラを切り替えた
	if _stuck():
		_note(i, ["役者が物にぶつかって、立ち止まった"], dt)
		return
	if not (game.actors[0].beat_walking() and game.actors[1].beat_walking()):
		return          # 歩いていない間は、数えない
	var r: Array = game.judge.problems(f)
	if crew:
		r.append("スタッフが映っていた")
	if r.is_empty() and step < TRACK_SPEED * dt:
		r.append("カメラが止まっていた（歩く二人と一緒に、カメラを動かす）")
	if not r.is_empty():
		_note(i, r, dt)
		return
	_track_m += step
	if _track_m >= NEED_TRACK:
		_met(i)


# 上から落ちる：立ち止まった二人を映している間に、そばで物が1m以上落ちる（画面の中で）。落とす人が映ってはいけない
func _rule_drop(i: int, f: Dictionary, dt: float, crew: bool) -> void:
	var film: Node3D = game.program_camera()
	var cam: Camera3D = film.view_cam
	var vs := Vector2(film.view.size)
	var fell := false
	for p: Node3D in game.props.values():
		if p.absent or p.holder != 0 or p.immovable or p.fixed or p.stored_in != 0 or p.kind in ["mark", "truck"]:
			continue
		var c: Vector3 = p.center_global()
		var top := maxf(float(_drop_top.get(p.pid, c.y)), c.y)
		_drop_top[p.pid] = top
		if top - c.y >= DROP_M and game.judge._in_frame(cam, vs, c):
			fell = true
			_drop_top[p.pid] = c.y          # 同じ物は、もう一度持ち上がるまで数えない
	if not fell:
		return
	if not (game.actors[0].beat_arrived() and game.actors[1].beat_arrived()):
		_note(i, ["二人が立ち止まる前に落ちた"], dt)
		return
	var r: Array = game.judge.problems(f)
	if crew:
		r.append("スタッフが映っていた（落とす人は映さない）")
	if not r.is_empty():
		_note(i, r, dt)
		return
	_met(i)


# 大岩に追われる：走って逃げる二人の後ろから、転がる物（回りながら進む物）が迫ってくる。押す人・引く人が映ってはいけない。
# 「後ろ」は二人の逃げる向きで決める（カメラの向きは問わない。正面から撮っても、横から撮ってもいい）
func _rule_chase(i: int, f: Dictionary, dt: float, crew: bool) -> void:
	if _stuck():
		_note(i, ["役者が物にぶつかって、立ち止まった"], dt)
		return
	var a0: Node3D = game.actors[0]
	var a1: Node3D = game.actors[1]
	if not (a0.beat_walking() and a1.beat_walking()):
		return          # 走っていない間は、数えない
	var r: Array = game.judge.problems(f)
	if crew:
		r.append("スタッフが映っていた（押す人・引く人は映さない）")
	var mid: Vector3 = (a0.global_position + a1.global_position) * 0.5
	var goal: Vector3 = (a0.beat as Dictionary).get("to", mid)
	var run := Vector3(goal.x - mid.x, 0.0, goal.z - mid.z)
	if run.length() < 0.05:
		return
	run = run.normalized()
	var film: Node3D = game.program_camera()
	var cam: Camera3D = film.view_cam
	var vs := Vector2(film.view.size)
	var space := film.get_world_3d().direct_space_state
	var miss := "二人の後ろから、転がって迫る物が無かった"
	var chased := false
	for p: Node3D in game.props.values():
		if p.absent or p.holder != 0 or p.kind in ["mark", "truck"]:
			continue
		var v: Vector3 = p.linear_velocity
		var flat := Vector3(v.x, 0.0, v.z)
		if flat.length() < CHASE_SPEED or p.angular_velocity.length() < CHASE_SPIN or flat.dot(run) <= 0.0:
			continue
		var c: Vector3 = p.center_global()
		var rel := Vector3(c.x - mid.x, 0.0, c.z - mid.z)
		if rel.dot(run) > 0.3:
			miss = "転がる物が、二人の前にあった（後ろから迫って見えない）"
			continue
		var near := minf(Vector2(c.x - a0.global_position.x, c.z - a0.global_position.z).length(), Vector2(c.x - a1.global_position.x, c.z - a1.global_position.z).length())
		if near > CHASE_NEAR:
			miss = "転がる物が、二人から遠かった"
			continue
		if not game.judge._in_frame(cam, vs, c) or game.judge._blocked(space, cam.global_position, c, [film.get_rid(), p.get_rid()]):
			miss = "転がって迫る物が、映っていなかった"
			continue
		chased = true
		break
	if not chased:
		r.append(miss)
	_count(i, r, dt, NEED_CHASE)


func _rule_show(i: int, f: Dictionary, dt: float, crew: bool) -> void:
	if _stuck():
		_note(i, ["役者が物にぶつかって、立ち止まった"], dt)
		return
	if not (game.actors[0].beat_arrived() and game.actors[1].beat_arrived()):
		return
	var b: Dictionary = list()[i]
	var r: Array = game.judge.problems(f)
	match str(b.get("role", "")):
		"castle":
			if not f.get("castle", false):
				r.append("城の裏側が映っていた" if f.get("castle_back", false) else ("城役の物が映っていなかった" if f.get("castle_any", false) else "城役の物が決まっていない（物を見て Y で城の役にする）"))
		"moon":
			if not f.get("moon", false):
				r.append("月役の物が映っていなかった（物を見て Y で月の役にする）")
	# 場所が変わった場面：前の場面の物が映っていたら、同じ場所に見える（場転で、片づける・隠す）
	match str(b.get("hide", "")):
		"castle":
			if f.get("castle", false) or f.get("castle_back", false):
				r.append("前の場面の城が映っていた（場所が変わったように見えない。片づけるか、隠す）")
	if b.get("close", false):
		var acts: Array = f["actors"]
		if not f["close"]:
			r.append("二人が近づいていなかった")
		elif r.is_empty() and minf(float(acts[0]["h"]), float(acts[1]["h"])) < CLOSE_MIN:
			r.append("寄りが足りない（カメラを二人へ寄せる）")
	if crew:
		r.append("スタッフが映っていた")
	_count(i, r, dt, NEED_SHOW)


# 背後で爆発（どの台本でも使える）：この場面の間に起きた爆発が、二人の背後に、二人と一緒に映る。
# 爆発から judge.BOOM_WINDOW 秒のうちに NEED_BOOM 秒。だめなら、次の爆発を待つ
func _rule_blast(i: int, f: Dictionary, dt: float, crew: bool, t: float) -> void:
	if _boom_t < 0.0 or _boom_done:
		return
	var jd: RefCounted = game.judge
	if t - _boom_t <= jd.BOOM_WINDOW:
		var r: Array = jd.problems(f, false)
		if not f["fx_in"]:
			r.append("爆発が画面に入っていなかった")
		elif not f["fx_behind"]:
			r.append("爆発が二人より手前だった")
		if crew:
			r.append("スタッフが映っていた")
		if r.is_empty():
			_boom_acc += dt
			if _boom_acc >= NEED_BOOM:
				_boom_done = true
				_met(i)
		else:
			_note(i, r, dt)
		return
	# 間に合わなかった：次の爆発を待つ
	if _top_reason(i) == "":
		_note(i, ["爆発と二人が一緒に映る時間が足りなかった"], 1.0)
	_boom_t = -1.0
	_boom_acc = 0.0


# テイクの結果（場面ごとの成否と、撮れなかった理由）
func results() -> Array:
	var out: Array = []
	var beats := list()
	var titles: Array = flow.job()["scenes"]
	var film_out: bool = float(game.take_t) >= FILM_SEC - 0.05
	for i in beats.size():
		var ok: bool = i < lit.size() and bool(lit[i])
		var rule := str(beats[i].get("rule", ""))
		var detail := ""
		if ok:
			detail = "%.1f秒で成立" % float(met_at[i])
		elif i >= _entered.size() or not _entered[i]:
			detail = "フィルムが切れて、この場面まで進まなかった" if film_out else "この場面まで進めなかった（台本を読める人が、1 で進める）"
		else:
			detail = _top_reason(i)
			if detail == "" and rule == "attack" and _boom_t < 0.0 and _boom_before:
				detail = "爆発が、この場面より前に起きた（順序が違う）"
			if detail == "":
				detail = str(NO_REASON.get(rule, "映る時間が足りなかった"))
		out.append({"ok": ok, "title": str(titles[i]) if i < titles.size() else "", "detail": detail, "at": float(met_at[i]) if i < met_at.size() else -1.0})
	return out


# ---- 登録（feature_hooks.gd）。決まった名前の関数を持っていると、中心の側が呼ぶ ----

func hook_events() -> Array:
	return ["beat"]


# 場面の進み：いまの場面・撮れた場面のランプ・稽古かどうか
func hook_event(_n: String, a: Array) -> void:
	receive(a[0])


# 場面の進み（いまの場面・ランプ）は、見返しでも同じに流す
func hook_rec_events() -> Array:
	return ["beat"]


func hook_sync(who: int) -> void:
	sync_to(who)


# 準備中にテイクを始める直前：通し稽古は、ここまで。役者は最初の印へ戻る
func hook_take_ready() -> void:
	host_reset()


# 本番が始まった：場面は最初から。ランプは全部消えている（この知らせは、見返しの最初にも流れる）。
# カット割りの依頼では、カチンコの合図で、最初の場面がそのまま始まる
func hook_take_start() -> void:
	if active():
		host_reset()
		_broadcast()
		if cut_mode():
			_enter(0, false)


func hook_take_cut() -> void:
	host_reset()


func hook_retake_done() -> void:
	host_reset()


func hook_playback(on: bool) -> void:
	playback_changed(on)


# 依頼を受けた：場面の列を持つ依頼なら、役者の印（①②③）を現場に並べる
func hook_new_job() -> void:
	host_new_job()


# 場面の列を持つ依頼のときだけ、印②③・リール・ランプを出す
func hook_production_applied() -> void:
	refresh()

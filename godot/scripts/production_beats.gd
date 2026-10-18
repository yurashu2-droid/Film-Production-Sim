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
const Cast := preload("res://scripts/production_cast.gd")

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
# 名場面のパロディ用（_rule_ring ほか）
const RING_WINDOW := 0.6          # 鳴る（ring）：鳴ってから、この秒数のうちに映っていれば数える
const NEED_CROSS := 0.25          # 月の前を横切る（cross）：月に重なって動いている秒数（横切るのは一瞬）
const HIT_SPEED := 1.4            # 当たる（hit）：これより速く動いている物が当たったら
const HIT_NEAR := 0.55            # 当たる：役者の胸から、物の真ん中まで（＋物の大きさの半分）
const SCORCH_NEAR := 1.0          # 焦げる（scorch）：炎が、役者の腰からこの距離まで
const NEED_SCORCH := 0.4
const HIGH_M := 0.4               # 高い所（high）：足元が、床からこれだけ上
const NEED_HIGH := 1.2
const NEED_WIND := 1.2            # 風（wind）：二人が風を受けて映っている秒数
const ORBIT_RAD := 1.05           # 回り込む（orbit）：カメラの向きが、二人のまわりでこれだけ（約60度）変わる
const CLIMB_M := 0.8              # 駆け上がる（climb）：場面の始まりより、これだけ高い所に着く
const PASS_SIZE := 0.45           # 走り抜ける（pass）：これより大きい物（いちばん長い向きの半分）
const PASS_SPEED := 0.9
const PASS_M := 2.0
# 役者ごとの印 ①②③ の、最初の置き場所（現場の座標）。班が、好きな所へ置き直す
# （室内スタジオの左右の壁は x＝±4.1。どの現場でも、壁の内側に並ぶようにしてある）
const MARK_HOME := [[Vector3(-3.4, 0.05, -1.5), Vector3(-0.6, 0.05, -1.5), Vector3(2.6, 0.05, -1.5)],
	[Vector3(-3.4, 0.05, -0.3), Vector3(-0.6, 0.05, -0.3), Vector3(2.6, 0.05, -0.3)],
	[Vector3(-3.4, 0.05, 0.9), Vector3(-0.6, 0.05, 0.9), Vector3(2.6, 0.05, 0.9)],
	[Vector3(-3.4, 0.05, 2.1), Vector3(-0.6, 0.05, 2.1), Vector3(2.6, 0.05, 2.1)]]
const ACTORS := ["A", "B", "C", "D"]
const MAX_CAST := 4               # 役者は台本ごとに最大4人（A・B は舞台がはじめから持っている。C・D はここで作る）
const Actor := preload("res://scripts/actor.gd")
const EXTRA_CAST := [["03", "役者C"], ["06", "役者D"]]
const STEPS := ["①", "②", "③"]
# 場面ごとの、理由が1つも控えられなかったときの文
const NO_REASON := {
	"sign": "看板と役者が一緒に映る時間が足りなかった",
	"roll": "一人ずつの寄りが、そろわなかった",
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
	"ring": "時計（ボタン）が鳴るところが映らなかった",
	"cross": "月の前を横切るところが映らなかった",
	"hit": "役者に物が当たるところが映らなかった",
	"scorch": "役者のそばの炎が映らなかった",
	"high": "高い所に立つ二人が映る時間が足りなかった",
	"wind": "風を受ける二人が映る時間が足りなかった",
	"orbit": "二人のまわりを、カメラが回り込まなかった",
	"climb": "上りきった二人が映らなかった",
	"pass": "大きな物が、画面の中を走り抜けなかった",
}

var game: Node
var flow: Node
var marks: Array = [[], [], [], []]       # 役者ごとの印 [①, ②, ③]（A〜D）
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
# 一人ずつ寄り（"roll"）：役ごとに、寄りで撮れたか（全員の画面。view に載る）。全員そろうと、その場面が撮れる
var roll_done: Array = [false, false, false, false]
var roll_holds := 0               # 一人ずつ寄りの途中で、フィルムを止めた回数（0 のまま撮り切ると、カメラを振って一続きに撮った）
var roll_cut: Dictionary = {}     # 一人ずつ寄りで、頭が見切れたまま撮れた役（役の番号 → true）
const ROLL_MIN := 0.55            # 一人ずつ寄り：その人の身長が、画面の高さに対してこれ以上（胸から上が大きく映る）
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
var _orbit_sum := 0.0             # 回り込む：カメラが二人のまわりを回った角度
var _orbit_last := NAN
var _climb_y0: Array = []         # 駆け上がる：場面の始まりの、二人の高さ
var _pass_m := {}                 # 走り抜ける：画面の中を走った距離（物のID → m）
# 画面
var _playback := false
var _before_replay := {}
var _rattle := 0.0


# 印②③ を作る。全員の画面で同じ順に呼ぶ（物のIDがそろう）。ふだんは片づけてあり、この依頼のときだけ出る
func setup() -> void:
	flow = game.production
	# 役者C・D と、その最初の印（ふだんは誰も演じない＝舞台の外で待つ。台本の人数が3人以上の依頼のときだけ出る）
	for k in EXTRA_CAST.size():
		var aid: int = 2 + k
		var first: RigidBody3D = game.stage.spawn_mark(aid, Vector3(float(game.props.size() + 1) * 3.0, -60.0, 40.0))
		var a: CharacterBody3D = Actor.new()
		a.game = game
		a.aid = aid
		a.label = str(EXTRA_CAST[k][1])
		a.name = "Actor%d" % aid
		a.setup(str(EXTRA_CAST[k][0]), [])
		a.mark = first
		a.position = Vector3(float(aid) * 3.0, -40.0, -40.0)
		game.stage.add_child(a)
		game.actors.append(a)
		a.set_grade("none")
	for k in EXTRA_CAST.size():
		game.actors[2 + k].partner = game.actors[3 - k]
	for aid in MAX_CAST:
		marks[aid] = [game.actors[aid].mark]
	for aid in MAX_CAST:
		for _more in 2:
			var disc: RigidBody3D = game.stage.spawn_mark(aid, Vector3(float(game.props.size() + 1) * 3.0, -60.0, 40.0))
			(marks[aid] as Array).append(disc)
	for aid in MAX_CAST:
		for step in 3:
			_dress(marks[aid][step], aid, step)
	# 最初の置き場所（会社の前で撮ったあと、ここへ戻す）
	for aid in MAX_CAST:
		_mark_start.append([])
		for step in 3:
			(_mark_start[aid] as Array).append((marks[aid][step] as RigidBody3D).get_state())
	refresh()


# 印に、番号を付ける：円盤の上の数字（床の印として、映画にも映る）。役者は円盤の色で分かる
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


func mark(aid: int, step: int) -> RigidBody3D:
	return marks[aid][clampi(step, 0, 2)]


# 印を、その場に留める・戻す（ホスト。爆風を計算する間だけ留める。production_main.gd の host_burst）
func pin_marks(on: bool) -> void:
	for aid in MAX_CAST:
		for step in 3:
			(marks[aid][step] as RigidBody3D).immovable = on


# いまの依頼の、場面の列（無ければ空）
func list() -> Array:
	return Scripts.beats(flow.chosen_job) if flow != null else []


# いまの依頼が、場面の列で進む依頼か（依頼を受けてから、事務所へ戻るまで）
func active() -> bool:
	return flow != null and flow.phase >= 1 and not list().is_empty()


# この台本の役者の人数（台本の "cast"。場面の列が無い依頼は二人）
func cast_count() -> int:
	return int(Scripts.cast_size(flow.chosen_job)) if active() else 2


# 出ている役者：この台本の人数の中で、いま誰かが演じている役者（数えるのは、この役者たちだけ）。
# 場面に "who"（出る役の番号の並び）があれば、その役者だけ（社長だけの場面 など）
func present() -> Array:
	var who := _who(scene)
	var out: Array = []
	for a: CharacterBody3D in game.actors:
		if int(a.aid) < cast_count() and a.present() and (who.is_empty() or int(a.aid) in who):
			out.append(a)
	return out


# その場面に出る役の番号（"who"。無ければ全員）
func _who(i: int) -> Array:
	var l := list()
	if i >= 0 and i < l.size() and str((l[i] as Dictionary).get("rule", "")) == "roll":
		var next := roll_target()
		return [next] if next >= 0 else [-1]
	return (l[i] as Dictionary).get("who", []) if i >= 0 and i < l.size() else []


# 一人ずつ寄り：次に寄りで撮る役（出ている役のうち、まだ撮れていない最初の役。全員撮れていれば -1）
func roll_target() -> int:
	for a: CharacterBody3D in game.actors:
		var aid := int(a.aid)
		if aid < cast_count() and a.present() and not bool(roll_done[aid]):
			return aid
	return -1


# 一人ずつ寄り：撮れた人数と、出ている人数
func roll_count() -> Vector2i:
	var done := 0
	var here := 0
	for a: CharacterBody3D in game.actors:
		var aid := int(a.aid)
		if aid < cast_count() and (a.present() or bool(roll_done[aid])):
			here += 1
			done += 1 if bool(roll_done[aid]) else 0
	return Vector2i(done, here)


# 役の呼び名（台本の "cast"。"社員" のように同じ名前が続くときは、役の記号を付ける）
func role_name(aid: int) -> String:
	var names: Array = Scripts.cast(flow.chosen_job) if active() else []
	var name: String = str(names[aid]) if aid < names.size() else "役者%s" % ACTORS[aid]
	return name if names.count(name) <= 1 else "%s%s" % [name, ACTORS[aid]]


# 出ている役者が全員、そうなっているか（例：_all("beat_arrived")）。誰も出ていなければ false
func _all(method: String) -> bool:
	var here := present()
	return not here.is_empty() and here.all(func(a: Node) -> bool: return bool(a.call(method)))


# 必ず誰かが演じる役のうち、誰も演じていない役の名前
func missing_cast() -> Array:
	var out: Array = []
	if not active():
		return out
	var names: Array = Scripts.cast(flow.chosen_job)
	for aid in mini(Scripts.cast_need(flow.chosen_job), (game.actors as Array).size()):
		if not game.actors[aid].present():
			out.append(str(names[aid]) if str(names[aid]).length() > 1 else "役者%s" % ACTORS[aid])
	return out


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
	var cast := cast_count()
	for aid in MAX_CAST:
		for step in 3:
			var item: RigidBody3D = marks[aid][step]
			if step > 0 or aid >= 2:
				item.set_absent(not on or aid >= cast)
			item.label = "立ち位置の印 %s%s" % [ACTORS[aid], STEPS[step] if on else ""]
			(item.get_node("Numeral") as Node3D).visible = on
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
		refresh()
		for aid in MAX_CAST:
			for step in 3:
				(marks[aid][step] as RigidBody3D).restore([MARK_HOME[aid][step] + flow.site_center(), Quaternion.IDENTITY, false])
		for a: CharacterBody3D in game.actors:
			a.set_state(a.St.STANDBY)
	_broadcast()


# 帰社（ホスト）：会社の前で撮ったあとは、印を、軽トラで行く現場の最初の置き場所へ戻す（役者もそこへ戻る）
func hook_return_office() -> void:
	if not multiplayer.is_server() or not flow.shoots_home():
		return
	for aid in MAX_CAST:
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
	var out: Array = []
	for aid in MAX_CAST:
		out.append(mark(aid, to).global_position)
	if b.get("meet", false):
		var here: Array = present().map(func(a: Node) -> int: return int(a.aid))
		if here.size() >= 2:
			var first: Vector3 = out[here[0]]
			var last: Vector3 = out[here[here.size() - 1]]
			var apart := Vector3(first.x - last.x, 0.0, first.z - last.z)
			if apart.length() > MEET_GAP * float(here.size() - 1):
				var mid := Vector3.ZERO
				for k: int in here:
					mid += out[k]
				mid /= float(here.size())
				var dir := apart.normalized()
				for n in here.size():
					var k: int = here[n]
					var off := dir * MEET_GAP * (float(here.size() - 1) * 0.5 - float(n))
					out[k] = Vector3(mid.x + off.x, (out[k] as Vector3).y, mid.z + off.z)
	return out


# その場面を始める（again＝やり直し。役者は、その場面の最初の印まで走って戻ってから、もう一度演じる）
func _enter(i: int, again: bool) -> void:
	var b: Dictionary = list()[i]
	scene = i
	rehearsal = game.state == game.S.PREP
	var targets := _targets(b)
	var faces: Array = b.get("face", ["neutral", "neutral"])
	var who := _who(i)
	for a: CharacterBody3D in game.actors:
		if not who.is_empty() and int(a.aid) not in who:
			continue          # この場面に出ない役者は、その場で待つ
		var pose := str((b.get("pose_by", {}) as Dictionary).get(str(a.aid), b.get("pose", "idle")))
		var spec := {"to": targets[a.aid], "gait": str(b.get("gait", "walk")), "pose": pose,
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
	# 一人ずつ寄りの途中で止めた（カメラを寄せ直す）
	if scene >= 0 and scene < list().size() and str(list()[scene].get("rule", "")) == "roll" and scene < lit.size() and not bool(lit[scene]):
		roll_holds += 1
	next_scene = clampi(next, 0, list().size() - 1)
	var b: Dictionary = list()[next_scene]
	var who := _who(next_scene)
	for a: CharacterBody3D in game.actors:
		if not who.is_empty() and int(a.aid) not in who:
			continue
		a.play_beat({"to": mark(a.aid, int(b.get("from", 0))).global_position, "gait": "walk", "pose": "idle",
			"look": "", "face_go": "neutral", "face_hold": "neutral"})
	game.host_ev("music", [""])
	game.host_ev("sfx", ["clap", null])
	var title := hold_title(next_scene)
	game.host_ev("toast", ["カット！ フィルムを止めた。場転：『%s』の用意ができたら、台本を読める人が 1 で回す" % title, 0])
	holding = true          # 止めてから配る（止めた知らせは、見返しの記録に入らない）
	_broadcast()


# 場転の札・知らせに出す、次に撮る物の名前（一人ずつ寄りの途中なら、次に寄る人も）
func hold_title(next: int) -> String:
	var titles: Array = flow.job()["scenes"]
	var title: String = str(titles[next]) if next >= 0 and next < titles.size() else ""
	if next >= 0 and next < list().size() and str(list()[next].get("rule", "")) == "roll":
		var aid := roll_target()
		if aid >= 0:
			var c := roll_count()
			title = "%s・%sの寄り %d/%d" % [title.get_slice("（", 0), role_name(aid), c.x + 1, c.y]
	return title


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
	return {"scene": scene, "lit": lit.duplicate(), "rehearsal": rehearsal, "hold": holding, "next": next_scene, "roll": roll_done.duplicate()}


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
	roll_done = (data.get("roll", [false, false, false, false]) as Array).duplicate()


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
	roll_done = [false, false, false, false]
	roll_holds = 0
	roll_cut = {}
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
		"orbit":
			_orbit_sum = 0.0
			_orbit_last = NAN
		"climb":
			_climb_y0 = []
		"pass":
			_pass_m = {}


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
	var missing := missing_cast()
	if not missing.is_empty():
		_note(scene, ["%sを、誰も演じていない（Y で役に入る・電話で雇う・等身大パネル）" % "・".join(PackedStringArray(missing))], dt)
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
		"ring":
			_rule_ring(scene, f, dt, crew)
		"cross":
			_rule_cross(scene, f, dt, crew)
		"hit":
			_rule_hit(scene, f, dt, crew)
		"scorch":
			_rule_scorch(scene, f, dt, crew)
		"high":
			_rule_high(scene, f, dt, crew)
		"wind":
			_rule_wind(scene, f, dt, crew)
		"orbit":
			_rule_orbit(scene, f, dt, crew)
		"climb":
			_rule_climb(scene, f, dt, crew)
		"pass":
			_rule_pass(scene, f, dt, crew)
		"sign":
			_rule_sign(scene, f, dt, crew)
		"roll":
			_rule_roll(scene, f, dt, crew)


func _stuck() -> bool:
	return present().any(func(a: Node) -> bool: return a.beat_stuck())


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
	if not _all("beat_walking"):
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
	if not _all("beat_arrived"):
		return
	var r: Array = game.judge.problems(f)
	r.append_array(game.judge.kaiju_problems(f))
	if crew:
		r.append("スタッフが映っていた")
	if r.is_empty():
		var acts: Array = f["actors"]
		_wide_sum += game.judge.min_h(f) * dt
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
	if not _all("beat_arrived"):
		return
	var r: Array = game.judge.problems(f)
	var acts: Array = f["actors"]
	if not f["close"]:
		r.append("二人が近づいていなかった")
	if not f["monster_down"]:
		r.append("倒れた怪獣が映っていなかった")
	if r.is_empty() and game.judge.min_h(f) < close_need():
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
	if not _all("beat_walking"):
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
	if not _all("beat_arrived"):
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
	if not _all("beat_walking"):
		return          # 走っていない間は、数えない
	var a0: Node3D = present()[0]
	var r: Array = game.judge.problems(f)
	if crew:
		r.append("スタッフが映っていた（押す人・引く人は映さない）")
	var mid: Vector3 = game.actors_mid()
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
		var near := INF
		for a: Node3D in present():
			near = minf(near, Vector2(c.x - a.global_position.x, c.z - a.global_position.z).length())
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


# ---- 名場面のパロディ用の決まり（ring・cross・hit・scorch・high・wind・orbit・climb・pass） ----

func _view() -> Array:
	var film: Node3D = game.program_camera()
	return [film, film.view_cam, Vector2(film.view.size), film.get_world_3d().direct_space_state]


# その点が、撮影カメラに映っているか（画面の中にあって、隠れていない）
func _shows(point: Vector3, skip: Array) -> bool:
	var v := _view()
	var cam: Camera3D = v[1]
	if not game.judge._in_frame(cam, v[2], point):
		return false
	var ex: Array = [(v[0] as Node3D).get_rid()]
	ex.append_array(skip)
	return not game.judge._blocked(v[3], cam.global_position, point, ex)


func _rig() -> Node:
	return game.hooks.feature("contraptions")


# 鳴る：二人が映っている間に、目覚まし時計か押しボタンが、画面の中で鳴る（カップ麺の3分・合図のチン）
func _rule_ring(i: int, f: Dictionary, dt: float, crew: bool) -> void:
	if not _all("beat_arrived"):
		return
	var r: Array = game.judge.problems(f)
	if crew:
		r.append("スタッフが映っていた")
	var rig := _rig()
	var heard := false
	var off := false
	if rig != null:
		for pid: int in rig.rang:
			var p: Node3D = game.props.get(pid)
			if p == null or float(game.take_t) - float(rig.rang[pid]) > RING_WINDOW:
				continue
			if _shows(p.center_global(), [p.get_rid()]):
				heard = true
			else:
				off = true
	if not heard:
		r.append("鳴った物が、映っていなかった" if off else "時計もボタンも、鳴らなかった")
		_note(i, r, dt)
		return
	if r.is_empty():
		_met(i)
	else:
		_note(i, r, dt)


# 月の前を横切る：月役の物の前を、役者が横切る（画面の上で、月の丸に重なって動く）。シルエットなので、顔の明るさは問わない
func _rule_cross(i: int, f: Dictionary, dt: float, crew: bool) -> void:
	var moving: Array = []
	for a: Node in present():
		if a.beat_walking():
			moving.append(a)
	if moving.is_empty():
		return
	var r: Array = game.judge.problems(f, false)
	if crew:
		r.append("スタッフが映っていた")
	var moon: Node3D = null
	for p: Node3D in game.props.values():
		if not p.absent and game.judge.role_of(p) == "moon":
			moon = p
	if moon == null:
		r.append("月役の物が決まっていない（物を見て Y で月の役にする）")
		_note(i, r, dt)
		return
	var v := _view()
	var cam: Camera3D = v[1]
	var c: Vector3 = moon.center_global()
	if cam.is_position_behind(c) or not _shows(c, [moon.get_rid()]):
		r.append("月が映っていなかった")
		_note(i, r, dt)
		return
	var at := cam.unproject_position(c)
	var rad := at.distance_to(cam.unproject_position(c + cam.global_basis.x * maxf(moon.half.x, moon.half.y))) * 1.15
	var depth := (c - cam.global_position).dot(-cam.global_basis.z)
	var over := false
	for a: Node in moving:
		var chest: Vector3 = a.chest_pos()
		if cam.is_position_behind(chest) or (chest - cam.global_position).dot(-cam.global_basis.z) >= depth:
			continue
		if cam.unproject_position(chest).distance_to(at) <= rad or cam.unproject_position(a.head_pos()).distance_to(at) <= rad:
			over = true
	if not over:
		r.append("月の前を、横切っていなかった（画面の上で、月に重ねる）")
	_count(i, r, dt, NEED_CROSS)


# 当たる：動いている物（振り子・投げた物・転がる物）が、役者に当たる。当たった役者は、のけぞる（雇った役者だけ）
func _rule_hit(i: int, f: Dictionary, dt: float, crew: bool) -> void:
	var r: Array = game.judge.problems(f)
	if crew:
		r.append("スタッフが映っていた（落とす人・投げる人は映さない）")
	var hit: Node = null
	var by: Node3D = null
	for p: Node3D in game.props.values():
		if p.absent or p.holder != 0 or p.kind in ["mark", "truck"] or p.linear_velocity.length() < HIT_SPEED:
			continue
		for a: Node in present():
			if p.center_global().distance_to(a.chest_pos()) <= HIT_NEAR + maxf(p.half.x, maxf(p.half.y, p.half.z)) * 0.5:
				hit = a
				by = p
	if hit == null:
		r.append("役者に、何も当たらなかった")
		_note(i, r, dt)
		return
	if hit.get("stand_in") == null:
		hit.knock(Vector3(by.linear_velocity.x, 0.0, by.linear_velocity.z).normalized() * 2.4 + Vector3(0, 1.4, 0))
	if r.is_empty():
		_met(i)
	else:
		_note(i, r, dt)


# 焦げる：点火トーチの炎が、役者のすぐそばで燃えている（お尻に火）。火を付ける人・ボタンを押す人は映さない
func _rule_scorch(i: int, f: Dictionary, dt: float, crew: bool) -> void:
	var r: Array = game.judge.problems(f)
	if crew:
		r.append("スタッフが映っていた")
	var rig := _rig()
	var near := false
	var seen := false
	if rig != null:
		for pid: int in rig.flames:
			var t: Node3D = game.props.get(pid)
			if t == null:
				continue
			var head: Vector3 = t.global_transform * rig.TORCH_HEAD
			for a: Node in present():
				if head.distance_to(a.global_position + Vector3(0, 0.6, 0)) <= SCORCH_NEAR:
					near = true
					seen = seen or _shows(head, [t.get_rid()])
	if not near:
		r.append("炎が、役者のそばで燃えていなかった")
	elif not seen:
		r.append("炎が映っていなかった")
	_count(i, r, dt, NEED_SCORCH)


# 高い所：二人とも、床より高い所（台・バルコニー・箱の上）に立っている（船の舳先・頂上）
func _rule_high(i: int, f: Dictionary, dt: float, crew: bool) -> void:
	if not _all("beat_arrived"):
		return
	var r: Array = game.judge.problems(f)
	if crew:
		r.append("スタッフが映っていた")
	for a: Node3D in present():
		if a.global_position.y < HIGH_M:
			r.append("%sが、高い所に立っていなかった（台や箱の上に印を置く）" % str(a.label))
	_count(i, r, dt, NEED_HIGH)


# 風：回っている送風機の風を、二人が正面から受けている（両手を広げる・髪がなびく）
func _rule_wind(i: int, f: Dictionary, dt: float, crew: bool) -> void:
	if not _all("beat_arrived"):
		return
	var r: Array = game.judge.problems(f)
	if crew:
		r.append("スタッフが映っていた")
	var rig := _rig()
	var windy := 0
	var running := false
	if rig != null:
		for pid: int in rig.fans:
			var fan: Node3D = game.props.get(pid)
			if fan == null:
				continue
			running = true
			var count := 0
			for a: Node in present():
				if rig.in_wind(fan, a.chest_pos()):
					count += 1
			windy = maxi(windy, count)
	if not running:
		r.append("送風機が回っていなかった")
	elif windy < present().size():
		r.append("出ている役者が全員、送風機の風の正面にいなかった")
	_count(i, r, dt, NEED_WIND)


# 回り込む：止まった二人を映したまま、カメラが二人のまわりを回る（向きが ORBIT_RAD 変わる）
func _rule_orbit(i: int, f: Dictionary, dt: float, crew: bool) -> void:
	var mid: Vector3 = game.actors_mid()
	var cam: Vector3 = game.program_camera().global_position
	var ang := atan2(cam.x - mid.x, cam.z - mid.z)
	var step := 0.0 if is_nan(_orbit_last) else absf(wrapf(ang - _orbit_last, -PI, PI))
	_orbit_last = ang
	if step > 0.3 or not _all("beat_arrived"):
		return          # カメラの切り替え・まだ着いていない
	var r: Array = game.judge.problems(f)
	if crew:
		r.append("スタッフが映っていた（カメラを押す人は映さない）")
	if not r.is_empty():
		_note(i, r, dt)
		return
	if step < 0.002:
		_note(i, ["カメラが、二人のまわりを回っていなかった"], dt)
		return
	_orbit_sum += step
	if _orbit_sum >= ORBIT_RAD:
		_met(i)


# 駆け上がる：二人が、この場面の始まりより CLIMB_M 以上高い印に着く（階段・坂・箱を上る）
func _rule_climb(i: int, f: Dictionary, dt: float, crew: bool) -> void:
	if _climb_y0.is_empty():
		for a: Node3D in game.actors:
			_climb_y0.append(a.global_position.y)
	if not _all("beat_arrived"):
		if _stuck():
			_note(i, ["役者が段差にぶつかって、上れなかった（坂や低い段を並べる）"], dt)
		return
	var r: Array = game.judge.problems(f)
	if crew:
		r.append("スタッフが映っていた")
	for a: Node3D in present():
		if a.global_position.y < float(_climb_y0[int(a.aid)]) + CLIMB_M:
			r.append("%sが、上っていなかった（上の印を、高い所に置く）" % a.label)
	_count(i, r, dt, NEED_HIGH)


# 看板の前で：手描きの看板（会社の名前など。features/signboard.gd）と、着いた役者が一緒に映る
func _rule_sign(i: int, f: Dictionary, dt: float, crew: bool) -> void:
	if _stuck():
		_note(i, ["役者が物にぶつかって、立ち止まった"], dt)
		return
	if not _all("beat_arrived"):
		return
	var r: Array = game.judge.problems(f)
	var board: Node = game.hooks.feature("signboard")
	if board == null or not board.showing():
		r.append("手描きの看板が映っていなかった（板やパネルに会社の名前を描いて、表をカメラへ向ける）")
	if crew:
		r.append("スタッフが映っていた")
	_count(i, r, dt, NEED_SHOW)


# 一人ずつ寄り（会社の紹介動画の社員紹介）：出ている役を一人ずつ、寄りで大きく映す（決めポーズ）。
# 一人分が撮れたら、次の人の番。止めずにカメラを振って寄る（撮影技術の加算。features/camera_craft.gd）か、
# 1 でフィルムを止めて、カメラを寄せ直してから回す。全員そろうと、場面が撮れる。
# 頭が画面から切れていても（見切れ）撮れたことにするが、精算で少し引かれる。
# 同じ人が、場転のたびに役を替えて（Y）全部を演じてもいい
func _rule_roll(i: int, f: Dictionary, dt: float, crew: bool) -> void:
	var aid := roll_target()
	if aid < 0:
		_met(i)
		return
	var who: CharacterBody3D = game.actors[aid]
	if who.beat_stuck():
		_note(i, ["役者が物にぶつかって、立ち止まった"], dt)
		return
	if not who.beat_arrived():
		return
	var r: Array = game.judge.problems(f)
	var acts: Array = f["actors"]
	if r.is_empty() and float(acts[aid]["h"]) < ROLL_MIN:
		r.append("寄りが足りない（カメラを%sへ寄せて、胸から上を大きく映す）" % role_name(aid))
	if crew:
		r.append("スタッフが映っていた")
	if not r.is_empty():
		_note(i, r, dt)
		return
	_acc[i] = float(_acc[i]) + dt
	if float(_acc[i]) < NEED_SHOW:
		return
	# 一人分、撮れた（頭が切れていれば、見切れとして控える）
	_acc[i] = 0.0
	roll_done[aid] = true
	if not bool(acts[aid].get("head", true)):
		roll_cut[aid] = true
	var c := roll_count()
	var next := roll_target()
	if next < 0:
		game.host_ev("toast", ["%sの寄り、OK！（%d/%d）　社員紹介、そろった" % [role_name(aid), c.x, c.y], 0])
		_met(i)
		return
	game.host_ev("sfx", ["ui_ok", null])
	if cut_mode() and game.state == game.S.TAKE:
		game.host_ev("toast", ["%sの寄り、OK！（%d/%d）　次は%s：止めずにカメラを振って寄る（撮影技術）か、1 で止めて寄せ直す" % [role_name(aid), c.x, c.y, role_name(next)], 0])
	else:
		game.host_ev("toast", ["%sの寄り、OK！（%d/%d）　次は%s" % [role_name(aid), c.x, c.y, role_name(next)], 0])
	_enter(i, false)


# 走り抜ける：大きな物（車・バスの書割・台車に載せた物）が、画面の中を PASS_M 以上走る（役者は問わない）
func _rule_pass(i: int, _f: Dictionary, dt: float, crew: bool) -> void:
	var r: Array = []
	if crew:
		r.append("スタッフが映っていた（押す人・引く人は映さない）")
	var best := 0.0
	for p: Node3D in game.props.values():
		if p.absent or p.holder != 0 or p.kind in ["mark", "truck"] or maxf(p.half.x, maxf(p.half.y, p.half.z)) < PASS_SIZE:
			continue
		var v: Vector3 = p.linear_velocity
		if Vector2(v.x, v.z).length() < PASS_SPEED or not _shows(p.center_global(), [p.get_rid()]):
			continue
		if r.is_empty():
			_pass_m[p.pid] = float(_pass_m.get(p.pid, 0.0)) + Vector2(v.x, v.z).length() * dt
		best = maxf(best, float(_pass_m.get(p.pid, 0.0)))
	if best >= PASS_M:
		_met(i)
	elif best <= 0.0:
		_note(i, r if not r.is_empty() else ["大きな物が、画面の中を走らなかった"], dt)


func _rule_show(i: int, f: Dictionary, dt: float, crew: bool) -> void:
	if _stuck():
		_note(i, ["役者が物にぶつかって、立ち止まった"], dt)
		return
	if not _all("beat_arrived"):
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
		var want:
			# 名場面のパロディの役（船・玄関・カップ麺 など。production_cast.gd の SCRIPT_ROLES）
			if want != "" and not (f.get("roles_in", {}) as Dictionary).has(want):
				var title: String = Cast.role_title(want, game.production.story() if game.production != null else "")
				r.append("%sの物が映っていなかった（物を見て Y で%sにする）" % [title, title])
	# 場所が変わった場面：前の場面の物が映っていたら、同じ場所に見える（場転で、片づける・隠す）
	match str(b.get("hide", "")):
		"castle":
			if f.get("castle", false) or f.get("castle_back", false):
				r.append("前の場面の城が映っていた（場所が変わったように見えない。片づけるか、隠す）")
	if b.get("close", false):
		var acts: Array = f["actors"]
		if not f["close"]:
			r.append("二人が近づいていなかった")
		elif r.is_empty() and game.judge.min_h(f) < CLOSE_MIN:
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

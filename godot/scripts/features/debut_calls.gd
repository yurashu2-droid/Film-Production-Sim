extends Node
## 最初の一本（会社の紹介動画）をネットに上げて事務所へ戻ると、机の黒電話が鳴る：動画を見た、地方テレビ局のランプ部長から。
## 「動画を見て、依頼が来た」を、画面の文だけでなく、事務所の物（鳴って震える電話）で見せる。
## 決めるのはホスト（帰社のあと、知らせを1回）。鳴らす・震わせるのは、全員の画面。
const Office := preload("res://scripts/production_office.gd")
const RINGS := 3              # 鳴る回数
const RING_GAP := 1.3         # 鳴る間（秒）

var game: Node
var rang := 0                 # この画面で鳴った回数（確認用）
var _pending := false         # ホスト：CMを納品して、帰社の途中
var _quiet := false           # ホスト：CMに1場面も映らず、電話が来ない（翌日もう一度、紹介動画。production_flow.gd の debut_redo）


## 1場面も映っていない紹介動画には、電話が来ない（コメント欄も空。production_flow.gd の settle）
func hook_return_office() -> void:
	var flow: Node = game.production
	var debut: bool = flow != null and bool(flow.job().get("debut", false)) and int(flow.phase) == 5
	_quiet = debut and bool(flow.debut_redo)
	_pending = debut and not _quiet


func hook_office_ready() -> void:
	if _quiet:
		_quiet = false
		game.host_ev("toast", ["電話は鳴らない。何も映っていない動画では、誰も見てくれなかった。もう一度、紹介動画を撮ろう（事務所の掲示板へ）", 1])
		return
	if not _pending:
		return
	_pending = false
	game.host_ev("toast", ["電話だ！「%sさんですか？ 動画、見ましたよ」地方テレビ局のランプ部長から。明日から、仕事の依頼が来る（事務所の掲示板へ）" % game.production.COMPANY, 0])
	game.host_ev("debut_ring", [])


func hook_events() -> Array:
	return ["debut_ring"]


func hook_event(_n: String, _a: Array) -> void:
	rang += 1
	var phone: Node3D = game.find_child("OrderPhone", true, false) as Node3D
	var at: Vector3 = phone.global_position if phone != null else Office.ORDER_PHONE
	for i in RINGS:
		get_tree().create_timer(RING_GAP * i).timeout.connect(_ring.bind(phone, at))


# ジリリリ：鳴らして、電話を小刻みに震わせる
func _ring(phone: Node3D, at: Vector3) -> void:
	Sfx.play("phone_ring", at)
	if phone == null or not is_instance_valid(phone):
		return
	var shake := create_tween()
	for i in 8:
		shake.tween_property(phone, "rotation:z", 0.06 if i % 2 == 0 else -0.06, 0.05)
	shake.tween_property(phone, "rotation:z", 0.0, 0.05)

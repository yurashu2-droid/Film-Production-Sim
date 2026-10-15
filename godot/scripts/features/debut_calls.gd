extends Node
## 最初の一本（会社のCM）を放送して事務所へ戻ると、机の黒電話が鳴る：CMを見た人から、依頼の電話が鳴りやまない。
## 「PR動画を見て、依頼が来た」を、画面の文だけでなく、事務所の物（鳴って震える電話）で見せる。
## 決めるのはホスト（帰社のあと、知らせを1回）。鳴らす・震わせるのは、全員の画面。
const Office := preload("res://scripts/production_office.gd")
const RINGS := 3              # 鳴る回数
const RING_GAP := 1.3         # 鳴る間（秒）

var game: Node
var rang := 0                 # この画面で鳴った回数（確認用）
var _pending := false         # ホスト：CMを納品して、帰社の途中


func hook_return_office() -> void:
	var flow: Node = game.production
	_pending = flow != null and bool(flow.job().get("debut", false)) and int(flow.phase) == 5


func hook_office_ready() -> void:
	if not _pending:
		return
	_pending = false
	game.host_ev("toast", ["電話が鳴りやまない！ CMを見た人から、依頼が来ている（事務所の掲示板へ）", 0])
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

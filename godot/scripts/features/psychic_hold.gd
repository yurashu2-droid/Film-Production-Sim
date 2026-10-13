extends Node
# 念力の見た目（vfx/vfx_psychic.gd）：物を持っている間、手から物へ念波が飛び、物の輪郭が念の膜に包まれる。
# 物は視線の先に浮かせて持つ作りなので、手が届かない所の物を動かせる理由を「念力」として見せる。
# 手で直接持てる近さ（G で手元へ寄せた時など）では、演出の側で薄れて消える。
# 持つ・離すの同期には手を入れない。全員の画面で、各自が参加者の held（持っている物のID）を毎コマ見て、出し入れする。
# 登録の土台（feature_hooks.gd）が、置いてあるだけで作ってくれる（docs/FEATURE_HOOKS.md）。中心のファイルには何も足していない。

const Psychic := preload("res://vfx/vfx_psychic.gd")
const CREW_LAYER := 1 << 11       # film_camera.gd と同じ番号（映画には映らない層）
# 映画（撮影カメラ）にも映すか。false＝制作班の画面にだけ見える（撮れる映像は今までどおり）
const IN_FILM := false
# キャラごとの念の色（main.gd の PLAYER_CASTS の番号）。そのキャラの持ち色から。表に無いキャラは紫
const TINTS := {
	"M02": Color(0.55, 0.4, 1.0),     # ロボット：腕の薄紫
	"04": Color(1.0, 0.5, 0.2),       # ベレー帽の人：首のオレンジ
	"09": Color(0.25, 0.85, 0.95),    # 段ボール頭：蝶ネクタイの水色
	"03": Color(1.0, 0.3, 0.42),      # 手帳の人：シャツの赤
	"01": Color(1.0, 0.42, 0.72),     # ドレスの人：ドレスのピンク
	"02": Color(0.45, 0.95, 0.5),     # カエルの警官：顔の緑
	"06": Color(1.0, 0.8, 0.3),       # モップの王様：王冠の金
}

var game: Node
# 見た目の型（vfx_psychic.gd の STYLES）：mix / nenpa / yuragi。project.godot の vfx/psychic_style で選ぶ。"off" で出さない
var style := str(ProjectSettings.get_setting("vfx/psychic_style", "mix"))
var _links: Dictionary = {}       # 参加者のID → [持っている物のID, 演出]


func _ready() -> void:
	process_priority = 40         # 体と物が動いた後、演出（50）の前
	# 画面なしの実行では出さない（見た目だけの物なので）
	if DisplayServer.get_name() == "headless" or style == "off":
		set_process(false)


func _process(_delta: float) -> void:
	if game == null:
		return
	for id: int in _links.keys():
		if not game.players.has(id):
			_drop(id)
	for id: int in game.players:
		var pl: Node3D = game.players[id]
		var prop: Node3D = game.props.get(pl.held) if pl.held != 0 else null
		if prop != null and (not is_instance_valid(prop) or prop.absent or not prop.is_visible_in_tree()):
			prop = null
		if _links.has(id) and (prop == null or _links[id][0] != pl.held or not is_instance_valid(_links[id][1])):
			_drop(id)
		if prop == null:
			continue
		if not _links.has(id):
			_links[id] = [pl.held, Psychic.attach(game, prop, {
				"style": style, "tint": TINTS.get(str(pl.vis.tag), Psychic.TINT),
				"layers": 1 if IN_FILM else CREW_LAYER, "center": prop.center, "half": prop.half,
			})]
		_links[id][1].hold(_hands(pl, prop), prop.get_global_transform_interpolated() * (prop.hold_grip_local as Vector3))


func _drop(id: int) -> void:
	var fx: Variant = _links[id][1]
	if is_instance_valid(fx):
		fx.release()
	_links.erase(id)


# 手の場所（ワールド）。片手で持つ小物は右手だけ、ほかは両手
func _hands(pl: Node3D, prop: Node3D) -> PackedVector3Array:
	var skel: Skeleton3D = pl.vis.skel
	var out := PackedVector3Array()
	# 一人称：自分にだけ見える腕の写しは、物のほうへ寄せてある（first_person_arms.gd）。その手首に合わせる
	var arms: Node3D = pl.arms if pl.is_local and pl.first_person and is_instance_valid(pl.arms) and pl.arms.visible else null
	var source: MeshInstance3D = arms.get_node_or_null(arms.get_meta("source") as NodePath) as MeshInstance3D if arms != null else null
	for side: String in (["R"] if prop.kind in pl.vis.ONE_HAND_PROPS else ["L", "R"]):
		var bone := skel.find_bone("HAND." + side)
		if bone < 0:
			continue
		var at: Vector3 = skel.global_transform * skel.get_bone_global_pose(bone).origin
		var copy: MeshInstance3D = arms.get_node_or_null(side) as MeshInstance3D if source != null else null
		if copy != null:
			at = copy.global_transform * (source.global_transform.affine_inverse() * at)
		out.append(at)
	if out.is_empty():
		out.append(pl.vis.chest_pos())
	return out

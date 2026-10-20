extends Node
## 爆弾の道具：ロープ（導火線になる）・はさみ・火薬の袋。数字やキーで決めず、ゲームの中の物を手で扱う。
##   ・ロープ（荷台のフックに掛けるのと同じ束。cargo_kit.gd の rope）：持って、爆弾の口を見て F でつなぐと導火線になる。束を持って離れると、線が束から出ていく（重力で垂れて床を這う）。
##     束の残りは、束の太さで分かる。使い切ると、先が束から外れる
##   ・はさみ（会社の備品。段ボール置き場に置いてある）：持って、線の好きな所を見て F で切る。切れ端は床に残る
##   ・点火：手ぶらで、線の先を見て F。火花は線の上を、長さぶんの時間をかけて進む（BURN_SEC_PER_M）。
##     燃えた所は無くなる。途中で切れば、火は切れた先へは進まない。火が口金に届くと爆発する。
##     つないでいない爆弾を見て F なら、その場ですぐ爆発する
##   ・火薬の袋：持って F を押している間、口から粉が出る。爆弾の口の上なら中へ入り、外せば床にこぼれて残る。
##     出方にはむらがある（最初は出が悪く、急にどさっと出る。止めても少しこぼれる）。入れた量だけ爆発が大きくなる。
##     こぼれた粉は、火花や爆発で火が移る。爆弾のすぐそばの粉に火が移ると、爆弾も爆発する
## 決めるのはホストだけ。線の形（節の位置）は各自の画面で計算し、送るのは
## 「どこにつながっているか・長さ・燃えているか・こぼれた粉・束の残り」だけ。
##   "bombkit" の合図＝全部（線の道すじの間引きつき。つなぐ・切る・点火・途中参加・見返しの始めと終わり）
##   "bombnum" の合図＝数だけ（伸びている・燃えている・注いでいる間、1秒に数回）
## 爆弾に入っている量と袋の残りは、物の状態（fx_box.gd・powder_sack.gd の get_state）で届く
const Cord := preload("res://scripts/fuse_cord.gd")
const Sack := preload("res://scripts/powder_sack.gd")
const FxBox := preload("res://scripts/fx_box.gd")

const CREW_LAYER := 1 << 11                   # 制作班にだけ見える表示（film_camera.gd と同じ番号）
const SACKS := 5                              # 火薬の袋の総数（爆弾に付く1袋＋買い足し4袋まで。持ち越した袋も、この中に入る）
const SACK_EMPTY := 0.02                      # 残りがこれ以下の袋は、空として捨てる（次の依頼へ持ち越さない）
const COIL_M := 10.0                          # ロープの束1つの長さ（m）
const BURN_SEC_PER_M := 1.5                   # 火が1m進むのにかかる秒数
const MIN_PIECE := 0.12                       # これより短い切れ端は、残さない
const MAX_SCRAPS := 6                         # 床に残す切れ端の数（古い物から消える）
const CUT_AIM := 0.16                         # はさみ：視線から線までの離れが、これ以内なら切れる
const TIP_AIM := 0.3                          # 点火：視線から線の先までの離れ
const CATCH_SURE := 0.2                       # 注ぐ：袋の口が爆弾の口からこの距離までなら、全部入る
const CATCH := 0.42                           # これより外は、全部こぼれる（間は、一部がこぼれる）
const MAX_SPILLS := 14
const SPILL_NEAR := 0.45                      # こぼれた粉が爆弾の口からこの距離（＋山の大きさ）までなら、火が移ると爆弾も爆発する
# 届いた物の置き場所（軽トラ HOME から見た位置）と、はさみの置き場所（段ボール置き場）
const DELIVERY := Vector3(-2.5, 0.03, -2.7)
const SCISSORS_AT := Vector3(71.05, 0.05, 18.82)
const CORD_COLOR := Color(0.93, 0.48, 0.16)

var game: Node
var flow: Node
var bomb: RigidBody3D
var coil: RigidBody3D
var scissors: RigidBody3D
var sacks: Array = []
var cords: Dictionary = {}                    # 線の番号 → fuse_cord.gd
var stock := COIL_M                           # 束に残っている長さ
var spills: Array = []                        # こぼれた粉 [[場所, 量], ...]
var rates: Dictionary = {}                    # いま注いでいる袋（物のID → 勢い）

var _next := 1
var _pours: Dictionary = {}                   # ホスト：注いでいる袋の様子（物のID → {who, phase, left, rate, ...}）
var _flash: Array = []                        # ホスト：これから火が移る粉 [[残り秒, 場所], ...]
var _dirty := false
var _send_t := 0.0
var _burn_send_t := 0.0
var _playback := false
var _before_replay := {}
var _pouring_local := 0                       # 自分が注いでいる袋（物のID）
var _spill_root: Node3D
var _spill_sig := ""
var _aim_mark: MeshInstance3D
var _crackle := 0.0


func _ready() -> void:
	# 物（爆弾・束）が動いたあとで、線を付いて行かせる
	process_physics_priority = 30


# 物を作る。全員の画面で同じ順に呼ぶ（物のIDがそろう）
func setup() -> void:
	flow = game.production
	bomb = game.fx
	# 束は、荷台に掛けるロープと同じ物（cargo_kit.gd が作る）。1本のロープを、荷物を押さえるのにも導火線にも使う
	coil = game.cargo_kit.rope
	scissors = game.stage.spawn("scissors", SCISSORS_AT, 0.7)
	for i in SACKS:
		var sack: RigidBody3D = Sack.new()
		sack.build()
		game.stage._register(sack, Vector3(float(game.props.size() + 1) * 3.0, -60.0, 34.0), 0.0)
		sacks.append(sack)
	_spill_root = Node3D.new()
	add_child(_spill_root)
	# はさみで切る場所・火を付ける先の目印（制作班にだけ見える）
	_aim_mark = MeshInstance3D.new()
	var ring := TorusMesh.new()
	ring.inner_radius = 0.045
	ring.outer_radius = 0.065
	ring.rings = 12
	ring.ring_segments = 6
	_aim_mark.mesh = ring
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1.0, 0.95, 0.6)
	mat.no_depth_test = true
	_aim_mark.material_override = mat
	_aim_mark.layers = CREW_LAYER
	_aim_mark.visible = false
	add_child(_aim_mark)
	absent_changed()
	if Net.is_host():
		# はさみは、寝かせて置く
		scissors.restore([SCISSORS_AT + Vector3(0, 0.06, 0), Quaternion(Vector3.UP, 0.7) * Quaternion(Vector3.RIGHT, -PI * 0.5), false])
		flow._home_layout[scissors.pid] = scissors.get_state()
		host_apply_order()


# 借りた数だけ、火薬の袋を出す（全員の画面。"absent" の合図のあとに呼ぶ）
func absent_changed() -> void:
	var count := sacks_out()
	for i in sacks.size():
		var sack: RigidBody3D = sacks[i]
		sack.set_absent(i >= count or sack.stored_in != 0)


# いま出ている袋の数：前の依頼から持ち越した袋＋爆弾に付く1袋（借りた・今回買った爆弾）＋買い足した袋。
# 数えるのは「決めた注文」（flow.ordered）。発注の画面で選んでいる途中の袋は、決めるまで出ない
func sacks_out() -> int:
	if flow == null:
		return 0
	var fresh := int(flow.ordered.get("refill", 0))
	if int(flow.ordered.get("fx", 0)) > 0 or "fx" in flow.bought_now:
		fresh += 1
	return mini(SACKS, flow.sack_stock.size() + fresh)


# 使い残した袋の、残りの量（事務所へ戻るときに数える）。空の袋は入れない
func leftover() -> Array:
	var out: Array = []
	var count := sacks_out()
	for i in sacks.size():
		var sack: RigidBody3D = sacks[i]
		if i < count and sack.fill > SACK_EMPTY:
			out.append(snappedf(sack.fill, 0.001))
	return out


# 注文が決まった・事務所へ戻った（ホスト）：線・粉・袋を新しくして（ロープの束も巻き直す）、借りた袋を軽トラの横へ置く
func host_apply_order() -> void:
	if not Net.is_host():
		return
	for id: int in cords.keys():
		_drop(id)
	spills = []
	_flash = []
	_pours = {}
	rates = {}
	# 束を巻き直す。荷台に掛けたままのロープの分は、束に戻らない
	stock = COIL_M
	for lash: Dictionary in game.cargo_kit.lashes.values():
		# 会社のロープから出た分だけ（毛ひもなど、ほかの束から出たひもは数えない）
		# （切れ端を結んだロープ＝-1 も、もとは会社のロープ）
		if int(lash.get("coil", 0)) <= 0:
			stock = maxf(0.0, stock - float(lash["cord"].length))
	bomb.charges = 0
	bomb.powder = 0.0
	var base: Vector3 = flow.HOME_TRUCK + DELIVERY
	var n := 0
	# 持ち越した袋は、残りの量のまま。新しい袋は、いっぱい
	var kept: Array = flow.sack_stock
	for i in sacks.size():
		var sack: RigidBody3D = sacks[i]
		sack.fill = float(kept[i]) if i < kept.size() else 1.0
		if sack.absent:
			continue
		sack.restore([base + Vector3(-0.5 * float(n), 0.0, 0.0), Quaternion(Vector3.UP, 0.4 * float(n)), false])
		n += 1
	_broadcast(true)


# 準備の途中で、注文を決め直した（ホスト）：変わった分だけを反映する。
# 前から出ている袋（残りの量・置き場所）・線・こぼれた粉・束の残りには触らない。
#   was：決める前に出ていた物（物のID → true）
func host_order_changed(was: Dictionary) -> void:
	if not Net.is_host():
		return
	if bomb.absent != (not was.has(bomb.pid)):
		# 爆弾が届いた・返した：つないであった線は外れて、床の切れ端になる。届いた爆弾は空
		for cord: Node3D in cords.values():
			if cord.a_body == bomb:
				cord.a_body = null
				cord.wake()
		bomb.douse()
		bomb.charges = 0
		bomb.powder = 0.0
	var base: Vector3 = flow.HOME_TRUCK + DELIVERY
	var kept: Array = flow.sack_stock
	for i in sacks.size():
		var sack: RigidBody3D = sacks[i]
		if sack.absent:
			# 返した袋：注いでいる途中なら、止める
			_pours.erase(sack.pid)
			rates.erase(sack.pid)
			continue
		if was.has(sack.pid):
			continue
		# 新しく届いた袋：持ち越した袋は残りの量のまま、新しい袋はいっぱい。軽トラの横の、その袋の場所へ
		sack.fill = float(kept[i]) if i < kept.size() else 1.0
		sack.restore([base + Vector3(-0.5 * float(i), 0.0, 0.0), Quaternion(Vector3.UP, 0.4 * float(i)), false])
	_broadcast(true)


# ---- 線を作る・消す ----

func _make(id: int) -> Node3D:
	var cord: Node3D = Cord.new()
	cord.id = id
	cord.name = "Cord%d" % id
	add_child(cord)
	cords[id] = cord
	return cord


func _drop(id: int) -> void:
	var cord: Node3D = cords.get(id)
	cords.erase(id)
	if cord != null:
		cord.queue_free()


func _coil_exit() -> Vector3:
	return coil.center + Vector3(0, coil.half.y * 0.5, 0)


# 爆弾につながっている線（無ければ null）
func bomb_cord() -> Node3D:
	for cord: Node3D in cords.values():
		if cord.a_body == bomb:
			return cord
	return null


# 束につながっている線（無ければ null）
func coil_cord() -> Node3D:
	for cord: Node3D in cords.values():
		if cord.b_body == coil:
			return cord
	return null


# 床に残す切れ端が多すぎたら、古い物から消す
func _trim_scraps() -> void:
	var loose: Array = []
	for id: int in cords:
		var cord: Node3D = cords[id]
		if cord.a_body == null and cord.b_body == null and not cord.burning:
			loose.append(id)
	loose.sort()
	while loose.size() > MAX_SCRAPS:
		_drop(int(loose.pop_front()))


# ---- ホスト：つなぐ・切る・点火 ----

func _host_ok() -> bool:
	return Net.is_host() and flow != null and not _playback and not game.replaying and game.state in [game.S.PREP, game.S.TAKE]


func _say(who: int, text: String, bad: bool) -> void:
	game.ev.rpc_id(who, "toast", [text, 1 if bad else 0])


# 束を持って、爆弾の口を見て F：束の線の端を、口金につなぐ
@rpc("any_peer", "call_local", "reliable")
func h_connect() -> void:
	if not _host_ok() or bomb.absent or coil.absent:
		return
	var who := Net.sender()
	var pl: Node3D = game.players.get(who)
	if pl == null or coil.holder != who:
		return
	var gap: float = bomb.mouth().distance_to(coil.global_transform * _coil_exit())
	if pl.global_position.distance_to(bomb.center_global()) > game.Player.REACH + 1.0 or gap > game.Player.REACH + 1.0:
		_say(who, "束を爆弾の口に近づけて、F でつなぐ", true)
		return
	var mine := bomb_cord()
	if mine != null and mine.b_body == coil:
		_say(who, "もうつないである。束を持って離れると、線が伸びる", false)
		return
	if stock < maxf(0.3, gap):
		_say(who, "束のロープが足りない" if stock >= 0.3 else "束のロープを使い切った", true)
		game.ev.rpc_id(who, "sfx", ["ui_fail", null])
		return
	# 荷台のフックに掛けている途中だったロープは、束から外れる（cargo_kit.gd）
	game.cargo_kit.host_coil_taken()
	# 前につないだ線は外れて、床の切れ端になる
	for cord: Node3D in cords.values():
		if cord.a_body == bomb:
			cord.a_body = null
			cord.wake()
		if cord.b_body == coil:
			cord.b_body = null
			cord.wake()
	var fresh := _make(_next)
	_next += 1
	fresh.a_body = bomb
	fresh.a_local = bomb.mouth_local()
	fresh.b_body = coil
	fresh.b_local = _coil_exit()
	fresh.lay(PackedVector3Array([bomb.mouth(), coil.global_transform * _coil_exit()]))
	stock = maxf(0.0, stock - float(fresh.length))
	_trim_scraps()
	game.host_ev("sfx", ["fix", bomb.global_position])
	_broadcast(true)


# 束から出ていた線を、束から外す（ホスト。束を、荷台のフックに掛けるほうへ回すとき。cargo_kit.gd）
func host_release_coil() -> void:
	var changed := false
	for cord: Node3D in cords.values():
		if cord.b_body == coil:
			cord.b_body = null
			cord.wake()
			changed = true
	if changed:
		_broadcast(true)


# 床に落ちる切れ端を足す（ホスト。荷台に掛けたロープを切ったときの、どこにも結んでいない側。cargo_kit.gd）
# 作った切れ端の番号を返す（残さなかったら 0）
func host_add_scrap(path: PackedVector3Array, length: float) -> int:
	if length < MIN_PIECE or path.size() < 2:
		return 0
	var scrap := _make(_next)
	_next += 1
	scrap.lay(path, length)
	_trim_scraps()
	_broadcast(true)
	return int(scrap.id)


func _rg() -> Node:
	return game.get("rope_grab")


# 手でつかんだ端を、爆弾の口金につなぐ（ホスト。rope_grab.gd）。end：1＝先 / 0＝根元。
# 床の切れ端なら、その長さの短い導火線になる。先をつないだときは、そちらが根元になる
func host_attach(id: int, end: int, who: int) -> bool:
	if not _host_ok() or bomb.absent or not cords.has(id):
		return false
	var pl: Node3D = game.players.get(who)
	var cord: Node3D = cords[id]
	if pl == null or cord.a_body == bomb:
		return false
	if (end == 0 and cord.a_body != null) or (end == 1 and (cord.b_body != null or cord.burning)):
		return false
	if pl.global_position.distance_to(bomb.center_global()) > game.Player.REACH + 1.0:
		_say(who, "爆弾の口に近づいて、F でつなぐ", true)
		return false
	# 前につないだ線は外れて、床の切れ端になる
	for other: Node3D in cords.values():
		if other.a_body == bomb:
			other.a_body = null
			other.wake()
	if end == 1:
		cord.flip()
	cord.a_body = bomb
	cord.a_local = bomb.mouth_local()
	# 手元にあった端を、口金へ持っていく（残りは、ひもの計算が引いて付いて来る）
	cord.reroot(bomb.mouth())
	game.host_ev("sfx", ["fix", bomb.global_position])
	_broadcast(true)
	return true


# 切れ端を、ほかの使い道（荷台のフックに結ぶ）へ回した（ホスト。rope_grab.gd）：ここの線ではなくなる
func host_take(id: int) -> void:
	if cords.has(id):
		_drop(id)
		_broadcast(true)


# はさみを持って、線を見て F：根元から s（m）の所で切る
@rpc("any_peer", "call_local", "reliable")
func h_cut(id: int, s: float) -> void:
	if not _host_ok() or not cords.has(id) or not is_finite(s):
		return
	var who := Net.sender()
	var pl: Node3D = game.players.get(who)
	if pl == null or scissors.holder != who:
		return
	var cord: Node3D = cords[id]
	s = clampf(s, 0.0, cord.length)
	var at: Vector3 = cord.point_at(s)
	if pl.global_position.distance_to(at) > game.Player.REACH + 1.5:
		_say(who, "はさみが届かない", true)
		return
	var pts: PackedVector3Array = cord.pts
	var k := clampi(int(s / Cord.SEG), 0, pts.size() - 2)
	var near := PackedVector3Array()
	for i in k + 1:
		near.append(pts[i])
	near.append(at)
	var far := PackedVector3Array([at])
	for i in range(k + 1, pts.size()):
		far.append(pts[i])
	var was_burning: bool = cord.burning
	# 先の側：束からも外れて、床に落ちる切れ端になる。燃えていたなら、火はこちらに残って燃え尽きる
	var whole: float = cord.length
	var far_id := 0
	if whole - s >= MIN_PIECE:
		var scrap := _make(_next)
		far_id = _next
		_next += 1
		scrap.lay(far, whole - s)
		scrap.burning = was_burning
		# 切り口が少し離れる（どちらの端か、見て分かるように）
		if far.size() >= 2 and far[0].distance_to(far[1]) > 0.001:
			var apart: Vector3 = (far[1] - far[0]).normalized() * 0.07
			for i in scrap.pts.size():
				scrap.pts[i] += apart
				scrap.old[i] += apart
		# 切った勢いで、少しはねる
		for i in scrap.old.size():
			scrap.old[i] -= Vector3(randf_range(-0.004, 0.004), 0.006, randf_range(-0.004, 0.004))
	# 根元の側：短くなって、つながったまま残る（火は消える）
	cord.b_body = null
	cord.burning = false
	if s >= MIN_PIECE:
		cord.lay(near, s)
	else:
		_drop(id)
	_trim_scraps()
	game.host_ev("sfx", ["unfix", at])
	_broadcast(true)
	if _rg() != null:
		_rg().host_split(0, id, s, s >= MIN_PIECE, 0, far_id if cords.has(far_id) else 0, false, whole)


# 線の端に火を付ける。end：1＝先 / 0＝根元の側（どこにもつながっていない切れ端だけ）
@rpc("any_peer", "call_local", "reliable")
func h_light(id: int, end: int) -> void:
	if not _host_ok() or not cords.has(id):
		return
	var who := Net.sender()
	var pl: Node3D = game.players.get(who)
	var cord: Node3D = cords[id]
	if pl == null or cord.burning:
		return
	if end == 0 and cord.a_body != null:
		return
	var at: Vector3 = cord.tip() if end == 1 else cord.root()
	if pl.global_position.distance_to(at) > game.Player.REACH + 1.5:
		_say(who, "火が届かない。線の先に近づく", true)
		return
	# 束につながったままの線に火を付けたら、束から外れる
	cord.b_body = null
	if end == 0:
		cord.flip()
		if _rg() != null:
			_rg().host_flipped(0, id)
	cord.burning = true
	cord.wake()
	game.host_ev("sfx", ["fuse", at])
	if cord.a_body == bomb:
		game.host_ev("toast", ["導火線（ロープ）に点火！ 離れろ！", 0])
		if game.crew_skills != null and game.state == game.S.TAKE:
			game.crew_skills.mark(who, "backstage", "effects")
	_broadcast(true)


# 導火線をつないでいない爆弾を見て F：その場ですぐ爆発する
@rpc("any_peer", "call_local", "reliable")
func h_light_bomb() -> void:
	if not _host_ok() or bomb.absent:
		return
	var who := Net.sender()
	var pl: Node3D = game.players.get(who)
	if pl == null or bomb.holder != 0 or pl.global_position.distance_to(bomb.center_global()) > game.Player.REACH + 1.0:
		_say(who, "爆弾は、置いた物のそばで点火する", true)
		return
	if bomb.fuse >= 0.0:
		return
	var mine := bomb_cord()
	if mine != null:
		if not mine.burning:
			_say(who, "ロープがつないである。ロープの先を見て F で火を付ける", false)
		return
	if game.state == game.S.TAKE and not bomb.loaded():
		_say(who, "火薬が入っていない", true)
		return
	if bomb.ignite(bomb.FUSE_SEC):
		game.host_ev("toast", ["点火！ 導火線が無いので、すぐ爆発する！", 1])
		if game.crew_skills != null and game.state == game.S.TAKE:
			game.crew_skills.mark(who, "backstage", "effects")


# ---- ホスト：火薬を注ぐ ----

# 袋を持って F を押した・離した
@rpc("any_peer", "call_local", "reliable")
func h_pour(on: bool) -> void:
	if not Net.is_host():
		return
	var who := Net.sender()
	var sack: RigidBody3D = null
	for item: RigidBody3D in sacks:
		if item.holder == who and not item.absent:
			sack = item
	if sack == null:
		return
	if not on:
		if _pours.has(sack.pid) and not bool(_pours[sack.pid]["stopping"]):
			# 止めても、少しこぼれる
			var running: Dictionary = _pours[sack.pid]
			running["stopping"] = true
			running["left"] = randf_range(0.12, 0.5)
			running["span"] = running["left"]
		return
	if not _host_ok() or _pours.has(sack.pid):
		return
	if sack.fill <= 0.0:
		_say(who, "この袋は、もう空っぽ", true)
		return
	# 出はじめ：たいていは出が悪い。ときどき、いきなりどさっと出る
	var st := {"who": who, "stopping": false, "span": 0.0, "lump": 0.0}
	if randf() < 0.2:
		_gush(st)
	else:
		st["phase"] = "clog"
		st["left"] = randf_range(0.2, 1.3)
		st["rate"] = randf_range(0.015, 0.05)
	_pours[sack.pid] = st


func _gush(st: Dictionary) -> void:
	st["phase"] = "gush"
	st["left"] = randf_range(0.2, 0.5)
	st["rate"] = randf_range(0.3, 0.55)
	st["lump"] = randf_range(0.05, 0.2)          # つまっていた分が、いちどに落ちる


func _pour_tick(sack: RigidBody3D, st: Dictionary, delta: float) -> void:
	if sack.absent or sack.holder != int(st["who"]) or sack.fill <= 0.0:
		_pours.erase(sack.pid)
		rates.erase(sack.pid)
		_dirty = true
		return
	st["left"] = float(st["left"]) - delta
	var rate: float = st["rate"]
	if bool(st["stopping"]):
		if float(st["left"]) <= 0.0:
			_pours.erase(sack.pid)
			rates.erase(sack.pid)
			_dirty = true
			return
		rate *= float(st["left"]) / maxf(float(st["span"]), 0.01)
	elif float(st["left"]) <= 0.0:
		# 出方が変わる：つまる → どさっ → ふつう → ときどき、またつまる
		match str(st["phase"]):
			"clog":
				_gush(st)
				game.host_ev("sfx", ["load", sack.global_position])
			"gush":
				st["phase"] = "flow"
				st["left"] = randf_range(0.4, 1.3)
				st["rate"] = randf_range(0.09, 0.2)
			_:
				if randf() < 0.4:
					st["phase"] = "clog"
					st["left"] = randf_range(0.25, 0.9)
					st["rate"] = randf_range(0.015, 0.05)
				else:
					st["left"] = randf_range(0.4, 1.3)
					st["rate"] = randf_range(0.09, 0.2)
		rate = st["rate"]
	rate *= randf_range(0.8, 1.2)
	_aim_sack(sack)
	var amount := minf(sack.fill, rate * delta + float(st["lump"]))
	st["lump"] = 0.0
	sack.fill = maxf(0.0, sack.fill - amount)
	_deliver(amount, sack.spout(), sack)
	if not is_equal_approx(float(rates.get(sack.pid, 0.0)), rate):
		rates[sack.pid] = rate
		_dirty = true


# 袋を傾ける向き：持っている人から見て、向こう側
func _aim_sack(sack: RigidBody3D) -> void:
	var holder: Node3D = game.players.get(sack.holder)
	if holder == null:
		return
	var away: Vector3 = sack.center_global() - holder.global_position
	away.y = 0.0
	if away.length() > 0.05:
		sack.pour_dir = away.normalized()


# 口から落ちた粉の行き先：爆弾の口の上なら中へ。外れた分と、あふれた分は床へ
func _deliver(amount: float, from: Vector3, sack: RigidBody3D) -> void:
	var into := 0.0
	if not bomb.absent:
		var mouth: Vector3 = bomb.mouth()
		var off := Vector2(from.x - mouth.x, from.z - mouth.z).length()
		if from.y > mouth.y - 0.05:
			into = amount * (1.0 - smoothstep(CATCH_SURE, CATCH, off))
		var room: float = maxf(0.0, bomb.CAP - bomb.powder)
		var over := maxf(0.0, into - room)
		bomb.powder += into - over
		if over > 0.0001:
			# あふれた粉は、爆弾のまわりに落ちる
			var side := Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)).normalized() * randf_range(0.3, 0.45)
			var both: Array[RID] = [bomb.get_rid(), sack.get_rid()]
			_spill(_floor_under(bomb.global_position + side + Vector3(0, 0.4, 0), both), over)
	var missed := amount - into
	if missed > 0.0001:
		var skip: Array[RID] = [sack.get_rid()]
		_spill(_floor_under(from, skip), missed)


func _floor_under(from: Vector3, skip: Array[RID]) -> Vector3:
	var q := PhysicsRayQueryParameters3D.create(from, from + Vector3(0, -6.0, 0), 1 | 2)
	q.exclude = skip
	var hit: Dictionary = game.get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		return Vector3(from.x, from.y - 1.0, from.z)
	return hit["position"]


func _spill(at: Vector3, amount: float) -> void:
	var best := -1
	for i in spills.size():
		var d: float = (spills[i][0] as Vector3).distance_to(at)
		if d < 0.4 and (best < 0 or d < (spills[best][0] as Vector3).distance_to(at)):
			best = i
	if best < 0 and spills.size() >= MAX_SPILLS:
		for i in spills.size():
			if best < 0 or (spills[i][0] as Vector3).distance_to(at) < (spills[best][0] as Vector3).distance_to(at):
				best = i
	if best >= 0:
		spills[best][1] = float(spills[best][1]) + amount
	else:
		spills.append([at, amount])
	_dirty = true


static func spill_radius(amount: float) -> float:
	return 0.06 + 0.5 * sqrt(clampf(amount, 0.0, 2.0))


# こぼれた粉の、その場所に火が移る（少し遅れて燃える）
func _touch_spills(at: Vector3, reach: float, delay: float) -> void:
	for spill: Array in spills:
		var pos: Vector3 = spill[0]
		if Vector2(pos.x - at.x, pos.z - at.z).length() > reach + spill_radius(float(spill[1])) or absf(pos.y - at.y) > maxf(1.0, reach):
			continue
		var queued := false
		for item: Array in _flash:
			queued = queued or (item[1] as Vector3).is_equal_approx(pos)
		if not queued:
			_flash.append([delay, pos])


func _flash_tick(delta: float) -> void:
	for i in range(_flash.size() - 1, -1, -1):
		_flash[i][0] = float(_flash[i][0]) - delta
		if float(_flash[i][0]) > 0.0:
			continue
		var pos: Vector3 = _flash[i][1]
		_flash.remove_at(i)
		for k in spills.size():
			if not (spills[k][0] as Vector3).is_equal_approx(pos):
				continue
			var amount: float = spills[k][1]
			spills.remove_at(k)
			_dirty = true
			# ぼっと燃える（煙と音だけ。周りの物は飛ばない）
			game.host_ev("burst", [pos + Vector3(0, 0.25, 0), 0.0])
			game.host_ev("sfx", ["explosion_fizzle", pos])
			var radius := spill_radius(amount)
			_touch_spills(pos, radius + 0.7, 0.14)
			# 爆弾のすぐそばの粉：口へ火が飛んで、爆弾も爆発する
			if not bomb.absent and bomb.loaded() and bomb.fuse < 0.0:
				var mouth: Vector3 = bomb.mouth()
				if Vector2(pos.x - mouth.x, pos.z - mouth.z).length() < SPILL_NEAR + radius and absf(pos.y - bomb.global_position.y) < 1.0:
					game.host_ev("toast", ["こぼれた火薬から、爆弾に火が移った！", 1])
					game.host_burst(bomb)
			break


# ---- ホスト：毎コマ ----

func _host_tick(delta: float) -> void:
	# 物が無くなった（しまわれた・借りていない）：線を外す
	for id: int in cords.keys():
		var cord: Node3D = cords[id]
		if cord.a_body == bomb and bomb.absent:
			cord.a_body = null
			_broadcast(true)
		if cord.b_body == coil and coil.absent:
			cord.b_body = null
			_broadcast(true)
	# 束から線が出ていく：引っぱられた分と、床に垂れる分のゆるみ
	var feeding := coil_cord()
	if feeding != null:
		var path: float = feeding.path_length()
		var want: float = feeding.length
		if path > feeding.length + 0.01:
			# 張っている：張りが抜けるところまで出す（張ったまま残すと、いつまでも小さく動く）
			want = path + 0.03
		# 手に持って運んでいる間は、床に垂れる分のゆるみも出す（置いてある束からは、引かれた分しか出ない）
		if coil.holder != 0:
			want = maxf(want, _slack_need(feeding))
		if want > feeding.length + 0.01 and stock > 0.0:
			var add := minf(want - feeding.length, stock)
			stock -= add
			feeding.set_length(feeding.length + add)
			_dirty = true
		elif stock <= 0.001 and path > feeding.length * 1.1:
			# 使い切った：先が束から外れて落ちる
			feeding.b_body = null
			feeding.wake()
			if coil.holder != 0:
				_say(coil.holder, "束のロープを使い切った。先が束から外れた", true)
			_broadcast(true)
	# 燃えている線：火が根元まで来たら、爆弾が爆発する。こぼれた粉の上を通れば、火が移る
	for id: int in cords.keys():
		var cord: Node3D = cords[id]
		if not cord.burning:
			continue
		_touch_spills(cord.tip(), 0.05, 0.0)
		if cord.length <= 0.02:
			var to_bomb: bool = cord.a_body == bomb and not bomb.absent
			_drop(id)
			_broadcast(true)
			if to_bomb and bomb.fuse < 0.0:
				game.host_burst(bomb)
	for sack: RigidBody3D in sacks:
		if _pours.has(sack.pid):
			_pour_tick(sack, _pours[sack.pid], delta)
	_flash_tick(delta)
	# 数だけの知らせ：変わったときに、1秒に数回まで。燃えている間は、ずれを直すために0.5秒ごと
	_send_t -= delta
	_burn_send_t -= delta
	var burning := false
	for cord: Node3D in cords.values():
		burning = burning or cord.burning
	if (_dirty and _send_t <= 0.0) or (burning and _burn_send_t <= 0.0):
		_broadcast(false)


# 床に垂らして這わせるのに要る長さ：口金から床へ下りて、床を進み、束まで上がる（まっすぐの距離＋2mまで）
func _slack_need(cord: Node3D) -> float:
	var a: Vector3 = bomb.mouth()
	var b: Vector3 = coil.global_transform * _coil_exit()
	var straight := a.distance_to(b)
	var flat := Vector2(a.x - b.x, a.z - b.z).length()
	var drop_a := maxf(0.0, a.y - bomb.global_position.y)
	var skip: Array[RID] = [coil.get_rid()]
	var drop_b := maxf(0.0, b.y - _floor_under(b, skip).y)
	return maxf(straight * 1.03, minf(drop_a + flat * 1.03 + drop_b, straight + 2.0))


# 爆弾が爆発した（ホスト。production_main.gd の host_burst から）：つないだ線は吹き飛び、こぼれた粉に火が移る
func on_bomb_burst(power: float) -> void:
	if not Net.is_host():
		return
	var changed := false
	for id: int in cords.keys():
		if (cords[id] as Node3D).a_body == bomb:
			_drop(id)
			changed = true
	if changed:
		_broadcast(true)
	_touch_spills(bomb.global_position, 3.0 + 3.0 * power, 0.2)


# 爆発が見えた（全員の画面。"burst" の合図）：床の線が吹き飛ぶ
func on_burst_seen(pos: Vector3, power: float) -> void:
	if power <= 0.0:
		return
	for cord: Node3D in cords.values():
		cord.shove(pos, 6.0 * power, 0.25 * power)


func _physics_process(delta: float) -> void:
	if flow == null:
		return
	var host: bool = Net.is_host() and not _playback
	var shapes: Array = [] if bomb.absent else [bomb.ball()]
	for cord: Node3D in cords.values():
		cord.balls = shapes
		if cord.a_body == bomb:
			cord.a_local = bomb.mouth_local()
		if cord.burning:
			# 火は先から根元へ進む。燃えた所は無くなる（ホストが決めた長さが届くたびに、ずれは直る）
			cord.set_length(cord.length - delta / BURN_SEC_PER_M)
			cord.visible = cord.length > 0.02
			# 口金に届く直前：爆弾が震えて、火花を噴く
			var left: float = cord.length * BURN_SEC_PER_M
			if cord.a_body == bomb and left <= bomb.FUSE_SEC and left > 0.06 and bomb._burn_left <= 0.0:
				bomb.show_fuse(left, left)
		cord.step(delta)
	bomb.has_cord = bomb_cord() != null
	if host:
		_host_tick(delta)
	for sack: RigidBody3D in sacks:
		sack.pour_rate = float(rates.get(sack.pid, 0.0))
		if sack.pour_rate > 0.0:
			_aim_sack(sack)


func _process(delta: float) -> void:
	if flow == null:
		return
	_show_spills()
	# 燃えている線は、パチパチと鳴る
	_crackle -= delta
	if _crackle <= 0.0:
		_crackle = randf_range(0.16, 0.34)
		for cord: Node3D in cords.values():
			if cord.burning and cord.visible and Sfx.has_sound("fuse"):
				Sfx.play("fuse", cord.tip(), -9.0)
	var me: Node = game.local_player()
	# 自分が注いでいる間：F を離したら（袋を手放したら）止める
	if _pouring_local != 0:
		if me == null or me.held != _pouring_local or not Input.is_action_pressed("operate") or game.ui_blocking():
			_pouring_local = 0
			h_pour.rpc_id(1, false)
	# はさみで切る場所・火を付ける先の目印
	var mark := false
	if me != null and not game.ui_blocking():
		var act := f_action(me)
		if act.has("point"):
			_aim_mark.global_position = act["point"]
			var cam: Camera3D = get_viewport().get_camera_3d()
			if cam != null and cam.global_position.distance_to(act["point"]) > 0.05:
				_aim_mark.look_at(cam.global_position, Vector3.UP)
				_aim_mark.rotate_object_local(Vector3.RIGHT, PI * 0.5)
			mark = true
	_aim_mark.visible = mark


# ---- 通信 ----

# いまの様子。full＝線の道すじ（間引き）と、爆弾・袋の量も入れる
func snapshot(full: bool) -> Dictionary:
	var list: Array = []
	for id: int in cords:
		var cord: Node3D = cords[id]
		list.append([id, cord.a_body.pid if cord.a_body != null else 0, cord.b_body.pid if cord.b_body != null else 0,
			cord.length, cord.burning, cord.samples() if full else null])
	var data := {"full": full, "cords": list, "stock": stock, "spills": spills.duplicate(true), "rates": rates.duplicate()}
	if full:
		data["next"] = _next
		data["powder"] = bomb.powder
		var fills := {}
		for sack: RigidBody3D in sacks:
			fills[sack.pid] = sack.fill
		data["fills"] = fills
	return data


# 全員へ配る（ホスト）。本番中の変化は、見返しのために記録にも残る（下の hook_rec_events）
func _broadcast(full: bool) -> void:
	_dirty = false
	_send_t = 0.18
	_burn_send_t = 0.5
	game.host_ev("bombkit" if full else "bombnum", [snapshot(full)])
	# 場転でフィルムを止めている間の変化（つなぐ・切る・注ぐ）は、合図としては記録されない。
	# 見返しで、回し直したときから今の線と火薬が見えるように、全部の様子を記録に残す（荷台のロープの cargo_kit.gd と同じ）
	if game.state == game.S.TAKE and game.take_held() and not game.replaying:
		game._rec_events.append([float(game.take_t), "bombkit", [snapshot(true)]])


func sync_to(who: int) -> void:
	if Net.is_host() and who != Net.my_id():
		game.ev.rpc_id(who, "bombkit", [snapshot(true)])


# 合図を受け取った（全員）。ホストは自分で決めた物なので、見返しの間だけ受け取る
func receive(data: Dictionary) -> void:
	if Net.is_host() and not _playback:
		return
	apply(data)


func apply(data: Dictionary) -> void:
	var full: bool = data.get("full", false)
	var seen := {}
	for row: Array in data.get("cords", []):
		var id: int = row[0]
		seen[id] = true
		var cord: Node3D = cords.get(id)
		var path: Variant = row[5]
		if cord == null:
			if not path is PackedVector3Array:
				continue          # まだ知らない線の、数だけの知らせ（全部の知らせが別に届く）
			cord = _make(id)
			cord.lay(path, float(row[3]))
		elif path is PackedVector3Array and (path as PackedVector3Array).size() >= 2:
			var theirs: PackedVector3Array = path
			var their_tip: Vector3 = theirs[theirs.size() - 1]
			if cord.root().distance_to(their_tip) + 0.3 < cord.tip().distance_to(their_tip) and cord.root().distance_to(theirs[0]) > 0.3:
				# ホストで先と根元が入れ替わった（切れ端の根元の側に火が付いた）
				cord.pts.reverse()
				cord.old.reverse()
			if cord.tip().distance_to(their_tip) > 1.0 and float(row[3]) >= cord.length - 0.3:
				# 形が大きくずれていたら、ホストの道すじに合わせる（切られて短くなった分は、下で先から外す）
				cord.lay(theirs, float(row[3]))
			elif not bool(row[4]) and absf(float(row[3]) - float(cord.length)) < 0.3 and _off_shape(cord, theirs):
				# 途中の形が大きくずれている（手でつかんで動かしたあとなど）：ホストの道すじに合わせる
				cord.lay(theirs, float(row[3]))
		cord.a_body = game.props.get(int(row[1])) if int(row[1]) != 0 else null
		cord.b_body = game.props.get(int(row[2])) if int(row[2]) != 0 else null
		if cord.a_body == bomb:
			cord.a_local = bomb.mouth_local()
		if cord.b_body == coil:
			cord.b_local = _coil_exit()
		cord.set_length(float(row[3]))
		if bool(row[4]) != cord.burning:
			cord.burning = row[4]
			cord.wake()
		cord.visible = not cord.burning or cord.length > 0.02
	if full:
		for id: int in cords.keys():
			if not seen.has(id):
				_drop(id)
		_next = maxi(_next, int(data.get("next", _next)))
	stock = float(data.get("stock", stock))
	spills = (data.get("spills", []) as Array).duplicate(true)
	rates = (data.get("rates", {}) as Dictionary).duplicate()
	bomb.has_cord = bomb_cord() != null
	_show_coil()


# 自分の画面の線が、ホストの道すじ（間引き）から大きく離れているか（どこかが 0.6m より遠い）
func _off_shape(cord: Node3D, path: PackedVector3Array) -> bool:
	for point: Vector3 in path:
		var near := INF
		for mine: Vector3 in cord.pts:
			near = minf(near, mine.distance_squared_to(point))
		if near > 0.36:
			return true
	return false


# 見返しの始まりと終わり（ホスト）。見返しの間は記録どおりに見せ、終わったら今の様子へ戻す
func playback_changed(on: bool) -> void:
	if not Net.is_host():
		return
	if on:
		_before_replay = snapshot(true)
		_pours = {}
		_flash = []
		_playback = true
	elif _playback:
		_playback = false
		var data := _before_replay
		_before_replay = {}
		# 見返しで付け替わった線は、いったん全部消してから、今の道すじで作り直す
		for id: int in cords.keys():
			_drop(id)
		apply(data)
		bomb.powder = float(data.get("powder", bomb.powder))
		var fills: Dictionary = data.get("fills", {})
		for sack: RigidBody3D in sacks:
			sack.fill = float(fills.get(sack.pid, sack.fill))
		rates = {}
		game.ev.rpc("bombkit", [snapshot(true)])


# ---- 見た目 ----

# 束の残り：使うほど、束が細くなる
func _show_coil() -> void:
	if coil == null or coil.visual == null:
		return
	var k := clampf(stock / COIL_M, 0.0, 1.0)
	var base: float = float(game.stage.DEFS["rope"].get("scale", 1.0))
	coil.visual.scale = Vector3(base * lerpf(0.55, 1.0, k), base * lerpf(0.3, 1.0, k), base * lerpf(0.55, 1.0, k))


func _show_spills() -> void:
	var sig := ""
	for spill: Array in spills:
		sig += "%.2f,%.2f,%.3f;" % [(spill[0] as Vector3).x, (spill[0] as Vector3).z, float(spill[1])]
	if sig == _spill_sig:
		return
	_spill_sig = sig
	_show_coil()
	while _spill_root.get_child_count() < spills.size():
		var pile := MeshInstance3D.new()
		var cone := CylinderMesh.new()
		cone.top_radius = 0.12
		cone.bottom_radius = 1.0
		cone.height = 1.0
		cone.radial_segments = 14
		cone.rings = 1
		pile.mesh = cone
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.13, 0.12, 0.13)
		mat.roughness = 1.0
		pile.material_override = mat
		_spill_root.add_child(pile)
	for i in _spill_root.get_child_count():
		var pile: MeshInstance3D = _spill_root.get_child(i)
		pile.visible = i < spills.size()
		if pile.visible:
			var radius := spill_radius(float(spills[i][1]))
			var tall := maxf(0.012, radius * 0.22)
			pile.scale = Vector3(radius, tall, radius)
			pile.global_position = (spills[i][0] as Vector3) + Vector3(0, tall * 0.5, 0)


# ---- 操作（F）と画面の案内 ----

func _view(me: Node) -> Array:
	var cam: Camera3D = me.cam
	if cam == null:
		return []
	return [cam.global_position, -cam.global_basis.z]


# 視線の先の、線の上の場所（はさみで切る所）。無ければ {}
func aim_cord(me: Node) -> Dictionary:
	var view := _view(me)
	if view.is_empty():
		return {}
	var best := {}
	for id: int in cords:
		var cord: Node3D = cords[id]
		var hit: Dictionary = cord.nearest_to_ray(view[0], view[1])
		if hit.is_empty() or float(hit["off"]) > CUT_AIM + 0.02 * float(hit["along"]):
			continue
		if (hit["point"] as Vector3).distance_to(me.global_position + Vector3(0, 1.0, 0)) > game.Player.REACH + 0.6:
			continue
		if best.is_empty() or float(hit["off"]) < float(best["off"]):
			best = hit
			best["cord"] = id
	return best


# 視線の先の、火を付けられる端（燃えていない線の先。切れ端なら両方の端）。無ければ {}
func aim_end(me: Node) -> Dictionary:
	var view := _view(me)
	if view.is_empty():
		return {}
	var from: Vector3 = view[0]
	var dir: Vector3 = view[1]
	var best := {}
	for id: int in cords:
		var cord: Node3D = cords[id]
		if cord.burning or cord.pts.size() < 2:
			continue
		var ends: Array = []
		if cord.b_body == null:
			ends.append([1, cord.tip()])
		if cord.a_body == null:
			ends.append([0, cord.root()])
		for item: Array in ends:
			var p: Vector3 = item[1]
			var along := (p - from).dot(dir)
			if along < 0.2 or p.distance_to(me.global_position + Vector3(0, 1.0, 0)) > game.Player.REACH + 0.6:
				continue
			var off := (p - from - dir * along).length()
			if off > TIP_AIM + 0.02 * along:
				continue
			# 切った所では、爆弾につながった線の先と、切れ端の端が並ぶ。爆弾につながった線を先に選ぶ
			var rank: float = off - (0.2 if cord.a_body == bomb else 0.0)
			if best.is_empty() or rank < float(best["off"]):
				best = {"cord": id, "end": int(item[0]), "point": p, "off": rank}
	return best


# いま F を押すと起きること。{"do": 種類, ...}。関係なければ {}
#   do：connect（つなぐ）/ coil（束を持っているだけ）/ cut（切る）/ scissors（はさみを持っているだけ）/ pour（注ぐ）/
#       light（線の端に点火）/ light_bomb（つないでいない爆弾に点火）/ bomb_cord（つないである爆弾を見ている）/ run（燃えている）
func f_action(me: Node) -> Dictionary:
	if me == null or flow == null or me.operating != 0 or flow.phase not in [2, 4] or game.state not in [game.S.PREP, game.S.TAKE] or game.replaying:
		return {}
	var held: Node3D = game.props.get(me.held) if me.held != 0 else null
	var target: Node3D = me.target
	if held != null:
		if held == coil:
			if target == bomb and not bomb.absent:
				return {"do": "connect"}
			return {"do": "coil"}
		if held == scissors:
			var cut := aim_cord(me)
			if cut.is_empty():
				return {"do": "scissors"}
			cut["do"] = "cut"
			return cut
		if held in sacks:
			return {"do": "pour", "sack": held}
		return {}
	var tip := aim_end(me)
	if not tip.is_empty():
		tip["do"] = "light"
		return tip
	if target == coil and not coil.absent:
		var fed := coil_cord()
		if fed != null and not fed.burning:
			return {"do": "light", "cord": fed.id, "end": 1, "point": fed.tip()}
	if target == bomb and not bomb.absent:
		var mine := bomb_cord()
		if bomb._burn_left > 0.0 or (mine != null and mine.burning):
			return {"do": "run"}
		return {"do": "bomb_cord"} if mine != null else {"do": "light_bomb"}
	return {}


# ロープを持って、つなげる爆弾を見ているか（cargo_kit.gd が、フックに結ぶ操作より先に譲る）
func wants_rope(me: Node) -> bool:
	return str(f_action(me).get("do", "")) == "connect"


# F が押された（自分の画面）。ここで受けたら true
func handle_f(me: Node) -> bool:
	var act := f_action(me)
	if act.is_empty():
		return false
	match str(act["do"]):
		"connect":
			h_connect.rpc_id(1)
		"cut":
			h_cut.rpc_id(1, int(act["cord"]), float(act["s"]))
		"pour":
			_pouring_local = int(act["sack"].pid)
			h_pour.rpc_id(1, true)
		"light":
			h_light.rpc_id(1, int(act["cord"]), int(act["end"]))
		"light_bomb", "bomb_cord":
			h_light_bomb.rpc_id(1)
		_:
			# 束・はさみを持っているだけ：F はほかの使い道（箱に入れる・荷台に積む）へ回す
			return false
	return true


# 画面の案内（production_hud.gd）。動作だけを書く。量・長さ・秒数は書かない。{}＝関係ない
#   label：狙っている物の名前 / keys：操作の案内
func hud_view(me: Node) -> Dictionary:
	var act := f_action(me)
	if act.is_empty():
		return {}
	var put: String = "\n" + str(game.hold_hint())
	match str(act["do"]):
		"connect":
			return {"keys": "F つなぐ" + put}
		"coil":
			return {}          # ロープを持っているだけ：案内は cargo_kit.gd（フックに結ぶ・つなぐ）
		"cut":
			return {"label": "ロープ", "keys": "F 切る" + put}
		"scissors":
			# 荷台に掛けたロープを狙っているなら、そちらの案内（cargo_kit.gd）
			if str(game.cargo_kit.f_action(me).get("do", "")) == "cut":
				return {}
			return {"keys": "ロープを見て F 切る" + put}
		"pour":
			return {"keys": "F 注ぐ（押している間）" + put}
		"light":
			return {"label": "ロープの先", "keys": "F 点火"}
		"light_bomb":
			return {"label": "爆弾", "keys": "F 点火\n左クリック 持つ"}
		"bomb_cord":
			return {"label": "爆弾", "keys": "ロープの先を見て F 点火\n左クリック 持つ"}
		"run":
			return {"label": "爆弾", "keys": "離れろ！"}
	return {}


# ---- 登録（feature_hooks.gd）。決まった名前の関数を持っていると、中心の側が呼ぶ ----

func hook_events() -> Array:
	return ["bombkit", "bombnum"]


# 導火線（つながり・長さ・燃えているか）と、こぼれた火薬
func hook_event(_n: String, a: Array) -> void:
	receive(a[0])


# 本番中の変化は、見返しにも同じに流す
func hook_rec_events() -> Array:
	return ["bombkit", "bombnum"]


func hook_core_event(n: String, a: Array) -> void:
	if n == "absent":
		absent_changed()
	elif n == "burst":
		on_burst_seen(a[0], float(a[1]))


func hook_sync(who: int) -> void:
	sync_to(who)


# F：束を持ってつなぐ・はさみで切る・袋から注ぐ・線の先（つないでいない爆弾）に点火
func hook_f(me: Node) -> bool:
	return handle_f(me)


# 画面の案内：できる動作だけを案内する（つなぐ・切る・注ぐ・点火）。
# 火薬の量・導火線の長さ・残り秒数は出さない（ゲームの中の見た目で判断する）。文は hud_view() が決める
func hook_hud(me: Node, _label: String, _keys: String) -> Dictionary:
	if game.production.phase not in [2, 4] or game.state not in [game.S.PREP, game.S.TAKE]:
		return {}
	var view: Dictionary = hud_view(me)
	if view.is_empty():
		return {}
	var out := {"keys_all": view["keys"]}
	if view.has("label"):
		out["label"] = view["label"]
	return out


# 本番が始まった：見返しの最初に、撮り始めたときの導火線とこぼれた火薬へ戻す
func hook_take_start() -> void:
	game._rec_events.append([0.0, "bombkit", [snapshot(true)]])


func hook_playback(on: bool) -> void:
	playback_changed(on)


# 買った爆弾に付く袋・持ち越した袋の数が変わったら、出ている袋を合わせ直す
func hook_production_applied() -> void:
	absent_changed()

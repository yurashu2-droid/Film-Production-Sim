extends RefCounted
## ひもの束：会社のロープ（1本）と、あとから足した束（モップの王様の毛ひも）。残りの長さを出し入れする。
## cargo_kit.gd（運ぶ道具の入口）が作って持つ。外からは game.cargo_kit.〜 で呼ぶ（cargo_kit.gd が、ここへ渡す）。
## 使うのは、荷台のロープ（cargo_lash.gd）・爆弾の導火線（bomb_kit.gd）・キャラの特技（cast_talent.gd）・手でつかむ（rope_grab.gd）。
## 会社のロープの残りの長さそのものは、爆弾の道具（bomb_kit.gd の stock）が持っている（荷物を押さえるのにも、導火線にも使う1本）

# ---- ロープ ----
const ROPE_COLOR := Color(0.80, 0.66, 0.40)
const SCRAP := -1                             # ロープの出どころ：床の切れ端を手で結んだ（束には戻らない。ほどくと、床の切れ端に戻る）

var kit: Node                                 # cargo_kit.gd（入口）
var game: Node:
	get:
		return kit.game
var rope: RigidBody3D
# 会社のロープのほかの束（物のID → {prop 束の物, bank 残りの長さを持っている所, color ひもの色}）。
# いまは、モップの王様の毛ひも（cast_talent.gd）。bank は coil_stock(物のID) と coil_use(物のID, 長さ) を持つ
var coils: Dictionary = {}


# ---- ロープ（荷台のフックからフックへ掛ける） ----


# 束を1つ増やす（全員の画面で、同じ順に呼ぶ）。会社のロープとは別の、自分の長さを持つ束。
# 持って、フックを見て F で結ぶ・掛ける・ほどく・はさみで切れる、は会社のロープと同じ
func add_coil(prop: RigidBody3D, bank: Object, color: Color) -> void:
	coils[prop.pid] = {"prop": prop, "bank": bank, "color": color}


# その物は、ひもの束か（会社のロープ、または、足した束）
func is_coil(prop: Node) -> bool:
	return prop != null and (prop == rope or coils.has(prop.pid))


# 束の番号（会社のロープは 0、足した束は、その物のID）
func coil_id(prop: Node) -> int:
	return int(prop.pid) if prop != null and coils.has(prop.pid) else 0


# 束の物（番号 0＝会社のロープ）
func coil_prop(coil: int) -> RigidBody3D:
	return coils[coil]["prop"] if coils.has(coil) else rope


# 当たりを調べるときに、よける束（全部）
func _coil_rids() -> Array[RID]:
	var out: Array[RID] = [rope.get_rid()]
	for row: Dictionary in coils.values():
		out.append((row["prop"] as RigidBody3D).get_rid())
	return out


# 束に残っている長さ（会社のロープは、爆弾の導火線に使う分と同じ束）
func stock(coil: int = 0) -> float:
	if coil == SCRAP:
		return 0.0
	if coils.has(coil):
		return float(coils[coil]["bank"].coil_stock(coil))
	var bk: Node = kit._bk()
	return float(bk.stock) if bk != null else 0.0


# 束から出す（負なら、束に巻き戻す）
func _use(amount: float, coil: int = 0) -> void:
	if coil == SCRAP:
		return
	if coils.has(coil):
		coils[coil]["bank"].coil_use(coil, amount)
		return
	var bk: Node = kit._bk()
	if bk == null:
		return
	bk.stock = clampf(float(bk.stock) - amount, 0.0, float(bk.COIL_M))
	bk._dirty = true


func _coil_exit(coil: int = 0) -> Vector3:
	var prop := coil_prop(coil)
	return prop.center + Vector3(0, prop.half.y * 0.5, 0)


# ---- 見た目 ----


# 巻いたケーブルのモデルを、ロープの色にする（形はそのまま。金具と留め具の色は変えない）
func _tint_rope(model: Node3D) -> void:
	var hemp := StandardMaterial3D.new()
	hemp.albedo_color = ROPE_COLOR
	hemp.roughness = 0.95
	for mesh: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		for s in mesh.mesh.get_surface_count():
			var mat: Material = mesh.get_active_material(s)
			if mat != null and mat.resource_name.to_lower().begins_with("rubber"):
				mesh.set_surface_override_material(s, hemp)

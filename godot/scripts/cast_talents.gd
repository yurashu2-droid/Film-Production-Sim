extends RefCounted
## キャラごとの特技の表と、ゲームの状態に触らない決まりごと。
##
## ・特技はキャラを選ぶだけで使える（K キー）。育たない・保存しない・レベルで強さが変わらない。
##   経験値で育つ「制作班スキル」（crew_skills.gd / crew_profile.gd）とは別の表・別の画面。
## ・状態を持つ部分（誰が何をしまっているか、ランプの点灯）と、ホストの判断・見た目は cast_talent.gd。
## ・まだ作っていない特技は ready を false にしておく（キャラを選ぶ画面に「準備中」と出る）。
##
## 特技を足すときは TALENTS の ready を true にして、cast_talent.gd の host_use() にそのキャラの分岐を足す。

const KEY_NAME := "K"

# tag：キャラの番号（main.gd の PLAYER_CASTS と同じ）
#   name：特技の名前 / desc：キャラを選ぶ画面に出す説明 / ready：もう使えるか
const TALENTS := {
	"M02": {"name": "おなかランプ", "ready": true,
		"desc": "おなかの窓が光って、向いた先を弱く照らす。K で点ける・消す。\n役者の顔を明るくする足しになる（これだけでは、まだ暗い）。"},
	"09": {"name": "頭の道具箱", "ready": true,
		"desc": "小物を3つまで頭にしまって、手ぶらで運べる。仲間も、頭を見て F で取り出せる。\n小物を持って（見て）K でしまう。手ぶらの K で、最後に入れた物を出す。"},
	"04": {"name": "びよーん首", "ready": true,
		"desc": "K で首を伸ばす・戻す。高い所から見渡せて、高い所の物にも手が届く。\n離れた確認用モニターものぞける。伸ばしている間は走れない。"},
	"03": {"name": "台本の写し", "ready": true,
		"desc": "台本を持っていなくても、手帳に写した台本のページを開ける。K で開く・閉じる。\n台本は1冊のまま。台本を持つ人と二人で、せりふを読み分けられる。"},
	"01": {"name": "ショールをかける", "ready": true,
		"desc": "物を見て K で、肩のショールをかける。役に合わない物が「それっぽく」見える。\nかけた物を見て K で外す。風や爆風で、ずれる・飛ぶことがある。"},
	"02": {"name": "止まれ！", "ready": true,
		"desc": "K で、目の前の動く物（台車・風で流れた物・落ちてくる物）を、少しの間ぴたりと止める。\n背中の赤い札が立っていれば使える。使うと倒れて、ゆっくり起き上がる。"},
	"06": {"name": "毛ひも", "ready": true,
		"desc": "K で自分の毛をひもにして持つ。荷台のフックを見て F で結び、荷物に掛けられる。\nもう一度 K でしまう。使った分だけ、頭の毛がさみしくなる。"},
}

# ---- 段ボール頭「頭の道具箱」 ----
const STOW_SLOTS := 3            # 頭にしまえる数（手に持つ1個とは別）
const STOW_MAX_SIDE := 0.85      # 入る物の、いちばん長い辺（m）
const STOW_MAX_MASS := 3.0       # 入る物の重さ（kg）
# 大きさや重さに関係なく、しまえない物：みんなで使う会社の機材・台本・役者の印・危ない物・道具・入れ物
const STOW_NEVER := ["clapper", "script", "cue_card", "standin", "camera", "spot", "monitor", "mark", "fx", "glue", "carton", "truck", "hair_cord"]
const STOW_SHOW_MIN := 0.30      # 頭の上に出す縮めた見た目の、いちばん長い辺（m）。小さい物でも見分けられる大きさ
const STOW_SHOW_MAX := 0.48
const STOW_SHOW_RATE := 0.6     # もとの大きさに掛ける割合（上の2つの間に収める）

# ---- ロボット「おなかランプ」 ----
const LAMP_RANGE := 5.0          # 光が届く距離（m）。遠いほど弱い
const LAMP_ANGLE := 32.0         # 光の広がり（度。中心からの角度）
const LAMP_TILT := 0.26          # 少し上向きに照らす（ラジアン）。2〜4m先の顔に当たる
# 採点（judge.gd の brightness）に足す明るさの上限。顔の明るさの基準は 0.30 で、何も無い所が 0.05。
# ランプだけでは 0.25 までにしかならない（月やスポットライトの足しにして、はじめて届く）
const LAMP_FACTOR := 0.20
const LAMP_AT := Vector3(0.0, 0.74, 0.34)     # おなかの窓の位置（キャラの足元から。+Z が正面）

# ---- ドレスの人「ショールをかける」 ----
const SHAWL_COUNT := 2           # 1つの依頼で使えるショールの枚数（残りは、肩に掛かっている枚数で見せる）
const SHAWL_REACH := 1.0         # かける・外すときに手が届く距離（Player.REACH に足す）
const SHAWL_GUST := Vector2(0.2, 0.75)   # 突風1回で、布がずれる量（1.0 までずれたら飛ぶ）
const SHAWL_BLAST := 5.0         # 爆発から、この距離までの布がずれる・飛ぶ（m）

# ---- カエルの警官「止まれ！」 ----
const HALT_RANGE := 5.0          # 止められる距離（m）
const HALT_ANGLE := 45.0         # 左右の広がり（度。正面からの角度）
const HALT_TIME := 2.0           # 止まっている長さ（秒）
const HALT_WAIT := 8.0           # 次に使えるまで（秒。背中の札が起き上がるまで）
const HALT_NEVER := ["truck", "mark", "carton_pile"]

# ---- モップの王様「毛ひも」 ----
const HAIR_M := 6.0              # 毛ひもにできる長さ（m。1つの依頼で）
const HAIR_KIND := "hair_cord"   # 手に持つ毛の束（物の種類）
const HAIR_COILS := 4            # 束の数（参加者の数だけ用意しておく）
const HAIR_TUFTS := 6            # 頭の房の数（使った長さだけ、短くなって消えていく）
const HAIR_COLOR := Color(0.93, 0.89, 0.78)
const HAIR_CORD_COLOR := Color(0.90, 0.80, 0.52)   # 掛けたひもの色（白い荷台の上でも見えるよう、少し濃い）

# ---- ベレー帽の人「びよーん首」 ----
const NECK_RISE := 0.5           # 視点と、手が届く基準が上がる高さ（m）
const NECK_MONITOR := 6.5        # 確認用モニターをのぞける距離（m。ふつうは 3.4）
const NECK_SPEED := 2.2          # 伸び縮みの速さ（m/秒）


static func has(tag: String) -> bool:
	return TALENTS.has(tag)


static func of(tag: String) -> Dictionary:
	return TALENTS.get(tag, {})


static func title(tag: String) -> String:
	return str(of(tag).get("name", ""))


static func describe(tag: String) -> String:
	return str(of(tag).get("desc", ""))


static func ready(tag: String) -> bool:
	return bool(of(tag).get("ready", false))


# その物を頭にしまえない理由（""＝しまえる）。種類・大きさ（half＝外形の半分）・重さだけで決まる
static func stow_refusal(kind: String, half: Vector3, mass: float) -> String:
	if kind in STOW_NEVER:
		return "これは頭にしまえない"
	if maxf(half.x, maxf(half.y, half.z)) * 2.0 > STOW_MAX_SIDE + 0.001:
		return "入らない（大きすぎ）"
	if mass > STOW_MAX_MASS + 0.001:
		return "入らない（重すぎ）"
	return ""


static func can_stow(kind: String, half: Vector3, mass: float) -> bool:
	return stow_refusal(kind, half, mass) == ""


# 「止まれ！」の扇形に入っているか。from＝立っている場所、facing＝向いている先（水平）、at＝物の中心
static func in_halt_fan(from: Vector3, facing: Vector3, at: Vector3) -> bool:
	var to := Vector3(at.x - from.x, 0.0, at.z - from.z)
	if to.length() > HALT_RANGE or absf(at.y - from.y) > HALT_RANGE:
		return false
	if to.length() < 0.3:
		return true
	return rad_to_deg(Vector3(facing.x, 0.0, facing.z).normalized().angle_to(to.normalized())) <= HALT_ANGLE


# 毛の残り（m）→ 頭の房それぞれの長さ（0〜1）。後ろの房から順に短くなる
static func hair_tufts(left: float) -> Array:
	var out: Array = []
	var per: float = HAIR_M / float(HAIR_TUFTS)
	for i in HAIR_TUFTS:
		out.append(clampf((left - per * float(i)) / per, 0.0, 1.0))
	return out


# 頭の上に出す縮めた見た目の、いちばん長い辺（m）
static func stow_show_size(half: Vector3) -> float:
	var longest: float = maxf(half.x, maxf(half.y, half.z)) * 2.0
	return clampf(longest * STOW_SHOW_RATE, STOW_SHOW_MIN, STOW_SHOW_MAX)


# ランプの光の広がり方：中心からの角度（度）と距離（m）→ 0〜1
static func lamp_falloff(angle_deg: float, distance: float) -> float:
	if distance >= LAMP_RANGE:
		return 0.0
	var cone: float = 1.0 - smoothstep(LAMP_ANGLE * 0.8, LAMP_ANGLE, angle_deg)
	return cone * (1.0 - distance / LAMP_RANGE)

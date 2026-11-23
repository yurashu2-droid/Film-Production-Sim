extends "res://scripts/paint_board.gd"
# 等身大パネル（P04 等身大・代役パネル）。前面の紙（+Z）に、色つきで絵を描ける。
# 何を描いてもいいので、見立てでは「ジョーカー」：どの役にもなれて、コンボを1つ完成させられる
# （production_cast.gd の joker）。白紙のままだと、ただの白い板として扱われる。
# 元の素材：小物/撮影機材/等身大パネル/P04_Actor_StandIn_Package.zip（形・比率はそのまま、等倍で使う）
const MODEL := preload("res://assets/gear/P04_Actor_StandIn.glb")
const RESOLUTION := Vector2i(512, 1200)       # 前面の紙は 0.768m × 1.8m（32:75）
# 最初から貼れる見本（素材に付いていた架空の俳優の絵）
const PRESETS := {
	"actor_a": "res://assets/gear/standin/Actor_A_BaseColor.png",
	"actor_b": "res://assets/gear/standin/Actor_B_BaseColor.png",
}
const BLANK_BELOW := 0.02                      # 描いた所がこれより少なければ白紙あつかい
const PropShapes := preload("res://scripts/prop_shapes.gd")


func build() -> void:
	kind = "standin"
	label = "等身大パネル（Fでペイント）"
	mass = 9.0
	one_sided = true
	hold_min = 1.5
	visual = MODEL.instantiate()
	add_child(visual)
	# 全体：幅0.83 × 高さ1.91 × 奥行0.82。板が前（+Z）、三角の支えが後ろへ伸びる
	center = Vector3(0, 0.955, -0.378)
	half = Vector3(0.415, 0.955, 0.389)
	make_ink(RESOLUTION)
	var found := bind_surface(visual, "P04_FRONT_IMAGE", true)
	assert(found, "Supplied stand-in panel must have P04_FRONT_IMAGE")
	# 当たり判定と重心は表（prop_shapes.gd）：立っている板、床の足、後ろの横木、斜めの支え（足の間は空いている）。
	# 重心は低く、板と支えの間。背が高いので倒れにくくする
	PropShapes.build(self, kind)
	angular_damp = 1.5
	_refresh()


# 何か描いてあるか（見本を貼っただけでも「描いてある」）
func blank() -> bool:
	return painted() < BLANK_BELOW


func paste_preset(id: String) -> void:
	if not PRESETS.has(id):
		return
	var picture := load(PRESETS[id]) as Texture2D
	if picture != null:
		set_picture(picture.get_image())

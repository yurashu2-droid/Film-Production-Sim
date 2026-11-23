extends Node
## 夜の撮影（依頼の "night"）。1日目の紹介動画は夜に撮る（2026-11-13 ユーザー「紹介動画は夜でいいよ。ライトのチュートリアルも入れる」）。
##   ・ふつうに遊ぶ1日目は、準備の間に日が暮れる（同日「準備中にだんだん暗くなって、その時にライトをバズ山が教える」）：
##     依頼を受けた時は昼。撮影時間（lease）が DUSK_START 秒たつと夕方になり始め、DUSK_END 秒で夜。
##     暗くなると、講師がライトを教える（features/day1_guide.gd）。準備が先に全部済んだら、急いで暮れる（hurry）
##   ・そのほかの夜の依頼は、受けている間ずっと夜（2 秒かけて替える）
##   ・昼 → 夕方（日が傾いて影が長くなり、空が橙）→ 夜（青い月明かり、空は紺）。目で見る現場も、撮影カメラの映像も同じ
##   ・顔の明るさの判定は、もとから光の当たり方（judge.gd の brightness）で決めている。夜はライトが要る、が見て分かる
## 舞台（stage.gd）の日の光と、拠点の空（production_flow.gd・production_look.gd）は書き換えず、元の値を覚えておいて掛け合わせる
## 全員の画面で、そろって届いている依頼・日にち・撮影時間から決める（合図は要らない。少しのずれは、ゆっくり追うのでならす）
const BLEND_SEC := 2.0                # 夜の依頼で、昼 → 夜にかける秒数（急いで暮れる時も）
const DUSK_START := 40.0              # 1日目：依頼を受けてから、暮れ始めるまでの秒数
const DUSK_END := 200.0               # 1日目：この秒数で、夜になりきる
const DARK := 0.8                     # これより暗ければ「暗くなった」（講師がライトを教える）
# 夕方（night = 0.5）
const DUSK_SUN := 0.75
const DUSK_SUN_COLOR := Color(1.0, 0.6, 0.36)
const DUSK_PITCH := -13.0             # 日の高さ（度）。低いほど影が長い
const DUSK_AMBIENT := 0.7
const DUSK_AMBIENT_COLOR := Color(0.95, 0.72, 0.62)
const DUSK_SKY := [Color("41558c"), Color("f0956a"), Color("9a7462"), Color("4c4242")]
const DUSK_SKY_ENERGY := 0.8
const DUSK_FOG := Color("c98f73")
# 夜（night = 1）
const SUN_ENERGY := 0.16              # 日の光（月明かり）の強さの倍率
const SUN_COLOR := Color(0.55, 0.66, 1.0)
const FILL_ENERGY := 0.35
const AMBIENT := 0.32                 # 環境光の倍率
const AMBIENT_COLOR := Color(0.42, 0.5, 0.78)
const NIGHT_SKY := [Color("0b1326"), Color("27304a"), Color("1c2130"), Color("0d1018")]
const SKY_ENERGY := 0.35
const FOG_COLOR := Color("1d2438")

var game: Node
var force := false                    # 自動確認でも、1日目に日を暮れさせる
var hurry := false                    # 準備が先に済んだ：すぐ夜にする（講師が立てる）
var night := 0.0                      # 0 昼 〜 0.5 夕方 〜 1 夜
var _base := {}                       # 元の値（はじめて暮れる時に覚える）
var _suns: Array = []


# いまの暗さの目当て（0 昼 〜 1 夜）
func goal() -> float:
	var flow: Node = game.get("production")
	if flow == null:
		return 0.0
	if int(flow.day) <= 1 and ((bool(flow.daily) and not _debug()) or force):
		# ふつうに遊ぶ1日目：依頼を受けてから、撮影時間の進みで暮れる
		if int(flow.phase) >= 5:
			return 1.0          # 納品したあとも、その日は夜のまま
		if int(flow.phase) < 4:
			return 0.0
		if hurry:
			return 1.0
		var spent: float = float(flow.lease_time()) - float(flow.lease_left)
		return clampf((spent - DUSK_START) / (DUSK_END - DUSK_START), 0.0, 1.0)
	if bool(flow.job().get("night", false)) and int(flow.phase) >= 4:
		return 1.0
	return 0.0


func dark() -> bool:
	return night >= DARK


func _debug() -> bool:
	var start: Node = game.hooks.feature("start_day")
	return start != null and start.has_method("keeps_everything") and bool(start.keeps_everything())


func _process(delta: float) -> void:
	if game == null or game.get("production") == null:
		return
	var flow: Node = game.production
	if int(flow.day) > 1 or int(flow.phase) < 4:
		hurry = false
	var g := goal()
	if is_equal_approx(night, g):
		return
	if _base.is_empty() and not _remember():
		return
	# 撮影時間は少しずつ届くので、ゆっくり追う。夜の依頼・急ぐ時は 2 秒で
	night = move_toward(night, g, delta / BLEND_SEC)
	_apply(night)


# 元の値を覚える（拠点の空ができてから）
func _remember() -> bool:
	var env: Environment = game.production.get("_world_environment")
	if env == null:
		return false
	_base["env"] = env
	_base["ambient"] = env.ambient_light_energy
	_base["ambient_color"] = env.ambient_light_color
	_base["fog"] = env.fog_light_color
	_base["fog_energy"] = env.fog_light_energy
	var sky_mat: ProceduralSkyMaterial = env.sky.sky_material as ProceduralSkyMaterial if env.sky != null else null
	if sky_mat != null:
		_base["sky"] = sky_mat
		_base["sky_cols"] = [sky_mat.sky_top_color, sky_mat.sky_horizon_color, sky_mat.ground_horizon_color, sky_mat.ground_bottom_color]
		_base["sky_mul"] = sky_mat.energy_multiplier
	_suns.clear()
	for child: Node in game.stage.get_children():
		if child is DirectionalLight3D:
			var l := child as DirectionalLight3D
			_suns.append([l, l.light_energy, l.light_color, l.rotation_degrees.x])
	return true


# 昼 → 夕方 → 夜 の 3 つの値の間
func _f3(day: float, dusk: float, nite: float, k: float) -> float:
	return lerpf(day, dusk, k * 2.0) if k < 0.5 else lerpf(dusk, nite, k * 2.0 - 1.0)


func _c3(day: Color, dusk: Color, nite: Color, k: float) -> Color:
	return day.lerp(dusk, k * 2.0) if k < 0.5 else dusk.lerp(nite, k * 2.0 - 1.0)


func _apply(k: float) -> void:
	var env: Environment = _base["env"]
	var amb: float = _base["ambient"]
	env.ambient_light_energy = _f3(amb, amb * DUSK_AMBIENT, amb * AMBIENT, k)
	env.ambient_light_color = _c3(_base["ambient_color"], DUSK_AMBIENT_COLOR, AMBIENT_COLOR, k)
	env.fog_light_color = _c3(_base["fog"], DUSK_FOG, FOG_COLOR, k)
	env.fog_light_energy = _f3(_base["fog_energy"], _base["fog_energy"], float(_base["fog_energy"]) * 0.5, k)
	if _base.has("sky"):
		var sky_mat: ProceduralSkyMaterial = _base["sky"]
		var cols: Array = _base["sky_cols"]
		sky_mat.sky_top_color = _c3(cols[0], DUSK_SKY[0], NIGHT_SKY[0], k)
		sky_mat.sky_horizon_color = _c3(cols[1], DUSK_SKY[1], NIGHT_SKY[1], k)
		sky_mat.ground_horizon_color = _c3(cols[2], DUSK_SKY[2], NIGHT_SKY[2], k)
		sky_mat.ground_bottom_color = _c3(cols[3], DUSK_SKY[3], NIGHT_SKY[3], k)
		var mul: float = _base["sky_mul"]
		sky_mat.energy_multiplier = _f3(mul, mul * DUSK_SKY_ENERGY, mul * SKY_ENERGY, k)
	for i in _suns.size():
		var s: Array = _suns[i]
		var l: DirectionalLight3D = s[0]
		if not is_instance_valid(l):
			continue
		var e: float = s[1]
		if i == 0:
			# いちばん強いもの（最初の 1 本）が日の光：夕方に傾いて橙になり、夜は低いまま青い月明かりになる
			l.light_energy = _f3(e, e * DUSK_SUN, e * SUN_ENERGY, k)
			l.light_color = _c3(s[2], DUSK_SUN_COLOR, SUN_COLOR, k)
			l.rotation_degrees.x = lerpf(float(s[3]), DUSK_PITCH, minf(k * 2.0, 1.0))
		else:
			l.light_energy = _f3(e, e, e * FILL_ENERGY, k)
			l.light_color = _c3(s[2], s[2], SUN_COLOR, k)

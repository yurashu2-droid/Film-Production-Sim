extends Node
## 夜の撮影（依頼の "night"）。1日目の紹介動画は夜に撮る（2026-11-13 ユーザー「紹介動画は夜でいいよ。ライトのチュートリアルも入れる」）。
##   ・現場の空・日の光・環境光・もやを、夜の色へ 2 秒かけて替える（昼に戻す時も同じ）。目で見る現場も、撮影カメラの映像も、同じ夜
##   ・ふつうに遊ぶ1日目は、箱を開けた時から夜（依頼を受ける前から）。そのほかは、夜の依頼を受けている間だけ
##   ・顔の明るさの判定は、もとから光の当たり方（judge.gd の brightness）で決めているので、夜でも昼でも同じ。夜はライトが要る、が見て分かる
## 舞台（stage.gd）の日の光と、拠点の空（production_flow.gd・production_look.gd）は書き換えず、元の値を覚えておいて掛け合わせる
## 全員の画面で、そろって届いている依頼と日にちから決める（合図は要らない）
const BLEND_SEC := 2.0
const SUN_ENERGY := 0.16              # 日の光（月明かり）の強さの倍率
const SUN_COLOR := Color(0.55, 0.66, 1.0)
const FILL_ENERGY := 0.35
const AMBIENT := 0.32                 # 環境光の倍率
const AMBIENT_COLOR := Color(0.42, 0.5, 0.78)
const SKY_TOP := Color("0b1326")
const SKY_HORIZON := Color("27304a")
const GROUND_HORIZON := Color("1c2130")
const GROUND_BOTTOM := Color("0d1018")
const SKY_ENERGY := 0.35
const FOG_COLOR := Color("1d2438")

var game: Node
var force := false                    # 自動確認でも、1日目を夜にする
var night := 0.0                      # 0 昼 〜 1 夜
var _base := {}                       # 元の値（はじめて夜にする時に覚える）
var _suns: Array = []


func wanted() -> bool:
	var flow: Node = game.get("production")
	if flow == null:
		return false
	if bool(flow.job().get("night", false)) and int(flow.phase) >= 4:
		return true
	# ふつうに遊ぶ1日目は、依頼を受ける前から夜
	return int(flow.day) <= 1 and ((bool(flow.daily) and not _debug()) or force)


func _debug() -> bool:
	var start: Node = game.hooks.feature("start_day")
	return start != null and start.has_method("keeps_everything") and bool(start.keeps_everything())


func _process(delta: float) -> void:
	if game == null or game.get("production") == null:
		return
	var goal := 1.0 if wanted() else 0.0
	if is_equal_approx(night, goal):
		return
	if _base.is_empty() and not _remember():
		return
	night = move_toward(night, goal, delta / BLEND_SEC)
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
	_base["sky_energy"] = env.background_energy_multiplier
	var sky_mat: ProceduralSkyMaterial = env.sky.sky_material as ProceduralSkyMaterial if env.sky != null else null
	if sky_mat != null:
		_base["sky"] = sky_mat
		_base["sky_cols"] = [sky_mat.sky_top_color, sky_mat.sky_horizon_color, sky_mat.ground_horizon_color, sky_mat.ground_bottom_color]
		_base["sky_mul"] = sky_mat.energy_multiplier
	_suns.clear()
	for child: Node in game.stage.get_children():
		if child is DirectionalLight3D:
			var l := child as DirectionalLight3D
			_suns.append([l, l.light_energy, l.light_color])
	return true


func _apply(k: float) -> void:
	var env: Environment = _base["env"]
	env.ambient_light_energy = lerpf(_base["ambient"], _base["ambient"] * AMBIENT, k)
	env.ambient_light_color = (_base["ambient_color"] as Color).lerp(AMBIENT_COLOR, k)
	env.fog_light_color = (_base["fog"] as Color).lerp(FOG_COLOR, k)
	env.fog_light_energy = lerpf(_base["fog_energy"], _base["fog_energy"] * 0.5, k)
	if _base.has("sky"):
		var sky_mat: ProceduralSkyMaterial = _base["sky"]
		var cols: Array = _base["sky_cols"]
		sky_mat.sky_top_color = (cols[0] as Color).lerp(SKY_TOP, k)
		sky_mat.sky_horizon_color = (cols[1] as Color).lerp(SKY_HORIZON, k)
		sky_mat.ground_horizon_color = (cols[2] as Color).lerp(GROUND_HORIZON, k)
		sky_mat.ground_bottom_color = (cols[3] as Color).lerp(GROUND_BOTTOM, k)
		sky_mat.energy_multiplier = lerpf(_base["sky_mul"], _base["sky_mul"] * SKY_ENERGY, k)
	for i in _suns.size():
		var s: Array = _suns[i]
		var l: DirectionalLight3D = s[0]
		if not is_instance_valid(l):
			continue
		# いちばん強いもの（最初の 1 本）が日の光、ほかは補い
		l.light_energy = lerpf(s[1], float(s[1]) * (SUN_ENERGY if i == 0 else FILL_ENERGY), k)
		l.light_color = (s[2] as Color).lerp(SUN_COLOR, k)

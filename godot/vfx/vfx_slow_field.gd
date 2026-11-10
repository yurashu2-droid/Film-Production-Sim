extends Node3D
## スロー光線の見た目（道具と決まりは scripts/features/slow_ray.gd）。
## 題材：時間が遅くなる。光る泡で包むのではなく、「遅れた時間」そのものを見せる。
## 参考：映画の連続写真（マレー、マイブリッジ。1枚に何コマも重ねて写す）、『ビューティフル ジョー』のスロー（残像）、
##       『ベヨネッタ』のウィッチタイム（時計の文字盤）、映写機の光の中に浮くほこり。
##
## 素材：        目盛りと針（紙に引いた線。光らない）／少し前の姿のコマ（網点）／光の中に浮くほこり（小さなきらめき）
## どこから来る： 目盛りは、浴びた物のまわりに上から時計回りに1本ずつ現れる。ほこりは、懐中電灯の頭から先へ流れる
## 先に動く部分： 針（0.5秒ごとに1目盛り、コマ送りで進む）と、物そのもの
## 遅れて追う部分：少し前の姿のコマ（0.07秒おきに4枚。古いほど網点が粗い）と、まわりに浮くほこり
## 形の変化：     0.0〜0.3秒：目盛りが12本、順に現れる ／ 0.5秒ごと：針がカチッと1目盛り進む ／
##                動いている間：コマが後ろに並び、止まると重なって見えなくなる ／ ほこりは2〜3秒ごとに生まれ直し、少しずつ昇る
## 終わり：       目盛り＝針が早回りで1周して、通った所から1本ずつぬぐわれる（時間が元に戻る）。0.36秒
##                コマ＝新しいコマが足されなくなり、古いほうから1枚ずつ抜けて、物に追いつく
##                ほこり＝上へ細く伸びて抜ける
##                範囲の円すい＝出どころが止まるので、根元から先へ消える。中のほこりは、流れ切る
## 映画に映る物：目盛り・コマ・物のまわりのほこり。映らない物（制作班だけ）：範囲の円すいと、その中のほこり
const TICK := preload("res://vfx/shaders/slow_tick.gdshader")
const GHOST := preload("res://vfx/shaders/slow_ghost.gdshader")
const MOTE := preload("res://vfx/shaders/slow_mote.gdshader")
const CONE := preload("res://vfx/shaders/slow_cone.gdshader")
const FLOOR := preload("res://vfx/shaders/slow_floor.gdshader")
const WARP := preload("res://vfx/shaders/slow_warp.gdshader")
const EsperAura := preload("res://vfx/esper/esper_aura.gd")
# ---- もう1つの型「psychic」：超能力・空間のゆがみ（2026-11-10 ユーザー「超能力っぽい感じとか空間のゆがみとかで表現するパターンも見てみたい」）----
# 浴びている物・人：輪郭そのものが膜になって、ゆっくり沸く（念力のオーラ shaders/psychic_aura。ゆらぎの型）。
#   まわりの景色がゆがみ、色が少しずれる。輪郭と同じ形の波紋が、1.15秒ごとに、のろのろ広がる（遅い鼓動）。
#   出る時：懐中電灯に近い側から、膜が物をなめるように広がる。終わる時：同じ側から、ぬぐわれるように消える。
# 届く範囲：円すいを通して見える景色が、ゆっくり波打つ（光る筋や粒は出さない）。床の扇形は同じ。
const PSY_LOOK := {"band": 0.03, "amp": 0.12, "jag": 0.0, "rise": 0.3, "split": 0.02, "haze": 0.4,
	"ring_gain": 1.0, "ring_reach": 0.6, "ring_width": 0.02, "warp": 1.0, "tint": Color(0.62, 0.48, 1.0)}
const PSY_RING_SEC := 1.6            # 波紋1本が広がり切るまで（遅い）
# ---- 3つ目の型「syrup」：光線の中だけ、空気が水あめになる（2026-11-10。浴びた物ではなく、物が入っている「場」を見せる）----
# 素材：        濃い液体のような空気（透明。光らない）。その中に浮くほこり
# どこから来る： 懐中電灯の頭から先へ、円すいの形に満ちる
# 先に動く部分： 物そのもの（境目を越えた瞬間に、ぷるんと縮む）
# 遅れて追う部分：物の輪郭にまとわりつく膜と、動いた後ろに残る引き波。着地の土ぼこりは、ゆっくり広がる
# 形の変化：     入った瞬間：輪郭の形の波紋が1つ立つ・物がぷるんと縮んで戻る（0.6秒）／中で動く：膜が後ろへ伸びる／
#                場は、大きくのろいうねり（細かく震えない）。ほこりは、ほぼ止まって、ゆっくり沈む
# 終わり：       出た瞬間：波紋がもう1つ・物がぷるんと伸びて戻る。膜は、懐中電灯に近い側からぬぐわれる。
#                場は、根元から先へ消える。ほこりは、沈みながら見えなくなる
# 映画に映る物：物の小さなぷるんと、ゆっくり舞う土ぼこりだけ。膜・波紋・場のゆがみ・ほこり・床の扇形は、制作班にだけ見える
const SYRUP_LOOK := {"band": 0.014, "amp": 0.04, "jag": 0.0, "rise": 0.0, "split": 0.0, "haze": 0.22,
	"ring_gain": 0.9, "ring_reach": 0.5, "ring_width": 0.02, "warp": 0.85, "opacity": 0.62, "tint": Color(1.0, 0.8, 0.46), "layers": 1 << 11}
const SYRUP_RING_SEC := 1.1
const POP_SEC := 0.6                 # ぷるんの長さ
const POP_SIZE := 0.1                # ぷるんの大きさ（1 に対して）
const Dust := preload("res://scripts/toon_dust.gd")
const PSY_PULSE := 1.15              # 波紋を出す間隔
const PSY_APPEAR := 0.35
const PSY_LEAVE := 0.5
const CREW_LAYER := 1 << 11          # 映画には映らない層（film_camera.gd と同じ番号）
const STEP := 1.0 / 12.0             # コマ打ち（目盛りと針）
const APPEAR := 0.3                  # 目盛りが出そろう秒数
const TICK_EVERY := 0.5              # 針が1目盛り進む間隔
const LEAVE := 0.36                  # 終わり：針が早回りして、目盛りをぬぐう秒数
const GHOSTS := 4                    # 少し前の姿のコマの枚数
const SAMPLE := 0.07                 # コマを取る間隔
const GHOST_DENSITY := [0.62, 0.46, 0.3, 0.16]
const GHOST_SHRINK := 0.95           # コマは少し小さく（物に重なっている所は、物の中に隠れる。はみ出した所だけ見える）
const MOTES_EACH := 6                # 浴びている物1つのまわりに浮くほこり
const MOTE_MAX := 96
const CONE_MOTES := 72               # 範囲の円すいの中を流れるほこり
const GROW := 0.25                   # 円すいが根元から先へ伸びる秒数
const EATEN := 0.45                  # 円すいが根元から先へ消える秒数

var style := "clock"                 # 見た目の型："clock"（時計の目盛り・残像・ほこり）／"psychic"（輪郭のオーラ・波紋・空間のゆがみ）
var _t := 0.0
var _range := 9.0
var _half := 0.17
var _marks := {}                     # 浴びている物・人 → {ring, mat, born, leave, hand0, seed, center, radius, visual, ghosts, hist, sample}
var _motes: MultiMesh
var _cone_pivot: Node3D
var _cone_mat: ShaderMaterial
var _cone_mesh: MeshInstance3D
var _mote_mats: Array = []
var _dusts: Array = []               # ゆっくり舞う土ぼこり [[煙, 進んだ秒数], ...]
var _warp_mat: ShaderMaterial
var _floor: MeshInstance3D           # 床に映る扇形
var _floor_mat: ShaderMaterial
var _floor_y := 0.0
var _cone_motes: MultiMesh
var _cone_on := false
var _cone_grow := 0.0
var _cone_eaten := 1.0
var _cone_power := 0.0
var _cone_want := 0.0
var _cone_from := Vector3.ZERO
var _cone_dir := Vector3.FORWARD


func setup(reach: float, half_angle: float, look: String = "clock") -> void:
	style = look
	_range = reach
	_half = half_angle
	_motes = _mote_cloud(MOTE_MAX, 1)
	_cone_motes = _mote_cloud(CONE_MOTES, CREW_LAYER)
	# 範囲の円すい：とがった先を、懐中電灯の頭に置く
	_cone_pivot = Node3D.new()
	_cone_pivot.name = "SlowCone"
	_cone_pivot.visible = false
	add_child(_cone_pivot)
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.0
	mesh.bottom_radius = reach * tan(half_angle)
	mesh.height = reach
	mesh.radial_segments = 40
	mesh.rings = 12
	mesh.cap_top = false
	mesh.cap_bottom = false
	var cone := MeshInstance3D.new()
	cone.mesh = mesh
	cone.position.y = -reach * 0.5
	_cone_mat = ShaderMaterial.new()
	_cone_mat.shader = CONE
	_cone_mat.set_shader_parameter("height", reach)
	_warp_mat = ShaderMaterial.new()
	_warp_mat.shader = WARP
	_warp_mat.set_shader_parameter("height", reach)
	_cone_mesh = cone
	cone.material_override = _warp_mat if style != "clock" else _cone_mat
	cone.layers = CREW_LAYER
	cone.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_cone_pivot.add_child(cone)
	# 床に映る扇形（上から見た範囲）
	_floor = MeshInstance3D.new()
	_floor.name = "SlowFloor"
	var plane := PlaneMesh.new()
	plane.size = Vector2(reach * 2.1, reach * 2.1)
	_floor.mesh = plane
	_floor_mat = ShaderMaterial.new()
	_floor_mat.shader = FLOOR
	_floor_mat.set_shader_parameter("reach", reach)
	_floor_mat.set_shader_parameter("spread", tan(half_angle))
	_floor.material_override = _floor_mat
	_floor.layers = CREW_LAYER
	_floor.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_floor.visible = false
	add_child(_floor)
	_palette()


# 型ごとの色と、ゆがみの性格
func _palette() -> void:
	var syrup := style == "syrup"
	_warp_mat.set_shader_parameter("tint", Vector3(1.0, 0.8, 0.45) if syrup else Vector3(0.62, 0.5, 1.0))
	_warp_mat.set_shader_parameter("pace", 0.45 if syrup else 1.0)
	_warp_mat.set_shader_parameter("grain", 0.55 if syrup else 1.0)
	_warp_mat.set_shader_parameter("chroma", 0.0 if syrup else 1.0)
	_warp_mat.set_shader_parameter("bend", 0.034 if syrup else 0.022)
	_floor_mat.set_shader_parameter("tint", Vector3(0.95, 0.68, 0.25) if syrup else Vector3(0.42, 0.3, 0.86))
	_floor_mat.set_shader_parameter("ink", Vector3(0.5, 0.32, 0.1) if syrup else Vector3(0.22, 0.14, 0.42))
	for mat: ShaderMaterial in _mote_mats:
		mat.set_shader_parameter("light", Vector3(1.0, 0.95, 0.8) if syrup else Vector3(0.95, 0.92, 1.0))
		mat.set_shader_parameter("ink", Vector3(0.45, 0.3, 0.12) if syrup else Vector3(0.24, 0.17, 0.4))


func _mote_cloud(count: int, layers: int) -> MultiMesh:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	mm.mesh = quad
	mm.instance_count = count
	mm.visible_instance_count = 0
	var holder := MultiMeshInstance3D.new()
	holder.multimesh = mm
	var mat := ShaderMaterial.new()
	mat.shader = MOTE
	_mote_mats.append(mat)
	holder.material_override = mat
	holder.layers = layers
	holder.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	holder.custom_aabb = AABB(Vector3(-600, -100, -600), Vector3(1200, 300, 1200))
	add_child(holder)
	return mm


# 見た目の型を替える（出ている物は、いったん片づける）
func set_style(look: String) -> void:
	for body: Variant in _marks.keys():
		_drop(body)
	style = look
	_cone_mesh.material_override = _warp_mat if style != "clock" else _cone_mat
	_motes.visible_instance_count = 0
	_palette()


# 決まった乱数（0〜1）
static func h(a: int, b: int) -> float:
	var n: int = (a * 374761393 + b * 668265263) & 0xffffffff
	n = ((n ^ (n >> 13)) * 1274126177) & 0xffffffff
	n = n ^ (n >> 16)
	return float(n & 0xffff) / 65535.0


# ---- 浴びている物・人 ----

# いま浴びている物・人をまとめて渡す：{体 → [中心（体から見た場所）, 大きさ（半径 m）, 残像にする見た目（無ければ null）]}
func sync(targets: Dictionary) -> void:
	for body: Variant in targets:
		if _marks.has(body) and float(_marks[body]["leave"]) < 0.0:
			continue
		if _marks.has(body):
			_drop(body)          # 終わりかけの物に、もう一度当たった：出し直す
		_begin(body as Node3D, targets[body])
	for body: Variant in _marks.keys():
		if not targets.has(body) and float(_marks[body]["leave"]) < 0.0:
			_end(body)


func _begin(body: Node3D, info: Array) -> void:
	if style != "clock":
		_begin_psychic(body, info)
		return
	var seed_value := float(body.get_instance_id() % 997) / 997.0
	var ring := MeshInstance3D.new()
	ring.name = "SlowAura"
	var quad := QuadMesh.new()
	quad.size = Vector2(2.0, 2.0)
	ring.mesh = quad
	var mat := ShaderMaterial.new()
	mat.shader = TICK
	mat.set_shader_parameter("seed", seed_value)
	mat.set_shader_parameter("appear", 0.0)
	ring.material_override = mat
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ring.extra_cull_margin = 8.0
	ring.position = info[0]
	ring.scale = Vector3.ONE * float(info[1])
	body.add_child(ring)
	var ghosts: Array = []
	var visual: Node3D = info[2] as Node3D
	if visual != null:
		for i in GHOSTS:
			var copy: Node3D = visual.duplicate(0)
			for s: Node in copy.find_children("*", "", true, false):
				# コマには、形だけあればよい（動きの再生機・カメラ・明かり・音・当たりは要らない）
				if not (s is Node3D) or s is Camera3D or s is Light3D or s is CollisionObject3D or s is AudioStreamPlayer3D or s is GPUParticles3D:
					if is_instance_valid(s) and not s.is_queued_for_deletion():
						s.queue_free()
			var gmat := ShaderMaterial.new()
			gmat.shader = GHOST
			gmat.set_shader_parameter("density", float(GHOST_DENSITY[i]))
			for mesh: Node in [copy] + copy.find_children("*", "GeometryInstance3D", true, false):
				if mesh is GeometryInstance3D:
					(mesh as GeometryInstance3D).material_override = gmat
					(mesh as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			copy.visible = false
			add_child(copy)
			copy.set_meta("shrink", Basis().scaled(Vector3.ONE * GHOST_SHRINK))
			ghosts.append(copy)
	_marks[body] = {"ring": ring, "mat": mat, "born": _t, "leave": -1.0, "hand0": 0.0, "seed": seed_value,
		"center": info[0], "radius": float(info[1]), "visual": visual, "ghosts": ghosts, "hist": [], "sample": 0.0}


# 終わりを始める：針が早回りして、目盛りをぬぐう
func _end(body: Variant) -> void:
	var m: Dictionary = _marks[body]
	m["leave"] = _t
	if not m.has("aura"):
		m["hand0"] = _hand(m)
	elif bool(m.get("syrup", false)):
		# 境目を出た：波紋がもう1つ。物は、伸びて戻る
		if is_instance_valid(m["aura"]):
			(m["aura"] as MeshInstance3D).ring(_t)
		if m.has("base"):
			m["pop"] = _t
			m["pop_dir"] = -1.0
	if is_instance_valid(m["ring"]):
		(m["ring"] as Node).name = "SlowAuraEnding"


# 超能力の型・水あめの型：輪郭に沿う膜を付ける（物は、見た目の外形に沿う。人は、頭と足をつないだ丸い形）
func _begin_psychic(body: Node3D, info: Array) -> void:
	var marker := Node3D.new()            # 「浴びている」の印（中身は無い。膜は、この仕組みの子）
	marker.name = "SlowAura"
	body.add_child(marker)
	var syrup := style == "syrup"
	var visual: Node3D = info[2] as Node3D
	var opts: Dictionary = (SYRUP_LOOK if syrup else PSY_LOOK).duplicate()
	var aura: MeshInstance3D
	if visual != null:
		aura = EsperAura.around(self, visual, opts)
	else:
		opts["pad"] = 0.42
		aura = EsperAura.at(self, PackedVector3Array([body.global_position + Vector3(0, 0.3, 0), body.global_position + Vector3(0, 1.45, 0)]), opts)
	aura.ring_sec = SYRUP_RING_SEC if syrup else PSY_RING_SEC
	aura.p("reveal", 0.0)
	_marks[body] = {"ring": marker, "aura": aura, "person": visual == null, "born": _t, "leave": -1.0, "pulse": _t + 0.25,
		"center": info[0], "radius": float(info[1]), "ghosts": [], "syrup": syrup, "last": body.global_position, "speed": Vector3.ZERO}
	if syrup:
		aura.ring(_t)                     # 境目を越えた：波紋が1つ
		if visual != null:
			_marks[body]["visual"] = visual
			_marks[body]["base"] = visual.scale
			_marks[body]["pop"] = _t
			_marks[body]["pop_dir"] = 1.0


# 膜の1コマ：相手に沿わせる。出入りは、懐中電灯に近い側から。
# 超能力の型は、のろい波紋を出し続ける。水あめの型は、動いた後ろへ膜を伸ばし（引き波）、出入りの瞬間に物をぷるんとさせる
func _psychic_step(body: Node3D, m: Dictionary, delta: float) -> void:
	var aura: MeshInstance3D = m["aura"]
	if not is_instance_valid(aura):
		_drop(body)
		return
	if bool(m["person"]):
		aura.move(PackedVector3Array([body.global_position + Vector3(0, 0.3, 0), body.global_position + Vector3(0, 1.45, 0)]))
	aura.place(_t, 0.0)
	var centre: Vector3 = body.to_global(m["center"])
	var radius: float = float(m["radius"])
	var toward: Vector3 = _cone_from - centre
	aura.p("grip", centre + (toward.normalized() if toward.length() > 0.01 else Vector3.UP) * radius)
	var span := radius * 2.0 + 1.6
	var syrup: bool = bool(m["syrup"])
	if syrup:
		# 引き波：動く向きの後ろへ、膜が伸びる（急に変えず、なめらかに追う）
		if delta > 0.0:
			var now: Vector3 = (body.global_position - (m["last"] as Vector3)) / delta
			m["speed"] = (m["speed"] as Vector3).lerp(now, 0.2)
			m["last"] = body.global_position
		aura.p("trail_world", (m["speed"] as Vector3).limit_length(1.6) / 1.6)
		_pop(m)
	if float(m["leave"]) < 0.0:
		var k := clampf((_t - float(m["born"])) / PSY_APPEAR, 0.0, 1.0)
		aura.p("reveal", (1.0 - pow(1.0 - k, 2.0)) * span)
		aura.p("drain", -1.0)
		if not syrup and _t >= float(m["pulse"]):
			aura.ring(_t)
			m["pulse"] = _t + PSY_PULSE
	else:
		var k := clampf((_t - float(m["leave"])) / PSY_LEAVE, 0.0, 1.0)
		aura.p("drain", k * k * span)
		if _t - float(m["leave"]) > maxf(PSY_LEAVE, POP_SEC if syrup else 0.0) + 0.05:
			_drop(body)


# ぷるん：境目を越えた瞬間に、物の見た目が少し縮んで（出る時は伸びて）、揺れながら戻る
func _pop(m: Dictionary) -> void:
	if not m.has("base") or not is_instance_valid(m.get("visual")):
		return
	var visual: Node3D = m["visual"]
	var age: float = _t - float(m["pop"])
	var base: Vector3 = m["base"]
	if age >= POP_SEC:
		visual.scale = base
		return
	var w := sin(age * 20.0) * exp(-age * 6.5) * POP_SIZE * float(m["pop_dir"])
	visual.scale = base * Vector3(1.0 + w * 0.6, 1.0 - w, 1.0 + w * 0.6)


# ゆっくり舞う土ぼこり（スローの中で着地した時）。煙の進み方を、こちらで 0.3 倍にして進める
func dust(at: Vector3, size: float) -> void:
	for k in 4:
		var turn := TAU * float(k) / 4.0 + 0.5
		var puff: Node3D = Dust.new()
		add_child(puff)
		puff.global_position = at + Vector3(sin(turn), 0.0, cos(turn)) * 0.2
		puff.burst(Vector3(sin(turn), 0.0, cos(turn)), size)
		puff.set_physics_process(false)
		_dusts.append([puff, 0.0])


func _dust_step(delta: float) -> void:
	for row: Array in _dusts.duplicate():
		var puff: Node3D = row[0]
		if not is_instance_valid(puff):
			_dusts.erase(row)
			continue
		row[1] = float(row[1]) + delta * 0.3
		puff.age = float(row[1])
		if float(row[1]) >= float(puff.LIFETIME):
			_dusts.erase(row)
			puff.queue_free()
		else:
			puff._update_puffs()


func _drop(body: Variant) -> void:
	var m: Dictionary = _marks[body]
	_marks.erase(body)
	if m.has("aura") and is_instance_valid(m["aura"]):
		(m["aura"] as Node).queue_free()
	if m.has("base") and is_instance_valid(m.get("visual")):
		(m["visual"] as Node3D).scale = m["base"]          # ぷるんの途中で片づけても、元の大きさに戻す
	if is_instance_valid(m["ring"]):
		(m["ring"] as Node).queue_free()
	for g: Variant in m["ghosts"]:
		if is_instance_valid(g):
			(g as Node).queue_free()


# 針の向き（1 で1周）：0.5秒ごとに、カチッと1目盛り進む
func _hand(m: Dictionary) -> float:
	var age: float = _t - float(m["born"])
	var steps := floorf(age / TICK_EVERY)
	var within := age - steps * TICK_EVERY
	var k := clampf(within / 0.16, 0.0, 1.0)
	return (steps - 1.0 + (1.0 - pow(1.0 - k, 3.0))) / 12.0 + float(m["seed"])


func _process(delta: float) -> void:
	_t += delta
	var stepped: float = floorf(_t / STEP) * STEP
	var n := 0
	for body: Variant in _marks.keys():
		var m: Dictionary = _marks[body]
		if not is_instance_valid(body) or not is_instance_valid(m["ring"]):
			_drop(body)
			continue
		if m.has("aura"):
			_psychic_step(body as Node3D, m, delta)
			continue
		var mat: ShaderMaterial = m["mat"]
		var leaving: bool = float(m["leave"]) >= 0.0
		var out := 0.0
		if leaving:
			out = clampf((stepped - float(m["leave"])) / LEAVE, 0.0, 1.0)
			if _t - float(m["leave"]) > LEAVE + 0.3:
				_drop(body)
				continue
			# 針が1周、早回り（はじめゆっくり、すぐ速く）。通った所から、目盛りが消える
			var turn := out * out * (3.0 - 2.0 * out)
			mat.set_shader_parameter("hand", float(m["hand0"]) + turn)
			mat.set_shader_parameter("wipe_from", fposmod(float(m["hand0"]), 1.0))
			mat.set_shader_parameter("wipe", turn)
		else:
			mat.set_shader_parameter("appear", clampf((stepped - float(m["born"])) / APPEAR, 0.0, 1.0))
			mat.set_shader_parameter("hand", _hand(m))
			mat.set_shader_parameter("wipe", 0.0)
		_ghosts(m, delta, leaving)
		n = _body_motes(body as Node3D, m, n, out)
	_motes.visible_instance_count = n
	_cone_step(delta)
	_dust_step(delta)


# 少し前の姿のコマ：0.07秒おきに今の姿を控え、古い順に並べる。終わりは、古いほうから1枚ずつ抜ける
func _ghosts(m: Dictionary, delta: float, leaving: bool) -> void:
	var visual: Node3D = m["visual"] as Node3D
	var ghosts: Array = m["ghosts"]
	if ghosts.is_empty() or not is_instance_valid(visual):
		return
	var hist: Array = m["hist"]
	m["sample"] = float(m["sample"]) + delta
	if float(m["sample"]) >= SAMPLE:
		m["sample"] = 0.0
		if leaving:
			if not hist.is_empty():
				hist.pop_back()
		else:
			hist.push_front(visual.global_transform)
			if hist.size() > GHOSTS + 1:
				hist.pop_back()
	for i in ghosts.size():
		var g: Node3D = ghosts[i]
		var at := i + 1
		var seen: bool = at < hist.size() and (hist[at] as Transform3D).origin.distance_to(visual.global_position) > 0.09
		g.visible = seen
		if seen:
			var past: Transform3D = hist[at]
			g.global_transform = Transform3D(past.basis * (g.get_meta("shrink") as Basis), past.origin)


# 浴びている物のまわりに浮くほこり：2〜3秒ごとに、別の場所に生まれ直す。少しずつ昇り、終わりは上へ細く伸びて抜ける
func _body_motes(body: Node3D, m: Dictionary, n: int, out: float) -> int:
	var age: float = _t - float(m["born"])
	var centre: Vector3 = body.to_global(m["center"])
	var radius: float = float(m["radius"])
	var id := int(float(m["seed"]) * 997.0)
	for j in MOTES_EACH:
		if n >= MOTE_MAX:
			break
		var cycle := 1.8 + 1.4 * h(id, j * 7 + 1)
		var phase := (age + cycle * h(id, j * 7 + 2)) / cycle
		var lap := int(floorf(phase))
		var u := phase - floorf(phase)
		var turn := TAU * h(id + lap * 31, j * 7 + 3)
		var lift := lerpf(-0.5, 0.8, h(id + lap * 31, j * 7 + 4))
		var far := radius * lerpf(0.7, 1.05, h(id + lap * 31, j * 7 + 5))
		var size := lerpf(0.06, 0.11, h(id, j * 7 + 6)) * clampf(radius, 0.5, 1.4)
		# 大きいかけらは遅く、小さいかけらは速く昇る
		var rise := lerpf(0.34, 0.14, (size - 0.025) / 0.115) * u
		var pos := centre + Vector3(cos(turn) * far, lift * radius * 0.7 + rise, sin(turn) * far)
		var glow := smoothstep(0.0, 0.1, u) * (1.0 - smoothstep(0.72, 1.0, u))
		var stretch := smoothstep(0.72, 1.0, u)
		if out > 0.0:
			pos.y += out * out * 0.6
			stretch = maxf(stretch, out)
			glow *= 1.0 - out
		_motes.set_instance_transform(n, Transform3D(Basis().scaled(Vector3.ONE * size), pos))
		_motes.set_instance_custom_data(n, Color(glow, stretch, 0.0, 0.0))
		n += 1
	return n


# ---- 範囲の円すい（制作班だけ） ----

# aim：[出どころ, 向き]。空なら、消す。power：出している＝1、持っているだけ＝弱く（ほこりは流さない）。floor_y：扇形を映す床の高さ
func cone(aim: Array, power: float, floor_y: float = 0.0) -> void:
	if aim.is_empty():
		_cone_on = false
		return
	_floor_y = floor_y
	_cone_from = aim[0]
	_cone_dir = (aim[1] as Vector3).normalized()
	_cone_want = power
	if not _cone_on:
		_cone_on = true
		if _cone_eaten >= 1.0:
			_cone_grow = 0.0          # 消え切っていたら、根元から伸ばし直す
		_cone_eaten = 0.0


func _cone_step(delta: float) -> void:
	if _cone_on:
		_cone_grow = minf(1.0, _cone_grow + delta / GROW)
	else:
		_cone_eaten = minf(1.0, _cone_eaten + delta / EATEN)
	_cone_power = move_toward(_cone_power, _cone_want, delta * 3.0)
	var live: bool = _cone_on or _cone_eaten < 1.0
	_cone_pivot.visible = live
	_floor.visible = live
	if not live:
		_cone_motes.visible_instance_count = 0
		return
	# とがった先を出どころに、開いた口を向きの先へ
	var facing: Basis = Basis(Quaternion(Vector3.DOWN, _cone_dir)) if _cone_dir.dot(Vector3.UP) < 0.999 else Basis(Vector3.RIGHT, PI)
	_cone_pivot.global_transform = Transform3D(facing, _cone_from)
	_cone_mat.set_shader_parameter("grow", _cone_grow)
	_cone_mat.set_shader_parameter("eaten", _cone_eaten)
	_cone_mat.set_shader_parameter("power", _cone_power)
	_cone_mat.set_shader_parameter("t", _t)
	_warp_mat.set_shader_parameter("grow", _cone_grow)
	_warp_mat.set_shader_parameter("eaten", _cone_eaten)
	_warp_mat.set_shader_parameter("power", _cone_power)
	_warp_mat.set_shader_parameter("t", _t)
	_floor.global_position = Vector3(_cone_from.x, _floor_y + 0.03, _cone_from.z)
	_floor_mat.set_shader_parameter("from", _cone_from)
	_floor_mat.set_shader_parameter("dir", _cone_dir)
	_floor_mat.set_shader_parameter("grow", _cone_grow)
	_floor_mat.set_shader_parameter("eaten", _cone_eaten)
	_floor_mat.set_shader_parameter("power", clampf(_cone_power * 1.2, 0.0, 1.0))
	_floor_mat.set_shader_parameter("t", _t)
	# 光の中のほこり：根元から先へ、ゆっくり流れ続ける（先で光が弱くなって見えなくなり、根元に生まれ直す）
	var side: Vector3 = facing.x
	var up: Vector3 = facing.z
	var spread := tan(_half)
	var n := 0
	var motes_on := clampf((_cone_power - 0.5) / 0.4, 0.0, 1.0) if style != "psychic" else 0.0
	if motes_on > 0.0 and style == "syrup":
		# 水あめの型：ほこりは流れない。ほぼ止まって、ゆっくり沈む。数秒ごとに、別の場所に生まれ直す
		for j in CONE_MOTES:
			var life := 4.0 + 3.0 * h(j, 21)
			var phase := (_t + life * h(j, 22)) / life
			var lap := int(floorf(phase))
			var u := phase - floorf(phase)
			var size := lerpf(0.035, 0.08, h(j, 11))
			var along := lerpf(0.12, 0.9, h(j + lap * 17, 23))
			var turn := TAU * h(j + lap * 17, 24)
			var off := sqrt(h(j + lap * 17, 25)) * 0.9 * along * _range * spread
			var sink := lerpf(0.05, 0.02, (size - 0.035) / 0.045) * u * life        # 大きいかけらは遅く沈む
			var pos := _cone_from + _cone_dir * (along * _range) + (side * cos(turn) + up * sin(turn)) * off + Vector3(sin(_t * 0.4 + float(j)) * 0.02, -sink, 0.0)
			var glow := smoothstep(0.0, 0.15, u) * (1.0 - smoothstep(0.7, 1.0, u))
			glow *= smoothstep(_cone_eaten - 0.02, _cone_eaten + 0.08, along) * (1.0 - smoothstep(_cone_grow - 0.08, _cone_grow + 0.02, along))
			_cone_motes.set_instance_transform(n, Transform3D(Basis().scaled(Vector3.ONE * size), pos))
			_cone_motes.set_instance_custom_data(n, Color(glow * motes_on * 0.8, 0.0, 0.0, 0.0))
			n += 1
	elif motes_on > 0.0:
		for j in CONE_MOTES:
			var size := lerpf(0.035, 0.085, h(j, 11))
			var speed := lerpf(0.75, 0.3, (size - 0.035) / 0.05)          # 大きいかけらは遅い
			var along := fposmod(h(j, 12) + _t * speed / _range, 1.0)
			var turn := TAU * h(j, 13) + _t * (h(j, 14) - 0.5) * 0.5
			var off := sqrt(h(j, 15)) * 0.9 * along * _range * spread
			var pos := _cone_from + _cone_dir * (along * _range) + (side * cos(turn) + up * sin(turn)) * off
			var glow := smoothstep(0.03, 0.12, along) * (1.0 - smoothstep(0.7, 0.97, along))
			glow *= smoothstep(_cone_eaten - 0.02, _cone_eaten + 0.08, along) * (1.0 - smoothstep(_cone_grow - 0.08, _cone_grow + 0.02, along))
			_cone_motes.set_instance_transform(n, Transform3D(Basis().scaled(Vector3.ONE * size), pos))
			_cone_motes.set_instance_custom_data(n, Color(glow * motes_on * 0.85, 0.0, 0.0, 0.0))
			n += 1
	_cone_motes.visible_instance_count = n

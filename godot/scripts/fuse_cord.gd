extends Node3D
# 束から出したロープ1本（爆弾につなぐと導火線になる）。節を短い間隔でつないだ、自前のひもの計算。
#   伸びない・重さで垂れる・床との摩擦で止まる・はねない・引くと端から順について来る。
#   誰も触っていなければ、落ち着いたあとは完全に止まる（asleep。節は1つも動かない）。
#   根元（a_body）＝爆弾の口金 / 先（b_body）＝ロープの束。どちらも null なら、床に落ちた切れ端。
#   長さ（length）は実際の長さ（m）。火が付くと、先から根元へ向かって燃えて短くなっていく。
# 形の計算は、全員がそれぞれの画面で行う（節の位置は送らない）。
# つながり・長さ・切れた場所・火が付いたかどうかは、ホストが決めて配る（bomb_kit.gd）。

const SEG := 0.1              # 節の間隔（m）
const THICK := 0.02           # 線の半径。床からこの高さに寝る
const ITER := 8               # 1コマあたりの、長さをそろえる計算の回数
const BEND := SEG * 0.95      # 1つ飛ばした節どうしの、いちばん近い距離（これより鋭くは折れない）
const SQUEEZE := 0.8          # たるんだ所で、節が寄れる限度（決まった間隔に対する割合）
const DAMP := 0.965            # 空中での勢いの残り方（揺れが、すぐおさまる）
const STICK := 0.0025          # 床の上で、1コマの引かれ方がこれより小さければ動かない（止まっている摩擦）
const SLIDE := 0.0             # 床をこすって動くときに残る勢い（残さない。引かれている間だけ動き、はずみで滑り続けない）
const PULL := 0.012            # 止まっている節が動き出す、となりの区切りの伸び（m）
const REST := 0.001            # 全部の節の1コマの動きがこれより小さければ「止まった」とみる（m）
const HITS := 1 | 2           # 当たる相手：床・壁と、置いてある物
const MAX_NODES := 400

var id := 0
var a_body: Node3D
var a_local := Vector3.ZERO
var b_body: Node3D
var b_local := Vector3.ZERO
var length := 0.0
var burning := false
var pts: PackedVector3Array = PackedVector3Array()
var old: PackedVector3Array = PackedVector3Array()
var asleep := false
var grip: PackedByteArray = PackedByteArray()    # 床の上で、摩擦で止まっている節（1）。となりの区切りが強く引かれるまで動かない
var balls: Array = []         # 丸い物（爆弾の玉）：[中心, 半径]。当たり判定より見た目が大きい分を、ここで押し出す
var iterations := ITER        # 1コマあたりの、長さをそろえる計算の回数（張って使うロープは、多くして伸びにくくする。cargo_kit.gd）
var hit_tip := false          # 先をつないだ物にも当てる（荷台のフックからフックへ掛けたロープ：軽トラの壁や荷台に当たる。cargo_kit.gd）
var hands: Dictionary = {}    # 手でつかまれている節（節の番号 → 手の場所）。毎コマ rope_grab.gd が入れる。その節は手について行く

var _mesh: MultiMeshInstance3D
var _spark: Node3D
var _spark_light: OmniLight3D
var _sparks: CPUParticles3D
var _still := 0
var _calm := 0
var _frame := 0
var _a_last := Vector3.ZERO
var _b_last := Vector3.ZERO
var _drawn := false
var _had_hands := false


func _ready() -> void:
	top_level = true
	global_transform = Transform3D.IDENTITY
	_mesh = MultiMeshInstance3D.new()
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	var tube := CylinderMesh.new()
	tube.top_radius = THICK
	tube.bottom_radius = THICK
	tube.height = 1.0
	tube.radial_segments = 6
	tube.rings = 1
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.80, 0.66, 0.40)       # ロープの色（cargo_kit.gd の ROPE_COLOR と同じ）
	mat.roughness = 0.9
	mat.emission_enabled = true
	mat.emission = Color(0.80, 0.66, 0.40)
	mat.emission_energy_multiplier = 0.15           # 暗い現場でも、床の線が見える
	tube.material = mat
	mm.mesh = tube
	mm.instance_count = 64
	mm.visible_instance_count = 0
	_mesh.multimesh = mm
	_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_mesh.custom_aabb = AABB(Vector3(-600, -100, -600), Vector3(1200, 300, 1200))
	add_child(_mesh)
	# 火花：燃えている間だけ、線の先に出る
	_spark = Node3D.new()
	_spark.visible = false
	add_child(_spark)
	var ember := MeshInstance3D.new()
	var dot := SphereMesh.new()
	dot.radius = 0.06
	dot.height = 0.12
	ember.mesh = dot
	var glow := StandardMaterial3D.new()
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.albedo_color = Color(1.0, 0.86, 0.45)
	ember.material_override = glow
	_spark.add_child(ember)
	_spark_light = OmniLight3D.new()
	_spark_light.light_color = Color(1.0, 0.62, 0.25)
	_spark_light.omni_range = 3.6
	_spark_light.light_energy = 3.0
	_spark.add_child(_spark_light)
	_sparks = CPUParticles3D.new()
	_sparks.amount = 18
	_sparks.lifetime = 0.35
	_sparks.direction = Vector3.UP
	_sparks.spread = 70.0
	_sparks.initial_velocity_min = 0.8
	_sparks.initial_velocity_max = 2.2
	_sparks.gravity = Vector3(0, -5.0, 0)
	_sparks.scale_amount_min = 0.5
	_sparks.scale_amount_max = 1.0
	var bit := SphereMesh.new()
	bit.radius = 0.016
	bit.height = 0.032
	bit.radial_segments = 4
	bit.rings = 2
	bit.material = glow
	_sparks.mesh = bit
	_sparks.emitting = false
	_spark.add_child(_sparks)
	_draw()


# ---- 形を決める ----

# 道すじ（折れ線）から節を並べる。nominal＝ロープの長さ（たるんで寄っていた分も数えた、もとの長さ）。
# 省くと、道すじの長さになる
func lay(path: PackedVector3Array, nominal: float = -1.0) -> void:
	pts = PackedVector3Array()
	if path.size() < 2:
		path = PackedVector3Array([Vector3.ZERO, Vector3(0.01, 0, 0)]) if path.is_empty() else PackedVector3Array([path[0], path[0] + Vector3(0.01, 0, 0)])
	var total := 0.0
	for i in path.size() - 1:
		total += path[i].distance_to(path[i + 1])
	if nominal <= 0.0:
		nominal = total
	nominal = maxf(nominal, 0.01)
	var count := mini(MAX_NODES, maxi(2, ceili(nominal / SEG - 0.001) + 1))
	var seg := 0
	var seg_from := 0.0
	for i in count:
		var want := minf(total, float(i) * SEG * total / nominal)
		if i == count - 1:
			want = total
		while seg < path.size() - 2 and seg_from + path[seg].distance_to(path[seg + 1]) < want:
			seg_from += path[seg].distance_to(path[seg + 1])
			seg += 1
		var span := maxf(path[seg].distance_to(path[seg + 1]), 0.0001)
		pts.append(path[seg].lerp(path[seg + 1], clampf((want - seg_from) / span, 0.0, 1.0)))
	old = pts.duplicate()
	grip = PackedByteArray()
	grip.resize(pts.size())
	length = nominal
	wake()


# 根元の端を、to へ持っていく（手でつかんでいた端を、口金やフックにつないだとき）。伸ばさない：
# to から少し離れた床へ垂らし、そこから届く所までの節は並べ直す。その先は、いまの形のまま。
# （to から床の節へ、斜めにぴんと渡すと、床の摩擦で張ったままになり、爆弾の玉の所で震え続ける）
func reroot(to: Vector3) -> void:
	var n := pts.size()
	var path := PackedVector3Array([to])
	var out := pts[n - 1] - to
	for j in range(1, n):
		if Vector2(pts[j].x - to.x, pts[j].z - to.z).length() > 0.3:
			out = pts[j] - to
			break
	out.y = 0.0
	out = out.normalized() if out.length() > 0.01 else Vector3.RIGHT
	# 垂らす先：to から横へ少し離れた、下の床（物の上）
	var used := 0.0
	var drop := to + out * 0.3
	var q := PhysicsRayQueryParameters3D.create(drop, drop + Vector3(0, -4.0, 0), HITS)
	var hit := get_world_3d().direct_space_state.intersect_ray(q) if is_inside_tree() else {}
	if not hit.is_empty() and (hit["position"] as Vector3).distance_to(to) < length * 0.8:
		drop = (hit["position"] as Vector3) + Vector3(0, THICK, 0)
		path.append(drop)
		used = to.distance_to(drop)
	else:
		drop = to
	var from := -1
	for j in range(1, n):
		if used + drop.distance_to(pts[j]) <= SEG * float(j) * 0.9:
			from = j
			break
	if from < 0:
		# 全部たぐっても届かない：垂らした先から、外の向きへ、残りの長さいっぱいに置く
		path.append(drop + out * maxf(0.05, (length - used) * 0.95))
	else:
		for j in range(from, n):
			path.append(pts[j])
	lay(path, length)


# 送る用の、間引いた道すじ（3節ごと。最後の節は必ず入れる）
func samples() -> PackedVector3Array:
	var out := PackedVector3Array()
	var step := maxi(3, ceili(float(pts.size()) / 40.0))
	for i in range(0, pts.size(), step):
		out.append(pts[i])
	if pts.size() > 0 and (pts.size() - 1) % step != 0:
		out.append(pts[pts.size() - 1])
	return out


# いちばん先の区切りの、決まった長さ（ほかの区切りは SEG）
func _tail_rest() -> float:
	return length - SEG * float(pts.size() - 2)


# 長さを変える。伸ばすときは先（束の側）に節を足し、縮めるときは先から節を外す
func set_length(next: float) -> void:
	next = maxf(next, 0.0)
	if is_equal_approx(next, length):
		return
	length = next
	while pts.size() < MAX_NODES and _tail_rest() > SEG * 1.5:
		var n := pts.size()
		var mid := pts[n - 2].lerp(pts[n - 1], clampf(SEG / maxf(pts[n - 2].distance_to(pts[n - 1]), 0.001), 0.0, 1.0))
		pts.insert(n - 1, mid)
		old.insert(n - 1, mid)
		grip.insert(n - 1, 0)
	while pts.size() > 2 and _tail_rest() <= 0.0:
		pts.remove_at(pts.size() - 1)
		old.remove_at(old.size() - 1)
		grip.remove_at(grip.size() - 1)
	wake()


func wake() -> void:
	asleep = false
	_still = 0
	_calm = 0


# 線ごと運ぶ（つないだ軽トラが動いた分だけ。荷台に掛けたロープは、走っている軽トラといっしょに動く）。
# 形は変わらないので、眠っている線は眠ったまま
func carry(shift: Transform3D) -> void:
	for i in pts.size():
		pts[i] = shift * pts[i]
		old[i] = shift * old[i]
	if _a_last != Vector3.ZERO:
		_a_last = shift * _a_last
	if _b_last != Vector3.ZERO:
		_b_last = shift * _b_last
	_drawn = false


# 節をつないだ道のり（引っぱられて伸びていると、length より長くなる）
func path_length() -> float:
	var total := 0.0
	for i in pts.size() - 1:
		total += pts[i].distance_to(pts[i + 1])
	return total


func tip() -> Vector3:
	return pts[pts.size() - 1] if not pts.is_empty() else Vector3.ZERO


func root() -> Vector3:
	return pts[0] if not pts.is_empty() else Vector3.ZERO


# 根元からの道のり s（m）にある点
func point_at(s: float) -> Vector3:
	var n := pts.size()
	if n < 2:
		return root()
	var i := clampi(int(s / SEG), 0, n - 2)
	var rest := SEG if i < n - 2 else maxf(_tail_rest(), 0.001)
	return pts[i].lerp(pts[i + 1], clampf((s - float(i) * SEG) / rest, 0.0, 1.0))


# 根元からの道のり s（m）にいちばん近い、手でつかめる節の番号（つないである端は、つかめない）。無ければ -1
func node_at(s: float) -> int:
	var n := pts.size()
	var first := 1 if a_body != null else 0
	var last := n - 2 if b_body != null else n - 1
	if n < 2 or first > last:
		return -1
	var k := n - 1 if s >= length - SEG * 0.5 else int(round(s / SEG))
	return clampi(k, first, last)


# 節 k の、根元からの道のり（m）
func s_of(k: int) -> float:
	return length if k >= pts.size() - 1 else SEG * float(k)


# 視線（from から dir の向き）にいちばん近い、線の上の場所。{"s": 根元からの道のり, "point": その点, "off": 視線からの離れ, "along": 視線に沿った距離}
func nearest_to_ray(from: Vector3, dir: Vector3) -> Dictionary:
	var best := {}
	var n := pts.size()
	for i in n - 1:
		var rest := SEG if i < n - 2 else maxf(_tail_rest(), 0.001)
		for k in 2:
			var w := 0.25 + 0.5 * float(k)
			var p := pts[i].lerp(pts[i + 1], w)
			var along := (p - from).dot(dir)
			if along < 0.2:
				continue
			var off := (p - from - dir * along).length()
			if best.is_empty() or off < float(best["off"]):
				best = {"s": float(i) * SEG + rest * w, "point": p, "off": off, "along": along}
	return best


# 先と根元を入れ替える（切れ端の、根元の側に火を付けたとき。火はいつも「先」から進む）
func flip() -> void:
	pts.reverse()
	old.reverse()
	var body := a_body
	var local := a_local
	a_body = b_body
	a_local = b_local
	b_body = body
	b_local = local
	# 入れ替えたあとも、端の区切りの長さが合うように並べ直す
	lay(pts.duplicate(), length)


# 爆風などで、節を吹き飛ばす
func shove(from: Vector3, reach: float, power: float) -> void:
	for i in pts.size():
		var d := pts[i] - from
		var dist := d.length()
		if dist < reach:
			var push := (d.normalized() + Vector3(0, 0.6, 0)).normalized() * power * (1.0 - dist / reach)
			old[i] = pts[i] - push
			grip[i] = 0
	wake()


# ---- 動かす（全員の画面で、毎コマ） ----

func _anchor(body: Node3D, local: Vector3) -> Vector3:
	return body.global_transform * local


func step(delta: float) -> void:
	var n := pts.size()
	if n < 2:
		return
	var a_pin := a_body != null and is_instance_valid(a_body)
	var b_pin := b_body != null and is_instance_valid(b_body)
	var a_at := _anchor(a_body, a_local) if a_pin else Vector3.ZERO
	var b_at := _anchor(b_body, b_local) if b_pin else Vector3.ZERO
	# つないだ物が遠くへ置き直された（現場への移動・撮り直し）：線ごと付いていく
	var jump := Vector3.ZERO
	if a_pin and a_at.distance_to(_a_last) > 2.5 and _a_last != Vector3.ZERO:
		jump = a_at - _a_last
	elif b_pin and not a_pin and b_at.distance_to(_b_last) > 2.5 and _b_last != Vector3.ZERO:
		jump = b_at - _b_last
	if jump != Vector3.ZERO:
		for i in n:
			pts[i] += jump
			old[i] += jump
	# つないだ物が動いたときだけ、起こす（2mm より小さな揺れでは起こさない）
	var moved := (a_pin and a_at.distance_squared_to(_a_last) > 0.000004) or (b_pin and b_at.distance_squared_to(_b_last) > 0.000004)
	if moved or jump != Vector3.ZERO or not asleep:
		_a_last = a_at
		_b_last = b_at
	if moved:
		wake()
	if grip.size() != n:
		grip.resize(n)
	var first := 1 if a_pin else 0
	var last := n - 2 if b_pin else n - 1
	# 手でつかまれた節（grip 2）：手が動いたら起こす。離されたら、その場から落ちる
	if _had_hands or not hands.is_empty():
		for i in n:
			if grip[i] == 2:
				grip[i] = 0
		if hands.is_empty():
			wake()
		for k: int in hands:
			if k < first or k > last:
				continue
			grip[k] = 2
			if pts[k].distance_squared_to(hands[k]) > 0.000001:
				wake()
		_had_hands = not hands.is_empty()
	if asleep:
		return
	var fall := Vector3(0, -9.8 * delta * delta, 0)
	var start := pts.duplicate()
	_frame += 1
	for i in range(first, last + 1):
		if grip[i] != 0:
			continue
		var p := pts[i]
		pts[i] = p + (p - old[i]) * DAMP + fall
		old[i] = p
	for k: int in hands:
		if k >= first and k <= last:
			pts[k] = hands[k]
			old[k] = hands[k]
	if a_pin:
		pts[0] = a_at
	if b_pin:
		pts[n - 1] = b_at
	# 伸びない：節の間隔を、決まった長さにそろえる。つないだ端から順に解く（行きと帰りを交互に）
	var tail := maxf(_tail_rest(), 0.005)
	# 手でつかまれている間は、引きがロープの先まで伝わるよう、計算の回数を増やす
	var rounds := maxi(iterations, 24) if not hands.is_empty() else iterations
	for pass_no in rounds:
		for step_no in n - 1:
			var i := step_no if pass_no % 2 == 0 else n - 2 - step_no
			var rest := SEG if i < n - 2 else tail
			var d := pts[i + 1] - pts[i]
			var dist := d.length()
			if dist < 0.00001:
				continue
			# ロープは引っぱりにだけ逆らう（押し返さない）。たるんだ所は、節が少し寄るだけ。
			# 寄りすぎ（決まった間隔の8割より近い）だけは、そっと戻す（1か所に固まって、短く見えないように）
			var want := rest
			if dist < rest:
				if dist >= rest * SQUEEZE:
					continue
				want = rest * SQUEEZE
			var fix := d * ((dist - want) / dist)
			var lock_a := i < first or grip[i] != 0
			var lock_b := i + 1 > last or grip[i + 1] != 0
			if lock_a and lock_b:
				continue
			if lock_a:
				pts[i + 1] -= fix
			elif lock_b:
				pts[i] += fix
			else:
				pts[i] += fix * 0.5
				pts[i + 1] -= fix * 0.5
		# 折れ曲がりすぎない（1つ飛ばした節どうしを、近づけすぎない）。落ちて重なった線が、ぎざぎざに折れないように
		for i in n - 3:
			var across := pts[i + 2] - pts[i]
			var gap := across.length()
			if gap >= BEND or gap < 0.00001:
				continue
			var open := across * ((gap - BEND) / gap)
			var hold_a := i < first or grip[i] != 0
			var hold_b := i + 2 > last or grip[i + 2] != 0
			if hold_a and hold_b:
				continue
			if hold_a:
				pts[i + 2] -= open
			elif hold_b:
				pts[i] += open
			else:
				pts[i] += open * 0.5
				pts[i + 2] -= open * 0.5
	# 手でつかんだ節から、どこにも結んでいない端までは、手から順について来る（伸びない。床の摩擦で止まっていた節も引きずる）
	for k: int in hands:
		if k < first or k > last:
			continue
		var lo := _fixed_past(k, -1, a_pin, b_pin)
		var hi := _fixed_past(k, 1, a_pin, b_pin)
		if lo < 0:
			_trail(k, -1, tail)
		else:
			_span(lo, k, tail)
		if hi < 0:
			_trail(k, 1, tail)
		elif not hands.has(hi):
			_span(k, hi, tail)          # 手と手の間は、根元の側の手の番で、もう済ませてある
	# 床・壁・物に当てる：このコマの動きの線で調べ、当たった面の上に乗せる。はねない
	var space := get_world_3d().direct_space_state
	# 根元の爆弾には当てる（口金から出て、玉の上を垂れる）。先の束は、線の出口が束の中にあるので当てない
	var skip: Array[RID] = []
	if b_pin and b_body is CollisionObject3D and not hit_tip:
		skip.append((b_body as CollisionObject3D).get_rid())
	var most := 0.0
	var busy := 0                 # このコマに、1mm より大きく動いた節の数
	for i in range(first, last + 1):
		var from := start[i]
		if grip[i] == 2:
			continue          # 手でつかまれた節は、手の場所のまま
		if grip[i] == 1:
			# 摩擦で止まっている節：となりの区切りが、はっきり引かれて伸びたら、動けるようにする（次のコマから付いて行く）。
			# ときどき、下の床がまだ在るかも確かめる（乗っていた物が運び去られたら、落ちる）
			var pulled := from.distance_to(pts[i - 1]) > SEG + PULL if i > 0 else false
			if i < n - 1 and from.distance_to(pts[i + 1]) > (SEG if i < n - 2 else tail) + PULL:
				pulled = true
			if not pulled and (_frame + i) % 24 == 0:
				var check := PhysicsRayQueryParameters3D.create(from + Vector3(0, 0.05, 0), from + Vector3(0, -THICK - 0.01, 0), HITS)
				check.exclude = skip
				pulled = space.intersect_ray(check).is_empty()
			if pulled:
				grip[i] = 0
				most = maxf(most, REST * REST * 4.0)
			continue
		var to := pts[i]
		var move := to - from
		var dist := move.length()
		var floor_up := Vector3.ZERO          # 乗っている面の向き（床の上でなければ ZERO）
		if dist > 0.00001:
			var q := PhysicsRayQueryParameters3D.create(from, to + move / dist * THICK, HITS)
			q.exclude = skip
			var hit := space.intersect_ray(q)
			if not hit.is_empty():
				var normal: Vector3 = hit["normal"]
				to = (hit["position"] as Vector3) + normal * THICK
				if normal.y > 0.5:
					floor_up = normal
				else:
					# 壁や物の横：面に沿った動きだけを残す。はねない
					old[i] = to
		if floor_up == Vector3.ZERO:
			# すぐ下に床があるか（横へ動いただけの節は、上の調べ方では床に触れない）
			var probe := PhysicsRayQueryParameters3D.create(to + Vector3(0, 0.05, 0), to + Vector3(0, -THICK - 0.002, 0), HITS)
			probe.exclude = skip
			var under := space.intersect_ray(probe)
			if not under.is_empty() and (under["normal"] as Vector3).y > 0.5:
				floor_up = under["normal"]
				to = (under["position"] as Vector3) + floor_up * THICK
		if floor_up != Vector3.ZERO:
			# 床の上：はずみは残さない。ほとんど引かれていなければ、摩擦でその場に止まったまま
			var slide := to - from
			slide -= floor_up * slide.dot(floor_up)
			if slide.length() < STICK and absf((to - from).dot(floor_up)) < 0.004:
				to = from
				grip[i] = 1
			old[i] = to
		pts[i] = to
		for ball: Array in balls:
			var out: Vector3 = pts[i] - (ball[0] as Vector3)
			var far: float = out.length()
			if far < float(ball[1]) and far > 0.0001:
				pts[i] = (ball[0] as Vector3) + out / far * float(ball[1])
				old[i] = old[i].lerp(pts[i], 0.7)
		if pts[i].y < -40.0:
			# 床の無い所へ落ちた節は、止める（待機場所の下まで落ち続けない）
			pts[i].y = -40.0
			old[i] = pts[i]
		var went := start[i].distance_squared_to(pts[i])
		most = maxf(most, went)
		if went > REST * REST:
			busy += 1
	# 動きが止まったら、完全に止める（つないだ物が動く・長さが変わる・切られる・爆風を受けるまで、節は1つも動かない）
	if most < REST * REST:
		_still += 1
		if _still > 20:
			asleep = true
			old = pts.duplicate()
	else:
		_still = 0
	# 小さな揺れだけが続いたら、止める。張ったロープが、物の角や爆弾の玉の所で、いつまでも小さく震え続けないように
	# （つないだ物・手が動く・長さが変わる、で、また動き出す）。小さな揺れ＝全体が1コマに 1cm より小さくしか動かない、
	# または、動いているのが3節までで、それも 3cm より小さい（落ちる・すべる・揺れるときは、たくさんの節が動く）
	if most < 0.0001 or (busy <= 3 and most < 0.0009):
		_calm += 1
		if _calm > 45:
			asleep = true
			old = pts.duplicate()
	else:
		_calm = 0
	_drawn = false


# 節 k から dir の側（-1＝根元の側 / 1＝先の側）へたどって、最初にある動かない節（ほかの手・結んだ端）。無ければ -1
func _fixed_past(k: int, dir: int, a_pin: bool, b_pin: bool) -> int:
	var n := pts.size()
	var best := -1
	for other: int in hands:
		if (other - k) * dir > 0 and other >= 0 and other < n and (best < 0 or absi(other - k) < absi(best - k)):
			best = other
	if best < 0:
		if dir < 0 and a_pin:
			best = 0
		elif dir > 0 and b_pin:
			best = n - 1
	return best


# 動かない節 lo と hi の間を、両側から順に引き寄せる（間が、決まった間隔より開いていたら、その分だけ寄せる）。
# たるんでいる分は、そのまま
func _span(lo: int, hi: int, tail: float) -> void:
	var n := pts.size()
	if hi - lo < 2:
		return
	for round_no in 3:
		for j in range(hi - 1, lo, -1):
			var rest := tail if j + 1 == n - 1 else SEG
			var d := pts[j] - pts[j + 1]
			var dist := d.length()
			if dist > rest:
				var to := pts[j + 1] + d * (rest / dist)
				old[j] += to - pts[j]
				pts[j] = to
				grip[j] = 0
		for j in range(lo + 1, hi):
			var d := pts[j] - pts[j - 1]
			var dist := d.length()
			if dist > SEG:
				var to := pts[j - 1] + d * (SEG / dist)
				old[j] += to - pts[j]
				pts[j] = to
				grip[j] = 0


# 節 k から端まで、順に引き寄せる（となりとの間が、決まった間隔より開いていたら、その分だけ寄せる）
func _trail(k: int, dir: int, tail: float) -> void:
	var n := pts.size()
	var prev := k
	var j := k + dir
	while j >= 0 and j < n:
		var rest := tail if maxi(prev, j) == n - 1 else SEG
		var d := pts[j] - pts[prev]
		var dist := d.length()
		if dist > rest:
			# 引き寄せた分は、勢いにしない（勢いにすると、ロープが手の先へ跳ね上がって暴れる）
			var to := pts[prev] + d * (rest / dist)
			old[j] += to - pts[j]
			pts[j] = to
			grip[j] = 0
		prev = j
		j += dir


# 節の速さ（m/秒）のいちばん大きい値。止まっていれば 0
func speed() -> float:
	if asleep:
		return 0.0
	var most := 0.0
	for i in pts.size():
		# つないである端は、つないだ物が動かしているので数えない
		if (i == 0 and a_body != null) or (i == pts.size() - 1 and b_body != null) or hands.has(i):
			continue
		most = maxf(most, pts[i].distance_to(old[i]))
	return most * 60.0


func _process(_delta: float) -> void:
	if not _drawn:
		_draw()
	if burning and not pts.is_empty():
		_spark.visible = true
		_spark.global_position = tip() + Vector3(0, 0.03, 0)
		_spark.scale = Vector3.ONE * randf_range(0.8, 1.35)
		_spark_light.light_energy = randf_range(2.0, 4.0)
		_sparks.emitting = true
	elif _spark.visible:
		_spark.visible = false
		_sparks.emitting = false


func _draw() -> void:
	_drawn = true
	if _mesh == null:
		return
	var mm := _mesh.multimesh
	var n := pts.size()
	if n < 2:
		mm.visible_instance_count = 0
		return
	if mm.instance_count < n - 1:
		mm.instance_count = mini(MAX_NODES, maxi(n - 1, mm.instance_count * 2))
	var shown := mini(n - 1, mm.instance_count)
	for i in shown:
		var a := pts[i]
		var b := pts[i + 1]
		var d := b - a
		var dist := d.length()
		var basis := Basis.IDENTITY
		if dist > 0.0001:
			basis = Basis(Quaternion(Vector3.UP, d / dist)) * Basis.from_scale(Vector3(1.0, dist + 0.008, 1.0))
		else:
			basis = Basis.from_scale(Vector3(1.0, 0.001, 1.0))
		mm.set_instance_transform(i, Transform3D(basis, (a + b) * 0.5))
	mm.visible_instance_count = shown

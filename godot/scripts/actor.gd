extends CharacterBody3D
# 合図で動く役者（NPC）。仕込み中は立ち位置の印の上で待つ。
# 役に入った人（stand_in：班のプレイヤーか等身大パネル。features/stand_ins.gd）がいる間は、姿を消してその人に付いていく。
# 判定・場面の進め方は、そのまま「役者」を見るので、役に入った人の位置と動きで数えることになる

const CastVisual := preload("res://scripts/cast_visual.gd")

# BEAT_〜 は、場面の列を持つ台本（production_beats.gd）だけが使う：印へ向かう / 着いて、その姿で待つ / 進めずに立ち止まった
enum St { STANDBY, IDLE, CONFESS, FLINCH, REUNION_MOVE, REUNION_HOLD, BEAT_GO, BEAT_HOLD, BEAT_STUCK }

const CONFESS_SEC := 6.0
const RUN_SPEED := 3.4
const WALK_SPEED := 1.9
const ARRIVE := 0.12          # 印に、ここまで近づいたら着いた
const STAND_ARRIVE := 0.75    # 役に入った人は、印からこの距離にいれば着いた（人の足で、ぴたりとは止まれない）
const STUCK_SEC := 0.45       # まっすぐ進めないまま、これだけ経ったら立ち止まる
const STEP_UP := 0.65         # 上の印へ向かう途中なら、この高さまでの段（箱・台・階段）には跳び乗る
const STUCK_PACE := 0.3       # 進む速さが、歩く・走る速さのこの割合より遅ければ「進めていない」
const GRAVITY := 16.0
const FACE_BY_STATE := {St.STANDBY: "neutral", St.IDLE: "neutral", St.CONFESS: "happy", St.FLINCH: "shock",
	St.REUNION_MOVE: "sad", St.REUNION_HOLD: "happy", St.BEAT_GO: "neutral", St.BEAT_HOLD: "neutral", St.BEAT_STUCK: "sad"}

var game: Node
var aid := 0
var label := ""
var vis: Node3D
var mark: Node3D
var partner: CharacterBody3D
var st := St.STANDBY
var st_t := 0.0
var after_flinch := St.IDLE
var special: Array = []       # 告白で使う固有モーション
# 骨格に重ねるポーズ（peep_pose.gd の "bow"・"hips"・"wave"・"point"・"cheer"・"duck"。"" ＝無し）。全員の画面へ、記録へも載る
var body_pose := ""
const BodyPose := preload("res://scripts/peep_pose.gd")
# 穴（"pit" の役の物）：飛び込む場面（beat の "dive"）では、穴の物を通り抜けて中へ跳び込む。しゃがむ（"duck"）と、穴の中へ沈む
const PIT_SHOW := 0.42        # 穴の中でしゃがんだとき、穴のふちから出る高さ（m）。頭と肩くらい
const ACTOR_W := 1.0          # 役者の体の幅（m）。穴の口より大きければ、その分だけ縮む
const DIVE_AT := 1.1          # 印まで、この距離になったら跳び込む
var _dove: Array = []         # 通り抜けている穴の物
var _dive_hop := false
var _layer_before := -1       # 穴の中でしゃがむ間は、ほかの物に当たらない（転がる大岩が上を通れる）。その前の値
# ぺちゃんこ：転がってきた重い物（大岩）に追いつかれると、平たくつぶれて、しばらくしてから、ぽんと戻る（漫画の理屈。けがはしない）。
# つぶれている間は body_pose が "flat"（全員の画面・見返しにも載る）。大岩はその上を転がっていく
const FLAT_SEC := 1.6
const FLAT_SPEED := 1.5       # これより速く転がっている物に
const FLAT_SPIN := 1.2
const FLAT_MASS := 3.0        # これより重い物に追いつかれると、つぶれる
var _flat_t := 0.0
# キャラごとのあいさつの動き（台本のポーズ "greet"）。無いキャラは、手を振る
const GREET := {"01": "GREETING", "02": "ON_DUTY", "03": "NOTES", "06": "ORDER"}
var playback := false

var _stuck := 0.0
var _net: Array = []
var _spec_i := 0
var _spec_t := 0.0
# 場面の列：いまの場面の動き（ホストが決める。production_beats.gd の _enter）
#   to＝行き先 / back＝やり直しのとき、先に戻る場所 / gait＝walk・run / pose＝着いてからの姿 /
#   look＝着いてから見る先 / face_go・face_hold＝動いている間と、着いてからの顔
var beat: Dictionary = {}
var _beat_leg := 1            # 0＝やり直しで、最初の印へ走って戻っている / 2＝戻って、相手が戻るのを待つ / 1＝その場面の動き
var _beat_dir := Vector3.FORWARD
var stand_in: Node3D = null   # 役に入っている人（プレイヤー）か等身大パネル
var _stand_speed := 0.0
# 誰がこの役を演じるか（features/stand_ins.gd が決める）："pro"＝雇ったベテラン / "rookie"＝劇団の新人 /
# "stand"＝班のプレイヤーか等身大パネル / "none"＝誰も演じない（姿も無い）
var grade := "pro"
var _rng := RandomNumberGenerator.new()
var _late := 0.0              # 新人：合図から動き出すまでの出遅れ
var _over := 0.0              # 新人：印を通り過ぎる距離
var _trip_at := -1.0          # 新人：残りがこの距離になったら、転ぶ
var _blank := 0.0             # 新人：せりふで固まっている残り


func setup(cast_tag: String, specials: Array) -> void:
	special = specials
	_rng.randomize()
	collision_layer = 8
	collision_mask = 1 | 2 | 4 | 8
	floor_snap_length = 0.2
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.3
	cap.height = 1.5
	cs.shape = cap
	cs.position = Vector3(0, 0.75, 0)
	add_child(cs)
	vis = CastVisual.new()
	add_child(vis)
	vis.setup(cast_tag)
	set_state(St.STANDBY)


func _kaiju() -> bool:
	return game != null and game.judge != null and game.judge.story == "kaiju"


# いちばん近い怪獣役の小道具（無ければ撮影カメラ）のほうを見る
func _monster_pos() -> Vector3:
	var best: Vector3 = game.film.global_position
	var best_d := INF
	for p: Node3D in game.props.values():
		if p.absent or game.judge.role_of(p) != "monster":
			continue
		var d := p.global_position.distance_to(global_position)
		if d < best_d:
			best_d = d
			best = p.global_position
	return best


func is_confessing() -> bool:
	return st == St.CONFESS


func head_pos() -> Vector3:
	return vis.head_pos()


func chest_pos() -> Vector3:
	return vis.chest_pos()


func set_state(s: St) -> void:
	if s != St.BEAT_HOLD and body_pose != "":
		set_body_pose("")
	if s == St.CONFESS and st != St.CONFESS and grade == "rookie" and _rng.randf() < 0.35:
		_blank = _rng.randf_range(1.5, 2.6)
	st = s
	# 待機中は印に付いて回るだけの幽霊にする（瞬間移動でセットを弾き飛ばさないため）
	collision_layer = 0 if s == St.STANDBY or stand_in != null else 8
	collision_mask = 0 if s == St.STANDBY or stand_in != null else 7     # 役者どうしは重なれる（頭の上に乗らないように）
	if s != St.BEAT_HOLD:
		_layer_before = -1          # 当たる層は、上で決め直した（穴の中でしゃがむ間の 0 は、もう無い）
	st_t = 0.0
	_stuck = 0.0
	_spec_i = 0
	_spec_t = 0.0
	vis.set_face(_face_for(s))


func _face_for(s: St) -> String:
	if s == St.CONFESS and _kaiju():
		return "surprised"
	if s == St.BEAT_GO:
		return str(beat.get("face_go", "neutral"))
	if s == St.BEAT_HOLD:
		return str(beat.get("face_hold", "neutral"))
	return FACE_BY_STATE[s]


func knock(impulse: Vector3) -> void:
	if st == St.STANDBY or stand_in != null:
		return
	if st in [St.BEAT_GO, St.BEAT_HOLD, St.BEAT_STUCK] or (st == St.FLINCH and after_flinch == St.BEAT_GO):
		# 場面の途中で吹き飛ばされた：起き上がったら、その場面の印へ向かい直す
		after_flinch = St.BEAT_GO
		_beat_leg = 1
	else:
		after_flinch = St.REUNION_MOVE if st in [St.REUNION_MOVE, St.REUNION_HOLD] else St.IDLE
	velocity = impulse
	set_state(St.FLINCH)
	vis.play("flinch", 0.08, true)


func _face(target: Vector3, delta: float) -> void:
	var d := target - global_position
	d.y = 0.0
	if d.length() > 0.05:
		rotation.y = lerp_angle(rotation.y, atan2(d.x, d.z), clampf(delta * 9.0, 0.0, 1.0))


func _physics_process(delta: float) -> void:
	_sink(delta)
	if playback:
		return
	if stand_in != null and not is_instance_valid(stand_in):
		set_stand_in(null)
	if grade == "none" and stand_in == null:
		# 誰も演じない役：舞台の外（地面の下）で待つ。判定には映らない
		if multiplayer.is_server():
			velocity = Vector3.ZERO
			global_position = Vector3(float(aid) * 3.0, -40.0, -40.0)
		return
	if stand_in != null:
		if multiplayer.is_server():
			_follow_stand_in(delta)
		else:
			_follow_net(delta)
		return
	if not multiplayer.is_server():
		_follow_net(delta)
		return
	if _flat_t > 0.0:
		_flat_t -= delta
		velocity.x = 0.0
		velocity.z = 0.0
		_fall(delta, 12.0)
		if _flat_t <= 0.0:
			_unflat()
		return
	if _rolled_over():
		return
	st_t += delta
	match st:
		St.STANDBY:
			velocity = Vector3.ZERO
			global_position = mark.global_position + Vector3(0, 0.04, 0)
			_face(partner.global_position, delta)
			vis.play("idle")
		St.IDLE:
			_fall(delta, 10.0)
			_face(partner.global_position, delta)
			vis.play("idle")
		St.CONFESS when _blank > 0.0:
			# 新人：せりふで固まる（しばらく、ぽかんと立っているだけ）
			_blank -= delta
			_fall(delta, 10.0)
			vis.play("idle")
			vis.set_face("surprised")
		St.CONFESS:
			# 怪獣映画では同じ合図で「怪獣を見上げて驚く」芝居になる
			var acts: Array = ["flinch", "jump"] if _kaiju() else special
			_fall(delta, 10.0)
			_face(_monster_pos() if _kaiju() else partner.global_position, delta)
			_spec_t -= delta
			if _spec_t <= 0.0 and not acts.is_empty():
				var a: String = acts[_spec_i % acts.size()]
				_spec_i += 1
				_spec_t = vis.length(a) + 0.25
				vis.play(a, 0.15, true)
			if st_t >= CONFESS_SEC:
				set_state(St.IDLE)
		St.FLINCH:
			_fall(delta, 2.5)
			if st_t >= 1.1 and is_on_floor():
				set_state(after_flinch)
		St.REUNION_MOVE:
			_reunion_move(delta)
		St.REUNION_HOLD:
			# 重なって着地したら、手を取れる距離まで離れる
			var sep := global_position - partner.global_position
			sep.y = 0.0
			if sep.length() < 0.8 and is_on_floor():
				var away := sep.normalized() if sep.length() > 0.02 else Vector3(1.0 if aid == 0 else -1.0, 0, 0)
				velocity.x = away.x * 1.6
				velocity.z = away.z * 1.6
			_fall(delta, 12.0)
			_face(partner.global_position, delta)
			if st_t < vis.length("grab"):
				vis.play("grab", 0.15)
			else:
				vis.play("idle")
		St.BEAT_GO:
			_beat_go(delta)
		St.BEAT_HOLD:
			_beat_hold(delta)
		St.BEAT_STUCK:
			# 進めなかった：その場で立ち止まって、困った顔をする（次の合図を待つ）
			_fall(delta, 12.0)
			_face(global_position + _beat_dir, delta)
			if st_t >= vis.length("brake"):
				vis.play("idle")


func _fall(delta: float, friction: float) -> void:
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	var k := clampf(friction * delta, 0.0, 1.0)
	velocity.x = lerpf(velocity.x, 0.0, k)
	velocity.z = lerpf(velocity.z, 0.0, k)
	move_and_slide()


func _reunion_move(delta: float) -> void:
	var d := partner.global_position - global_position
	var dy := absf(d.y)
	d.y = 0.0
	var dist := d.length()
	if dist < 1.0 and dy < 0.5 and is_on_floor():
		set_state(St.REUNION_HOLD)
		if partner.st == St.REUNION_MOVE:
			partner.set_state(St.REUNION_HOLD)
		return
	# 相手が高い所にいて近いなら、下の役者はその場で待つ（上の役者が降りてくる）
	if dist < 1.0 and partner.global_position.y > global_position.y + 0.4:
		_fall(delta, 12.0)
		_face(partner.global_position, delta)
		vis.play("idle")
		return
	var before := global_position
	var dir := d.normalized() if dist > 0.05 else global_basis.z
	velocity.x = dir.x * RUN_SPEED
	velocity.z = dir.z * RUN_SPEED
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	move_and_slide()
	_face(partner.global_position, delta)
	vis.play("run" if is_on_floor() else "jump")
	# 手すりや小道具に引っかかったら跳び越える
	var moved := (global_position - before).length() / maxf(delta, 0.0001)
	if is_on_floor() and moved < 0.6:
		_stuck += delta
		if _stuck > 0.35:
			velocity.y = 7.0
			_stuck = 0.0
	else:
		_stuck = 0.0


# ---- 場面の列（production_beats.gd）：印から印へ、まっすぐ動く ----

# その場面の動きを始める（ホスト）。吹き飛ばされている最中なら、起き上がってから向かう
func play_beat(spec: Dictionary) -> void:
	_leave_pit()
	beat = spec
	_beat_leg = 0 if spec.has("back") else 1
	_rookie_beat()
	if st == St.FLINCH:
		after_flinch = St.BEAT_GO
		return
	set_state(St.BEAT_GO)


# その場面の動きで、歩いている（走っている）最中か。やり直しで印へ戻っている間は数えない
func beat_walking() -> bool:
	if stand_in != null:
		return st == St.BEAT_GO and _beat_leg == 1 and _stand_speed > 0.5
	return st == St.BEAT_GO and _beat_leg == 1 and Vector2(velocity.x, velocity.z).length() > 0.5


# その場面の印に着いて、決まった姿で待っているか
func beat_arrived() -> bool:
	return st == St.BEAT_HOLD


# この役を、いま誰かが演じているか（雇った役者・班の人・等身大パネル）。誰も演じない役は、舞台の外で待っている
func present() -> bool:
	return grade != "none" or stand_in != null


# 物にぶつかって進めず、立ち止まっているか
func beat_stuck() -> bool:
	return st == St.BEAT_STUCK and stand_in == null


# ---- 役に入った人（班のプレイヤー・等身大パネル）に付いていく ----

# 誰がこの役を演じるかを決める（全員の画面。features/stand_ins.gd）
func set_grade(g: String) -> void:
	grade = g
	vis.visible = stand_in == null and g != "none"
	if g == "none":
		collision_layer = 0
		collision_mask = 0
	elif stand_in == null:
		set_state(st)


# 新人のハプニングを、その場面の動きごとに決める（ホスト）。ベテランは何も起きない
func _rookie_beat() -> void:
	_late = 0.0
	_over = 0.0
	_trip_at = -1.0
	if grade != "rookie" or beat.has("back"):
		return
	if _rng.randf() < 0.45:
		_late = _rng.randf_range(0.5, 1.4)
	if _rng.randf() < 0.4:
		_over = _rng.randf_range(0.7, 1.4)
	if _rng.randf() < 0.2:
		_trip_at = _rng.randf_range(0.8, 1.6)


# 役に入った人を決める（全員の画面。features/stand_ins.gd）。null で、NPC の役者に戻る
func set_stand_in(n: Node3D) -> void:
	stand_in = n
	vis.visible = n == null and grade != "none"
	_stand_speed = 0.0
	if n != null:
		collision_layer = 0
		collision_mask = 0
		velocity = Vector3.ZERO
	else:
		set_state(st)


# 役に入った人の位置と向きに重なり、場面の印に着いたか・歩いているかを、その人の動きで決める（ホスト）
func _follow_stand_in(delta: float) -> void:
	var p: Vector3 = stand_in.global_position
	var step := Vector2(p.x - global_position.x, p.z - global_position.z).length()
	_stand_speed = lerpf(_stand_speed, step / maxf(delta, 0.0001), clampf(delta * 8.0, 0.0, 1.0))
	global_position = p
	velocity = Vector3.ZERO
	var body: Variant = stand_in.get("vis")
	rotation.y = (body as Node3D).global_rotation.y if body is Node3D else stand_in.global_rotation.y
	st_t += delta
	match st:
		St.BEAT_GO:
			var target: Vector3 = beat.get("back" if _beat_leg == 0 else "to", p)
			if Vector2(target.x - p.x, target.z - p.z).length() < STAND_ARRIVE:
				if _beat_leg == 0:
					_beat_leg = 1          # やり直し：最初の印へ戻った。そのまま演じ直す
				else:
					set_state(St.BEAT_HOLD)
		St.BEAT_HOLD:
			var spot: Vector3 = beat.get("to", p)
			if Vector2(spot.x - p.x, spot.z - p.z).length() > STAND_ARRIVE * 1.8:
				set_state(St.BEAT_GO)      # 印から離れた
		St.CONFESS:
			if st_t >= CONFESS_SEC:
				set_state(St.IDLE)
		St.FLINCH, St.BEAT_STUCK, St.REUNION_MOVE, St.REUNION_HOLD:
			set_state(St.BEAT_GO if not beat.is_empty() else St.IDLE)


func _beat_go(delta: float) -> void:
	if _beat_leg == 2:
		# 最初の印で、相手が戻るのを待つ。そろったら、二人で演じ直す
		_fall(delta, 12.0)
		vis.play("idle")
		if not partner.present() or partner.st != St.BEAT_GO or partner._beat_leg != 0:
			_beat_leg = 1
		return
	if _late > 0.0 and _beat_leg == 1:
		# 新人：合図に出遅れる
		_late -= delta
		_fall(delta, 12.0)
		vis.play("idle")
		return
	var target: Vector3 = beat.get("back" if _beat_leg == 0 else "to", global_position)
	if _over > 0.0 and _beat_leg == 1:
		# 新人：印を通り過ぎて止まる
		var run_dir := target - global_position
		run_dir.y = 0.0
		if run_dir.length() > 0.05:
			target += run_dir.normalized() * _over
	var d := target - global_position
	d.y = 0.0
	var dist := d.length()
	if _trip_at > 0.0 and _beat_leg == 1 and dist < _trip_at:
		# 新人：途中で転ぶ（起き上がってから、また向かう）
		_trip_at = -1.0
		knock(Vector3(d.x, 0.0, d.z).normalized() * 2.2 + Vector3(0, 1.5, 0))
		return
	if dist < ARRIVE:
		velocity.x = 0.0
		velocity.z = 0.0
		_stuck = 0.0
		if _beat_leg == 0:
			_beat_leg = 2          # 最初の印へ戻った。相手を待って、もう一度演じる
			return
		set_state(St.BEAT_HOLD)
		return
	if _beat_leg == 1 and beat.get("dive", false):
		_dive(dist, d / dist)
	var gait: String = "run" if _beat_leg == 0 else str(beat.get("gait", "walk"))
	var speed: float = RUN_SPEED if gait == "run" else WALK_SPEED
	var dir := d / dist
	_beat_dir = dir
	var before := global_position
	var pace := minf(speed, dist / maxf(delta, 0.0001))
	velocity.x = dir.x * pace
	velocity.z = dir.z * pace
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	move_and_slide()
	_face(global_position + dir, delta)
	vis.play(gait if is_on_floor() or st_t < 0.2 else "jump")
	# まっすぐ進めない（物や壁に当たった）：その場で立ち止まる。よけない・跳び越えない・すり抜けない。
	# ただし、印が今より高い所にあって、前が低い段（STEP_UP まで）なら、跳び乗る（階段・台・箱を上る。名場面の舳先・頂上）
	var progress := (global_position - before).dot(dir) / maxf(delta, 0.0001)
	if is_on_floor() and progress < pace * STUCK_PACE and target.y > global_position.y + 0.2 and _hop_up(dir):
		_stuck = 0.0
		return
	if is_on_floor() and progress < pace * STUCK_PACE:
		_stuck += delta
		if _stuck > STUCK_SEC:
			velocity = Vector3.ZERO
			set_state(St.BEAT_STUCK)
			vis.play("brake", 0.08, true)
	else:
		_stuck = 0.0


# 前の段の上に、跳び乗る。段の上が STEP_UP より高い・段が無いなら、何もしない（false）
func _hop_up(dir: Vector3) -> bool:
	var space := get_world_3d().direct_space_state
	var ahead := global_position + dir * 0.45
	var q := PhysicsRayQueryParameters3D.create(ahead + Vector3(0, STEP_UP + 0.1, 0), ahead + Vector3(0, 0.05, 0), 1 | 2)
	q.exclude = [get_rid()]
	var hit := space.intersect_ray(q)
	if hit.is_empty():
		return false
	var rise: float = (hit["position"] as Vector3).y - global_position.y
	if rise < 0.12 or rise > STEP_UP:
		return false
	velocity.y = sqrt(2.0 * GRAVITY * (rise + 0.2))
	velocity.x = dir.x * WALK_SPEED
	velocity.z = dir.z * WALK_SPEED
	move_and_slide()
	return true


func _beat_hold(delta: float) -> void:
	_fall(delta, 12.0)
	match str(beat.get("look", "")):
		"monster":
			_face(_monster_pos(), delta)
		"camera":
			_face((game.program_camera() as Node3D).global_position, delta)
		"partner":
			_face(partner.global_position, delta)
	var pose := str(beat.get("pose", "idle"))
	set_body_pose(pose if pose in ["bow", "hips", "wave", "point", "cheer", "duck"] else ("wave" if pose == "greet" and not GREET.has(vis.tag) else ""))
	# 穴の中でしゃがんでいる間は、ほかの物に当たらない（大岩が頭の上を転がっていける）。床には立つ
	if pose == "duck" and in_pit() != null and _layer_before < 0:
		_layer_before = collision_layer
		collision_layer = 0
	match pose:
		"greet":
			# あいさつ：キャラの決めの動きを、くり返す
			if GREET.has(vis.tag):
				_spec_t -= delta
				if _spec_t <= 0.0:
					_spec_t = vis.length(str(GREET[vis.tag])) + 0.4
					vis.play(str(GREET[vis.tag]), 0.15, true)
			else:
				vis.play("idle")
		"freeze":
			# 見上げて、びくっとして固まる（1回だけ）
			if st_t < vis.length("flinch"):
				vis.play("flinch", 0.1)
			else:
				vis.play("idle")
		"cheer":
			# 万歳：跳ねて喜ぶ
			_spec_t -= delta
			if _spec_t <= 0.0:
				_spec_t = vis.length("jump") + 0.15
				vis.play("jump", 0.12, true)
		_:
			vis.play("idle")


# ---- 同期と記録 ----

func get_state() -> Array:
	return [global_position, rotation.y, vis.current, vis.face, body_pose]


func apply_state(s: Array, immediate: bool = false) -> void:
	if immediate:
		global_position = s[0]
		rotation.y = s[1]
		vis.play(s[2] as String, 0.12)
		vis.set_face(s[3] as String)
		set_body_pose(str(s[4]) if s.size() > 4 else "")
	else:
		_net = s


# いま入っている穴の物（"pit" の役。足もとが、その物の外形の内側）。無ければ null
func in_pit() -> Node3D:
	var flow: Node = game.production if game != null else null
	if flow == null:
		return null
	for pid: int in flow.casting:
		if str(flow.casting[pid]) != "pit":
			continue
		var p: Node3D = game.props.get(pid)
		if p == null or p.absent:
			continue
		var box := pit_box(p)
		var at := global_position
		if at.x > box.position.x - 0.15 and at.x < box.end.x + 0.15 and at.z > box.position.z - 0.15 and at.z < box.end.z + 0.15 and at.y > box.position.y - 0.6 and at.y < box.end.y + 0.6:
			return p
	return null


# 穴の物の、世界の向きでの外形（寝かせた板・傾いた箱でも、上から見た広さと、ふちの高さが分かる）
static func pit_box(p: Node3D) -> AABB:
	var b: Basis = p.global_basis
	var h: Vector3 = p.half
	var ext := Vector3(
		absf(b.x.x) * h.x + absf(b.y.x) * h.y + absf(b.z.x) * h.z,
		absf(b.x.y) * h.x + absf(b.y.y) * h.y + absf(b.z.y) * h.z,
		absf(b.x.z) * h.x + absf(b.y.z) * h.y + absf(b.z.z) * h.z)
	return AABB(p.center_global() - ext, ext * 2.0)


# つぶれているか（全員の画面で分かる）
func is_flat() -> bool:
	return body_pose == "flat"


# 転がってくる大岩に追いつかれたら、ぺちゃんこになる（ホスト）。穴の中でしゃがんでいれば、上を通っていくだけ
func _rolled_over() -> bool:
	if st == St.STANDBY or (body_pose == "duck" and in_pit() != null):
		return false
	var me := global_position
	for p: Node3D in game.props.values():
		if p.absent or p.holder != 0 or p.mass < FLAT_MASS:
			continue
		# 大岩だけ（張りぼての大岩と、大岩に見立てた物）。倒れる怪獣などでは、つぶれない
		if p.kind != "boulder" and (game.production == null or game.production.role_of(p) != "bigrock"):
			continue
		var v: Vector3 = p.linear_velocity
		var flat_v := Vector3(v.x, 0.0, v.z)
		if flat_v.length() < FLAT_SPEED or p.angular_velocity.length() < FLAT_SPIN:
			continue
		var c: Vector3 = p.center_global()
		var to_me := Vector3(me.x - c.x, 0.0, me.z - c.z)
		var r: float = maxf(p.half.x, maxf(p.half.y, p.half.z))
		if to_me.length() > r + 0.3 or flat_v.dot(to_me) <= 0.0 or c.y - r > me.y + 1.0:
			continue
		_flat_t = FLAT_SEC
		set_body_pose("flat")
		collision_layer = 0
		velocity = Vector3.ZERO
		vis.play("flinch", 0.05, true)
		game.host_ev("sfx", ["land", me])
		return true
	return false


# ぽんと戻る（ホスト）：当たる層を戻して、さっきの続きをする
func _unflat() -> void:
	set_body_pose("")
	set_state(st)
	game.host_ev("sfx", ["whoosh_soft", global_position])


# 穴へ跳び込む（ホスト）：印に近づいたら、近くの穴の物を通り抜けられるようにして、ひと跳び
func _dive(dist: float, dir: Vector3) -> void:
	if dist > DIVE_AT * 1.8:
		return
	var flow: Node = game.production
	var target: Vector3 = beat.get("to", global_position)
	for pid: int in flow.casting:
		var p: Node3D = game.props.get(pid)
		if str(flow.casting[pid]) != "pit" or p == null or p.absent or p in _dove:
			continue
		if Vector2(p.global_position.x - target.x, p.global_position.z - target.z).length() < maxf(p.half.x, p.half.z) + 0.6:
			add_collision_exception_with(p)
			_dove.append(p)
	if not _dive_hop and dist < DIVE_AT and is_on_floor() and not _dove.is_empty():
		_dive_hop = true
		velocity.y = 4.2
		velocity.x = dir.x * RUN_SPEED
		velocity.z = dir.z * RUN_SPEED
		vis.play("jump", 0.08, true)


# 穴から出る：通り抜けを戻し、当たる層を戻す
func _leave_pit() -> void:
	for p: Variant in _dove:
		if is_instance_valid(p):
			remove_collision_exception_with(p)
	_dove.clear()
	_dive_hop = false
	if _layer_before >= 0:
		collision_layer = _layer_before
		_layer_before = -1


# 穴の中でしゃがむと、見た目を沈める（全員の画面。しゃがむかどうかは body_pose で届く。見返しも同じ）
# 穴の中でしゃがむと、頭と肩だけが穴のふちから出る高さへ、見た目を下げる（全員の画面。しゃがむかどうかは body_pose で届く。見返しも同じ）。
# 入れ物（バスタブ・箱）なら、ふちから頭が出る。平たい物（絵に描いた穴）なら、床の下へ沈んで頭だけ出る（アニメの「持ち運べる穴」）
func _sink(delta: float) -> void:
	if vis == null:
		return
	if body_pose == "flat":
		# ぺちゃんこ：床に貼りつくように、平たく広がる
		vis.position.y = 0.0
		vis.scale = vis.scale.move_toward(Vector3(1.45, 0.12, 1.45), delta * 14.0)
		return
	var want := 0.0
	var size := 1.0
	var pit: Node3D = in_pit() if body_pose == "duck" else null
	if pit != null:
		size = _pit_fit(pit)
		var box := pit_box(pit)
		var rim: float = box.end.y
		var tall: float = ((vis.head_pos().y - vis.global_position.y) / maxf(vis.scale.y, 0.01) + 0.15) * size
		want = minf(rim - global_position.y + PIT_SHOW * size - tall, 0.0)
		if box.size.y > 0.25:
			# 入れ物：中の底（ふちから、高さの4分の3ほど下）より下へは沈めない（脚のある入れ物の下から、体が見えないように）
			want = maxf(want, rim - box.size.y * 0.75 - global_position.y)
	vis.position.y = move_toward(vis.position.y, want, delta * 4.0)
	vis.scale = vis.scale.move_toward(Vector3.ONE * size, delta * (6.0 if vis.scale.y < 0.5 else 2.5))      # つぶれた後は、ぽんと早く戻る


# 穴の口に収まる大きさ（1 ＝そのまま）。同じ穴に入っている人数で、長いほうの辺を分け合う。小さい穴ほど、身を縮める（漫画の理屈）
func _pit_fit(pit: Node3D) -> float:
	var n := 0
	for a: Node in game.actors:
		if a.present() and a.body_pose == "duck" and a.in_pit() == pit:
			n += 1
	var box := pit_box(pit)
	var short: float = minf(box.size.x, box.size.z) * 0.9
	var long: float = maxf(box.size.x, box.size.z) * 0.9 / float(maxi(n, 1))
	return clampf(minf(short, long) / ACTOR_W, 0.5, 1.0)


# 骨格に重ねるポーズを付ける・外す（"" で外す）
func set_body_pose(mode: String) -> void:
	if mode == body_pose:
		return
	body_pose = mode
	var skel: Skeleton3D = vis.skel if vis != null else null
	if skel == null:
		return
	var node: Node = skel.get_node_or_null("BeatPose")
	if mode == "":
		if node != null:
			skel.remove_child(node)
			node.queue_free()
		return
	if node == null:
		node = BodyPose.new()
		node.name = "BeatPose"
		skel.add_child(node)
	node.mode = mode
	node.lean = 0.7 if mode == "bow" else 0.0


func _follow_net(delta: float) -> void:
	if _net.is_empty():
		return
	var w := clampf(delta * 14.0, 0.0, 1.0)
	global_position = global_position.lerp(_net[0] as Vector3, w)
	rotation.y = lerp_angle(rotation.y, _net[1] as float, w)
	vis.play(_net[2] as String, 0.12)
	vis.set_face(_net[3] as String)

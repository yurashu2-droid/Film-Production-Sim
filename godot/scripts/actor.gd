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
	if s == St.CONFESS and st != St.CONFESS and grade == "rookie" and _rng.randf() < 0.35:
		_blank = _rng.randf_range(1.5, 2.6)
	st = s
	# 待機中は印に付いて回るだけの幽霊にする（瞬間移動でセットを弾き飛ばさないため）
	collision_layer = 0 if s == St.STANDBY or stand_in != null else 8
	collision_mask = 0 if s == St.STANDBY or stand_in != null else 7     # 役者どうしは重なれる（頭の上に乗らないように）
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
		if partner.st != St.BEAT_GO or partner._beat_leg != 0:
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
	# まっすぐ進めない（物や壁に当たった）：その場で立ち止まる。よけない・跳び越えない・すり抜けない
	var progress := (global_position - before).dot(dir) / maxf(delta, 0.0001)
	if is_on_floor() and progress < pace * STUCK_PACE:
		_stuck += delta
		if _stuck > STUCK_SEC:
			velocity = Vector3.ZERO
			set_state(St.BEAT_STUCK)
			vis.play("brake", 0.08, true)
	else:
		_stuck = 0.0


func _beat_hold(delta: float) -> void:
	_fall(delta, 12.0)
	match str(beat.get("look", "")):
		"monster":
			_face(_monster_pos(), delta)
		"camera":
			_face((game.program_camera() as Node3D).global_position, delta)
		"partner":
			_face(partner.global_position, delta)
	match str(beat.get("pose", "idle")):
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
	return [global_position, rotation.y, vis.current, vis.face]


func apply_state(s: Array, immediate: bool = false) -> void:
	if immediate:
		global_position = s[0]
		rotation.y = s[1]
		vis.play(s[2] as String, 0.12)
		vis.set_face(s[3] as String)
	else:
		_net = s


func _follow_net(delta: float) -> void:
	if _net.is_empty():
		return
	var w := clampf(delta * 14.0, 0.0, 1.0)
	global_position = global_position.lerp(_net[0] as Vector3, w)
	rotation.y = lerp_angle(rotation.y, _net[1] as float, w)
	vis.play(_net[2] as String, 0.12)
	vis.set_face(_net[3] as String)

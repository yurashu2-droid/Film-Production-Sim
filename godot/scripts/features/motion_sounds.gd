extends Node
## 体と物の動きの音：足音・着地・風切り。
## 参考にしたゲーム映像（一人称で棒を持って走り回る）の音を測って合わせた（音の作り方は assets/audio/README.md）。
## どれも各自の画面で、見えている動きから決めて鳴らす（通信は増やさない。ほかの人の足音・振った物の音も聞こえる）。
##   足音＝歩く・走る足が地面に着いた瞬間（左右の足のどちらが低いかが入れ替わった時）
##   着地＝跳んで降りた時
##   風切り＝物が急に速く動いた時（振る・持ったまま振り向く・投げる・吹き飛ぶ）。落ちる・倒れる・転がるだけでは鳴らさない
##   車輪のロボット（M02）＝足音の代わりに、走っている間ずっと車輪とモーターの音。速さで音量と高さが変わる。
##     着地は「ガタッ」で、モーターの音が一瞬止まって、うなりながら戻る
# 足音を鳴らす動き → 音量（dB）。走るほど大きく、しゃがみ歩きは小さく。
# 参考の映像（足音は振りより約20dB小さい）に合わせて下げたら、遊んでみて「小さくしなくてよかった」（2026-10-15）。
# その後、ロボットの音と比べて「人の音は倍くらいでいい」となり、+6dB（音の振れ幅で2倍）にした（2026-10-17）
const STEP_CLIPS := {"walk": -9.0, "run": -3.0, "crouch_walk": -18.0, "run_start": -4.0, "run_stop": -2.0, "step_down": -4.0}
const LAND_DB := Vector2(-3.0, 3.0)    # 人の着地の音量（宙にいた時間が短い〜長い）。足音と同じく+6dB
# ロボットの音（走る音・着地）は、聞こえの大きさを人とそろえても、鳴りっぱなしの機械の音なので大きく聞こえた。
# 「3分の1くらいでいい」となり、−9.5dB（音の振れ幅で1/3）にした（2026-10-17）
const ROBOT_TRIM := -9.5
const STEP_SWAP := 0.006       # 左右の足の高さの差（m）が、これを超えて入れ替わったら1歩
const STEP_GAP := 0.14         # 1人の足音どうしの最短の間（秒）
const LAND_AIR := 0.3          # これより長く宙にいたら、降りた時に着地の音
const SWISH_ON := 7.0          # 物のいちばん速い所（m/秒）がこれを超えたら鳴らす
const SWISH_SHARP := 14.0      # これより速いと「ブンッ」。遅ければ低い風（振り向いた時など）
const SWISH_JUMP := 4.0        # 0.15秒前より、これだけ速くなっていること（落ちる・車で運ばれるだけの物では鳴らさない）
const SWISH_REARM := 3.5       # 一度鳴ったら、これより遅くなるまで鳴らさない（回し続けても鳴りっぱなしにしない）
const SWISH_WARP := 30.0       # 1コマでこれより速く動いたのは、置き直し（鳴らさない）
const SWISH_TURN_WARP := 1.2   # 1コマで、これ（ラジアン）より回ったのも置き直し
const SWISH_GRAB := 0.35       # 持った直後は手へ寄っていく動きなので、この秒数は鳴らさない
const SWISH_MAX := 3           # 0.25秒の間に鳴らす風切りの数の上限（爆発で物がいっせいに飛んでも、うるさくしない）
# 車輪のロボットが走る速さ（5.8m/秒）の時の、車輪とモーターの音量。人の足音と同じ聞こえの大きさに合わせた
# （耳の感じ方の重みで測って、走る人と全速、歩く人と歩く速さが、それぞれ同じくらい。2026-10-17）
const ROLL_DB := -18.5 + ROBOT_TRIM
const ROLL_CURVE := 30.0       # 速さの割合 k のとき、音量は ROLL_DB + ROLL_CURVE×log10(k)（人の歩き・走りの差と同じ7dBほどの差）
const ROLL_FULL := 5.8         # この速さで、いちばん大きく・高くなる
const ROLL_STALL := 0.12       # 着地でモーターが止まっている秒
const ROLL_RECOVER := 0.3      # そこから、低くうなりながら元へ戻る秒
const ROLL_PITCH := {"robot_tire": Vector2(0.8, 1.1), "robot_motor": Vector2(0.85, 1.15)}   # 止まりかけ〜全速の高さ

var game: Node
var steps := 0                 # 鳴らした数（確認用）
var lands := 0
var swishes := 0
var _feet := {}                # 人 → [どちらの足が低いか(-1=左/0=まだ/1=右), 最後の足音からの秒, 宙にいる秒]
var _props := {}               # 物のID → [位置, 向き, 速さの記録 [Vector2(時刻, 速さ)...], 鳴らせるか, 半径, 持っている人, 持った時刻]
var _recent: Array[float] = []
var _rolls := {}               # 人 → [前の位置, なめらかにした速さ, 車輪の音, モーターの音, 着地してからの秒]
var _clock := 0.0


func _physics_process(delta: float) -> void:
	if game == null or delta <= 0.0:
		return
	_clock += delta
	for pl: Node in game.players.values():
		if is_instance_valid(pl) and pl.get("vis") != null:
			_step_sounds(pl, delta)
	_swish_sounds(delta)


# ---- 足音・着地 ----

func _step_sounds(pl: Node, delta: float) -> void:
	var st: Array = _feet.get(pl, [0, 1.0, 0.0])
	st[1] += delta
	_feet[pl] = st
	var vis: Node3D = pl.vis
	var robot: bool = vis.tag == "M02"
	var base: String = vis.current.trim_prefix("carry_").trim_prefix("onehand_")
	if robot:
		_roll_sound(pl, delta, not pl.vehicle_riding(), base != "jump")
	if pl.vehicle_riding():
		st[0] = 0                  # 車に乗っている人は、足音なし
		st[2] = 0.0
		return
	if base == "jump":
		st[2] += delta
		st[0] = 0
		return
	if st[2] >= LAND_AIR:
		lands += 1
		var land_db := lerpf(LAND_DB.x, LAND_DB.y, clampf((st[2] - LAND_AIR) / 0.6, 0.0, 1.0))
		if robot and Sfx.has_sound("robot_land"):
			Sfx.play("robot_land", pl.global_position, land_db + ROBOT_TRIM)
			if _rolls.has(pl):
				_rolls[pl][4] = 0.0
		else:
			Sfx.play("land", pl.global_position, land_db)
		st[1] = 0.0
	st[2] = 0.0
	if robot or not STEP_CLIPS.has(base):
		st[0] = 0
		return
	var left: Vector3 = vis.foot_position("L")
	var right: Vector3 = vis.foot_position("R")
	var d := left.y - right.y
	var side := -1 if d < -STEP_SWAP else (1 if d > STEP_SWAP else 0)
	if side == 0 or side == st[0]:
		return
	# 歩き出しの最初の入れ替わりは、足を上げただけなので鳴らさない
	if st[0] != 0 and st[1] >= STEP_GAP:
		steps += 1
		Sfx.play("step", left if side < 0 else right, STEP_CLIPS[base])
		st[1] = 0.0
	st[0] = side


# ---- 車輪のロボットが走る音 ----

# 車輪とモーターの音を、体に付けてくり返し鳴らす。速さ（位置の動きから測る。ほかの人のロボットも同じ）で音量と高さを変える。
# 宙にいる間は、車輪の音だけ止める
func _roll_sound(pl: Node3D, delta: float, active: bool, grounded: bool) -> void:
	var r: Array = _rolls.get(pl, [])
	if r.is_empty() or not is_instance_valid(r[2]):
		if not Sfx.has_sound("robot_tire") or not Sfx.has_sound("robot_motor"):
			return
		r = [pl.global_position, 0.0, _loop_player(pl, "robot_tire"), _loop_player(pl, "robot_motor"), 99.0]
		_rolls[pl] = r
	var pos: Vector3 = pl.global_position
	var speed := Vector2(pos.x - (r[0] as Vector3).x, pos.z - (r[0] as Vector3).z).length() / delta
	r[0] = pos
	if speed > 20.0 or not active:
		speed = 0.0                # 置き直し・車に乗っている間は鳴らさない
	r[1] = lerpf(r[1], speed, clampf(delta * 8.0, 0.0, 1.0))
	var k := clampf(float(r[1]) / ROLL_FULL, 0.0, 1.0)
	# 着地の直後は、モーターが一瞬止まり、低くうなりながら戻る
	r[4] += delta
	var stall: float = r[4]
	var revive := clampf((stall - ROLL_STALL) / ROLL_RECOVER, 0.0, 1.0)
	for i in 2:
		var p: AudioStreamPlayer3D = r[2 + i]
		var on := k > 0.05 and not Sfx.muted and (grounded or i == 1)
		if not on:
			if p.playing:
				p.stop()
			continue
		var span: Vector2 = ROLL_PITCH[p.name]
		p.volume_db = ROLL_DB + ROLL_CURVE * log(k) / log(10.0)
		p.pitch_scale = lerpf(span.x, span.y, k)
		if i == 1 and revive < 1.0:
			p.volume_db += linear_to_db(maxf(revive, 0.001))
			p.pitch_scale *= lerpf(0.7, 1.0, revive)
		if not p.playing:
			p.play(randf() * p.stream.get_length())


func _loop_player(pl: Node3D, sound: String) -> AudioStreamPlayer3D:
	var p := AudioStreamPlayer3D.new()
	p.name = sound
	p.stream = Sfx.get_stream(sound)
	p.unit_size = 8.0
	p.max_distance = 60.0
	p.position = Vector3(0, 0.3, 0)
	pl.add_child(p)
	return p


# ---- 風切り ----

func _swish_sounds(delta: float) -> void:
	while not _recent.is_empty() and _clock - _recent[0] > 0.25:
		_recent.pop_front()
	for id: int in game.props:
		var p: Node3D = game.props[id]
		if not is_instance_valid(p) or p.absent or p.stored_in != 0 or p.immovable:
			_props.erase(id)
			continue
		var pos := p.global_position
		var q := p.global_basis.get_rotation_quaternion()
		var st: Array = _props.get(id, [])
		if st.is_empty():
			_props[id] = [pos, q, [], true, _radius(p), p.holder, -1.0]
			continue
		var lin: float = pos.distance_to(st[0]) / delta
		var turn: float = (st[1] as Quaternion).angle_to(q)
		st[0] = pos
		st[1] = q
		var hist: Array = st[2]
		if lin > SWISH_WARP or turn > SWISH_TURN_WARP:
			hist.clear()
			continue
		if p.holder != st[5]:
			st[5] = p.holder
			if p.holder != 0:
				st[6] = _clock
		# 回る速さは、持っている物だけ足す（振る・右ドラッグで回す）。手を離れた物が倒れる・転がる回転では鳴らさない
		var speed: float = lin + (turn / delta * st[4] if p.holder != 0 else 0.0)
		var before: float = (hist.back() as Vector2).y if not hist.is_empty() else 0.0
		hist.append(Vector2(_clock, speed))
		while hist.size() > 1 and _clock - (hist[0] as Vector2).x > 0.15:
			hist.pop_front()
		if not st[3]:
			st[3] = speed < SWISH_REARM
			continue
		# 2コマ続けて速いこと（置き直しの瞬間移動は1コマだけ速い）
		if speed < SWISH_ON or before < SWISH_ON * 0.6 or _clock - st[6] < SWISH_GRAB or _recent.size() >= SWISH_MAX:
			continue
		var slow := speed
		for h: Vector2 in hist:
			slow = minf(slow, h.y)
		if speed - slow < SWISH_JUMP:
			continue
		st[3] = false
		_recent.append(_clock)
		swishes += 1
		# 小さい物は小さく
		var small := -4.0 if st[4] < 0.2 else 0.0
		if speed >= SWISH_SHARP:
			Sfx.play("whoosh", pos, lerpf(-6.0, 0.0, clampf((speed - SWISH_SHARP) / 12.0, 0.0, 1.0)) + small)
		else:
			Sfx.play("whoosh_soft", pos, lerpf(-16.0, -9.0, (speed - SWISH_ON) / (SWISH_SHARP - SWISH_ON)) + small)


# 物の中心から端までの長さ（回った時の、端の速さに使う。当たり判定の箱の半分の対角）
func _radius(p: Node3D) -> float:
	var half: Variant = p.get("half")
	return clampf((half as Vector3).length(), 0.05, 1.5) if half is Vector3 else 0.3

extends "res://vfx/vfx_base.gd"
# 墨連拳。参考：このプロジェクトの墨の龍（黒い筆腹、金の流路、短い白芯）。
# 素材：圧力で放出される墨。拳の先頭に遅れて墨の肩・首が追い、着弾で側方へ裂ける。
# どこから来る：左側の左右の手元。0.34/0.66の二連打、1.08〜1.69の加速、2.43の重い締め。
# 先に動く部分：拳に相当する幅広の先頭。短い放出の各地点を放出時刻ごとに前へ運ぶ。
# 遅れて追う部分：細い手首の墨筋。先頭を追い、供給終了で尾から切れる。先端は戻さない。
# 形の変化：0.0〜0.19各発の肩が前進／0.19〜0.30着弾で首が曲がり外へ開く
#             着弾前面の墨は色と速度を保ってほどける。最後は斜め上へ抜く一発。
# 着弾前面：元の四流路の位置と速度と黒・金・白を密度場へ受け渡す。灰色の煙を足さない。
# 終わり：白は短く先へ抜け、金は横へほどけ、黒の腹は遅れて側方へ発散する。
#          同じ墨の房が分離して薄まる。原点に別の煙柱を新生させない。
# 寿命ノイズ穴消し0層。模様は恒常的な空隙用、形と消去は放出時刻・運動・供給前線で作る。

# [開始, 左右, 高さ, 曲がり, 強さ]。拳は全て右向き、左右は手元の奥行き。
const BEATS := [
	[0.34, -1.0, 1.65, 0.18, 0.95],
	[0.66, 1.0, 1.90, -0.22, 0.88],
	[1.08, -1.0, 1.55, 0.28, 0.85],
	[1.32, 1.0, 1.95, -0.30, 0.93],
	[1.52, -1.0, 1.75, 0.20, 1.0],
	[1.69, 1.0, 2.10, -0.18, 1.04],
	[2.43, -1.0, 1.85, 0.65, 1.55],
]
const RADII := [0.82, 0.42, 0.15]
const SHADES := [Vector3(0.018,0.014,0.02), Vector3(0.72,0.32,0.04), Vector3(2.5,2.1,1.4)]
const HOTS := [Vector3(0.16,0.12,0.09), Vector3(2.1,1.1,0.20), Vector3(4.2,3.8,2.8)]
const AfterSmoke := preload("res://vfx/vfx_ink_after_smoke.gd")
var _size := 1.0
var _punches: Array = []
var _hands: Array = []
var _impacts: Array = []
var _after_smokes: Array = []

static func spawn(parent: Node, ground: Vector3, size: float = 1.0) -> Node3D:
	var fx: Node3D = new()
	parent.add_child(fx)
	fx.global_position = ground
	fx.start(size)
	return fx

func start(size: float) -> void:
	_size = size
	life = 5.8
	for n in BEATS.size():
		var layers: Array = []
		var hands: Array = []
		for k in 3:
			var mesh := Lib.wisp_layer(ArrayMesh.new(), k, 3, SHADES[k], HOTS[k])
			mesh.material_override = Lib.material("ink_pressure", {
				"grain": Lib.tex("marblenoise_tiled.png") if k == 0 else Lib.tex("liquidvertical_wave.png"),
				"layer": float(k), "seed": n * 0.73 + k * 0.29,
				"shade": SHADES[k], "hot": HOTS[k],
			})
			add_child(mesh)
			layers.append(mesh)
			var hand := Lib.wisp_layer(ArrayMesh.new(),k,3,SHADES[k],HOTS[k])
			hand.material_override = (mesh.material_override as ShaderMaterial).duplicate()
			param(hand,"hand_mode",true)
			param(hand,"hand_surface",true)
			add_child(hand)
			hands.append(hand)
		_punches.append(layers)
		_hands.append(hands)
		var impact := MeshInstance3D.new()
		impact.mesh = Lib.quad()
		impact.material_override = Lib.material("comic_impact",{
			"ink":Vector3(.024,.016,.021), "fill_color":Vector3(2.0,1.55,.65),
			"turn":float(n)*1.13,"ink_width":.085,
		})
		impact.position = Vector3(1.48,float(BEATS[n][2]),float(BEATS[n][1])*.18)*size
		impact.scale = Vector3.ONE*float(BEATS[n][4])*size*1.45
		impact.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(impact)
		_impacts.append(impact)
		var front := _parcel(.265,0.0,BEATS[n],0)
		var origin := to_global(front)
		var drift := Vector3(.65,.08,float(BEATS[n][1])*.21)
		var smoke_size := size*float(BEATS[n][4])
		var smoke := AfterSmoke.spawn(self,origin,drift,smoke_size)
		var sources: Array[PackedVector3Array] = []
		var velocities: Array[PackedVector3Array] = []
		for k in 3:
			var points := PackedVector3Array()
			var speeds := PackedVector3Array()
			for j in 4:
				for u: float in [0.0,0.5,1.0]:
					var p := _hand_exit_point(.265,BEATS[n],k,j,u)
					points.append((p-front)/smoke_size)
					speeds.append((_hand_exit_point(.269,BEATS[n],k,j,u)-p)/(.004*smoke_size))
			sources.append(points)
			velocities.append(speeds)
		smoke.configure_sources(sources,velocities,SHADES,HOTS)
		# 親の材料時計から駆動し、独立した子のspeedで煙だけ進まないようにする。
		smoke.set_process(false)
		smoke.visible = false
		_after_smokes.append(smoke)
	_pose()

func _tick(_delta: float) -> void:
	_pose()

# q は放出された材料の年齢。放出方向も e ごとに変え、先頭の履歴のコピーにしない。
func _parcel(q: float, e: float, beat: Array, k: int) -> Vector3:
	var hand := float(beat[1])
	var bend := float(beat[3])
	var heavy := float(beat[4])
	var fly := smoothstep(0.0,0.19,q)
	var shoulder := sin(fly*PI)
	var p := Vector3(lerpf(-2.25,1.05,fly),float(beat[2]),hand*0.62*(1.0-fly))
	p.y += bend*shoulder + e*(1.4 if heavy>1.2 else -0.8)
	p.z += hand*shoulder*(0.16+e*1.6)
	var after := maxf(q-0.19,0.0)
	var split := smoothstep(0.19,0.28,q)
	p.x += after*(2.8 if k == 0 else 4.4)
	p.y += (0.35 if k == 0 else 1.2)*split*e*5.0
	p.z += hand*split*(0.16+e*3.2)
	if k == 0:
		p.y -= 8.0*after*after
		p.z += sin(e*24.0+after*7.0)*after*0.8
	elif k == 1:
		p.y += sin(after*5.0)*0.55*heavy
		p.z += hand*after*after*2.8
	else:
		p.y += bend*after*1.8
	return p*_size

func _pose() -> void:
	for n in BEATS.size():
		var beat: Array = BEATS[n]
		var t := age-float(beat[0])
		var heavy := float(beat[4])
		var emission := 0.21 if heavy>1.2 else 0.105
		var smoke: Node3D = _after_smokes[n]
		smoke.age = maxf(0.0,t-.265)
		smoke.visible = t>=.265 and smoke.age<smoke.life
		if smoke.visible:smoke._tick(0.0)
		_impacts[n].visible = t>=0.20 and t<0.27
		for k in 3:
			var hand: MeshInstance3D = _hands[n][k]
			hand.visible = t>.05 and t<.315
			if hand.visible:
				hand.mesh = _hand_mesh(t,beat,k) if t<.265 else _hand_exit_mesh(t,beat,k)
				param(hand,"hand_mode",t<.265)
				param(hand,"transfer",smoothstep(.265,.310,t))
				param(hand,"phase",t)
				param(hand,"emission",.08)
				param(hand,"newest",.065)
				param(hand,"oldest",0.0)
				param(hand,"duration",.41 if k==0 else .35)
			var mi: MeshInstance3D = _punches[n][k]
			var duration: float = [0.52,0.40,0.30][k]
			mi.visible = t>0.0 and t<emission+duration
			if not mi.visible: continue
			# 活きている放出区間だけを作る。尾が後から先頭へ追いつき、根元へ戻らない。
			var newest := minf(t,emission)
			var oldest := maxf(0.0,t-duration)
			var points := PackedVector3Array()
			var profile := PackedFloat32Array()
			for i in 32:
				var u := float(i)/31.0
				var e := lerpf(newest,oldest,u)
				var q := t-e
				var position := _parcel(q,e,beat,k)
				points.append(position)
				var head := smoothstep(0.35,0.69,u)*(1.0-smoothstep(0.85,1.0,u))
				var neck := 0.10+0.36*head
				var pressure := sin(clampf(q/0.19,0.0,1.0)*PI/2.0)
				var released := smoothstep(0.20,0.39,q)
				var gate := 1.0-smoothstep(duration-0.15,duration,q)
				var radius := neck*(0.35+0.65*pressure)*gate
				# 外は衝突で腹が開き、金は首が先へ走る。全体scaleは変えない。
				radius *= 1.0-released*(0.42 if k == 0 else 0.35)
				profile.append(maxf(radius,0.003))
			mi.mesh = _fist_flow_mesh(points,float(RADII[k])*heavy*_size,profile)
			param(mi,"phase",t)
			param(mi,"emission",emission)
			param(mi,"newest",newest)
			param(mi,"oldest",oldest)
			param(mi,"duration",duration)
# 薄い殻の断面を掌の扁平な形にする。先端に小さい節、下面に親指の腹。
# 面は通過する材料で組み直され、着弾後には同じ拳の輪郭を保持しない。
func _fist_flow_mesh(points: PackedVector3Array, radius: float, profile: PackedFloat32Array) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rows: Array = []
	for i in points.size():
		var u := float(i)/float(points.size()-1)
		var tangent := (points[mini(i+1,points.size()-1)]-points[maxi(i-1,0)]).normalized()
		var across := tangent.cross(Vector3.UP).normalized()
		var vertical := across.cross(tangent).normalized()
		var palm := smoothstep(0.46,0.74,u)
		var row := PackedVector3Array()
		for j in 25:
			var a := float(j)/24.0*TAU
			var x := cos(a)
			var y := sin(a)
			var squared_x := signf(x)*pow(absf(x),lerpf(1.0,0.58,palm))
			var squared_y := signf(y)*pow(absf(y),lerpf(1.0,0.58,palm))
			var knuckles := 1.0+0.07*cos(a*8.0+age*5.0-u*5.0)*palm
			var thumb := 0.16*exp(-pow((a-4.1)/0.43,2.0))*palm
			var r := radius*profile[i]*(knuckles+thumb)
			# The back shoulder is broad in Z as well as Y, with local liquid lobes.
			var side_flow := sin(a*3.0-u*7.0-age*4.0)*palm*.09
			row.append(points[i]+(across*squared_x*(.91+side_flow)+vertical*squared_y)*r)
		rows.append(row)
	for i in points.size()-1:
		for j in 24:
			for c: Array in [[i,j],[i+1,j],[i,j+1],[i,j+1],[i+1,j],[i+1,j+1]]:
				st.set_uv(Vector2(float(c[1])/24.0,float(c[0])/float(points.size()-1)))
				st.add_vertex(rows[c[0]][c[1]])
	st.generate_normals()
	return st.commit()

# 接触後の元の四流路。位置・速度を同色の密度場へ渡すための短い接続。
func _hand_exit_point(t: float, beat: Array, k: int, j: int, u: float) -> Vector3:
	var after := t-.265
	var heavy := float(beat[4])
	var point := _parcel(t-(1.0-u)*.045,0.0,beat,k)
	point.x += (.28+u*.62+after*(1.0+j*.5))*_size*heavy
	point.y += (j*.29-.34+sin(u*PI+after*10.0+j*.65)*after*2.5)*_size*heavy
	point.z += (sin(u*4.0+j*.75+after*8.0)*after*1.8+(j%2*2-1)*.14)*_size*heavy
	if k==0:point.y -= after*after*12.0*_size
	return point

func _hand_exit_mesh(t: float, beat: Array, k: int) -> ArrayMesh:
	var result := ArrayMesh.new()
	var after := t-.265
	var heavy := float(beat[4])
	var rad: float = [.14,.075,.025][k]
	for j in 4:
		var points := PackedVector3Array()
		var profile := PackedFloat32Array()
		for i in 20:
			var u := float(i)/19.0
			points.append(_hand_exit_point(t,beat,k,j,u))
			profile.append(pow(sin(u*PI),.7)*(1.0-smoothstep(.08,.155,after)))
		var mesh := Lib.path_tube(points,rad*heavy*_size,0.0,12,profile)
		result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,mesh.surface_get_arrays(0))
	return result

# 奥行きのある掌。指節と親指の輪郭を持ち、前面の圧縮に背と側面の墨が遅れ、
# 指間の墨が別の速度で落下する。完成した拳モデルのscaleアニメーションではない。
func _hand_mesh(t: float, beat: Array, k: int) -> ArrayMesh:
	var outline := PackedVector2Array([
		Vector2(-.78,-.19),Vector2(-.47,-.30),Vector2(-.20,-.32),
		Vector2(-.02,-.57),Vector2(.27,-.60),Vector2(.45,-.44),Vector2(.38,-.27),
		Vector2(.62,-.32),Vector2(.79,-.26),Vector2(.85,-.14),Vector2(.77,-.04),
		Vector2(.87,.02),Vector2(.88,.15),Vector2(.78,.23),
		Vector2(.86,.30),Vector2(.84,.44),Vector2(.72,.49),
		Vector2(.77,.57),Vector2(.70,.69),Vector2(.52,.70),
		Vector2(.18,.65),Vector2(-.12,.49),Vector2(-.46,.34),Vector2(-.78,.22),
	])
	var heavy := float(beat[4])
	var r: float = [1.0,.63,.18][k]
	var pressure := smoothstep(.035,.12,t)
	var release := maxf(t-.23,0.0)
	var unbind := smoothstep(.24,.33,t)
	var rows: Array = []
	for j in 19:
		var v := float(j)/18.0
		var z := cos(v*PI)
		# Broad rounded palm ends, not two sharp tips of a flattened XY silhouette.
		var contour := pow(maxf(sin(v*PI),0.0),.32)
		var row := PackedVector3Array()
		for p in outline:
			var finger := floorf(clampf((p.y+.6)/1.3,0.0,.999)*4.0)
			var leading := smoothstep(.23,.78,p.x)
			# Different liquid-arrival ages: foremost knuckles compress while the
			# rear palm and side lobes are still arriving. No whole-hand scale tween.
			var lag := .026*(1.0-leading)+.012*absf(z)+.004*finger
			var local_t := maxf(t-lag,0.0)
			var body := _parcel(local_t,0.0,beat,k)
			var belly := 1.0+.10*sin(p.y*7.0-local_t*15.0+k*.7)*(1.0-leading)
			var side_lobe := .075*sin(p.y*9.0-local_t*18.0+float(beat[1]))*sin(v*PI)
			var point := Vector3(p.x*contour,p.y*contour*.82,z*(.70*belly+side_lobe))*r*heavy
			# Four knuckles lie across depth, so the X-facing view has anatomy too.
			var knuckle_cap := 0.0
			for digit in 4:
				var center := -.73+float(digit)*.48
				var arrival := smoothstep(.035+digit*.003,.14+digit*.003,local_t)
				var swelling := exp(-pow((z-center)/.19,2.0))*(.16+.035*sin(local_t*19.0-digit*.8))*arrival
				knuckle_cap=maxf(knuckle_cap,swelling)
			var upper_face := smoothstep(.12,.53,p.y)*leading
			point.y+=knuckle_cap*upper_face*r*heavy
			point.x+=knuckle_cap*leading*(.4+.6*upper_face)*r*heavy
			var lower_belly := (1.0-smoothstep(-.28,.13,p.y))*(1.0-smoothstep(.28,.72,p.x))
			point.y-=.10*lower_belly*pow(maxf(sin(v*PI),0.0),.5)*r*heavy
			var thumb_side := (1.0-smoothstep(-.40,-.20,p.y))*exp(-pow((z-.48)/.35,2.0))
			point.z+=.18*thumb_side*r*heavy
			var ridge := .10*cos((p.y+.6)*19.3+local_t*2.0)*leading*pow(maxf(sin(v*PI),0.0),.4)
			point.x += ridge*r*heavy
			# Contact advances across the face; the folded back does not flatten with it.
			point.x -= .25*smoothstep(.17,.225,local_t)*leading*(.65+.35*pow(absf(z),.5))*r*heavy
			point.z += leading*z*.14*smoothstep(.17,.24,local_t)*r*heavy
			point.x += release*(1.8+finger*.45)*2.0
			var streamed_y: float = (finger*.32-.45)*r*heavy+sin((p.x+.78)*2.5+release*9.0+finger)*release*2.8
			point.y = lerpf(point.y,streamed_y,unbind)
			point.x += sin((p.x+.78)*4.0+release*10.0+finger)*release*unbind*.9
			point.z += sin((p.x+.78)*3.0+finger*.8+release*13.0)*release*unbind*1.8
			point.y += sin(p.x*4.0-t*12.0)*.065*pressure
			if k==0:
				point.y -= release*release*(6.0+p.x*5.0)
				point.z += sin(p.y*9.0)*release*1.3
			else:
				point.y += release*(p.x+.6)*1.2
			point.y += float(beat[3])*.4*p.x
			row.append(body+point*_size)
		rows.append(row)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for j in 18:
		for i in outline.size():
			var next := (i+1)%outline.size()
			for c: Array in [[j,i],[j+1,i],[j,next],[j,next],[j+1,i],[j+1,next]]:
				var p: Vector2 = outline[c[1]]
				st.set_color(Color(clampf((p.y+.6)/1.3,0.0,1.0),1,1,1))
				# Deflect the permanent channels around each finger rather than cutting
				# the front into identical straight vertical strips.
				var axial := clampf((p.x+.78)/1.66,0.0,1.0)
				var depth := cos(float(c[0])/18.0*PI)
				var channel := (depth+.85)/1.92
				var palm_bridge := 1.0-smoothstep(.10,.44,p.y)
				channel=lerpf(channel,.3125,palm_bridge*.88)
				# Coordinate compensation pins the permanent channels to the separate
				# knuckles, while the connected lower palm keeps a clear fist volume.
				var material_seed := float(BEATS.find(beat))*.73+k*.29
				var e := .065*(1.0-axial)
				var flow_uv := channel-e+t*7.0/25.133-material_seed*3.0/25.133
				st.set_uv(Vector2(flow_uv,axial))
				st.add_vertex(rows[c[0]][c[1]])
	st.generate_normals()
	return st.commit()

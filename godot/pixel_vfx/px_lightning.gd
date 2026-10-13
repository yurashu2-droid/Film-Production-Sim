extends "res://pixel_vfx/px_base.gd"
# Pixel三連放電。既存Pixelの5色/12fpsに、枝を順番に渡る漫画的な放電を組み合わせる。
# 供給は上空の電荷。先行する導電路が下へ走り、側枝は到着を遅らせる。
# .0〜.6 地面予兆／.65,1.35,2.15 各回で違う3分岐／2.5〜3.85 枝端→地面導電路へ。
# 青外層は遅い電荷、明るい青は主路、短い白は一瞬の前線。
# 供給停止は上から下へ進み、枝先への消費を地面の扇状導電路へ渡す。
# 平板上のセルごとの曲線分岐。白線の束だけにしない。寿命ノイズ穴0層。
const COLORS:=[Vector3(.012,.025,.11),Vector3(.045,.12,.43),Vector3(.16,.52,1.55),Vector3(.8,1.65,2.5),Vector3(4.8,5.2,4.3)]
const BEATS:=[.65,1.35,2.15]
var _size:=1.0
var _arcs:Array=[]
var _ground:Array=[]
var _light:OmniLight3D
static func spawn(parent:Node,pos:Vector3,size:float=1.0)->Node3D:
	var fx:Node3D=new()
	parent.add_child(fx)
	fx.global_position=pos
	fx.start(size)
	return fx
func start(size:float)->void:
	_size=size
	life=4.4
	for n in 3:
		var row:Array=[]
		for k in 3:
			var m:=quad(material("px_chain_arc",COLORS,{"layer":float(k),"variant":float(n),"res":30.0}),Vector2(3.7,4.0)*size)
			m.position=Vector3(0,2.02,(k-1)*.13)*size
			m.rotation.y=(k-1)*.15
			row.append(m)
		_arcs.append(row)
	for k in 3:
		var m:=quad(material("px_surge_ground",COLORS,{"seed":k*.21,"mode":1,"res":26.0}),Vector2.ONE*(3.8-k*.34)*size)
		m.rotation.x=-PI/2.0
		m.position.y=(.018+k*.005)*size
		_ground.append(m)
	_light=lamp(COLORS[3],8.0*size)
	_light.position.y=1.4*size
	_step(0.0)
func _step(t:float)->void:
	var energy:=0.0
	for n in 3:
		var q:float=t-BEATS[n]
		for k in 3:
			var arc:MeshInstance3D=_arcs[n][k]
			arc.visible=q>0.0 and q<.77-k*.025
			param(arc,"phase",t)
			param(arc,"pulse",maxf(0.0,q)-k*.018)
			# Each discharge leans differently, retaining genuine 3D layer spacing.
			arc.rotation.y=(k-1)*.15+.045*sin(float(n)*2.0+maxf(q,0.0)*5.0)
		energy+=maxf(0.0,1.0-absf(q-.22)/.27)*5.0
	for k in 3:
		var m:MeshInstance3D=_ground[k]
		m.visible=t>.06+k*.05 and t<3.87-k*.035
		var last:=0.0
		for beat:float in BEATS:
			if t>beat+.28:last=maxf(last,smoothstep(beat+.28,beat+.48,t))
		param(m,"spread",(.45+.45*last)*(smoothstep(.05,.52,t)))
		param(m,"phase",t)
		param(m,"cooled",smoothstep(2.85,3.70,t))
		param(m,"sweep",smoothstep(3.16+k*.08,3.84,t))
	_light.light_energy=energy*_size

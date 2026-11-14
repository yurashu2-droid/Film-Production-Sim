extends "res://vfx/vfx_base.gd"
# 素材: 薄い朱漆の殻。生成亀裂画像の黒い境界を数値分割し、区画・剥離順を導出。
# 発生: 地面から塗膜が立ち上がる。亀裂が先行し、上端が剥がれ、下端が遅れる。
# 1.2s: 最も強い亀裂から曲がる / 2.0s: 裏の金が露出 / 3.2s: 片端を残して裂け落ちる。
# 終わり: 曲げた同じ塗膜が重力で落下→接地で平らな染み→地面に吸収される。
# ランダム穴消し・個体の一様拡縮は使用しない。

const SOURCE := "res://assets/vfx/ai_methods/lacquer_fractures.png"
const SHADER := preload("res://vfx/shaders/gen_erosion.gdshader")
const W := 160
const H := 104
static var _labels := PackedInt32Array()
static var _seeds: Array[Vector2] = []
static var _strength := PackedFloat32Array()
static var _texture: ImageTexture
var _patches: Array = []
var _size := 1.0

static func spawn(parent: Node, pos: Vector3, size: float = 1.0) -> Node3D:
	var fx := new()
	parent.add_child(fx)
	fx.position = pos
	fx._size = size
	fx.life = 6.0
	fx._build()
	return fx

static func _luma(img: Image, x: int, y: int) -> float:
	var c := img.get_pixel(posmod(x,W),clampi(y,0,H-1))
	return c.r*0.2126+c.g*0.7152+c.b*0.0722

static func _segment() -> void:
	if not _labels.is_empty():
		return
	var img := Image.load_from_file(ProjectSettings.globalize_path(SOURCE))
	assert(img != null,"Missing generated lacquer fracture image")
	_texture = ImageTexture.create_from_image(img)
	img.resize(W,H,Image.INTERPOLATE_LANCZOS)
	_strength.resize(W*H)
	for y in H:
		for x in W:
			var gx := _luma(img,x+1,y)-_luma(img,x-1,y)
			var gy := _luma(img,x,y+1)-_luma(img,x,y-1)
			_strength[y*W+x] = sqrt(gx*gx+gy*gy)
	# Closed black fractures are barriers. Connected light islands become real regions.
	# No synthetic grid boundary is added inside an image island.
	_labels.resize(W*H)
	_labels.fill(-1)
	var open := PackedByteArray()
	open.resize(W*H)
	for y in H:
		for x in W:
			var value := _luma(img,x,y)
			for oy in range(-1,2):
				for ox in range(-1,2):
					value = minf(value,_luma(img,x+ox,y+oy))
			open[y*W+x] = 1 if value >= 0.22 else 0
	for index in W*H:
		var x := index%W
		var y := index/W
		if _labels[index] >= 0 or open[index] == 0:
			continue
		var queue := PackedInt32Array([index])
		var region := _seeds.size()
		_labels[index] = region
		var center := Vector2.ZERO
		var cursor := 0
		while cursor < queue.size():
			var cell := queue[cursor]
			cursor += 1
			var cx := cell%W
			var cy := cell/W
			center += Vector2(cx,cy)
			for neighbor in [Vector2i(cx-1,cy),Vector2i(cx+1,cy),Vector2i(cx,cy-1),Vector2i(cx,cy+1)]:
				if neighbor.x < 0 or neighbor.x >= W or neighbor.y < 0 or neighbor.y >= H:
					continue
				var n: int = neighbor.y*W+neighbor.x
				if _labels[n] == -1 and open[n] == 1:
					_labels[n] = region
					queue.append(n)
		_seeds.append(center/maxf(queue.size(),1))

static func _surface(uv: Vector2) -> Vector3:
	var a := uv.x*TAU
	var v := uv.y
	var radius := 1.15*(0.88+0.15*sin(a*3.0+0.4)+0.10*cos(a*5.0))*(0.65+0.35*sin(PI*v))
	var height := 2.50+0.46*sin(a+1.2)+0.28*cos(a*3.0-0.7)
	var y := 0.12+(1.0-v)*height
	return Vector3(cos(a)*radius+0.24*sin(v*4.0),y,sin(a)*radius+0.17*cos(v*3.7))

func _build() -> void:
	_segment()
	for region in _seeds.size():
		var seed: Vector2 = _seeds[region]
		var theta := seed.x/W*TAU
		var center := _surface(Vector2(seed.x/W,seed.y/H))
		var basis := Basis(Vector3(-sin(theta),0,cos(theta)),Vector3.UP,Vector3(cos(theta),0,sin(theta)))
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var strong := 0.0
		var count := 0
		for y in H:
			for x in W:
				if _labels[y*W+x] != region:
					continue
				strong += _strength[y*W+x]
				count += 1
				for corner in [Vector2(0,0),Vector2(1,0),Vector2(0,1),Vector2(1,0),Vector2(1,1),Vector2(0,1)]:
					var uv := Vector2((x+corner.x)/W,(y+corner.y)/H)
					var p := _surface(uv)
					st.set_uv(uv)
					st.add_vertex(basis.inverse()*(p-center)*_size)
		if count == 0:
			continue
		st.generate_normals()
		var mi := MeshInstance3D.new()
		mi.mesh = st.commit()
		var mat := ShaderMaterial.new()
		mat.shader = SHADER
		mat.set_shader_parameter("fracture_image",_texture)
		mat.set_shader_parameter("seed_uv",Vector2(seed.x/W,seed.y/H))
		mi.material_override = mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.transform = Transform3D(basis,center*_size)
		add_child(mi)
		var avg := strong/maxf(count,1)
		var onset := 0.96+seed.y/H*1.36+(1.0-clampf(avg*6,0,1))*0.39+0.28*sin(theta*2.0)
		_patches.append({"node":mi,"center":center*_size,"basis":basis,"theta":theta,"onset":onset,"avg":avg,"region":region})
	_tick(0.0)

func _tick(_delta: float) -> void:
	for patch: Dictionary in _patches:
		var mi: MeshInstance3D = patch.node
		var dt: float = age-patch.onset
		var curl := clampf(dt/0.64,0.0,1.0)
		var falling := maxf(dt-0.58,0.0)
		var c: Vector3 = patch.center
		var angle: float = patch.theta
		var radial := Vector3(cos(angle),0,sin(angle))
		var outward := radial*(0.32*curl+falling*(0.33+float(patch.avg)*0.6))*_size
		var drop := 2.7*falling*falling*_size
		var floor_time := sqrt(maxf(c.y-0.05,0.0)/(2.7*_size))
		var grounded := falling >= floor_time
		var flat := clampf((falling-floor_time)/0.25,0.0,1.0)
		mi.visible = age < 5.72
		mi.position = c+outward-Vector3.UP*minf(drop,c.y-0.027*_size)
		var rotation_amount := minf(falling,floor_time)*0.66
		mi.basis = (patch.basis as Basis)*Basis(Vector3.RIGHT,rotation_amount)
		if grounded:
			mi.basis = (patch.basis as Basis)*Basis(Vector3.RIGHT,lerpf(rotation_amount,PI*0.5,flat))
			mi.position.y -= clampf((age-5.20)/0.48,0,1)*0.19*_size
		param(mi,"curl",curl*(1.0-flat))
		param(mi,"flatten",flat)
		param(mi,"reveal",clampf((age-0.08)/0.66,0.0,1.0))
		param(mi,"peel",curl)
		param(mi,"dry",clampf((age-4.55)/0.8,0.0,1.0)*flat)


extends "res://vfx/vfx_base.gd"
# 素材: 白金色の潮流。画像の線の局所構造テンソルから接線を数値化し、速度へ渡す。
# 圧力源: 地表の短い不等間隔の噴出。頭が先行、厚い腹と尾は放出時刻ぶん遅れる。
# 0.2s: 頭が上昇 / 1.1s: 肩が横へせん断 / 1.9s: 頭が巻き返し尾が落下。
# 終わり: 外殻は先に落水、中殻は遅れた腹を運ぶ、白芯は最後の供給が地表へ流出。
# Lifetime の穴消しは使用しない。窓は「今そこにある材料」の放出時刻から求める。

const SOURCE := "res://assets/vfx/ai_methods/streamlines.png"
const SHADER := preload("res://vfx/shaders/gen_flow.gdshader")
static var _field: Image
static var _field_texture: ImageTexture
var _jets: Array = []
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
	var c := img.get_pixel(clampi(x, 0, img.get_width()-1), clampi(y, 0, img.get_height()-1))
	return c.r * 0.2126 + c.g * 0.7152 + c.b * 0.0722

static func _derive_field() -> void:
	if _field != null:
		return
	var src := Image.load_from_file(ProjectSettings.globalize_path(SOURCE))
	assert(src != null, "Missing generated streamlines image")
	src.resize(96, 96, Image.INTERPOLATE_LANCZOS)
	_field = Image.create(96, 96, false, Image.FORMAT_RGBA8)
	for y in 96:
		for x in 96:
			var xx := 0.0
			var yy := 0.0
			var xy := 0.0
			var density := 0.0
			for oy in range(-2, 3):
				for ox in range(-2, 3):
					var gx := _luma(src, x+ox+1, y+oy)-_luma(src, x+ox-1, y+oy)
					var gy := _luma(src, x+ox, y+oy+1)-_luma(src, x+ox, y+oy-1)
					xx += gx*gx
					yy += gy*gy
					xy += gx*gy
					density += _luma(src,x+ox,y+oy)
			# Largest eigenvector is the image-edge normal; rotate 90 degrees for tangent.
			var normal_angle := 0.5 * atan2(2.0*xy, xx-yy)
			var v := Vector2(-sin(normal_angle), cos(normal_angle))
			if v.y < 0.0:
				v = -v
			var coherence := sqrt((xx-yy)*(xx-yy)+4.0*xy*xy)/maxf(xx+yy, 0.0001)
			v = Vector2(0.0, 1.0).lerp(v, coherence * 0.88).normalized()
			_field.set_pixel(x, y, Color(v.x*0.5+0.5, v.y*0.5+0.5, density/25.0, coherence))
	_field_texture = ImageTexture.create_from_image(_field)

func _build() -> void:
	_derive_field()
	for j in 4:
		var paths := PackedVector3Array()
		var p := Vector3(-0.75 + j*0.47, 0.05, sin(j*2.3)*0.3)
		var velocity := Vector3(0.4*sin(j*2.8), 2.7-j*0.12, 0.15*cos(j))
		for k in 91:
			paths.append(p)
			var t := float(k) * 0.035
			var c := _field.get_pixel(clampi(int(48+p.x*15+j*4),0,95),clampi(int(93-t*28),0,95))
			var vx := c.r*2.0-1.0
			velocity.x += (vx*1.65 + sin(t*2.6+j)*0.45)*0.035
			velocity.z += (vx*cos(j*1.7)*0.8+sin(t*3.1+j*1.3)*0.7)*0.035
			velocity.y += (0.3*(c.g*2.0-1.0)-6.8*clampf((t-0.65)*1.1,0,1))*0.035
			p += velocity*0.035
		var shells: Array = []
		for layer in 3:
			var mi := MeshInstance3D.new()
			var mat := ShaderMaterial.new()
			mat.shader = SHADER
			mat.set_shader_parameter("field_map", _field_texture)
			mat.set_shader_parameter("layer", float(layer))
			mat.set_shader_parameter("seed", float(j)*0.231)
			mi.material_override = mat
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(mi)
			shells.append(mi)
		_jets.append({"path":paths,"start":[0.05,0.61,1.55,2.19][j],"span":[2.50,2.00,1.20,0.75][j],"shells":shells})
	_tick(0.0)

func _sample(path: PackedVector3Array, t: float) -> Vector3:
	var f := clampf(t/0.035, 0.0, path.size()-1.001)
	var i := int(f)
	return path[i].lerp(path[mini(i+1,path.size()-1)], f-i)

func _tick(_delta: float) -> void:
	for j in _jets.size():
		var jet: Dictionary = _jets[j]
		var local: float = age-jet.start
		for layer in 3:
			var mi: MeshInstance3D = jet.shells[layer]
			var lag := layer*0.045
			var head := local-lag
			var tail := maxf(0.0,head-float(jet.span)+layer*0.055)
			var end := 2.60+layer*0.06
			mi.visible = head > 0.01 and tail < end
			if not mi.visible:
				continue
			head = minf(head,end)
			var points := PackedVector3Array()
			var profile := PackedFloat32Array()
			for i in 28:
				var u := float(i)/27.0
				var tr := lerpf(tail,head,u)
				var p := _sample(jet.path,tr)
				# Material emitted at different times keeps its own velocity/phase.
				var emitted := local-tr
				p.x += sin(emitted*5.4+j*2.3)*0.18*tr
				p.z += cos(emitted*4.1+j)*0.16*tr
				p.y = maxf(0.025,p.y*0.78)
				points.append(p*_size)
				var shoulder := exp(-pow((u-0.77)/0.22,2.0))
				var taper := pow(sin(PI*u),0.28)
				var r := (0.78+0.22*shoulder)*taper*(0.74+0.26*sin(tr*6.0-emitted*2.1+j))
				# Upon reaching the floor the same jet opens into a shallow draining film.
				r *= 1.0-clampf((tr-2.4)*1.4,0.0,0.85)
				profile.append(maxf(0.018,r))
			mi.mesh = Lib.path_tube(points, [0.70,0.48,0.27][layer]*_size,0.0,20,profile)
			param(mi,"phase", age)
			param(mi,"travel", tail)

extends "res://vfx/vfx_base.gd"
# 素材: 亀裂から圧力で噴く熱い墨。生成画像の輝度CDFから発生地点と供給量を選ぶ。
# .15-.7s 最初の噴出 / 1.1-2.4s 曲がる頭と遅い腹 / 3.0-3.8s 不均等な最終噴出。
# 白芯は冷却、橙の腹は横へ割れ、外の墨は落ちて地表へ流れる。寿命ノイズ穴なし。
# 参考: 圧力噴流と火山亀裂の形をゲーム向けに誇張。画像輝度は正確な圧力ではない。
const SOURCE := "res://assets/vfx/ai_methods/crack_emission.png"
var _size := 1.0
var _streams: Array[Dictionary] = []
var _shells: Array[Array] = []
var extracted_emitters: Array[Vector3] = []
var image_weight_sum := 0.0
var used_generated_image := false
var _ground: Array[MeshInstance3D] = []

static func spawn(parent:Node,pos:Vector3,size:float=1.0) -> Node3D:
	var fx: Node3D = new()
	parent.add_child(fx)
	fx.global_position = pos
	fx.start(size)
	return fx

func start(size:float) -> void:
	_size = size
	life = 6.2
	var weighted := _load_distribution()
	var image := Image.load_from_file(ProjectSettings.globalize_path(SOURCE))
	if image != null and not image.is_empty():
		image.generate_mipmaps()
		var tex := ImageTexture.create_from_image(image)
		for layer in 2:
			var ground := MeshInstance3D.new()
			var plane := PlaneMesh.new()
			plane.size = Vector2(3.5,3.5)*_size
			ground.mesh = plane
			ground.position.y = (.024+float(layer)*.006)*_size
			ground.material_override = Lib.material("gen_emission_ground",{"cracks":tex,"layer":float(layer)})
			ground.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(ground)
			_ground.append(ground)
	var times := [.15,.33,.66,1.14,1.34,1.55,2.15,2.4,3.05,3.33,3.78]
	for i in times.size():
		var entry: Dictionary = weighted[i]
		var origin: Vector3 = entry["point"]
		extracted_emitters.append(origin)
		var angle := atan2(origin.z,origin.x)+.5*sin(float(i)*2.1)
		var power: float = entry["weight"]
		_streams.append({"birth":times[i],"supply":.34+.13*_hash(i+9),"burn":1.1+.14*_hash(i+1),"origin":origin,"angle":angle,"speed":3.4+2.4*power,"seed":float(i)*2.13,"parent":-1,"width":.45+.20*power})
	# Shoulder splits are released from live parent material, rather than extra sticks.
	for i in [1,3,6,8,10]:
		var source: Dictionary = _streams[i]
		_streams.append({"birth":float(source["birth"])+.37,"supply":.24,"burn":.90,"origin":source["origin"],"angle":float(source["angle"])+.8,"speed":2.2,"seed":float(i)*1.8+7.0,"parent":i,"width":.29})
	for i in _streams.size():
		var row: Array = []
		for layer in 3:
			var node := MeshInstance3D.new()
			node.material_override = Lib.material("gen_emission",{"layer":float(layer),"seed":float(_streams[i]["seed"])})
			node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(node)
			row.append(node)
		_shells.append(row)
	_tick(0.0)

static func _hash(i:int) -> float:
	return fposmod(sin(float(i)*127.1+37.6)*41718.21,1.0)

func _load_distribution() -> Array[Dictionary]:
	var img := Image.load_from_file(ProjectSettings.globalize_path(SOURCE))
	var pixels: Array[Dictionary] = []
	if img != null and not img.is_empty():
		used_generated_image = true
		img.resize(64,64,Image.INTERPOLATE_LANCZOS)
		for y in 64:
			for x in 64:
				var c := img.get_pixel(x,y)
				var value := maxf(c.r,maxf(c.g,c.b))*c.a
				var weight := pow(maxf(0.0,value-.16),2.0)
				if weight < .025: continue
				image_weight_sum += weight
				pixels.append({"point":Vector3((float(x)/63.0-.5)*3.5,.07,(float(y)/63.0-.5)*3.5),"weight":value,"sum":image_weight_sum})
	if pixels.is_empty():
		push_warning("gen_emission requires generated crack_emission.png; temporary distribution")
		pixels.append({"point":Vector3.ZERO,"weight":1.0,"sum":1.0})
		image_weight_sum = 1.0
	var selected: Array[Dictionary] = []
	for i in 11:
		var target := _hash(i+17)*image_weight_sum
		for px in pixels:
			if float(px["sum"]) >= target:
				selected.append(px)
				break
	return selected

# Each simultaneously surviving parcel has its own emission time and initial direction.
# Head acceleration, later material direction, drag and curl deform the belly and neck.
func _parcel(i:int,elapsed:float,emitted:float) -> Vector3:
	var stream := _streams[i]
	var dt := maxf(0.0,elapsed-emitted)
	var fraction := emitted/float(stream["supply"])
	var angle := float(stream["angle"])+.65*sin(fraction*2.1+float(stream["seed"])*.4)
	var side := Vector3(-sin(angle),0,cos(angle))
	var direction := Vector3(cos(angle),0,sin(angle))
	var speed0 := float(stream["speed"])*(1.0-.3*fraction)
	var travel := speed0*(1.0-exp(-1.9*dt))/1.9
	var up := (6.6+1.6*_hash(i+19))*(1.0-.3*fraction)*(1.0-exp(-1.65*dt))/1.65
	var curl := .43*(sin(dt*4.2+fraction*1.3)-sin(fraction*1.3))*smoothstep(.1,.65,dt)
	var origin: Vector3 = stream["origin"]
	var parent_id := int(stream["parent"])
	if parent_id >= 0:
		var parent_release := float(stream["birth"])-float(_streams[parent_id]["birth"])
		origin = _parcel(parent_id,parent_release,.055)
		up *= .45
		travel *= .65
	var p := origin+direction*travel+side*curl+Vector3.UP*(up-2.45*dt*dt)
	if p.y < .07:
		p.y = .07
		p += direction*.45*smoothstep(.8,1.5,dt)
	return p

func _tick(_delta:float) -> void:
	for ground in _ground: param(ground,"phase",age)
	for i in _streams.size():
		var stream := _streams[i]
		var dt := age-float(stream["birth"])
		var supply := float(stream["supply"])
		var burn := float(stream["burn"])
		for layer in 3:
			var node: MeshInstance3D = _shells[i][layer]
			var layer_burn: float = burn+[.20,-.05,-.42][layer]
			var first := maxf(0.0,dt-layer_burn)
			var last := minf(supply,dt)
			node.visible = dt>0.0 and last-first>.004
			if not node.visible: continue
			var points := PackedVector3Array()
			var widths := PackedFloat32Array()
			for j in 17:
				var u := float(j)/16.0
				# Tail is newest, head oldest; root tail disappears as supply ends.
				var emitted := lerpf(last,first,u)
				var material_age := dt-emitted
				var p := _parcel(i,dt,emitted)
				var shear := smoothstep(.15,.8,material_age)
				p += Vector3(.035*sin(u*8.0+age*3.0+float(i)),.025*sin(u*5.0+float(i)),.045*sin(u*7.0-age*2.0))*shear*float(layer)
				points.append(p*_size)
				var belly := pow(sin(u*PI),.55)*(.75+.25*sin(u*17.0+material_age*4.0+float(i)))
				var cooling := 1.0-.48*smoothstep(.4,layer_burn,material_age)
				# A newly split shoulder opens under pressure rather than appearing as a ring.
				var pressure := smoothstep(.0,.13,dt)
				widths.append((.035+.965*belly)*(1.0+.25*sin(u*8.0-material_age*5.0+float(i)))*cooling*pressure)
			# Open shear fans replace the closed capsule/leaf circumference. They leave
			# real empty sectors through which a second, differently aged flow is visible.
			node.mesh = _shear_mesh(points,widths,float(stream["width"])*[1.0,.57,.24][layer]*_size,layer,float(stream["seed"]),dt)
			param(node,"phase",age)
			param(node,"elapsed",dt)
			param(node,"emitted_first",first)
			param(node,"emitted_last",last)
			param(node,"burn",layer_burn)

func _shear_mesh(points:PackedVector3Array,widths:PackedFloat32Array,radius:float,layer:int,seed:float,elapsed:float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var count := points.size()
	var vertices: Array[PackedVector3Array] = []
	for strand in 3:
		var edge := PackedVector3Array()
		for j in count:
			var u := float(j)/float(count-1)
			var tangent := (points[mini(j+1,count-1)]-points[maxi(j-1,0)]).normalized()
			var side := tangent.cross(Vector3.BACK if absf(tangent.z)<.9 else Vector3.UP).normalized()
			var depth := tangent.cross(side).normalized()
			var center := float(strand)*TAU/3.0+seed+float(layer)*.7+.45*sin(elapsed*2.4+u*5.0+seed)
			for wing in 2:
				var a := center+(float(wing)-.5)*(1.23+.24*sin(u*12.0+elapsed*3.0))
				var r := radius*widths[j]*(1.0+.25*sin(u*19.0-elapsed*5.0+float(wing)*1.6+seed))
				edge.append(points[j]+(side*cos(a)+depth*sin(a))*r)
		vertices.append(edge)
	for strand in 3:
		var edge: PackedVector3Array = vertices[strand]
		for j in count-1:
			for corner:Vector2i in [Vector2i(j,0),Vector2i(j+1,0),Vector2i(j,1),Vector2i(j,1),Vector2i(j+1,0),Vector2i(j+1,1)]:
				st.set_uv(Vector2(float(corner.y),float(corner.x)/float(count-1)))
				st.add_vertex(edge[corner.x*2+corner.y])
	st.generate_normals()
	return st.commit()

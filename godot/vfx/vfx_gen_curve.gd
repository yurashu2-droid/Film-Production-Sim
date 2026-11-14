extends "res://vfx/vfx_base.gd"
# 素材: 金色の放電。生成した枝画像の白線を細線化し、根から枝先への経路にする。
# .15s 根の放電 / .7s 分岐へ圧力到着 / 1.8s 遅い枝の再点火 / 4.0s 最終供給。
# 外のコロナは先へ散り、白芯の供給尾が根から先へ抜け、金の余光が最後に抜ける。
# 参考: 木状のリヒテンベルク放電を、ゲーム向けに遅く誇張。画像の陰影は物理データではない。
const SOURCE := "res://assets/vfx/ai_methods/branch_lines.png"
const RES := 96
var _paths: Array[Dictionary] = []
var _shells: Array[Array] = []
var _size := 1.0
var extracted_pixels := 0
var extracted_branches := 0
var used_generated_image := false
static var _graph_cache: Array[Dictionary] = []
static var _pixel_cache := 0

static func spawn(parent: Node, pos: Vector3, size: float = 1.0) -> Node3D:
	var fx: Node3D = new()
	parent.add_child(fx)
	fx.global_position = pos
	fx.start(size)
	return fx

func start(size: float) -> void:
	_size = size
	life = 6.0
	if _graph_cache.is_empty():
		_graph_cache = _extract_graph()
	_paths = _graph_cache.duplicate(true)
	extracted_pixels = _pixel_cache
	extracted_branches = _paths.size()
	used_generated_image = FileAccess.file_exists(SOURCE)
	for i in _paths.size():
		var row: Array = []
		for layer in 3:
			var node := MeshInstance3D.new()
			node.material_override = Lib.material("gen_curve", {"layer":float(layer), "seed":float(i)*1.79})
			node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(node)
			row.append(node)
		_shells.append(row)
	_tick(0.0)

func _extract_graph() -> Array[Dictionary]:
	var img := Image.load_from_file(ProjectSettings.globalize_path(SOURCE))
	if img == null or img.is_empty():
		push_warning("gen_curve requires generated branch_lines.png; using temporary graph")
		return [{"points":PackedVector3Array([Vector3(0,.2,0),Vector3(-.2,1.1,.3),Vector3(.4,2.0,-.3),Vector3(-.2,3.3,.4)]),"start":0.0,"end":1.0}]
	img.resize(RES, RES, Image.INTERPOLATE_LANCZOS)
	var pixels := PackedByteArray()
	pixels.resize(RES*RES)
	for y in RES:
		for x in RES:
			var c := img.get_pixel(x,y)
			pixels[y*RES+x] = 1 if maxf(c.r,maxf(c.g,c.b))*c.a > .32 else 0
	# Zhang-Suen: retain connectivity and branch locations while removing line thickness.
	for cycle in 36:
		var changes := 0
		for pass_id in 2:
			var remove: Array[int] = []
			for y in range(1,RES-1):
				for x in range(1,RES-1):
					var p := y*RES+x
					if pixels[p] == 0: continue
					var nb: Array[int] = [pixels[p-RES],pixels[p-RES+1],pixels[p+1],pixels[p+RES+1],pixels[p+RES],pixels[p+RES-1],pixels[p-1],pixels[p-RES-1]]
					var count := 0
					var transitions := 0
					for k in 8:
						count += nb[k]
						if nb[k] == 0 and nb[(k+1)%8] == 1: transitions += 1
					if count < 2 or count > 6 or transitions != 1: continue
					if pass_id == 0 and (nb[0]*nb[2]*nb[4] != 0 or nb[2]*nb[4]*nb[6] != 0): continue
					if pass_id == 1 and (nb[0]*nb[2]*nb[6] != 0 or nb[0]*nb[4]*nb[6] != 0): continue
					remove.append(p)
			for p in remove: pixels[p] = 0
			changes += remove.size()
		if changes == 0: break
	var root := -1
	for y in range(RES-2,0,-1):
		var best := 999
		for x in range(1,RES-1):
			if pixels[y*RES+x] != 0 and absi(x-RES/2)<best:
				root = y*RES+x
				best = absi(x-RES/2)
		if root >= 0: break
	if root < 0: return []
	var visited: Dictionary = {root:-1}
	var distance: Dictionary = {root:0.0}
	var queue: Array[int] = [root]
	var endpoints: Array[int] = []
	var head := 0
	while head < queue.size():
		var p := queue[head]
		head += 1
		var nbs := _neighbors(p,pixels)
		if nbs.size() == 1 and p != root: endpoints.append(p)
		for nb in nbs:
			if visited.has(nb): continue
			visited[nb] = p
			distance[nb] = float(distance[p])+1.0
			queue.append(nb)
	_pixel_cache = queue.size()
	endpoints.sort_custom(func(a:int,b:int)->bool: return float(distance[a])>float(distance[b]))
	if endpoints.is_empty(): endpoints.append(queue.back())
	var max_dist: float = distance[endpoints[0]]
	var claimed: Dictionary = {}
	var out: Array[Dictionary] = []
	for tip in endpoints:
		var path: Array[int] = [tip]
		var p := tip
		while int(visited[p]) >= 0:
			p = int(visited[p])
			path.push_front(p)
			if claimed.has(p): break
		if path.size() < 7: continue
		var ctrl := PackedVector3Array()
		for k in range(0,path.size(),3):
			ctrl.append(_pixel_point(path[k],root))
		ctrl.append(_pixel_point(path.back(),root))
		out.append({"points":Lib.smooth_path(ctrl,2),"start":float(distance[path[0]])/max_dist,"end":float(distance[tip])/max_dist})
		for px in path: claimed[px]=true
		if out.size() >= 20: break
	return out

func _neighbors(p:int,pixels:PackedByteArray) -> Array[int]:
	var result: Array[int] = []
	var x := p%RES
	var y := p/RES
	for yy in range(maxi(0,y-1),mini(RES,y+2)):
		for xx in range(maxi(0,x-1),mini(RES,x+2)):
			var q := yy*RES+xx
			if q != p and pixels[q] != 0: result.append(q)
	return result

func _pixel_point(p:int,root:int) -> Vector3:
	var x := float(p%RES-root%RES)/float(RES)
	var y := float(root/RES-p/RES)/float(RES)
	# The actual image skeleton sets XY; a folded depth embedding gives real side volume.
	return Vector3(x*5.4,.2+y*3.8,sin(x*8.0+y*4.2)*.85+sin(y*9.0)*.24)

func _tick(_delta:float) -> void:
	for i in _paths.size():
		var data := _paths[i]
		var base: PackedVector3Array = data["points"]
		var start_d: float = data["start"]
		var end_d: float = data["end"]
		for layer in 3:
			var node: MeshInstance3D = _shells[i][layer]
			var points := PackedVector3Array()
			var widths := PackedFloat32Array()
			for j in base.size():
				var u := float(j)/float(base.size()-1)
				var d := lerpf(start_d,end_d,u)
				var front := _energy(d,age-float(layer)*.065)
				var p := base[j]
				# Local moving shoulder: a bend follows each advancing discharge front.
				p.x += .10*sin(d*17.0-age*6.0+float(i))*front
				p.y += .07*sin(d*9.0-age*3.0)*front*float(layer)*.4
				p.z += .15*sin(d*13.0-age*4.0+float(i)*.7)*front
				if layer == 0:
					p.z += .09*sin(d*19.0-age*2.0)*_energy(d,age-.23)
				# The last corona drifts outward along the already reached branch direction.
				if age > 4.4:
					var outward := (base[j]-base[maxi(0,j-1)]).normalized()
					p += outward*.15*smoothstep(4.4,5.3,age)*float(2-layer)*.5
				points.append(p*_size)
				widths.append((.28+.72*front)*(.78+.22*sin(d*13.0-age*3.0)))
			node.mesh = Lib.path_tube(points,[.34,.15,.048][layer]*_size,0.0,9,widths)
			param(node,"phase",age)
			param(node,"distance_start",start_d)
			param(node,"distance_end",end_d)
			node.visible = age < 5.55

func _energy(d:float,t:float) -> float:
	var result := 0.0
	for cue:float in [.15,1.05,2.2,3.72]:
		var arrival := cue+d*1.08
		result = maxf(result, exp(-pow((t-arrival)/.25,2.0)))
	return result

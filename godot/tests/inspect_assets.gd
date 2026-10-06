extends SceneTree
# 取り込んだGLBの寸法とアニメーション名を出力する確認用スクリプト
#   godot --headless --path godot -s res://tests/inspect_assets.gd


func _init() -> void:
	for dir in ["res://assets/props", "res://assets/cast"]:
		for f in DirAccess.get_files_at(dir):
			if not f.ends_with(".glb"):
				continue
			var ps: PackedScene = load(dir + "/" + f)
			if ps == null:
				print("LOAD_FAIL ", f)
				continue
			var n: Node3D = ps.instantiate()
			var box := _merged_aabb(n, Transform3D.IDENTITY)
			var line := "%s  min=%s size=%s" % [f, _v(box.position), _v(box.size)]
			var ap: AnimationPlayer = _find(n, "AnimationPlayer")
			if ap:
				line += "  anims=" + str(ap.get_animation_list())
			var sk: Skeleton3D = _find(n, "Skeleton3D")
			if sk:
				line += "  bones=%d" % sk.get_bone_count()
			print(line)
			if dir.ends_with("props"):
				_dump(n, 1, Transform3D.IDENTITY)
			n.free()
	quit()


func _v(v: Vector3) -> String:
	return "(%.2f, %.2f, %.2f)" % [v.x, v.y, v.z]


func _find(n: Node, cls: String) -> Node:
	if n.is_class(cls):
		return n
	for c in n.get_children():
		var r := _find(c, cls)
		if r:
			return r
	return null


func _merged_aabb(n: Node, xf: Transform3D) -> AABB:
	var out := AABB()
	var first := true
	var stack: Array = [[n, xf]]
	while not stack.is_empty():
		var it: Array = stack.pop_back()
		var node: Node = it[0]
		var t: Transform3D = it[1]
		if node is Node3D and node != n:
			t = t * (node as Node3D).transform
		if node is MeshInstance3D and (node as MeshInstance3D).mesh:
			var b: AABB = t * (node as MeshInstance3D).mesh.get_aabb()
			out = b if first else out.merge(b)
			first = false
		for c in node.get_children():
			stack.push_back([c, t])
	return out


func _dump(n: Node, depth: int, xf: Transform3D) -> void:
	for c in n.get_children():
		var t := xf
		if c is Node3D:
			t = xf * (c as Node3D).transform
		if depth <= 1 or not (c is MeshInstance3D):
			if not (c is MeshInstance3D):
				print("    ".repeat(depth), c.name, " [", c.get_class(), "] ", _v(t.origin) if c is Node3D else "")
		_dump(c, depth + 1, t)

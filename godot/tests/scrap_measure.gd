extends SceneTree
# 廃材置き場の追加GLBを計測する（寸法・三角形数・頂点色・材質）。
func _initialize() -> void:
	run.call_deferred()
func run() -> void:
	var dir := DirAccess.open("res://assets/production/scrap")
	var files: Array = []
	for f in dir.get_files():
		if f.ends_with(".glb"):
			files.append(f)
	files.sort()
	for f in files:
		var node := (load("res://assets/production/scrap/" + f) as PackedScene).instantiate() as Node3D
		root.add_child(node)
		var tris := 0
		var box := AABB()
		var first := true
		var has_vc := false
		var mats := {}
		var meshes := 0
		for mi in node.find_children("*", "MeshInstance3D", true, false):
			meshes += 1
			var m := mi as MeshInstance3D
			var t := m.global_transform
			var b: AABB = t * m.get_aabb()
			box = b if first else box.merge(b)
			first = false
			for s in m.mesh.get_surface_count():
				var arr := m.mesh.surface_get_arrays(s)
				var idx = arr[Mesh.ARRAY_INDEX]
				tris += (idx.size() if idx != null else (arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()) / 3
				if arr[Mesh.ARRAY_COLOR] != null:
					has_vc = true
				var mat := m.mesh.surface_get_material(s)
				mats[mat.resource_name if mat else "NONE"] = (mat is BaseMaterial3D and (mat as BaseMaterial3D).albedo_texture != null)
		print("MEASURE %s tris=%d meshes=%d size=(%.3f, %.3f, %.3f) min=(%.3f, %.3f, %.3f) vcol=%s mats=%s" % [f, tris, meshes, box.size.x, box.size.y, box.size.z, box.position.x, box.position.y, box.position.z, has_vc, mats.keys()])
		node.queue_free()
	quit()

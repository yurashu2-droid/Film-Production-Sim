extends SceneTree
# 靴の実頂点で埋まりを検出し、元の骨の姿勢・素材の保持も確認する。
var failed := false
func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	print("FOOT_CHECK ", label, " ", "OK" if ok else "FAIL")
	failed = failed or not ok
func foot_vertices(v: Node) -> Dictionary:
	var feet := {}
	for mesh: MeshInstance3D in v.find_children("*", "MeshInstance3D", true, false):
		if not mesh.skin: continue
		for surface in mesh.mesh.get_surface_count():
			var a: Array = mesh.mesh.surface_get_arrays(surface)
			var vertices: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
			var bones: PackedInt32Array = a[Mesh.ARRAY_BONES]
			var weights: PackedFloat32Array = a[Mesh.ARRAY_WEIGHTS]
			var count := bones.size() / vertices.size()
			for i in vertices.size():
				for j in count:
					if weights[i * count + j] < 0.999: continue
					var bind: int = bones[i * count + j]
					var b: int = v.skel.find_bone(mesh.skin.get_bind_name(bind)) if mesh.skin.get_bind_name(bind) != "" else mesh.skin.get_bind_bone(bind)
					if not v.skel.get_bone_name(b).begins_with("FOOT."): continue
					if not feet.has(b): feet[b] = PackedVector3Array()
					feet[b].append(mesh.skin.get_bind_pose(bind) * vertices[i])
	return feet
func bottom(v: Node, feet: Dictionary) -> float:
	var low := INF
	for b in feet:
		var tr: Transform3D = v.skel.global_transform * v.skel.get_bone_global_pose(b)
		for p: Vector3 in feet[b]: low = minf(low, (tr * p).y)
	return low
func run() -> void:
	for tag in ["M02", "04", "09", "03", "01", "02", "06"]:
		var before := FileAccess.get_sha256("res://assets/cast/cast%s_game.glb" % tag)
		var v: Node = load("res://scripts/cast_visual.gd").new()
		root.add_child(v); v.setup(tag)
		if v.face_anim: v.face_anim.pause()
		var feet := foot_vertices(v)
		var raw_low := INF
		var fixed_low := INF
		var preserved := true
		var raised_only_when_needed := true
		for clip in ["walk", "run", "run_start", "run_stop", "carry_run", "onehand_run"]:
			v.play(clip, 0, true); v.anim.pause()
			for frame in 31:
				if "grounding_enabled" in v: v.grounding_enabled = false
				v.anim.seek(v.length(clip) * frame / 31.0, true)
				v.skel.force_update_all_bone_transforms()
				var raw := bottom(v, feet)
				raw_low = minf(raw_low, raw)
				var poses: Array = []
				for b in v.skel.get_bone_count(): poses.append(v.skel.get_bone_global_pose(b))
				if "grounding_enabled" in v: v.grounding_enabled = true
				if v.has_method("_update_grounding"): v._update_grounding()
				var corrected := bottom(v, feet)
				fixed_low = minf(fixed_low, corrected)
				for b in v.skel.get_bone_count(): preserved = preserved and poses[b].is_equal_approx(v.skel.get_bone_global_pose(b))
				if raw != INF and raw >= 0.002: raised_only_when_needed = raised_only_when_needed and absf(raw - corrected) < 0.0001
		if feet.is_empty():
			check(tag == "M02", tag + " wheels keep original animation")
		else:
			check(fixed_low >= -0.003, tag + " sole stays above floor (raw %.3fm, fixed %.3fm)" % [raw_low, fixed_low])
		check(preserved and raised_only_when_needed, tag + " original pose and airborne stride preserved")
		check(FileAccess.get_sha256("res://assets/cast/cast%s_game.glb" % tag) == before, tag + " source asset untouched")
		if "grounding_enabled" in v:
			v.grounding_enabled = false
			check(v.get_child(0).position.y == 0, tag + " restore original immediately")
			v.grounding_enabled = true
			v.play("jump",0,true); v.anim.advance(0.15)
			v.skel.force_update_all_bone_transforms(); v._update_grounding()
			check(v.get_child(0).position.y == 0, tag + " jump remains original")
		# 実フレームの更新・モーション間のブレンドでも補正が追従する。
		v.play("run",0,true)
		for i in 38:
			await process_frame
			if not feet.is_empty():
				check(bottom(v, feet) >= -0.003, tag + " live run frame %d" % i)
		v.play("idle",0.18,true)
		for i in 14:
			await process_frame
			if not feet.is_empty():
				check(bottom(v, feet) >= -0.003, tag + " blend to idle frame %d" % i)
		v.queue_free()
	print("FOOTTEST_FAIL" if failed else "FOOTTEST_OK")
	quit(1 if failed else 0)

extends Node3D
## Matched legacy/refined prop views. Used with the hidden render dev session.
const MovieProp := preload("res://scripts/production_movie_prop.gd")
const Scrap := preload("res://scripts/production_scrap.gd")
const PropShapes := preload("res://scripts/prop_shapes.gd")
const LEGACY_FILES := preload("res://tools/prop_rebuild_baseline.gd").FILES
var camera: Camera3D
var models: Array[Node3D] = []
var key: DirectionalLight3D
var fill: DirectionalLight3D

func _ready() -> void:
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	var env := environment.environment
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("434a4e")
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color("b4c7df")
	sky_material.sky_horizon_color = Color("e6e0d4")
	sky_material.ground_horizon_color = Color("afa994")
	sky_material.ground_bottom_color = Color("32383d")
	env.sky = Sky.new()
	env.sky.sky_material = sky_material
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.6
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_white = 6.0
	add_child(environment)
	key = DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-48,-32,0)
	key.light_energy = 1.6
	key.shadow_enabled = true
	key.light_angular_distance = 2.0
	add_child(key)
	fill = DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-28,135,0)
	fill.light_energy = 0.55
	add_child(fill)
	var floor_mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(100,100)
	floor_mesh.mesh = plane
	var floor_mat := StandardMaterial3D.new()
	floor_mat.albedo_color = Color("676d70")
	floor_mat.roughness = 0.85
	floor_mesh.material_override = floor_mat
	add_child(floor_mesh)
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.current = true
	add_child(camera)
	show_pair("scrap_chest")

func make_prop(kind: String, refined: bool, file_override: String = "") -> Node3D:
	var entry: Dictionary = Scrap.find(kind).duplicate(true)
	if not refined:
		entry.file = LEGACY_FILES[kind]
	if not file_override.is_empty():
		entry.file = file_override
	var body := MovieProp.new()
	body.fixed = true
	body._build_scrap(entry)
	add_child(body)
	body.set_physics_process(false)
	models.append(body)
	return body

func clear_models() -> void:
	for model: Node3D in models:
		model.free()
	models.clear()

func show_pair(kind: String, rear: bool = false, warm: bool = false) -> void:
	clear_models()
	var gap := 0.47 if kind == "scrap_chest" else 0.61
	make_prop(kind,false).position.x = -gap
	make_prop(kind,true).position.x = gap
	var center := Vector3(0,0.27 if kind == "scrap_chest" else 0.7,0)
	camera.size = 1.9 if kind == "scrap_chest" else 2.35
	camera.position = center + Vector3(1.2,0.8,-4 if rear else 4)
	camera.look_at(center)
	key.light_color = Color("ffdfb9") if warm else Color.WHITE
	key.light_energy = 1.0 if warm else 1.6
	fill.light_energy = 0.25 if warm else 0.55

func show_detail(kind: String, rear: bool = false) -> void:
	clear_models()
	make_prop(kind,true)
	var center := Vector3(0,0.27 if kind == "scrap_chest" else 0.7,0)
	camera.size = 0.92 if kind == "scrap_chest" else (1.95 if kind == "scrap_vending" else 1.72)
	camera.position = center + Vector3(2,1.0,-3.4 if rear else 3.4)
	camera.look_at(center)

func save_catalog(kinds: Array = ["scrap_chest","scrap_fridge"]) -> Array[String]:
	get_tree().paused = false
	var viewport := SubViewport.new()
	viewport.size = Vector2i(384,384)
	viewport.own_world_3d = true
	viewport.transparent_bg = true
	viewport.msaa_3d = Viewport.MSAA_4X
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	var environment := WorldEnvironment.new()
	environment.environment = (get_child(0) as WorldEnvironment).environment.duplicate(true)
	environment.environment.background_color = Color(0,0,0,0)
	viewport.add_child(environment)
	var photo_key := key.duplicate() as DirectionalLight3D
	photo_key.light_angular_distance = 0.0
	viewport.add_child(photo_key)
	viewport.add_child(fill.duplicate())
	var photo_camera := Camera3D.new()
	photo_camera.fov = 26.0
	photo_camera.current = true
	viewport.add_child(photo_camera)
	var saved: Array[String] = []
	for kind: String in kinds:
		var holder := make_prop(kind,true)
		remove_child(holder)
		viewport.add_child(holder)
		models.erase(holder)
		var center: Vector3 = holder.center
		var radius: float = holder.half.length()
		photo_camera.position = center + Vector3(0.62,0.42,1).normalized() * (radius / tan(deg_to_rad(13.0)) * 1.04)
		photo_camera.look_at(center)
		for i in 6:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var picture := viewport.get_texture().get_image()
		picture.convert(Image.FORMAT_RGBA8)
		var used := picture.get_used_rect().grow(6).intersection(Rect2i(0,0,384,384))
		var output := "res://assets/ui/catalog/"+kind+".png"
		picture.get_region(used).save_png(ProjectSettings.globalize_path(output))
		saved.append(output)
		holder.free()
	viewport.queue_free()
	return saved

func audit_props(kinds: Array = ["scrap_chest","scrap_fridge"]) -> Dictionary:
	clear_models()
	var errors: Array[String] = []
	var rows: Array[Dictionary] = []
	for kind: String in kinds:
		var body := make_prop(kind,true)
		var expected := Scrap.find(kind)
		var size: Vector3 = body.half * 2
		if not is_equal_approx(size[size.max_axis_index()],float(expected.size)) or not is_equal_approx(body.mass,float(expected.mass)):
			errors.append(kind+": size or mass changed")
		var collider := body.get_child(body.get_child_count()-1) as CollisionShape3D
		# Preserve the existing compound or catalog-selected collider type.
		if PropShapes.has(kind):
			var colliders := body.find_children("*","CollisionShape3D",false,false)
			if colliders.size() != PropShapes.TABLE[kind].shapes.size():
				errors.append(kind+": compound collider count changed")
		elif String(expected.get("shape","box")) == "cyl":
			if collider == null or not collider.shape is CylinderShape3D or not is_equal_approx(collider.shape.height,size.y) or not is_equal_approx(collider.shape.radius,minf(size.x,size.z)*0.5):
				errors.append(kind+": cylinder collider no longer matches the measured prop")
		elif collider == null or not collider.shape is BoxShape3D or not collider.shape.size.is_equal_approx(size * Vector3(0.97,1,0.97)):
			errors.append(kind+": collider no longer matches the measured prop")
		var anchor := body.visual.find_child("DisposalTicketAnchor",true,false) as Node3D
		var ticket := body.visual.find_child("Ticket",true,false) as Node3D
		if not expected.has("bag") and (anchor == null or ticket == null):
			errors.append(kind+": authored ticket position missing")
		elif anchor != null and ticket != null and (anchor.global_position.distance_to(ticket.global_position) > 0.01 or anchor.global_basis.z.normalized().dot(Vector3.BACK) < 0.99):
			errors.append(kind+": ticket does not follow the authored surface")
		var triangles := 0
		var materials := {}
		var textured := false
		for mesh: MeshInstance3D in body.visual.find_children("*","MeshInstance3D",true,false):
			for surface in mesh.mesh.get_surface_count():
				var arrays := mesh.mesh.surface_get_arrays(surface)
				var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
				for vertex: Vector3 in vertices:
					if not vertex.is_finite(): errors.append(kind+": nonfinite vertex")
				var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
				triangles += (indices.size() if not indices.is_empty() else vertices.size()) / 3
				var mat := mesh.get_active_material(surface) as StandardMaterial3D
				if mat != null:
					materials[mat.resource_name] = true
					textured = textured or mat.albedo_texture != null
		if kind == "scrap_chest" and not textured: errors.append("chest: embedded wood texture missing")
		rows.append({"kind":kind,"size_m":size,"mass_kg":body.mass,"triangles_with_ticket":triangles,"materials_with_ticket":materials.size(),"embedded_albedo":textured,"marker_normal":anchor.global_basis.z.normalized() if anchor != null else Vector3.ZERO,"ticket_distance_m":anchor.global_position.distance_to(ticket.global_position) if anchor != null and ticket != null else -1.0})
	return {"errors":errors,"props":rows}

func show_simple_lineup() -> void:
	clear_models()
	for i in 3:
		make_prop(["scrap_lamp","scrap_clock","scrap_vending"][i],true).position.x = (i-1) * 1.05
	var center := Vector3(0,0.72,0)
	camera.size = 2.15
	camera.position = center + Vector3(1.2,0.65,5.5)
	camera.look_at(center)

func show_fresh_pair(kind: String, rear: bool = false) -> void:
	clear_models()
	var extent: float = Scrap.find(kind).size
	var old := make_prop(kind,false)
	var fresh := make_prop(kind,true)
	old.position.x = -extent * 0.68
	fresh.position.x = extent * 0.68
	var center := Vector3(0,fresh.center.y,0)
	camera.size = extent * 1.65
	camera.position = center + Vector3(-1.3,0.9,-4 if rear else 4)
	camera.look_at(center)

func show_fresh_lineup(rear: bool = false) -> void:
	clear_models()
	make_prop("scrap_teapot",true).position.x = -0.40
	make_prop("scrap_travel_suitcase",true).position.x = 0.40
	var center := Vector3(0,0.24,0)
	camera.size = 1.15
	camera.position = center + Vector3(-1.1,0.75,-4 if rear else 4)
	camera.look_at(center)

func show_photo_prop(kind: String, rear: bool = false) -> void:
	clear_models()
	var body := make_prop(kind,true)
	var center: Vector3 = body.center
	camera.size = float(Scrap.find(kind).size) * 1.32
	camera.position = center + Vector3(1.4,1.1,-4 if rear else 4)
	camera.look_at(center)

func show_photo_lineup(kinds: Array = ["scrap_fan","scrap_tub","scrap_phone"], spacing: float = 1.22, frame: float = 2.55) -> void:
	clear_models()
	var max_height := 0.0
	for i in kinds.size():
		var body := make_prop(kinds[i],true)
		body.position.x = (float(i) - (kinds.size()-1) * 0.5) * spacing
		max_height = maxf(max_height,body.center.y * 2.0)
	var center := Vector3(0,max_height * 0.5,0)
	camera.size = frame
	camera.position = center + Vector3(1.2,1.25,6)
	camera.look_at(center)

func show_asset_pair(kind: String, new_file: String, rear: bool = false) -> void:
	clear_models()
	var extent: float = Scrap.find(kind).size
	var old := make_prop(kind,false)
	var fresh := make_prop(kind,true,new_file)
	old.position.x = -extent * 0.68
	fresh.position.x = extent * 0.68
	var center := Vector3(0,fresh.center.y,0)
	camera.size = extent * 1.65
	camera.position = center + Vector3(-1.3,0.9,-4 if rear else 4)
	camera.look_at(center)

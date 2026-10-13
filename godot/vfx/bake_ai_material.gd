extends SceneTree
# Scalar height -> tangent-space normal, local height-field cavity AO and roughness.
# Keeps the generated source unchanged. AO estimates only this relief, not mesh occlusion.
const DIR := "res://assets/vfx/ai_methods/"
var src: Image
func h(x: int,y: int) -> float:
	return src.get_pixel(posmod(x,512),posmod(y,512)).r
func _initialize() -> void:
	src=Image.load_from_file(ProjectSettings.globalize_path(DIR+"material_height.png"))
	src.resize(512,512,Image.INTERPOLATE_LANCZOS)
	var normal:=Image.create(512,512,false,Image.FORMAT_RGB8)
	var ao:=Image.create(512,512,false,Image.FORMAT_RGB8)
	var rough:=Image.create(512,512,false,Image.FORMAT_RGB8)
	for y in 512:
		for x in 512:
			var center:=h(x,y)
			var v:=Vector3(-(h(x+3,y)-h(x-3,y))*4.0,(h(x,y+3)-h(x,y-3))*4.0,1).normalized()
			normal.set_pixel(x,y,Color(v.x*.5+.5,v.y*.5+.5,v.z*.5+.5))
			var cavity:=0.0
			for d: Vector2i in [Vector2i(15,0),Vector2i(-15,0),Vector2i(0,15),Vector2i(0,-15)]:
				cavity+=maxf(h(x+d.x,y+d.y)-center,0.0)
			var a:=clampf(1.0-cavity*.65,.55,1.0)
			ao.set_pixel(x,y,Color(a,a,a))
			var r:=clampf(.28+(1.0-center)*.42,.28,.70)
			rough.set_pixel(x,y,Color(r,r,r))
	var ok:=normal.save_png(ProjectSettings.globalize_path(DIR+"material_normal.png"))==OK
	ok=ao.save_png(ProjectSettings.globalize_path(DIR+"material_ao.png"))==OK and ok
	ok=rough.save_png(ProjectSettings.globalize_path(DIR+"material_roughness.png"))==OK and ok
	print("GENERATED_MAPS_OK" if ok else "GENERATED_MAPS_FAIL")
	quit(0 if ok else 1)


extends Node
## 拠点の通路から外れた、街の小さな郵便ポスト。前回の完成済みモデルを再利用。
const MODEL := "res://assets/production/scrap/S057_street_mailbox_rebuilt.glb"
const HOME := Vector3(66.4, 0, 8.0)
var game: Node

func setup() -> void:
	build(game)

static func build(parent: Node3D) -> Node3D:
	var body := StaticBody3D.new()
	body.name = "MapStreetMailbox"
	body.position = HOME
	body.collision_layer = 1
	body.collision_mask = 0
	parent.add_child(body)
	var visual := (load(MODEL) as PackedScene).instantiate() as Node3D
	body.add_child(visual)
	var bounds := AABB()
	var first := true
	for mesh: MeshInstance3D in visual.find_children("*", "MeshInstance3D", true, false):
		var xf := mesh.transform
		var ancestor := mesh.get_parent() as Node3D
		while ancestor != visual:
			xf = ancestor.transform * xf
			ancestor = ancestor.get_parent() as Node3D
		var box: AABB = xf * mesh.mesh.get_aabb()
		bounds = box if first else bounds.merge(box)
		first = false
	var factor := 1.3 / bounds.size.y
	visual.scale = Vector3.ONE * factor
	visual.position = Vector3(-bounds.get_center().x,-bounds.position.y,-bounds.get_center().z) * factor
	var size := bounds.size * factor
	# 投函口のある本体・支柱・足を分けて、細い支柱のまわりは歩ける。
	for part: Array in [[Vector3(0,size.y*.65,0),size*Vector3(.92,.60,.88)],
			[Vector3(0,size.y*.23,0),size*Vector3(.29,.40,.36)],
			[Vector3(0,size.y*.033,0),size*Vector3(.75,.066,.70)]]:
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = part[1]
		shape.shape = box
		shape.position = part[0]
		body.add_child(shape)
	return body

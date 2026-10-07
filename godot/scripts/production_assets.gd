extends RefCounted
## Owner-provided assets, authored in metres. Parent supplies the walkable floor.
const BASE := "res://assets/production/"

static func decorate(parent: Node3D, area: String) -> Node3D:
	var root := Node3D.new()
	root.name = "ProductionDecor_" + area
	parent.add_child(root)
	match area:
		"studio":
			var room := _model(root, "studio.glb", Vector3.ZERO)
			# Open dollhouse: roof and camera-facing south wall are deliberately hidden.
			for node in room.find_children("MODULE_*", "Node3D", true, false):
				if node.name.begins_with("MODULE_07") or node.name.begins_with("MODULE_05") or node.name.begins_with("MODULE_09") or node.name.begins_with("MODULE_10"):
					node.visible = false
			_box(root, Vector3(0, 2.1, -5.1), Vector3(8.4, 4.2, 0.2))
			_box(root, Vector3(-4.1, 2.1, 0), Vector3(0.2, 4.2, 10))
			_box(root, Vector3(4.1, 2.1, 0), Vector3(0.2, 4.2, 10))
		"office":
			var room := _model(root, "studio.glb", Vector3.ZERO)
			for node in room.find_children("MODULE_*", "Node3D", true, false):
				node.visible = node.name.begins_with("MODULE_12") or node.name.begins_with("MODULE_13")
			_model(root, "cleaning_cart.glb", Vector3(2.5, 0, 2.0))
			_box(root, Vector3(2.5, 0.5, 2.0), Vector3(1.2, 1, 0.6))
		"scrapyard":
			_model(root, "lift_cart.glb", Vector3(-2.5, 0, -1.6), 0.35)
			_model(root, "cleaning_cart.glb", Vector3(2.3, 0, 1.5), -0.4)
			_box(root, Vector3(-2.5, 0.3, -1.6), Vector3(1.3, 0.6, 0.7))
			_box(root, Vector3(2.3, 0.5, 1.5), Vector3(1.2, 1, 0.6))
		"yard":
			_model(root, "shutter.glb", Vector3(0, 0, -3.5))
			# Hose reel is a close-up prop; only one instance to limit its 129k-triangle cost.
			_model(root, "hose_reel.glb", Vector3(3.2, 1.2, -3.3))
			_box(root, Vector3(0, 1.5, -3.5), Vector3(3.2, 3, 0.18))
	return root

static func _model(parent: Node3D, filename: String, at: Vector3, yaw: float = 0.0) -> Node3D:
	var packed := load(BASE + filename) as PackedScene
	var node := packed.instantiate() as Node3D
	node.name = filename.get_basename()
	parent.add_child(node)
	node.position = at
	node.rotation.y = yaw
	return node

static func _box(parent: Node3D, at: Vector3, size: Vector3) -> void:
	var body := StaticBody3D.new()
	body.name = "DecorCollision"
	parent.add_child(body)
	body.position = at
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collider.shape = shape
	body.add_child(collider)

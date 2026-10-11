extends Node3D
# Shared deterministic review stage. Cylinders/glove are scale references, not VFX.
var effect: Node3D
var frame := 0
var expired_effects := 0
var glove: MeshInstance3D

func _ready() -> void:
	var world := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.085, 0.12, 0.16)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color.WHITE
	env.ambient_light_energy = 0.8
	world.environment = env
	add_child(world)
	var ground := PlaneMesh.new()
	ground.size = Vector2(15, 15)
	_mesh(ground, Vector3.ZERO, Color(0.18, 0.24, 0.28))
	var person := CapsuleMesh.new()
	person.radius = 0.20
	person.height = 1.7
	_mesh(person, Vector3(0.65, 0.85, -0.7), Color(0.65, 0.71, 0.72))
	var head := SphereMesh.new()
	head.radius = 0.22
	head.height = 0.44
	_mesh(head, Vector3(0.65, 1.55, -0.7), Color(0.88, 0.74, 0.50))
	var hand := BoxMesh.new()
	hand.size = Vector3(0.32, 0.28, 0.29)
	glove = _mesh(hand, Vector3(-0.85, 1.05, 0), Color(0.86, 0.30, 0.10))
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-45, -35, 0)
	sun.light_energy = 1.0
	sun.shadow_enabled = true
	add_child(sun)
	var camera := Camera3D.new()
	camera.position = Vector3(3.4, 2.1, 4.8)
	camera.fov = 35
	add_child(camera)
	camera.look_at(Vector3(0, 1.05, 0))
	camera.make_current()
	set_physics_process(false)

func _mesh(mesh: Mesh, pos: Vector3, color: Color) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.85
	node.material_override = material
	add_child(node)
	node.position = pos
	return node

func begin(path: String, random_seed: int = 431) -> void:
	if is_instance_valid(effect):
		effect.free()
	seed(random_seed)
	frame = 0
	expired_effects = 0
	glove.position.x = -0.85
	var script = load(path)
	effect = script.spawn(self, Vector3(0, 1.05, 0), 1.0, Vector3.RIGHT)
	effect.set_process(false)
	effect._process(0.0)
	set_physics_process(true)

func _physics_process(_delta: float) -> void:
	frame += 1
	var time := frame / 60.0
	if time < 0.12:
		glove.position.x = lerpf(-0.85, -0.05, pow(time / 0.12, 2))
	else:
		glove.position.x = lerpf(-0.05, -0.85, smoothstep(0.16, 0.38, time))
	if is_instance_valid(effect):
		# Invoke the base clock once per real physics tick, independent of GPU speed.
		effect._process(1.0 / 60.0)
	if frame >= 78:
		expired_effects = 0
		for member in get_tree().get_nodes_in_group("vfx"):
			if is_ancestor_of(member):
				expired_effects += 1

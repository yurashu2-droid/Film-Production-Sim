extends RefCounted
# 超能力の演出（vfx/esper/）をラボで見せるための、舞台の部品：能力者（ゲームのキャラ）と小道具（ゲームのモデル）を置く。
const CastVisual := preload("res://scripts/cast_visual.gd")

const PROPS := {
	"box": "res://assets/props/P069_apple_box.glb",
	"basket": "res://assets/props/P070_prop_basket.glb",
	"fish": "res://assets/props/P039_rubber_fish.glb",
	"can": "res://assets/props/P057_film_can.glb",
	"phone": "res://assets/props/P018_rotary_phone.glb",
	"reel": "res://assets/props/P056_film_reel.glb",
	"tape": "res://assets/props/P067_gaffer_tape.glb",
	"bag": "res://assets/props/P068_sandbag.glb",
	"crown": "res://assets/props/P027_paper_crown.glb",
	"rock": "res://assets/props/foam_rock.glb",
	"bino": "res://assets/props/P019_binoculars.glb",
	"spray": "res://assets/props/P090_spray_bottle.glb",
	"flat": "res://assets/props/scenic_flat.glb",
	"standin": "res://assets/gear/P04_Actor_StandIn.glb",
}


# キャラを置く。look＝向く先（水平の向き）。pose は cast_visual.gd の動きの名前（carry_idle＝両腕を前へ出した構え）
static func figure(parent: Node, tag: String, pos: Vector3, look: Vector3, pose: String = "idle") -> Node3D:
	var vis: Node3D = CastVisual.new()
	parent.add_child(vis)
	vis.setup(tag)
	vis.position = pos
	vis.rotation.y = atan2(look.x, look.z)      # 素材は +Z 向き
	vis.play(pose, 0.0)
	return vis


# 小道具を置く。足もとが pos に来る。戻り値のメタ "rest"＝足もとからモデルの原点までの高さ、"size"＝大きさ
static func prop(parent: Node, key: String, pos: Vector3, yaw: float = 0.0) -> Node3D:
	var node: Node3D = (load(PROPS[key]) as PackedScene).instantiate()
	parent.add_child(node)
	var box := AABB()
	var first := true
	for mesh: MeshInstance3D in node.find_children("*", "MeshInstance3D", true, false):
		var part: AABB = (node.global_transform.affine_inverse() * mesh.global_transform) * mesh.get_aabb()
		box = part if first else box.merge(part)
		first = false
	node.set_meta("rest", -box.position.y)
	node.set_meta("size", box.size)
	node.set_meta("mid", box.get_center())
	node.position = pos + Vector3(0, -box.position.y, 0)
	node.rotation.y = yaw
	return node


static func hand(vis: Node3D, side: String) -> Vector3:
	var skel: Skeleton3D = vis.skel
	var bone := skel.find_bone("HAND." + side)
	if bone < 0:
		return vis.chest_pos()
	return skel.global_transform * skel.get_bone_global_pose(bone).origin


static func hands_mid(vis: Node3D) -> Vector3:
	return (hand(vis, "L") + hand(vis, "R")) * 0.5


# 額のあたり（念の出どころ）
static func brow(vis: Node3D) -> Vector3:
	return vis.head_pos() + vis.global_basis.z.normalized() * 0.18 - Vector3(0, 0.12, 0)


static func ease_io(k: float) -> float:
	return smoothstep(0.0, 1.0, clampf(k, 0.0, 1.0))

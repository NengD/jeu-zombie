extends SceneTree
# Rend les icônes des armes à partir des modèles 3D (fond transparent).
const IDS = ["couteau","batte","batte_cloutee","machette","machette_art","hache","matraque","pistolet","revolver","fusil_pompe","fusil_artisanal","carabine","fusil_assaut"]
var idx := -1
var wait := 0
var vp: SubViewport
var holder: Node3D
var cam: Camera3D
func _initialize():
	vp = SubViewport.new(); vp.transparent_bg = true; vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.own_world_3d = true
	root.add_child(vp)
	var env := WorldEnvironment.new(); var e := Environment.new(); e.background_mode = Environment.BG_CLEAR_COLOR
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; e.ambient_light_color = Color(0.75,0.75,0.75); e.ambient_light_energy = 0.9
	env.environment = e; vp.add_child(env)
	var sun := DirectionalLight3D.new(); sun.rotation_degrees = Vector3(-35, 60, 0); sun.light_energy = 1.3; vp.add_child(sun)
	var fill := DirectionalLight3D.new(); fill.rotation_degrees = Vector3(-20, 140, 0); fill.light_energy = 0.4; vp.add_child(fill)
	cam = Camera3D.new(); cam.projection = Camera3D.PROJECTION_ORTHOGONAL; vp.add_child(cam)
	holder = Node3D.new(); vp.add_child(holder)
func _aabb(n: Node, xf: Transform3D, acc: Array):
	if n is MeshInstance3D:
		var a: AABB = (xf * n.transform) * n.get_aabb()
		acc[0] = a if acc[0] == null else acc[0].merge(a)
	var t = xf * n.transform if n is Node3D else xf
	for c in n.get_children(): _aabb(c, t, acc)
func _process(d):
	if wait > 0:
		wait -= 1
		if wait == 0:
			vp.get_texture().get_image().save_png("/mnt/user-data/outputs/jeu-zombie/icones/%s.png" % IDS[idx])
		return false
	idx += 1
	if idx >= IDS.size():
		quit(); return false
	for c in holder.get_children(): c.queue_free()
	var id = IDS[idx]
	var sz = root.get_node("Items").size(id)
	vp.size = Vector2i(sz.x * 128, sz.y * 128)
	var m = load("res://modeles/%s.glb" % id).instantiate()
	var piv := Node3D.new(); holder.add_child(piv); piv.add_child(m)
	if sz.y > sz.x: piv.rotation_degrees = Vector3(90, 0, 0)
	piv.rotation_degrees.y += 0.0
	var acc = [null]; _aabb(piv, Transform3D.IDENTITY, acc)
	var a: AABB = acc[0]
	piv.position = -a.get_center()
	# caméra latérale (vue de profil, légère perspective 3/4)
	cam.look_at_from_position(Vector3(3, 0.35, 0.0), Vector3.ZERO)
	var aspect := float(vp.size.x) / vp.size.y
	var need_h := maxf(a.size.y, (a.size.z if sz.y <= sz.x else a.size.x) / aspect)
	if sz.y > sz.x: need_h = maxf(a.size.y, a.size.z / aspect)
	cam.size = need_h * 1.12
	wait = 4
	return false

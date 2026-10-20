extends SceneTree
## Rend les icônes (fond transparent) des armes à feu, armes blanches D_U, grenade, accessoires et munitions
## à partir de leurs modèles 3D. Sortie : res://icones/<id>.png (taille = cases d'inventaire × 128 px).
## Lancer (avec affichage) : godot --path . -s outils/godot/generer_icones_armes.gd

var ids := []
var idx := -1
var wait := 0
var vp: SubViewport
var holder: Node3D
var cam: Camera3D


func _initialize() -> void:
	var items = root.get_node("Items")
	for id in items.DB:
		var t: String = items.DB[id].get("type", "")
		if t in ["gun", "lancer", "accessoire"] or id in ["couteau_km2000"] or (t == "ammo" and items.DB[id].has("modele")):
			if _modele(id) != "":
				ids.append(id)
	vp = SubViewport.new()
	vp.transparent_bg = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.own_world_3d = true
	root.add_child(vp)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_CLEAR_COLOR
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.8, 0.8, 0.8)
	e.ambient_light_energy = 1.0
	env.environment = e
	vp.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-35, 60, 0)
	sun.light_energy = 1.4
	vp.add_child(sun)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-20, 140, 0)
	fill.light_energy = 0.5
	vp.add_child(fill)
	cam = Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	vp.add_child(cam)
	holder = Node3D.new()
	vp.add_child(holder)


func _modele(id: String) -> String:
	var items = root.get_node("Items")
	var info: Dictionary = items.info(id)
	var nom := id
	if info.get("type", "") == "accessoire":
		nom = str(Accessoires.MODELES.get(id, ""))
	elif info.get("type", "") == "ammo":
		nom = str(info.get("modele", ""))
	if nom == "" or not ResourceLoader.exists("res://modeles/armes/%s.scn" % nom):
		return ""
	return "res://modeles/armes/%s.scn" % nom


func _aabb(n: Node, xf: Transform3D, acc: Array) -> void:
	var t: Transform3D = xf * n.transform if n is Node3D else xf
	if n is MeshInstance3D and (n as MeshInstance3D).visible:
		var a: AABB = t * n.get_aabb()
		acc[0] = a if acc[0] == null else acc[0].merge(a)
	for c in n.get_children():
		_aabb(c, t, acc)


func _process(_d: float) -> bool:
	if wait > 0:
		wait -= 1
		if wait == 0:
			vp.get_texture().get_image().save_png("res://icones/%s.png" % ids[idx])
		return false
	idx += 1
	if idx >= ids.size():
		print(ids.size(), " icônes")
		quit()
		return false
	for c in holder.get_children():
		c.queue_free()
	var id: String = ids[idx]
	var items = root.get_node("Items")
	var sz: Vector2i = items.size(id)
	var munition: bool = items.info(id).get("type", "") == "ammo"
	vp.size = Vector2i(sz.x * 128, sz.y * 128)
	var m: Node3D = load(_modele(id)).instantiate()
	var piv := Node3D.new()
	holder.add_child(piv)
	piv.add_child(m)
	if sz.y > sz.x:
		piv.rotation_degrees = Vector3(90, 0, 0)
	if munition:
		# une petite pile de trois cartouches
		for k in range(1, 3):
			var c2: Node3D = load(_modele(id)).instantiate()
			piv.add_child(c2)
			c2.position = Vector3(0.0, -k * 0.016, k * 0.012)
	var acc = [null]
	_aabb(piv, Transform3D.IDENTITY, acc)
	var a: AABB = acc[0]
	piv.position = -a.get_center()
	cam.look_at_from_position(Vector3(3, 0.6, 0.0), Vector3.ZERO)
	var aspect := float(vp.size.x) / vp.size.y
	# caméra sur +X : largeur à l'écran = z, hauteur = y
	cam.size = maxf(a.size.y, a.size.z / aspect) * 1.12
	wait = 4
	return false

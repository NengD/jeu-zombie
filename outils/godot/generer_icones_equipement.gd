extends SceneTree
## Rend les icônes (fond transparent) de l'équipement porté à partir de ses modèles 3D (modeles/equipement/*.res,
## réglages de scripts/equipement_visuel.gd). Sortie : res://icones/<id>.png (cases d'inventaire × 128 px).
## Seulement les objets sans icône, ou ceux donnés en argument.
## Lancer (avec affichage) : godot --path . -s res://outils/godot/generer_icones_equipement.gd [-- id1 id2…]

const Equip = preload("res://scripts/equipement_visuel.gd")


func _initialize() -> void:
	_go.call_deferred()


func _go() -> void:
	var items = root.get_node("Items")
	var ids: Array = OS.get_cmdline_user_args()
	if ids.is_empty():
		for id in Equip.PIECES:
			if not ResourceLoader.exists("res://icones/%s.png" % id) and not ResourceLoader.exists("res://icones/%s.svg" % id):
				ids.append(id)
	var vp := SubViewport.new()
	vp.transparent_bg = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.own_world_3d = true
	root.add_child(vp)
	var lum := DirectionalLight3D.new()
	lum.rotation = Vector3(-0.9, 0.6, 0)
	vp.add_child(lum)
	var lum2 := DirectionalLight3D.new()
	lum2.rotation = Vector3(-0.3, -2.2, 0)
	lum2.light_energy = 0.45
	vp.add_child(lum2)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_CLEAR_COLOR
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.75, 0.75, 0.75)
	vp.add_child(env)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	vp.add_child(cam)
	for id in ids:
		var p: Dictionary = Equip.PIECES.get(id, {})
		if p.is_empty():
			continue
		var mesh: Mesh = load(Equip.DOSSIER % p.m)
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		if p.has("col"):
			for s in mesh.get_surface_count():
				mi.set_surface_override_material(s, Equip.Perso._recolore(mesh.surface_get_material(s), p.col))
		# vu de trois quarts avant (sacs : de dos, côté extérieur)
		var sac: bool = p.os != "Head"
		mi.rotation = Vector3(0.25, (PI if sac else 0.0) + 0.6, 0) + Vector3(p.get("rot", Vector3.ZERO)) * PI / 180.0
		vp.add_child(mi)
		var sz: Vector2i = items.size(id)
		vp.size = Vector2i(sz.x * 128, sz.y * 128)
		var a: AABB = mi.transform * mesh.get_aabb()
		var aspect := float(vp.size.x) / vp.size.y
		cam.keep_aspect = Camera3D.KEEP_HEIGHT
		cam.size = maxf(a.size.y, a.size.x / aspect) * 1.1
		cam.position = a.get_center() + Vector3(0, 0, 5)
		cam.look_at(a.get_center())
		for k in 4:
			await process_frame
		vp.get_texture().get_image().save_png("res://icones/%s.png" % id)
		print("icône ", id)
		mi.queue_free()
	quit()

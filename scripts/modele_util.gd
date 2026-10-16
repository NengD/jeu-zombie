extends RefCounted
## Outils pour les modèles 3D (.glb créés dans Blender) : chargement,
## animations, ombres. Si un modèle manque, le jeu garde les formes simples.

static func charger(path: String) -> Node3D:
	if ResourceLoader.exists(path):
		var res = load(path)
		if res is PackedScene:
			return res.instantiate()
	return null


static func anim_player(n: Node) -> AnimationPlayer:
	return n.find_child("AnimationPlayer", true, false) as AnimationPlayer


static func boucler(ap: AnimationPlayer, noms: Array) -> void:
	for nom in noms:
		if ap.has_animation(nom):
			ap.get_animation(nom).loop_mode = Animation.LOOP_LINEAR


static func geometries(n: Node, out: Array = []) -> Array:
	if n is GeometryInstance3D:
		out.append(n)
	for c in n.get_children():
		geometries(c, out)
	return out


static func ombres(n: Node, mode: int) -> void:
	for g in geometries(n):
		g.cast_shadow = mode


static func distance_visible(n: Node, dist: float) -> void:
	for g in geometries(n):
		g.visibility_range_end = dist


static func squelette(n: Node) -> Skeleton3D:
	return _find_skel(n)


static func _find_skel(n: Node) -> Skeleton3D:
	for c in n.get_children():
		if c is Skeleton3D:
			return c
		var s := _find_skel(c)
		if s:
			return s
	return null


static var _teintes := {}


## Teinte une partie d'un modèle (matériau nommé dans Blender) pour varier les zombies.
static func teinter(n: Node, nom_materiau: String, couleur: Color) -> void:
	for g in geometries(n):
		if not (g is MeshInstance3D) or g.mesh == null:
			continue
		var mi: MeshInstance3D = g
		for s in mi.mesh.get_surface_count():
			var m := mi.mesh.surface_get_material(s)
			if m and m.resource_name.begins_with(nom_materiau) and m is BaseMaterial3D:
				var cle := "%s_%s" % [m.get_instance_id(), couleur.to_html()]
				if not _teintes.has(cle):
					var copie: BaseMaterial3D = m.duplicate()
					copie.albedo_color = couleur
					_teintes[cle] = copie
				mi.set_surface_override_material(s, _teintes[cle])

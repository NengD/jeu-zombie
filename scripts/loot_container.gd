extends StaticBody3D
## Meuble fouillable (armoire, casier, caisse…), caisse de stockage ou tas d'objets au sol.
## Son contenu est une grille d'inventaire ; le butin est tiré au sort à la première ouverture.

var label := "Meuble"
var table := "maison"
var rolls := 2
var searched := false
var is_storage := false
var grille: Grille = null
var mesh_i: MeshInstance3D
var mat: StandardMaterial3D
var box_size := Vector3.ONE
var modele: Node3D = null
var uid := -1          # numéro du meuble dans le monde généré (pour la sauvegarde)


func setup(p_label: String, p_table: String, size: Vector3, col: Color, p_rolls := 2) -> void:
	label = p_label
	table = p_table
	add_to_group("conteneurs")
	rolls = p_rolls
	box_size = size
	collision_layer = Game.LAYER_WORLD | Game.LAYER_INTERACT
	collision_mask = 0
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	cs.position.y = size.y / 2.0
	add_child(cs)
	mesh_i = MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mesh_i.mesh = bm
	mesh_i.position.y = size.y / 2.0
	mat = StandardMaterial3D.new()
	mat.albedo_color = col
	mat.roughness = 0.85
	mesh_i.material_override = mat
	mesh_i.visibility_range_end = 140.0
	add_child(mesh_i)


## Remplace la boîte par un modèle 3D (meuble réaliste), tourné de « angle » autour de Y.
func set_modele(id: String, angle: float) -> void:
	var n := Decor.ajuste(id, Vector3(box_size.x, box_size.y, box_size.z) if is_zero_approx(fmod(angle, PI)) else Vector3(box_size.z, box_size.y, box_size.x))
	if n == null:
		return
	n.rotation.y = angle
	add_child(n)
	Decor.distance(n, 70.0)
	mesh_i.visible = false
	modele = n


## Habille la boîte d'une texture du décor (appareils sans modèle 3D : réfrigérateur…).
func set_texture(nom: String) -> void:
	var p := "res://textures/%s_albedo.jpg" % nom
	if not ResourceLoader.exists(p):
		return
	mat.albedo_texture = load(p)
	mat.uv1_triplanar = true
	mat.metallic = 0.3
	if ResourceLoader.exists("res://textures/%s_normal.png" % nom):
		mat.normal_enabled = true
		mat.normal_texture = load("res://textures/%s_normal.png" % nom)


## Transforme en rangement du joueur (caisse, tas au sol).
func make_storage(w: int, h: int) -> void:
	is_storage = true
	searched = true
	grille = Grille.creer(label, w, h)


func _grid_size() -> Vector2i:
	var vol := box_size.x * box_size.y * box_size.z
	if label == "Rayon":
		return Vector2i(6, 5)
	if vol > 1.0:
		return Vector2i(6, 4)
	if vol > 0.4:
		return Vector2i(5, 3)
	return Vector2i(4, 3)


## Génère le contenu à la première ouverture.
func ensure_contents() -> void:
	if grille != null:
		return
	var gs := _grid_size()
	grille = Grille.creer(label, gs.x, gs.y)
	var r := rolls
	if Game.player and not is_storage:
		r += (1 if Game.player.prog.a("fouilleur") else 0) + (1 if Game.player.prog.a("vue_percante") else 0)
	var found := Items.roll_loot(table, r)
	for id in found:
		if Items.grid(id).x > 0:
			for i in int(found[id]):
				grille.ajouter_entree(Game.player.nouvelle_entree(id) if Game.player else {"id": id, "n": 1, "x": 0, "y": 0, "r": false, "contenu": null})
		else:
			grille.ajouter(id, int(found[id]))
	# munitions dans les armes trouvées
	if Game.player:
		for e in grille.entrees:
			var w := Items.info(e.id)
			if w.get("type", "") == "gun" and not Game.player.mags.has(e.id):
				Game.player.mags[e.id] = int(int(w.mag) * randf_range(0.2, 1.0))


func get_prompt() -> String:
	if is_storage:
		return "[F] Ouvrir : %s" % label
	if searched and grille and grille.vide():
		return "%s (vide)" % label
	return "[F] Fouiller : %s" % label


func interact(player: Node) -> void:
	if not searched:
		searched = true
		if not is_storage and player.has_method("count"):
			player.prog.gagner("exploration", 6)
			if randf() < 0.3:
				player.gagner_argent(randi_range(5, 25))
		if modele == null:
			mat.albedo_color = mat.albedo_color.darkened(0.35)
		Game.make_noise(global_position, 5.0)
		Game.play_ui("fouille", -4.0)
	ensure_contents()
	player.open_storage(self)


## Appelé quand l'inventaire se ferme.
func on_closed() -> void:
	if is_in_group("tas_sol") and grille and grille.vide():
		queue_free()


## Surbrillance (liseré doré) : posée par le joueur sur les contenants proches qui ont encore quelque chose.
static var _mat_surbrillance: ShaderMaterial = null
var surligne := false


func a_donner() -> bool:
	if is_storage and not is_in_group("tas_sol"):
		return false   # rangements du joueur : pas de surbrillance
	ensure_contents()
	return grille != null and not grille.vide()


func surligner(on: bool) -> void:
	if on == surligne:
		return
	surligne = on
	if _mat_surbrillance == null:
		_mat_surbrillance = ShaderMaterial.new()
		_mat_surbrillance.shader = preload("res://shaders/surbrillance.gdshader")
	var cible: Node = modele if modele != null else mesh_i
	if cible == null:
		return
	var geos: Array = cible.find_children("*", "GeometryInstance3D", true, false)
	if cible is GeometryInstance3D:
		geos.append(cible)
	for gi in geos:
		(gi as GeometryInstance3D).material_overlay = _mat_surbrillance if on else null

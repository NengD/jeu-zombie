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


func setup(p_label: String, p_table: String, size: Vector3, col: Color, p_rolls := 2) -> void:
	label = p_label
	table = p_table
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
	var found := Items.roll_loot(table, rolls)
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
		mat.albedo_color = mat.albedo_color.darkened(0.35)
		Game.make_noise(global_position, 5.0)
		Game.play_ui("fouille", -4.0)
	ensure_contents()
	player.open_storage(self)


## Appelé quand l'inventaire se ferme.
func on_closed() -> void:
	if is_in_group("tas_sol") and grille and grille.vide():
		queue_free()

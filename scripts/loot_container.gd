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


# ---------------------------------------------------------------- tas au sol : objets visibles
const VISUEL_MAX := 5
const ModeleUtil = preload("res://scripts/modele_util.gd")
const ArcModele = preload("res://scripts/arc.gd")
const EquipVisuel = preload("res://scripts/equipement_visuel.gd")
# objets sans modèle : petite boîte (taille, couleur)
const FORME_TYPE := {
	"material": [Vector3(0.22, 0.08, 0.16), Color(0.45, 0.38, 0.3)],
	"food": [Vector3(0.14, 0.06, 0.1), Color(0.55, 0.25, 0.2)],
	"drink": [Vector3(0.08, 0.2, 0.08), Color(0.35, 0.45, 0.55)],
	"heal": [Vector3(0.1, 0.05, 0.07), Color(0.85, 0.85, 0.82)],
	"armor": [Vector3(0.32, 0.06, 0.26), Color(0.33, 0.35, 0.28)],
	"placeable": [Vector3(0.3, 0.12, 0.2), Color(0.45, 0.33, 0.2)],
}
const FORME_ID := {
	"batterie": [Vector3(0.26, 0.18, 0.17), Color(0.12, 0.12, 0.13)],
	"pneu": [Vector3(0.6, 0.2, 0.6), Color(0.08, 0.08, 0.08)],
	"buche": [Vector3(0.5, 0.16, 0.16), Color(0.4, 0.27, 0.15)],
	"planche": [Vector3(0.8, 0.03, 0.14), Color(0.6, 0.45, 0.28)],
	"pierre": [Vector3(0.2, 0.14, 0.17), Color(0.5, 0.5, 0.48)],
	"minerai": [Vector3(0.2, 0.14, 0.17), Color(0.42, 0.3, 0.25)],
	"ciment": [Vector3(0.45, 0.12, 0.3), Color(0.7, 0.68, 0.62)],
	"tissu": [Vector3(0.26, 0.03, 0.2), Color(0.7, 0.65, 0.55)],
	"viande_crue": [Vector3(0.16, 0.05, 0.12), Color(0.65, 0.18, 0.16)],
	"viande_cuite": [Vector3(0.16, 0.05, 0.12), Color(0.45, 0.25, 0.12)],
	"soda": [Vector3(0.07, 0.12, 0.07), Color(0.75, 0.12, 0.1)],
	"viande_sechee": [Vector3(0.18, 0.025, 0.06), Color(0.32, 0.17, 0.1)],
	"peau": [Vector3(0.4, 0.02, 0.3), Color(0.5, 0.36, 0.24)],
	"cuir": [Vector3(0.36, 0.02, 0.26), Color(0.36, 0.22, 0.12)],
	"fleche": [Vector3(0.015, 0.015, 0.7), Color(0.55, 0.42, 0.25)],
}
# objets qui reprennent le modèle d'un autre
const MODELE_ID := {"soda": "", "ration": "barre", "antidouleur": "bandage", "medicament": "trousse",
	"alcool": "bouteille2", "bouillon": "conserve_ouverte", "ragout": "conserve_ouverte"}
static var _formes := {}
var _sig_tas := ""
var _t_tas := 0.0
var _visuel: Node3D = null


func _ready() -> void:
	set_process(is_in_group("tas_sol"))


func _process(delta: float) -> void:
	_t_tas -= delta
	if _t_tas <= 0.0:
		_t_tas = 0.5
		maj_visuel_tas()


## Montre au sol les objets du tas (arme, conserve, bandage…) au lieu d'un paquet : jusqu'à VISUEL_MAX objets
## différents en couronne ; refait seulement quand le contenu change.
func maj_visuel_tas() -> void:
	if grille == null:
		return
	var ids: Array = []
	for e in grille.entrees:
		if not ids.has(e.id):
			ids.append(e.id)
		if ids.size() >= VISUEL_MAX:
			break
	var sig := ",".join(ids)
	if sig == _sig_tas:
		return
	_sig_tas = sig
	if _visuel:
		_visuel.queue_free()
		_visuel = null
		modele = null
	if ids.is_empty():
		return
	_visuel = Node3D.new()
	add_child(_visuel)
	var h := hash(get_instance_id())
	for i in ids.size():
		var n := _modele_objet(ids[i])
		if n == null:
			continue
		var pivot := Node3D.new()
		_visuel.add_child(pivot)
		pivot.add_child(n)
		# posé à plat, centré sur sa boîte, en couronne autour du centre du tas
		var b := _boite_noeud(n, n.transform)
		n.position -= Vector3(b.get_center().x, b.position.y, b.get_center().z)
		var a := float(i) / ids.size() * TAU + float(h % 100) * 0.06
		var r := 0.0 if ids.size() == 1 else 0.18 + 0.03 * ids.size()
		pivot.position = Vector3(cos(a) * r, 0.0, sin(a) * r)
		pivot.rotation.y = a * 1.7 + float(h % 7)
		ModeleUtil.distance_visible(pivot, 45.0)
	mesh_i.visible = false
	modele = _visuel
	if surligne:   # surbrillance remise sur les nouveaux objets
		surligne = false
		surligner(true)


func _modele_objet(id: String) -> Node3D:
	var info: Dictionary = Items.info(id)
	var t := str(info.get("type", ""))
	var src: String = MODELE_ID.get(id, id)
	if src != "" and ResourceLoader.exists("res://modeles/objets/%s.scn" % src):
		return ModeleUtil.charger("res://modeles/objets/%s.scn" % src)
	if t in ["gun", "melee", "lancer", "outil", "accessoire"] or ResourceLoader.exists("res://modeles/armes/%s.scn" % id):
		var m := ModeleUtil.arme(id)
		if m:
			# couché sur le flanc
			var p := Node3D.new()
			p.add_child(m)
			m.rotation.z = PI / 2.0
			return p
	if t == "arc":
		var arc := ArcModele.new()
		var p2 := Node3D.new()
		p2.add_child(arc)
		arc.rotation.x = PI / 2.0
		return p2
	if t == "ammo":
		var cart := "cart_" + id.trim_prefix("mun_")
		if ResourceLoader.exists("res://modeles/armes/%s.scn" % cart):
			# boîte de munitions entrouverte et quelques cartouches à côté
			var tas := _boite_forme([Vector3(0.11, 0.05, 0.075), Color(0.55, 0.42, 0.25)])
			for k in 3:
				var c := ModeleUtil.charger("res://modeles/armes/%s.scn" % cart)
				c.scale = Vector3.ONE * 1.4
				c.rotation = Vector3(0, k * 1.9, PI / 2.0)
				c.position = Vector3(0.09 + k * 0.025, -0.02, k * 0.02 - 0.02)
				tas.add_child(c)
			return tas
	if t == "armor" and EquipVisuel.PIECES.has(id):
		var piece: Dictionary = EquipVisuel.PIECES[id]
		var chemin := "res://modeles/equipement/%s.res" % piece.m
		if ResourceLoader.exists(chemin):
			var mi := MeshInstance3D.new()
			mi.mesh = load(chemin)
			if piece.has("col"):
				var mc := StandardMaterial3D.new()
				mc.albedo_color = piece.col
				mi.material_override = mc
			return mi
	if t == "armor" and id.begins_with("sac") and ResourceLoader.exists("res://modeles/objets/sac_dos.scn"):
		return ModeleUtil.charger("res://modeles/objets/sac_dos.scn")   # sac sans modèle porté
	if id == "soda":
		# canette (cylindre) couchée
		var can := MeshInstance3D.new()
		var cy := CylinderMesh.new()
		cy.top_radius = 0.033
		cy.bottom_radius = 0.033
		cy.height = 0.12
		cy.radial_segments = 10
		can.mesh = cy
		var ms := StandardMaterial3D.new()
		ms.albedo_color = Color(0.75, 0.12, 0.1)
		ms.metallic = 0.6
		ms.roughness = 0.35
		can.material_override = ms
		can.rotation.z = PI / 2.0
		can.position.y = 0.033
		var pc := Node3D.new()
		pc.add_child(can)
		return pc
	return _boite_forme(FORME_ID.get(id, FORME_TYPE.get(t, [Vector3(0.15, 0.08, 0.12), Color(0.4, 0.38, 0.34)])))


func _boite_forme(forme: Array) -> MeshInstance3D:
	var cle := str(forme)
	if not _formes.has(cle):
		var bm := BoxMesh.new()
		bm.size = forme[0]
		var mf := StandardMaterial3D.new()
		mf.albedo_color = forme[1]
		mf.roughness = 0.9
		bm.material = mf
		_formes[cle] = bm
	var mb := MeshInstance3D.new()
	mb.mesh = _formes[cle]
	return mb


static func _boite_noeud(n: Node, xf: Transform3D) -> AABB:
	var b := AABB()
	var premier := true
	if n is MeshInstance3D and (n as MeshInstance3D).mesh:
		b = xf * (n as MeshInstance3D).get_aabb()
		premier = false
	for c in n.get_children():
		if c is Node3D:
			var bc := _boite_noeud(c, xf * (c as Node3D).transform)
			if bc.size != Vector3.ZERO:
				b = bc if premier else b.merge(bc)
				premier = false
	return b


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
			var arg: Array = Items.ARGENT_TABLE.get(table, [0.3, 5, 25])
			if randf() < float(arg[0]):
				player.gagner_argent(randi_range(int(arg[1]), int(arg[2])))
		if modele == null:
			mat.albedo_color = mat.albedo_color.darkened(0.35)
		Game.make_noise(global_position, 5.0)
		Game.play_ui("fouille", -4.0)
		if not is_storage:
			Game.maj_lieu_fouille(global_position)
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

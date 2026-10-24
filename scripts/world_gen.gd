extends Node3D
## Génère le monde : ville (majoritaire), campagne, points stratégiques,
## meubles fouillables et zombies gardiens.
## Toute la géométrie statique est regroupée par « chunks » pour les performances.
## Pour remplacer plus tard par des modèles Blender : remplacer les appels à
## _building() / _car() / arbres par des instances de scènes .glb.

const LootContainer = preload("res://scripts/loot_container.gd")
const Porte = preload("res://scripts/porte.gd")
const Relief = preload("res://scripts/relief.gd")
const Neon = preload("res://scripts/neon.gd")
const Morceaux = preload("res://scripts/morceaux.gd")

const BLOCK := 46.0      # taille d'un pâté de maisons (route comprise)
const ROAD := 10.0       # largeur des routes
const NB := 7            # nombre de pâtés par côté
const CHUNK := 64.0
const VERSION_MONDE := 12 # à augmenter quand la génération change (numéros des meubles dans les sauvegardes)
const WALL_T := 0.3
const INT_H := 3.3       # hauteur intérieure du rez-de-chaussée
const DOOR_W := 1.8
const DOOR_H := 2.4

const C_ASPHALT := Color(0.16, 0.16, 0.17)
const C_DIRT := Color(0.36, 0.29, 0.2)
const C_LINE := Color(0.75, 0.72, 0.6)
const C_WINDOW := Color(0.09, 0.11, 0.14)
const C_FLOOR := Color(0.4, 0.36, 0.31)

const HOUSE_COLORS := [Color(0.62, 0.55, 0.45), Color(0.55, 0.42, 0.36), Color(0.7, 0.67, 0.58), Color(0.5, 0.52, 0.48), Color(0.6, 0.5, 0.4), Color(0.47, 0.36, 0.3)]
const CITY_COLORS := [Color(0.5, 0.5, 0.52), Color(0.42, 0.4, 0.38), Color(0.55, 0.5, 0.44), Color(0.36, 0.38, 0.42), Color(0.6, 0.58, 0.55), Color(0.45, 0.33, 0.28)]
const CAR_COLORS := [Color(0.5, 0.1, 0.1), Color(0.15, 0.2, 0.35), Color(0.6, 0.6, 0.6), Color(0.1, 0.1, 0.1), Color(0.35, 0.38, 0.3), Color(0.55, 0.45, 0.3), Color(0.8, 0.8, 0.78)]

# [nom, taille (long. le long du mur, hauteur, profondeur), couleur, table de butin (facultative, sinon le type du bâtiment)]
const FURN := {
	"maison": [["Armoire", Vector3(1.2, 2.0, 0.6), Color(0.4, 0.28, 0.18)], ["Commode", Vector3(1.0, 0.9, 0.5), Color(0.45, 0.32, 0.2)], ["Placard de cuisine", Vector3(1.8, 0.95, 0.6), Color(0.75, 0.73, 0.68)], ["Réfrigérateur", Vector3(0.8, 1.9, 0.7), Color(0.85, 0.85, 0.82)], ["Lave-linge", Vector3(0.65, 0.85, 0.65), Color(0.9, 0.9, 0.9)],
		["Table de chevet", Vector3(0.5, 0.6, 0.45), Color(0.45, 0.32, 0.2)], ["Bibliothèque", Vector3(1.0, 1.9, 0.4), Color(0.42, 0.3, 0.2)]],
	"pharmacie": [["Armoire à pharmacie", Vector3(1.0, 1.9, 0.5), Color(0.85, 0.85, 0.88)], ["Comptoir", Vector3(2.2, 1.0, 0.7), Color(0.8, 0.8, 0.78)], ["Étagère", Vector3(2.0, 1.8, 0.5), Color(0.5, 0.5, 0.52)]],
	"bar": [["Comptoir", Vector3(2.2, 1.0, 0.7), Color(0.4, 0.3, 0.22)], ["Frigo vitré", Vector3(1.6, 2.0, 0.7), Color(0.6, 0.7, 0.75)], ["Placard de cuisine", Vector3(1.8, 0.95, 0.6), Color(0.75, 0.73, 0.68)]],
	"eglise": [["Coffre", Vector3(1.0, 0.7, 0.6), Color(0.35, 0.25, 0.15), "maison"], ["Armoire", Vector3(1.2, 2.0, 0.6), Color(0.4, 0.28, 0.18), "maison"]],
	"bibliotheque": [["Rayonnage de livres", Vector3(2.0, 2.0, 0.45), Color(0.42, 0.3, 0.2), "bureau"], ["Bureau", Vector3(1.6, 0.8, 0.8), Color(0.45, 0.35, 0.25), "bureau"], ["Classeur", Vector3(0.6, 1.3, 0.6), Color(0.45, 0.47, 0.5), "bureau"]],
	"garage": [["Établi", Vector3(2.0, 0.95, 0.8), Color(0.45, 0.33, 0.2)], ["Étagère d'outils", Vector3(2.4, 1.8, 0.6), Color(0.55, 0.35, 0.15)], ["Bidons", Vector3(1.2, 1.0, 0.6), Color(0.7, 0.15, 0.1)]],
	"vetements": [["Portant", Vector3(2.0, 1.6, 0.6), Color(0.5, 0.5, 0.52), "maison"], ["Comptoir", Vector3(2.2, 1.0, 0.7), Color(0.4, 0.3, 0.22), "magasin"]],
	"magasin": [["Étagère", Vector3(2.0, 1.8, 0.5), Color(0.5, 0.5, 0.52)], ["Comptoir", Vector3(2.2, 1.0, 0.7), Color(0.4, 0.3, 0.22)], ["Frigo vitré", Vector3(1.6, 2.0, 0.7), Color(0.6, 0.7, 0.75)]],
	"bureau": [["Bureau", Vector3(1.6, 0.8, 0.8), Color(0.45, 0.35, 0.25)], ["Armoire métallique", Vector3(1.0, 1.9, 0.5), Color(0.45, 0.47, 0.5)], ["Casier", Vector3(0.6, 1.9, 0.5), Color(0.4, 0.42, 0.45)]],
	"quincaillerie": [["Étagère d'outils", Vector3(2.4, 1.8, 0.6), Color(0.55, 0.35, 0.15)], ["Étagère", Vector3(2.0, 1.8, 0.5), Color(0.5, 0.5, 0.52)], ["Bac à matériaux", Vector3(1.4, 0.8, 0.9), Color(0.4, 0.4, 0.3)]],
	"hopital": [["Armoire à pharmacie", Vector3(1.0, 1.9, 0.5), Color(0.85, 0.85, 0.88)], ["Chariot médical", Vector3(0.9, 1.0, 0.6), Color(0.7, 0.72, 0.75)], ["Bureau", Vector3(1.6, 0.8, 0.8), Color(0.45, 0.35, 0.25)]],
	"armurerie": [["Vitrine", Vector3(1.8, 1.0, 0.6), Color(0.3, 0.3, 0.32)], ["Râtelier", Vector3(2.0, 1.9, 0.4), Color(0.25, 0.2, 0.15)], ["Coffre", Vector3(1.0, 1.2, 0.8), Color(0.2, 0.2, 0.22)]],
	"police": [["Casier", Vector3(0.6, 1.9, 0.5), Color(0.3, 0.35, 0.45)], ["Bureau", Vector3(1.6, 0.8, 0.8), Color(0.45, 0.35, 0.25)], ["Armoire à armes", Vector3(1.4, 2.0, 0.6), Color(0.2, 0.22, 0.28)]],
	"militaire": [["Caisse militaire", Vector3(1.4, 0.7, 0.8), Color(0.3, 0.35, 0.2)], ["Casier militaire", Vector3(0.7, 1.9, 0.5), Color(0.28, 0.32, 0.2)], ["Caisse de munitions", Vector3(1.0, 0.5, 0.6), Color(0.25, 0.3, 0.18)]],
	"armurerie_mil": [["Râtelier militaire", Vector3(2.0, 1.9, 0.5), Color(0.22, 0.26, 0.16)], ["Caisse de munitions", Vector3(1.0, 0.5, 0.6), Color(0.25, 0.3, 0.18)], ["Caisse militaire", Vector3(1.4, 0.7, 0.8), Color(0.3, 0.35, 0.2)]],
	"station": [["Étagère", Vector3(2.0, 1.8, 0.5), Color(0.5, 0.5, 0.52)], ["Comptoir", Vector3(2.2, 1.0, 0.7), Color(0.4, 0.3, 0.22)], ["Frigo vitré", Vector3(1.6, 2.0, 0.7), Color(0.6, 0.7, 0.75)]],
	"ferme": [["Armoire", Vector3(1.2, 2.0, 0.6), Color(0.4, 0.28, 0.18)], ["Commode", Vector3(1.0, 0.9, 0.5), Color(0.45, 0.32, 0.2)], ["Placard de cuisine", Vector3(1.8, 0.95, 0.6), Color(0.6, 0.5, 0.4)], ["Coffre", Vector3(1.0, 0.7, 0.6), Color(0.35, 0.25, 0.15)]],
	"grange": [["Caisse en bois", Vector3(1.2, 1.0, 1.0), Color(0.5, 0.38, 0.22)], ["Établi de ferme", Vector3(2.0, 0.95, 0.8), Color(0.45, 0.33, 0.2)], ["Étagère", Vector3(2.0, 1.8, 0.5), Color(0.45, 0.4, 0.35)]],
}

# Matériaux du décor : [texture, taille de la tuile en m, rugosité, métal]
# (textures procédurales générées par outils/textures/generer_textures.py)
const MATS := {
	"uni": ["", 1.0, 0.85, 0.0], "metal": ["", 1.0, 0.45, 0.6],
	"asphalte": ["asphalte", 4.0, 0.9, 0.0], "beton": ["beton", 3.0, 0.9, 0.0],
	"trottoir": ["trottoir", 2.0, 0.9, 0.0], "brique": ["brique", 1.0, 0.9, 0.0],
	"enduit": ["enduit", 2.0, 0.92, 0.0], "parquet": ["parquet", 2.0, 0.6, 0.0],
	"carrelage": ["carrelage", 1.2, 0.3, 0.0], "herbe": ["herbe", 3.0, 0.95, 0.0],
	"terre": ["terre", 3.0, 0.95, 0.0], "toit": ["toit", 2.0, 0.95, 0.0],
	"planches": ["planches", 2.0, 0.85, 0.0], "tole": ["tole", 1.0, 0.5, 0.5],
	"parpaing": ["parpaing", 2.0, 0.9, 0.0], "vitre": ["vitre", 1.5, 0.08, 0.4],
	"tuiles": ["tuiles", 2.0, 0.8, 0.0], "roche": ["roche", 4.0, 0.95, 0.0],
}

# modèles 3D (modeles/props) utilisés pour chaque meuble fouillable
const MODELES_MEUBLES := {
	"Armoire": ["placard_peint2", "meuble_tiroirs"], "Commode": ["commode", "chevet", "console"],
	"Placard de cuisine": ["placard_peint"], "Étagère": ["etagere_metal", "etagere_murale"],
	"Comptoir": ["armoire_bois"], "Bureau": ["bureau", "bureau_ecole"],
	"Armoire métallique": ["classeur"], "Casier": ["casier"], "Étagère d'outils": ["etagere_metal"],
	"Bac à matériaux": ["caisse_bois"], "Armoire à pharmacie": ["placard_peint2"],
	"Vitrine": ["etagere_bois"], "Râtelier": ["etagere_murale"], "Armoire à armes": ["casier"],
	"Caisse militaire": ["caisse_bois"], "Casier militaire": ["casier_mil"], "Caisse de munitions": ["caisse_mil"],
	"Râtelier militaire": ["etagere_metal"], "Caisse en bois": ["caisse_bois"], "Établi de ferme": ["table_bois"],
	"Coffre": ["caisse_mil"], "Table de chevet": ["chevet"],
	"Lave-linge": ["lave_linge"], "Bibliothèque": ["etagere_bois"],
	"Rayonnage de livres": ["etagere_bois"], "Classeur": ["classeur"], "Établi": ["table_bois"], "Portant": ["etagere_metal"],
}

var rng := RandomNumberGenerator.new()
var sts := {}         # "chunk|matériau" -> SurfaceTool
var bodies := {}      # chunk -> StaticBody3D
var mat: StandardMaterial3D
var mats := {}        # nom -> matériau
var cur_mat := "uni"  # matériau utilisé par _box() quand aucun n'est précisé
var decor: Node3D     # objets de décor (modèles 3D)
var portes: Array = []       # portes des bâtiments (ordre de génération)
var portes_bat: Array = []   # portes du bâtiment en cours de construction
var conteneurs: Array = []   # meubles fouillables, dans l'ordre de génération
var reserved: Array = []   # Rect2 occupés (pour placer les arbres)
var guards: Array = []     # zombies à placer : {pos, kind, radius}
var trees: Array = []      # Vector3
# récolte (scripts/recolte.gd) : par arbre [clé du MultiMesh, n° d'instance, collision, transform] ;
# rochers et épaves : {n: modèle, cs: collision, k: taille}, dans l'ordre de génération (même graine = mêmes numéros)
var arbres_ref: Array = []
var arbres_mm := {}
var rochers: Array = []
var epaves: Array = []
var champs: Array = []     # Rect2 des champs des fermes (faune : faisans, lapins)
var spawn_point := Vector3.ZERO
var spawn_zone: Dictionary = {}
var half := 0.0
var relief = null            # relief de la campagne (collines, lacs, rivière)
var routes: Array = []       # [{r: Rect2, x: bool (le long de x)}]
var plats: Array = []        # zones à garder plates (villages, fermes) sans bloquer les constructions
var lampadaires: Array = []  # positions des lampadaires (éclairés la nuit par eclairage_rues.gd)


func build(seed_value: int) -> Vector3:
	rng.seed = seed_value
	half = NB * BLOCK / 2.0
	Game.city_half = half
	# villes de la carte (pour Game.in_city : herbe, zombies, décalques…)
	Game.villes = [{"c": Vector3.ZERO, "demi": half}, {"c": VILLE_B, "demi": NB_B * BLOCK / 2.0}]
	mat = StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.vertex_color_is_srgb = true
	mat.roughness = 0.92
	_creer_materiaux()
	decor = Node3D.new()
	decor.name = "Decor"
	add_child(decor)
	morceaux = Morceaux.new()
	morceaux.name = "Morceaux"
	add_child(morceaux)
	var t := Time.get_ticks_msec()
	_ground()
	_city()
	_poi("Bellerive", Vector3.ZERO, Color(0.95, 0.95, 0.95))
	t = _chrono("ville", t)
	_countryside()
	_military_base(Vector3(-255, 0, -250))
	t = _chrono("campagne", t)
	_regions()
	t = _chrono("regions", t)
	_relief()
	t = _chrono("relief", t)
	_trees()
	_vegetation()
	t = _chrono("arbres", t)
	_commit()
	t = _chrono("commit", t)
	return spawn_point


var chrono := {}   # durée de chaque étape de la génération (ms), pour les mesures
var morceaux       # chargement par morceaux (morceaux.gd) : seules les cases proches restent dans l'arbre
var tache_carte := -1


func _carte_prete(img: Image) -> void:
	Game.carte_relief = ImageTexture.create_from_image(img)


func _exit_tree() -> void:
	if tache_carte >= 0:
		WorkerThreadPool.wait_for_task_completion(tache_carte)
		tache_carte = -1


## Après la génération (et la création des camps, qui dégagent leur terrain) : range les nœuds du monde
## par cases et ne garde que celles autour de « p ».
func ranger_par_morceaux(p: Vector3) -> void:
	morceaux.ranger(self)
	morceaux.ranger(decor)
	morceaux.maj(p, true)


func _chrono(nom: String, t: int) -> int:
	var maintenant := Time.get_ticks_msec()
	chrono[nom] = maintenant - t
	return maintenant


# ================================================================ géométrie
static var _cache_mats := {}


func _creer_materiaux() -> void:
	if not _cache_mats.is_empty():
		mats = _cache_mats
		return
	for nom in MATS:
		var d: Array = MATS[nom]
		var m := StandardMaterial3D.new()
		m.vertex_color_use_as_albedo = true
		m.vertex_color_is_srgb = true
		m.roughness = d[2]
		m.metallic = d[3]
		var tex: String = d[0]
		if tex != "" and ResourceLoader.exists("res://textures/%s_albedo.jpg" % tex):
			m.albedo_texture = load("res://textures/%s_albedo.jpg" % tex)
			if ResourceLoader.exists("res://textures/%s_normal.png" % tex):
				m.normal_enabled = true
				m.normal_texture = load("res://textures/%s_normal.png" % tex)
			if ResourceLoader.exists("res://textures/%s_rough.jpg" % tex):
				m.roughness_texture = load("res://textures/%s_rough.jpg" % tex)
				m.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
				m.roughness = 1.0
			# les UV des boîtes sont en mètres : une répétition par tuile
			var k := 1.0 / float(d[1])
			m.uv1_scale = Vector3(k, k, k)
			m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
		mats[nom] = m
	_cache_mats = mats


func _chunk(p: Vector3) -> Vector2i:
	return Vector2i(floori(p.x / CHUNK), floori(p.z / CHUNK))


func _box(c: Vector3, s: Vector3, col: Color, solid := true, m := "") -> void:
	var k := _chunk(c)
	if m == "invisible":
		_collision(k, c, s)
		return
	var cle := "%d|%d|%s" % [k.x, k.y, m if m != "" else cur_mat]
	if not sts.has(cle):
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		sts[cle] = st
	_box_faces(sts[cle], c, s, col)
	if solid:
		_collision(k, c, s)


func _collision(k: Vector2i, c: Vector3, s: Vector3) -> void:
	if true:
		if not bodies.has(k):
			var b := StaticBody3D.new()
			b.collision_layer = Game.LAYER_WORLD
			b.collision_mask = 0
			add_child(b)
			bodies[k] = b
		var cs := CollisionShape3D.new()
		var sh := BoxShape3D.new()
		sh.size = s
		cs.shape = sh
		cs.position = c
		bodies[k].add_child(cs)


const FACES := [
	[Vector3(1, 0, 0), Vector3(0, 0, -1), Vector3(0, 1, 0)],
	[Vector3(-1, 0, 0), Vector3(0, 0, 1), Vector3(0, 1, 0)],
	[Vector3(0, 1, 0), Vector3(1, 0, 0), Vector3(0, 0, -1)],
	[Vector3(0, -1, 0), Vector3(1, 0, 0), Vector3(0, 0, 1)],
	[Vector3(0, 0, 1), Vector3(1, 0, 0), Vector3(0, 1, 0)],
	[Vector3(0, 0, -1), Vector3(-1, 0, 0), Vector3(0, 1, 0)],
]


func _box_faces(st: SurfaceTool, c: Vector3, s: Vector3, col: Color) -> void:
	var h := s * 0.5
	for f in FACES:
		var n: Vector3 = f[0]
		var u: Vector3 = f[1]
		var v: Vector3 = f[2]
		var hn := absf(n.dot(h))
		var hu := absf(u.dot(h))
		var hv := absf(v.dot(h))
		var base := c + n * hn
		var p0 := base - u * hu - v * hv
		var p1 := base + u * hu - v * hv
		var p2 := base + u * hu + v * hv
		var p3 := base - u * hu + v * hv
		# UV en mètres, alignées sur le monde : les textures se raccordent d'une boîte à l'autre
		var tg := Plane(u.x, u.y, u.z, 1.0)
		# Godot : faces avant dans le sens horaire
		for p in [p0, p2, p1, p0, p3, p2]:
			st.set_normal(n)
			st.set_tangent(tg)
			st.set_color(col)
			st.set_uv(Vector2(p.dot(u), -p.dot(v)))
			st.add_vertex(p)


func _flat(r: Rect2, y: float, col: Color, m := "") -> void:
	_box(Vector3(r.position.x + r.size.x / 2.0, y, r.position.y + r.size.y / 2.0), Vector3(r.size.x, 0.02, r.size.y), col, false, m)


func _reserve(r: Rect2, map_col := Color(0, 0, 0, 0)) -> void:
	reserved.append(r)
	if map_col.a > 0.0:
		Game.map_rects.append({"rect": r, "color": map_col})


func _commit() -> void:
	for k in sts:
		var mi := MeshInstance3D.new()
		mi.mesh = sts[k].commit()
		mi.material_override = mats.get(str(k).get_slice("|", 2), mat)
		add_child(mi)
	sts.clear()


# ================================================================ sol
func _ground() -> void:
	# le sol lui-même (relief) est construit plus tard, une fois tous les lieux placés
	var body := StaticBody3D.new()
	body.collision_layer = Game.LAYER_WORLD
	add_child(body)
	# limites invisibles de la carte
	var m := Game.map_half
	for e in [[Vector3(m, 5, 0), Vector3(1, 10, 2 * m)], [Vector3(-m, 5, 0), Vector3(1, 10, 2 * m)], [Vector3(0, 5, m), Vector3(2 * m, 10, 1)], [Vector3(0, 5, -m), Vector3(2 * m, 10, 1)]]:
		var cs2 := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = e[1]
		cs2.shape = bs
		cs2.position = e[0]
		body.add_child(cs2)
	_sol_ville(Vector3.ZERO, half)


## Sol bétonné d'une ville (centre o, demi-côté hv), réservé et dessiné sur la carte.
func _sol_ville(o: Vector3, hv: float) -> void:
	reserved.append(Rect2(o.x - hv - 10, o.z - hv - 10, 2 * hv + 20, 2 * hv + 20))
	_flat(Rect2(o.x - hv - 8, o.z - hv - 8, 2 * hv + 16, 2 * hv + 16), 0.006, Color(0.85, 0.85, 0.83), "trottoir")
	Game.map_rects.append({"rect": Rect2(o.x - hv - 8, o.z - hv - 8, 2 * hv + 16, 2 * hv + 16), "color": Color(0.22, 0.22, 0.22)})


# ================================================================ routes
## Route alignée sur un axe entre a et b (coordonnées x,z).
func _road(a: Vector2, b: Vector2, width: float, col := C_ASPHALT, lines := true) -> void:
	var r := Rect2(minf(a.x, b.x) - width / 2.0, minf(a.y, b.y) - width / 2.0, absf(b.x - a.x) + width, absf(b.y - a.y) + width)
	# découpe en tronçons pour le regroupement par chunk
	var along_x := absf(b.x - a.x) > absf(b.y - a.y)
	var length := r.size.x if along_x else r.size.y
	var pieces := maxi(1, ceili(length / 40.0))
	for i in pieces:
		var pr: Rect2
		if along_x:
			pr = Rect2(r.position.x + r.size.x * i / pieces, r.position.y, r.size.x / pieces, r.size.y)
		else:
			pr = Rect2(r.position.x, r.position.y + r.size.y * i / pieces, r.size.x, r.size.y / pieces)
		if col == C_ASPHALT:
			_flat(pr, 0.02, Color(0.95, 0.95, 0.95), "asphalte")
		elif col == C_DIRT:
			_flat(pr, 0.02, Color(0.95, 0.92, 0.88), "terre")
		else:
			_flat(pr, 0.02, col)
	_reserve(r, Color(0.12, 0.12, 0.12) if col == C_ASPHALT else Color(0.35, 0.28, 0.18))
	routes.append({"r": r, "x": along_x})
	Game.sols.append({"r": r, "s": "beton" if col == C_ASPHALT else "terre"})
	if lines:
		var d := 0.0
		while d < length - 4.0:
			if along_x:
				_box(Vector3(r.position.x + d + 2.0, 0.035, (a.y + b.y) / 2.0), Vector3(3.0, 0.01, 0.15), C_LINE, false, "uni")
			else:
				_box(Vector3((a.x + b.x) / 2.0, 0.035, r.position.y + d + 2.0), Vector3(0.15, 0.01, 3.0), C_LINE, false, "uni")
			d += 7.0


# [modèle, poids, solide, rotation aléatoire]
const MOBILIER := [["poubelle", 5, true], ["poubelle_rue", 4, true], ["borne_incendie", 3, true],
	["baril_rouge", 1, true], ["baril_bleu", 1, true], ["cone", 2, false], ["pneu", 2, false],
	["palette", 2, false], ["carton", 3, false], ["armoire_electrique", 2, true], ["banc", 2, true],
	["glissiere", 1, true], ["barriere_beton", 1, true]]


## Mobilier urbain le long des trottoirs, plaques d'égout, barrages abandonnés.
func _mobilier_urbain(o: Vector3 = Vector3.ZERO, nb: int = NB) -> void:
	if not Decor.existe("poubelle"):
		return
	var hv := nb * BLOCK / 2.0
	var total := 0
	for m in MOBILIER:
		total += m[1]
	for i in nb + 1:
		var c := -hv + i * BLOCK
		for j in nb:
			var a0 := -hv + j * BLOCK + ROAD / 2.0 + 2.5
			var a1 := -hv + (j + 1) * BLOCK - ROAD / 2.0 - 2.5
			for sd in [-1.0, 1.0]:
				if (i == 0 and sd < 0) or (i == nb and sd > 0):
					continue
				var off: float = c + sd * (ROAD / 2.0 + 0.7)
				for along_x in [true, false]:
					var nbo := rng.randi_range(1, 4)
					for q in nbo:
						var a := rng.randf_range(a0, a1)
						var r := rng.randi() % total
						var choix: Array = MOBILIER[0]
						for m in MOBILIER:
							r -= m[1]
							if r < 0:
								choix = m
								break
						var pos := (Vector3(a, 0.0, off) if along_x else Vector3(off, 0.0, a)) + Vector3(o.x, 0.0, o.z)
						var t := Decor.taille(choix[0])
						if _overlaps(Rect2(pos.x - t.x / 2.0, pos.z - t.x / 2.0, t.x, t.x)):
							continue
						# face vers la route, un peu de désordre
						var ang := (0.0 if sd < 0 else PI) if along_x else (PI / 2.0 if sd < 0 else -PI / 2.0)
						ang += rng.randf_range(-0.3, 0.3) if choix[0] != "banc" else 0.0
						if choix[0] in ["pneu", "carton", "cone"] and rng.randf() < 0.4:
							ang = rng.randf() * TAU
						_prop(choix[0], pos, ang, choix[2], 1.0, 90.0)
			# plaques d'égout au milieu de la chaussée
			if rng.randf() < 0.6:
				var a := rng.randf_range(a0, a1)
				_prop("plaque_egout", Vector3(o.x + a, 0.02, o.z + c + rng.randf_range(-2.0, 2.0)), 0.0, false, 1.0, 60.0)
	# barrages abandonnés à quelques carrefours
	for n in int(10 * float(nb * nb) / float(NB * NB)) + 1:
		var i := rng.randi_range(1, nb - 1)
		var j := rng.randi_range(1, nb - 1)
		var p := Vector3(-hv + i * BLOCK, 0, -hv + j * BLOCK + (BLOCK / 2.0 - 6.0) * (1.0 if rng.randf() < 0.5 else -1.0))
		if rng.randf() < 0.5:
			p = Vector3(p.z, 0, p.x)
		var le_long_x := absf(fposmod(p.x + hv, BLOCK)) < 1.0
		p += Vector3(o.x, 0.0, o.z)
		for k in 4:
			var offk := (k - 1.5) * 1.7 + rng.randf_range(-0.2, 0.2)
			var pos := p + (Vector3(offk, 0, 0) if le_long_x else Vector3(0, 0, offk))
			var id := "glissiere" if rng.randf() < 0.6 else "barriere_beton"
			var ang := (0.0 if le_long_x else PI / 2.0) + rng.randf_range(-0.25, 0.25)
			if id == "glissiere":
				ang += PI / 2.0
			_prop(id, pos, ang, true, 1.0, 150.0)
		for k in 3:
			_prop("cone", p + Vector3(rng.randf_range(-4, 4), 0, rng.randf_range(-4, 4)), rng.randf() * TAU, false, 1.0, 80.0)


const VOITURES := ["voiture1", "voiture2", "voiture_suv", "voiture_taxi", "voiture_sport", "voiture1", "voiture2",
		"voiture_pickup", "voiture_camionnette", "voiture_moto"]


## Objet de décor (modèle 3D) posé au sol, avec collision en boîte si « solide ».
func _prop(id: String, pos: Vector3, ang: float, solide := true, k := 1.0, dist := 110.0) -> Node3D:
	var n := Decor.instance(id)
	if n == null:
		return null
	n.position = pos
	n.rotation.y = ang
	n.scale = Vector3.ONE * k
	decor.add_child(n)
	Decor.distance(n, dist)
	if id.begins_with("buisson"):
		var tb := Decor.taille(id) * k
		Game.ajouter_buisson(pos, maxf(tb.x, tb.z) * 0.5)
	if solide:
		var t := Decor.taille(id) * k
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = t
		cs.shape = bs
		cs.transform = Transform3D(Basis(Vector3.UP, ang), pos + Vector3(0, t.y / 2.0, 0))
		var kch := _chunk(pos)
		if not bodies.has(kch):
			var b := StaticBody3D.new()
			b.collision_layer = Game.LAYER_WORLD
			b.collision_mask = 0
			add_child(b)
			bodies[kch] = b
		bodies[kch].add_child(cs)
		if id == "rocher":
			rochers.append({"n": n, "cs": cs, "k": k})
		elif id.begins_with("voiture"):
			epaves.append({"n": n, "cs": cs, "k": k})
	return n


func _car(c: Vector3, along_x: bool, col: Color, id := "") -> void:
	if Decor.existe("voiture1"):
		if id == "":
			id = VOITURES[rng.randi() % VOITURES.size()]
		var ang := (PI / 2.0 if along_x else 0.0) + (PI if rng.randf() < 0.5 else 0.0) + rng.randf_range(-0.2, 0.2)
		var v := _prop(id, c, ang, true, 1.0, 220.0)
		if v and id != "voiture_police" and id != "voiture_taxi":
			Decor.peindre(v, col)
		# épaves : rouillées ou brûlées
		var r_ep := rng.randf()
		if v and r_ep < 0.22:
			Decor.vieillir(v, Color(0.42, 0.24, 0.12), 0.7)
		elif v and r_ep < 0.3:
			Decor.vieillir(v, Color(0.07, 0.06, 0.055), 0.88)
		return
	var body := Vector3(4.3, 0.9, 1.9) if along_x else Vector3(1.9, 0.9, 4.3)
	var cab := Vector3(2.2, 0.7, 1.75) if along_x else Vector3(1.75, 0.7, 2.2)
	_box(c + Vector3(0, 0.75, 0), body, col)
	_box(c + Vector3(0, 1.55, 0), cab, col.darkened(0.15))
	# vitres
	_box(c + Vector3(0, 1.55, 0), cab + Vector3(0.04, -0.2, 0.04), C_WINDOW, false)
	# roues (sombres, visuelles)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			var off := Vector3(sx * 1.4, 0.35, sz * 0.85) if along_x else Vector3(sz * 0.85, 0.35, sx * 1.4)
			_box(c + off, Vector3(0.7, 0.7, 0.3) if along_x else Vector3(0.3, 0.7, 0.7), Color(0.05, 0.05, 0.05), false)


# ================================================================ bâtiments
func _building(c: Vector3, w: float, d: float, h: float, col: Color, doors: Array, kind: String, label := "", partition := false, furn := -1, map_col := Color(0.5, 0.5, 0.5), toit := "plat") -> Dictionary:
	var t := WALL_T
	var x0 := c.x - w / 2.0
	var x1 := c.x + w / 2.0
	var z0 := c.z - d / 2.0
	var z1 := c.z + d / 2.0
	# étages : chaque étage fait INT_H de haut ; certains bâtiments n'ont qu'un grand volume
	var un_seul := kind in ["grange", "station", "garage", "eglise"] or label in ["Hangar", "Supermarché", "Centre commercial"]
	var n := 1 if un_seul else clampi(int(floor((maxf(h, INT_H + 0.3) - 0.3) / INT_H + 0.25)), 1, 8)
	var haut_etage := maxf(h - 0.3, INT_H) if un_seul else INT_H
	h = n * haut_etage + 0.3
	var sommet := n * haut_etage
	# revêtements : façade selon le type de bâtiment, sol intérieur selon l'usage
	var facade := _facade(kind, h)
	if facade == "brique":
		col = Color(1, 1, 1).lerp(col, 0.25).lightened(0.1)
	elif facade == "parpaing" or facade == "planches":
		col = col.lightened(0.35)
	else:
		col = col.lightened(0.2)
	var sol := "parquet"
	if kind in ["magasin", "hopital", "station", "bureau", "police", "armurerie", "pharmacie", "bar", "vetements"]:
		sol = "carrelage"
	elif kind in ["militaire", "armurerie_mil", "grange", "quincaillerie", "garage"]:
		sol = "beton"
	var col_sol := Color(0.9, 0.88, 0.85) if sol != "parquet" else Color(1, 1, 1)
	var mat_avant := cur_mat
	cur_mat = facade
	# ---------------------------------------------------------------- murs, portes, fenêtres
	var door_list: Array = []
	portes_bat = []
	var outward := {"n": Vector3(0, 0, -1), "s": Vector3(0, 0, 1), "w": Vector3(-1, 0, 0), "e": Vector3(1, 0, 0)}
	var portes_dc := {}
	for side in ["n", "s", "w", "e"]:
		var along_x: bool = side == "n" or side == "s"
		var fixed: float
		match side:
			"n": fixed = z0 + t / 2.0
			"s": fixed = z1 - t / 2.0
			"w": fixed = x0 + t / 2.0
			_: fixed = x1 - t / 2.0
		var a0: float = x0 if along_x else z0 + t
		var a1: float = x1 if along_x else z1 - t
		var has_door: bool = side in doors
		var dc := (a0 + a1) / 2.0
		var o: Vector3 = outward[side]
		if has_door:
			var spread := maxf(0.0, (a1 - a0) / 2.0 - 2.5)
			if partition and not along_x:
				dc = c.z + (d / 4.0) * (1.0 if rng.randf() < 0.5 else -1.0)
			else:
				dc += rng.randf_range(-spread, spread) * 0.5
			portes_dc[side] = dc
			var dp := Vector3(dc, 0, fixed) if along_x else Vector3(fixed, 0, dc)
			door_list.append({"pos": dp, "out": dp + o * 1.5, "inn": dp - o * 1.5})
			_wall(along_x, fixed, a0, dc - DOOR_W / 2.0, 0.0, sommet, col)
			_wall(along_x, fixed, dc + DOOR_W / 2.0, a1, 0.0, sommet, col)
			_wall(along_x, fixed, dc - DOOR_W / 2.0, dc + DOOR_W / 2.0, DOOR_H, sommet, col.darkened(0.2))
			_porte(dp, along_x, o)
		else:
			_wall(along_x, fixed, a0, a1, 0.0, sommet, col)
		var sgn: float = o.z if along_x else o.x
		var face: float = fixed + sgn * (t / 2.0)
		var face_in: float = fixed - sgn * (t / 2.0)
		_bande(along_x, face, sgn, a0 - (t if not along_x else 0.0), a1 + (t if not along_x else 0.0), 0.0, 0.45, 0.04, Color(0.7, 0.7, 0.68), "beton", has_door, dc)
		var nb_rangs := n if not un_seul else maxi(1, int(haut_etage / 3.3))
		for k in nb_rangs:
			var base := k * (haut_etage if not un_seul else 3.3)
			var y := base + 1.0
			if y + 1.2 > sommet:
				break
			if k > 0:
				_bande(along_x, face, sgn, a0, a1, base - 0.2, base + 0.05, 0.05, Color(0.78, 0.77, 0.74), "beton", false, 0.0)
			var a := a0 + 2.0
			while a < a1 - 2.0:
				var skip := has_door and k == 0 and absf(a - dc) < 2.0
				if not skip:
					_fenetre(along_x, face, sgn, a, y, kind)
					# vitre vue de l'intérieur
					_sur_facade(along_x, face_in, -sgn, a, y + 0.55, 0.01, 1.3, 1.1, 0.02, Color(0.55, 0.62, 0.7), "vitre")
				a += 3.6
		# corniche en haut de la façade (deux bandeaux en saillie)
		if OS.get_environment("SANS_FACADES") != "":
			continue
		var ac0: float = a0 - (t if not along_x else 0.0)
		var ac1: float = a1 + (t if not along_x else 0.0)
		_bande(along_x, face, sgn, ac0, ac1, sommet - 0.18, sommet + 0.32, 0.12, Color(0.8, 0.79, 0.76), "beton", false, 0.0)
		_bande(along_x, face, sgn, ac0, ac1, sommet + 0.18, sommet + 0.3, 0.22, Color(0.74, 0.73, 0.7), "beton", false, 0.0)
		# descente de gouttière dans un coin de la façade (côtés nord et sud)
		if along_x and a1 - a0 > 5.0:
			var ap: float = a0 + 0.35 if rng.randf() < 0.5 else a1 - 0.35
			var gris := Color(0.38, 0.39, 0.4)
			_sur_facade(along_x, face, sgn, ap, (sommet + 0.25) / 2.0, 0.09, 0.1, sommet + 0.25, 0.1, gris, "metal_peint")
			_sur_facade(along_x, face, sgn, ap, 0.08, 0.16, 0.14, 0.16, 0.26, gris, "metal_peint")   # sabot au pied
			for yb in range(1, int(sommet / 2.0) + 1):
				_sur_facade(along_x, face, sgn, ap, yb * 2.0, 0.05, 0.16, 0.05, 0.06, gris.darkened(0.2), "metal_peint")   # colliers
	# ---------------------------------------------------------------- cage d'escalier
	var cage := {}
	if n > 1:
		cage = _choisir_cage(x0 + t, x1 - t, z0 + t, z1 - t, doors, portes_dc)
	# ---------------------------------------------------------------- planchers, toit
	var zones_etages: Array = []
	for k in n:
		var base := k * haut_etage
		var trou := Rect2()
		if k > 0 and not cage.is_empty():
			trou = cage.trou
		if k == 0:
			_box(Vector3(c.x, 0.015, c.z), Vector3(w - 0.1, 0.03, d - 0.1), col_sol, false, sol)
		else:
			# dalle (plafond de l'étage du dessous) + revêtement du sol
			_dalle(Rect2(x0 + t, z0 + t, w - 2 * t, d - 2 * t), trou, base - 0.26, base - 0.02, Color(0.88, 0.87, 0.84), "enduit", true)
			_dalle(Rect2(x0 + t, z0 + t, w - 2 * t, d - 2 * t), trou, base - 0.02, base + 0.015, col_sol, sol, false)
	_box(Vector3(c.x, sommet + 0.15, c.z), Vector3(w, 0.3, d), Color(0.85, 0.84, 0.8), true, "enduit")
	if toit == "pente":
		_toit_pente(c, w, d, sommet + 0.3, col, facade)
	else:
		_toit_plat(c, w, d, h, x0, x1, z0, z1)

	# ---------------------------------------------------------------- escaliers
	if not cage.is_empty():
		for k in n - 1:
			_escalier(cage, k * haut_etage, haut_etage)
	# ---------------------------------------------------------------- zones (une par étage), cloisons, meubles
	var id_bat := Game.zones.size()
	for k in n:
		var base := k * haut_etage
		var placed: Array = []
		if not cage.is_empty():
			placed.append(cage.emprise)
		cur_mat = "enduit"
		var passages: Array = []
		if partition and d >= 12.0:
			var gx := rng.randf_range(x0 + 2.5, x1 - 2.5)
			passages.append(Vector3(gx, base, c.z))
			_wall(true, c.z, x0 + t, gx - 1.0, base, base + haut_etage, col.lightened(0.15))
			_wall(true, c.z, gx + 1.0, x1 - t, base, base + haut_etage, col.lightened(0.15))
			placed.append(Rect2(x0, c.z - 0.5, gx - 1.3 - x0, 1.0))
			placed.append(Rect2(gx + 1.3, c.z - 0.5, x1 - gx - 1.3, 1.0))
			placed.append(Rect2(gx - 1.5, c.z - 2.0, 3.0, 4.0))
		var zone := {
			"aabb": AABB(Vector3(x0 + t, base, z0 + t), Vector3(w - 2 * t, haut_etage, d - 2 * t)),
			"doors": door_list if k == 0 else [], "kind": kind, "name": label, "center": c,
			"id": Game.zones.size(), "etage": k, "batiment": id_bat, "liens": [], "passages": passages,
		}
		if k == 0:
			for dr in door_list:
				zone.liens.append({"pos": dr.pos, "a": dr.inn, "b": dr.out, "vers": -1, "type": "porte"})
		Game.zones.append(zone)
		zones_etages.append(zone)
		var nf := furn
		if nf < 0:
			nf = clampi(int(w * d / 22.0), 2, 14)   # intérieurs bien remplis
		if k > 0:
			nf = maxi(2, int(nf * 0.7))
		_furnish(zone, kind, nf, placed)
		_deco_piece(zone, kind, placed)
		_plafonnier(Vector3(c.x + rng.randf_range(-w, w) * 0.15, base + haut_etage - (0.3 if k < n - 1 else 0.05), c.z + rng.randf_range(-d, d) * 0.15), kind, label != "")
		if k > 0:
			var rk := {"hopital": "patient", "police": "police", "militaire": "militaire", "armurerie_mil": "militaire"}
			_residents(zone, 0.45 if k < 4 else 0.15, 2, rk.get(kind, "civil"))
	cur_mat = mat_avant
	# liens d'escalier entre étages (pour que les zombies suivent)
	if not cage.is_empty():
		for k in n - 1:
			var bas: Dictionary = zones_etages[k]
			var haut: Dictionary = zones_etages[k + 1]
			# points du chemin : y = 0 -> étage k, y = 1 -> étage k+1
			var ch: Array = []
			for q in cage.chemin:
				ch.append(Vector3(q.x, k * haut_etage + q.y * haut_etage, q.z))
			var a: Vector3 = ch[0]
			var b: Vector3 = ch[ch.size() - 1]
			var m := (a + b) * 0.5
			var ch_inv := ch.duplicate()
			ch_inv.reverse()
			bas.liens.append({"pos": m, "a": a, "b": b, "vers": haut.id, "type": "escalier", "chemin": ch})
			haut.liens.append({"pos": m, "a": b, "b": a, "vers": bas.id, "type": "escalier", "chemin": ch_inv})
	var zone0: Dictionary = zones_etages[0]
	zone0["etages"] = zones_etages
	zone0["portes"] = portes_bat.duplicate()
	_reserve(Rect2(x0 - 1.0, z0 - 1.0, w + 2.0, d + 2.0))
	Game.map_rects.append({"rect": Rect2(x0, z0, w, d), "color": map_col})
	return zone0


## Toit-terrasse gravillonné + acrotère.
func _toit_plat(c: Vector3, w: float, d: float, h: float, x0: float, x1: float, z0: float, z1: float) -> void:
	_box(Vector3(c.x, h + 0.02, c.z), Vector3(w - 0.4, 0.04, d - 0.4), Color(0.9, 0.9, 0.9), false, "toit")
	for e in [[Vector3(c.x, h + 0.3, z0 + 0.15), Vector3(w + 0.2, 0.6, 0.3)], [Vector3(c.x, h + 0.3, z1 - 0.15), Vector3(w + 0.2, 0.6, 0.3)],
			[Vector3(x0 + 0.15, h + 0.3, c.z), Vector3(0.3, 0.6, d)], [Vector3(x1 - 0.15, h + 0.3, c.z), Vector3(0.3, 0.6, d)]]:
		_box(e[0], e[1], Color(0.75, 0.74, 0.7), false, "beton")


## Toit à deux pans en tuiles (faîtage dans le sens de la plus grande longueur) + pignons.
func _toit_pente(c: Vector3, w: float, d: float, y0: float, col: Color, facade: String) -> void:
	var deb := 0.45
	var faitage_x := w >= d
	var demi := (d if faitage_x else w) / 2.0
	var hauteur := (demi + deb) * tan(deg_to_rad(33.0))
	var lg := (w if faitage_x else d) / 2.0 + deb
	var ep := 0.12
	for cote in [-1.0, 1.0]:
		# pan : du bord (bas) au faîtage (haut)
		var bas_c := Vector3(0, y0 - deb * tan(deg_to_rad(33.0)), cote * (demi + deb))
		var haut_c := Vector3(0, y0 + hauteur - deb * tan(deg_to_rad(33.0)), 0)
		var p0: Vector3
		var p1: Vector3
		var p2: Vector3
		var p3: Vector3
		if faitage_x:
			p0 = c + Vector3(-lg, bas_c.y, bas_c.z)
			p1 = c + Vector3(lg, bas_c.y, bas_c.z)
			p2 = c + Vector3(lg, haut_c.y, 0)
			p3 = c + Vector3(-lg, haut_c.y, 0)
		else:
			p0 = c + Vector3(bas_c.z, bas_c.y, -lg)
			p1 = c + Vector3(bas_c.z, bas_c.y, lg)
			p2 = c + Vector3(0, haut_c.y, lg)
			p3 = c + Vector3(0, haut_c.y, -lg)
		_quad(p0, p1, p2, p3, Color(1, 1, 1), "tuiles", true)
		# sous-face (visible depuis la rue)
		_quad(p0 + Vector3.DOWN * ep, p1 + Vector3.DOWN * ep, p2 + Vector3.DOWN * ep, p3 + Vector3.DOWN * ep, Color(0.6, 0.5, 0.4), "planches", false)
	# pignons triangulaires (dans le matériau de la façade)
	var yb := y0 - 0.02
	var yh := y0 + hauteur - deb * tan(deg_to_rad(33.0))
	for bout in [-1.0, 1.0]:
		var a: Vector3
		var b: Vector3
		var t: Vector3
		var bord := (w if faitage_x else d) / 2.0 - 0.02
		if faitage_x:
			a = c + Vector3(bout * bord, yb, -demi)
			b = c + Vector3(bout * bord, yb, demi)
			t = c + Vector3(bout * bord, yh, 0)
		else:
			a = c + Vector3(-demi, yb, bout * bord)
			b = c + Vector3(demi, yb, bout * bord)
			t = c + Vector3(0, yh, bout * bord)
		_tri(a, b, t, col, facade)
		_tri(b, a, t, col, facade)


func _st(c: Vector3, m: String) -> SurfaceTool:
	var k := _chunk(c)
	var cle := "%d|%d|%s" % [k.x, k.y, m]
	if not sts.has(cle):
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		sts[cle] = st
	return sts[cle]


## Quadrilatère (p0 -> p1 -> p2 -> p3) avec UV en mètres. « recto_verso » : visible des deux côtés.
func _quad(p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, col: Color, m: String, recto_verso := false) -> void:
	var st := _st((p0 + p2) * 0.5, m)
	var u := (p1 - p0).normalized()
	var v := (p3 - p0).normalized()
	for sens in ([1, -1] if recto_verso else [1]):
		var n := u.cross(v).normalized() * float(sens)
		var ordre := [p0, p2, p1, p0, p3, p2] if sens == 1 else [p0, p1, p2, p0, p2, p3]
		if n.y < 0.0 and not recto_verso:
			ordre = [p0, p1, p2, p0, p2, p3]
			n = -n
		for p in ordre:
			st.set_normal(n)
			st.set_tangent(Plane(u.x, u.y, u.z, 1.0))
			st.set_color(col)
			st.set_uv(Vector2((p - p0).dot(u), -(p - p0).dot(v)))
			st.add_vertex(p)


func _tri(a: Vector3, b: Vector3, t: Vector3, col: Color, m: String) -> void:
	var st := _st((a + b + t) / 3.0, m)
	var u := (b - a).normalized()
	var n := u.cross(t - a).normalized()
	for p in [a, t, b]:
		st.set_normal(-n)
		st.set_tangent(Plane(u.x, u.y, u.z, 1.0))
		st.set_color(col)
		st.set_uv(Vector2((p - a).dot(u), -(p.y - a.y)))
		st.add_vertex(p)


const ESC_LONG := 5.2     # longueur de la volée
const ESC_PALIER := 1.4   # palier d'arrivée
const ESC_LARG := 1.25    # largeur d'une voie (volée / passage)


## Cherche un coin pour la cage d'escalier, loin des portes.
func _choisir_cage(ix0: float, ix1: float, iz0: float, iz1: float, doors: Array, portes_dc: Dictionary) -> Dictionary:
	var lg := ESC_LONG + ESC_PALIER
	var la := ESC_LARG * 2.0
	for coin in [[-1, 1], [1, 1], [-1, -1], [1, -1]]:
		var sx: int = coin[0]
		var sz: int = coin[1]
		var xa := ix0 if sx < 0 else ix1 - lg
		var za := iz1 - la if sz > 0 else iz0
		var r := Rect2(xa, za, lg, la)
		var ok := true
		for side in portes_dc:
			var dc: float = portes_dc[side]
			var p: Vector2
			match side:
				"n": p = Vector2(dc, iz0)
				"s": p = Vector2(dc, iz1)
				"w": p = Vector2(ix0, dc)
				_: p = Vector2(ix1, dc)
			if r.grow(2.2).has_point(p):
				ok = false
		if not ok:
			continue
		# voie A (volée) contre le mur extérieur, voie B (passage) côté intérieur.
		# La volée part du côté ouvert (accessible depuis la pièce) et monte vers le coin,
		# où se trouve le palier d'arrivée.
		var dirx := 1.0 if sx < 0 else -1.0
		var x_coin := xa if sx < 0 else xa + lg
		var x_ouvert := x_coin + dirx * lg
		var z_a := za + ESC_LARG * 0.5 if sz < 0 else za + la - ESC_LARG * 0.5
		var z_b := z_a + (ESC_LARG if sz < 0 else -ESC_LARG)
		var x_haut := x_coin + dirx * ESC_PALIER        # haut de la volée
		var trou_x1 := x_haut + dirx * ESC_LONG * 0.7
		var trou := Rect2(minf(x_haut, trou_x1), z_a - ESC_LARG * 0.5, absf(trou_x1 - x_haut), ESC_LARG)
		# chemin pour monter : bas de la volée -> palier (voie A) -> palier (voie B) -> sortie le long du garde-corps
		var chemin := [Vector3(x_ouvert + dirx * 0.4, 0.0, z_a), Vector3(x_coin + dirx * ESC_PALIER * 0.5, 1.0, z_a),
				Vector3(x_coin + dirx * ESC_PALIER * 0.5, 1.0, z_b), Vector3(trou_x1 + dirx * 0.7, 1.0, z_b)]
		return {"x": x_ouvert, "dir": -dirx, "z_a": z_a, "z_b": z_b, "trou": trou, "emprise": r.grow(0.6),
				"depart": chemin[0], "arrivee": chemin[3], "chemin": chemin}
	return {}


## Volée d'escalier de « base » à « base + haut » : marches visibles + rampe de collision + garde-corps.
func _escalier(cage: Dictionary, base: float, haut: float) -> void:
	var nb := 15
	var run := ESC_LONG / nb
	var rise := haut / nb
	var dirx: float = cage.dir
	for i in nb:
		var xm: float = cage.x + dirx * (i + 0.5) * run
		var top := base + (i + 1) * rise
		_box(Vector3(xm, top - (rise + 0.25) / 2.0, cage.z_a), Vector3(run + 0.01, rise + 0.25, ESC_LARG), Color(0.82, 0.8, 0.76), false, "beton")
	# rampe invisible inclinée (les personnages montent dessus sans à-coups)
	var p0 := Vector3(cage.x, base, cage.z_a)
	var p1 := Vector3(cage.x + dirx * ESC_LONG, base + haut, cage.z_a)
	var milieu := (p0 + p1) * 0.5
	var longueur := p0.distance_to(p1)
	var ang := atan2(haut, ESC_LONG) * dirx
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(longueur, 0.12, ESC_LARG)
	cs.shape = bs
	cs.transform = Transform3D(Basis(Vector3(0, 0, 1), ang), milieu + Vector3(0, -0.06, 0))
	var kch := _chunk(milieu)
	if not bodies.has(kch):
		var b := StaticBody3D.new()
		b.collision_layer = Game.LAYER_WORLD
		b.collision_mask = 0
		add_child(b)
		bodies[kch] = b
	bodies[kch].add_child(cs)
	# dessous de la première volée plein (on ne peut pas passer dessous) ;
	# aux étages, le dessous de la volée est la trémie de celle d'en dessous : on le laisse libre
	for seg in (3 if base < 0.1 else 0):
		var f0 := float(seg + 1) / 3.0 - 1.0 / 3.0
		var hseg := base + haut * f0 - 0.5   # assez bas pour ne pas gêner ceux qui montent
		if hseg - base > 0.3:
			var xm2: float = cage.x + dirx * ESC_LONG * (f0 + 1.0 / 6.0)
			_box(Vector3(xm2, (base + hseg) / 2.0, cage.z_a), Vector3(ESC_LONG / 3.0, hseg - base, ESC_LARG - 0.05), Color(0.8, 0.79, 0.75), true, "enduit")
	# garde-corps entre la volée et le passage, à l'étage d'arrivée (le long du trémie)
	var tr: Rect2 = cage.trou
	var zg: float = (cage.z_a + cage.z_b) * 0.5
	_box(Vector3(tr.get_center().x, base + haut + 0.5, zg), Vector3(tr.size.x, 1.0, 0.05), Color(0.25, 0.25, 0.27), true, "metal")
	_box(Vector3(tr.get_center().x, base + haut + 1.0, zg), Vector3(tr.size.x, 0.06, 0.08), Color(0.35, 0.25, 0.18), false, "planches")


## Dalle horizontale avec un trou rectangulaire (trémie d'escalier).
func _dalle(r: Rect2, trou: Rect2, y0: float, y1: float, col: Color, m: String, solide: bool) -> void:
	var rs: Array = []
	if trou.size == Vector2.ZERO:
		rs = [r]
	else:
		rs = [Rect2(r.position.x, r.position.y, r.size.x, trou.position.y - r.position.y),
			Rect2(r.position.x, trou.end.y, r.size.x, r.end.y - trou.end.y),
			Rect2(r.position.x, trou.position.y, trou.position.x - r.position.x, trou.size.y),
			Rect2(trou.end.x, trou.position.y, r.end.x - trou.end.x, trou.size.y)]
	for q in rs:
		if q.size.x > 0.02 and q.size.y > 0.02:
			_box(Vector3(q.get_center().x, (y0 + y1) / 2.0, q.get_center().y), Vector3(q.size.x, y1 - y0, q.size.y), col, solide, m)


## Porte à deux battants dans une ouverture de façade.
func _porte(dp: Vector3, along_x: bool, o: Vector3) -> void:
	var p = Porte.new()
	add_child(p)
	p.position = dp
	# repère de la porte : X le long du mur ; on tourne pour les murs est/ouest
	p.rotation.y = 0.0 if along_x else PI / 2.0
	var vers_int := -o
	var local_z: Vector3 = p.basis.inverse() * vers_int
	p.setup(DOOR_W, DOOR_H, signf(local_z.z) if absf(local_z.z) > 0.1 else 1.0, [Color(0.55, 0.38, 0.22), Color(0.35, 0.3, 0.28), Color(0.6, 0.6, 0.58), Color(0.3, 0.38, 0.5)][rng.randi() % 4])
	p.idx = portes.size()
	portes.append(p)
	p.basculer(rng.randf() < 0.45, true)
	portes_bat.append(p)


const CADRES := [Color(0.92, 0.92, 0.9), Color(0.25, 0.25, 0.26), Color(0.35, 0.24, 0.16), Color(0.6, 0.6, 0.6)]


## Revêtement de façade selon le type de bâtiment.
func _facade(kind: String, h: float) -> String:
	match kind:
		"militaire", "armurerie_mil":
			return "parpaing"
		"grange":
			return "planches"
		"garage":
			return "parpaing"
		"eglise":
			return "enduit" if rng.randf() < 0.6 else "brique"
		"hopital", "station", "police":
			return "enduit"
		"quincaillerie", "armurerie":
			return "brique" if rng.randf() < 0.5 else "parpaing"
		"maison", "ferme":
			if h > 10.0:
				return "brique" if rng.randf() < 0.55 else "enduit"
			return "enduit" if rng.randf() < 0.7 else "brique"
	return "brique" if rng.randf() < 0.5 else "enduit"


## Boîte posée contre une façade : a = position le long du mur, off = décalage vers l'extérieur.
func _sur_facade(along_x: bool, face: float, sgn: float, a: float, yc: float, off: float, larg: float, haut: float, ep: float, col: Color, m: String, solid := false) -> void:
	if along_x:
		_box(Vector3(a, yc, face + sgn * off), Vector3(larg, haut, ep), col, solid, m)
	else:
		_box(Vector3(face + sgn * off, yc, a), Vector3(ep, haut, larg), col, solid, m)


## Bandeau horizontal (soubassement, corniche d'étage), interrompu au niveau de la porte.
func _bande(along_x: bool, face: float, sgn: float, a0: float, a1: float, y0: float, y1: float, ep: float, col: Color, m: String, porte: bool, dc: float) -> void:
	var segs := [[a0, a1]]
	if porte:
		segs = [[a0, dc - DOOR_W / 2.0], [dc + DOOR_W / 2.0, a1]]
	for sg in segs:
		if sg[1] - sg[0] > 0.05:
			_sur_facade(along_x, face, sgn, (sg[0] + sg[1]) / 2.0, (y0 + y1) / 2.0, ep / 2.0, sg[1] - sg[0], y1 - y0, ep, col, m)


## Fenêtre : cadre, vitre (parfois cassée), meneau, appui en béton ; parfois condamnée par des planches.
func _fenetre(along_x: bool, face: float, sgn: float, a: float, y: float, kind: String) -> void:
	var larg := 1.3
	var haut := 1.1
	var y0 := y
	if y < INT_H and kind in ["magasin", "station", "supermarche"]:
		larg = 2.7   # vitrine
		haut = 1.9
		y0 = 0.5
	var yc := y0 + haut / 2.0
	var cadre: Color = CADRES[rng.randi() % CADRES.size()]
	_sur_facade(along_x, face, sgn, a, yc, 0.03, larg + 0.14, haut + 0.14, 0.06, cadre, "uni")
	var r := rng.randf()
	if r < 0.16:
		_sur_facade(along_x, face, sgn, a, yc, 0.065, larg, haut, 0.02, Color(0.03, 0.03, 0.035), "uni")   # vitre brisée
		# restes de verre accrochés dans un ou deux coins du cadre
		for i in rng.randi_range(1, 2):
			var lw := larg * rng.randf_range(0.2, 0.42)
			var lh := haut * rng.randf_range(0.18, 0.45)
			var sx := -1.0 if rng.randf() < 0.5 else 1.0
			var sy := -1.0 if rng.randf() < 0.5 else 1.0
			_sur_facade(along_x, face, sgn, a + sx * (larg - lw) / 2.0, yc + sy * (haut - lh) / 2.0, 0.07, lw, lh, 0.015, Color(0.6, 0.66, 0.72).darkened(rng.randf_range(0.0, 0.3)), "vitre")
	else:
		var teinte := Color(0.62, 0.68, 0.74).darkened(rng.randf_range(0.0, 0.3))
		_sur_facade(along_x, face, sgn, a, yc, 0.065, larg, haut, 0.02, teinte, "vitre")
	if larg < 2.0:
		_sur_facade(along_x, face, sgn, a, yc, 0.085, 0.05, haut, 0.03, cadre, "uni")
	_sur_facade(along_x, face, sgn, a, y0 - 0.04, 0.08, larg + 0.25, 0.07, 0.16, Color(0.8, 0.79, 0.76), "beton")
	if OS.get_environment("SANS_FACADES") != "":
		return
	# linteau au-dessus de la fenêtre
	_sur_facade(along_x, face, sgn, a, y0 + haut + 0.12, 0.05, larg + 0.3, 0.16, 0.1, Color(0.76, 0.75, 0.72), "beton")
	# volets battants sur les maisons (ouverts, parfois de travers)
	if kind == "maison" and larg < 2.0 and rng.randf() < 0.55:
		var vc: Color = [Color(0.25, 0.35, 0.28), Color(0.45, 0.25, 0.18), Color(0.3, 0.38, 0.5), Color(0.7, 0.68, 0.62)][rng.randi() % 4]
		for sd in [-1.0, 1.0]:
			if rng.randf() < 0.12:
				continue   # volet arraché
			_sur_facade(along_x, face, sgn, a + sd * (larg / 2.0 + 0.36), yc, 0.04, 0.6, haut + 0.1, 0.04, vc.darkened(rng.randf_range(0.0, 0.25)), "planches")
	if (r > 0.8 and y < INT_H) or (r > 0.94 and y >= INT_H):
		# planches clouées (souvent au rez-de-chaussée, parfois aux étages)
		for i in 3:
			var ty := y0 + haut * (0.2 + i * 0.3)
			_sur_facade(along_x, face, sgn, a + rng.randf_range(-0.1, 0.1), ty, 0.11, larg + 0.3, 0.2, 0.03, Color(0.75, 0.6, 0.45), "planches")


func _wall(along_x: bool, fixed: float, a0: float, a1: float, y0: float, y1: float, col: Color) -> void:
	if a1 - a0 < 0.05 or y1 - y0 < 0.05:
		return
	var mid := (a0 + a1) / 2.0
	var cy := (y0 + y1) / 2.0
	if along_x:
		_box(Vector3(mid, cy, fixed), Vector3(a1 - a0, y1 - y0, WALL_T), col)
	else:
		_box(Vector3(fixed, cy, mid), Vector3(WALL_T, y1 - y0, a1 - a0), col)


func _furnish(zone: Dictionary, kind: String, count: int, placed: Array) -> void:
	var furn_set: Array = FURN.get(kind, FURN["maison"])
	var ab: AABB = zone.aabb
	var ix0 := ab.position.x
	var ix1 := ab.position.x + ab.size.x
	var iz0 := ab.position.z
	var iz1 := ab.position.z + ab.size.z
	var n := 0
	var tries := 0
	while n < count and tries < count * 15:
		tries += 1
		var f: Array = furn_set[rng.randi() % furn_set.size()]
		var sz: Vector3 = f[1]
		var side: String = ["n", "s", "w", "e"][rng.randi() % 4]
		var size3: Vector3
		var pos: Vector3
		if side == "n" or side == "s":
			if ix1 - ix0 < sz.x + 0.4:
				continue
			size3 = sz
			pos.x = rng.randf_range(ix0 + sz.x / 2.0 + 0.1, ix1 - sz.x / 2.0 - 0.1)
			pos.z = iz0 + sz.z / 2.0 + 0.03 if side == "n" else iz1 - sz.z / 2.0 - 0.03
		else:
			if iz1 - iz0 < sz.x + 0.4:
				continue
			size3 = Vector3(sz.z, sz.y, sz.x)
			pos.z = rng.randf_range(iz0 + sz.x / 2.0 + 0.1, iz1 - sz.x / 2.0 - 0.1)
			pos.x = ix0 + sz.z / 2.0 + 0.03 if side == "w" else ix1 - sz.z / 2.0 - 0.03
		var rect := Rect2(pos.x - size3.x / 2.0, pos.z - size3.z / 2.0, size3.x, size3.z)
		var ok := true
		for r in placed:
			if r.grow(0.25).intersects(rect):
				ok = false
				break
		if ok:
			for dp in zone.doors:
				if Vector2(dp.pos.x, dp.pos.z).distance_to(Vector2(pos.x, pos.z)) < 2.6:
					ok = false
					break
		if not ok:
			continue
		placed.append(rect)
		pos.y = ab.position.y
		var cont := _container(pos, size3, f[2], f[0], f[3] if f.size() > 3 else kind)
		var choix: Array = MODELES_MEUBLES.get(f[0], [])
		if not choix.is_empty():
			var ang: float = {"n": 0.0, "s": PI, "w": PI / 2.0, "e": -PI / 2.0}[side]
			cont.set_modele(choix[rng.randi() % choix.size()], ang)
			# meuble d'intérieur : visible de moins loin et sans ombre portée (sous un toit)
			if cont.modele:
				Decor.distance(cont.modele, 45.0)
			_sans_ombre(cont.modele)
		else:
			cont.set_texture("metal_peint")
		n += 1


func _container(pos: Vector3, size: Vector3, col: Color, label: String, table: String, rolls := -1) -> LootContainer:
	var c = LootContainer.new()
	c.uid = conteneurs.size()
	conteneurs.append(c)
	if rolls < 0:
		rolls = 1 + (1 if size.x * size.y * size.z > 1.0 else 0) + (1 if rng.randf() < 0.35 else 0)
	c.setup(label, table, size, col, rolls)
	add_child(c)
	c.position = pos
	return c


func _residents(zone: Dictionary, chance: float, max_n: int, kind := "civil") -> void:
	if zone == spawn_zone or rng.randf() > chance:
		return
	for i in rng.randi_range(1, max_n):
		guards.append({"pos": _random_in(zone, 1.2), "kind": kind, "radius": 4.0})


func _random_in(zone: Dictionary, margin: float) -> Vector3:
	var ab: AABB = zone.aabb
	return Vector3(rng.randf_range(ab.position.x + margin, ab.end.x - margin), ab.position.y + 0.1, rng.randf_range(ab.position.z + margin, ab.end.z - margin))


func _poi(label: String, pos: Vector3, col: Color) -> void:
	Game.pois.append({"name": label, "pos": pos, "color": col})


# ================================================================ ville
func _city(o: Vector3 = Vector3.ZERO, nb: int = NB, specials: Dictionary = {}, spawn_block := Vector2i(1, NB - 1), principale := true) -> void:
	var hv := nb * BLOCK / 2.0
	var ox := o.x
	var oz := o.z
	for i in nb + 1:
		var cx := ox - hv + i * BLOCK
		var cz := oz - hv + i * BLOCK
		_road(Vector2(cx, oz - hv - 5), Vector2(cx, oz + hv + 5), ROAD)
		_road(Vector2(ox - hv - 5, cz), Vector2(ox + hv + 5, cz), ROAD)
	# bordures de trottoir entre les carrefours
	for i in nb + 1:
		for j in nb:
			var a0 := -hv + j * BLOCK + ROAD / 2.0
			var a1 := -hv + (j + 1) * BLOCK - ROAD / 2.0
			var mid := (a0 + a1) / 2.0
			var c := -hv + i * BLOCK
			for sd in [-1.0, 1.0]:
				var off: float = c + sd * (ROAD / 2.0 - 0.12)
				_box(Vector3(ox + mid, 0.07, oz + off), Vector3(a1 - a0, 0.14, 0.24), Color(0.8, 0.8, 0.78), false, "beton")
				_box(Vector3(ox + off, 0.07, oz + mid), Vector3(0.24, 0.14, a1 - a0), Color(0.8, 0.8, 0.78), false, "beton")
	# lampadaires aux carrefours (allumés la nuit, certains en panne : eclairage_rues.gd)
	for i in nb + 1:
		for j in nb + 1:
			var p := Vector3(ox - hv + i * BLOCK + 6.0, 0, oz - hv + j * BLOCK + 6.0)
			if Decor.existe("lampadaire"):
				var lp := _prop("lampadaire", p, rng.randf() * TAU, false, 1.0, 200.0)
				if lp:
					lampadaires.append(lp)
				_box(p + Vector3(0, 2.0, 0), Vector3(0.2, 4.0, 0.2), Color.WHITE, true, "invisible")
			else:
				_box(p + Vector3(0, 3.0, 0), Vector3(0.18, 6.0, 0.18), Color(0.2, 0.2, 0.22))
				_box(p + Vector3(-0.6, 6.0, 0), Vector3(1.4, 0.15, 0.3), Color(0.2, 0.2, 0.22), false)
	if specials.is_empty() and principale:
		specials = {
			Vector2i(2, 2): "police", Vector2i(4, 4): "hopital", Vector2i(4, 2): "supermarche",
			Vector2i(2, 4): "armurerie", Vector2i(1, 3): "quincaillerie", Vector2i(3, 3): "parc",
			Vector2i(5, 1): "parc", Vector2i(5, 3): "centre_commercial", Vector2i(1, 5): "eglise", Vector2i(3, 1): "bibliotheque",
			Vector2i(1, 1): "garage", Vector2i(3, 5): "pharmacie", Vector2i(5, 5): "bar",
		}
	for bi in nb:
		for bj in nb:
			var bc := Vector3(ox - hv + (bi + 0.5) * BLOCK, 0, oz - hv + (bj + 0.5) * BLOCK)
			var key := Vector2i(bi, bj)
			var outer := bi == 0 or bj == 0 or bi == nb - 1 or bj == nb - 1
			# centre-ville dense (immeubles hauts) au milieu, pavillons sur le pourtour
			var dense := maxi(absi(bi - (nb - 1) / 2), absi(bj - (nb - 1) / 2)) <= 1
			if specials.has(key):
				match specials[key]:
					"police": _police(bc)
					"hopital": _hospital(bc)
					"supermarche": _supermarket(bc)
					"armurerie": _small_special(bc, "armurerie", "Armurerie", Color(0.3, 0.28, 0.27), Color(0.75, 0.3, 0.2))
					"quincaillerie": _small_special(bc, "quincaillerie", "Quincaillerie", Color(0.55, 0.45, 0.3), Color(0.8, 0.6, 0.2))
					"ecole": _small_special(bc, "bureau", "École", Color(0.78, 0.7, 0.55), Color(0.85, 0.75, 0.4))
					"pompiers": _small_special(bc, "quincaillerie", "Caserne de pompiers", Color(0.62, 0.2, 0.17), Color(0.9, 0.3, 0.25))
					"mairie": _small_special(bc, "bureau", "Hôtel de ville", Color(0.75, 0.72, 0.65), Color(0.8, 0.8, 0.7))
					"entrepot": _small_special(bc, "grange", "Entrepôt", Color(0.5, 0.52, 0.55), Color(0.55, 0.55, 0.6))
					"parc": _park(bc)
					"centre_commercial": _centre_commercial(bc)
					"eglise": _eglise(bc)
					"bibliotheque": _small_special(bc, "bibliotheque", "Bibliothèque", Color(0.72, 0.62, 0.5), Color(0.7, 0.55, 0.85), 16.0, 13.0, 7.0, 10)
					"garage": _garage(bc)
					"pharmacie": _pharmacie(bc)
					"bar": _small_special(bc, "bar", "Bar-restaurant", Color(0.55, 0.4, 0.3), Color(0.95, 0.5, 0.3), 15.0, 12.0, 4.5, 6)
			elif outer:
				_residential(bc, principale and key == spawn_block)
			elif dense:
				if rng.randf() < 0.5:
					_apartments(bc, true)
				else:
					_commercial(bc, true)
			elif rng.randf() < 0.35:
				_apartments(bc)
			else:
				_commercial(bc)
	# voitures abandonnées
	for n in int(55 * float(nb * nb) / float(NB * NB)):
		var i := rng.randi_range(0, nb)
		var along := rng.randf_range(-hv, hv)
		var line := -hv + i * BLOCK
		if fposmod(along + hv, BLOCK) < 9.0 or fposmod(along + hv, BLOCK) > BLOCK - 9.0:
			continue
		var lane := 2.4 * (1.0 if rng.randf() < 0.5 else -1.0)
		var col: Color = CAR_COLORS[rng.randi() % CAR_COLORS.size()].darkened(rng.randf_range(0.0, 0.35))
		if rng.randf() < 0.5:
			_car(Vector3(ox + along, 0, oz + line + lane), true, col)
		else:
			_car(Vector3(ox + line + lane, 0, oz + along), false, col)
	_mobilier_urbain(o, nb)


func _doors_toward_roads(qx: float, qz: float) -> Array:
	var opts := []
	opts.append("e" if qx > 0 else "w")
	opts.append("s" if qz > 0 else "n")
	return [opts[rng.randi() % 2]]


func _residential(bc: Vector3, is_spawn: bool) -> void:
	var first := true
	for qx in [-1.0, 1.0]:
		for qz in [-1.0, 1.0]:
			var w := rng.randf_range(9.0, 12.5)
			var d := rng.randf_range(8.0, 11.0)
			var c := bc + Vector3(qx * 8.5, 0, qz * 8.5)
			var h := INT_H + 0.3 if rng.randf() < 0.5 else 6.6
			var col: Color = HOUSE_COLORS[rng.randi() % HOUSE_COLORS.size()]
			var doors := _doors_toward_roads(qx, qz)
			var z := _building(c, w, d, h, col, doors, "maison", "", false, -1, Color(0.45, 0.4, 0.35), "pente" if rng.randf() < 0.6 else "plat")
			if is_spawn and first:
				spawn_zone = z
				for pp in z.portes:
					pp.basculer(true, true)
				var dr: Dictionary = z.doors[0]
				spawn_point = dr.out + (dr.out - dr.pos).normalized() * 1.0
				first = false
			else:
				_residents(z, 0.4, 2)
			_jardin(bc, qx, qz, doors[0])
	_reserve(Rect2(bc.x - 18, bc.z - 18, 36, 36))


func _commercial(bc: Vector3, dense := false) -> void:
	for sx in [-1.0, 1.0]:
		var w := rng.randf_range(13.0, 16.0)
		var d := rng.randf_range(26.0, 33.0)
		var h := rng.randf_range(12.0, 21.0) if dense else rng.randf_range(7.0, 16.0)
		var col: Color = CITY_COLORS[rng.randi() % CITY_COLORS.size()]
		var kind: String = (["bureau", "magasin", "bureau", "maison"] if dense else ["magasin", "bureau", "maison", "magasin"])[rng.randi() % 4]
		var doors := ["e" if sx > 0 else "w"]
		if rng.randf() < 0.5:
			doors.append("s" if rng.randf() < 0.5 else "n")
		var z := _building(bc + Vector3(sx * 9.5, 0, 0), w, d, h, col, doors, kind, "", true, -1, Color(0.5, 0.5, 0.5))
		_residents(z, 0.55, 3)


func _apartments(bc: Vector3, dense := false) -> void:
	var w := rng.randf_range(26.0, 32.0)
	var d := rng.randf_range(26.0, 32.0)
	var col: Color = CITY_COLORS[rng.randi() % CITY_COLORS.size()]
	var z := _building(bc, w, d, rng.randf_range(18.0, 26.0) if dense else rng.randf_range(12.0, 20.0), col, ["n", "s"], "maison", "", true, 12, Color(0.47, 0.47, 0.5))
	_residents(z, 0.8, 4)


func _park(bc: Vector3) -> void:
	_flat(Rect2(bc.x - 18, bc.z - 18, 36, 36), 0.01, Color(0.9, 0.95, 0.85), "herbe")
	Game.map_rects.append({"rect": Rect2(bc.x - 18, bc.z - 18, 36, 36), "color": Color(0.2, 0.35, 0.18)})
	for i in 14:
		trees.append(bc + Vector3(rng.randf_range(-16, 16), 0, rng.randf_range(-16, 16)))
	for i in 5:
		var p := bc + Vector3(rng.randf_range(-12, 12), 0, rng.randf_range(-12, 12))
		_box(p + Vector3(0, 0.45, 0), Vector3(1.8, 0.12, 0.5), Color(0.7, 0.5, 0.35), true, "planches")
	_box(bc + Vector3(0, 1.0, 0), Vector3(2.5, 2.0, 2.5), Color(0.85, 0.83, 0.8), true, "beton")
	_box(bc + Vector3(0, 3.0, 0), Vector3(0.8, 2.0, 0.8), Color(0.35, 0.45, 0.4), true, "metal")
	_reserve(Rect2(bc.x - 2, bc.z - 2, 4, 4))


func _police(bc: Vector3) -> void:
	var z := _building(bc + Vector3(0, 0, -3), 28.0, 20.0, 8.0, Color(0.38, 0.42, 0.5), ["s", "n"], "police", "Poste de police", true, 14, Color(0.25, 0.4, 0.75))
	# bandeau bleu
	_box(bc + Vector3(0, 3.0, 7.0 + 0.2), Vector3(10.0, 0.6, 0.1), Color(0.1, 0.2, 0.6), false)
	for i in 3:
		var col := Color(0.9, 0.9, 0.9) if i % 2 == 0 else Color(0.1, 0.15, 0.4)
		_car(bc + Vector3(-8.0 + i * 6.0, 0, 13.0), true, col, "voiture_police")
	_poi("Poste de police", bc, Color(0.35, 0.55, 1.0))
	for i in 5:
		guards.append({"pos": _random_in(z, 1.0), "kind": "police", "radius": 6.0})
	for i in 4:
		guards.append({"pos": bc + Vector3(rng.randf_range(-12, 12), 0.1, rng.randf_range(10, 15)), "kind": "police", "radius": 8.0})


func _hospital(bc: Vector3) -> void:
	var z := _building(bc, 32.0, 26.0, 16.0, Color(0.78, 0.78, 0.75), ["s", "e"], "hopital", "Hôpital", true, 16, Color(0.85, 0.85, 0.85))
	_box(bc + Vector3(0, 5.5, 13.2), Vector3(3.0, 0.8, 0.1), Color(0.8, 0.1, 0.1), false)
	_box(bc + Vector3(0, 5.5, 13.2), Vector3(0.8, 3.0, 0.1), Color(0.8, 0.1, 0.1), false)
	_poi("Hôpital", bc, Color(1.0, 0.35, 0.35))
	for sx in [-4.0, 4.0]:
		_prop("voiture_ambulance", bc + Vector3(sx, 0, 17.5), PI / 2.0 + rng.randf_range(-0.2, 0.2), true, 1.0, 220.0)
	for i in 7:
		guards.append({"pos": _random_in(z, 1.0), "kind": "patient", "radius": 6.0})
	for i in 4:
		guards.append({"pos": bc + Vector3(rng.randf_range(-14, 14), 0.1, 15.5), "kind": "patient", "radius": 8.0})


func _supermarket(bc: Vector3) -> void:
	var z := _building(bc + Vector3(0, 0, -3), 32.0, 24.0, 6.5, Color(0.6, 0.55, 0.48), ["s"], "magasin", "Supermarché", false, 8, Color(0.85, 0.65, 0.3))
	# rayons au centre
	var ab: AABB = z.aabb
	for i in 4:
		var x := ab.position.x + 6.0 + i * 5.5
		var rayon := _container(Vector3(x, 0, ab.get_center().z - 1.0), Vector3(1.0, 1.6, 9.0), Color(0.55, 0.55, 0.58), "Rayon", "magasin", 3)
		if Decor.existe("etagere_metal"):
			rayon.mesh_i.visible = false
			for k in 5:
				for sd in [-1.0, 1.0]:
					var e := Decor.instance("etagere_metal")
					e.scale = Vector3.ONE * 0.7
					e.rotation.y = sd * PI / 2.0
					e.position = Vector3(sd * 0.26, 0, -3.6 + k * 1.65)
					rayon.add_child(e)
					Decor.distance(e, 70.0)
	for i in 3:
		_car(bc + Vector3(-10.0 + i * 9.0, 0, 14.0), false, CAR_COLORS[rng.randi() % CAR_COLORS.size()])
	_poi("Supermarché", bc, Color(1.0, 0.75, 0.3))
	for i in 6:
		guards.append({"pos": _random_in(z, 1.0), "kind": "civil", "radius": 8.0})


## Couleurs des enseignes (fond, texte) par type de bâtiment.
const ENSEIGNES := {
	"pharmacie": [Color(0.1, 0.55, 0.25), Color(1, 1, 1)], "garage": [Color(0.15, 0.25, 0.5), Color(1.0, 0.85, 0.2)],
	"bar": [Color(0.35, 0.12, 0.08), Color(1.0, 0.75, 0.35)], "bibliotheque": [Color(0.25, 0.18, 0.12), Color(0.95, 0.9, 0.75)],
	"armurerie": [Color(0.12, 0.12, 0.12), Color(0.9, 0.3, 0.2)], "quincaillerie": [Color(0.75, 0.45, 0.1), Color(1, 1, 1)],
}


## Enseigne : panneau sur la façade (normale = direction de la rue) et texte en Label3D, visible à 90 m.
func _enseigne(centre: Vector3, normale: Vector3, texte: String, largeur: float, fond: Color, col_txt: Color, haut := 0.6) -> void:
	var sur_x := absf(normale.z) > 0.5
	var taille := Vector3(largeur, haut, 0.08) if sur_x else Vector3(0.08, haut, largeur)
	_box(centre + normale * 0.06, taille, fond, false, "uni")
	_box(centre + normale * 0.05, taille + Vector3(0.12, 0.12, 0.12) * Vector3(1 if sur_x else 0, 1, 0 if sur_x else 1), fond.darkened(0.5), false, "metal")
	var l := Label3D.new()
	l.text = texte
	l.font_size = 72
	l.outline_size = 0
	l.modulate = col_txt
	l.pixel_size = minf(haut * 0.62 / 72.0, largeur * 0.88 / (texte.length() * 0.62 * 72.0))
	l.position = centre + normale * 0.105
	l.rotation.y = atan2(normale.x, normale.z)
	l.double_sided = false
	l.visibility_range_end = 90.0
	l.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(l)


## Croix de pharmacie (verte, à plat sur une façade ou en drapeau).
func _croix_pharmacie(c: Vector3, normale: Vector3, t := 1.2) -> void:
	var sur_x := absf(normale.z) > 0.5
	var ep := 0.12
	_box(c + normale * 0.08, Vector3(t, t * 0.32, ep) if sur_x else Vector3(ep, t * 0.32, t), Color(0.1, 0.8, 0.25), false, "uni")
	_box(c + normale * 0.08, Vector3(t * 0.32, t, ep) if sur_x else Vector3(ep, t, t * 0.32), Color(0.1, 0.8, 0.25), false, "uni")


func _small_special(bc: Vector3, kind: String, label: String, col: Color, map_col: Color, w := 15.0, d := 12.0, h := 4.5, furn := 8, maisons := [Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]) -> Dictionary:
	var z := _building(bc + Vector3(-8.0, 0, -8.0), w, d, h, col, ["n", "w"], kind, label, false, furn, map_col)
	# enseigne au-dessus des vitrines de la façade nord
	var ens: Array = ENSEIGNES.get(kind, [Color(0.2, 0.22, 0.25), Color(0.95, 0.95, 0.9)])
	var zf := bc.z - 8.0 - d / 2.0
	var yen := 2.85
	_enseigne(Vector3(bc.x - 8.0, yen, zf), Vector3(0, 0, -1), label.to_upper(), minf(w - 2.0, 3.0 + label.length() * 0.42), ens[0], ens[1], 0.6)
	if kind == "pharmacie":
		_croix_pharmacie(Vector3(bc.x - 8.0 - w / 2.0 + 1.2, yen, zf), Vector3(0, 0, -1), 0.9)
		_croix_pharmacie(Vector3(bc.x - 8.0 + w / 2.0 - 1.2, yen, zf), Vector3(0, 0, -1), 0.9)
	_poi(label, bc + Vector3(-8.0, 0, -8.0), map_col)
	for i in 3:
		guards.append({"pos": _random_in(z, 1.0), "kind": "civil", "radius": 5.0})
	# maisons sur le reste du pâté
	for q in maisons:
		var c := bc + Vector3(q.x * 8.5, 0, q.y * 8.5)
		var hz := _building(c, rng.randf_range(9, 12), rng.randf_range(8, 11), 6.6, HOUSE_COLORS[rng.randi() % HOUSE_COLORS.size()], _doors_toward_roads(q.x, q.y), "maison", "", false, -1, Color(0.45, 0.4, 0.35))
		_residents(hz, 0.4, 2)
	return z


# ================================================================ régions (carte de 5 km)
## Deuxième ville (Valmont), au nord-est, plus petite que la ville de départ.
const VILLE_B := Vector3(1450, 0, -1350)
const NB_B := 5


## Le reste de la carte de 5 × 5 km : Valmont et sa zone industrielle, deux villages de plus,
## routes de campagne, fermes, stations-service, motel, maisons isolées, accidents de la route.
func _regions() -> void:
	var hx := -half + 4 * BLOCK   # autoroutes (mêmes que _countryside)
	var hz := -half + 3 * BLOCK
	var m := Game.map_half
	# --- Valmont
	var hvb := NB_B * BLOCK / 2.0
	_sol_ville(VILLE_B, hvb)
	_city(VILLE_B, NB_B, {
		Vector2i(1, 1): "police", Vector2i(3, 3): "hopital", Vector2i(3, 1): "supermarche",
		Vector2i(1, 3): "ecole", Vector2i(2, 2): "parc", Vector2i(2, 0): "pompiers",
		Vector2i(0, 2): "mairie", Vector2i(4, 2): "armurerie", Vector2i(2, 4): "quincaillerie",
		Vector2i(2, 3): "eglise", Vector2i(1, 2): "pharmacie", Vector2i(0, 4): "garage", Vector2i(4, 0): "bar",
	}, Vector2i(-1, -1), false)
	_poi("Valmont", VILLE_B, Color(0.95, 0.95, 0.95))
	# route d'accès depuis l'autoroute est-ouest (alignée sur une rue de la ville)
	var xa := VILLE_B.x - hvb + 2 * BLOCK
	_road(Vector2(xa, hz), Vector2(xa, VILLE_B.z + hvb + 5.0), 9.0)
	_ligne_electrique(Vector2(xa + 8.0, hz - 20.0), Vector2(xa + 8.0, VILLE_B.z + hvb + 20.0))
	# zone industrielle à l'est de Valmont
	_zone_industrielle(Vector3(VILLE_B.x + hvb + 75.0, 0, VILLE_B.z), VILLE_B.x + hvb + 5.0)
	# --- routes secondaires, voie ferrée, forêts, fermes et maisons le long des routes
	_plan_campagne()
	_lieux_uniques()
	_nature_plan()
	# --- villages reliés par leur route
	_village_relie(Vector3(-1500, 0, -1400), "Village des Granges", hz)
	_village_relie(Vector3(1300, 0, 1550), "Village de Pont-Rouge", hz)
	# --- fermes le long des nouvelles routes (chemin de terre jusqu'à la route la plus proche)
	_farm(Vector3(-1450, 0, -900), -1610.0, 1.0e6, "Ferme des Granges")
	_farm(Vector3(1300, 0, 900), 1190.0, 1.0e6, "Ferme du Pont")
	_farm(Vector3(xa + 90.0, 0, -700), xa, 1.0e6, "Ferme de Valmont")
	_farm(Vector3(-1100, 0, hz + 120.0), 1.0e6, hz, "Ferme de la Plaine")
	_farm(Vector3(900, 0, hz - 140.0), 1.0e6, hz, "Ferme des Hauts")
	# --- le long des autoroutes : stations, motel, relais, maisons isolées, accidents
	_gas_station(Vector3(hx + 24.0, 0, -1700.0))
	_gas_station(Vector3(1900.0, 0, hz + 24.0))
	_gas_station(Vector3(-1900.0, 0, hz + 24.0))
	_motel(Vector3(hx + 30.0, 0, 1300.0))
	_motel(Vector3(-900.0, 0, hz - 32.0))
	for c in [Vector3(1100.0, 0, hz), Vector3(-1350.0, 0, hz), Vector3(hx, 0, 1900.0), Vector3(hx, 0, -1200.0)]:
		_carambolage(c, absf(c.z - hz) < 1.0)
	for i in 26:
		var along := rng.randf_range(820.0, m - 60.0) * (1.0 if rng.randf() < 0.5 else -1.0)
		var off := 18.0 * (1.0 if rng.randf() < 0.5 else -1.0)
		var c: Vector3
		var doors: Array
		if rng.randf() < 0.5:
			c = Vector3(hx + off, 0, along)
			doors = ["w" if off > 0 else "e"]
		else:
			c = Vector3(along, 0, hz + off)
			doors = ["n" if off > 0 else "s"]
		if _overlaps(Rect2(c.x - 8, c.z - 8, 16, 16)):
			continue
		var zm := _building(c, rng.randf_range(9, 12), rng.randf_range(8, 10), 6.6, HOUSE_COLORS[rng.randi() % HOUSE_COLORS.size()], doors, "maison", "", false, -1, Color(0.45, 0.4, 0.35), "pente")
		_residents(zm, 0.5, 2)
	_nouveaux_lieux(hx, hz)
	# voitures abandonnées sur les grandes routes lointaines
	for i in 40:
		var t := rng.randf_range(800.0, m - 30.0) * (1.0 if rng.randf() < 0.5 else -1.0)
		var col: Color = CAR_COLORS[rng.randi() % CAR_COLORS.size()].darkened(0.3)
		if rng.randf() < 0.5:
			_car(Vector3(hx + rng.randf_range(-3, 3), 0, t), false, col)
		else:
			_car(Vector3(t, 0, hz + rng.randf_range(-3, 3)), true, col)


## Village relié par une route nord-sud depuis l'autoroute est-ouest (z = hz) ; la rue principale part de cette route.
func _village_relie(c: Vector3, nom: String, hz: float) -> void:
	var xr := c.x - 110.0
	_road(Vector2(xr, hz), Vector2(xr, c.z), 9.0)
	_ligne_electrique(Vector2(xr + 8.0, hz + signf(c.z - hz) * 20.0), Vector2(xr + 8.0, c.z - signf(c.z - hz) * 15.0))
	_village(c, xr, nom, false)


## Motel au bord de la route : deux ailes de chambres, réception, parking avec voitures.
func _motel(c: Vector3) -> void:
	var col := Color(0.82, 0.74, 0.6)
	var z1 := _building(c, 30.0, 9.0, 4.0, col, ["s"], "maison", "Motel de la Route", true, 10, Color(0.75, 0.6, 0.45))
	var z2 := _building(c + Vector3(-11.0, 0, 15.0), 8.0, 20.0, 4.0, col.darkened(0.08), ["e"], "bureau", "", true, 6, Color(0.75, 0.6, 0.45))
	_residents(z1, 0.8, 4)
	_residents(z2, 0.6, 2)
	_flat(Rect2(c.x - 4.0, c.z + 6.0, 22.0, 20.0), 0.02, Color(0.9, 0.9, 0.9), "asphalte")
	_reserve(Rect2(c.x - 18.0, c.z - 6.0, 38.0, 34.0), Color(0.5, 0.42, 0.32))
	for i in 3:
		_car(c + Vector3(rng.randf_range(0.0, 14.0), 0, rng.randf_range(10.0, 22.0)), rng.randf() < 0.5, CAR_COLORS[rng.randi() % CAR_COLORS.size()].darkened(0.25))
	_poi("Motel", c, Color(0.95, 0.65, 0.4))


## Zone industrielle : trois entrepôts autour d'une cour bétonnée, palettes et camions ; route vers la ville.
func _zone_industrielle(c: Vector3, x_ville: float) -> void:
	_road(Vector2(x_ville, c.z), Vector2(c.x - 20.0, c.z), 9.0)
	_flat(Rect2(c.x - 20.0, c.z - 45.0, 90.0, 90.0), 0.015, Color(0.82, 0.82, 0.8), "beton")
	_reserve(Rect2(c.x - 22.0, c.z - 47.0, 94.0, 94.0), Color(0.4, 0.4, 0.42))
	var gris := [Color(0.55, 0.57, 0.6), Color(0.62, 0.6, 0.55), Color(0.5, 0.52, 0.5)]
	var places := [Vector3(10.0, 0, -28.0), Vector3(48.0, 0, -28.0), Vector3(30.0, 0, 26.0)]
	var noms := ["Entrepôt Logistique", "Usine de pièces", "Entrepôt frigorifique"]
	for k in 3:
		var z := _building(c + places[k], 30.0, 20.0, 7.5, gris[k], ["n", "s"] if k < 2 else ["n"], "grange", noms[k], false, 9, Color(0.5, 0.5, 0.55))
		_residents(z, 0.8, 4)
	for i in 10:
		var p := c + Vector3(rng.randf_range(-10.0, 60.0), 0, rng.randf_range(-6.0, 6.0))
		_prop(["palette", "caisse_bois", "baril_bleu", "baril_rouge", "pneu"][rng.randi() % 5], p, rng.randf() * TAU, true, 1.0, 120.0)
	for i in 3:
		_car(c + Vector3(rng.randf_range(0.0, 50.0), 0, rng.randf_range(-8.0, 8.0)), true, Color(0.75, 0.75, 0.72).darkened(rng.randf_range(0.0, 0.3)), "voiture_suv")
	_poi("Zone industrielle", c + Vector3(30.0, 0, 0), Color(0.6, 0.6, 0.65))


# ================================================================ campagne
func _countryside() -> void:
	var hx := -half + 4 * BLOCK   # autoroute nord-sud
	var hz := -half + 3 * BLOCK   # autoroute est-ouest
	var m := Game.map_half
	# tracé de la rivière (au nord de la ville), réservé avant tout le reste
	relief = Relief.new()
	relief.riv_p1 = rng.randf() * TAU
	relief.riv_p2 = rng.randf() * TAU
	var xr := -m - 150.0
	while xr < m + 150.0:
		var zr: float = relief.riviere_z(xr)
		reserved.append(Rect2(xr - 4.0, zr - 15.0, 8.0, 30.0))
		xr += 8.0
	_road(Vector2(hx, half + 5), Vector2(hx, m), 11.0)
	_road(Vector2(hx, -m), Vector2(hx, -half - 5), 11.0)
	_road(Vector2(half + 5, hz), Vector2(m, hz), 11.0)
	_road(Vector2(-m, hz), Vector2(-half - 5, hz), 11.0)
	# voitures sur l'autoroute
	for i in 18:
		var t := rng.randf_range(half + 20, m - 20) * (1.0 if rng.randf() < 0.5 else -1.0)
		var col: Color = CAR_COLORS[rng.randi() % CAR_COLORS.size()].darkened(0.3)
		if rng.randf() < 0.5:
			_car(Vector3(hx + rng.randf_range(-3, 3), 0, t), false, col)
		else:
			_car(Vector3(t, 0, hz + rng.randf_range(-3, 3)), true, col)
	_gas_station(Vector3(half + 70.0, 0, hz + 20.0))
	_village(Vector3(hx + 95.0, 0, 520.0), hx, "Village de Saint-Aubin")
	_village(Vector3(-470.0, 0, hz - 70.0), hz, "Hameau des Sources", true)
	_carambolage(Vector3(half + 230.0, 0, hz), true)
	_carambolage(Vector3(hx, 0, -half - 190.0), false)
	_grotte(Vector3(-500.0, 0, 470.0), hx)
	_farm(Vector3(-250, 0, 210), hx, hz, "Ferme des Peupliers")
	_farm(Vector3(250, 0, 245), hx, hz, "Ferme du Moulin")
	_farm(Vector3(265, 0, -215), hx, hz, "Ferme Bellevue")
	# maisons isolées le long des routes
	for i in 7:
		var along := rng.randf_range(half + 30, m - 40) * (1.0 if rng.randf() < 0.5 else -1.0)
		var off := 18.0 * (1.0 if rng.randf() < 0.5 else -1.0)
		var c: Vector3
		var doors: Array
		if rng.randf() < 0.5:
			c = Vector3(hx + off, 0, along)
			doors = ["w" if off > 0 else "e"]
		else:
			c = Vector3(along, 0, hz + off)
			doors = ["n" if off > 0 else "s"]
		if _overlaps(Rect2(c.x - 8, c.z - 8, 16, 16)):
			continue
		var z := _building(c, rng.randf_range(9, 12), rng.randf_range(8, 10), 6.6, HOUSE_COLORS[rng.randi() % HOUSE_COLORS.size()], doors, "maison", "", false, -1, Color(0.45, 0.4, 0.35))
		_residents(z, 0.5, 2)


## Zones réservées indexées par cases de 64 m (la liste ne fait que grandir : indexation au fil de l'eau).
var _index_res := {}
var _nb_indexe := 0
const CASE_RES := 64.0


func _overlaps(r: Rect2) -> bool:
	while _nb_indexe < reserved.size():
		var ri: Rect2 = reserved[_nb_indexe]
		for cx in range(floori(ri.position.x / CASE_RES), floori(ri.end.x / CASE_RES) + 1):
			for cz in range(floori(ri.position.y / CASE_RES), floori(ri.end.y / CASE_RES) + 1):
				var k := Vector2i(cx, cz)
				if not _index_res.has(k):
					_index_res[k] = []
				_index_res[k].append(_nb_indexe)
		_nb_indexe += 1
	for cx in range(floori(r.position.x / CASE_RES), floori(r.end.x / CASE_RES) + 1):
		for cz in range(floori(r.position.y / CASE_RES), floori(r.end.y / CASE_RES) + 1):
			for i in _index_res.get(Vector2i(cx, cz), []):
				if (reserved[i] as Rect2).intersects(r):
					return true
	return false


func _gas_station(c: Vector3) -> void:
	var z := _building(c + Vector3(0, 0, 6), 13.0, 9.0, 4.0, Color(0.7, 0.68, 0.6), ["n"], "station", "Station-service", false, 6, Color(0.95, 0.85, 0.3))
	# auvent + pompes
	for p in [Vector3(-6, 0, -6), Vector3(6, 0, -6), Vector3(-6, 0, -1), Vector3(6, 0, -1)]:
		_box(c + p + Vector3(0, 2.4, 0), Vector3(0.4, 4.8, 0.4), Color(0.8, 0.8, 0.8), true, "metal")
	_box(c + Vector3(0, 5.0, -3.5), Vector3(15.0, 0.4, 8.0), Color(0.8, 0.15, 0.1), true, "uni")
	_box(c + Vector3(0, 4.75, -3.5), Vector3(14.6, 0.1, 7.6), Color(0.9, 0.9, 0.88), false, "uni")
	_flat(Rect2(c.x - 8, c.z - 8, 16, 9), 0.025, Color(0.9, 0.9, 0.9), "beton")
	for x in [-2.5, 2.5]:
		_box(c + Vector3(x, 0.15, -3.5), Vector3(1.4, 0.3, 1.0), Color(0.8, 0.8, 0.78), true, "beton")
		_box(c + Vector3(x, 0.95, -3.5), Vector3(0.7, 1.3, 0.5), Color(0.85, 0.85, 0.8), true, "metal")
		_box(c + Vector3(x, 1.25, -3.5), Vector3(0.72, 0.35, 0.52), Color(0.8, 0.12, 0.08), false, "uni")
	_reserve(Rect2(c.x - 8, c.z - 8, 16, 12))
	_poi("Station-service", c, Color(1.0, 0.9, 0.3))
	for i in 2:
		guards.append({"pos": _random_in(z, 1.0), "kind": "civil", "radius": 6.0})


func _farm(c: Vector3, hx: float, hz: float, label: String) -> void:
	var house := _building(c, 12.0, 10.0, 6.6, Color(0.66, 0.6, 0.5), ["s"], "ferme", label, false, 6, Color(0.6, 0.45, 0.3))
	_prop("voiture_tracteur", c + Vector3(-9.0, 0, 8.0), rng.randf() * TAU, true, 1.0, 220.0)
	var barn := _building(c + Vector3(20, 0, -2), 16.0, 20.0, 8.0, Color(0.5, 0.18, 0.13), ["w", "e"], "grange", "Grange", false, 7, Color(0.6, 0.25, 0.2))
	_residents(house, 0.7, 2)
	_residents(barn, 0.8, 3)
	_poi(label, c, Color(0.85, 0.6, 0.35))
	plats.append(Rect2(c.x - 60, c.z - 50, 120, 110))
	# champs et clôtures
	for i in 4:
		var dir := signf(c.z)
		var fc := c + Vector3(-30.0 + (i % 2) * 48.0, 0, dir * (30.0 + floorf(i / 2.0) * 34.0))
		var r := Rect2(fc.x - 20, fc.z - 15, 40, 30)
		if _overlaps(r):
			continue
		champs.append(r)
		var fcol: Color = [Color(0.45, 0.4, 0.2), Color(0.35, 0.3, 0.18), Color(0.3, 0.38, 0.18)][i % 3]
		if i % 3 == 2:
			_flat(r, 0.012, Color(1.0, 0.95, 0.75), "herbe")
		else:
			_flat(r, 0.012, Color(1.0, 0.95, 0.85) if i % 3 == 0 else Color(0.85, 0.8, 0.75), "terre")
		Game.map_rects.append({"rect": r, "color": fcol.darkened(0.2)})
		reserved.append(r)
		# clôture (avec ouverture)
		_box(Vector3(fc.x, 0.5, r.position.y), Vector3(40, 1.0, 0.12), Color(0.65, 0.5, 0.38), true, "planches")
		_box(Vector3(fc.x - 10.5, 0.5, r.end.y), Vector3(19, 1.0, 0.12), Color(0.65, 0.5, 0.38), true, "planches")
		_box(Vector3(fc.x + 10.5, 0.5, r.end.y), Vector3(19, 1.0, 0.12), Color(0.65, 0.5, 0.38), true, "planches")
	# silo à grain derrière la grange (repère visible de loin)
	var ps := c + Vector3(34.0, 0, -9.0)
	if not _overlaps(Rect2(ps.x - 3.5, ps.z - 3.5, 7.0, 7.0)):
		_silo(ps)
	# chemin de terre jusqu'à la route
	var start := Vector2(c.x, c.z + 12.0)
	if absf(c.x - hx) < absf(c.z - hz):
		_road(start, Vector2(hx, start.y), 5.0, C_DIRT, false)
	else:
		_road(start, Vector2(start.x, hz), 5.0, C_DIRT, false)


# ================================================================ base militaire
func _military_base(c: Vector3) -> void:
	var w := 100.0
	var d := 90.0
	var x0 := c.x - w / 2.0
	var x1 := c.x + w / 2.0
	var z0 := c.z - d / 2.0
	var z1 := c.z + d / 2.0
	var wall_col := Color(0.82, 0.82, 0.78)
	var hgt := 4.5
	var mat_avant := cur_mat
	cur_mat = "parpaing"
	_flat(Rect2(x0, z0, w, d), 0.01, Color(0.85, 0.83, 0.78), "beton")
	Game.sols.append({"r": Rect2(x0, z0, w, d), "s": "beton"})
	Game.map_rects.append({"rect": Rect2(x0, z0, w, d), "color": Color(0.3, 0.35, 0.22)})
	# murs d'enceinte : portail à l'est, brèche au nord
	_box(Vector3(c.x, hgt / 2.0, z1), Vector3(w, hgt, 0.6), wall_col)
	_box(Vector3(x0, hgt / 2.0, c.z), Vector3(0.6, hgt, d), wall_col)
	var breach_x := c.x - 18.0
	_box(Vector3((x0 + breach_x - 1.6) / 2.0, hgt / 2.0, z0), Vector3(breach_x - 1.6 - x0, hgt, 0.6), wall_col)
	_box(Vector3((breach_x + 1.6 + x1) / 2.0, hgt / 2.0, z0), Vector3(x1 - breach_x - 1.6, hgt, 0.6), wall_col)
	for i in 4:  # gravats de la brèche
		_box(Vector3(breach_x + rng.randf_range(-3, 3), 0.3, z0 + rng.randf_range(-2.5, 2.5)), Vector3(rng.randf_range(0.6, 1.2), 0.6, rng.randf_range(0.6, 1.2)), wall_col.darkened(0.2), false)
	var gate := 4.0
	_box(Vector3(x1, hgt / 2.0, (z0 + c.z - gate) / 2.0), Vector3(0.6, hgt, c.z - gate - z0), wall_col)
	_box(Vector3(x1, hgt / 2.0, (c.z + gate + z1) / 2.0), Vector3(0.6, hgt, z1 - c.z - gate), wall_col)
	# barbelés (visuels)
	_box(Vector3(c.x, hgt + 0.3, z1), Vector3(w, 0.5, 0.3), Color(0.25, 0.25, 0.25), false, "metal")
	_box(Vector3(x0, hgt + 0.3, c.z), Vector3(0.3, 0.5, d), Color(0.25, 0.25, 0.25), false, "metal")
	# miradors
	for p in [Vector3(x0 + 3, 0, z0 + 3), Vector3(x1 - 3, 0, z0 + 3), Vector3(x0 + 3, 0, z1 - 3), Vector3(x1 - 3, 0, z1 - 3)]:
		for o in [Vector3(-1.5, 0, -1.5), Vector3(1.5, 0, -1.5), Vector3(-1.5, 0, 1.5), Vector3(1.5, 0, 1.5)]:
			_box(p + o + Vector3(0, 3.5, 0), Vector3(0.3, 7.0, 0.3), Color(0.6, 0.5, 0.38), true, "planches")
		_box(p + Vector3(0, 7.1, 0), Vector3(4.0, 0.25, 4.0), Color(0.6, 0.5, 0.38), true, "planches")
		_box(p + Vector3(0, 8.6, 0), Vector3(4.2, 0.2, 4.2), Color(0.55, 0.6, 0.45), false, "tole")
	# bâtiments
	var hangar := _building(c + Vector3(22, 0, -24), 26.0, 18.0, 9.0, Color(0.4, 0.43, 0.35), ["w", "n"], "militaire", "Hangar", false, 10, Color(0.35, 0.42, 0.28))
	var cas1 := _building(c + Vector3(-25, 0, 25), 24.0, 10.0, 4.0, Color(0.45, 0.47, 0.38), ["n"], "militaire", "Caserne", false, 8, Color(0.35, 0.42, 0.28))
	var cas2 := _building(c + Vector3(10, 0, 30), 24.0, 10.0, 4.0, Color(0.45, 0.47, 0.38), ["n"], "militaire", "Caserne", false, 8, Color(0.35, 0.42, 0.28))
	var arm := _building(c + Vector3(-35, 0, -25), 12.0, 10.0, 4.0, Color(0.32, 0.35, 0.28), ["e"], "armurerie_mil", "Armurerie militaire", false, 6, Color(0.6, 0.7, 0.3))
	# camions et sacs de sable
	_modele_ou_voiture("camion_mil", c + Vector3(30, 0, 5), 0.0, "voiture_suv", Color(0.28, 0.32, 0.2))
	_modele_ou_voiture("camion_mil", c + Vector3(37, 0, 8), 0.1, "voiture_suv", Color(0.28, 0.32, 0.2))
	_modele_ou_voiture("camion_mil", c + Vector3(-10, 0, -5), PI / 2.0, "voiture_suv", Color(0.28, 0.32, 0.2))
	for p in [Vector3(42, 0, -8), Vector3(42, 0, 8), Vector3(10, 0, 0), Vector3(-15, 0, 10), Vector3(-30, 0, -8)]:
		_box(c + p + Vector3(0, 0.6, 0), Vector3(1.2, 1.2, 5.0), Color(1.1, 1.0, 0.8), true, "terre")
	cur_mat = mat_avant
	_reserve(Rect2(x0 - 2, z0 - 2, w + 4, d + 4))
	_poi("Base militaire", c, Color(0.6, 0.8, 0.3))
	# chemin d'accès vers l'autoroute
	_road(Vector2(x1 + 3.0, c.z), Vector2(-half + 4 * BLOCK, c.z), 7.0, C_DIRT, false)
	# gardiens
	for i in 18:
		var p := Vector3(rng.randf_range(x0 + 4, x1 - 4), 0.1, rng.randf_range(z0 + 4, z1 - 4))
		if not Game.find_zone(p + Vector3.UP).is_empty():
			continue
		guards.append({"pos": p, "kind": "militaire", "radius": 14.0})
	for zz in [hangar, cas1, cas2]:
		for i in 3:
			guards.append({"pos": _random_in(zz, 1.0), "kind": "militaire", "radius": 5.0})
	for i in 4:
		guards.append({"pos": _random_in(arm, 1.0), "kind": "militaire", "radius": 3.0})
	for i in 4:
		guards.append({"pos": Vector3(x1 + rng.randf_range(4, 14), 0.1, c.z + rng.randf_range(-6, 6)), "kind": "militaire", "radius": 10.0})


# ================================================================ arbres
func _trees() -> void:
	var m := Game.map_half - 10.0
	var centers := []
	for i in 210:
		centers.append(Vector3(rng.randf_range(-m, m), 0, rng.randf_range(-m, m)))
	var candidates := trees.duplicate()
	for cc in centers:
		for i in 45:
			candidates.append(cc + Vector3(rng.randfn(0, 22), 0, rng.randfn(0, 22)))
	for i in 3800:
		candidates.append(Vector3(rng.randf_range(-m, m), 0, rng.randf_range(-m, m)))
	# forêts nommées : bien plus denses
	for f in forets:
		var r: float = f.r
		for i in int(r * r * 0.012):
			var a := rng.randf() * TAU
			candidates.append(f.c + Vector3(cos(a), 0, sin(a)) * r * sqrt(rng.randf()))
	var park_count := trees.size()
	var final: Array = []
	for idx in candidates.size():
		var p: Vector3 = candidates[idx]
		if absf(p.x) > m or absf(p.z) > m:
			continue
		if idx >= park_count:
			if absf(p.x) < half + 10 and absf(p.z) < half + 10:
				continue
			var r := Rect2(p.x - 2.5, p.z - 2.5, 5, 5)
			if _overlaps(r):
				continue
			if relief and (relief.dans_eau(p.x, p.z) or relief.pente(p.x, p.z) > 0.3):
				continue
		final.append(p)
	trees = final
	# collisions des troncs : un corps par case de 128 m (un seul corps à 10 000 formes est très lent à construire)
	var corps_cases := {}
	var feuillus := ["arbre_0", "arbre_1", "arbre_2", "arbre_3"]
	var sapins := ["sapin_0", "sapin_1", "sapin_2"]
	var modeles_ok := ResourceLoader.exists("res://modeles/arbres/arbre_0.res")
	# regroupement par variante et par zone de 128 m (chaque groupe est masqué hors du champ de vision)
	var groupes := {}
	for i in trees.size():
		var p: Vector3 = trees[i]
		var s := rng.randf_range(0.8, 1.3)
		var en_ville := (absf(p.x) < half + 10 and absf(p.z) < half + 10) or _dans_verger(p)
		p.y = relief.hauteur(p.x, p.z) - 0.1 if relief else 0.0
		# plus de sapins sur les hauteurs
		var p_sapin := 0.35 + smoothstep(6.0, 22.0, p.y) * 0.5
		var id: String = feuillus[rng.randi() % feuillus.size()] if (en_ville or rng.randf() > p_sapin) else sapins[rng.randi() % sapins.size()]
		# variété hors des villes : arbres morts et jeunes arbres
		var r_var := rng.randf()
		if not en_ville and r_var < 0.05:
			id = "mort_0" if r_var < 0.03 else "mort_1"
		elif not en_ville and r_var < 0.14 and id in feuillus:
			id = "jeune_0"
		var cle := "%s|%d|%d" % [id, floori(p.x / 128.0), floori(p.z / 128.0)]
		if not groupes.has(cle):
			groupes[cle] = []
		groupes[cle].append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s, s)), p))
		var cs := CollisionShape3D.new()
		var cyl := CylinderShape3D.new()
		cyl.radius = 0.3 * s
		cyl.height = 4.0 * s
		cs.shape = cyl
		cs.position = p + Vector3(0, 2.0 * s, 0)
		var kc := Vector2i(floori(p.x / 128.0), floori(p.z / 128.0))
		if not corps_cases.has(kc):
			var b := StaticBody3D.new()
			b.collision_layer = Game.LAYER_WORLD
			b.collision_mask = 0
			add_child(b)
			corps_cases[kc] = b
		corps_cases[kc].add_child(cs)
		arbres_ref.append([cle, groupes[cle].size() - 1, cs, groupes[cle][-1]])
	if not modeles_ok:
		return
	for cle in groupes:
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = load("res://modeles/arbres/%s.res" % str(cle).get_slice("|", 0))
		var xfs: Array = groupes[cle]
		mm.instance_count = xfs.size()
		for k in xfs.size():
			mm.set_instance_transform(k, xfs[k])
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.visibility_range_end = 450.0
		add_child(mmi)
		arbres_mm[cle] = mm


## Buissons, rochers, souches et troncs morts dans la campagne ; buissons dans les jardins.
func _vegetation() -> void:
	Game.buissons.clear()
	if not Decor.existe("buisson"):
		return
	var m := Game.map_half - 15.0
	var choix := [["buisson", false], ["buisson2", false], ["rocher", true], ["souche", true], ["tronc_mort", true], ["buisson", false],
			["buisson_fleuri_0", false], ["buisson_fleuri_1", false]]
	for i in 3000:
		var p := Vector3(rng.randf_range(-m, m), 0, rng.randf_range(-m, m))
		if absf(p.x) < half + 12 and absf(p.z) < half + 12:
			continue
		if _overlaps(Rect2(p.x - 2, p.z - 2, 4, 4)):
			continue
		if relief:
			if relief.dans_eau(p.x, p.z):
				continue
			p.y = relief.hauteur(p.x, p.z) - 0.05
		var c: Array = choix[rng.randi() % choix.size()]
		_prop(c[0], p, rng.randf() * TAU, c[1], rng.randf_range(0.7, 1.3), 220.0)
	# buissons dans les parcs et le long des maisons
	for t in trees:
		if absf(t.x) < half and absf(t.z) < half and rng.randf() < 0.6:
			_prop(["buisson", "buisson2", "buisson_fleuri_0", "buisson_fleuri_1"][rng.randi() % 4], t + Vector3(rng.randf_range(-3, 3), 0, rng.randf_range(-3, 3)), rng.randf() * TAU, false, rng.randf_range(0.6, 1.0), 150.0)



# ================================================================ village
## Village de maisons (toits en tuiles, jardins, clôtures) relié à l'autoroute.
## « route » = coordonnée de l'autoroute la plus proche ; « est_ouest » : village au bord de la route est-ouest.
func _village(c: Vector3, route: float, nom: String, est_ouest := false) -> void:
	var lg := 190.0
	# rue principale perpendiculaire à l'autoroute, puis rue transversale au centre du village
	var axe := Vector3(0, 0, 1) if est_ouest else Vector3(1, 0, 0)
	var trans := Vector3(1, 0, 0) if est_ouest else Vector3(0, 0, 1)
	var c_axe := c.z if est_ouest else c.x
	var sg := signf(c_axe - route)
	var debut := c - axe * (c_axe - route)          # point sur l'autoroute
	var fin := c + axe * sg * lg / 2.0
	_road(Vector2(debut.x, debut.z), Vector2(fin.x, fin.z), 8.0)
	var t1 := c - trans * 70.0
	var t2 := c + trans * 70.0
	_road(Vector2(t1.x, t1.z), Vector2(t2.x, t2.z), 7.0)
	_poi(nom, c, Color(0.9, 0.7, 0.45))
	Game.map_rects.append({"rect": Rect2(c.x - 100, c.z - 100, 200, 200), "color": Color(0.3, 0.33, 0.22, 0.35)})
	plats.append(Rect2(c.x - 95, c.z - 95, 190, 190))
	var maisons := 0
	var speciaux := [["Église", "eglise"], ["Épicerie", "magasin"], ["Mairie", "bureau"], ["Bar du village", "magasin"]]
	var rues := [[debut + axe * sg * 25.0, axe * sg, absf(c_axe - route) + lg / 2.0 - 30.0], [t1 + trans * 5.0, trans, 130.0]]
	for r in rues:
		var dep: Vector3 = r[0]
		var dir: Vector3 = r[1]
		var long: float = r[2]
		var cote := Vector3(-dir.z, 0, dir.x)
		var t := 6.0
		while t < long:
			for sd in [-1.0, 1.0]:
				var w := rng.randf_range(9.0, 12.0)
				var d := rng.randf_range(8.0, 10.0)
				var special := maisons % 5 == 2 and not speciaux.is_empty()
				if special:
					w += 4.0
					d += 3.0
				var demi := maxf(w, d) / 2.0 + 1.5
				var recul := demi + rng.randf_range(5.5, 7.5)
				var p: Vector3 = dep + dir * t + cote * sd * recul
				var rect := Rect2(p.x - demi, p.z - demi, demi * 2.0, demi * 2.0)
				if _overlaps(rect) or absf(p.x) > Game.map_half - 20 or absf(p.z) > Game.map_half - 20:
					continue
				# porte côté rue
				var vers_rue: Vector3 = -cote * sd
				var porte := ""
				if absf(vers_rue.x) > 0.5:
					porte = "e" if vers_rue.x > 0 else "w"
				else:
					porte = "s" if vers_rue.z > 0 else "n"
				var label := ""
				var kind := "maison"
				if special:
					var sp: Array = speciaux.pop_front()
					label = sp[0] + " (" + nom.get_slice(" ", nom.get_slice_count(" ") - 1) + ")"
					kind = sp[1]
				var h := 6.6 if rng.randf() < 0.65 else INT_H + 0.3
				if kind == "eglise":
					h = 8.0
				var col: Color = HOUSE_COLORS[rng.randi() % HOUSE_COLORS.size()].lightened(0.1)
				var z := _building(p, w, d, h, col, [porte], "maison" if kind == "eglise" else kind, label, false, -1, Color(0.55, 0.42, 0.32), "pente")
				_residents(z, 0.65, 3)
				maisons += 1
				# jardin : herbe, clôture basse en bois avec portillon côté rue
				var jr := Rect2(p.x - demi, p.z - demi, demi * 2.0, demi * 2.0)
				_flat(jr, 0.012, Color(0.95, 1.0, 0.9), "herbe")
				_cloture(jr, vers_rue)
				for b in 2:
					var bp := p + Vector3(rng.randf_range(-6.0, 6.0), 0, rng.randf_range(-6.0, 6.0))
					if absf(bp.x - p.x) > w / 2.0 + 1.2 or absf(bp.z - p.z) > d / 2.0 + 1.2:
						trees.append(bp)
			t += rng.randf_range(19.0, 24.0)
	# horde dans le village
	for i in 10:
		guards.append({"pos": c + Vector3(rng.randf_range(-60, 60), 0.1, rng.randf_range(-40, 40)), "kind": "civil", "radius": 25.0})


## Clôture en planches autour d'un jardin, ouverte du côté « ouverture ».
func _cloture(r: Rect2, ouverture: Vector3) -> void:
	var col := Color(0.75, 0.62, 0.45)
	var cotes := {"n": [Vector3(r.get_center().x, 0.5, r.position.y), Vector3(r.size.x, 1.0, 0.08), Vector3(0, 0, -1)],
		"s": [Vector3(r.get_center().x, 0.5, r.end.y), Vector3(r.size.x, 1.0, 0.08), Vector3(0, 0, 1)],
		"w": [Vector3(r.position.x, 0.5, r.get_center().y), Vector3(0.08, 1.0, r.size.y), Vector3(-1, 0, 0)],
		"e": [Vector3(r.end.x, 0.5, r.get_center().y), Vector3(0.08, 1.0, r.size.y), Vector3(1, 0, 0)]}
	for k in cotes:
		var e: Array = cotes[k]
		if Vector3(e[2]).dot(ouverture) > 0.5:
			# deux morceaux de part et d'autre du portillon (2,4 m)
			var long: float = maxf(e[1].x, e[1].z)
			var morceau := (long - 2.4) / 2.0
			var axe := Vector3(1, 0, 0) if e[1].x > e[1].z else Vector3(0, 0, 1)
			for sd in [-1.0, 1.0]:
				var ctr: Vector3 = e[0] + axe * sd * (1.2 + morceau / 2.0)
				var sz: Vector3 = Vector3(morceau, 1.0, 0.08) if axe.x > 0.5 else Vector3(0.08, 1.0, morceau)
				_box(ctr, sz, col, true, "planches")
		else:
			_box(e[0], e[1], col, true, "planches")


# ================================================================ zones infestées
## Carambolage sur l'autoroute : voitures entassées et horde de zombies (meilleur butin dans les coffres).
func _carambolage(c: Vector3, le_long_x: bool) -> void:
	for i in 22:
		var t := rng.randf_range(-45.0, 45.0)
		var lat := rng.randf_range(-4.5, 4.5)
		var p := c + (Vector3(t, 0, lat) if le_long_x else Vector3(lat, 0, t))
		_car(p, le_long_x, CAR_COLORS[rng.randi() % CAR_COLORS.size()].darkened(rng.randf_range(0.2, 0.5)))
	for i in 6:
		var t2 := rng.randf_range(-40.0, 40.0)
		var p2 := c + (Vector3(t2, 0, rng.randf_range(-3, 3)) if le_long_x else Vector3(rng.randf_range(-3, 3), 0, t2))
		var cont := _container(p2, Vector3(0.9, 0.5, 0.6), Color(0.3, 0.3, 0.3), "Coffre de voiture", "infeste", 3)
		cont.set_texture("metal_peint")
	for i in 26:
		var t3 := rng.randf_range(-50.0, 50.0)
		var p3 := c + (Vector3(t3, 0.1, rng.randf_range(-8, 8)) if le_long_x else Vector3(rng.randf_range(-8, 8), 0.1, t3))
		guards.append({"pos": p3, "kind": ["civil", "civil", "police", "militaire"][rng.randi() % 4], "radius": 30.0})
	_poi("Carambolage (zone infestée)", c, Color(1.0, 0.25, 0.2))
	Game.map_rects.append({"rect": Rect2(c.x - 55, c.z - 55, 110, 110), "color": Color(0.8, 0.1, 0.1, 0.25)})



# ================================================================ grotte du boss
## Colline rocheuse creusée d'un tunnel menant à une grande salle sombre où dort le Colosse.
## L'entrée est à l'est ; un chemin de terre la relie à l'autoroute nord-sud.
func _grotte(c: Vector3, route_x: float, nom := "") -> void:
	var col := Color(0.85, 0.82, 0.78)
	var x0 := c.x - 12.0      # salle : 24 × 24 m, 7 m de haut
	var x1 := c.x + 12.0
	var z0 := c.z - 12.0
	var z1 := c.z + 12.0
	var hs := 7.0
	var tl := 22.0            # tunnel : 22 m de long, 4,5 m de large, 4 m de haut
	var tw := 4.5
	var th := 4.0
	var ep := 2.0
	var tx1 := x1 + tl
	_road(Vector2(tx1 + 2.0, c.z), Vector2(route_x - 6.0, c.z), 5.0, C_DIRT, false)
	_reserve(Rect2(x0 - 12, z0 - 12, (tx1 - x0) + 24, (z1 - z0) + 24))
	Game.grotte_rect = Rect2(x0 - ep, z0 - ep, (tx1 - x0) + ep, (z1 - z0) + 2 * ep)
	# sol
	_flat(Rect2(x0, z0, x1 - x0, z1 - z0), 0.015, col.darkened(0.25), "roche")
	_flat(Rect2(x1, c.z - tw / 2.0, tl, tw), 0.015, col.darkened(0.25), "roche")
	# murs de la salle
	_box(Vector3(x0 - ep / 2.0, hs / 2.0, c.z), Vector3(ep, hs, z1 - z0 + 2 * ep), col, true, "roche")
	_box(Vector3(c.x, hs / 2.0, z0 - ep / 2.0), Vector3(x1 - x0 + 2 * ep, hs, ep), col, true, "roche")
	_box(Vector3(c.x, hs / 2.0, z1 + ep / 2.0), Vector3(x1 - x0 + 2 * ep, hs, ep), col, true, "roche")
	var mz := (z1 - z0 - tw) / 2.0
	_box(Vector3(x1 + ep / 2.0, hs / 2.0, z0 + mz / 2.0), Vector3(ep, hs, mz), col, true, "roche")
	_box(Vector3(x1 + ep / 2.0, hs / 2.0, z1 - mz / 2.0), Vector3(ep, hs, mz), col, true, "roche")
	_box(Vector3(x1 + ep / 2.0, (hs + th) / 2.0, c.z), Vector3(ep, hs - th, tw), col, true, "roche")
	_box(Vector3(c.x, hs + ep / 2.0, c.z), Vector3(x1 - x0 + 2 * ep, ep, z1 - z0 + 2 * ep), col, true, "roche")
	# tunnel
	var tcx := x1 + ep + (tl - ep) / 2.0
	_box(Vector3(tcx, th / 2.0, c.z - tw / 2.0 - ep / 2.0), Vector3(tl - ep, th, ep), col, true, "roche")
	_box(Vector3(tcx, th / 2.0, c.z + tw / 2.0 + ep / 2.0), Vector3(tl - ep, th, ep), col, true, "roche")
	_box(Vector3(tcx, th + ep / 2.0, c.z), Vector3(tl - ep, ep, tw + 2 * ep), col, true, "roche")
	# masse rocheuse autour (rochers géants purement visuels, hors de l'intérieur)
	var ext := Rect2(x0 - ep, z0 - ep, (tx1 - x0) + ep, (z1 - z0) + 2 * ep)
	for i in 46:
		var k := rng.randf_range(4.5, 8.0)
		var p := Vector3.ZERO
		var cote := i % 4
		match cote:
			0: p = Vector3(rng.randf_range(ext.position.x, ext.end.x), 0, ext.position.y - k * 0.5)
			1: p = Vector3(rng.randf_range(ext.position.x, ext.end.x), 0, ext.end.y + k * 0.5)
			2: p = Vector3(ext.position.x - k * 0.5, 0, rng.randf_range(ext.position.y, ext.end.y))
			3:
				# côté est : seulement autour de l'entrée
				var zz := rng.randf_range(ext.position.y, ext.end.y)
				if absf(zz - c.z) < tw / 2.0 + k * 0.9:
					zz = c.z + signf(zz - c.z + 0.01) * (tw / 2.0 + ep + k * 0.9)
				p = Vector3(tx1 - rng.randf_range(0.0, 4.0), 0, zz)
		p.y = -k * 0.25
		_prop("rocher", p, rng.randf() * TAU, false, k, 400.0)
	# façade : gros rochers de part et d'autre de l'entrée et au-dessus
	for sd in [-1.0, 1.0]:
		for j in 3:
			var kf := rng.randf_range(4.0, 6.0)
			_prop("rocher", Vector3(tx1 + kf * 0.35 - j * 5.0, -kf * 0.15 + j * 1.5, c.z + sd * (tw / 2.0 + ep + kf * 0.45)), rng.randf() * TAU, false, kf, 400.0)
	for j in 3:
		var kt := rng.randf_range(4.0, 5.5)
		_prop("rocher", Vector3(tx1 - 1.0 - j * 6.0, th + ep - kt * 0.2, c.z + rng.randf_range(-1.0, 1.0)), rng.randf() * TAU, false, kt, 400.0)
	# chapeau de rochers sur le toit
	for i in 18:
		var k2 := rng.randf_range(5.0, 9.0)
		var t := rng.randf()
		var p2: Vector3
		if t < 0.6:
			p2 = Vector3(rng.randf_range(x0, x1), hs + ep - k2 * 0.3, rng.randf_range(z0, z1))
		else:
			p2 = Vector3(rng.randf_range(x1 + 4.0, tx1 - 4.0), th + ep - k2 * 0.35, c.z + rng.randf_range(-3.0, 3.0))
		_prop("rocher", p2, rng.randf() * TAU, false, k2, 400.0)
	# intérieur : rochers, ossements (caisses cassées), lueur de braises
	for i in 7:
		var pr := Vector3(rng.randf_range(x0 + 1.5, x1 - 1.5), 0, rng.randf_range(z0 + 1.5, z1 - 1.5))
		if pr.distance_to(c) < 5.0 or absf(pr.z - c.z) < 3.0 and pr.x > x1 - 4.0:
			continue
		_prop("rocher", pr, rng.randf() * TAU, true, rng.randf_range(0.8, 1.6), 120.0)
	for i in 2:
		var lum := OmniLight3D.new()
		lum.light_color = Color(1.0, 0.45, 0.2)
		lum.light_energy = 0.7
		lum.omni_range = 7.0
		lum.position = Vector3(x0 + 2.0 + i * 20.0, 0.4, z0 + 2.0 + i * 20.0)
		decor.add_child(lum)
		_box(lum.position - Vector3(0, 0.3, 0), Vector3(0.9, 0.15, 0.9), Color(0.15, 0.08, 0.05), false)
	_grotte_details(c, x0, x1, z0, z1, hs, x1, tx1, tw, th, col)
	if nom != "":   # autre grotte : cache de contrebandiers gardée par des zombies, sans boss
		var cache := _container(Vector3(x0 + 2.0, 0, c.z), Vector3(1.4, 0.9, 0.9), Color(0.25, 0.3, 0.2), "Cache des contrebandiers", "armurerie", 5)
		cache.set_texture("metal_peint")
		for i in 4:
			var cp := _container(Vector3(rng.randf_range(x0 + 2, x1 - 2), 0, z1 - 1.5), Vector3(1.0, 0.7, 0.7), Color(0.4, 0.3, 0.2), "Caisse abandonnée", "infeste", 3)
			cp.set_texture("planches")
		for i in 10:
			guards.append({"pos": Vector3(rng.randf_range(x0 + 2, tx1 - 2.0), 0.1, c.z + rng.randf_range(-1.5, 1.5)), "kind": ["militaire", "civil", "civil"][i % 3], "radius": 5.0})
		_poi(nom, Vector3(c.x, 0, c.z), Color(0.7, 0.6, 0.85))
		Game.map_rects.append({"rect": Rect2(x0 - ep, z0 - ep, (tx1 - x0) + ep, (z1 - z0) + 2 * ep), "color": Color(0.42, 0.4, 0.38)})
		return
	# trésor du Colosse
	var coffre := _container(Vector3(x0 + 2.0, 0, c.z), Vector3(1.4, 0.9, 0.9), Color(0.25, 0.3, 0.2), "Cache du Colosse", "boss", 7)
	if Decor.existe("caisse_mil"):
		coffre.set_modele("caisse_mil", PI / 2.0)
	else:
		coffre.set_texture("metal_peint")
	for i in 3:
		var cp := _container(Vector3(rng.randf_range(x0 + 2, x1 - 2), 0, z1 - 1.5), Vector3(1.0, 0.7, 0.7), Color(0.4, 0.3, 0.2), "Caisse abandonnée", "infeste", 3)
		cp.set_texture("planches")
	# le boss et sa garde
	guards.append({"pos": c + Vector3(-2.0, 0.1, 0), "kind": "boss", "radius": 7.0})
	for i in 5:
		guards.append({"pos": Vector3(rng.randf_range(x1 + 3.0, tx1 - 2.0), 0.1, c.z + rng.randf_range(-1.2, 1.2)), "kind": "militaire" if i % 2 == 0 else "civil", "radius": 3.0})
	for i in 6:
		guards.append({"pos": Vector3(tx1 + rng.randf_range(4, 18), 0.1, c.z + rng.randf_range(-14, 14)), "kind": "civil", "radius": 12.0})
	_poi("Grotte du Colosse (boss)", Vector3(c.x, 0, c.z), Color(0.75, 0.3, 0.95))
	Game.map_rects.append({"rect": Rect2(x0 - ep, z0 - ep, (tx1 - x0) + ep, (z1 - z0) + 2 * ep), "color": Color(0.42, 0.4, 0.38)})



# ================================================================ relief
const TerrainShader = preload("res://shaders/terrain.gdshader")
const EauShader = preload("res://shaders/eau.gdshader")


## Collines, lacs, rivière, ponts, ponton, antenne, lignes électriques et rochers.
func _relief() -> void:
	var m := Game.map_half
	# --- lacs (dans la campagne, loin de tout)
	var essais := 0
	while relief.lacs.size() < 14 and essais < 1500:
		essais += 1
		var r := rng.randf_range(24.0, 46.0)
		var c := Vector2(rng.randf_range(-m + 80, m - 80), rng.randf_range(-m + 80, m - 80))
		if absf(c.x) < half + 60 and absf(c.y) < half + 60:
			continue
		var re := Rect2(c.x - r * 1.3 - 6, c.y - r * 1.3 - 6, r * 2.6 + 12, r * 2.6 + 12)
		if _overlaps(re) or relief.dist_riviere(c.x, c.y) < r * 1.4 + 30.0:
			continue
		var proche := false
		for l in relief.lacs:
			if Vector2(l.c).distance_to(c) < r + float(l.r) + 60.0:
				proche = true
		if proche:
			continue
		relief.lacs.append({"c": c, "r": r, "p": [rng.randf() * TAU, rng.randf() * TAU, rng.randf() * TAU], "prof": rng.randf_range(1.2, 1.8)})
		reserved.append(re)
	relief.lacs.append_array(lacs_speciaux)   # lacs du barrage et de la colonie (après les lacs tirés au hasard)
	# cabane de pêche et ponton sur le premier lac (côté ville)
	if not relief.lacs.is_empty():
		_cabane_peche(relief.lacs[0])
	# --- calcul du relief
	var occupe: Array = reserved.filter(func(r): return not non_plats.has(r))
	occupe.append_array(plats)
	relief.generer(rng.randi(), m, occupe)
	Game.relief = relief
	_poser_routes_drapees()
	# --- sol
	var tm := ShaderMaterial.new()
	tm.shader = TerrainShader
	for t in ["herbe", "terre", "roche"]:
		tm.set_shader_parameter(t, load("res://textures/%s_albedo.jpg" % t))
		tm.set_shader_parameter(t + "_n", load("res://textures/%s_normal.png" % t))
	var sol := Node3D.new()
	sol.name = "Sol"
	add_child(sol)
	# tuiles du sol construites à l'approche du joueur (chargement par morceaux)
	for cj in relief.nb_tuiles():
		for ci in relief.nb_tuiles():
			morceaux.differer(relief.centre_tuile(ci, cj), relief.tuile.bind(ci, cj, tm), sol)
	relief.construire_collision(self, Game.LAYER_WORLD)
	# image de la carte (M) calculée en parallèle
	tache_carte = WorkerThreadPool.add_task(func(): _carte_prete.call_deferred(relief.image_carte(m)))

	# --- eau
	var em := ShaderMaterial.new()
	em.shader = EauShader
	for k in ["vagues1", "vagues2"]:
		var nt := NoiseTexture2D.new()
		nt.width = 256
		nt.height = 256
		nt.seamless = true
		nt.as_normal_map = true
		nt.bump_strength = 6.0
		var fn := FastNoiseLite.new()
		fn.seed = rng.randi()
		fn.frequency = 0.03 if k == "vagues1" else 0.05
		nt.noise = fn
		em.set_shader_parameter(k, nt)
	var er := em.duplicate()
	er.set_shader_parameter("courant", Vector2(0.02, 0.0))
	_eau_riviere(er)
	for l in relief.lacs:
		_eau_lac(l, em)
	if not relief.lacs.is_empty():
		var l0: Vector2 = relief.lacs[0].c
		_poi("Étang", Vector3(l0.x, 0, l0.y), Color(0.4, 0.65, 0.95))
	# --- ponts là où une route traverse la rivière
	for rt in routes:
		if rt.x:
			continue
		var rr: Rect2 = rt.r
		var xc := rr.get_center().x
		var zr: float = relief.riviere_z(xc)
		if zr > rr.position.y and zr < rr.end.y:
			_pont(xc, zr, rr.size.x)
	_antenne()
	# --- lignes électriques le long des autoroutes
	var hx := -half + 4 * BLOCK
	var hz := -half + 3 * BLOCK
	_ligne_electrique(Vector2(hx + 9.0, half + 20.0), Vector2(hx + 9.0, m - 15.0))
	_ligne_electrique(Vector2(hx - 9.0, -half - 20.0), Vector2(hx - 9.0, -m + 15.0))
	_ligne_electrique(Vector2(half + 20.0, hz - 9.0), Vector2(m - 15.0, hz - 9.0))
	_ligne_electrique(Vector2(-half - 20.0, hz + 9.0), Vector2(-m + 15.0, hz + 9.0))
	_lignes_ht()
	_eoliennes()
	_details_routes()
	_nature_details()
	# --- rochers sur les pentes
	var n_roc := 0
	for i in 9000:
		if n_roc >= 900:
			break
		var p := Vector3(rng.randf_range(-m + 20, m - 20), 0, rng.randf_range(-m + 20, m - 20))
		if relief.pente(p.x, p.z) < 0.12 or _overlaps(Rect2(p.x - 3, p.z - 3, 6, 6)):
			continue
		var k := rng.randf_range(1.4, 4.0)
		p.y = relief.hauteur(p.x, p.z) - k * 0.3
		_prop("rocher", p, rng.randf() * TAU, true, k, 300.0)
		n_roc += 1



func _eau_riviere(materiau: Material) -> void:
	var verts := PackedVector3Array()
	var idx := PackedInt32Array()
	var x: float = -relief.demi
	var lg := Relief.RIV_DEMI_LARGEUR * 1.5
	var k := 0
	while x <= relief.demi:
		var z: float = relief.riviere_z(x)
		var s: float = relief.riviere_pente(x)
		var nrm := Vector2(-s, 1.0).normalized() * lg
		verts.append(Vector3(x - nrm.x, Relief.NIVEAU_EAU, z - nrm.y))
		verts.append(Vector3(x + nrm.x, Relief.NIVEAU_EAU, z + nrm.y))
		if k > 0:
			var a := (k - 1) * 2
			idx.append_array([a, a + 2, a + 1, a + 1, a + 2, a + 3])
		k += 1
		x += 4.0
	_maillage_eau(verts, idx, materiau)


func _eau_lac(l: Dictionary, materiau: Material) -> void:
	var c: Vector2 = l.c
	var verts := PackedVector3Array([Vector3(c.x, Relief.NIVEAU_EAU, c.y)])
	var idx := PackedInt32Array()
	var nseg := 64
	for i in nseg + 1:
		var a := TAU * i / nseg
		var r: float = Relief.rayon_lac(l, a) * 1.1
		verts.append(Vector3(c.x + cos(a) * r, Relief.NIVEAU_EAU, c.y + sin(a) * r))
		if i > 0:
			idx.append_array([0, i + 1, i])
	_maillage_eau(verts, idx, materiau)


func _maillage_eau(verts: PackedVector3Array, idx: PackedInt32Array, materiau: Material) -> void:
	var norms := PackedVector3Array()
	norms.resize(verts.size())
	norms.fill(Vector3.UP)
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = norms
	arr[Mesh.ARRAY_INDEX] = idx
	var am := ArrayMesh.new()
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	var mi := MeshInstance3D.new()
	mi.mesh = am
	mi.material_override = materiau
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


## Pont en béton (tablier + parapets) pour une route nord-sud au-dessus de la rivière.
func _pont(xc: float, zr: float, largeur: float) -> void:
	var lg := Relief.RIV_DEMI_LARGEUR * 3.2 + 8.0
	var col := Color(0.8, 0.79, 0.76)
	_box(Vector3(xc, -0.3, zr), Vector3(largeur + 1.2, 0.6, lg), col, true, "beton")
	for sd in [-1.0, 1.0]:
		_box(Vector3(xc + sd * (largeur / 2.0 + 0.35), 0.45, zr), Vector3(0.4, 0.9, lg), col, true, "beton")
		_box(Vector3(xc + sd * (largeur / 2.0 + 0.35), 0.95, zr), Vector3(0.5, 0.1, lg), col.darkened(0.1), false, "beton")
	# piles dans l'eau
	for dz in [-lg / 4.0, lg / 4.0]:
		_box(Vector3(xc, -1.6, zr + dz), Vector3(largeur - 2.0, 2.0, 1.0), col.darkened(0.15), true, "beton")
	_poi("Pont", Vector3(xc, 0, zr), Color(0.75, 0.75, 0.7))


## Cabane de pêcheur au bord d'un lac, avec un ponton en bois.
func _cabane_peche(l: Dictionary) -> void:
	var c: Vector2 = l.c
	var dir := (-c).normalized()
	var a := dir.angle()
	var r: float = Relief.rayon_lac(l, a)
	var pc := c + dir * (r + 9.0)
	var porte := ""
	if absf(dir.x) > absf(dir.y):
		porte = "w" if dir.x > 0 else "e"
	else:
		porte = "n" if dir.y > 0 else "s"
	var z := _building(Vector3(pc.x, 0, pc.y), 7.0, 6.0, 3.6, Color(0.55, 0.42, 0.3), [porte], "maison", "Cabane de pêche", false, 4, Color(0.55, 0.42, 0.3), "pente")
	_residents(z, 0.5, 1)
	# ponton : du bord vers le centre du lac
	var bois := Color(0.62, 0.48, 0.34)
	var p0 := c + dir * (r + 1.5)
	var p1 := c + dir * (r - 13.0)
	var mid := (p0 + p1) / 2.0
	var long := p0.distance_to(p1)
	var le_long_x := absf(dir.x) > absf(dir.y)
	var taille := Vector3(long, 0.2, 2.2) if le_long_x else Vector3(2.2, 0.2, long)
	# ponton droit le long de l'axe dominant (le caisson est une boîte alignée sur les axes)
	var dd := p1 - p0
	var ax := Vector2(signf(dd.x), 0) if le_long_x else Vector2(0, signf(dd.y))
	p0 = mid - ax * long / 2.0
	p1 = mid + ax * long / 2.0
	_box(Vector3(mid.x, 0.14, mid.y), taille, bois.darkened(0.45), true, "planches")
	_planches(p0, p1, 2.2, 0.26, bois)
	for t in 5:
		var pp := p0.lerp(p1, t / 4.0)
		for sd in [-1.0, 1.0]:
			var off := Vector2(0, sd * 1.0) if le_long_x else Vector2(sd * 1.0, 0)
			_box(Vector3(pp.x + off.x, -1.0, pp.y + off.y), Vector3(0.2, 2.4, 0.2), bois.darkened(0.3), false, "planches")
	# barque amarrée le long du ponton (« Boat » de Quaternius), fouillable
	var pb := p0.lerp(p1, 0.7) + (Vector2(0, 2.3) if le_long_x else Vector2(2.3, 0))
	var barque := _container(Vector3(pb.x, -0.3, pb.y), Vector3(3.2, 0.75, 1.75) if le_long_x else Vector3(1.75, 0.75, 3.2), Color(0.35, 0.3, 0.25), "Barque du pêcheur", "ferme", 3)
	barque.set_modele("barque", PI / 2.0 if le_long_x else 0.0)
	if barque.modele == null:
		barque.set_texture("planches")
	reserved.append(Rect2(minf(p0.x, p1.x) - 3, minf(p0.y, p1.y) - 3, absf(p1.x - p0.x) + 6, absf(p1.y - p0.y) + 6))


## Antenne relais sur le point le plus haut de la carte jouable.
func _antenne() -> void:
	var m := Game.map_half - 90.0
	var best := Vector3(0, -100, 0)
	var x := -m
	while x < m:
		var z := -m
		while z < m:
			var y: float = relief.hauteur(x, z)
			if y > best.y and relief.pente(x, z) < 0.25 and not _overlaps(Rect2(x - 6, z - 6, 12, 12)):
				best = Vector3(x, y, z)
			z += 8.0
		x += 8.0
	if best.y < 6.0:
		return
	var metal := Color(0.7, 0.7, 0.72)
	var hm := 30.0
	for o in [Vector2(-0.9, -0.9), Vector2(0.9, -0.9), Vector2(-0.9, 0.9), Vector2(0.9, 0.9)]:
		_box(best + Vector3(o.x, hm / 2.0 - 1.0, o.y), Vector3(0.18, hm, 0.18), metal, true, "metal")
	var y2 := 3.0
	while y2 < hm:
		_box(best + Vector3(0, y2, -0.9), Vector3(1.9, 0.08, 0.08), metal, false, "metal")
		_box(best + Vector3(0, y2, 0.9), Vector3(1.9, 0.08, 0.08), metal, false, "metal")
		_box(best + Vector3(-0.9, y2, 0), Vector3(0.08, 0.08, 1.9), metal, false, "metal")
		_box(best + Vector3(0.9, y2, 0), Vector3(0.08, 0.08, 1.9), metal, false, "metal")
		y2 += 3.0
	for k in 3:
		_box(best + Vector3(0.0, hm - 3.0 - k * 1.5, -1.2), Vector3(0.6, 1.2, 0.15), Color(0.85, 0.85, 0.85), false, "metal")
	var feu := OmniLight3D.new()
	feu.light_color = Color(1.0, 0.15, 0.1)
	feu.light_energy = 2.0
	feu.omni_range = 6.0
	feu.position = best + Vector3(0, hm, 0)
	decor.add_child(feu)
	_box(best + Vector3(0, hm - 0.8, 0), Vector3(0.35, 0.35, 0.35), Color(1.0, 0.2, 0.15), false, "uni")
	# local technique et clôture
	_box(best + Vector3(5.0, 0.8, 0), Vector3(4.0, 4.0, 3.0), Color(0.75, 0.74, 0.7), true, "beton")
	_box(best + Vector3(5.0, 2.85, 0), Vector3(4.4, 0.15, 3.4), Color(0.4, 0.4, 0.4), true, "tole")
	var caisse := _container(best + Vector3(5.0, 0.0, 2.3), Vector3(1.0, 0.8, 0.7), Color(0.4, 0.42, 0.45), "Armoire technique", "quincaillerie", 3)
	caisse.position.y = relief.hauteur(best.x + 5.0, best.z + 2.3) - 0.05
	caisse.set_texture("metal_peint")
	_poi("Antenne relais", best, Color(0.85, 0.85, 0.9))
	for i in 3:
		guards.append({"pos": best + Vector3(rng.randf_range(-6, 6), 0.4, rng.randf_range(-6, 6)), "kind": "civil", "radius": 8.0})


## Poteaux en bois et câbles le long d'un segment (axe x ou z).
func _ligne_electrique(a: Vector2, b: Vector2) -> void:
	var bois := Color(0.45, 0.36, 0.28)
	var long := a.distance_to(b)
	var dir := (b - a) / long
	var le_long_x := absf(dir.x) > 0.5
	var precedent := Vector3.INF
	var t := 0.0
	while t <= long:
		var p := a + dir * t
		t += 45.0
		var y: float = maxf(relief.hauteur(p.x, p.y), 0.0)
		if relief.dans_eau(p.x, p.y) or _overlaps(Rect2(p.x - 0.5, p.y - 0.5, 1, 1)):
			precedent = Vector3.INF
			continue
		_box(Vector3(p.x, y + 4.0, p.y), Vector3(0.28, 8.5, 0.28), bois, true, "planches")
		_box(Vector3(p.x, y + 7.8, p.y), Vector3(0.15, 0.15, 2.0) if le_long_x else Vector3(2.0, 0.15, 0.15), bois, false, "planches")
		var haut := Vector3(p.x, y + 7.9, p.y)
		if precedent != Vector3.INF and absf(precedent.y - haut.y) < 2.0:
			var mid := (precedent + haut) / 2.0
			for o in [-0.85, 0.0, 0.85]:
				var off := Vector3(0, -0.15, o) if le_long_x else Vector3(o, -0.15, 0)
				var sz := Vector3(absf(haut.x - precedent.x), 0.03, 0.03) if le_long_x else Vector3(0.03, 0.03, absf(haut.z - precedent.z))
				_box(mid + off, sz, Color(0.08, 0.08, 0.08), false, "uni")
		precedent = haut



## Plafonnier à néon ; certains sont encore alimentés (secours) et éclairent faiblement, parfois en clignotant.
func _plafonnier(p: Vector3, kind: String, important: bool) -> void:
	_box(p + Vector3(0, -0.03, 0), Vector3(0.3, 0.06, 1.25), Color(0.75, 0.75, 0.73), false, "metal")
	var chance := 0.55 if (important or kind in ["hopital", "police", "militaire", "magasin", "supermarche"]) else 0.22
	if rng.randf() > chance:
		return
	var tube := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.08, 0.04, 1.15)
	tube.mesh = bm
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.95, 0.97, 1.0)
	m.emission_enabled = true
	m.emission = Color(0.85, 0.93, 1.0)
	m.emission_energy_multiplier = 2.5
	tube.material_override = m
	tube.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	tube.position = p + Vector3(0, -0.075, 0)
	tube.visibility_range_end = 75.0
	decor.add_child(tube)
	var l := Neon.new()
	l.light_color = Color(0.82, 0.9, 1.0)
	l.base = rng.randf_range(0.7, 1.2)
	l.light_energy = l.base
	l.omni_range = 7.5
	l.omni_attenuation = 1.3
	l.shadow_enabled = false
	l.distance_fade_enabled = true     # lumières d'étage lointaines : estompées (coût par image)
	l.distance_fade_begin = 60.0
	l.distance_fade_length = 15.0
	l.position = p + Vector3(0, -0.25, 0)
	l.clignote = rng.randf() < 0.4
	l.mat_tube = m
	decor.add_child(l)



## Stalactites, stalagmites, rochers le long des parois et ossements dans la grotte.
func _grotte_details(c: Vector3, x0: float, x1: float, z0: float, z1: float, hs: float, tx0: float, tx1: float, tw: float, th: float, col: Color) -> void:
	var mat_roc: Material = mats["roche"].duplicate()
	(mat_roc as StandardMaterial3D).vertex_color_use_as_albedo = false
	(mat_roc as StandardMaterial3D).albedo_color = col.darkened(0.1)
	var cone := CylinderMesh.new()
	cone.top_radius = 0.35
	cone.bottom_radius = 0.0
	cone.height = 1.0
	cone.radial_segments = 7
	cone.rings = 1
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = cone
	var xfs: Array = []
	# stalactites (plafond de la salle et du tunnel)
	for i in 70:
		var dans_tunnel := i % 4 == 0
		var p := Vector3(rng.randf_range(x0 + 0.5, x1 - 0.5), hs, rng.randf_range(z0 + 0.5, z1 - 0.5))
		if dans_tunnel:
			p = Vector3(rng.randf_range(tx0 + 1.0, tx1 - 1.0), th, c.z + rng.randf_range(-tw / 2.0 + 0.4, tw / 2.0 - 0.4))
		var lg := rng.randf_range(0.4, 2.2) if not dans_tunnel else rng.randf_range(0.2, 0.8)
		var lr := rng.randf_range(0.5, 1.2)
		xfs.append(Transform3D(Basis.from_scale(Vector3(lr, lg, lr)), p - Vector3(0, lg / 2.0, 0)))
	# stalagmites (sol de la salle, hors du passage central)
	for i in 22:
		var p2 := Vector3(rng.randf_range(x0 + 0.8, x1 - 0.8), 0, rng.randf_range(z0 + 0.8, z1 - 0.8))
		if Vector2(p2.x - c.x, p2.z - c.z).length() < 6.0 or (absf(p2.z - c.z) < 3.0 and p2.x > x1 - 6.0):
			continue
		var lg2 := rng.randf_range(0.4, 1.6)
		var lr2 := rng.randf_range(0.6, 1.3)
		xfs.append(Transform3D(Basis(Vector3.RIGHT, PI) * Basis.from_scale(Vector3(lr2, lg2, lr2)), p2 + Vector3(0, lg2 / 2.0, 0)))
	mm.instance_count = xfs.size()
	for k in xfs.size():
		mm.set_instance_transform(k, xfs[k])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = mat_roc
	decor.add_child(mmi)
	# rochers encastrés dans les parois (cachent les murs droits)
	for i in 26:
		var cote := i % 4
		var p3 := Vector3.ZERO
		var k := rng.randf_range(1.6, 3.0)
		match cote:
			0: p3 = Vector3(x0 - 0.2, rng.randf_range(-0.5, 3.5), rng.randf_range(z0, z1))
			1: p3 = Vector3(rng.randf_range(x0, x1), rng.randf_range(-0.5, 3.5), z0 - 0.2)
			2: p3 = Vector3(rng.randf_range(x0, x1), rng.randf_range(-0.5, 3.5), z1 + 0.2)
			3:
				var zz := rng.randf_range(z0, z1)
				if absf(zz - c.z) < tw / 2.0 + 1.5:
					continue
				p3 = Vector3(x1 + 0.2, rng.randf_range(-0.5, 3.5), zz)
		_prop("rocher", p3, rng.randf() * TAU, false, k, 120.0)
	for i in 10:
		var p4 := Vector3(rng.randf_range(tx0 + 1.0, tx1 - 2.0), rng.randf_range(-0.6, 1.2), c.z + (tw / 2.0 + 0.3) * (1.0 if i % 2 == 0 else -1.0))
		_prop("rocher", p4, rng.randf() * TAU, false, rng.randf_range(1.0, 1.8), 120.0)
	# ossements et crânes autour du repaire
	var os_col := Color(0.86, 0.82, 0.72)
	var mat_os := StandardMaterial3D.new()
	mat_os.albedo_color = os_col
	mat_os.roughness = 0.8
	for i in 40:
		var a := rng.randf() * TAU
		var r := rng.randf_range(1.5, 9.0)
		var p5 := c + Vector3(cos(a) * r, 0.04, sin(a) * r)
		var mi := MeshInstance3D.new()
		if i % 6 == 0:
			var sm := SphereMesh.new()
			sm.radius = 0.11
			sm.height = 0.2
			mi.mesh = sm
			p5.y = 0.09
		else:
			var cm := CylinderMesh.new()
			cm.top_radius = 0.025
			cm.bottom_radius = 0.03
			cm.height = rng.randf_range(0.25, 0.5)
			mi.mesh = cm
			mi.rotation = Vector3(PI / 2.0, rng.randf() * TAU, 0)
		mi.material_override = mat_os
		mi.position = p5
		decor.add_child(mi)


## Dégage un cercle (camp construit après la génération) : arbres masqués, décor et collisions retirés.
func degager(centre: Vector3, r: float) -> void:
	var c2 := Vector2(centre.x, centre.z)
	var dedans := func(p: Vector3) -> bool: return Vector2(p.x, p.z).distance_to(c2) < r
	# les instances d'un MultiMesh d'arbres (case de 128 m) et les formes d'un corps de chunk sont à moins
	# de 182 m de la première : on saute d'un coup les groupes trop loin (sinon tous les arbres de la carte à chaque camp)
	var loin := func(p: Vector3) -> bool: return Vector2(p.x, p.z).distance_to(c2) > r + 182.0
	var enfants := get_children()
	enfants.append_array(morceaux.detaches(self))   # cases loin du joueur, hors de l'arbre
	for n in enfants:
		# arbres : instances des MultiMesh mises à l'échelle zéro
		if n is MultiMeshInstance3D and (n as MultiMeshInstance3D).multimesh:
			var mm: MultiMesh = (n as MultiMeshInstance3D).multimesh
			if mm.instance_count == 0 or loin.call(mm.get_instance_transform(0).origin):
				continue
			for k in mm.instance_count:
				var xf := mm.get_instance_transform(k)
				if dedans.call(xf.origin):
					mm.set_instance_transform(k, Transform3D(Basis.from_scale(Vector3.ZERO), xf.origin))
		# collisions (troncs, rochers…) : formes dont le centre est dans le cercle
		elif n is StaticBody3D:
			if n.position == Vector3.ZERO and n.get_child_count() > 0 and n.get_child(0) is CollisionShape3D and loin.call(n.get_child(0).position):
				continue
			for cs in n.get_children():
				if cs is CollisionShape3D and dedans.call((cs as CollisionShape3D).position) and _petite_forme((cs as CollisionShape3D).shape):
					cs.queue_free()
	if decor:
		var objets := decor.get_children()
		objets.append_array(morceaux.detaches(decor))
		for d in objets:
			if d is Node3D and dedans.call((d as Node3D).position):
				d.queue_free()
	for cle in Game.buissons:
		var liste: Array = Game.buissons[cle]
		for i in range(liste.size() - 1, -1, -1):
			if dedans.call(liste[i][0]):
				liste.remove_at(i)


## Forme d'un petit objet (tronc, rocher, caisse) — jamais le sol, un mur ou un bâtiment.
func _petite_forme(s: Shape3D) -> bool:
	if s is CylinderShape3D:
		return (s as CylinderShape3D).radius < 1.5
	if s is BoxShape3D:
		var t: Vector3 = (s as BoxShape3D).size
		return t.x < 5.0 and t.z < 5.0 and t.y < 5.0
	return false


# ================================================================ quartiers et nouveaux lieux
## Décor non fouillable posé dans les pièces : [modèle, nombre par étage], selon le type de bâtiment.
const DECO_PIECES := {
	# [modèle, nombre, chance par pièce (1 si absente)]
	"maison": [["canape", 1], ["table_bois", 1], ["lit_double", 1, 0.35], ["lit_simple", 1, 0.2], ["baignoire", 1, 0.12], ["lavabo", 1, 0.15], ["wc", 1, 0.12]],
	"ferme": [["table_bois", 1], ["canape", 1], ["lit_double", 1, 0.3], ["baignoire", 1, 0.1]],
	"bureau": [["bureau_ecole", 3]], "bibliotheque": [["table_bois", 3]], "bar": [["table_bois", 4], ["wc", 1, 0.3]],
	"police": [["bureau_ecole", 2]], "hopital": [["bureau_ecole", 1], ["lit_simple", 3, 0.8]], "motel": [["lit_double", 1, 0.8], ["lavabo", 1, 0.4]],
}


func _deco_piece(zone: Dictionary, kind: String, placed: Array) -> void:
	var ab: AABB = zone.aabb
	if ab.size.x < 5.0 or ab.size.z < 5.0:
		return
	for e in DECO_PIECES.get(kind, []):
		var id: String = e[0]
		var t := Decor.taille(id)
		if e.size() > 2 and rng.randf() > float(e[2]):
			continue
		for i in int(e[1]):
			for essai in 6:
				var quart := rng.randi_range(0, 3)
				var sx := t.x if quart % 2 == 0 else t.z
				var sz := t.z if quart % 2 == 0 else t.x
				var p := Vector3(rng.randf_range(ab.position.x + 1.3, ab.end.x - 1.3), ab.position.y, rng.randf_range(ab.position.z + 1.3, ab.end.z - 1.3))
				var r := Rect2(p.x - sx / 2.0, p.z - sz / 2.0, sx, sz)
				var ok := true
				for pr in placed:
					if (pr as Rect2).grow(0.7).intersects(r):
						ok = false
						break
				for dp in zone.doors:
					if Vector2(dp.pos.x, dp.pos.z).distance_to(Vector2(p.x, p.z)) < 3.0:
						ok = false
				for ps in zone.get("passages", []):
					if Vector2(ps.x, ps.z).distance_to(Vector2(p.x, p.z)) < 2.2:
						ok = false
				if not ok:
					continue
				placed.append(r)
				_sans_ombre(_prop(id, p, quart * PI / 2.0, true, 1.0, 30.0))
				break


## Objet d'intérieur : pas d'ombre portée (inutile sous un toit, et deux fois moins de dessin).
func _sans_ombre(n: Node3D) -> void:
	if n == null:
		return
	for g in n.find_children("*", "GeometryInstance3D", true, false):
		(g as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## Jardin d'une maison de quartier pavillonnaire : pelouse, haie ou muret (jamais devant la porte), arbre.
func _jardin(bc: Vector3, qx: float, qz: float, porte: String) -> void:
	_flat(Rect2(bc.x + (0.4 if qx > 0 else -17.6), bc.z + (0.4 if qz > 0 else -17.6), 17.2, 17.2), 0.012, Color(0.85, 0.95, 0.8), "herbe")
	if porte in ["e", "w"]:
		if rng.randf() < 0.6:
			_box(Vector3(bc.x + qx * 9.0, 0.55, bc.z + qz * 17.5), Vector3(16.0, 1.1, 0.7), Color(0.25, 0.4, 0.2), true, "herbe")
	elif rng.randf() < 0.5:
		_box(Vector3(bc.x + qx * 17.0, 0.4, bc.z + qz * 8.5), Vector3(0.25, 0.8, 14.0), Color(0.85, 0.84, 0.8), true, "beton")
	if rng.randf() < 0.5:
		trees.append(bc + Vector3(qx * 16.0, 0, qz * 16.0))


## Côté (n, s, e, w) correspondant à une direction horizontale.
func _cote(d: Vector3) -> String:
	if absf(d.x) > absf(d.z):
		return "e" if d.x > 0 else "w"
	return "s" if d.z > 0 else "n"


## Rectangle du sol couvert par [a0, a1] le long de u et [b0, b1] le long de v, à partir de o.
func _rect_ab(o: Vector3, u: Vector3, v: Vector3, a0: float, a1: float, b0: float, b1: float) -> Rect2:
	var p := o + u * a0 + v * b0
	var q := o + u * a1 + v * b1
	return Rect2(minf(p.x, q.x), minf(p.z, q.z), absf(q.x - p.x), absf(q.z - p.z))


## Taille d'une boîte (lu le long de u, lv le long de v, hauteur h) dans les axes du monde.
func _taille_ab(u: Vector3, v: Vector3, lu: float, lv: float, h: float) -> Vector3:
	return Vector3(absf(u.x) * lu + absf(v.x) * lv, h, absf(u.z) * lu + absf(v.z) * lv)


## Bâtiment posé dans le repère d'un lieu (u : largeur, v : vers la route) ; portes : avant, arriere, gauche, droite.
func _bat_lieu(c: Vector3, u: Vector3, v: Vector3, a: float, b: float, lu: float, lv: float, h: float, col: Color, portes: Array, kind: String, label: String, furn: int, map_col: Color, toit := "plat") -> Dictionary:
	var sens := {"avant": v, "arriere": -v, "gauche": -u, "droite": u}
	var cotes: Array = []
	for pt in portes:
		cotes.append(_cote(sens[pt]))
	var t := _taille_ab(u, v, lu, lv, h)
	return _building(c + u * a + v * b, t.x, t.z, h, col, cotes, kind, label, false, furn, map_col, toit)


## Emplacement libre (carré de demi-côté « demi ») près de « base », ou Vector3.INF.
func _lieu_libre(base: Vector3, demi: float, portee: float) -> Vector3:
	var lim := Game.map_half - demi - 60.0
	for i in 40:
		var f := minf(1.0, i / 12.0)
		var p := base + Vector3(rng.randf_range(-portee, portee) * f, 0, rng.randf_range(-portee, portee) * f)
		if absf(p.x) > lim or absf(p.z) > lim:
			continue
		if not _overlaps(Rect2(p.x - demi, p.z - demi, 2.0 * demi, 2.0 * demi)):
			return p
	return Vector3.INF


## Lotissements, lieux de campagne reliés à l'autoroute la plus proche, châteaux d'eau.
func _nouveaux_lieux(hx: float, hz: float) -> void:
	_lotissement(Vector3.ZERO, NB, "Lotissement des Tilleuls")
	_lotissement(VILLE_B, NB_B, "Lotissement du Moulin-Neuf")
	# [position voulue, direction de la route, demi-côté, construction]
	var lieux := [
		[Vector3(-1250.0, 0, hz - 70.0), Vector3(0, 0, 1), 30.0, _scierie],
		[Vector3(hx + 75.0, 0, 1000.0), Vector3(-1, 0, 0), 30.0, _camping],
		[Vector3(700.0, 0, hz + 60.0), Vector3(0, 0, -1), 28.0, _relais_routier],
	]
	for l in lieux:
		var demi: float = l[2]
		var p := _lieu_libre(l[0], demi, 35.0)
		if p == Vector3.INF:
			continue
		var v: Vector3 = l[1]
		var u := Vector3(-v.z, 0, v.x)
		(l[3] as Callable).call(p, u, v)
		var bord := p + v * demi
		if absf(v.z) > 0.5:
			_road(Vector2(bord.x, bord.z), Vector2(bord.x, hz), 7.0, C_ASPHALT, false)
		else:
			_road(Vector2(bord.x, bord.z), Vector2(hx, bord.z), 7.0, C_ASPHALT, false)
		_reserve(Rect2(p.x - demi, p.z - demi, 2.0 * demi, 2.0 * demi))
	for e in [[Vector3(hx + 45.0, 0, -half - 90.0), "Château d'eau"], [Vector3(1380.0, 0, 1460.0), "Château d'eau de Pont-Rouge"]]:
		var p := _lieu_libre(e[0], 10.0, 70.0)
		if p != Vector3.INF:
			_chateau_eau(p, e[1])


# ---------------------------------------------------------------- lotissement
## Lotissement neuf en périphérie d'une ville : rue en boucle partant de deux rues voisines de la ville,
## maisons identiques des deux côtés (pelouse, allée, voiture), haies au fond des jardins.
func _lotissement(o: Vector3, nb: int, nom: String) -> void:
	var hv := nb * BLOCK / 2.0
	var longueur := 112.0
	var essais: Array = []
	for dir in [Vector3(-1, 0, 0), Vector3(1, 0, 0), Vector3(0, 0, -1), Vector3(0, 0, 1)]:
		for i in range(1, nb - 1):
			essais.append([dir, i])
	for k in range(essais.size() - 1, 0, -1):
		var j := rng.randi_range(0, k)
		var tmp = essais[k]
		essais[k] = essais[j]
		essais[j] = tmp
	for e in essais:
		var u: Vector3 = e[0]
		var v := Vector3(absf(u.z), 0, absf(u.x))
		var dep: Vector3 = o + u * (hv + 5.0) + v * (-hv + int(e[1]) * BLOCK)
		var emprise := _rect_ab(dep, u, v, 6.0, longueur + 10.0, -24.0, BLOCK + 24.0)
		if _overlaps(emprise):
			continue
		_construire_lotissement(dep, u, v, longueur, nom)
		_reserve(emprise)
		return


func _construire_lotissement(dep: Vector3, u: Vector3, v: Vector3, lg: float, nom: String) -> void:
	var pt := func(a: float, b: float) -> Vector2: return Vector2((dep + u * a + v * b).x, (dep + u * a + v * b).z)
	_road(pt.call(0.0, 0.0), pt.call(lg, 0.0), 8.0)
	_road(pt.call(0.0, BLOCK), pt.call(lg, BLOCK), 8.0)
	_road(pt.call(lg, 0.0), pt.call(lg, BLOCK), 8.0)
	var col: Color = HOUSE_COLORS[rng.randi() % HOUSE_COLORS.size()].lightened(0.15)
	var lu := 10.0
	var lv := 8.5
	# [b du centre de la maison, sens de la rue (+v / -v)]
	var rangs := [[-11.25, 1.0], [11.25, -1.0], [BLOCK - 11.25, 1.0], [BLOCK + 11.25, -1.0]]
	var a := 16.0
	while a <= lg - 8.0:
		for rg in rangs:
			var b: float = rg[0]
			var s: float = rg[1]
			var z := _bat_lieu(dep, u, v * s, a, b * s, lu, lv, 6.6, col, ["avant"], "maison", "", -1, Color(0.5, 0.45, 0.38), "pente")
			_residents(z, 0.2, 2)
			var bord := b + s * 7.25      # bord de la rue côté maison
			var fond := b - s * 11.75     # fond du jardin
			_flat(_rect_ab(dep, u, v, a - 7.5, a + 7.5, minf(bord, fond), maxf(bord, fond)), 0.012, Color(0.85, 0.95, 0.8), "herbe")
			_flat(_rect_ab(dep, u, v, a + 5.8, a + 8.6, minf(bord, b), maxf(bord, b)), 0.02, Color(0.9, 0.9, 0.88), "beton")
			if rng.randf() < 0.45:
				var pc := dep + u * (a + 7.2) + v * ((bord + b) * 0.5)
				_car(pc, absf(v.x) > 0.5, CAR_COLORS[rng.randi() % CAR_COLORS.size()].darkened(0.2))
			if b < 0.0 or b > BLOCK:
				_box(dep + u * a + v * fond + Vector3(0, 0.55, 0), _taille_ab(u, v, 15.0, 0.7, 1.1), Color(0.25, 0.4, 0.2), true, "herbe")
			elif s < 0.0:
				_box(dep + u * a + v * fond + Vector3(0, 0.6, 0), _taille_ab(u, v, 15.0, 0.08, 1.2), Color(0.6, 0.48, 0.36), true, "planches")
		a += 15.0
	_poi(nom, dep + u * (lg * 0.5) + v * (BLOCK * 0.5), Color(0.7, 0.85, 0.5))


# ---------------------------------------------------------------- bâtiments de ville
## Centre commercial : grande galerie, six boutiques le long des murs est et ouest (vitrines ouvertes, enseignes).
func _centre_commercial(bc: Vector3) -> void:
	var c := bc + Vector3(0, 0, -1.0)
	var z := _building(c, 34.0, 30.0, 7.0, Color(0.72, 0.7, 0.66), ["s", "n"], "magasin", "Centre commercial", false, 0, Color(0.9, 0.55, 0.75))
	var ab: AABB = z.aabb
	# façades nord et sud vitrées (mur-rideau à meneaux, laissant la porte libre) et grande enseigne
	for sgn in [-1.0, 1.0]:
		var face: float = (c.z - 15.0) if sgn < 0 else (c.z + 15.0)
		var dc := c.x
		for dp in z.doors:
			if signf(dp.pos.z - c.z) == sgn:
				dc = dp.pos.x
		var x0 := c.x - 15.5
		var x1 := c.x + 15.5
		var y0 := 0.45
		var y1 := 5.6
		for seg in [[x0, dc - DOOR_W / 2.0 - 0.1, y0], [dc + DOOR_W / 2.0 + 0.1, x1, y0], [dc - DOOR_W / 2.0 - 0.1, dc + DOOR_W / 2.0 + 0.1, DOOR_H + 0.1]]:
			var lg: float = seg[1] - seg[0]
			if lg > 0.2:
				_sur_facade(true, face, sgn, (seg[0] + seg[1]) / 2.0, (seg[2] + y1) / 2.0, 0.2, lg, y1 - seg[2], 0.03, Color(0.45, 0.58, 0.66), "vitre")
		var xm := x0
		while xm <= x1 + 0.01:
			if absf(xm - dc) > DOOR_W / 2.0 + 0.05:
				_sur_facade(true, face, sgn, xm, (y0 + y1) / 2.0, 0.24, 0.1, y1 - y0, 0.08, Color(0.25, 0.27, 0.3), "metal")
			xm += 2.6
		for yt in [y0, 2.9, y1]:
			_sur_facade(true, face, sgn, c.x, yt, 0.24, x1 - x0 + 0.1, 0.1, 0.08, Color(0.25, 0.27, 0.3), "metal")
		_enseigne(Vector3(c.x, 6.3, face + sgn * 0.12), Vector3(0, 0, sgn), "CENTRE COMMERCIAL", 15.0, Color(0.85, 0.3, 0.5), Color(1, 1, 1), 0.9)
		# auvent au-dessus de l'entrée
		_box(Vector3(dc, DOOR_H + 0.35, face + sgn * 1.2), Vector3(4.0, 0.12, 2.4), Color(0.3, 0.32, 0.35), false, "metal")
	var mat_avant := cur_mat
	cur_mat = "enduit"
	var types := ["magasin", "pharmacie", "vetements", "quincaillerie", "bar", "vetements"]
	for k in range(types.size() - 1, 0, -1):
		var j := rng.randi_range(0, k)
		var tmp = types[k]
		types[k] = types[j]
		types[j] = tmp
	var prof := 8.0
	var mur := Color(0.86, 0.85, 0.82)
	var n := 0
	for cote in [-1.0, 1.0]:
		var xm: float = ab.position.x if cote < 0 else ab.end.x
		var xf: float = xm - cote * prof
		var lz := ab.size.z / 3.0
		for i in 3:
			var z0b := ab.position.z + i * lz
			var z1b := z0b + lz
			var zc := (z0b + z1b) / 2.0
			_wall(false, xf, z0b, zc - 1.6, 0.0, 3.6, mur)
			_wall(false, xf, zc + 1.6, z1b, 0.0, 3.6, mur)
			_wall(false, xf, zc - 1.6, zc + 1.6, 3.0, 3.6, mur)
			if i < 2:
				_wall(true, z1b, minf(xm, xf), maxf(xm, xf), 0.0, 3.6, mur)
			var col_e: Color = [Color(0.8, 0.2, 0.2), Color(0.2, 0.6, 0.3), Color(0.2, 0.35, 0.75), Color(0.85, 0.6, 0.15)][n % 4]
			_box(Vector3(xf + cote * 0.2, 3.3, zc), Vector3(0.06, 0.5, 2.8), col_e, false, "uni")
			var bx0 := minf(xm, xf) + 0.2
			var bx1 := maxf(xm, xf) - 0.2
			var boutique := {"aabb": AABB(Vector3(bx0, 0.0, z0b + 0.2), Vector3(bx1 - bx0, 3.3, lz - 0.4)), "doors": [{"pos": Vector3(xf, 0, zc)}], "passages": []}
			_furnish(boutique, types[n], 4, [])
			n += 1
	cur_mat = mat_avant
	# galerie : bacs à plantes et bancs
	for i in 3:
		var p := Vector3(c.x, 0, ab.position.z + ab.size.z * (i + 1) / 4.0)
		_box(p + Vector3(0, 0.4, 0), Vector3(1.6, 0.8, 1.6), Color(0.6, 0.6, 0.58), true, "beton")
		_box(p + Vector3(0, 0.83, 0), Vector3(1.4, 0.06, 1.4), Color(0.35, 0.5, 0.25), false, "herbe")
		_prop("banc", p + Vector3(2.3, 0, 0), PI / 2.0, true, 1.0, 45.0)
		_prop("banc", p + Vector3(-2.3, 0, 0), -PI / 2.0, true, 1.0, 45.0)
	for i in 5:
		guards.append({"pos": Vector3(rng.randf_range(c.x - 6.0, c.x + 6.0), 0.1, rng.randf_range(ab.position.z + 2.0, ab.end.z - 2.0)), "kind": "civil", "radius": 8.0})
	_poi("Centre commercial", c, Color(0.95, 0.55, 0.8))


## Église : nef sous un toit en pente, clocher à flèche au nord, bancs et autel ; deux maisons sur le reste du pâté.
func _eglise(bc: Vector3) -> void:
	var c := bc + Vector3(-7.5, 0, 1.5)
	var z := _building(c, 13.0, 25.0, 9.0, Color(0.82, 0.78, 0.7), ["s"], "eglise", "Église", false, 3, Color(0.8, 0.75, 0.6), "pente")
	var ab: AABB = z.aabb
	_enseigne(Vector3(c.x, 3.4, c.z + 12.5), Vector3(0, 0, 1), "ÉGLISE SAINT-MARTIN", 7.0, Color(0.72, 0.69, 0.62), Color(0.22, 0.2, 0.17), 0.55)
	var ct := c + Vector3(0, 0, -12.5 - 2.3)
	_box(ct + Vector3(0, 9.0, 0), Vector3(4.6, 18.0, 4.6), Color(0.85, 0.82, 0.75), true, "enduit")
	var sommet := ct + Vector3(0, 25.0, 0)
	var coins := [Vector3(-2.4, 18.0, -2.4), Vector3(2.4, 18.0, -2.4), Vector3(2.4, 18.0, 2.4), Vector3(-2.4, 18.0, 2.4)]
	for k in 4:
		var a: Vector3 = ct + coins[k]
		var b: Vector3 = ct + coins[(k + 1) % 4]
		_tri(a, b, sommet, Color(0.32, 0.34, 0.38), "tuiles")
		_tri(b, a, sommet, Color(0.32, 0.34, 0.38), "tuiles")
	_box(sommet + Vector3(0, 1.0, 0), Vector3(0.15, 2.0, 0.15), Color(0.2, 0.2, 0.2), false, "metal")
	_box(sommet + Vector3(0, 1.4, 0), Vector3(1.0, 0.15, 0.15), Color(0.2, 0.2, 0.2), false, "metal")
	for s in [Vector3(0, 0, -2.31), Vector3(0, 0, 2.31), Vector3(-2.31, 0, 0), Vector3(2.31, 0, 0)]:
		_box(ct + s + Vector3(0, 15.0, 0), Vector3(1.4, 2.2, 0.06) if s.x == 0.0 else Vector3(0.06, 2.2, 1.4), Color(0.12, 0.12, 0.13), false, "uni")
	_reserve(Rect2(ct.x - 2.4, ct.z - 2.4, 4.8, 4.8))
	# bancs face à l'autel
	for r in 7:
		var zr := ab.end.z - 4.0 - r * 2.0
		for x in [-4.0, -2.85, -1.7, 1.7, 2.85, 4.0]:
			_sans_ombre(_prop("banc", Vector3(c.x + x, 0, zr), 0.0, true, 1.0, 35.0))
	_box(Vector3(c.x, 0.5, ab.position.z + 3.0), Vector3(3.2, 1.0, 1.2), Color(0.92, 0.9, 0.86), true, "beton")
	for i in 3:
		guards.append({"pos": _random_in(z, 1.5), "kind": "civil", "radius": 6.0})
	for q in [Vector2(1, -1), Vector2(1, 1)]:
		var hc := bc + Vector3(q.x * 8.5, 0, q.y * 8.5)
		var hz := _building(hc, rng.randf_range(9, 12), rng.randf_range(8, 11), 6.6, HOUSE_COLORS[rng.randi() % HOUSE_COLORS.size()], _doors_toward_roads(q.x, q.y), "maison", "", false, -1, Color(0.45, 0.4, 0.35))
		_residents(hz, 0.4, 2)
	_poi("Église", c, Color(0.85, 0.8, 0.6))


## Garage auto : atelier avec une voiture, cour bétonnée avec épaves, pneus et bidons.
func _garage(bc: Vector3) -> void:
	_small_special(bc, "garage", "Garage auto", Color(0.62, 0.62, 0.64), Color(0.55, 0.62, 0.75), 16.0, 13.0, 5.0, 6, [Vector2(1, -1), Vector2(1, 1)])
	_car(bc + Vector3(-8.0, 0, -8.0), true, CAR_COLORS[rng.randi() % CAR_COLORS.size()].darkened(0.3))
	_flat(Rect2(bc.x - 17.5, bc.z + 0.5, 17.0, 17.0), 0.012, Color(0.85, 0.85, 0.83), "beton")
	for i in 2:
		_car(bc + Vector3(-12.0 + i * 7.0, 0, 10.0), false, CAR_COLORS[rng.randi() % CAR_COLORS.size()].darkened(0.4))
	for id in ["pneu", "pneu", "baril_rouge", "jerrican", "palette", "baril_bleu"]:
		_prop(id, bc + Vector3(rng.randf_range(-16.0, -2.0), 0, rng.randf_range(2.0, 4.0)), rng.randf() * TAU, true, 1.0, 100.0)
	_reserve(Rect2(bc.x - 18.0, bc.z + 0.5, 18.0, 17.5))


## Pharmacie : croix verte sur le toit, au-dessus de la façade nord.
func _pharmacie(bc: Vector3) -> void:
	_small_special(bc, "pharmacie", "Pharmacie", Color(0.84, 0.84, 0.82), Color(0.3, 0.85, 0.45), 13.0, 11.0, 4.5, 8)
	var p := bc + Vector3(-8.0, 4.5, -8.0 - 5.5 + 0.3)
	_box(p, Vector3(1.4, 0.45, 0.1), Color(0.1, 0.75, 0.25), false, "uni")
	_box(p, Vector3(0.45, 1.4, 0.1), Color(0.1, 0.75, 0.25), false, "uni")


# ---------------------------------------------------------------- lieux de campagne
## Scierie : hangar, bureau, piles de grumes et de planches, scie.
func _scierie(p: Vector3, u: Vector3, v: Vector3) -> void:
	var r := _rect_ab(p, u, v, -29.0, 29.0, -29.0, 29.0)
	_flat(r, 0.012, Color(0.95, 0.9, 0.85), "terre")
	Game.map_rects.append({"rect": r, "color": Color(0.42, 0.33, 0.22)})
	var z := _bat_lieu(p, u, v, -8.0, -12.0, 24.0, 14.0, 7.0, Color(0.6, 0.45, 0.3), ["avant", "gauche"], "grange", "Scierie", 9, Color(0.6, 0.42, 0.25))
	_residents(z, 0.9, 3)
	var zb := _bat_lieu(p, u, v, 18.0, 14.0, 8.0, 6.0, 3.6, Color(0.7, 0.62, 0.5), ["gauche"], "bureau", "", 3, Color(0.6, 0.42, 0.25), "pente")
	_residents(zb, 0.5, 1)
	var ang := atan2(-v.z, v.x)   # grumes couchées le long de v
	for k in 3:
		var c := p + u * (-20.0 + k * 9.0) + v * 12.0
		for etage in 3:
			for j in 4 - etage:
				_prop("tronc_mort", c + u * ((j - (3 - etage) * 0.5) * 0.52) + Vector3(0, etage * 0.42, 0), ang, true, 1.6, 150.0)
	for k in 4:
		var cp := p + u * (4.0 + k * 3.2) + v * 2.0
		_box(cp + Vector3(0, 0.45, 0), _taille_ab(u, v, 2.4, 1.2, 0.9), Color(0.78, 0.62, 0.42), true, "planches")
	_box(p - u * 8.0 + v * 2.0 + Vector3(0, 0.45, 0), _taille_ab(u, v, 5.0, 1.2, 0.9), Color(0.45, 0.47, 0.5), true, "metal")
	_box(p - u * 8.0 + v * 2.0 + Vector3(0, 1.1, 0), _taille_ab(u, v, 1.4, 0.04, 0.9), Color(0.75, 0.75, 0.78), false, "metal")
	for k in 2:
		var cc := _container(p - u * (24.0 - k * 1.6) + v * 0.5, Vector3(1.2, 1.0, 1.2), Color(0.5, 0.38, 0.22), "Caisse en bois", "quincaillerie")
		cc.set_modele("caisse_bois", 0.0)
	for i in 3:
		guards.append({"pos": p + u * rng.randf_range(-20.0, 20.0) + v * rng.randf_range(-2.0, 8.0) + Vector3(0, 0.1, 0), "kind": "civil", "radius": 10.0})
	_poi("Scierie", p, Color(0.8, 0.58, 0.32))


## Camping : accueil, sanitaires, caravanes et tentes fouillables, tables de pique-nique, pins autour.
func _camping(p: Vector3, u: Vector3, v: Vector3) -> void:
	var r := _rect_ab(p, u, v, -29.0, 29.0, -29.0, 29.0)
	_flat(r, 0.012, Color(0.9, 1.0, 0.85), "herbe")
	Game.map_rects.append({"rect": r, "color": Color(0.3, 0.45, 0.25)})
	var za := _bat_lieu(p, u, v, -20.0, 22.0, 7.0, 6.0, 3.6, Color(0.7, 0.55, 0.38), ["avant"], "magasin", "Accueil du camping", 3, Color(0.4, 0.6, 0.35), "pente")
	_bat_lieu(p, u, v, 20.0, 22.0, 8.0, 5.0, 3.6, Color(0.8, 0.8, 0.78), ["gauche"], "maison", "", 2, Color(0.4, 0.6, 0.35))
	_residents(za, 0.6, 1)
	for pl in [Vector2(-18, 6), Vector2(-6, 6), Vector2(6, 6), Vector2(18, 6), Vector2(-18, -10), Vector2(18, -10)]:
		_caravane(p + u * pl.x + v * pl.y, u, v)
	for k in 6:
		_tente(p + u * (-14.0 + (k % 3) * 14.0) + v * (-16.0 - floori(k / 3.0) * 6.0), u, v, [Color(0.2, 0.5, 0.3), Color(0.75, 0.3, 0.15), Color(0.2, 0.35, 0.7)][k % 3])
	for k in 3:
		_prop("table_bois", p + u * (-6.0 + k * 6.0) - v * 4.0, rng.randf() * 0.4, true, 1.0, 100.0)
	_prop("brasero", p - v * 9.0, 0.0, true, 1.0, 120.0)
	for i in 14:
		var a := rng.randf_range(-27.0, 27.0)
		if i % 2 == 0:
			trees.append(p + u * a - v * 27.5)
		else:
			trees.append(p + u * (27.5 if a > 0 else -27.5) + v * rng.randf_range(-24.0, 10.0))
	for i in 5:
		guards.append({"pos": p + u * rng.randf_range(-24.0, 24.0) + v * rng.randf_range(-22.0, 2.0) + Vector3(0, 0.1, 0), "kind": "civil", "radius": 10.0})
	_poi("Camping des Pins", p, Color(0.45, 0.8, 0.45))


## Caravane (fouillable) : caisse blanche sur roues, bande colorée et vitres.
func _caravane(c: Vector3, u: Vector3, v: Vector3) -> void:
	var t := _taille_ab(u, v, 2.3, 6.0, 2.5)
	_container(c + Vector3(0, 0.35, 0), t, Color(0.92, 0.9, 0.84), "Caravane", "camping", 3)
	_box(c + Vector3(0, 1.35, 0), Vector3(t.x + 0.04, 0.18, t.z + 0.04), Color(0.25, 0.45, 0.7), false, "uni")
	_box(c + Vector3(0, 2.05, 0), Vector3(t.x + 0.03, 0.45, t.z + 0.03) - _taille_ab(u, v, 0.0, 1.2, 0.0), Color(0.12, 0.14, 0.16), false, "vitre")
	for sgn in [-1.0, 1.0]:
		_box(c + u * (sgn * 1.15) + Vector3(0, 0.35, 0), _taille_ab(u, v, 0.25, 0.7, 0.7), Color(0.1, 0.1, 0.1), false, "uni")


## Tente (fouillable) : deux pans de toile et deux pignons sur la boîte d'interaction cachée.
func _tente(c: Vector3, u: Vector3, v: Vector3, col: Color) -> void:
	var lu := 2.2
	var lv := 2.6
	var h := 1.4
	var ct := _container(c, _taille_ab(u, v, lu, lv, h), col, "Tente", "camping", 1)
	ct.mesh_i.visible = false
	var f0 := c - v * lv / 2.0 + Vector3(0, h, 0)
	var f1 := c + v * lv / 2.0 + Vector3(0, h, 0)
	var g0 := c - u * lu / 2.0 - v * lv / 2.0
	var g1 := c - u * lu / 2.0 + v * lv / 2.0
	var d0 := c + u * lu / 2.0 - v * lv / 2.0
	var d1 := c + u * lu / 2.0 + v * lv / 2.0
	_quad(g0, g1, f1, f0, col, "uni", true)
	_quad(d0, d1, f1, f0, col, "uni", true)
	for e in [[g0, d0, f0], [g1, d1, f1]]:
		_tri(e[0], e[1], e[2], col.darkened(0.2), "uni")
		_tri(e[1], e[0], e[2], col.darkened(0.2), "uni")


## Relais routier : restaurant, grand parking avec camions (remorques fouillables) et voitures.
func _relais_routier(p: Vector3, u: Vector3, v: Vector3) -> void:
	var parking := _rect_ab(p, u, v, -27.0, 27.0, -2.0, 27.0)
	_flat(parking, 0.012, Color(0.9, 0.9, 0.9), "asphalte")
	Game.map_rects.append({"rect": parking, "color": Color(0.15, 0.15, 0.15)})
	var z := _bat_lieu(p, u, v, -6.0, -15.0, 22.0, 11.0, 4.2, Color(0.75, 0.5, 0.35), ["avant", "droite"], "bar", "Relais routier", 9, Color(0.95, 0.55, 0.3))
	_residents(z, 0.9, 4)
	for k in 3:
		_camion(p + u * (-18.0 + k * 9.0) + v * 12.0, u, v, [Color(0.75, 0.2, 0.15), Color(0.2, 0.3, 0.6), Color(0.85, 0.85, 0.82)][k])
	for k in 2:
		_car(p + u * (16.0 + k * 5.0) + v * 3.0, absf(v.x) > 0.5, CAR_COLORS[rng.randi() % CAR_COLORS.size()].darkened(0.3))
	for i in 3:
		guards.append({"pos": p + u * rng.randf_range(-20.0, 20.0) + v * rng.randf_range(0.0, 20.0) + Vector3(0, 0.1, 0), "kind": "civil", "radius": 10.0})
	_poi("Relais routier", p, Color(0.95, 0.6, 0.35))


## Camion garé : cabine vers +v, remorque fouillable, roues.
func _camion(c: Vector3, u: Vector3, v: Vector3, col: Color) -> void:
	_container(c - v * 1.5 + Vector3(0, 0.9, 0), _taille_ab(u, v, 2.5, 10.0, 3.0), Color(0.85, 0.85, 0.83), "Remorque", "magasin", 4)
	_box(c + v * 5.4 + Vector3(0, 1.75, 0), _taille_ab(u, v, 2.5, 2.4, 2.9), col, true, "metal")
	_box(c + v * 6.62 + Vector3(0, 2.3, 0), _taille_ab(u, v, 2.2, 0.04, 1.0), Color(0.12, 0.14, 0.16), false, "vitre")
	for b in [5.4, 2.0, -4.5, -6.0]:
		for sgn in [-1.0, 1.0]:
			_box(c + u * (sgn * 1.2) + v * b + Vector3(0, 0.5, 0), _taille_ab(u, v, 0.35, 1.0, 1.0), Color(0.08, 0.08, 0.08), false, "uni")


## Château d'eau : réservoir sur un fût en béton, repère visible de loin.
func _chateau_eau(c: Vector3, nom: String) -> void:
	_cylindre(c, 1.6, 22.0, Color(0.8, 0.79, 0.76), "beton")
	_cylindre(c + Vector3(0, 22.0, 0), 6.5, 7.0, Color(0.86, 0.85, 0.82), "beton")
	_disque(c + Vector3(0, 22.0, 0), 6.5, Color(0.7, 0.7, 0.68), "beton")
	_cone(c + Vector3(0, 29.0, 0), 6.8, 2.5, Color(0.55, 0.56, 0.58), "tole")
	_box(c + Vector3(0, 11.0, 0), Vector3(2.4, 22.0, 2.4), Color.WHITE, true, "invisible")
	# réservoir : collision cylindrique (la caméra à ressort ne doit pas entrer dedans depuis la coursive)
	var corps := StaticBody3D.new()
	corps.collision_layer = Game.LAYER_WORLD
	corps.collision_mask = 0
	var cs := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = 6.6
	cyl.height = 9.5
	cs.shape = cyl
	corps.add_child(cs)
	add_child(corps)
	corps.position = c + Vector3(0, 22.0 + 9.5 / 2.0, 0)
	# coursive à 22 m autour du réservoir (point de vue), garde-corps ouvert du côté de l'échelle (+x)
	var h := 22.0
	var nseg := 16
	var r0 := 6.5
	var r1 := 8.1
	var metal := Color(0.32, 0.34, 0.36)
	for i in nseg:
		var a := TAU * i / nseg
		var dir := Vector3(cos(a), 0, sin(a))
		var tang := Vector3(-dir.z, 0, dir.x)
		var lg := TAU * r1 / nseg + 0.1
		var m := c + dir * ((r0 + r1) / 2.0)
		# plancher : anneau lisse (dessus, dessous, rive) ; collision en petites boîtes alignées sur les axes
		var a0 := TAU * (i - 0.5) / nseg
		var a1 := TAU * (i + 0.5) / nseg
		var d0 := Vector3(cos(a0), 0, sin(a0))
		var d1 := Vector3(cos(a1), 0, sin(a1))
		for yy in [h, h - 0.15]:
			_quad(c + d0 * r0 + Vector3(0, yy, 0), c + d1 * r0 + Vector3(0, yy, 0), c + d1 * r1 + Vector3(0, yy, 0), c + d0 * r1 + Vector3(0, yy, 0), metal, "metal", true)
		_quad(c + d0 * r1 + Vector3(0, h - 0.15, 0), c + d1 * r1 + Vector3(0, h - 0.15, 0), c + d1 * r1 + Vector3(0, h, 0), c + d0 * r1 + Vector3(0, h, 0), metal.darkened(0.2), "metal", true)
		for k in 3:
			var p := m + tang * (lg * (k - 1) / 3.0) + Vector3(0, h - 0.1, 0)
			_box(p, Vector3(1.1, 0.2, 1.1), metal, true, "invisible")
		# garde-corps : poteau + lisses (sauf devant l'échelle)
		var p_fin := c + Vector3(cos(TAU * (i + 0.5) / nseg), 0, sin(TAU * (i + 0.5) / nseg)) * (r1 - 0.05)
		var p_deb := c + Vector3(cos(TAU * (i - 0.5) / nseg), 0, sin(TAU * (i - 0.5) / nseg)) * (r1 - 0.05)
		_box(p_deb + Vector3(0, h + 0.55, 0), Vector3(0.08, 1.1, 0.08), metal, true, "metal")
		if i == 0:
			continue
		for yl in [0.5, 1.02]:
			var y0 := Vector3(0, h + yl, 0)
			var y1 := Vector3(0, h + yl + 0.07, 0)
			_quad(p_deb + y0, p_fin + y0, p_fin + y1, p_deb + y1, metal, "metal", true)
		# garde-corps de collision (pour ne pas tomber) : petites boîtes le long du segment, rien sur la coursive
		for k in 4:
			_box(p_deb.lerp(p_fin, (k + 0.5) / 4.0) + Vector3(0, h + 0.6, 0), Vector3(0.7, 1.2, 0.7), Color.WHITE, true, "invisible")
	# échelle sur le côté +x : deux montants, barreaux tous les 30 cm, attaches au fût
	var xe := c.x + 8.4
	for sz in [-0.25, 0.25]:
		_box(Vector3(xe, c.y + (h + 1.1) / 2.0, c.z + sz), Vector3(0.06, h + 1.1, 0.06), metal, false, "metal")
	var yb := 0.3
	while yb < h:
		_box(Vector3(xe, c.y + yb, c.z), Vector3(0.04, 0.04, 0.5), metal, false, "metal")
		yb += 0.3
	for ya in [4.0, 9.0, 14.0, 19.0]:
		_box(Vector3((xe + c.x + 1.6) / 2.0, c.y + ya, c.z), Vector3(xe - c.x - 1.6, 0.08, 0.08), metal, false, "metal")
	Game.echelles.append({"pos": Vector3(xe, c.y, c.z), "n": Vector3(1, 0, 0), "haut": h})
	_reserve(Rect2(c.x - 9.5, c.z - 9.5, 19.0, 19.0), Color(0.6, 0.62, 0.65))
	_poi(nom, c, Color(0.6, 0.8, 0.95))


## Silo à grain : cylindre en tôle et toit conique.
func _silo(c: Vector3) -> void:
	_cylindre(c, 3.0, 13.0, Color(0.78, 0.78, 0.76), "tole")
	_cone(c + Vector3(0, 13.0, 0), 3.2, 3.0, Color(0.6, 0.6, 0.6), "tole")
	_box(c + Vector3(0, 6.5, 0), Vector3(4.2, 13.0, 4.2), Color.WHITE, true, "invisible")
	_reserve(Rect2(c.x - 3.2, c.z - 3.2, 6.4, 6.4), Color(0.6, 0.6, 0.6))


func _cylindre(base: Vector3, r: float, h: float, col: Color, m: String, n := 14) -> void:
	for i in n:
		var p0 := base + Vector3(cos(TAU * i / n) * r, 0, sin(TAU * i / n) * r)
		var p1 := base + Vector3(cos(TAU * (i + 1) / n) * r, 0, sin(TAU * (i + 1) / n) * r)
		_quad(p0, p1, p1 + Vector3(0, h, 0), p0 + Vector3(0, h, 0), col, m, true)


func _cone(base: Vector3, r: float, h: float, col: Color, m: String, n := 14) -> void:
	var sommet := base + Vector3(0, h, 0)
	for i in n:
		var p0 := base + Vector3(cos(TAU * i / n) * r, 0, sin(TAU * i / n) * r)
		var p1 := base + Vector3(cos(TAU * (i + 1) / n) * r, 0, sin(TAU * (i + 1) / n) * r)
		_tri(p0, p1, sommet, col, m)
		_tri(p1, p0, sommet, col, m)


func _disque(c: Vector3, r: float, col: Color, m: String, n := 14) -> void:
	for i in n:
		var p0 := c + Vector3(cos(TAU * i / n) * r, 0, sin(TAU * i / n) * r)
		var p1 := c + Vector3(cos(TAU * (i + 1) / n) * r, 0, sin(TAU * (i + 1) / n) * r)
		_tri(p0, p1, c, col, m)
		_tri(p1, p0, c, col, m)


# ================================================================ campagne quadrillée
## Routes secondaires posées sur le relief (les collines restent), voie ferrée, forêts nommées,
## fermes et maisons isolées le long des nouvelles routes ; lignes à haute tension et éoliennes (après le relief).
const Eolienne = preload("res://scripts/eolienne.gd")
const RS_X := [-2000.0, -1000.0, 780.0, 1950.0]   # routes secondaires nord-sud
const RS_Z := [-2000.0, -800.0, 1100.0, 2050.0]   # routes secondaires est-ouest
const RAIL_Z := -1530.0                            # voie ferrée est-ouest (au nord de Valmont et des Granges)
const FORETS := [
	[Vector3(-650, 0, -1900), 230.0, "Forêt du Nord"],
	[Vector3(560, 0, -1820), 220.0, "Bois de la Vieille-Croix"],
	[Vector3(-1500, 0, 1300), 260.0, "Forêt des Combes"],
	[Vector3(-600, 0, 1750), 200.0, "Bois Noir"],
	[Vector3(1900, 0, 550), 200.0, "Bois de l'Est"],
	[Vector3(600, 0, 1820), 180.0, "Bois des Chênes"],
	[Vector3(-1750, 0, 350), 220.0, "Forêt de la Rivière"],
]
var non_plats := {}      # Rect2 réservés qui n'aplatissent pas le relief (routes posées dessus)
var drapees: Array = []  # routes à poser sur le relief : [a, b, largeur, couleur, hauteur au-dessus du sol]
var forets: Array = []   # {c, r, nom}


func _plan_campagne() -> void:
	var hx := -half + 4 * BLOCK
	var hz := -half + 3 * BLOCK
	_voie_ferree(hx)
	for x in RS_X:
		_route_drapee(Vector2(x, RS_Z[0]), Vector2(x, RS_Z[-1]), 7.0, C_ASPHALT, 0.07)
	for z in RS_Z:
		_route_drapee(Vector2(RS_X[0], z), Vector2(RS_X[-1], z), 7.0, C_ASPHALT, 0.09)
	# fermes le long des routes nord-sud (chemin de terre jusqu'à la route)
	for f in [[Vector3(-1920, 0, -1200), -2000.0, "Ferme des Saules"], [Vector3(-920, 0, 1300), -1000.0, "Ferme de la Combe"],
			[Vector3(870, 0, -1100), 780.0, "Ferme du Haut-Bois"], [Vector3(2040, 0, 800), 1950.0, "Ferme des Rochers"],
			[Vector3(-1080, 0, -1900), -1000.0, "Ferme du Calvaire"]]:
		var c: Vector3 = f[0]
		if not _overlaps(Rect2(c.x - 14, c.z - 12, 50, 24)):
			_farm(c, f[1], 1.0e6, f[2])
	# forêts nommées : clairière avec cabane de chasseur, clairière avec mirador, sentiers vers la route
	for f in FORETS:
		var c: Vector3 = f[0]
		var r: float = f[1]
		forets.append({"c": c, "r": r, "nom": f[2]})
		_poi(f[2], c, Color(0.35, 0.65, 0.35))
		Game.map_rects.append({"rect": Rect2(c.x - r * 0.75, c.z - r * 0.75, r * 1.5, r * 1.5), "color": Color(0.08, 0.28, 0.1, 0.3)})
		for k in 2:
			for essai in 14:
				var a := rng.randf() * TAU
				var p := c + Vector3(cos(a), 0, sin(a)) * r * rng.randf_range(0.2, 0.6)
				if _overlaps(Rect2(p.x - 16, p.z - 16, 32, 32)):
					continue
				if k == 0:
					_cabane_chasseur(p)
				else:
					_mirador(p)
				_sentier(p)
				break
	# maisons isolées le long des routes secondaires
	for i in 36:
		var le_long_z := rng.randf() < 0.5
		var ligne: float = (RS_X if le_long_z else RS_Z)[rng.randi() % 4]
		var along := rng.randf_range(-1980.0, 1930.0)
		var off := 17.0 * (1.0 if rng.randf() < 0.5 else -1.0)
		var c := Vector3(ligne + off, 0, along) if le_long_z else Vector3(along, 0, ligne + off)
		var doors: Array = [("w" if off > 0 else "e")] if le_long_z else [("n" if off > 0 else "s")]
		var proche := false
		for x in RS_X + [hx]:
			for z in RS_Z + [hz]:
				if Vector2(c.x - x, c.z - z).length() < 30.0:
					proche = true
		if proche or Game.in_city(c) or _overlaps(Rect2(c.x - 9, c.z - 9, 18, 18)):
			continue
		var zm := _building(c, rng.randf_range(9, 12), rng.randf_range(8, 10), 6.6, HOUSE_COLORS[rng.randi() % HOUSE_COLORS.size()], doors, "maison", "", false, -1, Color(0.45, 0.4, 0.35), "pente")
		_residents(zm, 0.5, 2)


## Route droite (axe x ou z) posée sur le relief une fois celui-ci calculé (elle ne l'aplatit pas).
func _route_drapee(a: Vector2, b: Vector2, w: float, col: Color, dy := 0.07) -> void:
	var r := Rect2(minf(a.x, b.x) - w / 2.0, minf(a.y, b.y) - w / 2.0, absf(b.x - a.x) + w, absf(b.y - a.y) + w)
	_reserve(r, Color(0.16, 0.16, 0.16) if col == C_ASPHALT else Color(0.35, 0.28, 0.18))
	non_plats[r] = true
	routes.append({"r": r, "x": absf(b.x - a.x) > absf(b.y - a.y)})
	Game.sols.append({"r": r, "s": "beton" if col == C_ASPHALT else "terre"})
	drapees.append([a, b, w, col, dy])


func _poser_routes_drapees() -> void:
	for d in drapees:
		var a: Vector2 = d[0]
		var b: Vector2 = d[1]
		var asphalte: bool = d[3] == C_ASPHALT
		var dy: float = d[4]
		var m := "asphalte" if asphalte else "terre"
		var col := Color(0.95, 0.95, 0.95) if asphalte else Color(0.95, 0.92, 0.88)
		var long := a.distance_to(b)
		var dir := (b - a) / long
		var lat := Vector2(-dir.y, dir.x) * float(d[2]) / 2.0
		var n := maxi(1, ceili(long / 5.0))
		var pg := Vector3.ZERO
		var pd := Vector3.ZERO
		for i in n + 1:
			var p := a + dir * (long * i / n)
			var g := p + lat
			var q := p - lat
			var ng := Vector3(g.x, maxf(relief.hauteur(g.x, g.y), 0.0) + dy, g.y)
			var nd := Vector3(q.x, maxf(relief.hauteur(q.x, q.y), 0.0) + dy, q.y)
			if i > 0:
				_quad_sol(pg, ng, nd, pd, col, m)
			pg = ng
			pd = nd


## Quadrilatère de sol (face vers le haut), UV alignées sur le monde comme les boîtes.
func _quad_sol(p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, col: Color, m: String) -> void:
	var st := _st((p0 + p2) * 0.5, m)
	var n := (p1 - p0).cross(p3 - p0).normalized()
	var ordre := [p0, p2, p1, p0, p3, p2]
	if n.y < 0.0:
		n = -n
		ordre = [p0, p1, p2, p0, p2, p3]
	for p in ordre:
		st.set_normal(n)
		st.set_tangent(Plane(1, 0, 0, 1))
		st.set_color(col)
		st.set_uv(Vector2(p.x, p.z))
		st.add_vertex(p)


## Sentier de terre d'une clairière jusqu'à la route la plus proche qu'il peut atteindre sans traverser un lieu.
func _sentier(p: Vector3) -> void:
	_relier(p, Rect2(-14, -14, 28, 28), 2.6, C_DIRT, 0.05)


## Cabane de chasseur dans une clairière : coffre, tas de bois, foyer.
func _cabane_chasseur(p: Vector3) -> void:
	_reserve(Rect2(p.x - 14, p.z - 14, 28, 28))
	var z := _building(p, 7.0, 6.0, 3.6, Color(0.5, 0.38, 0.26), ["s"], "maison", "Cabane de chasseur", false, 3, Color(0.45, 0.35, 0.25), "pente")
	_residents(z, 0.5, 1)
	var cof := _container(p + Vector3(2.4, 0, 3.8), Vector3(1.0, 0.6, 0.6), Color(0.4, 0.3, 0.2), "Coffre du chasseur", "chasseur", 3)
	cof.set_texture("planches")
	_box(p + Vector3(4.6, 0.5, 0), Vector3(1.0, 1.0, 3.0), Color(0.55, 0.4, 0.28), true, "planches")
	for i in 7:
		var a := TAU * i / 7.0
		_box(p + Vector3(-2.0 + cos(a) * 0.8, 0.12, 7.0 + sin(a) * 0.8), Vector3(0.35, 0.24, 0.35), Color(0.6, 0.6, 0.58), false, "roche")
	_poi("Cabane de chasseur", p, Color(0.7, 0.55, 0.35))


## Mirador de chasse : plateforme à 4,2 m (échelle côté +z), caisse du chasseur.
func _mirador(p: Vector3) -> void:
	_reserve(Rect2(p.x - 12, p.z - 12, 24, 24))
	var bois := Color(0.55, 0.42, 0.3)
	var hp := 4.2
	for o in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
		_box(p + Vector3(o.x * 1.25, (hp + 2.2) / 2.0, o.y * 1.25), Vector3(0.18, hp + 2.2, 0.18), bois, true, "planches")
	_box(p + Vector3(0, hp, 0), Vector3(2.8, 0.15, 2.8), bois, true, "planches")
	_box(p + Vector3(0, hp + 0.55, -1.35), Vector3(2.8, 1.0, 0.08), bois, true, "planches")
	for sx in [-1.0, 1.0]:
		_box(p + Vector3(sx * 1.35, hp + 0.55, 0), Vector3(0.08, 1.0, 2.8), bois, true, "planches")
		_box(p + Vector3(sx * 0.95, hp + 0.55, 1.35), Vector3(0.9, 1.0, 0.08), bois, true, "planches")
	_box(p + Vector3(0, hp + 2.25, 0), Vector3(3.2, 0.1, 3.2), Color(0.4, 0.42, 0.38), false, "tole")
	var ze := p.z + 1.6
	for sx in [-0.25, 0.25]:
		_box(Vector3(p.x + sx, (hp + 1.0) / 2.0, ze), Vector3(0.06, hp + 1.0, 0.06), bois, false, "planches")
	var yb := 0.3
	while yb < hp:
		_box(Vector3(p.x, yb, ze), Vector3(0.5, 0.05, 0.05), bois, false, "planches")
		yb += 0.3
	Game.echelles.append({"pos": Vector3(p.x, 0, ze), "n": Vector3(0, 0, 1), "haut": hp})
	var c := _container(p + Vector3(-0.7, hp + 0.08, -0.7), Vector3(0.7, 0.4, 0.5), Color(0.35, 0.3, 0.22), "Caisse du chasseur", "chasseur", 2)
	c.set_texture("planches")
	_poi("Mirador de chasse", p, Color(0.7, 0.55, 0.35))


# ---------------------------------------------------------------- voie ferrée
func _voie_ferree(hx: float) -> void:
	var m := Game.map_half - 70.0
	_reserve(Rect2(-m, RAIL_Z - 5.0, 2.0 * m, 10.0), Color(0.3, 0.24, 0.22))
	Game.sols.append({"r": Rect2(-m, RAIL_Z - 2.3, 2.0 * m, 4.6), "s": "terre"})
	var passages: Array = [hx]
	passages.append_array(RS_X)
	_rails(-m, m, RAIL_Z, passages)
	for px in passages:
		_passage_niveau(px)
	for sx in [-1.0, 1.0]:   # heurtoirs aux deux bouts
		_box(Vector3(sx * (m - 1.0), 0.6, RAIL_Z), Vector3(0.8, 1.2, 3.0), Color(0.7, 0.15, 0.1), true, "metal")
	_gare_valmont()
	_halte(Vector3(-1500.0, 0, RAIL_Z + 9.0), "Halte des Granges", -1470.0)
	_train_deraille(Vector3(-680.0, 0, RAIL_Z))
	# wagons abandonnés le long de la voie
	var n := 0
	for essai in 40:
		if n >= 6:
			break
		var wx := rng.randf_range(-m + 40.0, m - 40.0)
		var ok := absf(wx - VILLE_B.x) > 130.0 and absf(wx + 1500.0) > 60.0 and absf(wx + 680.0) > 120.0
		for px in passages:
			if absf(wx - px) < 30.0:
				ok = false
		if ok:
			var t: String = ["magasin", "quincaillerie", "ferme", "station", "garage"][rng.randi() % 5]
			_wagon(Vector3(wx, 0, RAIL_Z), true, false, t, "Wagon de marchandises")
			n += 1


## Ballast, rails et traverses entre x0 et x1 (pas de traverses sur les routes traversées).
func _rails(x0: float, x1: float, z: float, passages: Array) -> void:
	var x := x0
	while x < x1:
		var lg := minf(40.0, x1 - x)
		_flat(Rect2(x, z - 2.3, lg, 4.6), 0.03, Color(0.75, 0.72, 0.7), "roche")
		for sz in [-0.72, 0.72]:
			_box(Vector3(x + lg / 2.0, 0.2, z + sz), Vector3(lg, 0.13, 0.09), Color(0.45, 0.4, 0.36), false, "metal")
		x += lg
	x = x0 + 1.0
	while x < x1:
		var libre := true
		for px in passages:
			if absf(x - px) < 7.0:
				libre = false
		if libre:
			_box(Vector3(x, 0.08, z), Vector3(0.26, 0.12, 2.5), Color(0.38, 0.29, 0.2), false, "planches")
		x += 2.0


## Passage à niveau : poteaux rouge et blanc, barrières levées, panneaux.
func _passage_niveau(px: float) -> void:
	for sd in [-1.0, 1.0]:
		var p := Vector3(px + sd * 7.0, 0, RAIL_Z + sd * 5.0)
		_box(p + Vector3(0, 0.6, 0), Vector3(0.35, 1.2, 0.35), Color(0.85, 0.85, 0.85), true, "metal")
		_box(p + Vector3(0, 3.0, 0), Vector3(0.12, 3.6, 0.12), Color(0.85, 0.15, 0.1), false, "uni")
		_box(p + Vector3(0, 2.0, sd * 0.4), Vector3(1.0, 1.0, 0.05), Color(0.9, 0.9, 0.88), false, "metal")
		_box(p + Vector3(0, 2.0, sd * 0.43), Vector3(0.8, 0.8, 0.02), Color(0.8, 0.1, 0.08), false, "uni")


## Wagon de marchandises (debout ou couché sur le flanc) avec ce qu'il transportait à fouiller devant la porte.
func _wagon(c: Vector3, le_long_x: bool, couche: bool, table: String, label: String) -> void:
	var col: Color = [Color(0.45, 0.22, 0.15), Color(0.3, 0.35, 0.4), Color(0.35, 0.38, 0.28), Color(0.5, 0.45, 0.35)][rng.randi() % 4]
	var u := Vector3(1, 0, 0) if le_long_x else Vector3(0, 0, 1)
	var v := Vector3(-u.z, 0, u.x)
	var modele := "train_conteneur" if table in ["militaire", "armurerie_mil"] else ("train_charbon" if table in ["quincaillerie", "ferme"] else "train_wagon")
	if Decor.existe(modele):
		var t := Decor.taille(modele)
		if couche:
			_vehicule_couche(modele, c, 0.0 if le_long_x else PI / 2.0)
		else:
			_prop(modele, c, 0.0 if le_long_x else PI / 2.0, true, 1.0, 260.0)
		var cm := _container(c - v * ((t.y if couche else t.z) / 2.0 + 0.8), Vector3(1.3, 0.9, 0.9), col.darkened(0.2), label, table, 3)
		cm.set_texture("metal_peint")
		return
	var lat := 3.4 if couche else 2.9
	var ht := 2.9 if couche else 3.4
	var y0 := 0.0 if couche else 0.9
	_box(c + Vector3(0, y0 + ht / 2.0, 0), _taille_ab(u, v, 13.0, lat, ht), col, true, "tole")
	_box(c + Vector3(0, y0 + ht / 2.0, 0), _taille_ab(u, v, 2.4, lat + 0.06, ht * 0.8), col.darkened(0.35), false, "metal")
	for sa in [-4.6, 4.6]:
		if couche:
			_box(c + u * sa + v * (lat / 2.0 + 0.4) + Vector3(0, 1.45, 0), _taille_ab(u, v, 2.4, 0.8, 2.2), Color(0.12, 0.12, 0.12), false, "metal")
		else:
			_box(c + u * sa + Vector3(0, 0.45, 0), _taille_ab(u, v, 2.4, 2.2, 0.9), Color(0.12, 0.12, 0.12), true, "metal")
	var cont := _container(c - v * (lat / 2.0 + 0.8), Vector3(1.3, 0.9, 0.9), col.darkened(0.2), label, table, 3)
	cont.set_texture("metal_peint")


## Véhicule (modèle dont la longueur est sur x) couché sur le flanc, avec sa collision.
func _vehicule_couche(id: String, c: Vector3, ang: float) -> void:
	var t := Decor.taille(id)
	var n := _prop(id, c, ang, false, 1.0, 260.0)
	if n == null:
		return
	n.transform.basis = Basis(Vector3.UP, ang) * Basis(Vector3(1, 0, 0), PI / 2.0)
	var haut := Basis(Vector3.UP, ang) * Vector3(0, 0, 1)   # le toit pointe par là une fois couché
	n.position = c + Vector3(0, t.z / 2.0 - 0.15, 0) - haut * t.y / 2.0
	var u := Basis(Vector3.UP, ang) * Vector3(1, 0, 0)
	_box(c + Vector3(0, t.z / 2.0, 0), _taille_ab(u, haut, t.x, t.y, t.z), Color.WHITE, true, "invisible")


func _gare_valmont() -> void:
	var gx := VILLE_B.x
	var xa := VILLE_B.x - NB_B * BLOCK / 2.0 + 2 * BLOCK
	_flat(Rect2(gx - 35.0, RAIL_Z + 2.4, 70.0, 6.0), 0.035, Color(0.9, 0.9, 0.88), "beton")
	_box(Vector3(gx, 0.05, RAIL_Z + 2.8), Vector3(70.0, 0.02, 0.25), Color(0.95, 0.85, 0.2), false, "uni")
	var z := _building(Vector3(gx, 0, RAIL_Z + 13.0), 26.0, 9.0, 4.6, Color(0.75, 0.68, 0.55), ["n", "s"], "bureau", "Gare de Valmont", true, 8, Color(0.55, 0.5, 0.45))
	_residents(z, 0.9, 4)
	# auvent du quai
	for i in 8:
		_box(Vector3(gx - 28.0 + i * 8.0, 1.7, RAIL_Z + 7.6), Vector3(0.2, 3.4, 0.2), Color(0.3, 0.32, 0.35), true, "metal")
	_box(Vector3(gx, 3.45, RAIL_Z + 6.0), Vector3(62.0, 0.15, 5.0), Color(0.45, 0.47, 0.5), false, "tole")
	for i in 4:
		_prop("banc", Vector3(gx - 20.0 + i * 13.0, 0.03, RAIL_Z + 6.8), 0.0, false, 1.0, 120.0)
	# parking et route vers la ville
	_flat(Rect2(gx - 14.0, RAIL_Z + 18.5, 34.0, 14.0), 0.02, Color(0.9, 0.9, 0.9), "asphalte")
	_road(Vector2(xa, RAIL_Z + 20.0), Vector2(xa, RAIL_Z + 58.0), 7.0, C_ASPHALT, false)
	for i in 2:
		_car(Vector3(gx - 8.0 + i * 9.0, 0, RAIL_Z + 25.0), false, CAR_COLORS[rng.randi() % CAR_COLORS.size()].darkened(0.3))
	_reserve(Rect2(gx - 36.0, RAIL_Z + 2.4, 72.0, 31.0), Color(0.5, 0.45, 0.4))
	# voie de garage au nord avec des wagons
	_reserve(Rect2(gx - 90.0, RAIL_Z - 11.0, 180.0, 8.0))
	_rails(gx - 85.0, gx + 85.0, RAIL_Z - 7.0, [])
	for wx in [-50.0, -35.0, 30.0]:
		_wagon(Vector3(gx + wx, 0, RAIL_Z - 7.0), true, false, ["magasin", "quincaillerie", "station"][rng.randi() % 3], "Wagon de marchandises")
	_prop("train_loco", Vector3(gx + 58.0, 0, RAIL_Z - 7.0), 0.0, true, 1.0, 260.0)
	for i in 6:
		guards.append({"pos": Vector3(gx + rng.randf_range(-30, 30), 0.1, RAIL_Z + rng.randf_range(3, 8)), "kind": "civil", "radius": 20.0})
	_poi("Gare de Valmont", Vector3(gx, 0, RAIL_Z + 13.0), Color(0.85, 0.75, 0.55))


## Halte de village : quai, abri, panneau, chemin jusqu'au village.
func _halte(c: Vector3, nom: String, z_village: float) -> void:
	_flat(Rect2(c.x - 15.0, RAIL_Z + 2.4, 30.0, 4.0), 0.035, Color(0.9, 0.9, 0.88), "beton")
	_box(c + Vector3(0, 1.3, 1.2), Vector3(4.0, 2.4, 0.08), Color(0.6, 0.48, 0.34), true, "planches")
	for sx in [-1.0, 1.0]:
		_box(c + Vector3(sx * 2.0, 1.3, 0.4), Vector3(0.08, 2.4, 1.6), Color(0.6, 0.48, 0.34), true, "planches")
	_box(c + Vector3(0, 2.55, 0.3), Vector3(4.4, 0.12, 2.2), Color(0.4, 0.3, 0.25), true, "tuiles")
	_prop("banc", c + Vector3(0, 0, 0.7), 0.0, false, 1.0, 120.0)
	var dist := _container(c + Vector3(3.2, 0, 0.6), Vector3(0.8, 1.6, 0.6), Color(0.7, 0.2, 0.15), "Distributeur", "station", 2)
	dist.set_texture("metal_peint")
	var l := Label3D.new()
	l.text = nom
	l.font_size = 48
	l.pixel_size = 0.008
	l.outline_size = 10
	l.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	l.position = c + Vector3(0, 3.3, 0.3)
	l.visibility_range_end = 60.0
	add_child(l)
	_road(Vector2(c.x, c.z + 2.5), Vector2(c.x, z_village), 3.0, C_DIRT, false)
	_reserve(Rect2(c.x - 16.0, RAIL_Z + 2.4, 32.0, 9.0), Color(0.5, 0.45, 0.4))
	_poi(nom, c, Color(0.85, 0.75, 0.55))


## Train déraillé : locomotive et wagons en accordéon, cargaison militaire, horde (zone infestée, butin rare).
func _train_deraille(c: Vector3) -> void:
	var bleu := Color(0.22, 0.3, 0.5)
	if Decor.existe("train_loco"):
		_vehicule_couche("train_loco", c + Vector3(-27.0, 0, 6.0), 0.0)
	else:
		_box(c + Vector3(-27.0, 1.7, 5.5), Vector3(17.0, 3.4, 4.0), bleu, true, "metal")
		_box(c + Vector3(-33.0, 1.7, 8.0), Vector3(4.0, 3.0, 1.2), bleu.darkened(0.3), true, "metal")
		_box(c + Vector3(-27.0, 1.7, 3.3), Vector3(17.0, 2.0, 0.4), Color(0.12, 0.12, 0.12), false, "metal")
	var tables := ["militaire", "infeste", "militaire", "armurerie_mil", "infeste", "magasin"]
	var decal := [-7.0, 6.0, -9.0, 3.0, 9.0, -5.0]
	for i in 6:
		var t: String = tables[i]
		var p := c + Vector3(-9.0 + i * 15.0, 0, decal[i])
		var lbl := "Wagon blindé" if t == "armurerie_mil" else ("Wagon militaire" if t == "militaire" else "Wagon de marchandises")
		_wagon(p, i % 3 != 1, i % 2 == 0, t, lbl)
	for i in 12:
		var p := c + Vector3(rng.randf_range(-35.0, 75.0), 0, rng.randf_range(-14.0, 14.0))
		if absf(p.z - c.z) < 2.0:
			continue
		_prop(["caisse_mil", "caisse_bois", "baril_bleu", "palette", "caisse_munitions"][rng.randi() % 5], p, rng.randf() * TAU, true, 1.0, 150.0)
	_reserve(Rect2(c.x - 40.0, c.z - 17.0, 120.0, 34.0))
	for i in 28:
		var p := c + Vector3(rng.randf_range(-40.0, 75.0), 0.1, rng.randf_range(-16.0, 16.0))
		guards.append({"pos": p, "kind": ["militaire", "militaire", "civil", "civil", "police"][rng.randi() % 5], "radius": 35.0})
	_poi("Train déraillé (zone infestée)", c + Vector3(15.0, 0, 0), Color(1.0, 0.25, 0.2))
	Game.map_rects.append({"rect": Rect2(c.x - 45.0, c.z - 30.0, 130.0, 60.0), "color": Color(0.8, 0.1, 0.1, 0.25)})


# ---------------------------------------------------------------- après le relief
## Lignes à haute tension (pylônes posés sur le relief, câbles qui pendent).
func _lignes_ht() -> void:
	var m := Game.map_half - 120.0
	_ligne_ht(Vector2(-1350.0, -m), Vector2(-1350.0, m))
	_ligne_ht(Vector2(-m, 1750.0), Vector2(m, 1750.0))


func _ligne_ht(a: Vector2, b: Vector2) -> void:
	var long := a.distance_to(b)
	var dir := (b - a) / long
	var lat := Vector3(-dir.y, 0, dir.x)
	var av := Vector3(dir.x, 0, dir.y)
	var prec: Array = []
	var t := 0.0
	while t <= long:
		var p := a + dir * t
		t += 170.0
		var y: float = relief.hauteur(p.x, p.y)
		if relief.dans_eau(p.x, p.y) or _overlaps(Rect2(p.x - 4, p.y - 4, 8, 8)):
			prec = []
			continue
		var base := Vector3(p.x, y, p.y)
		_pylone(base, lat, av)
		var attaches: Array = []
		for e in [[20.0, 5.5], [25.5, 4.0]]:
			for sd in [-1.0, 1.0]:
				attaches.append(base + lat * sd * float(e[1]) + Vector3(0, float(e[0]) - 1.3, 0))
		if not prec.is_empty():
			for k in attaches.size():
				_cable(prec[k], attaches[k], 3.0)
		prec = attaches
		_reserve(Rect2(p.x - 4, p.y - 4, 8, 8))


func _pylone(base: Vector3, lat: Vector3, av: Vector3) -> void:
	var metal := Color(0.62, 0.63, 0.65)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			_box(base + Vector3(sx * 2.2, 5.0, sz * 2.2), Vector3(0.3, 10.0, 0.3), metal, true, "metal")
			_box(base + Vector3(sx * 1.0, 19.0, sz * 1.0), Vector3(0.22, 18.0, 0.22), metal, false, "metal")
	for hy in [3.0, 6.5, 10.0]:
		for sd in [-1.0, 1.0]:
			_box(base + Vector3(0, hy, sd * 2.2), Vector3(4.6, 0.15, 0.15), metal, false, "metal")
			_box(base + Vector3(sd * 2.2, hy, 0), Vector3(0.15, 0.15, 4.6), metal, false, "metal")
	for hy in [14.0, 18.0, 22.0, 27.0]:
		for sd in [-1.0, 1.0]:
			_box(base + Vector3(0, hy, sd * 1.0), Vector3(2.2, 0.12, 0.12), metal, false, "metal")
			_box(base + Vector3(sd * 1.0, hy, 0), Vector3(0.12, 0.12, 2.2), metal, false, "metal")
	for e in [[20.0, 12.0, 5.5], [25.5, 9.0, 4.0]]:
		_box(base + Vector3(0, float(e[0]), 0), _taille_ab(lat, av, float(e[1]), 0.5, 0.4), metal, false, "metal")
		for sd in [-1.0, 1.0]:
			_box(base + lat * sd * float(e[2]) + Vector3(0, float(e[0]) - 0.65, 0), Vector3(0.22, 1.3, 0.22), Color(0.25, 0.27, 0.3), false, "uni")
	_box(base + Vector3(0, 29.5, 0), Vector3(0.2, 3.0, 0.2), metal, false, "metal")


## Câble entre deux points, qui pend de « fleche » au milieu (deux bandes croisées : visible sous tous les angles).
func _cable(a: Vector3, b: Vector3, fleche: float) -> void:
	var noir := Color(0.1, 0.1, 0.1)
	var cote := (b - a).cross(Vector3.UP).normalized() * 0.035
	var prev := a
	for i in range(1, 5):
		var t := i / 4.0
		var p := a.lerp(b, t) - Vector3(0, fleche * 4.0 * t * (1.0 - t), 0)
		_quad(prev, p, p + Vector3(0, 0.07, 0), prev + Vector3(0, 0.07, 0), noir, "uni", true)
		_quad(prev - cote, p - cote, p + cote, prev + cote, noir, "uni", true)
		prev = p


## Éoliennes sur les sommets des collines (repères visibles de loin), pales qui tournent.
func _eoliennes() -> void:
	var cands: Array = []
	var m := Game.map_half - 150.0
	var x := -m
	while x < m:
		var z := -m
		while z < m:
			var y: float = relief.hauteur(x, z)
			if y > 13.0 and relief.pente(x, z) < 0.15 and not Game.in_city(Vector3(x, 0, z)) and not _overlaps(Rect2(x - 8, z - 8, 16, 16)):
				cands.append(Vector3(x, y, z))
			z += 30.0
		x += 30.0
	cands.sort_custom(func(a, b): return a.y > b.y)
	# trois parcs de 3 à 4 éoliennes autour des plus hauts sommets
	var poses: Array = []
	var parcs: Array = []   # [centre, nombre]
	for c in cands:
		var ok := true
		for p in poses:
			if Vector2(p.x - c.x, p.z - c.z).length() < 140.0:
				ok = false
		if not ok:
			continue
		var parc: Array = []
		for pa in parcs:
			if Vector2(pa[0].x - c.x, pa[0].z - c.z).length() < 480.0:
				parc = pa
		if parc.is_empty():
			if parcs.size() >= 3:
				continue
			parc = [c, 0]
			parcs.append(parc)
			_poi("Parc éolien", c, Color(0.85, 0.9, 0.95))
		elif parc[1] >= 4:
			continue
		parc[1] += 1
		poses.append(c)
		_eolienne(c)


func _eolienne(c: Vector3) -> void:
	var blanc := Color(0.92, 0.92, 0.9)
	var hm := 48.0
	_cylindre(c - Vector3(0, 0.5, 0), 1.5, hm + 0.5, blanc, "metal", 12)
	_box(c + Vector3(0, hm / 2.0, 0), Vector3(2.6, hm, 2.6), Color.WHITE, true, "invisible")
	_box(c + Vector3(0, hm + 1.2, 0.8), Vector3(2.4, 2.6, 6.0), blanc, false, "metal")
	_box(c + Vector3(0, 0.2, 0), Vector3(6.0, 0.8, 6.0), Color(0.8, 0.8, 0.78), true, "beton")
	var rotor := Eolienne.new()
	rotor.position = c + Vector3(0, hm + 1.2, -2.4)
	rotor.vitesse = rng.randf_range(0.35, 0.7)
	rotor.rotation.z = rng.randf() * TAU
	add_child(rotor)
	_reserve(Rect2(c.x - 5, c.z - 5, 10, 10))


## Panneaux aux carrefours, abribus, barrages routiers abandonnés.
func _details_routes() -> void:
	var hx := -half + 4 * BLOCK
	var hz := -half + 3 * BLOCK
	var croix: Array = []
	for x in RS_X:
		for z in RS_Z:
			croix.append(Vector3(x, 0, z))
		croix.append(Vector3(x, 0, hz))
	for z in RS_Z:
		croix.append(Vector3(hx, 0, z))
	var villes: Array = []
	for p in Game.pois:
		var nm: String = p.name
		if nm in ["Bellerive", "Valmont"] or nm.begins_with("Village") or nm.begins_with("Hameau"):
			villes.append(p)
	for i in croix.size():
		var c: Vector3 = croix[i]
		_panneau(c + Vector3(7.5, 0, 7.5), villes)
		if i % 2 == 0:
			_abribus(c + Vector3(-9.5, 0, 7.6))
	for b in [Vector3(-1000, 0, -1300), Vector3(400, 0, -800), Vector3(780, 0, 600), Vector3(-1500, 0, 1100), Vector3(1950, 0, -400)]:
		_barrage(b, b.z in RS_Z)


func _panneau(p: Vector3, villes: Array) -> void:
	if _overlaps(Rect2(p.x - 1, p.z - 1, 2, 2)):
		return
	p.y = relief.hauteur(p.x, p.z)
	_box(p + Vector3(0, 1.5, 0), Vector3(0.12, 3.0, 0.12), Color(0.5, 0.5, 0.5), true, "metal")
	var tri := villes.duplicate()
	tri.sort_custom(func(a, b): return Vector2(a.pos.x - p.x, a.pos.z - p.z).length() < Vector2(b.pos.x - p.x, b.pos.z - p.z).length())
	var lignes: Array = []
	for v in tri.slice(0, 3):
		var d := Vector2(v.pos.x - p.x, v.pos.z - p.z)
		var nom: String = str(v.name).trim_prefix("Village de ").trim_prefix("Village des ").trim_prefix("Hameau des ")
		var dist := ("%d m" % (roundi(d.length() / 50.0) * 50)) if d.length() < 1000.0 else ("%.1f km" % (d.length() / 1000.0)).replace(".", ",")
		lignes.append("%s  (%s)  %s" % [nom, ["E", "SE", "S", "SO", "O", "NO", "N", "NE"][posmod(roundi(atan2(d.y, d.x) / (PI / 4.0)), 8)], dist])
	var l := Label3D.new()
	l.text = "\n".join(lignes)
	l.font_size = 36
	l.pixel_size = 0.006
	l.outline_size = 10
	l.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	l.position = p + Vector3(0, 3.5, 0)
	l.visibility_range_end = 45.0
	l.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(l)
	_reserve(Rect2(p.x - 1, p.z - 1, 2, 2))


func _abribus(p: Vector3) -> void:
	if _overlaps(Rect2(p.x - 2.2, p.z - 1.2, 4.4, 2.4)):
		return
	p.y = relief.hauteur(p.x, p.z)
	var verre := Color(0.7, 0.8, 0.85)
	_box(p + Vector3(0, 0.05, 0), Vector3(4.2, 0.3, 2.0), Color(0.8, 0.8, 0.78), true, "beton")
	_box(p + Vector3(0, 1.4, 0.85), Vector3(3.8, 2.4, 0.06), verre, true, "vitre")
	for sx in [-1.0, 1.0]:
		_box(p + Vector3(sx * 1.9, 1.4, 0.3), Vector3(0.06, 2.4, 1.2), verre, true, "vitre")
	_box(p + Vector3(0, 2.65, 0.1), Vector3(4.2, 0.12, 2.0), Color(0.3, 0.32, 0.35), true, "metal")
	_prop("banc", p + Vector3(0, 0.2, 0.4), 0.0, false, 1.0, 120.0)
	_reserve(Rect2(p.x - 2.2, p.z - 1.2, 4.4, 2.4))


## Barrage routier abandonné : blocs de béton en travers, voiture de police, sacs de sable, caisse, policiers zombies.
func _barrage(c: Vector3, le_long_x: bool) -> void:
	var u := Vector3(1, 0, 0) if le_long_x else Vector3(0, 0, 1)
	var v := Vector3(-u.z, 0, u.x)
	var ang := PI / 2.0 if le_long_x else 0.0
	var sol := func(p: Vector3) -> Vector3: return Vector3(p.x, maxf(relief.hauteur(p.x, p.z), 0.0), p.z)
	for k in [-2.6, -0.9, 0.9]:
		_prop("barriere_beton", sol.call(c + v * k), PI / 2.0 - ang, true, 1.0, 160.0)
	_prop("voiture_police", sol.call(c + u * 7.0 + v * 1.4), ang + rng.randf_range(-0.5, 0.5), true, 1.0, 220.0)
	for i in 5:
		_prop("cone", sol.call(c - u * rng.randf_range(3.0, 8.0) + v * rng.randf_range(-3.0, 3.0)), rng.randf() * TAU, false, 1.0, 120.0)
	for sd in [-1.0, 1.0]:
		var ps: Vector3 = sol.call(c - u * 2.0 + v * sd * 5.2)
		if not _overlaps(Rect2(ps.x - 1.6, ps.z - 1.6, 3.2, 3.2)):
			_box(ps + Vector3(0, 0.55, 0), _taille_ab(u, v, 3.0, 1.0, 1.1), Color(1.1, 1.0, 0.8), true, "terre")
	var cont := _container(sol.call(c + u * 3.5 - v * 2.0), Vector3(1.0, 0.7, 0.6), Color(0.25, 0.28, 0.35), "Caisse de la police", "police", 3)
	cont.set_texture("metal_peint")
	for i in 7:
		var p: Vector3 = sol.call(c + u * rng.randf_range(-18.0, 18.0) + v * rng.randf_range(-5.0, 5.0))
		guards.append({"pos": p + Vector3(0, 0.1, 0), "kind": ["police", "police", "civil", "militaire"][rng.randi() % 4], "radius": 18.0})
	_poi("Barrage routier", c, Color(0.95, 0.5, 0.2))


# ================================================================ lieux uniques
## Aérodrome, camp de réfugiés, crash d'hélicoptère, casse auto, prison, barrage et centrale, manoir et cimetière,
## colonie de vacances, décharge : chacun sur un terrain aplani, relié à la route la plus proche.
var lacs_speciaux: Array = []   # lacs de ces lieux, ajoutés au relief après les lacs tirés au hasard


func _lieux_uniques() -> void:
	# [position voulue, emprise (relative à la position), construction, largeur de la route d'accès]
	var lieux := [
		[Vector3(1690, 0, -380), Rect2(-240, -75, 480, 115), _aerodrome, 7.0],
		[Vector3(-1130, 0, 650), Rect2(-65, -55, 130, 110), _camp_refugies, 6.0],
		[Vector3(-1430, 0, 1420), Rect2(-16, -16, 32, 32), _crash_helico, 0.0],
		[Vector3(1330, 0, -1000), Rect2(-45, -35, 90, 70), _casse_auto, 6.0],
		[Vector3(-2200, 0, -1700), Rect2(-60, -60, 120, 120), _prison, 7.0],
		[Vector3(-1600, 0, -350), Rect2(-80, -150, 160, 195), _barrage_centrale, 6.0],
		[Vector3(-300, 0, -1150), Rect2(-60, -45, 120, 90), _manoir, 4.0],
		[Vector3(1650, 0, 1300), Rect2(-75, -120, 150, 170), _colonie, 6.0],
		[Vector3(-1650, 0, 1860), Rect2(-55, -45, 110, 90), _decharge, 6.0],
	]
	for l in lieux:
		var rel: Rect2 = l[1]
		var p := _libre_rect(l[0], rel, 80.0)
		if p == Vector3.INF:
			continue
		(l[2] as Callable).call(p)
		_reserve(Rect2(p.x + rel.position.x, p.z + rel.position.y, rel.size.x, rel.size.y))
		if float(l[3]) > 0.0:
			_relier(p, rel, l[3], C_ASPHALT, 0.06)
		else:
			_relier(p, rel, 2.6, C_DIRT, 0.05)


## Position libre près de « base » pour une emprise « rel » (relative), ou Vector3.INF.
func _libre_rect(base: Vector3, rel: Rect2, portee: float) -> Vector3:
	var lim := Game.map_half - 70.0
	for i in 40:
		var f := minf(1.0, i / 12.0)
		var p := base + Vector3(rng.randf_range(-portee, portee) * f, 0, rng.randf_range(-portee, portee) * f)
		var r := Rect2(p.x + rel.position.x, p.z + rel.position.y, rel.size.x, rel.size.y)
		if r.position.x < -lim or r.end.x > lim or r.position.y < -lim or r.end.y > lim:
			continue
		if not _overlaps(r):
			return p
	return Vector3.INF


## Route (posée sur le relief) d'un lieu d'emprise « rel » jusqu'à la route la plus proche qu'elle peut atteindre sans traverser un autre lieu.
func _relier(p: Vector3, rel: Rect2, larg: float, col: Color, dy: float) -> void:
	var hx := -half + 4 * BLOCK
	var hz := -half + 3 * BLOCK
	var cibles: Array = []
	for x in RS_X + [hx]:
		cibles.append(Vector2(x, p.z))
	for z in RS_Z + [hz]:
		cibles.append(Vector2(p.x, z))
	var a := Vector2(p.x, p.z)
	cibles.sort_custom(func(u, v): return a.distance_to(u) < a.distance_to(v))
	for cible in cibles.slice(0, 4):
		var long: float = a.distance_to(cible)
		if long < 1.0:
			continue
		var dir: Vector2 = (cible - a) / long
		var sortie: float = (rel.end.x if dir.x > 0.5 else -rel.position.x) if absf(dir.x) > 0.5 else (rel.end.y if dir.y > 0.5 else -rel.position.y)
		var depart := sortie + 2.5
		if long > 800.0 or long < depart + 6.0:
			continue
		var deb := a + dir * depart
		var fin: Vector2 = cible - dir * 7.0
		var test := Rect2(minf(deb.x, fin.x) - larg / 2.0 - 0.5, minf(deb.y, fin.y) - larg / 2.0 - 0.5, absf(fin.x - deb.x) + larg + 1.0, absf(fin.y - deb.y) + larg + 1.0)
		if _overlaps(test):
			continue
		_route_drapee(a + dir * (sortie - 1.0), cible, larg, col, dy)
		return


## Lac posé avec un lieu ; le rive sud est la plus éloignée du centre (c'est là qu'on construit).
func _lac_special(c: Vector3, r: float) -> void:
	lacs_speciaux.append({"c": Vector2(c.x, c.z), "r": r, "p": [-PI, 0.0, PI / 2.0], "prof": 2.2})
	_reserve(Rect2(c.x - r * 1.3 - 6.0, c.z - r * 1.3 - 6.0, r * 2.6 + 12.0, r * 2.6 + 12.0))


func _guards(c: Vector3, n: int, demi: Vector2, kinds: Array, rayon: float) -> void:
	for i in n:
		guards.append({"pos": c + Vector3(rng.randf_range(-demi.x, demi.x), 0.1, rng.randf_range(-demi.y, demi.y)), "kind": kinds[rng.randi() % kinds.size()], "radius": rayon})


## Grillage (poteaux + panneau de treillis) le long d'un segment axé ; « trou » : ouverture centrée de cette largeur.
func _grillage(a: Vector2, b: Vector2, h: float, trou := 0.0) -> void:
	var long := a.distance_to(b)
	var dir := (b - a) / long
	var morceaux: Array = [[0.0, long]] if trou <= 0.0 else [[0.0, (long - trou) / 2.0], [(long + trou) / 2.0, long]]
	for m in morceaux:
		var p0: Vector2 = a + dir * float(m[0])
		var p1: Vector2 = a + dir * float(m[1])
		var mid := (p0 + p1) / 2.0
		var lg := p0.distance_to(p1)
		var t := Vector3(lg, h, 0.05) if absf(dir.x) > 0.5 else Vector3(0.05, h, lg)
		_box(Vector3(mid.x, h / 2.0, mid.y), t, Color.WHITE, true, "invisible")
		for k in 6:   # fils tendus (on voit à travers), le dernier en barbelé
			var y := 0.25 + k * (h - 0.25) / 5.0
			_box(Vector3(mid.x, y, mid.y), Vector3(lg, 0.03, 0.03) if absf(dir.x) > 0.5 else Vector3(0.03, 0.03, lg), Color(0.5, 0.52, 0.55), false, "metal")
		var s := 0.0
		while s <= lg:
			var q := p0 + dir * s
			_box(Vector3(q.x, h / 2.0 + 0.1, q.y), Vector3(0.1, h + 0.2, 0.1), Color(0.4, 0.42, 0.44), false, "metal")
			s += 3.0


func _sacs_sable(c: Vector3, le_long_x: bool, lg: float) -> void:
	_box(c + Vector3(0, 0.55, 0), Vector3(lg, 1.1, 1.0) if le_long_x else Vector3(1.0, 1.1, lg), Color(1.1, 1.0, 0.8), true, "terre")


# ---------------------------------------------------------------- aérodrome
func _aerodrome(p: Vector3) -> void:
	var piste := Rect2(p.x - 230.0, p.z + 10.0, 460.0, 22.0)
	_flat(piste, 0.03, Color(0.85, 0.85, 0.85), "asphalte")
	Game.sols.append({"r": piste, "s": "beton"})
	var x := piste.position.x + 20.0
	while x < piste.end.x - 20.0:
		_box(Vector3(x, 0.045, p.z + 21.0), Vector3(12.0, 0.01, 0.5), Color(0.92, 0.92, 0.9), false, "uni")
		x += 30.0
	for sx in [-1.0, 1.0]:
		for k in 6:
			_box(Vector3(p.x + sx * 222.0, 0.045, p.z + 13.0 + k * 3.2), Vector3(10.0, 0.01, 1.4), Color(0.92, 0.92, 0.9), false, "uni")
	_flat(Rect2(p.x - 120.0, p.z - 40.0, 210.0, 32.0), 0.025, Color(0.85, 0.85, 0.82), "beton")
	_flat(Rect2(p.x - 20.0, p.z - 8.0, 14.0, 18.0), 0.028, Color(0.85, 0.85, 0.85), "asphalte")
	var gris := Color(0.62, 0.64, 0.66)
	var h1 := _building(p + Vector3(-90.0, 0, -54.0), 32.0, 28.0, 9.0, gris, ["s"], "grange", "Hangar de l'aérodrome", false, 8, Color(0.5, 0.52, 0.55))
	var h2 := _building(p + Vector3(-45.0, 0, -54.0), 30.0, 28.0, 9.0, gris.darkened(0.1), ["s"], "garage", "Hangar d'entretien", false, 8, Color(0.5, 0.52, 0.55))
	var club := _building(p + Vector3(15.0, 0, -56.0), 18.0, 12.0, 3.6, Color(0.82, 0.8, 0.74), ["s"], "bureau", "Club d'aviation", false, 6, Color(0.55, 0.52, 0.48))
	for z in [h1, h2, club]:
		_residents(z, 0.8, 3)
	# tour de contrôle : fût, cabine vitrée à 14 m, échelle côté +x
	var t := p + Vector3(60.0, 0, -56.0)
	_box(t + Vector3(0, 7.0, 0), Vector3(4.0, 14.0, 4.0), Color(0.85, 0.84, 0.8), true, "beton")
	_box(t + Vector3(0, 14.15, 0), Vector3(7.0, 0.3, 7.0), Color(0.75, 0.75, 0.72), true, "beton")
	for e in [[Vector3(0, 0, -3.4), Vector3(7.0, 1.0, 0.15)], [Vector3(0, 0, 3.4), Vector3(7.0, 1.0, 0.15)], [Vector3(-3.4, 0, 0), Vector3(0.15, 1.0, 7.0)]]:
		_box(t + e[0] + Vector3(0, 14.8, 0), e[1], Color(0.75, 0.75, 0.72), true, "beton")
	_box(t + Vector3(3.4, 14.8, -2.0), Vector3(0.15, 1.0, 3.0), Color(0.75, 0.75, 0.72), true, "beton")
	_box(t + Vector3(0, 16.3, 0), Vector3(7.0, 2.0, 7.0), Color(0.6, 0.75, 0.8), false, "vitre")
	_box(t + Vector3(0, 17.45, 0), Vector3(7.6, 0.3, 7.6), Color(0.4, 0.4, 0.42), true, "metal")
	var xe := t.x + 2.2
	for sz in [-0.25, 0.25]:
		_box(Vector3(xe, 7.5, t.z + 1.0 + sz), Vector3(0.06, 15.0, 0.06), Color(0.6, 0.6, 0.6), false, "metal")
	var yb := 0.3
	while yb < 14.3:
		_box(Vector3(xe, yb, t.z + 1.0), Vector3(0.04, 0.04, 0.5), Color(0.6, 0.6, 0.6), false, "metal")
		yb += 0.3
	Game.echelles.append({"pos": Vector3(xe, 0, t.z + 1.0), "n": Vector3(1, 0, 0), "haut": 14.3})
	var pupitre := _container(t + Vector3(-2.2, 14.3, 0), Vector3(1.6, 0.9, 0.7), Color(0.3, 0.3, 0.32), "Pupitre de la tour", "police", 3)
	pupitre.set_texture("metal_peint")
	# petit avion sur le tarmac : la carlingue se fouille (soute)
	var a := p + Vector3(20.0, 0, -25.0)
	var blanc := Color(0.9, 0.9, 0.88)
	if Decor.existe("avion_leger"):
		_prop("avion_leger", a, PI / 2.0, false, 1.0, 300.0)
		var so := _container(a + Vector3(0, 0.4, 0), Vector3(6.5, 1.6, 1.4), blanc, "Soute de l'avion", "magasin", 4)
		so.mesh_i.visible = false
	else:
		_avion_boites(a, blanc, true)
	# cuves de carburant, manche à air, voitures
	_aerodrome_suite(p)


## Petit avion en boîtes (sans modèle 3D) ; « soute » : la carlingue se fouille.
func _avion_boites(a: Vector3, blanc: Color, soute: bool) -> void:
	if soute:
		var s := _container(a + Vector3(0, 0.5, 0), Vector3(8.0, 1.6, 1.6), blanc, "Soute de l'avion", "magasin", 4)
		s.set_texture("metal_peint")
	else:
		_box(a + Vector3(0, 1.3, 0), Vector3(8.0, 1.6, 1.6), blanc.darkened(0.15), true, "metal")
	_box(a + Vector3(-0.8, 1.5, 0), Vector3(1.8, 0.18, 11.0), blanc, true, "metal")
	_box(a + Vector3(3.8, 1.3, 0), Vector3(1.2, 0.12, 3.6), blanc, false, "metal")
	_box(a + Vector3(4.0, 2.2, 0), Vector3(1.0, 1.6, 0.12), Color(0.75, 0.15, 0.1), false, "metal")
	_box(a + Vector3(-2.2, 1.95, 0), Vector3(1.6, 0.7, 1.4), Color(0.2, 0.25, 0.3), false, "vitre")
	_box(a + Vector3(-4.15, 1.3, 0), Vector3(0.1, 2.2, 0.2), Color(0.15, 0.15, 0.15), false, "metal")
	for sz in [-0.9, 0.9]:
		_box(a + Vector3(-1.0, 0.25, sz), Vector3(0.5, 0.5, 0.2), Color(0.1, 0.1, 0.1), false, "uni")


func _aerodrome_suite(p: Vector3) -> void:
	# cuves de carburant, manche à air, voitures
	for k in 2:
		var cu := p + Vector3(100.0 + k * 7.0, 0, -50.0)
		_cylindre(cu, 2.4, 4.5, Color(0.8, 0.8, 0.78), "metal", 12)
		_disque(cu + Vector3(0, 4.5, 0), 2.4, Color(0.75, 0.75, 0.72), "metal", 12)
		_box(cu + Vector3(0, 2.25, 0), Vector3(4.0, 4.5, 4.0), Color.WHITE, true, "invisible")
	for i in 4:
		_prop("jerrican", p + Vector3(rng.randf_range(94.0, 112.0), 0, rng.randf_range(-44.0, -42.0)), rng.randf() * TAU, false, 1.0, 100.0)
	_box(p + Vector3(150.0, 3.0, -20.0), Vector3(0.15, 6.0, 0.15), Color(0.7, 0.7, 0.7), false, "metal")
	_box(p + Vector3(151.4, 5.6, -20.0), Vector3(2.6, 0.6, 0.6), Color(0.95, 0.45, 0.1), false, "uni")
	for i in 3:
		_car(p + Vector3(40.0 + i * 8.0, 0, -32.0), false, CAR_COLORS[rng.randi() % CAR_COLORS.size()].darkened(0.3))
	_guards(p + Vector3(0, 0, -20.0), 16, Vector2(130.0, 25.0), ["civil", "civil", "civil", "militaire"], 40.0)
	Game.map_rects.append({"rect": Rect2(p.x - 230.0, p.z + 10.0, 460.0, 22.0), "color": Color(0.3, 0.3, 0.32)})
	_poi("Aérodrome", p + Vector3(0, 0, -20.0), Color(0.75, 0.8, 0.9))


# ---------------------------------------------------------------- camp de réfugiés
func _camp_refugies(p: Vector3) -> void:
	_flat(Rect2(p.x - 60.0, p.z - 50.0, 120.0, 100.0), 0.012, Color(0.95, 0.92, 0.88), "terre")
	_grillage(Vector2(p.x - 60.0, p.z - 50.0), Vector2(p.x + 60.0, p.z - 50.0), 2.6, 8.0)
	_grillage(Vector2(p.x - 60.0, p.z + 50.0), Vector2(p.x + 60.0, p.z + 50.0), 2.6, 8.0)
	_grillage(Vector2(p.x - 60.0, p.z - 50.0), Vector2(p.x - 60.0, p.z + 50.0), 2.6)
	_grillage(Vector2(p.x + 60.0, p.z - 50.0), Vector2(p.x + 60.0, p.z + 50.0), 2.6, 8.0)
	# check-points aux entrées : sacs de sable, guérite, barrière
	for e in [[Vector3(p.x, 0, p.z + 50.0), true], [Vector3(p.x, 0, p.z - 50.0), true], [Vector3(p.x + 60.0, 0, p.z), false]]:
		var c: Vector3 = e[0]
		var lx: bool = e[1]
		var dh := Vector3(1, 0, 0) if lx else Vector3(0, 0, 1)
		var dv := Vector3(0, 0, 1) if lx else Vector3(1, 0, 0)
		for sd in [-1.0, 1.0]:
			_sacs_sable(c + dh * sd * 6.5 + dv * 3.0, lx, 3.0)
		_box(c + dh * 7.0 - dv * 3.5 + Vector3(0, 1.3, 0), Vector3(2.2, 2.6, 2.2), Color(0.35, 0.4, 0.3), true, "tole")
		_box(c + dh * -3.0 + Vector3(0, 1.0, 0), (Vector3(6.0, 0.15, 0.15) if lx else Vector3(0.15, 0.15, 6.0)), Color(0.85, 0.2, 0.15), false, "uni")
		var cc := _container(c + dh * 7.0 + dv * 1.0, Vector3(1.0, 0.6, 0.6), Color(0.3, 0.33, 0.25), "Caisse du check-point", "militaire", 2)
		cc.set_texture("metal_peint")
	# rangées de tentes
	var olive := Color(0.36, 0.4, 0.28)
	for i in 4:
		for k in 5:
			var c := p + Vector3(-42.0 + k * 13.0, 0, -32.0 + i * 13.0)
			if k == 4 and i < 2:
				continue
			_tente_grande(c, olive.lightened(rng.randf_range(-0.05, 0.1)), ["camping", "camping", "maison", "hopital"][rng.randi() % 4])
	var inf := _building(p + Vector3(32.0, 0, -32.0), 16.0, 9.0, 3.6, Color(0.85, 0.85, 0.8), ["s"], "hopital", "Infirmerie de campagne", false, 7, Color(0.7, 0.3, 0.3))
	var cmd := _building(p + Vector3(32.0, 0, 25.0), 12.0, 8.0, 3.6, olive, ["w"], "militaire", "Poste de commandement", false, 6, Color(0.35, 0.42, 0.28))
	_residents(inf, 1.0, 4)
	_residents(cmd, 1.0, 3)
	for i in 8:
		_prop(["caisse_mil", "caisse_bois", "palette", "baril_bleu"][rng.randi() % 4], p + Vector3(rng.randf_range(-52.0, 52.0), 0, rng.randf_range(40.0, 46.0)), rng.randf() * TAU, true, 1.0, 140.0)
	for i in 3:
		var cr := _container(p + Vector3(-50.0 + i * 4.0, 0, 44.0), Vector3(1.2, 0.8, 0.8), Color(0.85, 0.85, 0.82), "Caisse humanitaire", "magasin", 3)
		cr.set_texture("metal_peint")
	_modele_ou_voiture("camion_mil", p + Vector3(48.0, 0, 10.0), 0.1, "voiture_suv", Color(0.28, 0.32, 0.2))
	_modele_ou_voiture("camion_mil", p + Vector3(50.0, 0, -8.0), -0.15, "voiture_suv", Color(0.28, 0.32, 0.2))
	for e in [Vector3(-55.0, 0, -45.0), Vector3(-55.0, 0, 45.0)]:   # tours de garde aux coins
		_prop("tour_garde", p + e, 0.0, true, 1.2, 320.0)
	_guards(p, 50, Vector2(55.0, 45.0), ["civil", "civil", "civil", "civil", "militaire"], 45.0)
	_poi("Camp de réfugiés (zone infestée)", p, Color(1.0, 0.25, 0.2))
	Game.map_rects.append({"rect": Rect2(p.x - 62.0, p.z - 52.0, 124.0, 104.0), "color": Color(0.8, 0.1, 0.1, 0.25)})


## Grande tente (fouillable) : comme _tente, plus grande, avec une table de butin au choix.
func _tente_grande(c: Vector3, col: Color, table: String) -> void:
	var u := Vector3(1, 0, 0)
	var v := Vector3(0, 0, 1)
	var lu := 4.0
	var lv := 6.0
	var h := 2.4
	var ct := _container(c, _taille_ab(u, v, lu, lv, h), col, "Tente", table, 2)
	ct.mesh_i.visible = false
	if _prop("tente_mil", c, 0.0, false, 1.0, 200.0):
		return
	var f0 := c - v * lv / 2.0 + Vector3(0, h, 0)
	var f1 := c + v * lv / 2.0 + Vector3(0, h, 0)
	var g0 := c - u * lu / 2.0 - v * lv / 2.0
	var g1 := c - u * lu / 2.0 + v * lv / 2.0
	var d0 := c + u * lu / 2.0 - v * lv / 2.0
	var d1 := c + u * lu / 2.0 + v * lv / 2.0
	_quad(g0, g1, f1, f0, col, "uni", true)
	_quad(d0, d1, f1, f0, col, "uni", true)
	for e in [[g0, d0, f0], [g1, d1, f1]]:
		_tri(e[0], e[1], e[2], col.darkened(0.2), "uni")
		_tri(e[1], e[0], e[2], col.darkened(0.2), "uni")


## Véhicule ou décor en modèle 3D si disponible, sinon voiture (id_secours) comme avant.
func _modele_ou_voiture(id: String, c: Vector3, ang: float, id_secours: String, col: Color) -> void:
	if Decor.existe(id):
		_prop(id, c, ang, true, 1.0, 240.0)
	else:
		_car(c, absf(sin(ang)) > 0.5, col, id_secours)


# ---------------------------------------------------------------- crash d'hélicoptère
func _crash_helico(p: Vector3) -> void:
	var olive := Color(0.3, 0.34, 0.24)
	var carl := _container(p, Vector3(3.0, 2.4, 9.0), olive, "Épave de l'hélicoptère", "militaire", 4)
	carl.set_texture("metal_peint")
	var helico := _prop("helico", p + Vector3(0, -0.3, 0), rng.randf_range(-0.3, 0.3), false, 1.0, 300.0) if Decor.existe("helico") else null
	if helico:
		carl.mesh_i.visible = false   # la carlingue du modèle sert de boîte à fouiller
		helico.rotation.z = 0.42
		helico.position.y -= 0.5
	else:
		_box(p + Vector3(0, 1.5, -5.2), Vector3(2.6, 1.8, 1.6), Color(0.2, 0.25, 0.3), true, "vitre")
		_box(p + Vector3(0.6, 1.6, 8.6), Vector3(0.8, 0.8, 8.2), olive, true, "metal")
		_box(p + Vector3(0.6, 2.6, 12.4), Vector3(0.15, 2.0, 1.2), olive, false, "metal")
		_box(p + Vector3(0, 2.6, 0), Vector3(0.5, 0.4, 0.5), Color(0.15, 0.15, 0.15), false, "metal")
	for k in 4:
		var q := p + Vector3(rng.randf_range(-9.0, 9.0), 0.08, rng.randf_range(-9.0, 9.0))
		_box(q, Vector3(7.0, 0.08, 0.45) if k % 2 == 0 else Vector3(0.45, 0.08, 7.0), Color(0.12, 0.12, 0.12), false, "metal")
	for k in 4:   # herbe brûlée autour de l'épave
		_flat(Rect2(p.x + rng.randf_range(-7.0, 3.0), p.z + rng.randf_range(-8.0, 4.0), rng.randf_range(4.0, 7.0), rng.randf_range(4.0, 8.0)), 0.015 + k * 0.002, Color(0.3, 0.27, 0.24), "terre")
	var armes := _container(p + Vector3(3.2, 0, -1.0), Vector3(1.2, 0.5, 0.6), Color(0.3, 0.33, 0.25), "Caisse d'armes", "armurerie_mil", 2)
	armes.set_texture("metal_peint")
	for i in 3:
		_prop(["caisse_mil", "caisse_munitions"][i % 2], p + Vector3(rng.randf_range(-8.0, 8.0), 0, rng.randf_range(-10.0, 10.0)), rng.randf() * TAU, true, 1.0, 120.0)
	_guards(p, 10, Vector2(12.0, 12.0), ["militaire"], 25.0)
	_poi("Crash d'hélicoptère", p, Color(1.0, 0.45, 0.2))


# ---------------------------------------------------------------- casse auto
func _casse_auto(p: Vector3) -> void:
	_flat(Rect2(p.x - 42.0, p.z - 32.0, 84.0, 64.0), 0.012, Color(0.8, 0.75, 0.7), "terre")
	var cote := [[Vector2(-42, -32), Vector2(42, -32)], [Vector2(-42, 32), Vector2(42, 32)], [Vector2(-42, -32), Vector2(-42, 32)], [Vector2(42, -32), Vector2(42, 32)]]
	for c in cote:
		var a: Vector2 = c[0]
		var b: Vector2 = c[1]
		var le_long_x := absf(b.x - a.x) > 1.0
		var lg := absf(b.x - a.x) if le_long_x else absf(b.y - a.y)
		for sd in [-1.0, 1.0]:   # tôles de part et d'autre d'une entrée de 8 m
			var m := (a + b) / 2.0 + (Vector2(sd * (lg / 4.0 + 2.0), 0) if le_long_x else Vector2(0, sd * (lg / 4.0 + 2.0)))
			_box(Vector3(p.x + m.x, 1.2, p.z + m.y), Vector3(lg / 2.0 - 4.0, 2.4, 0.08) if le_long_x else Vector3(0.08, 2.4, lg / 2.0 - 4.0), Color(0.55, 0.5, 0.45), true, "tole")
	# rangées d'épaves (démontables à la hache ou à la pioche), quelques-unes empilées
	for row in 4:
		for k in 7:
			var c := p + Vector3(-27.0 + k * 8.0, 0, -22.0 + row * 12.0)
			if row == 3 and k > 4:
				continue
			var id: String = VOITURES[rng.randi() % VOITURES.size()]
			var col: Color = CAR_COLORS[rng.randi() % CAR_COLORS.size()].darkened(rng.randf_range(0.3, 0.6))
			var v := _prop(id, c, rng.randf_range(-0.15, 0.15), true, 1.0, 220.0)
			if v and id != "voiture_taxi":
				Decor.peindre(v, col)
			if rng.randf() < 0.3:
				var v2 := _prop(VOITURES[rng.randi() % 2], c + Vector3(0, 1.45, 0), rng.randf_range(-0.3, 0.3), true, 1.0, 220.0)
				if v2:
					Decor.peindre(v2, CAR_COLORS[rng.randi() % CAR_COLORS.size()].darkened(0.5))
	for i in 10:
		_prop("pneu", p + Vector3(rng.randf_range(-38.0, 38.0), 0, rng.randf_range(26.0, 29.0)), rng.randf() * TAU, false, 1.0, 120.0)
	var bur := _building(p + Vector3(32.0, 0, 22.0), 9.0, 6.0, 3.6, Color(0.6, 0.55, 0.45), ["w"], "garage", "Bureau de la casse", false, 4, Color(0.5, 0.45, 0.4))
	_residents(bur, 0.7, 2)
	for i in 4:
		var c := _container(p + Vector3(-38.0 + i * 3.0, 0, 26.0), Vector3(1.4, 0.8, 0.9), Color(0.45, 0.32, 0.22), "Pièces détachées", "garage", 2)
		c.set_texture("metal_peint")
	_guards(p, 10, Vector2(38.0, 28.0), ["civil"], 30.0)
	_poi("Casse auto", p, Color(0.75, 0.6, 0.45))


# ---------------------------------------------------------------- prison
func _prison(p: Vector3) -> void:
	_flat(Rect2(p.x - 55.0, p.z - 55.0, 110.0, 110.0), 0.012, Color(0.85, 0.83, 0.8), "beton")
	Game.sols.append({"r": Rect2(p.x - 55.0, p.z - 55.0, 110.0, 110.0), "s": "beton"})
	var mur := Color(0.78, 0.77, 0.74)
	var hm := 5.5
	_box(p + Vector3(0, hm / 2.0, -55.0), Vector3(110.0, hm, 0.7), mur, true, "beton")
	_box(p + Vector3(-55.0, hm / 2.0, 0), Vector3(0.7, hm, 110.0), mur, true, "beton")
	_box(p + Vector3(55.0, hm / 2.0, 0), Vector3(0.7, hm, 110.0), mur, true, "beton")
	for sd in [-1.0, 1.0]:   # mur sud avec le portail (ouvert) au milieu
		_box(p + Vector3(sd * 30.0, hm / 2.0, 55.0), Vector3(50.0, hm, 0.7), mur, true, "beton")
	for e in [[Vector3(0, hm + 0.3, -55.0), Vector3(110.0, 0.5, 0.3)], [Vector3(-55.0, hm + 0.3, 0), Vector3(0.3, 0.5, 110.0)], [Vector3(55.0, hm + 0.3, 0), Vector3(0.3, 0.5, 110.0)]]:
		_box(p + e[0], e[1], Color(0.25, 0.25, 0.25), false, "metal")
	# miradors en béton aux coins
	for c in [Vector3(-52, 0, -52), Vector3(52, 0, -52), Vector3(-52, 0, 52), Vector3(52, 0, 52)]:
		_box(p + c + Vector3(0, 4.5, 0), Vector3(2.6, 9.0, 2.6), mur.darkened(0.1), true, "beton")
		_box(p + c + Vector3(0, 9.6, 0), Vector3(4.0, 1.2, 4.0), Color(0.6, 0.72, 0.78), false, "vitre")
		_box(p + c + Vector3(0, 10.35, 0), Vector3(4.6, 0.3, 4.6), Color(0.35, 0.35, 0.37), false, "metal")
	var gris := Color(0.7, 0.68, 0.64)
	var a := _building(p + Vector3(-25.0, 0, -28.0), 40.0, 14.0, 7.2, gris, ["s"], "police", "Bloc cellulaire A", true, 10, Color(0.45, 0.45, 0.5))
	var b := _building(p + Vector3(25.0, 0, -28.0), 40.0, 14.0, 7.2, gris, ["s"], "police", "Bloc cellulaire B", true, 10, Color(0.45, 0.45, 0.5))
	var adm := _building(p + Vector3(-30.0, 0, 28.0), 22.0, 12.0, 3.6, gris.lightened(0.1), ["e"], "bureau", "Administration pénitentiaire", true, 8, Color(0.45, 0.45, 0.5))
	var ref := _building(p + Vector3(28.0, 0, 28.0), 20.0, 12.0, 3.6, gris.lightened(0.05), ["w"], "magasin", "Réfectoire", false, 8, Color(0.45, 0.45, 0.5))
	for z in [a, b, adm, ref]:
		_residents(z, 1.0, 5)
	var arm := _container(p + Vector3(-45.0, 0, 44.0), Vector3(1.4, 1.8, 0.6), Color(0.3, 0.32, 0.36), "Armurerie des surveillants", "police", 4)
	arm.set_texture("metal_peint")
	_prop("voiture_police", p + Vector3(8.0, 0, 64.0), PI / 2.0, true, 1.0, 220.0)
	_guards(p, 28, Vector2(48.0, 10.0), ["civil", "civil", "civil", "police"], 40.0)
	_guards(p + Vector3(0, 0, 62.0), 5, Vector2(20.0, 4.0), ["police"], 25.0)
	_poi("Prison", p, Color(0.6, 0.6, 0.7))


# ---------------------------------------------------------------- barrage et centrale
func _barrage_centrale(p: Vector3) -> void:
	var r := 55.0
	var lc := p + Vector3(0, 0, -70.0)
	_lac_special(lc, r)
	var zm := lc.z + r * 1.32 + 2.5   # mur du barrage, contre la rive sud
	var beton := Color(0.8, 0.79, 0.76)
	_box(Vector3(lc.x, 3.3, zm), Vector3(150.0, 8.4, 5.0), beton, true, "beton")
	for sd in [-1.0, 1.0]:
		_box(Vector3(lc.x, 8.0, zm + sd * 2.35), Vector3(150.0, 1.0, 0.25), beton.darkened(0.1), true, "beton")
	for k in 4:   # vannes de l'évacuateur
		_box(Vector3(lc.x - 22.5 + k * 15.0, 4.0, zm + 2.6), Vector3(4.0, 6.0, 0.3), Color(0.35, 0.37, 0.4), false, "metal")
	var xe := lc.x + 76.0
	for sz in [-0.25, 0.25]:
		_box(Vector3(xe, 3.8, zm + sz), Vector3(0.06, 7.6, 0.06), Color(0.6, 0.6, 0.6), false, "metal")
	var yb := 0.3
	while yb < 7.5:
		_box(Vector3(xe, yb, zm), Vector3(0.04, 0.04, 0.5), Color(0.6, 0.6, 0.6), false, "metal")
		yb += 0.3
	Game.echelles.append({"pos": Vector3(xe, 0, zm), "n": Vector3(1, 0, 0), "haut": 7.5})
	var cen := _building(Vector3(lc.x - 15.0, 0, zm + 24.0), 40.0, 18.0, 9.0, Color(0.72, 0.7, 0.66), ["s", "n"], "grange", "Centrale hydroélectrique", false, 9, Color(0.45, 0.48, 0.55))
	_residents(cen, 1.0, 5)
	# poste de transformation
	var tp := Vector3(lc.x + 35.0, 0, zm + 24.0)
	for i in 3:
		for k in 2:
			_box(tp + Vector3(-8.0 + i * 8.0, 1.6, -4.0 + k * 8.0), Vector3(3.0, 3.2, 2.4), Color(0.45, 0.48, 0.45), true, "metal")
			_box(tp + Vector3(-8.0 + i * 8.0, 4.0, -4.0 + k * 8.0), Vector3(0.3, 1.6, 0.3), Color(0.7, 0.55, 0.4), false, "uni")
	_grillage(Vector2(tp.x - 13.0, tp.z - 9.0), Vector2(tp.x + 13.0, tp.z - 9.0), 2.4)
	_grillage(Vector2(tp.x - 13.0, tp.z + 9.0), Vector2(tp.x + 13.0, tp.z + 9.0), 2.4, 4.0)
	_grillage(Vector2(tp.x + 13.0, tp.z - 9.0), Vector2(tp.x + 13.0, tp.z + 9.0), 2.4)
	for i in 2:
		var c := _container(tp + Vector3(-11.0 + i * 3.0, 0, 6.5), Vector3(1.0, 1.8, 0.5), Color(0.5, 0.52, 0.55), "Armoire électrique", "quincaillerie", 3)
		c.set_texture("metal_peint")
	_guards(Vector3(lc.x, 0, zm + 20.0), 12, Vector2(60.0, 14.0), ["civil"], 30.0)
	_poi("Barrage et centrale", Vector3(lc.x, 0, zm), Color(0.5, 0.7, 0.95))
	_poi("Lac du Barrage", lc, Color(0.4, 0.65, 0.95))


# ---------------------------------------------------------------- manoir et cimetière
func _manoir(p: Vector3) -> void:
	var m := p + Vector3(-28.0, 0, 0)
	var man := _building(m, 22.0, 16.0, 6.6, Color(0.55, 0.5, 0.45), ["s"], "maison", "Manoir en ruine", false, 12, Color(0.4, 0.36, 0.33), "pente")
	_residents(man, 1.0, 5)
	for i in 14:   # gravats, poutres tombées
		var q := m + Vector3(rng.randf_range(-15.0, 15.0), 0, rng.randf_range(-12.0, 12.0))
		if absf(q.x - m.x) < 11.5 and absf(q.z - m.z) < 8.5:
			continue
		_box(q + Vector3(0, 0.25, 0), Vector3(rng.randf_range(0.5, 1.6), rng.randf_range(0.3, 0.7), rng.randf_range(0.5, 1.6)), Color(0.5, 0.46, 0.42), false, "brique")
	_box(m + Vector3(13.0, 1.2, -6.0), Vector3(1.2, 2.4, 1.0), Color(0.5, 0.42, 0.38), true, "brique")
	for i in 5:
		_prop(["tronc_mort", "buisson", "buisson2"][rng.randi() % 3], m + Vector3(rng.randf_range(-20.0, 20.0), 0, rng.randf_range(12.0, 18.0)), rng.randf() * TAU, false, rng.randf_range(0.8, 1.3), 160.0)
	# cimetière muré à l'est, chapelle
	var cr := Rect2(p.x + 4.0, p.z - 32.0, 52.0, 64.0)
	var pierre := Color(0.62, 0.6, 0.56)
	_box(Vector3(cr.get_center().x, 0.6, cr.position.y), Vector3(cr.size.x, 1.2, 0.4), pierre, true, "roche")
	_box(Vector3(cr.get_center().x, 0.6, cr.end.y), Vector3(cr.size.x, 1.2, 0.4), pierre, true, "roche")
	_box(Vector3(cr.end.x, 0.6, cr.get_center().y), Vector3(0.4, 1.2, cr.size.y), pierre, true, "roche")
	for sd in [-1.0, 1.0]:
		_box(Vector3(cr.position.x, 0.6, cr.get_center().y + sd * 18.0), Vector3(0.4, 1.2, cr.size.y / 2.0 - 4.0), pierre, true, "roche")
	for i in 6:
		for k in 8:
			var g := Vector3(cr.position.x + 6.0 + i * 5.0, 0, cr.position.y + 5.0 + k * 5.5)
			if i >= 4 and k < 4:
				continue
			_box(g + Vector3(0, 0.1, 0.9), Vector3(0.9, 0.2, 1.9), pierre.darkened(rng.randf_range(0.0, 0.2)), false, "roche")
			if rng.randf() < 0.75:
				_box(g + Vector3(0, 0.5, -0.1), Vector3(0.7, 1.0, 0.18), pierre.darkened(rng.randf_range(0.0, 0.25)), true, "roche")
			else:
				_box(g + Vector3(0, 0.7, -0.1), Vector3(0.12, 1.4, 0.12), Color(0.3, 0.3, 0.3), true, "metal")
				_box(g + Vector3(0, 1.05, -0.1), Vector3(0.6, 0.12, 0.12), Color(0.3, 0.3, 0.3), false, "metal")
	var cav := Vector3(cr.end.x - 8.0, 0, cr.position.y + 6.0)
	_box(cav + Vector3(0, 1.6, 0), Vector3(3.6, 3.2, 3.0), pierre.darkened(0.1), true, "roche")
	var c := _container(cav + Vector3(0, 0, 1.9), Vector3(1.2, 0.6, 0.6), pierre.darkened(0.3), "Caveau de famille", "armurerie", 2)
	c.set_texture("planches")
	var ch := _building(Vector3(cr.position.x + 30.0, 0, cr.position.y + 9.0), 8.0, 11.0, 6.0, Color(0.7, 0.65, 0.58), ["s"], "eglise", "Chapelle", false, 4, Color(0.5, 0.45, 0.4), "pente")
	_residents(ch, 0.8, 3)
	_guards(Vector3(cr.get_center().x, 0, cr.get_center().y), 16, Vector2(22.0, 26.0), ["civil"], 35.0)
	_poi("Manoir et cimetière", p, Color(0.65, 0.55, 0.7))


# ---------------------------------------------------------------- colonie de vacances
func _colonie(p: Vector3) -> void:
	var r := 42.0
	var lc := p + Vector3(0, 0, -55.0)
	_lac_special(lc, r)
	var bois := Color(0.6, 0.45, 0.3)
	for k in 6:
		var z := _building(p + Vector3(-60.0 + k * 24.0, 0, 12.0), 9.0, 6.0, 3.6, bois.lightened(rng.randf_range(0.0, 0.15)), ["n"], "maison", "Chalet" if k == 0 else "", false, 3, Color(0.55, 0.42, 0.3), "pente")
		_residents(z, 0.6, 2)
	var refe := _building(p + Vector3(-35.0, 0, 34.0), 20.0, 12.0, 4.0, bois, ["n"], "magasin", "Réfectoire de la colonie", false, 8, Color(0.55, 0.42, 0.3), "pente")
	var inf := _building(p + Vector3(5.0, 0, 34.0), 9.0, 7.0, 3.6, Color(0.85, 0.85, 0.8), ["n"], "pharmacie", "Infirmerie de la colonie", false, 4, Color(0.55, 0.42, 0.3), "pente")
	var dir := _building(p + Vector3(40.0, 0, 34.0), 11.0, 8.0, 6.6, Color(0.75, 0.68, 0.55), ["n"], "maison", "Maison du directeur", false, 6, Color(0.55, 0.42, 0.3), "pente")
	for z in [refe, inf, dir]:
		_residents(z, 0.9, 3)
	# ponton et canoës
	var rive := lc.z + r * 1.32
	_box(Vector3(lc.x, 0.14, rive - 6.0), Vector3(2.4, 0.2, 14.0), bois.darkened(0.45), true, "planches")
	_planches(Vector2(lc.x, rive + 1.0), Vector2(lc.x, rive - 13.0), 2.4, 0.26, bois)
	for t in 4:
		for sd in [-1.0, 1.0]:
			_box(Vector3(lc.x + sd * 1.1, -1.0, rive + 0.5 - t * 4.0), Vector3(0.2, 2.4, 0.2), bois.darkened(0.3), false, "planches")
	for k in 3:
		var ca := _container(Vector3(lc.x + 6.0 + k * 2.6, 0, rive + 3.0), Vector3(1.75, 0.75, 3.2), [Color(0.85, 0.3, 0.15), Color(0.2, 0.45, 0.75), Color(0.9, 0.75, 0.2)][k], "Barque", "camping", 1)
		ca.set_modele("barque" if k < 2 else "canot", 0.0)
		if ca.modele == null:
			ca.set_texture("planches")
	# bus scolaires sur le parking
	for e in [Vector3(-63.0, 0, 30.0), Vector3(62.0, 0, 28.0)]:
		_modele_ou_voiture("bus_scolaire", p + e, rng.randf_range(-0.15, 0.15), "voiture_suv", Color(0.9, 0.75, 0.15))
	# mât et foyer
	_box(p + Vector3(20.0, 4.0, 22.0), Vector3(0.15, 8.0, 0.15), Color(0.75, 0.75, 0.75), false, "metal")
	_box(p + Vector3(20.8, 7.3, 22.0), Vector3(1.4, 0.9, 0.04), Color(0.2, 0.4, 0.8), false, "uni")
	for i in 8:
		var a := TAU * i / 8.0
		_box(p + Vector3(-5.0 + cos(a) * 1.4, 0.15, 24.0 + sin(a) * 1.4), Vector3(0.4, 0.3, 0.4), Color(0.6, 0.6, 0.58), false, "roche")
	for i in 4:
		_prop("banc", p + Vector3(-5.0 + cos(i * PI / 2.0) * 4.0, 0, 24.0 + sin(i * PI / 2.0) * 4.0), i * PI / 2.0, false, 1.0, 120.0)
	_guards(p + Vector3(0, 0, 20.0), 20, Vector2(65.0, 20.0), ["civil"], 40.0)
	_poi("Colonie de vacances", p + Vector3(0, 0, 20.0), Color(0.5, 0.8, 0.6))


# ---------------------------------------------------------------- décharge
func _decharge(p: Vector3) -> void:
	_flat(Rect2(p.x - 52.0, p.z - 42.0, 104.0, 84.0), 0.012, Color(0.55, 0.5, 0.45), "terre")
	for c in [[Vector2(-52, -42), Vector2(52, -42), 0.0], [Vector2(-52, 42), Vector2(52, 42), 10.0], [Vector2(-52, -42), Vector2(-52, 42), 0.0], [Vector2(52, -42), Vector2(52, 42), 10.0]]:
		_grillage(Vector2(p.x, p.z) + c[0], Vector2(p.x, p.z) + c[1], 2.4, c[2])
	var tas := [Color(0.42, 0.38, 0.32), Color(0.38, 0.36, 0.34), Color(0.45, 0.4, 0.3)]
	for i in 7:
		var c := p + Vector3(rng.randf_range(-36.0, 30.0), 0, rng.randf_range(-28.0, 20.0))
		var rr := rng.randf_range(6.0, 10.0)
		var hh := rng.randf_range(3.0, 5.5)
		_cone(c, rr, hh, tas[i % 3], "terre", 10)
		_box(c + Vector3(0, hh * 0.3, 0), Vector3(rr * 1.1, hh * 0.6, rr * 1.1), Color.WHITE, true, "invisible")
	for i in 45:
		var q := p + Vector3(rng.randf_range(-48.0, 48.0), 0, rng.randf_range(-38.0, 38.0))
		_prop(["pneu", "carton", "baril_rouge", "baril_bleu", "palette", "poubelle", "carton"][rng.randi() % 7], q, rng.randf() * TAU, false, rng.randf_range(0.8, 1.2), 140.0)
	# bulldozer abandonné
	var bd := p + Vector3(30.0, 0, 26.0)
	var jaune := Color(0.85, 0.65, 0.12)
	if Decor.existe("bulldozer"):
		_prop("bulldozer", bd, rng.randf() * TAU, true, 1.0, 220.0)
	else:
		_box(bd + Vector3(0, 1.3, 0), Vector3(4.0, 1.6, 2.6), jaune, true, "metal")
		_box(bd + Vector3(0.6, 2.8, 0), Vector3(1.8, 1.5, 2.0), Color(0.25, 0.3, 0.35), false, "vitre")
		_box(bd + Vector3(-2.6, 0.8, 0), Vector3(0.3, 1.4, 3.2), jaune.darkened(0.3), true, "metal")
		for sd in [-1.0, 1.0]:
			_box(bd + Vector3(0, 0.45, sd * 1.4), Vector3(4.2, 0.9, 0.6), Color(0.12, 0.12, 0.12), false, "metal")
	var h := _building(p + Vector3(-38.0, 0, 32.0), 12.0, 8.0, 4.5, Color(0.55, 0.55, 0.52), ["e"], "garage", "Hangar de tri", false, 5, Color(0.45, 0.42, 0.38))
	_residents(h, 0.8, 2)
	for i in 4:
		var c := _container(p + Vector3(rng.randf_range(-30.0, 30.0), 0, rng.randf_range(22.0, 36.0)), Vector3(1.4, 0.7, 1.0), Color(0.45, 0.3, 0.2), "Tas de ferraille", "garage", 3)
		c.set_texture("metal_peint")
	_guards(p, 16, Vector2(45.0, 35.0), ["civil"], 35.0)
	_poi("Décharge", p, Color(0.6, 0.55, 0.4))


# ================================================================ nature et détails
## Avant le relief : vergers, vignes, champs de maïs (cachette), marais près de la rivière, carrière et deuxième grotte.
## Après le relief : épaves dans les fossés, feux de camp abandonnés, cachettes de survivants, nids de zombies.
var vergers: Array = []   # Rect2 : arbres fruitiers (feuillus seulement)


func _nature_plan() -> void:
	for b in [Vector3(-1850, 0, -1080), Vector3(-850, 0, 1400), Vector3(960, 0, -1200), Vector3(2100, 0, 900)]:
		var p := _libre_rect(b, Rect2(-27, -22, 54, 44), 140.0)
		if p != Vector3.INF:
			_verger(p)
	for b in [Vector3(1150, 0, 620), Vector3(-800, 0, -560)]:
		var p := _libre_rect(b, Rect2(-36, -26, 72, 52), 160.0)
		if p != Vector3.INF:
			_vignoble(p)
	for b in [Vector3(-1300, 0, -1050), Vector3(250, 0, -650), Vector3(1450, 0, 620), Vector3(-300, 0, 950)]:
		var p := _libre_rect(b, Rect2(-27, -22, 54, 44), 160.0)
		if p != Vector3.INF:
			_mais(p)
	for x in [-1250.0, 1550.0]:
		_marais(Vector3(x, 0, relief.riviere_z(x) + 48.0))
	var g := _libre_rect(Vector3(600, 0, -1350), Rect2(-26, -26, 74, 52), 80.0)
	if g != Vector3.INF:
		_grotte(g, 780.0, "Grotte des Contrebandiers")
	var q := _libre_rect(Vector3(470, 0, -1240), Rect2(-42, -36, 84, 72), 120.0)
	if q != Vector3.INF:
		_carriere(q)
		_reserve(Rect2(q.x - 42, q.z - 36, 84, 72))
		_relier(q, Rect2(-42, -36, 84, 72), 6.0, C_ASPHALT, 0.06)


func _verger(p: Vector3) -> void:
	var r := Rect2(p.x - 25.0, p.z - 20.0, 50.0, 40.0)
	vergers.append(r)
	_reserve(Rect2(p.x - 27.0, p.z - 22.0, 54.0, 44.0), Color(0.3, 0.45, 0.2, 0.6))
	var x := r.position.x + 3.0
	while x < r.end.x:
		var z := r.position.y + 3.0
		while z < r.end.y:
			trees.append(Vector3(x + rng.randf_range(-0.4, 0.4), 0, z + rng.randf_range(-0.4, 0.4)))
			z += 6.5
		x += 6.5
	var cab := _building(p + Vector3(0, 0, 25.5), 5.0, 3.5, 3.0, Color(0.6, 0.48, 0.34), ["s"], "ferme", "", false, 2, Color(0.5, 0.4, 0.3), "pente")
	_residents(cab, 0.4, 1)
	for i in 3:
		var c := _container(p + Vector3(-6.0 + i * 1.4, 0, 21.5), Vector3(0.9, 0.45, 0.6), Color(0.6, 0.45, 0.3), "Cagettes de fruits", "magasin", 1)
		c.set_texture("planches")
	_guards(p, 4, Vector2(22.0, 18.0), ["civil"], 20.0)
	_poi("Verger", p, Color(0.55, 0.75, 0.35))


func _dans_verger(p: Vector3) -> bool:
	for r in vergers:
		if (r as Rect2).grow(2.0).has_point(Vector2(p.x, p.z)):
			return true
	return false


func _vignoble(p: Vector3) -> void:
	_reserve(Rect2(p.x - 36.0, p.z - 26.0, 72.0, 52.0), Color(0.42, 0.3, 0.38, 0.6))
	_flat(Rect2(p.x - 34.0, p.z - 14.0, 68.0, 38.0), 0.012, Color(0.85, 0.78, 0.7), "terre")
	var vert := Color(0.3, 0.42, 0.18)
	var z := p.z - 12.0
	while z < p.z + 23.0:
		for s in 3:   # rangs par tronçons de 22 m (regroupement par case)
			var x0 := p.x - 33.0 + s * 22.0
			_box(Vector3(x0 + 11.0, 0.85, z), Vector3(21.0, 1.0, 0.55), vert.darkened(rng.randf_range(0.0, 0.2)), false, "herbe")
			for k in 4:
				_box(Vector3(x0 + 0.5 + k * 7.0, 0.7, z), Vector3(0.08, 1.4, 0.08), Color(0.45, 0.35, 0.25), false, "planches")
		z += 2.6
	var chai := _building(p + Vector3(-18.0, 0, -20.0), 16.0, 9.0, 4.5, Color(0.8, 0.72, 0.6), ["s"], "bar", "Domaine viticole", false, 7, Color(0.5, 0.35, 0.4), "pente")
	_residents(chai, 0.8, 3)
	for i in 4:
		_prop("baril_rouge", p + Vector3(-6.0 + i * 1.3, 0, -18.0), 0.0, true, 1.0, 120.0)
	_guards(p, 6, Vector2(30.0, 16.0), ["civil"], 25.0)
	_poi("Vignoble", p, Color(0.65, 0.4, 0.6))


## Champ de maïs haut (2 m) : on peut s'y cacher (comme dans les buissons).
func _mais(p: Vector3) -> void:
	var r := Rect2(p.x - 25.0, p.z - 20.0, 50.0, 40.0)
	_reserve(Rect2(p.x - 27.0, p.z - 22.0, 54.0, 44.0), Color(0.75, 0.68, 0.25, 0.7))
	champs.append(r)
	_flat(r, 0.012, Color(0.85, 0.78, 0.7), "terre")
	var x := r.position.x + 0.8
	while x < r.end.x:
		var z := r.position.y + 0.8
		while z < r.end.y:
			var h := rng.randf_range(1.9, 2.5)
			var c := Color(0.42, 0.5, 0.2).lerp(Color(0.62, 0.58, 0.25), rng.randf())
			_box(Vector3(x, h / 2.0, z), Vector3(0.45, h, 0.45), c, false, "herbe")
			z += 1.5
		x += 1.3
	x = r.position.x + 2.0
	while x < r.end.x:
		var z := r.position.y + 2.0
		while z < r.end.y:
			Game.ajouter_buisson(Vector3(x, 0, z), 2.3)
			z += 3.0
		x += 3.0
	_guards(p, 5, Vector2(22.0, 18.0), ["civil"], 20.0)
	_poi("Champ de maïs", p, Color(0.85, 0.8, 0.3))


## Marais : mares peu profondes, roseaux (on s'y cache), arbres morts, zombies noyés.
func _marais(c: Vector3) -> void:
	var n := 0
	var centres: Array = []
	for essai in 30:
		if n >= 6:
			break
		var rr := rng.randf_range(9.0, 15.0)
		var e := rr * 1.3 + 6.0
		var p := _libre_rect(c + Vector3(rng.randf_range(-55.0, 55.0), 0, rng.randf_range(-15.0, 35.0)), Rect2(-e, -e, 2.0 * e, 2.0 * e), 10.0)
		if p == Vector3.INF:
			continue
		lacs_speciaux.append({"c": Vector2(p.x, p.z), "r": rr, "p": [rng.randf() * TAU, rng.randf() * TAU, rng.randf() * TAU], "prof": 0.5})
		_reserve(Rect2(p.x - e, p.z - e, 2.0 * e, 2.0 * e))
		centres.append([p, rr])
		n += 1
	if centres.is_empty():
		return
	var vert := Color(0.38, 0.42, 0.22)
	for e in centres:
		var p: Vector3 = e[0]
		var rr: float = e[1]
		for i in 26:   # roseaux sur la rive
			var a := rng.randf() * TAU
			var q: Vector3 = p + Vector3(cos(a), 0, sin(a)) * rr * rng.randf_range(1.15, 1.6)
			for k in 4:
				var h := rng.randf_range(1.4, 2.2)
				_box(q + Vector3(rng.randf_range(-0.5, 0.5), h / 2.0 - 0.2, rng.randf_range(-0.5, 0.5)), Vector3(0.08, h, 0.08), vert.lerp(Color(0.6, 0.55, 0.3), rng.randf()), false, "uni")
			Game.ajouter_buisson(q, 1.4)
		for i in 2:
			var a2 := rng.randf() * TAU
			_prop(["tronc_mort", "souche"][i], p + Vector3(cos(a2), 0, sin(a2)) * rr * 1.45, rng.randf() * TAU, true, rng.randf_range(0.9, 1.3), 180.0)
	var p0: Vector3 = centres[0][0]
	_guards(p0, 9, Vector2(40.0, 25.0), ["civil"], 30.0)
	var sac := _container(p0 + Vector3(centres[0][1] * 1.5, 0, 0), Vector3(0.8, 0.4, 0.5), Color(0.3, 0.32, 0.25), "Sac d'un noyé", "maison", 2)
	sac.set_texture("planches")
	_poi("Marais", p0, Color(0.4, 0.55, 0.45))


## Carrière de pierre : fosse aux parois rocheuses, gros rochers (pioche : pierre et minerai), engins, bureau.
func _carriere(p: Vector3) -> void:
	var roche := Color(0.72, 0.7, 0.66)
	_flat(Rect2(p.x - 40.0, p.z - 34.0, 80.0, 68.0), 0.012, Color(0.85, 0.82, 0.78), "roche")
	for k in 3:   # parois en gradins au nord, à l'ouest et à l'est
		var hk := 7.0 - k * 2.2
		var ek := 3.0 + k * 3.0
		_box(Vector3(p.x, hk / 2.0, p.z - 34.0 + ek / 2.0), Vector3(80.0, hk, ek), roche.darkened(k * 0.05), true, "roche")
		for sd in [-1.0, 1.0]:
			_box(Vector3(p.x + sd * (40.0 - ek / 2.0), hk / 2.0, p.z - 6.0), Vector3(ek, hk, 56.0), roche.darkened(k * 0.05), true, "roche")
	for i in 22:
		var q := p + Vector3(rng.randf_range(-26.0, 26.0), 0, rng.randf_range(-20.0, 22.0))
		var k := rng.randf_range(1.6, 3.6)
		q.y = -k * 0.3
		_prop("rocher", q, rng.randf() * TAU, true, k, 300.0)
	# concasseur et tapis
	var jaune := Color(0.85, 0.65, 0.12)
	_box(p + Vector3(20.0, 2.0, 22.0), Vector3(5.0, 4.0, 4.0), jaune.darkened(0.2), true, "metal")
	_box(p + Vector3(10.0, 2.6, 22.0), Vector3(14.0, 0.3, 1.4), Color(0.2, 0.2, 0.2), false, "metal")
	for x in [5.0, 11.0]:
		_box(p + Vector3(x, 1.2, 22.0), Vector3(0.25, 2.4, 0.25), Color(0.4, 0.4, 0.4), false, "metal")
	_cone(p + Vector3(-12.0, 0, 24.0), 5.0, 3.5, roche.lightened(0.05), "roche", 10)
	_box(p + Vector3(-12.0, 1.0, 24.0), Vector3(5.5, 2.0, 5.5), Color.WHITE, true, "invisible")
	var bur := _building(p + Vector3(30.0, 0, 30.0), 8.0, 5.0, 3.0, Color(0.7, 0.68, 0.6), ["w"], "quincaillerie", "Bureau de la carrière", false, 4, Color(0.5, 0.48, 0.45))
	_residents(bur, 0.7, 2)
	var c := _container(p + Vector3(24.0, 0, 30.0), Vector3(1.2, 0.8, 0.8), Color(0.7, 0.2, 0.15), "Caisse d'outils", "quincaillerie", 3)
	c.set_texture("metal_peint")
	_guards(p, 8, Vector2(30.0, 25.0), ["civil"], 30.0)
	_poi("Carrière de pierre", p, Color(0.7, 0.7, 0.68))


# ---------------------------------------------------------------- après le relief
func _nature_details() -> void:
	# épaves dans les fossés des routes secondaires
	var asphalte: Array = []
	for d in drapees:
		if d[3] == C_ASPHALT and float(d[2]) >= 7.0:
			asphalte.append(d)
	var n := 0
	for essai in 120:
		if n >= 30:
			break
		var d: Array = asphalte[rng.randi() % asphalte.size()]
		var a: Vector2 = d[0]
		var b: Vector2 = d[1]
		var dir := (b - a).normalized()
		var lat := Vector2(-dir.y, dir.x) * (5.8 + rng.randf_range(0.0, 1.0)) * (1.0 if rng.randf() < 0.5 else -1.0)
		var q := a.lerp(b, rng.randf_range(0.03, 0.97)) + lat
		if relief.dans_eau(q.x, q.y) or _overlaps(Rect2(q.x - 2.6, q.y - 2.6, 5.2, 5.2)):
			continue
		var ang := (PI / 2.0 if absf(dir.x) > 0.5 else 0.0) + rng.randf_range(-0.6, 0.6) + (PI if rng.randf() < 0.5 else 0.0)
		var v := _prop(VOITURES[rng.randi() % VOITURES.size()], Vector3(q.x, relief.hauteur(q.x, q.y) - 0.25, q.y), ang, true, 1.0, 220.0)
		if v:
			v.rotation.z = rng.randf_range(-0.18, 0.18)
			Decor.peindre(v, CAR_COLORS[rng.randi() % CAR_COLORS.size()].darkened(rng.randf_range(0.35, 0.6)))
		_reserve(Rect2(q.x - 2.6, q.y - 2.6, 5.2, 5.2))
		n += 1
	for i in 14:
		var p := _point_campagne(6.0)
		if p != Vector3.INF:
			_feu_abandonne(p)
	for i in 8:
		var f: Dictionary = forets[i % forets.size()]
		for essai in 20:
			var a := rng.randf() * TAU
			var p: Vector3 = f.c + Vector3(cos(a), 0, sin(a)) * float(f.r) * rng.randf_range(0.3, 0.85)
			if _sol_libre(p, 4.0):
				_cachette(Vector3(p.x, relief.hauteur(p.x, p.z), p.z))
				break
	for i in 6:
		var p := _point_campagne(16.0)
		if p != Vector3.INF:
			_nid_zombies(p)


## Point de campagne au hasard : sec, presque plat, libre, hors des villes et loin du départ.
func _point_campagne(demi: float) -> Vector3:
	var m := Game.map_half - 120.0
	for essai in 60:
		var p := Vector3(rng.randf_range(-m, m), 0, rng.randf_range(-m, m))
		if Game.in_city(p) or p.length() < 450.0 or not _sol_libre(p, demi):
			continue
		p.y = relief.hauteur(p.x, p.z)
		return p
	return Vector3.INF


func _sol_libre(p: Vector3, demi: float) -> bool:
	if relief.dans_eau(p.x, p.z) or relief.pente(p.x, p.z) > 0.12:
		return false
	for o in [Vector2(-demi, -demi), Vector2(demi, demi), Vector2(-demi, demi), Vector2(demi, -demi)]:
		if relief.dans_eau(p.x + o.x, p.z + o.y) or absf(relief.hauteur(p.x + o.x, p.z + o.y) - relief.hauteur(p.x, p.z)) > 1.5:
			return false
	return not _overlaps(Rect2(p.x - demi, p.z - demi, 2.0 * demi, 2.0 * demi))


## Feu de camp de survivants abandonné : foyer éteint, tente, couchage, sac à fouiller.
func _feu_abandonne(p: Vector3) -> void:
	for i in 7:
		var a := TAU * i / 7.0
		_box(p + Vector3(cos(a) * 0.8, 0.1, sin(a) * 0.8), Vector3(0.35, 0.25, 0.35), Color(0.55, 0.55, 0.52), false, "roche")
	for i in 3:
		_box(p + Vector3(0, 0.1, 0), Vector3(1.0, 0.12, 0.15) if i % 2 == 0 else Vector3(0.15, 0.12, 1.0), Color(0.1, 0.08, 0.07), false, "planches")
	var u := Vector3(1, 0, 0)
	var v := Vector3(0, 0, 1)
	_tente(p + Vector3(3.5, 0, 0), u, v, [Color(0.25, 0.4, 0.3), Color(0.55, 0.35, 0.2), Color(0.3, 0.35, 0.5)][rng.randi() % 3])
	_box(p + Vector3(-1.5, 0.08, 2.4), Vector3(0.8, 0.16, 1.9), Color(0.3, 0.35, 0.45), false, "uni")
	var s := _container(p + Vector3(-2.2, 0, -1.6), Vector3(0.6, 0.5, 0.4), Color(0.35, 0.33, 0.25), "Sac abandonné", "camping", 2)
	s.set_texture("planches")
	_reserve(Rect2(p.x - 6.0, p.z - 6.0, 12.0, 12.0))
	for i in rng.randi_range(1, 3):
		guards.append({"pos": p + Vector3(rng.randf_range(-8.0, 8.0), 0.1, rng.randf_range(-8.0, 8.0)), "kind": "civil", "radius": 12.0})
	_poi("Feu de camp abandonné", p, Color(0.9, 0.6, 0.3))


## Cachette de survivant (pas sur la carte) : abri bas camouflé sous une bâche, bon butin.
func _cachette(p: Vector3) -> void:
	var bache := Color(0.25, 0.32, 0.2)
	for sx in [-1.0, 1.0]:
		_box(p + Vector3(sx * 1.4, 0.6, 0), Vector3(0.15, 1.2, 2.6), Color(0.45, 0.35, 0.25), true, "planches")
	_box(p + Vector3(0, 0.6, -1.3), Vector3(2.9, 1.2, 0.15), Color(0.45, 0.35, 0.25), true, "planches")
	_box(p + Vector3(0, 1.3, 0), Vector3(3.6, 0.1, 3.4), bache, false, "uni")
	_prop("buisson", p + Vector3(2.4, 0, 1.0), rng.randf() * TAU, false, 1.1, 150.0)
	_prop("buisson2", p + Vector3(-2.2, 0, 1.4), rng.randf() * TAU, false, 1.0, 150.0)
	var c := _container(p + Vector3(0, 0, -0.5), Vector3(1.2, 0.7, 0.7), Color(0.3, 0.33, 0.25), "Cachette de survivant", "cachette", 4)
	c.set_texture("metal_peint")
	_reserve(Rect2(p.x - 4.0, p.z - 4.0, 8.0, 8.0))


## Nid de zombies : charnier, barricade effondrée, horde (zone infestée sur la carte).
func _nid_zombies(p: Vector3) -> void:
	var sang := Color(0.3, 0.06, 0.05)
	for i in 6:
		var q := p + Vector3(rng.randf_range(-8.0, 8.0), 0, rng.randf_range(-8.0, 8.0))
		q.y = relief.hauteur(q.x, q.z)
		_box(q + Vector3(0, 0.03, 0), Vector3(rng.randf_range(2.0, 4.0), 0.04, rng.randf_range(2.0, 4.0)), sang, false, "terre")
	for i in 10:
		var q := p + Vector3(rng.randf_range(-7.0, 7.0), 0, rng.randf_range(-7.0, 7.0))
		q.y = relief.hauteur(q.x, q.z)
		if i % 3 == 0:
			_box(q + Vector3(0, 0.2, 0), Vector3(0.6, 0.4, 1.8), Color(0.12, 0.13, 0.12), false, "uni")   # housse mortuaire
		else:
			_box(q + Vector3(0, 0.06, 0), Vector3(0.5, 0.08, 0.1), Color(0.85, 0.82, 0.75), false, "uni")   # os
	for i in 5:
		var q := p + Vector3(rng.randf_range(-12.0, 12.0), 0, rng.randf_range(-12.0, 12.0))
		q.y = relief.hauteur(q.x, q.z)
		_prop(["palette", "pneu", "baril_rouge", "caisse_bois", "tronc_mort"][i], q, rng.randf() * TAU, false, 1.0, 140.0)
	var c := _container(p + Vector3(2.0, 0, 1.0), Vector3(0.8, 0.5, 0.5), Color(0.35, 0.3, 0.25), "Restes d'un survivant", "infeste", 3)
	c.set_texture("planches")
	_reserve(Rect2(p.x - 16.0, p.z - 16.0, 32.0, 32.0))
	for i in 28:
		var q := p + Vector3(rng.randf_range(-14.0, 14.0), 0, rng.randf_range(-14.0, 14.0))
		q.y = relief.hauteur(q.x, q.z) + 0.1
		guards.append({"pos": q, "kind": ["civil", "civil", "civil", "police", "militaire"][rng.randi() % 5], "radius": 28.0})
	_poi("Nid de zombies (zone infestée)", p, Color(1.0, 0.25, 0.2))
	Game.map_rects.append({"rect": Rect2(p.x - 25.0, p.z - 25.0, 50.0, 50.0), "color": Color(0.8, 0.1, 0.1, 0.25)})


## Platelage d'un ponton : planches en travers (avec jours) posées sur le caisson, de p0 à p1 (plan XZ).
func _planches(p0: Vector2, p1: Vector2, larg: float, pas: float, bois: Color) -> void:
	var d := p1 - p0
	var long := d.length()
	var le_long_x := absf(d.x) > absf(d.y)
	var nb := int(long / pas)
	for i in nb:
		var q := p0.lerp(p1, (i + 0.5) / nb)
		var taille := Vector3(pas - 0.04, 0.05, larg) if le_long_x else Vector3(larg, 0.05, pas - 0.04)
		var teinte := bois * (0.9 + 0.2 * float((i * 7) % 5) / 4.0)
		teinte.a = 1.0
		_box(Vector3(q.x, 0.265, q.y), taille, teinte, false, "planches")

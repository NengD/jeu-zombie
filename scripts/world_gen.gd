extends Node3D
## Génère le monde : ville (majoritaire), campagne, points stratégiques,
## meubles fouillables et zombies gardiens.
## Toute la géométrie statique est regroupée par « chunks » pour les performances.
## Pour remplacer plus tard par des modèles Blender : remplacer les appels à
## _building() / _car() / arbres par des instances de scènes .glb.

const LootContainer = preload("res://scripts/loot_container.gd")

const BLOCK := 46.0      # taille d'un pâté de maisons (route comprise)
const ROAD := 10.0       # largeur des routes
const NB := 7            # nombre de pâtés par côté
const CHUNK := 64.0
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

# [nom, taille (long. le long du mur, hauteur, profondeur), couleur]
const FURN := {
	"maison": [["Armoire", Vector3(1.2, 2.0, 0.6), Color(0.4, 0.28, 0.18)], ["Commode", Vector3(1.0, 0.9, 0.5), Color(0.45, 0.32, 0.2)], ["Placard de cuisine", Vector3(1.8, 0.95, 0.6), Color(0.75, 0.73, 0.68)], ["Réfrigérateur", Vector3(0.8, 1.9, 0.7), Color(0.85, 0.85, 0.82)]],
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
	"Coffre": ["caisse_mil"],
}

var rng := RandomNumberGenerator.new()
var sts := {}         # "chunk|matériau" -> SurfaceTool
var bodies := {}      # chunk -> StaticBody3D
var mat: StandardMaterial3D
var mats := {}        # nom -> matériau
var cur_mat := "uni"  # matériau utilisé par _box() quand aucun n'est précisé
var decor: Node3D     # objets de décor (modèles 3D)
var reserved: Array = []   # Rect2 occupés (pour placer les arbres)
var guards: Array = []     # zombies à placer : {pos, kind, radius}
var trees: Array = []      # Vector3
var spawn_point := Vector3.ZERO
var spawn_zone: Dictionary = {}
var half := 0.0


func build(seed_value: int) -> Vector3:
	rng.seed = seed_value
	half = NB * BLOCK / 2.0
	Game.city_half = half
	mat = StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.vertex_color_is_srgb = true
	mat.roughness = 0.92
	_creer_materiaux()
	decor = Node3D.new()
	decor.name = "Decor"
	add_child(decor)
	_ground()
	_city()
	_countryside()
	_military_base(Vector3(-255, 0, -250))
	_trees()
	_vegetation()
	_commit()
	return spawn_point


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
	var size := Game.map_half * 2.0 + 300.0
	var mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(size, size)
	mi.mesh = pm
	var gm: StandardMaterial3D = mats["herbe"].duplicate()
	gm.vertex_color_use_as_albedo = false
	gm.albedo_color = Color(0.85, 0.85, 0.8)
	gm.uv1_scale = Vector3(size / 3.0, size / 3.0, 1.0)
	mi.material_override = gm
	add_child(mi)
	var body := StaticBody3D.new()
	body.collision_layer = Game.LAYER_WORLD
	var cs := CollisionShape3D.new()
	cs.shape = WorldBoundaryShape3D.new()
	body.add_child(cs)
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
	# sol bétonné de la ville
	_flat(Rect2(-half - 8, -half - 8, 2 * half + 16, 2 * half + 16), 0.006, Color(0.85, 0.85, 0.83), "trottoir")
	Game.map_rects.append({"rect": Rect2(-half - 8, -half - 8, 2 * half + 16, 2 * half + 16), "color": Color(0.22, 0.22, 0.22)})


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
func _mobilier_urbain() -> void:
	if not Decor.existe("poubelle"):
		return
	var total := 0
	for m in MOBILIER:
		total += m[1]
	for i in NB + 1:
		var c := -half + i * BLOCK
		for j in NB:
			var a0 := -half + j * BLOCK + ROAD / 2.0 + 2.5
			var a1 := -half + (j + 1) * BLOCK - ROAD / 2.0 - 2.5
			for sd in [-1.0, 1.0]:
				if (i == 0 and sd < 0) or (i == NB and sd > 0):
					continue
				var o: float = c + sd * (ROAD / 2.0 + 0.7)
				for along_x in [true, false]:
					var nb := rng.randi_range(1, 4)
					for q in nb:
						var a := rng.randf_range(a0, a1)
						var r := rng.randi() % total
						var choix: Array = MOBILIER[0]
						for m in MOBILIER:
							r -= m[1]
							if r < 0:
								choix = m
								break
						var pos := Vector3(a, 0.0, o) if along_x else Vector3(o, 0.0, a)
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
				_prop("plaque_egout", Vector3(a, 0.02, c + rng.randf_range(-2.0, 2.0)), 0.0, false, 1.0, 60.0)
	# barrages abandonnés à quelques carrefours
	for n in 10:
		var i := rng.randi_range(1, NB - 1)
		var j := rng.randi_range(1, NB - 1)
		var p := Vector3(-half + i * BLOCK, 0, -half + j * BLOCK + (BLOCK / 2.0 - 6.0) * (1.0 if rng.randf() < 0.5 else -1.0))
		if rng.randf() < 0.5:
			p = Vector3(p.z, 0, p.x)
		var le_long_x := absf(fposmod(p.x + half, BLOCK)) < 1.0
		for k in 4:
			var off := (k - 1.5) * 1.7 + rng.randf_range(-0.2, 0.2)
			var pos := p + (Vector3(off, 0, 0) if le_long_x else Vector3(0, 0, off))
			var id := "glissiere" if rng.randf() < 0.6 else "barriere_beton"
			var ang := (0.0 if le_long_x else PI / 2.0) + rng.randf_range(-0.25, 0.25)
			if id == "glissiere":
				ang += PI / 2.0
			_prop(id, pos, ang, true, 1.0, 150.0)
		for k in 3:
			_prop("cone", p + Vector3(rng.randf_range(-4, 4), 0, rng.randf_range(-4, 4)), rng.randf() * TAU, false, 1.0, 80.0)


const VOITURES := ["voiture1", "voiture2", "voiture_suv", "voiture_taxi", "voiture_sport", "voiture1", "voiture2"]


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
	return n


func _car(c: Vector3, along_x: bool, col: Color, id := "") -> void:
	if Decor.existe("voiture1"):
		if id == "":
			id = VOITURES[rng.randi() % VOITURES.size()]
		var ang := (PI / 2.0 if along_x else 0.0) + (PI if rng.randf() < 0.5 else 0.0) + rng.randf_range(-0.2, 0.2)
		var v := _prop(id, c, ang, true, 1.0, 220.0)
		if v and id != "voiture_police" and id != "voiture_taxi":
			Decor.peindre(v, col)
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
func _building(c: Vector3, w: float, d: float, h: float, col: Color, doors: Array, kind: String, label := "", partition := false, furn := -1, map_col := Color(0.5, 0.5, 0.5)) -> Dictionary:
	var t := WALL_T
	var x0 := c.x - w / 2.0
	var x1 := c.x + w / 2.0
	var z0 := c.z - d / 2.0
	var z1 := c.z + d / 2.0
	h = maxf(h, INT_H + 0.3)
	# revêtements : façade selon le type de bâtiment, sol intérieur selon l'usage
	var facade := _facade(kind, h)
	var col_f := col
	if facade == "brique":
		col_f = Color(1, 1, 1).lerp(col, 0.25).lightened(0.1)
	elif facade == "parpaing" or facade == "planches":
		col_f = col.lightened(0.35)
	else:
		col_f = col.lightened(0.2)
	col = col_f
	var sol := "parquet"
	if kind in ["magasin", "hopital", "station", "bureau", "police", "armurerie"]:
		sol = "carrelage"
	elif kind in ["militaire", "armurerie_mil", "grange", "quincaillerie"]:
		sol = "beton"
	_box(Vector3(c.x, 0.015, c.z), Vector3(w - 0.1, 0.03, d - 0.1), Color(0.9, 0.88, 0.85) if sol != "parquet" else Color(1, 1, 1), false, sol)
	var mat_avant := cur_mat
	cur_mat = facade
	var door_list: Array = []
	var outward := {"n": Vector3(0, 0, -1), "s": Vector3(0, 0, 1), "w": Vector3(-1, 0, 0), "e": Vector3(1, 0, 0)}
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
		if has_door:
			var spread := maxf(0.0, (a1 - a0) / 2.0 - 2.5)
			if partition and not along_x:
				dc = c.z + (d / 4.0) * (1.0 if rng.randf() < 0.5 else -1.0)
			else:
				dc += rng.randf_range(-spread, spread) * 0.5
			var dp := Vector3(dc, 0, fixed) if along_x else Vector3(fixed, 0, dc)
			var o: Vector3 = outward[side]
			door_list.append({"pos": dp, "out": dp + o * 1.5, "inn": dp - o * 1.5})
			_wall(along_x, fixed, a0, dc - DOOR_W / 2.0, 0.0, INT_H, col)
			_wall(along_x, fixed, dc + DOOR_W / 2.0, a1, 0.0, INT_H, col)
			_wall(along_x, fixed, dc - DOOR_W / 2.0, dc + DOOR_W / 2.0, DOOR_H, INT_H, col.darkened(0.2))
		else:
			_wall(along_x, fixed, a0, a1, 0.0, INT_H, col)
		# fenêtres (cadre, vitre, appui), soubassement, bandeaux d'étage
		var sgn: float = outward[side].z if along_x else outward[side].x
		var face: float = fixed + sgn * (t / 2.0)
		_bande(along_x, face, sgn, a0 - (t if not along_x else 0.0), a1 + (t if not along_x else 0.0), 0.0, 0.45, 0.04, Color(0.7, 0.7, 0.68), "beton", has_door, dc)
		var y := 1.1
		var etage := 0
		while y + 1.0 < h:
			if etage > 0:
				_bande(along_x, face, sgn, a0, a1, y - 0.55, y - 0.3, 0.05, Color(0.78, 0.77, 0.74), "beton", false, 0.0)
			var a := a0 + 2.0
			while a < a1 - 2.0:
				var skip := has_door and y < INT_H and absf(a - dc) < 2.0
				if not skip:
					_fenetre(along_x, face, sgn, a, y, kind)
				a += 3.6
			y += 3.4 if y < INT_H else 3.2
			etage += 1
	# plafond + étages (volume plein au-dessus du rez-de-chaussée)
	_box(Vector3(c.x, INT_H + 0.15, c.z), Vector3(w, 0.3, d), Color(0.85, 0.84, 0.8), true, "enduit")
	if h > INT_H + 0.6:
		_box(Vector3(c.x, (INT_H + 0.3 + h) / 2.0, c.z), Vector3(w, h - INT_H - 0.3, d), col)
	# toit-terrasse gravillonné + acrotère
	_box(Vector3(c.x, h + 0.02, c.z), Vector3(w - 0.4, 0.04, d - 0.4), Color(0.9, 0.9, 0.9), false, "toit")
	for e in [[Vector3(c.x, h + 0.3, z0 + 0.15), Vector3(w + 0.2, 0.6, 0.3)], [Vector3(c.x, h + 0.3, z1 - 0.15), Vector3(w + 0.2, 0.6, 0.3)],
			[Vector3(x0 + 0.15, h + 0.3, c.z), Vector3(0.3, 0.6, d)], [Vector3(x1 - 0.15, h + 0.3, c.z), Vector3(0.3, 0.6, d)]]:
		_box(e[0], e[1], Color(0.75, 0.74, 0.7), false, "beton")
	# cloison intérieure
	var placed: Array = []
	cur_mat = "enduit"
	if partition and d >= 12.0:
		var gx := rng.randf_range(x0 + 2.5, x1 - 2.5)
		_wall(true, c.z, x0 + t, gx - 1.0, 0.0, INT_H, col.lightened(0.15))
		_wall(true, c.z, gx + 1.0, x1 - t, 0.0, INT_H, col.lightened(0.15))
		placed.append(Rect2(x0, c.z - 0.5, gx - 1.3 - x0, 1.0))
		placed.append(Rect2(gx + 1.3, c.z - 0.5, x1 - gx - 1.3, 1.0))
		placed.append(Rect2(gx - 1.5, c.z - 2.0, 3.0, 4.0))  # garder le passage libre
	cur_mat = mat_avant
	var zone := {
		"aabb": AABB(Vector3(x0 + t, 0.0, z0 + t), Vector3(w - 2 * t, INT_H, d - 2 * t)),
		"doors": door_list, "kind": kind, "name": label, "center": c,
	}
	Game.zones.append(zone)
	_reserve(Rect2(x0 - 1.0, z0 - 1.0, w + 2.0, d + 2.0))
	Game.map_rects.append({"rect": Rect2(x0, z0, w, d), "color": map_col})
	if furn < 0:
		furn = clampi(int(w * d / 28.0), 2, 12)
	_furnish(zone, kind, furn, placed)
	return zone


const CADRES := [Color(0.92, 0.92, 0.9), Color(0.25, 0.25, 0.26), Color(0.35, 0.24, 0.16), Color(0.6, 0.6, 0.6)]


## Revêtement de façade selon le type de bâtiment.
func _facade(kind: String, h: float) -> String:
	match kind:
		"militaire", "armurerie_mil":
			return "parpaing"
		"grange":
			return "planches"
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
	if r < 0.07:
		_sur_facade(along_x, face, sgn, a, yc, 0.065, larg, haut, 0.02, Color(0.03, 0.03, 0.035), "uni")   # vitre brisée
	else:
		var teinte := Color(0.62, 0.68, 0.74).darkened(rng.randf_range(0.0, 0.3))
		_sur_facade(along_x, face, sgn, a, yc, 0.065, larg, haut, 0.02, teinte, "vitre")
	if larg < 2.0:
		_sur_facade(along_x, face, sgn, a, yc, 0.085, 0.05, haut, 0.03, cadre, "uni")
	_sur_facade(along_x, face, sgn, a, y0 - 0.04, 0.08, larg + 0.25, 0.07, 0.16, Color(0.8, 0.79, 0.76), "beton")
	if r > 0.9 and y < INT_H:
		# planches clouées
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
		var cont := _container(pos, size3, f[2], f[0], kind)
		var choix: Array = MODELES_MEUBLES.get(f[0], [])
		if not choix.is_empty():
			var ang: float = {"n": 0.0, "s": PI, "w": PI / 2.0, "e": -PI / 2.0}[side]
			cont.set_modele(choix[rng.randi() % choix.size()], ang)
		else:
			cont.set_texture("metal_peint")
		n += 1


func _container(pos: Vector3, size: Vector3, col: Color, label: String, table: String, rolls := -1) -> LootContainer:
	var c = LootContainer.new()
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
	return Vector3(rng.randf_range(ab.position.x + margin, ab.end.x - margin), 0.1, rng.randf_range(ab.position.z + margin, ab.end.z - margin))


func _poi(label: String, pos: Vector3, col: Color) -> void:
	Game.pois.append({"name": label, "pos": pos, "color": col})


# ================================================================ ville
func _city() -> void:
	for i in NB + 1:
		var c := -half + i * BLOCK
		_road(Vector2(c, -half - 5), Vector2(c, half + 5), ROAD)
		_road(Vector2(-half - 5, c), Vector2(half + 5, c), ROAD)
	# bordures de trottoir entre les carrefours
	for i in NB + 1:
		var c := -half + i * BLOCK
		for j in NB:
			var a0 := -half + j * BLOCK + ROAD / 2.0
			var a1 := -half + (j + 1) * BLOCK - ROAD / 2.0
			var mid := (a0 + a1) / 2.0
			for sd in [-1.0, 1.0]:
				var o: float = c + sd * (ROAD / 2.0 - 0.12)
				_box(Vector3(mid, 0.07, o), Vector3(a1 - a0, 0.14, 0.24), Color(0.8, 0.8, 0.78), false, "beton")
				_box(Vector3(o, 0.07, mid), Vector3(0.24, 0.14, a1 - a0), Color(0.8, 0.8, 0.78), false, "beton")
	# lampadaires éteints aux carrefours
	for i in NB + 1:
		for j in NB + 1:
			var p := Vector3(-half + i * BLOCK + 6.0, 0, -half + j * BLOCK + 6.0)
			if Decor.existe("lampadaire"):
				_prop("lampadaire", p, rng.randf() * TAU, false, 1.0, 200.0)
				_box(p + Vector3(0, 2.0, 0), Vector3(0.2, 4.0, 0.2), Color.WHITE, true, "invisible")
			else:
				_box(p + Vector3(0, 3.0, 0), Vector3(0.18, 6.0, 0.18), Color(0.2, 0.2, 0.22))
				_box(p + Vector3(-0.6, 6.0, 0), Vector3(1.4, 0.15, 0.3), Color(0.2, 0.2, 0.22), false)
	var specials := {
		Vector2i(2, 2): "police", Vector2i(4, 4): "hopital", Vector2i(4, 2): "supermarche",
		Vector2i(2, 4): "armurerie", Vector2i(1, 3): "quincaillerie", Vector2i(3, 3): "parc",
		Vector2i(5, 1): "parc",
	}
	var spawn_block := Vector2i(1, NB - 1)
	for bi in NB:
		for bj in NB:
			var bc := Vector3(-half + (bi + 0.5) * BLOCK, 0, -half + (bj + 0.5) * BLOCK)
			var key := Vector2i(bi, bj)
			var outer := bi == 0 or bj == 0 or bi == NB - 1 or bj == NB - 1
			if specials.has(key):
				match specials[key]:
					"police": _police(bc)
					"hopital": _hospital(bc)
					"supermarche": _supermarket(bc)
					"armurerie": _small_special(bc, "armurerie", "Armurerie", Color(0.3, 0.28, 0.27), Color(0.75, 0.3, 0.2))
					"quincaillerie": _small_special(bc, "quincaillerie", "Quincaillerie", Color(0.55, 0.45, 0.3), Color(0.8, 0.6, 0.2))
					"parc": _park(bc)
			elif outer:
				_residential(bc, key == spawn_block)
			elif rng.randf() < 0.35:
				_apartments(bc)
			else:
				_commercial(bc)
	# voitures abandonnées
	for n in 55:
		var i := rng.randi_range(0, NB)
		var along := rng.randf_range(-half, half)
		var line := -half + i * BLOCK
		if fposmod(along + half, BLOCK) < 9.0 or fposmod(along + half, BLOCK) > BLOCK - 9.0:
			continue
		var lane := 2.4 * (1.0 if rng.randf() < 0.5 else -1.0)
		var col: Color = CAR_COLORS[rng.randi() % CAR_COLORS.size()].darkened(rng.randf_range(0.0, 0.35))
		if rng.randf() < 0.5:
			_car(Vector3(along, 0, line + lane), true, col)
		else:
			_car(Vector3(line + lane, 0, along), false, col)
	_mobilier_urbain()


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
			var z := _building(c, w, d, h, col, doors, "maison", "", false, -1, Color(0.45, 0.4, 0.35))
			if is_spawn and first:
				spawn_zone = z
				var dr: Dictionary = z.doors[0]
				spawn_point = dr.out + (dr.out - dr.pos).normalized() * 1.0
				first = false
			else:
				_residents(z, 0.4, 2)
			# petit muret de jardin
			if rng.randf() < 0.5:
				var gx: float = bc.x + qx * 17.0
				_box(Vector3(gx, 0.4, bc.z + qz * 8.5), Vector3(0.25, 0.8, 14.0), Color(0.85, 0.84, 0.8), true, "beton")
	_reserve(Rect2(bc.x - 18, bc.z - 18, 36, 36))


func _commercial(bc: Vector3) -> void:
	for sx in [-1.0, 1.0]:
		var w := rng.randf_range(13.0, 16.0)
		var d := rng.randf_range(26.0, 33.0)
		var h := rng.randf_range(7.0, 16.0)
		var col: Color = CITY_COLORS[rng.randi() % CITY_COLORS.size()]
		var kind: String = ["magasin", "bureau", "maison", "magasin"][rng.randi() % 4]
		var doors := ["e" if sx > 0 else "w"]
		if rng.randf() < 0.5:
			doors.append("s" if rng.randf() < 0.5 else "n")
		var z := _building(bc + Vector3(sx * 9.5, 0, 0), w, d, h, col, doors, kind, "", true, -1, Color(0.5, 0.5, 0.5))
		_residents(z, 0.55, 3)


func _apartments(bc: Vector3) -> void:
	var w := rng.randf_range(26.0, 32.0)
	var d := rng.randf_range(26.0, 32.0)
	var col: Color = CITY_COLORS[rng.randi() % CITY_COLORS.size()]
	var z := _building(bc, w, d, rng.randf_range(14.0, 26.0), col, ["n", "s"], "maison", "", true, 12, Color(0.47, 0.47, 0.5))
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


func _small_special(bc: Vector3, kind: String, label: String, col: Color, map_col: Color) -> void:
	var z := _building(bc + Vector3(-8.0, 0, -8.0), 15.0, 12.0, 4.5, col, ["n", "w"], kind, label, false, 8, map_col)
	_poi(label, bc + Vector3(-8.0, 0, -8.0), map_col)
	for i in 3:
		guards.append({"pos": _random_in(z, 1.0), "kind": "civil", "radius": 5.0})
	# maisons sur le reste du pâté
	for q in [Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
		var c := bc + Vector3(q.x * 8.5, 0, q.y * 8.5)
		var hz := _building(c, rng.randf_range(9, 12), rng.randf_range(8, 11), 6.6, HOUSE_COLORS[rng.randi() % HOUSE_COLORS.size()], _doors_toward_roads(q.x, q.y), "maison", "", false, -1, Color(0.45, 0.4, 0.35))
		_residents(hz, 0.4, 2)


# ================================================================ campagne
func _countryside() -> void:
	var hx := -half + 4 * BLOCK   # autoroute nord-sud
	var hz := -half + 3 * BLOCK   # autoroute est-ouest
	var m := Game.map_half
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


func _overlaps(r: Rect2) -> bool:
	for o in reserved:
		if o.intersects(r):
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
	var barn := _building(c + Vector3(20, 0, -2), 16.0, 20.0, 8.0, Color(0.5, 0.18, 0.13), ["w", "e"], "grange", "Grange", false, 7, Color(0.6, 0.25, 0.2))
	_residents(house, 0.7, 2)
	_residents(barn, 0.8, 3)
	_poi(label, c, Color(0.85, 0.6, 0.35))
	# champs et clôtures
	for i in 4:
		var dir := signf(c.z)
		var fc := c + Vector3(-30.0 + (i % 2) * 48.0, 0, dir * (30.0 + floorf(i / 2.0) * 34.0))
		var r := Rect2(fc.x - 20, fc.z - 15, 40, 30)
		if _overlaps(r):
			continue
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
	_car(c + Vector3(30, 0, 5), false, Color(0.28, 0.32, 0.2), "voiture_suv")
	_car(c + Vector3(36, 0, 8), false, Color(0.28, 0.32, 0.2), "voiture_suv")
	_car(c + Vector3(-10, 0, -5), true, Color(0.28, 0.32, 0.2), "voiture_suv")
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
	for i in 14:
		centers.append(Vector3(rng.randf_range(-m, m), 0, rng.randf_range(-m, m)))
	var candidates := trees.duplicate()
	for cc in centers:
		for i in 45:
			candidates.append(cc + Vector3(rng.randfn(0, 22), 0, rng.randfn(0, 22)))
	for i in 250:
		candidates.append(Vector3(rng.randf_range(-m, m), 0, rng.randf_range(-m, m)))
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
		final.append(p)
	trees = final
	var body := StaticBody3D.new()
	body.collision_layer = Game.LAYER_WORLD
	add_child(body)
	var feuillus := ["arbre_0", "arbre_1", "arbre_2", "arbre_3"]
	var sapins := ["sapin_0", "sapin_1"]
	var modeles_ok := ResourceLoader.exists("res://modeles/arbres/arbre_0.res")
	# regroupement par variante et par zone de 128 m (chaque groupe est masqué hors du champ de vision)
	var groupes := {}
	for i in trees.size():
		var p: Vector3 = trees[i]
		var s := rng.randf_range(0.8, 1.3)
		var en_ville := absf(p.x) < half + 10 and absf(p.z) < half + 10
		var id: String = feuillus[rng.randi() % feuillus.size()] if (en_ville or rng.randf() < 0.65) else sapins[rng.randi() % sapins.size()]
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
		body.add_child(cs)
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


## Buissons, rochers, souches et troncs morts dans la campagne ; buissons dans les jardins.
func _vegetation() -> void:
	if not Decor.existe("buisson"):
		return
	var m := Game.map_half - 15.0
	var choix := [["buisson", false], ["buisson2", false], ["rocher", true], ["souche", true], ["tronc_mort", true], ["buisson", false]]
	for i in 260:
		var p := Vector3(rng.randf_range(-m, m), 0, rng.randf_range(-m, m))
		if absf(p.x) < half + 12 and absf(p.z) < half + 12:
			continue
		if _overlaps(Rect2(p.x - 2, p.z - 2, 4, 4)):
			continue
		var c: Array = choix[rng.randi() % choix.size()]
		_prop(c[0], p, rng.randf() * TAU, c[1], rng.randf_range(0.7, 1.3), 220.0)
	# buissons dans les parcs et le long des maisons
	for t in trees:
		if absf(t.x) < half and absf(t.z) < half and rng.randf() < 0.6:
			_prop("buisson" if rng.randf() < 0.5 else "buisson2", t + Vector3(rng.randf_range(-3, 3), 0, rng.randf_range(-3, 3)), rng.randf() * TAU, false, rng.randf_range(0.6, 1.0), 150.0)

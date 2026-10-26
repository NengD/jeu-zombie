class_name Perso
extends RefCounted

const ModeleUtil = preload("res://scripts/modele_util.gd")
## Création des personnages (survivant, zombies) à partir des modèles générés par
## outils/godot/generer_persos.gd. L'apparence (peau, vêtements, coiffure, sang…) passe par
## les paramètres d'instance du shader perso.gdshader.

const PEAUX := [Color(0.93, 0.76, 0.64), Color(0.85, 0.66, 0.52), Color(0.72, 0.53, 0.39),
		Color(0.55, 0.38, 0.26), Color(0.38, 0.26, 0.18), Color(0.96, 0.82, 0.72)]
const CHEVEUX := [Color(0.08, 0.06, 0.05), Color(0.18, 0.12, 0.07), Color(0.32, 0.21, 0.12),
		Color(0.55, 0.42, 0.25), Color(0.62, 0.55, 0.45), Color(0.35, 0.33, 0.32)]
const HAUTS := [Color(0.55, 0.12, 0.12), Color(0.18, 0.28, 0.45), Color(0.82, 0.80, 0.76),
		Color(0.25, 0.35, 0.22), Color(0.12, 0.12, 0.13), Color(0.62, 0.52, 0.30), Color(0.40, 0.42, 0.46),
		Color(0.70, 0.45, 0.18), Color(0.35, 0.20, 0.35)]
const BAS := [Color(0.16, 0.22, 0.34), Color(0.12, 0.15, 0.22), Color(0.28, 0.33, 0.42),
		Color(0.30, 0.26, 0.20), Color(0.10, 0.10, 0.10), Color(0.45, 0.40, 0.30)]
const CHAUSSURES := [Color(0.10, 0.09, 0.08), Color(0.35, 0.22, 0.12), Color(0.85, 0.85, 0.85), Color(0.25, 0.25, 0.28)]
const COIFFURES_H := ["cheveux_simple_parted", "cheveux_buzzed", "", "cheveux_simple_parted"]
const COIFFURES_F := ["cheveux_long", "cheveux_buns", "cheveux_buzzed_female", "cheveux_long"]

static var _scenes := {}

# ---------------------------------------------------------------- personnages low-poly (Quaternius)
## Modèles par type de personnage (outils/godot/generer_persos_modulaires.gd -> modeles/persos_mod/).
const MOD := "res://modeles/persos_mod/%s.scn"
const MODELES := {
	"survivant": ["h_adventurer"],
	"vendeur": ["h_worker", "h_farmer", "f_worker", "h_suit", "f_adventurer"],
	"bandit": ["h_punk", "h_casual_hoodie", "h_farmer", "f_punk", "f_adventurer", "h_adventurer"],
	"garde": ["h_swat", "f_soldier", "h_adventurer", "h_worker"],
	"civil": ["h_casual_2", "h_casual_hoodie", "h_beach", "h_farmer", "h_worker", "h_suit", "h_punk",
			"f_casual", "f_formal", "f_punk", "f_worker", "f_suit", "f_adventurer"],
	"police": ["h_swat", "h_suit"],
	"militaire": ["h_swat", "f_soldier"],
	"patient": ["h_beach", "f_casual"],
	"boss": ["h_worker"],
}
const PEAU_ZOMBIE := [Color(0.6, 0.62, 0.57), Color(0.53, 0.56, 0.53), Color(0.64, 0.62, 0.58), Color(0.5, 0.54, 0.5)]   # gris cendre, à peine verdâtre
static var _mats := {}   # matériaux recolorés, partagés (clé = matériau + couleur)


static func modulaires() -> bool:
	return ResourceLoader.exists(MOD % "h_adventurer")


static func _scene(sexe: String) -> PackedScene:
	if not _scenes.has(sexe):
		var p := "res://modeles/persos/%s.scn" % sexe
		_scenes[sexe] = load(p) if ResourceLoader.exists(p) else null
	return _scenes[sexe]


static func disponible() -> bool:
	return modulaires() or _scene("homme") != null


## Personnage low-poly : modèle selon le type, peau, cheveux et vêtements recolorés.
static func _creer_modulaire(a: Dictionary) -> Node3D:
	var liste: Array = MODELES.get(a.get("type", "civil"), MODELES.civil)
	if a.get("type", "") in ["coureur", "gros", "rampant"]:
		liste = MODELES.civil
	var r := RandomNumberGenerator.new()
	r.seed = int(a.graine * 1000.0)
	var id: String = a.get("modele", liste[r.randi() % liste.size()])
	var ps: PackedScene = _scenes.get(id)
	if ps == null:
		ps = load(MOD % id)
		_scenes[id] = ps
	var n: Node3D = ps.instantiate()
	n.set_meta("modele", id)   # équipement visible : réglages par modèle (equipement_visuel.gd)
	var zombie: bool = a.zombie
	var teinte := Color(r.randf_range(0.8, 1.15), r.randf_range(0.8, 1.15), r.randf_range(0.8, 1.15)) if a.get("type", "") != "survivant" else Color.WHITE
	var peau: Color = PEAU_ZOMBIE[r.randi() % PEAU_ZOMBIE.size()] if zombie else a.peau
	var sang_mat: ShaderMaterial = null
	if zombie or a.get("sang", 0.0) > 0.0:
		sang_mat = _materiau_sang()
	for mi in n.find_children("*", "MeshInstance3D", true, false):
		var m3: MeshInstance3D = mi
		for s in m3.mesh.get_surface_count():
			var base: Material = m3.mesh.surface_get_material(s)
			if not base is StandardMaterial3D:
				continue
			var nom := String(base.resource_name)
			var c: Color = (base as StandardMaterial3D).albedo_color
			if nom.begins_with("Skin"):
				c = peau.darkened(0.12) if nom == "Skin_Darker" else peau
			elif nom.begins_with("Hair") or nom in ["Eyebrows", "Moustache"]:
				c = a.cheveux_col.lightened(0.15)
				if zombie:
					c = c.darkened(0.3)
			elif nom == "Eye":
				c = Color(0.85, 0.8, 0.55) if zombie else c
			else:
				if a.has("tenue") and (a.tenue.has(String(m3.name) + ":" + nom) or a.tenue.has(nom)):
					c = a.tenue.get(String(m3.name) + ":" + nom, a.tenue.get(nom))   # tenue imposée (marchands, zombies de métier)
				else:
					c = Color(c.r * teinte.r, c.g * teinte.g, c.b * teinte.b)
				if zombie:
					# vêtements sales et délavés (les déchirures sont peintes par le calque de sang)
					c = c.lerp(Color(c.v, c.v, c.v), 0.4 if not a.has("tenue") else 0.2).lerp(Color(0.28, 0.24, 0.18), 0.25 * a.sale).darkened(0.15)
			m3.set_surface_override_material(s, _recolore(base, c))
		if zombie:
			m3.set_instance_shader_parameter("dechire", clampf(0.35 + a.sale * 0.6, 0.0, 1.0))
			m3.set_instance_shader_parameter("sale", a.sale)
			m3.set_instance_shader_parameter("peau", peau)
			m3.set_instance_shader_parameter("graine", a.graine)
		if sang_mat:
			m3.material_overlay = sang_mat
			m3.set_instance_shader_parameter("sang", a.sang if zombie else 0.0)
			m3.set_instance_shader_parameter("graine", a.graine)
	_fusionner_mains(n, id)
	if a.has("equipement"):
		load("res://scripts/equipement_visuel.gd").appliquer(n, a.equipement)
	else:
		_equiper_pnj(n, id, a.get("type", ""), r)
	return n


## Pouce fusionné dans le poing (un maillage par main au lieu de deux : -2 appels de rendu par personnage,
## plus leurs ombres). Maillages fusionnés en cache par modèle et par main.
static var _mains := {}

static func _fusionner_mains(n: Node3D, id: String) -> void:
	for cote in ["_l", "_r"]:
		var ba := n.find_child("MainSimple" + cote, true, false)
		if ba == null:
			continue
		var poing: MeshInstance3D = ba.get_node_or_null("Poing")
		var pouce: MeshInstance3D = ba.get_node_or_null("Pouce")
		if poing == null or pouce == null:
			continue
		var cle: String = id + cote
		if not _mains.has(cle):
			var st := SurfaceTool.new()
			st.append_from(poing.mesh, 0, Transform3D.IDENTITY)
			st.append_from(pouce.mesh, 0, poing.transform.affine_inverse() * pouce.transform)
			var m := st.commit()
			m.surface_set_material(0, poing.mesh.surface_get_material(0))
			_mains[cle] = m
		var mat := poing.get_surface_override_material(0)
		poing.mesh = _mains[cle]
		poing.set_surface_override_material(0, mat)
		ba.remove_child(pouce)
		pouce.free()


## Tenues de métier : modèle + couleurs par matériau (« maillage:matériau » ou « matériau ») + équipement visible.
const TENUES := {
	"medecin": [
		{"modele": "h_suit", "tenue": {"Suit_Body:Suit": Color(0.86, 0.87, 0.85), "Suit_Legs:Suit": Color(0.2, 0.24, 0.3),
			"Tie": Color(0.3, 0.42, 0.55), "White": Color(0.55, 0.68, 0.8)}},
		{"modele": "f_suit", "tenue": {"Suit_Body:Black": Color(0.86, 0.87, 0.85), "Suit_Legs:Black": Color(0.2, 0.24, 0.3),
			"White": Color(0.55, 0.68, 0.8)}}],
	"quincaillier": [
		{"modele": "h_worker", "tenue": {"Worker_Vest": Color(0.2, 0.27, 0.36), "Worker_Body:Worker_Yellow": Color(0.62, 0.6, 0.55),
			"LightBrown": Color(0.55, 0.52, 0.46), "Brown": Color(0.28, 0.26, 0.23), "Brown2": Color(0.22, 0.2, 0.18)}, "tete": "casquette"},
		{"modele": "f_worker", "tenue": {"Worker_Vest": Color(0.2, 0.27, 0.36), "Worker_Body:Worker_Yellow": Color(0.62, 0.6, 0.55),
			"Brown_02": Color(0.28, 0.26, 0.23), "Brown2": Color(0.22, 0.2, 0.18)}, "tete": "bonnet"}],
	"armurier": [
		{"modele": "h_farmer", "tenue": {"Farmer_Body:LightBlue": Color(0.3, 0.27, 0.22), "Beige": Color(0.42, 0.4, 0.32)},
			"torse": "gilet_militaire", "tete": "casquette"},
		{"modele": "h_adventurer", "tenue": {}, "torse": "gilet_militaire"}],
	# zombies selon le lieu (zombie._tenue_du_lieu)
	"pompier": [
		{"modele": "h_worker", "tenue": {"Worker_Vest": Color(0.55, 0.45, 0.15), "Worker_Body:Worker_Yellow": Color(0.8, 0.78, 0.4),
			"LightBrown": Color(0.13, 0.15, 0.22), "Worker_Head:Worker_Yellow": Color(0.62, 0.1, 0.08), "Brown": Color(0.13, 0.15, 0.22), "Brown2": Color(0.1, 0.11, 0.15)}},
		{"modele": "f_worker", "tenue": {"Worker_Vest": Color(0.55, 0.45, 0.15), "Worker_Body:Worker_Yellow": Color(0.8, 0.78, 0.4),
			"White": Color(0.13, 0.15, 0.22), "Worker_Head:Worker_Yellow": Color(0.62, 0.1, 0.08), "Brown_02": Color(0.13, 0.15, 0.22), "Brown2": Color(0.1, 0.11, 0.15)}}],
	"soignant": [
		{"modele": "h_casual_2", "tenue": {"LightBrown": Color(0.42, 0.62, 0.6), "LightBlue": Color(0.42, 0.62, 0.6), "Red_Dark": Color(0.85, 0.85, 0.85)}},
		{"modele": "f_casual", "tenue": {"Casual_Body:White": Color(0.42, 0.62, 0.6), "Orange": Color(0.42, 0.62, 0.6), "Grey": Color(0.85, 0.85, 0.85)}},
		{"modele": "h_suit", "tenue": {"Suit_Body:Suit": Color(0.86, 0.87, 0.85), "Suit_Legs:Suit": Color(0.42, 0.62, 0.6), "Tie": Color(0.42, 0.62, 0.6), "White": Color(0.42, 0.62, 0.6)}}],
	"ouvrier": [{"modele": "h_worker", "tenue": {}}, {"modele": "h_worker", "tenue": {}}, {"modele": "f_worker", "tenue": {}}],
	"prisonnier": [
		{"modele": "h_casual_2", "tenue": {"LightBrown": Color(0.85, 0.4, 0.1), "LightBlue": Color(0.85, 0.4, 0.1)}},
		{"modele": "h_casual_hoodie", "tenue": {"Casual_Body:Purple": Color(0.85, 0.4, 0.1), "LightBlue": Color(0.85, 0.4, 0.1), "Casual_Feet:Purple": Color(0.2, 0.2, 0.2)}}],
	"soldat": [
		{"modele": "h_swat", "tenue": {"Swat": Color(0.3, 0.33, 0.22), "Swat_Black": Color(0.2, 0.21, 0.15)}},
		{"modele": "f_soldier", "tenue": {"Swat": Color(0.3, 0.33, 0.22), "Black": Color(0.2, 0.21, 0.15)}, "tete": "casque_militaire"}],
}


## Habille un marchand selon son métier (même tirage pour un même marchand).
static func tenue_metier(a: Dictionary, metier: String, r: RandomNumberGenerator) -> void:
	var choix: Array = TENUES.get(metier, [])
	if choix.is_empty():
		return
	var t: Dictionary = choix[r.randi() % choix.size()]
	a.modele = t.modele
	a.sexe = "femme" if t.modele.begins_with("f_") else "homme"
	a.tenue = t.tenue
	var eq := {}
	for s in ["tete", "torse"]:
		if t.has(s):
			eq[s] = {"id": t[s]}
	a.equipement = eq


static func _recolore(base: Material, c: Color) -> Material:
	var cle := "%d_%s" % [base.get_instance_id(), c.to_html()]
	if not _mats.has(cle):
		var m: StandardMaterial3D = base.duplicate()
		m.albedo_color = c
		m.roughness = maxf(m.roughness, 0.75)
		_mats[cle] = m
	return _mats[cle]


static var _sang: ShaderMaterial = null


static func _materiau_sang() -> ShaderMaterial:
	if _sang == null:
		_sang = ShaderMaterial.new()
		_sang.shader = load("res://shaders/sang_perso.gdshader")
	return _sang


## Apparence aléatoire pour un type de personnage : survivant, civil, police, militaire, patient.
static func apparence(kind: String, rng: RandomNumberGenerator = null) -> Dictionary:
	if rng == null:
		rng = RandomNumberGenerator.new()
		rng.randomize()
	var f := rng.randf() < (0.45 if kind in ["civil", "patient"] else 0.2)
	var a := {
		"type": kind,
		"sexe": "femme" if f else "homme",
		"peau": PEAUX[rng.randi() % PEAUX.size()],
		"cheveux_col": CHEVEUX[rng.randi() % CHEVEUX.size()],
		"coiffure": (COIFFURES_F if f else COIFFURES_H)[rng.randi() % 4],
		"haut": HAUTS[rng.randi() % HAUTS.size()],
		"bas": BAS[rng.randi() % BAS.size()],
		"chaussures": CHAUSSURES[rng.randi() % CHAUSSURES.size()],
		"manches": [0.35, 0.33, 1.0, 0.0][rng.randi() % 4],
		"jambes": 1.0 if rng.randf() < 0.85 else 0.42,
		"style": 0.0 if rng.randf() < 0.6 else 4.0,
		"zombie": not kind in ["survivant", "bandit", "vendeur", "garde"],
		"sang": rng.randf_range(0.4, 1.0),
		"sale": rng.randf_range(0.3, 0.9),
		"graine": rng.randf() * 100.0,
		"barbe": not f and rng.randf() < 0.3,
		"casque": false, "casquette": false,
	}
	if a.style == 4.0:
		a.manches = 1.0
	match kind:
		"survivant":
			a.sexe = "homme"
			a.peau = PEAUX[1]
			a.coiffure = "cheveux_simple_parted"
			a.cheveux_col = CHEVEUX[1]
			a.haut = Color(0.24, 0.30, 0.24)
			a.bas = Color(0.16, 0.20, 0.30)
			a.chaussures = Color(0.30, 0.20, 0.12)
			a.style = 4.0
			a.manches = 1.0
			a.jambes = 1.0
			a.sang = 0.0
			a.sale = 0.25
			a.barbe = true
		"bandit":
			# vivant, vêtements sombres ou de récup', parfois une casquette
			a.zombie = false
			a.sang = 0.0
			a.sale = rng.randf_range(0.4, 0.8)
			a.haut = [Color(0.12, 0.12, 0.12), Color(0.28, 0.19, 0.12), Color(0.22, 0.26, 0.17), Color(0.32, 0.1, 0.08)][rng.randi() % 4]
			a.bas = [Color(0.1, 0.1, 0.12), Color(0.16, 0.2, 0.3), Color(0.24, 0.22, 0.16)][rng.randi() % 3]
			a.chaussures = Color(0.08, 0.07, 0.06)
			a.manches = 1.0
			a.jambes = 1.0
			a.casquette = rng.randf() < 0.5
		"garde":
			# survivant chargé de la sécurité du camp : tenue kaki ou sombre, souvent casqué
			a.zombie = false
			a.sang = 0.0
			a.sale = rng.randf_range(0.3, 0.6)
			a.haut = [Color(0.32, 0.34, 0.22), Color(0.22, 0.24, 0.2), Color(0.38, 0.33, 0.24)][rng.randi() % 3]
			a.bas = [Color(0.2, 0.22, 0.16), Color(0.14, 0.15, 0.17), Color(0.3, 0.27, 0.2)][rng.randi() % 3]
			a.chaussures = Color(0.08, 0.07, 0.06)
			a.manches = 1.0
			a.jambes = 1.0
			a.casque = rng.randf() < 0.5
			a.casquette = not a.casque and rng.randf() < 0.5
		"police":
			a.style = 1.0
			a.haut = Color(0.10, 0.14, 0.26)
			a.bas = Color(0.08, 0.10, 0.18)
			a.chaussures = Color(0.05, 0.05, 0.05)
			a.manches = 0.35 if rng.randf() < 0.5 else 1.0
			a.jambes = 1.0
			a.casquette = rng.randf() < 0.6
		"militaire":
			a.style = 2.0
			a.chaussures = Color(0.08, 0.07, 0.06)
			a.manches = 1.0
			a.jambes = 1.0
			a.casque = rng.randf() < 0.75
		"boss":
			a.sexe = "homme"
			a.peau = Color(0.50, 0.55, 0.47)
			a.haut = Color(0.18, 0.15, 0.13)
			a.bas = Color(0.20, 0.18, 0.15)
			a.manches = 0.0
			a.jambes = 1.0
			a.style = 0.0
			a.sang = 1.0
			a.sale = 1.0
			a.barbe = true
			a.coiffure = COIFFURES_H[0]
		"coureur":
			a.manches = [0.0, 0.35][rng.randi() % 2]
			a.jambes = 0.42 if rng.randf() < 0.5 else 1.0
			a.sang = rng.randf_range(0.7, 1.0)
		"gros":
			a.sexe = "homme"
			a.style = 4.0
			a.manches = 1.0
			a.sang = rng.randf_range(0.5, 1.0)
			a.sale = 1.0
		"rampant":
			a.sang = 1.0
			a.sale = 1.0
		"patient":
			a.style = 3.0
			a.haut = [Color(0.62, 0.75, 0.82), Color(0.80, 0.84, 0.80), Color(0.70, 0.80, 0.72)][rng.randi() % 3]
			a.manches = 0.3
			a.jambes = 0.0
			a.sang = rng.randf_range(0.6, 1.0)
	return a


## Instancie le modèle et applique l'apparence. Renvoie null si les modèles sont absents.
static func creer(a: Dictionary) -> Node3D:
	if modulaires():
		return _creer_modulaire(a)
	var ps := _scene(a.get("sexe", "homme"))
	if ps == null:
		return null
	var n: Node3D = ps.instantiate()
	appliquer(n, a)
	return n


static func appliquer(n: Node3D, a: Dictionary) -> void:
	var corps: MeshInstance3D = n.find_child("Corps", true, false)
	if corps:
		corps.set_instance_shader_parameter("c_peau", _rgb(a.peau))
		corps.set_instance_shader_parameter("c_haut", _rgb(a.haut))
		corps.set_instance_shader_parameter("c_bas", _rgb(a.bas))
		corps.set_instance_shader_parameter("c_chaussures", _rgb(a.chaussures))
		corps.set_instance_shader_parameter("c_cheveux", _rgb(a.cheveux_col))
		corps.set_instance_shader_parameter("manches", a.manches)
		corps.set_instance_shader_parameter("jambes", a.jambes)
		corps.set_instance_shader_parameter("style", a.style)
		corps.set_instance_shader_parameter("zombie", 1.0 if a.zombie else 0.0)
		corps.set_instance_shader_parameter("sang", a.sang if a.zombie else 0.0)
		corps.set_instance_shader_parameter("sale", a.sale)
		corps.set_instance_shader_parameter("graine", a.graine)
		corps.set_instance_shader_parameter("cheveux", 0.0 if a.coiffure == "" else (2.0 if a.coiffure in ["cheveux_long"] else 1.0))
		corps.set_instance_shader_parameter("femme", 1.0 if a.sexe == "femme" else 0.0)
	var sk: Skeleton3D = ModeleUtil.squelette(n)
	if sk == null:
		return
	var casque_ou_casquette: bool = a.get("casque", false) or a.get("casquette", false)
	for c in sk.get_children():
		if c is MeshInstance3D and c.name.begins_with("cheveux_"):
			c.visible = (c.name == a.coiffure and not casque_ou_casquette) or (c.name == "cheveux_beard" and a.get("barbe", false))
			if c.visible:
				_teinter_cheveux(c, a.cheveux_col, a.zombie)
		elif c is MeshInstance3D and c.name.begins_with("sourcils"):
			c.visible = (c.name == "sourcils") == (a.sexe == "homme")
			if c.visible:
				_teinter_cheveux(c, a.cheveux_col, a.zombie)
	var tete: Node = sk.get_node_or_null("Tete")
	if tete:
		tete.get_node("Casque").visible = a.get("casque", false)
		tete.get_node("Casquette").visible = a.get("casquette", false)


static var _mats_cheveux := {}


static func _teinter_cheveux(mi: MeshInstance3D, c: Color, zombie: bool) -> void:
	var base: StandardMaterial3D = mi.material_override
	if base == null:
		return
	var cle := "%s_%s_%s" % [base.get_instance_id(), c.to_html(), zombie]
	if not _mats_cheveux.has(cle):
		var m: StandardMaterial3D = base.duplicate()
		# la texture est châtain : on la ramène vers la couleur voulue
		m.albedo_color = Color(c.r * 1.9, c.g * 1.9, c.b * 1.9).clamp(Color(0, 0, 0), Color(1, 1, 1))
		if zombie:
			m.albedo_color = m.albedo_color.darkened(0.25)
		_mats_cheveux[cle] = m
	mi.material_override = _mats_cheveux[cle]


static func _rgb(c: Color) -> Vector3:
	return Vector3(c.r, c.g, c.b)



## Équipement visible des PNJ (zombies policiers et militaires, quelques civils, bandits) : tiré au hasard
## selon le type et le modèle (même tirage pour une même graine). Purement visuel.
static func _equiper_pnj(n: Node3D, id: String, type: String, r: RandomNumberGenerator) -> void:
	var eq := {}
	var x := r.randf()
	match type:
		"police":
			if id == "h_suit" and x < 0.6:
				eq.tete = "casquette_police"
		"militaire":
			if id == "f_soldier" and x < 0.8:
				eq.tete = "casque_militaire"
			if r.randf() < 0.3:
				eq.dos = "sac_militaire"
		"bandit":
			if x < 0.45:
				eq.tete = ["bonnet", "casquette", "casquette", "bonnet", "casque_moto"][r.randi() % 5]
			elif x < 0.55:
				eq.visage = "masque_gaz"
			if r.randf() < 0.3:
				eq.dos = ["sac_a_dos", "sac_sport", "sac_toile"][r.randi() % 3]
		"civil", "coureur":
			if x < 0.08:
				eq.tete = "casquette" if r.randf() < 0.6 else "bonnet"
			elif x < 0.11:
				eq.tete = "casque_chantier" if id.ends_with("worker") else "casquette"
	if eq.is_empty():
		return
	for s in eq:
		eq[s] = {"id": eq[s]}
	load("res://scripts/equipement_visuel.gd").appliquer(n, eq)

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


static func _scene(sexe: String) -> PackedScene:
	if not _scenes.has(sexe):
		var p := "res://modeles/persos/%s.scn" % sexe
		_scenes[sexe] = load(p) if ResourceLoader.exists(p) else null
	return _scenes[sexe]


static func disponible() -> bool:
	return _scene("homme") != null


## Apparence aléatoire pour un type de personnage : survivant, civil, police, militaire, patient.
static func apparence(kind: String, rng: RandomNumberGenerator = null) -> Dictionary:
	if rng == null:
		rng = RandomNumberGenerator.new()
		rng.randomize()
	var f := rng.randf() < (0.45 if kind in ["civil", "patient"] else 0.2)
	var a := {
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
		"zombie": kind != "survivant",
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
		"patient":
			a.style = 3.0
			a.haut = [Color(0.62, 0.75, 0.82), Color(0.80, 0.84, 0.80), Color(0.70, 0.80, 0.72)][rng.randi() % 3]
			a.manches = 0.3
			a.jambes = 0.0
			a.sang = rng.randf_range(0.6, 1.0)
	return a


## Instancie le modèle et applique l'apparence. Renvoie null si les modèles sont absents.
static func creer(a: Dictionary) -> Node3D:
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

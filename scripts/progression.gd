class_name Progression
extends RefCounted
## Niveaux, attributs et compétences du survivant.
## - Niveau global : chaque niveau donne 1 point d'attribut (endurance, santé, soif, faim).
## - Compétences Combat / Fabrication / Exploration / Survie : XP propre, niveaux 1 à 10 ;
##   chaque niveau de compétence donne 1 point de talent à dépenser dans cette compétence.
## Les actions rapportent de l'XP de compétence et de l'XP globale.

signal niveau_global(n: int)
signal niveau_competence(comp: String, n: int)
signal xp_gagnee(comp: String, qte: int)

const COMPETENCES := ["combat", "fabrication", "exploration", "survie"]
const NOMS := {"combat": "Combat", "fabrication": "Fabrication", "exploration": "Exploration", "survie": "Survie"}
const NIVEAU_MAX_COMP := 10

const ATTRIBUTS := {
	"endurance": {"nom": "Endurance", "desc": "+10 d'endurance max et récupération +8 %"},
	"sante": {"nom": "Santé", "desc": "+10 de santé max"},
	"soif": {"nom": "Soif", "desc": "La soif baisse 7 % moins vite"},
	"faim": {"nom": "Faim", "desc": "La faim baisse 7 % moins vite"},
}

## Talents : compétence, niveau de compétence requis, description.
const TALENTS := {
	# --- combat
	"coup_puissant": {"comp": "combat", "niv": 1, "nom": "Coup puissant", "desc": "+25 % de dégâts au corps à corps."},
	"main_sure": {"comp": "combat", "niv": 1, "nom": "Main sûre", "desc": "Tirs 25 % plus précis."},
	"recharge_rapide": {"comp": "combat", "niv": 2, "nom": "Recharge rapide", "desc": "Rechargement 25 % plus rapide."},
	"souffle": {"comp": "combat", "niv": 3, "nom": "Second souffle", "desc": "Les coups au corps à corps coûtent 30 % d'endurance en moins."},
	"tireur": {"comp": "combat", "niv": 4, "nom": "Tireur d'élite", "desc": "+20 % de dégâts avec les armes à feu."},
	"robuste": {"comp": "combat", "niv": 5, "nom": "Peau dure", "desc": "Tu subis 15 % de dégâts en moins."},
	"critique": {"comp": "combat", "niv": 7, "nom": "Coup critique", "desc": "20 % de chances d'infliger double dégâts au corps à corps."},
	"sang_froid": {"comp": "combat", "niv": 9, "nom": "Sang-froid", "desc": "Recul des armes réduit de 35 %."},
	"lame_aiguisee": {"comp": "combat", "niv": 2, "nom": "Lame aiguisée", "desc": "Hache, machette et couteau : +20 % de dégâts et plus de sang."},
	"frappeur": {"comp": "combat", "niv": 3, "nom": "Frappeur", "desc": "Battes et matraque repoussent les zombies à chaque coup."},
	"charge_rapide": {"comp": "combat", "niv": 4, "nom": "Concentration", "desc": "Le coup puissant se charge 40 % plus vite."},
	"balayage": {"comp": "combat", "niv": 6, "nom": "Grand balayage", "desc": "Le balayage latéral touche jusqu'à deux zombies."},
	"brute": {"comp": "combat", "niv": 8, "nom": "Brute", "desc": "Un coup puissant chargé à fond renverse toujours le zombie."},
	# --- fabrication
	"soigneur": {"comp": "fabrication", "niv": 1, "nom": "Soigneur", "desc": "Les soins rendent 30 % de santé en plus."},
	"econome": {"comp": "fabrication", "niv": 1, "nom": "Économe", "desc": "30 % de chances de récupérer un matériau en fabriquant."},
	"cartoucherie": {"comp": "fabrication", "niv": 2, "nom": "Cartoucherie", "desc": "Les munitions fabriquées sont 50 % plus nombreuses."},
	"charpentier": {"comp": "fabrication", "niv": 3, "nom": "Charpentier", "desc": "Barricades et établis posés ont 60 % de solidité en plus."},
	"cuisinier": {"comp": "fabrication", "niv": 4, "nom": "Débrouillard", "desc": "Nourriture et boissons nourrissent 25 % de plus."},
	"atelier": {"comp": "fabrication", "niv": 6, "nom": "Atelier portatif", "desc": "Fabrique les recettes d'établi partout."},
	"maitre_artisan": {"comp": "fabrication", "niv": 8, "nom": "Maître artisan", "desc": "Une chance sur deux d'obtenir un objet fabriqué en double (hors munitions)."},
	# --- exploration
	"fouilleur": {"comp": "exploration", "niv": 1, "nom": "Fouilleur", "desc": "Les meubles contiennent plus d'objets."},
	"discret": {"comp": "exploration", "niv": 1, "nom": "Pas de loup", "desc": "Les zombies te repèrent de 30 % moins loin."},
	"coureur": {"comp": "exploration", "niv": 2, "nom": "Coureur", "desc": "Sprint 12 % plus rapide."},
	"poches": {"comp": "exploration", "niv": 3, "nom": "Poches profondes", "desc": "+1 rangée à ton inventaire de base (8×6)."},
	"marathonien": {"comp": "exploration", "niv": 4, "nom": "Marathonien", "desc": "Le sprint consomme 35 % d'endurance en moins."},
	"poches2": {"comp": "exploration", "niv": 6, "nom": "Poches de cargo", "desc": "+1 rangée supplémentaire (8×7)."},
	"vue_percante": {"comp": "exploration", "niv": 8, "nom": "Œil de lynx", "desc": "Les meubles contiennent encore plus d'objets."},
	# --- survie (XP : manger, boire, se soigner, survivre aux blessures)
	"regeneration": {"comp": "survie", "niv": 1, "nom": "Régénération", "desc": "La santé remonte deux fois plus vite quand tu es nourri et hydraté."},
	"frugal": {"comp": "survie", "niv": 2, "nom": "Frugal", "desc": "La faim et la soif baissent 15 % moins vite."},
	"endurci": {"comp": "survie", "niv": 3, "nom": "Endurci", "desc": "L'endurance remonte 25 % plus vite."},
	"adrenaline": {"comp": "survie", "niv": 5, "nom": "Adrénaline", "desc": "Sous 25 % de santé : +20 % de dégâts et de vitesse."},
	"increvable": {"comp": "survie", "niv": 8, "nom": "Increvable", "desc": "Une fois par jour, une blessure mortelle te laisse à 15 de santé."},
}

var niveau := 1
var xp := 0
var points := 0
var attributs := {"endurance": 0, "sante": 0, "soif": 0, "faim": 0}
var comp := {}          # nom -> {"niv": int, "xp": int, "points": int}
var talents: Array = []
var lieux_vus := {}     # bâtiments/points d'intérêt déjà découverts


func _init() -> void:
	for c in COMPETENCES:
		comp[c] = {"niv": 0, "xp": 0, "points": 0}


static func xp_niveau(n: int) -> int:
	return int(100.0 * pow(n, 1.45))


static func xp_comp(n: int) -> int:
	return int(60.0 * pow(n + 1, 1.5))


func a(talent: String) -> bool:
	return talent in talents


## Gagne de l'XP dans une compétence (et autant d'XP globale).
func gagner(c: String, qte: int) -> void:
	if qte <= 0:
		return
	xp_gagnee.emit(c, qte)
	xp += qte
	while xp >= xp_niveau(niveau):
		xp -= xp_niveau(niveau)
		niveau += 1
		points += 1
		niveau_global.emit(niveau)
	if not comp.has(c):
		return
	var d: Dictionary = comp[c]
	if d.niv >= NIVEAU_MAX_COMP:
		return
	d.xp += qte
	while d.niv < NIVEAU_MAX_COMP and d.xp >= xp_comp(d.niv):
		d.xp -= xp_comp(d.niv)
		d.niv += 1
		d.points += 1
		niveau_competence.emit(c, d.niv)


func peut_debloquer(t: String) -> bool:
	if a(t) or not TALENTS.has(t):
		return false
	var info: Dictionary = TALENTS[t]
	var d: Dictionary = comp[info.comp]
	return d.points > 0 and d.niv >= info.niv


func debloquer(t: String) -> bool:
	if not peut_debloquer(t):
		return false
	comp[TALENTS[t].comp].points -= 1
	talents.append(t)
	return true


func ameliorer(attr: String) -> bool:
	if points <= 0 or not attributs.has(attr):
		return false
	points -= 1
	attributs[attr] += 1
	return true


# ---------------------------------------------------------------- effets
func sante_max() -> float:
	return 100.0 + 10.0 * attributs.sante


func endurance_max() -> float:
	return 100.0 + 10.0 * attributs.endurance


func recup_endurance() -> float:
	return (1.0 + 0.08 * attributs.endurance) * (1.25 if a("endurci") else 1.0)


func faim_mult() -> float:
	return pow(0.93, attributs.faim) * (0.85 if a("frugal") else 1.0)


func soif_mult() -> float:
	return pow(0.93, attributs.soif) * (0.85 if a("frugal") else 1.0)


func lignes_inventaire() -> int:
	return 5 + (1 if a("poches") else 0) + (1 if a("poches2") else 0)


# ---------------------------------------------------------------- sauvegarde
func vers_dict() -> Dictionary:
	return {"niveau": niveau, "xp": xp, "points": points, "attributs": attributs, "comp": comp,
			"talents": talents, "lieux": lieux_vus.keys()}


func depuis_dict(d: Dictionary) -> void:
	niveau = int(d.get("niveau", 1))
	xp = int(d.get("xp", 0))
	points = int(d.get("points", 0))
	var at: Dictionary = d.get("attributs", {})
	for k in attributs:
		attributs[k] = int(at.get(k, 0))
	var cd: Dictionary = d.get("comp", {})
	for c in COMPETENCES:
		var x: Dictionary = cd.get(c, {})
		comp[c] = {"niv": int(x.get("niv", 0)), "xp": int(x.get("xp", 0)), "points": int(x.get("points", 0))}
	talents = []
	for t in d.get("talents", []):
		if TALENTS.has(str(t)):
			talents.append(str(t))
	lieux_vus = {}
	for l in d.get("lieux", []):
		lieux_vus[str(l)] = true
